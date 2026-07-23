import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/archives/archive.dart';
import '../../core/archives/archive_repository.dart';
import '../../core/archives/archive_search.dart';
import '../../core/diary/diary_entry.dart';
import '../../core/diary/diary_repository.dart';
import '../../core/diary/diary_search.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_search_field.dart';
import '../../l10n/app_localizations.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({
    required this.onClose,
    required this.onOpenEntry,
    required this.onOpenArchive,
    super.key,
  });

  final VoidCallback onClose;
  final ValueChanged<String> onOpenEntry;
  final ValueChanged<String> onOpenArchive;

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  static const _debounceDuration = Duration(milliseconds: 300);
  static const _moods = <String, String>{
    'happy': '😊',
    'excited': '🤩',
    'calm': '😌',
    'tired': '😴',
    'sad': '😔',
  };

  final _queryController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _debounce;
  DiarySearchResult? _result;
  List<Archive> _archiveMatches = const <Archive>[];
  List<String> _history = const <String>[];
  Object? _error;
  String? _selectedMood;
  DateTimeRange? _dateRange;
  bool _isLoading = false;
  int _requestId = 0;

  bool get _hasFilters => _selectedMood != null || _dateRange != null;

  @override
  void initState() {
    super.initState();
    _queryController.addListener(_onQueryChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
    unawaited(_loadHistory());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController
      ..removeListener(_onQueryChanged)
      ..dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    if (!mounted) return;
    setState(() {});
    _debounce?.cancel();
    final query = _queryController.text.trim();
    if (query.isEmpty && !_hasFilters) {
      _requestId++;
      setState(() {
        _result = null;
        _archiveMatches = const <Archive>[];
        _error = null;
        _isLoading = false;
      });
      return;
    }
    _debounce = Timer(_debounceDuration, _runSearch);
  }

  Future<void> _loadHistory() async {
    try {
      final history = await ref
          .read(diarySearchRepositoryProvider)
          .loadSearchHistory();
      if (mounted) setState(() => _history = history);
    } on Object {
      // Search remains useful when history storage is unavailable.
    }
  }

  Future<void> _runSearch({bool remember = false}) async {
    _debounce?.cancel();
    final query = _queryController.text.trim();
    if (query.isEmpty && !_hasFilters) return;

    final requestId = ++_requestId;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final searchFuture = ref
          .read(diarySearchRepositoryProvider)
          .searchDiaries(
            DiarySearchParams(
              keyword: query,
              mood: _selectedMood,
              dateFrom: _dateRange?.start,
              dateTo: _dateRange?.end,
            ),
          );
      final archivesFuture = query.isEmpty
          ? Future<List<Archive>>.value(const <Archive>[])
          : ref.read(archiveRepositoryProvider).listArchives();
      final values = await Future.wait<Object>([searchFuture, archivesFuture]);
      if (!mounted || requestId != _requestId) return;

      final result = values[0] as DiarySearchResult;
      final archives = values[1] as List<Archive>;
      setState(() {
        _result = result;
        _archiveMatches = query.isEmpty
            ? const <Archive>[]
            : searchArchives(archives, query).take(8).toList(growable: false);
        _isLoading = false;
      });
      if (remember && query.isNotEmpty) unawaited(_rememberSearch(query));
    } on Object catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _error = error;
        _isLoading = false;
      });
    }
  }

  Future<void> _rememberSearch(String query) async {
    try {
      await ref.read(diarySearchRepositoryProvider).rememberSearch(query);
      await _loadHistory();
    } on Object {
      // A failed history write must not block opening a search result.
    }
  }

  void _submitSearch(String _) {
    unawaited(_runSearch(remember: true));
  }

  void _useHistory(String query) {
    _queryController.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    unawaited(_runSearch(remember: true));
  }

  Future<void> _clearHistory() async {
    try {
      await ref.read(diarySearchRepositoryProvider).clearSearchHistory();
      if (mounted) setState(() => _history = const <String>[]);
    } on Object {
      // History controls are intentionally non-blocking.
    }
  }

  void _selectMood(String mood) {
    setState(() {
      _selectedMood = _selectedMood == mood ? null : mood;
    });
    _refreshAfterFilterChange();
  }

  Future<void> _selectDateRange() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final now = DateTime.now();
    final selection = await showModalBottomSheet<_DateRangeSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _SearchDateRangeSheet(
        initialRange: _dateRange,
        firstDay: DateTime(1970),
        lastDay: DateTime(now.year + 1, 12, 31),
      ),
    );
    if (selection == null || !mounted) return;
    setState(() => _dateRange = selection.range);
    _refreshAfterFilterChange();
  }

  void _clearFilters() {
    setState(() {
      _selectedMood = null;
      _dateRange = null;
    });
    _refreshAfterFilterChange();
  }

  void _refreshAfterFilterChange() {
    if (_queryController.text.trim().isEmpty) {
      if (!_hasFilters) {
        _resetToStartState();
        return;
      }
    }
    unawaited(_runSearch());
  }

  void _resetToStartState() {
    _requestId++;
    setState(() {
      _result = null;
      _archiveMatches = const <Archive>[];
      _error = null;
      _isLoading = false;
    });
  }

  void _openEntry(String id) {
    final query = _queryController.text.trim();
    if (query.isNotEmpty) unawaited(_rememberSearch(query));
    widget.onOpenEntry(id);
  }

  void _openArchive(String id) {
    final query = _queryController.text.trim();
    if (query.isNotEmpty) unawaited(_rememberSearch(query));
    widget.onOpenArchive(id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final background = theme.scaffoldBackgroundColor;
    final wash = Color.alphaBlend(
      colors.primary.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.1 : 0.055,
      ),
      background,
    );

    return Scaffold(
      key: const Key('search-page'),
      resizeToAvoidBottomInset: true,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [wash, background, background],
            stops: const [0, 0.46, 1],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  0,
                ),
                child: _buildSearchField(context),
              ),
              const SizedBox(height: 12),
              _buildFilters(context),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: _isLoading
                    ? const LinearProgressIndicator(
                        key: Key('search-progress'),
                        minHeight: 2,
                      )
                    : const SizedBox(
                        key: Key('search-progress-idle'),
                        height: 2,
                      ),
              ),
              Expanded(child: _buildBody(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppSearchField(
      textFieldKey: const Key('search-query-field'),
      controller: _queryController,
      focusNode: _searchFocusNode,
      autofocus: true,
      hintText: l10n.searchHint,
      clearTooltip: l10n.searchClear,
      onClear: _queryController.clear,
      clearButtonKey: const Key('search-clear-button'),
      onSubmitted: _submitSearch,
      onTapOutside: (_) => _searchFocusNode.unfocus(),
      trailing: IconButton(
        key: const Key('search-close-button'),
        tooltip: l10n.searchClose,
        onPressed: () {
          FocusManager.instance.primaryFocus?.unfocus();
          widget.onClose();
        },
        icon: const Icon(Icons.close_rounded),
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dateLabel = _dateRange == null
        ? l10n.searchDateFilter
        : _formatDateRange(_dateRange!, locale);
    return SizedBox(
      height: 50,
      child: ListView(
        key: const Key('search-filter-list'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, 8),
        children: [
          FilterChip(
            key: const Key('search-date-filter'),
            selected: _dateRange != null,
            avatar: const Icon(Icons.calendar_today_rounded, size: 17),
            label: Text(dateLabel),
            onSelected: (_) => unawaited(_selectDateRange()),
          ),
          const SizedBox(width: AppSpacing.sm),
          for (final mood in _moods.entries) ...[
            FilterChip(
              key: Key('search-mood-${mood.key}'),
              selected: _selectedMood == mood.key,
              tooltip: _moodLabel(l10n, mood.key),
              label: Text('${mood.value} ${_moodLabel(l10n, mood.key)}'),
              onSelected: (_) => _selectMood(mood.key),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          if (_hasFilters)
            IconButton(
              key: const Key('search-clear-filters'),
              tooltip: l10n.searchClearFilters,
              onPressed: _clearFilters,
              icon: const Icon(Icons.filter_alt_off_rounded),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final result = _result;
    final stateKey = _error != null
        ? 'error'
        : result == null
        ? 'start'
        : 'results-${result.total}-${_archiveMatches.length}';
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final offset = Tween<Offset>(
          begin: const Offset(0, 0.025),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: KeyedSubtree(
        key: ValueKey(stateKey),
        child: _error != null
            ? _buildError(context)
            : result == null
            ? _buildStart(context)
            : _buildResults(context, result),
      ),
    );
  }

  Widget _buildStart(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      key: const Key('search-start-state'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: [
        if (_history.isEmpty) ...[
          const Center(child: _SearchLensMark()),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.searchStartTitle,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                l10n.searchStartBody,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.55,
                ),
              ),
            ),
          ),
        ] else
          Column(
            key: const Key('search-history-section'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.searchHistoryTitle,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    key: const Key('search-history-clear'),
                    tooltip: l10n.searchHistoryClear,
                    onPressed: _clearHistory,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final query in _history)
                    _SearchHistoryChip(
                      key: Key('search-history-$query'),
                      label: query,
                      onPressed: () => _useHistory(query),
                    ),
                ],
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildError(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _SearchMessage(
      key: const Key('search-error-state'),
      icon: Icons.cloud_off_rounded,
      title: l10n.searchLoadErrorTitle,
      body: l10n.searchLoadErrorBody,
      action: FilledButton.tonalIcon(
        onPressed: _runSearch,
        icon: const Icon(Icons.refresh_rounded),
        label: Text(l10n.retry),
      ),
    );
  }

  Widget _buildResults(BuildContext context, DiarySearchResult result) {
    final l10n = AppLocalizations.of(context);
    final expanded = _expandedKeywordLabel(result);
    final hasAnyResult =
        result.entries.isNotEmpty || _archiveMatches.isNotEmpty;
    return ListView(
      key: const Key('search-results-list'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.searchResultsCount(result.total),
                key: const Key('search-result-count'),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (_hasFilters)
              Icon(
                Icons.filter_alt_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
          ],
        ),
        if (expanded != null) ...[
          const SizedBox(height: 12),
          _ExpansionNote(label: l10n.searchExpandedKeywords(expanded)),
        ],
        if (_archiveMatches.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.searchRelatedArchives,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 104,
            child: ListView.separated(
              key: const Key('search-archive-results'),
              scrollDirection: Axis.horizontal,
              itemCount: _archiveMatches.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final archive = _archiveMatches[index];
                return _ArchiveSearchCard(
                  archive: archive,
                  onTap: () => _openArchive(archive.id),
                );
              },
            ),
          ),
        ],
        if (!hasAnyResult)
          Padding(
            padding: const EdgeInsets.only(top: 56),
            child: _SearchMessage(
              key: const Key('search-empty-state'),
              icon: Icons.auto_awesome_rounded,
              title: l10n.searchNoResultsTitle,
              body: l10n.searchNoResultsBody,
            ),
          )
        else if (result.entries.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.lg),
            child: Text(
              l10n.searchNoResultsBody,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else ...[
          const SizedBox(height: AppSpacing.lg),
          for (var index = 0; index < result.entries.length; index++) ...[
            _DiarySearchCard(
              entry: result.entries[index],
              keywords: result.highlightKeywords,
              onTap: () => _openEntry(result.entries[index].id),
            ),
            if (index != result.entries.length - 1) const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }

  String? _expandedKeywordLabel(DiarySearchResult result) {
    final rawKeywords = _queryController.text
        .trim()
        .split(RegExp(r'\s+'))
        .map((keyword) => keyword.toLowerCase())
        .toSet();
    final expanded = result.expandedKeywords
        .where((keyword) => !rawKeywords.contains(keyword.toLowerCase()))
        .take(6)
        .toList(growable: false);
    return expanded.isEmpty ? null : expanded.join(' · ');
  }
}

class _DateRangeSelection {
  const _DateRangeSelection(this.range);

  final DateTimeRange? range;
}

class _SearchDateRangeSheet extends StatefulWidget {
  const _SearchDateRangeSheet({
    required this.firstDay,
    required this.lastDay,
    this.initialRange,
  });

  final DateTime firstDay;
  final DateTime lastDay;
  final DateTimeRange? initialRange;

  @override
  State<_SearchDateRangeSheet> createState() => _SearchDateRangeSheetState();
}

class _SearchDateRangeSheetState extends State<_SearchDateRangeSheet> {
  late DateTime _focusedDay;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  @override
  void initState() {
    super.initState();
    _rangeStart = widget.initialRange == null
        ? null
        : DateUtils.dateOnly(widget.initialRange!.start);
    _rangeEnd = widget.initialRange == null
        ? null
        : DateUtils.dateOnly(widget.initialRange!.end);
    final today = DateUtils.dateOnly(DateTime.now());
    _focusedDay = _rangeStart ?? today;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final bodyStyle = theme.textTheme.bodyMedium ?? const TextStyle();
    final labelStyle = theme.textTheme.labelMedium ?? const TextStyle();
    final dayDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(10),
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              key: const Key('search-date-range-sheet'),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.searchSelectDateRange,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.searchDateRangeHint,
                  style: bodyStyle.copyWith(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 10),
                TableCalendar<void>(
                  key: const Key('search-date-range-calendar'),
                  locale: locale,
                  firstDay: widget.firstDay,
                  lastDay: widget.lastDay,
                  focusedDay: _focusedDay,
                  currentDay: DateUtils.dateOnly(DateTime.now()),
                  rangeStartDay: _rangeStart,
                  rangeEndDay: _rangeEnd,
                  rangeSelectionMode: RangeSelectionMode.toggledOn,
                  availableCalendarFormats: const {
                    CalendarFormat.month: 'Month',
                  },
                  calendarFormat: CalendarFormat.month,
                  rowHeight: 40,
                  daysOfWeekHeight: 28,
                  startingDayOfWeek: StartingDayOfWeek.sunday,
                  availableGestures: AvailableGestures.horizontalSwipe,
                  headerStyle: HeaderStyle(
                    titleCentered: true,
                    formatButtonVisible: false,
                    leftChevronIcon: Icon(
                      Icons.chevron_left_rounded,
                      color: colors.onSurface,
                    ),
                    rightChevronIcon: Icon(
                      Icons.chevron_right_rounded,
                      color: colors.onSurface,
                    ),
                    titleTextStyle:
                        theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ) ??
                        const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  daysOfWeekStyle: DaysOfWeekStyle(
                    weekdayStyle: labelStyle.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                    weekendStyle: labelStyle.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  calendarStyle: CalendarStyle(
                    outsideDaysVisible: false,
                    cellMargin: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 1,
                    ),
                    defaultTextStyle: bodyStyle,
                    weekendTextStyle: bodyStyle,
                    defaultDecoration: dayDecoration,
                    weekendDecoration: dayDecoration,
                    selectedDecoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    selectedTextStyle: bodyStyle.copyWith(
                      color: colors.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    todayDecoration: BoxDecoration(
                      color: colors.secondaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    todayTextStyle: bodyStyle.copyWith(
                      color: colors.onSecondaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                    rangeHighlightColor: colors.primaryContainer.withValues(
                      alpha: 0.72,
                    ),
                    rangeStartDecoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    rangeEndDecoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    rangeStartTextStyle: bodyStyle.copyWith(
                      color: colors.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    rangeEndTextStyle: bodyStyle.copyWith(
                      color: colors.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    withinRangeTextStyle: bodyStyle.copyWith(
                      color: colors.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                    withinRangeDecoration: dayDecoration,
                  ),
                  onRangeSelected: (start, end, focusedDay) {
                    setState(() {
                      _rangeStart = start == null
                          ? null
                          : DateUtils.dateOnly(start);
                      _rangeEnd = end == null ? null : DateUtils.dateOnly(end);
                      _focusedDay = DateUtils.dateOnly(focusedDay);
                    });
                  },
                  onPageChanged: (focusedDay) {
                    setState(() {
                      _focusedDay = DateUtils.dateOnly(focusedDay);
                    });
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    TextButton(
                      key: const Key('search-date-clear'),
                      onPressed: _rangeStart == null && _rangeEnd == null
                          ? null
                          : () => Navigator.of(
                              context,
                            ).pop(const _DateRangeSelection(null)),
                      child: Text(l10n.searchDateClear),
                    ),
                    const Spacer(),
                    TextButton(
                      key: const Key('search-date-cancel'),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.cancel),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    FilledButton(
                      key: const Key('search-date-apply'),
                      onPressed: _rangeStart == null
                          ? null
                          : () {
                              final start = _rangeStart!;
                              final end = _rangeEnd ?? start;
                              Navigator.of(context).pop(
                                _DateRangeSelection(
                                  DateTimeRange(start: start, end: end),
                                ),
                              );
                            },
                      child: Text(l10n.searchDateApply),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchLensMark extends StatelessWidget {
  const _SearchLensMark();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Icon(
      Icons.search_rounded,
      key: const Key('search-start-icon'),
      size: 40,
      color: colors.primary,
    );
  }
}

class _SearchHistoryChip extends StatelessWidget {
  const _SearchHistoryChip({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}

class _ExpansionNote extends StatelessWidget {
  const _ExpansionNote({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.hub_rounded, size: 18, color: colors.onSecondaryContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSecondaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchiveSearchCard extends StatelessWidget {
  const _ArchiveSearchCard({required this.archive, required this.onTap});

  final Archive archive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final aliases = archive.aliases.take(2).join(' · ');
    return SizedBox(
      width: 178,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('search-archive-${archive.id}'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: colors.tertiaryContainer,
                  foregroundColor: colors.onTertiaryContainer,
                  child: Icon(
                    archive.type == ArchiveType.person
                        ? Icons.person_outline_rounded
                        : Icons.inventory_2_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        archive.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (aliases.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          aliases,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ],
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

class _DiarySearchCard extends StatelessWidget {
  const _DiarySearchCard({
    required this.entry,
    required this.keywords,
    required this.onTap,
  });

  final DiaryEntry entry;
  final List<SearchHighlightKeyword> keywords;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final title = entry.title.trim().isEmpty
        ? l10n.searchUntitledDiary
        : entry.title;
    final snippet = _extractSnippet(entry.plainContent, keywords);
    return Card(
      key: Key('search-entry-${entry.id}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      DateFormat.yMMMd(locale).format(entry.createdAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _moodEmoji(entry.mood),
                    semanticsLabel: _moodLabel(l10n, entry.mood),
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 19,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SearchHighlightedText(
                text: title,
                keywords: keywords,
                maxLines: 2,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (snippet.isEmpty)
                Text(
                  l10n.searchEmptyEntry,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else
                SearchHighlightedText(
                  text: snippet,
                  keywords: keywords,
                  maxLines: 3,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class SearchHighlightedText extends StatelessWidget {
  const SearchHighlightedText({
    required this.text,
    required this.keywords,
    this.style,
    this.maxLines,
    super.key,
  });

  final String text;
  final List<SearchHighlightKeyword> keywords;
  final TextStyle? style;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    final highlightStyle = baseStyle.copyWith(
      color: colors.onSecondaryContainer,
      backgroundColor: colors.secondaryContainer,
      fontWeight: FontWeight.w800,
    );
    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: _highlightSpans(text, keywords, baseStyle, highlightStyle),
      ),
      maxLines: maxLines,
      overflow: maxLines == null ? TextOverflow.clip : TextOverflow.ellipsis,
    );
  }
}

class _SearchMessage extends StatelessWidget {
  const _SearchMessage({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: colors.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: colors.onSecondaryContainer),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                body,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              if (action case final action?) ...[
                const SizedBox(height: AppSpacing.lg),
                action,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _moodEmoji(String mood) {
  return switch (mood) {
    'happy' => '😊',
    'excited' => '🤩',
    'calm' => '😌',
    'tired' => '😴',
    'sad' => '😔',
    _ => '•',
  };
}

String _moodLabel(AppLocalizations l10n, String mood) {
  return switch (mood) {
    'happy' => l10n.editorMoodHappy,
    'excited' => l10n.editorMoodExcited,
    'calm' => l10n.editorMoodCalm,
    'tired' => l10n.editorMoodTired,
    'sad' => l10n.editorMoodSad,
    _ => l10n.searchMoodFilter,
  };
}

String _formatDateRange(DateTimeRange range, String locale) {
  final formatter = DateFormat.MMMd(locale);
  final start = formatter.format(range.start);
  final end = formatter.format(range.end);
  return start == end ? start : '$start – $end';
}

String _extractSnippet(String text, List<SearchHighlightKeyword> keywords) {
  final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.isEmpty) return '';
  final match = _findNextMatch(normalized, keywords, 0);
  if (match == null) {
    return normalized.length <= 132
        ? normalized
        : '${normalized.substring(0, 132).trimRight()}…';
  }
  final start = (match.start - 44).clamp(0, normalized.length);
  final end = (match.end + 76).clamp(0, normalized.length);
  return '${start > 0 ? '…' : ''}'
      '${normalized.substring(start, end).trim()}'
      '${end < normalized.length ? '…' : ''}';
}

List<InlineSpan> _highlightSpans(
  String text,
  List<SearchHighlightKeyword> keywords,
  TextStyle baseStyle,
  TextStyle highlightStyle,
) {
  if (text.isEmpty || keywords.isEmpty) return [TextSpan(text: text)];
  final spans = <InlineSpan>[];
  var cursor = 0;
  while (cursor < text.length) {
    final match = _findNextMatch(text, keywords, cursor);
    if (match == null) {
      spans.add(TextSpan(text: text.substring(cursor), style: baseStyle));
      break;
    }
    if (match.start > cursor) {
      spans.add(
        TextSpan(text: text.substring(cursor, match.start), style: baseStyle),
      );
    }
    spans.add(
      TextSpan(
        text: text.substring(match.start, match.end),
        style: highlightStyle,
      ),
    );
    cursor = match.end;
  }
  return spans;
}

_TextMatch? _findNextMatch(
  String text,
  List<SearchHighlightKeyword> keywords,
  int start,
) {
  final normalizedText = text.toLowerCase();
  _TextMatch? best;
  final sortedKeywords =
      keywords
          .where((keyword) => keyword.value.isNotEmpty)
          .toList(growable: false)
        ..sort((a, b) => b.value.length.compareTo(a.value.length));
  for (final keyword in sortedKeywords) {
    final normalizedKeyword = keyword.value.toLowerCase();
    var index = normalizedText.indexOf(normalizedKeyword, start);
    while (index != -1 &&
        keyword.standalone &&
        !_hasStandaloneBoundaries(
          normalizedText,
          index,
          index + normalizedKeyword.length,
        )) {
      index = normalizedText.indexOf(normalizedKeyword, index + 1);
    }
    if (index == -1) continue;
    final candidate = _TextMatch(index, index + normalizedKeyword.length);
    if (best == null ||
        candidate.start < best.start ||
        (candidate.start == best.start && candidate.end > best.end)) {
      best = candidate;
    }
  }
  return best;
}

bool _hasStandaloneBoundaries(String text, int start, int end) {
  final previous = _runeBefore(text, start);
  final next = _runeAfter(text, end);
  return !_isWordLike(previous) && !_isWordLike(next);
}

String? _runeBefore(String text, int index) {
  if (index <= 0) return null;
  var start = index - 1;
  if (start > 0 &&
      _isLowSurrogate(text.codeUnitAt(start)) &&
      _isHighSurrogate(text.codeUnitAt(start - 1))) {
    start--;
  }
  return text.substring(start, index);
}

String? _runeAfter(String text, int index) {
  if (index >= text.length) return null;
  var end = index + 1;
  if (_isHighSurrogate(text.codeUnitAt(index)) &&
      end < text.length &&
      _isLowSurrogate(text.codeUnitAt(end))) {
    end++;
  }
  return text.substring(index, end);
}

bool _isHighSurrogate(int codeUnit) => codeUnit >= 0xD800 && codeUnit <= 0xDBFF;

bool _isLowSurrogate(int codeUnit) => codeUnit >= 0xDC00 && codeUnit <= 0xDFFF;

final RegExp _wordLikeCharacter = RegExp(r'^[\p{L}\p{N}]$', unicode: true);

bool _isWordLike(String? character) {
  return character != null && _wordLikeCharacter.hasMatch(character);
}

class _TextMatch {
  const _TextMatch(this.start, this.end);

  final int start;
  final int end;
}
