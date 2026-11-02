import 'package:flutter/foundation.dart';

/// Immutable model representing Cloud Firestore Customer App Settings & Version Control
/// Document Path: `app_settings/customer_app`
@immutable
class CustomerAppSettings {
  final bool forceUpdateEnabled;
  final String minimumSupportedVersion;
  final String latestVersion;
  final String updateTitle;
  final String updateMessage;
  final String updateButtonText;
  final String playStoreUrl;
  final bool maintenanceMode;
  final String maintenanceMessage;
  final bool updateBannerEnabled;
  final bool isGeminiAiSearchEnabled;
  final String supportPhoneNumber;
  final String supportWhatsappNumber;
  final String imageBaseUrl;

  const CustomerAppSettings({
    required this.forceUpdateEnabled,
    required this.minimumSupportedVersion,
    required this.latestVersion,
    required this.updateTitle,
    required this.updateMessage,
    required this.updateButtonText,
    required this.playStoreUrl,
    required this.maintenanceMode,
    required this.maintenanceMessage,
    this.updateBannerEnabled = true,
    this.isGeminiAiSearchEnabled = true,
    this.supportPhoneNumber = '+91 94312 88412',
    this.supportWhatsappNumber = '+91 94312 88412',
    this.imageBaseUrl = '',
  });

  /// Compile-time safe fallback defaults used offline or if Firestore document is missing
  factory CustomerAppSettings.fallback() {
    return const CustomerAppSettings(
      forceUpdateEnabled: false,
      minimumSupportedVersion: '1.0.0',
      latestVersion: '1.2.5',
      updateTitle: 'New Update Available',
      updateMessage:
          'जमुई सर्विस ऐप का नया और सुरक्षित संस्करण उपलब्ध है। बेहतर सेवाओं एवं नए फीचर्स के लिए कृपया ऐप अभी अपडेट करें।',
      updateButtonText: 'Update Now',
      playStoreUrl:
          'https://play.google.com/store/apps/details?id=com.jamuiservice.customer',
      maintenanceMode: false,
      maintenanceMessage:
          'जमुई सर्विस में तकनीकी सुधार कार्य प्रगति पर है। कृपया थोड़ी देर बाद पुनः प्रयास करें।',
      updateBannerEnabled: true,
      isGeminiAiSearchEnabled: true,
      supportPhoneNumber: '+91 94312 88412',
      supportWhatsappNumber: '+91 94312 88412',
    );
  }

