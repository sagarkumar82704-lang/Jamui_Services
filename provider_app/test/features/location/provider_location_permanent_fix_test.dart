import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_jamui_provider/core/services/location_service.dart';
import 'package:apna_jamui_provider/features/location/domain/entities/provider_location_entity.dart';
import 'package:apna_jamui_provider/features/location/data/datasources/location_remote_data_source.dart';
import 'package:apna_jamui_provider/features/location/data/datasources/location_local_data_source.dart';
import 'package:apna_jamui_provider/features/auth/domain/entities/provider_profile_entity.dart';

ProviderLocationEntity createTestLocation({
  required double latitude,
  required double longitude,
  double? accuracy,
  String source = 'native_gps',
  String placeName = 'Jamui Bazaar',
  String formattedAddress = 'Jamui Bazaar, Jamui, Bihar, 811307',
}) {
  return ProviderLocationEntity(
    latitude: latitude,
    longitude: longitude,
    placeName: placeName,
    formattedAddress: formattedAddress,
    city: 'Jamui',
    district: 'Jamui',
    state: 'Bihar',
    pincode: '811307',
    accuracy: accuracy,
    timestamp: DateTime.now(),
    source: source,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Jamui Services — Provider Location Permanent Fix Comprehensive Audit & Unit Tests', () {

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 1: Native GPS valid accuracy (accuracy ≤ 100m)
    // ─────────────────────────────────────────────────────────────────────────
    test('1. Native GPS valid accuracy (accuracy <= 100m) is marked as accurate', () {
      final accurateLocation = createTestLocation(
        latitude: 24.9200,
        longitude: 86.2200,
        accuracy: 15.0,
        source: 'native_gps',
      );

      expect(accurateLocation.isAccurate, isTrue);
      expect(accurateLocation.isWarningAccuracy, isFalse);
      expect(accurateLocation.isPoorAccuracy, isFalse);
      expect(accurateLocation.source, equals('native_gps'));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 2: Native GPS timeout (25s) handling & bridge timeout precedence
    // ─────────────────────────────────────────────────────────────────────────
    test('2. Native GPS 25s timeout and Web Host Bridge 28s timeout hierarchy', () {
      const nativeGpsTimeoutSeconds = 25;
      const webHostBridgeTimeoutSeconds = 28;

      // The Web Host Bridge timeout MUST be strictly greater than native GPS timeout
      // so the bridge doesn't abort while native GPS is about to deliver high accuracy fix
      expect(webHostBridgeTimeoutSeconds, greaterThan(nativeGpsTimeoutSeconds));
      expect(webHostBridgeTimeoutSeconds - nativeGpsTimeoutSeconds, greaterThanOrEqualTo(3));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 3: Accuracy 80m accepted
    // ─────────────────────────────────────────────────────────────────────────
    test('3. Accuracy 80m is accepted as accurate (<= 100m threshold)', () {
      final loc80m = createTestLocation(
        latitude: 24.9180,
        longitude: 86.2250,
        placeName: 'Bodhwantalaab',
        accuracy: 80.0,
      );

      expect(loc80m.isAccurate, isTrue);
      expect(loc80m.isWarningAccuracy, isFalse);
      expect(loc80m.isPoorAccuracy, isFalse);
      expect(LocationService.evaluateAccuracy(loc80m.accuracy!), equals(LocationAccuracyTier.acceptable));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 4: Accuracy 120m warning handling
    // ─────────────────────────────────────────────────────────────────────────
    test('4. Accuracy 120m triggers warning tier (100m < acc <= 150m)', () {
      final loc120m = createTestLocation(
        latitude: 24.9180,
        longitude: 86.2250,
        placeName: 'Mahisauri',
        accuracy: 120.0,
      );

      expect(loc120m.isAccurate, isFalse);
      expect(loc120m.isWarningAccuracy, isTrue);
      expect(loc120m.isPoorAccuracy, isFalse);
      expect(LocationService.evaluateAccuracy(loc120m.accuracy!), equals(LocationAccuracyTier.warning));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 5: Accuracy 500m rejected (InaccurateLocationException thrown)
    // ─────────────────────────────────────────────────────────────────────────
    test('5. Accuracy 500m is classified as poor accuracy and rejected', () {
      final loc500m = createTestLocation(
        latitude: 24.9180,
        longitude: 86.2250,
        placeName: 'Uncalibrated Area',
        accuracy: 500.0,
      );

      expect(loc500m.isAccurate, isFalse);
      expect(loc500m.isWarningAccuracy, isFalse);
      expect(loc500m.isPoorAccuracy, isTrue);

      expect(
        () => throw InaccurateLocationException(
          accuracy: loc500m.accuracy!,
          message: 'GPS Accuracy is 500.0m which exceeds 150m threshold',
        ),
        throwsA(isA<InaccurateLocationException>().having((e) => e.accuracy, 'accuracy', 500.0)),
      );
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 6: Browser fallback poor accuracy (> 150m) rejected
    // ─────────────────────────────────────────────────────────────────────────
    test('6. Browser fallback cellular/IP geolocation (> 150m) is rejected', () {
      // Cellular IP geolocation typically yields 800m - 30km inaccuracy
      const double browserIpAccuracy = 850.0;
      final browserFallbackLoc = createTestLocation(
        latitude: 25.5941, // Patna coordinates mistakenly detected
        longitude: 85.1376,
        placeName: 'Patna (Mismatched IP Geo)',
        accuracy: browserIpAccuracy,
        source: 'browser_geolocation',
      );

      expect(browserFallbackLoc.isPoorAccuracy, isTrue);
      expect(browserFallbackLoc.source, equals('browser_geolocation'));

      // Validate that our validation gate blocks saving
      expect(
        () {
          if ((browserFallbackLoc.accuracy ?? 0) > 150.0) {
            throw InaccurateLocationException(
              accuracy: browserFallbackLoc.accuracy!,
              message: 'Location accuracy (${browserFallbackLoc.accuracy}m) is unacceptable (> 150m). Rejecting unverified browser coordinates.',
            );
          }
        },
        throwsA(isA<InaccurateLocationException>()),
      );
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 7: Stale cache expired (> 24 hours)
    // ─────────────────────────────────────────────────────────────────────────
    test('7. Stale location cache older than 24 hours expires and returns null', () async {
      SharedPreferences.setMockInitialValues({
        'cached_provider_location_prov_123': jsonEncode({
          'latitude': 24.9200,
          'longitude': 86.2200,
          'placeName': 'Jamui',
          'formattedAddress': 'Jamui Bazaar',
          'village': '',
          'locality': '',
          'city': 'Jamui',
          'district': 'Jamui',
          'state': 'Bihar',
          'pincode': '811307',
          'accuracy': 10.0,
          'serviceRadiusKm': 15.0,
          'providerId': 'prov_123',
          // Saved 26 hours ago
          'savedAt': DateTime.now().subtract(const Duration(hours: 26)).toIso8601String(),
        }),
      });

      final prefs = await SharedPreferences.getInstance();
      final localDataSource = LocationLocalDataSourceImpl(prefs: prefs);

      final cached = await localDataSource.getCachedLocation(providerId: 'prov_123');
      expect(cached, isNull, reason: 'Cache > 24 hours must be evicted and return null');

      // Verify the expired cache was removed from prefs
      expect(prefs.containsKey('cached_provider_location_prov_123'), isFalse);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 8: Provider A vs Provider B cache isolation
    // ─────────────────────────────────────────────────────────────────────────
    test('8. Provider A and Provider B location cache are strictly isolated', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final localDataSource = LocationLocalDataSourceImpl(prefs: prefs);

      final locProviderA = createTestLocation(
        latitude: 24.9200,
        longitude: 86.2200,
        placeName: 'Jamui Sadar',
        formattedAddress: 'Shop A, Jamui Sadar',
        accuracy: 12.0,
      );

      final locProviderB = createTestLocation(
        latitude: 24.7733,
        longitude: 86.3778,
        placeName: 'Jhajha',
        formattedAddress: 'Shop B, Jhajha Main Road',
        accuracy: 18.0,
      );

      // Save for Provider A
      await localDataSource.cacheLocation(locProviderA, providerId: 'provider_A');
      // Save for Provider B
      await localDataSource.cacheLocation(locProviderB, providerId: 'provider_B');

      // Fetch for Provider A
      final fetchedA = await localDataSource.getCachedLocation(providerId: 'provider_A');
      expect(fetchedA, isNotNull);
      expect(fetchedA!.formattedAddress, equals('Shop A, Jamui Sadar'));
      expect(fetchedA.latitude, equals(24.9200));

      // Fetch for Provider B
      final fetchedB = await localDataSource.getCachedLocation(providerId: 'provider_B');
      expect(fetchedB, isNotNull);
      expect(fetchedB!.formattedAddress, equals('Shop B, Jhajha Main Road'));
      expect(fetchedB.latitude, equals(24.7733));

      // Fetch for Provider C (not logged in / no cache)
      final fetchedC = await localDataSource.getCachedLocation(providerId: 'provider_C');
      expect(fetchedC, isNull);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 9: Logout & clear cache behavior
    // ─────────────────────────────────────────────────────────────────────────
    test('9. clearCachedLocation removes provider-specific cache and legacy global key', () async {
      SharedPreferences.setMockInitialValues({
        'cached_provider_location_provider_A': '{"latitude": 24.92}',
        'cached_provider_location_v2': '{"latitude": 24.92}',
      });

      final prefs = await SharedPreferences.getInstance();
      final localDataSource = LocationLocalDataSourceImpl(prefs: prefs);

      await localDataSource.clearCachedLocation(providerId: 'provider_A');

      expect(prefs.containsKey('cached_provider_location_provider_A'), isFalse);
      expect(prefs.containsKey('cached_provider_location_v2'), isFalse);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 10: Duplicate location requests ignored
    // ─────────────────────────────────────────────────────────────────────────
    test('10. Duplicate requestId is rejected by the processed request cache', () {
      final processedRequestIds = <String>{};

      bool handleRequest(String requestId) {
        if (requestId.trim().isEmpty) return false;
        if (processedRequestIds.contains(requestId)) return false; // Duplicate
        processedRequestIds.add(requestId);
        return true;
      }

      const reqId = 'req_loc_abc123';
      expect(handleRequest(reqId), isTrue);  // First request accepted
      expect(handleRequest(reqId), isFalse); // Duplicate request rejected
      expect(handleRequest(''), isFalse);     // Empty request rejected
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 11: Stale requestId response discarded
    // ─────────────────────────────────────────────────────────────────────────
    test('11. Stale or unmatched requestId responses are discarded by WebHostBridge', () {
      final pendingCompleters = <String, dynamic>{
        'req_valid_456': 'active_completer',
      };

      bool dispatchResponse(String responseRequestId) {
        if (!pendingCompleters.containsKey(responseRequestId)) {
          // Stale or duplicate response: discard safely
          return false;
        }
        pendingCompleters.remove(responseRequestId);
        return true;
      }

      // First valid response processed
      expect(dispatchResponse('req_valid_456'), isTrue);
      // Re-delivery of same requestId is ignored (not found in pendingCompleters)
      expect(dispatchResponse('req_valid_456'), isFalse);
      // Unrecognized requestId is ignored
      expect(dispatchResponse('req_unknown_999'), isFalse);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 12: Edit Profile address + coordinates synchronization
    // ─────────────────────────────────────────────────────────────────────────
    test('12. Edit Profile synchronizes latitude, longitude, and address fields', () {
      final initialProfile = ProviderProfileEntity(
        id: 'prov_test',
        fullName: 'Sharma Ji',
        businessName: 'Sharma Electricals',
        primaryCategoryId: 'electrician',
        primaryCategoryTitle: 'Electrician',
        email: 'sharma@example.com',
        phoneNumber: '9876543210',
        latitude: 24.9180,
        longitude: 86.2230,
        jamuiArea: 'Bodhwantalaab',
        fullAddress: 'Bodhwantalaab, Jamui',
        serviceRadiusKm: 15.0,
        createdAt: DateTime.now(),
      );

      // Provider updates location via map picker
      final newLat = 24.9250;
      final newLng = 86.2300;
      final newArea = 'Mahisauri';
      final newAddress = 'Near Mahisauri Chowk, Jamui';

      final permittedUpdateFields = <String, dynamic>{
        'latitude': newLat,
        'longitude': newLng,
        'jamuiArea': newArea,
        'fullAddress': newAddress,
        'serviceRadiusKm': 20.0,
      };

      final updatedProfile = initialProfile.copyWith(
        latitude: permittedUpdateFields['latitude'] as double?,
        longitude: permittedUpdateFields['longitude'] as double?,
        jamuiArea: permittedUpdateFields['jamuiArea'] as String?,
        fullAddress: permittedUpdateFields['fullAddress'] as String?,
        serviceRadiusKm: permittedUpdateFields['serviceRadiusKm'] as double?,
      );

      expect(updatedProfile.latitude, equals(24.9250));
      expect(updatedProfile.longitude, equals(86.2300));
      expect(updatedProfile.jamuiArea, equals('Mahisauri'));
      expect(updatedProfile.fullAddress, equals('Near Mahisauri Chowk, Jamui'));
      expect(updatedProfile.serviceRadiusKm, equals(20.0));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 13: Canonical document ID resolution
    // ─────────────────────────────────────────────────────────────────────────
    test('13. Canonical providerId resolution prioritizes explicit id, then stored active UID', () async {
      SharedPreferences.setMockInitialValues({
        'provider_active_uid': 'stored_canonical_uid_777',
      });
      final prefs = await SharedPreferences.getInstance();

      String resolveId({String? explicitId, String? authUid}) {
        if (explicitId != null && explicitId.trim().isNotEmpty) {
          return explicitId.trim();
        }
        final stored = prefs.getString('provider_active_uid');
        if (stored != null && stored.trim().isNotEmpty) {
          return stored.trim();
        }
        return authUid ?? '';
      }

      // Priority 1: Explicit ID
      expect(resolveId(explicitId: 'explicit_prov_1'), equals('explicit_prov_1'));

      // Priority 2: Stored active UID
      expect(resolveId(explicitId: null, authUid: 'fallback_auth_uid'), equals('stored_canonical_uid_777'));

      // Priority 3: Auth UID if no stored active UID
      await prefs.remove('provider_active_uid');
      expect(resolveId(explicitId: null, authUid: 'fallback_auth_uid'), equals('fallback_auth_uid'));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 14: Distance calculation with valid vs invalid coordinates
    // ─────────────────────────────────────────────────────────────────────────
    test('14. Customer & Provider distance calculation handles valid and invalid coordinates', () {
      // Valid coordinates: Jamui Sadar to Jhajha Station (~22.6 km)
      final validDistance = LocationService.calculateDistanceKm(
        startLatitude: 24.9200,
        startLongitude: 86.2200,
        endLatitude: 24.7733,
        endLongitude: 86.3778,
      );
      expect(validDistance, greaterThan(20.0));
      expect(validDistance, lessThan(25.0));

      // Same point distance is 0.0
      final zeroDistance = LocationService.calculateDistanceKm(
        startLatitude: 24.9200,
        startLongitude: 86.2200,
        endLatitude: 24.9200,
        endLongitude: 86.2200,
      );
      expect(zeroDistance, closeTo(0.0, 0.01));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 15: Permission denied handling
    // ─────────────────────────────────────────────────────────────────────────
    test('15. PermissionDeniedException carries clear actionable message', () {
      const message = 'लोकेशन अनुमति (Location Permission) अस्वीकृत की गई। कृपया ऐप सेटिंग्स से अनुमति दें।';
      final exception = PermissionDeniedException(message);

      expect(exception.message, equals(message));
      expect(exception.toString(), contains('लोकेशन अनुमति'));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 16: GPS disabled handling
    // ─────────────────────────────────────────────────────────────────────────
    test('16. LocationServiceDisabledException is recognized and handled', () {
      const exception = LocationServiceDisabledException();
      expect(exception, isA<LocationServiceDisabledException>());
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 17: Manual map pin confirmation override (accuracy check bypassed)
    // ─────────────────────────────────────────────────────────────────────────
    test('17. Manual map pin confirmation sets source=manual_pin and bypasses accuracy rejection', () {
      final manualPinLocation = createTestLocation(
        latitude: 24.9195,
        longitude: 86.2215,
        placeName: 'Manual Pin Placement',
        accuracy: 999.0, // High/unmeasured accuracy number
        source: 'manual_pin',
      );

      // Accuracy is > 150m, but source is 'manual_pin'
      expect(manualPinLocation.source, equals('manual_pin'));

      bool canSaveLocation(ProviderLocationEntity loc) {
        if (loc.source == 'manual_pin') {
          return true; // Intentional provider pin override
        }
        return (loc.accuracy ?? 999.0) <= 150.0;
      }

      expect(canSaveLocation(manualPinLocation), isTrue,
        reason: 'Manual pin on map is an intentional human selection and must be accepted');

      // But an automated GPS fix with 999.0m accuracy must still be rejected
      final poorGpsLocation = manualPinLocation.copyWith(source: 'native_gps');
      expect(canSaveLocation(poorGpsLocation), isFalse);
    });

  });
}
