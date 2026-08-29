import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

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

class LiquidNavigationBar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final List<LiquidNavItem> items;
  final Color barColor;
  final Color activeCircleColor;
  final Color activeIconColor;
  final Color inactiveIconColor;
  final Color activeTextColor;

  const LiquidNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.items,
    this.barColor = const Color(0xFF0F172A), // Deep Midnight Slate (as in TikTok demo)
    this.activeCircleColor = Colors.white, // Crisp elevated white circle
    this.activeIconColor = const Color(0xFF0F172A),
    this.inactiveIconColor = const Color(0xFF94A3B8),
    this.activeTextColor = Colors.white,
  });

  @override
  State<LiquidNavigationBar> createState() => _LiquidNavigationBarState();
}

class _LiquidNavigationBarState extends State<LiquidNavigationBar> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _positionAnimation;
  int _lastIndex = 0;

  @override
  void initState() {
    super.initState();
    _lastIndex = widget.selectedIndex;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _positionAnimation = Tween<double>(
      begin: widget.selectedIndex.toDouble(),
      end: widget.selectedIndex.toDouble(),
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOutCubicEmphasized,
    ));
  }

  @override
  void didUpdateWidget(covariant LiquidNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _positionAnimation = Tween<double>(
        begin: oldWidget.selectedIndex.toDouble(),
        end: widget.selectedIndex.toDouble(),
      ).animate(CurvedAnimation(
        parent: _animController,
        curve: Curves.easeInOutCubicEmphasized,
      ));
      _animController.forward(from: 0.0);
      _lastIndex = widget.selectedIndex;
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.items.length;
    const barHeight = 68.0;
    const circleRadius = 26.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      height: barHeight + circleRadius,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final itemWidth = width / count;

          return AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              final currentPos = _animController.isAnimating
                  ? _positionAnimation.value
                  : widget.selectedIndex.toDouble();
              final circleCenterX = (currentPos + 0.5) * itemWidth;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // ── 1. Curved Scooped Liquid Bar ────────────────────────
                  Positioned(
                    top: circleRadius,
                    left: 0,
                    right: 0,
                    height: barHeight,
                    child: CustomPaint(
                      painter: _LiquidBarPainter(
                        centerX: circleCenterX,
                        barColor: widget.barColor,
                      ),
                      child: Row(
                        children: List.generate(count, (index) {
                          final isSelected = widget.selectedIndex == index;
                          final item = widget.items[index];

                          return Expanded(
                            child: GestureDetector(
                              onTap: () => widget.onItemSelected(index),
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                height: barHeight,
                                alignment: Alignment.center,
                                child: isSelected
                                    ? Padding(
                                        padding: const EdgeInsets.only(top: 32),
                                        child: Text(
                                          item.label,
                                          style: TextStyle(
                                            color: widget.activeTextColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                      )
                                    : Icon(
                                        item.icon,
                                        color: widget.inactiveIconColor,
                                        size: 22,
                                      ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),

                  // ── 2. Elevated Floating Liquid Circle ──────────────────
                  Positioned(
                    top: 0,
                    left: circleCenterX - circleRadius,
                    child: GestureDetector(
                      onTap: () => widget.onItemSelected(widget.selectedIndex),
                      child: Container(
                        width: circleRadius * 2,
                        height: circleRadius * 2,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.activeCircleColor,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            widget.items[widget.selectedIndex].activeIcon,
                            color: widget.activeIconColor,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _LiquidBarPainter extends CustomPainter {
  final double centerX;
  final Color barColor;

  _LiquidBarPainter({
    required this.centerX,
    required this.barColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const cornerRadius = 24.0;
    const notchWidth = 72.0;
    const notchDepth = 32.0;

    final paint = Paint()
      ..color = barColor
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = const Color(0x250F172A)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);

    final path = Path();

    // Start top-left
    path.moveTo(cornerRadius, 0);

    // Left notch start point
    final notchLeft = centerX - (notchWidth / 2);
    final notchRight = centerX + (notchWidth / 2);

    // Line to left start of notch
    path.lineTo(notchLeft, 0);

    // Smooth Bezier Curve Scoop (The Liquid Dip)
    path.cubicTo(
      notchLeft + 12, 0,
      centerX - 24, notchDepth,
      centerX, notchDepth,
    );
    path.cubicTo(
      centerX + 24, notchDepth,
      notchRight - 12, 0,
      notchRight, 0,
    );

    // Line to top-right
    path.lineTo(w - cornerRadius, 0);

    // Top-right rounded corner
    path.quadraticBezierTo(w, 0, w, cornerRadius);

    // Line down to bottom-right
    path.lineTo(w, h - cornerRadius);

    // Bottom-right rounded corner
    path.quadraticBezierTo(w, h, w - cornerRadius, h);

    // Line to bottom-left
    path.lineTo(cornerRadius, h);

    // Bottom-left rounded corner
    path.quadraticBezierTo(0, h, 0, h - cornerRadius);

    // Line to top-left
    path.lineTo(0, cornerRadius);

    // Top-left rounded corner
    path.quadraticBezierTo(0, 0, cornerRadius, 0);

    path.close();

    // Draw shadow and bar body
    canvas.drawPath(path, shadowPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _LiquidBarPainter oldDelegate) =>
      oldDelegate.centerX != centerX || oldDelegate.barColor != barColor;
}
