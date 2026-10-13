import 'package:flutter/material.dart';

// Same look as citycalls-customer-mobile's theme/app_theme.dart — light grey
// page, white hairline-bordered cards, dark ink primary buttons, CityCalls
// green accents, and the black/lime treatment on login + dark headers.
// Still independently defined (no shared package between the two apps).
//
// The older teal palette's names (primary, teal400, cyan400, bgWarm…) are
// kept as aliases onto the customer palette so every screen picks up the
// new look without each call site having to be rewritten.
class AppColors {
  AppColors._();

  // Customer-app palette.
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const faint = Color(0xFF94A3B8);
  static const line = Color(0xFFE2E8F0);
  static const hairline = Color(0xFFF1F5F9);
  static const page = Color(0xFFF6F7F9);
  static const green = Color(0xFF16A34A);
  static const greenDark = Color(0xFF15803D);
  static const greenSoft = Color(0xFFDCFCE7);
  static const lime500 = Color(0xFF84CC16);
  static const lime400 = Color(0xFFA3E635);
  // Dark header gradient, as on the customer Home / Profile headers.
  static const heroDark = Color(0xFF0B0B0B);
  static const heroDark2 = Color(0xFF1C2A14);
  static const heroLime = Color(0xFF8BD450);
  static const indigo500 = Color(0xFF6366F1);

  // Legacy names, re-pointed at the customer palette.
  static const primary = green;
  static const primaryDark = greenDark;
  static const primaryLight = greenSoft;
  static const teal400 = lime500;
  static const cyan400 = indigo500;
  static const bgWarm = page;
  static const gold400 = Color(0xFFD97706);

  static const black = Color(0xFF0A0A0A);
  static const slate950 = Color(0xFF020617);
  static const slate900 = Color(0xFF0F172A);
  static const slate700 = Color(0xFF334155);
  static const slate600 = Color(0xFF475569);
  static const slate500 = Color(0xFF64748B);
  static const slate400 = Color(0xFF94A3B8);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate100 = Color(0xFFF1F5F9);
  static const white = Color(0xFFFFFFFF);
  static const red400 = Color(0xFFF87171);

  // Job-status/urgency signaling — a field app lives and dies by "what needs
  // my attention right now," so these get real color weight, not just text.
  static const urgent = Color(0xFFDC2626); // red-600 — overdue/SLA breached
  static const warning = Color(0xFFD97706); // amber-600 — due soon
  static const success = Color(0xFF16A34A); // green-600 — completed/on track
  static const info = Color(0xFF2563EB); // blue-600 — informational
}

// Same slide transition as the customer app (Android's default zoom
// transition crashes on screens whose content resizes mid-push).
const _pageTransitionsTheme = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: CupertinoPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
  },
);

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    const ink = AppColors.ink;
    const muted = AppColors.muted;
    const line = AppColors.line;
    const accent = AppColors.green;
    final radius12 = BorderRadius.circular(12);
    OutlineInputBorder field(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: radius12, borderSide: BorderSide(color: c, width: w));
    WidgetStateProperty<Color?> selected(Color on) =>
        WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? on : null);

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.page,
      colorScheme: ColorScheme.fromSeed(
        seedColor: ink,
        brightness: Brightness.light,
        primary: ink,
        onPrimary: AppColors.white,
        secondary: accent,
        surface: AppColors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.white,
        foregroundColor: ink,
        surfaceTintColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleSpacing: 4,
        titleTextStyle:
            TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ink),
        shape: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      pageTransitionsTheme: _pageTransitionsTheme,
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        showDragHandle: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: line,
          disabledForegroundColor: AppColors.faint,
          minimumSize: const Size.fromHeight(50),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: radius12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: AppColors.white,
          elevation: 0,
          minimumSize: const Size(64, 48),
          textStyle:
              const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: radius12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size(64, 50),
          side: const BorderSide(color: line),
          textStyle:
              const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: radius12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        labelStyle: const TextStyle(color: muted),
        floatingLabelStyle: const TextStyle(color: ink),
        hintStyle: const TextStyle(color: AppColors.faint),
        border: field(line),
        enabledBorder: field(line),
        focusedBorder: field(ink, 1.5),
        errorBorder: field(AppColors.urgent),
        focusedErrorBorder: field(AppColors.urgent, 1.5),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: line),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: muted,
        titleTextStyle:
            TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: ink),
        subtitleTextStyle: TextStyle(fontSize: 12.5, color: muted),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.hairline),
      dividerColor: AppColors.hairline,
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.white,
        selectedColor: accent.withValues(alpha: 0.12),
        side: const BorderSide(color: line),
        labelStyle: const TextStyle(fontSize: 13, color: ink),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.w700, color: ink),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        shape: RoundedRectangleBorder(borderRadius: radius12),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: accent),
      checkboxTheme: CheckboxThemeData(
        fillColor: selected(accent),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(fillColor: selected(accent)),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? AppColors.white : null),
        trackColor: selected(accent),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: ink,
        unselectedLabelColor: muted,
        indicatorColor: accent,
        labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// Customer-facing statuses are collapsed for readability elsewhere in this
