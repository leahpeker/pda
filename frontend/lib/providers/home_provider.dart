import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pda/providers/auth_provider.dart';
import 'package:pda/providers/guidelines_provider.dart';

class HomePageNotifier extends AsyncNotifier<Guidelines> {
  @override
  Future<Guidelines> build() async {
    final api = ref.read(apiClientProvider);
    final response = await api.get('/api/community/home/');
    return Guidelines.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> saveContent(String content) async {
    final api = ref.read(apiClientProvider);
    final response = await api.patch(
      '/api/community/home/',
      data: {'content': content},
    );
    state = AsyncData(
      Guidelines.fromJson(response.data as Map<String, dynamic>),
    );
  }
}

final homePageNotifierProvider =
    AsyncNotifierProvider<HomePageNotifier, Guidelines>(HomePageNotifier.new);
