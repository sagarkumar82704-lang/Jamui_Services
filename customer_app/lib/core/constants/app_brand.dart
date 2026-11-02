import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Centralized Branding & Configuration for Jamui Services
/// 
/// Changing the branding tokens here automatically updates them across
/// all screens, headers, dialogs, drawers, splash, and notifications.
class AppBrand {
  AppBrand._();

  // --- Core Identity ---
  static const String appName = 'JAMUI SERVICES';
  static const String shortName = 'JAMUI SERVICE';
  static const String taglineHindi = 'जमुई का अपना विश्वसनीय लोकल सेवा मंच';
  static const String taglineEnglish = 'Jamui\'s Trusted Hyperlocal Service Platform';

  // --- Assets ---
  static const String logoAsset = 'assets/images/app_logo.png';

  // --- Location & Regional Info ---
  static const String cityName = 'Jamui';
  static const String cityNameHindi = 'जमुई';
  static const String stateName = 'Bihar';
  static const String stateNameHindi = 'बिहार';
  static const String defaultPincode = '811307';
  static const String locationTitle = 'जमुई (बिहार) - 811307';

  // --- Contact & Helpline ---
  static const String helplineTitle = 'JAMUI SERVICE हेल्पलाइन';
  static const String defaultSupportPhone = '+919999999999';
  static const String defaultSupportWhatsApp = '+919999999999';
  static const String supportEmail = 'support@jamuiservice.in';

  // --- Verification & Trust Badges (Customizable Verification Text) ---
  static const String verifiedBadgeText = '100% सत्यापित';
  static const String verifiedBadgeSubtitle = 'पहचान व अनुभव जांच पूर्ण';
  static const String verifiedProviderLabel = 'वेरिफाइड कारीगर (Verified)';
  static const String trustGuaranteeText = '100% सत्यापित स्थानीय कारीगर';

  // --- Theme Accessors ---
  static const Color primaryColor = AppColors.primary;
  static const Color secondaryColor = AppColors.secondary;
  static const Color accentColor = AppColors.accent;
}
