import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/archives/archive.dart';
import '../../core/archives/archive_repository.dart';
import '../../core/services/archive_image_service.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import 'archive_image_viewer.dart';

class ArchiveEditorPage extends ConsumerStatefulWidget {
  const ArchiveEditorPage({this.archiveId, super.key});

  final String? archiveId;

  @override
  ConsumerState<ArchiveEditorPage> createState() => _ArchiveEditorPageState();
}

class _ArchiveEditorPageState extends ConsumerState<ArchiveEditorPage> {
  static const maxImages = 20;
  static const _maxImagesPerSelection = 9;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _uuid = const Uuid();
  final List<String> _aliases = [];
  final List<String> _images = [];
  final Set<String> _newManagedPaths = {};

  late final ArchiveRepository _repository;
  late final ArchiveImageService _imageService;
  Archive? _original;
  ArchiveType _type = ArchiveType.person;
  String? _mainImage;
  String _baselineName = '';
  String _baselineDescription = '';
  List<String> _baselineAliases = const [];
  ArchiveType _baselineType = ArchiveType.person;
  String? _baselineMainImage;
  List<String> _baselineImages = const [];
  Object? _loadError;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isAddingImages = false;
  bool _allowPop = false;

  bool get _isNew => widget.archiveId == null;

  int get _imageCount => _images.length + (_mainImage == null ? 0 : 1);

  bool get _hasChanges {
    if (_isLoading || _loadError != null) return false;
    return _nameController.text != _baselineName ||
        _descriptionController.text != _baselineDescription ||
        _type != _baselineType ||
        _mainImage != _baselineMainImage ||
        !_sameList(_aliases, _baselineAliases) ||
        !_sameList(_images, _baselineImages);
  }

