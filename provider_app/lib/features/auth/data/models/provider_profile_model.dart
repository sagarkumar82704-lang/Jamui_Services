import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/provider_profile_entity.dart';

class ProviderProfileModel extends ProviderProfileEntity {
  const ProviderProfileModel({
    required super.id,
    required super.email,
    required super.phoneNumber,
    super.isMobileVerified,
    super.isEmailVerified,
    required super.fullName,
    required super.businessName,
    super.businessDescription,
    super.businessType,
    required super.primaryCategoryId,
    required super.primaryCategoryTitle,
    super.selectedCategoryIds,
    super.adminCategoryOverrideLimit,
    super.subServices,
    super.experienceYears,
    super.visitingCharge,
    super.serviceRadiusKm,
    super.jamuiArea,
    super.fullAddress,
    super.latitude,
    super.longitude,
    super.profileImageUrl,
    super.businessImageUrl,
    super.workingHours,
    super.hasExperienceCertificate,
    super.experienceCertificateUrl,
    super.experienceCertificateStatus,
    super.previousOrganization,
    super.experienceDescription,
    super.certificateVerifiedAt,
    super.certificateVerifiedBy,
    super.certificateRejectionReason,
    super.kycStatus,
    super.status,
    super.rejectionReason,
    super.subscriptionPlan,
    super.subscriptionPlanTier,
    super.isSubscriptionActive,
    super.isPremiumEligible,
    super.subscriptionExpiry,
    super.paymentVerified,
    super.paymentStatus,
    super.paymentOrderId,
    super.paymentId,
    super.subscriptionApprovalStatus,
    super.isActive,
    super.deactivationReason,
    super.isDeleted,
    super.deletionReason,
    super.totalViews,
    super.totalCalls,
    super.totalWhatsAppClicks,
    super.rating,
    super.ratingCount,
    super.isAvailable,
    required super.createdAt,
    super.updatedAt,
    super.isOtherService,
    super.customServiceStatus,
    super.customServiceName,
    super.customServiceDescription,
    super.customServiceOffered,
    super.customServiceFeedback,
    super.registrationStatus,
    super.currentStep,
    super.completedSteps,
    super.selectedCategoryId,
    super.categoryRequestStatus,
    super.categoryRequestId,
    super.categoryRejectionReason,
    super.requestedCategoryId,
    super.requestedCategoryTitle,
    super.categoryApprovalStatus,
    super.categoryRequestSubmittedAt,
    super.galleryImages,
    super.servicesWithPricing,
    super.instagramUrl,
    super.facebookUrl,
    super.websiteUrl,
    super.categoryType,
    super.premiumServiceDetails,
    super.generalServiceDetails,
  });

