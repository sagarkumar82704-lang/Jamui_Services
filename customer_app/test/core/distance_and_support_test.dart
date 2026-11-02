import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_customer/core/services/location_service.dart';
import 'package:apna_jamui_customer/core/services/company_settings_service.dart';

void main() {
  group('Distance Calculation and Formatting Tests', () {
    test('returns null when any coordinate is null', () {
      expect(
        LocationService.getFormattedDistanceString(
          customerLat: null,
          customerLng: 86.22,
          providerLat: 24.92,
          providerLng: 86.22,
        ),
        isNull,
      );

      expect(
        LocationService.getFormattedDistanceString(
          customerLat: 24.92,
          customerLng: null,
          providerLat: 24.92,
          providerLng: 86.22,
        ),
        isNull,
      );

      expect(
        LocationService.getFormattedDistanceString(
          customerLat: 24.92,
          customerLng: 86.22,
          providerLat: null,
          providerLng: 86.22,
        ),
        isNull,
      );

      expect(
        LocationService.getFormattedDistanceString(
          customerLat: 24.92,
          customerLng: 86.22,
          providerLat: 24.92,
          providerLng: null,
        ),
        isNull,
      );
    });

    test('returns null when coordinates are 0.0, 0.0 (dummy/default)', () {
      expect(
        LocationService.getFormattedDistanceString(
          customerLat: 0.0,
          customerLng: 0.0,
          providerLat: 24.92,
          providerLng: 86.22,
        ),
        isNull,
      );

      expect(
        LocationService.getFormattedDistanceString(
          customerLat: 24.92,
          customerLng: 86.22,
          providerLat: 0.0,
          providerLng: 0.0,
        ),
        isNull,
      );
    });

    test('returns null when coordinates are out of valid GPS range', () {
      expect(
        LocationService.getFormattedDistanceString(
          customerLat: 95.0,
          customerLng: 86.22,
          providerLat: 24.92,
          providerLng: 86.22,
        ),
        isNull,
      );
    });

    test('formats meters when distance is under 1 km (< 1000m)', () {
      // Coordinates approx 400-500 meters apart in Jamui
      // 24.9200, 86.2200 to 24.9235, 86.2200 is approx 390m
      final result = LocationService.getFormattedDistanceString(
        customerLat: 24.9200,
        customerLng: 86.2200,
        providerLat: 24.9235,
        providerLng: 86.2200,
      );

      expect(result, isNotNull);
      expect(result, contains('m दूर'));
    });

    test('formats kilometers when distance is 1 km or greater', () {
      // 24.9200, 86.2200 to 24.9500, 86.2200 is approx 3.3 km
      final result = LocationService.getFormattedDistanceString(
        customerLat: 24.9200,
        customerLng: 86.2200,
        providerLat: 24.9500,
        providerLng: 86.2200,
      );

      expect(result, isNotNull);
      expect(result, contains('km दूर'));
      expect(result, contains('3.3 km दूर'));
    });
  });

  group('CompanySettingsEntity Model Tests', () {
    test('uses production fallbacks when map is empty', () {
      final settings = CompanySettingsEntity.fromMap({});
      expect(settings.companyName, isNotEmpty);
      expect(settings.supportPhone, isNotEmpty);
      expect(settings.supportEmail, isNotEmpty);
      expect(settings.workingHours, isNotEmpty);
      expect(settings.maintenanceMode, isFalse);
    });

    test('correctly parses Firestore document values', () {
      final data = {
        'companyName': 'Apna Jamui Super Services',
        'supportPhone': '+91 99999 88888',
        'supportEmail': 'help@apnajamui.com',
        'supportWhatsapp': '+91 99999 88888',
        'companyAddress': 'Main Market, Jamui, Bihar - 811307',
        'websiteUrl': 'https://apnajamui.in',
        'workingHours': '08:00 AM - 10:00 PM',
        'maintenanceMode': true,
      };

      final settings = CompanySettingsEntity.fromMap(data);
      expect(settings.companyName, equals('Apna Jamui Super Services'));
      expect(settings.supportPhone, equals('+91 99999 88888'));
      expect(settings.supportEmail, equals('help@apnajamui.com'));
      expect(settings.supportWhatsapp, equals('+91 99999 88888'));
      expect(settings.companyAddress, equals('Main Market, Jamui, Bihar - 811307'));
      expect(settings.websiteUrl, equals('https://apnajamui.in'));
      expect(settings.workingHours, equals('08:00 AM - 10:00 PM'));
      expect(settings.maintenanceMode, isTrue);
    });
  });
}
