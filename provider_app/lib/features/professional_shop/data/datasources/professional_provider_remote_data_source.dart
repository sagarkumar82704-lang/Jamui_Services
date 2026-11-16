import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../domain/entities/professional_shop_profile_entity.dart';
import '../../domain/entities/seller_store_category_entity.dart';
import '../../domain/entities/seller_stock_movement_entity.dart';
import '../../domain/entities/private_product_pricing_entity.dart';
import '../../domain/entities/product_variant_entity.dart';
import '../../domain/entities/store_features_entity.dart';
import '../../domain/entities/custom_attribute_template_entity.dart';

class ProfessionalProviderRemoteDataSource {
  // Underlying physical collections preserved for Firebase backwards compatibility
  static const String collectionShops = 'diamond_shops';
  static const String collectionOrders = 'diamond_orders';
  static const String collectionSubscriptionPlans = 'diamond_subscription_plans';
  static const String collectionPayments = 'diamond_payments';
  /// Technical abuse safeguard only (NOT a commercial/subscription limit).
  static const int technicalMaxVariantsPerProduct = 50;
  static const String legacyCollectionShops = 'shops';
  static const String subcollectionStoreCategories = 'store_categories';
  static const String subcollectionStockMovements = 'stock_movements';
  static const String subcollectionPrivatePricing = 'private_pricing';
  static const String subcollectionVariants = 'variants';
  static const String subcollectionAttributeTemplates = 'attribute_templates';

  final FirebaseFirestore? _customFirestore;
  final FirebaseFunctions? _customFunctions;

