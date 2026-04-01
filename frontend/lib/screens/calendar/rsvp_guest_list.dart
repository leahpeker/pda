import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pda/models/event.dart';
import 'package:pda/config/constants.dart';

class RsvpGuestList extends StatelessWidget {
  final List<EventGuest> guests;

  const RsvpGuestList({super.key, required this.guests});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final attending =
        guests.where((g) => g.status == RsvpStatus.attending).toList();
    final maybe = guests.where((g) => g.status == RsvpStatus.maybe).toList();
    final cantGo = guests.where((g) => g.status == RsvpStatus.cantGo).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GuestStatusGroup(label: 'going', guests: attending, color: cs.primary),
        _GuestStatusGroup(label: 'maybe', guests: maybe, color: cs.tertiary),
        _GuestStatusGroup(
          label: "can't make it",
          guests: cantGo,
          color: cs.error,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Expandable group row
// ---------------------------------------------------------------------------

class _GuestStatusGroup extends StatefulWidget {
  final String label;
  final List<EventGuest> guests;
  final Color color;

  const _GuestStatusGroup({
    required this.label,
    required this.guests,
    required this.color,
  });

  @override
  State<_GuestStatusGroup> createState() => _GuestStatusGroupState();
}

class _GuestStatusGroupState extends State<_GuestStatusGroup> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.guests.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final count = widget.guests.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            label:
                '$count ${widget.label}, tap to ${_expanded ? 'collapse' : 'expand'} guest list',
            excludeSemantics: true,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    _StackedAvatarRow(guests: widget.guests),
                    const SizedBox(width: 10),
                    Text(
                      '$count ${widget.label}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: widget.color,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 18,
                      color: cs.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child:
                _expanded
                    ? Padding(
                      padding: const EdgeInsets.only(top: 4, left: 4),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children:
                            widget.guests
                                .map((g) => _GuestChip(guest: g))
                                .toList(),
                      ),
                    )
                    : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stacked avatar row
// ---------------------------------------------------------------------------

class _StackedAvatarRow extends StatelessWidget {
  final List<EventGuest> guests;
  static const int _maxVisible = 5;
  static const double _radius = 14;
  static const double _overlap = _radius * 1.2;

  const _StackedAvatarRow({required this.guests});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final visible = guests.take(_maxVisible).toList();
    final overflow = guests.length - _maxVisible;
    final stackWidth =
        visible.isEmpty ? 0.0 : _radius * 2 + (visible.length - 1) * _overlap;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: stackWidth,
          height: _radius * 2,
          child: Stack(
            children: [
              for (var i = visible.length - 1; i >= 0; i--)
                Positioned(
                  left: i * _overlap,
                  child: _StackedAvatar(
                    guest: visible[i],
                    radius: _radius,
                    borderColor: cs.surface,
                  ),
                ),
            ],
          ),
        ),
        if (overflow > 0) ...[
          const SizedBox(width: 6),
          Text(
            '+$overflow',
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

class _StackedAvatar extends StatelessWidget {
  final EventGuest guest;
  final double radius;
  final Color borderColor;

  const _StackedAvatar({
    required this.guest,
    required this.radius,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final initials = guest.name.isNotEmpty ? guest.name[0].toUpperCase() : '?';

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
      ),
      child: CircleAvatar(
        radius: radius - 2,
        backgroundImage:
            guest.photoUrl.isNotEmpty ? NetworkImage(guest.photoUrl) : null,
        backgroundColor: cs.primaryContainer,
        child:
            guest.photoUrl.isEmpty
                ? Text(
                  initials,
                  style: TextStyle(
                    fontSize: (radius - 2) * 0.85,
                    fontWeight: FontWeight.w600,
                    color: cs.onPrimaryContainer,
                  ),
                )
                : null,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Guest chip (expanded list)
// ---------------------------------------------------------------------------

class _GuestAvatar extends StatelessWidget {
  final EventGuest guest;
  const _GuestAvatar({required this.guest});

  static const double radius = 14;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final initials = guest.name.isNotEmpty ? guest.name[0].toUpperCase() : '?';

    if (guest.photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(guest.photoUrl),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: cs.primaryContainer,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: radius * 0.9,
          fontWeight: FontWeight.w600,
          color: cs.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _GuestChip extends StatefulWidget {
  final EventGuest guest;

  const _GuestChip({required this.guest});

  @override
  State<_GuestChip> createState() => _GuestChipState();
}

class _GuestChipState extends State<_GuestChip> {
  OverlayEntry? _overlay;
  final _link = LayerLink();

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  void _showOverlay(String phone) {
    if (_overlay != null) return;
    _overlay = OverlayEntry(
      builder:
          (_) => GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _removeOverlay,
            child: Stack(
              children: [
                CompositedTransformFollower(
                  link: _link,
                  offset: const Offset(0, 20),
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey.shade900,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.smartphone_outlined,
                            size: 13,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(width: 6),
                          SelectableText(
                            phone,
                            style: TextStyle(
                              fontSize: 13,
                              fontFamily: 'monospace',
                              color: Colors.grey.shade100,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
    Overlay.of(context).insert(_overlay!);
  }

  @override
  Widget build(BuildContext context) {
    final phone = widget.guest.phone;
    final isWide = MediaQuery.sizeOf(context).width >= 720;
    final cs = Theme.of(context).colorScheme;

    if (phone == null) {
      return Semantics(
        button: true,
        label: "view ${widget.guest.name}'s profile",
        excludeSemantics: true,
        child: InkWell(
          onTap: () => context.push('/members/${widget.guest.userId}'),
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _GuestAvatar(guest: widget.guest),
                const SizedBox(width: 6),
                Text(widget.guest.name, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ),
      );
    }

    if (isWide) {
      return Semantics(
        button: true,
        label: "view ${widget.guest.name}'s profile",
        excludeSemantics: true,
        child: CompositedTransformTarget(
          link: _link,
          child: MouseRegion(
            onEnter: (_) => _showOverlay(phone),
            onExit: (_) => _removeOverlay(),
            cursor: SystemMouseCursors.basic,
            child: InkWell(
              onTap: () => context.push('/members/${widget.guest.userId}'),
              customBorder: const StadiumBorder(),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _GuestAvatar(guest: widget.guest),
                    const SizedBox(width: 6),
                    Text(
                      widget.guest.name,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Mobile: tap navigates to profile, phone shown as subtitle
    return Semantics(
      button: true,
      label: "view ${widget.guest.name}'s profile",
      excludeSemantics: true,
      child: InkWell(
        onTap: () => context.push('/members/${widget.guest.userId}'),
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _GuestAvatar(guest: widget.guest),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.guest.name, style: const TextStyle(fontSize: 13)),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.smartphone_outlined,
                        size: 11,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        phone,
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
