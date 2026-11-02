import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/admin_banner_model.dart';

abstract class AdminBannerRemoteDataSource {
  Stream<List<AdminBannerModel>> watchAllBanners();
  Future<void> createBanner(AdminBannerModel banner);
  Future<void> updateBanner(AdminBannerModel banner);
  Future<void> toggleBannerStatus(String bannerId, bool isActive);
  Future<void> deleteBanner(String bannerId);
}

class FirebaseAdminBannerRemoteDataSource implements AdminBannerRemoteDataSource {
  final FirebaseFirestore _firestore;
  static const String _bannersCollection = 'banners';

  FirebaseAdminBannerRemoteDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<List<AdminBannerModel>> watchAllBanners() {
    return _firestore.collection(_bannersCollection).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => AdminBannerModel.fromFirestore(doc))
          .where((b) => b.props.isNotEmpty)
          .toList()
        ..sort((a, b) => a.priority.compareTo(b.priority));
    });
  }

  @override
  Future<void> createBanner(AdminBannerModel banner) async {
    final docRef = _firestore.collection(_bannersCollection).doc();
    final map = banner.toMap();
    map['createdAt'] = FieldValue.serverTimestamp();
    await docRef.set(map);
  }

  @override
  Future<void> updateBanner(AdminBannerModel banner) async {
    final map = banner.toMap();
    await _firestore.collection(_bannersCollection).doc(banner.id).update(map);
  }

  @override
  Future<void> toggleBannerStatus(String bannerId, bool isActive) async {
    await _firestore.collection(_bannersCollection).doc(bannerId).update({
      'isActive': isActive,
      'status': isActive ? 'active' : 'inactive',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> deleteBanner(String bannerId) async {
    await _firestore.collection(_bannersCollection).doc(bannerId).delete();
  }
}
