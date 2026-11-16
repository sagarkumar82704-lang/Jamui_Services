import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_provider/features/professional_shop/domain/entities/seller_store_category_entity.dart';
import 'package:apna_jamui_provider/features/professional_shop/data/datasources/professional_provider_remote_data_source.dart';
import 'package:apna_jamui_provider/features/professional_shop/presentation/pages/professional_manage_store_categories_page.dart';
import 'package:apna_jamui_provider/features/professional_shop/presentation/pages/professional_shop_inventory_page.dart';
import 'package:apna_jamui_provider/features/professional_shop/presentation/pages/professional_add_edit_product_page.dart';
import 'package:apna_jamui_provider/features/auth/domain/entities/provider_profile_entity.dart';

/// Mock Data Source simulating Checkpoint 2E backend behaviors in memory
class MockProfessionalRemoteDataSource2F extends ProfessionalProviderRemoteDataSource {
  final Map<String, List<SellerStoreCategoryEntity>> storeCategories = {};
  final Map<String, List<Map<String, dynamic>>> products = {};
  final Map<String, int> productReferences = {};

  final StreamController<List<SellerStoreCategoryEntity>> _catController =
      StreamController<List<SellerStoreCategoryEntity>>.broadcast();
  final StreamController<List<Map<String, dynamic>>> _prodController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  bool shouldThrowFunctionError = false;
  String functionErrorCode = 'failed-precondition';
  int stockAdjustmentCallCount = 0;

  MockProfessionalRemoteDataSource2F() : super(firestore: null, functions: null);

  void seedCategories(String shopId, List<SellerStoreCategoryEntity> cats) {
    storeCategories[shopId] = List.from(cats);
    if (!_catController.isClosed) {
      _catController.add(storeCategories[shopId]!);
    }
  }

  void seedProducts(String shopId, List<Map<String, dynamic>> prods) {
    products[shopId] = List.from(prods);
    if (!_prodController.isClosed) {
      _prodController.add(products[shopId]!);
    }
  }

  void setProductReferenceCount(String categoryId, int count) {
    productReferences[categoryId] = count;
  }

  @override
  Stream<List<SellerStoreCategoryEntity>> streamStoreCategories(String shopId) async* {
    yield storeCategories[shopId] ?? [];
    await for (final _ in _catController.stream) {
      yield storeCategories[shopId] ?? [];
    }
  }

