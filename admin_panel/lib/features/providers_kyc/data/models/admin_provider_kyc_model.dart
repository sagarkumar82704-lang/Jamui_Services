import '../../domain/entities/admin_provider_kyc_entity.dart';

class AdminProviderKycModel extends AdminProviderKycEntity {
  const AdminProviderKycModel({
    required super.id,
    required super.fullName,
    required super.businessName,
    required super.phoneNumber,
    required super.categoryTitle,
    required super.jamuiArea,
    required super.visitingCharge,
    required super.experienceYears,
    super.profileImageUrl,
    super.businessImageUrl,
    super.experienceCertificateUrl,
    super.experienceCertificateStatus,
    super.previousOrganization,
    required super.status,
    super.rejectionReason,
    required super.appliedAt,
  });

  factory AdminProviderKycModel.fromMap(Map<String, dynamic> map, String id) {
    return AdminProviderKycModel(
      id: id,
      fullName: (map['fullName'] as String?) ?? '',
      businessName: (map['businessName'] as String?) ?? '',
      phoneNumber: (map['phoneNumber'] as String?) ?? (map['phone'] as String?) ?? '',
      categoryTitle: (map['primaryCategoryTitle'] as String?) ?? (map['categoryTitle'] as String?) ?? '',
      jamuiArea: (map['jamuiArea'] as String?) ?? 'जमुई',
      visitingCharge: (map['visitingCharge'] as num?)?.toDouble() ?? 100.0,
      experienceYears: (map['experienceYears'] as num?)?.toInt() ?? 1,
      profileImageUrl: (map['profileImageUrl'] as String?) ??
          (map['profilePhotoUrl'] as String?) ??
          (map['photoUrl'] as String?) ??
          (map['profilePhoto'] as String?) ??
          '',
      businessImageUrl: (map['businessImageUrl'] as String?) ??
          (map['workplacePhotoUrl'] as String?) ??
          (map['businessImage'] as String?) ??
          '',
      experienceCertificateUrl: (map['experienceCertificateUrl'] as String?) ??
          (map['certificateUrl'] as String?) ??
          (map['experienceCertUrl'] as String?) ??
          '',
      experienceCertificateStatus: (map['experienceCertificateStatus'] as String?) ?? 'notUploaded',
      previousOrganization: (map['previousOrganization'] as String?) ?? '',
      status: _parseStatus(map['kycStatus'] as String?),
      rejectionReason: map['rejectionReason'] as String?,
      appliedAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  static AdminKycStatus _parseStatus(String? status) {
    switch (status) {
      case 'approved':
        return AdminKycStatus.approved;
      case 'rejected':
        return AdminKycStatus.rejected;
      default:
        return AdminKycStatus.pendingReview;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'businessName': businessName,
      'phoneNumber': phoneNumber,
      'primaryCategoryTitle': categoryTitle,
      'jamuiArea': jamuiArea,
      'visitingCharge': visitingCharge,
      'experienceYears': experienceYears,
      'profileImageUrl': profileImageUrl,
      'businessImageUrl': businessImageUrl,
      'experienceCertificateUrl': experienceCertificateUrl,
      'experienceCertificateStatus': experienceCertificateStatus,
      'previousOrganization': previousOrganization,
      'kycStatus': status.name,
      'rejectionReason': rejectionReason,
      'createdAt': appliedAt.toIso8601String(),
    };
  }
}
