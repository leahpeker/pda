import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pda/models/event.dart';
import 'package:pda/screens/calendar/day_view.dart';
import 'package:pda/screens/calendar/list_view.dart';
import 'package:pda/screens/calendar/week_view.dart';

void main() {
  final testEvent = Event(
    id: 'test-1',
    title: 'Community Potluck',
    description: 'Bring vegan food',
    startDatetime: DateTime(2026, 3, 25, 18, 0),
    endDatetime: DateTime(2026, 3, 25, 21, 0),
    location: 'Park',
  );

  group('WeekView accessibility', () {
    Widget buildWeekView({List<Event> events = const []}) {
      return MaterialApp(
        home: Scaffold(
          body: WeekView(
            events: events,
            selectedDate: DateTime(2026, 3, 25),
            onDateChanged: (_) {},
          ),
        ),
      );
    }

    testWidgets('event chips have semantic labels with event title', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(buildWeekView(events: [testEvent]));

      final eventSemantics = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.label == 'Community Potluck' &&
            w.properties.button == true,
      );
      expect(eventSemantics, findsOneWidget);
      handle.dispose();
    });
  });

  group('EventListView accessibility', () {
    // Use a future date so the event shows under the default "upcoming" filter.
    final futureEvent = Event(
      id: 'future-1',
      title: 'Community Potluck',
      description: 'Bring vegan food',
      startDatetime: DateTime.now().add(const Duration(days: 7)),
      endDatetime: DateTime.now().add(const Duration(days: 7, hours: 3)),
      location: 'Park',
    );

    Widget buildListView({List<Event> events = const []}) {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => Scaffold(body: EventListView(events: events)),
          ),
          GoRoute(path: '/events/:id', builder: (_, __) => const SizedBox()),
        ],
      );
      return MaterialApp.router(routerConfig: router);
    }

    testWidgets('event rows have semantic labels with event title', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(buildListView(events: [futureEvent]));
      await tester.pumpAndSettle();

      final eventSemantics = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.label == 'Community Potluck' &&
            w.properties.button == true,
      );
      expect(eventSemantics, findsOneWidget);
      handle.dispose();
    });
  });

  group('DayView accessibility', () {
    Widget buildDayView({List<Event> events = const []}) {
      return MaterialApp(
        home: Scaffold(
          body: DayView(
            events: events,
            selectedDate: DateTime(2026, 3, 25),
            onDateChanged: (_) {},
          ),
        ),
      );
    }

    testWidgets('event cards have semantic labels with event title', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(buildDayView(events: [testEvent]));

      final eventSemantics = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.label == 'Community Potluck' &&
            w.properties.button == true,
      );
      expect(eventSemantics, findsOneWidget);
      handle.dispose();
    });
  });
}
