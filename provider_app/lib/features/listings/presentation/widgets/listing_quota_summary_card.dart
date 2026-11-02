import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class ListingQuotaSummaryCard extends StatelessWidget {
  final Map<String, dynamic> planLimits;
  final Map<String, dynamic> storageUsage;
  final int activeListingsCount;
  final VoidCallback onUpgradePressed;

  const ListingQuotaSummaryCard({
    super.key,
    required this.planLimits,
    required this.storageUsage,
    required this.activeListingsCount,
    required this.onUpgradePressed,
  });

  @override
  Widget build(BuildContext context) {
    final maxListings = (planLimits['maxActiveListings'] as num?)?.toInt() ?? 1;
    final maxImages = (planLimits['maxImagesPerProvider'] as num?)?.toInt() ?? 3;
    final maxStorageBytes = (planLimits['maxTotalStorageBytes'] as num?)?.toInt() ?? (6 * 1024 * 1024);

    final totalImages = (storageUsage['totalImagesCount'] as num?)?.toInt() ?? 0;
    final totalBytesUsed = (storageUsage['totalBytesUsed'] as num?)?.toInt() ?? 0;

    final usedMb = totalBytesUsed / (1024 * 1024);
    final maxMb = maxStorageBytes / (1024 * 1024);

    final listingsPct = (activeListingsCount / (maxListings > 0 ? maxListings : 1)).clamp(0.0, 1.0);
    final imagesPct = (totalImages / (maxImages > 0 ? maxImages : 1)).clamp(0.0, 1.0);
    final storagePct = (totalBytesUsed / (maxStorageBytes > 0 ? maxStorageBytes : 1)).clamp(0.0, 1.0);

    final isStorageNearLimit = storagePct >= 0.85;
    final isListingsLimitReached = activeListingsCount >= maxListings;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isStorageNearLimit || isListingsLimitReached)
              ? Colors.amber.shade300
              : AppColors.border,
          width: (isStorageNearLimit || isListingsLimitReached) ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.pie_chart_outline_rounded, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'प्लान कोटा व स्टोरेज उपयोग',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                  ),
                ],
              ),
              InkWell(
                onTap: onUpgradePressed,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'अपग्रेड करें',
                        style: TextStyle(color: Colors.amber.shade900, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.arrow_forward_ios, size: 10, color: Colors.amber.shade900),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3 Metric rows
          _buildMetricRow(
            label: 'एक्टिव लिस्टिंग्स',
            valueText: '$activeListingsCount / $maxListings',
            progress: listingsPct,
            progressColor: activeListingsCount >= maxListings ? Colors.red : AppColors.primary,
          ),
          const SizedBox(height: 8),
          _buildMetricRow(
            label: 'अपलोड की गई फ़ोटोज़',
            valueText: '$totalImages / $maxImages',
            progress: imagesPct,
            progressColor: totalImages >= maxImages ? Colors.red : AppColors.accent,
          ),
          const SizedBox(height: 8),
          _buildMetricRow(
            label: 'क्लाउड स्टोरेज उपयोग',
            valueText: '${usedMb.toStringAsFixed(1)} MB / ${maxMb.toStringAsFixed(1)} MB',
            progress: storagePct,
            progressColor: isStorageNearLimit ? Colors.red : Colors.green.shade700,
          ),

          if (isListingsLimitReached || isStorageNearLimit) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 16, color: Colors.amber.shade900),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isListingsLimitReached
                          ? 'एक्टिव लिस्टिंग सीमा पूरी हो चुकी है। नई लिस्टिंग हेतु प्लान अपग्रेड करें या पुरानी डिलीट करें।'
                          : 'स्टोरेज कोटा 85% से अधिक भर चुका है। सुरक्षित उपयोग हेतु अपग्रेड करें।',
                      style: TextStyle(fontSize: 10.5, color: Colors.amber.shade900, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricRow({
    required String label,
    required String valueText,
    required double progress,
    required Color progressColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            Text(valueText, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            minHeight: 5,
          ),
        ),
      ],
    );
  }
}
