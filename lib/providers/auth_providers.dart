import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/api_client.dart';
import '../data/auth_repository.dart';
import '../models/auth_models.dart';

// The ONLY place the API base URL is set (ApiClient has no default). Live by
// default; override for local/staging builds with
//   flutter run --dart-define=API_BASE_URL=http://<mac-ip>:4000/api/v1
const _apiBaseUrl = String.fromEnvironment('API_BASE_URL',
    defaultValue: 'https://api.citycalls.in/api/v1');

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(baseUrl: _apiBaseUrl);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});

// Per docs/manish/09-vendor-app-functional-plan.md §6: this binary serves
// Employee and Vendor Technician roles (same execution screens, scoped by
// assigneeType EMPLOYEE vs VENDOR server-side) — VENDOR_OWNER/VENDOR_MANAGER
// are a distinct, non-field-work role (company roster/dashboard/payouts,
// see role_router.dart) but log into the same app.
const _supportedRoles = {
  'EMPLOYEE',
  'TECHNICIAN',
  'VENDOR_OWNER',
  'VENDOR_MANAGER',
  'VENDOR_TECHNICIAN'
};

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

  AuthState copyWith(
      {AuthStep? step,
      bool? isLoading,
      String? errorMessage,
      String? mobile,
      AuthUser? user,
      bool? sessionChecked}) {
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
      state = state.copyWith(
          isLoading: false, errorMessage: 'Failed to connect to the server.');
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
          errorMessage:
              'This number isn\'t registered as a technician or vendor. Contact your admin.',
        );
        return;
      }
      await _repository.cacheUser(result.user);
      await _repository.saveRememberedMobile(mobile);
      state = state.copyWith(
          isLoading: false,
          step: AuthStep.loggedIn,
          user: result.user,
          sessionChecked: true);
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(
          isLoading: false, errorMessage: 'Failed to connect to the server.');
    }
  }

  void backToMobileEntry() {
    state = state.copyWith(step: AuthStep.enterMobile, errorMessage: null);
  }

  // Called once from the splash screen — a stored token doesn't prove it's
  // still valid (could be expired/revoked server-side), so this round-trips
  // through GET /auth/me rather than trusting the token's mere presence.
  //
  // A network failure is NOT a logout: a field technician often opens the
  // app with no signal, and their offline queue needs the session. In that
  // case the last signed-in user (cached at login) is restored; only a real
  // server rejection (handled by ApiClient's refresh) ends the session.
  Future<void> restoreSession() async {
    try {
      final refreshToken = await _client.readRefreshToken();
      if (refreshToken == null) {
        state = state.copyWith(sessionChecked: true);
        return;
      }
      final user =
          await _repository.getMe().timeout(const Duration(seconds: 10));
      if (!_supportedRoles.contains(user.role)) {
        await _repository.logout();
        state = state.copyWith(sessionChecked: true);
        return;
      }
      await _repository.cacheUser(user);
      state = state.copyWith(
          user: user, step: AuthStep.loggedIn, sessionChecked: true);
    } catch (e) {
      final serverRejected = e is DioException && e.response != null;
      final cached = serverRejected ? null : await _repository.readCachedUser();
      if (cached != null && await _client.readRefreshToken() != null) {
        state = state.copyWith(
            user: cached, step: AuthStep.loggedIn, sessionChecked: true);
        return;
      }
      if (serverRejected) {
        await _repository.logout().catchError((_) {});
      }
      state = state.copyWith(sessionChecked: true);
    }
  }

  // ApiClient already cleared the tokens; drop the in-memory user too.
  void sessionEnded() {
    _repository.clearCachedUser();
    state = const AuthState(sessionChecked: true);
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthState(sessionChecked: true);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
      ref.watch(authRepositoryProvider), ref.watch(apiClientProvider));
});
