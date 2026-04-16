import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:logging/logging.dart';
import 'package:pda/config/constants.dart';
import 'package:pda/models/event_flag.dart';
import 'package:pda/providers/event_flag_provider.dart';
import 'package:pda/services/api_error.dart';
import 'package:pda/utils/snackbar.dart';
import 'package:pda/widgets/app_scaffold.dart';

final _log = Logger('FlaggedEvents');

const _filterLabels = ['all', 'pending', 'dismissed', 'actioned'];

class FlaggedEventsScreen extends ConsumerStatefulWidget {
  const FlaggedEventsScreen({super.key});

  @override
  ConsumerState<FlaggedEventsScreen> createState() =>
      _FlaggedEventsScreenState();
}

class _FlaggedEventsScreenState extends ConsumerState<FlaggedEventsScreen> {
  String _selectedFilter = 'pending';

  String? get _apiFilter => _selectedFilter == 'all' ? null : _selectedFilter;

  String _emptyMessage() => switch (_selectedFilter) {
    'pending' => 'nothing flagged right now 🌿',
    'dismissed' => 'no dismissed flags',
    'actioned' => 'no actioned flags',
    _ => 'no flags yet 🌿',
  };

  Future<void> _dismiss(EventFlag flag) async {
    try {
      await updateFlagStatus(ref, flag.id, EventFlagStatus.dismissed);
    } catch (e, st) {
      _log.warning('failed to dismiss flag ${flag.id}', e, st);
      if (mounted) showErrorSnackBar(context, ApiError.from(e).message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final flagsAsync = ref.watch(eventFlagsProvider(_apiFilter));

    return AppScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FilterChips(
            selected: _selectedFilter,
            onSelected: (f) => setState(() => _selectedFilter = f),
          ),
          Expanded(
            child: flagsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => const Center(
                child: Text("couldn't load flagged events — try refreshing"),
              ),
              data: (flags) {
                if (flags.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        _emptyMessage(),
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemCount: flags.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final flag = flags[index];
                    return _FlagCard(
                      flag: flag,
                      onDismiss: flag.status == EventFlagStatus.pending
                          ? () => _dismiss(flag)
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const _FilterChips({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Wrap(
        spacing: 8,
        children: _filterLabels.map((filter) {
          final isSelected = selected == filter;
          return FilterChip(
            label: Text(filter),
            selected: isSelected,
            showCheckmark: false,
            onSelected: (_) => onSelected(filter),
          );
        }).toList(),
      ),
    );
  }
}

class _FlagCard extends StatelessWidget {
  final EventFlag flag;
  final VoidCallback? onDismiss;

  const _FlagCard({required this.flag, this.onDismiss});

  Color _statusColor(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return switch (flag.status) {
      EventFlagStatus.dismissed => cs.onSurfaceVariant,
      EventFlagStatus.actioned => cs.primary,
      _ => cs.tertiary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('MMM d, yyyy');
    final statusColor = _statusColor(context);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => context.push('/events/${flag.eventId}'),
                    borderRadius: BorderRadius.circular(4),
                    child: Text(
                      flag.eventTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _StatusBadge(status: flag.status, color: statusColor),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'flagged by ${flag.flaggedByName}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              flag.reason,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dateFmt.format(flag.createdAt.toLocal()),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (onDismiss != null)
                  OutlinedButton(
                    onPressed: onDismiss,
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('dismiss'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final Color color;

  const _StatusBadge({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
