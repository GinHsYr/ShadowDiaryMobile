import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page.dart';
import '../../l10n/app_localizations.dart';

class EditorPlaceholderPage extends StatelessWidget {
  const EditorPlaceholderPage({this.entryId, super.key});

  final String? entryId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = entryId == null ? l10n.editorNewTitle : l10n.editorEditTitle;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: EmptyStateCard(
            icon: Icons.edit_note_rounded,
            title: title,
            body: l10n.editorPlaceholder,
          ),
        ),
      ),
    );
  }
}
