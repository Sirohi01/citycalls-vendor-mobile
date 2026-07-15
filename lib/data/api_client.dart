import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Local to this repo — no shared api-client package exists (multi-repo, per
// docs/coordination/03-code-ownership.md). Independently built from the same
// pattern as citycalls-customer-mobile's client, not shared code with it.
class ApiClient {
  static const String _accessTokenKey = 'citycalls_access_token';
  final Dio dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  ApiClient({String baseUrl = 'http://localhost:4000/api/v1'})
      : dio = Dio(BaseOptions(baseUrl: baseUrl, headers: {'Content-Type': 'application/json'})) {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: _accessTokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ));
  }

  Future<void> saveAccessToken(String token) => _storage.write(key: _accessTokenKey, value: token);
  Future<void> clearAccessToken() => _storage.delete(key: _accessTokenKey);
}
