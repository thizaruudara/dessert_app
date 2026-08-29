import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/liquid_navigation_bar.dart';

class StudentShell extends StatefulWidget {
  final Widget child;
  const StudentShell({super.key, required this.child});

  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
  final _tabs = const [
    '/student',
    '/student/leaderboard',
    '/student/desserts',
    '/student/submit',
    '/student/profile',
  ];

  final _items = const [
    LiquidNavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    LiquidNavItem(
      icon: Icons.emoji_events_outlined,
      activeIcon: Icons.emoji_events_rounded,
      label: 'Ranks',
    ),
    LiquidNavItem(
      icon: Icons.folder_special_outlined,
      activeIcon: Icons.folder_special_rounded,
      label: 'Desserts',
    ),
    LiquidNavItem(
      icon: Icons.add_circle_outline_rounded,
      activeIcon: Icons.add_circle_rounded,
      label: 'Submit',
    ),
    LiquidNavItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    for (int i = 0; i < _tabs.length; i++) {
      if (location == _tabs[i] || (i == 0 && location == '/student')) {
        return i;
      }
    }
    for (int i = _tabs.length - 1; i >= 0; i--) {
      if (location.startsWith(_tabs[i])) {
        return i;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);
    final location = GoRouterState.of(context).uri.path;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: false,
      backgroundColor: isDark ? const Color(0xFF0B0F19) : AppColors.background,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
            ),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.015),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey(location),
          child: widget.child,
        ),
      ),
      bottomNavigationBar: LiquidNavigationBar(
        selectedIndex: selectedIndex,
        onItemSelected: (i) {
          if (selectedIndex != i) {
            context.go(_tabs[i]);
          }
        },
        items: _items,
        barColor: isDark ? const Color(0xFF111827) : Colors.white,
        borderColor: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0),
        activeCircleGradient: isDark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF06B6D4), Color(0xFF2563EB)],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF227AFF), Color(0xFF1565D8)],
              ),
        activeIconColor: Colors.white,
        inactiveIconColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        activeTextColor: isDark ? const Color(0xFF38BDF8) : const Color(0xFF227AFF),
      ),
    );
  }
}
