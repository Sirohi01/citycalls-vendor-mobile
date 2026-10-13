import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// Dark header with rounded bottom corners — the same black → deep-green
// gradient as citycalls-customer-mobile's Profile header. Draws under the
// status bar and pads itself below it.
class HeroHeader extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const HeroHeader(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 24)});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.heroDark, AppColors.heroDark2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(top: top),
      child: Padding(padding: padding, child: child),
    );
  }
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
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            height: 1),
        children: const [
          TextSpan(text: 'City', style: TextStyle(color: AppColors.heroLime)),
          TextSpan(
              text: 'Calls',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        ],
      ),
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
          ? AppColors.heroLime.withValues(alpha: 0.16)
          : Colors.white.withValues(alpha: 0.07),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: highlight
                ? AppColors.heroLime.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.12)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.heroLime, size: 18),
              const SizedBox(height: 8),
              Text(value?.toString() ?? '—',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                      height: 1.1)),
              const SizedBox(height: 2),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11.5)),
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
        IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon, color: Colors.white, size: 22),
          style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.08)),
        ),
        if (badge > 0)
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              constraints: const BoxConstraints(minWidth: 17),
              decoration: BoxDecoration(
                color: AppColors.urgent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.heroDark, width: 1.5),
              ),
              child: Text(badge > 9 ? '9+' : '$badge',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ),
          ),
      ],
    );
  }
}
