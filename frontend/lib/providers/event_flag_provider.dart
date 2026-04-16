import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:pda/models/event_flag.dart';
import 'package:pda/providers/auth_provider.dart';

final _log = Logger('EventFlagProvider');

final eventFlagsProvider = FutureProvider.family<List<EventFlag>, String?>((
  ref,
  status,
) async {
  ref.watch(authProvider);
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.get(
      '/api/community/event-flags/',
      queryParameters: status != null ? {'status': status} : null,
    );
    final list = response.data as List<dynamic>;
    return list
        .map((e) => EventFlag.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (e) {
    _log.warning('Failed to load event flags', e);
    rethrow;
  }
});

Future<void> flagEvent(WidgetRef ref, String eventId, String reason) async {
  final api = ref.read(apiClientProvider);
  await api.post(
    '/api/community/events/$eventId/flag/',
    data: {'reason': reason},
  );
  ref.invalidate(eventFlagsProvider(null));
}

Future<void> updateFlagStatus(
  WidgetRef ref,
  String flagId,
  String status,
) async {
  final api = ref.read(apiClientProvider);
  await api.patch(
    '/api/community/event-flags/$flagId/',
    data: {'status': status},
  );
  ref.invalidate(eventFlagsProvider(null));
  ref.invalidate(eventFlagsProvider('pending'));
  ref.invalidate(eventFlagsProvider('dismissed'));
  ref.invalidate(eventFlagsProvider('actioned'));
}
