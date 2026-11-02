import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/service_category_model.dart';
import 'category_remote_data_source.dart';

/// Fetches real categories created by Admin in Firestore 'categories' collection.
/// ZERO DUMMY DATA.
class FirebaseCategoryRemoteDataSource implements CategoryRemoteDataSource {
  final FirebaseFirestore _firestore;
  static const String _collectionName = 'categories';

  FirebaseCategoryRemoteDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<ServiceCategoryModel>> fetchActiveCategories() async {
    try {
      final snapshot = await _firestore.collection(_collectionName).get();

      final list = snapshot.docs
          .map((doc) => ServiceCategoryModel.fromMap(doc.data(), doc.id))
          .where((cat) =>
              cat.isDeleted == false &&
              (cat.status.toLowerCase() == 'active' || cat.isActive == true))
          .toList();

      list.sort((a, b) => a.priorityOrder.compareTo(b.priorityOrder));
      return list;
    } catch (e) {
      throw Exception('Unable to load categories: $e');
    }
  }

  @override
  Future<List<ServiceCategoryModel>> fetchActivePremiumCategories() async {
    try {
      final snapshot = await _firestore.collection('premium_categories').get();
      final list = <ServiceCategoryModel>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final isActive = (data['isActive'] as bool?) ?? true;
        if (!isActive) continue;

        final catId = (data['categoryId'] as String?) ?? doc.id;
        final title = (data['customTitle'] as String?) ??
            (data['title'] as String?) ??
            (data['categoryName'] as String?) ??
            'प्रीमियम सेवा';
        final priority = (data['priority'] as num?)?.toInt() ?? 99;
        final imgUrl = (data['imageUrl'] as String?) ?? '';

        final List<String> subServices = (data['subServices'] is List)
            ? (data['subServices'] as List).map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
            : const <String>[];

        list.add(ServiceCategoryModel(
          id: catId,
          titleHindi: title,
          titleEnglish: (data['categoryName'] as String?) ?? title,
          description: (data['description'] as String?) ?? 'प्रीमियम सेवा श्रेणी',
          imageUrl: imgUrl,
          iconName: (data['iconName'] as String?) ?? 'workspace_premium',
          colorHex: (data['colorHex'] as String?) ?? '#D4AF37',
          priorityOrder: priority,
          subServices: subServices,
          isPremium: true,
          categoryType: 'premium',
        ));
      }

      list.sort((a, b) => a.priorityOrder.compareTo(b.priorityOrder));
      return list;
    } catch (e) {
      // Graceful fallback: return empty list if collection rules or query fails
      return const [];
    }
  }
}
