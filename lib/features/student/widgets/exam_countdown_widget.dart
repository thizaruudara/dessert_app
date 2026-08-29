import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class ExamCountdownWidget extends StatefulWidget {
  final String examYear;

  const ExamCountdownWidget({
    super.key,
    this.examYear = '2025 A/L',
  });

  @override
  State<ExamCountdownWidget> createState() => _ExamCountdownWidgetState();
}

class _ExamCountdownWidgetState extends State<ExamCountdownWidget> {
  Timer? _timer;
  late Duration _remaining;

  // Approximate target date: November 25th of the exam year
  late DateTime _targetDate;

  @override
  void initState() {
    super.initState();
    _initTargetDate();
    _calculateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _calculateRemaining());
      }
    });
  }

  void _initTargetDate() {
    int year = 2025;
    if (widget.examYear.contains('2026')) {
      year = 2026;
    } else if (widget.examYear.contains('2027')) {
      year = 2027;
    }
    _targetDate = DateTime(year, 11, 25, 8, 30);
  }

  void _calculateRemaining() {
    final now = DateTime.now();
    final diff = _targetDate.difference(now);
    _remaining = diff.isNegative ? Duration.zero : diff;
  }

  @override
  void didUpdateWidget(covariant ExamCountdownWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.examYear != widget.examYear) {
      _initTargetDate();
      _calculateRemaining();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final days = _remaining.inDays;
    final hours = _remaining.inHours % 24;
    final mins = _remaining.inMinutes % 60;
    final secs = _remaining.inSeconds % 60;

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
                    ),
                    child: const Row(
                      children: [
                        Text('⏳ ', style: TextStyle(fontSize: 12)),
                        Text(
                          'A/L TARGET',
                          style: TextStyle(
                            color: Color(0xFFFDE68A),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.examYear} Final Countdown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF10B981),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF10B981),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDigitBox('$days', 'DAYS', const Color(0xFF38BDF8)),
              _buildColon(),
              _buildDigitBox(hours.toString().padLeft(2, '0'), 'HOURS', const Color(0xFF818CF8)),
              _buildColon(),
              _buildDigitBox(mins.toString().padLeft(2, '0'), 'MINS', const Color(0xFFF472B6)),
              _buildColon(),
              _buildDigitBox(secs.toString().padLeft(2, '0'), 'SECS', const Color(0xFFFBBF24)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDigitBox(String val, String label, Color accent) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2.5),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withOpacity(0.55),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withOpacity(0.35)),
        ),
        child: Column(
          children: [
            Text(
              val,
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()],
                shadows: [
                  Shadow(
                    color: accent.withOpacity(0.6),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: accent.withOpacity(0.9),
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColon() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        ':',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
