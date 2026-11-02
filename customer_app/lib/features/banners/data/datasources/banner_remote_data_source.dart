import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/banner_model.dart';

abstract class BannerRemoteDataSource {
  Stream<List<BannerModel>> watchActiveBanners();
  Future<List<BannerModel>> fetchActiveBanners();
  Future<void> trackImpression(String bannerId, {String? customerId});
  Future<void> trackClick(String bannerId, {String? customerId});
}

class FirebaseBannerRemoteDataSource implements BannerRemoteDataSource {
  final FirebaseFirestore _firestore;
  static const String _bannersCollection = 'banners';
  static const String _analyticsCollection = 'banner_analytics';

  // In-memory cache for active banners to reduce Firestore read costs
  static List<BannerModel>? _cachedBanners;
  static DateTime? _lastFetchTime;
  static const Duration _cacheTtl = Duration(minutes: 15);
  static Stream<List<BannerModel>>? _bannersBroadcastStream;

  FirebaseBannerRemoteDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<List<BannerModel>> watchActiveBanners() {
    _bannersBroadcastStream ??= _firestore
        .collection(_bannersCollection)
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();
      final list = snapshot.docs
          .map((doc) => BannerModel.fromFirestore(doc))
          .where((b) {
            if (!b.isActive) return false;
            if (b.startAt != null && now.isBefore(b.startAt!)) return false;
            if (b.endAt != null && now.isAfter(b.endAt!)) return false;
            return true;
          })
          .toList()
        ..sort((a, b) => a.priority.compareTo(b.priority));
      _cachedBanners = list;
      _lastFetchTime = DateTime.now();
      return list;
    }).asBroadcastStream();
    return _bannersBroadcastStream!;
  }

  @override
  Future<List<BannerModel>> fetchActiveBanners({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _cachedBanners != null &&
        _lastFetchTime != null &&
        now.difference(_lastFetchTime!) < _cacheTtl) {
      return _cachedBanners!;
    }

    try {
      final snapshot = await _firestore
          .collection(_bannersCollection)
          .get()
          .timeout(const Duration(seconds: 5));

      final list = snapshot.docs
          .map((doc) => BannerModel.fromFirestore(doc))
          .where((b) {
            if (!b.isActive) return false;
            if (b.startAt != null && now.isBefore(b.startAt!)) return false;
            if (b.endAt != null && now.isAfter(b.endAt!)) return false;
            return true;
          })
          .toList();

      list.sort((a, b) => a.priority.compareTo(b.priority));
      _cachedBanners = list;
      _lastFetchTime = now;
      return list;
    } catch (_) {
      return _cachedBanners ?? [];
    }
  }

  @override
  Future<void> trackImpression(String bannerId, {String? customerId}) async {
    try {
      // 1. Increment banner doc impressions count
      await _firestore.collection(_bannersCollection).doc(bannerId).update({
        'impressions': FieldValue.increment(1),
        'lastImpressionAt': FieldValue.serverTimestamp(),
      });

      // 2. Add analytics record
      await _firestore.collection(_analyticsCollection).add({
        'bannerId': bannerId,
        'eventType': 'impression',
        'customerId': customerId ?? '',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  @override
  Future<void> trackClick(String bannerId, {String? customerId}) async {
    try {
      // 1. Increment banner doc clicks count
      await _firestore.collection(_bannersCollection).doc(bannerId).update({
        'clicks': FieldValue.increment(1),
        'lastClickAt': FieldValue.serverTimestamp(),
      });

      // 2. Add analytics record
      await _firestore.collection(_analyticsCollection).add({
        'bannerId': bannerId,
        'eventType': 'click',
        'customerId': customerId ?? '',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}
