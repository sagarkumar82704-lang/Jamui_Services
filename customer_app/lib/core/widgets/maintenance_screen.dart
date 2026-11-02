import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';
import '../services/customer_app_settings_service.dart';

class MaintenanceScreen extends StatelessWidget {
  final String message;

  const MaintenanceScreen({
    super.key,
    required this.message,
  });

  Future<void> _callSupport() async {
    final phone = CustomerAppSettingsService().supportPhoneNumber;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.construction_rounded,
                    size: 64,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Under Scheduled Maintenance',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message.isNotEmpty
                      ? message
                      : 'Jamui Services is temporarily unavailable while we perform system upgrades. We will be back online shortly!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                OutlinedButton.icon(
                  onPressed: _callSupport,
                  icon: const Icon(Icons.support_agent_rounded, color: AppColors.primary),
                  label: const Text(
                    'Contact Support',
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
