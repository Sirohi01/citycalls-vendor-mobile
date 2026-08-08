import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';
import '../theme/app_theme.dart';
import 'vendor_dashboard_screen.dart';
import 'vendor_roster_screen.dart';
import 'vendor_payouts_screen.dart';
import 'otp_request_screen.dart';

class VendorOwnerShell extends ConsumerStatefulWidget {
  const VendorOwnerShell({super.key});

  @override
  ConsumerState<VendorOwnerShell> createState() => _VendorOwnerShellState();
}

class _VendorOwnerShellState extends ConsumerState<VendorOwnerShell> {
  int _index = 0;

  late final List<Widget> _screens;
  static const _titles = ['Dashboard', 'Roster', 'Payouts'];

  @override
  void initState() {
    super.initState();
    _screens = [
      VendorDashboardScreen(key: const PageStorageKey('vendor-dashboard')),
      VendorRosterScreen(key: const PageStorageKey('vendor-roster')),
      VendorPayoutsScreen(key: const PageStorageKey('vendor-payouts')),
    ];
  }

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const OtpRequestScreen()),
          (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          IconButton(
            tooltip: 'Log Out',
            icon: const Icon(Icons.logout, color: AppColors.urgent),
            onPressed: _logout,
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: _screens),
      extendBody: false,
      bottomNavigationBar: SafeArea(
        top: false,
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surface
                    .withValues(alpha: 0.9),
                border: Border(
                    top: BorderSide(
                        color: Theme.of(context).dividerColor, width: 1)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, -4))
                ],
              ),
              child: BottomNavigationBar(
                currentIndex: _index,
                onTap: (i) => setState(() => _index = i),
                backgroundColor: Colors.transparent,
                elevation: 0,
                items: const [
                  BottomNavigationBarItem(
                      icon: Icon(Icons.dashboard_outlined),
                      activeIcon: Icon(Icons.dashboard),
                      label: 'Dashboard'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.groups_outlined),
                      activeIcon: Icon(Icons.groups),
                      label: 'Roster'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.payments_outlined),
                      activeIcon: Icon(Icons.payments),
                      label: 'Payouts'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
