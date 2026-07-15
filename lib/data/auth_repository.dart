import 'package:dio/dio.dart';
import 'api_client.dart';
import '../models/auth_models.dart';

class AuthException implements Exception {
  final String message;
  final List<ApiFieldError> errors;
  AuthException(this.message, this.errors);
}

// One repository class per module, per docs/12-frontend-data-contracts.md §3.
class AuthRepository {
  final ApiClient _client;
  AuthRepository(this._client);

  Future<LoginResponse> login(String identifier, String password) async {
    try {
      final res = await _client.dio.post('/auth/login', data: {
        'identifier': identifier,
        'password': password,
      });
      final loginResponse = LoginResponse.fromJson(res.data['data'] as Map<String, dynamic>);
      await _client.saveAccessToken(loginResponse.accessToken);
      return loginResponse;
    } on DioException catch (e) {
      final body = e.response?.data;
      if (body is Map<String, dynamic> && body['errors'] != null) {
        final errors = (body['errors'] as List)
            .map((e) => ApiFieldError.fromJson(e as Map<String, dynamic>))
            .toList();
        throw AuthException(body['message'] as String? ?? 'Login failed', errors);
      }
      throw AuthException('Unable to reach the server. Please check your connection.', []);
    }
  }

  Future<void> logout() => _client.clearAccessToken();
}
