import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pda/config/constants.dart';
import 'package:pda/models/event.dart';
import 'package:pda/models/event_poll.dart';
import 'package:pda/models/user.dart';
import 'package:pda/providers/auth_provider.dart';
import 'package:pda/providers/event_poll_provider.dart';
import 'package:pda/utils/snackbar.dart';
import 'package:pda/widgets/poll_widgets.dart';

/// Renders an EventPoll inline inside the event detail "when" section card.
///
/// Shows voting chips when active, results when finalized, and a "sign in"
/// prompt for unauthenticated users.
class EmbeddedEventPoll extends ConsumerStatefulWidget {
  final Event event;

  const EmbeddedEventPoll({super.key, required this.event});

  @override
  ConsumerState<EmbeddedEventPoll> createState() => _EmbeddedEventPollState();
}

class _EmbeddedEventPollState extends ConsumerState<EmbeddedEventPoll> {
  // Maps optionId -> "yes" | "maybe"
  Map<String, String> _selected = {};
  bool _submitting = false;
  bool _editing = false;
  bool _prefilled = false;
  void _prefillFromPoll(EventPoll poll) {
    if (_prefilled || poll.myVotes.isEmpty) return;
    _selected = Map.of(poll.myVotes);
    _prefilled = true;
  }

  void _pruneStaleSelections(EventPoll poll) {
    final validIds = {for (final o in poll.options) o.id};
    final stale = _selected.keys.where((id) => !validIds.contains(id)).toList();
    if (stale.isEmpty) return;
    setState(() {
      for (final id in stale) {
        _selected.remove(id);
      }
    });
  }

  void _setAvailability(String optionId, String availability) {
    setState(() {
      if (_selected[optionId] == availability) {
        _selected = Map.of(_selected)..remove(optionId);
      } else {
        _selected = {..._selected, optionId: availability};
      }
    });
  }

