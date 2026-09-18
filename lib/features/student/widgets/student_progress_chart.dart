import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  int _selectedTab = 0; // 0 = Weekly, 1 = Monthly, 2 = All-Time

  @override
  Widget build(BuildContext context) {
    try {
      final now = DateTime.now();

      List<String> labels;
      List<int> counts;
      int activeIndex; // Current day/week/month to highlight
      int periodSubmissions;
      int periodApproved;
      String periodSubLabel;

      if (_selectedTab == 0) {
        // ── WEEKLY FILTER (Mon to Sun of current week) ──
        labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        counts = List.filled(7, 0);
        activeIndex = (now.weekday - 1) % 7;
        periodSubLabel = 'This Week';

        // Current calendar week (Monday 00:00:00 to end of Sunday)
        final currentMonday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
        final nextMonday = currentMonday.add(const Duration(days: 7));

        final weeklyDesserts = widget.desserts.where((d) {
          return d.submittedAt.isAfter(currentMonday.subtract(const Duration(seconds: 1))) &&
              d.submittedAt.isBefore(nextMonday);
        }).toList();

        for (final d in weeklyDesserts) {
          final weekdayIndex = (d.submittedAt.weekday - 1) % 7;
          counts[weekdayIndex]++;
        }

        periodSubmissions = weeklyDesserts.length;
        periodApproved = weeklyDesserts.where((d) => d.isApproved).length;
      } else if (_selectedTab == 1) {
        // ── MONTHLY FILTER (Weeks of current month) ──
        labels = ['Wk 1', 'Wk 2', 'Wk 3', 'Wk 4', 'Wk 5'];
        counts = List.filled(5, 0);
        activeIndex = ((now.day - 1) ~/ 7).clamp(0, 4);
        periodSubLabel = 'This Month';

        final monthlyDesserts = widget.desserts.where((d) {
          return d.submittedAt.year == now.year && d.submittedAt.month == now.month;
        }).toList();

        for (final d in monthlyDesserts) {
          final weekIndex = ((d.submittedAt.day - 1) ~/ 7).clamp(0, 4);
          counts[weekIndex]++;
        }

        periodSubmissions = monthlyDesserts.length;
        periodApproved = monthlyDesserts.where((d) => d.isApproved).length;
      } else {
        // ── ALL-TIME FILTER (Past 6 Months) ──
        final monthKeys = <DateTime>[];
        labels = [];
        for (int i = 5; i >= 0; i--) {
          final mDate = DateTime(now.year, now.month - i, 1);
          monthKeys.add(mDate);
          labels.add(DateFormat('MMM').format(mDate));
        }
        counts = List.filled(6, 0);
        activeIndex = 5; // Current month
        periodSubLabel = 'All Time';

        for (final d in widget.desserts) {
          for (int i = 0; i < monthKeys.length; i++) {
            final m = monthKeys[i];
            if (d.submittedAt.year == m.year && d.submittedAt.month == m.month) {
              counts[i]++;
              break;
            }
          }
        }

        periodSubmissions = widget.desserts.length;
        periodApproved = widget.desserts.where((d) => d.isApproved).length;
      }

      final successRate = periodSubmissions > 0
          ? ((periodApproved / periodSubmissions) * 100).toInt()
          : (widget.desserts.isNotEmpty
              ? ((widget.desserts.where((d) => d.isApproved).length / widget.desserts.length) * 100).toInt()
              : 100);

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
                      child: const Icon(Icons.show_chart_rounded, color: AppColors.primary, size: 20),
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
                // Segmented Toggle (Weekly, Monthly, All-Time)
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      _buildTabBtn('Weekly', 0),
                      _buildTabBtn('Monthly', 1),
                      _buildTabBtn('All-Time', 2),
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
                  label: periodSubLabel,
                  value: '$periodSubmissions',
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
            const SizedBox(height: 20),

            // Line Chart Display
            SizedBox(
              height: 160,
              child: _buildProgressLineChart(labels, counts, activeIndex),
            ),
          ],
        ),
      );
    } catch (e, stack) {
      debugPrint('Error in StudentProgressChart.build: $e\n$stack');
      return const SizedBox.shrink();
    }
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
            fontSize: 11.5,
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
                    style: const TextStyle(
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

  Widget _buildProgressLineChart(List<String> labels, List<int> counts, int activeIndex) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : 300.0;
        return CustomPaint(
          size: Size(w, 160),
          painter: _ActivityLineChartPainter(
            dayNames: labels,
            counts: counts,
            todayWeekday: activeIndex,
          ),
        );
      },
    );
  }
}

