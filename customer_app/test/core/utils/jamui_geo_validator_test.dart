import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_customer/core/utils/jamui_geo_validator.dart';

void main() {
  group('JamuiGeoValidator - Coordinate Validation', () {
    test('Rejects uninitialized Null Island sentinel (0.0, 0.0)', () {
      expect(JamuiGeoValidator.isValidCoordinates(0.0, 0.0), isFalse);
      expect(JamuiGeoValidator.isValidCoordinates(0, 0), isFalse);
    });

    test('Validates Equator (0.0, 86.22) as mathematically legal', () {
      expect(JamuiGeoValidator.isValidCoordinates(0.0, 86.22), isTrue);
    });

    test('Validates Prime Meridian (24.92, 0.0) as mathematically legal', () {
      expect(JamuiGeoValidator.isValidCoordinates(24.92, 0.0), isTrue);
    });

    test('Rejects null coordinates', () {
      expect(JamuiGeoValidator.isValidCoordinates(null, 86.22), isFalse);
      expect(JamuiGeoValidator.isValidCoordinates(24.92, null), isFalse);
      expect(JamuiGeoValidator.isValidCoordinates(null, null), isFalse);
    });

    test('Rejects NaN and Infinite coordinates', () {
      expect(JamuiGeoValidator.isValidCoordinates(double.nan, 86.22), isFalse);
      expect(JamuiGeoValidator.isValidCoordinates(24.92, double.nan), isFalse);
      expect(JamuiGeoValidator.isValidCoordinates(double.infinity, 86.22), isFalse);
      expect(JamuiGeoValidator.isValidCoordinates(24.92, double.negativeInfinity), isFalse);
    });

    test('Rejects out-of-range coordinates', () {
      expect(JamuiGeoValidator.isValidCoordinates(95.0, 86.22), isFalse);
      expect(JamuiGeoValidator.isValidCoordinates(-95.0, 86.22), isFalse);
      expect(JamuiGeoValidator.isValidCoordinates(24.92, 200.0), isFalse);
      expect(JamuiGeoValidator.isValidCoordinates(24.92, -200.0), isFalse);
    });

    test('Validates realistic Jamui coordinates', () {
      // Jamui Station: ~24.92, 86.22
      expect(JamuiGeoValidator.isValidCoordinates(24.92, 86.22), isTrue);
    });
  });

  group('JamuiGeoValidator - Haversine Distance & Displacement', () {
    test('Calculates accurate distance between Jamui Station and Malaypur', () {
      // Jamui: ~24.919, 86.223; Malaypur: ~24.945, 86.248 (~3.8 km)
      final distance = JamuiGeoValidator.calculateHaversineDistanceKm(
        24.919,
        86.223,
        24.945,
        86.248,
      );
      expect(distance, greaterThan(3.5));
      expect(distance, lessThan(4.5));
    });

    test('Identical points produce 0.0 km distance and 0.0m displacement', () {
      final distance = JamuiGeoValidator.calculateHaversineDistanceKm(
        24.92,
        86.22,
        24.92,
        86.22,
      );
      expect(distance, closeTo(0.0, 1e-6));

      final displacement = JamuiGeoValidator.calculateDisplacementMeters(
        24.92,
        86.22,
        24.92,
        86.22,
      );
      expect(displacement, closeTo(0.0, 1e-4));
    });

    test('Calculates displacement in meters accurately', () {
      final distanceKm = JamuiGeoValidator.calculateHaversineDistanceKm(
        24.919,
        86.223,
        24.920,
        86.223,
      );
      final displacementMeters = JamuiGeoValidator.calculateDisplacementMeters(
        24.919,
        86.223,
        24.920,
        86.223,
      );
      expect(displacementMeters, closeTo(distanceKm * 1000.0, 1e-4));
    });
  });

  group('JamuiGeoValidator - Geohash Encoder', () {
    test('Encodes standard 7-character Geohash for Jamui', () {
      final hash = JamuiGeoValidator.encodeGeohash(24.92, 86.22, precision: 7);
      expect(hash.length, equals(7));
      expect(hash, isNotEmpty);
    });

    test('Consistent encoding for identical coordinates', () {
      final hash1 = JamuiGeoValidator.encodeGeohash(24.92, 86.22, precision: 7);
      final hash2 = JamuiGeoValidator.encodeGeohash(24.92, 86.22, precision: 7);
      expect(hash1, equals(hash2));
    });

    test('Handles NaN gracefully with empty string', () {
      expect(JamuiGeoValidator.encodeGeohash(double.nan, 86.22), isEmpty);
    });
  });
}

