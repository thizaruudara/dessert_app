import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';

// ⚠️ Replace this with your actual institute WhatsApp Business number
const String kInstituteWhatsAppNumber = '+1234567890';
const String kInstituteWhatsAppName = 'Dessert Institute';

class StudentSubmitGuideScreen extends StatelessWidget {
  const StudentSubmitGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Submit Dessert 🍰')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF25D366).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text('📱', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text(
                    'Submit via WhatsApp',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Send your homework to our official number',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _openWhatsApp(context),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Open WhatsApp Chat'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF128C7E),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            Text('How to submit', style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 16),

            ..._steps.asMap().entries.map(
              (e) => _StepCard(number: e.key + 1, step: e.value),
            ),

            const SizedBox(height: 28),

            // Format tips
            Text('Submission formats', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            const _FormatChip(emoji: '📝', label: 'Text answer', color: AppColors.primary),
            const SizedBox(height: 8),
            const _FormatChip(emoji: '📸', label: 'Photo of written work', color: AppColors.accent),
            const SizedBox(height: 8),
            const _FormatChip(emoji: '📄', label: 'PDF / Document', color: AppColors.gold),

            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.darkCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.primary),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Your WhatsApp number must match the one you registered with in this app.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    final number = kInstituteWhatsAppNumber.replaceAll('+', '').replaceAll(' ', '');
    final uri = Uri.parse('https://wa.me/$number?text=Dessert+Submission%3A+');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp')),
        );
      }
    }
  }
}

const _steps = [
  (
    title: 'Open WhatsApp',
    desc: 'Tap the button above or open WhatsApp and search for $kInstituteWhatsAppName.',
    icon: '📱',
  ),
  (
    title: 'Write your student ID',
    desc: 'Start your message with your student ID so we know who you are. Example: "ID: S-2024-001"',
    icon: '🪪',
  ),
  (
    title: 'Send your homework',
    desc: 'Type your answer, attach a photo of your written work, or send a PDF file.',
    icon: '📚',
  ),
  (
    title: 'Wait for review',
    desc: 'Your teacher will review it and mark it as correct or incorrect. You\'ll see the result here!',
    icon: '⏳',
  ),
  (
    title: 'Earn credits',
    desc: 'Correct desserts earn you 10 credits each. Climb the leaderboard!',
    icon: '⭐',
  ),
];

class _StepCard extends StatelessWidget {
  final int number;
  final ({String title, String desc, String icon}) step;

  const _StepCard({required this.number, required this.step});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text('$number',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${step.icon}  ${step.title}',
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 4),
                Text(step.desc,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormatChip extends StatelessWidget {
  final String emoji;
  final String label;
  final Color color;
  const _FormatChip({required this.emoji, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
