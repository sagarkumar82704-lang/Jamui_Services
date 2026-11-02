import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Centralized Branding & Identity for Jamui Services Provider App
/// 
/// Changing the branding tokens here updates the Provider App identity
/// across splash, registration, dashboard, drawer, and support pages.
class AppBrand {
  AppBrand._();

  // --- Core Identity ---
  static const String appName = 'JAMUI SERVICES';
  static const String shortName = 'JAMUI SERVICE';
  static const String roleTitle = 'कारीगर व पार्टनर पार्टनर ऐप';
  static const String taglineHindi = 'जमुई का अपना सेवा पार्टनर मंच';
  static const String taglineEnglish = 'Jamui\'s Trusted Provider Partner Platform';

  // --- Assets ---
  static const String logoAsset = 'assets/images/app_logo.png';

  // --- Regional Info ---
  static const String cityName = 'Jamui';
  static const String cityNameHindi = 'जमुई';
  static const String stateName = 'Bihar';
  static const String defaultPincode = '811307';
  static const String locationTitle = 'जमुई (बिहार) - 811307';

  // --- Contact & Helpline ---
  static const String helplineTitle = 'JAMUI SERVICE पार्टनर हेल्पलाइन';
  static const String defaultSupportPhone = '+919999999999';
  static const String defaultSupportWhatsApp = '+919999999999';
  static const String supportEmail = 'partner@jamuiservice.in';

  // --- Verification & KYC Texts (No Aadhaar Required) ---
  static const String verifiedBadgeText = '100% सत्यापित पार्टनर';
  static const String kycTitle = 'प्रोफ़ाइल व पहचान सत्यापन';
  static const String kycSubtitle = 'व्यावसायिक अनुभव व पहचान सत्यापन';
  static const String kycUnderReviewTitle = 'प्रोफ़ाइल समीक्षाधीन है';
  static const String kycUnderReviewMessage = 'आपकी प्रोफाइल एवं विवरण एडमिन टीम द्वारा समीक्षाधीन है। सत्यापन पूर्ण होते ही आपको ग्रीन वेरिफाइड बैज मिल जाएगा।';
  static const String kycStep1Title = '1. प्रोफाइल व कार्य अनुभव दर्ज किया';
  static const String kycStep2Title = '2. एडमिन टीम द्वारा समीक्षा (Reviewing)';
  static const String kycStep3Title = '3. वेरिफाइड पार्टनर बैज एक्टिवेट';
  static const String kycApprovedMessage = 'व्यावसायिक व प्रोफाइल सत्यापन सफलतापूर्वक पूरा हो गया है।';
  static const String kycRejectedMessage = 'कृपया सही विवरण दर्ज करके पुनः सबमिट करें।';

  // --- Theme Accessors ---
  static const Color primaryColor = AppColors.primary;
  static const Color primaryLight = AppColors.primaryLight;
  static const Color accentColor = AppColors.accent;
}
