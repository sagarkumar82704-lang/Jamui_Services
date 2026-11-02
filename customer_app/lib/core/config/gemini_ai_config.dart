import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Secure Cloud Configuration for Google Gemini AI in Jamui Services Customer App.
class GeminiAiConfig {
  static String _cloudApiKey = '';
  static String _cloudModel = 'gemini-1.5-flash';
  static bool _listenerInitialized = false;

  /// Compile-time fallback key
  static const String _envApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  /// Initializes auth state listener to fetch key from authenticated Firestore
  static void initAuthListener() {
    if (_listenerInitialized) return;
    _listenerInitialized = true;
    try {
      FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user != null && !isConfigured) {
          fetchFromCloud();
        }
      });
    } catch (_) {}
  }

  /// Active Gemini API Key (Cloud Key > Environment Key)
  static String get apiKey {
    if (_cloudApiKey.trim().isNotEmpty) {
      return _cloudApiKey.trim();
    }
    if (_envApiKey.trim().isNotEmpty) {
      return _envApiKey.trim();
    }
    return '';
  }

  /// Model name (defaults to 'gemini-1.5-flash')
  static String get model => _cloudModel.isNotEmpty ? _cloudModel : 'gemini-1.5-flash';

  /// Whether a valid Gemini API Key is configured
  static bool get isConfigured {
    final k = apiKey;
    return k.isNotEmpty &&
        k.length >= 20 &&
        !k.contains('YOUR_') &&
        !k.contains('placeholder');
  }

  /// Fetches Gemini AI Config from Firestore `app_config/ai` or `app_config/gemini`
  static Future<void> fetchFromCloud({FirebaseFirestore? firestore}) async {
    try {
      final db = firestore ?? FirebaseFirestore.instance;

      // 1. Try `app_config/ai`
      try {
        final doc = await db.collection('app_config').doc('ai').get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final key = _extractApiKey(data);
          if (key.isNotEmpty) {
            _cloudApiKey = key;
            _cloudModel = (data['model'] as String?) ?? (data['gemini_model'] as String?) ?? 'gemini-1.5-flash';
            if (kDebugMode) {
              debugPrint('🤖 [GeminiAiConfig] Key loaded from Cloud (app_config/ai): ${_maskKey(_cloudApiKey)} (Model: $_cloudModel)');
            }
            return;
          }
        }
      } catch (_) {}

      // 2. Try `app_config/gemini`
      try {
        final doc = await db.collection('app_config').doc('gemini').get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final key = _extractApiKey(data);
          if (key.isNotEmpty) {
            _cloudApiKey = key;
            _cloudModel = (data['model'] as String?) ?? 'gemini-1.5-flash';
            if (kDebugMode) {
              debugPrint('🤖 [GeminiAiConfig] Key loaded from Cloud (app_config/gemini): ${_maskKey(_cloudApiKey)} (Model: $_cloudModel)');
            }
            return;
          }
        }
      } catch (_) {}
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [GeminiAiConfig] Cloud fetch error: $e');
      }
    }
  }

  static String _extractApiKey(Map<String, dynamic> data) {
    return (data['gemini_api_key'] as String? ??
            data['geminiApiKey'] as String? ??
            data['apiKey'] as String? ??
            data['api_key'] as String? ??
            data['key'] as String? ??
            '')
        .trim();
  }

  static String _maskKey(String key) {
    if (key.length <= 10) return key;
    return '${key.substring(0, 6)}...${key.substring(key.length - 4)}';
  }

  /// Manually set key in memory (e.g. for testing)
  static void setKeyInMemory(String key, {String model = 'gemini-1.5-flash'}) {
    _cloudApiKey = key;
    _cloudModel = model;
  }
}
