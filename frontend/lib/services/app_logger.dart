import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

/// Configures the root logger level and output listener.
///
/// Call once in `main()` before `runApp()`.
void setupLogging() {
  Logger.root.level = kReleaseMode ? Level.WARNING : Level.ALL;

  Logger.root.onRecord.listen((record) {
    final time = record.time.toIso8601String();
    final level = record.level.name;
    final logger = record.loggerName;
    final message = record.message;

    var output = '$time [$level] $logger: $message';
    if (record.error != null) {
      output += '\n  Error: ${record.error}';
    }
    if (record.stackTrace != null) {
      output += '\n  Stack: ${record.stackTrace}';
    }
    // ignore: avoid_print
    debugPrint(output);
  });
}

/// Sets up global error handlers that log unhandled exceptions.
///
/// Call once in `main()` after `setupLogging()`.
void setupErrorHandlers() {
  final logger = Logger('Flutter');

  FlutterError.onError = (details) {
    logger.severe(
      'FlutterError: ${details.exceptionAsString()}',
      details.exception,
      details.stack,
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    logger.severe('Unhandled error', error, stack);
    return true;
  };
}

/// Provides named loggers for application components.
class AppLogger {
  AppLogger._();

  /// Returns a [Logger] with the given [name].
  ///
  /// Loggers are hierarchical and cached — calling with the same name
  /// returns the same instance.
  static Logger get(String name) => Logger(name);
}
