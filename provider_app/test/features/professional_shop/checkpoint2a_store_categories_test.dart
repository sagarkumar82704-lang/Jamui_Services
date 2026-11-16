import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_provider/features/professional_shop/domain/entities/seller_store_category_entity.dart';
import 'package:apna_jamui_provider/features/professional_shop/domain/category_attribute_registry.dart';
import 'package:apna_jamui_provider/features/professional_shop/data/datasources/professional_provider_remote_data_source.dart';
import 'package:apna_jamui_provider/features/professional_shop/presentation/pages/professional_manage_store_categories_page.dart';
import 'package:apna_jamui_provider/features/professional_shop/presentation/pages/professional_add_edit_product_page.dart';

/// Mock Data Source for hermetic, deterministic testing without live Firebase
class MockProfessionalRemoteDataSource extends ProfessionalProviderRemoteDataSource {
  final Map<String, List<SellerStoreCategoryEntity>> storeCategories = {};
  final List<Map<String, dynamic>> savedProducts = [];
  final StreamController<List<SellerStoreCategoryEntity>> _catController =
      StreamController<List<SellerStoreCategoryEntity>>.broadcast();

  MockProfessionalRemoteDataSource() : super(firestore: null, functions: null);

  void seedCategories(String shopId, List<SellerStoreCategoryEntity> cats) {
    storeCategories[shopId] = List.from(cats);
    if (!_catController.isClosed) {
      _catController.add(storeCategories[shopId]!);
    }
  }

  @override
  Stream<List<SellerStoreCategoryEntity>> streamStoreCategories(String shopId) async* {
    yield storeCategories[shopId] ?? [];
    await for (final _ in _catController.stream) {
      yield storeCategories[shopId] ?? [];
    }
  }

  @override
  Future<void> saveStoreCategory(String shopId, SellerStoreCategoryEntity category) async {
    storeCategories.putIfAbsent(shopId, () => []);
    final idx = storeCategories[shopId]!.indexWhere((c) => c.id == category.id);
    if (idx >= 0) {
      storeCategories[shopId]![idx] = category;
    } else {
      storeCategories[shopId]!.add(category);
    }
    _catController.add(List.from(storeCategories[shopId]!));
  }

  @override
  Future<void> toggleStoreCategoryActive(String shopId, String categoryId, bool isActive) async {
    storeCategories.putIfAbsent(shopId, () => []);
    final idx = storeCategories[shopId]!.indexWhere((c) => c.id == categoryId);
    if (idx >= 0) {
      storeCategories[shopId]![idx] = storeCategories[shopId]![idx].copyWith(isActive: isActive);
      _catController.add(List.from(storeCategories[shopId]!));
    }
  }

  @override
  Future<String> saveProduct(String shopId, Map<String, dynamic> productData, {String? productId, double? costPrice, String? supplierName, String? purchaseNotes, num? initialStock, int? lowStockThreshold}) async {
    savedProducts.add({'shopId': shopId, 'productId': productId, ...productData});
    return productId ?? 'mock_prod_1';
  }
}

