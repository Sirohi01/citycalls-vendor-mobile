import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';
import 'providers/theme_provider.dart';

@pragma('vm-entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase isn't registered for this app's package
  // (com.citycalls.citycalls_vendor) yet — no google-services.json checked
  // in, so initializeApp() throws until that's added (mirrors exactly the
  // gap citycalls-customer-mobile had before its own Firebase Android
  // registration). Guarded so the rest of the app still boots and works —
  // push notifications simply won't fire until that config lands; nothing
  // else depends on Firebase.
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
  } catch (_) {
    // See comment above.
  }
  runApp(const ProviderScope(child: CityCallsVendorApp()));
}

class CityCallsVendorApp extends ConsumerWidget {
  const CityCallsVendorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'CityCalls Field',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      home: const SplashScreen(),
    );
  }
}
