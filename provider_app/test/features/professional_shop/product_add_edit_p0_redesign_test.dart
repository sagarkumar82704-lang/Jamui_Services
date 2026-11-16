import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_provider/features/professional_shop/presentation/pages/professional_add_edit_product_page.dart';
import 'package:apna_jamui_provider/features/professional_shop/data/datasources/professional_provider_remote_data_source.dart';
import 'package:apna_jamui_provider/features/professional_shop/domain/entities/seller_store_category_entity.dart';
import 'package:apna_jamui_provider/features/professional_shop/domain/entities/professional_shop_profile_entity.dart';
import 'package:apna_jamui_provider/features/professional_shop/domain/entities/product_variant_entity.dart';

class MockP0RemoteDataSource extends Fake implements ProfessionalProviderRemoteDataSource {
  final Map<String, dynamic> savedProducts = {};
  final List<ProductVariantEntity> savedVariants = [];
  bool saveProductCalled = false;

  @override
  Stream<List<SellerStoreCategoryEntity>> streamStoreCategories(String shopId) {
    return Stream.value([
      const SellerStoreCategoryEntity(
        id: 'cat_grocery',
        shopId: 'shop_test',
        name: 'Grocery & Staples',
        nameHindi: 'किराना एवं आवश्यक वस्तुएं',
      ),
      const SellerStoreCategoryEntity(
        id: 'cat_snacks',
        shopId: 'shop_test',
        name: 'Snacks & Beverages',
        nameHindi: 'नाश्ता और पेय',
      ),
    ]);
  }

  @override
  Future<ProfessionalShopProfileEntity?> fetchShopProfile(String shopId) async {
    return ProfessionalShopProfileEntity(
      id: shopId,
      shopName: 'Test Shop',
      subscriptionPlanName: 'Pro Monthly',
      isSubscriptionActive: true,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> fetchShopProducts(String shopId) async {
    return [];
  }

  @override
  Future<List<ProductVariantEntity>> fetchProductVariants(String shopId, String productId) async {
    return savedVariants;
  }

  @override
  Future<String> saveProduct(
    String shopId,
    Map<String, dynamic> productData, {
    String? productId,
    double? costPrice,
    String? supplierName,
    String? purchaseNotes,
    num? initialStock,
    int? lowStockThreshold,
  }) async {
    saveProductCalled = true;
    final effectiveId = productId ?? 'prod_123';
    savedProducts[effectiveId] = {
      ...productData,
      'initialStock': initialStock,
      'costPrice': costPrice,
    };
    return effectiveId;
  }

  @override
  Future<String> saveProductVariant(
    String shopId,
    String productId,
    ProductVariantEntity variant, {
    double? costPrice,
    String? supplierName,
    String? purchaseNotes,
  }) async {
    savedVariants.add(variant);
    return variant.id.isNotEmpty ? variant.id : 'var_123';
  }
}

void main() {
  const shopId = 'shop_test_123';
  late MockP0RemoteDataSource mockDs;

  setUp(() {
    mockDs = MockP0RemoteDataSource();
  });

  Widget buildTestWidget({Map<String, dynamic>? existingProduct}) {
    return MaterialApp(
      home: ProfessionalAddEditProductPage(
        shopId: shopId,
        existingProduct: existingProduct,
        dataSource: mockDs,
      ),
    );
  }

  group('JAMUI SERVICES — PRODUCT ADD/EDIT P0 & UX REDESIGN TESTS', () {
    testWidgets('1. Renders 3 Seller-First Archetype Cards and Basic Details', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Basic Information
      expect(find.text('उत्पाद की मुख्य जानकारी (Basic Information)'), findsOneWidget);
      expect(find.byType(TextFormField), findsWidgets);

      // Archetype Cards
      expect(find.text('सामान का प्रकार'), findsOneWidget);
      expect(find.text('पैकेट / पीस'), findsOneWidget);
      expect(find.text('खुला सामान'), findsOneWidget);
      expect(find.text('साइज / अलग-अलग पैक'), findsOneWidget);
    });

    testWidgets('2. Piece/Packet Archetype Form fields and discrete unit dropdown', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap on Piece / Packet (already selected by default)
      await tester.tap(find.text('पैकेट / पीस'));
      await tester.pumpAndSettle();

      // Verify Piece/Packet fields
      expect(find.text('बिक्री मूल्य (प्रति पीस/पैकेट) *'), findsOneWidget);
      expect(find.text('दुकान में कुल उपलब्ध स्टॉक *'), findsOneWidget);
    });

    testWidgets('3. Loose Goods Archetype supports kg/L toggle and decimal stock', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap Loose Goods card
      await tester.tap(find.text('खुला सामान'));
      await tester.pumpAndSettle();

      // Verify kg and L toggles
      expect(find.text('किलोग्राम (kg)'), findsOneWidget);
      expect(find.text('लीटर (L)'), findsOneWidget);
      expect(find.text('प्रति किलो बिक्री मूल्य *'), findsOneWidget);
      expect(find.text('दुकान में कुल उपलब्ध स्टॉक (kg) *'), findsOneWidget);

      // Verify customer buying shortcuts
      expect(find.text('ग्राहकों के लिए आसान खरीद विकल्प'), findsOneWidget);
      expect(find.text('250 g (₹0)'), findsOneWidget);
      expect(find.text('500 g (₹0)'), findsOneWidget);
      expect(find.text('1 kg (₹0)'), findsOneWidget);

      // Switch to Litre
      await tester.tap(find.text('लीटर (L)'));
      await tester.pumpAndSettle();

      expect(find.text('प्रति लीटर बिक्री मूल्य *'), findsOneWidget);
      expect(find.text('250 ml (₹0)'), findsOneWidget);
      expect(find.text('500 ml (₹0)'), findsOneWidget);
      expect(find.text('1 L (₹0)'), findsOneWidget);
    });

    testWidgets('4. Sizes / Separate Packs Archetype allows adding options', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap Sizes card
      await tester.tap(find.text('साइज / अलग-अलग पैक'));
      await tester.pumpAndSettle();

      expect(find.text('+ नया विकल्प जोड़ें'), findsOneWidget);
      expect(find.text('Standard'), findsOneWidget); // Default initial option
    });

    testWidgets('5. Safe Edit Mode locks Archetype and directs stock edit to Inventory', (tester) async {
      final existingProduct = {
        'id': 'prod_rice_99',
        'titleEnglish': 'India Gate Basmati Rice',
        'storeCategoryId': 'cat_grocery',
        'storeCategoryName': 'Grocery & Staples',
        'unit': 'kg',
        'sellingPrice': 110.0,
        'regularPrice': 120.0,
        'stockType': 'bulk',
        'stockQuantity': 25.5,
        'hasVariants': true,
      };

      await tester.pumpWidget(buildTestWidget(existingProduct: existingProduct));
      await tester.pumpAndSettle();

      // Archetype selection is replaced with Locked indicator
      expect(find.text('Locked'), findsOneWidget);

      // Stock input is replaced with safe Inventory link
      expect(find.text('दुकान में कुल उपलब्ध स्टॉक: 25.5 kg'), findsOneWidget);
      expect(find.text('इन्वेंट्री में जाएं'), findsOneWidget);
    });

    testWidgets('6. Zero RenderFlex overflow on standard viewports (360x780, 390x844, 1366x768)', (tester) async {
      final viewports = [
        const Size(360, 780),
        const Size(390, 844),
        const Size(1366, 768),
      ];

      for (final vp in viewports) {
        tester.view.physicalSize = vp;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'Must have zero RenderFlex overflow on $vp');
      }
    });
  });
}