  factory ProviderProfileModel.fromEntity(ProviderProfileEntity entity) {
    return ProviderProfileModel(
      id: entity.id,
      email: entity.email,
      phoneNumber: entity.phoneNumber,
      isMobileVerified: entity.isMobileVerified,
      isEmailVerified: entity.isEmailVerified,
      fullName: entity.fullName,
      businessName: entity.businessName,
      businessDescription: entity.businessDescription,
      businessType: entity.businessType,
      primaryCategoryId: entity.primaryCategoryId,
      primaryCategoryTitle: entity.primaryCategoryTitle,
      selectedCategoryIds: entity.selectedCategoryIds,
      adminCategoryOverrideLimit: entity.adminCategoryOverrideLimit,
      subServices: entity.subServices,
      experienceYears: entity.experienceYears,
      visitingCharge: entity.visitingCharge,
      serviceRadiusKm: entity.serviceRadiusKm,
      jamuiArea: entity.jamuiArea,
      fullAddress: entity.fullAddress,
      latitude: entity.latitude,
      longitude: entity.longitude,
      profileImageUrl: entity.profileImageUrl,
      businessImageUrl: entity.businessImageUrl,
      workingHours: entity.workingHours,
      hasExperienceCertificate: entity.hasExperienceCertificate,
      experienceCertificateUrl: entity.experienceCertificateUrl,
      experienceCertificateStatus: entity.experienceCertificateStatus,
      previousOrganization: entity.previousOrganization,
      experienceDescription: entity.experienceDescription,
      certificateVerifiedAt: entity.certificateVerifiedAt,
      certificateVerifiedBy: entity.certificateVerifiedBy,
      certificateRejectionReason: entity.certificateRejectionReason,
      kycStatus: entity.kycStatus,
      status: entity.status,
      rejectionReason: entity.rejectionReason,
      subscriptionPlan: entity.subscriptionPlan,
      subscriptionPlanTier: entity.subscriptionPlanTier,
      isSubscriptionActive: entity.isSubscriptionActive,
      isPremiumEligible: entity.isPremiumEligible,
      subscriptionExpiry: entity.subscriptionExpiry,
      paymentVerified: entity.paymentVerified,
      paymentStatus: entity.paymentStatus,
      paymentOrderId: entity.paymentOrderId,
      paymentId: entity.paymentId,
      subscriptionApprovalStatus: entity.subscriptionApprovalStatus,
      isActive: entity.isActive,
      deactivationReason: entity.deactivationReason,
      isDeleted: entity.isDeleted,
      deletionReason: entity.deletionReason,
      totalViews: entity.totalViews,
      totalCalls: entity.totalCalls,
      totalWhatsAppClicks: entity.totalWhatsAppClicks,
      rating: entity.rating,
      ratingCount: entity.ratingCount,
      isAvailable: entity.isAvailable,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      isOtherService: entity.isOtherService,
      customServiceStatus: entity.customServiceStatus,
      customServiceName: entity.customServiceName,
      customServiceDescription: entity.customServiceDescription,
      customServiceOffered: entity.customServiceOffered,
      customServiceFeedback: entity.customServiceFeedback,
      registrationStatus: entity.registrationStatus,
      currentStep: entity.currentStep,
      completedSteps: entity.completedSteps,
      selectedCategoryId: entity.selectedCategoryId,
      categoryRequestStatus: entity.categoryRequestStatus,
      categoryRequestId: entity.categoryRequestId,
      categoryRejectionReason: entity.categoryRejectionReason,
      requestedCategoryId: entity.requestedCategoryId,
      requestedCategoryTitle: entity.requestedCategoryTitle,
      categoryApprovalStatus: entity.categoryApprovalStatus,
      categoryRequestSubmittedAt: entity.categoryRequestSubmittedAt,
      galleryImages: entity.galleryImages,
      servicesWithPricing: entity.servicesWithPricing,
      instagramUrl: entity.instagramUrl,
      facebookUrl: entity.facebookUrl,
      websiteUrl: entity.websiteUrl,
      categoryType: entity.categoryType,
      premiumServiceDetails: entity.premiumServiceDetails,
      generalServiceDetails: entity.generalServiceDetails,
    );
  }

