import 'package:flutter_test/flutter_test.dart';
import 'package:pda/models/event.dart';
import 'package:pda/screens/calendar/week_placement_calculator.dart';

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
  group('WeekPlacementCalculator', () {
    final monday = DateTime(2026, 3, 23);
    final days = List.generate(7, (i) => monday.add(Duration(days: i)));

    test('returns empty list for no events', () {
      final calc = WeekPlacementCalculator(days: days, allEvents: []);
      expect(calc.calculate(), isEmpty);
    });

    test('places a single-day event at correct column', () {
      final event = _makeEvent(
        '1',
        DateTime(2026, 3, 25, 10),
        DateTime(2026, 3, 25, 12),
      );
      final calc = WeekPlacementCalculator(days: days, allEvents: [event]);
      final placements = calc.calculate();
      expect(placements, hasLength(1));
      expect(placements[0].startCol, 2);
      expect(placements[0].endCol, 2);
      expect(placements[0].row, 0);
    });

    test('places a multi-day event spanning columns', () {
      final event = _makeEvent(
        '1',
        DateTime(2026, 3, 23, 10),
        DateTime(2026, 3, 25, 12),
      );
      final calc = WeekPlacementCalculator(days: days, allEvents: [event]);
      final placements = calc.calculate();
      expect(placements, hasLength(1));
      expect(placements[0].startCol, 0);
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
      final calc = WeekPlacementCalculator(
        days: days,
        allEvents: [event1, event2],
      );
      final placements = calc.calculate();
      expect(placements, hasLength(2));
      final rows = placements.map((p) => p.row).toSet();
      expect(rows, {0, 1});
    });
  });
}
