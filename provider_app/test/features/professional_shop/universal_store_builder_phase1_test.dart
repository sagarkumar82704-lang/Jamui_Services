import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_provider/features/professional_shop/domain/entities/product_variant_entity.dart';
import 'package:apna_jamui_provider/features/professional_shop/domain/entities/store_features_entity.dart';
import 'package:apna_jamui_provider/features/professional_shop/domain/entities/custom_attribute_template_entity.dart';
import 'package:apna_jamui_provider/features/professional_shop/domain/entities/professional_product_item_entity.dart';
import 'package:apna_jamui_provider/features/professional_shop/data/datasources/professional_provider_remote_data_source.dart';

/// In-memory mock simulating Hybrid Product + Variant Subcollection Firestore Data Source
class MockHybridProfessionalDataSource extends ProfessionalProviderRemoteDataSource {
  final Map<String, List<Map<String, dynamic>>> products = {};
  final Map<String, List<ProductVariantEntity>> variants = {};
  final Map<String, Map<String, dynamic>> privatePricing = {};
  final Map<String, StoreFeaturesEntity> storeFeatures = {};
  final Map<String, List<CustomAttributeTemplateEntity>> attributeTemplates = {};

  MockHybridProfessionalDataSource() : super(firestore: null, functions: null);

  @override
  Future<String> saveProductVariant(
    String shopId,
    String productId,
    ProductVariantEntity variant, {
    double? costPrice,
    String? supplierName,
    String? purchaseNotes,
  }) async {
    final shopProducts = products[shopId] ?? [];
    final pIdx = shopProducts.indexWhere((p) => p['id'] == productId);
    if (pIdx < 0) {
      throw StateError('Parent product $productId does not exist in shop $shopId');
    }

    final parentData = shopProducts[pIdx];
    final basePrice = (parentData['basePrice'] as num?)?.toDouble() ??
        (parentData['sellingPrice'] as num?)?.toDouble() ??
        (parentData['price'] as num?)?.toDouble() ??
        0.0;
    final baseMrp = (parentData['baseMrp'] as num?)?.toDouble() ??
        (parentData['regularPrice'] as num?)?.toDouble() ??
        (parentData['mrp'] as num?)?.toDouble() ??
        basePrice;

    // Validate price override (Rejects invalid overrides)
    variant.validatePriceOverride(basePrice, baseMrp);

    final effectiveId = variant.id.isEmpty
        ? 'var_${DateTime.now().millisecondsSinceEpoch}_${variants['${shopId}_$productId']?.length ?? 0}'
        : variant.id;

    final effectiveVariant = variant.copyWith(
      id: effectiveId,
      productId: productId,
      shopId: shopId,
    );

    variants.putIfAbsent('${shopId}_$productId', () => []);
    final vList = variants['${shopId}_$productId']!;
    final vIdx = vList.indexWhere((v) => v.id == effectiveId);
    if (vIdx >= 0) {
      vList[vIdx] = effectiveVariant;
    } else {
      vList.add(effectiveVariant);
    }

    // Save Private Cost in isolated structure
    if (costPrice != null) {
      privatePricing.putIfAbsent('${shopId}_$productId', () => {});
      final pricingMap = privatePricing['${shopId}_$productId']!;
      pricingMap.putIfAbsent('variantCosts', () => <String, dynamic>{});
      (pricingMap['variantCosts'] as Map<String, dynamic>)[effectiveId] = {
        'costPrice': costPrice,
        if (supplierName != null) 'supplierName': supplierName,
        if (purchaseNotes != null) 'purchaseNotes': purchaseNotes,
      };
    }

    // Recompute parent aggregates
    await recomputeParentProductAggregates(shopId, productId);

    return effectiveId;
  }

  @override
  Future<List<ProductVariantEntity>> fetchProductVariants(String shopId, String productId) async {
    return List.from(variants['${shopId}_$productId'] ?? []);
  }

  @override
  Future<void> toggleVariantActive(String shopId, String productId, String variantId, bool isActive) async {
    final vList = variants['${shopId}_$productId'] ?? [];
    final idx = vList.indexWhere((v) => v.id == variantId);
    if (idx >= 0) {
      vList[idx] = vList[idx].copyWith(isActive: isActive);
    }
    await recomputeParentProductAggregates(shopId, productId);
  }

