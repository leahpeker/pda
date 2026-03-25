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

    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(2));

    // Email field should have email autofill hint
    final emailField = tester.widget<TextField>(textFields.at(0));
    expect(emailField.autofillHints, contains(AutofillHints.email));

    // Password field should have password autofill hint
    final passwordField = tester.widget<TextField>(textFields.at(1));
    expect(passwordField.autofillHints, contains(AutofillHints.password));

    // Fields should be wrapped in an AutofillGroup
    expect(find.byType(AutofillGroup), findsOneWidget);
  });

  testWidgets('email field shows error for value without @', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    final emailField = find.byType(TextFormField).first;
    await tester.enterText(emailField, 'notanemail');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    expect(find.text('Enter a valid email'), findsOneWidget);
  });
}

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<User?> build() async => null;

  @override
  Future<void> login(String email, String password) async {}

  @override
  Future<void> logout() async {}
}
