import 'package:cloud_firestore/cloud_firestore.dart';

class ProfessionalAdminRemoteDataSource {
  // Underlying physical collections preserved for Firebase backwards compatibility
  static const String collectionShops = 'diamond_shops';
  static const String collectionOrders = 'diamond_orders';
  static const String collectionCategories = 'diamond_categories';
  static const String collectionSubscriptionPlans = 'diamond_subscription_plans';
  static const String collectionPayments = 'diamond_payments';

  final FirebaseFirestore _firestore;

  ProfessionalAdminRemoteDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // --- KPI Metrics ---
  Future<Map<String, dynamic>> fetchDashboardMetrics() async {
    try {
      final shopsSnap = await _firestore.collection(collectionShops).get();
      final activeShops = shopsSnap.docs.where((d) => (d.data()['isActive'] as bool?) ?? true).length;
      final ordersSnap = await _firestore.collection(collectionOrders).get();

      double totalSales = 0.0;
      for (final doc in ordersSnap.docs) {
        final amt = (doc.data()['totalAmount'] as num?)?.toDouble() ?? 0.0;
        totalSales += amt;
      }

      return {
        'totalShops': shopsSnap.docs.length,
        'activeShops': activeShops,
        'totalOrders': ordersSnap.docs.length,
        'totalSales': totalSales,
      };
    } catch (_) {
      return {
        'totalShops': 0,
        'activeShops': 0,
        'totalOrders': 0,
        'totalSales': 0.0,
      };
    }
  }

