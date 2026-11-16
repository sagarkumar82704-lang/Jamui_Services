import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_jamui_provider/core/localization/provider_locale_controller.dart';
import 'package:apna_jamui_provider/features/professional_shop/domain/entities/professional_shop_profile_entity.dart';
import 'package:apna_jamui_provider/features/professional_shop/presentation/pages/professional_shop_profile_page.dart';
import 'package:apna_jamui_provider/features/professional_shop/presentation/pages/professional_shop_workspace_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testShop = ProfessionalShopProfileEntity(
    id: 'shop_test_123',
    ownerUid: 'owner_test_123',
    shopName: 'sagar Groccory Jamui',
    demandCategoryTitle: 'Groccory',
    isApproved: true,
    isOpen: true,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ProviderLocaleController.instance.resetForTest('hi');
  });

  group('Professional Seller Language Access Tests', () {
    testWidgets('1. Professional Profile page displays App Settings & Language card with switch option', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 768));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfessionalShopProfilePage(shop: testShop),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the App Settings & Language Section
      final tileFinder = find.byKey(const Key('tile_profile_language'));
      expect(tileFinder, findsOneWidget);

      // Verify Hindi is shown by default
      expect(ProviderLocaleController.instance.isHindi, isTrue);

      // Ensure visible and tap on Language tile
      await tester.ensureVisible(tileFinder);
      await tester.pumpAndSettle();
      await tester.tap(tileFinder);
      await tester.pumpAndSettle();

      // Verify Language modal opened with options
      expect(find.byKey(const Key('lang_option_hi')), findsOneWidget);
      expect(find.byKey(const Key('lang_option_en')), findsOneWidget);

      // Switch to English
      await tester.tap(find.byKey(const Key('lang_option_en')));
      await tester.pumpAndSettle();

      // Verify locale switched to English
      expect(ProviderLocaleController.instance.currentLocale, 'en');
      expect(ProviderLocaleController.instance.isHindi, isFalse);
    });

    testWidgets('2. Professional Workspace Screen displays Language Switcher in sidebar footer', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfessionalShopWorkspaceScreen(shop: testShop),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify sidebar language button exists
      expect(find.byKey(const Key('sidebar_language_btn')), findsOneWidget);

      // Tap on sidebar language button
      await tester.tap(find.byKey(const Key('sidebar_language_btn')));
      await tester.pumpAndSettle();

      // Verify Language modal opened
      expect(find.byKey(const Key('lang_option_hi')), findsOneWidget);
      expect(find.byKey(const Key('lang_option_en')), findsOneWidget);
    });
  });
}
