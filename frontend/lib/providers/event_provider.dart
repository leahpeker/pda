import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:pda/models/event.dart';
import 'package:pda/providers/auth_provider.dart';

final _log = Logger('EventProvider');

final eventsProvider = FutureProvider<List<Event>>((ref) async {
  // Re-fetch when auth state changes so authenticated users see private fields.
  ref.watch(authProvider);
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.get('/api/community/events/');
    final list = response.data as List<dynamic>;
    final events =
        list.map((e) => Event.fromJson(e as Map<String, dynamic>)).toList();
    _log.info('Loaded ${events.length} events');
    return events;
  } catch (e) {
    _log.warning('Failed to load events', e);
    rethrow;
  }
});
