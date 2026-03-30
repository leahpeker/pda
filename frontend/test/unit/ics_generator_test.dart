import 'package:flutter_test/flutter_test.dart';
import 'package:pda/models/event.dart';
import 'package:pda/utils/ics_generator.dart';

void main() {
  group('generateEventIcs', () {
    test('generates valid ICS with all fields', () {
      final event = Event(
        id: 'abc-123',
        title: 'Vegan Potluck',
        description: 'Bring your best dish!',
        startDatetime: DateTime.utc(2026, 4, 15, 18, 0),
        endDatetime: DateTime.utc(2026, 4, 15, 21, 0),
        location: 'Central Park',
      );

      final ics = generateEventIcs(event);

      expect(ics, contains('BEGIN:VCALENDAR'));
      expect(ics, contains('END:VCALENDAR'));
      expect(ics, contains('BEGIN:VEVENT'));
      expect(ics, contains('END:VEVENT'));
      expect(ics, contains('UID:abc-123@pda'));
      expect(ics, contains('SUMMARY:Vegan Potluck'));
      expect(ics, contains('DTSTART:20260415T180000Z'));
      expect(ics, contains('DTEND:20260415T210000Z'));
      expect(ics, contains('DESCRIPTION:Bring your best dish!'));
      expect(ics, contains('LOCATION:Central Park'));
      expect(ics, contains('PRODID:-//PDA//PDA Calendar//EN'));
    });

    test('defaults DTEND to start + 2h when endDatetime is null', () {
      final event = Event(
        id: 'abc-123',
        title: 'Open Hangout',
        description: '',
        startDatetime: DateTime.utc(2026, 4, 15, 18, 0),
        location: '',
      );

      final ics = generateEventIcs(event);

      expect(ics, contains('DTSTART:20260415T180000Z'));
      expect(ics, contains('DTEND:20260415T200000Z'));
    });

    test('omits DESCRIPTION and LOCATION when empty', () {
      final event = Event(
        id: 'abc-123',
        title: 'Mystery Event',
        description: '',
        startDatetime: DateTime.utc(2026, 4, 15, 18, 0),
        location: '',
      );

      final ics = generateEventIcs(event);

      expect(ics, isNot(contains('DESCRIPTION')));
      expect(ics, isNot(contains('LOCATION')));
    });

    test('escapes special characters', () {
      final event = Event(
        id: 'abc-123',
        title: 'Fun, Games; and More',
        description: 'Line one\nLine two',
        startDatetime: DateTime.utc(2026, 4, 15, 18, 0),
        location: 'Room 1, Floor 2; Building A',
      );

      final ics = generateEventIcs(event);

      expect(ics, contains('Fun\\, Games\\; and More'));
      expect(ics, contains('Line one\\nLine two'));
      expect(ics, contains('Room 1\\, Floor 2\\; Building A'));
    });

    test('formats UTC dates correctly', () {
      final event = Event(
        id: 'abc-123',
        title: 'Test',
        description: '',
        startDatetime: DateTime.utc(2026, 1, 5, 9, 5, 3),
        location: '',
      );

      final ics = generateEventIcs(event);

      expect(ics, contains('DTSTART:20260105T090503Z'));
    });

    test('includes links in description', () {
      final event = Event(
        id: 'abc-123',
        title: 'Linked Event',
        description: 'Join us!',
        startDatetime: DateTime.utc(2026, 4, 15, 18, 0),
        location: '',
        whatsappLink: 'https://chat.whatsapp.com/abc',
        partifulLink: 'https://partiful.com/e/xyz',
        otherLink: 'https://example.com',
      );

      final ics = generateEventIcs(event);

      // Unfold ICS line continuations before checking content
      final unfolded = ics.replaceAll(RegExp(r'\r?\n '), '');
      expect(unfolded, contains('Join us!'));
      expect(unfolded, contains('WhatsApp: https://chat.whatsapp.com/abc'));
      expect(unfolded, contains('Partiful: https://partiful.com/e/xyz'));
      expect(unfolded, contains('Link: https://example.com'));
    });
  });

  group('googleCalendarUrl', () {
    test('builds correct URL with all fields', () {
      final event = Event(
        id: 'abc-123',
        title: 'Vegan Potluck',
        description: 'Bring food!',
        startDatetime: DateTime.utc(2026, 4, 15, 18, 0),
        endDatetime: DateTime.utc(2026, 4, 15, 21, 0),
        location: 'Central Park',
      );

      final url = googleCalendarUrl(event);

      expect(url, contains('calendar.google.com'));
      expect(url, contains('action=TEMPLATE'));
      expect(url, contains('text=Vegan+Potluck'));
      expect(url, contains('20260415T180000Z'));
      expect(url, contains('20260415T210000Z'));
      expect(url, contains('location=Central+Park'));
    });

    test('defaults end to start + 2h when null', () {
      final event = Event(
        id: 'abc-123',
        title: 'Open Hangout',
        description: '',
        startDatetime: DateTime.utc(2026, 4, 15, 18, 0),
        location: '',
      );

      final url = googleCalendarUrl(event);

      expect(url, contains('20260415T180000Z'));
      expect(url, contains('20260415T200000Z'));
    });
  });
}
