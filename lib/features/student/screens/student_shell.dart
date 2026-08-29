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
  int _index = 0;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: widget.child,
      bottomNavigationBar: LiquidNavigationBar(
        selectedIndex: _index,
        onItemSelected: (i) {
          setState(() => _index = i);
          context.go(_tabs[i]);
        },
        items: _items,
        barColor: const Color(0xFF0F172A), // Deep Midnight Slate (TikTok look)
        activeCircleColor: Colors.white, // Floating elevated white circle
        activeIconColor: const Color(0xFF227AFF), // EduPeak Brand Blue
        inactiveIconColor: const Color(0xFF94A3B8), // Sleek muted slate
        activeTextColor: Colors.white,
      ),
    );
  }
}
