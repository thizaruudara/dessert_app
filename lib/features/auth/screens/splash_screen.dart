import 'dart:math' as math;
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
  late AnimationController _pulseCtrl;

  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<Offset> _logoSlide;

  late Animation<double> _titleFade;
  late Animation<Offset> _titleSlide;

  late Animation<double> _badgeFade;
  late Animation<Offset> _badgeSlide;

  late Animation<double> _loaderFade;

  @override
  void initState() {
    super.initState();

    // 1. Entrance orchestration controller
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // 2. Continuous breathing / glowing aura loop
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    // Choreographed entrance curves
    _logoScale = Tween<double>(begin: 0.72, end: 1.0).animate(
      CurvedAnimation(
        parent: _enterCtrl,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutBack),
      ),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _enterCtrl,
        curve: const Interval(0.0, 0.40, curve: Curves.easeOut),
      ),
    );

    _logoSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _enterCtrl,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic),
      ),
    );

    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _enterCtrl,
        curve: const Interval(0.35, 0.75, curve: Curves.easeOut),
      ),
    );

    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _enterCtrl,
        curve: const Interval(0.35, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    _badgeFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _enterCtrl,
        curve: const Interval(0.55, 0.90, curve: Curves.easeOut),
      ),
    );

    _badgeSlide = Tween<Offset>(
      begin: const Offset(0, 0.30),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _enterCtrl,
        curve: const Interval(0.55, 0.90, curve: Curves.easeOutCubic),
      ),
    );

    _loaderFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _enterCtrl,
        curve: const Interval(0.70, 1.0, curve: Curves.easeIn),
      ),
    );

    _enterCtrl.forward();

    // Navigate smoothly after entry animation completes
    _initNavigation();
  }

  void _initNavigation() {
    Future.delayed(const Duration(milliseconds: 2200), () async {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      if (auth.isLoggedIn) {
        context.go(auth.isAdmin ? '/admin' : '/student');
        return;
      }

      // Check for up to 2 extra seconds if background auth restore is finalizing over Wi-Fi
      for (int i = 0; i < 4; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        if (auth.isLoggedIn) {
          context.go(auth.isAdmin ? '/admin' : '/student');
          return;
        }
      }

      if (mounted) {
        context.go('/auth/login');
      }
    });
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // ── 1. Modern Ambient Radial Glow Background ─────────────────────
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.15),
                  radius: 0.95,
                  colors: isDark
                      ? [
                          const Color(0xFF1E3A8A).withOpacity(0.40),
                          const Color(0xFF0F172A),
                          const Color(0xFF020617),
                        ]
                      : [
                          const Color(0xFFE3F0FF),
                          const Color(0xFFF1F6FF),
                          const Color(0xFFF8FAFC),
                        ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),

          // ── 2. Subtle Animated Shimmer Rings in Center ───────────────────
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (context, _) {
              final pulse = _pulseCtrl.value;
              return Center(
                child: Transform.translate(
                  offset: const Offset(0, -40),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer diffuse halo
                      Container(
                        width: 240 + (pulse * 24),
                        height: 240 + (pulse * 24),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF38BDF8).withOpacity(0.08 + (pulse * 0.05)),
                        ),
                      ),
                      // Core luminous glow
                      Container(
                        width: 170 + (pulse * 14),
                        height: 170 + (pulse * 14),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withOpacity(0.22 + (pulse * 0.12)),
                              blurRadius: 50,
                              spreadRadius: 8,
                            ),
                            BoxShadow(
                              color: const Color(0xFF38BDF8).withOpacity(0.28 + (pulse * 0.14)),
                              blurRadius: 30,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // ── 3. Choreographed Content ─────────────────────────────────────
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 3),

                    // ── Animated Logo (100% Transparent, No Box!) ──────────
                    SlideTransition(
                      position: _logoSlide,
                      child: ScaleTransition(
                        scale: _logoScale,
                        child: FadeTransition(
                          opacity: _logoFade,
                          child: SizedBox(
                            width: 150,
                            height: 150,
                            child: Image.asset(
                              'assets/images/edupeak_logo.png',
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ── Brand Title with Premium Gradient & Typography ─────
                    SlideTransition(
                      position: _titleSlide,
                      child: FadeTransition(
                        opacity: _titleFade,
                        child: ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [
                              Color(0xFF1D4ED8), // Deep vibrant blue
                              Color(0xFF2563EB), // Primary brand blue
                              Color(0xFF0284C7), // Sky blue
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds),
                          child: Text(
                            'EduPeak',
                            style: GoogleFonts.outfit(
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.6,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // ── Tagline Badge (Liquid Glass Pill) ──────────────────
                    SlideTransition(
                      position: _badgeSlide,
                      child: FadeTransition(
                        opacity: _badgeFade,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.06)
                                : Colors.white.withOpacity(0.70),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withOpacity(0.12)
                                  : const Color(0xFF2563EB).withOpacity(0.15),
                              width: 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(isDark ? 0.20 : 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [Color(0xFF38BDF8), Color(0xFF2563EB)],
                                  ),
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

                    // ── Futuristic Shimmer Capsule Progress Loader ─────────
                    FadeTransition(
                      opacity: _loaderFade,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _FuturisticLoader(isDark: isDark),
                          const SizedBox(height: 12),
                          Text(
                            'Initializing Portal...',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? const Color(0xFF64748B)
                                  : const Color(0xFF94A3B8),
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A sleek, futuristic glowing progress bar that sweeps smoothly
class _FuturisticLoader extends StatefulWidget {
  final bool isDark;
  const _FuturisticLoader({required this.isDark});

  @override
  State<_FuturisticLoader> createState() => _FuturisticLoaderState();
}

class _FuturisticLoaderState extends State<_FuturisticLoader>
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
      width: 140,
      height: 4,
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withOpacity(0.08)
            : const Color(0xFF2563EB).withOpacity(0.10),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: AnimatedBuilder(
          animation: _sweepCtrl,
          builder: (context, _) {
            final t = _sweepCtrl.value;
            return Transform.translate(
              offset: Offset((t * 2.0 - 1.0) * 140, 0),
              child: Container(
                width: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      const Color(0xFF38BDF8).withOpacity(0.9),
                      const Color(0xFF2563EB),
                      Colors.transparent,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF38BDF8).withOpacity(0.7),
                      blurRadius: 6,
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
