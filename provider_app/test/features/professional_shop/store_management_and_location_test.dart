import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:apna_jamui_provider/features/location/data/datasources/location_remote_data_source.dart';
import 'package:apna_jamui_provider/features/location/domain/entities/provider_location_entity.dart';
import 'package:apna_jamui_provider/features/professional_shop/data/datasources/professional_provider_remote_data_source.dart';
import 'package:apna_jamui_provider/features/professional_shop/domain/entities/professional_shop_profile_entity.dart';
import 'package:apna_jamui_provider/features/professional_shop/presentation/pages/professional_set_store_location_page.dart';

class _FakeLocationRemoteDataSource implements LocationRemoteDataSource {
  Position? nextPosition;
  Object? nextPositionError;
  LocationPermission permission = LocationPermission.whileInUse;
  final Map<String, StoreReverseGeocodeResult> reverseResults = {};
  List<ProviderLocationEntity> searchResultList = const [];

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => permission;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;

  @override
  Future<Position> getCurrentPosition() async {
    if (nextPositionError != null) {
      throw nextPositionError!;
    }
    return nextPosition ??
        Position(
          latitude: 24.9195,
          longitude: 86.2208,
          timestamp: DateTime(2026, 11, 9),
          accuracy: 8.0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
  }

  @override
  Future<ProviderLocationEntity> reverseGeocode(
    double latitude,
    double longitude, {
    double? accuracy,
    double serviceRadiusKm = 10.0,
  }) async {
    final res = await reverseGeocodeForStoreLocation(
      latitude,
      longitude,
      accuracy: accuracy,
    );
    return ProviderLocationEntity(
      latitude: latitude,
      longitude: longitude,
      placeName: res.placeName,
      formattedAddress: res.formattedAddress,
      village: res.isApproximate ? '' : res.area,
      locality: res.isApproximate ? '' : res.area,
      city: res.city,
      district: res.district,
      state: res.state,
      pincode: res.pincode,
      accuracy: accuracy,
      serviceRadiusKm: serviceRadiusKm,
      timestamp: DateTime(2026, 11, 9),
    );
  }

  @override
  Future<StoreReverseGeocodeResult> reverseGeocodeForStoreLocation(
    double latitude,
    double longitude, {
    double? accuracy,
  }) async {
    if (!StoreCoordinateValidator.isValidNumbers(latitude, longitude)) {
      throw FormatException('Invalid coordinates ($latitude, $longitude)');
    }
    final key = '${latitude.toStringAsFixed(4)},${longitude.toStringAsFixed(4)}';
    if (reverseResults.containsKey(key)) {
      return reverseResults[key]!;
    }
    return StoreReverseGeocodeResult(
      latitude: latitude,
      longitude: longitude,
      formattedAddress: 'Maharajganj Main Road, Jamui, Bihar, 811307',
      placeName: 'Maharajganj Main Road',
      area: 'Maharajganj',
      city: 'Jamui',
      district: 'Jamui',
      state: 'Bihar',
      pincode: '811307',
      isApproximate: false,
      isNotFound: false,
    );
  }

  @override
  Future<List<ProviderLocationEntity>> searchPlaces(
    String query, {
    double? providerLat,
    double? providerLng,
  }) async {
    return searchResultList;
  }
}

ProfessionalShopProfileEntity _buildSampleShop({
  double latitude = 24.9195,
  double longitude = 86.2208,
  String fullAddress = 'Station Road, Jamui, Bihar',
  String landmark = 'Near Kali Mandir',
  ShopPromoBannerEntity? promoBanner,
}) {
  return ProfessionalShopProfileEntity(
    id: 'shop_sagar_1',
    ownerUid: 'uid_sagar_1',
    ownerEmail: 'sagar@example.com',
    shopName: 'Sagar Grocery Jamui',
    demandCategoryTitle: 'Kirana & Grocery',
    description: 'Daily essentials & grocery store in Jamui',
    logoUrl: 'providers/uid_sagar_1/profile/logo.jpg',
    bannerUrl: 'providers/uid_sagar_1/business/cover.jpg',
    fullAddress: fullAddress,
    jamuiArea: 'Station Road',
    landmark: landmark,
    latitude: latitude,
    longitude: longitude,
    locationSource: 'manual_lat_lng',
    isLocationApproximate: false,
    contactPhone: '9876543210',
    whatsAppNumber: '9876543210',
    openingTime: '08:00 AM',
    closingTime: '09:00 PM',
    isOpen: true,
    isHomeDeliveryActive: true,
    isPickupActive: true,
    minOrderAmount: 100,
    deliveryCharges: 20,
    freeDeliveryThreshold: 499,
    serviceRadiusKm: 5,
    estimatedDeliveryTimeMinutes: 35,
    pickupInstructions: 'Counter 1',
    isApproved: true,
    status: 'approved',
    isSubscriptionActive: true,
    promoBanner: promoBanner,
  );
}

void main() {
  group('StoreCoordinateValidator — Range & Format Validation', () {
    test('accepts valid Jamui coordinates (24.9195, 86.2208)', () {
      final res = StoreCoordinateValidator.validateStrings('24.9195', '86.2208');
      expect(res.isValid, isTrue);
      expect(res.latitude, closeTo(24.9195, 0.000001));
      expect(res.longitude, closeTo(86.2208, 0.000001));
      expect(res.latitudeError, isNull);
      expect(res.longitudeError, isNull);
      expect(res.generalError, isNull);
    });

    test('rejects out-of-range latitude (< -90 or > +90)', () {
      final high = StoreCoordinateValidator.validateStrings('91.25', '86.2208');
      expect(high.isValid, isFalse);
      expect(high.latitudeError, contains('between -90 and +90'));

      final low = StoreCoordinateValidator.validateStrings('-95.0', '86.2208');
      expect(low.isValid, isFalse);
      expect(low.latitudeError, contains('between -90 and +90'));
    });

    test('rejects out-of-range longitude (< -180 or > +180)', () {
      final high = StoreCoordinateValidator.validateStrings('24.9195', '181.5');
      expect(high.isValid, isFalse);
      expect(high.longitudeError, contains('between -180 and +180'));

      final low = StoreCoordinateValidator.validateStrings('24.9195', '-185.0');
      expect(low.isValid, isFalse);
      expect(low.longitudeError, contains('between -180 and +180'));
    });

    test('rejects empty, malformed, and (0, 0) coordinates', () {
      final empty = StoreCoordinateValidator.validateStrings('', '');
      expect(empty.isValid, isFalse);
      expect(empty.latitudeError, isNotNull);
      expect(empty.longitudeError, isNotNull);

      final malformed =
          StoreCoordinateValidator.validateStrings('abc', '86.22.08');
      expect(malformed.isValid, isFalse);
      expect(malformed.latitudeError, isNotNull);
      expect(malformed.longitudeError, isNotNull);

      final zeroZero = StoreCoordinateValidator.validateStrings('0', '0.0');
      expect(zeroZero.isValid, isFalse);
      expect(zeroZero.generalError, contains('(0, 0)'));
    });
  });

  group('ProfessionalProviderRemoteDataSource — Security & Payload Sanitization',
      () {
    test('strips all admin/approval/subscription/financial fields', () {
      final rawPayload = <String, dynamic>{
        'shopName': 'Updated Sagar Store',
        'description': 'Fresh groceries',
        'latitude': 24.9195,
        'longitude': 86.2208,
        // Attempted unauthorized modifications:
        'isApproved': true,
        'status': 'approved',
        'ownerUid': 'hacker_uid',
        'isSubscriptionActive': true,
        'rating': 5.0,
        'ratingCount': 999,
        'totalRevenue': 500000,
        'maxProductsLimit': 10000,
        'shopCategory': 'Pharmacy',
      };

      final sanitized =
          ProfessionalProviderRemoteDataSource.sanitizeShopUpdatePayload(
        rawPayload,
      );

      expect(sanitized['shopName'], equals('Updated Sagar Store'));
      expect(sanitized['description'], equals('Fresh groceries'));
      expect(sanitized['latitude'], equals(24.9195));
      expect(sanitized['longitude'], equals(86.2208));

      expect(sanitized.containsKey('isApproved'), isFalse);
      expect(sanitized.containsKey('status'), isFalse);
      expect(sanitized.containsKey('ownerUid'), isFalse);
      expect(sanitized.containsKey('isSubscriptionActive'), isFalse);
      expect(sanitized.containsKey('rating'), isFalse);
      expect(sanitized.containsKey('ratingCount'), isFalse);
      expect(sanitized.containsKey('totalRevenue'), isFalse);
      expect(sanitized.containsKey('maxProductsLimit'), isFalse);
      expect(sanitized.containsKey('shopCategory'), isFalse);
    });

    test('throws FormatException when coordinates in update payload are invalid',
        () {
      expect(
        () => ProfessionalProviderRemoteDataSource.sanitizeShopUpdatePayload({
          'shopName': 'Bad Coords Shop',
          'latitude': 120.0,
          'longitude': 86.2208,
        }),
        throwsFormatException,
      );
    });
  });

  group('ShopPromoBannerEntity — Schedule & Active State', () {
    test('isCurrentlyLive respects isActive, content, startDate, and endDate',
        () {
      final now = DateTime(2026, 11, 9, 12, 0);

      const emptyBanner = ShopPromoBannerEntity(isActive: true);
      expect(emptyBanner.hasContent, isFalse);
      expect(emptyBanner.isCurrentlyLive(now), isFalse);

      final activeBanner = ShopPromoBannerEntity(
        title: 'Flat 20% OFF',
        subtitle: 'On Daily Essentials',
        offerText: 'Free Delivery Above ₹499',
        imageUrl: 'providers/uid_sagar_1/workplace/banner.jpg',
        isActive: true,
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 15),
      );
      expect(activeBanner.hasContent, isTrue);
      expect(activeBanner.isCurrentlyLive(now), isTrue);

      final expiredBanner = activeBanner.copyWith(
        endDate: DateTime(2026, 11, 5),
      );
      expect(expiredBanner.isCurrentlyLive(now), isFalse);

      final inactiveBanner = activeBanner.copyWith(isActive: false);
      expect(inactiveBanner.isCurrentlyLive(now), isFalse);
    });
  });

