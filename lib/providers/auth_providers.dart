import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/api_client.dart';
import '../data/auth_repository.dart';
import '../models/auth_models.dart';

// Compile-time override for staging/prod: flutter run/build
// --dart-define=API_BASE_URL=https://api.citycalls.example/api/v1
const _apiBaseUrl = String.fromEnvironment('API_BASE_URL',
    defaultValue: 'https://nenita-untoured-nonhesitantly.ngrok-free.dev/api/v1');

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(baseUrl: _apiBaseUrl);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});

// Only these roles have the Employee record + scoping this app is actually
// built against ('/employees/me', assigneeType EMPLOYEE) — VENDOR_OWNER/
// VENDOR_MANAGER/VENDOR_TECHNICIAN exist as roles in the backend (outsourced
// partners, keyed off VendorModel not EmployeeModel) but nothing in this app
// resolves a Vendor's own profile/jobs yet, so they're deliberately rejected
// here with a clear message rather than silently landing in a broken app.
const _supportedRoles = {'EMPLOYEE', 'TECHNICIAN'};

enum AuthStep { enterMobile, otpSent, loggedIn }

class AuthState {
  final AuthStep step;
  final bool isLoading;
  final String? errorMessage;
  final String? mobile;
  final AuthUser? user;
  // Splash waits on this before deciding Login vs MainShell — distinct from
  // isLoading, which only covers an in-flight OTP submission.
  final bool sessionChecked;

  const AuthState({
    this.step = AuthStep.enterMobile,
    this.isLoading = false,
    this.errorMessage,
    this.mobile,
    this.user,
    this.sessionChecked = false,
  });

  AuthState copyWith({AuthStep? step, bool? isLoading, String? errorMessage, String? mobile, AuthUser? user, bool? sessionChecked}) {
    return AuthState(
      step: step ?? this.step,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      mobile: mobile ?? this.mobile,
      user: user ?? this.user,
      sessionChecked: sessionChecked ?? this.sessionChecked,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  final ApiClient _client;
  AuthNotifier(this._repository, this._client) : super(const AuthState());

  Future<void> requestOtp(String mobile) async {
    state = state.copyWith(isLoading: true, errorMessage: null, mobile: mobile);
    try {
      await _repository.requestOtp(mobile);
      state = state.copyWith(isLoading: false, step: AuthStep.otpSent);
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(isLoading: false, errorMessage: 'Failed to connect to the server.');
    }
  }

  Future<void> verifyOtp(String otp) async {
    final mobile = state.mobile;
    if (mobile == null) return;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final result = await _repository.verifyOtp(mobile, otp);
      if (!_supportedRoles.contains(result.user.role)) {
        await _client.clearAccessToken();
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'This number isn\'t registered as a technician. Contact your admin.',
        );
        return;
      }
      state = state.copyWith(isLoading: false, step: AuthStep.loggedIn, user: result.user, sessionChecked: true);
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(isLoading: false, errorMessage: 'Failed to connect to the server.');
    }
  }

  void backToMobileEntry() {
    state = state.copyWith(step: AuthStep.enterMobile, errorMessage: null);
  }

  // Called once from the splash screen — a stored token doesn't prove it's
  // still valid (could be expired/revoked server-side), so this round-trips
  // through GET /auth/me rather than trusting the token's mere presence.
  Future<void> restoreSession() async {
    try {
      final token = await _client.readAccessToken();
      if (token == null) {
        state = state.copyWith(sessionChecked: true);
        return;
      }
      final user = await _repository.getMe();
      if (!_supportedRoles.contains(user.role)) {
        await _client.clearAccessToken();
        state = state.copyWith(sessionChecked: true);
        return;
      }
      state = state.copyWith(user: user, step: AuthStep.loggedIn, sessionChecked: true);
    } catch (_) {
      // Covers both "session invalid/expired" (clear it) and "secure storage
      // itself unavailable" (e.g. no platform channel in a widget test) —
      // either way, fail safe to the login screen rather than leaving the
      // splash screen spinning forever.
      await _client.clearAccessToken().catchError((_) {});
      state = state.copyWith(sessionChecked: true);
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthState(sessionChecked: true);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider), ref.watch(apiClientProvider));
});
