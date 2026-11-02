import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Entity representing a merchant's private store category within their shop.
/// Storage path: diamond_shops/{shopId}/store_categories/{storeCategoryId}
class SellerStoreCategoryEntity extends Equatable {
  final String id;
  final String shopId;
  final String name;
  final String nameHindi;
  final String imageUrl;
  final int displayOrder;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SellerStoreCategoryEntity({
    required this.id,
    required this.shopId,
    required this.name,
    this.nameHindi = '',
    this.imageUrl = '',
    this.displayOrder = 0,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  /// User-facing display title (English name with optional Hindi name)
  String get displayTitle {
    if (nameHindi.isNotEmpty && nameHindi != name) {
      return '$name ($nameHindi)';
    }
    return name;
  }

  SellerStoreCategoryEntity copyWith({
    String? id,
    String? shopId,
    String? name,
    String? nameHindi,
    String? imageUrl,
    int? displayOrder,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SellerStoreCategoryEntity(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      name: name ?? this.name,
      nameHindi: nameHindi ?? this.nameHindi,
      imageUrl: imageUrl ?? this.imageUrl,
      displayOrder: displayOrder ?? this.displayOrder,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shopId': shopId,
      'name': name,
      'nameHindi': nameHindi,
      'imageUrl': imageUrl,
      'displayOrder': displayOrder,
      'isActive': isActive,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory SellerStoreCategoryEntity.fromMap(Map<String, dynamic> map, String id, {String shopId = ''}) {
    DateTime? parsedCreated;
    final rawCreated = map['createdAt'];
    if (rawCreated is Timestamp) {
      parsedCreated = rawCreated.toDate();
    } else if (rawCreated is String) {
      parsedCreated = DateTime.tryParse(rawCreated);
    }

    DateTime? parsedUpdated;
    final rawUpdated = map['updatedAt'];
    if (rawUpdated is Timestamp) {
      parsedUpdated = rawUpdated.toDate();
    } else if (rawUpdated is String) {
      parsedUpdated = DateTime.tryParse(rawUpdated);
    }

    return SellerStoreCategoryEntity(
      id: (map['id'] as String?) ?? id,
      shopId: (map['shopId'] as String?) ?? shopId,
      name: (map['name'] as String?) ?? '',
      nameHindi: (map['nameHindi'] as String?) ?? '',
      imageUrl: (map['imageUrl'] as String?) ?? '',
      displayOrder: (map['displayOrder'] as num?)?.toInt() ?? 0,
      isActive: (map['isActive'] as bool?) ?? true,
      createdAt: parsedCreated,
      updatedAt: parsedUpdated,
    );
  }

  @override
  List<Object?> get props => [id, shopId, name, nameHindi, imageUrl, displayOrder, isActive];
}

