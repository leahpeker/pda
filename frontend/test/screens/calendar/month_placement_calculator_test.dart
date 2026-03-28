import 'package:flutter_test/flutter_test.dart';
import 'package:pda/models/event.dart';
import 'package:pda/screens/calendar/month_placement_calculator.dart';
import 'package:pda/screens/calendar/placement_types.dart';

Event _makeEvent(String id, DateTime start, DateTime end) {
  return Event(
    id: id,
    title: 'Event $id',
    description: '',
    startDatetime: start,
    endDatetime: end,
    location: '',
  );
}

void main() {
  group('MonthPlacementCalculator', () {
    final monday = DateTime(2026, 3, 23);
    final days = List.generate(7, (i) => monday.add(Duration(days: i)));

    test('returns empty list for no events', () {
      final calc = MonthPlacementCalculator(days: days, allEvents: []);
      expect(calc.calculate(), isEmpty);
    });

    test('places a single-day event at correct column', () {
      // Wednesday = index 2
      final event = _makeEvent(
        '1',
        DateTime(2026, 3, 25, 10),
        DateTime(2026, 3, 25, 12),
      );
      final calc = MonthPlacementCalculator(days: days, allEvents: [event]);
      final placements = calc.calculate();
      expect(placements, hasLength(1));
      expect(placements[0].startCol, 2);
      expect(placements[0].endCol, 2);
      expect(placements[0].row, 0);
    });

    test('places a multi-day event spanning columns', () {
      // Monday to Wednesday
      final event = _makeEvent(
        '1',
        DateTime(2026, 3, 23, 10),
        DateTime(2026, 3, 25, 12),
      );
      final calc = MonthPlacementCalculator(days: days, allEvents: [event]);
      final placements = calc.calculate();
      expect(placements, hasLength(1));
      expect(placements[0].startCol, 0);
      expect(placements[0].endCol, 2);
    });

    test('places event with null endDatetime on its start day only', () {
      final event = Event(
        id: '1',
        title: 'Event 1',
        description: '',
        startDatetime: DateTime(2026, 3, 25, 10),
        location: '',
      );
      final calc = MonthPlacementCalculator(days: days, allEvents: [event]);
      final placements = calc.calculate();
      expect(placements, hasLength(1));
      expect(placements[0].startCol, 2);
      expect(placements[0].endCol, 2);
    });

    test('assigns different slot rows to overlapping events', () {
      final event1 = _makeEvent(
        '1',
        DateTime(2026, 3, 23, 10),
        DateTime(2026, 3, 23, 12),
      );
      final event2 = _makeEvent(
        '2',
        DateTime(2026, 3, 23, 11),
        DateTime(2026, 3, 23, 13),
      );
      final calc = MonthPlacementCalculator(
        days: days,
        allEvents: [event1, event2],
      );
      final placements = calc.calculate();
      expect(placements, hasLength(2));
      final rows = placements.map((p) => p.row).toSet();
      expect(rows, {0, 1});
    });
  });

  group('dayContains', () {
    test('returns true when event spans the day', () {
      final day = DateTime(2026, 3, 25);
      final event = _makeEvent(
        '1',
        DateTime(2026, 3, 25, 10),
        DateTime(2026, 3, 25, 12),
      );
      expect(dayContains(day, event), isTrue);
    });

    test('returns true for event with null endDatetime on its start day', () {
      final day = DateTime(2026, 3, 25);
      final event = Event(
        id: '1',
        title: 'Event 1',
        description: '',
        startDatetime: DateTime(2026, 3, 25, 10),
        location: '',
      );
      expect(dayContains(day, event), isTrue);
    });

    test('returns false for event with null endDatetime on different day', () {
      final day = DateTime(2026, 3, 26);
      final event = Event(
        id: '1',
        title: 'Event 1',
        description: '',
        startDatetime: DateTime(2026, 3, 25, 10),
        location: '',
      );
      expect(dayContains(day, event), isFalse);
    });

    test('returns false when event is on different day', () {
      final day = DateTime(2026, 3, 26);
      final event = _makeEvent(
        '1',
        DateTime(2026, 3, 25, 10),
        DateTime(2026, 3, 25, 12),
      );
      expect(dayContains(day, event), isFalse);
    });
  });
}
