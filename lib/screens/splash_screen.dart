import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';
import '../theme/app_theme.dart';
import 'otp_request_screen.dart';
import 'role_router.dart';

// App entry point (MaterialApp's `home` in main.dart) — same black city
// skyline splash as citycalls-customer-mobile. Restores the session
// (authProvider.restoreSession()) and lands the user in the right shell.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  // main.dart's sessionExpired listener checks this so it doesn't yank the
  // splash away while the splash is itself resolving a dead session.
  static bool bootstrapping = true;

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<Offset> _logoSlide;
  late final Animation<Offset> _taglineSlide;
  late final Animation<double> _taglineFade;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.2, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _logoSlide = Tween<Offset>(begin: const Offset(0, 0.8), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic)));
    _taglineSlide = Tween<Offset>(begin: const Offset(0, 0.6), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic)));
    _taglineFade = CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut));
    _controller.forward();

    _resolveDestination();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _resolveDestination() async {
    final stopwatch = Stopwatch()..start();
    await ref.read(authProvider.notifier).restoreSession();

    // Keep the brand moment on screen briefly even when restore is instant.
    const minDisplay = Duration(milliseconds: 2200);
    final remaining = minDisplay - stopwatch.elapsed;
    if (remaining > Duration.zero) await Future.delayed(remaining);

    SplashScreen.bootstrapping = false;
    if (!mounted) return;
    final user = ref.read(authProvider).user;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
          builder: (_) => user != null
              ? homeScreenForUser(user)
              : const OtpRequestScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FadeTransition(
        opacity: _fade,
        child: Stack(
          children: [
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child:
                  Image.asset('assets/login/splace.png', fit: BoxFit.fitWidth),
            ),
            Align(
              alignment: const Alignment(0, -0.30),
              child: ScaleTransition(
                scale: _scale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SlideTransition(
                      position: _logoSlide,
                      child: Image.asset('assets/images/logo.png',
                          height: 80, fit: BoxFit.contain),
                    ),
                    const SizedBox(height: 12),
                    SlideTransition(
                      position: _taglineSlide,
                      child: FadeTransition(
                        opacity: _taglineFade,
                        child: const Column(
                          children: [
                            Text('Field Partner',
                                style: TextStyle(
                                    color: AppColors.lime500,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 2)),
                            SizedBox(height: 6),
                            Text('For technicians & service partners',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
