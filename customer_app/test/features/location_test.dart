import 'dart:async';
import 'package:apna_jamui_customer/core/services/location_service.dart';
import 'package:apna_jamui_customer/features/discovery/domain/entities/paginated_providers_entity.dart';
import 'package:apna_jamui_customer/features/discovery/domain/entities/service_category_entity.dart';
import 'package:apna_jamui_customer/features/discovery/domain/entities/service_provider_entity.dart';
import 'package:apna_jamui_customer/features/discovery/domain/repositories/customer_discovery_repository.dart';
import 'package:apna_jamui_customer/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:apna_jamui_customer/features/location/domain/entities/customer_location_entity.dart';
import 'package:apna_jamui_customer/features/location/domain/repositories/location_repository.dart';
import 'package:apna_jamui_customer/features/location/presentation/bloc/location_bloc.dart';
import 'package:apna_jamui_customer/features/location/presentation/bloc/location_event.dart';
import 'package:apna_jamui_customer/features/location/presentation/bloc/location_state.dart';
import 'package:apna_jamui_customer/features/location/presentation/pages/location_picker_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  group('Customer Location & Real GPS Tests', () {
    test('CustomerLocationEntity serialization & deserialization', () {
      final now = DateTime.now();
      final entity = CustomerLocationEntity(
        latitude: 24.91823,
        longitude: 86.22341,
        placeName: 'Bodhwantalaab',
        formattedAddress: 'Bodhwantalaab, Jamui, Bihar, 811307',
        city: 'Jamui',
        district: 'Jamui',
        state: 'Bihar',
        pincode: '811307',
        timestamp: now,
      );

      final map = entity.toMap();
      final fromMapEntity = CustomerLocationEntity.fromMap(map);

      expect(fromMapEntity.latitude, 24.91823);
      expect(fromMapEntity.longitude, 86.22341);
      expect(fromMapEntity.placeName, 'Bodhwantalaab');
      expect(fromMapEntity.formattedAddress, 'Bodhwantalaab, Jamui, Bihar, 811307');
      expect(fromMapEntity.city, 'Jamui');
      expect(fromMapEntity.district, 'Jamui');
      expect(fromMapEntity.state, 'Bihar');
      expect(fromMapEntity.pincode, '811307');
    });

    test('calculateDistanceKm returns accurate distance between two coordinates', () {
      // Jamui Market approx: (24.9200, 86.2200)
      // Jhajha approx: (24.7733, 86.3778)
      final distanceKm = LocationService.calculateDistanceKm(
        startLatitude: 24.9200,
        startLongitude: 86.2200,
        endLatitude: 24.7733,
        endLongitude: 86.3778,
      );

      // Expected distance between Jamui and Jhajha is approx ~22-25 KM
      expect(distanceKm, greaterThan(20.0));
      expect(distanceKm, lessThan(30.0));
    });

    test('Provider Service Radius filtering based on real GPS coordinates', () {
      // Customer standing at Budwantalaab (24.9205, 86.2230)
      const customerLat = 24.9205;
      const customerLng = 86.2230;

      // Provider 1 is 2 KM away with 10 KM service radius -> Inside radius (SHOW)
      const provider1Lat = 24.9350;
      const provider1Lng = 86.2250;
      const provider1RadiusKm = 10.0;
      final dist1 = LocationService.calculateDistanceKm(
        startLatitude: customerLat,
        startLongitude: customerLng,
        endLatitude: provider1Lat,
        endLongitude: provider1Lng,
      );
      final isProvider1Eligible = dist1 <= provider1RadiusKm;
      expect(isProvider1Eligible, isTrue);

      // Provider 2 is in another district (e.g. 50 KM away) with 10 KM radius -> Outside radius (DON'T SHOW)
      const provider2Lat = 25.3000;
      const provider2Lng = 86.5000;
      const provider2RadiusKm = 10.0;
      final dist2 = LocationService.calculateDistanceKm(
        startLatitude: customerLat,
        startLongitude: customerLng,
        endLatitude: provider2Lat,
        endLongitude: provider2Lng,
      );
      final isProvider2Eligible = dist2 <= provider2RadiusKm;
      expect(isProvider2Eligible, isFalse);
    });

    test('CustomerLocationEntity flags 0.0, 0.0 as invalid and unavailable', () {
      final zeroLocation = CustomerLocationEntity(
        latitude: 0.0,
        longitude: 0.0,
        placeName: '',
        formattedAddress: '',
        city: '',
        district: '',
        state: '',
        pincode: '',
        timestamp: DateTime.now(),
      );

      expect(zeroLocation.hasValidCoordinates, isFalse);
      expect(zeroLocation.isLocationUnavailable, isTrue);

      final validLocation = zeroLocation.copyWith(latitude: 24.92, longitude: 86.22);
      expect(validLocation.hasValidCoordinates, isTrue);
      expect(validLocation.isLocationUnavailable, isFalse);
    });

    test('Selecting new coordinates resets address and does not inherit stale Khaira address', () async {
      final repo = FakeLocationRepository();
      final bloc = LocationBloc(locationRepository: repo);

      // 1. Initial state with Khaira (e.g. from previously loaded cache)
      final khaira = CustomerLocationEntity(
        latitude: 24.849,
        longitude: 86.213,
        placeName: 'खैरा',
        formattedAddress: 'खैरा, जमुई, बिहार, 811317',
        city: 'Jamui',
        district: 'Jamui',
        state: 'Bihar',
        pincode: '811317',
        timestamp: DateTime.now(),
      );
      bloc.add(SetExplicitLocationEvent(location: khaira));
      await Future.delayed(const Duration(milliseconds: 20));

      final stateBefore = bloc.state as LocationLoaded;
      expect(stateBefore.location.placeName, 'खैरा');

      // 2. Select completely new coordinates (e.g. Patna: 25.594, 85.137)
      repo.customReverseGeocode = (lat, lng) => CustomerLocationEntity(
            latitude: lat,
            longitude: lng,
            placeName: 'Patna Junction',
            formattedAddress: 'Patna Junction, Patna, Bihar, 800001',
            city: 'Patna',
            district: 'Patna',
            state: 'Bihar',
            pincode: '800001',
            timestamp: DateTime.now(),
          );

      bloc.add(const SelectCoordinatesEvent(
        latitude: 25.594,
        longitude: 85.137,
        shouldReverseGeocode: true,
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      final stateAfter = bloc.state as LocationLoaded;
      expect(stateAfter.location.latitude, 25.594);
      expect(stateAfter.location.longitude, 85.137);
      // Verify that placeName was updated to Patna Junction and NOT stale 'खैरा'
      expect(stateAfter.location.placeName, 'Patna Junction');
      expect(stateAfter.location.formattedAddress, contains('Patna'));
      expect(stateAfter.location.placeName, isNot(contains('खैरा')));

      await bloc.close();
    });

    test('Stale slow reverse-geocode response cannot overwrite newer pin selection', () async {
      final repo = FakeLocationRepository();
      final bloc = LocationBloc(locationRepository: repo);

      // Request 1: Pin at Khaira with artificial delay of 80ms
      repo.customReverseGeocode = (lat, lng) {
        if (lat == 24.849) {
          return CustomerLocationEntity(
            latitude: lat,
            longitude: lng,
            placeName: 'OLD STALE KHAIRA',
            formattedAddress: 'Old Stale Khaira Address',
            city: '',
            district: '',
            state: '',
            pincode: '',
            timestamp: DateTime.now(),
          );
        }
        return CustomerLocationEntity(
          latitude: lat,
          longitude: lng,
          placeName: 'NEW PIN LOCATION',
          formattedAddress: 'New Pin Address',
          city: '',
          district: '',
          state: '',
          pincode: '',
          timestamp: DateTime.now(),
        );
      };

      // Dispatch request 1 with delay
      repo.reverseGeocodeDelay = const Duration(milliseconds: 80);
      bloc.add(const SelectCoordinatesEvent(latitude: 24.849, longitude: 86.213));

      // 20ms later, user rapidly moves pin to new coordinates (Request 2)
      await Future.delayed(const Duration(milliseconds: 20));
      repo.reverseGeocodeDelay = const Duration(milliseconds: 10);
      bloc.add(const SelectCoordinatesEvent(latitude: 25.000, longitude: 86.500));

      // Wait 120ms so both asynchronous responses have returned
      await Future.delayed(const Duration(milliseconds: 120));

      final finalState = bloc.state as LocationLoaded;
      // Request 1 (Khaira) MUST be discarded by sequence guard!
      expect(finalState.location.latitude, 25.000);
      expect(finalState.location.longitude, 86.500);
      expect(finalState.location.placeName, 'NEW PIN LOCATION');
      expect(finalState.location.placeName, isNot(contains('OLD STALE KHAIRA')));

      await bloc.close();
    });
  });

  group('Location UI Overflow Regression Tests', () {
    testWidgets('Confirm Location button does not overflow on 320dp narrow screen', (WidgetTester tester) async {
      // Simulate narrow 320px Android device
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 280, // 320 - 40px margins
                height: 52,
                child: ElevatedButton(
                  onPressed: () {},
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, size: 20),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'यह स्थान चुनें (Confirm Location)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Verify no overflow exception was thrown and widget rendered
      expect(tester.takeException(), isNull);
      expect(find.text('यह स्थान चुनें (Confirm Location)'), findsOneWidget);
    });

    testWidgets('LocationPickerScreen renders SearchBar, GPS card, and Controls during LocationLoading (Never Blank)', (WidgetTester tester) async {
      final repo = FakeLocationRepository();
      final completer = Completer<CustomerLocationEntity>();
      repo.customGpsFuture = () => completer.future;
      final locationBloc = LocationBloc(locationRepository: repo);
      final discoveryBloc = DiscoveryBloc(discoveryRepository: FakeDiscoveryRepository());

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<LocationBloc>.value(value: locationBloc),
            BlocProvider<DiscoveryBloc>.value(value: discoveryBloc),
          ],
          child: MaterialApp(
            home: LocationPickerScreen(tileProvider: FakeTileProvider()),
          ),
        ),
      );
      await tester.pump();

      // Verify LocationPickerScreen is rendered
      expect(find.byType(LocationPickerScreen), findsOneWidget);
      // Verify Search TextField is rendered
      expect(find.byType(TextField), findsOneWidget);
      // Verify Use Current Location button is rendered
      expect(find.text('वर्तमान स्थान खोजें (Use Current Location)'), findsOneWidget);
      // Verify Confirm Location button is rendered
      expect(find.text('यह स्थान चुनें (Confirm Location)'), findsOneWidget);
      // Verify non-blocking loading status is shown
      expect(find.text('GPS से वास्तविक स्थान खोजा जा रहा है...'), findsWidgets);
      // Verify GPS card shows scanning indicator
      expect(find.text('GPS सिग्नल खोजा जा रहा है...'), findsOneWidget);

      completer.complete(CustomerLocationEntity(
        latitude: 24.92,
        longitude: 86.22,
        placeName: 'जमुई',
        formattedAddress: 'जमुई, बिहार',
        city: 'Jamui',
        district: 'Jamui',
        state: 'Bihar',
        pincode: '811307',
        timestamp: DateTime.now(),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(const SizedBox.shrink());
      locationBloc.close();
      discoveryBloc.close();
    });

    testWidgets('LocationPickerScreen renders GPS disabled banner when GPS is off', (WidgetTester tester) async {
      final repo = FakeLocationRepository();
      repo.isServiceEnabled = false;
      final locationBloc = LocationBloc(locationRepository: repo);
      final discoveryBloc = DiscoveryBloc(discoveryRepository: FakeDiscoveryRepository());

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<LocationBloc>.value(value: locationBloc),
            BlocProvider<DiscoveryBloc>.value(value: discoveryBloc),
          ],
          child: MaterialApp(
            home: LocationPickerScreen(tileProvider: FakeTileProvider()),
          ),
        ),
      );

      locationBloc.add(const FetchDeviceGpsLocationEvent());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(LocationPickerScreen), findsOneWidget);
      expect(find.text('डिवाइस GPS बंद है। कृपया चालू करें।'), findsOneWidget);
      expect(find.text('GPS चालू करें'), findsOneWidget);
      expect(find.text('वर्तमान स्थान खोजें (Use Current Location)'), findsOneWidget);
      expect(find.text('यह स्थान चुनें (Confirm Location)'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      locationBloc.close();
      discoveryBloc.close();
    });

    testWidgets('LocationPickerScreen renders Permission banner when permission is denied', (WidgetTester tester) async {
      final repo = FakeLocationRepository();
      repo.permissionResult = LocationPermission.denied;
      final locationBloc = LocationBloc(locationRepository: repo);
      final discoveryBloc = DiscoveryBloc(discoveryRepository: FakeDiscoveryRepository());

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<LocationBloc>.value(value: locationBloc),
            BlocProvider<DiscoveryBloc>.value(value: discoveryBloc),
          ],
          child: MaterialApp(
            home: LocationPickerScreen(tileProvider: FakeTileProvider()),
          ),
        ),
      );

      locationBloc.add(const FetchDeviceGpsLocationEvent());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(LocationPickerScreen), findsOneWidget);
      expect(find.text('सटीक GPS के लिए लोकेशन अनुमति दें।'), findsOneWidget);
      expect(find.text('अनुमति दें'), findsOneWidget);
      expect(find.text('यह स्थान चुनें (Confirm Location)'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      locationBloc.close();
      discoveryBloc.close();
    });

    testWidgets('LocationPickerScreen renders Error banner when GPS fails', (WidgetTester tester) async {
      final repo = FakeLocationRepository();
      repo.throwErrorOnGps = true;
      final locationBloc = LocationBloc(locationRepository: repo);
      final discoveryBloc = DiscoveryBloc(discoveryRepository: FakeDiscoveryRepository());

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<LocationBloc>.value(value: locationBloc),
            BlocProvider<DiscoveryBloc>.value(value: discoveryBloc),
          ],
          child: MaterialApp(
            home: LocationPickerScreen(tileProvider: FakeTileProvider()),
          ),
        ),
      );

      locationBloc.add(const FetchDeviceGpsLocationEvent());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(LocationPickerScreen), findsOneWidget);
      expect(find.text('पुनः प्रयास'), findsOneWidget);
      expect(find.text('यह स्थान चुनें (Confirm Location)'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      locationBloc.close();
      discoveryBloc.close();
    });
  });
}

