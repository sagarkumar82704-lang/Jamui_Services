import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

enum BadgeType { success, warning, danger, info, neutral }

class StatusBadge extends StatelessWidget {
  final String label;
  final BadgeType type;

  const StatusBadge({
    super.key,
    required this.label,
    this.type = BadgeType.info,
  });

  factory StatusBadge.fromStatus(String status) {
    final lower = status.toLowerCase();
    if (lower == 'active' || lower == 'approved' || lower == 'completed' || lower == 'verified' || lower == 'success') {
      return StatusBadge(label: status, type: BadgeType.success);
    } else if (lower == 'pending' || lower == 'pendingreview' || lower.contains('pending') || lower == 'ongoing' || lower == 'warning' || lower == 'investigating') {
      return StatusBadge(label: status, type: BadgeType.warning);
    } else if (lower == 'blocked' || lower == 'rejected' || lower == 'cancelled' || lower == 'failed' || lower == 'inactive') {
      return StatusBadge(label: status, type: BadgeType.danger);
    } else if (lower == 'new' || lower == 'open' || lower == 'info') {
      return StatusBadge(label: status, type: BadgeType.info);
    }
    return StatusBadge(label: status, type: BadgeType.neutral);
  }

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    switch (type) {
      case BadgeType.success:
        bg = AppColors.successBg;
        fg = AppColors.success;
        break;
      case BadgeType.warning:
        bg = AppColors.warningBg;
        fg = AppColors.warning;
        break;
      case BadgeType.danger:
        bg = AppColors.dangerBg;
        fg = AppColors.danger;
        break;
      case BadgeType.info:
        bg = AppColors.infoBg;
        fg = AppColors.info;
        break;
      case BadgeType.neutral:
        bg = AppColors.surfaceSubtle;
        fg = AppColors.textSecondary;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withOpacity(0.3), width: 1),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.badge.copyWith(color: fg, fontSize: 11),
      ),
    );
  }
}
