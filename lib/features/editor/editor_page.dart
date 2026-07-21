import 'dart:async';

import 'package:easy_date_timeline/easy_date_timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';

import '../../core/diary/diary_entry.dart';
import '../../core/diary/diary_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

class EditorPage extends ConsumerStatefulWidget {
  const EditorPage({this.entryId, super.key});

  final String? entryId;

  @override
  ConsumerState<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends ConsumerState<EditorPage>
    with WidgetsBindingObserver {
  static final _firstDate = DateTime(1900);
  static final _lastDate = DateTime(2100, 12, 31);
  static const _defaultMood = 'calm';

  final _titleController = TextEditingController();
  final _editorFocusNode = FocusNode();
  final _editorScrollController = ScrollController();
  final _datePickerController = EasyDatePickerController();
  final _uuid = const Uuid();

  late final DiaryRepository _repository;
  late DateTime _selectedDate;
  late QuillController _quillController;
  StreamSubscription<DocChange>? _documentChanges;
  Timer? _saveDebounce;
  Future<void> _saveQueue = Future<void>.value();
  DiaryEntry? _entry;
  String _mood = _defaultMood;
  int _changeRevision = 0;
  int _pendingSaves = 0;
  bool _datePickerExpanded = true;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasChanges = false;
  bool _isApplyingEntry = false;
  bool _isChangingDate = false;
  bool _isExiting = false;
  bool _allowPop = false;
  bool _lastSaveSucceeded = true;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _repository = ref.read(diaryRepositoryProvider);
    _selectedDate = DateUtils.dateOnly(DateTime.now());
    _quillController = QuillController.basic();
    WidgetsBinding.instance.addObserver(this);
    _listenToDocument();
    _titleController.addListener(_onFieldChanged);
    _loadInitialEntry();
  }

