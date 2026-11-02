import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class AdminTopbar extends StatelessWidget {
  final String title;
  final String adminEmail;
  final VoidCallback onToggleSidebar;
  final VoidCallback onLogout;

  const AdminTopbar({
    super.key,
    required this.title,
    required this.adminEmail,
    required this.onToggleSidebar,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.menu, color: AppColors.textSecondary),
                onPressed: onToggleSidebar,
                tooltip: 'Toggle Sidebar',
              ),
              const SizedBox(width: 12),
              Text(title, style: AppTextStyles.h2),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_outlined, color: AppColors.textSecondary),
                onPressed: () {},
                tooltip: 'Notifications',
              ),
              const SizedBox(width: 12),
              const VerticalDivider(indent: 16, endIndent: 16),
              const SizedBox(width: 12),
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primarySubtle,
                child: Text(
                  adminEmail.isNotEmpty ? adminEmail[0].toUpperCase() : 'A',
                  style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Master Admin', style: AppTextStyles.bodyBold.copyWith(fontSize: 13)),
                  Text(adminEmail, style: AppTextStyles.caption),
                ],
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
                onSelected: (value) {
                  if (value == 'logout') onLogout();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(Icons.person_outline, size: 18),
                        SizedBox(width: 8),
                        Text('Profile'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, size: 18, color: AppColors.danger),
                        SizedBox(width: 8),
                        Text('Logout', style: TextStyle(color: AppColors.danger)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
