import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pda/models/user.dart';
import 'package:pda/providers/auth_provider.dart';
import 'package:pda/providers/join_request_provider.dart';
import 'package:pda/screens/join_screen.dart';
import 'package:pda/services/api_error.dart';

// Join form is long — use a tall viewport so the submit button is reachable.
const _kTestSize = Size(700, 1200);

Widget _buildSubject({JoinRequestNotifier? notifier}) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, __) => const JoinScreen()),
      GoRoute(path: '/join', builder: (_, __) => const JoinScreen()),
      GoRoute(path: '/join/success', builder: (_, __) => const _SuccessPage()),
    ],
  );
  return ProviderScope(
    overrides: [
      joinRequestProvider.overrideWith(
        () => notifier ?? _FakeJoinRequestNotifier(),
      ),
      authProvider.overrideWith(() => _GuestAuthNotifier()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  setUp(() {});

  testWidgets('renders form fields', (tester) async {
    tester.view.physicalSize = _kTestSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildSubject());
    await tester.pump();

    expect(find.text('Request to join PDA'), findsOneWidget);
    expect(find.byType(TextFormField), findsWidgets);
    expect(find.text('Submit request'), findsOneWidget);
  });

  testWidgets('shows validation error when required fields are empty', (
    tester,
  ) async {
    tester.view.physicalSize = _kTestSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildSubject());
    await tester.pump();

    await tester.tap(find.text('Submit request'));
    await tester.pump();

    expect(find.textContaining('Required'), findsWidgets);
  });

  testWidgets('shows error message on submission failure', (tester) async {
    tester.view.physicalSize = _kTestSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildSubject(notifier: _ErrorJoinNotifier()));
    await tester.pump();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Display name *'),
      'Alex R',
    );
    // Enter a valid phone number in the phone field (first TextFormField after display name)
    final phoneField = find.byType(TextFormField).at(1);
    await tester.enterText(phoneField, '2025551234');
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Why do you want to join? *'),
      'I really love animals and want to be part of this community.',
    );

    await tester.tap(find.text('Submit request'));
    await tester.pump();

    // NetworkError.message = 'Could not connect to server. Check your internet connection.'
    expect(find.textContaining('Could not connect'), findsOneWidget);
  });

  testWidgets('navigates to /join/success on successful submission', (
    tester,
  ) async {
    tester.view.physicalSize = _kTestSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    bool landedOnSuccess = false;
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const JoinScreen()),
        GoRoute(path: '/join', builder: (_, __) => const JoinScreen()),
        GoRoute(
          path: '/join/success',
          builder: (_, __) {
            landedOnSuccess = true;
            return const _SuccessPage();
          },
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          joinRequestProvider.overrideWith(() => _FakeJoinRequestNotifier()),
          authProvider.overrideWith(() => _GuestAuthNotifier()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Display name *'),
      'Alex R',
    );
    // Enter a valid phone number
    final phoneField = find.byType(TextFormField).at(1);
    await tester.enterText(phoneField, '2025551234');
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Why do you want to join? *'),
      'I really love animals and want to be part of this community.',
    );

    await tester.tap(find.text('Submit request'));
    await tester.pumpAndSettle();

    expect(landedOnSuccess, isTrue);
  });
}

class _GuestAuthNotifier extends AuthNotifier {
  @override
  Future<User?> build() async => null;

  @override
  Future<void> logout() async {}
}

class _FakeJoinRequestNotifier extends JoinRequestNotifier {
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

class _ErrorJoinNotifier extends JoinRequestNotifier {
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
    state = AsyncError(const NetworkError(), StackTrace.current);
  }
}

class _SuccessPage extends StatelessWidget {
  const _SuccessPage();

  @override
  Widget build(BuildContext context) => const Text('Success!');
}
