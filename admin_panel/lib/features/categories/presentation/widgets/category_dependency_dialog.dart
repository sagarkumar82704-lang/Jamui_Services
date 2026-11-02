import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/category_dependency_count.dart';

class CategoryDependencyDialog extends StatelessWidget {
  final CategoryEntity category;
  final CategoryDependencyCount dependencyCount;
  final VoidCallback onDeactivate;
  final VoidCallback onArchive;
  final VoidCallback onDeletePermanently;

  const CategoryDependencyDialog({
    super.key,
    required this.category,
    required this.dependencyCount,
    required this.onDeactivate,
    required this.onArchive,
    required this.onDeletePermanently,
  });

  @override
  Widget build(BuildContext context) {
    final hasDeps = dependencyCount.hasDependencies;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasDeps ? Icons.warning_amber_rounded : Icons.delete_forever,
                  color: hasDeps ? AppColors.warning : AppColors.danger,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  hasDeps ? 'Dependencies Detected' : 'Delete Category',
                  style: AppTextStyles.h2,
                ),
              ],
            ),
            const Divider(height: 24),
            if (hasDeps) ...[
              Text(
                'Category "${category.name}" cannot be permanently deleted because it is currently linked with existing system records:',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _buildMetricRow('Providers', dependencyCount.providerCount),
                    _buildMetricRow('Services', dependencyCount.serviceCount),
                    _buildMetricRow('Leads', dependencyCount.leadCount),
                    _buildMetricRow('Bookings', dependencyCount.bookingCount),
                    _buildMetricRow('Reviews', dependencyCount.reviewCount),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Please deactivate or archive this category instead. Existing providers, bookings, and leads will remain completely safe.',
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              ),
            ] else ...[
              Text(
                'Are you sure you want to permanently delete category "${category.name}"?',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 8),
              Text(
                'This category has 0 active dependencies and can be purged safely.',
                style: AppTextStyles.caption,
              ),
            ],
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                if (hasDeps) ...[
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onDeactivate();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warning,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Deactivate Category'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onArchive();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Archive Category'),
                  ),
                ] else ...[
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onDeletePermanently();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Delete Permanently'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.body),
          Text(
            count.toString(),
            style: AppTextStyles.bodyBold.copyWith(
              color: count > 0 ? AppColors.danger : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
