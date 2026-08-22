import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_info.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page.dart';
import '../../l10n/app_localizations.dart';

typedef AboutUrlLauncher = Future<bool> Function(Uri url);

Future<bool> launchAboutUrl(Uri url) {
  return launchUrl(url, mode: LaunchMode.externalApplication);
}

class AboutPage extends StatelessWidget {
  const AboutPage({this.urlLauncher, super.key});

  static const appVersion = AppInfo.version;
  static const author = 'GinHsYr';
  static const authorUrl = 'https://github.com/GinHsYr';
  static const openSourceUrl = 'https://github.com/GinHsYr/ShadowDiaryMobile';

  final AboutUrlLauncher? urlLauncher;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      key: const Key('about-page'),
      appBar: AppBar(title: Text(l10n.about)),
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
              ),
              sliver: SliverToBoxAdapter(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppPage.maxContentWidth,
                    ),
                    child: Column(
                      children: [
                        Semantics(
                          label: l10n.aboutSoftwareIcon,
                          child: SmoothClipRRect(
                            key: const Key('about-app-icon'),
                            smoothness: cornerSmoothing,
                            borderRadius: BorderRadius.circular(24),
                            child: Image.asset(
                              'resources/icon.png',
                              width: 112,
                              height: 112,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          l10n.appName,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '${l10n.aboutVersion}: $appVersion',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Column(
                              children: [
                                _AboutInfoRow(
                                  key: const Key('about-author-link'),
                                  icon: Icons.person_outline_rounded,
                                  label: l10n.aboutAuthor,
                                  value: Text(
                                    author,
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                  onTap: () => _openUrl(Uri.parse(authorUrl)),
                                ),
                                const Divider(height: AppSpacing.lg),
                                _AboutInfoRow(
                                  key: const Key('about-repository-link'),
                                  icon: Icons.code_rounded,
                                  label: l10n.aboutOpenSource,
                                  value: Text(
                                    openSourceUrl,
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                  onTap: () =>
                                      _openUrl(Uri.parse(openSourceUrl)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openUrl(Uri url) {
    final launcher = urlLauncher ?? launchAboutUrl;
    unawaited(launcher(url).catchError((_) => false));
  }
}

class _AboutInfoRow extends StatelessWidget {
  const _AboutInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final Widget value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      link: onTap != null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: smoothRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: colors.primary),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: theme.textTheme.labelLarge),
                      const SizedBox(height: AppSpacing.xs),
                      DefaultTextStyle(
                        style: theme.textTheme.bodyMedium!.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                        child: value,
                      ),
                    ],
                  ),
                ),
                if (onTap != null)
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.sm),
                    child: Icon(
                      Icons.open_in_new_rounded,
                      size: 18,
                      color: colors.onSurfaceVariant,
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
