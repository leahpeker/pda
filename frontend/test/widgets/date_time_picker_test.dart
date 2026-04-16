import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pda/widgets/date_time_picker.dart';
import 'package:pda/widgets/date_time_picker_dialog.dart';

Widget _app(Widget child) => MaterialApp(
  theme: ThemeData(splashFactory: NoSplash.splashFactory),
  home: Scaffold(body: child),
);

void main() {
  group('DateTimePicker', () {
    testWidgets('renders calendar and time wheels', (tester) async {
      await tester.pumpWidget(
        _app(
          DateTimePicker(
            initialDateTime: DateTime(2024, 6, 15, 14, 30),
            onDateTimeChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CalendarDatePicker), findsOneWidget);
      // Three scroll wheels: hour, minute, AM/PM
      expect(find.byType(ListWheelScrollView), findsNWidgets(3));
    });

    testWidgets('calendar date selection preserves time', (tester) async {
      DateTime? result;
      final initial = DateTime(2024, 6, 15, 14, 30);

      await tester.pumpWidget(
        _app(
          DateTimePicker(
            initialDateTime: initial,
            onDateTimeChanged: (dt) => result = dt,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap a different day in the calendar (the 20th)
      await tester.tap(find.text('20'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      // Time must be preserved
      expect(result!.hour, equals(14));
      expect(result!.minute, equals(30));
      // Date must have changed
      expect(result!.day, equals(20));
    });

    testWidgets('clamps time when date selection makes current time invalid', (
      tester,
    ) async {
      // firstDate = today at 3:00 PM (15:00)
      final firstDate = DateTime(2024, 6, 15, 15, 0);
      // Start on a future date with time 1:00 PM (valid for that date)
      final initial = DateTime(2024, 6, 20, 13, 0);
      DateTime? result;

      await tester.pumpWidget(
        _app(
          DateTimePicker(
            initialDateTime: initial,
            firstDate: firstDate,
            onDateTimeChanged: (dt) => result = dt,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap today (the 15th) — this makes 1:00 PM invalid (before 3:00 PM)
      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      // Must be clamped to at least firstDate
      expect(result!.isBefore(firstDate), isFalse);
      expect(result!.day, equals(15));
    });

    testWidgets('no clamping when selected date is after firstDate day', (
      tester,
    ) async {
      final firstDate = DateTime(2024, 6, 15, 23, 0);
      final initial = DateTime(2024, 6, 20, 1, 0); // future date, early time
      DateTime? result;

      await tester.pumpWidget(
        _app(
          DateTimePicker(
            initialDateTime: initial,
            firstDate: firstDate,
            onDateTimeChanged: (dt) => result = dt,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the 25th — a date beyond firstDate, so early time is fine
      await tester.tap(find.text('25'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      // Time should be preserved as-is (1:00 AM on the 25th is not before firstDate)
      expect(result!.day, equals(25));
      expect(result!.hour, equals(1));
    });

    testWidgets('no clamping when firstDate is null', (tester) async {
      final initial = DateTime(2024, 6, 15, 14, 30);
      DateTime? result;

      await tester.pumpWidget(
        _app(
          DateTimePicker(
            initialDateTime: initial,
            onDateTimeChanged: (dt) => result = dt,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('10'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      // Time preserved, no clamping
      expect(result!.hour, equals(14));
      expect(result!.minute, equals(30));
    });

    testWidgets(
      'didUpdateWidget syncs controllers when initialDateTime changes',
      (tester) async {
        final notifier = ValueNotifier(DateTime(2024, 6, 15, 10, 0));

        await tester.pumpWidget(
          _app(
            ValueListenableBuilder<DateTime>(
              valueListenable: notifier,
              builder: (_, dt, __) => DateTimePicker(
                initialDateTime: dt,
                onDateTimeChanged: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Change the initial value externally
        notifier.value = DateTime(2024, 6, 15, 16, 0);
        await tester.pumpAndSettle();

        // Widget should not throw; just verify it rebuilds without error
        expect(find.byType(DateTimePicker), findsOneWidget);
      },
    );
  });

  group('showDateTimePicker dialog', () {
    testWidgets('returns null when cancelled', (tester) async {
      // Use a large surface so CalendarDatePicker + time wheels fit without overflow
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      DateTime? result =
          DateTime.now(); // start non-null to confirm it goes null
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => TextButton(
                onPressed: () async {
                  result = await showDateTimePicker(
                    context: ctx,
                    initialDateTime: DateTime(2024, 6, 15, 10, 0),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('cancel'), findsOneWidget);
      await tester.tap(find.text('cancel'));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });

    testWidgets('returns selected datetime when done is tapped', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      DateTime? result;
      final initial = DateTime(2024, 6, 15, 10, 0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => TextButton(
                onPressed: () async {
                  result = await showDateTimePicker(
                    context: ctx,
                    initialDateTime: initial,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('done'), findsOneWidget);
      await tester.tap(find.text('done'));
      await tester.pumpAndSettle();

      // Returns the initial value unchanged if no interaction
      expect(result, equals(initial));
    });
  });
}
