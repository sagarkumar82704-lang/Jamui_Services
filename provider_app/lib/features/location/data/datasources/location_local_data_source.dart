import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/provider_location_entity.dart';
import 'location_remote_data_source.dart';

abstract class LocationLocalDataSource {
  Future<void> cacheLocation(ProviderLocationEntity location, {String? providerId});
  Future<ProviderLocationEntity?> getCachedLocation({String? providerId});
  Future<void> clearCachedLocation({String? providerId});
}

class LocationLocalDataSourceImpl implements LocationLocalDataSource {
  static const String _legacyGlobalKey = 'cached_provider_location_v2';
  static String _providerCacheKey(String providerId) => 'cached_provider_location_$providerId';

  final SharedPreferences prefs;
  final FirebaseFirestore? firestore;
  final FirebaseAuth? auth;

  LocationLocalDataSourceImpl({
    required this.prefs,
    this.firestore,
    this.auth,
  });

  String? _resolveProviderId(String? explicitId) {
    if (explicitId != null && explicitId.trim().isNotEmpty) {
      return explicitId.trim();
    }
    final activeUid = prefs.getString('provider_active_uid');
    if (activeUid != null && activeUid.trim().isNotEmpty) {
      return activeUid.trim();
    }
    final currentAuthUid = (auth?.currentUser ?? FirebaseAuth.instance.currentUser)?.uid;
    if (currentAuthUid != null && currentAuthUid.trim().isNotEmpty) {
      return currentAuthUid.trim();
    }
    return null;
  }

  @override
  Future<void> cacheLocation(ProviderLocationEntity location, {String? providerId}) async {
    // 1. Invalidate legacy unscoped global cache key safely
    try {
      await prefs.remove(_legacyGlobalKey);
    } catch (_) {}

    // 2. Strict GPS Accuracy validation before saving
    if (location.accuracy != null && location.accuracy! > 150.0 && location.source != 'manual_pin') {
      throw InaccurateLocationException(
        accuracy: location.accuracy!,
        message: 'आपकी GPS Location अभी सटीक नहीं मिल रही है (±${location.accuracy!.toInt()}m)। कृपया खुले स्थान पर जाएँ और दोबारा Location Fetch करें। आप Map पर Pin Adjust भी कर सकते हैं।',
      );
    }

    if (!location.hasValidCoordinates) {
      throw Exception('अमान्य लोकेशन कोर्डिनेट्स: (0.0, 0.0) सेव नहीं किया जा सकता।');
    }

    // 3. Resolve canonical provider document identity
    final canonicalId = _resolveProviderId(providerId);

    // 4. Save to Provider-Specific SharedPreferences cache with TTL metadata
    if (canonicalId != null) {
      try {
        final payload = {
          'providerId': canonicalId,
          'savedAt': DateTime.now().toIso8601String(),
          'location': location.toMap(),
        };
        await prefs.setString(_providerCacheKey(canonicalId), jsonEncode(payload));
      } catch (e) {
        debugPrint('⚠️ [LocationLocalDataSource] Error writing local provider cache: $e');
      }
    }

    // 5. Save to Firestore under exact canonical provider document ID
    try {
      if (canonicalId != null) {
        final fs = firestore ?? FirebaseFirestore.instance;
        await fs.collection('providers').doc(canonicalId).set({
          'latitude': location.latitude,
          'longitude': location.longitude,
          'jamuiArea': location.placeName,
          'fullAddress': location.formattedAddress,
          'address': location.formattedAddress,
          'village': location.village,
          'locality': location.locality,
          'city': location.city,
          'district': location.district,
          'state': location.state,
          'pincode': location.pincode,
          'serviceRadiusKm': location.serviceRadiusKm,
          'locationSource': location.source,
          'locationAccuracy': location.accuracy,
          'locationUpdatedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).timeout(const Duration(seconds: 4));
      }
    } catch (e) {
      debugPrint('⚠️ [LocationLocalDataSource] Error persisting to Firestore: $e');
    }
  }

  @override
  Future<ProviderLocationEntity?> getCachedLocation({String? providerId}) async {
    // 1. Invalidate legacy unscoped global cache key if present
    try {
      if (prefs.containsKey(_legacyGlobalKey)) {
        await prefs.remove(_legacyGlobalKey);
      }
    } catch (_) {}

    final canonicalId = _resolveProviderId(providerId);
    if (canonicalId == null) return null;

    try {
      final jsonStr = prefs.getString(_providerCacheKey(canonicalId));
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;

        // Verify provider ownership
        final cachedProvId = map['providerId'] as String?;
        if (cachedProvId != canonicalId) {
          debugPrint('⚠️ [LocationLocalDataSource] Cache identity mismatch. Clearing.');
          await prefs.remove(_providerCacheKey(canonicalId));
          return null;
        }

        // Validate 24-hour TTL expiration
        final savedAtStr = map['savedAt'] as String?;
        if (savedAtStr != null) {
          final savedAt = DateTime.tryParse(savedAtStr);
          if (savedAt == null || DateTime.now().difference(savedAt) > const Duration(hours: 24)) {
            debugPrint('⏱️ [LocationLocalDataSource] Provider cache expired (>24h). Clearing.');
            await prefs.remove(_providerCacheKey(canonicalId));
            return null;
          }
        }

        final locMap = map['location'] as Map<String, dynamic>?;
        if (locMap != null) {
          return ProviderLocationEntity.fromMap(locMap);
        }
      }
    } catch (e) {
      debugPrint('⚠️ [LocationLocalDataSource] Error reading provider location cache: $e');
    }
    return null;
  }

  @override
  Future<void> clearCachedLocation({String? providerId}) async {
    try {
      await prefs.remove(_legacyGlobalKey);
      final canonicalId = _resolveProviderId(providerId);
      if (canonicalId != null) {
        await prefs.remove(_providerCacheKey(canonicalId));
      }
    } catch (e) {
      debugPrint('⚠️ [LocationLocalDataSource] Error clearing provider location cache: $e');
    }
  }
}
