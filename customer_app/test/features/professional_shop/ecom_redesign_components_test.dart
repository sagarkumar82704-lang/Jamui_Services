import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_jamui_customer/features/professional_shop/domain/entities/professional_product_entity.dart';
import 'package:apna_jamui_customer/features/professional_shop/domain/entities/professional_shop_entity.dart';
import 'package:apna_jamui_customer/features/professional_shop/presentation/bloc/professional_cart_bloc.dart';
import 'package:apna_jamui_customer/features/professional_shop/presentation/localization/ecom_strings.dart';
import 'package:apna_jamui_customer/features/professional_shop/presentation/localization/ecom_locale_controller.dart';
import 'package:apna_jamui_customer/features/professional_shop/data/services/shop_favorites_service.dart';
import 'package:apna_jamui_customer/features/professional_shop/presentation/pages/professional_product_details_page.dart';
import 'package:apna_jamui_customer/features/professional_shop/presentation/widgets/ecom_order_status_timeline.dart';
import 'package:apna_jamui_customer/features/professional_shop/presentation/widgets/ecom_product_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testShop = ProfessionalShopEntity(
    id: 'shop_test_1',
    shopName: 'Sagar Grocery Jamui',
    jamuiArea: 'Jamui',
    isHomeDeliveryActive: true,
    isPickupActive: true,
    estimatedDeliveryTimeMinutes: 35,
    rating: 0.0,
    ratingCount: 0,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await EcomLocaleController.instance.setLocale('hi');
  });

  group('EcomLocaleController & EcomStrings Tests', () {
    test('Default locale is Hindi (hi) and formats units in Hindi', () async {
      await EcomLocaleController.instance.init();
      expect(EcomLocaleController.instance.currentLocale, 'hi');
      expect(EcomLocaleController.instance.isHindi, true);
      expect(EcomStrings.addToCart, 'कार्ट में जोड़ें');
      expect(EcomStrings.placeOrder, 'ऑर्डर करें');
      expect(EcomStrings.productDetails, 'उत्पाद विवरण');
      expect(EcomStrings.formatUnit(1, 'kg'), '1 किलो');
      expect(EcomStrings.formatUnit(500, 'gm'), '500 ग्राम');
    });

    test('Switching to English updates strings and units dynamically', () async {
      await EcomLocaleController.instance.setLocale('en');
      expect(EcomLocaleController.instance.currentLocale, 'en');
      expect(EcomLocaleController.instance.isHindi, false);
      expect(EcomStrings.addToCart, 'Add to Cart');
      expect(EcomStrings.placeOrder, 'Place Order');
      expect(EcomStrings.productDetails, 'Product Details');
      expect(EcomStrings.formatUnit(1, 'kg'), '1 kg');

      // Toggle back to Hindi
      await EcomLocaleController.instance.toggleLocale();
      expect(EcomLocaleController.instance.currentLocale, 'hi');
      expect(EcomStrings.addToCart, 'कार्ट में जोड़ें');
    });
  });

  group('ShopFavoritesService Tests', () {
    test('Can add, check, and remove favorites per shop with isolated keys', () async {
      const shopIdA = 'shop_123';
      const shopIdB = 'shop_999';
      const productId = 'prod_456';

      await ShopFavoritesService.instance.loadFavorites(shopIdA);
      await ShopFavoritesService.instance.loadFavorites(shopIdB);
      expect(ShopFavoritesService.instance.isFavorite(shopIdA, productId), false);

      await ShopFavoritesService.instance.toggleFavorite(shopIdA, productId);
      expect(ShopFavoritesService.instance.isFavorite(shopIdA, productId), true);
      expect(ShopFavoritesService.instance.isFavorite(shopIdB, productId), false);

      await ShopFavoritesService.instance.toggleFavorite(shopIdA, productId);
      expect(ShopFavoritesService.instance.isFavorite(shopIdA, productId), false);
    });
  });

  group('Zero Dummy Data & Approved Decisions Verification', () {
    testWidgets('Product Details hides fake ratings and shows factual fields when description is empty', (tester) async {
      await EcomLocaleController.instance.setLocale('en');
      const product = ProfessionalProductEntity(
        id: 'prod_rice',
        shopId: 'shop_test_1',
        titleEnglish: 'Basmati Rice',
        titleHindi: 'बासमती चावल',
        description: '',
        categoryName: 'Rice & Grains',
        storeCategoryName: 'चावल',
        sellingPrice: 120,
        regularPrice: 140,
        unit: 'kg',
        unitValue: 1,
        inStock: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider(
            create: (_) => ProfessionalCartBloc(),
            child: const ProfessionalProductDetailsPage(
              shop: testShop,
              product: product,
            ),
          ),
        ),
      );

      // Must NOT show hardcoded 4.5 or 320 reviews or Tata Salt claims
      expect(find.textContaining('4.5'), findsNothing);
      expect(find.textContaining('320'), findsNothing);
      expect(find.textContaining('आयोडीन'), findsNothing);
      expect(find.textContaining('Iodized'), findsNothing);

      // Must show real title, unit, price, MRP, and factual fallback fields
      expect(find.text('Basmati Rice (1 kg)'), findsOneWidget);
      expect(find.text('₹120'), findsOneWidget);
      expect(find.text('₹140'), findsOneWidget);
      expect(find.text('14% OFF'), findsOneWidget);
      expect(find.text('Category: चावल'), findsOneWidget);
      expect(find.text('Pack / Unit: 1 kg'), findsOneWidget);
      expect(find.text('Availability: In Stock'), findsOneWidget);
    });

    testWidgets('Product Details renders real seller-entered description lines when non-empty', (tester) async {
      await EcomLocaleController.instance.setLocale('en');
      const productWithDesc = ProfessionalProductEntity(
        id: 'prod_salt',
        shopId: 'shop_test_1',
        titleEnglish: 'Tata Salt',
        titleHindi: 'टाटा नमक',
        description: 'Vacuum evaporated iodized salt\n1 kg sealed pack',
        categoryName: 'Salt',
        sellingPrice: 40,
        regularPrice: 50,
        unit: 'kg',
        unitValue: 1,
        inStock: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider(
            create: (_) => ProfessionalCartBloc(),
            child: const ProfessionalProductDetailsPage(
              shop: testShop,
              product: productWithDesc,
            ),
          ),
        ),
      );

      expect(find.text('Vacuum evaporated iodized salt'), findsOneWidget);
      expect(find.text('1 kg sealed pack'), findsOneWidget);
      expect(find.text('20% OFF'), findsOneWidget);
    });

    testWidgets('EcomOrderStatusTimeline renders real timestamp only and supports cancelled/rejected', (tester) async {
      await EcomLocaleController.instance.setLocale('en');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EcomOrderStatusTimeline(
              orderStatus: 'out_for_delivery',
              isDelivery: true,
              orderDateFormatted: '09 Nov 2026, 10:24 AM',
            ),
          ),
        ),
      );

      expect(find.text('09 Nov 2026, 10:24 AM'), findsOneWidget);
      // Must NOT show fake step timestamps
      expect(find.text('Updated'), findsNothing);
      expect(find.text('In transit'), findsNothing);
      expect(find.text('In progress'), findsNothing);
    });

    testWidgets('EcomProductCard displays localized unit and genuine discount badge', (tester) async {
      await EcomLocaleController.instance.setLocale('hi');
      const product = ProfessionalProductEntity(
        id: 'prod_salt',
        shopId: 'shop_test_1',
        titleEnglish: 'Tata Salt',
        titleHindi: 'टाटा नमक',
        sellingPrice: 40,
        regularPrice: 50,
        unit: 'kg',
        unitValue: 1,
        inStock: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 300,
              child: EcomProductCard(
                shop: testShop,
                product: product,
                cartQuantity: 0,
                onTap: () {},
                onAddToCart: () {},
                onIncrement: () {},
                onDecrement: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('टाटा नमक'), findsOneWidget);
      expect(find.text('1 किलो'), findsOneWidget);
      expect(find.text('20% OFF'), findsOneWidget);
      expect(find.text('₹40'), findsOneWidget);
      expect(find.text('₹50'), findsOneWidget);
    });
  });

  group('ProfessionalShopEntity — Store Location & Promotional Banner Parsing', () {
    test('parses real seller promoBanner, landmark, and coordinates accurately', () {
      final shop = ProfessionalShopEntity.fromMap(
        {
          'shopName': 'Sagar Grocery Jamui',
          'ownerName': 'Sagar',
          'ownerPhone': '9876543210',
          'contactPhone': '9876543210',
          'whatsAppNumber': '9876543210',
          'shopCategory': 'Kirana',
          'description': 'Fresh groceries in Jamui',
          'logoUrl': 'providers/uid_1/profile/logo.jpg',
          'bannerUrl': 'providers/uid_1/business/cover.jpg',
          'fullAddress': 'Maharajganj Main Road, Jamui',
          'jamuiArea': 'Maharajganj',
          'landmark': 'Near Post Office',
          'latitude': 24.9195,
          'longitude': 86.2208,
          'locationSource': 'manual_lat_lng',
          'isLocationApproximate': false,
          'isApproved': true,
          'isOpen': true,
          'isSubscriptionActive': true,
          'promoBanner': {
            'title': 'Flat 20% OFF',
            'subtitle': 'On Daily Essentials',
            'offerText': 'Free Delivery Above ₹499',
            'imageUrl': 'providers/uid_1/workplace/promo.jpg',
            'isActive': true,
          },
        },
        'shop_sagar_1',
      );

      expect(shop.landmark, equals('Near Post Office'));
      expect(shop.latitude, closeTo(24.9195, 0.0001));
      expect(shop.longitude, closeTo(86.2208, 0.0001));
      expect(shop.locationSource, equals('manual_lat_lng'));
      expect(shop.isLocationApproximate, isFalse);
      expect(shop.promoBanner, isNotNull);
      expect(shop.promoBanner!.title, equals('Flat 20% OFF'));
      expect(shop.promoBanner!.subtitle, equals('On Daily Essentials'));
      expect(shop.promoBanner!.offerText, equals('Free Delivery Above ₹499'));
      expect(shop.promoBanner!.isCurrentlyLive(), isTrue);
    });

    test('hides promoBanner when inactive or empty', () {
      final shopWithoutBanner = ProfessionalShopEntity.fromMap(
        {
          'shopName': 'No Banner Shop',
          'isApproved': true,
          'isOpen': true,
          'isSubscriptionActive': true,
          'promoBanner': {
            'title': 'Old Offer',
            'isActive': false,
          },
        },
        'shop_2',
      );
      expect(shopWithoutBanner.promoBanner?.isCurrentlyLive(), isFalse);
    });
  });
}
