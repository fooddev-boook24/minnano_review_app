import 'package:go_router/go_router.dart';

import '../../features/home/home_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/explore/explore_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/app_detail/app_detail_screen.dart';
import '../../features/share_card/share_card_screen.dart';
import '../../shared/widgets/main_shell.dart';

final router = GoRouter(
  initialLocation: '/home',
  routes: [
    ShellRoute(
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(
          path: '/home',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: HomeScreen()),
        ),
        GoRoute(
          path: '/explore',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ExploreScreen()),
        ),
        GoRoute(
          path: '/search',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: SearchScreen()),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: SettingsScreen()),
        ),
        GoRoute(
          path: '/app/:trackId',
          builder: (context, state) {
            final trackId = state.pathParameters['trackId']!;
            return AppDetailScreen(trackId: trackId);
          },
        ),
        GoRoute(
          path: '/app/:trackId/share',
          builder: (context, state) {
            final trackId = state.pathParameters['trackId']!;
            return ShareCardScreen(trackId: trackId);
          },
        ),
      ],
    ),
  ],
);
