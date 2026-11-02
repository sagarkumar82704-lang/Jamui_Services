import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/stat_card.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../bloc/dashboard_bloc.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, state) {
        if (state is DashboardLoading) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: GridView.count(
              crossAxisCount: 4,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.8,
              children: List.generate(8, (_) => const LoadingSkeleton(height: 100)),
            ),
          );
        }

        if (state is DashboardError) {
          return EmptyStateWidget(
            title: "Error Loading Dashboard",
            message: state.message,
            icon: Icons.error_outline,
            onRefresh: () => context.read<DashboardBloc>().add(FetchDashboardStatsEvent()),
          );
        }

        if (state is DashboardLoaded) {
          final s = state.stats;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Dashboard Overview', style: AppTextStyles.h1),
                        const SizedBox(height: 4),
                        Text('Real-time database analytics for JAMUI SERVICE', style: AppTextStyles.body),
                      ],
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.read<DashboardBloc>().add(FetchDashboardStatsEvent()),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Refresh Stats'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Top KPI Grid
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final crossAxisCount = width < 600
                        ? 1
                        : width < 1000
                            ? 2
                            : 4;

                    return GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: width < 600 ? 2.5 : 1.8,
                      children: [
                        StatCard(
                          title: 'TOTAL CUSTOMERS',
                          value: '${s.totalCustomers}',
                          icon: Icons.people_outline,
                          color: AppColors.primary,
                        ),
                        StatCard(
                          title: 'TOTAL PROVIDERS',
                          value: '${s.totalProviders}',
                          icon: Icons.storefront_outlined,
                          color: AppColors.info,
                          subtitle: '${s.activeProviders} Active | ${s.pendingProviders} Pending',
                        ),
                        StatCard(
                          title: 'ACTIVE SUBSCRIPTIONS',
                          value: '${s.activeSubscriptions}',
                          icon: Icons.card_membership_outlined,
                          color: AppColors.success,
                        ),
                        StatCard(
                          title: 'TOTAL REVENUE',
                          value: '₹${s.totalRevenue.toStringAsFixed(0)}',
                          icon: Icons.payments_outlined,
                          color: AppColors.accent,
                        ),
                        StatCard(
                          title: 'TOTAL LEADS',
                          value: '${s.totalLeads}',
                          icon: Icons.contact_mail_outlined,
                          color: AppColors.warning,
                        ),
                        StatCard(
                          title: 'TOTAL BOOKINGS',
                          value: '${s.totalBookings}',
                          icon: Icons.calendar_today_outlined,
                          color: AppColors.secondary,
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 32),

                // Real Analytics Section (No Dummy Data)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('System Activity & Analytics', style: AppTextStyles.h3),
                      const SizedBox(height: 8),
                      Text('Charts will reflect real platform transactions when activity increases.', style: AppTextStyles.caption),
                      const SizedBox(height: 24),
                      if (s.totalCustomers == 0 && s.totalProviders == 0 && s.totalLeads == 0)
                        const EmptyStateWidget(
                          title: "No Analytics Data Available",
                          message: "The database currently has 0 registered users/leads. New metrics will render automatically.",
                          icon: Icons.bar_chart_outlined,
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline, color: AppColors.success),
                              const SizedBox(width: 12),
                              Text(
                                'Database Connected: ${s.totalCustomers} Customers, ${s.totalProviders} Providers registered.',
                                style: AppTextStyles.bodyBold,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}
