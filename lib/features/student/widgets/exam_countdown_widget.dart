import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/models/exam_countdown_model.dart';
import '../../../core/services/exam_countdown_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/liquid_glass_card.dart';

class ExamCountdownWidget extends StatefulWidget {
  final String examYear;

  const ExamCountdownWidget({
    super.key,
    this.examYear = '2027 A/L',
  });

  @override
  State<ExamCountdownWidget> createState() => _ExamCountdownWidgetState();
}

class _ExamCountdownWidgetState extends State<ExamCountdownWidget>
    with SingleTickerProviderStateMixin {
  final ExamCountdownService _service = ExamCountdownService();
  Timer? _timer;
  late Duration _remaining;
  late DateTime _targetDate;
  String _displayTitle = '';
  bool _isEnabled = false;
  StreamSubscription<ExamCountdownConfig?>? _configSubscription;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initDefaultTargetDate();
    _calculateRemaining();
    _subscribeToConfig();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _calculateRemaining());
      }
    });
  }

  void _initDefaultTargetDate() {
    final match = RegExp(r'\d{4}').firstMatch(widget.examYear);
    int year = match != null ? int.parse(match.group(0)!) : 2027;
    _targetDate = DateTime(year, 11, 25, 8, 30);
    _displayTitle = '${widget.examYear} Final Countdown';
  }

  void _subscribeToConfig() {
    _configSubscription?.cancel();
    _configSubscription = _service.streamConfigForYear(widget.examYear).listen((config) {
      if (!mounted) return;
      if (config != null) {
        setState(() {
          _isEnabled = config.isEnabled;
          _targetDate = config.targetDate;
          _displayTitle = config.customTitle.isNotEmpty
              ? config.customTitle
              : '${widget.examYear} Final Countdown';
          _calculateRemaining();
        });
      } else {
        setState(() {
          _isEnabled = false;
        });
      }
    });
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
      _initDefaultTargetDate();
      _subscribeToConfig();
      _calculateRemaining();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _configSubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isEnabled) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final days = _remaining.inDays;
    final hours = _remaining.inHours % 24;
    final mins = _remaining.inMinutes % 60;
    final secs = _remaining.inSeconds % 60;

    return LiquidGlassCard(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(22),
      blur: 20,
      surfaceOpacity: isDark ? 0.60 : 0.88,
      glowColor: const Color(0xFF227AFF),
      borderColor: isDark ? Colors.white.withOpacity(0.18) : Colors.white.withOpacity(0.95),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Target Badge + Title + Live Pulsing Beacon
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFFD97706).withOpacity(0.3), const Color(0xFFB45309).withOpacity(0.3)]
                        : [const Color(0xFFFEF3C7), const Color(0xFFFDE68A)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFFF59E0B).withOpacity(0.5) : const Color(0xFFF59E0B).withOpacity(0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('⏳ ', style: TextStyle(fontSize: 11)),
                    Text(
                      'A/L TARGET',
                      style: TextStyle(
                        color: isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _displayTitle,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              // Live animated beacon dot
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, _) {
                  return Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF10B981),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withOpacity(0.6 * _pulseAnimation.value.clamp(0.4, 1.0)),
                          blurRadius: 7 * _pulseAnimation.value,
                          spreadRadius: 2 * (_pulseAnimation.value - 0.7),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Countdown Digits Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDigitBox('$days', 'DAYS', const Color(0xFF0284C7), isDark),
              _buildColon(isDark),
              _buildDigitBox(hours.toString().padLeft(2, '0'), 'HOURS', const Color(0xFF4F46E5), isDark),
              _buildColon(isDark),
              _buildDigitBox(mins.toString().padLeft(2, '0'), 'MINS', const Color(0xFF9333EA), isDark),
              _buildColon(isDark),
              _buildDigitBox(secs.toString().padLeft(2, '0'), 'SECS', const Color(0xFFEA580C), isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDigitBox(String val, String label, Color accent, bool isDark) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2.5),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF0F172A).withOpacity(0.65)
              : Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: accent.withOpacity(isDark ? 0.35 : 0.22),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(isDark ? 0.15 : 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              val,
              style: TextStyle(
                color: isDark ? Colors.white : accent,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()],
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isDark ? accent.withOpacity(0.9) : accent.withOpacity(0.85),
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColon(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        ':',
        style: TextStyle(
          color: isDark ? Colors.white60 : const Color(0xFF94A3B8),
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
