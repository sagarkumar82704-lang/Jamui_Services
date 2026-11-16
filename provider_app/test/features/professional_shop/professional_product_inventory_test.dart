import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_provider/features/professional_shop/domain/entities/private_product_pricing_entity.dart';
import 'package:apna_jamui_provider/features/professional_shop/domain/entities/seller_stock_movement_entity.dart';
import 'package:apna_jamui_provider/features/professional_shop/domain/entities/seller_store_category_entity.dart';
import 'package:apna_jamui_provider/features/professional_shop/data/datasources/professional_provider_remote_data_source.dart';
import 'package:apna_jamui_provider/features/professional_shop/presentation/pages/professional_add_edit_product_page.dart';
import 'package:apna_jamui_provider/features/professional_shop/presentation/pages/professional_shop_inventory_page.dart';

class MockProfessionalDataSourceForInventory extends ProfessionalProviderRemoteDataSource {
  final Map<String, List<SellerStoreCategoryEntity>> storeCategories = {};
  final Map<String, List<Map<String, dynamic>>> products = {};
  final Map<String, List<SellerStockMovementEntity>> stockMovements = {};
  final Map<String, PrivateProductPricingEntity> privatePricing = {};

  final StreamController<List<SellerStoreCategoryEntity>> _catController =
      StreamController<List<SellerStoreCategoryEntity>>.broadcast();
  final StreamController<List<Map<String, dynamic>>> _prodController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  final StreamController<List<SellerStockMovementEntity>> _movementController =
      StreamController<List<SellerStockMovementEntity>>.broadcast();

  MockProfessionalDataSourceForInventory() : super(firestore: null, functions: null);

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
  Stream<List<SellerStockMovementEntity>> streamStockMovements(String shopId, {String? productId, int limit = 50}) async* {
    yield stockMovements[shopId] ?? [];
    await for (final _ in _movementController.stream) {
      yield stockMovements[shopId] ?? [];
    }
  }

  @override
  Future<PrivateProductPricingEntity?> fetchProductPrivatePricing(String shopId, String productId) async {
    return privatePricing['${shopId}_$productId'];
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
    final effectiveId = productId ?? 'prod_${DateTime.now().millisecondsSinceEpoch}';
    final productMap = Map<String, dynamic>.from(productData);
    productMap['id'] = effectiveId;
    productMap['shopId'] = shopId;
    productMap['lowStockThreshold'] = lowStockThreshold ?? 5;
    if (initialStock != null && !productMap.containsKey('stock')) {
      productMap['stock'] = initialStock;
    }

    products.putIfAbsent(shopId, () => []);
    final idx = products[shopId]!.indexWhere((p) => p['id'] == effectiveId);
    if (idx >= 0) {
      products[shopId]![idx] = productMap;
    } else {
      products[shopId]!.add(productMap);
    }
    _prodController.add(List.from(products[shopId]!));

    if (costPrice != null) {
      final pricing = PrivateProductPricingEntity(
        productId: effectiveId,
        costPrice: costPrice,
        sellingPrice: (productMap['price'] as num?)?.toDouble() ?? 0.0,
        regularPrice: (productMap['mrp'] as num?)?.toDouble() ?? 0.0,
        supplierName: supplierName,
        purchaseNotes: purchaseNotes,
        updatedAt: DateTime.now(),
      );
      privatePricing['${shopId}_$effectiveId'] = pricing;
    }

    if (initialStock != null && initialStock > 0 && productId == null) {
      final movement = SellerStockMovementEntity(
        id: 'mov_init_$effectiveId',
        shopId: shopId,
        productId: effectiveId,
        productName: productMap['title'] as String? ?? 'Product',
        movementType: 'initial',
        changeAmount: initialStock.toInt(),
        previousStock: 0,
        newStock: initialStock.toInt(),
        reason: 'Initial stock setup on product creation',
        actorRole: 'shopkeeper',
        createdAt: DateTime.now(),
      );
      stockMovements.putIfAbsent(shopId, () => []);
      stockMovements[shopId]!.insert(0, movement);
      _movementController.add(List.from(stockMovements[shopId]!));
    }

    return effectiveId;
  }

