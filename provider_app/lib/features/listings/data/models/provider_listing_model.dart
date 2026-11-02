import 'package:cloud_firestore/cloud_firestore.dart';

class ProviderListingModel {
  final String id;
  final String providerId;
  final String providerName;
  final String providerPhone;
  final String title;
  final String description;
  final String listingType; // 'service' | 'product' | 'job'
  final String categoryId;
  final String categoryName;
  final double price;
  final List<String> images;
  final List<String> storageKeys;
  final String status; // 'pending_review' | 'approved' | 'rejected' | 'paused'
  final String? rejectionReason;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ProviderListingModel({
    required this.id,
    required this.providerId,
    required this.providerName,
    required this.providerPhone,
    required this.title,
    required this.description,
    required this.listingType,
    required this.categoryId,
    required this.categoryName,
    required this.price,
    required this.images,
    required this.storageKeys,
    required this.status,
    this.rejectionReason,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  factory ProviderListingModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return ProviderListingModel.fromMap(data, doc.id);
  }

  factory ProviderListingModel.fromMap(Map<String, dynamic> data, String id) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final rawImages = data['images'];
    final List<String> imagesList = rawImages is List
        ? rawImages.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
        : [];

    final rawKeys = data['storageKeys'];
    final List<String> keysList = rawKeys is List
        ? rawKeys.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
        : [];

    return ProviderListingModel(
      id: id,
      providerId: data['providerId']?.toString() ?? '',
      providerName: data['providerName']?.toString() ?? '',
      providerPhone: data['providerPhone']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      listingType: (data['listingType']?.toString().toLowerCase().trim() ?? 'service'),
      categoryId: data['categoryId']?.toString() ?? '',
      categoryName: data['categoryName']?.toString() ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      images: imagesList,
      storageKeys: keysList,
      status: (data['status']?.toString().toLowerCase().trim() ?? 'pending_review'),
      rejectionReason: data['rejectionReason']?.toString(),
      isActive: (data['isActive'] as bool?) ?? true,
      createdAt: parseDate(data['createdAt']),
      updatedAt: data['updatedAt'] != null ? parseDate(data['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'providerId': providerId,
      'providerName': providerName,
      'providerPhone': providerPhone,
      'title': title,
      'description': description,
      'listingType': listingType,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'price': price,
      'images': images,
      'storageKeys': storageKeys,
      'status': status,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
