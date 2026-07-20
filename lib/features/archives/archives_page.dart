import 'package:flutter/material.dart';

import '../../core/widgets/app_page.dart';
import '../../l10n/app_localizations.dart';

class ArchivesPage extends StatelessWidget {
  const ArchivesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppPage(
      child: EmptyStateCard(
        icon: Icons.folder_open_rounded,
        title: l10n.archivesEmptyTitle,
        body: l10n.archivesEmptyBody,
      ),
    );
  }
}
