import 'package:flutter/material.dart';
import '../../features/provider_portal/presentation/pages/provider_webview_screen.dart';
import '../constants/app_colors.dart';

/// [ProviderAppLauncherService]
/// Provides seamless in-app WebView navigation for the Provider Login experience.
/// Zero external browser redirects, zero Play Store redirects.
class ProviderAppLauncherService {
  ProviderAppLauncherService._();

  /// Real verified Firebase Hosting URL for the Jamui Services Provider Web App
  static const String providerWebUrl = 'https://jamui-provider.web.app';

  /// Deep link scheme configured in the Provider App AndroidManifest (retained for testing)
  static const String providerDeepLinkUri = 'jamuiservice-provider://login';

  /// Official Android package name (retained for testing)
  static const String providerPackageName = 'com.jamuiservice.provider';

  /// Opens the Provider Experience in a dedicated, branded in-app WebView screen.
  /// Zero external browser redirection, zero Play Store prompts.
  static void openProviderLoginWebView(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProviderWebViewScreen(),
      ),
    );
  }

  /// Alias for backward compatibility — navigates directly to the In-App WebView
  static void launchProviderApp(BuildContext context) {
    openProviderLoginWebView(context);
  }

  /// Displays a professional bottom sheet inviting local service providers
  /// with a direct action to open the in-app Provider portal.
  static void showJoinProviderModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.handyman_rounded, color: AppColors.primary, size: 28),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'क्या आप सर्विस प्रोवाइडर हैं?',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Jamui Services पार्टनर प्रोग्राम',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Jamui Services से जुड़ें और अपने बिजनेस को अधिक ग्राहकों तक पहुँचाएँ।',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.45),
            ),
            const SizedBox(height: 16),
            _buildFeatureBullet(
              icon: Icons.money_off_rounded,
              color: Colors.green,
              title: '0% कमीशन',
              subtitle: 'ग्राहकों से होने वाली सीधी कमाई पूरी तरह आपकी।',
            ),
            const SizedBox(height: 10),
            _buildFeatureBullet(
              icon: Icons.phone_in_talk_rounded,
              color: Colors.blue,
              title: 'डायरेक्ट फोन व व्हाट्सएप पूछताछ',
              subtitle: 'जमुई के स्थानीय ग्राहक आपसे सीधे संपर्क करेंगे।',
            ),
            const SizedBox(height: 10),
            _buildFeatureBullet(
              icon: Icons.verified_user_rounded,
              color: Colors.amber.shade800,
              title: 'वेरिफाइड पार्टनर बैज',
              subtitle: 'KYC और एडमिन वेरिफिकेशन के बाद विश्वसनीय पहचान।',
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  openProviderLoginWebView(context);
                },
                icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                label: const Text(
                  'प्रोवाइडर बनें (Join Now)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  static Widget _buildFeatureBullet({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