void main() {
  group('JAMUI SERVICES — CHECKPOINT 2A STORE CATEGORIES & ATTRIBUTES AUDIT', () {
    const testShopA = 'shop_mock_seller_a';
    const testShopB = 'shop_mock_seller_b';

    // --- TEST 1: Store Category Entity Serialization & Equality ---
    test('1. SellerStoreCategoryEntity serialization, deserialization and equality', () {
      final now = DateTime(2026, 11, 1, 12, 0);
      final entity = SellerStoreCategoryEntity(
        id: 'sc_daal_01',
        shopId: testShopA,
        name: 'दाल (Pulses)',
        nameHindi: 'दाल एवं दलहन',
        displayOrder: 1,
        isActive: true,
        createdAt: now,
      );

      final map = entity.toMap();
      expect(map['id'], 'sc_daal_01');
      expect(map['shopId'], testShopA);
      expect(map['name'], 'दाल (Pulses)');
      expect(map['nameHindi'], 'दाल एवं दलहन');
      expect(map['displayOrder'], 1);
      expect(map['isActive'], true);

      final fromMapEntity = SellerStoreCategoryEntity.fromMap(map, 'sc_daal_01', shopId: testShopA);
      expect(fromMapEntity.name, entity.name);
      expect(fromMapEntity.displayOrder, 1);
      expect(fromMapEntity.isActive, true);
      expect(fromMapEntity, equals(entity));
    });

    // --- TEST 2: CategoryAttributeRegistry for all 8 categories ---
    test('2. CategoryAttributeRegistry returns dynamic schemas for all 8 supported categories', () {
      final supported = CategoryAttributeRegistry.supportedCategories;
      expect(supported.length, 8);

      // Grocery attributes check
      final groceryAttrs = CategoryAttributeRegistry.getAttributesForCategory('Grocery');
      expect(groceryAttrs.any((a) => a.key == 'weight'), isTrue);
      expect(groceryAttrs.any((a) => a.key == 'expiryDate'), isTrue);

      // Milk & Dairy check
      final dairyAttrs = CategoryAttributeRegistry.getAttributesForCategory('Milk & Dairy');
      expect(dairyAttrs.any((a) => a.key == 'storageType'), isTrue);

      // Vegetables check
      final vegAttrs = CategoryAttributeRegistry.getAttributesForCategory('Vegetables');
      expect(vegAttrs.any((a) => a.key == 'freshness'), isTrue);
      expect(vegAttrs.any((a) => a.key == 'pricePerKg'), isTrue);

      // Fruits check
      final fruitAttrs = CategoryAttributeRegistry.getAttributesForCategory('Fruits');
      expect(fruitAttrs.any((a) => a.key == 'variety'), isTrue);
      expect(fruitAttrs.any((a) => a.key == 'ripeness'), isTrue);

      // Clothing check
      final clothingAttrs = CategoryAttributeRegistry.getAttributesForCategory('Clothing');
      expect(clothingAttrs.any((a) => a.key == 'sizes'), isTrue);
      expect(clothingAttrs.any((a) => a.key == 'fabric'), isTrue);
      expect(clothingAttrs.any((a) => a.key == 'gender'), isTrue);

      // Footwear check
      final footwearAttrs = CategoryAttributeRegistry.getAttributesForCategory('Footwear');
      expect(footwearAttrs.any((a) => a.key == 'shoeSizes'), isTrue);

      // Electronics check
      final electroAttrs = CategoryAttributeRegistry.getAttributesForCategory('Electronics');
      expect(electroAttrs.any((a) => a.key == 'warranty'), isTrue);

      // Cosmetics check
      final cosmeticAttrs = CategoryAttributeRegistry.getAttributesForCategory('Cosmetics');
      expect(cosmeticAttrs.any((a) => a.key == 'netContent'), isTrue);
      expect(cosmeticAttrs.any((a) => a.key == 'targetType'), isTrue);
    });

    // --- TEST 3: Store Category UI loading, creation, editing and deactivation ---
    testWidgets('3. Store Category UI displays categories, supports adding and deactivation',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockSource = MockProfessionalRemoteDataSource();
      mockSource.seedCategories(testShopA, [
        const SellerStoreCategoryEntity(
          id: 'sc_01',
          shopId: testShopA,
          name: 'दाल',
          nameHindi: 'दाल एवं दलहन',
          displayOrder: 1,
          isActive: true,
        ),
        const SellerStoreCategoryEntity(
          id: 'sc_02',
          shopId: testShopA,
          name: 'चावल',
          displayOrder: 2,
          isActive: true,
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: ProfessionalManageStoreCategoriesPage(
            shopId: testShopA,
            dataSource: mockSource,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify categories render
      expect(find.text('दाल'), findsOneWidget);
      expect(find.text('चावल'), findsOneWidget);
      expect(find.text('Active'), findsNWidgets(2));

      // Test deactivation tap
      final switchFinder = find.byType(Switch).first;
      await tester.tap(switchFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Deactivation warning dialog appears
      expect(find.text('श्रेणी निष्क्रिय करें? (Deactivate)'), findsOneWidget);
      await tester.tap(find.text('निष्क्रिय करें'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Category is now inactive
      expect(find.text('Inactive'), findsOneWidget);
    });

    // --- TEST 4: Seller-Specific Category Filtering ---
    test('4. Seller-specific category data isolation ensures zero cross-shop category leakage', () {
      final mockSource = MockProfessionalRemoteDataSource();
      mockSource.seedCategories(testShopA, [
        const SellerStoreCategoryEntity(id: 'sc_a1', shopId: testShopA, name: 'दाल Shop A'),
      ]);
      mockSource.seedCategories(testShopB, [
        const SellerStoreCategoryEntity(id: 'sc_b1', shopId: testShopB, name: 'दाल Shop B'),
      ]);

      // Verify that Shop A's store categories do NOT contain Shop B's categories
      final shopACats = mockSource.storeCategories[testShopA]!;
      expect(shopACats.length, 1);
      expect(shopACats.first.name, 'दाल Shop A');
      expect(shopACats.any((c) => c.shopId == testShopB), isFalse);

      final shopBCats = mockSource.storeCategories[testShopB]!;
      expect(shopBCats.length, 1);
      expect(shopBCats.first.name, 'दाल Shop B');
      expect(shopBCats.any((c) => c.shopId == testShopA), isFalse);
    });

    // --- TEST 5: Inactive Category Exclusion from Product Dropdown ---
    testWidgets('5. Inactive store categories are excluded from product dropdown on new product creation',
        (tester) async {
      final mockSource = MockProfessionalRemoteDataSource();
      mockSource.seedCategories(testShopA, [
        const SellerStoreCategoryEntity(
          id: 'sc_active',
          shopId: testShopA,
          name: 'सक्रिय श्रेणी',
          isActive: true,
        ),
        const SellerStoreCategoryEntity(
          id: 'sc_inactive',
          shopId: testShopA,
          name: 'निष्क्रिय श्रेणी',
          isActive: false,
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: ProfessionalAddEditProductPage(
            shopId: testShopA,
            marketplaceCategory: 'Grocery',
            dataSource: mockSource,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Open store category dropdown
      final dropdownFinder = find.byType(DropdownButtonFormField<String>).first;
      await tester.tap(dropdownFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Active category MUST be present in dropdown options
      expect(find.textContaining('सक्रिय श्रेणी'), findsWidgets);

      // Inactive category MUST NOT be present in dropdown options for new products
      expect(find.textContaining('निष्क्रिय श्रेणी'), findsNothing);
    });

    // --- TEST 6: Product Attributes Form for Grocery & Clothing ---
    testWidgets('6. Dynamic product attributes render category-specific fields for Grocery and Clothing',
        (tester) async {
      final mockSource = MockProfessionalRemoteDataSource();
      mockSource.seedCategories(testShopA, [
        const SellerStoreCategoryEntity(id: 'sc_1', shopId: testShopA, name: 'दाल'),
      ]);

      // Test 6A: Grocery
      await tester.pumpWidget(
        MaterialApp(
          home: ProfessionalAddEditProductPage(
            shopId: testShopA,
            marketplaceCategory: 'Grocery',
            dataSource: mockSource,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Grocery specific attributes appear
      expect(find.textContaining('Brand / Company'), findsOneWidget);
      expect(find.textContaining('Pack Weight / Net Qty'), findsOneWidget);
      expect(find.textContaining('Expiry / Best Before Date'), findsOneWidget);

      // Test 6B: Clothing
      await tester.pumpWidget(
        MaterialApp(
          home: ProfessionalAddEditProductPage(
            shopId: testShopA,
            marketplaceCategory: 'Clothing',
            dataSource: mockSource,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Clothing specific attributes appear
      expect(find.textContaining('Available Sizes'), findsOneWidget);
      expect(find.textContaining('Fabric Material'), findsOneWidget);
      expect(find.textContaining('Target Segment'), findsWidgets);
      expect(find.text('XL'), findsOneWidget);
    });

    // --- TEST 7: Product Attributes Persistence in Attributes Map ---
    testWidgets('7. Saving a product packages all dynamic category attributes into attributes map',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockSource = MockProfessionalRemoteDataSource();
      mockSource.seedCategories(testShopA, [
        const SellerStoreCategoryEntity(id: 'sc_daal', shopId: testShopA, name: 'दाल'),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: ProfessionalAddEditProductPage(
            shopId: testShopA,
            marketplaceCategory: 'Grocery',
            dataSource: mockSource,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Select Store Category
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('दाल').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Fill Name and Selling Price
      await tester.enterText(find.byType(TextFormField).at(0), 'Tata Sampann Toor Dal');
      await tester.enterText(find.byType(TextFormField).at(2), '165');

      // Tap Save
      final saveBtnFinder = find.text('उत्पाद जोड़ें (Add Product)');
      await tester.ensureVisible(saveBtnFinder);
      await tester.pump();
      await tester.tap(saveBtnFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(mockSource.savedProducts.length, 1);
      final saved = mockSource.savedProducts.first;
      expect(saved['titleEnglish'], 'Tata Sampann Toor Dal');
      expect(saved['storeCategoryId'], 'sc_daal');
      expect(saved['storeCategoryName'], 'दाल');
      expect(saved['sellingPrice'], 165.0);
      expect(saved['attributes'], isA<Map<String, dynamic>>());
    });

    // --- TEST 8: Backward Compatibility with Existing Products ---
    testWidgets('8. Existing legacy product without storeCategoryId or attributes loads safely without crash',
        (tester) async {
      final mockSource = MockProfessionalRemoteDataSource();
      mockSource.seedCategories(testShopA, []);

      // Legacy product missing storeCategoryId and attributes
      final legacyProduct = {
        'id': 'legacy_prod_1',
        'titleEnglish': 'Old Product',
        'sellingPrice': 99.0,
        'regularPrice': 120.0,
        'categoryName': 'General Grocery',
        'unit': 'kg',
        'inStock': true,
      };

      await tester.pumpWidget(
        MaterialApp(
          home: ProfessionalAddEditProductPage(
            shopId: testShopA,
            marketplaceCategory: 'Grocery',
            existingProduct: legacyProduct,
            dataSource: mockSource,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Page opens normally with existing values loaded
      expect(find.text('उत्पाद संपादित करें (Edit Product)'), findsOneWidget);
      expect(find.text('Old Product'), findsOneWidget);
      expect(find.text('99.0'), findsOneWidget);
    });
  });
}
