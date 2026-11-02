import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:apna_jamui_customer/core/utils/jamui_geo_validator.dart';
import '../../domain/entities/paginated_shops_result.dart';
import '../../domain/entities/professional_category_entity.dart';
import '../../domain/entities/professional_order_entity.dart';
import '../../domain/entities/professional_product_entity.dart';
import '../../domain/entities/professional_shop_entity.dart';
import 'professional_shop_cache_manager.dart';

class ProfessionalShopRemoteDataSource {
  final FirebaseFirestore? _customFirestore;
  final FirebaseFunctions? _customFunctions;
  final ProfessionalShopCacheManager cacheManager;

  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;
  FirebaseFunctions get _functions =>
      _customFunctions ?? FirebaseFunctions.instanceFor(region: 'asia-south1');

  // Backward-compatible physical Firebase collection names (Preserved per architecture safety rule)
  static const String collectionCategories = 'diamond_categories';
  static const String collectionShops = 'diamond_shops';
  static const String collectionOrders = 'diamond_orders';
  static const String legacyCollectionShops = 'shops';
  static const String legacyCollectionCategories = 'demand_categories';

  ProfessionalShopRemoteDataSource({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    ProfessionalShopCacheManager? cacheManager,
  })  : _customFirestore = firestore,
        _customFunctions = functions,
        cacheManager = cacheManager ?? ProfessionalShopCacheManager();

