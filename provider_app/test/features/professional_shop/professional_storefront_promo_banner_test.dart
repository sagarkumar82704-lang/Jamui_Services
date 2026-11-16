import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_provider/features/professional_shop/domain/entities/professional_shop_profile_entity.dart';
import 'package:apna_jamui_provider/features/professional_shop/presentation/widgets/professional_storefront_promo_banner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProfessionalStorefrontPromoBanner — Provider App Unit & Widget Tests', () {
    testWidgets('1. Mode 1: Image banner renders full-bleed with 2.4:1 aspect ratio', (tester) async {
      const banner = ShopPromoBannerEntity(
        imageUrl: 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=800',
        title: 'Fresh Grocery',
        subtitle: 'Daily Essentials at Best Prices',
        offerText: 'Special Offer',
        isActive: true,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 390,
                child: ProfessionalStorefrontPromoBanner(
                  banner: banner,
                ),
              ),
            ),
          ),
        ),
      );

      // Verify AspectRatio widget with 2.4 ratio
      final aspectRatioFinder = find.byType(AspectRatio);
      expect(aspectRatioFinder, findsOneWidget);
      final AspectRatio aspectRatioWidget = tester.widget(aspectRatioFinder);
      expect(aspectRatioWidget.aspectRatio, equals(2.4));

      // In Image Mode, the image is rendered full-bleed inside a Stack within the banner
      final bannerStackFinder = find.descendant(
        of: find.byType(ProfessionalStorefrontPromoBanner),
        matching: find.byType(Stack),
      );
      expect(bannerStackFinder, findsOneWidget);
    });

    testWidgets('2. Mode 2: Text-only banner renders title, subtitle, and offer badge cleanly', (tester) async {
      const banner = ShopPromoBannerEntity(
        imageUrl: '', // No image
        title: 'Flat 20% OFF Everything',
        subtitle: 'Valid on fresh fruits and vegetables',
        offerText: 'Weekend Mega Deal',
        isActive: true,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 390,
                child: ProfessionalStorefrontPromoBanner(
                  banner: banner,
                ),
              ),
            ),
          ),
        ),
      );

      // Verify text elements are rendered
      expect(find.text('Weekend Mega Deal'), findsOneWidget);
      expect(find.text('Flat 20% OFF Everything'), findsOneWidget);
      expect(find.text('Valid on fresh fruits and vegetables'), findsOneWidget);

      // Verify 2.4 aspect ratio is maintained
      final aspectRatioFinder = find.byType(AspectRatio);
      expect(aspectRatioFinder, findsOneWidget);
      final AspectRatio aspectRatioWidget = tester.widget(aspectRatioFinder);
      expect(aspectRatioWidget.aspectRatio, equals(2.4));
    });

    testWidgets('3. Offer badge falls back to free delivery threshold when offerText is empty', (tester) async {
      const banner = ShopPromoBannerEntity(
        imageUrl: '',
        title: 'Super Saver Sale',
        subtitle: 'Shop your favorites today',
        offerText: '', // Empty
        isActive: true,
      );

      // English fallback test
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 390,
              child: ProfessionalStorefrontPromoBanner(
                banner: banner,
                freeDeliveryThreshold: 499.0,
                isHindi: false,
              ),
            ),
          ),
        ),
      );
      expect(find.text('Free Delivery Above ₹499'), findsOneWidget);

      // Hindi fallback test
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 390,
              child: ProfessionalStorefrontPromoBanner(
                banner: banner,
                freeDeliveryThreshold: 499.0,
                isHindi: true,
              ),
            ),
          ),
        ),
      );
      expect(find.text('₹499 के ऊपर मुफ़्त डिलीवरी'), findsOneWidget);
    });

    testWidgets('4. Responsive screen widths: 320dp, 360dp, 390dp, 412dp, and 800dp tablet', (tester) async {
      const banner = ShopPromoBannerEntity(
        imageUrl: '',
        title: 'Special Season Mega Discount for All Customers in Jamui District',
        subtitle: 'Organic farm produce delivered to your doorstep in 30 minutes',
        offerText: 'Limited Period',
        isActive: true,
      );

      final screenWidths = [320.0, 360.0, 390.0, 412.0, 800.0];

      for (final w in screenWidths) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: w,
                  child: const ProfessionalStorefrontPromoBanner(
                    banner: banner,
                  ),
                ),
              ),
            ),
          ),
        );

        // Verify zero overflow errors across all screen sizes
        expect(tester.takeException(), isNull);
        expect(find.text('Limited Period'), findsOneWidget);
        expect(find.byType(AspectRatio), findsOneWidget);
      }
    });

    test('5. Schedule & Active State Invariants (Inactive, Expired, Future-scheduled)', () {
      final now = DateTime(2026, 11, 9, 12, 0);

      // Active banner within schedule
      final activeBanner = ShopPromoBannerEntity(
        title: 'Active Promo',
        isActive: true,
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 15),
      );
      expect(activeBanner.isCurrentlyLive(now), isTrue);

      // Inactive toggle turned OFF
      final inactiveBanner = activeBanner.copyWith(isActive: false);
      expect(inactiveBanner.isCurrentlyLive(now), isFalse);

      // Expired banner
      final expiredBanner = activeBanner.copyWith(endDate: DateTime(2026, 11, 5));
      expect(expiredBanner.isCurrentlyLive(now), isFalse);

      // Future scheduled banner (not yet started)
      final futureBanner = activeBanner.copyWith(startDate: DateTime(2026, 11, 20));
      expect(futureBanner.isCurrentlyLive(now), isFalse);

      // Empty content
      const emptyBanner = ShopPromoBannerEntity(isActive: true);
      expect(emptyBanner.isCurrentlyLive(now), isFalse);
    });
  });
}

