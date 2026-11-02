import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../auth/domain/entities/user_entity.dart';

/// [RoleSelectionPage] यूजर को यह चुनने की सुविधा देता है कि वह ग्राहक (Customer) के रूप में प्रवेश कर रहा है या सर्विस प्रोवाइडर (Service Provider)।
class RoleSelectionPage extends StatelessWidget {
  const RoleSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on, size: 14, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text(
                      'जमुई, बिहार',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'आप JAMUI SERVICE का उपयोग\nकिस रूप में करना चाहते हैं?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'कृपया अपना सही रोल चुनें ताकि हम आपको सबसे बेहतरीन अनुभव दे सकें।',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),

              // Customer Card
              _buildRoleCard(
                context: context,
                title: 'मुझे सर्विस चाहिए (ग्राहक)',
                subtitle: 'प्लंबर, इलेक्ट्रीशियन, रिपेयरिंग या अन्य कारीगर खोजने और सीधे संपर्क करने के लिए।',
                icon: Icons.person_search_rounded,
                accentColor: AppColors.primary,
                badgeText: '100% मुफ़्त',
                onTap: () {
                  Navigator.of(context).pushNamed(AppRoutes.phoneLogin, arguments: UserRole.customer);
                },
              ),

              const SizedBox(height: 16),

              // Provider Card
              _buildRoleCard(
                context: context,
                title: 'मैं सर्विस प्रोवाइडर / मिस्त्री हूँ',
                subtitle: 'जमुई के ग्राहकों से सीधे काम पाने, कॉल और व्हाट्सएप लीड्स प्राप्त करने के लिए।',
                icon: Icons.handyman_rounded,
                accentColor: AppColors.secondary,
                badgeText: '0% कमीशन',
                onTap: () {
                  Navigator.of(context).pushNamed(AppRoutes.phoneLogin, arguments: UserRole.provider);
                },
              ),

              const Spacer(),

              // Admin Portal Link
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamed(AppRoutes.phoneLogin, arguments: UserRole.admin);
                  },
                  icon: const Icon(Icons.admin_panel_settings_outlined, size: 16, color: AppColors.textMuted),
                  label: const Text(
                    'एडमिन पोर्टल (व्यवस्थापक लॉगिन)',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required String badgeText,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accentColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeText,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
