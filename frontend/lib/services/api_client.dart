import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'package:pda/config/api_config.dart';
import 'package:pda/services/secure_storage.dart';

final _log = Logger('ApiClient');

class ApiClient {
  late final Dio _dio;
  final SecureStorageService _storage;

  ApiClient(this._storage) {
    _dio = Dio(BaseOptions(baseUrl: apiBaseUrl));

    // Logging interceptor — logs request/response/error without sensitive data.
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          _log.info('${options.method} ${options.path}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          _log.info(
            '${response.requestOptions.method} ${response.requestOptions.path}'
            ' -> ${response.statusCode}',
          );
          return handler.next(response);
        },
        onError: (error, handler) {
          _log.warning(
            '${error.requestOptions.method} ${error.requestOptions.path}'
            ' -> ${error.response?.statusCode ?? "no response"}',
          );
          return handler.next(error);
        },
      ),
    );

    // Auth interceptor — adds JWT and handles token refresh.
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            final refreshed = await _tryRefresh();
            if (refreshed) {
              final token = await _storage.getAccessToken();
              error.requestOptions.headers['Authorization'] = 'Bearer $token';
              final response = await _dio.fetch(error.requestOptions);
              return handler.resolve(response);
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  Future<bool> _tryRefresh() async {
    final refresh = await _storage.getRefreshToken();
    if (refresh == null) return false;
    try {
      final response = await Dio(
        BaseOptions(baseUrl: apiBaseUrl),
      ).post('/api/auth/refresh/', data: {'refresh': refresh});
      await _storage.saveTokens(
        access: response.data['access'] as String,
        refresh: refresh,
      );
      return true;
    } catch (_) {
      await _storage.clearTokens();
      return false;
    }
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) =>
      _dio.get(path, queryParameters: queryParameters);

  Future<Response> post(String path, {dynamic data}) =>
      _dio.post(path, data: data);

  Future<Response> patch(String path, {dynamic data}) =>
      _dio.patch(path, data: data);

  Future<Response> delete(String path) => _dio.delete(path);
}