  @override
  Future<void> recomputeParentProductAggregates(String shopId, String productId) async {
    final shopProducts = products[shopId] ?? [];
    final pIdx = shopProducts.indexWhere((p) => p['id'] == productId);
    if (pIdx < 0) return;

    final parentData = shopProducts[pIdx];
    final basePrice = (parentData['basePrice'] as num?)?.toDouble() ??
        (parentData['sellingPrice'] as num?)?.toDouble() ??
        (parentData['price'] as num?)?.toDouble() ??
        0.0;

    final vList = variants['${shopId}_$productId'] ?? [];
    final activeVariants = vList.where((v) => v.isActive).toList();

    if (activeVariants.isEmpty) {
      parentData['hasVariants'] = vList.isNotEmpty;
      parentData['variantCount'] = vList.length;
      parentData['totalStockQuantity'] = 0;
      parentData['stockQuantity'] = 0;
      parentData['inStock'] = false;
      return;
    }

    double resolvedMin = double.infinity;
    double resolvedMax = 0.0;
    int resolvedStock = 0;

    for (final v in activeVariants) {
      final effPrice = v.resolvePrice(basePrice);
      if (effPrice < resolvedMin) resolvedMin = effPrice;
      if (effPrice > resolvedMax) resolvedMax = effPrice;
      resolvedStock += v.stockQuantity;
    }

    parentData['hasVariants'] = true;
    parentData['variantCount'] = vList.length;
    parentData['minPrice'] = resolvedMin.isFinite ? resolvedMin : basePrice;
    parentData['maxPrice'] = resolvedMax > 0 ? resolvedMax : basePrice;
    parentData['totalStockQuantity'] = resolvedStock;
    parentData['stockQuantity'] = resolvedStock;
    parentData['inStock'] = resolvedStock > 0;
    parentData['price'] = resolvedMin.isFinite ? resolvedMin : basePrice;
    parentData['sellingPrice'] = resolvedMin.isFinite ? resolvedMin : basePrice;
  }

  @override
  Future<void> saveStoreFeatures(String shopId, StoreFeaturesEntity features) async {
    storeFeatures[shopId] = features;
  }

  @override
  Future<StoreFeaturesEntity> fetchStoreFeatures(String shopId) async {
    return storeFeatures[shopId] ?? const StoreFeaturesEntity();
  }

  @override
  Future<String> saveAttributeTemplate(String shopId, CustomAttributeTemplateEntity template) async {
    attributeTemplates.putIfAbsent(shopId, () => []);
    final list = attributeTemplates[shopId]!;
    final effId = template.id.isEmpty ? 'tpl_${DateTime.now().millisecondsSinceEpoch}' : template.id;
    final effective = CustomAttributeTemplateEntity(
      id: effId,
      shopId: shopId,
      name: template.name,
      targetCategory: template.targetCategory,
      customVariantTypes: template.customVariantTypes,
      customFields: template.customFields,
    );

    final idx = list.indexWhere((t) => t.id == effId);
    if (idx >= 0) {
      list[idx] = effective;
    } else {
      list.add(effective);
    }
    return effId;
  }

