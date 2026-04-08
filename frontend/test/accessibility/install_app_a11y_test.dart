import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pda/models/user.dart';
import 'package:pda/providers/auth_provider.dart';
import 'package:pda/screens/install_app_screen.dart';

import '../helpers/provider_overrides.dart';

class _UnauthNotifier extends AuthNotifier {
  @override
  Future<User?> build() async => null;

  @override
  Future<void> logout() async {}
}

Widget _buildSubject() {
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, __) => const InstallAppScreen())],
  );
  return ProviderScope(
    overrides: [
      authProvider.overrideWith(() => _UnauthNotifier()),
      silentNotificationsOverride,
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('install app screen accessibility', () {
    testWidgets('meets labeled tap target guideline', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(_buildSubject());
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      handle.dispose();
    });

    testWidgets('meets text contrast guideline', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(_buildSubject());
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(textContrastGuideline));

      handle.dispose();
    });

    testWidgets('meets android tap target guideline', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(_buildSubject());
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));

      handle.dispose();
    });
  });
}
