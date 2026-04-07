import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pda/config/constants.dart';
import 'package:pda/providers/auth_provider.dart';
import 'package:pda/screens/calendar/co_host_picker.dart';

class EventFormSettingsSection extends ConsumerWidget {
  final bool rsvpEnabled;
  final String visibilityChoice;
  final String partifulLinkText;
  final String invitePermission;
  final Set<String> coHostIds;
  final Map<String, String> coHostNames;
  final ScrollController scrollController;
  final bool allowPlusOnes;
  final ValueChanged<bool> onRsvpChanged;
  final ValueChanged<bool> onAllowPlusOnesChanged;
  final ValueChanged<String> onVisibilityChoiceChanged;
  final ValueChanged<String> onInvitePermissionChanged;
  final ValueChanged<Set<String>> onCoHostsChanged;

  const EventFormSettingsSection({
    super.key,
    required this.rsvpEnabled,
    required this.allowPlusOnes,
    required this.visibilityChoice,
    required this.partifulLinkText,
    required this.invitePermission,
    required this.coHostIds,
    required this.coHostNames,
    required this.scrollController,
    required this.onRsvpChanged,
    required this.onAllowPlusOnesChanged,
    required this.onVisibilityChoiceChanged,
    required this.onInvitePermissionChanged,
    required this.onCoHostsChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final canTagOfficial =
        ref
            .watch(authProvider)
            .value
            ?.hasPermission(Permission.tagOfficialEvent) ??
        false;
    final showOfficialOption =
        canTagOfficial || visibilityChoice == EventVisibilityChoice.official;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          value: rsvpEnabled,
          onChanged: onRsvpChanged,
          title: const Text('enable RSVPs'),
          subtitle: rsvpEnabled && partifulLinkText.trim().isNotEmpty
              ? Text(
                  'you have a partiful link set — consider using one or the other',
                  style: TextStyle(color: theme.colorScheme.tertiary),
                )
              : null,
          contentPadding: EdgeInsets.zero,
        ),
        if (rsvpEnabled) ...[
          SwitchListTile(
            value: allowPlusOnes,
            onChanged: onAllowPlusOnesChanged,
            title: const Text('allow +1s'),
            subtitle: const Text('guests can bring additional people'),
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            title: const Text('guests can invite friends'),
            value: invitePermission == InvitePermission.allMembers,
            contentPadding: EdgeInsets.zero,
            onChanged: (val) => onInvitePermissionChanged(
              val ? InvitePermission.allMembers : InvitePermission.coHostsOnly,
            ),
          ),
        ],
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: visibilityChoice,
          decoration: const InputDecoration(
            labelText: 'visibility',
            border: OutlineInputBorder(),
          ),
          items: [
            if (showOfficialOption)
              const DropdownMenuItem(
                value: EventVisibilityChoice.official,
                child: Text('official PDA event'),
              ),
            const DropdownMenuItem(
              value: EventVisibilityChoice.public_,
              child: Text('public'),
            ),
            const DropdownMenuItem(
              value: EventVisibilityChoice.membersOnly,
              child: Text('pda members only'),
            ),
            const DropdownMenuItem(
              value: EventVisibilityChoice.inviteOnly,
              child: Text('invite only'),
            ),
          ],
          onChanged: (val) =>
              onVisibilityChoiceChanged(val ?? EventVisibilityChoice.public_),
        ),
        const SizedBox(height: 4),
        Text(switch (visibilityChoice) {
          EventVisibilityChoice.official =>
            'this is an official PDA event — visible to everyone',
          EventVisibilityChoice.membersOnly =>
            'only pda members can see this one',
          EventVisibilityChoice.inviteOnly =>
            'invite-only — just the people you pick',
          _ =>
            'anyone can find this event — members get the full details like location and links',
        }, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface)),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),
        Text('co-hosts', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        CoHostPicker(
          selectedIds: coHostIds,
          selectedNames: coHostNames,
          onChanged: onCoHostsChanged,
          scrollController: scrollController,
        ),
      ],
    );
  }
}
