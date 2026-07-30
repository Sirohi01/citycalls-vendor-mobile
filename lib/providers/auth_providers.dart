import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/api_client.dart';
import '../data/auth_repository.dart';
import '../models/auth_models.dart';

// Compile-time override for staging/prod: flutter run/build
// --dart-define=API_BASE_URL=https://api.citycalls.example/api/v1
const _apiBaseUrl = String.fromEnvironment('API_BASE_URL',
    defaultValue:
        'https://nenita-untoured-nonhesitantly.ngrok-free.dev/api/v1');

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(baseUrl: _apiBaseUrl);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});

class AuthState {
  final bool isLoading;
  final String? errorMessage;
  final AuthUser? user;
  // Splash waits on this before deciding Login vs MainShell — distinct from
  // isLoading, which only covers an in-flight login submission.
  final bool sessionChecked;

  const AuthState(
      {this.isLoading = false,
      this.errorMessage,
      this.user,
      this.sessionChecked = false});

  AuthState copyWith(
      {bool? isLoading,
      String? errorMessage,
      AuthUser? user,
      bool? sessionChecked}) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      user: user ?? this.user,
      sessionChecked: sessionChecked ?? this.sessionChecked,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  final ApiClient _client;
  AuthNotifier(this._repository, this._client) : super(const AuthState());

  Future<void> login(String identifier, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final result = await _repository.login(identifier, password);
      state = state.copyWith(
          isLoading: false, user: result.user, sessionChecked: true);
    } on AuthException catch (e) {
      state = AuthState(
          isLoading: false, errorMessage: e.message, sessionChecked: true);
    }
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
      state = state.copyWith(user: user, sessionChecked: true);
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
  return AuthNotifier(
      ref.watch(authRepositoryProvider), ref.watch(apiClientProvider));
});
