import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pda/config/constants.dart';
import 'package:pda/screens/calendar/event_colors.dart';

void main() {
  group('eventColors', () {
    test('all four visibility choices produce distinct light colors', () {
      final colors = <Color>{};
      for (final choice in [
        (EventType.official, PageVisibility.public_),
        (EventType.community, PageVisibility.public_),
        (EventType.community, PageVisibility.membersOnly),
        (EventType.community, PageVisibility.inviteOnly),
      ]) {
        final (bg, _) = eventColors(choice.$1, choice.$2, Brightness.light);
        colors.add(bg);
      }
      expect(colors.length, 4);
    });

    test('all four visibility choices produce distinct dark colors', () {
      final colors = <Color>{};
      for (final choice in [
        (EventType.official, PageVisibility.public_),
        (EventType.community, PageVisibility.public_),
        (EventType.community, PageVisibility.membersOnly),
        (EventType.community, PageVisibility.inviteOnly),
      ]) {
        final (bg, _) = eventColors(choice.$1, choice.$2, Brightness.dark);
        colors.add(bg);
      }
      expect(colors.length, 4);
    });

    test('light mode has lighter backgrounds', () {
      final (bg, _) = eventColors(
        EventType.official,
        PageVisibility.public_,
        Brightness.light,
      );
      final hsl = HSLColor.fromColor(bg);
      expect(hsl.lightness, greaterThan(0.7));
    });

    test('dark mode has darker backgrounds', () {
      final (bg, _) = eventColors(
        EventType.official,
        PageVisibility.public_,
        Brightness.dark,
      );
      final hsl = HSLColor.fromColor(bg);
      expect(hsl.lightness, lessThan(0.3));
    });
  });
}
