import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pda/models/survey.dart';
import 'package:pda/providers/auth_provider.dart';

/// Fetches a public survey by slug (with questions).
final surveyBySlugProvider = FutureProvider.family<Survey, String>((
  ref,
  slug,
) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get('/api/community/surveys/$slug/');
  return Survey.fromJson(response.data as Map<String, dynamic>);
});