  Future<List<ProfessionalCategoryEntity>> fetchProfessionalCategories() async {
    try {
      QuerySnapshot? snap;
      try {
        snap = await _firestore
            .collection(collectionCategories)
            .where('isActive', isEqualTo: true)
            .get()
            .timeout(const Duration(seconds: 5));
      } catch (_) {}

      if (snap == null || snap.docs.isEmpty) {
        try {
          snap = await _firestore
              .collection(collectionCategories)
              .get()
              .timeout(const Duration(seconds: 5));
        } catch (_) {}
      }

      if (snap == null || snap.docs.isEmpty) {
        try {
          snap = await _firestore
              .collection(legacyCollectionCategories)
              .where('isActive', isEqualTo: true)
              .get()
              .timeout(const Duration(seconds: 5));
        } catch (_) {}
      }

      if (snap == null || snap.docs.isEmpty) {
        return [];
      }

      final list = snap.docs
          .map((doc) => ProfessionalCategoryEntity.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .where((cat) => cat.isActive)
          .toList();

      list.sort((a, b) => a.priorityOrder.compareTo(b.priorityOrder));
      return list;
    } catch (_) {
      return [];
    }
  }

  /// Backward-compatible shop fetching method.
  Future<List<ProfessionalShopEntity>> fetchNearbyShops({
    String? categoryId,
    double? customerLat,
    double? customerLng,
    String? jamuiArea,
    String? areaId,
    int limit = 100,
    bool forceRefresh = false,
  }) async {
    final result = await fetchPaginatedShops(
      categoryId: categoryId,
      customerLat: customerLat,
      customerLng: customerLng,
      areaId: areaId,
      chunkSize: limit,
      forceRefresh: forceRefresh,
    );
    return result.shops;
  }

  /// Paginated cursor-based shop fetching with 5 mandatory security filters,
  /// 100-doc uniform chunking, dynamic GPS re-evaluation, and LRU caching.
  Future<PaginatedProfessionalShopsResult> fetchPaginatedShops({
    String? categoryId,
    double? customerLat,
    double? customerLng,
    String? areaId,
    DocumentSnapshot? lastDoc,
    int chunkSize = 100,
    bool forceRefresh = false,
  }) async {
    final cleanCategory = (categoryId != null && categoryId.isNotEmpty && categoryId != 'all')
        ? categoryId
        : '';
    final hasGps = customerLat != null &&
        customerLng != null &&
        JamuiGeoValidator.isValidCoordinates(customerLat, customerLng);

    // 1. Check in-memory cache for initial page when forceRefresh is false
    if (lastDoc == null && !forceRefresh && hasGps) {
      final cachedEntry = cacheManager.get(
        categoryId: cleanCategory,
        lat: customerLat,
        lng: customerLng,
      );

      if (cachedEntry != null) {
        // Post-Cache Dynamic Re-evaluation: Live distance and sorting recalculated
        final reEvaluated = _processAndSortShops(
          rawShops: cachedEntry.rawShops,
          customerLat: customerLat,
          customerLng: customerLng,
          hasGps: true,
        );

        return PaginatedProfessionalShopsResult(
          shops: reEvaluated,
          lastDoc: cachedEntry.lastDoc,
          hasMore: cachedEntry.hasMore,
          totalLoaded: reEvaluated.length,
          isFromCache: true,
        );
      }
    }

    // 2. Build Query adhering strictly to 5 mandatory Firestore Security Rules filters
    Query query = _firestore
        .collection(collectionShops)
        .where('status', isEqualTo: 'approved')
        .where('isApproved', isEqualTo: true)
        .where('isActive', isEqualTo: true)
        .where('isSubscriptionActive', isEqualTo: true)
        .where('isDeleted', isEqualTo: false);

    if (cleanCategory.isNotEmpty) {
      query = query.where('demandCategoryId', isEqualTo: cleanCategory);
    }

    // Apply cursor pagination
    if (lastDoc != null) {
      query = query.startAfterDocument(lastDoc);
    }

    query = query.limit(chunkSize);

    QuerySnapshot? snap;
    try {
      snap = await query.get().timeout(const Duration(seconds: 7));
    } catch (e) {
      debugPrint('[ProfessionalShopDataSource] Primary query error: $e');
    }

    // Fallback: Query legacy collection if primary collection has no docs
    if (snap == null || snap.docs.isEmpty) {
      try {
        Query fallbackQuery = _firestore
            .collection(legacyCollectionShops)
            .where('status', isEqualTo: 'approved')
            .where('isApproved', isEqualTo: true)
            .where('isActive', isEqualTo: true)
            .where('isSubscriptionActive', isEqualTo: true)
            .where('isDeleted', isEqualTo: false);

        if (cleanCategory.isNotEmpty) {
          fallbackQuery = fallbackQuery.where('demandCategoryId', isEqualTo: cleanCategory);
        }
        if (lastDoc != null) {
          fallbackQuery = fallbackQuery.startAfterDocument(lastDoc);
        }
        fallbackQuery = fallbackQuery.limit(chunkSize);
        snap = await fallbackQuery.get().timeout(const Duration(seconds: 7));
      } catch (_) {}
    }

    if (snap == null || snap.docs.isEmpty) {
      return const PaginatedProfessionalShopsResult(
        shops: [],
        lastDoc: null,
        hasMore: false,
        totalLoaded: 0,
        isFromCache: false,
      );
    }

    // 3. Map documents to entities and filter approved & live
    final rawShops = snap.docs
        .map((doc) => ProfessionalShopEntity.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .where((s) => s.isApprovedAndLive)
        .toList();

    // 4. Calculate live distance & sort nearest-first
    final processedShops = _processAndSortShops(
      rawShops: rawShops,
      customerLat: customerLat,
      customerLng: customerLng,
      hasGps: hasGps,
    );

    final hasMore = snap.docs.length >= chunkSize;
    final lastVisibleDoc = snap.docs.isNotEmpty ? snap.docs.last : null;

    // 5. Store in Cache for initial page
    if (lastDoc == null && hasGps) {
      cacheManager.put(
        categoryId: cleanCategory,
        lat: customerLat,
        lng: customerLng,
        rawShops: rawShops,
        lastDoc: lastVisibleDoc,
        hasMore: hasMore,
      );
    }

    return PaginatedProfessionalShopsResult(
      shops: processedShops,
      lastDoc: lastVisibleDoc,
      hasMore: hasMore,
      totalLoaded: processedShops.length,
      isFromCache: false,
    );
  }

  /// Evaluates distance, filters invalid coordinates, and sorts nearest-first.
  List<ProfessionalShopEntity> _processAndSortShops({
    required List<ProfessionalShopEntity> rawShops,
    double? customerLat,
    double? customerLng,
    required bool hasGps,
  }) {
    List<ProfessionalShopEntity> list = rawShops;

    if (hasGps && customerLat != null && customerLng != null) {
      list = list.map((shop) {
        if (shop.hasValidLocation) {
          final dist = JamuiGeoValidator.calculateHaversineDistanceKm(
            customerLat,
            customerLng,
            shop.latitude,
            shop.longitude,
          );
          return shop.copyWith(distanceKm: dist);
        }
        return shop.copyWith(distanceKm: null);
      }).toList();

      // Nearest-First Sort: Valid distance shops first (ascending),
      // Invalid location / fallback shops partitioned to the bottom.
      list.sort((a, b) {
        final distA = a.distanceKm;
        final distB = b.distanceKm;

        if (distA != null && distB != null) {
          return distA.compareTo(distB);
        } else if (distA != null && distB == null) {
          return -1; // Valid location placed before invalid
        } else if (distA == null && distB != null) {
          return 1;  // Invalid location placed after valid
        }
        return a.shopName.toLowerCase().compareTo(b.shopName.toLowerCase());
      });
    }

    return list;
  }

  /// Search with automatic background cursor drain capped strictly at [maxReadCeiling] (default 300).
  ///
  /// Prevents runaway Firestore reads while searching deeper than position 100.
  Future<PaginatedProfessionalShopsResult> searchShopsWithCeiling({
    required String queryText,
    String? categoryId,
    double? customerLat,
    double? customerLng,
    String? areaId,
    int maxReadCeiling = 300,
    int chunkSize = 100,
    int? generationToken,
  }) async {
    final cleanQuery = queryText.trim().toLowerCase();
    if (cleanQuery.isEmpty) {
      return fetchPaginatedShops(
        categoryId: categoryId,
        customerLat: customerLat,
        customerLng: customerLng,
        areaId: areaId,
        chunkSize: chunkSize,
      );
    }

    final accumulatedShops = <ProfessionalShopEntity>[];
    final seenIds = <String>{};
    DocumentSnapshot? currentCursor;
    var hasMore = true;
    var totalFetchedDocs = 0;

    while (hasMore && totalFetchedDocs < maxReadCeiling) {
      final chunkResult = await fetchPaginatedShops(
        categoryId: categoryId,
        customerLat: customerLat,
        customerLng: customerLng,
        areaId: areaId,
        lastDoc: currentCursor,
        chunkSize: chunkSize,
        forceRefresh: false,
      );

      totalFetchedDocs += chunkSize;
      currentCursor = chunkResult.lastDoc;
      hasMore = chunkResult.hasMore;

      for (final shop in chunkResult.shops) {
        if (!seenIds.contains(shop.id)) {
          seenIds.add(shop.id);
          accumulatedShops.add(shop);
        }
      }

      if (currentCursor == null) break;
    }

    // In-memory case-insensitive keyword filtering across accumulated pool
    final matchedShops = accumulatedShops.where((s) {
      return s.shopName.toLowerCase().contains(cleanQuery) ||
          s.description.toLowerCase().contains(cleanQuery) ||
          s.jamuiArea.toLowerCase().contains(cleanQuery) ||
          s.fullAddress.toLowerCase().contains(cleanQuery);
    }).toList();

    return PaginatedProfessionalShopsResult(
      shops: matchedShops,
      lastDoc: currentCursor,
      hasMore: hasMore,
      totalLoaded: accumulatedShops.length,
      isFromCache: false,
    );
  }

  /// Pure filtering utility applying tab rules: 'all', 'delivery', 'pickup', 'open'.
  static List<ProfessionalShopEntity> filterShopsByTab({
    required List<ProfessionalShopEntity> shops,
    required String activeTab,
    required bool hasGps,
    String? selectedAreaId,
  }) {
    switch (activeTab.toLowerCase()) {
      case 'delivery':
        // If GPS is disabled, delivery tab is suppressed (cannot verify radius)
        if (!hasGps) return [];
        return shops
            .where((s) => s.isDeliveryEligibleForDistance(s.distanceKm))
            .toList();

      case 'pickup':
        return shops.where((s) {
          if (!s.isPickupActive) return false;
          if (hasGps) return true;
          // Fail-closed structured locality matching when GPS is disabled
          if (selectedAreaId != null && selectedAreaId.isNotEmpty) {
            return s.areaId == selectedAreaId;
          }
          return s.jamuiArea.isNotEmpty;
        }).toList();

      case 'open':
      case 'open now':
        return shops.where((s) {
          if (!s.isOpenNowAt()) return false;
          if (hasGps) {
            return s.isDeliveryEligibleForDistance(s.distanceKm) || s.isPickupActive;
          }
          return s.isPickupActive;
        }).toList();

      case 'all':
      default:
        return shops.where((s) {
          if (hasGps) {
            return s.isDeliveryEligibleForDistance(s.distanceKm) || s.isPickupActive;
          }
          // GPS unavailable: Never show delivery-only shops in fallback
          if (!s.isPickupActive) return false;
          if (selectedAreaId != null && selectedAreaId.isNotEmpty) {
            return s.areaId == selectedAreaId;
          }
          return s.jamuiArea.isNotEmpty;
        }).toList();
    }
  }

  /// Deduplicates incoming shops against existing accumulated list by shop ID.
  static List<ProfessionalShopEntity> deduplicateShops(
    List<ProfessionalShopEntity> existing,
    List<ProfessionalShopEntity> incoming,
  ) {
    final seen = existing.map((s) => s.id).toSet();
    final combined = List<ProfessionalShopEntity>.from(existing);
    for (final shop in incoming) {
      if (!seen.contains(shop.id)) {
        seen.add(shop.id);
        combined.add(shop);
      }
    }
    return combined;
  }

  Future<ProfessionalShopEntity?> fetchShopDetails(String shopId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection(collectionShops).doc(shopId).get();
      if (!doc.exists) {
        doc = await _firestore.collection(legacyCollectionShops).doc(shopId).get();
      }
      if (doc.exists && doc.data() != null) {
        final shop = ProfessionalShopEntity.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        if (shop.isApprovedAndLive) {
          return shop;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<ProfessionalShopEntity?> fetchShopById(String shopId) => fetchShopDetails(shopId);

  Future<List<ProfessionalProductEntity>> fetchShopProducts(String shopId, {String? category}) async {
    try {
      Query query = _firestore.collection(collectionShops).doc(shopId).collection('products');
      if (category != null && category.isNotEmpty && category != 'All' && category != 'सभी उत्पाद') {
        query = query.where('categoryName', isEqualTo: category);
      }

      QuerySnapshot snap = await query.get().timeout(const Duration(seconds: 6));

      if (snap.docs.isEmpty) {
        Query fallbackQuery = _firestore.collection(legacyCollectionShops).doc(shopId).collection('products');
        if (category != null && category.isNotEmpty && category != 'All' && category != 'सभी उत्पाद') {
          fallbackQuery = fallbackQuery.where('categoryName', isEqualTo: category);
        }
        snap = await fallbackQuery.get().timeout(const Duration(seconds: 6));
      }

      return snap.docs
          .map((doc) => ProfessionalProductEntity.fromMap(doc.data() as Map<String, dynamic>, doc.id, shopId))
          .where((p) => p.isActive && !p.isDeleted)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> fetchShopProductCategories(String shopId) async {
    try {
      // 1. Primary: diamond_shops/{shopId}/store_categories where isActive == true
      QuerySnapshot snap = await _firestore
          .collection(collectionShops)
          .doc(shopId)
          .collection('store_categories')
          .where('isActive', isEqualTo: true)
          .get()
          .timeout(const Duration(seconds: 4));

      if (snap.docs.isEmpty) {
        snap = await _firestore
            .collection(collectionShops)
            .doc(shopId)
            .collection('store_categories')
            .get()
            .timeout(const Duration(seconds: 4));
      }

      if (snap.docs.isEmpty) {
        snap = await _firestore
            .collection(collectionShops)
            .doc(shopId)
            .collection('categories')
            .get()
            .timeout(const Duration(seconds: 4));
      }

      if (snap.docs.isEmpty) {
        snap = await _firestore
            .collection(legacyCollectionShops)
            .doc(shopId)
            .collection('categories')
            .get()
            .timeout(const Duration(seconds: 4));
      }

      if (snap.docs.isNotEmpty) {
        return snap.docs
            .map((d) {
              final data = d.data() as Map<String, dynamic>;
              return (data['name'] ?? data['nameEnglish'] ?? data['nameHindi'] ?? d.id).toString();
            })
            .where((s) => s.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<String> placeOrder(ProfessionalOrderEntity order) async {
    try {
      final callable = _functions.httpsCallable('placeDiamondOrder');
      final payload = {
        'shopId': order.shopId,
        'items': order.items.map((it) => {
          'productId': it.productId,
          'quantity': it.quantity,
        }).toList(),
        'deliveryMethod': order.fulfillmentType,
        'deliveryAddress': order.deliveryAddress != null
            ? {
                'customerName': order.customerName,
                'contactPhone': order.customerPhone,
                'address': order.deliveryAddress!['address'] ?? '',
                'area': order.deliveryAddress!['area'] ?? '',
                'latitude': order.deliveryAddress!['latitude'] ?? 0,
                'longitude': order.deliveryAddress!['longitude'] ?? 0,
              }
            : null,
        'customerNotes': order.customerNotes,
        'idempotencyKey': 'ord_${order.customerId}_${order.shopId}_${order.createdAt.millisecondsSinceEpoch}',
      };

      final response = await callable.call(payload);
      final data = response.data as Map<dynamic, dynamic>? ?? {};
      return (data['orderId'] ?? data['orderNumber'] ?? order.orderId).toString();
    } on FirebaseFunctionsException catch (fe) {
      throw Exception(fe.message ?? 'Order placement failed: ${fe.code}');
    } catch (e) {
      throw Exception('Failed to place order: $e');
    }
  }

  Stream<ProfessionalOrderEntity?> streamOrder(String orderId) {
    return _firestore.collection(collectionOrders).doc(orderId).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return ProfessionalOrderEntity.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    });
  }

  Stream<List<ProfessionalOrderEntity>> streamCustomerOrders(String customerId) {
    return _firestore
        .collection(collectionOrders)
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ProfessionalOrderEntity.fromMap(d.data(), d.id))
            .toList());
  }

  Future<List<ProfessionalOrderEntity>> fetchCustomerOrders(String customerId) async {
    try {
      final snap = await _firestore
          .collection(collectionOrders)
          .where('customerId', isEqualTo: customerId)
          .orderBy('createdAt', descending: true)
          .get();

      return snap.docs
          .map((d) => ProfessionalOrderEntity.fromMap(d.data(), d.id))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