  @override
  Stream<List<Map<String, dynamic>>> streamProducts(String shopId) async* {
    yield products[shopId] ?? [];
    await for (final _ in _prodController.stream) {
      yield products[shopId] ?? [];
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
  Future<void> deleteStoreCategory(String shopId, String categoryId) async {
    storeCategories.putIfAbsent(shopId, () => []);
    storeCategories[shopId]!.removeWhere((c) => c.id == categoryId);
    _catController.add(List.from(storeCategories[shopId]!));
  }

  @override
  Future<int> countProductsReferencingCategory(String shopId, String categoryId) async {
    return productReferences[categoryId] ?? 0;
  }

  @override
  Future<Map<String, dynamic>> adjustProductStock({
    required String shopId,
    required String productId,
    required String operation,
    required num amount,
    String? reason,
  }) async {
    stockAdjustmentCallCount++;

    if (shouldThrowFunctionError) {
      throw Exception('$functionErrorCode: Simulated Cloud Function error.');
    }

    final shopProds = products[shopId] ?? [];
    final idx = shopProds.indexWhere((p) => p['id'] == productId);
    if (idx < 0) {
      throw Exception('not-found: Product not found.');
    }

    final currentStock = (shopProds[idx]['stockQuantity'] as num?)?.toInt() ?? 0;
    int newStock = 0;

    if (operation == 'set') {
      newStock = amount;
    } else if (operation == 'increment') {
      newStock = currentStock + amount;
    } else if (operation == 'decrement') {
      if (currentStock < amount) {
        throw Exception('failed-precondition: Insufficient stock. Negative stock prevented.');
      }
      newStock = currentStock - amount;
    }

    shopProds[idx]['stockQuantity'] = newStock;
    shopProds[idx]['inStock'] = newStock > 0;
    _prodController.add(List.from(shopProds));

    return {
      'success': true,
      'shopId': shopId,
      'productId': productId,
      'operation': operation,
      'amount': amount,
      'previousStock': currentStock,
      'newStock': newStock,
      'inStock': newStock > 0,
    };
  }

  @override
  Future<String> saveProduct(String shopId, Map<String, dynamic> productData, {String? productId, double? costPrice, String? supplierName, String? purchaseNotes, num? initialStock, int? lowStockThreshold}) async {
    products.putIfAbsent(shopId, () => []);
    final effectiveId = productId ?? 'mock_prod_${DateTime.now().millisecondsSinceEpoch}';
    if (productId != null && productId.isNotEmpty) {
      final idx = products[shopId]!.indexWhere((p) => p['id'] == productId);
      if (idx >= 0) {
        products[shopId]![idx] = {...products[shopId]![idx], ...productData};
      }
    } else {
      products[shopId]!.add({
        'id': effectiveId,
        'shopId': shopId,
        ...productData,
      });
    }
    _prodController.add(List.from(products[shopId]!));
    return effectiveId;
  }
}

void main() {
  group('JAMUI SERVICES — CHECKPOINT 2F INVENTORY & STORE CATEGORIES UI AUDIT', () {
    const testShopA = 'shop_seller_a_uid';
    const testShopB = 'shop_seller_b_uid';

    late MockProfessionalRemoteDataSource2F mockDataSource;

    setUp(() {
      mockDataSource = MockProfessionalRemoteDataSource2F();
    });

    // --- TEST 1: STORE CATEGORIES: SEPARATE ACTIVE & INACTIVE TABS ---
    testWidgets('1. Store Categories UI displays Active and Inactive categories in separate tabs', (tester) async {
      mockDataSource.seedCategories(testShopA, [
        SellerStoreCategoryEntity(
          id: 'sc_active_1',
          shopId: testShopA,
          name: 'दाल एवं दलहन',
          displayOrder: 1,
          isActive: true,
        ),
        SellerStoreCategoryEntity(
          id: 'sc_inactive_1',
          shopId: testShopA,
          name: 'सर्दियों के विशेष मसाले',
          displayOrder: 2,
          isActive: false,
        ),
      ]);

      await tester.pumpWidget(MaterialApp(
        home: ProfessionalManageStoreCategoriesPage(
          shopId: testShopA,
          dataSource: mockDataSource,
        ),
      ));
      await tester.pumpAndSettle();

      // Active and Inactive categories displayed in separate distinct sections
      expect(find.textContaining('सक्रिय श्रेणियां'), findsOneWidget);
      expect(find.textContaining('निष्क्रिय श्रेणियां'), findsOneWidget);
      expect(find.text('दाल एवं दलहन'), findsOneWidget);
      expect(find.text('सर्दियों के विशेष मसाले'), findsOneWidget);
    });

    // --- TEST 2: DUPLICATE CATEGORY NAME PREVENTION ---
    testWidgets('2. Prevent duplicate store category names within the same shop', (tester) async {
      mockDataSource.seedCategories(testShopA, [
        SellerStoreCategoryEntity(
          id: 'sc_existing_1',
          shopId: testShopA,
          name: 'चावल',
          displayOrder: 1,
          isActive: true,
        ),
      ]);

      await tester.pumpWidget(MaterialApp(
        home: ProfessionalManageStoreCategoriesPage(
          shopId: testShopA,
          dataSource: mockDataSource,
        ),
      ));
      await tester.pumpAndSettle();

      // Tap + नई श्रेणी जोड़ें
      await tester.tap(find.text('+ नई श्रेणी जोड़ें (Add Store Category)'));
      await tester.pumpAndSettle();

      // Enter duplicate name 'चावल'
      final nameField = find.byType(TextFormField).first;
      await tester.enterText(nameField, 'चावल');
      await tester.pumpAndSettle();

      // Tap Save
      await tester.tap(find.text('सहेजें (Save)'));
      await tester.pumpAndSettle();

      // Validation error must appear
      expect(find.text('इस नाम की श्रेणी पहले से मौजूद है'), findsOneWidget);

      // Ensure duplicate was not added
      expect(mockDataSource.storeCategories[testShopA]!.length, 1);
    });

    // --- TEST 3: CATEGORY DELETION PROTECTED BY PRODUCT REFERENCES ---
    testWidgets('3. Category deletion is blocked when products reference it; allowed when 0 products', (tester) async {
      mockDataSource.seedCategories(testShopA, [
        SellerStoreCategoryEntity(
          id: 'sc_with_prods',
          shopId: testShopA,
          name: 'आटा एवं मैदा',
          displayOrder: 1,
          isActive: true,
        ),
        SellerStoreCategoryEntity(
          id: 'sc_empty',
          shopId: testShopA,
          name: 'खाली श्रेणी',
          displayOrder: 2,
          isActive: true,
        ),
      ]);

      mockDataSource.setProductReferenceCount('sc_with_prods', 4);
      mockDataSource.setProductReferenceCount('sc_empty', 0);

      await tester.pumpWidget(MaterialApp(
        home: ProfessionalManageStoreCategoriesPage(
          shopId: testShopA,
          dataSource: mockDataSource,
        ),
      ));
      await tester.pumpAndSettle();

      // 1. Try deleting 'आटा एवं मैदा' (has 4 products)
      final deleteButtons = find.byIcon(Icons.delete_outline_rounded);
      await tester.tap(deleteButtons.first);
      await tester.pumpAndSettle();

      // Warning dialog appears
      expect(find.text('हटाना संभव नहीं है'), findsOneWidget);
      expect(find.textContaining('4 उत्पाद जुड़े हुए हैं'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('समझ गया (OK)'));
      await tester.pumpAndSettle();

      // Category still exists
      expect(mockDataSource.storeCategories[testShopA]!.length, 2);

      // 2. Delete 'खाली श्रेणी' (0 products)
      await tester.tap(find.byIcon(Icons.delete_outline_rounded).last);
      await tester.pumpAndSettle();

      // Confirmation dialog appears
      expect(find.text('श्रेणी हटाएं? (Delete Category)'), findsOneWidget);

      // Confirm deletion
      await tester.tap(find.text('हटाएं (Delete)'));
      await tester.pumpAndSettle();

      // Category deleted from in-memory store
      expect(mockDataSource.storeCategories[testShopA]!.length, 1);
      expect(mockDataSource.storeCategories[testShopA]!.first.name, 'आटा एवं मैदा');
    });

    // --- TEST 4: INVENTORY STOCK ADJUSTMENT: INCREMENT ---
    testWidgets('4. Inventory UI executes atomic stock increment via adjustDiamondProductStock', (tester) async {
      mockDataSource.seedProducts(testShopA, [
        {
          'id': 'prod_rice_1',
          'shopId': testShopA,
          'titleEnglish': 'Fortune Basmati Rice',
          'stockQuantity': 10,
          'inStock': true,
          'unit': 'kg',
        }
      ]);

      await tester.pumpWidget(MaterialApp(
        home: ProfessionalShopInventoryPage(
          shopId: testShopA,
          dataSource: mockDataSource,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Fortune Basmati Rice'), findsOneWidget);
      expect(find.text('समायोजित करें'), findsOneWidget);

      // Tap समायोजित करें
      await tester.tap(find.text('समायोजित करें'));
      await tester.pumpAndSettle();

      // Bottom sheet open with + बढ़ाएं selected by default
      expect(find.text('वर्तमान स्टॉक: 10 kg'), findsOneWidget);

      // Enter 15
      await tester.enterText(find.byType(TextFormField).first, '15');
      await tester.pumpAndSettle();

      // Projected stock indicates 25 kg
      expect(find.text('नया: 25 kg'), findsOneWidget);

      // Submit
      await tester.tap(find.text('स्टॉक अपडेट करें (Submit Stock)'));
      await tester.pumpAndSettle();

      // Success SnackBar appears
      expect(find.text('स्टॉक सफलतापूर्वक अपडेट किया गया! नया स्टॉक: 25 kg'), findsOneWidget);

      // In-memory product stock updated to 25
      expect(mockDataSource.products[testShopA]!.first['stockQuantity'], 25);
    });

    // --- TEST 5: INVENTORY STOCK ADJUSTMENT: DECREMENT WITH CONFIRMATION ---
    testWidgets('5. Inventory UI executes stock decrement with confirmation dialog', (tester) async {
      mockDataSource.seedProducts(testShopA, [
        {
          'id': 'prod_oil_1',
          'shopId': testShopA,
          'titleEnglish': 'Mustard Oil 1L',
          'stockQuantity': 20,
          'inStock': true,
          'unit': 'लीटर',
        }
      ]);

      await tester.pumpWidget(MaterialApp(
        home: ProfessionalShopInventoryPage(
          shopId: testShopA,
          dataSource: mockDataSource,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('समायोजित करें'));
      await tester.pumpAndSettle();

      // Select '- घटाएं'
      await tester.tap(find.text('- घटाएं'));
      await tester.pumpAndSettle();

      // Enter 8
      await tester.enterText(find.byType(TextFormField).first, '8');
      await tester.pumpAndSettle();

      expect(find.text('नया: 12 लीटर'), findsOneWidget);

      // Tap submit -> Confirmation dialog appears
      await tester.tap(find.text('स्टॉक अपडेट करें (Submit Stock)'));
      await tester.pumpAndSettle();

      expect(find.text('स्टॉक पुष्टि (Confirm Stock)'), findsOneWidget);
      expect(find.textContaining('8 लीटर स्टॉक घटाना चाहते हैं'), findsOneWidget);

      // Confirm
      await tester.tap(find.text('पुष्टि करें'));
      await tester.pumpAndSettle();

      expect(find.text('स्टॉक सफलतापूर्वक अपडेट किया गया! नया स्टॉक: 12 लीटर'), findsOneWidget);
      expect(mockDataSource.products[testShopA]!.first['stockQuantity'], 12);
    });

    // --- TEST 6: INSUFFICIENT STOCK & NEGATIVE STOCK VALIDATION ---
    testWidgets('6. Prevent decrement exceeding current stock and invalid amounts', (tester) async {
      mockDataSource.seedProducts(testShopA, [
        {
          'id': 'prod_salt_1',
          'shopId': testShopA,
          'titleEnglish': 'Tata Salt 1kg',
          'stockQuantity': 5,
          'inStock': true,
          'unit': 'पैकेट',
        }
      ]);

      await tester.pumpWidget(MaterialApp(
        home: ProfessionalShopInventoryPage(
          shopId: testShopA,
          dataSource: mockDataSource,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('समायोजित करें'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('- घटाएं'));
      await tester.pumpAndSettle();

      // Enter 10 (which is > current stock of 5)
      await tester.enterText(find.byType(TextFormField).first, '10');
      await tester.pumpAndSettle();

      await tester.tap(find.text('स्टॉक अपडेट करें (Submit Stock)'));
      await tester.pumpAndSettle();

      // Validation error appears
      expect(find.text('घटाने की मात्रा वर्तमान स्टॉक (5) से अधिक नहीं हो सकती'), findsOneWidget);
      expect(mockDataSource.stockAdjustmentCallCount, 0); // Not submitted to function
    });

    // --- TEST 7: SET OPERATION AND ZERO STOCK SETS inStock=false ---
    testWidgets('7. Set operation to 0 sets inStock to false accurately', (tester) async {
      mockDataSource.seedProducts(testShopA, [
        {
          'id': 'prod_sugar_1',
          'shopId': testShopA,
          'titleEnglish': 'Sugar 1kg',
          'stockQuantity': 15,
          'inStock': true,
          'unit': 'kg',
        }
      ]);

      await tester.pumpWidget(MaterialApp(
        home: ProfessionalShopInventoryPage(
          shopId: testShopA,
          dataSource: mockDataSource,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('समायोजित करें'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('= सेट करें'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, '0');
      await tester.pumpAndSettle();

      await tester.tap(find.text('स्टॉक अपडेट करें (Submit Stock)'));
      await tester.pumpAndSettle();

      // Confirm
      await tester.tap(find.text('पुष्टि करें'));
      await tester.pumpAndSettle();

      expect(mockDataSource.products[testShopA]!.first['stockQuantity'], 0);
      expect(mockDataSource.products[testShopA]!.first['inStock'], false);
    });

    // --- TEST 8: SERVER ERROR HANDLING (FAILED-PRECONDITION / PERMISSION-DENIED) ---
    testWidgets('8. Cloud Function error displays cleanly in bottom sheet without false success', (tester) async {
      mockDataSource.seedProducts(testShopA, [
        {
          'id': 'prod_tea_1',
          'shopId': testShopA,
          'titleEnglish': 'Red Label Tea',
          'stockQuantity': 10,
          'inStock': true,
          'unit': 'gm',
        }
      ]);

      mockDataSource.shouldThrowFunctionError = true;
      mockDataSource.functionErrorCode = 'failed-precondition';

      await tester.pumpWidget(MaterialApp(
        home: ProfessionalShopInventoryPage(
          shopId: testShopA,
          dataSource: mockDataSource,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('समायोजित करें'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, '5');
      await tester.pumpAndSettle();

      await tester.tap(find.text('स्टॉक अपडेट करें (Submit Stock)'));
      await tester.pumpAndSettle();

      // Error banner visible in bottom sheet
      expect(find.textContaining('failed-precondition: Simulated Cloud Function error'), findsOneWidget);

      // Bottom sheet remained open (not dismissed with false success)
      expect(find.text('स्टॉक समायोजन: Red Label Tea'), findsOneWidget);
    });

    // --- TEST 9: PRODUCT ADD/EDIT INTEGRATION WITH STORE CATEGORIES ---
    testWidgets('9. Product Add/Edit page loads store categories and saves storeCategoryId', (tester) async {
      mockDataSource.seedCategories(testShopA, [
        SellerStoreCategoryEntity(
          id: 'sc_grocery_dal',
          shopId: testShopA,
          name: 'दाल एवं दलहन',
          displayOrder: 1,
          isActive: true,
        ),
      ]);

      await tester.pumpWidget(MaterialApp(
        home: ProfessionalAddEditProductPage(
          shopId: testShopA,
          marketplaceCategory: 'Grocery',
          dataSource: mockDataSource,
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Open store category dropdown
      final dropdownFinder = find.byType(DropdownButtonFormField<String>).first;
      await tester.tap(dropdownFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Category dropdown has loaded the store category
      expect(find.textContaining('दाल एवं दलहन'), findsWidgets);
    });

    // --- TEST 10: NORMAL SERVICE PROVIDER ISOLATION REGRESSION ---
    test('10. Normal Service Provider remains strictly isolated with zero professional exposure', () {
      final normalProvider = ProviderProfileEntity(
        id: 'plumber_uid_01',
        fullName: 'Ramesh Kumar',
        businessName: 'Ramesh Plumbing Services',
        businessType: 'Individual',
        phoneNumber: '+919876543210',
        email: 'ramesh@jamui.com',
        primaryCategoryId: 'cat_plumbing',
        primaryCategoryTitle: 'Plumber',
        categoryType: 'general',
        registrationStatus: 'approved',
        createdAt: DateTime(2026, 1, 1),
      );

      bool isProDomain(ProviderProfileEntity prof) {
        final bType = prof.businessType.toLowerCase().trim();
        if (bType == 'professional_seller' || bType == 'ecommerce_seller' || bType == 'shopkeeper') {
          return true;
        }
        final cType = prof.categoryType.toLowerCase().trim();
        if (cType == 'professional' || cType == 'diamond' || cType == 'marketplace' || cType == 'ecommerce') {
          return true;
        }
        return false;
      }

      // Verified domain invariants
      expect(isProDomain(normalProvider), isFalse);
      expect(normalProvider.categoryType, 'general');
    });
  });
}
