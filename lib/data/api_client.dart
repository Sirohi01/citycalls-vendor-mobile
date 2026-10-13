import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Local to this repo — no shared api-client package exists (multi-repo, per
// docs/coordination/03-code-ownership.md). Independently built from the same
// pattern as citycalls-customer-mobile's client, not shared code with it.
class ApiClient {
  static const String _accessTokenKey = 'citycalls_access_token';
  static const String _refreshTokenKey = 'citycalls_refresh_token';
  static const String _retriedFlag = 'tokenRefreshRetried';
  final Dio dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  Future<String?>? _refreshingAccessToken;

  // Flipped to true once the server has rejected the refresh token and the
  // session is over. main.dart listens and sends the technician back to
  // login — otherwise every screen just shows an error forever.
  final ValueNotifier<bool> sessionExpired = ValueNotifier(false);

  // No default here on purpose — the base URL is configured in one place
  // only, auth_providers.dart's `_apiBaseUrl`.
  ApiClient({required String baseUrl})
      : dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          headers: {'Content-Type': 'application/json'},
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        )) {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await readAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final request = error.requestOptions;
        final shouldRefresh = error.response?.statusCode == 401 &&
            request.extra[_retriedFlag] != true &&
            !request.path.contains('/auth/refresh') &&
            !request.path.contains('/auth/otp/');
        if (!shouldRefresh) {
          handler.next(error);
          return;
        }

        // Share one refresh across simultaneous expired requests. Refresh
        // tokens rotate, so racing separate refresh calls would invalidate
        // each other and incorrectly log the technician out.
        final newAccessToken = await _refreshAccessToken();
        if (newAccessToken == null) {
          handler.next(error);
          return;
        }

        try {
          request.headers['Authorization'] = 'Bearer $newAccessToken';
          request.extra[_retriedFlag] = true;
          handler.resolve(await dio.fetch(request));
        } on DioException catch (e) {
          handler.next(e);
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
    if (refreshToken == null) {
      await _endSession();
      return null;
    }

    try {
      // A separate client avoids recursively invoking the main interceptor.
      final response =
          await Dio(BaseOptions(baseUrl: dio.options.baseUrl)).post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final data = response.data['data'] as Map<String, dynamic>;
      final accessToken = data['accessToken'] as String;
      await saveTokens(accessToken, data['refreshToken'] as String);
      return accessToken;
    } on DioException catch (e) {
      // Only a real server rejection ends the session. A technician in a
      // basement with no signal must stay logged in — their queued offline
      // actions (sync_engine.dart) still need this session to flush later.
      if (e.response != null) await _endSession();
      return null;
    }
  }

  Future<void> _endSession() async {
    await clearTokens();
    sessionExpired.value = true;
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

  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);
}
