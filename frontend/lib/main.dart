import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:pda/router/app_router.dart';
import 'package:pda/services/app_logger.dart';
import 'package:pda/services/error_reporter.dart';
import 'package:pda/services/secure_storage.dart';

/// Initializes the Flutter binding and enables the semantics tree.
///
/// The semantics tree creates a shadow DOM with ARIA-annotated elements
/// on CanvasKit web, making the app accessible to screen readers and
/// browser automation tools regardless of whether a screen reader is detected.
SemanticsHandle ensureAppInitialized() {
  WidgetsFlutterBinding.ensureInitialized();
  return SemanticsBinding.instance.ensureSemantics();
}

void main() {
  ensureAppInitialized();
  setupLogging();
  final reporter = ErrorReporter(SecureStorageService());
  setupErrorHandlers(
    onError: (error, stackTrace) {
      reporter.report(error: error, stackTrace: stackTrace, context: 'global');
    },
  );
  usePathUrlStrategy();
  runApp(const ProviderScope(child: PdaApp()));
}

class PdaApp extends ConsumerWidget {
  const PdaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Protein Deficients Anonymous',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
        useMaterial3: true,
      ),
      routerConfig: router,
      localizationsDelegates: const [
        FlutterQuillLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: FlutterQuillLocalizations.supportedLocales,
    );
  }
}