  @override
  void initState() {
    super.initState();
    _repository = ref.read(archiveRepositoryProvider);
    _imageService = ref.read(archiveImageServiceProvider);
    _nameController.addListener(_onTextChanged);
    _descriptionController.addListener(_onTextChanged);
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final archive = widget.archiveId == null
          ? null
          : await _repository.findById(widget.archiveId!);
      if (!mounted) return;
      if (widget.archiveId != null && archive == null) {
        setState(() {
          _loadError = StateError('Archive not found.');
          _isLoading = false;
        });
        return;
      }
      _original = archive;
      _nameController.text = archive?.name ?? '';
      _descriptionController.text = archive?.description ?? '';
      _aliases
        ..clear()
        ..addAll(archive?.aliases ?? const <String>[]);
      _type = archive?.type ?? ArchiveType.person;
      _mainImage = archive?.mainImage;
      _images
        ..clear()
        ..addAll(
          (archive?.images ?? const <String>[]).where(
            (path) => path != archive?.mainImage,
          ),
        );
      _captureBaseline();
      setState(() => _isLoading = false);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _isLoading = false;
      });
    }
  }

  void _captureBaseline() {
    _baselineName = _nameController.text;
    _baselineDescription = _descriptionController.text;
    _baselineAliases = List.unmodifiable(_aliases);
    _baselineType = _type;
    _baselineMainImage = _mainImage;
    _baselineImages = List.unmodifiable(_images);
  }

  void _onTextChanged() {
    if (mounted && !_isLoading) setState(() {});
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_onTextChanged)
      ..dispose();
    _descriptionController
      ..removeListener(_onTextChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_requestExit());
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _ArchiveEditorHeader(
                title: _isNew
                    ? l10n.archiveEditorNewTitle
                    : l10n.archiveEditorEditTitle,
                isSaving: _isSaving,
                onBack: _isSaving || _isAddingImages
                    ? null
                    : () => unawaited(_requestExit()),
                onSave:
                    _isLoading ||
                        _loadError != null ||
                        _isSaving ||
                        _isAddingImages
                    ? null
                    : () => unawaited(_save()),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: _motionDuration(context, 220),
                  child: _isLoading
                      ? const Center(
                          key: ValueKey('archive-editor-loading'),
                          child: CircularProgressIndicator(),
                        )
                      : _loadError != null
                      ? _ArchiveEditorError(
                          key: const ValueKey('archive-editor-error'),
                          onBack: () => unawaited(_pop()),
                        )
                      : _buildForm(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Form(
      key: _formKey,
      child: ListView(
        key: const ValueKey('archive-editor-form'),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        children: [
          _SectionLabel(label: l10n.archiveMainImage),
          const SizedBox(height: AppSpacing.sm),
          _MainImagePicker(
            imagePath: _mainImage,
            onPreview: _mainImage == null ? null : () => _previewMainImage(),
            onPick: _isSaving ? null : () => unawaited(_pickMainImage()),
            onRemove: _mainImage == null || _isSaving
                ? null
                : () => unawaited(_removeMainImage()),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            key: const Key('archive-name-field'),
            controller: _nameController,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: l10n.archiveName,
              hintText: l10n.archiveNameHint,
            ),
            validator: (value) {
              return value == null || value.trim().isEmpty
                  ? l10n.archiveNameRequired
                  : null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          _SectionLabel(label: l10n.archiveAlias),
          const SizedBox(height: AppSpacing.sm),
          _AliasTagsEditor(
            aliases: _aliases,
            enabled: !_isSaving,
            onAdd: _showAddAliasDialog,
            onDeleted: (index) => setState(() => _aliases.removeAt(index)),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionLabel(label: l10n.archiveType),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ArchiveType>(
              key: const Key('archive-type-selector'),
              segments: [
                ButtonSegment(
                  value: ArchiveType.person,
                  icon: const Icon(Icons.person_outline_rounded),
                  label: Text(l10n.archiveTypePerson),
                ),
                ButtonSegment(
                  value: ArchiveType.other,
                  icon: const Icon(Icons.category_outlined),
                  label: Text(l10n.archiveTypeOther),
                ),
              ],
              selected: {_type},
              onSelectionChanged: _isSaving
                  ? null
                  : (selection) => setState(() => _type = selection.single),
              showSelectedIcon: false,
              expandedInsets: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            key: const Key('archive-description-field'),
            controller: _descriptionController,
            minLines: 4,
            maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.archiveDescription,
              alignLabelWithHint: true,
              hintText: l10n.archiveDescriptionHint,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(child: _SectionLabel(label: l10n.archiveGallery)),
              Text(
                l10n.archiveImageCount(_imageCount, maxImages),
                key: const Key('archive-image-count'),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _ArchiveMasonryGallery(
            images: _images,
            showAddTile: _imageCount < maxImages,
            isAdding: _isAddingImages,
            onAdd: _isSaving ? null : () => unawaited(_addGalleryImages()),
            onPreview: _previewGalleryImage,
            onRemove: _isSaving
                ? null
                : (path) => unawaited(_removeGalleryImage(path)),
          ),
          if (!_isNew) ...[
            const SizedBox(height: AppSpacing.xl),
            Divider(color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              key: const Key('archive-editor-delete-button'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
                side: BorderSide(color: Theme.of(context).colorScheme.error),
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _isSaving ? null : () => unawaited(_deleteArchive()),
              icon: const Icon(Icons.delete_outline_rounded),
              label: Text(l10n.archiveDeleteAction),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showAddAliasDialog() async {
    final alias = await showDialog<String>(
      context: context,
      builder: (context) => _AddAliasDialog(existingAliases: _aliases),
    );
    if (!mounted || alias == null) return;
    setState(() => _aliases.add(alias));
  }

  Future<void> _pickMainImage() async {
    if (_mainImage == null && _imageCount >= maxImages) {
      _showImageLimit();
      return;
    }
    setState(() => _isAddingImages = true);
    try {
      final images = await _imageService.pickAndStore(maxImages: 1);
      if (images.isEmpty) return;
      if (!mounted) {
        await _imageService.deleteManagedImages(images);
        return;
      }
      final oldMainImage = _mainImage;
      final newMainImage = images.first;
      setState(() {
        _mainImage = newMainImage;
        _newManagedPaths.add(newMainImage);
      });
      if (oldMainImage != null && _newManagedPaths.remove(oldMainImage)) {
        await _imageService.deleteManagedImages([oldMainImage]);
      }
    } on Object {
      if (mounted) _showImageError();
    } finally {
      if (mounted) setState(() => _isAddingImages = false);
    }
  }

  Future<void> _removeMainImage() async {
    final path = _mainImage;
    if (path == null) return;
    setState(() => _mainImage = null);
    if (_newManagedPaths.remove(path)) {
      await _imageService.deleteManagedImages([path]);
    }
  }

  Future<void> _addGalleryImages() async {
    final remaining = maxImages - _imageCount;
    if (remaining <= 0) {
      _showImageLimit();
      return;
    }
    setState(() => _isAddingImages = true);
    try {
      final selected = await _imageService.pickAndStore(
        maxImages: remaining.clamp(1, _maxImagesPerSelection),
      );
      if (selected.isEmpty) return;
      if (!mounted) {
        await _imageService.deleteManagedImages(selected);
        return;
      }
      setState(() {
        _images.addAll(selected);
        _newManagedPaths.addAll(selected);
      });
    } on Object {
      if (mounted) _showImageError();
    } finally {
      if (mounted) setState(() => _isAddingImages = false);
    }
  }

  Future<void> _removeGalleryImage(String path) async {
    setState(() => _images.remove(path));
    if (_newManagedPaths.remove(path)) {
      await _imageService.deleteManagedImages([path]);
    }
  }

  void _previewMainImage() {
    final mainImage = _mainImage;
    if (mainImage == null) return;
    unawaited(
      showArchiveImageViewer(
        context,
        images: [mainImage, ..._images],
        initialIndex: 0,
      ),
    );
  }

  void _previewGalleryImage(int index) {
    final images = [?_mainImage, ..._images];
    final viewerIndex = index + (_mainImage == null ? 0 : 1);
    unawaited(
      showArchiveImageViewer(
        context,
        images: images,
        initialIndex: viewerIndex,
      ),
    );
  }

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_imageCount > maxImages) {
      _showImageLimit();
      return;
    }

    setState(() => _isSaving = true);
    final now = DateTime.now();
    final archive = Archive(
      id: _original?.id ?? _uuid.v4(),
      name: _nameController.text,
      alias: _aliases.join(','),
      description: _descriptionController.text,
      type: _type,
      mainImage: _mainImage,
      images: List.unmodifiable(_images),
      createdAt: _original?.createdAt ?? now,
      updatedAt: now,
    );
    try {
      await _repository.save(archive);
      final oldPaths = <String>{?_original?.mainImage, ...?_original?.images};
      final retainedPaths = <String>{?_mainImage, ..._images};
      await _imageService.deleteManagedImages(
        oldPaths.difference(retainedPaths),
      );
      _newManagedPaths.clear();
      ref.invalidate(archiveListProvider);
      if (!mounted) return;
      await _pop(true);
    } on Object {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).archiveSaveError)),
      );
    }
  }

  Future<void> _deleteArchive() async {
    final archive = _original;
    if (archive == null) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.archiveDeleteTitle),
        content: Text(l10n.archiveDeleteMessage(archive.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const Key('archive-editor-delete-confirm-button'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);
    try {
      await _repository.delete(archive.id);
      await _imageService.deleteManagedImages({
        ?archive.mainImage,
        ...archive.images,
        ..._newManagedPaths,
      });
      _newManagedPaths.clear();
      ref.invalidate(archiveListProvider);
      if (!mounted) return;
      await _pop(true);
    } on Object {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.archiveDeleteError)));
    }
  }

  Future<void> _requestExit() async {
    if (_allowPop) return;
    if (!_hasChanges) {
      await _pop();
      return;
    }
    final l10n = AppLocalizations.of(context);
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.archiveDiscardTitle),
        content: Text(l10n.archiveDiscardMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.archiveContinueEditing),
          ),
          FilledButton(
            key: const Key('archive-discard-confirm-button'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.archiveDiscardAction),
          ),
        ],
      ),
    );
    if (discard != true || !mounted) return;
    await _imageService.deleteManagedImages(_newManagedPaths);
    _newManagedPaths.clear();
    if (mounted) await _pop();
  }

  Future<void> _pop([Object? result]) async {
    if (!mounted) return;
    setState(() => _allowPop = true);
    // PopScope updates its route registration during the next build. Waiting
    // for that frame avoids a programmatic pop being vetoed by the previous
    // canPop=false value, especially on go_router custom pages.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      Navigator.of(context).pop(result);
    } else {
      router.pop(result);
    }
  }

  void _showImageLimit() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context).archiveImageLimit(maxImages),
        ),
      ),
    );
  }

  void _showImageError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).archiveImageAddError),
      ),
    );
  }
}

