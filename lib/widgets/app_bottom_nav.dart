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

/// Space a tab screen leaves at the bottom of its scroll content. The bar is
/// docked below the content (no `extendBody`), so this is just breathing room.
double bottomNavClearance(BuildContext context) => 28;

// Bottom bar shared by MainShell and VendorOwnerShell, in the customer app's
// style: a white bar docked to the bottom edge with rounded top corners.
// Every tab shows its icon with its name underneath. The selected tab gets a
// soft green pill behind a filled green icon and a bold dark label, so it's
// obvious where you are even at a glance in sunlight.
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: const Border(top: BorderSide(color: AppColors.line)),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(8, 8, 8, bottom > 0 ? bottom : 10),
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
    const idle = AppColors.slate500;
    return Semantics(
      selected: selected,
      button: true,
      label: data.badge > 0 ? '${data.label}, ${data.badge} new' : data.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: AppColors.green.withValues(alpha: 0.10),
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    width: selected ? 60 : 44,
                    height: 34,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.green.withValues(alpha: 0.13)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Icon(
                      selected ? data.activeIcon : data.icon,
                      size: 24,
                      color: selected ? AppColors.green : idle,
                    ),
                  ),
                  if (data.badge > 0)
                    Positioned(
                      right: selected ? 6 : 2,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4.5, vertical: 1),
                        constraints: const BoxConstraints(minWidth: 18),
                        decoration: BoxDecoration(
                          color: AppColors.urgent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 2),
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
              const SizedBox(height: 4),
              Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 0.1,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? AppColors.ink : idle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
