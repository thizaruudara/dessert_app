import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/badge_model.dart';
import '../../../core/utils/haptic_feedback_service.dart';

class TrophyRoomSheet extends StatelessWidget {
  final int totalCredits;
  final int approvedSubmissions;
  final int totalSubmissions;
  final int streakDays;

  const TrophyRoomSheet({
    super.key,
    required this.totalCredits,
    required this.approvedSubmissions,
    required this.totalSubmissions,
    this.streakDays = 3,
  });

  static void show(
    BuildContext context, {
    required int totalCredits,
    required int approvedSubmissions,
    required int totalSubmissions,
    int streakDays = 3,
  }) {
    HapticFeedbackService.medium();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TrophyRoomSheet(
        totalCredits: totalCredits,
        approvedSubmissions: approvedSubmissions,
        totalSubmissions: totalSubmissions,
        streakDays: streakDays,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final badges = BadgeItem.calculateBadges(
      totalCredits: totalCredits,
      approvedSubmissions: approvedSubmissions,
      totalSubmissions: totalSubmissions,
      streakDays: streakDays,
    );

    final unlockedCount = badges.where((b) => b.isUnlocked).length;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x30000000),
            blurRadius: 30,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF374151) : const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(3),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Text('🏆', style: TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trophy Room & Flex Zone',
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Unlocked $unlockedCount of ${badges.length} Badges',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: isDark ? Colors.white70 : Colors.black54),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Badge Grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(18),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.85,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              itemCount: badges.length,
              itemBuilder: (context, index) {
                final b = badges[index];
                return _buildBadgeCard(context, b, isDark);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeCard(BuildContext context, BadgeItem badge, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? (badge.isUnlocked ? const Color(0xFF1E293B) : const Color(0xFF0F172A).withOpacity(0.4))
            : (badge.isUnlocked ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9).withOpacity(0.6)),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: badge.isUnlocked
              ? badge.glowColor.withOpacity(0.4)
              : (isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0)),
          width: badge.isUnlocked ? 1.5 : 1,
        ),
        boxShadow: badge.isUnlocked
            ? [
                BoxShadow(
                  color: badge.glowColor.withOpacity(0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Emoji bubble
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: badge.isUnlocked
                  ? badge.glowColor.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.12),
              border: Border.all(
                color: badge.isUnlocked ? badge.glowColor : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                badge.isUnlocked ? badge.emoji : '🔒',
                style: TextStyle(
                  fontSize: badge.isUnlocked ? 26 : 20,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Title
          Text(
            badge.title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),

          // Description
          Text(
            badge.description,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
              fontSize: 10.5,
              height: 1.2,
            ),
          ),
          const Spacer(),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: badge.progress,
              backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                badge.isUnlocked ? badge.glowColor : const Color(0xFF94A3B8),
              ),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 4),

          Text(
            badge.progressLabel,
            style: TextStyle(
              color: badge.isUnlocked ? badge.glowColor : (isDark ? const Color(0xFF64748B) : AppColors.textMuted),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
