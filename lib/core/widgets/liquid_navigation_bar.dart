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
  State<LiquidNavigationBar> createState() => _LiquidNavigationBarState();
}

class _LiquidNavigationBarState extends State<LiquidNavigationBar>
    with TickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _positionAnimation;
  late AnimationController _bubblePopController;
  late Animation<double> _bubbleScaleAnimation;

  @override
  void initState() {
    super.initState();
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

    _bubblePopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _bubbleScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.88), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 0.88, end: 1.08), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 25),
    ]).animate(CurvedAnimation(
      parent: _bubblePopController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void didUpdateWidget(covariant LiquidNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _positionAnimation = Tween<double>(
        begin: _positionAnimation.value,
        end: widget.selectedIndex.toDouble(),
      ).animate(CurvedAnimation(
        parent: _animController,
        curve: Curves.easeInOutCubicEmphasized,
      ));
      _animController.forward(from: 0.0);
      _bubblePopController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _bubblePopController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.items.length;
    const barHeight = 62.0;
    const circleRadius = 26.0;

    return Container(
      color: widget.barColor,
      child: SafeArea(
        top: false,
        bottom: true,
        child: SizedBox(
          height: barHeight + circleRadius,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final itemWidth = width / count;

              return AnimatedBuilder(
                animation: Listenable.merge([_animController, _bubblePopController]),
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
                        bottom: 0,
                        child: CustomPaint(
                          painter: _LiquidBarPainter(
                            centerX: circleCenterX,
                            barColor: widget.barColor,
                            borderColor: widget.borderColor,
                          ),
                          child: Row(
                            children: List.generate(count, (index) {
                              final isSelected = widget.selectedIndex == index;
                              final item = widget.items[index];

                              return Expanded(
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => widget.onItemSelected(index),
                                    customBorder: const CircleBorder(),
                                    splashColor: widget.activeTextColor.withOpacity(0.08),
                                    highlightColor: Colors.transparent,
                                    child: Container(
                                      height: barHeight,
                                      alignment: Alignment.center,
                                      child: isSelected
                                          ? Padding(
                                              padding: const EdgeInsets.only(top: 28),
                                              child: AnimatedOpacity(
                                                duration: const Duration(milliseconds: 200),
                                                opacity: (currentPos - index).abs() < 0.3 ? 1.0 : 0.0,
                                                child: Text(
                                                  item.label,
                                                  style: TextStyle(
                                                    color: widget.activeTextColor,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: -0.2,
                                                  ),
                                                ),
                                              ),
                                            )
                                          : AnimatedScale(
                                              scale: (currentPos - index).abs() < 0.5 ? 0.75 : 1.0,
                                              duration: const Duration(milliseconds: 180),
                                              child: Icon(
                                                item.icon,
                                                color: widget.inactiveIconColor,
                                                size: 22,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ),

                      // ── 2. Elevated Floating Liquid Circle (Bubble) ──────────
                      Positioned(
                        top: 0,
                        left: circleCenterX - circleRadius,
                        child: GestureDetector(
                          onTap: () => widget.onItemSelected(widget.selectedIndex),
                          child: ScaleTransition(
                            scale: _bubbleScaleAnimation,
                            child: Container(
                              width: circleRadius * 2,
                              height: circleRadius * 2,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: widget.activeCircleGradient,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.85),
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF2563EB).withOpacity(0.38),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                  BoxShadow(
                                    color: const Color(0x180F172A),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
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
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LiquidBarPainter extends CustomPainter {
  final double centerX;
  final Color barColor;
  final Color borderColor;

  _LiquidBarPainter({
    required this.centerX,
    required this.barColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const notchWidth = 72.0;
    const notchDepth = 28.0;

    final paint = Paint()
      ..color = barColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final shadowPaint = Paint()
      ..color = const Color(0x100F172A)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    final path = Path();

    // Start top-left
    path.moveTo(0, 0);

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
    path.lineTo(w, 0);

    // Line down to bottom-right
    path.lineTo(w, h);

    // Line to bottom-left
    path.lineTo(0, h);

    path.close();

    // Draw subtle drop shadow above bar
    canvas.save();
    canvas.translate(0, -2);
    canvas.drawPath(path, shadowPaint);
    canvas.restore();

    // Draw bar body
    canvas.drawPath(path, paint);

    // Draw top border + notch curve
    final borderPath = Path();
    borderPath.moveTo(0, 0);
    borderPath.lineTo(notchLeft, 0);
    borderPath.cubicTo(
      notchLeft + 12, 0,
      centerX - 24, notchDepth,
      centerX, notchDepth,
    );
    borderPath.cubicTo(
      centerX + 24, notchDepth,
      notchRight - 12, 0,
      notchRight, 0,
    );
    borderPath.lineTo(w, 0);
    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _LiquidBarPainter oldDelegate) =>
      oldDelegate.centerX != centerX ||
      oldDelegate.barColor != barColor ||
      oldDelegate.borderColor != borderColor;
}
