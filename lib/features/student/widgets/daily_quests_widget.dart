import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/haptic_feedback_service.dart';
import '../../../core/widgets/confetti_overlay.dart';
import '../../../core/widgets/liquid_glass_card.dart';

class DailyQuestsWidget extends StatefulWidget {
  final int totalSubmissions;
  final VoidCallback onOpenLeaderboard;
  final EdgeInsetsGeometry? margin;

  const DailyQuestsWidget({
    super.key,
    required this.totalSubmissions,
    required this.onOpenLeaderboard,
    this.margin,
  });

  @override
  State<DailyQuestsWidget> createState() => _DailyQuestsWidgetState();
}

class _DailyQuestsWidgetState extends State<DailyQuestsWidget> {
  bool _askedAiTutor = false;
  bool _checkedRank = false;
  bool _claimedMysteryBox = false;

  Future<void> _launchWhatsAppAiTutor() async {
    HapticFeedbackService.medium();
    setState(() => _askedAiTutor = true);
    final appUri = Uri.parse('tg://resolve?domain=edupeakbot&start=daily_quest');
    final webUri = Uri.parse('https://t.me/edupeakbot?start=daily_quest');
    try {
      if (await canLaunchUrl(appUri)) {
        await launchUrl(appUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    }
  }

  void _claimMysteryBox() {
    if (_claimedMysteryBox) return;

    HapticFeedbackService.success();
    ConfettiOverlay.show(context);
    setState(() => _claimedMysteryBox = true);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Theme.of(context).cardTheme.color ?? Colors.white,
        title: const Column(
          children: [
            Text('🎁', style: TextStyle(fontSize: 48)),
            SizedBox(height: 8),
            Text(
              'Mystery Box Unlocked!',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '🎉 You crushed all daily quests today!\n\n+50 Bonus Study Credits & 1-Day Streak Guard awarded to your account!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF227AFF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Awesome! 🚀', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    try {
      final isDark = Theme.of(context).brightness == Brightness.dark;

      final bool quest1 = widget.totalSubmissions > 0;
      final bool quest2 = _askedAiTutor;
      final bool quest3 = _checkedRank;

      int completedCount = (quest1 ? 1 : 0) + (quest2 ? 1 : 0) + (quest3 ? 1 : 0);
      final double progress = completedCount / 3.0;
      final bool allDone = completedCount >= 3;

      return LiquidGlassCard(
        margin: widget.margin ?? EdgeInsets.zero,
        padding: const EdgeInsets.all(18),
        borderRadius: BorderRadius.circular(24),
        blur: 18,
        surfaceOpacity: isDark ? 0.60 : 0.86,
        glowColor: const Color(0xFF227AFF),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header & Progress
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF227AFF).withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Text('🎯', style: TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daily Study Quests',
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.textPrimary,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          '$completedCount of 3 completed',
                          style: TextStyle(
                            color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Mystery Box Button
                GestureDetector(
                  onTap: allDone ? _claimMysteryBox : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: allDone && !_claimedMysteryBox
                          ? const LinearGradient(
                              colors: [Color(0xFFF59E0B), Color(0xFFEAB308)],
                            )
                          : null,
                      color: _claimedMysteryBox
                          ? const Color(0xFF10B981)
                          : (allDone ? null : (isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF5FF))),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: allDone && !_claimedMysteryBox
                            ? const Color(0xFFF59E0B)
                            : (isDark ? const Color(0xFF334155) : const Color(0xFFDCE7FD)),
                      ),
                      boxShadow: allDone && !_claimedMysteryBox
                          ? [
                              BoxShadow(
                                color: const Color(0xFFF59E0B).withOpacity(0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      children: [
                        Text(
                          _claimedMysteryBox ? '✅' : '🎁',
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _claimedMysteryBox
                              ? 'Claimed'
                              : (allDone ? 'OPEN LOOT!' : 'Mystery Box'),
                          style: TextStyle(
                            color: allDone || _claimedMysteryBox
                                ? Colors.white
                                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF2563EB)),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(
                  allDone ? const Color(0xFF10B981) : const Color(0xFF227AFF),
                ),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 14),

            // Quest Items
            _buildQuestTile(
              emoji: '📝',
              title: 'Submit Today\'s Homework Solution',
              xp: '+25 XP',
              isDone: quest1,
              isDark: isDark,
              onTap: () {
                HapticFeedbackService.light();
                context.go('/student/desserts');
              },
            ),
            const SizedBox(height: 8),
            _buildQuestTile(
              emoji: '🤖',
              title: 'Consult WhatsApp 24/7 AI Tutor',
              xp: '+10 XP',
              isDone: quest2,
              isDark: isDark,
              onTap: _launchWhatsAppAiTutor,
            ),
            const SizedBox(height: 8),
            _buildQuestTile(
              emoji: '🏆',
              title: 'Check Institute Leaderboard Standings',
              xp: '+5 XP',
              isDone: quest3,
              isDark: isDark,
              onTap: () {
                HapticFeedbackService.light();
                setState(() => _checkedRank = true);
                widget.onOpenLeaderboard();
              },
            ),
          ],
        ),
      );
    } catch (e, stack) {
      debugPrint('Error in DailyQuestsWidget.build: $e\n$stack');
      return const SizedBox.shrink();
    }
  }

  Widget _buildQuestTile({
    required String emoji,
    required String title,
    required String xp,
    required bool isDone,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDone
              ? const Color(0xFF10B981).withOpacity(0.08)
              : (isDark ? const Color(0xFF1E293B).withOpacity(0.5) : Colors.white.withOpacity(0.7)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDone
                ? const Color(0xFF10B981).withOpacity(0.3)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.textPrimary,
                  fontSize: 12.5,
                  fontWeight: isDone ? FontWeight.w700 : FontWeight.w600,
                  decoration: isDone ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isDone
                    ? const Color(0xFF10B981).withOpacity(0.15)
                    : const Color(0xFF227AFF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                isDone ? 'COMPLETED' : xp,
                style: TextStyle(
                  color: isDone ? const Color(0xFF10B981) : const Color(0xFF227AFF),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