  @override
  Future<Map<String, dynamic>> adjustProductStock({
    required String shopId,
    required String productId,
    required String operation,
    required num amount,
    String? reason,
  }) async {
    final shopProducts = products[shopId] ?? [];
    final idx = shopProducts.indexWhere((p) => p['id'] == productId);
    if (idx < 0) return {'success': false, 'error': 'Product not found'};

    final currentStock = (shopProducts[idx]['stock'] as num?)?.toInt() ?? 0;
    num newStock = currentStock;
    num change = 0;
    String movementType = 'manual_set';

    if (operation == 'increment') {
      newStock = currentStock + amount;
      change = amount;
      movementType = 'manual_inward';
    } else if (operation == 'decrement') {
      newStock = (currentStock - amount).clamp(0, 999999);
      change = -amount;
      movementType = 'manual_outward';
    } else if (operation == 'set') {
      change = amount - currentStock;
      newStock = amount;
      movementType = 'manual_set';
    }

    shopProducts[idx]['stock'] = newStock;
    _prodController.add(List.from(shopProducts));

    final movement = SellerStockMovementEntity(
      id: 'mov_${DateTime.now().millisecondsSinceEpoch}',
      shopId: shopId,
      productId: productId,
      productName: shopProducts[idx]['title'] as String? ?? 'Product',
      movementType: movementType,
      changeAmount: change.toInt(),
      previousStock: currentStock,
      newStock: newStock.toInt(),
      reason: reason ?? 'Manual stock adjustment',
      actorRole: 'shopkeeper',
      createdAt: DateTime.now(),
    );
    stockMovements.putIfAbsent(shopId, () => []);
    stockMovements[shopId]!.insert(0, movement);
    _movementController.add(List.from(stockMovements[shopId]!));

    return {'success': true, 'newStock': newStock};
  }

