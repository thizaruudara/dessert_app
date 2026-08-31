import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/otp_screen.dart';
import '../../features/student/screens/student_shell.dart';
import '../../features/student/screens/student_home_screen.dart';
import '../../features/student/screens/student_leaderboard_screen.dart';
import '../../features/student/screens/student_desserts_screen.dart';
import '../../features/student/screens/student_submit_guide_screen.dart';
import '../../features/student/screens/dessert_detail_screen.dart';
import '../../features/student/screens/student_profile_screen.dart';
import '../../features/admin/screens/admin_shell.dart';
import '../../features/admin/screens/admin_home_screen.dart';
import '../../features/admin/screens/admin_review_screen.dart';
import '../../features/admin/screens/admin_students_screen.dart';
import '../../features/admin/screens/admin_announcements_screen.dart';

CustomTransitionPage<void> _buildSmoothPage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.04, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: child,
        ),
      );
    },
  );
}

class AppRouter {
  final AuthProvider authProvider;

  AppRouter(this.authProvider);

  late final GoRouter router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: authProvider,
    redirect: (context, state) {
      final loggedIn = authProvider.isLoggedIn;
      final onAuth = state.matchedLocation.startsWith('/auth') ||
          state.matchedLocation == '/splash';

      if (!loggedIn && !onAuth) return '/auth/login';
      if (loggedIn && onAuth) {
        return authProvider.isAdmin ? '/admin' : '/student';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) => _buildSmoothPage(
          key: state.pageKey,
          child: const SplashScreen(),
        ),
      ),

      // ── Auth ──────────────────────────────────────────────
      GoRoute(
        path: '/auth/login',
        pageBuilder: (context, state) => _buildSmoothPage(
          key: state.pageKey,
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: '/auth/otp',
        pageBuilder: (context, state) {
          final extra = state.extra;
          String phone = '';
          String? name;
          String? examYear;
          bool isRegister = false;

          if (extra is Map<String, dynamic>) {
            phone = extra['phone']?.toString() ?? '';
            name = extra['name']?.toString();
            examYear = extra['examYear']?.toString();
            isRegister = extra['isRegister'] == true;
          } else if (extra is String) {
            phone = extra;
          }

          return _buildSmoothPage(
            key: state.pageKey,
            child: OtpScreen(
              phoneNumber: phone,
              name: name,
              examYear: examYear,
              isRegister: isRegister,
            ),
          );
        },
      ),

      // ── Student Shell ─────────────────────────────────────
      ShellRoute(
        builder: (_, __, child) => StudentShell(child: child),
        routes: [
          GoRoute(
            path: '/student',
            builder: (_, __) => const StudentHomeScreen(),
          ),
          GoRoute(
            path: '/student/leaderboard',
            builder: (_, __) => const StudentLeaderboardScreen(),
          ),
          GoRoute(
            path: '/student/desserts',
            builder: (_, __) => const StudentDessertsScreen(),
          ),
          GoRoute(
            path: '/student/submit',
            builder: (_, __) => const StudentSubmitGuideScreen(),
          ),
          GoRoute(
            path: '/student/dessert/:id',
            pageBuilder: (context, state) => _buildSmoothPage(
              key: state.pageKey,
              child: DessertDetailScreen(
                dessertId: state.pathParameters['id']!,
              ),
            ),
          ),
          GoRoute(
            path: '/student/profile',
            builder: (_, __) => const StudentProfileScreen(),
          ),
        ],
      ),

      // ── Admin Shell ───────────────────────────────────────
      ShellRoute(
        builder: (_, __, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: '/admin',
            builder: (_, __) => const AdminHomeScreen(),
          ),
          GoRoute(
            path: '/admin/review/:id',
            pageBuilder: (context, state) => _buildSmoothPage(
              key: state.pageKey,
              child: AdminReviewScreen(
                dessertId: state.pathParameters['id']!,
              ),
            ),
          ),
          GoRoute(
            path: '/admin/students',
            builder: (_, __) => const AdminStudentsScreen(),
          ),
          GoRoute(
            path: '/admin/announcements',
            builder: (_, __) => const AdminAnnouncementsScreen(),
          ),
        ],
      ),
    ],
  );
}