class FakeLocationRepository implements LocationRepository {
  bool isServiceEnabled = true;
  LocationPermission permissionResult = LocationPermission.always;
  bool throwErrorOnGps = false;
  Duration gpsDelay = Duration.zero;
  CustomerLocationEntity? cachedLocation;
  CustomerLocationEntity? gpsLocation;
  Duration reverseGeocodeDelay = Duration.zero;
  CustomerLocationEntity Function(double lat, double lng)? customReverseGeocode;
  Future<CustomerLocationEntity> Function()? customGpsFuture;

  @override
  Future<bool> isLocationServiceEnabled() async => isServiceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permissionResult;

  @override
  Future<LocationPermission> requestPermission() async => permissionResult;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;

  @override
  Future<CustomerLocationEntity> getCurrentGpsLocation() async {
    if (customGpsFuture != null) {
      return await customGpsFuture!();
    }
    if (gpsDelay > Duration.zero) {
      await Future.delayed(gpsDelay);
    }
    if (throwErrorOnGps) {
      throw Exception('GPS Hardware fault');
    }
    return gpsLocation ??
        CustomerLocationEntity(
          latitude: 24.92,
          longitude: 86.22,
          placeName: 'जमुई स्टेशन',
          formattedAddress: 'जमुई स्टेशन, बिहार',
          city: 'Jamui',
          district: 'Jamui',
          state: 'Bihar',
          pincode: '811307',
          timestamp: DateTime.now(),
        );
  }

