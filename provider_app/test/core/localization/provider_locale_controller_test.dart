import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_jamui_provider/core/localization/provider_locale_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ProviderLocaleController.instance.resetForTest('hi');
  });

  group('ProviderLocaleController Tests', () {
    test('Default locale is Hindi on fresh install', () {
      final controller = ProviderLocaleController.instance;
      expect(controller.currentLocale, 'hi');
      expect(controller.isHindi, isTrue);
      expect(controller.isEnglish, isFalse);
    });

    test('Loads saved locale from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        ProviderLocaleController.prefKey: 'en',
      });
      final prefs = await SharedPreferences.getInstance();

      final controller = ProviderLocaleController.instance;
      await controller.init(prefs: prefs);

      expect(controller.currentLocale, 'en');
      expect(controller.isEnglish, isTrue);
      expect(controller.isHindi, isFalse);
    });

    test('setLocale switches language and updates SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final controller = ProviderLocaleController.instance;

      bool notified = false;
      controller.addListener(() => notified = true);

      await controller.setLocale('en', prefs: prefs);

      expect(controller.currentLocale, 'en');
      expect(controller.isEnglish, isTrue);
      expect(notified, isTrue);
      expect(prefs.getString(ProviderLocaleController.prefKey), 'en');

      // Switch back to Hindi
      notified = false;
      await controller.setLocale('hi', prefs: prefs);

      expect(controller.currentLocale, 'hi');
      expect(controller.isHindi, isTrue);
      expect(notified, isTrue);
      expect(prefs.getString(ProviderLocaleController.prefKey), 'hi');
    });

    test('toggleLocale switches back and forth', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final controller = ProviderLocaleController.instance;

      expect(controller.currentLocale, 'hi');

      await controller.toggleLocale(prefs: prefs);
      expect(controller.currentLocale, 'en');
      expect(prefs.getString(ProviderLocaleController.prefKey), 'en');

      await controller.toggleLocale(prefs: prefs);
      expect(controller.currentLocale, 'hi');
      expect(prefs.getString(ProviderLocaleController.prefKey), 'hi');
    });

    test('Ignores invalid locale codes', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final controller = ProviderLocaleController.instance;

      await controller.setLocale('fr', prefs: prefs);
      expect(controller.currentLocale, 'hi');

      await controller.setLocale('', prefs: prefs);
      expect(controller.currentLocale, 'hi');
    });
  });
}