// codebase (see JobSummary) — this maps a status to the urgency color used
// throughout Job cards/badges, not to a human label.
Color statusAccentColor(String status) {
  if (newJobStatuses.contains(status)) return AppColors.urgent;
  const urgentStatuses = {
    'CUSTOMER_UNAVAILABLE',
    'REASSIGNMENT_REQUIRED',
    'ON_HOLD'
  };
  const completedStatuses = {
    'SERVICE_COMPLETED',
    'CUSTOMER_CONFIRMATION_PENDING',
    'PAID',
    'CLOSED'
  };
  const activeStatuses = {
    'ACCEPTED',
    'APPOINTMENT_SCHEDULED',
    'RESCHEDULED',
    'TECHNICIAN_EN_ROUTE',
    'TECHNICIAN_ARRIVED',
    'INSPECTION_STARTED',
    'INSPECTION_COMPLETED',
    'ESTIMATE_PENDING',
    'ESTIMATE_SHARED',
    'AWAITING_CUSTOMER_APPROVAL',
    'ESTIMATE_APPROVED',
    'PARTS_PENDING',
    'WORK_STARTED',
    'WORK_IN_PROGRESS',
    'PAYMENT_PENDING',
    'PARTIALLY_PAID',
  };
  if (urgentStatuses.contains(status)) return AppColors.urgent;
  if (completedStatuses.contains(status)) return AppColors.success;
  if (activeStatuses.contains(status)) return AppColors.info;
  return AppColors.slate500;
}

// Every status a job can be in when it lands on a technician/vendor and
// still needs their Accept/Reject — the API allows ACCEPTED from all of
// these (scripts/seed.ts "Accept/reject from every assignable state"), not
// just ASSIGNED_TO_EMPLOYEE. A vendor technician's job typically arrives as
// ASSIGNED_TO_VENDOR or OUTSOURCED.
const newJobStatuses = {
  'ASSIGNED_TO_EMPLOYEE',
  'ASSIGNED_TO_VENDOR',
  'OUTSOURCED',
  'ASSIGNED_TO_TEAM',
};

// The app is light-only now (like the customer app), so these no longer
// branch on brightness — kept as functions so call sites stay unchanged.
Color secondaryTextColor(BuildContext context) => AppColors.slate500;

Color strongSecondaryTextColor(BuildContext context) => AppColors.slate700;

Color subtleSurfaceColor(BuildContext context) => AppColors.slate100;

// Shared field styling for the black login screens — identical to
// citycalls-customer-mobile's widgets/auth_background.dart.
InputDecoration authFieldDecoration(
    {required String label,
    IconData? icon,
    String? prefixText,
    String? errorText}) {
  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(
        color: AppColors.slate300.withValues(alpha: 0.8), fontSize: 14),
    floatingLabelStyle: const TextStyle(color: AppColors.lime400),
    hintStyle: TextStyle(color: AppColors.slate400.withValues(alpha: 0.7)),
    prefixIcon: icon != null
        ? Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Icon(icon, color: AppColors.slate400, size: 22),
          )
        : null,
    prefixText: prefixText,
    prefixStyle: const TextStyle(
        color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
    errorText: errorText,
    errorStyle:
        const TextStyle(color: AppColors.red400, fontWeight: FontWeight.w500),
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.05),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide:
          BorderSide(color: Colors.white.withValues(alpha: 0.12), width: 1.5),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide:
          BorderSide(color: Colors.white.withValues(alpha: 0.12), width: 1.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.lime400, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.red400, width: 1.5),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.red400, width: 2),
    ),
  );
}

ButtonStyle authButtonStyle() {
  return FilledButton.styleFrom(
    backgroundColor: AppColors.lime500,
    foregroundColor: AppColors.slate950,
    disabledBackgroundColor: AppColors.lime500.withValues(alpha: 0.3),
    disabledForegroundColor: AppColors.slate950.withValues(alpha: 0.5),
    minimumSize: const Size.fromHeight(52),
    elevation: 0,
    textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
}

// White rounded card with a hairline border — the customer app's card. The
// name is kept from the old frosted-glass version so every screen switches
// over without call-site changes; [tint]/[blur] are accepted and ignored
// apart from [tint] as a plain background colour.
class GlassCard extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final Color? tint;
  final double blur;
  final Color? borderColor;
  final double borderWidth;

  const GlassCard({
    super.key,
    required this.child,
    this.radius = 16,
    this.padding = const EdgeInsets.all(16),
    this.tint,
    this.blur = 0,
    this.borderColor,
    this.borderWidth = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: tint ?? AppColors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
            color: borderColor ?? AppColors.line, width: borderWidth),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
