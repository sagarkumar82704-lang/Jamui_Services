import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'app_logo.dart';

class NavigationMenuItem {
  final String id;
  final String title;
  final IconData icon;

  const NavigationMenuItem({
    required this.id,
    required this.title,
    required this.icon,
  });
}

class AdminSidebar extends StatelessWidget {
  final String currentRoute;
  final ValueChanged<String> onSelectRoute;
  final bool isCollapsed;

  static const List<NavigationMenuItem> menuItems = [
    NavigationMenuItem(id: 'dashboard', title: 'Dashboard', icon: Icons.dashboard_outlined),
    NavigationMenuItem(id: 'professional_dashboard', title: 'Professional (Pro)', icon: Icons.storefront_rounded),
    NavigationMenuItem(id: 'professional_plans', title: 'Professional Plans', icon: Icons.workspace_premium_rounded),
    NavigationMenuItem(id: 'customers', title: 'Customers', icon: Icons.people_outline),
    NavigationMenuItem(id: 'providers', title: 'Providers', icon: Icons.storefront_outlined),
    NavigationMenuItem(id: 'categories', title: 'Categories', icon: Icons.category_outlined),
    NavigationMenuItem(id: 'banners', title: 'Sponsor Banners', icon: Icons.view_carousel_outlined),
    NavigationMenuItem(id: 'services', title: 'Services', icon: Icons.build_outlined),
    NavigationMenuItem(id: 'leads', title: 'Leads', icon: Icons.contact_mail_outlined),
    NavigationMenuItem(id: 'bookings', title: 'Bookings', icon: Icons.calendar_today_outlined),
    NavigationMenuItem(id: 'subscriptions', title: 'Subscriptions', icon: Icons.card_membership_outlined),
    NavigationMenuItem(id: 'payments', title: 'Payments', icon: Icons.payments_outlined),
    NavigationMenuItem(id: 'reviews', title: 'Reviews', icon: Icons.star_outline),
    NavigationMenuItem(id: 'complaints', title: 'Complaints', icon: Icons.report_problem_outlined),
    NavigationMenuItem(id: 'notifications', title: 'Notifications', icon: Icons.notifications_outlined),
    NavigationMenuItem(id: 'analytics', title: 'Analytics', icon: Icons.insights_outlined),
    NavigationMenuItem(id: 'ai_insights', title: 'AI Insights', icon: Icons.psychology_outlined),
    NavigationMenuItem(id: 'admins', title: 'Admins', icon: Icons.admin_panel_settings_outlined),
    NavigationMenuItem(id: 'audit_logs', title: 'Audit Logs', icon: Icons.history_outlined),
    NavigationMenuItem(id: 'settings', title: 'Settings', icon: Icons.settings_outlined),
  ];

  const AdminSidebar({
    super.key,
    required this.currentRoute,
    required this.onSelectRoute,
    this.isCollapsed = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isCollapsed ? 70 : 250,
      color: AppColors.sidebarBackground,
      child: Column(
        children: [
          // Logo & Title
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.sidebarBorder)),
            ),
            child: Row(
              children: [
                const AppLogo(
                  size: 36,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                  showShadow: true,
                ),
                if (!isCollapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'JAMUI SERVICE',
                          style: AppTextStyles.h3.copyWith(
                            color: Colors.white,
                            fontSize: 15,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'Admin Dashboard',
                          style: AppTextStyles.caption.copyWith(color: AppColors.sidebarText),
                        ),
                      ],
                    ),
                  ),
                ]
              ],
            ),
          ),

          // Menu List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: menuItems.length,
              itemBuilder: (context, index) {
                final item = menuItems[index];
                final isSelected = currentRoute == item.id;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  child: InkWell(
                    onTap: () => onSelectRoute(item.id),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item.icon,
                            size: 20,
                            color: isSelected ? Colors.white : AppColors.sidebarText,
                          ),
                          if (!isCollapsed) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item.title,
                                style: AppTextStyles.body.copyWith(
                                  color: isSelected ? Colors.white : AppColors.sidebarText,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
