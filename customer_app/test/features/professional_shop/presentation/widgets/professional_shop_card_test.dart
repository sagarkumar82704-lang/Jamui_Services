import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_customer/features/professional_shop/domain/entities/professional_shop_entity.dart';
import 'package:apna_jamui_customer/features/professional_shop/presentation/widgets/professional_shop_card.dart';

void main() {
  ProfessionalShopEntity createShop({
    String id = 'shop_1',
    String shopName = 'Jamui Kirana Store',
    double? distanceKm = 2.5,
    String jamuiArea = 'Station Road, Jamui',
    bool isVerified = true,
    double rating = 4.5,
    int ratingCount = 20,
    bool isHomeDeliveryActive = true,
    bool isPickupActive = true,
    double serviceRadiusKm = 10.0,
    Map<String, dynamic>? weeklySchedule,
    double minOrderAmount = 199.0,
    double deliveryCharges = 25.0,
    int estimatedDeliveryTimeMinutes = 35,
  }) {
    return ProfessionalShopEntity(
      id: id,
      shopName: shopName,
      latitude: 25.1337,
      longitude: 86.1772,
      distanceKm: distanceKm,
      jamuiArea: jamuiArea,
      isVerified: isVerified,
      rating: rating,
      ratingCount: ratingCount,
      isHomeDeliveryActive: isHomeDeliveryActive,
      isPickupActive: isPickupActive,
      serviceRadiusKm: serviceRadiusKm,
      weeklySchedule: weeklySchedule,
      minOrderAmount: minOrderAmount,
      deliveryCharges: deliveryCharges,
      estimatedDeliveryTimeMinutes: estimatedDeliveryTimeMinutes,
    );
  }

  Widget createWidgetUnderTest(ProfessionalShopEntity shop, {VoidCallback? onTap}) {
    return MaterialApp(
      home: Scaffold(
        body: ProfessionalShopCard(
          shop: shop,
          onTap: onTap,
        ),
      ),
    );
  }

  group('ProfessionalShopCard Tests', () {
    testWidgets('renders shop name and verified badge', (tester) async {
      final shop = createShop(shopName: 'Maa Durga Electricals', isVerified: true);
      await tester.pumpWidget(createWidgetUnderTest(shop));

      expect(find.text('Maa Durga Electricals'), findsOneWidget);
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
    });

    testWidgets('displays real verified distance chip when GPS distance is available', (tester) async {
      final shop = createShop(distanceKm: 3.4);
      await tester.pumpWidget(createWidgetUnderTest(shop));

      expect(find.text('3.4 km'), findsOneWidget);
      expect(find.byIcon(Icons.location_on_rounded), findsOneWidget);
    });

    testWidgets('displays locality badge fallback when distance is null (never 0.0 km)', (tester) async {
      final shop = createShop(distanceKm: null, jamuiArea: 'Kachahari Road');
      await tester.pumpWidget(createWidgetUnderTest(shop));

      expect(find.text('0.0 km'), findsNothing);
      expect(find.text('Kachahari Road'), findsOneWidget);
      expect(find.byIcon(Icons.location_on_rounded), findsOneWidget);
    });

    testWidgets('hides rating badge when ratingCount is 0 or rating is 0.0 (zero fake ratings)', (tester) async {
      final shop = createShop(rating: 0.0, ratingCount: 0);
      await tester.pumpWidget(createWidgetUnderTest(shop));

      expect(find.byIcon(Icons.star_rounded), findsNothing);
      expect(find.textContaining('0.0'), findsNothing);
    });

    testWidgets('shows rating badge when rating > 0.0 and ratingCount > 0', (tester) async {
      final shop = createShop(rating: 4.8, ratingCount: 42);
      await tester.pumpWidget(createWidgetUnderTest(shop));

      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
      expect(find.text('4.8 (42)'), findsOneWidget);
    });

    testWidgets('shows "Delivery & Pickup" chip when both delivery and pickup are eligible', (tester) async {
      final shop = createShop(
        isHomeDeliveryActive: true,
        isPickupActive: true,
        serviceRadiusKm: 10.0,
        distanceKm: 4.0,
      );
      await tester.pumpWidget(createWidgetUnderTest(shop));

      expect(find.text('Delivery & Pickup'), findsOneWidget);
    });

    testWidgets('shows "Home Delivery Only" chip when pickup is inactive', (tester) async {
      final shop = createShop(
        isHomeDeliveryActive: true,
        isPickupActive: false,
        serviceRadiusKm: 10.0,
        distanceKm: 4.0,
      );
      await tester.pumpWidget(createWidgetUnderTest(shop));

      expect(find.text('Home Delivery Only'), findsOneWidget);
    });

    testWidgets('shows "Store Pickup (Outside Delivery Zone)" when distance exceeds service radius', (tester) async {
      final shop = createShop(
        isHomeDeliveryActive: true,
        isPickupActive: true,
        serviceRadiusKm: 5.0,
        distanceKm: 8.5,
      );
      await tester.pumpWidget(createWidgetUnderTest(shop));

      expect(find.text('Store Pickup (Outside Delivery Zone)'), findsOneWidget);
    });

    testWidgets('shows "Store Pickup Only" when home delivery is inactive', (tester) async {
      final shop = createShop(
        isHomeDeliveryActive: false,
        isPickupActive: true,
      );
      await tester.pumpWidget(createWidgetUnderTest(shop));

      expect(find.text('Store Pickup Only'), findsOneWidget);
    });

    testWidgets('shows pricing footer with Min Order and Delivery charge', (tester) async {
      final shop = createShop(
        isHomeDeliveryActive: true,
        minOrderAmount: 250.0,
        deliveryCharges: 30.0,
        estimatedDeliveryTimeMinutes: 40,
      );
      await tester.pumpWidget(createWidgetUnderTest(shop));

      expect(find.text('Min. ₹250'), findsOneWidget);
      expect(find.text('Delivery ₹30'), findsOneWidget);
      expect(find.text('40m'), findsOneWidget);
    });

    testWidgets('shows Free Delivery when delivery charge is 0', (tester) async {
      final shop = createShop(
        isHomeDeliveryActive: true,
        minOrderAmount: 150.0,
        deliveryCharges: 0.0,
      );
      await tester.pumpWidget(createWidgetUnderTest(shop));

      expect(find.text('Free Delivery'), findsOneWidget);
    });

    testWidgets('invokes onTap callback when card is tapped', (tester) async {
      bool tapped = false;
      final shop = createShop();
      await tester.pumpWidget(createWidgetUnderTest(shop, onTap: () => tapped = true));

      await tester.tap(find.text('Jamui Kirana Store'));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });
}
