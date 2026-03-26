import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pda/models/event.dart';
import 'package:pda/providers/event_provider.dart';
import 'package:pda/screens/calendar/event_detail_panel.dart';
import 'package:pda/widgets/app_scaffold.dart';

class EventDetailScreen extends ConsumerWidget {
  final String eventId;

  const EventDetailScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsProvider);

    return AppScaffold(
      child: eventsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load event: $e')),
        data: (events) {
          final Event? event = events.cast<Event?>().firstWhere(
            (e) => e?.id == eventId,
            orElse: () => null,
          );
          if (event == null) {
            return const Center(child: Text('Event not found.'));
          }
          return EventDetailContent(event: event, fullPage: true);
        },
      ),
    );
  }
}
