import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/customer_location_entity.dart';

abstract class LocationLocalDataSource {
  Future<void> cacheLocation(CustomerLocationEntity location);
  Future<CustomerLocationEntity?> getCachedLocation();
  Future<void> clearCachedLocation();
}

class LocationLocalDataSourceImpl implements LocationLocalDataSource {
  static const String _keyCachedLocation = 'cached_customer_location_v3';
  final SharedPreferences? prefs;
  final FirebaseFirestore? firestore;
  final FirebaseAuth? auth;

  LocationLocalDataSourceImpl({
    this.prefs,
    this.firestore,
    this.auth,
  });

  @override
  Future<void> cacheLocation(CustomerLocationEntity location) async {
    try {
      final jsonStr = jsonEncode(location.toMap());
      await prefs?.setString(_keyCachedLocation, jsonStr);
    } catch (e) {
      debugPrint('⚠️ [LocationLocalDataSource] Error saving location to SharedPreferences: $e');
    }

    try {
      // Also persist to current logged in customer's profile if Firebase is active
      User? user = auth?.currentUser;
      if (user == null && auth == null) {
        try {
          user = FirebaseAuth.instance.currentUser;
        } catch (_) {}
      }

      if (user != null) {
        final fs = firestore ?? FirebaseFirestore.instance;
        final locationData = <String, dynamic>{
          'latitude': location.latitude,
          'longitude': location.longitude,
          'jamuiArea': location.placeName,
          'address': location.formattedAddress,
          'formattedAddress': location.formattedAddress,
          'village': location.village,
          'locality': location.locality,
          'suburb': location.suburb,
          'block': location.block,
          'city': location.city,
          'district': location.district,
          'state': location.state,
          'pincode': location.pincode,
          'lastLocationUpdatedAt': FieldValue.serverTimestamp(),
        };

        await Future.wait([
          fs
              .collection('customers')
              .doc(user.uid)
              .set(locationData, SetOptions(merge: true))
              .timeout(const Duration(seconds: 4)),
          fs
              .collection('users')
              .doc(user.uid)
              .set(locationData, SetOptions(merge: true))
              .timeout(const Duration(seconds: 4)),
        ]);
      }
    } catch (e) {
      debugPrint('⚠️ [LocationLocalDataSource] Error syncing location to Firestore: $e');
    }
  }

  @override
  Future<CustomerLocationEntity?> getCachedLocation() async {
    try {
      final jsonStr = prefs?.getString(_keyCachedLocation);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        final location = CustomerLocationEntity.fromMap(map);

        // Sanity Check: Khaira center is ~(24.8490, 86.2130).
        // If cached location contains Khaira or 811317 but distance > 4000m, it is poisoned stale data. Purge it!
        final distMeters = Geolocator.distanceBetween(
          location.latitude,
          location.longitude,
          24.8490,
          86.2130,
        );
        final isStaleKhaira = (location.placeName.toLowerCase().contains('khaira') ||
                location.formattedAddress.toLowerCase().contains('khaira') ||
                location.placeName.contains('खैरा') ||
                location.pincode == '811317') &&
            distMeters > 4000.0;

        if (isStaleKhaira) {
          if (kDebugMode) {
            debugPrint('🗑️ [CACHE_DIAG] Purged stale Khaira from customer cache: ${(distMeters / 1000).toStringAsFixed(1)}km from Khaira center');
          }
          await clearCachedLocation();
          return null;
        }

        return location;
      }
    } catch (e) {
      debugPrint('⚠️ [LocationLocalDataSource] Error getting cached location: $e');
    }
    return null;
  }

  @override
  Future<void> clearCachedLocation() async {
    await prefs?.remove(_keyCachedLocation);
    // Also clear old v2 key if present
    await prefs?.remove('cached_customer_location_v2');
  }
}
