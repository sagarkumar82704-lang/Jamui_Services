import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class CustomerReviewEntity extends Equatable {
  final String id;
  final String bookingId;
  final String providerId;
  final String providerName;
  final String customerId;
  final String customerDisplayName;
  final int rating; // 1 to 5
  final String comment;
  final List<String> tags;
  final List<String> photoUrls;
  final bool isEdited;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CustomerReviewEntity({
    required this.id,
    required this.bookingId,
    required this.providerId,
    required this.providerName,
    required this.customerId,
    required this.customerDisplayName,
    required this.rating,
    this.comment = '',
    this.tags = const [],
    this.photoUrls = const [],
    this.isEdited = false,
    this.createdAt,
    this.updatedAt,
  });

  factory CustomerReviewEntity.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    
    DateTime? parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    final rawRating = (data['rating'] as num?)?.toInt() ?? 5;
    final clampedRating = rawRating.clamp(1, 5);

    return CustomerReviewEntity(
      id: doc.id,
      bookingId: (data['bookingId'] ?? data['leadId'] ?? doc.id).toString(),
      providerId: (data['providerId'] ?? '').toString(),
      providerName: (data['providerName'] ?? '').toString(),
      customerId: (data['customerId'] ?? '').toString(),
      customerDisplayName: (data['customerDisplayName'] ?? data['customerName'] ?? 'सत्यापित ग्राहक').toString(),
      rating: clampedRating,
      comment: (data['comment'] ?? '').toString(),
      tags: List<String>.from(data['tags'] ?? []),
      photoUrls: List<String>.from(data['photoUrls'] ?? []),
      isEdited: data['isEdited'] == true,
      createdAt: parseTimestamp(data['createdAt']),
      updatedAt: parseTimestamp(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'bookingId': bookingId,
      'leadId': bookingId,
      'providerId': providerId,
      'providerName': providerName,
      'customerId': customerId,
      'customerDisplayName': customerDisplayName,
      'rating': rating,
      'comment': comment,
      'tags': tags,
      'photoUrls': photoUrls,
      'isEdited': isEdited,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  CustomerReviewEntity copyWith({
    String? id,
    String? bookingId,
    String? providerId,
    String? providerName,
    String? customerId,
    String? customerDisplayName,
    int? rating,
    String? comment,
    List<String>? tags,
    List<String>? photoUrls,
    bool? isEdited,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomerReviewEntity(
      id: id ?? this.id,
      bookingId: bookingId ?? this.bookingId,
      providerId: providerId ?? this.providerId,
      providerName: providerName ?? this.providerName,
      customerId: customerId ?? this.customerId,
      customerDisplayName: customerDisplayName ?? this.customerDisplayName,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      tags: tags ?? this.tags,
      photoUrls: photoUrls ?? this.photoUrls,
      isEdited: isEdited ?? this.isEdited,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        bookingId,
        providerId,
        customerId,
        rating,
        comment,
        tags,
        photoUrls,
        isEdited,
      ];
}
