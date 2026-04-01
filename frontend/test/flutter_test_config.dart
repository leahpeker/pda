import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Suppress asset-not-found errors across all widget tests.
//
// Two types of asset errors occur in the VM test environment:
//  1. Image.asset('assets/logo.png') — handled by errorBuilder in AppScaffold.
//  2. FragmentProgram._fromAsset('shaders/ink_sparkle.frag') — thrown when
//     Material InkSplash animations run; filtered here.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Filter shader/image asset errors before they fail tests.
  final originalReporter = reportTestException;
  reportTestException = (FlutterErrorDetails details, String testDescription) {
    final message = details.exception.toString();
    if (message.contains('ink_sparkle') ||
        message.contains('.frag') ||
        message.contains('Unable to load asset') ||
        message.contains('logo.png')) {
      return; // swallow
    }
    originalReporter(details, testDescription);
  };

  await testMain();
}
