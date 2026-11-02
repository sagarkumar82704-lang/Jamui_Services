/// [AppStrings] पूरे प्रोजेक्ट के सभी स्ट्रिंग्स और लेबल्स को एक जगह रखता है।
/// इससे कभी भी स्पेलिंग मिस्टेक नहीं होती और भविष्य में बहुभाषी (Multi-language) सपोर्ट आसान हो जाता है।
abstract class AppStrings {
  // App Branding
  static const String appName = 'JAMUI SERVICE';
  static const String appTagline = 'जमुई की लोकल सेवा, सीधे आपके द्वार';
  static const String appSubtagline = 'Plumber, Electrician, Mechanic और 50+ सेवाएँ बिना किसी कमीशन के!';

  // Roles
  static const String customer = 'ग्राहक (Customer)';
  static const String provider = 'सर्विस प्रोवाइडर (Service Provider)';
  static const String admin = 'एडमिनिस्ट्रेटर (Admin)';

  // Common Actions
  static const String continueText = 'आगे बढ़ें';
  static const String verifyOtp = 'OTP सत्यापित करें';
  static const String resendOtp = 'पुनः OTP भेजें';
  static const String submit = 'जमा करें';
  static const String cancel = 'रद्द करें';
  static const String searchPlaceholder = 'सर्विस या मैकेनिक खोजें (जैसे प्लंबर, एसी रिपेयर)...';
  static const String retry = 'दोबारा कोशिश करें';
  static const String viewAll = 'सभी देखें';

  // Navigation Titles
  static const String navHome = 'होम';
  static const String navBookings = 'मेरी बुकिंग';
  static const String navLeads = 'लीड्स';
  static const String navAnalytics = 'एनालिटिक्स';
  static const String navProfile = 'प्रोफ़ाइल';

  // Provider Specific
  static const String zeroCommissionTag = '0% कमीशन • सीधा ग्राहक';
  static const String subscriptionActive = 'सब्सक्रिप्शन सक्रिय';
  static const String subscriptionExpired = 'सब्सक्रिप्शन समाप्त';

  // Errors & Alerts
  static const String defaultError = 'कुछ गलत हो गया। कृपया पुन: प्रयास करें।';
  static const String networkError = 'इंटरनेट कनेक्शन नहीं है। कृपया अपना नेटवर्क जांचें।';
  static const String phoneInvalid = 'कृपया 10 अंकों का मान्य मोबाइल नंबर दर्ज करें।';
  static const String otpInvalid = 'कृपया 6 अंकों का सही OTP दर्ज करें।';
}
