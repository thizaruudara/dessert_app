import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../core/models/dessert_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/media_image_view.dart';

class DessertDetailScreen extends StatelessWidget {
  final String dessertId;
  const DessertDetailScreen({super.key, required this.dessertId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('desserts')
          .doc(dessertId)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }
        if (!snap.hasData || !snap.data!.exists) {
          return const Scaffold(body: Center(child: Text('Dessert not found')));
        }
        final dessert = DessertModel.fromFirestore(snap.data!);
        return _DessertDetailView(dessert: dessert);
      },
    );
  }
}

class _DessertDetailView extends StatelessWidget {
  final DessertModel dessert;
  const _DessertDetailView({required this.dessert});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, yyyy · h:mm a');
    return Scaffold(
      appBar: AppBar(title: const Text('Submission Detail')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status banner
            _StatusBanner(dessert: dessert),
            const SizedBox(height: 20),

            // Submission content
            if (dessert.caption != null && dessert.caption!.isNotEmpty) ...[
              Text('Your Answer', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.darkCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.darkBorder),
                ),
                child: Text(
                  dessert.caption!,
                  style: const TextStyle(color: AppColors.textPrimary, height: 1.5),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Images
            if (dessert.mediaUrls.isNotEmpty) ...[
              Text('Attached Files', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              ...dessert.mediaUrls.map(
                (url) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: AppColors.darkCard,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: MediaImageView(
                    url: url,
                    fit: BoxFit.cover,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Admin feedback
            if (dessert.adminFeedback != null) ...[
              Text('Teacher Feedback', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: dessert.isApproved
                      ? AppColors.success.withOpacity(0.08)
                      : AppColors.error.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: dessert.isApproved
                        ? AppColors.success.withOpacity(0.3)
                        : AppColors.error.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  dessert.adminFeedback!,
                  style: TextStyle(
                    color: dessert.isApproved ? AppColors.success : AppColors.error,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Metadata
            _MetaRow(label: 'Submitted', value: fmt.format(dessert.submittedAt)),
            if (dessert.reviewedAt != null)
              _MetaRow(label: 'Reviewed', value: fmt.format(dessert.reviewedAt!)),
            if (dessert.subject != null)
              _MetaRow(label: 'Subject', value: dessert.subject!),
            if (dessert.isApproved)
              _MetaRow(
                label: 'Credits Earned',
                value: '+${dessert.creditsAwarded} pts',
                valueColor: AppColors.success,
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final DessertModel dessert;
  const _StatusBanner({required this.dessert});

  @override
  Widget build(BuildContext context) {
    final color = dessert.isApproved
        ? AppColors.success
        : dessert.isRejected
            ? AppColors.error
            : AppColors.gold;
    final label = dessert.isApproved
        ? '✅  Approved'
        : dessert.isRejected
            ? '❌  Needs Improvement'
            : '⏳  Awaiting Review';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
          if (dessert.isApproved)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '+${dessert.creditsAwarded} pts',
                style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _MetaRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text('$label:', style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
