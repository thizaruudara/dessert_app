import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/models/dessert_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../desserts/providers/desserts_provider.dart';

class AdminReviewScreen extends StatefulWidget {
  final String dessertId;
  const AdminReviewScreen({super.key, required this.dessertId});

  @override
  State<AdminReviewScreen> createState() => _AdminReviewScreenState();
}

class _AdminReviewScreenState extends State<AdminReviewScreen> {
  final _feedbackCtrl = TextEditingController();
  int _credits = 10;
  bool _submitting = false;

  @override
  void dispose() {
    _feedbackCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(bool approve, DessertModel dessert) async {
    setState(() => _submitting = true);
    final admin = context.read<AuthProvider>().user!;
    final provider = context.read<DessertsProvider>();

    if (approve) {
      await provider.approveDessert(
        dessert: dessert,
        admin: admin,
        credits: _credits,
        feedback: _feedbackCtrl.text.trim().isNotEmpty
            ? _feedbackCtrl.text.trim()
            : 'Great work! ✅',
      );
    } else {
      await provider.rejectDessert(
        dessert: dessert,
        admin: admin,
        feedback: _feedbackCtrl.text.trim().isNotEmpty
            ? _feedbackCtrl.text.trim()
            : 'Needs improvement. Please try again. ❌',
      );
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('desserts')
          .doc(widget.dessertId)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }
        final dessert = DessertModel.fromFirestore(snap.data!);
        return _ReviewView(
          dessert: dessert,
          feedbackCtrl: _feedbackCtrl,
          credits: _credits,
          onCreditsChanged: (v) => setState(() => _credits = v),
          submitting: _submitting,
          onApprove: () => _submit(true, dessert),
          onReject: () => _submit(false, dessert),
        );
      },
    );
  }
}

class _ReviewView extends StatelessWidget {
  final DessertModel dessert;
  final TextEditingController feedbackCtrl;
  final int credits;
  final ValueChanged<int> onCreditsChanged;
  final bool submitting;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _ReviewView({
    required this.dessert,
    required this.feedbackCtrl,
    required this.credits,
    required this.onCreditsChanged,
    required this.submitting,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, yyyy · h:mm a');
    final alreadyReviewed = !dessert.isPending;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Submission'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.darkCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primary.withOpacity(0.15),
                    child: Text(
                      dessert.studentName.isNotEmpty ? dessert.studentName[0].toUpperCase() : '?',
                      style: const TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(dessert.studentName,
                            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 16)),
                        const SizedBox(height: 2),
                        Text(dessert.studentPhone,
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(fmt.format(dessert.submittedAt),
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Submission content
            if (dessert.caption != null && dessert.caption!.isNotEmpty) ...[
              Text('Submission', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.darkCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.darkBorder),
                ),
                child: SelectableText(
                  dessert.caption!,
                  style: const TextStyle(color: AppColors.textPrimary, height: 1.6, fontSize: 15),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Media
            if (dessert.mediaUrls.isNotEmpty) ...[
              Text('Attached Files', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 10),
              ...dessert.mediaUrls.map(
                (url) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: AppColors.darkCard,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (!alreadyReviewed) ...[
              // Credits slider
              Text('Credits to award', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.darkCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.darkBorder),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('0', style: TextStyle(color: AppColors.textMuted)),
                        Text('+$credits pts',
                            style: const TextStyle(
                                color: AppColors.gold, fontSize: 22, fontWeight: FontWeight.bold)),
                        const Text('50', style: TextStyle(color: AppColors.textMuted)),
                      ],
                    ),
                    Slider(
                      value: credits.toDouble(),
                      min: 0,
                      max: 50,
                      divisions: 10,
                      activeColor: AppColors.gold,
                      inactiveColor: AppColors.darkBorder,
                      onChanged: (v) => onCreditsChanged(v.toInt()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Feedback
              Text('Feedback (optional)', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 10),
              TextField(
                controller: feedbackCtrl,
                maxLines: 3,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Write feedback for the student...',
                ),
              ),
              const SizedBox(height: 32),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: submitting ? null : onReject,
                      icon: const Icon(Icons.close, color: AppColors.error),
                      label: const Text('Reject', style: TextStyle(color: AppColors.error)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: submitting ? null : onApprove,
                      icon: submitting
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Already reviewed — show result
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: dessert.isApproved
                      ? AppColors.success.withOpacity(0.1)
                      : AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: dessert.isApproved ? AppColors.success.withOpacity(0.4) : AppColors.error.withOpacity(0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dessert.isApproved ? '✅ Approved' : '❌ Rejected',
                      style: TextStyle(
                        color: dessert.isApproved ? AppColors.success : AppColors.error,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (dessert.adminFeedback != null) ...[
                      const SizedBox(height: 8),
                      Text(dessert.adminFeedback!,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
