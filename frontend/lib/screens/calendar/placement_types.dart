import '../../models/event.dart';

/// A positioned event span within a week row.
class SpanPlacement {
  final Event event;

  /// Start column (0–6 inclusive).
  final int startCol;

  /// End column (0–6 inclusive).
  final int endCol;

  /// Slot row index (0 = first row, 1 = second, etc.).
  final int row;

  const SpanPlacement({
    required this.event,
    required this.startCol,
    required this.endCol,
    required this.row,
  });
}

/// Whether [event] overlaps with the calendar [day].
bool dayContains(DateTime day, Event e) {
  final dayStart = DateTime(day.year, day.month, day.day);
  final dayEnd = dayStart.add(const Duration(days: 1));
  final start = e.startDatetime.toLocal();
  final end = e.endDatetime.toLocal();
  return start.isBefore(dayEnd) && end.isAfter(dayStart);
}
