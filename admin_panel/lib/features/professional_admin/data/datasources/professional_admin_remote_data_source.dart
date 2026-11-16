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
    final shopsSnap = await _firestore.collection(collectionShops).get();
    final activeShops = shopsSnap.docs.where((d) => (d.data()['isActive'] as bool?) ?? true).length;
    final ordersSnap = await _firestore.collection(collectionOrders).get();

    double totalSales = 0.0;
    for (final doc in ordersSnap.docs) {
      final data = doc.data();
      final status = (data['status'] as String? ?? '').toLowerCase().trim();
      // Sales definition: Only delivered or collected customer orders contribute to authoritative revenue
      if (status == 'delivered' || status == 'collected') {
        final sub = (data['subtotal'] as num?)?.toDouble() ??
            (((data['totalAmount'] as num?)?.toDouble() ?? 0.0) -
                ((data['deliveryFee'] as num?)?.toDouble() ?? 0.0));
        totalSales += (sub > 0 ? sub : 0.0);
      }
    }

    return {
      'totalShops': shopsSnap.docs.length,
      'activeShops': activeShops,
      'totalOrders': ordersSnap.docs.length,
      'totalSales': totalSales,
    };
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
    int maxVariantsPerProduct = 5,
    required int maxImagesPerMonth,
    required int storageMb,
    bool advancedAnalytics = false,
    bool promotionalTools = false,
    bool lowStockAlerts = true,
    bool customAttributes = true,
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
      'productLimit': maxProducts,
      'maxVariantsPerProduct': maxVariantsPerProduct,
      'variantLimit': maxVariantsPerProduct,
      'maxImagesPerMonth': maxImagesPerMonth,
      'imageLimit': maxImagesPerMonth,
      'storageMb': storageMb,
      'storageLimitMb': storageMb,
      'advancedAnalytics': advancedAnalytics,
      'promotionalTools': promotionalTools,
      'lowStockAlerts': lowStockAlerts,
      'customAttributes': customAttributes,
      'features': {
        'advancedAnalytics': advancedAnalytics,
        'promotionalTools': promotionalTools,
        'lowStockAlerts': lowStockAlerts,
        'customAttributes': customAttributes,
      },
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
    int maxVariantsPerProduct = 5,
    required int maxImagesPerMonth,
    required int storageMb,
    bool? advancedAnalytics,
    bool? promotionalTools,
    bool? lowStockAlerts,
    bool? customAttributes,
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
      'productLimit': maxProducts,
      'maxVariantsPerProduct': maxVariantsPerProduct,
      'variantLimit': maxVariantsPerProduct,
      'maxImagesPerMonth': maxImagesPerMonth,
      'imageLimit': maxImagesPerMonth,
      'storageMb': storageMb,
      'storageLimitMb': storageMb,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (advancedAnalytics != null) payload['advancedAnalytics'] = advancedAnalytics;
    if (promotionalTools != null) payload['promotionalTools'] = promotionalTools;
    if (lowStockAlerts != null) payload['lowStockAlerts'] = lowStockAlerts;
    if (customAttributes != null) payload['customAttributes'] = customAttributes;
    if (advancedAnalytics != null || promotionalTools != null || lowStockAlerts != null || customAttributes != null) {
      payload['features'] = {
        'advancedAnalytics': advancedAnalytics ?? false,
        'promotionalTools': promotionalTools ?? false,
        'lowStockAlerts': lowStockAlerts ?? true,
        'customAttributes': customAttributes ?? true,
      };
    }
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

  /// Fetches 7-day delivered sales totals (IST-adjusted) for the bar chart.
  /// Returns a list of 7 entries: [{label: 'Mon 03', sales: 1200.0}, ...]
  /// ordered from 6 days ago → today.
  Future<List<Map<String, dynamic>>> fetchWeeklySalesData() async {
    final now = DateTime.now().toUtc();
    // Start of 7 days ago (UTC midnight)
    final weekStart = DateTime.utc(now.year, now.month, now.day)
        .subtract(const Duration(days: 6));

    final snap = await _firestore
        .collection(collectionOrders)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
        .get()
        .timeout(const Duration(seconds: 8));

    // Bucket by UTC date string 'yyyy-MM-dd'
    final Map<String, double> buckets = {};
    for (var i = 0; i < 7; i++) {
      final day = weekStart.add(Duration(days: i));
      final key =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      buckets[key] = 0.0;
    }

    for (final doc in snap.docs) {
      final data = doc.data();
      final status = (data['status'] as String? ?? '').toLowerCase();
      if (status != 'delivered' && status != 'collected') continue;

      final ts = data['createdAt'];
      DateTime? dt;
      if (ts is Timestamp) {
        dt = ts.toDate().toUtc();
      }
      if (dt == null) continue;

      final key =
          '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      if (buckets.containsKey(key)) {
        final sub = (data['subtotal'] as num?)?.toDouble() ??
            (((data['totalAmount'] as num?)?.toDouble() ?? 0.0) -
                ((data['deliveryFee'] as num?)?.toDouble() ?? 0.0));
        buckets[key] = (buckets[key] ?? 0.0) + (sub > 0 ? sub : 0.0);
      }
    }

    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const monthLabels = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    final result = <Map<String, dynamic>>[];
    for (var i = 0; i < 7; i++) {
      final day = weekStart.add(Duration(days: i));
      final key =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final dayOfWeek = dayLabels[day.weekday - 1]; // weekday 1=Mon
      final label = '$dayOfWeek ${day.day.toString().padLeft(2, '0')} ${monthLabels[day.month - 1]}';
      result.add({'label': label, 'sales': buckets[key] ?? 0.0});
    }
    return result;
  }

  /// Fetches order status breakdown for the donut chart.
  /// Returns {delivered, preparing, pending, cancelled, total}.
  Future<Map<String, int>> fetchOrderStatusBreakdown() async {
    final snap = await _firestore
        .collection(collectionOrders)
        .get()
        .timeout(const Duration(seconds: 8));

    int delivered = 0, preparing = 0, pending = 0, cancelled = 0;
    for (final doc in snap.docs) {
      final status =
          ((doc.data()['status'] as String?) ?? '').toLowerCase().trim();
      if (status == 'delivered' || status == 'collected') {
        delivered++;
      } else if (status == 'preparing' || status == 'accepted') {
        preparing++;
      } else if (status == 'placed') {
        pending++;
      } else if (status == 'cancelled' || status == 'rejected') {
        cancelled++;
      }
    }

    return {
      'delivered': delivered,
      'preparing': preparing,
      'pending': pending,
      'cancelled': cancelled,
      'total': snap.docs.length,
    };
  }
}

