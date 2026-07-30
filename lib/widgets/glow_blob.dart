import 'package:flutter/material.dart';

// Soft radial-gradient circle used behind dark auth screens for the brand's
// glow-blob motif. Independently defined from citycalls-customer-mobile's
// copy — no shared code between the two Flutter apps.
class GlowBlob extends StatelessWidget {
  final Color color;
  final double size;
  const GlowBlob({super.key, required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}