  group('ProfessionalSetStoreLocationPage — 3 Location Methods Widget Tests',
      () {
    testWidgets(
      'preserves saved store location on open and validates Manual Lat/Lng (Exact, Approximate, Not Found)',
      (tester) async {
        final fakeLocDs = _FakeLocationRemoteDataSource();
        // Exact address for 24.9195, 86.2208
        fakeLocDs.reverseResults['24.9195,86.2208'] =
            const StoreReverseGeocodeResult(
          latitude: 24.9195,
          longitude: 86.2208,
          formattedAddress: 'Maharajganj Main Road, Jamui, Bihar, 811307',
          placeName: 'Maharajganj Main Road',
          area: 'Maharajganj',
          city: 'Jamui',
          district: 'Jamui',
          state: 'Bihar',
          pincode: '811307',
          isApproximate: false,
          isNotFound: false,
        );
        // Approximate area-level address for 24.8500, 86.1500
        fakeLocDs.reverseResults['24.8500,86.1500'] =
            const StoreReverseGeocodeResult(
          latitude: 24.8500,
          longitude: 86.1500,
          formattedAddress: 'Jamui District, Bihar',
          placeName: 'Jamui District',
          area: 'Jamui',
          city: '',
          district: 'Jamui',
          state: 'Bihar',
          pincode: '',
          isApproximate: true,
          isNotFound: false,
        );
        // Address not found for 25.1111, 86.9999
        fakeLocDs.reverseResults['25.1111,86.9999'] =
            const StoreReverseGeocodeResult(
          latitude: 25.1111,
          longitude: 86.9999,
          formattedAddress: 'Address not found',
          isNotFound: true,
          isApproximate: false,
        );

        StoreLocationSelectionResult? confirmedSelection;
        final shop = _buildSampleShop();

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (ctx) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    confirmedSelection = await Navigator.of(ctx)
                        .push<StoreLocationSelectionResult>(
                      MaterialPageRoute(
                        builder: (_) => ProfessionalSetStoreLocationPage(
                          shop: shop,
                          locationDataSource: fakeLocDs,
                          persistImmediately: false,
                        ),
                      ),
                    );
                  },
                  child: const Text('Open Location Picker'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Location Picker'));
        await tester.pumpAndSettle();

        // Verify existing saved shop address & coordinates are displayed and NOT overwritten
        expect(find.text('Station Road, Jamui, Bihar'), findsOneWidget);
        expect(
          find.textContaining('Saved Coordinates: 24.919500, 86.220800'),
          findsOneWidget,
        );

        // Option C (Manual Lat/Lng) is selected because shop.locationSource == 'manual_lat_lng'
        // 1. Test invalid latitude (> 90)
        await tester.enterText(
          find.byKey(const Key('field_manual_latitude')),
          '99.5',
        );
        await tester.enterText(
          find.byKey(const Key('field_manual_longitude')),
          '86.2208',
        );
        await tester.tap(find.byKey(const Key('btn_manual_find_address')));
        await tester.pumpAndSettle();
        expect(find.textContaining('between -90 and +90'), findsOneWidget);

        // 2. Test "Address not found" state
        await tester.enterText(
          find.byKey(const Key('field_manual_latitude')),
          '25.1111',
        );
        await tester.enterText(
          find.byKey(const Key('field_manual_longitude')),
          '86.9999',
        );
        await tester.tap(find.byKey(const Key('btn_manual_find_address')));
        await tester.pumpAndSettle();
        expect(find.text('Address not found'), findsOneWidget);

        // Confirm button should be disabled when address is not found
        final confirmBtnWhenNotFound = tester.widget<ElevatedButton>(
          find.byKey(const Key('btn_confirm_and_save_location')),
        );
        expect(confirmBtnWhenNotFound.onPressed, isNull);

        // 3. Test Approximate area-level address badge
        await tester.enterText(
          find.byKey(const Key('field_manual_latitude')),
          '24.8500',
        );
        await tester.enterText(
          find.byKey(const Key('field_manual_longitude')),
          '86.1500',
        );
        await tester.tap(find.byKey(const Key('btn_manual_find_address')));
        await tester.pumpAndSettle();
        expect(find.text('Approximate Area-Level Address'), findsOneWidget);
        expect(find.text('Jamui District, Bihar'), findsOneWidget);

        // 4. Test Exact Jamui coordinates (24.9195, 86.2208) & Confirm
        await tester.enterText(
          find.byKey(const Key('field_manual_latitude')),
          '24.9195',
        );
        await tester.enterText(
          find.byKey(const Key('field_manual_longitude')),
          '86.2208',
        );
        await tester.tap(find.byKey(const Key('btn_manual_find_address')));
        await tester.pumpAndSettle();
        expect(
          find.text('Maharajganj Main Road, Jamui, Bihar, 811307'),
          findsOneWidget,
        );

        await tester.ensureVisible(
          find.byKey(const Key('btn_confirm_and_save_location')),
        );
        await tester.tap(
          find.byKey(const Key('btn_confirm_and_save_location')),
        );
        await tester.pumpAndSettle();

        expect(confirmedSelection, isNotNull);
        expect(confirmedSelection!.latitude, closeTo(24.9195, 0.00001));
        expect(confirmedSelection!.longitude, closeTo(86.2208, 0.00001));
        expect(
          confirmedSelection!.fullAddress,
          equals('Maharajganj Main Road, Jamui, Bihar, 811307'),
        );
        expect(confirmedSelection!.locationSource, equals('manual_lat_lng'));
        expect(confirmedSelection!.isLocationApproximate, isFalse);
      },
    );

    testWidgets(
      'Option A (Current GPS) handles permission denial and confirms only on explicit tap',
      (tester) async {
        final fakeLocDs = _FakeLocationRemoteDataSource();
        fakeLocDs.nextPositionError = const PermissionDeniedException(
          'Location permission denied by user.',
        );

        final shop = _buildSampleShop();
        await tester.pumpWidget(
          MaterialApp(
            home: ProfessionalSetStoreLocationPage(
              shop: shop,
              locationDataSource: fakeLocDs,
              persistImmediately: false,
            ),
          ),
        );

        // Switch to Option A (Current GPS)
        await tester.tap(find.byKey(const Key('tab_option_a_current_gps')));
        await tester.pumpAndSettle();

        // Tap Fetch GPS -> should show permission denied error banner
        await tester.tap(find.byKey(const Key('btn_fetch_current_gps')));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Location permission denied by user.'),
          findsOneWidget,
        );

        // Now allow GPS position and retry
        fakeLocDs.nextPositionError = null;
        await tester.tap(find.byKey(const Key('btn_fetch_current_gps')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(
          find.text('Maharajganj Main Road, Jamui, Bihar, 811307'),
          findsOneWidget,
        );
      },
    );
  });
}

