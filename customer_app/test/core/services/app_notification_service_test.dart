import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_customer/core/services/app_notification_service.dart';

void main() {
  group('AppNotificationService Lifecycle Tests', () {
    tearDown(() {
      AppNotificationService.dispose();
    });

    test('Test 1: AppNotificationService.dispose() safely cleans up without throwing exceptions', () {
      expect(() => AppNotificationService.dispose(), returnsNormally);
      expect(() => AppNotificationService.dispose(), returnsNormally);
    });
  });
}
