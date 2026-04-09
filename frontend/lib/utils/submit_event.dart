import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pda/providers/auth_provider.dart';
import 'package:pda/providers/event_provider.dart';
import 'package:pda/screens/calendar/event_form_result.dart';
import 'package:pda/utils/create_datetime_poll.dart';

/// Submits a new event via the API, uploads the photo if provided,
/// creates a datetime poll if options were specified, then invalidates
/// the events cache. Returns the ID of the newly created event.
Future<String> submitNewEvent(WidgetRef ref, EventFormResult result) async {
  final api = ref.read(apiClientProvider);
  final response = await api.post('/api/community/events/', data: result.data);
  final eventId = (response.data as Map<String, dynamic>)['id'] as String;
  if (result.photo != null) {
    await uploadEventPhoto(ref, eventId, result.photo!);
  }
  if (result.datetimePollOptions.isNotEmpty) {
    await createDatetimePoll(
      ref: ref,
      eventId: eventId,
      eventTitle: result.data['title'] as String,
      options: result.datetimePollOptions,
    );
  }
  ref.invalidate(eventsProvider);
  return eventId;
}
