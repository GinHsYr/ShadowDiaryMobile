import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/media/media_library.dart';
import '../features/archives/archive_editor_page.dart';
import '../features/archives/archives_page.dart';
import '../features/editor/editor_page.dart';
import '../features/home/home_page.dart';
import '../features/media/media_page.dart';
import '../features/search/search_page.dart';
import '../features/settings/settings_page.dart';
import 'radial_reveal_transition.dart';
import 'shell.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const archives = '/archives';
  static const media = '/media';
  static const settings = '/settings';
  static const search = '/search';
  static const newEntry = '/entries/new';
  static const newArchive = '/archives/new';

  static String newEntryForDate(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    return Uri(
      path: newEntry,
      queryParameters: {'date': dateOnly.toIso8601String()},
    ).toString();
  }

  static String editEntry(String id, {String? imageSource, int? imageIndex}) {
    return _locationWithQuery('/entries/${Uri.encodeComponent(id)}/edit', {
      'image': ?imageSource,
      'imageIndex': ?imageIndex?.toString(),
    });
  }

  static String editArchive(String id, {String? imagePath}) {
    return _locationWithQuery('/archives/${Uri.encodeComponent(id)}/edit', {
      'image': ?imagePath,
    });
  }

  static String _locationWithQuery(
    String path,
    Map<String, String> queryParameters,
  ) {
    if (queryParameters.isEmpty) return path;
    return '$path?${Uri(queryParameters: queryParameters).query}';
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => HomePage(
                  onSearchRequested: (origin) {
                    context.push(AppRoutes.search, extra: origin);
                  },
                  onCalendarDateSelected: (date) {
                    context.push(AppRoutes.newEntryForDate(date));
                  },
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.archives,
                builder: (context, state) => ArchivesPage(
                  onAddArchive: () =>
                      context.push<Object?>(AppRoutes.newArchive),
                  onEditArchive: (archiveId) =>
                      context.push<Object?>(AppRoutes.editArchive(archiveId)),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.media,
                builder: (context, state) => MediaPage(
                  onOpenSource: (item) {
                    final location = switch (item.sourceType) {
                      MediaSourceType.diary => AppRoutes.editEntry(
                        item.sourceId,
                        imageSource: item.imageSource,
                        imageIndex: item.sourceImageIndex,
                      ),
                      MediaSourceType.archive => AppRoutes.editArchive(
                        item.sourceId,
                        imagePath: item.imageSource,
                      ),
                    };
                    return context.push<Object?>(location);
                  },
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                builder: (context, state) => const SettingsPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.search,
        pageBuilder: (context, state) {
          final size = MediaQuery.sizeOf(context);
          final padding = MediaQuery.paddingOf(context);
          final origin = state.extra is Offset
              ? state.extra! as Offset
              : Offset(size.width - 40, padding.top + 40);
          return CustomTransitionPage<void>(
            key: state.pageKey,
            transitionDuration: const Duration(milliseconds: 760),
            reverseTransitionDuration: const Duration(milliseconds: 420),
            child: SearchPage(
              onClose: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(AppRoutes.home);
                }
              },
              onOpenEntry: (entryId) {
                context.push(AppRoutes.editEntry(entryId));
              },
              onOpenArchive: (archiveId) {
                context.push(AppRoutes.editArchive(archiveId));
              },
            ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return RadialRevealTransition(
                    key: const Key('search-radial-reveal'),
                    animation: animation,
                    origin: origin,
                    child: child,
                  );
                },
          );
        },
      ),
      GoRoute(
        path: AppRoutes.newEntry,
        builder: (context, state) {
          final date = DateTime.tryParse(
            state.uri.queryParameters['date'] ?? '',
          );
          return EditorPage(initialDate: date);
        },
      ),
      GoRoute(
        path: '/entries/:id/edit',
        builder: (context, state) {
          return EditorPage(
            entryId: state.pathParameters['id'],
            initialImageSource: state.uri.queryParameters['image'],
            initialImageIndex: int.tryParse(
              state.uri.queryParameters['imageIndex'] ?? '',
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.newArchive,
        pageBuilder: (context, state) {
          return _archiveEditorPage(
            state: state,
            child: const ArchiveEditorPage(),
          );
        },
      ),
      GoRoute(
        path: '/archives/:id/edit',
        pageBuilder: (context, state) {
          return _archiveEditorPage(
            state: state,
            child: ArchiveEditorPage(
              archiveId: state.pathParameters['id'],
              initialImagePath: state.uri.queryParameters['image'],
            ),
          );
        },
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

CustomTransitionPage<void> _archiveEditorPage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.disableAnimationsOf(context)) return child;
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.035),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
