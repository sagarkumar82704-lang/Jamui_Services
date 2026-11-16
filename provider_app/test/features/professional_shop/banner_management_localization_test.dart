import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_provider/core/localization/provider_locale_controller.dart';
import 'package:apna_jamui_provider/features/professional_shop/domain/entities/professional_shop_profile_entity.dart';
import 'package:apna_jamui_provider/features/professional_shop/presentation/pages/professional_store_banner_management_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testShop = ProfessionalShopProfileEntity(
    id: 'shop_test_123',
    shopName: 'Jamui Grocery Mart',
    ownerUid: 'provider_test_uid',
    promoBanner: ShopPromoBannerEntity(
      imageUrl: '',
      title: 'Fresh Grocery',
      subtitle: 'Daily Essentials at Best Prices',
      offerText: 'Special Offer',
      isActive: true,
    ),
  );

  group('Promotional Banner Management Localization Tests', () {
    testWidgets('Renders Hindi labels when Hindi locale is active', (tester) async {
      ProviderLocaleController.instance.resetForTest('hi');

      await tester.pumpWidget(
        MaterialApp(
          home: ProfessionalStoreBannerManagementPage(shop: testShop),
        ),
      );
      await tester.pumpAndSettle();

      // Reference UI items in Hindi
      expect(find.text('प्रचार बैनर'), findsOneWidget); // AppBar
      expect(find.text('स्टोरफ़्रंट बैनर पूर्वावलोकन'), findsOneWidget); // Header
      expect(find.text('स्टोर पर लाइव'), findsOneWidget); // Status pill
      expect(find.text('बैनर सक्रिय स्थिति'), findsOneWidget); // Switch label
      expect(find.text('बैनर शीर्षक'), findsOneWidget); // Form label
      expect(find.text('बैनर उपशीर्षक'), findsOneWidget); // Form label
      expect(find.text('प्रचार बैनर सहेजें'), findsOneWidget); // Save button
    });

    testWidgets('Renders English labels matching reference screenshot when English is active', (tester) async {
      ProviderLocaleController.instance.resetForTest('en');

      await tester.pumpWidget(
        MaterialApp(
          home: ProfessionalStoreBannerManagementPage(shop: testShop),
        ),
      );
      await tester.pumpAndSettle();

      // Reference UI items in English
      expect(find.text('Promotional Banner'), findsOneWidget); // AppBar
      expect(find.text('Storefront Banner Preview'), findsOneWidget); // Header
      expect(find.text('LIVE ON STOREFRONT'), findsOneWidget); // Status pill
      expect(find.text('Banner Active Status'), findsOneWidget); // Switch label
      expect(find.text('Banner Title'), findsOneWidget); // Form label
      expect(find.text('Banner Subtitle'), findsOneWidget); // Form label
      expect(find.text('Save Promotional Banner'), findsOneWidget); // Save button
    });
  });
}
