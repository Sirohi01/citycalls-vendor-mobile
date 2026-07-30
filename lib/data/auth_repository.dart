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

  // OTP login (no password) — matches citycalls-customer-mobile's flow.
  // Unlike the customer app, verifyOtp does NOT auto-create a new account
  // for an unrecognized mobile in a useful way here: the backend's
  // verifyOtp() auto-creates a CUSTOMER for any never-seen mobile
  // (auth.service.ts), which would silently log a mistyped/wrong number
  // into this app as a customer with no Employee record. The caller
  // (auth_providers.dart) checks `role` after verify and rejects non
  // EMPLOYEE/TECHNICIAN accounts rather than trusting verify's mere success.
  Future<void> requestOtp(String mobile) async {
    try {
      await _client.dio.post('/auth/otp/request', data: {'mobile': mobile});
    } on DioException catch (e) {
      throw _toAuthException(e, 'Failed to send OTP. Please try again.');
    }
  }

  Future<LoginResponse> verifyOtp(String mobile, String otp) async {
    try {
      final res = await _client.dio.post('/auth/otp/verify', data: {'mobile': mobile, 'otp': otp});
      final loginResponse = LoginResponse.fromJson(res.data['data'] as Map<String, dynamic>);
      await _client.saveAccessToken(loginResponse.accessToken);
      return loginResponse;
    } on DioException catch (e) {
      throw _toAuthException(e, 'Incorrect or expired OTP.');
    }
  }

  AuthException _toAuthException(DioException e, String fallback) {
    final body = e.response?.data;
    if (body is Map<String, dynamic> && body['errors'] != null) {
      final errors = (body['errors'] as List).map((e) => ApiFieldError.fromJson(e as Map<String, dynamic>)).toList();
      return AuthException(body['message'] as String? ?? fallback, errors);
    }
    return AuthException('Unable to reach the server. Please check your connection.', []);
  }

  Future<AuthUser> getMe() async {
    final res = await _client.dio.get('/auth/me');
    return AuthUser.fromMeJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<void> logout() => _client.clearAccessToken();
}
