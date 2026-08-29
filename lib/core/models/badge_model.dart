import 'package:flutter/material.dart';

class BadgeItem {
  final String id;
  final String title;
  final String description;
  final String emoji;
  final Color glowColor;
  final bool isUnlocked;
  final double progress; // 0.0 to 1.0
  final String progressLabel;

  const BadgeItem({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    required this.glowColor,
    required this.isUnlocked,
    required this.progress,
    required this.progressLabel,
  });

  static List<BadgeItem> calculateBadges({
    required int totalCredits,
    required int approvedSubmissions,
    required int totalSubmissions,
    required int streakDays,
  }) {
    return [
      BadgeItem(
        id: 'streak_3',
        title: '3-Day Fire Streak',
        description: 'Stay active and learn for 3 consecutive days.',
        emoji: '🔥',
        glowColor: const Color(0xFFF97316),
        isUnlocked: streakDays >= 3,
        progress: (streakDays / 3).clamp(0.0, 1.0),
        progressLabel: '$streakDays / 3 Days',
      ),
      BadgeItem(
        id: 'first_masterpiece',
        title: 'First Masterpiece',
        description: 'Get your very first homework approved by the teacher.',
        emoji: '🍰',
        glowColor: const Color(0xFFEC4899),
        isUnlocked: approvedSubmissions >= 1,
        progress: (approvedSubmissions / 1).clamp(0.0, 1.0),
        progressLabel: '$approvedSubmissions / 1 Approved',
      ),
      BadgeItem(
        id: 'century_club',
        title: 'Century Scholar',
        description: 'Earn 100 or more XP credits across all homework.',
        emoji: '⚡',
        glowColor: const Color(0xFFEAB308),
        isUnlocked: totalCredits >= 100,
        progress: (totalCredits / 100).clamp(0.0, 1.0),
        progressLabel: '$totalCredits / 100 XP',
      ),
      BadgeItem(
        id: 'speed_demon',
        title: 'Speed Demon',
        description: 'Submit 5 homework solutions with high precision.',
        emoji: '🚀',
        glowColor: const Color(0xFF38BDF8),
        isUnlocked: totalSubmissions >= 5,
        progress: (totalSubmissions / 5).clamp(0.0, 1.0),
        progressLabel: '$totalSubmissions / 5 Done',
      ),
      BadgeItem(
        id: 'night_owl',
        title: 'Night Owl Scholar',
        description: 'Dedication at night! Submit homework after 9:00 PM.',
        emoji: '🦉',
        glowColor: const Color(0xFF8B5CF6),
        isUnlocked: totalSubmissions >= 2,
        progress: (totalSubmissions / 2).clamp(0.0, 1.0),
        progressLabel: '${totalSubmissions >= 2 ? 2 : totalSubmissions} / 2 Night Subs',
      ),
      BadgeItem(
        id: 'podium_king',
        title: 'Podium King',
        description: 'Reach the Top 3 on the Institute Leaderboard.',
        emoji: '👑',
        glowColor: const Color(0xFFF59E0B),
        isUnlocked: totalCredits >= 200,
        progress: (totalCredits / 200).clamp(0.0, 1.0),
        progressLabel: '$totalCredits / 200 XP',
      ),
      BadgeItem(
        id: 'grandmaster',
        title: 'Dessert Grandmaster',
        description: 'Accumulate 500 XP and achieve ultimate mastery.',
        emoji: '🏆',
        glowColor: const Color(0xFF10B981),
        isUnlocked: totalCredits >= 500,
        progress: (totalCredits / 500).clamp(0.0, 1.0),
        progressLabel: '$totalCredits / 500 XP',
      ),
      BadgeItem(
        id: 'ai_pioneer',
        title: 'AI Study Pioneer',
        description: 'Consult the 24/7 WhatsApp AI Tutor for study help.',
        emoji: '🤖',
        glowColor: const Color(0xFF06B6D4),
        isUnlocked: true,
        progress: 1.0,
        progressLabel: 'Unlocked ✨',
      ),
    ];
  }
}
