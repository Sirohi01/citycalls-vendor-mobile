import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

// Shared chrome for the login flow — black background, the CityCalls
// wordmark sliding in, and the form below it. Same as
// citycalls-customer-mobile's widgets/auth_background.dart (independently
// defined, no shared code between the two apps).
class AuthBackground extends StatefulWidget {
  final Widget child;
  const AuthBackground({super.key, required this.child});

  @override
  State<AuthBackground> createState() => _AuthBackgroundState();
}

class _AuthBackgroundState extends State<AuthBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeLogo;
  late final Animation<Offset> _slideLogo;
  late final Animation<double> _fadeCard;
  late final Animation<Offset> _slideCard;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _fadeLogo = CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut));
    _slideLogo =
        Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic)),
    );
    _fadeCard = CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut));
    _slideCard =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic)),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // City skyline from the splash, faded in at the bottom.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.55,
                child: Image.asset('assets/login/splace.png',
                    fit: BoxFit.fitWidth),
              ),
            ),
          ),
          // Soft lime glow behind the logo.
          Positioned(
            top: -size.width * 0.35,
            left: -size.width * 0.2,
            right: -size.width * 0.2,
            child: IgnorePointer(
              child: Container(
                height: size.width * 1.1,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    AppColors.lime400.withValues(alpha: 0.16),
                    AppColors.lime400.withValues(alpha: 0),
                  ]),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FadeTransition(
                      opacity: _fadeLogo,
                      child: SlideTransition(
                        position: _slideLogo,
                        child: Column(
                          children: [
                            Image.asset('assets/images/logo.png',
                                height: 64, fit: BoxFit.contain),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.lime400.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: AppColors.lime400
                                        .withValues(alpha: 0.35)),
                              ),
                              child: const Text('FIELD PARTNER APP',
                                  style: TextStyle(
                                      color: AppColors.lime400,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.6)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                    FadeTransition(
                      opacity: _fadeCard,
                      child: SlideTransition(
                        position: _slideCard,
                        child: Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxWidth: 420),
                          padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0C120E)
                                .withValues(alpha: 0.88),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08)),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    AppColors.lime400.withValues(alpha: 0.06),
                                blurRadius: 40,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: widget.child,
                        ),
                      ),
                    ),
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
