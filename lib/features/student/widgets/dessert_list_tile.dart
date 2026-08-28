import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/models/dessert_model.dart';
import '../../../core/theme/app_theme.dart';

class DessertListTile extends StatelessWidget {
  final DessertModel dessert;
  final VoidCallback onTap;

  const DessertListTile({super.key, required this.dessert, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _borderColor,
            width: dessert.isPending ? 1 : 1.5,
          ),
        ),
        child: Row(
          children: [
            // Status icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Text(_emoji, style: const TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          dessert.caption ?? 'Photo submission',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (dessert.isApproved)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('+${dessert.creditsAwarded} pts',
                              style: const TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _statusLabel,
                          style: TextStyle(
                            color: _statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeago.format(dessert.submittedAt),
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Color get _statusColor {
    if (dessert.isApproved) return AppColors.success;
    if (dessert.isRejected) return AppColors.error;
    return AppColors.gold;
  }

  Color get _borderColor {
    if (dessert.isApproved) return AppColors.success.withOpacity(0.3);
    if (dessert.isRejected) return AppColors.error.withOpacity(0.2);
    return AppColors.darkBorder;
  }

  String get _emoji {
    if (dessert.isApproved) return '✅';
    if (dessert.isRejected) return '❌';
    return '⏳';
  }

  String get _statusLabel {
    if (dessert.isApproved) return 'Approved';
    if (dessert.isRejected) return 'Rejected';
    return 'Pending';
  }
}
