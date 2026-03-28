import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pda/models/user.dart';
import 'package:pda/providers/auth_provider.dart';
import 'package:pda/providers/join_request_provider.dart';
import 'package:pda/screens/join_screen.dart';
import 'package:pda/screens/join_success_screen.dart';

Widget _buildApp() {
  final router = GoRouter(
    initialLocation: '/join',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const Text('Home')),
      GoRoute(path: '/join', builder: (_, __) => const JoinScreen()),
      GoRoute(
        path: '/join/success',
        builder: (_, __) => const JoinSuccessScreen(),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      joinRequestProvider.overrideWith(() => _InstantSuccessJoinNotifier()),
      authProvider.overrideWith(() => _GuestAuthNotifier()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('filling form and submitting navigates to /join/success', (
    tester,
  ) async {
    // Tall viewport so the submit button is reachable.
    tester.view.physicalSize = const Size(700, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildApp());
    await tester.pump();

    // Fill required fields
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Display name *'),
      'Alex R',
    );
    // Phone field (second TextFormField)
    final phoneField = find.byType(TextFormField).at(1);
    await tester.enterText(phoneField, '2025551234');
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Why do you want to join? *'),
      'I really love animals and want to be part of this community.',
    );

    await tester.tap(find.text('Submit request'));
    await tester.pumpAndSettle();

    // Should now be on success screen
    expect(find.byType(JoinSuccessScreen), findsOneWidget);
  });
}

class _GuestAuthNotifier extends AuthNotifier {
  @override
  Future<User?> build() async => null;

  @override
  Future<void> logout() async {}
}

class _InstantSuccessJoinNotifier extends JoinRequestNotifier {
  @override
  Future<void> build() async {}

  @override
  Future<void> submit({
    required String displayName,
    required String phoneNumber,
    String email = '',
    required String pronouns,
    required String howTheyHeard,
    required String whyJoin,
  }) async {
    state = const AsyncData(null);
  }
}
