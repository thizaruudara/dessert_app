import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/models/dessert_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/media_image_view.dart';
import '../../../core/widgets/liquid_glass_card.dart';

class DessertListTile extends StatelessWidget {
  final DessertModel dessert;
  final VoidCallback onTap;

  const DessertListTile({super.key, required this.dessert, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasImages = dessert.mediaUrls.isNotEmpty;
    final firstImg = dessert.mediaUrls.isNotEmpty ? dessert.mediaUrls.first : null;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LiquidGlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      borderRadius: BorderRadius.circular(20),
      blur: 16,
      surfaceOpacity: isDark ? 0.60 : 0.86,
      borderColor: _borderColor,
      glowColor: _statusColor,
      onTap: onTap,
      child: Row(
              children: [
                // Thumbnail or Status Emoji Box
                if (hasImages && firstImg != null && firstImg.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: MediaImageView(
                        url: firstImg,
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                else
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(_emoji, style: const TextStyle(fontSize: 24)),
                    ),
                  ),
                const SizedBox(width: 14),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              dessert.caption?.isNotEmpty == true
                                  ? dessert.caption!
                                  : (dessert.mediaUrls.length > 1
                                      ? 'Photo Submission (${dessert.mediaUrls.length} photos)'
                                      : 'Homework Submission'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (dessert.isApproved)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.success.withOpacity(0.25),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                '+${dessert.creditsAwarded} pts',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: _statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: _statusColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _statusLabel,
                                  style: TextStyle(
                                    color: _statusColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            timeago.format(dessert.submittedAt),
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppColors.textMuted,
                  size: 14,
                ),
              ],
            ),
    );
  }

  Color get _statusColor {
    if (dessert.isApproved) return AppColors.success;
    if (dessert.isRejected) return AppColors.error;
    return AppColors.gold;
  }

  Color get _borderColor {
    if (dessert.isApproved) return AppColors.success.withOpacity(0.25);
    if (dessert.isRejected) return AppColors.error.withOpacity(0.2);
    return AppColors.border;
  }

  String get _emoji {
    if (dessert.isApproved) return '🎉';
    if (dessert.isRejected) return '⚠️';
    return '📝';
  }

  String get _statusLabel {
    if (dessert.isApproved) return 'Approved';
    if (dessert.isRejected) return 'Revision Needed';
    return 'Under Review';
  }
}
