import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_customer/core/services/customer_app_settings_service.dart';

void main() {
  group('CustomerAppSettingsService Version Comparison Tests', () {
    test('isVersionLowerThan returns true when current version is strictly lower', () {
      expect(CustomerAppSettingsService.isVersionLowerThan('1.0.0', '1.0.1'), isTrue);
      expect(CustomerAppSettingsService.isVersionLowerThan('1.0.0', '1.1.0'), isTrue);
      expect(CustomerAppSettingsService.isVersionLowerThan('1.0.0', '2.0.0'), isTrue);
      expect(CustomerAppSettingsService.isVersionLowerThan('1.2.3', '1.2.4'), isTrue);
      expect(CustomerAppSettingsService.isVersionLowerThan('1.2.3', '1.3.0'), isTrue);
    });

    test('isVersionLowerThan returns false when current version is equal or higher', () {
      expect(CustomerAppSettingsService.isVersionLowerThan('1.0.0', '1.0.0'), isFalse);
      expect(CustomerAppSettingsService.isVersionLowerThan('1.0.1', '1.0.0'), isFalse);
      expect(CustomerAppSettingsService.isVersionLowerThan('2.0.0', '1.9.9'), isFalse);
      expect(CustomerAppSettingsService.isVersionLowerThan('1.3.0', '1.2.9'), isFalse);
    });

    test('isVersionLowerThan handles build numbers and suffixes gracefully', () {
      expect(CustomerAppSettingsService.isVersionLowerThan('1.0.0+1', '1.0.1'), isTrue);
      expect(CustomerAppSettingsService.isVersionLowerThan('1.0.1+5', '1.0.1'), isFalse);
      expect(CustomerAppSettingsService.isVersionLowerThan('1.0.0-beta', '1.0.1'), isTrue);
    });
  });
}
