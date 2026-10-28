import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/ui_kit.dart';
import 'vendor_dashboard_screen.dart';
import 'vendor_roster_screen.dart';
import 'vendor_payouts_screen.dart';
import 'otp_request_screen.dart';

// VENDOR_OWNER / VENDOR_MANAGER shell — company view rather than field work
// (see role_router.dart). Same bottom bar as MainShell / the customer app.
class VendorOwnerShell extends ConsumerStatefulWidget {
  const VendorOwnerShell({super.key});

  @override
  ConsumerState<VendorOwnerShell> createState() => _VendorOwnerShellState();
}

class _VendorOwnerShellState extends ConsumerState<VendorOwnerShell> {
  int _index = 0;

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need an OTP to log in again.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.urgent,
                minimumSize: const Size(110, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(authProvider.notifier).logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const OtpRequestScreen()),
          (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Invoices/payouts need vendors:viewFinancial, which only VENDOR_OWNER
    // holds (scripts/seed.ts) — a manager would only ever see an error there.
    final canSeeEarnings =
        ref.watch(authProvider).user?.role == 'VENDOR_OWNER';
    final tabs = [
      VendorDashboardScreen(onLogout: _logout),
      const _TitledTab(title: 'My Team', child: VendorRosterScreen()),
      if (canSeeEarnings)
        const _TitledTab(title: 'Earnings', child: VendorPayoutsScreen()),
    ];
    if (_index >= tabs.length) _index = 0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.page,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: PopScope(
        canPop: _index == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) setState(() => _index = 0);
        },
        child: Scaffold(
          // Content scrolls underneath the floating bottom bar.
          extendBody: true,
          body: IndexedStack(index: _index, children: tabs),
          bottomNavigationBar: AppBottomNav(
            currentIndex: _index,
            onTap: (i) => setState(() => _index = i),
            items: vendorNavItems(showEarnings: canSeeEarnings),
          ),
        ),
      ),
    );
  }
}

class _TitledTab extends StatelessWidget {
  final String title;
  final Widget child;
  const _TitledTab({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          UiPageHeader(title: title),
          Expanded(child: child),
        ],
      ),
    );
  }
}
