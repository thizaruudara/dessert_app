import 'package:flutter/material.dart';

class LiquidNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const LiquidNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// Student navigation styled to match the compact web-app bottom bar.
class LiquidNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final List<LiquidNavItem> items;
  final Color barColor;
  final Color borderColor;
  final Gradient activeCircleGradient;
  final Color activeIconColor;
  final Color inactiveIconColor;
  final Color activeTextColor;

  const LiquidNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.items,
    this.barColor = Colors.white,
    this.borderColor = const Color(0xFFE2E8F0),
    this.activeCircleGradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
    ),
    this.activeIconColor = Colors.white,
    this.inactiveIconColor = const Color(0xFF64748B),
    this.activeTextColor = const Color(0xFF2563EB),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: barColor,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: List.generate(items.length, (index) {
              final item = items[index];
              final selected = index == selectedIndex;
              return Expanded(
                child: Semantics(
                  button: true,
                  selected: selected,
                  label: item.label,
                  child: InkWell(
                    onTap: () => onItemSelected(index),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          width: 44,
                          height: 32,
                          decoration: BoxDecoration(
                            color: selected
                                ? activeTextColor.withOpacity(0.09)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            selected ? item.activeIcon : item.icon,
                            size: 21,
                            color: selected ? activeTextColor : inactiveIconColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected ? activeTextColor : inactiveIconColor,
                            fontSize: 9.5,
                            height: 1.1,
                            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
