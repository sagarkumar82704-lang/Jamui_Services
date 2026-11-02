import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:apna_jamui_customer/core/utils/jamui_geo_validator.dart';
import 'package:apna_jamui_customer/features/professional_shop/domain/entities/professional_category_entity.dart';
import 'package:apna_jamui_customer/features/professional_shop/domain/entities/professional_product_entity.dart';
import 'package:apna_jamui_customer/features/professional_shop/domain/entities/professional_shop_entity.dart';
import 'package:apna_jamui_customer/features/professional_shop/presentation/bloc/professional_cart_bloc.dart';
import 'package:apna_jamui_customer/features/professional_shop/presentation/pages/professional_shops_listing_page.dart';
import 'package:apna_jamui_customer/features/professional_shop/presentation/pages/professional_shop_details_page.dart';
import 'package:apna_jamui_customer/features/professional_shop/presentation/pages/professional_storefront_page.dart';
import 'package:apna_jamui_customer/features/professional_shop/presentation/pages/professional_product_details_page.dart';
import 'package:apna_jamui_customer/features/professional_shop/presentation/pages/professional_cart_page.dart';
import 'package:apna_jamui_customer/features/professional_shop/presentation/widgets/professional_shop_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Test Fixtures
  ProfessionalShopEntity createTestShop({
    String id = 'shop_101',
    String shopName = 'Jamui Fresh Mart',
    String demandCategoryId = 'grocery_daily',
    String demandCategoryTitle = 'Grocery & Daily Needs',
    double latitude = 25.1337,
    double longitude = 86.1772,
    double? distanceKm = 1.8,
    String jamuiArea = 'Laxmi Chowk, Jamui',
    String fullAddress = 'Main Market, Laxmi Chowk, Jamui - 811307',
    bool isHomeDeliveryActive = true,
    bool isPickupActive = true,
    String pickupInstructions = 'Collect from Counter 2 with order ID',
    double minOrderAmount = 149.0,
    double deliveryCharges = 20.0,
    double freeDeliveryThreshold = 499.0,
    int estimatedDeliveryTimeMinutes = 25,
    String openingTime = '07:00 AM',
    String closingTime = '10:00 PM',
    bool isVerified = true,
    bool isActive = true,
    bool isDeleted = false,
    String status = 'approved',
    bool isSubscriptionActive = true,
    DateTime? subscriptionExpiresAt,
  }) {
    return ProfessionalShopEntity(
      id: id,
      shopName: shopName,
      demandCategoryId: demandCategoryId,
      demandCategoryTitle: demandCategoryTitle,
      latitude: latitude,
      longitude: longitude,
      distanceKm: distanceKm,
      jamuiArea: jamuiArea,
      fullAddress: fullAddress,
      isHomeDeliveryActive: isHomeDeliveryActive,
      isPickupActive: isPickupActive,
      pickupInstructions: pickupInstructions,
      minOrderAmount: minOrderAmount,
      deliveryCharges: deliveryCharges,
      freeDeliveryThreshold: freeDeliveryThreshold,
      estimatedDeliveryTimeMinutes: estimatedDeliveryTimeMinutes,
      openingTime: openingTime,
      closingTime: closingTime,
      isVerified: isVerified,
      isActive: isActive,
      isDeleted: isDeleted,
      status: status,
      isSubscriptionActive: isSubscriptionActive,
      subscriptionExpiresAt: subscriptionExpiresAt ?? DateTime.now().add(const Duration(days: 30)),
    );
  }

  ProfessionalProductEntity createTestProduct({
    String id = 'prod_01',
    String shopId = 'shop_101',
    String titleEnglish = 'Aashirvaad Shudh Chakki Atta',
    String titleHindi = 'आशीर्वाद आटा',
    String categoryName = 'Atta & Flours',
    String storeCategoryName = 'Atta & Flours',
    double sellingPrice = 360.0,
    double regularPrice = 420.0,
    String unit = 'kg',
    double unitValue = 10.0,
    bool inStock = true,
    Map<String, dynamic> attributes = const {
      'brand': 'Aashirvaad',
      'weight': '10 kg',
      'dietaryType': 'Vegetarian',
      'shelfLifeDays': '90 Days',
    },
  }) {
    return ProfessionalProductEntity(
      id: id,
      shopId: shopId,
      titleEnglish: titleEnglish,
      titleHindi: titleHindi,
      categoryName: categoryName,
      storeCategoryName: storeCategoryName,
      sellingPrice: sellingPrice,
      regularPrice: regularPrice,
      discountPercentage: 14.0,
      unit: unit,
      unitValue: unitValue,
      inStock: inStock,
      attributes: attributes,
    );
  }

  group('Phase 2G Screen 1: Customer Home Categories Navigation', () {
    test('ProfessionalCategoryEntity parses diamond_categories schema accurately', () {
      final map = {
        'titleEnglish': 'Grocery',
        'titleHindi': 'किराना',
        'slug': 'grocery',
        'priorityOrder': 1,
        'isActive': true,
      };
      final cat = ProfessionalCategoryEntity.fromMap(map, 'cat_groc');
      expect(cat.id, 'cat_groc');
      expect(cat.titleEnglish, 'Grocery');
      expect(cat.titleHindi, 'किराना');
      expect(cat.displayName, 'किराना');
      expect(cat.priorityOrder, 1);
      expect(cat.isActive, isTrue);
    });
  });

  group('Phase 2G Screen 2: Location-Wise Seller Listing & Eligibility', () {
    test('Strict Eligibility: Active, approved, non-expired subscription required', () {
      final validShop = createTestShop();
      expect(validShop.isApprovedAndLive, isTrue);

      final unapprovedShop = createTestShop(status: 'pending');
      expect(unapprovedShop.isApprovedAndLive, isFalse);

      final expiredShop = createTestShop(
        subscriptionExpiresAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(expiredShop.isApprovedAndLive, isFalse);

      final inactiveShop = createTestShop(isActive: false);
      expect(inactiveShop.isApprovedAndLive, isFalse);

      final deletedShop = createTestShop(isDeleted: true);
      expect(deletedShop.isApprovedAndLive, isFalse);
    });

    test('Geolocation: Haversine distance correctly sorts nearest first', () {
      // Customer at Laxmi Chowk (25.1337, 86.1772)
      const custLat = 25.1337;
      const custLng = 86.1772;

      // Shop A at 1 km away
      final distA = JamuiGeoValidator.calculateHaversineDistanceKm(custLat, custLng, 25.1400, 86.1800);
      // Shop B at 5 km away
      final distB = JamuiGeoValidator.calculateHaversineDistanceKm(custLat, custLng, 25.1700, 86.2000);

      expect(distA, isNotNull);
      expect(distB, isNotNull);
      expect(distA! < distB!, isTrue);
    });

    testWidgets('ProfessionalShopCard renders category, verified distance, and fulfillment chips', (tester) async {
      final shop = createTestShop(distanceKm: 1.8);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfessionalShopCard(shop: shop),
          ),
        ),
      );

      expect(find.text('Jamui Fresh Mart'), findsOneWidget);
      expect(find.textContaining('Grocery & Daily Needs'), findsOneWidget);
      expect(find.text('1.8 km'), findsOneWidget);
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
    });

    testWidgets('ProfessionalShopCard falls back gracefully when distance is null (Location Denied)', (tester) async {
      final shop = createTestShop(distanceKm: null, jamuiArea: 'Kachahari Road, Jamui');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfessionalShopCard(shop: shop),
          ),
        ),
      );

      expect(find.text('0.0 km'), findsNothing);
      expect(find.text('Kachahari Road, Jamui'), findsOneWidget);
    });
  });

  group('Phase 2G Screen 3: Professional Seller Details Page', () {
    testWidgets('Renders full shop metadata, pickup instructions, and "Shop Now" button', (tester) async {
      final shop = createTestShop(
        pickupInstructions: 'Pick up orders at front counter near entrance',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ProfessionalShopDetailsPage(shop: shop),
        ),
      );

      expect(find.text('Jamui Fresh Mart'), findsOneWidget);
      expect(find.text('Store Pickup Instructions'), findsOneWidget);
      expect(find.text('Pick up orders at front counter near entrance'), findsOneWidget);
      expect(find.text('Shop Now'), findsOneWidget);
    });
  });

  group('Phase 2G Screen 4: Mini Storefront & Dynamic Attributes', () {
    testWidgets('Product Details page renders dynamic Firestore attributes map', (tester) async {
      final shop = createTestShop();
      final product = createTestProduct(
        attributes: {
          'brand': 'Tata Sampann',
          'weight': '1 kg',
          'dietaryType': 'Vegetarian',
          'origin': 'India',
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider(
            create: (_) => ProfessionalCartBloc(),
            child: ProfessionalProductDetailsPage(shop: shop, product: product),
          ),
        ),
      );

      // Verify Product Specifications Card renders
      expect(find.text('Product Specifications'), findsOneWidget);
      expect(find.text('Brand'), findsOneWidget);
      expect(find.text('Tata Sampann'), findsOneWidget);
      expect(find.text('Dietary Type'), findsOneWidget);
      expect(find.text('Vegetarian'), findsOneWidget);
      expect(find.text('Origin'), findsOneWidget);
      expect(find.text('India'), findsOneWidget);
      expect(find.text('Pack / Unit'), findsOneWidget);
      expect(find.text('10 kg'), findsOneWidget);
    });

    test('ProfessionalProductEntity toMap and fromMap preserve attributes accurately', () {
      final prod = createTestProduct(
        attributes: {'fabric': 'Cotton 100%', 'warranty': '1 Year'},
      );
      final map = prod.toMap();
      final reconstructed = ProfessionalProductEntity.fromMap(map, 'prod_test', 'shop_101');

      expect(reconstructed.attributes['fabric'], 'Cotton 100%');
      expect(reconstructed.attributes['warranty'], '1 Year');
    });
  });

  group('Phase 2G Screen 5: Cart & Checkout Enforcement', () {
    test('Cart Bloc enforces single-shop isolation with conflict flag', () async {
      final bloc = ProfessionalCartBloc();
      final shopA = createTestShop(id: 'shop_A', shopName: 'Shop A');
      final shopB = createTestShop(id: 'shop_B', shopName: 'Shop B');
      final prodA = createTestProduct(id: 'p_1', shopId: 'shop_A');
      final prodB = createTestProduct(id: 'p_2', shopId: 'shop_B');

      // Add item from Shop A
      bloc.add(AddToCartEvent(shop: shopA, product: prodA));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.currentShop?.id, 'shop_A');
      expect(bloc.state.items.length, 1);
      expect(bloc.state.hasShopConflict, isFalse);

      // Try adding item from Shop B -> triggers conflict flag
      bloc.add(AddToCartEvent(shop: shopB, product: prodB));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.hasShopConflict, isTrue);
      expect(bloc.state.conflictingShop?.id, 'shop_B');

      // Confirm switch to Shop B
      bloc.add(ConfirmClearAndSwitchShopEvent(newShop: shopB, newProduct: prodB));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.currentShop?.id, 'shop_B');
      expect(bloc.state.items.length, 1);
      expect(bloc.state.items.first.product.id, 'p_2');
      expect(bloc.state.hasShopConflict, isFalse);
    });

    test('Cart State calculates delivery fee, free delivery threshold, and subtotal', () {
      final shop = createTestShop(
        deliveryCharges: 30.0,
        freeDeliveryThreshold: 500.0,
      );
      final prod = createTestProduct(sellingPrice: 200.0);

      final stateBelow = ProfessionalCartState(
        currentShop: shop,
        items: [CartItemModel(product: prod, quantity: 1)], // Total 200
        fulfillmentMode: 'delivery',
      );
      expect(stateBelow.subtotal, 200.0);
      expect(stateBelow.deliveryFee, 30.0);
      expect(stateBelow.grandTotal, 230.0);

      final stateAbove = ProfessionalCartState(
        currentShop: shop,
        items: [CartItemModel(product: prod, quantity: 3)], // Total 600 > 500 threshold
        fulfillmentMode: 'delivery',
      );
      expect(stateAbove.subtotal, 600.0);
      expect(stateAbove.deliveryFee, 0.0);
      expect(stateAbove.grandTotal, 600.0);

      final statePickup = ProfessionalCartState(
        currentShop: shop,
        items: [CartItemModel(product: prod, quantity: 1)],
        fulfillmentMode: 'pickup',
      );
      expect(statePickup.deliveryFee, 0.0);
    });
  });
}

