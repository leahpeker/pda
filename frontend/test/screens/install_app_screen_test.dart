import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pda/models/user.dart';
import 'package:pda/providers/auth_provider.dart';
import 'package:pda/screens/install_app_screen.dart';

import '../helpers/provider_overrides.dart';

const _kTestSize = Size(700, 900);

Widget _buildSubject({AuthNotifier? authNotifier}) {
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, __) => const InstallAppScreen())],
  );
  return ProviderScope(
    overrides: [
      authProvider.overrideWith(() => authNotifier ?? _UnauthNotifier()),
      silentNotificationsOverride,
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void _setTestSize(WidgetTester tester) {
  tester.view.physicalSize = _kTestSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('renders page title and subtitle', (tester) async {
    _setTestSize(tester);

    await tester.pumpWidget(_buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('install the app'), findsOneWidget);
    expect(find.textContaining('home screen'), findsWidgets);
  });

  testWidgets('shows both platform section titles', (tester) async {
    _setTestSize(tester);

    await tester.pumpWidget(_buildSubject());
    await tester.pumpAndSettle();

    // Both iOS and Android cards are always rendered (one expanded, one collapsed)
    expect(find.text('Android (Chrome)'), findsOneWidget);
    expect(find.text('iPhone / iPad (Safari)'), findsOneWidget);
  });

  testWidgets('shows step content', (tester) async {
    _setTestSize(tester);

    await tester.pumpWidget(_buildSubject());
    await tester.pumpAndSettle();

    // At least one platform's steps are visible (expanded)
    expect(find.textContaining('home screen'), findsWidgets);
  });

  testWidgets('works for unauthenticated user without crashing', (
    tester,
  ) async {
    _setTestSize(tester);

    await tester.pumpWidget(_buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('install the app'), findsOneWidget);
  });

  testWidgets('works for authenticated user', (tester) async {
    _setTestSize(tester);

    await tester.pumpWidget(_buildSubject(authNotifier: _MemberAuthNotifier()));
    await tester.pumpAndSettle();

    expect(find.text('install the app'), findsOneWidget);
  });
}

class _UnauthNotifier extends AuthNotifier {
  @override
  Future<User?> build() async => null;

  @override
  Future<void> logout() async {}
}

class _MemberAuthNotifier extends AuthNotifier {
  @override
  Future<User?> build() async =>
      const User(id: 'u1', phoneNumber: '+12025551234', displayName: 'Alice');

  @override
  Future<void> logout() async {}
}
