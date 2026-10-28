import 'package:flutter/material.dart';

// CityCalls Field design system. Brand stays the CityCalls black + lime/green
// of the customer app, lifted to a premium feel: Plus Jakarta Sans, a deep
// forest-black hero, soft-shadowed white cards, 16–24px radii and a floating
// dark bottom bar (see widgets/app_bottom_nav.dart).
//
// The older names (primary, teal400, cyan400, bgWarm, GlassCard…) are kept as
// aliases so every screen picks the system up without call-site changes.
class AppColors {
  AppColors._();

  static const fontFamily = 'PlusJakartaSans';

  // Ink & neutrals.
  static const ink = Color(0xFF0B1220);
  static const ink2 = Color(0xFF1E293B);
  static const muted = Color(0xFF64748B);
  static const faint = Color(0xFF94A3B8);
  static const line = Color(0xFFE6EAF0);
  static const hairline = Color(0xFFF0F2F6);
  static const page = Color(0xFFF3F5F8);

  // Brand.
  static const green = Color(0xFF16A34A);
  static const greenDark = Color(0xFF0F7A37);
  static const greenSoft = Color(0xFFE7F7EC);
  static const lime500 = Color(0xFF84CC16);
  static const lime400 = Color(0xFFA3E635);
  static const heroLime = Color(0xFF9BE15D);

  // Hero (dark headers, bottom bar, login).
  static const heroDark = Color(0xFF060D08);
  static const heroDark2 = Color(0xFF0D1F12);
  static const heroDark3 = Color(0xFF15301C);
  static const indigo500 = Color(0xFF6366F1);

  // Legacy names, re-pointed at this palette.
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

  // Status signalling.
  static const urgent = Color(0xFFE11D48); // rose-600
  static const warning = Color(0xFFF59E0B); // amber-500
  static const success = Color(0xFF16A34A);
  static const info = Color(0xFF2563EB);
  static const violet = Color(0xFF7C3AED);
}

// Shadows used across cards / floating elements.
class AppShadows {
  AppShadows._();

  static final card = [
    BoxShadow(
      color: const Color(0xFF0B1220).withValues(alpha: 0.05),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];

  static final raised = [
    BoxShadow(
      color: const Color(0xFF0B1220).withValues(alpha: 0.10),
      blurRadius: 28,
      offset: const Offset(0, 12),
    ),
  ];

  static List<BoxShadow> glow(Color c) => [
        BoxShadow(
          color: c.withValues(alpha: 0.35),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
      ];
}

// Slide transition on both platforms (Android's default zoom transition
// crashes on screens whose content resizes mid-push).
const _pageTransitionsTheme = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: CupertinoPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
  },
);

class AppTheme {
  AppTheme._();

  static const _font = AppColors.fontFamily;

  static ThemeData light() {
    const ink = AppColors.ink;
    const muted = AppColors.muted;
    const line = AppColors.line;
    const accent = AppColors.green;
    final radius14 = BorderRadius.circular(14);
    OutlineInputBorder field(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: radius14, borderSide: BorderSide(color: c, width: w));
    WidgetStateProperty<Color?> selected(Color on) =>
        WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? on : null);
    // Component text styles name the family explicitly — a style that sets
    // none would fall back to the platform font, not the theme's.
    TextStyle t(double size, FontWeight weight, [Color? color]) => TextStyle(
        fontFamily: _font,
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: -0.1);

    final base = ThemeData(
      useMaterial3: true,
      fontFamily: _font,
      scaffoldBackgroundColor: AppColors.page,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.light,
        primary: ink,
        onPrimary: AppColors.white,
        secondary: accent,
        surface: AppColors.white,
        onSurface: ink,
      ),
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
          fontFamily: _font, bodyColor: ink, displayColor: ink),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.page,
        foregroundColor: ink,
        surfaceTintColor: AppColors.page,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 4,
        titleTextStyle: t(19, FontWeight.w800, ink),
        iconTheme: const IconThemeData(color: ink, size: 22),
      ),
      pageTransitionsTheme: _pageTransitionsTheme,
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        showDragHandle: true,
        dragHandleColor: AppColors.slate300,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: line,
          disabledForegroundColor: AppColors.faint,
          minimumSize: const Size.fromHeight(54),
          elevation: 0,
          textStyle: t(15, FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: radius14),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: AppColors.white,
          elevation: 0,
          minimumSize: const Size(64, 50),
          textStyle: t(14.5, FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: radius14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          backgroundColor: AppColors.white,
          minimumSize: const Size(64, 54),
          side: const BorderSide(color: line, width: 1.2),
          textStyle: t(14.5, FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: radius14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle: t(14, FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        labelStyle: t(14, FontWeight.w500, muted),
        floatingLabelStyle: t(14, FontWeight.w600, ink),
        hintStyle: t(14, FontWeight.w400, AppColors.faint),
        prefixIconColor: AppColors.faint,
        border: field(line),
        enabledBorder: field(line),
        focusedBorder: field(accent, 1.6),
        errorBorder: field(AppColors.urgent),
        focusedErrorBorder: field(AppColors.urgent, 1.6),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.hairline),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: muted,
        titleTextStyle: t(14.5, FontWeight.w600, ink),
        subtitleTextStyle: t(12.5, FontWeight.w500, muted),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.hairline),
      dividerColor: AppColors.hairline,
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.white,
        selectedColor: ink,
        secondarySelectedColor: ink,
        side: const BorderSide(color: line),
        labelStyle: t(13, FontWeight.w600, ink),
        secondaryLabelStyle: t(13, FontWeight.w600, AppColors.white),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        checkmarkColor: AppColors.white,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: t(19, FontWeight.w800, ink),
        contentTextStyle: t(14, FontWeight.w500, AppColors.slate600),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: t(13.5, FontWeight.w600, AppColors.white),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: accent),
      checkboxTheme: CheckboxThemeData(
        fillColor: selected(accent),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      radioTheme: RadioThemeData(fillColor: selected(accent)),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? AppColors.white : null),
        trackColor: selected(accent),
        trackOutlineColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? accent : AppColors.slate300),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: ink,
        unselectedLabelColor: muted,
        indicatorColor: accent,
        labelStyle: t(14, FontWeight.w700),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: ink),
      ),
    );
  }
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

