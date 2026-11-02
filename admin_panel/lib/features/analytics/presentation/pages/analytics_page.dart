import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/empty_state_widget.dart';

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Advanced Growth & Demand Analytics', style: AppTextStyles.h2),
            const SizedBox(height: 8),
            Text('Real-time trend analysis computed from production activity.', style: AppTextStyles.caption),
            const SizedBox(height: 32),
            const EmptyStateWidget(
              title: "No Analytics Data Available",
              message: "Platform analytics require accumulated transaction logs. Metrics will calculate automatically as service bookings occur.",
              icon: Icons.insights_outlined,
            ),
          ],
        ),
      ),
    );
  }
}