  @override
  Future<List<CustomAttributeTemplateEntity>> fetchAttributeTemplates(String shopId) async {
    return List.from(attributeTemplates[shopId] ?? []);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UNIVERSAL STORE BUILDER — PHASE 1 DOMAIN ENTITIES & LOGIC', () {
    test('1. ProductVariantEntity priceMode resolution (inherit vs override)', () {
      const basePrice = 500.0;
      const baseMrp = 750.0;

      // Inherit mode
      const inheritVariant = ProductVariantEntity(
        id: 'v_inherit',
        productId: 'p_1',
        shopId: 's_1',
        title: 'Medium',
        priceMode: VariantPriceMode.inherit,
        stockQuantity: 10,
      );
      expect(inheritVariant.resolvePrice(basePrice), equals(500.0));
      expect(inheritVariant.resolveMrp(baseMrp), equals(750.0));

      // Override mode
      const overrideVariant = ProductVariantEntity(
        id: 'v_override',
        productId: 'p_1',
        shopId: 's_1',
        title: 'Extra Large',
        priceMode: VariantPriceMode.override,
        price: 599.0,
        mrp: 899.0,
        stockQuantity: 5,
      );
      expect(overrideVariant.resolvePrice(basePrice), equals(599.0));
      expect(overrideVariant.resolveMrp(baseMrp), equals(899.0));
    });

    test('2. Rejection of invalid price overrides', () {
      const basePrice = 500.0;
      const baseMrp = 750.0;

      // Selling price <= 0 must throw ArgumentError
      const zeroPriceVariant = ProductVariantEntity(
        id: 'v_zero',
        productId: 'p_1',
        shopId: 's_1',
        title: 'Faulty Price',
        priceMode: VariantPriceMode.override,
        price: 0.0,
      );
      expect(
        () => zeroPriceVariant.validatePriceOverride(basePrice, baseMrp),
        throwsArgumentError,
      );

      // Selling price exceeding MRP must throw ArgumentError
      const priceExceedsMrpVariant = ProductVariantEntity(
        id: 'v_exceed',
        productId: 'p_1',
        shopId: 's_1',
        title: 'Over MRP',
        priceMode: VariantPriceMode.override,
        price: 800.0,
        mrp: 750.0,
      );
      expect(
        () => priceExceedsMrpVariant.validatePriceOverride(basePrice, baseMrp),
        throwsArgumentError,
      );

      // Valid override must not throw
      const validOverride = ProductVariantEntity(
        id: 'v_valid',
        productId: 'p_1',
        shopId: 's_1',
        title: 'Valid',
        priceMode: VariantPriceMode.override,
        price: 650.0,
        mrp: 750.0,
      );
      expect(
        () => validOverride.validatePriceOverride(basePrice, baseMrp),
        returnsNormally,
      );
    });

    test('3. Variant serialization toMap and fromMap preserves all fields', () {
      const original = ProductVariantEntity(
        id: 'var_size_38_blue',
        productId: 'prod_shirt_1',
        shopId: 'shop_jamui_1',
        title: '38 / Navy Blue',
        sku: 'RYM-38-NVY',
        barcode: '8901234567890',
        selectedOptions: {'Size': '38', 'Color': 'Navy Blue'},
        priceMode: VariantPriceMode.override,
        price: 999.0,
        mrp: 1499.0,
        stockQuantity: 18,
        lowStockThreshold: 4,
        inStock: true,
        trackInventory: true,
        images: ['providers/s1/p1/img1.webp'],
        thumbnailUrl: 'providers/s1/p1/img1.webp',
        weightGrams: 250,
        dimensions: {'length': 30, 'width': 20, 'height': 3},
        isActive: true,
      );

      final map = original.toMap();
      expect(map['id'], equals('var_size_38_blue'));
      expect(map['priceMode'], equals('override'));
      expect(map['price'], equals(999.0));
      expect(map['sku'], equals('RYM-38-NVY'));
      expect(map['selectedOptions'], equals({'Size': '38', 'Color': 'Navy Blue'}));

      final reconstructed = ProductVariantEntity.fromMap(
        map,
        'var_size_38_blue',
        productId: 'prod_shirt_1',
        shopId: 'shop_jamui_1',
      );

      expect(reconstructed.id, equals(original.id));
      expect(reconstructed.sku, equals(original.sku));
      expect(reconstructed.price, equals(original.price));
      expect(reconstructed.selectedOptions, equals(original.selectedOptions));
      expect(reconstructed.stockQuantity, equals(original.stockQuantity));
      expect(reconstructed.weightGrams, equals(250));
    });

    test('4. StoreFeaturesEntity default values and custom settings registry extensibility', () {
      const defaultFeatures = StoreFeaturesEntity();
      expect(defaultFeatures.enableHomeDelivery, isTrue);
      expect(defaultFeatures.enableStorePickup, isTrue);
      expect(defaultFeatures.minOrderAmount, equals(0.0));
      expect(defaultFeatures.isReturnable, isFalse);

      final customFeatures = StoreFeaturesEntity(
        enableHomeDelivery: true,
        minOrderAmount: 249.0,
        freeDeliveryThreshold: 499.0,
        deliveryCharge: 35.0,
        isReturnable: true,
        returnWindowDays: 7,
        policyNote: 'Tags must be intact for garment exchange',
        customSettings: const {
          'allowGstInvoicing': true,
          'supportPrioritySms': false,
          'customBannerTag': 'Diwali Festive Sale',
        },
      );

      final map = customFeatures.toMap();
      expect(map['minOrderAmount'], equals(249.0));
      expect(map['freeDeliveryThreshold'], equals(499.0));
      expect(map['customSettings']['allowGstInvoicing'], isTrue);

      final parsed = StoreFeaturesEntity.fromMap(map);
      expect(parsed.minOrderAmount, equals(249.0));
      expect(parsed.isReturnable, isTrue);
      expect(parsed.returnWindowDays, equals(7));
      expect(parsed.customSettings['customBannerTag'], equals('Diwali Festive Sale'));
    });

    test('5. CustomAttributeTemplateEntity serialization for provider-defined fields and variants', () {
      const template = CustomAttributeTemplateEntity(
        id: 'tpl_clothing',
        shopId: 'shop_jamui_1',
        name: 'Garments Standard Template',
        targetCategory: 'Clothing',
        customVariantTypes: [
          CustomVariantTypeDefinition(
            key: 'size',
            label: 'Size / माप',
            displayType: 'pills',
            suggestedValues: ['S', 'M', 'L', 'XL', 'XXL'],
          ),
          CustomVariantTypeDefinition(
            key: 'color',
            label: 'Color / रंग',
            displayType: 'color_swatch',
            suggestedValues: ['White', 'Navy Blue', 'Maroon'],
          ),
        ],
        customFields: [
          CustomFieldDefinition(
            key: 'fabric',
            label: 'Fabric',
            fieldType: 'text',
            isRequired: true,
          ),
          CustomFieldDefinition(
            key: 'fit_type',
            label: 'Fit',
            fieldType: 'dropdown',
            options: ['Slim', 'Regular', 'Comfort'],
          ),
        ],
      );

      final map = template.toMap();
      expect(map['name'], equals('Garments Standard Template'));
      expect((map['customVariantTypes'] as List).length, equals(2));
      expect((map['customFields'] as List).length, equals(2));

      final parsed = CustomAttributeTemplateEntity.fromMap(map, 'tpl_clothing', shopId: 'shop_jamui_1');
      expect(parsed.customVariantTypes.first.key, equals('size'));
      expect(parsed.customVariantTypes.first.suggestedValues, contains('XL'));
      expect(parsed.customFields.first.key, equals('fabric'));
      expect(parsed.customFields.first.isRequired, isTrue);
    });

    test('6. Backward Compatibility: Existing Simple Products load without variants', () {
      // Simulating a legacy Simple Product Firestore map
      final legacyMap = {
        'id': 'legacy_prod_1',
        'shopId': 'shop_1',
        'title': 'Aashirvaad Atta 10kg',
        'price': 380.0,
        'mrp': 420.0,
        'stock': 25,
        'unit': 'pack',
        'isAvailable': true,
      };

      final product = ProfessionalProductItemEntity.fromMap(legacyMap, 'legacy_prod_1', shopId: 'shop_1');

      // Must identify as a Simple Product without variants
      expect(product.hasVariants, isFalse);
      expect(product.variantCount, equals(0));
      expect(product.variantOptions.isEmpty, isTrue);
      expect(product.basePrice, equals(380.0));
      expect(product.minPrice, equals(380.0));
      expect(product.maxPrice, equals(380.0));
      expect(product.totalStockQuantity, equals(25));
      expect(product.inStock, isTrue);
    });

    test('7. Hybrid Aggregate Calculation computes price ranges and total stock correctly', () {
      const parent = ProfessionalProductItemEntity(
        id: 'prod_shirt_100',
        shopId: 'shop_1',
        title: 'Linen Casual Shirt',
        basePrice: 899.0,
        baseMrp: 1499.0,
        hasVariants: true,
      );

      final variantsList = [
        const ProductVariantEntity(
          id: 'v_small',
          productId: 'prod_shirt_100',
          shopId: 'shop_1',
          title: 'Size 38',
          priceMode: VariantPriceMode.inherit, // ₹899
          stockQuantity: 10,
          isActive: true,
        ),
        const ProductVariantEntity(
          id: 'v_medium',
          productId: 'prod_shirt_100',
          shopId: 'shop_1',
          title: 'Size 40',
          priceMode: VariantPriceMode.override,
          price: 949.0, // ₹949
          stockQuantity: 15,
          isActive: true,
        ),
        const ProductVariantEntity(
          id: 'v_large',
          productId: 'prod_shirt_100',
          shopId: 'shop_1',
          title: 'Size 42',
          priceMode: VariantPriceMode.override,
          price: 999.0, // ₹999
          stockQuantity: 5,
          isActive: true,
        ),
        const ProductVariantEntity(
          id: 'v_deactivated',
          productId: 'prod_shirt_100',
          shopId: 'shop_1',
          title: 'Size 44 (Discontinued)',
          priceMode: VariantPriceMode.override,
          price: 1099.0,
          stockQuantity: 8,
          isActive: false, // Inactive variant should NOT contribute to aggregates
        ),
      ];

      final aggregated = parent.withRecomputedAggregates(variantsList);

      expect(aggregated.hasVariants, isTrue);
      expect(aggregated.variantCount, equals(4)); // Total registered variants
      expect(aggregated.minPrice, equals(899.0)); // Inherited basePrice is minimum
      expect(aggregated.maxPrice, equals(999.0)); // Active large is max (inactive excluded)
      expect(aggregated.totalStockQuantity, equals(30)); // 10 + 15 + 5 = 30 (inactive 8 excluded)
      expect(aggregated.inStock, isTrue);
    });
  });

  group('UNIVERSAL STORE BUILDER — HYBRID DATA SOURCE INTEGRATION', () {
    late MockHybridProfessionalDataSource mockDs;
    const shopId = 'vendor_jamui_pro';
    const prodId = 'prod_jeans_01';

    setUp(() {
      mockDs = MockHybridProfessionalDataSource();
      // Seed parent product
      mockDs.products[shopId] = [
        {
          'id': prodId,
          'shopId': shopId,
          'title': 'Stretch Denim Jeans',
          'basePrice': 1299.0,
          'baseMrp': 1999.0,
          'hasVariants': false,
          'stockQuantity': 0,
        }
      ];
    });

    test('Saves product variant, isolates private cost, and syncs parent aggregates', () async {
      // 1. Add Variant 30W
      final v1Id = await mockDs.saveProductVariant(
        shopId,
        prodId,
        const ProductVariantEntity(
          id: 'var_30',
          productId: prodId,
          shopId: shopId,
          title: 'Waist 30',
          sku: 'JNS-30',
          priceMode: VariantPriceMode.inherit,
          stockQuantity: 12,
        ),
        costPrice: 650.0,
        supplierName: 'Denim World Surat',
        purchaseNotes: 'Invoice #DW-102',
      );

      // 2. Add Variant 32W with price override
      final v2Id = await mockDs.saveProductVariant(
        shopId,
        prodId,
        const ProductVariantEntity(
          id: 'var_32',
          productId: prodId,
          shopId: shopId,
          title: 'Waist 32',
          sku: 'JNS-32',
          priceMode: VariantPriceMode.override,
          price: 1399.0,
          mrp: 2099.0,
          stockQuantity: 20,
        ),
        costPrice: 700.0,
        supplierName: 'Denim World Surat',
      );

      expect(v1Id, equals('var_30'));
      expect(v2Id, equals('var_32'));

      // 3. Verify Variants in Subcollection
      final fetchedVariants = await mockDs.fetchProductVariants(shopId, prodId);
      expect(fetchedVariants.length, equals(2));
      expect(fetchedVariants[0].sku, equals('JNS-30'));
      expect(fetchedVariants[1].sku, equals('JNS-32'));

      // 4. Verify Private Cost Isolation (Vendor-Only map)
      final privateCosts = mockDs.privatePricing['${shopId}_$prodId'];
      expect(privateCosts, isNotNull);
      final variantCosts = privateCosts!['variantCosts'] as Map<String, dynamic>;
      expect(variantCosts['var_30']['costPrice'], equals(650.0));
      expect(variantCosts['var_30']['supplierName'], equals('Denim World Surat'));
      expect(variantCosts['var_32']['costPrice'], equals(700.0));

      // 5. Verify Parent Aggregates automatically recomputed
      final parentProd = mockDs.products[shopId]!.firstWhere((p) => p['id'] == prodId);
      expect(parentProd['hasVariants'], isTrue);
      expect(parentProd['variantCount'], equals(2));
      expect(parentProd['minPrice'], equals(1299.0)); // Inherited basePrice
      expect(parentProd['maxPrice'], equals(1399.0)); // Overridden price
      expect(parentProd['totalStockQuantity'], equals(32)); // 12 + 20
      expect(parentProd['inStock'], isTrue);
    });

    test('Soft deactivating a variant updates parent aggregates and preserves records', () async {
      // Seed 2 variants
      await mockDs.saveProductVariant(
        shopId,
        prodId,
        const ProductVariantEntity(
          id: 'v1',
          productId: prodId,
          shopId: shopId,
          title: 'Size A',
          priceMode: VariantPriceMode.inherit,
          stockQuantity: 10,
        ),
      );
      await mockDs.saveProductVariant(
        shopId,
        prodId,
        const ProductVariantEntity(
          id: 'v2',
          productId: prodId,
          shopId: shopId,
          title: 'Size B',
          priceMode: VariantPriceMode.override,
          price: 1499.0,
          mrp: 1999.0,
          stockQuantity: 15,
        ),
      );

      // Initial state: total stock = 25, maxPrice = 1499
      var parent = mockDs.products[shopId]!.firstWhere((p) => p['id'] == prodId);
      expect(parent['totalStockQuantity'], equals(25));
      expect(parent['maxPrice'], equals(1499.0));

      // Soft deactivate v2
      await mockDs.toggleVariantActive(shopId, prodId, 'v2', false);

      // Verify v2 still exists in subcollection (never hard-deleted)
      final allVariants = await mockDs.fetchProductVariants(shopId, prodId);
      expect(allVariants.length, equals(2));
      final v2 = allVariants.firstWhere((v) => v.id == 'v2');
      expect(v2.isActive, isFalse);

      // Verify parent aggregates recomputed with only active variants
      parent = mockDs.products[shopId]!.firstWhere((p) => p['id'] == prodId);
      expect(parent['totalStockQuantity'], equals(10)); // v2 (15) excluded
      expect(parent['maxPrice'], equals(1299.0)); // v2 price excluded, basePrice becomes max
    });

    test('Saves and fetches Store Features and Custom Attribute Templates', () async {
      // Store Features
      const features = StoreFeaturesEntity(
        enableHomeDelivery: true,
        deliveryCharge: 40.0,
        freeDeliveryThreshold: 599.0,
        minOrderAmount: 199.0,
        isReturnable: true,
        returnWindowDays: 3,
      );
      await mockDs.saveStoreFeatures(shopId, features);
      final fetchedFeatures = await mockDs.fetchStoreFeatures(shopId);
      expect(fetchedFeatures.deliveryCharge, equals(40.0));
      expect(fetchedFeatures.freeDeliveryThreshold, equals(599.0));

      // Custom Attribute Template
      const template = CustomAttributeTemplateEntity(
        id: 'tpl_mobile',
        shopId: shopId,
        name: 'Mobile Phone Specifications',
        targetCategory: 'Electronics',
        customVariantTypes: [
          CustomVariantTypeDefinition(
            key: 'storage',
            label: 'Storage (ROM)',
            suggestedValues: ['64GB', '128GB', '256GB'],
          ),
        ],
        customFields: [
          CustomFieldDefinition(key: 'ram', label: 'RAM', fieldType: 'text'),
          CustomFieldDefinition(key: 'battery', label: 'Battery Capacity', fieldType: 'number'),
        ],
      );
      final tplId = await mockDs.saveAttributeTemplate(shopId, template);
      expect(tplId, equals('tpl_mobile'));

      final allTemplates = await mockDs.fetchAttributeTemplates(shopId);
      expect(allTemplates.length, equals(1));
      expect(allTemplates.first.name, equals('Mobile Phone Specifications'));
      expect(allTemplates.first.customVariantTypes.first.suggestedValues, contains('128GB'));
    });
  });
}

