import 'package:cloud_firestore/cloud_firestore.dart';

/// Secure Configuration Manager for Razorpay Payments in Provider App.
/// 
/// Security Architecture:
/// 1. Only Public Key (`key_id`) is used on the client.
/// 2. `key_secret` is NEVER exposed to the frontend / client app.
/// 3. Supports live cloud switching between Test Mode (`rzp_test_...`) and
///    Production Live Mode (`rzp_live_...`) via Firestore `app_config/payment`.
class RazorpayPaymentConfig {
  static String _cloudKeyId = '';
  static String _merchantName = 'JAMUI SERVICE';

  /// Compile-time fallback key (via --dart-define=RAZORPAY_KEY_ID=rzp_test_...)
  static const String _envKeyId = String.fromEnvironment(
    'RAZORPAY_KEY_ID',
    defaultValue: '',
  );

  /// Active Razorpay Key ID (Cloud Key > Environment Key > Fallback)
  static String get keyId {
    if (_cloudKeyId.trim().isNotEmpty) {
      return _cloudKeyId.trim();
    }
    if (_envKeyId.trim().isNotEmpty) {
      return _envKeyId.trim();
    }
    return '';
  }

  static String get merchantName => _merchantName;

  /// Whether Razorpay is in Production Live Mode
  static bool get isLiveMode => keyId.startsWith('rzp_live_');

  /// Whether Razorpay is in Test Mode
  static bool get isTestMode => keyId.startsWith('rzp_test_');

  /// Check whether a valid Razorpay Key is configured
  static bool get isConfigured {
    final k = keyId;
    return k.isNotEmpty &&
        (k.startsWith('rzp_test_') || k.startsWith('rzp_live_')) &&
        !k.contains('placeholder') &&
        !k.contains('YOUR_KEY');
  }

  /// Fetches the Razorpay Public Key securely from Firestore Cloud.
  /// Document: `app_config/payment` or `app_config/razorpay`
  static Future<void> fetchFromCloud({FirebaseFirestore? firestore}) async {
    try {
      final db = firestore ?? FirebaseFirestore.instance;

      // 1. Try `app_config/payment`
      try {
        final doc = await db.collection('app_config').doc('payment').get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final fetchedKey = _extractKey(data);
          if (fetchedKey.isNotEmpty) {
            _cloudKeyId = fetchedKey;
            _merchantName = (data['merchant_name'] as String?) ?? (data['merchantName'] as String?) ?? 'JAMUI SERVICE';
            return;
          }
        }
      } catch (_) {}

      // 2. Try `app_config/razorpay`
      try {
        final doc = await db.collection('app_config').doc('razorpay').get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final fetchedKey = _extractKey(data);
          if (fetchedKey.isNotEmpty) {
            _cloudKeyId = fetchedKey;
            _merchantName = (data['merchant_name'] as String?) ?? 'JAMUI SERVICE';
            return;
          }
        }
      } catch (_) {}
    } catch (_) {}
  }

  static String _extractKey(Map<String, dynamic> data) {
    return (data['razorpay_key_id'] as String? ??
            data['key_id'] as String? ??
            data['keyId'] as String? ??
            data['razorpayKeyId'] as String? ??
            data['api_key'] as String? ??
            '')
        .trim();
  }


  /// Manually set key in memory (e.g. for testing)
  static void setKeyInMemory(String key) {
    _cloudKeyId = key;
  }
}