class _ArchiveEditorHeader extends StatelessWidget {
  const _ArchiveEditorHeader({
    required this.title,
    required this.isSaving,
    required this.onBack,
    required this.onSave,
  });

  final String title;
  final bool isSaving;
  final VoidCallback? onBack;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            key: const Key('archive-editor-back-button'),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          FilledButton.icon(
            key: const Key('archive-save-button'),
            onPressed: onSave,
            icon: isSaving
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(isSaving ? l10n.archiveSaving : l10n.save),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _AliasTagsEditor extends StatelessWidget {
  const _AliasTagsEditor({
    required this.aliases,
    required this.enabled,
    required this.onAdd,
    required this.onDeleted,
  });

  final List<String> aliases;
  final bool enabled;
  final VoidCallback onAdd;
  final ValueChanged<int> onDeleted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return Wrap(
      key: const Key('archive-alias-tags'),
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var index = 0; index < aliases.length; index++)
          InputChip(
            key: Key('archive-alias-chip-$index'),
            label: Text(aliases[index]),
            onDeleted: enabled ? () => onDeleted(index) : null,
            deleteIcon: Icon(
              Icons.close_rounded,
              key: Key('archive-alias-remove-$index'),
              size: 17,
            ),
            deleteButtonTooltipMessage: l10n.archiveRemoveAlias,
            side: BorderSide(color: colors.outlineVariant),
            backgroundColor: colors.surfaceContainerHigh,
            visualDensity: VisualDensity.compact,
          ),
        ActionChip(
          key: const Key('archive-alias-add-button'),
          avatar: const Icon(Icons.add_rounded, size: 18),
          label: Text(l10n.archiveAddAlias),
          onPressed: enabled ? onAdd : null,
          side: BorderSide(color: colors.outlineVariant),
          backgroundColor: Colors.transparent,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

class _AddAliasDialog extends StatefulWidget {
  const _AddAliasDialog({required this.existingAliases});

  final List<String> existingAliases;

  @override
  State<_AddAliasDialog> createState() => _AddAliasDialogState();
}

class _AddAliasDialogState extends State<_AddAliasDialog> {
  final _controller = TextEditingController();

  String get _normalizedAlias => _controller.text.trim();

  bool get _isDuplicate {
    final normalized = _normalizedAlias.toLowerCase();
    return normalized.isNotEmpty &&
        widget.existingAliases.any(
          (alias) => alias.trim().toLowerCase() == normalized,
        );
  }

  bool get _canSubmit => _normalizedAlias.isNotEmpty && !_isDuplicate;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.archiveAddAlias),
      content: TextField(
        key: const Key('archive-alias-dialog-field'),
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          hintText: l10n.archiveAliasHint,
          errorText: _isDuplicate ? l10n.archiveAliasDuplicate : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('archive-alias-dialog-confirm'),
          onPressed: _canSubmit ? _submit : null,
          child: Text(l10n.archiveAddAliasAction),
        ),
      ],
    );
  }

