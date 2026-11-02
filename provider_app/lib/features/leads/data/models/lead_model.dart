import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/lead_entity.dart';

class LeadModel extends LeadEntity {
  const LeadModel({
    required super.id,
    required super.customerId,
    required super.customerName,
    required super.customerPhone,
    required super.providerId,
    required super.categoryId,
    required super.categoryTitle,
    required super.serviceName,
    required super.description,
    required super.address,
    required super.latitude,
    required super.longitude,
    required super.status,
    required super.createdAt,
    super.updatedAt,
    // ML timestamp fields
    super.viewedAt,
    super.acceptedAt,
    super.rejectedAt,
    super.completedAt,
    super.cancelledAt,
    // ML context fields
    super.customerArea,
    super.preferredDate,
    super.preferredTimeSlot,
    super.visitingCharge,
  });

  /// Helper to safely parse a Firestore Timestamp or ISO string to DateTime.
  static DateTime? _parseDateTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    return DateTime.tryParse(raw.toString());
  }

  factory LeadModel.fromMap(Map<String, dynamic> map, String id) {
    return LeadModel(
      id: id,
      customerId: (map['customerId'] as String?) ?? '',
      customerName: (map['customerName'] as String?) ?? 'ग्राहक',
      customerPhone: (map['customerPhone'] as String?) ?? '',
      providerId: (map['providerId'] as String?) ?? '',
      categoryId: (map['categoryId'] as String?) ?? '',
      categoryTitle: (map['categoryTitle'] as String?) ?? '',
      serviceName: (map['serviceName'] as String?) ?? 'सर्विस इनक्वायरी',
      description: (map['description'] as String?) ?? '',
      address: (map['address'] as String?) ?? (map['customerAddress'] as String?) ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      status: _parseLeadStatus(map['status'] as String?),
      createdAt: _parseDateTime(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(map['updatedAt']),
      // ML timestamps — written by updateLeadStatus when status changes
      viewedAt: _parseDateTime(map['viewedAt']),
      acceptedAt: _parseDateTime(map['acceptedAt']),
      rejectedAt: _parseDateTime(map['rejectedAt']),
      completedAt: _parseDateTime(map['completedAt']),
      cancelledAt: _parseDateTime(map['cancelledAt']),
      // ML context fields
      customerArea: (map['customerArea'] as String?) ?? '',
      preferredDate: (map['preferredDate'] as String?) ?? '',
      preferredTimeSlot: (map['preferredTimeSlot'] as String?) ?? '',
      visitingCharge: (map['visitingCharge'] as num?)?.toDouble() ?? 0.0,
    );
  }

  static LeadStatus _parseLeadStatus(String? status) {
    switch (status) {
      case 'viewed':
        return LeadStatus.viewed;
      case 'accepted':
        return LeadStatus.accepted;
      case 'rejected':
        return LeadStatus.rejected;
      case 'completed':
        return LeadStatus.completed;
      case 'cancelled':
        return LeadStatus.cancelled;
      default:
        return LeadStatus.newLead;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'providerId': providerId,
      'categoryId': categoryId,
      'categoryTitle': categoryTitle,
      'serviceName': serviceName,
      'description': description,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      // ML timestamps (only written when set)
      if (viewedAt != null) 'viewedAt': viewedAt!.toIso8601String(),
      if (acceptedAt != null) 'acceptedAt': acceptedAt!.toIso8601String(),
      if (rejectedAt != null) 'rejectedAt': rejectedAt!.toIso8601String(),
      if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
      if (cancelledAt != null) 'cancelledAt': cancelledAt!.toIso8601String(),
      // ML context
      'customerArea': customerArea,
      'preferredDate': preferredDate,
      'preferredTimeSlot': preferredTimeSlot,
      'visitingCharge': visitingCharge,
    };
  }
}
