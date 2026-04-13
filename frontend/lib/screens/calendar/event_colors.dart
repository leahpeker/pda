import 'package:flutter/material.dart';
import 'package:pda/config/constants.dart';

// Official (blue) — distinct hue for all CVD types
const _kOfficialLight = (Color(0xFFD0E8FF), Color(0xFF1A3A5C));
const _kOfficialDark = (Color(0xFF1A3050), Color(0xFFB0D4FF));

// Public community (teal) — differs from blue in green channel, from amber in luminance
const _kPublicLight = (Color(0xFFCCE8E4), Color(0xFF0A3D35));
const _kPublicDark = (Color(0xFF103028), Color(0xFFA8E0D8));

// Members only (warm amber) — high luminance, warm tone distinct from cool colors
const _kMembersOnlyLight = (Color(0xFFFFE0B2), Color(0xFF5C3800));
const _kMembersOnlyDark = (Color(0xFF3D2810), Color(0xFFFFD6A0));

// Invite only (lavender) — cool-warm midpoint, distinct luminance from blue
const _kInviteOnlyLight = (Color(0xFFE0D0F0), Color(0xFF2D1A5C));
const _kInviteOnlyDark = (Color(0xFF201040), Color(0xFFD0B8FF));

/// Returns (backgroundColor, foregroundColor) for an event based on its
/// type and visibility.
///
/// The four visibility choices map to distinct colors:
/// - Official PDA event (type=official) → blue
/// - Public community event → green
/// - Members only → orange
/// - Invite only → purple
(Color, Color) eventColors(
  String eventType,
  String visibility,
  Brightness brightness,
) {
  if (eventType == EventType.official) {
    return brightness == Brightness.dark ? _kOfficialDark : _kOfficialLight;
  }
  if (visibility == PageVisibility.inviteOnly) {
    return brightness == Brightness.dark ? _kInviteOnlyDark : _kInviteOnlyLight;
  }
  if (visibility == PageVisibility.membersOnly) {
    return brightness == Brightness.dark
        ? _kMembersOnlyDark
        : _kMembersOnlyLight;
  }
  return brightness == Brightness.dark ? _kPublicDark : _kPublicLight;
}
