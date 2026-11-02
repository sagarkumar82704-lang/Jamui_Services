import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/admin_provider_kyc_entity.dart';
import '../models/admin_provider_kyc_model.dart';
import 'admin_provider_remote_data_source.dart';

class FirebaseAdminProviderRemoteDataSource implements AdminProviderRemoteDataSource {
  FirebaseFirestore? _firestoreInstance;
  static const String _collectionName = 'providers';

  // लोकल इन-मेमोरी कैश / फॉलबैक
  final List<AdminProviderKycModel> _memoryStore = [];

  FirebaseAdminProviderRemoteDataSource({FirebaseFirestore? firestore})
      : _firestoreInstance = firestore;

  FirebaseFirestore? get _firestore {
    if (_firestoreInstance != null) return _firestoreInstance;
    try {
      _firestoreInstance = FirebaseFirestore.instance;
      return _firestoreInstance;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<AdminProviderKycModel>> getKycRequests() async {
    try {
      final fs = _firestore;
      if (fs != null) {
        final snapshot = await fs.collection(_collectionName).get();
        if (snapshot.docs.isNotEmpty) {
          return snapshot.docs
              .map((doc) => AdminProviderKycModel.fromMap(doc.data(), doc.id))
              .toList();
        }
      }
    } catch (e) {
      // Return empty list on failure, no dummy seed
    }

    return [];
  }

  @override
  Future<void> updateKycStatus(String providerId, String status, {String? reason}) async {
    final updateMap = <String, dynamic>{
      'status': status,
      'verificationStatus': status,
      'kycStatus': status,
      'isVerified': status == 'approved',
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (reason != null && reason.isNotEmpty) {
      updateMap['rejectionReason'] = reason;
    } else if (status == 'approved') {
      updateMap['rejectionReason'] = FieldValue.delete();
    }

    try {
      final fs = _firestore;
      if (fs != null) {
        await fs.collection(_collectionName).doc(providerId).update(updateMap);
      }
    } catch (_) {}

    final index = _memoryStore.indexWhere((p) => p.id == providerId);
    if (index != -1) {
      final item = _memoryStore[index];
      final newStatus = status == 'approved'
          ? AdminKycStatus.approved
          : (status == 'rejected' ? AdminKycStatus.rejected : AdminKycStatus.pendingReview);

      _memoryStore[index] = item.copyWith(
        status: newStatus,
        rejectionReason: reason,
      ) as AdminProviderKycModel;
    }
  }
}
