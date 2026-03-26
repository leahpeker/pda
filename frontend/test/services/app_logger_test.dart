import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:pda/services/app_logger.dart';

void main() {
  group('setupLogging', () {
    tearDown(() {
      Logger.root.clearListeners();
      Logger.root.level = Level.INFO;
    });

    test('configures root logger level', () {
      setupLogging();
      // In test mode (non-release), level should be ALL.
      expect(Logger.root.level, Level.ALL);
    });

    test('adds a listener to root logger', () {
      final records = <LogRecord>[];
      setupLogging();
      Logger.root.onRecord.listen(records.add);

      final logger = Logger('TestLogger');
      logger.info('test message');

      expect(records, isNotEmpty);
      expect(records.last.message, 'test message');
    });
  });

  group('AppLogger', () {
    test('get returns a named Logger', () {
      final logger = AppLogger.get('TestComponent');
      expect(logger, isA<Logger>());
      expect(logger.name, 'TestComponent');
    });

    test('get returns same Logger for same name', () {
      final logger1 = AppLogger.get('Same');
      final logger2 = AppLogger.get('Same');
      expect(identical(logger1, logger2), isTrue);
    });
  });
}
