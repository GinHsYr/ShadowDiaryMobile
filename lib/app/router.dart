import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

  static String editEntry(String id) => '/entries/$id/edit';
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
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.archives,
                builder: (context, state) => const ArchivesPage(),
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
        builder: (context, state) => const EditorPage(),
      ),
      GoRoute(
        path: '/entries/:id/edit',
        builder: (context, state) {
          return EditorPage(entryId: state.pathParameters['id']);
        },
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
