import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/service_provider_entity.dart';

class ServiceProviderModel extends ServiceProviderEntity {
  const ServiceProviderModel({
    required super.id,
    required super.fullName,
    required super.businessName,
    required super.phoneNumber,
    required super.categoryId,
    required super.categoryTitle,
    super.selectedCategoryIds,
    required super.visitingCharge,
    required super.experienceYears,
    required super.jamuiArea,
    super.fullAddress,
    super.latitude,
    super.longitude,
    super.serviceRadiusKm,
    super.profileImageUrl,
    super.businessImageUrl,
    super.businessDescription,
    super.workingHours,
    super.rating,
    super.ratingCount,
    super.isAvailable,
    super.isVerified,
    super.hasExperienceCertificate,
    super.experienceCertificateStatus,
    super.status,
    super.kycStatus,
    super.isSubscriptionActive,
    super.paymentVerified,
    super.subscriptionExpiry,
    super.subServices,
    super.distanceKm,
    super.isActive,
    super.isDeleted,
    // ML ranking features (read from Firestore)
    super.totalViews,
    super.totalCalls,
    super.totalWhatsAppClicks,
    super.subscriptionPlan,
    super.isPremiumEligible,
    super.galleryImages,
    super.servicesWithPricing,
    super.instagramUrl,
    super.facebookUrl,
    super.websiteUrl,
  });

