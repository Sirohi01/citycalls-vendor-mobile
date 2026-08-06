import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Local to this repo — no shared api-client package exists (multi-repo, per
// docs/coordination/03-code-ownership.md). Independently built from the same
// pattern as citycalls-customer-mobile's client, not shared code with it.
class ApiClient {
  static const String _accessTokenKey = 'citycalls_access_token';
  static const String _refreshTokenKey = 'citycalls_refresh_token';
  final Dio dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  Future<String?>? _refreshingAccessToken;

  ApiClient(
      {String baseUrl =
          'https://nenita-untoured-nonhesitantly.ngrok-free.dev/api/v1'})
      : dio = Dio(BaseOptions(
            baseUrl: baseUrl, headers: {'Content-Type': 'application/json'})) {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: _accessTokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final request = error.requestOptions;
        final shouldRefresh = error.response?.statusCode == 401 &&
            request.extra['tokenRefreshRetried'] != true &&
            !request.path.contains('/auth/refresh') &&
            !request.path.contains('/auth/otp/');
        if (!shouldRefresh) {
          handler.next(error);
          return;
        }

        try {
          // Share one refresh across simultaneous expired requests. Refresh
          // tokens rotate, so racing separate refresh calls would invalidate
          // each other and incorrectly log the technician out.
          final newAccessToken = await _refreshAccessToken();
          if (newAccessToken == null) {
            handler.next(error);
            return;
          }

          request.headers['Authorization'] = 'Bearer $newAccessToken';
          request.extra['tokenRefreshRetried'] = true;
          handler.resolve(await dio.fetch(request));
        } catch (_) {
          await clearTokens();
          handler.next(error);
        }
      },
    ));
  }

  Future<String?> _refreshAccessToken() {
    final activeRefresh = _refreshingAccessToken;
    if (activeRefresh != null) return activeRefresh;

    final refresh = _performTokenRefresh();
    _refreshingAccessToken = refresh;
    return refresh.whenComplete(() => _refreshingAccessToken = null);
  }

  Future<String?> _performTokenRefresh() async {
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    if (refreshToken == null) return null;

    // A separate client avoids recursively invoking the main interceptor.
    final response = await Dio(BaseOptions(baseUrl: dio.options.baseUrl)).post(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
    );
    final data = response.data['data'] as Map<String, dynamic>;
    final accessToken = data['accessToken'] as String;
    await saveTokens(accessToken, data['refreshToken'] as String);
    return accessToken;
  }

  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<void> clearAccessToken() => clearTokens();

  Future<void> clearTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);
}
