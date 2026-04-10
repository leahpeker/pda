import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:pda/models/event.dart';
import 'package:pda/providers/auth_provider.dart';
import 'package:pda/providers/event_provider.dart';
import 'package:pda/utils/snackbar.dart';
import 'package:pda/config/constants.dart';
import 'rsvp_guest_list.dart';
import 'rsvp_toggle_button.dart';

final _log = Logger('RSVP');

class RSVPSection extends ConsumerStatefulWidget {
  final Event event;
  const RSVPSection({super.key, required this.event});

  @override
  ConsumerState<RSVPSection> createState() => _RSVPSectionState();
}

class _RSVPSectionState extends ConsumerState<RSVPSection> {
  bool _loading = false;
  bool _bringingPlusOne = false;

  Future<void> _setRsvp(String status, {bool? hasPlusOne}) async {
    final plusOne = hasPlusOne ?? _bringingPlusOne;
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post(
        '/api/community/events/${widget.event.id}/rsvp/',
        data: {'status': status, 'has_plus_one': plusOne},
      );
      ref.invalidate(eventsProvider);
      ref.invalidate(eventDetailProvider(widget.event.id));
      _log.info('rsvp set to $status for event ${widget.event.id}');
    } catch (e, st) {
      _log.warning('failed to set rsvp', e, st);
      if (mounted) {
        showErrorSnackBar(context, 'couldn\'t update your rsvp — try again');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmAndSetRsvp(String status, String label) async {
    final user = ref.read(authProvider).value;
    final isCoHost =
        user != null &&
        (widget.event.coHostIds.contains(user.id) ||
            widget.event.createdById == user.id);

    if (isCoHost) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('change your rsvp?'),
          content: Text(
            'you\'re a co-host of this event — are you sure you want to rsvp as "$label"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('yes, update'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    await _setRsvp(status);
  }

  Future<void> _removeRsvp() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.delete('/api/community/events/${widget.event.id}/rsvp/');
      ref.invalidate(eventsProvider);
      ref.invalidate(eventDetailProvider(widget.event.id));
      _log.info('rsvp removed for event ${widget.event.id}');
    } catch (e, st) {
      _log.warning('failed to remove rsvp', e, st);
      if (mounted) {
        showErrorSnackBar(context, 'couldn\'t remove your rsvp — try again');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildToggleButtons({
    required String? myRsvp,
    required ColorScheme cs,
    required bool enabled,
    required bool atCapacity,
  }) {
    final String goingLabel;
    final IconData goingIcon;
    final VoidCallback goingTap;

    if (myRsvp == RsvpStatus.waitlisted) {
      goingLabel = 'leave waitlist';
      goingIcon = Icons.hourglass_empty_outlined;
      goingTap = _removeRsvp;
    } else if (atCapacity && myRsvp != RsvpStatus.attending) {
      goingLabel = 'join waitlist';
      goingIcon = Icons.hourglass_empty_outlined;
      goingTap = () => _setRsvp(RsvpStatus.attending);
    } else if (myRsvp == RsvpStatus.attending) {
      goingLabel = "i'm going";
      goingIcon = Icons.sentiment_very_satisfied_outlined;
      goingTap = _removeRsvp;
    } else {
      goingLabel = "i'm going";
      goingIcon = Icons.sentiment_very_satisfied_outlined;
      goingTap = () => _setRsvp(RsvpStatus.attending);
    }

    return Opacity(
      opacity: _loading ? 0.5 : 1.0,
      child: Row(
        spacing: 8,
        children: [
          Expanded(
            child: RsvpToggleButton(
              label: goingLabel,
              icon: goingIcon,
              activeColor: cs.primary,
              isActive: myRsvp == RsvpStatus.attending,
              enabled: enabled,
              onTap: goingTap,
            ),
          ),
          if (myRsvp != RsvpStatus.waitlisted) ...[
            Expanded(
              child: RsvpToggleButton(
                label: 'maybe',
                icon: Icons.sentiment_neutral_outlined,
                activeColor: cs.tertiary,
                isActive: myRsvp == RsvpStatus.maybe,
                enabled: enabled,
                onTap: () => myRsvp == RsvpStatus.maybe
                    ? _removeRsvp()
                    : _confirmAndSetRsvp(RsvpStatus.maybe, 'maybe'),
              ),
            ),
            Expanded(
              child: RsvpToggleButton(
                label: "can't make it",
                icon: Icons.sentiment_dissatisfied_outlined,
                activeColor: cs.error,
                isActive: myRsvp == RsvpStatus.cantGo,
                enabled: enabled,
                onTap: () => myRsvp == RsvpStatus.cantGo
                    ? _removeRsvp()
                    : _confirmAndSetRsvp(RsvpStatus.cantGo, "can't make it"),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _buildSummary(Event event) {
    final attendingCount = event.attendingCount > 0
        ? event.attendingCount
        : event.guests
              .where((g) => g.status == RsvpStatus.attending)
              .fold(0, (sum, g) => sum + 1 + (g.hasPlusOne ? 1 : 0));
    final maybeCount = event.guests
        .where((g) => g.status == RsvpStatus.maybe)
        .fold(0, (sum, g) => sum + 1 + (g.hasPlusOne ? 1 : 0));
    final waitlistedCount = event.waitlistedCount > 0
        ? event.waitlistedCount
        : event.guests.where((g) => g.status == RsvpStatus.waitlisted).length;

    final goingPart = event.maxAttendees != null
        ? '$attendingCount / ${event.maxAttendees} going'
        : attendingCount > 0
        ? '$attendingCount going'
        : null;

    final parts = [
      if (goingPart != null) goingPart,
      if (maybeCount > 0) '$maybeCount maybe',
      if (waitlistedCount > 0) '$waitlistedCount waitlisted',
    ];
    return parts.join(' · ');
  }

  Widget _buildPlusOneButton(String myRsvp) {
    return Center(
      child: _bringingPlusOne
          ? FilledButton.tonal(
              onPressed: _loading
                  ? null
                  : () {
                      setState(() => _bringingPlusOne = false);
                      _setRsvp(myRsvp, hasPlusOne: false);
                    },
              child: const Text('bringing +1 ✓'),
            )
          : OutlinedButton(
              onPressed: _loading
                  ? null
                  : () {
                      setState(() => _bringingPlusOne = true);
                      _setRsvp(myRsvp, hasPlusOne: true);
                    },
              child: const Text('bring a +1'),
            ),
    );
  }

  Widget? _buildStatusBanner({
    required bool isCancelled,
    required bool isPastForUser,
    required ColorScheme cs,
  }) {
    if (isCancelled) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          'this event has been cancelled',
          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
        ),
      );
    }
    if (isPastForUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          'rsvps are closed for past events',
          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
        ),
      );
    }
    return null;
  }

  bool _isCoHost(user, Event event) {
    if (user == null) return false;
    return event.coHostIds.contains(user.id) || event.createdById == user.id;
  }

  void _syncPlusOneFromGuests(List<EventGuest> guests, String? userId) {
    if (userId == null || _loading) return;
    final myGuest = guests.where((g) => g.userId == userId).firstOrNull;
    if (myGuest != null && myGuest.hasPlusOne != _bringingPlusOne) {
      _bringingPlusOne = myGuest.hasPlusOne;
    }
  }

  bool _showPlusOne(Event event, String? myRsvp) {
    if (!event.allowPlusOnes) return false;
    if (myRsvp == RsvpStatus.waitlisted) return false;
    return myRsvp == RsvpStatus.attending || myRsvp == RsvpStatus.maybe;
  }

  bool _atCapacity(Event event) {
    if (event.maxAttendees == null) return false;
    return event.attendingCount >= event.maxAttendees!;
  }

  bool _hasGuests(Event event) {
    return event.guests.isNotEmpty || event.invitedUserNames.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final liveEvent =
        ref.watch(eventDetailProvider(widget.event.id)).value ?? widget.event;
    final myRsvp = liveEvent.myRsvp;
    final currentUser = ref.watch(authProvider).value;
    final isCoHost = _isCoHost(currentUser, liveEvent);

    _syncPlusOneFromGuests(liveEvent.guests, currentUser?.id);

    final isPastForUser = liveEvent.isPast && !isCoHost;
    final isCancelled = liveEvent.status == EventStatus.cancelled;
    final summary = _buildSummary(liveEvent);
    final statusBanner = _buildStatusBanner(
      isCancelled: isCancelled,
      isPastForUser: isPastForUser,
      cs: cs,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (summary.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              summary,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        if (statusBanner != null) statusBanner,
        _buildToggleButtons(
          myRsvp: myRsvp,
          cs: cs,
          enabled: !_loading && !isPastForUser && !isCancelled,
          atCapacity: _atCapacity(liveEvent),
        ),
        if (myRsvp == RsvpStatus.waitlisted) ...[
          const SizedBox(height: 10),
          Text(
            "you're on the waitlist — we'll let you know if a spot opens",
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
        if (_showPlusOne(liveEvent, myRsvp)) ...[
          const SizedBox(height: 12),
          _buildPlusOneButton(myRsvp!),
        ],
        if (_hasGuests(liveEvent)) ...[
          const SizedBox(height: 16),
          RsvpGuestList(
            guests: liveEvent.guests,
            invitedUserIds: liveEvent.invitedUserIds,
            invitedUserNames: liveEvent.invitedUserNames,
            invitedUserPhotoUrls: liveEvent.invitedUserPhotoUrls,
            showInvited: isCoHost,
          ),
        ],
      ],
    );
  }
}
