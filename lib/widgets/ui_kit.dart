import 'package:flutter/material.dart';

// Small shared building blocks for the redesigned screens, so cards,
// section labels, empty states and dates look the same everywhere.

const kInk = Color(0xFF0F172A);
const kMuted = Color(0xFF64748B);
const kFaint = Color(0xFF94A3B8);
const kLine = Color(0xFFE2E8F0);
const kGreen = Color(0xFF16A34A);

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "12 Oct 2026" from an ISO string or DateTime (local time). Empty on bad input.
String formatDisplayDate(Object? value) {
  final d = value is DateTime
      ? value.toLocal()
      : DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  if (d == null) return '';
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}

/// "12 Oct 2026, 4:05 PM".
String formatDisplayDateTime(Object? value) {
  final d = value is DateTime
      ? value.toLocal()
      : DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  if (d == null) return '';
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '${formatDisplayDate(d)}, $h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
}

/// White rounded card with a hairline border.
class UiCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  const UiCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: kLine),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Small uppercase grey heading above a group of cards.
class UiSectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const UiSectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: kFaint,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Rounded icon in a soft tinted square.
class UiIconTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const UiIconTile(
      {super.key, required this.icon, this.color = kGreen, this.size = 40});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        child: Icon(icon, color: color, size: size * 0.5),
      );
}

/// Coloured status pill.
class UiPill extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const UiPill({super.key, required this.text, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Centered empty state: icon, title, message and an optional action.
class UiEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  const UiEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: kGreen.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: kGreen),
            ),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: kInk)),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(message!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13, height: 1.4, color: kMuted)),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(minimumSize: const Size(180, 46)),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Label / value row used inside detail cards.
class UiInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const UiInfoRow(
      {super.key,
      required this.icon,
      required this.label,
      required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: kFaint),
          const SizedBox(width: 10),
          SizedBox(
            width: 96,
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: kMuted)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w600, color: kInk)),
          ),
        ],
      ),
    );
  }
}
