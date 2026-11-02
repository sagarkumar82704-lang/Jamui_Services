import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/category_model.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/category_dependency_count.dart';
import 'category_remote_data_source.dart';

class FirebaseCategoryRemoteDataSource implements CategoryRemoteDataSource {
  final FirebaseFirestore _firestore;
  static const String _collectionName = 'categories';
  static const String _auditLogsCollection = 'audit_logs';

  FirebaseCategoryRemoteDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<CategoryModel>> fetchCategories({String? filterStatus, String? searchQuery}) async {
    try {
      Query<Map<String, dynamic>> query = _firestore.collection(_collectionName);

      if (filterStatus == 'active') {
        query = query.where('isDeleted', isEqualTo: false).where('status', isEqualTo: 'active');
      } else if (filterStatus == 'inactive') {
        query = query.where('isDeleted', isEqualTo: false).where('status', isEqualTo: 'inactive');
      } else if (filterStatus == 'archived') {
        query = query.where('isDeleted', isEqualTo: true);
      }

      final snapshot = await query.orderBy('sortOrder').get();
      List<CategoryModel> categories = snapshot.docs
          .map((doc) => CategoryModel.fromMap(doc.data(), doc.id))
          .toList();

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim().toLowerCase();
        categories = categories.where((c) =>
            c.name.toLowerCase().contains(q) ||
            c.titleHindi.toLowerCase().contains(q) ||
            c.slug.toLowerCase().contains(q) ||
            c.searchKeywords.any((k) => k.toLowerCase().contains(q))).toList();
      }

      return categories;
    } catch (e) {
      return [];
    }
  }

  @override
  Future<bool> isDuplicateName(String name, {String? excludeId}) async {
    try {
      final cleanName = name.trim().toLowerCase();
      if (cleanName.isEmpty) return false;
      final snapshot = await _firestore.collection(_collectionName).get();

      for (var doc in snapshot.docs) {
        if (excludeId != null && (doc.id == excludeId || doc.id.toLowerCase() == excludeId.toLowerCase())) continue;
        if (doc.data()['isDeleted'] == true) continue;
        final docName = ((doc.data()['name'] ?? doc.data()['titleEnglish'] ?? doc.data()['titleHindi'] ?? '') as String).trim().toLowerCase();
        if (docName.isNotEmpty && docName == cleanName) return true;
      }
    } catch (_) {}
    return false;
  }

  @override
  Future<bool> isDuplicateSlug(String slug, {String? excludeId}) async {
    try {
      final cleanSlug = slug.trim().toLowerCase();
      if (cleanSlug.isEmpty) return false;
      final snapshot = await _firestore.collection(_collectionName).get();

      for (var doc in snapshot.docs) {
        if (excludeId != null && (doc.id == excludeId || doc.id.toLowerCase() == excludeId.toLowerCase())) continue;
        if (doc.data()['isDeleted'] == true) continue;
        final docSlug = ((doc.data()['slug'] ?? '') as String).trim().toLowerCase();
        if (docSlug.isNotEmpty && docSlug == cleanSlug) return true;
      }
    } catch (_) {}
    return false;
  }

  @override
  Future<void> saveCategory(CategoryModel category, String adminId) async {
    final docId = category.id.isNotEmpty ? category.id : _firestore.collection(_collectionName).doc().id;
    final modelToSave = CategoryModel(
      id: docId,
      name: category.name,
      slug: category.slug,
      titleHindi: category.titleHindi,
      titleEnglish: category.titleEnglish,
      shortDescription: category.shortDescription,
      fullDescription: category.fullDescription,
      description: category.description,
      iconUrl: category.iconUrl,
      imageUrl: category.imageUrl,
      imageStoragePath: category.imageStoragePath,
      iconName: category.iconName,
      colorHex: category.colorHex,
      aboutCategory: category.aboutCategory,
      whatIncludes: category.whatIncludes,
      commonProblems: category.commonProblems,
      whoNeeds: category.whoNeeds,
      whenToContact: category.whenToContact,
      subServices: category.subServices,
      benefits: category.benefits,
      includedServices: category.includedServices,
      excludedServices: category.excludedServices,
      pricingType: category.pricingType,
      startingPrice: category.startingPrice,
      priceUnit: category.priceUnit,
      priceNote: category.priceNote,
      estimatedDuration: category.estimatedDuration,
      customerRequirements: category.customerRequirements,
      customerPhotoRequired: category.customerPhotoRequired,
      providerRequirements: category.providerRequirements,
      requiredSkills: category.requiredSkills,
      experienceCertificateRequired: category.experienceCertificateRequired,
      verificationRequired: category.verificationRequired,
      requiredDocuments: category.requiredDocuments,
      faqs: category.faqs,
      safetyInstructions: category.safetyInstructions,
      importantNotes: category.importantNotes,
      disclaimer: category.disclaimer,
      searchKeywords: category.searchKeywords,
      tags: category.tags,
      sortOrder: category.sortOrder,
      priorityOrder: category.priorityOrder,
      status: category.status,
      isFeatured: category.isFeatured,
      isDeleted: false,
      createdAt: category.createdAt,
      updatedAt: DateTime.now(),
    );

    await _firestore.collection(_collectionName).doc(docId).set(
      modelToSave.toMap(),
      SetOptions(merge: true),
    );

    await _logAudit(
      adminId: adminId,
      action: 'CATEGORY_CREATED',
      targetId: docId,
      details: 'Category created: ${category.name}',
    );
  }

  @override
  Future<void> updateCategory(CategoryModel category, String adminId) async {
    final updatedModel = CategoryModel(
      id: category.id,
      name: category.name,
      slug: category.slug,
      titleHindi: category.titleHindi,
      titleEnglish: category.titleEnglish,
      shortDescription: category.shortDescription,
      fullDescription: category.fullDescription,
      description: category.description,
      iconUrl: category.iconUrl,
      imageUrl: category.imageUrl,
      imageStoragePath: category.imageStoragePath,
      iconName: category.iconName,
      colorHex: category.colorHex,
      aboutCategory: category.aboutCategory,
      whatIncludes: category.whatIncludes,
      commonProblems: category.commonProblems,
      whoNeeds: category.whoNeeds,
      whenToContact: category.whenToContact,
      subServices: category.subServices,
      benefits: category.benefits,
      includedServices: category.includedServices,
      excludedServices: category.excludedServices,
      pricingType: category.pricingType,
      startingPrice: category.startingPrice,
      priceUnit: category.priceUnit,
      priceNote: category.priceNote,
      estimatedDuration: category.estimatedDuration,
      customerRequirements: category.customerRequirements,
      customerPhotoRequired: category.customerPhotoRequired,
      providerRequirements: category.providerRequirements,
      requiredSkills: category.requiredSkills,
      experienceCertificateRequired: category.experienceCertificateRequired,
      verificationRequired: category.verificationRequired,
      requiredDocuments: category.requiredDocuments,
      faqs: category.faqs,
      safetyInstructions: category.safetyInstructions,
      importantNotes: category.importantNotes,
      disclaimer: category.disclaimer,
      searchKeywords: category.searchKeywords,
      tags: category.tags,
      sortOrder: category.sortOrder,
      priorityOrder: category.priorityOrder,
      status: category.status,
      isFeatured: category.isFeatured,
      isDeleted: category.isDeleted,
      createdAt: category.createdAt,
      updatedAt: DateTime.now(),
    );

    await _firestore.collection(_collectionName).doc(category.id).set(
      updatedModel.toMap(),
      SetOptions(merge: true),
    );

    await _logAudit(
      adminId: adminId,
      action: 'CATEGORY_UPDATED',
      targetId: category.id,
      details: 'Category updated: ${category.name}',
    );
  }

  @override
  Future<void> setCategoryStatus(String id, CategoryStatus status, String adminId) async {
    final isDeleted = status == CategoryStatus.archived;
    await _firestore.collection(_collectionName).doc(id).set({
      'status': status.name,
      'isActive': status == CategoryStatus.active && !isDeleted,
      'isDeleted': isDeleted,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _logAudit(
      adminId: adminId,
      action: 'CATEGORY_STATUS_CHANGE',
      targetId: id,
      details: 'Status changed to: ${status.name}',
    );
  }

  @override
  Future<void> archiveCategory(String id, String adminId) async {
    await _firestore.collection(_collectionName).doc(id).set({
      'status': 'archived',
      'isActive': false,
      'isDeleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
      'deletedBy': adminId,
    }, SetOptions(merge: true));

    await _logAudit(
      adminId: adminId,
      action: 'CATEGORY_ARCHIVED',
      targetId: id,
      details: 'Category archived cleanly',
    );
  }

  @override
  Future<CategoryDependencyCount> checkDependencies(String categoryId, String categoryName) async {
    int pCount = 0;
    int sCount = 0;
    int lCount = 0;
    int bCount = 0;
    int rCount = 0;

    try {
      final pSnap = await _firestore.collection('providers').where('category', isEqualTo: categoryName).count().get();
      pCount = pSnap.count ?? 0;
    } catch (_) {}

    try {
      final sSnap = await _firestore.collection('services').where('categoryId', isEqualTo: categoryId).count().get();
      sCount = sSnap.count ?? 0;
    } catch (_) {}

    try {
      final lSnap = await _firestore.collection('leads').where('categoryId', isEqualTo: categoryId).count().get();
      lCount = lSnap.count ?? 0;
    } catch (_) {}

    try {
      final bSnap = await _firestore.collection('bookings').where('categoryId', isEqualTo: categoryId).count().get();
      bCount = bSnap.count ?? 0;
    } catch (_) {}

    try {
      final rSnap = await _firestore.collection('reviews').where('categoryId', isEqualTo: categoryId).count().get();
      rCount = rSnap.count ?? 0;
    } catch (_) {}

    return CategoryDependencyCount(
      providerCount: pCount,
      serviceCount: sCount,
      leadCount: lCount,
      bookingCount: bCount,
      reviewCount: rCount,
    );
  }

  @override
  Future<void> deletePermanently(String id, String adminId) async {
    await _firestore.collection(_collectionName).doc(id).delete();

    await _logAudit(
      adminId: adminId,
      action: 'CATEGORY_PERMANENTLY_DELETED',
      targetId: id,
      details: 'Category permanently purged',
    );
  }

  Future<void> _logAudit({
    required String adminId,
    required String action,
    required String targetId,
    required String details,
  }) async {
    try {
      await _firestore.collection(_auditLogsCollection).add({
        'adminId': adminId,
        'action': action,
        'targetId': targetId,
        'details': details,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}
