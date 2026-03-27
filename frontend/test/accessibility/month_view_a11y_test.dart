import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pda/models/event.dart';
import 'package:pda/screens/calendar/month_view.dart';

void main() {
  final testEvent = Event(
    id: 'test-1',
    title: 'Community Potluck',
    description: 'Bring vegan food',
    startDatetime: DateTime(2026, 3, 25, 18, 0),
    endDatetime: DateTime(2026, 3, 25, 21, 0),
    location: 'Park',
  );

  Widget buildMonthView({List<Event> events = const []}) {
    return MaterialApp(
      home: Scaffold(
        body: MonthView(
          events: events,
          selectedDate: DateTime(2026, 3, 25),
          onDateChanged: (_) {},
          onDayTapped: (_) {},
        ),
      ),
    );
  }

  testWidgets('day cells have semantic labels with date', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(buildMonthView());

    // Day cells should have Semantics with date labels
    final daySemantics = find.byWidgetPredicate(
      (w) =>
          w is Semantics &&
          w.properties.button == true &&
          w.properties.label != null &&
          w.properties.label!.contains('March'),
    );
    expect(daySemantics, findsWidgets);
    handle.dispose();
  });

  testWidgets('event chips have semantic labels with event title', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(buildMonthView(events: [testEvent]));

    // Event chip should have Semantics with the event title
    final eventSemantics = find.byWidgetPredicate(
      (w) =>
          w is Semantics &&
          w.properties.label == 'Community Potluck' &&
          w.properties.button == true,
    );
    expect(eventSemantics, findsOneWidget);
    handle.dispose();
  });

  testWidgets('no bare GestureDetector widgets for interactive elements', (
    tester,
  ) async {
    await tester.pumpWidget(buildMonthView(events: [testEvent]));

    // Find all GestureDetectors that are NOT inside an InkWell/InkResponse.
    // InkWell uses GestureDetector internally, which is fine.
    final gestureDetectors = find.byType(GestureDetector);

    for (final element in gestureDetectors.evaluate()) {
      final widget = element.widget as GestureDetector;
      if (widget.onTap == null) continue;

      // Walk up the tree to check if this GestureDetector is inside an InkWell
      var isInsideInkWell = false;
      element.visitAncestorElements((ancestor) {
        if (ancestor.widget is InkWell || ancestor.widget is InkResponse) {
          isInsideInkWell = true;
          return false;
        }
        // Stop at MonthView level to avoid searching too far
        if (ancestor.widget is MonthView) return false;
        return true;
      });

      if (!isInsideInkWell) {
        fail(
          'Found bare GestureDetector with onTap — should be replaced with '
          'InkWell + Semantics for accessibility',
        );
      }
    }
  });
}
