import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppNavItemData {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int badge;
  const AppNavItemData(
      {required this.icon,
      required this.activeIcon,
      required this.label,
      this.badge = 0});
}

/// Tabs of the field-work shell (MainShell). Familiar icons with a label
/// under every one, so each tab reads at a glance.
List<AppNavItemData> fieldNavItems({int newJobs = 0}) => [
      const AppNavItemData(
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          label: 'Home'),
      AppNavItemData(
          icon: Icons.assignment_outlined,
          activeIcon: Icons.assignment_rounded,
          label: 'My Jobs',
          badge: newJobs),
      const AppNavItemData(
          icon: Icons.history_rounded,
          activeIcon: Icons.history_rounded,
          label: 'History'),
      const AppNavItemData(
          icon: Icons.person_outline_rounded,
          activeIcon: Icons.person_rounded,
          label: 'Profile'),
    ];

/// Tabs of the vendor owner/manager shell (VendorOwnerShell).
List<AppNavItemData> vendorNavItems({required bool showEarnings}) => [
      const AppNavItemData(
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          label: 'Home'),
      const AppNavItemData(
          icon: Icons.groups_outlined,
          activeIcon: Icons.groups_rounded,
          label: 'My Team'),
      if (showEarnings)
        const AppNavItemData(
            icon: Icons.account_balance_wallet_outlined,
            activeIcon: Icons.account_balance_wallet_rounded,
            label: 'Earnings'),
    ];

/// Space a tab screen must leave at the bottom of its scroll content so the
/// last item isn't hidden behind the floating bar.
double bottomNavClearance(BuildContext context) =>
    MediaQuery.of(context).padding.bottom + 110;

// Floating dark bottom bar shared by MainShell and VendorOwnerShell. Every
// tab shows its icon with its name underneath; the selected tab gets a lime
// pill behind the icon and a lime, bold label. Shells use `extendBody: true`
// so content scrolls underneath it.
class AppBottomNav extends StatelessWidget {
  final List<AppNavItemData> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  const AppBottomNav(
      {super.key,
      required this.items,
      required this.currentIndex,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, bottom > 0 ? bottom : 12),
      child: Container(
        height: 74,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF111A14), AppColors.heroDark],
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          boxShadow: [
            BoxShadow(
              color: AppColors.heroDark.withValues(alpha: 0.35),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: _NavItem(
                  data: items[i],
                  selected: i == currentIndex,
                  onTap: () => onTap(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final AppNavItemData data;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem(
      {required this.data, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final idle = Colors.white.withValues(alpha: 0.62);
    return Semantics(
      selected: selected,
      button: true,
      label: data.badge > 0 ? '${data.label}, ${data.badge} new' : data.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: AppColors.lime400.withValues(alpha: 0.12),
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  width: selected ? 56 : 40,
                  height: 32,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.lime400 : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    selected ? data.activeIcon : data.icon,
                    size: 23,
                    color: selected ? AppColors.heroDark : idle,
                  ),
                ),
                if (data.badge > 0)
                  Positioned(
                    right: selected ? 2 : 4,
                    top: -5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4.5, vertical: 1),
                      constraints: const BoxConstraints(minWidth: 18),
                      decoration: BoxDecoration(
                        color: AppColors.urgent,
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: AppColors.heroDark, width: 1.8),
                      ),
                      child: Text(
                        data.badge > 9 ? '9+' : '${data.badge}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              data.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                letterSpacing: 0.1,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? AppColors.lime400 : idle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
