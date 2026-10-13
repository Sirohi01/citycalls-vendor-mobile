import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FadeTransition(
                  opacity: _fadeLogo,
                  child: SlideTransition(
                    position: _slideLogo,
                    child: Image.asset('assets/images/logo.png',
                        height: 72, fit: BoxFit.contain),
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
                      child: widget.child,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
