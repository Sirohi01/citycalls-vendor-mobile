import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// Dark brand header: forest-black gradient, a soft lime glow in the corner
// and a faint dot grid, rounded at the bottom. Draws under the status bar and
// pads itself below it. [overlap] leaves extra space at the bottom for a card
// that sits half on the header (see DashboardScreen).
class HeroHeader extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double overlap;
  const HeroHeader(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.fromLTRB(20, 10, 20, 28),
      this.overlap = 0});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.heroDark,
              AppColors.heroDark2,
              AppColors.heroDark3
            ],
            stops: [0, 0.55, 1],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: CustomPaint(painter: _DotGrid())),
            Positioned(
              right: -90,
              top: -70,
              child: _Glow(color: AppColors.lime400, size: 280, opacity: 0.20),
            ),
            Positioned(
              left: -80,
              bottom: -110,
              child: _Glow(color: AppColors.green, size: 240, opacity: 0.18),
            ),
            Padding(
              padding: EdgeInsets.only(top: top, bottom: overlap),
              child: Padding(padding: padding, child: child),
            ),
          ],
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;
  const _Glow({required this.color, required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: 0),
          ]),
        ),
      ),
    );
  }
}

class _DotGrid extends CustomPainter {
  const _DotGrid();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.045);
    const gap = 18.0;
    for (double y = 8; y < size.height; y += gap) {
      for (double x = 8; x < size.width; x += gap) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// "CityCalls" wordmark as text (lime City + white Calls), as in the
// customer app's top bar — the logo asset is used on the black login screens.
class Wordmark extends StatelessWidget {
  final double size;
  const Wordmark({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            height: 1),
        children: const [
          TextSpan(text: 'City', style: TextStyle(color: AppColors.heroLime)),
          TextSpan(
              text: 'Calls',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// Small lime-outlined tag next to the wordmark ("FIELD", "PARTNER").
class HeroTag extends StatelessWidget {
  final String text;
  const HeroTag(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.lime400.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lime400.withValues(alpha: 0.35)),
      ),
      child: Text(text,
          style: const TextStyle(
              color: AppColors.lime400,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4)),
    );
  }
}

// Translucent stat tile used inside a HeroHeader.
class HeroStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final int? value;
  final bool highlight;
  final VoidCallback? onTap;
  const HeroStat(
      {super.key,
      required this.icon,
      required this.label,
      required this.value,
      this.highlight = false,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlight
          ? AppColors.lime400.withValues(alpha: 0.14)
          : Colors.white.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
            color: highlight
                ? AppColors.lime400.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.09)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(icon, color: AppColors.lime400, size: 17),
                  const Spacer(),
                  if (onTap != null)
                    Icon(Icons.north_east_rounded,
                        size: 14, color: Colors.white.withValues(alpha: 0.35)),
                ],
              ),
              const SizedBox(height: 10),
              Text(value?.toString() ?? '—',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 24,
                      letterSpacing: -0.5,
                      height: 1.05)),
              const SizedBox(height: 3),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

// Round translucent icon button for the dark header, with optional badge.
class HeroIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final int badge;
  final String? tooltip;
  const HeroIconButton(
      {super.key,
      required this.icon,
      required this.onPressed,
      this.badge = 0,
      this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.white.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(15),
            child: Tooltip(
              message: tooltip ?? '',
              child: SizedBox(
                width: 46,
                height: 46,
                child: Icon(icon, color: Colors.white, size: 22),
              ),
            ),
          ),
        ),
        if (badge > 0)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              constraints: const BoxConstraints(minWidth: 19),
              decoration: BoxDecoration(
                color: AppColors.urgent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.heroDark, width: 2),
              ),
              child: Text(badge > 9 ? '9+' : '$badge',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800)),
            ),
          ),
      ],
    );
  }
}
