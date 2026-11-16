import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_jamui_provider/core/localization/provider_locale_controller.dart';
import 'package:apna_jamui_provider/core/localization/provider_strings.dart';
import 'package:apna_jamui_provider/features/auth/domain/entities/provider_profile_entity.dart';
import 'package:apna_jamui_provider/features/settings/presentation/pages/settings_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testProfile = ProviderProfileEntity(
    id: 'test_provider_1',
    email: 'test@jamuiservices.in',
    phoneNumber: '9876543210',
    fullName: 'Ramesh Kumar',
    businessName: 'Ramesh Store',
    primaryCategoryId: 'cat_pro',
    primaryCategoryTitle: 'General Store',
    createdAt: DateTime.now(),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ProviderLocaleController.instance.resetForTest('hi');
  });

  group('SettingsPage Language Selection Widget Tests', () {
    testWidgets('Shows Language tile with current language badge', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsPage(profile: testProfile),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the Language setting tile is visible
      expect(find.text(ProviderStrings.languageSettingTitle), findsOneWidget);
      expect(find.text('हिन्दी'), findsWidgets);
    });

    testWidgets('Tapping Language tile opens bottom sheet with Hindi and English options', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsPage(profile: testProfile),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on the language setting tile
      await tester.tap(find.text(ProviderStrings.languageSettingTitle));
      await tester.pumpAndSettle();

      // Verify BottomSheet opened with options
      expect(find.byKey(const Key('lang_option_hi')), findsOneWidget);
      expect(find.byKey(const Key('lang_option_en')), findsOneWidget);
      expect(find.text('Select Language'), findsNothing); // Under Hindi, title is 'भाषा चुनें'
      expect(find.text('भाषा चुनें'), findsWidgets);
    });

    testWidgets('Selecting English switches locale reactively and updates UI immediately', (tester) async {
      await tester.pumpWidget(
        ListenableBuilder(
          listenable: ProviderLocaleController.instance,
          builder: (context, _) => MaterialApp(
            locale: Locale(ProviderLocaleController.instance.currentLocale),
            home: Scaffold(
              body: SettingsPage(profile: testProfile),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial state is Hindi
      expect(ProviderLocaleController.instance.isHindi, isTrue);

      // Tap Language tile to open bottom sheet
      await tester.tap(find.text(ProviderStrings.languageSettingTitle));
      await tester.pumpAndSettle();

      // Tap English option
      await tester.tap(find.byKey(const Key('lang_option_en')));
      await tester.pumpAndSettle();

      // Verify controller updated to English
      expect(ProviderLocaleController.instance.isEnglish, isTrue);
      expect(ProviderLocaleController.instance.isHindi, isFalse);

      // Verify UI immediately updated to English
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);
      expect(find.text('Account Security & Privacy'), findsOneWidget);
    });
  });
}

