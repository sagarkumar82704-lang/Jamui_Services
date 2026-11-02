import 'package:apna_jamui_provider/core/services/location_service.dart';
import 'package:apna_jamui_provider/features/location/domain/entities/provider_location_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Provider Location & Google Maps Consistency Tests', () {
    test('TEST 1: ProviderLocationEntity serialization & deserialization', () {
      final now = DateTime.now();
      final entity = ProviderLocationEntity(
        latitude: 24.91823,
        longitude: 86.22341,
        placeName: 'Bodhwantalaab',
        formattedAddress: 'Bodhwantalaab, Jamui, Bihar, 811307',
        village: 'Bodhwan',
        locality: 'Jamui Sadar',
        city: 'Jamui',
        district: 'Jamui',
        state: 'Bihar',
        pincode: '811307',
        accuracy: 4.5,
        serviceRadiusKm: 15.0,
        timestamp: now,
      );

      final map = entity.toMap();
      final fromMapEntity = ProviderLocationEntity.fromMap(map);

      expect(fromMapEntity.latitude, 24.91823);
      expect(fromMapEntity.longitude, 86.22341);
      expect(fromMapEntity.placeName, 'Bodhwantalaab');
      expect(fromMapEntity.formattedAddress, 'Bodhwantalaab, Jamui, Bihar, 811307');
      expect(fromMapEntity.city, 'Jamui');
      expect(fromMapEntity.district, 'Jamui');
      expect(fromMapEntity.state, 'Bihar');
      expect(fromMapEntity.pincode, '811307');
      expect(fromMapEntity.accuracy, 4.5);
      expect(fromMapEntity.serviceRadiusKm, 15.0);
    });

    test('TEST 2: calculateDistanceKm returns accurate distance matching Customer App', () {
      // Jamui Market: (24.9200, 86.2200) -> Jhajha: (24.7733, 86.3778)
      final distanceKm = LocationService.calculateDistanceKm(
        startLatitude: 24.9200,
        startLongitude: 86.2200,
        endLatitude: 24.7733,
        endLongitude: 86.3778,
      );

      // Distance is ~22.6 KM
      expect(distanceKm, greaterThan(20.0));
      expect(distanceKm, lessThan(26.0));
    });

    test('TEST 3: Provider Service Radius filtering matches Customer discovery', () {
      // Customer location at Jamui Court (24.9260, 86.2220)
      const customerLat = 24.9260;
      const customerLng = 86.2220;

      // Provider 1: Mahisauri (24.9180, 86.2250) ~ 1 KM away with 10 KM radius -> INSIDE
      const provider1Lat = 24.9180;
      const provider1Lng = 86.2250;
      const provider1Radius = 10.0;

      final dist1 = LocationService.calculateDistanceKm(
        startLatitude: customerLat,
        startLongitude: customerLng,
        endLatitude: provider1Lat,
        endLongitude: provider1Lng,
      );
      expect(dist1, lessThan(2.0));
      expect(dist1 <= provider1Radius, isTrue);

      // Provider 2: Chakai (24.5400, 86.4200) ~ 46 KM away with 10 KM radius -> OUTSIDE
      const provider2Lat = 24.5400;
      const provider2Lng = 86.4200;
      const provider2Radius = 10.0;

      final dist2 = LocationService.calculateDistanceKm(
        startLatitude: customerLat,
        startLongitude: customerLng,
        endLatitude: provider2Lat,
        endLongitude: provider2Lng,
      );
      expect(dist2, greaterThan(40.0));
      expect(dist2 <= provider2Radius, isFalse);
    });

    test('TEST 4: LocationAccuracyTier evaluation', () {
      expect(LocationService.evaluateAccuracy(15.0), LocationAccuracyTier.excellent);
      expect(LocationService.evaluateAccuracy(50.0), LocationAccuracyTier.acceptable);
      expect(LocationService.evaluateAccuracy(300.0), LocationAccuracyTier.warning);
      expect(LocationService.evaluateAccuracy(800.0), LocationAccuracyTier.poor);
    });

    test('TEST 5: cleanAddressString deduplication & formatting', () {
      final address = LocationService.cleanAddressString(
        street: 'Kachahari Road',
        subLocality: 'Bodhwan Talaab',
        locality: 'Jamui',
        state: 'Bihar',
        postalCode: '811307',
      );

      expect(address, contains('Kachahari Road'));
      expect(address, contains('Bodhwan Talaab'));
      expect(address, contains('Jamui'));
      expect(address, contains('Bihar'));
      expect(address, contains('811307'));
    });
  });
}
