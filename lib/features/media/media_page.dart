import 'package:flutter/material.dart';

import '../../core/widgets/app_page.dart';
import '../../l10n/app_localizations.dart';

class MediaPage extends StatelessWidget {
  const MediaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppPage(
      child: EmptyStateCard(
        icon: Icons.photo_library_outlined,
        title: l10n.mediaEmptyTitle,
        body: l10n.mediaEmptyBody,
      ),
    );
  }
}
