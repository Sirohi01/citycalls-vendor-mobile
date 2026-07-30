import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'glow_blob.dart';

// Shared chrome for the Onboarding flow (OTP request/verify) — dark slate
// gradient, two soft teal/cyan glow blobs, the CityCalls logo, and a frosted
// glass card for the actual form. Mirrors citycalls-customer-mobile's
// widgets/auth_background.dart pattern (independently defined, no shared
// code between the two apps) with this app's teal identity in place of the
// customer app's lime.
class AuthBackground extends StatelessWidget {
  final Widget child;
  const AuthBackground({super.key, required this.child});

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
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset('assets/images/logo.png', height: 96, fit: BoxFit.contain),
                    ),
                    const SizedBox(height: 28),
                    _GlassCard(child: child),
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

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: child,
        ),
      ),
    );
  }
}
