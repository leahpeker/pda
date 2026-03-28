import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pda/providers/auth_provider.dart';
import 'package:pda/providers/home_provider.dart';
import 'package:pda/services/api_client.dart';
import 'package:pda/services/secure_storage.dart';
import 'package:dio/dio.dart';

import '../helpers/fake_secure_storage.dart';

class MockApiClient extends Mock implements ApiClient {}

final _homeJson = {
  'content': '# Welcome to PDA',
  'join_content': 'Join us today',
  'donate_url': 'https://example.com/donate',
  'updated_at': '2026-01-01T00:00:00Z',
};

void main() {
  late MockApiClient mockApi;
  late ProviderContainer container;

  setUp(() {
    mockApi = MockApiClient();
    container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(
          SecureStorageService.withStorage(FakeSecureStorage()),
        ),
        apiClientProvider.overrideWithValue(mockApi),
      ],
    );
  });

  tearDown(() => container.dispose());

  group('HomePageNotifier', () {
    test('build loads content and donateUrl from API', () async {
      when(() => mockApi.get('/api/community/home/')).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/api/community/home/'),
          statusCode: 200,
          data: _homeJson,
        ),
      );

      final result = await container.read(homePageNotifierProvider.future);
      expect(result.content, '# Welcome to PDA');
      expect(result.donateUrl, 'https://example.com/donate');
      expect(result.joinContent, 'Join us today');
    });

    test('donateUrl defaults to empty string when null in JSON', () async {
      when(() => mockApi.get('/api/community/home/')).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/api/community/home/'),
          statusCode: 200,
          data: {
            'content': '',
            'join_content': '',
            'donate_url': null,
            'updated_at': '2026-01-01T00:00:00Z',
          },
        ),
      );

      final result = await container.read(homePageNotifierProvider.future);
      expect(result.donateUrl, '');
    });

    test('saveContent patches API and updates state', () async {
      when(() => mockApi.get('/api/community/home/')).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/api/community/home/'),
          statusCode: 200,
          data: _homeJson,
        ),
      );
      when(
        () => mockApi.patch('/api/community/home/', data: any(named: 'data')),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/api/community/home/'),
          statusCode: 200,
          data: {
            'content': 'New content',
            'join_content': 'Join us today',
            'donate_url': 'https://example.com/donate',
            'updated_at': '2026-02-01T00:00:00Z',
          },
        ),
      );

      await container.read(homePageNotifierProvider.future);
      await container
          .read(homePageNotifierProvider.notifier)
          .saveContent('New content');

      final state = container.read(homePageNotifierProvider);
      expect(state.value?.content, 'New content');
    });

    test('saveDonateUrl patches API and updates state', () async {
      when(() => mockApi.get('/api/community/home/')).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/api/community/home/'),
          statusCode: 200,
          data: _homeJson,
        ),
      );
      when(
        () => mockApi.patch('/api/community/home/', data: any(named: 'data')),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/api/community/home/'),
          statusCode: 200,
          data: {
            'content': '# Welcome to PDA',
            'join_content': 'Join us today',
            'donate_url': 'https://new-donate.example.com',
            'updated_at': '2026-02-01T00:00:00Z',
          },
        ),
      );

      await container.read(homePageNotifierProvider.future);
      await container
          .read(homePageNotifierProvider.notifier)
          .saveDonateUrl('https://new-donate.example.com');

      final state = container.read(homePageNotifierProvider);
      expect(state.value?.donateUrl, 'https://new-donate.example.com');
    });
  });
}