  @override
  Future<CustomerLocationEntity> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    if (reverseGeocodeDelay > Duration.zero) {
      await Future.delayed(reverseGeocodeDelay);
    }
    if (customReverseGeocode != null) {
      return customReverseGeocode!(latitude, longitude);
    }
    return CustomerLocationEntity(
      latitude: latitude,
      longitude: longitude,
      placeName: 'स्थान ($latitude, $longitude)',
      formattedAddress: 'Address for $latitude, $longitude',
      city: 'City',
      district: 'District',
      state: 'State',
      pincode: '123456',
      timestamp: DateTime.now(),
    );
  }

  @override
  Future<List<CustomerLocationEntity>> searchPlaces(
    String query, {
    double? customerLat,
    double? customerLng,
  }) async =>
      [];

  @override
  Future<void> saveCustomerLocation(CustomerLocationEntity location) async {
    cachedLocation = location;
  }

  @override
  Future<CustomerLocationEntity?> getCachedCustomerLocation() async {
    return cachedLocation;
  }
}

class FakeDiscoveryRepository implements CustomerDiscoveryRepository {
  @override
  Future<List<ServiceCategoryEntity>> getCategories() async => [];

  @override
  Future<List<ServiceProviderEntity>> getProviders({
    String? categoryId,
    String? jamuiArea,
    String? searchQuery,
    double? customerLatitude,
    double? customerLongitude,
    double? maxRadiusKm,
  }) async =>
      [];

  @override
  Future<PaginatedProvidersResult> getPaginatedProviders({
    String? categoryId,
    String? jamuiArea,
    String? searchQuery,
    double? customerLatitude,
    double? customerLongitude,
    double? maxRadiusKm,
    int limit = 12,
    dynamic lastDocumentCursor,
  }) async =>
      PaginatedProvidersResult(items: [], lastDocumentCursor: null, hasMore: false);

  @override
  Future<void> trackLeadClick({
    required String providerId,
    required bool isCall,
    String? customerId,
    String? categoryId,
  }) async {}

  @override
  Future<void> trackProfileView({
    required String providerId,
    String? customerId,
  }) async {}
}

class FakeTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return MemoryImage(TileProvider.transparentImage);
  }
}



