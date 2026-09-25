import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../auth/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _enterCtrl;
  late AnimationController _swapUpCtrl;

  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<Offset> _logoSlide;

  late Animation<double> _badgeFade;
  late Animation<Offset> _badgeSlide;

  late Animation<double> _loaderFade;

  late Animation<Offset> _swapUpSlide;
  late Animation<double> _swapUpFade;

  @override
  void initState() {
    super.initState();

    // 1. Entrance orchestration controller
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // 2. Swap-up exit controller: slides the entire splash screen UP into the dashboard
    _swapUpCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    // Entrance curves
    _logoScale = Tween<double>(begin: 0.78, end: 1.0).animate(
      CurvedAnimation(
        parent: _enterCtrl,
        curve: const Interval(0.0, 0.70, curve: Curves.easeOutBack),
      ),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _enterCtrl,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
      ),
    );

    _logoSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _enterCtrl,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic),
      ),
    );

    _badgeFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _enterCtrl,
        curve: const Interval(0.40, 0.85, curve: Curves.easeOut),
      ),
    );

    _badgeSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _enterCtrl,
        curve: const Interval(0.40, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    _loaderFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _enterCtrl,
        curve: const Interval(0.60, 1.0, curve: Curves.easeIn),
      ),
    );

    // Swap-up curve: High-end iOS/Android physical lift gesture
    _swapUpSlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.0, -1.0),
    ).animate(
      CurvedAnimation(
        parent: _swapUpCtrl,
        curve: Curves.easeInOutCubic,
      ),
    );

    _swapUpFade = Tween<double>(
      begin: 1.0,
      end: 0.92,
    ).animate(
      CurvedAnimation(
        parent: _swapUpCtrl,
        curve: Curves.easeIn,
      ),
    );

    _enterCtrl.forward();

    // Start navigation timer and perform swap-up transition
    _initNavigation();
  }

  void _initNavigation() async {
    // Minimum viewing time so user sees the clean logo and loading line
    await Future.delayed(const Duration(milliseconds: 1900));
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    String target = '/auth/login';

    if (auth.isLoggedIn) {
      target = auth.isAdmin ? '/admin' : '/student';
    } else {
      // Check for up to 1.5s if background auth session is restoring
      for (int i = 0; i < 3; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        if (auth.isLoggedIn) {
          target = auth.isAdmin ? '/admin' : '/student';
          break;
        }
      }
    }

    if (!mounted) return;

    // Execute the Swap-Up animation
    await _swapUpCtrl.forward();

    if (mounted) {
      context.go(target);
    }
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _swapUpCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      body: SlideTransition(
        position: _swapUpSlide,
        child: FadeTransition(
          opacity: _swapUpFade,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  const Spacer(flex: 3),

                  // ── Hero Logo (100% Transparent, No Circles, No Boxes) ───
                  SlideTransition(
                    position: _logoSlide,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: FadeTransition(
                        opacity: _logoFade,
                        child: SizedBox(
                          width: 180,
                          height: 180,
                          child: Image.asset(
                            'assets/images/edupeak_logo.png',
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Tagline Pill Badge ───────────────────────────────────
                  SlideTransition(
                    position: _badgeSlide,
                    child: FadeTransition(
                      opacity: _badgeFade,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.06)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withOpacity(0.10)
                                : const Color(0xFFE2E8F0),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.25 : 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF2563EB),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFF2563EB),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'AI & Advanced Level Institute',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? const Color(0xFFCBD5E1)
                                    : const Color(0xFF475569),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const Spacer(flex: 3),

                  // ── Sleek Modern Bottom Loader ───────────────────────────
                  FadeTransition(
                    opacity: _loaderFade,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ModernProgressBar(isDark: isDark),
                        const SizedBox(height: 12),
                        Text(
                          'Connecting to Campus...',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? const Color(0xFF64748B)
                                : const Color(0xFF94A3B8),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A clean, minimalist glowing sweep progress line
class _ModernProgressBar extends StatefulWidget {
  final bool isDark;
  const _ModernProgressBar({required this.isDark});

  @override
  State<_ModernProgressBar> createState() => _ModernProgressBarState();
}

class _ModernProgressBarState extends State<_ModernProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _sweepCtrl;

  @override
  void initState() {
    super.initState();
    _sweepCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _sweepCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 3.5,
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withOpacity(0.08)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: widget.isDark
              ? Colors.white.withOpacity(0.05)
              : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: AnimatedBuilder(
          animation: _sweepCtrl,
          builder: (context, _) {
            final t = _sweepCtrl.value;
            return Transform.translate(
              offset: Offset((t * 2.0 - 1.0) * 120, 0),
              child: Container(
                width: 55,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Colors.transparent,
                      Color(0xFF38BDF8),
                      Color(0xFF2563EB),
                      Colors.transparent,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0xFF38BDF8),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
