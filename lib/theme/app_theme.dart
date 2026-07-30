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

  static const black = Color(0xFF0F172A); // slate-900
  static const slate900 = Color(0xFF0F172A);
  static const slate700 = Color(0xFF334155);
  static const slate500 = Color(0xFF64748B);
  static const slate400 = Color(0xFF94A3B8);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate100 = Color(0xFFF1F5F9);
  static const white = Color(0xFFFFFFFF);

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
      scaffoldBackgroundColor: AppColors.slate100,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.slate100,
        surfaceTintColor: AppColors.slate100,
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
  const urgentStatuses = {'CUSTOMER_UNAVAILABLE', 'REASSIGNMENT_REQUIRED', 'ON_HOLD'};
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
