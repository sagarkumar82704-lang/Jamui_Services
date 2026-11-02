import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/custom_service_application_entity.dart';

class CustomServiceApplicationModel extends CustomServiceApplicationEntity {
  const CustomServiceApplicationModel({
    required super.id,
    required super.providerId,
    required super.providerName,
    required super.phoneNumber,
    required super.serviceName,
    required super.serviceDescription,
    required super.offeredServices,
    super.experienceYears,
    super.visitingCharge,
    super.fullAddress,
    super.jamuiArea,
    super.status,
    super.adminFeedback,
    super.mappedCategoryId,
    super.mappedCategoryTitle,
    required super.createdAt,
    super.updatedAt,
    super.reviewedAt,
    super.reviewedBy,
  });

  factory CustomServiceApplicationModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    DateTime? parseNullableDate(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return CustomServiceApplicationModel(
      id: id,
      providerId: (map['providerId'] as String?) ?? id,
      providerName: (map['providerName'] as String?) ?? (map['fullName'] as String?) ?? 'N/A',
      phoneNumber: (map['phoneNumber'] as String?) ?? (map['phone'] as String?) ?? '',
      serviceName: (map['serviceName'] as String?) ?? (map['proposedServiceName'] as String?) ?? '',
      serviceDescription: (map['serviceDescription'] as String?) ?? (map['workDescription'] as String?) ?? '',
      offeredServices: (map['offeredServices'] as String?) ?? (map['servicesList'] as String?) ?? '',
      experienceYears: (map['experienceYears'] as num?)?.toInt() ?? 1,
      visitingCharge: (map['visitingCharge'] as num?)?.toDouble() ?? 100.0,
      fullAddress: (map['fullAddress'] as String?) ?? '',
      jamuiArea: (map['jamuiArea'] as String?) ?? (map['area'] as String?) ?? '',
      status: CustomServiceStatus.fromString(map['status'] as String?),
      adminFeedback: (map['adminFeedback'] as String?) ?? (map['adminNotes'] as String?),
      mappedCategoryId: map['mappedCategoryId'] as String?,
      mappedCategoryTitle: map['mappedCategoryTitle'] as String?,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseNullableDate(map['updatedAt']),
      reviewedAt: parseNullableDate(map['reviewedAt']),
      reviewedBy: map['reviewedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'providerId': providerId,
      'providerName': providerName,
      'phoneNumber': phoneNumber,
      'serviceName': serviceName,
      'serviceDescription': serviceDescription,
      'offeredServices': offeredServices,
      'experienceYears': experienceYears,
      'visitingCharge': visitingCharge,
      'fullAddress': fullAddress,
      'jamuiArea': jamuiArea,
      'status': _statusToString(status),
      'adminFeedback': adminFeedback,
      'mappedCategoryId': mappedCategoryId,
      'mappedCategoryTitle': mappedCategoryTitle,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'reviewedAt': reviewedAt?.toIso8601String(),
      'reviewedBy': reviewedBy,
    };
  }

  static String _statusToString(CustomServiceStatus s) {
    switch (s) {
      case CustomServiceStatus.none:
        return 'none';
      case CustomServiceStatus.pendingReview:
        return 'pending_review';
      case CustomServiceStatus.approved:
        return 'approved';
      case CustomServiceStatus.rejected:
        return 'rejected';
      case CustomServiceStatus.moreInfoRequired:
        return 'more_info_required';
    }
  }
}