  /// Parses Firestore document data supporting both camelCase and snake_case keys
  factory CustomerAppSettings.fromMap(Map<String, dynamic> data) {
    final fallback = CustomerAppSettings.fallback();

    bool parseBool(dynamic value, bool defaultValue) {
      if (value == null) return defaultValue;
      if (value is bool) return value;
      final str = value.toString().trim().toLowerCase();
      if (str == 'true' || str == '1' || str == 'yes') return true;
      if (str == 'false' || str == '0' || str == 'no') return false;
      return defaultValue;
    }

    String parseString(dynamic value, String defaultValue) {
      if (value == null) return defaultValue;
      final str = value.toString().trim();
      return str.isNotEmpty ? str : defaultValue;
    }

    final forceUpdate = parseBool(
      data['forceUpdateEnabled'] ??
          data['force_update_enabled'] ??
          data['customer_force_update_enabled'] ??
          data['is_force_update'] ??
          data['force_update'],
      fallback.forceUpdateEnabled,
    );

    final minVersion = parseString(
      data['minimumSupportedVersion'] ??
          data['minimum_supported_version'] ??
          data['min_required_customer_app_version'] ??
          data['min_required_version'],
      fallback.minimumSupportedVersion,
    ).replaceAll('"', '').replaceAll("'", '').trim();

    final latest = parseString(
      data['latestVersion'] ??
          data['latest_version'] ??
          data['latest_customer_app_version'],
      fallback.latestVersion,
    ).replaceAll('"', '').replaceAll("'", '').trim();

    final title = parseString(
      data['updateTitle'] ?? data['update_title'],
      fallback.updateTitle,
    );

    final message = parseString(
      data['updateMessage'] ?? data['update_message'],
      fallback.updateMessage,
    );

    final buttonText = parseString(
      data['updateButtonText'] ?? data['update_button_text'],
      fallback.updateButtonText,
    );

    final rawStoreUrl = parseString(
      data['playStoreUrl'] ??
          data['play_store_url'] ??
          data['update_app_url'] ??
          data['updateUrl'],
      fallback.playStoreUrl,
    );

    final storeUrl = _validatePlayStoreUrl(rawStoreUrl, fallback.playStoreUrl);

    final maintenance = parseBool(
      data['maintenanceMode'] ??
          data['maintenance_mode'] ??
          data['customer_maintenance_mode'] ??
          data['isMaintenanceMode'] ??
          data['is_maintenance'],
      fallback.maintenanceMode,
    );

    final maintMessage = parseString(
      data['maintenanceMessage'] ??
          data['maintenance_message'] ??
          data['customer_maintenance_message'],
      fallback.maintenanceMessage,
    );

    final bannerEnabled = parseBool(
      data['updateBannerEnabled'] ?? data['update_banner_enabled'],
      fallback.updateBannerEnabled,
    );

    final aiSearchEnabled = parseBool(
      data['isGeminiAiSearchEnabled'] ??
          data['enable_gemini_ai_search'] ??
          data['gemini_ai_search_enabled'],
      fallback.isGeminiAiSearchEnabled,
    );

    final phone = parseString(
      data['supportPhoneNumber'] ??
          data['support_phone_number'] ??
          data['supportPhone'],
      fallback.supportPhoneNumber,
    );

    final whatsapp = parseString(
      data['supportWhatsappNumber'] ??
          data['support_whatsapp_number'] ??
          data['supportWhatsapp'],
      fallback.supportWhatsappNumber,
    );

    final imgBaseUrl = parseString(
      data['imageBaseUrl'] ?? data['image_base_url'],
      fallback.imageBaseUrl,
    );

    return CustomerAppSettings(
      forceUpdateEnabled: forceUpdate,
      minimumSupportedVersion: minVersion,
      latestVersion: latest,
      updateTitle: title,
      updateMessage: message,
      updateButtonText: buttonText,
      playStoreUrl: storeUrl,
      maintenanceMode: maintenance,
      maintenanceMessage: maintMessage,
      updateBannerEnabled: bannerEnabled,
      isGeminiAiSearchEnabled: aiSearchEnabled,
      supportPhoneNumber: phone,
      supportWhatsappNumber: whatsapp,
      imageBaseUrl: imgBaseUrl,
    );
  }

  static String _validatePlayStoreUrl(String url, String fallbackUrl) {
    final uri = Uri.tryParse(url);
    if (uri != null && (uri.scheme == 'https' || uri.scheme == 'market')) {
      if (uri.host.contains('google.com') ||
          uri.scheme == 'market' ||
          uri.host.isEmpty) {
        return url;
      }
    }
    return fallbackUrl;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomerAppSettings &&
          runtimeType == other.runtimeType &&
          forceUpdateEnabled == other.forceUpdateEnabled &&
          minimumSupportedVersion == other.minimumSupportedVersion &&
          latestVersion == other.latestVersion &&
          updateTitle == other.updateTitle &&
          updateMessage == other.updateMessage &&
          updateButtonText == other.updateButtonText &&
          playStoreUrl == other.playStoreUrl &&
          maintenanceMode == other.maintenanceMode &&
          maintenanceMessage == other.maintenanceMessage &&
          updateBannerEnabled == other.updateBannerEnabled &&
          isGeminiAiSearchEnabled == other.isGeminiAiSearchEnabled &&
          supportPhoneNumber == other.supportPhoneNumber &&
          supportWhatsappNumber == other.supportWhatsappNumber &&
          imageBaseUrl == other.imageBaseUrl;

  @override
  int get hashCode => Object.hash(
        forceUpdateEnabled,
        minimumSupportedVersion,
        latestVersion,
        updateTitle,
        updateMessage,
        updateButtonText,
        playStoreUrl,
        maintenanceMode,
        maintenanceMessage,
        updateBannerEnabled,
        isGeminiAiSearchEnabled,
        supportPhoneNumber,
        supportWhatsappNumber,
        imageBaseUrl,
      );

  @override
  String toString() =>
      'CustomerAppSettings(forceUpdate: $forceUpdateEnabled, minVersion: $minimumSupportedVersion, latestVersion: $latestVersion, maintenance: $maintenanceMode, imageBaseUrl: $imageBaseUrl)';
}