  ProfessionalProviderRemoteDataSource({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _customFirestore = firestore,
        _customFunctions = functions;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  FirebaseFunctions get _functions =>
      _customFunctions ?? FirebaseFunctions.instanceFor(region: 'asia-south1');

  /// Authoritatively fetches and strictly verifies shop ownership against [currentUid].
  /// Guaranteed security invariant: Rejects any document where `ownerUid != currentUid`.
  Future<ProfessionalShopProfileEntity?> resolveVerifiedShop(String currentUid) async {
    try {
      // Step 1: Direct document lookup by current UID
      DocumentSnapshot doc = await _firestore.collection(collectionShops).doc(currentUid).get();
      if (!doc.exists) {
        doc = await _firestore.collection(legacyCollectionShops).doc(currentUid).get();
      }

      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        // Strict Mandatory Ownership Verification
        if (data['ownerUid'] == currentUid) {
          return ProfessionalShopProfileEntity.fromMap(data, doc.id);
        }
      }

      // Step 2: Fallback query by ownerUid (in case shop document has a custom or generated ID)
      final querySnap = await _firestore
          .collection(collectionShops)
          .where('ownerUid', isEqualTo: currentUid)
          .limit(1)
          .get();
      if (querySnap.docs.isNotEmpty) {
        final data = querySnap.docs.first.data();
        if (data['ownerUid'] == currentUid) {
          return ProfessionalShopProfileEntity.fromMap(data, querySnap.docs.first.id);
        }
      }
    } catch (e) {
      // Return null on failure to prevent any insecure fallback
      return null;
    }
    return null;
  }

  Future<ProfessionalShopProfileEntity?> fetchShopProfile(String uid) async {
    return resolveVerifiedShop(uid);
  }

  Stream<ProfessionalShopProfileEntity?> streamShopProfile(String uid, {String? ownerUid}) {
    try {
      final expectedOwnerUid = ownerUid ?? uid;
      return _firestore.collection(collectionShops).doc(uid).snapshots().map((doc) {
        if (doc.exists && doc.data() != null) {
          final data = doc.data() as Map<String, dynamic>;
          // Strict Mandatory Ownership Verification on live stream snapshots
          if (data['ownerUid'] == expectedOwnerUid) {
            return ProfessionalShopProfileEntity.fromMap(data, doc.id);
          }
        }
        return null;
      });
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Immutable admin/approval/subscription/financial fields on `diamond_shops/{shopId}`.
  /// Sellers can never modify these fields from Edit Store Profile, Store Settings, or Location Management.
  static const Set<String> immutableShopFields = {
    'id',
    'shopId',
    'ownerUid',
    'isApproved',
    'approvedAt',
    'approvedBy',
    'status',
    'isSubscriptionActive',
    'subscriptionExpiry',
    'subscriptionActivatedAt',
    'paymentVerified',
    'paymentId',
    'orderId',
    'razorpayPaymentId',
    'razorpayOrderId',
    'razorpaySignature',
    'rating',
    'ratingCount',
    'totalOrders',
    'totalRevenue',
    'subscriptionPlan',
    'subscriptionPlanId',
    'subscriptionPlanName',
    'subscriptionDurationDays',
    'maxProductsLimit',
    'productLimit',
    'maxProducts',
    'maxVariantsPerProduct',
    'variantLimit',
    'features',
    'imageLimit',
    'storageLimitMb',
    'paymentAmount',
    'paymentAmountInPaise',
    'paymentOrderId',
    'subscriptionExpiredAt',
    'productQuotaCheckedAt',
    'shopCategory',
    'businessCategory',
    'isVerified',
    'shopCode',
    'sellerOrderCounter',
  };

  /// Sanitizes a shop update map by stripping all admin/approval/subscription fields
  /// and validating latitude/longitude coordinates when present.
  static Map<String, dynamic> sanitizeShopUpdatePayload(Map<String, dynamic> data) {
    final sanitized = Map<String, dynamic>.from(data);
    for (final key in immutableShopFields) {
      sanitized.remove(key);
    }

    final hasLat = sanitized.containsKey('latitude');
    final hasLng = sanitized.containsKey('longitude');
    if (hasLat || hasLng) {
      final rawLat = sanitized['latitude'];
      final rawLng = sanitized['longitude'];
      final lat = rawLat is num ? rawLat.toDouble() : double.tryParse(rawLat?.toString() ?? '');
      final lng = rawLng is num ? rawLng.toDouble() : double.tryParse(rawLng?.toString() ?? '');
      if (lat == null ||
          lng == null ||
          !lat.isFinite ||
          !lng.isFinite ||
          lat < -90.0 ||
          lat > 90.0 ||
          lng < -180.0 ||
          lng > 180.0 ||
          (lat == 0.0 && lng == 0.0)) {
        throw const FormatException(
          'Invalid store coordinates: Latitude must be between -90 and +90, and Longitude must be between -180 and +180.',
        );
      }
      sanitized['latitude'] = lat;
      sanitized['longitude'] = lng;
    }

    return sanitized;
  }

  Future<void> _verifyShopOwnershipIfProvided(String shopId, String? currentUid) async {
    if (currentUid == null || currentUid.trim().isEmpty) return;
    if (shopId == currentUid) return;
    final snap = await _firestore.collection(collectionShops).doc(shopId).get();
    if (!snap.exists || snap.data() == null) {
      throw StateError('Store not found.');
    }
    final data = snap.data()!;
    final docOwnerUid = (data['ownerUid'] ?? '').toString();
    if (docOwnerUid != currentUid) {
      throw StateError('Unauthorized: You can only update your own store.');
    }
  }

  Future<void> updateShopSettings(
    String shopId,
    Map<String, dynamic> data, {
    String? currentUid,
  }) async {
    await _verifyShopOwnershipIfProvided(shopId, currentUid);
    final sanitized = sanitizeShopUpdatePayload(data);
    if (sanitized.isEmpty) return;
    await _firestore.collection(collectionShops).doc(shopId).update({
      ...sanitized,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateShopProfile(
    String shopId,
    Map<String, dynamic> data, {
    String? currentUid,
  }) async {
    await updateShopSettings(shopId, data, currentUid: currentUid);
  }

  Future<void> updateStoreLocation({
    required String shopId,
    required double latitude,
    required double longitude,
    required String fullAddress,
    String? jamuiArea,
    String? landmark,
    required String locationSource,
    required bool isLocationApproximate,
    String? currentUid,
  }) async {
    await updateShopSettings(
      shopId,
      {
        'latitude': latitude,
        'longitude': longitude,
        'fullAddress': fullAddress.trim(),
        if (jamuiArea != null && jamuiArea.trim().isNotEmpty)
          'jamuiArea': jamuiArea.trim(),
        'landmark': (landmark ?? '').trim(),
        'locationSource': locationSource.trim(),
        'isLocationApproximate': isLocationApproximate,
      },
      currentUid: currentUid,
    );
  }

  Future<void> savePromoBanner(
    String shopId,
    ShopPromoBannerEntity banner, {
    String? currentUid,
  }) async {
    await updateShopSettings(
      shopId,
      {
        'promoBanner': {
          ...banner.toMap(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      },
      currentUid: currentUid,
    );
  }

  Future<void> deletePromoBanner(
    String shopId, {
    String? currentUid,
  }) async {
    await _verifyShopOwnershipIfProvided(shopId, currentUid);
    await _firestore.collection(collectionShops).doc(shopId).update({
      'promoBanner': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> toggleShopOpenStatus(String shopId, bool isOpen) async {
    await _firestore.collection(collectionShops).doc(shopId).update({
      'isOpen': isOpen,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> streamShopOrders(String shopId) {
    try {
      return _firestore
          .collection(collectionOrders)
          .where('shopId', isEqualTo: shopId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snap) {
        return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      });
    } catch (_) {
      return const Stream.empty();
    }
  }

  final Map<String, String?> _catalogProductTitleCache = {};

  /// Checks if a stored order item name is a known legacy generic fallback placeholder.
  static bool isGenericFallbackItemName(String? rawName) {
    if (rawName == null) return true;
    final trimmed = rawName.trim().toLowerCase();
    return trimmed.isEmpty ||
        trimmed == 'product' ||
        trimmed == 'item' ||
        trimmed == 'उत्पाद';
  }

  /// Read-only fallback resolver for historical orders where item title is missing or generic.
  /// Resolves the current catalog title from `diamond_shops/{shopId}/products/{productId}`.
  ///
  /// Strict isolation guarantee:
  /// Requires explicit non-empty [shopId] and [productId]. Never queries across shops.
  /// Results are cached in-memory so identical products across orders are fetched at most once.
  Future<String?> resolveCatalogProductTitle({
    required String shopId,
    required String productId,
  }) async {
    final cleanShopId = shopId.trim();
    final cleanProductId = productId.trim();
    if (cleanShopId.isEmpty || cleanProductId.isEmpty) return null;

    final cacheKey = '${cleanShopId}_$cleanProductId';
    if (_catalogProductTitleCache.containsKey(cacheKey)) {
      return _catalogProductTitleCache[cacheKey];
    }

    try {
      final doc = await _firestore
          .collection(collectionShops)
          .doc(cleanShopId)
          .collection('products')
          .doc(cleanProductId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final title = (data['title'] as String?)?.trim() ??
            (data['titleHindi'] as String?)?.trim() ??
            (data['titleEnglish'] as String?)?.trim() ??
            (data['name'] as String?)?.trim();
        if (title != null && title.isNotEmpty) {
          _catalogProductTitleCache[cacheKey] = title;
          return title;
        }
      }
      _catalogProductTitleCache[cacheKey] = null;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Synchronously returns cached catalog title if already resolved, without I/O.
  String? getCachedCatalogProductTitle({
    required String shopId,
    required String productId,
  }) {
    final cleanShopId = shopId.trim();
    final cleanProductId = productId.trim();
    if (cleanShopId.isEmpty || cleanProductId.isEmpty) return null;
    return _catalogProductTitleCache['${cleanShopId}_$cleanProductId'];
  }

  /// Batch-resolves all generic items in a list of orders.
  /// Fetches unique uncached product IDs concurrently.
  Future<void> resolveOrdersCatalogTitles(
    List<Map<String, dynamic>> orders,
    String defaultShopId,
  ) async {
    final futures = <Future>[];
    for (final order in orders) {
      final orderShopId = ((order['shopId'] as String?) ?? defaultShopId).trim();
      final items = (order['items'] as List<dynamic>?) ?? [];
      for (final it in items) {
        if (it is Map) {
          final rawName = (it['name'] ?? it['title']) as String?;
          final productId = (it['productId'] as String?)?.trim() ?? '';
          if (isGenericFallbackItemName(rawName) && productId.isNotEmpty) {
            final cacheKey = '${orderShopId}_$productId';
            if (!_catalogProductTitleCache.containsKey(cacheKey)) {
              futures.add(resolveCatalogProductTitle(shopId: orderShopId, productId: productId));
            }
          }
        }
      }
    }
    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }

  /// Allows unit tests or mock setups to seed catalog product titles.
  @visibleForTesting
  void seedCatalogTitleCache(String shopId, String productId, String? title) {
    _catalogProductTitleCache['${shopId.trim()}_${productId.trim()}'] = title;
  }

  Future<void> updateOrderStatus(String orderId, String newStatus, {String? rejectionReason}) async {
    try {
      final callable = _functions.httpsCallable('updateDiamondOrderStatus');
      await callable.call({
        'orderId': orderId,
        'newStatus': newStatus,
        'reason': rejectionReason ?? '',
      });
    } catch (_) {
      // Direct Firestore update fallback if functions offline in dev/emulator
      await _firestore.collection(collectionOrders).doc(orderId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        if (rejectionReason != null && rejectionReason.isNotEmpty) 'rejectionReason': rejectionReason,
      });
    }
  }

  Stream<List<Map<String, dynamic>>> streamProducts(String shopId) {
    try {
      return _firestore
          .collection(collectionShops)
          .doc(shopId)
          .collection('products')
          .where('isDeleted', isEqualTo: false)
          .snapshots()
          .map((snap) {
        return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      });
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Counts active products for a shop
  Future<int> countShopProducts(String shopId) async {
    try {
      final snap = await _firestore
          .collection(collectionShops)
          .doc(shopId)
          .collection('products')
          .where('isDeleted', isEqualTo: false)
          .get();
      return snap.docs.length;
    } catch (_) {
      return 0;
    }
  }

  /// Fetches list of active products for a shop
  Future<List<Map<String, dynamic>>> fetchShopProducts(String shopId) async {
    try {
      final snap = await _firestore
          .collection(collectionShops)
          .doc(shopId)
          .collection('products')
          .where('isDeleted', isEqualTo: false)
          .get();
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (_) {
      return [];
    }
  }

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
    final col = _firestore.collection(collectionShops).doc(shopId).collection('products');
    final batch = _firestore.batch();
    late final DocumentReference prodRef;
    final isNew = productId == null || productId.isEmpty;

    final sanitizedData = Map<String, dynamic>.from(productData);
    // Explicitly guarantee private pricing never pollutes public product document
    sanitizedData.remove('costPrice');
    sanitizedData.remove('profitMargin');
    sanitizedData.remove('profitMarginRupees');
    sanitizedData.remove('profitMarginPercentage');
    sanitizedData.remove('supplierName');
    sanitizedData.remove('purchaseNotes');

    if (lowStockThreshold != null && lowStockThreshold > 0) {
      sanitizedData['lowStockThreshold'] = lowStockThreshold;
    }

    if (!isNew) {
      prodRef = col.doc(productId);
      // Zero-Trust Security: Ensure inventory & financial aggregates are not overwritten on basic detail update
      sanitizedData.remove('stockQuantity');
      sanitizedData.remove('totalStockQuantity');
      sanitizedData.remove('baseStockQuantity');
      sanitizedData.remove('inStock');
      sanitizedData.remove('totalOrders');
      sanitizedData.remove('totalRevenue');
      sanitizedData.remove('rating');
      sanitizedData.remove('ratingCount');
      batch.update(prodRef, {
        ...sanitizedData,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      // NEW products are created by the trusted Cloud Function so the subscription product quota,
      // subscription expiry and shop status are enforced transactionally on the server.
      // (Direct client creates are denied by Firestore rules.)
      final callable = _functions.httpsCallable('createProfessionalProduct');
      final res = await callable.call({
        'shopId': shopId,
        'productData': sanitizedData,
        if (costPrice != null && costPrice >= 0) 'costPrice': costPrice,
        if (supplierName != null && supplierName.isNotEmpty) 'supplierName': supplierName,
        if (purchaseNotes != null && purchaseNotes.isNotEmpty) 'purchaseNotes': purchaseNotes,
        'initialStock': initialStock ?? (sanitizedData['stockQuantity'] as num?) ?? 0,
      });
      final data = Map<String, dynamic>.from(res.data as Map);
      return (data['productId'] ?? '').toString();
    }

    // Save confidential vendor-only private pricing in isolated subcollection (existing products only)
    if (costPrice != null && costPrice >= 0) {
      final pricingRef = prodRef.collection(subcollectionPrivatePricing).doc('cost_data');
      final sellPrice = (sanitizedData['sellingPrice'] as num?)?.toDouble() ?? 0.0;
      final regPrice = (sanitizedData['regularPrice'] as num?)?.toDouble() ?? sellPrice;
      final margin = sellPrice > costPrice ? (sellPrice - costPrice) : 0.0;
      final marginPct = sellPrice > 0 ? ((margin / sellPrice) * 100) : 0.0;

      batch.set(
        pricingRef,
        {
          'productId': prodRef.id,
          'costPrice': costPrice,
          'sellingPrice': sellPrice,
          'regularPrice': regPrice,
          'profitMarginRupees': margin,
          'profitMarginPercentage': marginPct,
          if (supplierName != null && supplierName.isNotEmpty) 'supplierName': supplierName,
          if (purchaseNotes != null && purchaseNotes.isNotEmpty) 'purchaseNotes': purchaseNotes,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
    return prodRef.id;
  }

  /// Fetches private pricing entity for a product. Strictly vendor-accessible.
  Future<PrivateProductPricingEntity?> fetchProductPrivatePricing(String shopId, String productId) async {
    try {
      final doc = await _firestore
          .collection(collectionShops)
          .doc(shopId)
          .collection('products')
          .doc(productId)
          .collection(subcollectionPrivatePricing)
          .doc('cost_data')
          .get();

      if (doc.exists && doc.data() != null) {
        return PrivateProductPricingEntity.fromMap(doc.data()!, productId);
      }
    } catch (_) {}
    return null;
  }

  /// Streams real-time stock movement ledger for a vendor's shop.
  Stream<List<SellerStockMovementEntity>> streamStockMovements(String shopId, {String? productId, int limit = 50}) {
    try {
      Query query = _firestore
          .collection(collectionShops)
          .doc(shopId)
          .collection(subcollectionStockMovements)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (productId != null && productId.isNotEmpty) {
        query = query.where('productId', isEqualTo: productId);
      }

      return query.snapshots().map((snap) {
        return snap.docs
            .map((d) => SellerStockMovementEntity.fromMap(d.data() as Map<String, dynamic>, d.id, shopId: shopId))
            .toList();
      });
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Paginated query for products listing with cursor and filters.
  Future<Map<String, dynamic>> fetchProductsPaginated(
    String shopId, {
    int limit = 25,
    DocumentSnapshot? startAfter,
    String? filterStatus, // 'All', 'In Stock', 'Out of Stock'
    String? storeCategoryId,
    String? searchQuery,
  }) async {
    try {
      final baseCol = _firestore.collection(collectionShops).doc(shopId).collection('products');
      QuerySnapshot snap;

      // 1. Attempt compound query with server-side filters if index exists
      try {
        Query query = baseCol.where('isDeleted', isEqualTo: false);

        if (storeCategoryId != null && storeCategoryId.isNotEmpty) {
          query = query.where('storeCategoryId', isEqualTo: storeCategoryId);
        }

        if (filterStatus == 'In Stock') {
          query = query.where('inStock', isEqualTo: true);
        } else if (filterStatus == 'Out of Stock') {
          query = query.where('inStock', isEqualTo: false);
        }

        query = query.orderBy('createdAt', descending: true);

        if (startAfter != null) {
          query = query.startAfterDocument(startAfter);
        }

        query = query.limit(limit);
        snap = await query.get();
      } catch (queryErr) {
        debugPrint('⚠️ [ProfessionalProviderRemoteDataSource] fetchProductsPaginated compound query requires index or failed: $queryErr');
        // Resilient zero-index fallback: single field orderBy createdAt DESC (Firestore single-field index exists automatically)
        try {
          Query resilientQuery = baseCol.orderBy('createdAt', descending: true);
          if (startAfter != null) {
            resilientQuery = resilientQuery.startAfterDocument(startAfter);
          }
          resilientQuery = resilientQuery.limit(limit * 2);
          snap = await resilientQuery.get();
        } catch (resilientErr) {
          debugPrint('⚠️ [ProfessionalProviderRemoteDataSource] Resilient orderBy failed, falling back to direct collection read: $resilientErr');
          snap = await baseCol.limit(limit * 2).get();
        }
      }

      var items = snap.docs.map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>}).toList();

      // Robust in-memory filtering (guarantees correct display even under fallback mode)
      items = items.where((p) {
        if (p['isDeleted'] == true) return false;
        if (storeCategoryId != null && storeCategoryId.isNotEmpty && p['storeCategoryId'] != storeCategoryId) {
          return false;
        }
        if (filterStatus == 'In Stock') {
          final inStock = p['inStock'] as bool? ?? true;
          final qty = (p['stockQuantity'] as num?)?.toInt() ?? 0;
          if (!inStock || qty <= 0) return false;
        } else if (filterStatus == 'Out of Stock') {
          final inStock = p['inStock'] as bool? ?? true;
          final qty = (p['stockQuantity'] as num?)?.toInt() ?? 0;
          if (inStock && qty > 0) return false;
        }
        return true;
      }).toList();

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim().toLowerCase();
        items = items.where((p) {
          final title = (p['titleEnglish'] ?? p['titleHindi'] ?? p['title'] ?? '').toString().toLowerCase();
          return title.contains(q);
        }).toList();
      }

      final hasMore = snap.docs.length >= limit;
      final pagedItems = items.length > limit ? items.sublist(0, limit) : items;

      return {
        'products': pagedItems,
        'lastDoc': snap.docs.isNotEmpty ? snap.docs.last : null,
        'hasMore': hasMore,
      };
    } catch (e, stack) {
      debugPrint('❌ [ProfessionalProviderRemoteDataSource] fetchProductsPaginated fatal error: $e\n$stack');
      return {
        'products': <Map<String, dynamic>>[],
        'lastDoc': null,
        'hasMore': false,
      };
    }
  }

  /// Paginated query for inventory listing with cursor and filters.
  Future<Map<String, dynamic>> fetchInventoryPaginated(
    String shopId, {
    int limit = 25,
    DocumentSnapshot? startAfter,
    String? filterStatus, // 'All', 'In Stock', 'Low Stock', 'Out of Stock'
    String? searchQuery,
  }) async {
    try {
      final baseCol = _firestore.collection(collectionShops).doc(shopId).collection('products');
      QuerySnapshot snap;

      try {
        Query query = baseCol.where('isDeleted', isEqualTo: false);

        if (filterStatus == 'In Stock') {
          query = query.where('inStock', isEqualTo: true);
        } else if (filterStatus == 'Out of Stock') {
          query = query.where('inStock', isEqualTo: false);
        }

        query = query.orderBy('createdAt', descending: true);

        if (startAfter != null) {
          query = query.startAfterDocument(startAfter);
        }

        query = query.limit(limit);
        snap = await query.get();
      } catch (queryErr) {
        debugPrint('⚠️ [ProfessionalProviderRemoteDataSource] fetchInventoryPaginated compound query requires index or failed: $queryErr');
        try {
          Query resilientQuery = baseCol.orderBy('createdAt', descending: true);
          if (startAfter != null) {
            resilientQuery = resilientQuery.startAfterDocument(startAfter);
          }
          resilientQuery = resilientQuery.limit(limit * 2);
          snap = await resilientQuery.get();
        } catch (resilientErr) {
          debugPrint('⚠️ [ProfessionalProviderRemoteDataSource] Resilient inventory query failed: $resilientErr');
          snap = await baseCol.limit(limit * 2).get();
        }
      }

      var items = snap.docs.map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>}).toList();

      // In-memory filter for isDeleted
      items = items.where((p) => p['isDeleted'] != true).toList();

      // In-memory filter for dynamic per-product low stock and stock status
      if (filterStatus == 'In Stock') {
        items = items.where((p) {
          final inStock = (p['inStock'] as bool?) ?? true;
          final qty = (p['stockQuantity'] as num?)?.toInt() ?? 0;
          return inStock && qty > 0;
        }).toList();
      } else if (filterStatus == 'Low Stock') {
        items = items.where((p) {
          final qty = (p['stockQuantity'] as num?)?.toInt() ?? 0;
          final threshold = (p['lowStockThreshold'] as num?)?.toInt() ?? 5;
          final inStock = (p['inStock'] as bool?) ?? true;
          return inStock && qty > 0 && qty <= threshold;
        }).toList();
      } else if (filterStatus == 'Out of Stock') {
        items = items.where((p) {
          final inStock = (p['inStock'] as bool?) ?? true;
          final qty = (p['stockQuantity'] as num?)?.toInt() ?? 0;
          return !inStock || qty <= 0;
        }).toList();
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim().toLowerCase();
        items = items.where((p) {
          final title = (p['titleEnglish'] ?? p['titleHindi'] ?? p['title'] ?? '').toString().toLowerCase();
          return title.contains(q);
        }).toList();
      }

      final hasMore = snap.docs.length >= limit;
      final pagedItems = items.length > limit ? items.sublist(0, limit) : items;

      return {
        'items': pagedItems,
        'lastDoc': snap.docs.isNotEmpty ? snap.docs.last : null,
        'hasMore': hasMore,
      };
    } catch (e, stack) {
      debugPrint('❌ [ProfessionalProviderRemoteDataSource] fetchInventoryPaginated fatal error: $e\n$stack');
      return {
        'items': <Map<String, dynamic>>[],
        'lastDoc': null,
        'hasMore': false,
      };
    }
  }

  Future<void> toggleProductStock(String shopId, String productId, bool inStock) async {
    await _firestore
        .collection(collectionShops)
        .doc(shopId)
        .collection('products')
        .doc(productId)
        .update({
      'inStock': inStock,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteProduct(String shopId, String productId) async {
    await _firestore
        .collection(collectionShops)
        .doc(shopId)
        .collection('products')
        .doc(productId)
        .update({
      'isDeleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<Map<String, dynamic>>> fetchPublishedSubscriptionPlans() async {
    try {
      final snap = await _firestore
          .collection(collectionSubscriptionPlans)
          .where('isActive', isEqualTo: true)
          .orderBy('price')
          .get();

      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (_) {
      return [];
    }
  }

  // --- 2-LEVEL CATEGORY ARCHITECTURE: SELLER STORE CATEGORIES ---
  // Subcollection Path: diamond_shops/{shopId}/store_categories/{storeCategoryId}

  /// Real-time stream of seller's private store categories.
  Stream<List<SellerStoreCategoryEntity>> streamStoreCategories(String shopId) {
    try {
      return _firestore
          .collection(collectionShops)
          .doc(shopId)
          .collection(subcollectionStoreCategories)
          .orderBy('displayOrder')
          .snapshots()
          .map((snap) {
        return snap.docs
            .map((d) => SellerStoreCategoryEntity.fromMap(d.data(), d.id, shopId: shopId))
            .toList();
      });
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Saves or updates a seller store category in the dedicated subcollection.
  Future<void> saveStoreCategory(String shopId, SellerStoreCategoryEntity category) async {
    final col = _firestore
        .collection(collectionShops)
        .doc(shopId)
        .collection(subcollectionStoreCategories);

    if (category.id.isNotEmpty) {
      await col.doc(category.id).set(category.toMap(), SetOptions(merge: true));
    } else {
      await col.add(category.toMap());
    }
  }

  /// Toggles active status of a seller store category.
  Future<void> toggleStoreCategoryActive(String shopId, String categoryId, bool isActive) async {
    await _firestore
        .collection(collectionShops)
        .doc(shopId)
        .collection(subcollectionStoreCategories)
        .doc(categoryId)
        .update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Deletes a seller store category.
  Future<void> deleteStoreCategory(String shopId, String categoryId) async {
    await _firestore
        .collection(collectionShops)
        .doc(shopId)
        .collection(subcollectionStoreCategories)
        .doc(categoryId)
        .delete();
  }

  /// Counts active products currently assigned to a store category.
  Future<int> countProductsReferencingCategory(String shopId, String categoryId) async {
    try {
      final snap = await _firestore
          .collection(collectionShops)
          .doc(shopId)
          .collection('products')
          .where('storeCategoryId', isEqualTo: categoryId)
          .where('isDeleted', isEqualTo: false)
          .get();
      return snap.docs.length;
    } catch (_) {
      return 0;
    }
  }

  /// Adjusts stock atomically via server-authoritative Cloud Function.
  /// Strictly prevents negative stock and concurrency races.
  Future<Map<String, dynamic>> adjustProductStock({
    required String shopId,
    required String productId,
    required String operation, // 'set', 'increment', 'decrement'
    required num amount,
    String? reason,
  }) async {
    final callable = _functions.httpsCallable('adjustDiamondProductStock');
    final result = await callable.call({
      'shopId': shopId,
      'productId': productId,
      'operation': operation,
      'amount': amount,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  // ===========================================================================
  // PROFESSIONAL SELLER RAZORPAY SUBSCRIPTION INTEGRATION (PHASE 1C)
  // ===========================================================================

  /// Initiates server-authoritative Professional Subscription Order on Razorpay via Cloud Functions.
  /// Strictly passes only [shopId] and [planId]. Pricing and duration are resolved server-side.
  Future<Map<String, dynamic>> createProfessionalSubscriptionOrder({
    required String shopId,
    required String planId,
  }) async {
    final callable = _functions.httpsCallable('createProfessionalSubscriptionOrder');
    final result = await callable.call({
      'shopId': shopId.trim(),
      'planId': planId.trim(),
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  /// Cryptographically verifies Razorpay payment and activates subscription atomically via Cloud Functions.
  /// Strictly requires all 5 verification tokens.
  Future<Map<String, dynamic>> verifyProfessionalSubscriptionPayment({
    required String shopId,
    required String planId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    final callable = _functions.httpsCallable('verifyProfessionalSubscriptionPayment');
    final result = await callable.call({
      'shopId': shopId.trim(),
      'planId': planId.trim(),
      'razorpayOrderId': razorpayOrderId.trim(),
      'razorpayPaymentId': razorpayPaymentId.trim(),
      'razorpaySignature': razorpaySignature.trim(),
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  /// Fetches latest pending or pending_retry payment record for failure recovery and re-verification.
  Future<Map<String, dynamic>?> fetchLatestPendingPayment(String shopId) async {
    try {
      final snap = await _firestore
          .collection(collectionPayments)
          .where('shopId', isEqualTo: shopId.trim())
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        final status = data['status'] as String? ?? '';
        if (status == 'pending_retry' || status == 'created') {
          return {'id': snap.docs.first.id, ...data};
        }
      }
    } catch (_) {}
    return null;
  }

  /// Streams payment transaction history for this professional shop from diamond_payments.
  Stream<List<Map<String, dynamic>>> streamShopPayments(String shopId) {
    try {
      return _firestore
          .collection(collectionPayments)
          .where('shopId', isEqualTo: shopId.trim())
          .snapshots()
          .map((snap) {
        final list = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        list.sort((a, b) {
          final aTime = a['createdAt'];
          final bTime = b['createdAt'];
          if (aTime is Timestamp && bTime is Timestamp) {
            return bTime.compareTo(aTime);
          }
          return 0;
        });
        return list;
      });
    } catch (_) {
      return const Stream.empty();
    }
  }

  // ===========================================================================
  // HYBRID VARIANT SUBCOLLECTION CRUD & AGGREGATE RECALCULATION
  // ===========================================================================

  /// Saves or updates a product variant in subcollection:
  /// `diamond_shops/{shopId}/products/{productId}/variants/{variantId}`
  /// Automatically validates price override rules, stores private costs,
  /// and updates parent product aggregates.
  Future<String> saveProductVariant(
    String shopId,
    String productId,
    ProductVariantEntity variant, {
    double? costPrice,
    String? supplierName,
    String? purchaseNotes,
  }) async {
    final prodRef = _firestore
        .collection(collectionShops)
        .doc(shopId)
        .collection('products')
        .doc(productId);

    final parentDoc = await prodRef.get();
    if (!parentDoc.exists || parentDoc.data() == null) {
      throw StateError('Parent product $productId does not exist in shop $shopId');
    }

    final parentData = parentDoc.data()!;
    final basePrice = (parentData['basePrice'] as num?)?.toDouble() ??
        (parentData['sellingPrice'] as num?)?.toDouble() ??
        (parentData['price'] as num?)?.toDouble() ??
        0.0;
    final baseMrp = (parentData['baseMrp'] as num?)?.toDouble() ??
        (parentData['regularPrice'] as num?)?.toDouble() ??
        (parentData['mrp'] as num?)?.toDouble() ??
        basePrice;

    // Validate override rules (rejects invalid price overrides)
    variant.validatePriceOverride(basePrice, baseMrp);

    final isNew = variant.id.isEmpty;
    if (isNew) {
      // Subscription plans do NOT limit weight/size/colour/pack options (legacy maxVariantsPerProduct
      // fields are preserved in data but intentionally ignored). Only a technical abuse cap applies.
      try {
        final existingVariants = await prodRef.collection(subcollectionVariants).get();
        if (existingVariants.docs.length >= technicalMaxVariantsPerProduct) {
          throw StateError('A product can have at most $technicalMaxVariantsPerProduct selling options.');
        }
      } catch (e) {
        if (e is StateError) rethrow;
      }
    }
    final variantRef = isNew
        ? prodRef.collection(subcollectionVariants).doc()
        : prodRef.collection(subcollectionVariants).doc(variant.id);

    final effectiveVariant = variant.copyWith(
      id: variantRef.id,
      productId: productId,
      shopId: shopId,
    );

    final variantMap = effectiveVariant.toMap();
    if (!isNew) {
      // Stock adjustments for existing variants must go through adjustDiamondProductStock
      variantMap.remove('stockQuantity');
    }

    final batch = _firestore.batch();
    batch.set(variantRef, variantMap, SetOptions(merge: true));

    // Confidential vendor-only private pricing
    if (costPrice != null) {
      final pricingRef = prodRef.collection(subcollectionPrivatePricing).doc('cost_data');
      batch.set(
        pricingRef,
        {
          'productId': productId,
          'shopId': shopId,
          'variantCosts': {
            variantRef.id: {
              'costPrice': costPrice,
              if (supplierName != null && supplierName.isNotEmpty) 'supplierName': supplierName,
              if (purchaseNotes != null && purchaseNotes.isNotEmpty) 'purchaseNotes': purchaseNotes,
              'updatedAt': FieldValue.serverTimestamp(),
            }
          },
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();

    // Recompute parent aggregates
    await recomputeParentProductAggregates(shopId, productId);

    return variantRef.id;
  }

  /// Streams real-time variants for a product
  Stream<List<ProductVariantEntity>> streamProductVariants(String shopId, String productId) {
    try {
      return _firestore
          .collection(collectionShops)
          .doc(shopId)
          .collection('products')
          .doc(productId)
          .collection(subcollectionVariants)
          .snapshots()
          .map((snap) {
        return snap.docs
            .map((d) => ProductVariantEntity.fromMap(
                  d.data(),
                  d.id,
                  productId: productId,
                  shopId: shopId,
                ))
            .toList();
      });
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Fetches variants list once for a product
  Future<List<ProductVariantEntity>> fetchProductVariants(String shopId, String productId) async {
    try {
      final snap = await _firestore
          .collection(collectionShops)
          .doc(shopId)
          .collection('products')
          .doc(productId)
          .collection(subcollectionVariants)
          .get();

      return snap.docs
          .map((d) => ProductVariantEntity.fromMap(
                d.data(),
                d.id,
                productId: productId,
                shopId: shopId,
              ))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Soft deactivates or activates a variant (Never hard-deleted to preserve historical orders/ledger)
  Future<void> toggleVariantActive(String shopId, String productId, String variantId, bool isActive) async {
    await _firestore
        .collection(collectionShops)
        .doc(shopId)
        .collection('products')
        .doc(productId)
        .collection(subcollectionVariants)
        .doc(variantId)
        .update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await recomputeParentProductAggregates(shopId, productId);
  }

  /// Safely recomputes and syncs parent product aggregates
  Future<void> recomputeParentProductAggregates(String shopId, String productId) async {
    try {
      final prodRef = _firestore
          .collection(collectionShops)
          .doc(shopId)
          .collection('products')
          .doc(productId);

      final variantsSnap = await prodRef
          .collection(subcollectionVariants)
          .where('isActive', isEqualTo: true)
          .get();

      final parentDoc = await prodRef.get();
      if (!parentDoc.exists || parentDoc.data() == null) return;

      final parentData = parentDoc.data()!;
      final basePrice = (parentData['basePrice'] as num?)?.toDouble() ??
          (parentData['sellingPrice'] as num?)?.toDouble() ??
          (parentData['price'] as num?)?.toDouble() ??
          0.0;

      final allVariantsSnap = await prodRef.collection(subcollectionVariants).get();
      final totalVariantCount = allVariantsSnap.docs.length;

      if (variantsSnap.docs.isEmpty) {
        await prodRef.update({
          'hasVariants': totalVariantCount > 0,
          'variantCount': totalVariantCount,
          'totalStockQuantity': 0,
          'inStock': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      double resolvedMin = double.infinity;
      double resolvedMax = 0.0;
      int resolvedStock = 0;

      for (final doc in variantsSnap.docs) {
        final v = ProductVariantEntity.fromMap(
          doc.data(),
          doc.id,
          productId: productId,
          shopId: shopId,
        );
        final effPrice = v.resolvePrice(basePrice);
        if (effPrice < resolvedMin) resolvedMin = effPrice;
        if (effPrice > resolvedMax) resolvedMax = effPrice;
        resolvedStock += v.stockQuantity;
      }

      await prodRef.update({
        'hasVariants': true,
        'variantCount': totalVariantCount,
        'minPrice': resolvedMin.isFinite ? resolvedMin : basePrice,
        'maxPrice': resolvedMax > 0 ? resolvedMax : basePrice,
        'totalStockQuantity': resolvedStock,
        'inStock': resolvedStock > 0,
        // Mirror fields for backward compatibility with simple product queries
        'price': resolvedMin.isFinite ? resolvedMin : basePrice,
        'sellingPrice': resolvedMin.isFinite ? resolvedMin : basePrice,
        'stockQuantity': resolvedStock,
        'stock': resolvedStock,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // ===========================================================================
  // PROVIDER-CONFIGURABLE STORE FEATURES & CUSTOM ATTRIBUTES
  // ===========================================================================

  /// Saves provider-configurable store features and policies
  Future<void> saveStoreFeatures(String shopId, StoreFeaturesEntity features) async {
    await _firestore.collection(collectionShops).doc(shopId).update({
      'storeFeatures': features.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Fetches provider-configurable store features
  Future<StoreFeaturesEntity> fetchStoreFeatures(String shopId) async {
    try {
      final doc = await _firestore.collection(collectionShops).doc(shopId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        return StoreFeaturesEntity.fromMap(data['storeFeatures'] as Map<String, dynamic>?);
      }
    } catch (_) {}
    return const StoreFeaturesEntity();
  }

  /// Saves a custom attribute and variant template for a provider
  Future<String> saveAttributeTemplate(String shopId, CustomAttributeTemplateEntity template) async {
    final col = _firestore
        .collection(collectionShops)
        .doc(shopId)
        .collection(subcollectionAttributeTemplates);

    final docRef = template.id.isEmpty ? col.doc() : col.doc(template.id);
    final effective = CustomAttributeTemplateEntity(
      id: docRef.id,
      shopId: shopId,
      name: template.name,
      targetCategory: template.targetCategory,
      customVariantTypes: template.customVariantTypes,
      customFields: template.customFields,
    );

    await docRef.set(effective.toMap(), SetOptions(merge: true));
    return docRef.id;
  }

  /// Streams provider's custom attribute templates
  Stream<List<CustomAttributeTemplateEntity>> streamAttributeTemplates(String shopId) {
    try {
      return _firestore
          .collection(collectionShops)
          .doc(shopId)
          .collection(subcollectionAttributeTemplates)
          .snapshots()
          .map((snap) {
        return snap.docs
            .map((d) => CustomAttributeTemplateEntity.fromMap(d.data(), d.id, shopId: shopId))
            .toList();
      });
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Fetches provider's custom attribute templates list once
  Future<List<CustomAttributeTemplateEntity>> fetchAttributeTemplates(String shopId) async {
    try {
      final snap = await _firestore
          .collection(collectionShops)
          .doc(shopId)
          .collection(subcollectionAttributeTemplates)
          .get();

      return snap.docs
          .map((d) => CustomAttributeTemplateEntity.fromMap(d.data(), d.id, shopId: shopId))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}

