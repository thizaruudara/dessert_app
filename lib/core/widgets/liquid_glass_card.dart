import 'dart:ui';
import 'package:flutter/material.dart';

/// An ultra-premium liquid glassmorphism container.
///
/// Features authentic frosted glass blur (BackdropFilter), specular gradient
/// borders that reflect light, and dual-layer atmospheric shadows.
class LiquidGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final double blur;
  final double surfaceOpacity;
  final Color? tintColor;
  final Color? borderColor;
  final Color? glowColor;
  final VoidCallback? onTap;
  final Gradient? customSurfaceGradient;

  const LiquidGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius,
    this.blur = 18.0,
    this.surfaceOpacity = 0.82,
    this.tintColor,
    this.borderColor,
    this.glowColor,
    this.onTap,
    this.customSurfaceGradient,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = borderRadius ?? BorderRadius.circular(24);

    final effectiveGlow = glowColor ??
        (isDark ? const Color(0xFF38BDF8) : const Color(0xFF227AFF));

    // Dual-layer shadow: broad ambient colored aura + crisp contact shadow
    final shadows = [
      BoxShadow(
        color: effectiveGlow.withOpacity(isDark ? 0.12 : 0.07),
        blurRadius: 22,
        offset: const Offset(0, 8),
      ),
      BoxShadow(
        color: isDark
            ? Colors.black.withOpacity(0.25)
            : const Color(0x080F172A),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ];

    final surfaceColors = isDark
        ? [
            (tintColor ?? const Color(0xFF1E293B)).withOpacity(surfaceOpacity),
            (tintColor ?? const Color(0xFF0F172A)).withOpacity(surfaceOpacity * 0.95),
          ]
        : [
            (tintColor ?? Colors.white).withOpacity(surfaceOpacity),
            (tintColor ?? const Color(0xFFF8FAFC)).withOpacity(surfaceOpacity * 0.90),
          ];

    final borderStroke = borderColor ??
        (isDark
            ? Colors.white.withOpacity(0.16)
            : Colors.white.withOpacity(0.85));

    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: customSurfaceGradient ??
            LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: surfaceColors,
            ),
        border: Border.all(
          color: borderStroke,
          width: 1.2,
        ),
      ),
      child: child,
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: content,
        ),
      );
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: shadows,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: content,
        ),
      ),
    );
  }
}

/// A compact frosted liquid glass pill chip for badges and tags.
class LiquidGlassPill extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? tintColor;
  final Color? borderColor;
  final VoidCallback? onTap;

  const LiquidGlassPill({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    this.tintColor,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(20);

    Widget pill = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: radius,
            color: (tintColor ??
                    (isDark
                        ? Colors.white.withOpacity(0.12)
                        : Colors.white.withOpacity(0.75)))
                .withOpacity(0.75),
            border: Border.all(
              color: borderColor ??
                  (isDark
                      ? Colors.white.withOpacity(0.20)
                      : Colors.white.withOpacity(0.90)),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.15)
                    : const Color(0x0A227AFF),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      pill = GestureDetector(
        onTap: onTap,
        child: pill,
      );
    }

    return pill;
  }
}
