import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'customer_app_settings_service.dart';

/// Production-ready In-App Update and Play Store Redirection Manager
class AppUpdateManager {
  static const String customerPackageId = 'com.jamuiservice.customer';
  static const String defaultMarketUrl = 'market://details?id=$customerPackageId';
  static const String defaultWebStoreUrl =
      'https://play.google.com/store/apps/details?id=$customerPackageId';

  /// Performs immediate update flow:
  /// Launches official Google Play Store app listing directly via native market:// scheme,
  /// with fallback to https://play.google.com/store/apps/details?id=com.jamuiservice.customer.
  static Future<bool> startImmediateUpdate({String? customStoreUrl}) async {
    return openPlayStore(customStoreUrl: customStoreUrl);
  }

  /// Launches Google Play Store app listing via market:// intent or https:// fallback
  static Future<bool> openPlayStore({String? customStoreUrl}) async {
    final targetUrl = customStoreUrl?.trim().isNotEmpty == true
        ? customStoreUrl!.trim()
        : defaultWebStoreUrl;

    // Try native market:// scheme on Android first for instant Play Store app opening
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final marketUri = Uri.parse(defaultMarketUrl);
      try {
        if (await canLaunchUrl(marketUri)) {
          final launched = await launchUrl(
            marketUri,
            mode: LaunchMode.externalApplication,
          );
          if (launched) return true;
        }
      } catch (_) {}
    }

    // Fallback to https://play.google.com
    final webUri = Uri.tryParse(targetUrl);
    if (webUri != null) {
      try {
        return await launchUrl(
          webUri,
          mode: LaunchMode.externalApplication,
        );
      } catch (e) {
        debugPrint('⚠️ [AppUpdateManager] Failed to launch store URL: $e');
      }
    }
    return false;
  }

  /// Verifies if the installed app has actually been updated
  static Future<bool> isAppUpdatedToLatest({String? overrideVersion}) async {
    final decision = await CustomerAppSettingsService().evaluateUpdateStatus(
      overrideCurrentVersion: overrideVersion,
    );
    return !decision.isMandatory;
  }

  /// Reads current version name + build number
  static Future<String> getInstalledVersionString() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return '${info.version}+${info.buildNumber}';
    } catch (_) {
      return '1.0.0';
    }
  }
}