  factory ProviderProfileModel.fromMap(Map<String, dynamic> map, String id) {
    return ProviderProfileModel(
      id: id,
      email: (map['email'] as String?) ?? '',
      phoneNumber: (map['phoneNumber'] as String?) ?? (map['phone'] as String?) ?? '',
      isMobileVerified: (map['isMobileVerified'] as bool?) ?? true,
      isEmailVerified: (map['isEmailVerified'] as bool?) ?? true,
      fullName: (map['fullName'] as String?) ?? (map['ownerName'] as String?) ?? '',
      businessName: (map['businessName'] as String?) ?? '',
      businessDescription: (map['businessDescription'] as String?) ?? '',
      businessType: (map['businessType'] as String?) ?? 'Individual',
      primaryCategoryId: (map['primaryCategoryId'] as String?) ??
          (map['categoryId'] as String?) ??
          (map['category'] as String?) ??
          '',
      primaryCategoryTitle: (map['primaryCategoryTitle'] as String?) ??
          (map['categoryTitle'] as String?) ??
          (map['categoryName'] as String?) ??
          (map['serviceCategory'] as String?) ??
          '',
      selectedCategoryIds: (map['selectedCategoryIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? 
          (map['primaryCategoryId'] != null && map['primaryCategoryId'].toString().isNotEmpty
              ? [map['primaryCategoryId'].toString()]
              : const []),
      adminCategoryOverrideLimit: (map['adminCategoryOverrideLimit'] as num?)?.toInt(),
      subServices: (map['subServices'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      experienceYears: (map['experienceYears'] as num?)?.toInt() ?? 1,
      visitingCharge: (map['visitingCharge'] as num?)?.toDouble() ?? 100.0,
      serviceRadiusKm: (map['serviceRadiusKm'] as num?)?.toDouble() ?? 10.0,
      jamuiArea: (map['jamuiArea'] as String?) ?? (map['area'] as String?) ?? '',
      fullAddress: (map['fullAddress'] as String?) ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      profileImageUrl: (map['profileImageUrl'] as String?) ?? '',
      businessImageUrl: (map['businessImageUrl'] as String?) ?? '',
      workingHours: (map['workingHours'] as String?) ?? '09:00 AM - 08:00 PM',
      hasExperienceCertificate: (map['hasExperienceCertificate'] as bool?) ?? false,
      experienceCertificateUrl: (map['experienceCertificateUrl'] as String?) ?? '',
      experienceCertificateStatus: (map['experienceCertificateStatus'] as String?) ?? 'notUploaded',
      previousOrganization: (map['previousOrganization'] as String?) ?? '',
      experienceDescription: (map['experienceDescription'] as String?) ?? '',
      certificateVerifiedAt: _parseDateTime(map['certificateVerifiedAt']),
      certificateVerifiedBy: map['certificateVerifiedBy'] as String?,
      certificateRejectionReason: map['certificateRejectionReason'] as String?,
      kycStatus: _parseKycStatus(map['kycStatus'] ?? map['verificationStatus'] ?? (map['isVerified'] == true ? 'approved' : null)),
      status: _parseAccountStatus(map['status'] ?? map['verificationStatus'] ?? (map['isVerified'] == true ? 'approved' : null)),
      rejectionReason: (map['rejectionReason'] ?? map['kycRejectionReason']) as String?,
      subscriptionPlan: (map['subscriptionPlan'] as String?) ?? 'free_trial',
      subscriptionPlanTier: (map['subscriptionPlanTier'] as String?)?.trim().toLowerCase() ??
          (map['planTier'] as String?)?.trim().toLowerCase() ??
          '',
      isSubscriptionActive: (map['isSubscriptionActive'] as bool?) ?? false,
      isPremiumEligible: (map['isPremiumEligible'] as bool?) ?? false,
      subscriptionExpiry: _parseDateTime(map['subscriptionExpiry']),
      paymentVerified: (map['paymentVerified'] as bool?) ?? false,
      paymentStatus: (map['paymentStatus'] as String?) ?? (((map['paymentVerified'] as bool?) ?? false) ? 'success' : 'unpaid'),
      paymentOrderId: map['paymentOrderId'] as String?,
      paymentId: (map['paymentId'] ?? map['razorpayPaymentId']) as String?,
      subscriptionApprovalStatus: (map['subscriptionApprovalStatus'] ?? map['approvalStatus']) as String?,
      isActive: (map['isActive'] as bool?) ?? true,
      deactivationReason: map['deactivationReason'] as String?,
      isDeleted: (map['isDeleted'] as bool?) ?? false,
      deletionReason: map['deletionReason'] as String?,
      totalViews: (map['totalViews'] as num?)?.toInt() ?? 0,
      totalCalls: (map['totalCalls'] as num?)?.toInt() ?? 0,
      totalWhatsAppClicks: (map['totalWhatsAppClicks'] as num?)?.toInt() ?? 0,
      rating: (map['rating'] as num?)?.toDouble() ?? 5.0,
      ratingCount: (map['ratingCount'] as num?)?.toInt() ?? 0,
      isAvailable: (map['isAvailable'] as bool?) ?? (map['isOnline'] as bool?) ?? true,
      createdAt: _parseDateTime(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(map['updatedAt']),
      isOtherService: (map['isOtherService'] as bool?) ?? false,
      customServiceStatus: (map['customServiceStatus'] as String?) ?? 'none',
      customServiceName: (map['customServiceName'] as String?) ?? '',
      customServiceDescription: (map['customServiceDescription'] as String?) ?? '',
      customServiceOffered: (map['customServiceOffered'] as String?) ?? '',
      customServiceFeedback: map['customServiceFeedback'] as String?,
      registrationStatus: _parseRegistrationStatus(map),
      currentStep: (map['currentStep'] as num?)?.toInt() ?? 0,
      completedSteps: (map['completedSteps'] as List<dynamic>?)?.map((e) => (e as num).toInt()).toList() ?? const [],
      selectedCategoryId: (map['selectedCategoryId'] as String?) ?? (map['primaryCategoryId'] as String?) ?? '',
      categoryRequestStatus: (map['categoryRequestStatus'] as String?) ?? (map['customServiceStatus'] as String?) ?? 'none',
      categoryRequestId: map['categoryRequestId'] as String?,
      categoryRejectionReason: (map['categoryRejectionReason'] ?? map['rejectionReason']) as String?,
      requestedCategoryId: (map['requestedCategoryId'] as String?) ?? '',
      requestedCategoryTitle: (map['requestedCategoryTitle'] as String?) ?? (map['customServiceName'] as String?) ?? '',
      categoryApprovalStatus: (map['categoryApprovalStatus'] as String?) ?? (map['categoryRequestStatus'] as String?) ?? 'none',
      categoryRequestSubmittedAt: map['categoryRequestSubmittedAt'] is Timestamp
          ? (map['categoryRequestSubmittedAt'] as Timestamp).toDate()
          : (map['categoryRequestSubmittedAt'] is String ? DateTime.tryParse(map['categoryRequestSubmittedAt'] as String) : null),
      galleryImages: (map['galleryImages'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      servicesWithPricing: (map['servicesWithPricing'] as List<dynamic>?)
              ?.whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          const [],
      instagramUrl: (map['instagramUrl'] as String?) ?? (map['instagram'] as String?) ?? '',
      facebookUrl: (map['facebookUrl'] as String?) ?? (map['facebook'] as String?) ?? '',
      websiteUrl: (map['websiteUrl'] as String?) ?? (map['website'] as String?) ?? '',
      categoryType: (map['categoryType'] as String?) ??
          (((map['isPremiumCategory'] as bool?) == true ||
                  (map['isPremiumEligible'] as bool?) == true ||
                  (map['primaryCategoryId'] as String?)?.toLowerCase().trim() == 'unisex_salon' ||
                  (map['primaryCategoryId'] as String?)?.toLowerCase().trim() == 'salon' ||
                  (map['categoryId'] as String?)?.toLowerCase().trim() == 'unisex_salon' ||
                  (map['categoryId'] as String?)?.toLowerCase().trim() == 'salon')
              ? 'premium'
              : 'general'),
      premiumServiceDetails: (map['premiumServiceDetails'] as String?) ?? '',
      generalServiceDetails: (map['generalServiceDetails'] as String?) ?? '',
    );
  }

  static String _parseRegistrationStatus(Map<String, dynamic> map) {
    final rawRegStatus = (map['registrationStatus'] as String?)?.toLowerCase().trim();
    final parsedStatus = _parseAccountStatus(map['status'] ?? map['verificationStatus'] ?? (map['isVerified'] == true ? 'approved' : null));
    final rawCompletedSteps = (map['completedSteps'] as List<dynamic>?)?.map((e) => (e as num).toInt()).toList() ?? const [];

    final bool isFinished = rawCompletedSteps.contains(5) ||
        parsedStatus == ProviderAccountStatus.pendingReview ||
        parsedStatus == ProviderAccountStatus.approved;

    if (rawRegStatus != null && rawRegStatus.isNotEmpty) {
      if (isFinished && rawRegStatus == 'draft') {
        return 'completed';
      }
      return rawRegStatus;
    }

    return isFinished ? 'completed' : 'draft';
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return DateTime.tryParse(value.toString());
  }

  static ProviderKycStatus _parseKycStatus(dynamic status) {
    if (status == null) return ProviderKycStatus.notSubmitted;
    final s = status.toString().toLowerCase().trim().replaceAll(RegExp(r'[\s_\-]'), '');
    if (s == 'approved' || s == 'verified') {
      return ProviderKycStatus.approved;
    } else if (s == 'rejected') {
      return ProviderKycStatus.rejected;
    } else if (s == 'pendingreview' || s == 'pending' || s == 'underreview' || s == 'review' || s == 'submitted') {
      return ProviderKycStatus.pendingReview;
    }
    return ProviderKycStatus.notSubmitted;
  }

  static ProviderAccountStatus _parseAccountStatus(dynamic status) {
    if (status == null) return ProviderAccountStatus.draft;
    final s = status.toString().toLowerCase().trim().replaceAll(RegExp(r'[\s_\-]'), '');
    if (s == 'approved' || s == 'active' || s == 'verified') {
      return ProviderAccountStatus.approved;
    } else if (s == 'rejected') {
      return ProviderAccountStatus.rejected;
    } else if (s == 'suspended') {
      return ProviderAccountStatus.suspended;
    } else if (s == 'blocked') {
      return ProviderAccountStatus.blocked;
    } else if (s == 'pendingreview' || s == 'pending' || s == 'underreview' || s == 'review' || s == 'submitted') {
      return ProviderAccountStatus.pendingReview;
    }
    return ProviderAccountStatus.draft;
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'phoneNumber': phoneNumber,
      'phone': phoneNumber,
      'isMobileVerified': isMobileVerified,
      'isEmailVerified': isEmailVerified,
      'fullName': fullName,
      'ownerName': fullName,
      'businessName': businessName,
      'businessDescription': businessDescription,
      'businessType': businessType,
      'primaryCategoryId': primaryCategoryId,
      'categoryId': primaryCategoryId,
      'category': primaryCategoryId,
      'primaryCategoryTitle': primaryCategoryTitle,
      'categoryTitle': primaryCategoryTitle,
      'selectedCategoryIds': selectedCategoryIds,
      'adminCategoryOverrideLimit': adminCategoryOverrideLimit,
      'subServices': subServices,
      'experienceYears': experienceYears,
      'visitingCharge': visitingCharge,
      'serviceRadiusKm': serviceRadiusKm,
      'jamuiArea': jamuiArea,
      'fullAddress': fullAddress,
      'latitude': hasValidCoordinates ? latitude : null,
      'longitude': hasValidCoordinates ? longitude : null,
      'isLocationAvailable': hasValidCoordinates,
      'profileImageUrl': profileImageUrl,
      'businessImageUrl': businessImageUrl,
      'workingHours': workingHours,
      'hasExperienceCertificate': hasExperienceCertificate,
      'experienceCertificateUrl': experienceCertificateUrl,
      'experienceCertificateStatus': experienceCertificateStatus,
      'previousOrganization': previousOrganization,
      'experienceDescription': experienceDescription,
      'certificateVerifiedAt': certificateVerifiedAt?.toIso8601String(),
      'certificateVerifiedBy': certificateVerifiedBy,
      'certificateRejectionReason': certificateRejectionReason,
      'kycStatus': kycStatus.name,
      'status': status.name,
      'verificationStatus': (status == ProviderAccountStatus.approved)
          ? 'approved'
          : (status == ProviderAccountStatus.rejected ? 'rejected' : 'pending'),
      'isVerified': status == ProviderAccountStatus.approved,
      'rejectionReason': rejectionReason,
      'subscriptionPlan': subscriptionPlan,
      'subscriptionPlanTier': subscriptionPlanTier,
      'isSubscriptionActive': isSubscriptionActive,
      'isPremiumEligible': isPremiumEligible,
      'isPremiumCategory': isPremiumCategory,
      'subscriptionExpiry': subscriptionExpiry?.toIso8601String(),
      'paymentVerified': paymentVerified,
      'paymentStatus': paymentStatus,
      'paymentOrderId': paymentOrderId,
      'paymentId': paymentId,
      'subscriptionApprovalStatus': subscriptionApprovalStatus,
      'isActive': isActive,
      'deactivationReason': deactivationReason,
      'isDeleted': isDeleted,
      'deletionReason': deletionReason,
      'totalViews': totalViews,
      'totalCalls': totalCalls,
      'totalWhatsAppClicks': totalWhatsAppClicks,
      'rating': rating,
      'ratingCount': ratingCount,
      'isAvailable': isAvailable,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isOtherService': isOtherService,
      'customServiceStatus': customServiceStatus,
      'customServiceName': customServiceName,
      'customServiceDescription': customServiceDescription,
      'customServiceOffered': customServiceOffered,
      'customServiceFeedback': customServiceFeedback,
      'registrationStatus': registrationStatus,
      'currentStep': currentStep,
      'completedSteps': completedSteps,
      'selectedCategoryId': selectedCategoryId,
      'categoryRequestStatus': categoryRequestStatus,
      if (categoryRequestId != null) 'categoryRequestId': categoryRequestId,
      if (categoryRejectionReason != null) 'categoryRejectionReason': categoryRejectionReason,
      if (requestedCategoryId.isNotEmpty) 'requestedCategoryId': requestedCategoryId,
      if (requestedCategoryTitle.isNotEmpty) 'requestedCategoryTitle': requestedCategoryTitle,
      'categoryApprovalStatus': categoryApprovalStatus,
      if (categoryRequestSubmittedAt != null) 'categoryRequestSubmittedAt': categoryRequestSubmittedAt,
      'galleryImages': galleryImages,
      'servicesWithPricing': servicesWithPricing,
      'instagramUrl': instagramUrl,
      'facebookUrl': facebookUrl,
      'websiteUrl': websiteUrl,
      'categoryType': categoryType,
      'premiumServiceDetails': premiumServiceDetails,
      'generalServiceDetails': generalServiceDetails,
    };
  }
}