  Future<void> _submit() async {
    if (_selected.isEmpty) return;
    setState(() => _submitting = true);
    try {
      await submitPollVote(
        ref: ref,
        eventId: widget.event.id,
        votes: _selected,
      );
      if (mounted) setState(() => _editing = false);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, 'couldn\'t submit — try again');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showVoters(BuildContext context, EventPollOption option) {
    showModalBottomSheet<void>(
      context: context,
      builder:
          (ctx) => VotersSheet(
            option: formatPollOption(option.datetime),
            voters: option.allVoters,
          ),
    );
  }

  bool _canManagePoll(User user) {
    if (user.hasPermission(Permission.manageEvents)) return true;
    if (user.hasPermission(Permission.manageSurveys)) return true;
    if (widget.event.createdById == user.id) return true;
    if (widget.event.coHostIds.contains(user.id)) return true;
    return false;
  }

  void _showFinalizeSheet(EventPoll poll) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => _FinalizeSheet(poll: poll, eventId: widget.event.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pollAsync = ref.watch(eventPollProvider(widget.event.id));

    return pollAsync.when(
      loading:
          () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: CircularProgressIndicator()),
          ),
      error: (_, __) => const Text('date & time tbd'),
      data: (poll) {
        if (poll == null) return const Text('date & time tbd');

        _prefillFromPoll(poll);
        _pruneStaleSelections(poll);

        if (poll.isFinalized) {
          return _buildFinalized(poll.winningDatetime!);
        }

        final user = ref.watch(authProvider).valueOrNull;
        if (user == null) {
          return Text(
            'sign in to vote on a time 🌿',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          );
        }

        final canManage = _canManagePoll(user);

        // Sort options by total vote count descending (most popular first)
        final sortedOptions = [...poll.options]
          ..sort((a, b) => b.totalCount.compareTo(a.totalCount));

        final hasVoted = poll.myVotes.isNotEmpty;
        if (hasVoted && !_editing) {
          return _buildVotedView(theme, poll, sortedOptions, canManage);
        }
        return _buildVotingForm(
          theme,
          poll,
          hasVoted,
          sortedOptions,
          canManage,
        );
      },
    );
  }

  Widget _buildFinalized(DateTime winningUtc) {
    final winning = winningUtc.toLocal();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateFormat('EEEE, MMMM d').format(winning),
          style: const TextStyle(fontSize: 15, height: 1.4),
        ),
        Text(
          DateFormat('h:mm a').format(winning).toLowerCase(),
          style: const TextStyle(fontSize: 15, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildVotedView(
    ThemeData theme,
    EventPoll poll,
    List<EventPollOption> sortedOptions,
    bool canManage,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('you voted ✓', style: theme.textTheme.labelLarge),
            const Spacer(),
            if (canManage)
              TextButton(
                onPressed: () => _showFinalizeSheet(poll),
                child: const Text('choose winner'),
              )
            else
              TextButton(
                onPressed: () => setState(() => _editing = true),
                child: const Text('edit vote'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        ...sortedOptions.map(
          (option) => _PollOptionResult(
            option: option,
            onVotersTap: () => _showVoters(context, option),
          ),
        ),
        if (canManage) ...[
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => setState(() => _editing = true),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'edit vote',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVotingForm(
    ThemeData theme,
    EventPoll poll,
    bool hasVoted,
    List<EventPollOption> sortedOptions,
    bool canManage,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('pick a time', style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(
          'for each option, mark yes or maybe',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        ...sortedOptions.map(
          (option) => _PollOptionRow(
            option: option,
            availability: _selected[option.id],
            isEditing: true,
            onSetAvailability: (a) => _setAvailability(option.id, a),
            onVotersTap: () => _showVoters(context, option),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            FilledButton(
              onPressed:
                  _submitting || _selected.isEmpty ? null : () => _submit(),
              child: Text(
                _submitting
                    ? 'submitting...'
                    : hasVoted
                    ? 'update vote'
                    : 'submit vote',
              ),
            ),
            if (hasVoted) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => setState(() => _editing = false),
                child: const Text('cancel'),
              ),
            ],
          ],
        ),
        if (canManage) ...[
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => _showFinalizeSheet(poll),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'choose winner',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Read-only view shown after voting: date label + yes/maybe counts with avatars.
class _PollOptionResult extends StatelessWidget {
  final EventPollOption option;
  final VoidCallback onVotersTap;

  const _PollOptionResult({required this.option, required this.onVotersTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatPollOption(option.datetime),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _CountBucket(
                icon: Icons.check_circle_outline,
                count: option.yesCount,
                voters: option.yesVoters.take(3).toList(),
                color: theme.colorScheme.primary,
                onTap: option.yesVoters.isNotEmpty ? onVotersTap : null,
              ),
              const SizedBox(width: 16),
              _CountBucket(
                icon: Icons.help_outline,
                count: option.maybeCount,
                voters: option.maybeVoters.take(3).toList(),
                color: theme.colorScheme.secondary,
                onTap: option.maybeVoters.isNotEmpty ? onVotersTap : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountBucket extends StatelessWidget {
  final IconData icon;
  final int count;
  final List<PollVoter> voters;
  final Color color;
  final VoidCallback? onTap;

  const _CountBucket({
    required this.icon,
    required this.count,
    required this.voters,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Semantics(
        button: onTap != null,
        label: 'see who voted',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 3),
            Text(
              '$count',
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
            if (voters.isNotEmpty) ...[
              const SizedBox(width: 6),
              VoterAvatarStack(voters: voters),
            ],
          ],
        ),
      ),
    );
  }
}

class _PollOptionRow extends StatelessWidget {
  final EventPollOption option;
  final String? availability;
  final bool isEditing;
  final void Function(String availability)? onSetAvailability;
  final VoidCallback onVotersTap;

  const _PollOptionRow({
    required this.option,
    required this.availability,
    required this.isEditing,
    required this.onSetAvailability,
    required this.onVotersTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final voters = option.allVoters;
    final totalCount = option.totalCount;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  formatPollOption(option.datetime),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              if (voters.isNotEmpty)
                InkWell(
                  onTap: onVotersTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Semantics(
                    button: true,
                    label: 'see who voted',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        VoterAvatarStack(voters: voters),
                        const SizedBox(width: 4),
                        Text(
                          '$totalCount',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (totalCount > 0)
                Text(
                  '$totalCount',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              AvailabilityChip(
                label: PollAvailability.yes,
                icon: Icons.check_circle_outline,
                isActive: availability == PollAvailability.yes,
                count: option.yesCount,
                onTap:
                    isEditing
                        ? () => onSetAvailability?.call(PollAvailability.yes)
                        : null,
              ),
              const SizedBox(width: 8),
              AvailabilityChip(
                label: PollAvailability.maybe,
                icon: Icons.help_outline,
                isActive: availability == PollAvailability.maybe,
                count: option.maybeCount,
                onTap:
                    isEditing
                        ? () => onSetAvailability?.call(PollAvailability.maybe)
                        : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet for picking the winning poll option.
class _FinalizeSheet extends ConsumerStatefulWidget {
  final EventPoll poll;
  final String eventId;

  const _FinalizeSheet({required this.poll, required this.eventId});

  @override
  ConsumerState<_FinalizeSheet> createState() => _FinalizeSheetState();
}

class _FinalizeSheetState extends ConsumerState<_FinalizeSheet> {
  String? _selected;
  bool _submitting = false;

  Future<void> _confirm() async {
    if (_selected == null) return;
    setState(() => _submitting = true);
    try {
      await finalizeEventPoll(
        ref: ref,
        eventId: widget.eventId,
        winningOptionId: _selected!,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showErrorSnackBar(context, 'couldn\'t finalize — try again');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final options = [...widget.poll.options]
      ..sort((a, b) => a.datetime.compareTo(b.datetime));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('choose the winning time', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'this sets the event date and closes the poll',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            ...options.map(
              (option) => InkWell(
                onTap: () => setState(() => _selected = option.id),
                borderRadius: BorderRadius.circular(8),
                child: Semantics(
                  button: true,
                  label: formatPollOption(option.datetime),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(
                          _selected == option.id
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          size: 20,
                          color:
                              _selected == option.id
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(formatPollOption(option.datetime)),
                              Text(
                                '${option.yesCount} yes · ${option.maybeCount} maybe',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton(
                  onPressed: _submitting || _selected == null ? null : _confirm,
                  child: Text(_submitting ? 'finalizing...' : 'confirm'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
