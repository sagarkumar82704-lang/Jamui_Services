import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Secure Configuration for Map & Geocoding APIs.
/// By default, enablePaidGoogleGeocoding is FALSE to guarantee ₹0 recurring API cost.
class MapsConfig {
  static String _cloudApiKey = '';
  static bool _listenerInitialized = false;

  /// Feature flag: Set to true only if paid Google Geocoding API is explicitly desired.
  /// When false (default), the app uses 100% free open-source geocoders (BigDataCloud, OSM, Photon) and local cache.
  static bool enablePaidGoogleGeocoding = false;

  /// Compile-time fallback key (if provided via --dart-define)
  static const String _envApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );

  /// Active Google Maps & Geocoding API Key.
  /// Prioritizes Cloud-stored key, then compile-time environment key.
  static String get googleMapsApiKey {
    if (_cloudApiKey.trim().isNotEmpty) {
      return _cloudApiKey.trim();
    }
    return _envApiKey.trim();
  }

  /// Check whether a valid Google Maps API Key is available AND explicitly enabled.
  static bool get hasGoogleKey {
    if (!enablePaidGoogleGeocoding) return false;
    final key = googleMapsApiKey;
    return key.isNotEmpty &&
        !key.contains('Dummy') &&
        !key.contains('YOUR_KEY') &&
        !key.contains('Replace');
  }

  /// Sets up automatic retry when Firebase Auth completes authentication.
  static void initAuthListener() {
    if (_listenerInitialized) return;
    _listenerInitialized = true;
    try {
      FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user != null && !hasGoogleKey) {
          if (kDebugMode) {
            debugPrint('🔑 [MapsConfig] User authenticated (${user.uid}), fetching Cloud API key...');
          }
          fetchFromCloud();
        }
      });
    } catch (_) {}
  }

  /// Fetches the API Key securely from Firebase Firestore (Cloud).
  /// Multi-source fallback: `categories/maps`, `app_config/maps`, `app_settings/maps`.
  static Future<void> fetchFromCloud({FirebaseFirestore? firestore}) async {
    try {
      final db = firestore ?? FirebaseFirestore.instance;

      // 1. Try `app_config/maps`
      try {
        final docConfig = await db.collection('app_config').doc('maps').get();
        if (docConfig.exists && docConfig.data() != null) {
          final key = _extractKey(docConfig.data()!);
          if (key.isNotEmpty) {
            _cloudApiKey = key;
            if (kDebugMode) {
              debugPrint('🔒 [MapsConfig] Google API Key loaded securely from Cloud (app_config/maps)');
            }
            return;
          }
        }
      } catch (_) {}

      // 2. Try `categories/maps`
      try {
        final docCat = await db.collection('categories').doc('maps').get();
        if (docCat.exists && docCat.data() != null) {
          final key = _extractKey(docCat.data()!);
          if (key.isNotEmpty) {
            _cloudApiKey = key;
            if (kDebugMode) {
              debugPrint('🔒 [MapsConfig] Google API Key loaded securely from Cloud (categories/maps)');
            }
            return;
          }
        }
      } catch (_) {}

      // 3. Try `app_settings/maps`
      try {
        final docSettings = await db.collection('app_settings').doc('maps').get();
        if (docSettings.exists && docSettings.data() != null) {
          final key = _extractKey(docSettings.data()!);
          if (key.isNotEmpty) {
            _cloudApiKey = key;
            if (kDebugMode) {
              debugPrint('🔒 [MapsConfig] Google API Key loaded securely from Cloud (app_settings/maps)');
            }
            return;
          }
        }
      } catch (_) {}
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [MapsConfig] Could not fetch Cloud API key: $e');
      }
    }
  }

  static String _extractKey(Map<String, dynamic> data) {
    return (data['google_maps_api_key'] as String? ??
            data['api_key'] as String? ??
            data['key'] as String? ??
            data['apiKey'] as String? ??
            '')
        .trim();
  }

  /// Manually set key in memory (e.g. for testing)
  static void setKeyInMemory(String key) {
    _cloudApiKey = key;
  }
}
