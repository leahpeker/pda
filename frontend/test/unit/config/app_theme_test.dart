import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pda/config/app_theme.dart';

void main() {
  test('buildAppTheme disables page transitions for all platforms', () {
    final theme = buildAppTheme();
    final builders = theme.pageTransitionsTheme.builders;

    for (final platform in TargetPlatform.values) {
      expect(
        builders[platform],
        isNotNull,
        reason: 'Missing pageTransitionsTheme builder for $platform',
      );
    }
  });
}