  factory ServiceProviderModel.fromMap(Map<String, dynamic> map, String id) {
    final kycStatusStr = (map['kycStatus'] as String?) ?? (map['verificationStatus'] as String?) ?? 'notSubmitted';
    final statusStr = (map['status'] as String?) ?? (map['verificationStatus'] as String?) ?? 'pendingReview';
    final isBlockedOrRejected = statusStr.toLowerCase() == 'rejected' ||
        statusStr.toLowerCase() == 'suspended' ||
        statusStr.toLowerCase() == 'blocked' ||
        kycStatusStr.toLowerCase() == 'rejected';

    final isExplicitApprovedStatus = statusStr.toLowerCase() == 'approved' ||
        statusStr.toLowerCase() == 'active' ||
        kycStatusStr.toLowerCase() == 'approved';

    // Strict Security Guard: A provider is verified ONLY IF explicitly approved by Admin
    // and NOT in a blocked, suspended, or rejected state.
    // Client-side or tampered 'isVerified': true on unapproved accounts is strictly rejected.
    final isVerified = isExplicitApprovedStatus && !isBlockedOrRejected;
    final isAvailable = (map['isAvailable'] as bool?) ?? (map['isOnline'] as bool?) ?? true;

    // Lifecycle status: active by default unless explicitly false; not deleted unless explicitly true
    final isActive = (map['isActive'] as bool?) ?? true;
    final isDeleted = (map['isDeleted'] as bool?) ?? false;

    final selectedCategories = (map['selectedCategoryIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
        ((map['primaryCategoryId'] ?? map['categoryId']) != null
            ? [map['primaryCategoryId']?.toString() ?? map['categoryId']?.toString() ?? '']
            : const <String>[]);

    DateTime? subscriptionExpiry;
    final rawExpiry = map['subscriptionExpiry'];
    if (rawExpiry is Timestamp) {
      subscriptionExpiry = rawExpiry.toDate();
    } else if (rawExpiry != null) {
      subscriptionExpiry = DateTime.tryParse(rawExpiry.toString());
    }

    final rawPaymentVerified = map['paymentVerified'] as bool? ?? false;
    final rawIsSubActive = (map['isSubscriptionActive'] as bool?) ?? false;

    return ServiceProviderModel(
      id: id,
      fullName: (map['fullName'] as String?) ?? (map['ownerName'] as String?) ?? '',
      businessName: (map['businessName'] as String?) ?? '',
      phoneNumber: (map['phoneNumber'] as String?) ?? (map['phone'] as String?) ?? '',
      categoryId: (map['primaryCategoryId'] as String?) ?? (map['categoryId'] as String?) ?? '',
      categoryTitle: (map['primaryCategoryTitle'] as String?) ??
          (map['categoryTitle'] as String?) ??
          (map['categoryName'] as String?) ??
          (map['category'] as String?) ??
          (map['serviceCategory'] as String?) ??
          '',
      selectedCategoryIds: selectedCategories,
      visitingCharge: (map['visitingCharge'] as num?)?.toDouble() ?? 100.0,
      experienceYears: (map['experienceYears'] as num?)?.toInt() ?? 1,
      jamuiArea: (map['jamuiArea'] as String?) ?? (map['area'] as String?) ?? '',
      fullAddress: (map['fullAddress'] as String?) ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      serviceRadiusKm: (map['serviceRadiusKm'] as num?)?.toDouble() ?? 10.0,
      profileImageUrl: (map['profileImageUrl'] as String?) ?? '',
      businessImageUrl: (map['businessImageUrl'] as String?) ?? '',
      businessDescription: (map['businessDescription'] as String?) ?? '',
      workingHours: (map['workingHours'] as String?) ?? '09:00 AM - 08:00 PM',
      rating: (map['rating'] as num?)?.toDouble() ?? 5.0,
      ratingCount: (map['ratingCount'] as num?)?.toInt() ?? 0,
      isAvailable: isAvailable,
      isVerified: isVerified,
      hasExperienceCertificate: (map['hasExperienceCertificate'] as bool?) ?? false,
      experienceCertificateStatus: (map['experienceCertificateStatus'] as String?) ?? 'notUploaded',
      status: statusStr,
      kycStatus: kycStatusStr,
      isSubscriptionActive: rawIsSubActive,
      paymentVerified: rawPaymentVerified,
      subscriptionExpiry: subscriptionExpiry,
      subServices: (map['subServices'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      isActive: isActive,
      isDeleted: isDeleted,
      // ML ranking feature fields
      totalViews: (map['totalViews'] as num?)?.toInt() ?? 0,
      totalCalls: (map['totalCalls'] as num?)?.toInt() ?? 0,
      totalWhatsAppClicks: (map['totalWhatsAppClicks'] as num?)?.toInt() ?? 0,
      subscriptionPlan: (map['subscriptionPlan'] as String?) ?? 'free_trial',
      // Strictly resolve isPremiumEligible from explicit verified flag or authoritative plan limits.
      // Never infer from categoryType, isPremiumCategory, category membership, or plan name string.
      // Missing plan metadata or conflicting data strictly fails closed to false.
      isPremiumEligible: (map['isPremiumEligible'] as bool?) ??
          ((map['planLimits'] as Map?)?['isPremiumCategoryEligible'] as bool? ?? false),
      // Unisex Salon & Rich details
      galleryImages: (map['galleryImages'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      servicesWithPricing: (map['servicesWithPricing'] as List<dynamic>?)
              ?.whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          const [],
      instagramUrl: (map['instagramUrl'] as String?) ?? (map['instagram'] as String?) ?? '',
      facebookUrl: (map['facebookUrl'] as String?) ?? (map['facebook'] as String?) ?? '',
      websiteUrl: (map['websiteUrl'] as String?) ?? (map['website'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'businessName': businessName,
      'phoneNumber': phoneNumber,
      'primaryCategoryId': categoryId,
      'primaryCategoryTitle': categoryTitle,
      'selectedCategoryIds': selectedCategoryIds,
      'visitingCharge': visitingCharge,
      'experienceYears': experienceYears,
      'jamuiArea': jamuiArea,
      'fullAddress': fullAddress,
      'latitude': latitude,
      'longitude': longitude,
      'serviceRadiusKm': serviceRadiusKm,
      'profileImageUrl': profileImageUrl,
      'businessImageUrl': businessImageUrl,
      'businessDescription': businessDescription,
      'workingHours': workingHours,
      'rating': rating,
      'isActive': isActive,
      'isDeleted': isDeleted,
      'ratingCount': ratingCount,
      'isAvailable': isAvailable,
      'isVerified': isVerified,
      'hasExperienceCertificate': hasExperienceCertificate,
      'experienceCertificateStatus': experienceCertificateStatus,
      'status': status,
      'kycStatus': kycStatus,
      'isSubscriptionActive': isSubscriptionActive,
      'paymentVerified': paymentVerified,
      'subscriptionExpiry': subscriptionExpiry?.toIso8601String(),
      'subServices': subServices,
      'isPremiumEligible': isPremiumEligible,
      'galleryImages': galleryImages,
      'servicesWithPricing': servicesWithPricing,
      'instagramUrl': instagramUrl,
      'facebookUrl': facebookUrl,
      'websiteUrl': websiteUrl,
    };
  }

  @override
  ServiceProviderModel copyWith({
    double? distanceKm,
    int? totalViews,
    int? totalCalls,
    int? totalWhatsAppClicks,
    String? subscriptionPlan,
    bool? isSubscriptionActive,
    bool? paymentVerified,
    DateTime? subscriptionExpiry,
    bool? isActive,
    bool? isDeleted,
    bool? isPremiumEligible,
    List<String>? galleryImages,
    List<Map<String, dynamic>>? servicesWithPricing,
    String? instagramUrl,
    String? facebookUrl,
    String? websiteUrl,
  }) {
    return ServiceProviderModel(
      id: id,
      fullName: fullName,
      businessName: businessName,
      phoneNumber: phoneNumber,
      categoryId: categoryId,
      categoryTitle: categoryTitle,
      selectedCategoryIds: selectedCategoryIds,
      visitingCharge: visitingCharge,
      experienceYears: experienceYears,
      jamuiArea: jamuiArea,
      fullAddress: fullAddress,
      latitude: latitude,
      longitude: longitude,
      serviceRadiusKm: serviceRadiusKm,
      profileImageUrl: profileImageUrl,
      businessImageUrl: businessImageUrl,
      businessDescription: businessDescription,
      workingHours: workingHours,
      rating: rating,
      ratingCount: ratingCount,
      isAvailable: isAvailable,
      isVerified: isVerified,
      hasExperienceCertificate: hasExperienceCertificate,
      experienceCertificateStatus: experienceCertificateStatus,
      status: status,
      kycStatus: kycStatus,
      isSubscriptionActive: isSubscriptionActive ?? this.isSubscriptionActive,
      paymentVerified: paymentVerified ?? this.paymentVerified,
      subscriptionExpiry: subscriptionExpiry ?? this.subscriptionExpiry,
      subServices: subServices,
      distanceKm: distanceKm ?? this.distanceKm,
      isActive: isActive ?? this.isActive,
      isDeleted: isDeleted ?? this.isDeleted,
      totalViews: totalViews ?? this.totalViews,
      totalCalls: totalCalls ?? this.totalCalls,
      totalWhatsAppClicks: totalWhatsAppClicks ?? this.totalWhatsAppClicks,
      subscriptionPlan: subscriptionPlan ?? this.subscriptionPlan,
      isPremiumEligible: isPremiumEligible ?? this.isPremiumEligible,
      galleryImages: galleryImages ?? this.galleryImages,
      servicesWithPricing: servicesWithPricing ?? this.servicesWithPricing,
      instagramUrl: instagramUrl ?? this.instagramUrl,
      facebookUrl: facebookUrl ?? this.facebookUrl,
      websiteUrl: websiteUrl ?? this.websiteUrl,
    );
  }
}
