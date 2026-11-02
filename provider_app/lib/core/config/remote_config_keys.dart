/// Remote Config Parameter Keys & Safe Fallback Defaults for Jamui Services (Provider App)
/// 
/// STRICT SECURITY RULES:
/// - NEVER put private API secrets, payment secrets, or admin tokens in Remote Config.
/// - Business-critical rules (Subscription, category counts, KYC approval) remain enforced on Backend/Firestore.
abstract class RemoteConfigKeys {
  // --- Force Update & Version Enforcement ---
  static const String minRequiredProviderAppVersion = 'min_required_provider_app_version';
  static const String latestProviderAppVersion = 'latest_provider_app_version';
  static const String updateAppUrl = 'update_app_url';

  // --- Shared Update Parameter Keys (Cross-app safety) ---
  static const String forceUpdateEnabled = 'force_update_enabled';
  static const String latestVersion = 'latest_version';
  static const String minimumSupportedVersion = 'minimum_supported_version';
  static const String updateTitle = 'update_title';
  static const String updateMessage = 'update_message';
  static const String updateButtonText = 'update_button_text';
  static const String playStoreUrl = 'play_store_url';
  static const String updateBannerEnabled = 'update_banner_enabled';

  // --- Maintenance Mode ---
  static const String providerMaintenanceMode = 'provider_maintenance_mode';
  static const String providerMaintenanceMessage = 'provider_maintenance_message';

  // --- Feature Gates & Kill Switches ---
  static const String enableProviderRealtimeTracking = 'enable_provider_realtime_tracking';

  // --- Support Information ---
  static const String supportPhoneNumber = 'support_phone_number';
  static const String supportWhatsappNumber = 'support_whatsapp_number';

  // --- CDN & Media Storage ---
  static const String imageBaseUrl = 'image_base_url';

  /// Safe compile-time default values (Used offline or prior to first fetch)
  static final Map<String, dynamic> defaults = {
    minRequiredProviderAppVersion: '1.0.0',
    latestProviderAppVersion: '1.0.0',
    updateAppUrl: 'https://play.google.com/store/apps/details?id=com.jamuiservice.provider',
    forceUpdateEnabled: false,
    latestVersion: '1.0.0',
    minimumSupportedVersion: '1.0.0',
    updateTitle: 'New Update Available',
    updateMessage: 'Please update provider app.',
    updateButtonText: 'Update Now',
    playStoreUrl: 'https://play.google.com/store/apps/details?id=com.jamuiservice.provider',
    updateBannerEnabled: true,
    providerMaintenanceMode: false,
    providerMaintenanceMessage: 'Jamui Services Provider Portal is currently undergoing brief maintenance. New bookings will resume soon.',
    enableProviderRealtimeTracking: true,
    supportPhoneNumber: '+919999999999',
    supportWhatsappNumber: '+919999999999',
    imageBaseUrl: '',
  };
}
