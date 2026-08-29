import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/dessert_model.dart';

class StudentProgressChart extends StatefulWidget {
  final List<DessertModel> desserts;
  final int totalCredits;

  const StudentProgressChart({
    super.key,
    required this.desserts,
    required this.totalCredits,
  });

  @override
  State<StudentProgressChart> createState() => _StudentProgressChartState();
}

class _StudentProgressChartState extends State<StudentProgressChart> {
  int _selectedTab = 0; // 0 = Weekly Activity, 1 = Credit Growth

  @override
  Widget build(BuildContext context) {
    // Compute last 7 days submissions
    final now = DateTime.now();
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final counts = List.filled(7, 0);

    for (final d in widget.desserts) {
      final diff = now.difference(d.submittedAt).inDays;
      if (diff >= 0 && diff < 7) {
        final weekdayIndex = (d.submittedAt.weekday - 1) % 7;
        counts[weekdayIndex]++;
      }
    }

    final maxCount = counts.reduce(math.max);
    final highestVal = maxCount > 0 ? maxCount : 4;
    final approvedCount = widget.desserts.where((d) => d.isApproved).length;
    final totalSubmissions = widget.desserts.length;
    final successRate = totalSubmissions > 0
        ? ((approvedCount / totalSubmissions) * 100).toInt()
        : 100;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Tab Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.insights_rounded, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Learning Progress',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Activity & Performance',
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
              // Segmented Toggle
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.backgroundSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    _buildTabBtn('Activity', 0),
                    _buildTabBtn('Growth', 1),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Mini Stat Badges
          Row(
            children: [
              _buildMiniStat(
                label: 'Pass Rate',
                value: '$successRate%',
                icon: Icons.check_circle_outline_rounded,
                color: AppColors.success,
              ),
              const SizedBox(width: 12),
              _buildMiniStat(
                label: 'Submissions',
                value: '$totalSubmissions',
                icon: Icons.auto_awesome_rounded,
                color: AppColors.primary,
              ),
              const SizedBox(width: 12),
              _buildMiniStat(
                label: 'Total Pts',
                value: '${widget.totalCredits}',
                icon: Icons.stars_rounded,
                color: AppColors.gold,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Chart Display
          SizedBox(
            height: 140,
            child: _selectedTab == 0
                ? _buildWeeklyBarChart(dayNames, counts, highestVal)
                : _buildCreditGrowthCurve(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBtn(String label, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? const [BoxShadow(color: Color(0x0D0F172A), blurRadius: 4, offset: Offset(0, 1))]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppColors.primary : AppColors.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyBarChart(List<String> dayNames, List<int> counts, int highestVal) {
    final todayWeekday = (DateTime.now().weekday - 1) % 7;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (i) {
        final count = counts[i];
        final isToday = i == todayWeekday;
        final heightFactor = math.max(0.12, count / highestVal);

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (count > 0)
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isToday ? AppColors.primary : AppColors.textSecondary,
                    ),
                  ),
                const SizedBox(height: 4),
                // Animated / Styled Bar
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: heightFactor,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: isToday
                                ? [AppColors.primary, AppColors.primaryDark]
                                : count > 0
                                    ? [AppColors.primaryLight.withOpacity(0.8), AppColors.primary.withOpacity(0.5)]
                                    : [AppColors.backgroundSoft, AppColors.border],
                          ),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: isToday && count > 0
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  dayNames[i],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                    color: isToday ? AppColors.primary : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCreditGrowthCurve() {
    return CustomPaint(
      size: const Size(double.infinity, 140),
      painter: _GrowthCurvePainter(totalCredits: widget.totalCredits),
    );
  }
}

class _GrowthCurvePainter extends CustomPainter {
  final int totalCredits;

  _GrowthCurvePainter({required this.totalCredits});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Grid lines
    final gridPaint = Paint()
      ..color = AppColors.border.withOpacity(0.6)
      ..strokeWidth = 1;

    for (int i = 1; i <= 3; i++) {
      final y = (h / 4) * i;
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    // Points calculation (simulating cumulative growth)
    final points = [
      Offset(0, h * 0.85),
      Offset(w * 0.2, h * 0.70),
      Offset(w * 0.4, h * 0.65),
      Offset(w * 0.6, h * 0.45),
      Offset(w * 0.8, h * 0.30),
      Offset(w, h * 0.15),
    ];

    // Smooth Bezier path
    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final cx = (p0.dx + p1.dx) / 2;
      path.cubicTo(cx, p0.dy, cx, p1.dy, p1.dx, p1.dy);
    }

    // Gradient Fill under curve
    final fillPath = Path.from(path)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x33227AFF),
          Color(0x00227AFF),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(fillPath, fillPaint);

    // Line stroke
    final strokePaint = Paint()
      ..shader = const LinearGradient(
        colors: [AppColors.primaryLight, AppColors.primary, AppColors.primaryDark],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, strokePaint);

    // Draw Glowing End Point
    final lastPt = points.last;
    final glowPaint = Paint()
      ..color = AppColors.primary.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(lastPt, 8, glowPaint);

    final dotPaint = Paint()..color = AppColors.primary;
    canvas.drawCircle(lastPt, 5, dotPaint);

    final innerDot = Paint()..color = Colors.white;
    canvas.drawCircle(lastPt, 2.5, innerDot);
  }

  @override
  bool shouldRepaint(covariant _GrowthCurvePainter oldDelegate) =>
      oldDelegate.totalCredits != totalCredits;
}