  void _submit() {
    if (!_canSubmit) return;
    Navigator.of(context).pop(_normalizedAlias);
  }
}

class _MainImagePicker extends StatelessWidget {
  const _MainImagePicker({
    required this.imagePath,
    required this.onPreview,
    required this.onPick,
    required this.onRemove,
  });

  final String? imagePath;
  final VoidCallback? onPreview;
  final VoidCallback? onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final placeholder = Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        shape: BoxShape.circle,
        border: Border.all(color: colors.outlineVariant),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 40,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.archiveChooseMainImage,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );

    return Center(
      child: SizedBox(
        width: 164,
        height: 164,
        child: Stack(
          children: [
            Positioned.fill(
              child: Material(
                key: const Key('archive-main-image-surface'),
                color: Colors.transparent,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: const Key('archive-main-image'),
                  onTap: imagePath == null ? onPick : onPreview,
                  child: imagePath == null
                      ? placeholder
                      : Hero(
                          tag: archiveImageHeroTag(imagePath!),
                          child: Image.file(
                            File(imagePath!),
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _MissingArchiveImage(
                                label: l10n.archiveImageMissing,
                              );
                            },
                          ),
                        ),
                ),
              ),
            ),
            if (imagePath != null)
              PositionedDirectional(
                end: 2,
                top: 18,
                child: _ImageOverlayButton(
                  key: const Key('archive-main-image-change'),
                  tooltip: l10n.archiveChangeMainImage,
                  icon: Icons.edit_rounded,
                  onPressed: onPick,
                ),
              ),
            if (imagePath != null)
              PositionedDirectional(
                end: 2,
                bottom: 18,
                child: _ImageOverlayButton(
                  key: const Key('archive-main-image-remove'),
                  tooltip: l10n.archiveRemoveImage,
                  icon: Icons.delete_outline_rounded,
                  onPressed: onRemove,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ArchiveMasonryGallery extends StatelessWidget {
  const _ArchiveMasonryGallery({
    required this.images,
    required this.showAddTile,
    required this.isAdding,
    required this.onAdd,
    required this.onPreview,
    required this.onRemove,
  });

  final List<String> images;
  final bool showAddTile;
  final bool isAdding;
  final VoidCallback? onAdd;
  final ValueChanged<int> onPreview;
  final ValueChanged<String>? onRemove;

  @override
  Widget build(BuildContext context) {
    final itemCount = images.length + (showAddTile ? 1 : 0);
    return MasonryGridView.count(
      key: const Key('archive-masonry-gallery'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == images.length) {
          return _GalleryAddTile(isAdding: isAdding, onPressed: onAdd);
        }
        final path = images[index];
        return _GalleryImageTile(
          key: Key('archive-gallery-image-$index'),
          index: index,
          path: path,
          onTap: () => onPreview(index),
          onRemove: onRemove == null ? null : () => onRemove!(path),
        );
      },
    );
  }
}

class _GalleryImageTile extends StatelessWidget {
  const _GalleryImageTile({
    required this.index,
    required this.path,
    required this.onTap,
    required this.onRemove,
    super.key,
  });

  final int index;
  final String path;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Stack(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: Key('archive-gallery-preview-$index'),
            onTap: onTap,
            child: Hero(
              tag: archiveImageHeroTag(path),
              child: Image.file(
                File(path),
                width: double.infinity,
                fit: BoxFit.fitWidth,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded || frame != null) return child;
                  return AspectRatio(
                    aspectRatio: 1,
                    child: ColoredBox(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return AspectRatio(
                    aspectRatio: 1,
                    child: _MissingArchiveImage(
                      label: l10n.archiveImageMissing,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        PositionedDirectional(
          end: 6,
          top: 6,
          child: _ImageOverlayButton(
            tooltip: l10n.archiveRemoveImage,
            icon: Icons.close_rounded,
            onPressed: onRemove,
          ),
        ),
      ],
    );
  }
}

class _GalleryAddTile extends StatelessWidget {
  const _GalleryAddTile({required this.isAdding, required this.onPressed});

  final bool isAdding;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 1,
      child: Material(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('archive-add-images-button'),
          onTap: isAdding ? null : onPressed,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isAdding)
                const SizedBox.square(
                  dimension: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              else
                Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 36,
                  color: colors.primary,
                ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.archiveAddImages,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageOverlayButton extends StatelessWidget {
  const _ImageOverlayButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size(36, 36),
        backgroundColor: Colors.black.withValues(alpha: 0.62),
        foregroundColor: Colors.white,
      ),
      iconSize: 19,
      icon: Icon(icon),
    );
  }
}

class _MissingArchiveImage extends StatelessWidget {
  const _MissingArchiveImage({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image_outlined, color: colors.onSurfaceVariant),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArchiveEditorError extends StatelessWidget {
  const _ArchiveEditorError({required this.onBack, super.key});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 44,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.archiveLoadError, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              onPressed: onBack,
              child: Text(MaterialLocalizations.of(context).backButtonTooltip),
            ),
          ],
        ),
      ),
    );
  }
}

bool _sameList(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

Duration _motionDuration(BuildContext context, int milliseconds) {
  return MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : Duration(milliseconds: milliseconds);
}
