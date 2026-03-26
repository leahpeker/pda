import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pda/models/user.dart';
import 'package:pda/providers/auth_provider.dart';
import 'package:pda/screens/auth/login_screen.dart';

void main() {
  Widget buildSubject() {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/calendar', builder: (_, __) => const SizedBox()),
        GoRoute(path: '/login', builder: (_, __) => const SizedBox()),
      ],
    );
    return ProviderScope(
      overrides: [authProvider.overrideWith(() => _FakeAuthNotifier())],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('login form has autofill hints for password manager support', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    // Password field should have password autofill hint
    final textFields = find.byType(TextField);
    final passwordField = tester.widget<TextField>(textFields.last);
    expect(passwordField.autofillHints, contains(AutofillHints.password));

    // Fields should be wrapped in an AutofillGroup
    expect(find.byType(AutofillGroup), findsOneWidget);
  });

  testWidgets('phone field shows error when empty', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    // Tap login without entering phone number
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    expect(find.text('Required'), findsWidgets);
  });
}

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<User?> build() async => null;

  @override
  Future<void> login(String phoneNumber, String password) async {}

  @override
  Future<void> logout() async {}
}
