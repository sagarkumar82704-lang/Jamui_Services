import 'package:equatable/equatable.dart';

enum CustomServiceStatus {
  none,
  pendingReview,
  approved,
  rejected,
  moreInfoRequired;

  String get displayNameHindi {
    switch (this) {
      case CustomServiceStatus.none:
        return 'कोई अनुरोध नहीं';
      case CustomServiceStatus.pendingReview:
        return 'एडमिन समीक्षाधीन (Under Review)';
      case CustomServiceStatus.approved:
        return 'स्वीकृत (Approved)';
      case CustomServiceStatus.rejected:
        return 'अस्वीकृत (Rejected)';
      case CustomServiceStatus.moreInfoRequired:
        return 'अतिरिक्त जानकारी आवश्यक (Action Required)';
    }
  }

  static CustomServiceStatus fromString(String? val) {
    if (val == null) return CustomServiceStatus.none;
    final s = val.toLowerCase().trim();
    if (s == 'approved') return CustomServiceStatus.approved;
    if (s == 'rejected') return CustomServiceStatus.rejected;
    if (s == 'more_info_required' || s == 'more_info') return CustomServiceStatus.moreInfoRequired;
    if (s == 'pending_review' || s == 'pending') return CustomServiceStatus.pendingReview;
    return CustomServiceStatus.none;
  }
}

/// [CustomServiceApplicationEntity] — अन्य सेवा (Other Service) आवेदन डोमेन मॉडल
class CustomServiceApplicationEntity extends Equatable {
  final String id;
  final String providerId;
  final String providerName;
  final String phoneNumber;
  final String serviceName;
  final String serviceDescription;
  final String offeredServices;
  final int experienceYears;
  final double visitingCharge;
  final String fullAddress;
  final String jamuiArea;
  final CustomServiceStatus status;
  final String? adminFeedback;
  final String? mappedCategoryId;
  final String? mappedCategoryTitle;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;

  const CustomServiceApplicationEntity({
    required this.id,
    required this.providerId,
    required this.providerName,
    required this.phoneNumber,
    required this.serviceName,
    required this.serviceDescription,
    required this.offeredServices,
    this.experienceYears = 1,
    this.visitingCharge = 100.0,
    this.fullAddress = '',
    this.jamuiArea = '',
    this.status = CustomServiceStatus.pendingReview,
    this.adminFeedback,
    this.mappedCategoryId,
    this.mappedCategoryTitle,
    required this.createdAt,
    this.updatedAt,
    this.reviewedAt,
    this.reviewedBy,
  });

  CustomServiceApplicationEntity copyWith({
    String? id,
    String? providerId,
    String? providerName,
    String? phoneNumber,
    String? serviceName,
    String? serviceDescription,
    String? offeredServices,
    int? experienceYears,
    double? visitingCharge,
    String? fullAddress,
    String? jamuiArea,
    CustomServiceStatus? status,
    String? adminFeedback,
    String? mappedCategoryId,
    String? mappedCategoryTitle,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? reviewedAt,
    String? reviewedBy,
  }) {
    return CustomServiceApplicationEntity(
      id: id ?? this.id,
      providerId: providerId ?? this.providerId,
      providerName: providerName ?? this.providerName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      serviceName: serviceName ?? this.serviceName,
      serviceDescription: serviceDescription ?? this.serviceDescription,
      offeredServices: offeredServices ?? this.offeredServices,
      experienceYears: experienceYears ?? this.experienceYears,
      visitingCharge: visitingCharge ?? this.visitingCharge,
      fullAddress: fullAddress ?? this.fullAddress,
      jamuiArea: jamuiArea ?? this.jamuiArea,
      status: status ?? this.status,
      adminFeedback: adminFeedback ?? this.adminFeedback,
      mappedCategoryId: mappedCategoryId ?? this.mappedCategoryId,
      mappedCategoryTitle: mappedCategoryTitle ?? this.mappedCategoryTitle,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
    );
  }

  @override
  List<Object?> get props => [
        id,
        providerId,
        providerName,
        phoneNumber,
        serviceName,
        serviceDescription,
        offeredServices,
        experienceYears,
        visitingCharge,
        fullAddress,
        jamuiArea,
        status,
        adminFeedback,
        mappedCategoryId,
        mappedCategoryTitle,
        createdAt,
        updatedAt,
        reviewedAt,
        reviewedBy,
      ];
}
