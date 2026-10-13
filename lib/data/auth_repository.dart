import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_client.dart';
import '../models/auth_models.dart';

class AuthException implements Exception {
  final String message;
  final List<ApiFieldError> errors;
  AuthException(this.message, this.errors);
  @override
  String toString() => message;
}

// One repository class per module, per docs/12-frontend-data-contracts.md §3.
class AuthRepository {
  static const _cachedUserKey = 'citycalls_vendor_cached_user';
  static const _rememberedMobileKey = 'citycalls_vendor_remembered_mobile';
  static const _storage = FlutterSecureStorage();

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
      final res = await _client.dio
          .post('/auth/otp/verify', data: {'mobile': mobile, 'otp': otp});
      final loginResponse =
          LoginResponse.fromJson(res.data['data'] as Map<String, dynamic>);
      await _client.saveTokens(
          loginResponse.accessToken, loginResponse.refreshToken);
      return loginResponse;
    } on DioException catch (e) {
      throw _toAuthException(e, 'Incorrect or expired OTP.');
    }
  }

  AuthException _toAuthException(DioException e, String fallback) {
    final body = e.response?.data;
    if (body is Map<String, dynamic>) {
      final errors = body['errors'] is List
          ? (body['errors'] as List)
              .map((e) => ApiFieldError.fromJson(e as Map<String, dynamic>))
              .toList()
          : <ApiFieldError>[];
      return AuthException(body['message'] as String? ?? fallback, errors);
    }
    return AuthException(
        'Unable to reach the server. Please check your connection.', []);
  }

  Future<AuthUser> getMe() async {
    final res = await _client.dio.get('/auth/me');
    return AuthUser.fromMeJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<void> logout() async {
    await _client.clearAccessToken();
    await clearCachedUser();
  }

  // The signed-in user, kept on the device so a technician who opens the
  // app with no signal still lands in their shell (with their queued
  // offline actions) instead of being bounced to login.
  Future<void> cacheUser(AuthUser user) async {
    try {
      await _storage.write(
          key: _cachedUserKey, value: jsonEncode(user.toJson()));
    } catch (_) {}
  }

  Future<AuthUser?> readCachedUser() async {
    try {
      final raw = await _storage.read(key: _cachedUserKey);
      if (raw == null) return null;
      return AuthUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearCachedUser() async {
    try {
      await _storage.delete(key: _cachedUserKey);
    } catch (_) {}
  }

  // Number of the last successful login on this phone — the login screen
  // offers it back as "Continue with +91 …", same as the customer app.
  Future<String?> readRememberedMobile() async {
    try {
      return await _storage.read(key: _rememberedMobileKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveRememberedMobile(String mobile) async {
    try {
      await _storage.write(key: _rememberedMobileKey, value: mobile);
    } catch (_) {}
  }
}