  // --- Professional Categories CRUD ---
  Stream<List<Map<String, dynamic>>> streamCategories() {
    return _firestore
        .collection(collectionCategories)
        .orderBy('priorityOrder')
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Future<String> addCategory({
    required String titleEnglish,
    required String titleHindi,
    required String slug,
    required String iconUrl,
    required int priority,
  }) async {
    final cleanSlug = slug.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
    if (cleanSlug.isEmpty) {
      throw ArgumentError('Category slug cannot be empty or invalid.');
    }
    if (titleEnglish.trim().isEmpty) {
      throw ArgumentError('English title cannot be empty.');
    }

    final docRef = _firestore.collection(collectionCategories).doc(cleanSlug);
    final data = {
      'titleEnglish': titleEnglish.trim(),
      'titleHindi': titleHindi.trim().isNotEmpty ? titleHindi.trim() : titleEnglish.trim(),
      'slug': cleanSlug,
      'iconUrl': iconUrl.trim(),
      'priorityOrder': priority,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await docRef.set(data);

    // Read-after-write verification
    final verifyDoc = await docRef.get();
    if (!verifyDoc.exists) {
      throw Exception('Category save verification failed: document was not persisted.');
    }

    return cleanSlug;
  }

  Future<void> updateCategory({
    required String slug,
    required String titleEnglish,
    required String titleHindi,
    required String iconUrl,
    required int priority,
    bool? isActive,
  }) async {
    final cleanSlug = slug.trim().toLowerCase();
    if (cleanSlug.isEmpty) {
      throw ArgumentError('Category slug cannot be empty.');
    }

    final docRef = _firestore.collection(collectionCategories).doc(cleanSlug);
    final payload = <String, dynamic>{
      'titleEnglish': titleEnglish.trim(),
      'titleHindi': titleHindi.trim().isNotEmpty ? titleHindi.trim() : titleEnglish.trim(),
      'iconUrl': iconUrl.trim(),
      'priorityOrder': priority,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (isActive != null) {
      payload['isActive'] = isActive;
    }

    await docRef.update(payload);

    // Read-after-write verification
    final verifyDoc = await docRef.get();
    if (!verifyDoc.exists) {
      throw Exception('Category update verification failed: document does not exist.');
    }
  }

  Future<void> toggleCategoryActive(String catId, bool isActive) async {
    await _firestore.collection(collectionCategories).doc(catId).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // --- Professional Shops Management ---
  Stream<List<Map<String, dynamic>>> streamShops() {
    return _firestore
        .collection(collectionShops)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Future<void> updateShopStatus(String shopId, String status, {bool? isActive}) async {
    final payload = <String, dynamic>{
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (status == 'approved') {
      payload['isApproved'] = true;
      payload['isActive'] = true;
    } else if (status == 'suspended') {
      payload['isActive'] = false;
    } else if (status == 'rejected') {
      payload['isApproved'] = false;
      payload['isActive'] = false;
    }
    if (isActive != null) {
      payload['isActive'] = isActive;
    }
    await _firestore.collection(collectionShops).doc(shopId).update(payload);
  }

  // --- Subscription Plans CRUD ---
  Stream<List<Map<String, dynamic>>> streamPlans() {
    return _firestore
        .collection(collectionSubscriptionPlans)
        .orderBy('price')
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Future<String> addPlan({
    required String name,
    required double price,
    required int durationDays,
    required int maxProducts,
    required int maxImagesPerMonth,
    required int storageMb,
  }) async {
    if (name.trim().isEmpty) {
      throw ArgumentError('Plan name cannot be empty.');
    }
    if (price < 0) {
      throw ArgumentError('Price cannot be negative.');
    }
    if (durationDays <= 0 || durationDays > 3650) {
      throw ArgumentError('Duration must be a positive integer between 1 and 3650 days.');
    }
    if (maxProducts <= 0) {
      throw ArgumentError('Max products must be greater than zero.');
    }

    final docRef = await _firestore.collection(collectionSubscriptionPlans).add({
      'name': name.trim(),
      'price': price,
      'durationDays': durationDays,
      'maxProducts': maxProducts,
      'maxImagesPerMonth': maxImagesPerMonth,
      'storageMb': storageMb,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Read-after-write verification
    final verifyDoc = await docRef.get();
    if (!verifyDoc.exists) {
      throw Exception('Plan creation verification failed: document was not persisted.');
    }

    return docRef.id;
  }

  Future<void> updatePlan({
    required String planId,
    required String name,
    required double price,
    required int durationDays,
    required int maxProducts,
    required int maxImagesPerMonth,
    required int storageMb,
    bool? isActive,
  }) async {
    if (planId.trim().isEmpty) {
      throw ArgumentError('Plan ID cannot be empty.');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError('Plan name cannot be empty.');
    }
    if (price < 0) {
      throw ArgumentError('Price cannot be negative.');
    }
    if (durationDays <= 0 || durationDays > 3650) {
      throw ArgumentError('Duration must be a positive integer between 1 and 3650 days.');
    }

    final docRef = _firestore.collection(collectionSubscriptionPlans).doc(planId.trim());
    final payload = <String, dynamic>{
      'name': name.trim(),
      'price': price,
      'durationDays': durationDays,
      'maxProducts': maxProducts,
      'maxImagesPerMonth': maxImagesPerMonth,
      'storageMb': storageMb,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (isActive != null) {
      payload['isActive'] = isActive;
    }

    await docRef.update(payload);

    // Read-after-write verification
    final verifyDoc = await docRef.get();
    if (!verifyDoc.exists) {
      throw Exception('Plan update verification failed: document does not exist.');
    }
  }

  Future<void> togglePlanActive(String planId, bool isActive) async {
    await _firestore.collection(collectionSubscriptionPlans).doc(planId).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // --- City-Wide Orders Stream ---
  Stream<List<Map<String, dynamic>>> streamOrders() {
    return _firestore
        .collection(collectionOrders)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  // --- Comprehensive Real-Time Shop Inspection Metrics ---
  Future<Map<String, dynamic>> fetchShopInspectionDetails(String shopId, {String? ownerUid}) async {
    int totalProducts = 0;
    int activeProducts = 0;
    int inactiveProducts = 0;
    try {
      final snap = await _firestore.collection(collectionShops).doc(shopId).collection('products').get();
      totalProducts = snap.docs.length;
      activeProducts = snap.docs.where((d) {
        final data = d.data();
        final active = (data['isActive'] as bool?) ?? true;
        final deleted = (data['isDeleted'] as bool?) ?? false;
        return active && !deleted;
      }).length;
      inactiveProducts = totalProducts - activeProducts;
    } catch (_) {}

    int totalStoreCategories = 0;
    int activeStoreCategories = 0;
    int inactiveStoreCategories = 0;
    try {
      final snap = await _firestore.collection(collectionShops).doc(shopId).collection('store_categories').get();
      totalStoreCategories = snap.docs.length;
      activeStoreCategories = snap.docs.where((d) => (d.data()['isActive'] as bool?) ?? true).length;
      inactiveStoreCategories = totalStoreCategories - activeStoreCategories;
    } catch (_) {}

    int totalOrders = 0;
    int deliveredOrders = 0;
    int cancelledOrders = 0;
    double totalOrderValue = 0.0;
    try {
      final snap = await _firestore.collection(collectionOrders).where('shopId', isEqualTo: shopId).get();
      totalOrders = snap.docs.length;
      for (final doc in snap.docs) {
        final data = doc.data();
        final status = (data['status'] as String? ?? '').toLowerCase();
        if (status == 'delivered') deliveredOrders++;
        if (status == 'cancelled' || status == 'rejected') cancelledOrders++;
        totalOrderValue += (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
      }
    } catch (_) {}

    Map<String, dynamic>? latestPayment;
    try {
      final snap = await _firestore
          .collection(collectionPayments)
          .where('shopId', isEqualTo: shopId)
          .get();
      if (snap.docs.isNotEmpty) {
        final docs = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        docs.sort((a, b) {
          final aTime = a['createdAt'];
          final bTime = b['createdAt'];
          if (aTime is Timestamp && bTime is Timestamp) {
            return bTime.compareTo(aTime);
          }
          return 0;
        });
        latestPayment = docs.first;
      }
    } catch (_) {}

    return {
      'totalProducts': totalProducts,
      'activeProducts': activeProducts,
      'inactiveProducts': inactiveProducts,
      'totalStoreCategories': totalStoreCategories,
      'activeStoreCategories': activeStoreCategories,
      'inactiveStoreCategories': inactiveStoreCategories,
      'totalOrders': totalOrders,
      'deliveredOrders': deliveredOrders,
      'cancelledOrders': cancelledOrders,
      'totalOrderValue': totalOrderValue,
      'latestPayment': latestPayment,
    };
  }
}