  Future<void> _loadInitialEntry() async {
    try {
      final entry = widget.entryId == null
          ? await _repository.findByDate(_selectedDate)
          : await _repository.findById(widget.entryId!);
      if (!mounted) return;
      _entry = entry;
      _selectedDate = DateUtils.dateOnly(entry?.createdAt ?? _selectedDate);
      _applyEntry(entry);
    } on Object catch (error) {
      if (mounted) setState(() => _loadError = error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyEntry(DiaryEntry? entry) {
    _isApplyingEntry = true;
    _titleController.text = entry?.title ?? '';
    _mood = entry?.mood.isNotEmpty == true ? entry!.mood : _defaultMood;
    _quillController.document = _documentFromEntry(entry);
    _listenToDocument();
    _hasChanges = false;
    _lastSaveSucceeded = true;
    _isApplyingEntry = false;
  }

  Document _documentFromEntry(DiaryEntry? entry) {
    if (entry == null || entry.content.trim().isEmpty) return Document();
    try {
      final delta = HtmlToDelta().convert(entry.content);
      return delta.isEmpty ? Document() : Document.fromDelta(delta);
    } on Object {
      final document = Document();
      if (entry.plainContent.isNotEmpty) {
        document.insert(0, entry.plainContent);
      }
      return document;
    }
  }

  void _listenToDocument() {
    final previousSubscription = _documentChanges;
    if (previousSubscription != null) {
      unawaited(previousSubscription.cancel());
    }
    _documentChanges = _quillController.document.changes.listen((_) {
      if (!_isApplyingEntry && !_isLoading) _markChanged();
    });
  }

  void _onFieldChanged() {
    if (_isLoading || _isApplyingEntry) return;
    _markChanged();
  }

  void _markChanged() {
    _changeRevision++;
    _lastSaveSucceeded = true;
    if (!_hasChanges && mounted) setState(() => _hasChanges = true);
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 700), () {
      unawaited(_saveCurrent());
    });
  }

  Future<bool> _saveCurrent({bool updateUi = true}) async {
    if (!_hasChanges) {
      await _saveQueue;
      return _lastSaveSucceeded;
    }
    final date = _selectedDate;
    final revision = _changeRevision;
    final title = _titleController.text.trim();
    final plainContent = _quillController.document.toPlainText().trim();
    final hasContent =
        title.isNotEmpty || plainContent.isNotEmpty || _mood != _defaultMood;
    if (!hasContent && _entry == null) {
      _hasChanges = false;
      if (updateUi && mounted) setState(() {});
      return true;
    }

    final content = QuillDeltaToHtmlConverter(
      _quillController.document.toDelta().toJson(),
    ).convert();
    final now = DateTime.now();
    final createdAt = DateTime(
      date.year,
      date.month,
      date.day,
      now.hour,
      now.minute,
      now.second,
      now.millisecond,
    );
    final entry =
        (_entry ??
                DiaryEntry(
                  id: _uuid.v4(),
                  title: '',
                  content: '<p><br></p>',
                  plainContent: '',
                  mood: _defaultMood,
                  createdAt: createdAt,
                  updatedAt: now,
                ))
            .copyWith(
              title: title,
              content: content,
              plainContent: plainContent,
              mood: _mood,
              updatedAt: now,
            );

    _entry = entry;
    _pendingSaves++;
    if (updateUi && mounted) {
      setState(() => _isSaving = true);
    }
    final result = Completer<bool>();
    _saveQueue = _saveQueue.then((_) async {
      try {
        await _repository.save(entry);
        _lastSaveSucceeded = true;
        if (date == _selectedDate && revision == _changeRevision) {
          _hasChanges = false;
        }
        result.complete(true);
      } on Object catch (error, stack) {
        _lastSaveSucceeded = false;
        result.complete(false);
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'ShadowDiary autosave',
          ),
        );
      } finally {
        _pendingSaves--;
        if (updateUi && mounted) {
          setState(() => _isSaving = _pendingSaves > 0);
        }
      }
    });
    await _saveQueue;
    return result.future;
  }

  Future<void> _selectDate(DateTime date) async {
    final nextDate = DateUtils.dateOnly(date);
    if (nextDate == _selectedDate || _isChangingDate) return;
    setState(() => _isChangingDate = true);
    _saveDebounce?.cancel();
    try {
      final saved = await _saveCurrent();
      if (!saved) {
        _showSaveError();
        return;
      }
      final nextEntry = await _repository.findByDate(nextDate);
      if (!mounted) return;
      setState(() {
        _selectedDate = nextDate;
        _entry = nextEntry;
        _applyEntry(nextEntry);
      });
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).editorLoadError)),
        );
      }
    } finally {
      if (mounted) setState(() => _isChangingDate = false);
    }
  }

  Future<void> _exit() async {
    if (_isExiting) return;
    setState(() => _isExiting = true);
    _saveDebounce?.cancel();
    final saved = await _saveCurrent();
    if (!mounted) return;
    if (!saved) {
      _isExiting = false;
      _showSaveError();
      return;
    }
    setState(() => _allowPop = true);
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  void _showSaveError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).editorSaveError)),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _saveDebounce?.cancel();
      unawaited(_saveCurrent());
    }
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    unawaited(_saveCurrent(updateUi: false));
    final documentChanges = _documentChanges;
    if (documentChanges != null) unawaited(documentChanges.cancel());
    WidgetsBinding.instance.removeObserver(this);
    _quillController.dispose();
    _titleController.dispose();
    _editorFocusNode.dispose();
    _editorScrollController.dispose();
    _datePickerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_exit());
      },
      child: Scaffold(
        body: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _loadError != null
              ? Center(child: Text(l10n.editorLoadError))
              : AbsorbPointer(
                  absorbing: _isChangingDate || _isExiting,
                  child: Column(
                    children: [
                      _EditorHeader(
                        date: _selectedDate,
                        expanded: _datePickerExpanded,
                        isSaving: _isSaving || _hasChanges,
                        l10n: l10n,
                        onBack: _exit,
                        onToggleDatePicker: () => setState(
                          () => _datePickerExpanded = !_datePickerExpanded,
                        ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 180),
                        alignment: Alignment.topCenter,
                        child: _datePickerExpanded
                            ? _DatePicker(
                                selectedDate: _selectedDate,
                                locale: locale,
                                controller: _datePickerController,
                                firstDate: _firstDate,
                                lastDate: _lastDate,
                                onDateChange: _selectDate,
                              )
                            : const SizedBox.shrink(),
                      ),
                      _EditorFields(
                        titleController: _titleController,
                        mood: _mood,
                        onMoodChanged: (value) {
                          setState(() => _mood = value);
                          _markChanged();
                        },
                        l10n: l10n,
                      ),
                      const Divider(height: 1),
                      QuillSimpleToolbar(
                        controller: _quillController,
                        config: const QuillSimpleToolbarConfig(
                          showFontFamily: false,
                          showFontSize: false,
                          showColorButton: false,
                          showBackgroundColorButton: false,
                          showAlignmentButtons: false,
                          showListCheck: false,
                          showCodeBlock: false,
                          showQuote: false,
                          showIndent: false,
                          showLink: false,
                          showSearchButton: false,
                          showSubscript: false,
                          showSuperscript: false,
                          multiRowsDisplay: false,
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: QuillEditor(
                          key: const Key('editor-quill-editor'),
                          controller: _quillController,
                          focusNode: _editorFocusNode,
                          scrollController: _editorScrollController,
                          config: QuillEditorConfig(
                            placeholder: l10n.editorBodyPlaceholder,
                            padding: const EdgeInsets.all(AppSpacing.md),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _EditorHeader extends StatelessWidget {
  const _EditorHeader({
    required this.date,
    required this.expanded,
    required this.isSaving,
    required this.l10n,
    required this.onBack,
    required this.onToggleDatePicker,
  });

  final DateTime date;
  final bool expanded;
  final bool isSaving;
  final AppLocalizations l10n;
  final VoidCallback onBack;
  final VoidCallback onToggleDatePicker;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final label = DateFormat.yMMMMd(locale).format(date);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
      child: Row(
        children: [
          IconButton(
            key: const Key('editor-exit-button'),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.titleMedium),
                Text(
                  isSaving ? l10n.editorSaving : l10n.editorSaved,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          IconButton(
            key: const Key('editor-date-picker-toggle'),
            tooltip: expanded
                ? l10n.editorCollapseDates
                : l10n.editorExpandDates,
            onPressed: onToggleDatePicker,
            icon: Icon(
              expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _DatePicker extends StatelessWidget {
  const _DatePicker({
    required this.selectedDate,
    required this.locale,
    required this.controller,
    required this.firstDate,
    required this.lastDate,
    required this.onDateChange,
  });

  final DateTime selectedDate;
  final Locale locale;
  final EasyDatePickerController controller;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onDateChange;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const Key('editor-day-picker'),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(
            color: colors.outlineVariant.withValues(alpha: .5),
          ),
        ),
      ),
      child: EasyDateTimeLinePicker(
        controller: controller,
        firstDate: firstDate,
        lastDate: lastDate,
        focusedDate: selectedDate,
        locale: locale,
        headerOptions: const HeaderOptions(headerType: HeaderType.none),
        timelineOptions: const TimelineOptions(
          height: 92,
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
        onDateChange: onDateChange,
      ),
    );
  }
}

class _EditorFields extends StatelessWidget {
  const _EditorFields({
    required this.titleController,
    required this.mood,
    required this.onMoodChanged,
    required this.l10n,
  });

  final TextEditingController titleController;
  final String mood;
  final ValueChanged<String> onMoodChanged;
  final AppLocalizations l10n;

  static const _moods = <String, String>{
    'happy': '😊',
    'excited': '🤩',
    'calm': '😌',
    'tired': '😴',
    'sad': '😔',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          TextField(
            key: const Key('editor-title-field'),
            controller: titleController,
            textInputAction: TextInputAction.next,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              hintText: l10n.editorTitlePlaceholder,
              border: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text(
                  l10n.editorMood,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(width: 8),
                ..._moods.entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Semantics(
                      button: true,
                      selected: mood == entry.key,
                      label: _moodLabel(l10n, entry.key),
                      child: InkWell(
                        key: Key('editor-mood-${entry.key}'),
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => onMoodChanged(entry.key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: mood == entry.key
                                ? Theme.of(
                                    context,
                                  ).colorScheme.secondaryContainer
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            entry.value,
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _moodLabel(AppLocalizations l10n, String mood) {
    return switch (mood) {
      'happy' => l10n.editorMoodHappy,
      'excited' => l10n.editorMoodExcited,
      'calm' => l10n.editorMoodCalm,
      'tired' => l10n.editorMoodTired,
      'sad' => l10n.editorMoodSad,
      _ => l10n.editorMood,
    };
  }
}
