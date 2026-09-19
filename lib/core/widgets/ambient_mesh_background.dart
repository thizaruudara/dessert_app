import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// An ultra-smooth, lightweight live animated ambient mesh background.
///
/// It renders floating, breathing radiant orbs beneath the UI, providing
/// the authentic refractive substrate needed for liquid glassmorphism.
class AmbientMeshBackground extends StatefulWidget {
  final Widget child;
  final bool animate;
  final Color? baseColor;

  const AmbientMeshBackground({
    super.key,
    required this.child,
    this.animate = true,
    this.baseColor,
  });

  @override
  State<AmbientMeshBackground> createState() => _AmbientMeshBackgroundState();
}

class _AmbientMeshBackgroundState extends State<AmbientMeshBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    if (widget.animate) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AmbientMeshBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = widget.baseColor ??
        (isDark ? const Color(0xFF0A0F1D) : AppColors.background);

    return Container(
      color: base,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Live Ambient Gradient Mesh
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _AmbientMeshPainter(
                  progress: _controller.value,
                  isDark: isDark,
                ),
                size: Size.infinite,
              );
            },
          ),
          // Content layered on top
          widget.child,
        ],
      ),
    );
  }
}

class _AmbientMeshPainter extends CustomPainter {
  final double progress;
  final bool isDark;

  _AmbientMeshPainter({required this.progress, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final t = progress * 2 * math.pi;

    // Orb 1: Primary Brand Blue (Top Left, breathes diagonally)
    final orb1Center = Offset(
      size.width * (0.20 + 0.12 * math.sin(t)),
      size.height * (0.15 + 0.08 * math.cos(t)),
    );
    final orb1Radius = size.width * (0.65 + 0.08 * math.sin(t + 1.0));
    final orb1Paint = Paint()
      ..shader = RadialGradient(
        colors: [
          isDark
              ? const Color(0xFF1E3A8A).withOpacity(0.35)
              : const Color(0xFF227AFF).withOpacity(0.18),
          isDark
              ? const Color(0xFF1E3A8A).withOpacity(0.0)
              : const Color(0xFF227AFF).withOpacity(0.0),
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: orb1Center, radius: orb1Radius));
    canvas.drawCircle(orb1Center, orb1Radius, orb1Paint);

    // Orb 2: Electric Cyan / Sky (Top Right & Middle, orbits smoothly)
    final orb2Center = Offset(
      size.width * (0.80 - 0.15 * math.cos(t * 0.8)),
      size.height * (0.28 + 0.10 * math.sin(t * 0.8)),
    );
    final orb2Radius = size.width * (0.55 + 0.06 * math.cos(t));
    final orb2Paint = Paint()
      ..shader = RadialGradient(
        colors: [
          isDark
              ? const Color(0xFF0284C7).withOpacity(0.25)
              : const Color(0xFF38BDF8).withOpacity(0.20),
          isDark
              ? const Color(0xFF0284C7).withOpacity(0.0)
              : const Color(0xFF38BDF8).withOpacity(0.0),
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: orb2Center, radius: orb2Radius));
    canvas.drawCircle(orb2Center, orb2Radius, orb2Paint);

    // Orb 3: Soft Violet / Royal Indigo (Lower Middle)
    final orb3Center = Offset(
      size.width * (0.35 + 0.18 * math.sin(t * 0.7 + 2.0)),
      size.height * (0.65 + 0.12 * math.cos(t * 0.7)),
    );
    final orb3Radius = size.width * (0.60 + 0.07 * math.sin(t * 0.9));
    final orb3Paint = Paint()
      ..shader = RadialGradient(
        colors: [
          isDark
              ? const Color(0xFF4338CA).withOpacity(0.22)
              : const Color(0xFF818CF8).withOpacity(0.15),
          isDark
              ? const Color(0xFF4338CA).withOpacity(0.0)
              : const Color(0xFF818CF8).withOpacity(0.0),
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: orb3Center, radius: orb3Radius));
    canvas.drawCircle(orb3Center, orb3Radius, orb3Paint);

    // Orb 4: Warm Amber / Sunbeam (Subtle accent highlight)
    final orb4Center = Offset(
      size.width * (0.75 + 0.10 * math.cos(t * 0.6 + 1.5)),
      size.height * (0.80 - 0.10 * math.sin(t * 0.6)),
    );
    final orb4Radius = size.width * (0.50 + 0.05 * math.cos(t * 1.1));
    final orb4Paint = Paint()
      ..shader = RadialGradient(
        colors: [
          isDark
              ? const Color(0xFFD97706).withOpacity(0.15)
              : const Color(0xFFFBBF24).withOpacity(0.12),
          isDark
              ? const Color(0xFFD97706).withOpacity(0.0)
              : const Color(0xFFFBBF24).withOpacity(0.0),
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: orb4Center, radius: orb4Radius));
    canvas.drawCircle(orb4Center, orb4Radius, orb4Paint);
  }

  @override
  bool shouldRepaint(covariant _AmbientMeshPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isDark != isDark;
  }
}
