import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/location_service.dart';

class LocationPermissionDialog extends StatelessWidget {
  final VoidCallback onLocationGranted;
  final bool isPermanentlyDenied;

  const LocationPermissionDialog({
    super.key,
    required this.onLocationGranted,
    this.isPermanentlyDenied = false,
  });

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onLocationGranted,
    bool isPermanentlyDenied = false,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => LocationPermissionDialog(
        onLocationGranted: onLocationGranted,
        isPermanentlyDenied: isPermanentlyDenied,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.all(24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.location_on_rounded, size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 20),
          const Text(
            'लोकेशन अनुमति आवश्यक है',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            isPermanentlyDenied
                ? 'आपके नजदीकी वेरिफाइड कारीगर खोजने के लिए लोकेशन अनुमति अनिवार्य है। कृपया सेटिंग्स से अनुमति चालू करें।'
                : 'आपके आसपास उपलब्ध इलेक्ट्रीशियन, प्लंबर व अन्य कारीगर दिखाने के लिए आपकी लोकेशन की आवश्यकता है।',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () async {
                if (isPermanentlyDenied) {
                  await LocationService.openAppSettings();
                  if (context.mounted) Navigator.pop(context);
                } else {
                  try {
                    await LocationService.fetchCurrentLocation();
                    if (context.mounted) {
                      Navigator.pop(context);
                      onLocationGranted();
                    }
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                isPermanentlyDenied ? 'सेटिंग्स खोलें (Open Settings)' : 'लोकेशन अनुमति दें (Allow Location)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('बाद में (Cancel)', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}
