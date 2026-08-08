import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/glow_blob.dart';
import 'otp_request_screen.dart';
import 'role_router.dart';

// App entry point (set as MaterialApp's `home` in main.dart). Decides where
// to land the technician — MainShell if a saved access token still resolves
// to a supported EMPLOYEE/TECHNICIAN account, OtpRequestScreen otherwise.
// Also where session restore happens (authProvider.restoreSession()).
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.9, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
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

    // Keep the splash on screen for at least this long so the brand moment
    // registers even when session-restore resolves near-instantly (e.g. no
    // token stored, so no network round trip at all).
    const minDisplay = Duration(milliseconds: 900);
    final remaining = minDisplay - stopwatch.elapsed;
    if (remaining > Duration.zero) await Future.delayed(remaining);

    if (!mounted) return;
    final user = ref.read(authProvider).user;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => user != null ? homeScreenForUser(user) : const OtpRequestScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate950,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.slate950, AppColors.slate900, AppColors.slate950],
              ),
            ),
          ),
          const Positioned(left: -80, top: 220, child: GlowBlob(color: AppColors.teal400, size: 320)),
          const Positioned(right: -100, top: 40, child: GlowBlob(color: AppColors.cyan400, size: 260)),
          Center(
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset('assets/images/logo.png', height: 104, fit: BoxFit.contain),
                    ),
                    const SizedBox(height: 20),
                    const Text('CityCalls Field', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    const SizedBox(height: 6),
                    const Text('For technicians & field partners', style: TextStyle(color: AppColors.slate400, fontSize: 13.5)),
                    const SizedBox(height: 36),
                    const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.teal400)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
