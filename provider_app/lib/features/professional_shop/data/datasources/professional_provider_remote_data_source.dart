import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../domain/entities/professional_shop_profile_entity.dart';
import '../../domain/entities/seller_store_category_entity.dart';

class ProfessionalProviderRemoteDataSource {
  // Underlying physical collections preserved for Firebase backwards compatibility
  static const String collectionShops = 'diamond_shops';
  static const String collectionOrders = 'diamond_orders';
  static const String collectionSubscriptionPlans = 'diamond_subscription_plans';
  static const String collectionPayments = 'diamond_payments';
  static const String legacyCollectionShops = 'shops';
  static const String subcollectionStoreCategories = 'store_categories';

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

  Future<void> updateShopSettings(String shopId, Map<String, dynamic> data) async {
    await _firestore.collection(collectionShops).doc(shopId).update({
      ...data,
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

  Future<void> saveProduct(String shopId, Map<String, dynamic> productData, {String? productId}) async {
    final col = _firestore.collection(collectionShops).doc(shopId).collection('products');
    if (productId != null && productId.isNotEmpty) {
      await col.doc(productId).update({
        ...productData,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await col.add({
        ...productData,
        'shopId': shopId,
        'isActive': true,
        'isDeleted': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
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
    required int amount,
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
}

