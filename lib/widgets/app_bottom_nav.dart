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

// Bottom bar shared by MainShell and VendorOwnerShell — same as the customer
// app's: white bar, hairline top border, the selected tab gets a short green
// bar along the top edge, a filled icon and a bold label.
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: AppColors.hairline)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                _NavItem(
                  data: items[i],
                  selected: i == currentIndex,
                  onTap: () => onTap(i),
                ),
            ],
          ),
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
    final color = selected ? AppColors.green : AppColors.faint;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              width: selected ? 28 : 0,
              height: 3,
              decoration: const BoxDecoration(
                color: AppColors.green,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(3)),
              ),
            ),
            const Spacer(),
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(selected ? data.activeIcon : data.icon,
                    color: color, size: 24),
                if (data.badge > 0)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      constraints: const BoxConstraints(minWidth: 16),
                      decoration: BoxDecoration(
                        color: AppColors.urgent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(
                        data.badge > 9 ? '9+' : '${data.badge}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              data.label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
