import 'dart:ui';
import 'package:flutter/material.dart';

// Independently defined from citycalls-customer-mobile's app_theme.dart —
// no shared code between the two Flutter apps (multi-repo design, see
// docs/coordination/03-code-ownership.md). Teal/slate identity distinct from
// the customer app's black/lime, matching the existing ColorScheme.fromSeed
// (Colors.teal) main.dart already had — a professional field-ops feel rather
// than a consumer-facing one, since this app's entire user base is
// technicians/vendors working through a route of jobs, not customers browsing
// a catalog.
class AppColors {
  AppColors._();

  static const primary = Color(0xFF0F766E); // teal-700
  static const primaryDark = Color(0xFF0B4F49);
  static const primaryLight = Color(0xFFCCFBF1); // teal-100
  static const teal400 = Color(0xFF2DD4BF);
  static const cyan400 = Color(0xFF22D3EE);

  static const black = Color(0xFF0F172A); // slate-900
  static const slate950 = Color(0xFF020617);
  static const slate900 = Color(0xFF0F172A);
  static const slate700 = Color(0xFF334155);
  static const slate500 = Color(0xFF64748B);
  static const slate400 = Color(0xFF94A3B8);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate100 = Color(0xFFF1F5F9);
  static const white = Color(0xFFFFFFFF);
  static const red400 = Color(0xFFF87171);

  // Warm base the whole light-mode app now sits on (per Manish's ask for a
  // "halka sa yellowish" background) — a soft cream/amber wash instead of
  // the cooler slate-100, which is also what makes the frosted-glass cards
  // (GlassCard below) actually read as *glass over something*, rather than
  // white-on-white.
  static const bgWarm = Color(0xFFFFF8E9);
  static const bgWarmDeep = Color(0xFFFDECC1);
  static const gold400 = Color(0xFFE8B923);

  // Job-status/urgency signaling — a field app lives and dies by "what needs
  // my attention right now," so these get real color weight, not just text.
  static const urgent = Color(0xFFDC2626); // red-600 — overdue/SLA breached
  static const warning = Color(0xFFD97706); // amber-600 — due soon
  static const success = Color(0xFF16A34A); // green-600 — completed/on track
  static const info = Color(0xFF2563EB); // blue-600 — informational
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.bgWarm,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgWarm,
        surfaceTintColor: AppColors.bgWarm,
        foregroundColor: AppColors.slate900,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(color: AppColors.slate900, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size.fromHeight(50),
          side: const BorderSide(color: AppColors.primary, width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.slate200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.slate200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.urgent)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.slate400,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}

// Customer-facing statuses are collapsed for readability elsewhere in this
// codebase (see JobSummary) — this maps a status to the urgency color used
// throughout Job cards/badges, not to a human label.
Color statusAccentColor(String status) {
  const urgentStatuses = {'ASSIGNED_TO_EMPLOYEE', 'CUSTOMER_UNAVAILABLE', 'REASSIGNMENT_REQUIRED', 'ON_HOLD'};
  const completedStatuses = {'SERVICE_COMPLETED', 'CUSTOMER_CONFIRMATION_PENDING', 'PAID', 'CLOSED'};
  const activeStatuses = {
    'ACCEPTED', 'APPOINTMENT_SCHEDULED', 'RESCHEDULED', 'TECHNICIAN_EN_ROUTE', 'TECHNICIAN_ARRIVED',
    'INSPECTION_STARTED', 'INSPECTION_COMPLETED', 'ESTIMATE_PENDING', 'ESTIMATE_SHARED',
    'AWAITING_CUSTOMER_APPROVAL', 'ESTIMATE_APPROVED', 'PARTS_PENDING', 'WORK_STARTED', 'WORK_IN_PROGRESS',
    'PAYMENT_PENDING', 'PARTIALLY_PAID',
  };
  if (urgentStatuses.contains(status)) return AppColors.urgent;
  if (completedStatuses.contains(status)) return AppColors.success;
  if (activeStatuses.contains(status)) return AppColors.info;
  return AppColors.slate500;
}

// Shared field styling for the dark glass auth card — outlined, translucent,
// teal focus ring. Mirrors citycalls-customer-mobile's widgets/auth_background.dart
// pattern (independently defined, no shared code between the two apps).
InputDecoration authFieldDecoration({required String label, IconData? icon, String? prefixText, String? errorText}) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: AppColors.slate300),
    prefixIcon: icon != null ? Icon(icon, color: AppColors.slate400, size: 20) : null,
    prefixText: prefixText,
    prefixStyle: const TextStyle(color: AppColors.slate200),
    errorText: errorText,
    errorStyle: const TextStyle(color: AppColors.red400),
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.05),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.teal400, width: 1.5)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.red400)),
  );
}

ButtonStyle authButtonStyle() {
  return FilledButton.styleFrom(
    backgroundColor: AppColors.teal400,
    foregroundColor: AppColors.slate950,
    minimumSize: const Size.fromHeight(48),
    textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  );
}

// Real frosted-glass card — BackdropFilter blur (not just a translucent
// fill), so it actually reads as glass sitting over the warm scaffold
// background rather than a flat off-white box. Used across every screen in
// this app now (Dashboard/My Jobs/History/Job Detail/Profile/Inspection/
// Work Progress/Completion) for a single consistent glassmorphic language.
// `padding: null` lets a caller that wants to lay out its own Padding/no
// padding (e.g. wrapping a ListTile) skip the default.
class GlassCard extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final Color tint;
  final double blur;
  final Color? borderColor;
  final double borderWidth;

  const GlassCard({
    super.key,
    required this.child,
    this.radius = 20,
    this.padding = const EdgeInsets.all(16),
    this.tint = Colors.white,
    this.blur = 16,
    this.borderColor,
    this.borderWidth = 1.2,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [BoxShadow(color: (borderColor ?? AppColors.slate900).withValues(alpha: borderColor != null ? 0.1 : 0.07), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            width: double.infinity,
            padding: padding,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: borderColor ?? Colors.white.withValues(alpha: 0.7), width: borderWidth),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white.withValues(alpha: 0.35), Colors.white.withValues(alpha: 0.05)],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// Kept for any call site still using the old flat (non-blurred) decoration —
// prefer GlassCard for new/updated screens.
BoxDecoration glassCardDecoration({double radius = 18}) {
  return BoxDecoration(
    color: Colors.white.withValues(alpha: 0.7),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
    boxShadow: [BoxShadow(color: AppColors.slate900.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 8))],
  );
}