class _ActivityLineChartPainter extends CustomPainter {
  final List<String> dayNames;
  final List<int> counts;
  final int todayWeekday;

  _ActivityLineChartPainter({
    required this.dayNames,
    required this.counts,
    required this.todayWeekday,
  });

  @override
  void paint(Canvas canvas, Size size) {
    try {
      if (!size.width.isFinite || size.width <= 0 || !size.height.isFinite || size.height <= 0) return;
      final w = size.width;
      final chartHeight = size.height - 30; // Reserve 30px for X-axis labels
      if (chartHeight <= 0) return;
      final maxCount = counts.isEmpty ? 0 : counts.reduce(math.max);
      final highestVal = maxCount > 0 ? (maxCount + 1) : 4;

      // Grid lines (3 horizontal levels)
      final gridPaint = Paint()
        ..color = AppColors.border.withOpacity(0.5)
        ..strokeWidth = 1;

      for (int i = 1; i <= 3; i++) {
        final y = (chartHeight / 4) * i;
        canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
      }

      // Compute coordinate points dynamically according to dayNames count
      final numPoints = dayNames.length;
      final points = <Offset>[];
      final stepX = numPoints > 1 ? w / (numPoints - 1) : w;

      for (int i = 0; i < numPoints; i++) {
        final x = i * stepX;
        final val = i < counts.length ? counts[i] : 0;
        final y = chartHeight - (val / highestVal) * (chartHeight - 20) - 10;
        points.add(Offset(x, y));
      }

      // Smooth Bezier path
      final path = Path()..moveTo(points[0].dx, points[0].dy);
      for (int i = 0; i < points.length - 1; i++) {
        final p0 = points[i];
        final p1 = points[i + 1];
        final cx = (p0.dx + p1.dx) / 2;
        path.cubicTo(cx, p0.dy, cx, p1.dy, p1.dx, p1.dy);
      }

      // Gradient Fill Area
      final fillPath = Path.from(path)
        ..lineTo(w, chartHeight)
        ..lineTo(0, chartHeight)
        ..close();

      final fillPaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x35227AFF),
            Color(0x02227AFF),
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, chartHeight));

      canvas.drawPath(fillPath, fillPaint);

      // Line Stroke
      final linePaint = Paint()
        ..shader = const LinearGradient(
          colors: [AppColors.primaryLight, AppColors.primary, AppColors.primaryDark],
        ).createShader(Rect.fromLTWH(0, 0, w, chartHeight))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(path, linePaint);

      // Draw Data Points, Values & X-Axis Labels
      for (int i = 0; i < numPoints; i++) {
        final pt = points[i];
        final count = i < counts.length ? counts[i] : 0;
        final isToday = i == todayWeekday;

        // Glow & Dot on Active days or Today
        if (count > 0 || isToday) {
          final glowPaint = Paint()
            ..color = (isToday ? AppColors.primary : AppColors.primaryLight).withOpacity(0.3);
          canvas.drawCircle(pt, 7, glowPaint);

          final dotPaint = Paint()..color = isToday ? AppColors.primary : AppColors.primaryLight;
          canvas.drawCircle(pt, 4.5, dotPaint);

          final innerDot = Paint()..color = Colors.white;
          canvas.drawCircle(pt, 2, innerDot);

          // Value text bubble above dot
          if (count > 0) {
            final tpVal = TextPainter(
              text: TextSpan(
                text: '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isToday ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout();

            final bubbleRect = RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset(pt.dx, pt.dy - 16),
                width: tpVal.width + 10,
                height: tpVal.height + 4,
              ),
              const Radius.circular(6),
            );

            canvas.drawRRect(
              bubbleRect,
              Paint()..color = isToday ? AppColors.primaryLight.withOpacity(0.25) : AppColors.backgroundSoft,
            );
            tpVal.paint(canvas, Offset(pt.dx - tpVal.width / 2, pt.dy - 16 - tpVal.height / 2));
          }
        }

        // X-Axis Label (Mon/Tue... or Wk 1... or Jan/Feb...)
        if (i < dayNames.length) {
          final tpLabel = TextPainter(
            text: TextSpan(
              text: dayNames[i],
              style: TextStyle(
                fontSize: 11,
                fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                color: isToday ? AppColors.primary : AppColors.textMuted,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();

          tpLabel.paint(canvas, Offset(pt.dx - tpLabel.width / 2, chartHeight + 10));
        }
      }
    } catch (e, stack) {
      debugPrint('Error in _ActivityLineChartPainter: $e\n$stack');
    }
  }

  @override
  bool shouldRepaint(covariant _ActivityLineChartPainter oldDelegate) => true;
}
