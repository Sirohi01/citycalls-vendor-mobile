import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_navigator.dart';
import 'data/api_client.dart';
import 'providers/auth_providers.dart';
import 'screens/otp_request_screen.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
  } catch (_) {
    // No google-services.json / GoogleService-Info.plist bundled in this
    // build — the app still works, it just can't receive push
    // notifications (push_notification_service.dart checks Firebase.apps).
  }
  runApp(const ProviderScope(child: CityCallsVendorApp()));
}

class CityCallsVendorApp extends ConsumerStatefulWidget {
  const CityCallsVendorApp({super.key});

  @override
  ConsumerState<CityCallsVendorApp> createState() => _CityCallsVendorAppState();
}

class _CityCallsVendorAppState extends ConsumerState<CityCallsVendorApp> {
  // Held directly rather than re-read in dispose(): this is the root widget,
  // so its dispose runs while the ProviderScope is itself being torn down.
  late final ApiClient _apiClient;

  @override
  void initState() {
    super.initState();
    _apiClient = ref.read(apiClientProvider);
    _apiClient.sessionExpired.addListener(_onSessionExpired);
  }

  @override
  void dispose() {
    _apiClient.sessionExpired.removeListener(_onSessionExpired);
    super.dispose();
  }

  // The server rejected the refresh token — the session is really over, so
  // send the technician back to login with a message instead of leaving
  // every screen stuck on an error.
  void _onSessionExpired() {
    if (!_apiClient.sessionExpired.value) return;
    _apiClient.sessionExpired.value = false;
    // SplashScreen handles a missing/expired session on first load itself.
    if (SplashScreen.bootstrapping) return;
    ref.read(authProvider.notifier).sessionEnded();
    appNavigator?.pushAndRemoveUntil(
      MaterialPageRoute(
          builder: (_) => const OtpRequestScreen(sessionExpired: true)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CityCalls Field',
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      themeMode: ThemeMode.light,
      home: const SplashScreen(),
    );
  }
}
