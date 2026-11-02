import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_provider/core/services/remote_config_service.dart';

void main() {
  group('Provider App RemoteConfigService Version Comparison Tests', () {
    test('isVersionLowerThan returns true when current version is strictly lower', () {
      expect(RemoteConfigService.isVersionLowerThan('1.0.0', '1.0.1'), isTrue);
      expect(RemoteConfigService.isVersionLowerThan('1.0.0', '1.1.0'), isTrue);
      expect(RemoteConfigService.isVersionLowerThan('1.0.0', '2.0.0'), isTrue);
      expect(RemoteConfigService.isVersionLowerThan('1.2.3', '1.2.4'), isTrue);
    });

    test('isVersionLowerThan returns false when current version is equal or higher', () {
      expect(RemoteConfigService.isVersionLowerThan('1.0.0', '1.0.0'), isFalse);
      expect(RemoteConfigService.isVersionLowerThan('1.0.1', '1.0.0'), isFalse);
      expect(RemoteConfigService.isVersionLowerThan('2.0.0', '1.9.9'), isFalse);
    });
  });
}
