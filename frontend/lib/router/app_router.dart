import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pda/providers/auth_provider.dart';
import 'package:pda/screens/auth/login_screen.dart';
import 'package:pda/screens/calendar_screen.dart';
import 'package:pda/screens/event_management_screen.dart';
import 'package:pda/screens/home_screen.dart';
import 'package:pda/screens/join_requests_screen.dart';
import 'package:pda/screens/join_screen.dart';
import 'package:pda/screens/join_success_screen.dart';
import 'package:pda/screens/members_screen.dart';
import 'package:pda/screens/guidelines_screen.dart';
import 'package:pda/screens/event_detail_screen.dart';
import 'package:pda/screens/donate_screen.dart';
import 'package:pda/screens/settings_screen.dart';
import 'package:pda/screens/volunteer_screen.dart';

// Use NoTransitionPage on web so the browser's native back/forward swipe
// gesture doesn't conflict with a Flutter slide animation.
Page<void> _page(Widget child) =>
    kIsWeb ? NoTransitionPage(child: child) : MaterialPage(child: child);

final routerProvider = Provider<GoRouter>((ref) {
  // Use ref.listen (not ref.watch) so auth state changes trigger redirect
  // re-evaluation without recreating the entire GoRouter instance.
  final refreshNotifier = ValueNotifier<int>(0);
  ref.listen(authProvider, (_, __) {
    refreshNotifier.value++;
  });
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final user = authState.valueOrNull;
      final isAuthenticated = user != null;
      final isLoading = authState.isLoading;

      if (isLoading) return null;

      final loc = state.matchedLocation;
      final isProtected =
          loc == '/calendar' ||
          loc == '/guidelines' ||
          loc == '/members' ||
          loc == '/join-requests' ||
          loc == '/events/manage' ||
          loc == '/events/mine' ||
          loc == '/settings' ||
          loc == '/volunteer';

      if (isProtected && !isAuthenticated) {
        return '/login?redirect=${state.matchedLocation}';
      }

      if (isAuthenticated) {
        if (loc == '/members' && !user.hasPermission('manage_users')) {
          return '/calendar';
        }
        if (loc == '/join-requests' &&
            !user.hasPermission('approve_join_requests')) {
          return '/calendar';
        }
        if (loc == '/events/manage' && !user.hasPermission('manage_events')) {
          return '/calendar';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        pageBuilder: (_, __) => _page(const HomeScreen()),
      ),
      GoRoute(
        path: '/join',
        name: 'join',
        pageBuilder: (_, __) => _page(const JoinScreen()),
      ),
      GoRoute(
        path: '/join/success',
        name: 'join-success',
        pageBuilder: (_, __) => _page(const JoinSuccessScreen()),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        pageBuilder: (_, __) => _page(const LoginScreen()),
      ),
      GoRoute(
        path: '/calendar',
        name: 'calendar',
        pageBuilder: (_, __) => _page(const CalendarScreen()),
      ),
      GoRoute(
        path: '/members',
        name: 'members',
        pageBuilder: (_, __) => _page(const MembersScreen()),
      ),
      GoRoute(
        path: '/join-requests',
        name: 'join-requests',
        pageBuilder: (_, __) => _page(const JoinRequestsScreen()),
      ),
      GoRoute(
        path: '/events/mine',
        name: 'my-events',
        pageBuilder:
            (_, __) => _page(const EventManagementScreen(myEventsOnly: true)),
      ),
      GoRoute(
        path: '/events/manage',
        name: 'manage-events',
        pageBuilder: (_, __) => _page(const EventManagementScreen()),
      ),
      GoRoute(
        path: '/guidelines',
        name: 'guidelines',
        pageBuilder: (_, __) => _page(const GuidelinesScreen()),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        pageBuilder: (_, __) => _page(const SettingsScreen()),
      ),
      GoRoute(
        path: '/donate',
        name: 'donate',
        pageBuilder: (_, __) => _page(const DonateScreen()),
      ),
      GoRoute(
        path: '/volunteer',
        name: 'volunteer',
        pageBuilder: (_, __) => _page(const VolunteerScreen()),
      ),
      GoRoute(
        path: '/events/:id',
        name: 'event-detail',
        pageBuilder:
            (_, state) =>
                _page(EventDetailScreen(eventId: state.pathParameters['id']!)),
      ),
    ],
  );
});
