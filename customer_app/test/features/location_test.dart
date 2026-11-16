import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:apna_jamui_customer/core/services/location_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:apna_jamui_customer/features/discovery/domain/entities/paginated_providers_entity.dart';
import 'package:apna_jamui_customer/features/discovery/domain/entities/service_category_entity.dart';
import 'package:apna_jamui_customer/features/discovery/domain/entities/service_provider_entity.dart';
import 'package:apna_jamui_customer/features/discovery/domain/repositories/customer_discovery_repository.dart';
import 'package:apna_jamui_customer/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:apna_jamui_customer/features/location/data/datasources/location_local_data_source.dart';
import 'package:apna_jamui_customer/features/location/data/datasources/location_remote_data_source.dart';
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
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final hindiRegExp = RegExp(r'[\u0900-\u097F]');

  void expectNoHindiTextInTree(WidgetTester tester) {
    final textWidgets = tester.widgetList<Text>(find.byType(Text));
    for (final textWidget in textWidgets) {
      final value = textWidget.data ?? textWidget.textSpan?.toPlainText() ?? '';
      expect(
        hindiRegExp.hasMatch(value),
        isFalse,
        reason: 'Found unexpected Hindi text in LocationPickerScreen: "$value"',
      );
    }
  }

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

      // 1. Initial state with Khaira
      final khaira = CustomerLocationEntity(
        latitude: 24.849,
        longitude: 86.213,
        placeName: 'Khaira',
        formattedAddress: 'Khaira, Jamui, Bihar, 811317',
        city: 'Jamui',
        district: 'Jamui',
        state: 'Bihar',
        pincode: '811317',
        timestamp: DateTime.now(),
      );
      bloc.add(SetExplicitLocationEvent(location: khaira));
      await Future.delayed(const Duration(milliseconds: 20));

      final stateBefore = bloc.state as LocationLoaded;
      expect(stateBefore.location.placeName, 'Khaira');

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
      expect(stateAfter.location.placeName, 'Patna Junction');
      expect(stateAfter.location.formattedAddress, contains('Patna'));
      expect(stateAfter.location.placeName, isNot(contains('Khaira')));

      await bloc.close();
    });

    test('Stale slow reverse-geocode response cannot overwrite newer pin selection', () async {
      final repo = FakeLocationRepository();
      final bloc = LocationBloc(locationRepository: repo);

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

      repo.reverseGeocodeDelay = const Duration(milliseconds: 80);
      bloc.add(const SelectCoordinatesEvent(latitude: 24.849, longitude: 86.213));

      await Future.delayed(const Duration(milliseconds: 20));
      repo.reverseGeocodeDelay = const Duration(milliseconds: 10);
      bloc.add(const SelectCoordinatesEvent(latitude: 25.000, longitude: 86.500));

      await Future.delayed(const Duration(milliseconds: 120));

      final finalState = bloc.state as LocationLoaded;
      expect(finalState.location.latitude, 25.000);
      expect(finalState.location.longitude, 86.500);
      expect(finalState.location.placeName, 'NEW PIN LOCATION');
      expect(finalState.location.placeName, isNot(contains('OLD STALE KHAIRA')));

      await bloc.close();
    });

    test('SearchPlacesEvent works even while LocationBloc is in LocationLoading or LocationPermissionDeniedState', () async {
      final repo = FakeLocationRepository();
      final gpsCompleter = Completer<CustomerLocationEntity>();
      repo.customGpsFuture = () => gpsCompleter.future;
      repo.customSearch = (query) async => [
            CustomerLocationEntity(
              latitude: 24.8490,
              longitude: 86.2130,
              placeName: 'Khaira',
              formattedAddress: 'Khaira, Jamui, Bihar, 811317',
              village: 'Khaira',
              block: 'Khaira',
              city: 'Khaira',
              district: 'Jamui',
              state: 'Bihar',
              pincode: '811317',
              timestamp: DateTime.now(),
            ),
          ];

      final bloc = LocationBloc(locationRepository: repo);

      // Start slow GPS acquisition -> puts bloc into LocationLoading
      bloc.add(const FetchDeviceGpsLocationEvent());
      await Future.delayed(const Duration(milliseconds: 20));
      expect(bloc.state, isA<LocationLoading>());

      // User searches while GPS is still loading -> must NOT be ignored!
      bloc.add(const SearchPlacesEvent('Khaira'));
      await Future.delayed(const Duration(milliseconds: 40));

      expect(bloc.state, isA<LocationLoaded>());
      final loaded = bloc.state as LocationLoaded;
      expect(loaded.searchResults.length, equals(1));
      expect(loaded.searchResults.first.placeName, equals('Khaira'));
      expect(loaded.hasSearched, isTrue);

      await bloc.close();
    });
  });

  group('Location UI & English-Only Verification Tests', () {
    testWidgets('Confirm Location button does not overflow on 320dp narrow screen', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 280,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {},
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline_rounded, size: 20),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Confirm Location',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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

      expect(tester.takeException(), isNull);
      expect(find.text('Confirm Location'), findsOneWidget);
    });

    testWidgets('LocationPickerScreen renders English-only SearchBar, GPS card, and Controls during LocationLoading', (WidgetTester tester) async {
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

      expect(find.byType(LocationPickerScreen), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Select Location'), findsWidgets);
      expect(find.text('Accurate location for better service'), findsOneWidget);
      expect(find.text('Tap or drag the pin to select your location'), findsWidgets);
      expect(find.text('Use Current Location'), findsOneWidget);
      expect(find.text('Confirm Location'), findsOneWidget);
      expect(find.text('Detecting your current location...'), findsWidgets);
      expectNoHindiTextInTree(tester);

      completer.complete(CustomerLocationEntity(
        latitude: 24.92,
        longitude: 86.22,
        placeName: 'Jamui Bazaar',
        formattedAddress: 'Jamui Bazaar, Jamui, Bihar, 811307',
        village: 'Jamui Bazaar',
        suburb: 'Station Road',
        block: 'Jamui',
        city: 'Jamui',
        district: 'Jamui',
        state: 'Bihar',
        pincode: '811307',
        accuracy: 6.4,
        timestamp: DateTime.now(),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Jamui Bazaar'), findsOneWidget);
      expect(find.text('Accuracy: ±6.4m'), findsOneWidget);
      expect(find.text('Village / Locality: Jamui Bazaar'), findsOneWidget);
      expect(find.text('Suburb: Station Road'), findsOneWidget);
      expect(find.text('Block: Jamui'), findsOneWidget);
      expect(find.text('District: Jamui'), findsOneWidget);
      expect(find.text('State: Bihar'), findsOneWidget);
      expect(find.text('PIN Code: 811307'), findsOneWidget);
      expect(find.text('Latitude'), findsOneWidget);
      expect(find.text('Longitude'), findsOneWidget);
      expectNoHindiTextInTree(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      locationBloc.close();
      discoveryBloc.close();
    });

    testWidgets('LocationPickerScreen renders English GPS disabled banner when GPS is off', (WidgetTester tester) async {
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
      expect(find.text('Enable GPS to detect your location'), findsOneWidget);
      expect(find.text('Enable GPS'), findsOneWidget);
      expect(find.text('Use Current Location'), findsOneWidget);
      expect(find.text('Confirm Location'), findsOneWidget);
      expectNoHindiTextInTree(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      locationBloc.close();
      discoveryBloc.close();
    });

    testWidgets('LocationPickerScreen renders English Permission banner when permission is denied', (WidgetTester tester) async {
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
      expect(find.text('Location permission denied'), findsOneWidget);
      expect(find.text('Allow'), findsOneWidget);
      expect(find.text('Confirm Location'), findsOneWidget);
      expectNoHindiTextInTree(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      locationBloc.close();
      discoveryBloc.close();
    });

    testWidgets('LocationPickerScreen renders English Error banner when GPS fails', (WidgetTester tester) async {
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
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Confirm Location'), findsOneWidget);
      expectNoHindiTextInTree(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      locationBloc.close();
      discoveryBloc.close();
    });

    testWidgets('LocationPickerScreen debounces search input (450ms), shows suggestions, and selects suggestion', (WidgetTester tester) async {
      final repo = FakeLocationRepository();
      int searchCallCount = 0;
      repo.customSearch = (query) async {
        searchCallCount++;
        return [
          CustomerLocationEntity(
            latitude: 24.8490,
            longitude: 86.2130,
            placeName: 'Khaira Bazaar',
            formattedAddress: 'Khaira Bazaar, Khaira, Jamui, Bihar, 811317',
            village: 'Khaira',
            block: 'Khaira',
            city: 'Khaira',
            district: 'Jamui',
            state: 'Bihar',
            pincode: '811317',
            timestamp: DateTime.now(),
          ),
        ];
      };
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
      await tester.pump(const Duration(milliseconds: 50));

      // Rapid keystrokes within debounce window -> should only trigger 1 search call
      await tester.enterText(find.byType(TextField), 'Kha');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.enterText(find.byType(TextField), 'Khaira');
      await tester.pump(const Duration(milliseconds: 200));
      expect(searchCallCount, equals(0), reason: 'Must not search before 450ms debounce');

      await tester.pump(const Duration(milliseconds: 300));
      expect(searchCallCount, equals(1), reason: 'Debounced search must fire once after 450ms');
      expect(find.text('Khaira Bazaar'), findsOneWidget);

      // Select suggestion
      await tester.tap(find.text('Khaira Bazaar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final loadedState = locationBloc.state as LocationLoaded;
      expect(loadedState.location.placeName, equals('Khaira Bazaar'));
      expect(loadedState.location.village, equals('Khaira'));
      expect(loadedState.location.block, equals('Khaira'));
      expectNoHindiTextInTree(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      locationBloc.close();
      discoveryBloc.close();
    });

    testWidgets('LocationPickerScreen shows "No locations found" when Photon returns 0 results', (WidgetTester tester) async {
      final repo = FakeLocationRepository();
      repo.customSearch = (query) async => [];
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
      await tester.pump(const Duration(milliseconds: 50));

      await tester.enterText(find.byType(TextField), 'ZzUnknownPlace999');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.text('No locations found'), findsOneWidget);
      expectNoHindiTextInTree(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      locationBloc.close();
      discoveryBloc.close();
    });

    testWidgets('LocationPickerScreen shows retry message on Photon network failure and recovers on retry tap', (WidgetTester tester) async {
      final repo = FakeLocationRepository();
      bool shouldFail = true;
      repo.customSearch = (query) async {
        if (shouldFail) {
          throw Exception('Network timeout');
        }
        return [
          CustomerLocationEntity(
            latitude: 24.7733,
            longitude: 86.3778,
            placeName: 'Jhajha',
            formattedAddress: 'Jhajha, Jamui, Bihar, 811308',
            city: 'Jhajha',
            block: 'Jhajha',
            district: 'Jamui',
            state: 'Bihar',
            pincode: '811308',
            timestamp: DateTime.now(),
          ),
        ];
      };
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
      await tester.pump(const Duration(milliseconds: 50));

      await tester.enterText(find.byType(TextField), 'Jhajha');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.text('Unable to search locations. Tap to retry.'), findsOneWidget);
      expectNoHindiTextInTree(tester);

      // Now recover network and tap retry
      shouldFail = false;
      await tester.tap(find.text('Unable to search locations. Tap to retry.'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Jhajha'), findsWidgets);
      expectNoHindiTextInTree(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      locationBloc.close();
      discoveryBloc.close();
    });

    testWidgets('LocationPickerScreen shows "Unable to load map. Tap to retry." when tiles fail and recovers on retry tap', (WidgetTester tester) async {
      final repo = FakeLocationRepository();
      final locationBloc = LocationBloc(locationRepository: repo);
      final discoveryBloc = DiscoveryBloc(discoveryRepository: FakeDiscoveryRepository());
      final failingTileProvider = ToggleableFailingTileProvider(shouldFail: true);

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<LocationBloc>.value(value: locationBloc),
            BlocProvider<DiscoveryBloc>.value(value: discoveryBloc),
          ],
          child: MaterialApp(
            home: LocationPickerScreen(tileProvider: failingTileProvider),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Unable to load map. Tap to retry.'), findsOneWidget);
      expectNoHindiTextInTree(tester);

      // Recover tile provider and tap retry
      failingTileProvider.shouldFail = false;
      await tester.tap(find.text('Unable to load map. Tap to retry.'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Unable to load map. Tap to retry.'), findsNothing);
      expectNoHindiTextInTree(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      locationBloc.close();
      discoveryBloc.close();
    });

    testWidgets('Render and capture real OpenStreetMap + English LocationPickerScreen screenshots', (WidgetTester tester) async {
      await tester.runAsync(() async {
        // Locate artifacts/material_fonts in Flutter SDK cache
        final exeFile = File(Platform.resolvedExecutable);
        Directory? currentDir = exeFile.parent;
        Directory? materialFontsDir;
        for (int i = 0; i < 6 && currentDir != null; i++) {
          final candidate1 = Directory('${currentDir.path}/material_fonts');
          final candidate2 = Directory('${currentDir.path}/artifacts/material_fonts');
          if (candidate1.existsSync()) {
            materialFontsDir = candidate1;
            break;
          }
          if (candidate2.existsSync()) {
            materialFontsDir = candidate2;
            break;
          }
          currentDir = currentDir.parent;
        }

        Future<void> loadFontIfPresent(String family, List<String> paths) async {
          final loader = FontLoader(family);
          bool added = false;
          for (final p in paths) {
            final f = File(p);
            if (f.existsSync()) {
              final bytes = f.readAsBytesSync();
              loader.addFont(Future.value(ByteData.view(bytes.buffer)));
              added = true;
            }
          }
          if (added) {
            await loader.load();
          }
        }

        final mfPath = materialFontsDir?.path ?? '';
        await loadFontIfPresent('Roboto', [
          if (mfPath.isNotEmpty) '$mfPath/roboto-regular.ttf',
          if (mfPath.isNotEmpty) '$mfPath/roboto-medium.ttf',
          if (mfPath.isNotEmpty) '$mfPath/roboto-bold.ttf',
          'C:/Windows/Fonts/segoeui.ttf',
          'C:/Windows/Fonts/segoeuib.ttf',
        ]);
        await loadFontIfPresent('MaterialIcons', [
          if (mfPath.isNotEmpty) '$mfPath/MaterialIcons-Regular.otf',
        ]);

        // Fetch and decode real OpenStreetMap tiles for Jamui (24.9213, 86.2238 at zoom 14 and zoom 16)
        final decodedTiles = <String, ui.Image>{};
        ui.Image? fallbackTile;
        await HttpOverrides.runWithHttpOverrides(() async {
          final client = http.Client();
          try {
            // Jamui (24.9213, 86.2238) at z=14 (for zoom 14.3): center is (12116, 7020)
            final tileSpecs = <(int, int, int)>[
              for (final dx in [-1, 0, 1])
                for (final dy in [-2, -1, 0, 1, 2]) (14, 12116 + dx, 7020 + dy),
            ];
            for (final (z, x, y) in tileSpecs) {
              final res = await client.get(
                Uri.parse('https://tile.openstreetmap.org/$z/$x/$y.png'),
                headers: {
                  'User-Agent':
                      'JamuiServicesCustomerApp/1.2.7 (https://jamui-services.web.app; contact: support@apnajamui.in)',
                  'Accept': 'image/png,image/*;q=0.8,*/*;q=0.5',
                },
              );
              if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
                final codec = await ui.instantiateImageCodec(res.bodyBytes);
                final frame = await codec.getNextFrame();
                decodedTiles['$z/$x/$y'] = frame.image;
                if (z == 14 && x == 12116 && y == 7020) {
                  fallbackTile = frame.image;
                }
              }
            }
          } finally {
            client.close();
          }
        }, _RealHttpOverrides());

        final preloadedTileProvider = PreloadedRealOsmTileProvider(
          decodedTiles: decodedTiles,
          fallbackTile: fallbackTile!,
        );

        final repo = FakeLocationRepository();
        repo.gpsLocation = CustomerLocationEntity(
          latitude: 24.921300,
          longitude: 86.223800,
          placeName: 'Maharajganj Market, Jamui',
          formattedAddress: 'Maharajganj Market, Station Road, Jamui, Bihar, 811307',
          village: 'Maharajganj',
          locality: 'Station Road',
          suburb: 'Kachahari Chowk',
          block: 'Jamui',
          city: 'Jamui',
          district: 'Jamui',
          state: 'Bihar',
          pincode: '811307',
          accuracy: 4.8,
          timestamp: DateTime.now(),
        );
        repo.customSearch = (query) async => [
              CustomerLocationEntity(
                latitude: 24.808026,
                longitude: 86.155774,
                placeName: 'Khaira',
                formattedAddress: 'Khaira, Khaira Block, Jamui, Bihar, 811317',
                village: 'Khaira',
                block: 'Khaira',
                city: 'Khaira',
                district: 'Jamui',
                state: 'Bihar',
                pincode: '811317',
                timestamp: DateTime.now(),
              ),
              CustomerLocationEntity(
                latitude: 24.772858,
                longitude: 86.386300,
                placeName: 'Jhajha',
                formattedAddress: 'Jhajha, Jhajha Block, Jamui, Bihar, 811308',
                city: 'Jhajha',
                block: 'Jhajha',
                district: 'Jamui',
                state: 'Bihar',
                pincode: '811308',
                timestamp: DateTime.now(),
              ),
            ];

        final locationBloc = LocationBloc(locationRepository: repo);
        final discoveryBloc = DiscoveryBloc(discoveryRepository: FakeDiscoveryRepository());
        final boundaryKey = GlobalKey();

        tester.view.physicalSize = const Size(412 * 2, 915 * 2);
        tester.view.devicePixelRatio = 2.0;

        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: MultiBlocProvider(
              providers: [
                BlocProvider<LocationBloc>.value(value: locationBloc),
                BlocProvider<DiscoveryBloc>.value(value: discoveryBloc),
              ],
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: ThemeData(fontFamily: 'Roboto', useMaterial3: true),
                home: LocationPickerScreen(tileProvider: preloadedTileProvider),
              ),
            ),
          ),
        );

        await Future.delayed(const Duration(milliseconds: 200));
        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 200));
        await tester.pump();

        // Capture Screenshot 1: Corrected Location Picker with Real OSM Map & English UI
        final boundary = boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image1 = await boundary.toImage(pixelRatio: 2.0);
        final byteData1 = await image1.toByteData(format: ui.ImageByteFormat.png);
        if (byteData1 != null) {
          final out1 = File(
            'C:/Users/sagar/.gemini/antigravity/brain/1fe85145-e090-4658-a008-9de313aa5d5a/screenshot_location_picker_fixed.png',
          );
          await out1.writeAsBytes(byteData1.buffer.asUint8List());
          debugPrint('SAVED_SCREENSHOT_1: ${out1.path} (${byteData1.lengthInBytes} bytes)');
        }

        // Trigger Photon search for "Khaira" and capture Screenshot 2 showing live suggestions
        await tester.enterText(find.byType(TextField), 'Khaira');
        locationBloc.add(const SearchPlacesEvent('Khaira', customerLat: 24.9213, customerLng: 86.2238));
        await Future.delayed(const Duration(milliseconds: 200));
        await tester.pump();

        final image2 = await boundary.toImage(pixelRatio: 2.0);
        final byteData2 = await image2.toByteData(format: ui.ImageByteFormat.png);
        if (byteData2 != null) {
          final out2 = File(
            'C:/Users/sagar/.gemini/antigravity/brain/1fe85145-e090-4658-a008-9de313aa5d5a/screenshot_location_picker_photon_search.png',
          );
          await out2.writeAsBytes(byteData2.buffer.asUint8List());
          debugPrint('SAVED_SCREENSHOT_2: ${out2.path} (${byteData2.lengthInBytes} bytes)');
        }

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        await tester.pumpWidget(const SizedBox.shrink());
        await locationBloc.close();
        await discoveryBloc.close();
      });
    });
  });

  group('Photon Search, Nominatim Reverse Geocoding & Persistence Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      LocationRemoteDataSourceImpl.clearCachesForTesting();
    });

    test('Photon search extracts village, block, district, state, pincode, biases to Jamui when customerLat is 0.0, and NEVER calls Nominatim search', () async {
      final requestedUris = <Uri>[];
      final mockClient = MockClient((request) async {
        requestedUris.add(request.url);
        if (request.url.host == 'photon.komoot.io' && request.url.path == '/api/') {
          return http.Response(
            jsonEncode({
              'type': 'FeatureCollection',
              'features': [
                {
                  'type': 'Feature',
                  'geometry': {
                    'type': 'Point',
                    'coordinates': [86.2130, 24.8490],
                  },
                  'properties': {
                    'name': 'Khaira',
                    'osm_value': 'village',
                    'county': 'Khaira',
                    'district': 'Jamui',
                    'state': 'Bihar',
                    'postcode': '811317',
                    'country': 'India',
                    'countrycode': 'IN',
                  },
                },
                {
                  'type': 'Feature',
                  'geometry': {
                    'type': 'Point',
                    'coordinates': [86.3778, 24.7733],
                  },
                  'properties': {
                    'name': 'Jhajha',
                    'osm_value': 'town',
                    'city': 'Jhajha',
                    'county': 'Jhajha',
                    'district': 'Jamui',
                    'state': 'Bihar',
                    'postcode': '811308',
                    'country': 'India',
                    'countrycode': 'IN',
                  },
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final ds = LocationRemoteDataSourceImpl(
        client: mockClient,
        enforceNominatimRateLimit: false,
      );

      // Even if 0.0, 0.0 is passed, it must NOT bias to 0.0, 0.0 (Atlantic Ocean)
      final results = await ds.searchPlaces('Khaira 811317', customerLat: 0.0, customerLng: 0.0);
      expect(results.length, equals(2));
      expect(requestedUris.first.queryParameters['lat'], equals('24.9213'));
      expect(requestedUris.first.queryParameters['lon'], equals('86.2238'));

      expect(results[0].placeName, equals('Khaira'));
      expect(results[0].village, equals('Khaira'));
      expect(results[0].block, equals('Khaira'));
      expect(results[0].district, equals('Jamui'));
      expect(results[0].state, equals('Bihar'));
      expect(results[0].pincode, equals('811317'));

      expect(results[1].placeName, equals('Jhajha'));
      expect(results[1].city, equals('Jhajha'));
      expect(results[1].block, equals('Jhajha'));
      expect(results[1].pincode, equals('811308'));

      // Verify Nominatim /search was NEVER called
      expect(requestedUris.any((u) => u.host.contains('nominatim')), isFalse);

      // Verify caching: second identical search makes 0 additional HTTP requests
      final beforeCount = requestedUris.length;
      final cachedResults = await ds.searchPlaces('khaira 811317');
      expect(cachedResults.length, equals(2));
      expect(requestedUris.length, equals(beforeCount));
    });

    test('Nominatim reverse geocoding extracts village, suburb, block, district, state, pincode accurately', () async {
      final mockClient = MockClient((request) async {
        if (request.url.host == 'nominatim.openstreetmap.org') {
          return http.Response(
            jsonEncode({
              'name': 'Maharajganj Market',
              'address': {
                'suburb': 'Maharajganj',
                'village': 'Bishunpur',
                'county': 'Jamui',
                'state_district': 'Jamui',
                'state': 'Bihar',
                'postcode': '811307',
                'country': 'India',
              },
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(jsonEncode({'features': []}), 200);
      });

      final ds = LocationRemoteDataSourceImpl(
        client: mockClient,
        enforceNominatimRateLimit: false,
      );

      final loc = await ds.reverseGeocode(24.9213, 86.2238, accuracy: 8.5);
      expect(loc.placeName, equals('Maharajganj Market'));
      expect(loc.village, equals('Bishunpur'));
      expect(loc.suburb, equals('Maharajganj'));
      expect(loc.block, equals('Jamui'));
      expect(loc.district, equals('Jamui'));
      expect(loc.state, equals('Bihar'));
      expect(loc.pincode, equals('811307'));
      expect(loc.accuracy, equals(8.5));
    });

    test('Missing Block/Village fields are kept empty (never invented) and network failure falls back safely to coordinates', () async {
      final mockClient = MockClient((request) async {
        if (request.url.host == 'nominatim.openstreetmap.org') {
          return http.Response(
            jsonEncode({
              'name': '',
              'address': {
                'state': 'Bihar',
                'postcode': '811307',
              },
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(jsonEncode({'features': []}), 200);
      });

      final ds = LocationRemoteDataSourceImpl(
        client: mockClient,
        enforceNominatimRateLimit: false,
      );

      final loc = await ds.reverseGeocode(24.9500, 86.2600);
      expect(loc.village, isEmpty, reason: 'Must not invent missing village');
      expect(loc.block, isEmpty, reason: 'Must not invent missing block');
      expect(loc.district, isEmpty, reason: 'Must not invent missing district');
      expect(loc.state, equals('Bihar'));
      expect(loc.pincode, equals('811307'));
      expect(loc.hasValidCoordinates, isTrue);

      // Network failure resilience test
      LocationRemoteDataSourceImpl.clearCachesForTesting();
      final failingClient = MockClient((request) async {
        throw Exception('SocketException: Network unreachable');
      });
      final failingDs = LocationRemoteDataSourceImpl(
        client: failingClient,
        enforceNominatimRateLimit: false,
      );

      final fallbackLoc = await failingDs.reverseGeocode(24.9600, 86.2700);
      expect(fallbackLoc.hasValidCoordinates, isTrue);
      expect(fallbackLoc.latitude, equals(24.9600));
      expect(fallbackLoc.longitude, equals(86.2700));
      expect(fallbackLoc.placeName, equals('Location detected'));
      expect(fallbackLoc.village, isEmpty);
      expect(fallbackLoc.block, isEmpty);

      // Photon search failure surfaces exception so LocationBloc can show retry state
      await expectLater(failingDs.searchPlaces('Jamui'), throwsA(isA<Exception>()));
    });

    test('LocationLocalDataSourceImpl persists and restores full structured location including village, suburb, and block', () async {
      SharedPreferences.setMockInitialValues({'existing_profile_key': 'preserve_me'});
      final prefs = await SharedPreferences.getInstance();
      final localDs = LocationLocalDataSourceImpl(prefs: prefs);

      final entity = CustomerLocationEntity(
        latitude: 24.8490,
        longitude: 86.2130,
        placeName: 'Khaira',
        formattedAddress: 'Khaira, Jamui, Bihar, 811317',
        village: 'Khaira',
        locality: 'Main Road',
        suburb: 'Khaira Tola',
        block: 'Khaira',
        city: 'Khaira',
        district: 'Jamui',
        state: 'Bihar',
        pincode: '811317',
        timestamp: DateTime.now(),
      );

      await localDs.cacheLocation(entity);
      final restored = await localDs.getCachedLocation();

      expect(restored, isNotNull);
      expect(restored!.latitude, equals(24.8490));
      expect(restored.longitude, equals(86.2130));
      expect(restored.village, equals('Khaira'));
      expect(restored.suburb, equals('Khaira Tola'));
      expect(restored.block, equals('Khaira'));
      expect(restored.district, equals('Jamui'));
      expect(restored.state, equals('Bihar'));
      expect(restored.pincode, equals('811317'));
      expect(prefs.getString('existing_profile_key'), equals('preserve_me'));
    });

    test('LIVE API VERIFICATION: Real OpenStreetMap Tile, Real Photon Village/Town/PIN Search, and Real Nominatim Reverse Geocoding', () async {
      await HttpOverrides.runWithHttpOverrides(() async {
        LocationRemoteDataSourceImpl.clearCachesForTesting();
        final realClient = http.Client();
        try {
          // 1. Verify OpenStreetMap tile endpoint (Jamui: z=13, x=6058, y=3539)
          final tileUri = Uri.parse('https://tile.openstreetmap.org/13/6058/3539.png');
          final tileRes = await realClient.get(
            tileUri,
            headers: {
              'User-Agent':
                  'JamuiServicesCustomerApp/1.2.7 (https://jamui-services.web.app; contact: support@apnajamui.in)',
              'Accept': 'image/png,image/*;q=0.8,*/*;q=0.5',
            },
          ).timeout(const Duration(seconds: 10));

          debugPrint('LIVE_OSM_TILE: status=${tileRes.statusCode}, contentType=${tileRes.headers['content-type']}, bytes=${tileRes.bodyBytes.length}');
          expect(tileRes.statusCode, equals(200), reason: 'OpenStreetMap tile server must return HTTP 200');
          expect(tileRes.bodyBytes.length, greaterThan(100), reason: 'Tile PNG must be non-empty');
          // Verify PNG magic signature: 89 50 4E 47
          expect(tileRes.bodyBytes.sublist(0, 4), equals([0x89, 0x50, 0x4E, 0x47]));

          final liveDs = LocationRemoteDataSourceImpl(
            client: realClient,
            enforceNominatimRateLimit: true,
          );

          // 2. Verify live Photon search for known village: Khaira
          final villageResults = await liveDs.searchPlaces('Khaira');
          debugPrint('LIVE_PHOTON_VILLAGE (Khaira): count=${villageResults.length}, first=${villageResults.isNotEmpty ? "${villageResults.first.placeName} | ${villageResults.first.formattedAddress} (${villageResults.first.latitude}, ${villageResults.first.longitude})" : "NONE"}');
          expect(villageResults, isNotEmpty, reason: 'Photon search for village Khaira must return results');

          // 3. Verify live Photon search for known town: Jhajha
          final townResults = await liveDs.searchPlaces('Jhajha');
          debugPrint('LIVE_PHOTON_TOWN (Jhajha): count=${townResults.length}, first=${townResults.isNotEmpty ? "${townResults.first.placeName} | ${townResults.first.formattedAddress} (${townResults.first.latitude}, ${townResults.first.longitude})" : "NONE"}');
          expect(townResults, isNotEmpty, reason: 'Photon search for town Jhajha must return results');

          // 4. Verify live Photon search for PIN code: 811307
          final pinResults = await liveDs.searchPlaces('811307');
          debugPrint('LIVE_PHOTON_PIN (811307): count=${pinResults.length}, first=${pinResults.isNotEmpty ? "${pinResults.first.placeName} | ${pinResults.first.formattedAddress} (${pinResults.first.latitude}, ${pinResults.first.longitude})" : "NONE"}');
          expect(pinResults, isNotEmpty, reason: 'Photon search for PIN code 811307 must return results');

          // 5. Verify live Nominatim reverse geocoding for Jamui (24.9213, 86.2238)
          final revLoc = await liveDs.reverseGeocode(24.9213, 86.2238, accuracy: 5.0);
          debugPrint('LIVE_NOMINATIM_REVERSE (24.9213, 86.2238): place="${revLoc.placeName}", addr="${revLoc.formattedAddress}", block="${revLoc.block}", dist="${revLoc.district}", state="${revLoc.state}", pin="${revLoc.pincode}"');
          expect(revLoc.hasValidCoordinates, isTrue);
          expect(revLoc.formattedAddress, isNotEmpty);
        } finally {
          realClient.close();
        }
      }, _RealHttpOverrides());
    });
  });
}

class _RealHttpOverrides extends HttpOverrides {}

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
  Future<List<CustomerLocationEntity>> Function(String query)? customSearch;

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
          placeName: 'Jamui Station',
          formattedAddress: 'Jamui Station, Bihar',
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
      placeName: 'Location ($latitude, $longitude)',
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
  }) async {
    if (customSearch != null) {
      return await customSearch!(query);
    }
    return [];
  }

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
    String? customerVillage,
    String? customerBlock,
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
    String? customerVillage,
    String? customerBlock,
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

class PreloadedRealOsmTileProvider extends TileProvider {
  final Map<String, ui.Image> decodedTiles;
  final ui.Image fallbackTile;

  PreloadedRealOsmTileProvider({
    required this.decodedTiles,
    required this.fallbackTile,
  });

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final key = '${coordinates.z}/${coordinates.x}/${coordinates.y}';
    final image = decodedTiles[key] ?? fallbackTile;
    return _SynchronousUiImageProvider(image, key);
  }
}

@immutable
class _SynchronousUiImageProvider extends ImageProvider<_SynchronousUiImageProvider> {
  final ui.Image image;
  final String tileKey;

  const _SynchronousUiImageProvider(this.image, this.tileKey);

  @override
  Future<_SynchronousUiImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_SynchronousUiImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(_SynchronousUiImageProvider key, ImageDecoderCallback decode) {
    return OneFrameImageStreamCompleter(
      SynchronousFuture<ImageInfo>(ImageInfo(image: image, scale: 1.0)),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _SynchronousUiImageProvider && other.tileKey == tileKey);

  @override
  int get hashCode => tileKey.hashCode;
}

class ToggleableFailingTileProvider extends TileProvider {
  bool shouldFail;

  ToggleableFailingTileProvider({required this.shouldFail});

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    if (shouldFail) {
      return const _FailingImageProvider();
    }
    return MemoryImage(TileProvider.transparentImage);
  }
}

@immutable
class _FailingImageProvider extends ImageProvider<_FailingImageProvider> {
  const _FailingImageProvider();

  @override
  Future<_FailingImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_FailingImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(_FailingImageProvider key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: Future<ui.Codec>.error(Exception('Simulated tile network error')),
      scale: 1.0,
    );
  }
}