// The colour a status reads as everywhere (pills, card accents, stepper).
Color statusAccentColor(String status) {
  if (newJobStatuses.contains(status)) return AppColors.urgent;
  const attention = {
    'CUSTOMER_UNAVAILABLE',
    'REASSIGNMENT_REQUIRED',
    'ON_HOLD',
    'ESTIMATE_REJECTED',
  };
  const waiting = {
    'ESTIMATE_PENDING',
    'ESTIMATE_SHARED',
    'AWAITING_CUSTOMER_APPROVAL',
    'PARTS_PENDING',
    'CUSTOMER_CONFIRMATION_PENDING',
    'PAYMENT_PENDING',
    'PARTIALLY_PAID',
  };
  const moving = {'TECHNICIAN_EN_ROUTE', 'TECHNICIAN_ARRIVED'};
  const done = {'SERVICE_COMPLETED', 'PAID', 'CLOSED'};
  if (attention.contains(status)) return AppColors.urgent;
  if (waiting.contains(status)) return AppColors.warning;
  if (moving.contains(status)) return AppColors.violet;
  if (done.contains(status)) return AppColors.success;
  if (status == 'CANCELLED') return AppColors.slate500;
  return AppColors.info;
}

// The app is light-only, so these no longer branch on brightness — kept as
// functions so call sites stay unchanged.
Color secondaryTextColor(BuildContext context) => AppColors.muted;

Color strongSecondaryTextColor(BuildContext context) => AppColors.slate700;

Color subtleSurfaceColor(BuildContext context) => AppColors.slate100;

// Field styling for the black login screens.
InputDecoration authFieldDecoration(
    {required String label,
    IconData? icon,
    String? prefixText,
    String? errorText}) {
  const f = AppColors.fontFamily;
  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(
        fontFamily: f,
        color: AppColors.slate300.withValues(alpha: 0.8),
        fontSize: 14),
    floatingLabelStyle:
        const TextStyle(fontFamily: f, color: AppColors.lime400),
    hintStyle: TextStyle(
        fontFamily: f, color: AppColors.slate400.withValues(alpha: 0.7)),
    prefixIcon: icon != null
        ? Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Icon(icon, color: AppColors.slate400, size: 22),
          )
        : null,
    prefixText: prefixText,
    prefixStyle: const TextStyle(
        fontFamily: f,
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 15),
    errorText: errorText,
    errorStyle: const TextStyle(
        fontFamily: f, color: AppColors.red400, fontWeight: FontWeight.w500),
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.06),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 19),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide:
          BorderSide(color: Colors.white.withValues(alpha: 0.12), width: 1.4),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide:
          BorderSide(color: Colors.white.withValues(alpha: 0.12), width: 1.4),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: AppColors.lime400, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: AppColors.red400, width: 1.4),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: AppColors.red400, width: 2),
    ),
  );
}

ButtonStyle authButtonStyle() {
  return FilledButton.styleFrom(
    backgroundColor: AppColors.lime400,
    foregroundColor: AppColors.heroDark,
    disabledBackgroundColor: AppColors.lime400.withValues(alpha: 0.3),
    disabledForegroundColor: AppColors.heroDark.withValues(alpha: 0.5),
    minimumSize: const Size.fromHeight(56),
    elevation: 0,
    textStyle: const TextStyle(
        fontFamily: AppColors.fontFamily,
        fontWeight: FontWeight.w800,
        fontSize: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
  );
}

// White rounded card with a soft shadow. Name kept from the old frosted
// version so call sites didn't change; [tint] is a plain background colour.
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
    this.radius = 20,
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
            color: borderColor ?? AppColors.hairline, width: borderWidth),
        boxShadow: AppShadows.card,
      ),
      child: child,
    );
  }
}
