import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
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
    final tabs = [
      VendorDashboardScreen(onLogout: _logout),
      const _TitledTab(title: 'Technicians', child: VendorRosterScreen()),
      const _TitledTab(
          title: 'Invoices & Payouts', child: VendorPayoutsScreen()),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: PopScope(
        canPop: _index == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) setState(() => _index = 0);
        },
        child: Scaffold(
          body: IndexedStack(index: _index, children: tabs),
          bottomNavigationBar: AppBottomNav(
            currentIndex: _index,
            onTap: (i) => setState(() => _index = i),
            items: const [
              AppNavItemData(
                  icon: Icons.space_dashboard_outlined,
                  activeIcon: Icons.space_dashboard_rounded,
                  label: 'Home'),
              AppNavItemData(
                  icon: Icons.groups_outlined,
                  activeIcon: Icons.groups_rounded,
                  label: 'Roster'),
              AppNavItemData(
                  icon: Icons.payments_outlined,
                  activeIcon: Icons.payments_rounded,
                  label: 'Payouts'),
            ],
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
      appBar: AppBar(title: Text(title), titleSpacing: 16),
      body: child,
    );
  }
}
