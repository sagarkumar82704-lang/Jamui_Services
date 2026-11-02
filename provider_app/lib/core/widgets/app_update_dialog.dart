import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';

/// Non-dismissible Force Update Dialog for Provider App
class AppUpdateDialog extends StatelessWidget {
  final String updateUrl;
  final String latestVersion;

  const AppUpdateDialog({
    super.key,
    required this.updateUrl,
    required this.latestVersion,
  });

  Future<void> _openStore() async {
    final uri = Uri.tryParse(updateUrl);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.system_update_rounded, color: AppColors.primary, size: 28),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Update Required',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A critical update ($latestVersion) for Jamui Service Provider is required to receive new booking requests and manage payments securely.',
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 12),
            const Text(
              'Please update your app from the Play Store to continue.',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _openStore,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.download_rounded, size: 18),
                SizedBox(width: 8),
                Text('Update Now', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