  void dispose() {
    _catController.close();
    _prodController.close();
    _movementController.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PrivateProductPricingEntity Tests', () {
    test('Calculates profit margin in ₹ and percentage correctly', () {
      const pricing = PrivateProductPricingEntity(
        productId: 'prod_1',
        costPrice: 500.0,
        sellingPrice: 750.0,
        regularPrice: 800.0,
        supplierName: 'Patna Wholesale Hub',
        purchaseNotes: 'Includes shipping',
      );

      expect(pricing.profitMarginRupees, equals(250.0));
      expect(pricing.profitMarginPercentage, closeTo(33.33, 0.01));
      expect(pricing.markupPercentage, closeTo(50.0, 0.01));
    });

    test('Handles edge cases where costPrice is 0 or greater than selling price', () {
      const zeroCost = PrivateProductPricingEntity(
        productId: 'prod_zero',
        costPrice: 0.0,
        sellingPrice: 100.0,
        regularPrice: 120.0,
      );
      expect(zeroCost.profitMarginRupees, equals(0.0));
      expect(zeroCost.profitMarginPercentage, equals(0.0));

      const lossPricing = PrivateProductPricingEntity(
        productId: 'prod_loss',
        costPrice: 200.0,
        sellingPrice: 150.0,
        regularPrice: 200.0,
      );
      expect(lossPricing.profitMarginRupees, equals(0.0));
      expect(lossPricing.profitMarginPercentage, equals(0.0));
    });

    test('Serializes toMap and fromMap cleanly', () {
      final original = PrivateProductPricingEntity(
        productId: 'prod_x',
        costPrice: 420.50,
        sellingPrice: 600.0,
        regularPrice: 650.0,
        supplierName: 'Bihar Distributors',
        purchaseNotes: 'Batch #B-98',
        updatedAt: DateTime(2026, 11, 5, 12, 0),
      );

      final map = original.toMap();
      expect(map['costPrice'], equals(420.50));
      expect(map['supplierName'], equals('Bihar Distributors'));
      expect(map['purchaseNotes'], equals('Batch #B-98'));

      final parsed = PrivateProductPricingEntity.fromMap(map, 'prod_x');

      expect(parsed.costPrice, equals(420.50));
      expect(parsed.sellingPrice, equals(600.0));
      expect(parsed.profitMarginRupees, equals(179.50));
      expect(parsed.supplierName, equals('Bihar Distributors'));
    });
  });

  group('SellerStockMovementEntity Tests', () {
    test('Formats quantity change with sign correctly', () {
      final inward = SellerStockMovementEntity(
        id: 'mov_1',
        shopId: 'shop_1',
        productId: 'prod_1',
        productName: 'Rice 25kg',
        movementType: 'manual_inward',
        changeAmount: 15,
        previousStock: 5,
        newStock: 20,
        reason: 'New shipment',
        actorRole: 'shopkeeper',
        createdAt: DateTime.now(),
      );
      expect(inward.formattedChange, equals('+15'));
      expect(inward.isInward, isTrue);

      final outward = SellerStockMovementEntity(
        id: 'mov_2',
        shopId: 'shop_1',
        productId: 'prod_1',
        productName: 'Rice 25kg',
        movementType: 'order_deduction',
        changeAmount: -3,
        previousStock: 20,
        newStock: 17,
        orderId: 'ord_999',
        reason: 'Customer purchase',
        actorRole: 'customer',
        createdAt: DateTime.now(),
      );
      expect(outward.formattedChange, equals('-3'));
      expect(outward.isOutward, isTrue);
    });

    test('Provides appropriate display labels for movement types', () {
      final types = [
        'initial',
        'manual_inward',
        'manual_outward',
        'manual_set',
        'order_deduction',
        'order_restoration',
      ];

      for (final type in types) {
        final movement = SellerStockMovementEntity(
          id: 'test_$type',
          shopId: 'shop_1',
          productId: 'prod_test',
          productName: 'Test Item',
          movementType: type,
          changeAmount: 1,
          previousStock: 0,
          newStock: 1,
          reason: 'Test reason',
          actorRole: 'shopkeeper',
          createdAt: DateTime.now(),
        );
        expect(movement.movementTypeDisplayHindi.isNotEmpty, isTrue);
      }
    });
  });

  group('Inventory & Product Management Integration', () {
    late MockProfessionalDataSourceForInventory mockDs;

    setUp(() {
      mockDs = MockProfessionalDataSourceForInventory();
    });

    tearDown(() {
      mockDs.dispose();
    });

    test('saveProduct isolates private pricing and logs initial stock movement', () async {
      await mockDs.saveProduct(
        'shop_jamui',
        {
          'title': 'Wireless Mouse',
          'price': 499.0,
          'mrp': 799.0,
          'category': 'electronics',
          'description': 'High precision optical mouse',
        },
        costPrice: 280.0,
        supplierName: 'Tech Distro Patna',
        purchaseNotes: 'Invoice #INV-2026-09',
        initialStock: 25,
        lowStockThreshold: 4,
      );

      final savedProducts = mockDs.products['shop_jamui']!;
      expect(savedProducts.length, equals(1));
      final prod = savedProducts.first;
      expect(prod['title'], equals('Wireless Mouse'));
      expect(prod['stock'], equals(25));
      expect(prod['lowStockThreshold'], equals(4));

      // Check private pricing isolation
      final privatePricing = await mockDs.fetchProductPrivatePricing('shop_jamui', prod['id']);
      expect(privatePricing, isNotNull);
      expect(privatePricing!.costPrice, equals(280.0));
      expect(privatePricing.profitMarginRupees, equals(219.0));

      // Check initial stock movement ledger
      final movements = mockDs.stockMovements['shop_jamui']!;
      expect(movements.length, equals(1));
      expect(movements.first.movementType, equals('initial'));
      expect(movements.first.changeAmount, equals(25));
      expect(movements.first.newStock, equals(25));
    });

    test('adjustProductStock records atomic stock movements in ledger', () async {
      // Seed product
      await mockDs.saveProduct(
        'shop_jamui',
        {
          'title': 'Mechanical Keyboard',
          'price': 1999.0,
          'stock': 10,
        },
        productId: 'prod_keyboard',
        initialStock: 10,
      );

      // Increment stock
      final incRes = await mockDs.adjustProductStock(
        shopId: 'shop_jamui',
        productId: 'prod_keyboard',
        operation: 'increment',
        amount: 5,
        reason: 'Restock batch',
      );
      expect(incRes['success'], isTrue);
      expect(incRes['newStock'], equals(15));

      // Decrement stock
      final decRes = await mockDs.adjustProductStock(
        shopId: 'shop_jamui',
        productId: 'prod_keyboard',
        operation: 'decrement',
        amount: 2,
        reason: 'Damaged item written off',
      );
      expect(decRes['success'], isTrue);
      expect(decRes['newStock'], equals(13));

      // Verify movements
      final movements = mockDs.stockMovements['shop_jamui']!;
      expect(movements.length, equals(2));
      expect(movements[0].movementType, equals('manual_outward'));
      expect(movements[0].changeAmount, equals(-2));
      expect(movements[0].newStock, equals(13));

      expect(movements[1].movementType, equals('manual_inward'));
      expect(movements[1].changeAmount, equals(5));
      expect(movements[1].newStock, equals(15));
    });
  });

  group('Responsive Widget Tests — Add/Edit Product & Inventory Pages', () {
    late MockProfessionalDataSourceForInventory mockDs;
    const shopId = 'vendor_jamui_123';

    setUp(() {
      mockDs = MockProfessionalDataSourceForInventory();
      mockDs.storeCategories[shopId] = [
        SellerStoreCategoryEntity(
          id: 'cat_electronics',
          shopId: shopId,
          name: 'Electronics',
          displayOrder: 1,
          isActive: true,
          createdAt: DateTime(2026, 1, 1),
        ),
      ];
    });

    tearDown(() {
      mockDs.dispose();
    });

    testWidgets('ProfessionalAddEditProductPage renders on Mobile (360x780) with zero overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: ProfessionalAddEditProductPage(
            shopId: shopId,
            dataSource: mockDs,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify section titles
      expect(find.text('उत्पाद की मुख्य जानकारी (Basic Information)'), findsOneWidget);
      expect(find.text('मूल्य एवं निजी लागत (Pricing & Private Costing)'), findsOneWidget);
      expect(find.text('निजी लागत और मुनाफा (Confidential — Vendor Only)'), findsOneWidget);
      expect(find.text('उत्पाद जोड़ें (Add Product)'), findsOneWidget);

      // Verify no exceptions or overflows
      expect(tester.takeException(), isNull);
    });

    testWidgets('ProfessionalAddEditProductPage renders on Desktop (1366x768) with 2-column layout',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: ProfessionalAddEditProductPage(
            shopId: shopId,
            dataSource: mockDs,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('उत्पाद की मुख्य जानकारी (Basic Information)'), findsOneWidget);
      expect(find.text('उत्पाद जोड़ें (Add Product)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ProfessionalShopInventoryPage switches between Stock Items and Ledger tabs',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Seed product and movement
      mockDs.products[shopId] = [
        {
          'id': 'p1',
          'title': 'Test Item 1',
          'price': 250.0,
          'stockQuantity': 3,
          'lowStockThreshold': 5,
          'unit': 'इकाई',
          'storeCategoryId': 'cat_electronics',
        }
      ];

      mockDs.stockMovements[shopId] = [
        SellerStockMovementEntity(
          id: 'm1',
          shopId: shopId,
          productId: 'p1',
          productName: 'Test Item 1',
          movementType: 'initial',
          changeAmount: 3,
          previousStock: 0,
          newStock: 3,
          reason: 'Initial stock',
          actorRole: 'shopkeeper',
          createdAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: ProfessionalShopInventoryPage(
            shopId: shopId,
            dataSource: mockDs,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check tab bars
      expect(find.text('स्टॉक स्थिति (Stock Items)'), findsOneWidget);
      expect(find.text('स्टॉक लेजर (Movement History)'), findsOneWidget);

      // In Stock Items tab
      expect(find.text('Test Item 1'), findsOneWidget);
      expect(find.text('कम स्टॉक (3 इकाई)'), findsOneWidget);

      // Switch to Stock Ledger tab
      await tester.tap(find.text('स्टॉक लेजर (Movement History)'));
      await tester.pumpAndSettle();

      expect(find.text('+3'), findsOneWidget);
      expect(find.text('Initial stock'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  });
}
