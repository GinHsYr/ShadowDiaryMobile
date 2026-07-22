import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/archives/archive_editor_page.dart';
import '../features/archives/archives_page.dart';
import '../features/editor/editor_page.dart';
import '../features/home/home_page.dart';
import '../features/media/media_page.dart';
import '../features/settings/settings_page.dart';
import 'shell.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const archives = '/archives';
  static const media = '/media';
  static const settings = '/settings';
  static const newEntry = '/entries/new';
  static const newArchive = '/archives/new';

  static String newEntryForDate(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    return Uri(
      path: newEntry,
      queryParameters: {'date': dateOnly.toIso8601String()},
    ).toString();
  }

  static String editEntry(String id) => '/entries/$id/edit';

  static String editArchive(String id) {
    return '/archives/${Uri.encodeComponent(id)}/edit';
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
                builder: (context, state) => const MediaPage(),
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
          return EditorPage(entryId: state.pathParameters['id']);
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
            child: ArchiveEditorPage(archiveId: state.pathParameters['id']),
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
