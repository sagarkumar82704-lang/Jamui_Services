/// [AppEnvironmentType] वातावरण के प्रकार को परिभाषित करता है।
enum AppEnvironmentType {
  dev,     // डेवलपमेंट और टेस्टिंग (लोकल/डेव डेटाबेस)
  staging, // प्री-रिलीज़ टेस्टिंग
  prod,    // असली लाइव ग्राहक और सर्विस प्रोवाइडर्स
}

/// [AppConfig] पूरे एप्लिकेशन का ग्लोबल एनवायरनमेंट कॉन्फ़िगरेशन मैनेजर है।
/// इससे यह गारंटी मिलती है कि डेवलपमेंट के दौरान किया गया कोई भी बदलाव प्रोडक्शन डेटाबेस को प्रभावित नहीं करेगा।
class AppConfig {
  static AppEnvironmentType _environment = AppEnvironmentType.dev;
  static bool _isInitialized = false;

  /// वर्तमान वातावरण प्राप्त करें
  static AppEnvironmentType get environment => _environment;
  static bool get isDev => _environment == AppEnvironmentType.dev;
  static bool get isStaging => _environment == AppEnvironmentType.staging;
  static bool get isProd => _environment == AppEnvironmentType.prod;

  /// एनवायरनमेंट सेट करें
  static void setEnvironment(AppEnvironmentType env) {
    _environment = env;
    _isInitialized = true;
  }

  /// [getCollectionName] सुरक्षित कलेक्शन नेम प्रदान करता है।
  /// प्रोडक्शन में यह मूल नाम (उदा: `users`) देगा, जबकि Dev में यह `dev_users` देगा।
  /// इससे कभी भी प्रोडक्शन डेटा दूषित (Corrupted) नहीं होगा।
  static String getCollectionName(String baseName) {
    if (isProd) {
      return baseName;
    } else if (isStaging) {
      return 'staging_$baseName';
    } else {
      return 'dev_$baseName';
    }
  }

  /// फीचर टॉगल (Feature Flags) - सुरक्षा और नए फीचर्स को सुरक्षित रोलआउट करने के लिए
  static bool get enableDetailedAnalyticsLogging => isDev;
  static bool get enableMockPayments => isDev;
  static bool get isProductionMode => isProd && _isInitialized;
}
