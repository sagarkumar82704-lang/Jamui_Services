import 'package:equatable/equatable.dart';

enum AdminKycStatus {
  pendingReview,
  approved,
  rejected,
}

class AdminProviderKycEntity extends Equatable {
  final String id;
  final String fullName;
  final String businessName;
  final String phoneNumber;
  final String categoryTitle;
  final String jamuiArea;
  final double visitingCharge;
  final int experienceYears;
  final String profileImageUrl;
  final String businessImageUrl;
  final String experienceCertificateUrl;
  final String experienceCertificateStatus;
  final String previousOrganization;
  final AdminKycStatus status;
  final String? rejectionReason;
  final DateTime appliedAt;

  const AdminProviderKycEntity({
    required this.id,
    required this.fullName,
    required this.businessName,
    required this.phoneNumber,
    required this.categoryTitle,
    required this.jamuiArea,
    required this.visitingCharge,
    required this.experienceYears,
    this.profileImageUrl = '',
    this.businessImageUrl = '',
    this.experienceCertificateUrl = '',
    this.experienceCertificateStatus = 'notUploaded',
    this.previousOrganization = '',
    required this.status,
    this.rejectionReason,
    required this.appliedAt,
  });

  AdminProviderKycEntity copyWith({
    String? id,
    String? fullName,
    String? businessName,
    String? phoneNumber,
    String? categoryTitle,
    String? jamuiArea,
    double? visitingCharge,
    int? experienceYears,
    String? profileImageUrl,
    String? businessImageUrl,
    String? experienceCertificateUrl,
    String? experienceCertificateStatus,
    String? previousOrganization,
    AdminKycStatus? status,
    String? rejectionReason,
    DateTime? appliedAt,
  }) {
    return AdminProviderKycEntity(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      businessName: businessName ?? this.businessName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      categoryTitle: categoryTitle ?? this.categoryTitle,
      jamuiArea: jamuiArea ?? this.jamuiArea,
      visitingCharge: visitingCharge ?? this.visitingCharge,
      experienceYears: experienceYears ?? this.experienceYears,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      businessImageUrl: businessImageUrl ?? this.businessImageUrl,
      experienceCertificateUrl: experienceCertificateUrl ?? this.experienceCertificateUrl,
      experienceCertificateStatus: experienceCertificateStatus ?? this.experienceCertificateStatus,
      previousOrganization: previousOrganization ?? this.previousOrganization,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      appliedAt: appliedAt ?? this.appliedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        fullName,
        businessName,
        phoneNumber,
        categoryTitle,
        jamuiArea,
        visitingCharge,
        experienceYears,
        profileImageUrl,
        businessImageUrl,
        experienceCertificateUrl,
        experienceCertificateStatus,
        previousOrganization,
        status,
        rejectionReason,
        appliedAt,
      ];
}
