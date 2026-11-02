import 'package:equatable/equatable.dart';

enum ProviderKycStatus {
  notSubmitted,
  pendingReview,
  approved,
  rejected;

  String get displayNameHindi {
    switch (this) {
      case ProviderKycStatus.notSubmitted:
        return 'KYC अधूरा है';
      case ProviderKycStatus.pendingReview:
        return 'सत्यापन प्रक्रियाधीन (Under Review)';
      case ProviderKycStatus.approved:
        return 'सत्यापित (Verified Provider)';
      case ProviderKycStatus.rejected:
        return 'अस्वीकृत (Rejected)';
    }
  }
}

enum ProviderAccountStatus {
  draft,
  pendingReview,
  approved,
  rejected,
  suspended,
  blocked;

  String get displayNameHindi {
    switch (this) {
      case ProviderAccountStatus.draft:
        return 'प्रोफ़ाइल अधूरी है';
      case ProviderAccountStatus.pendingReview:
        return 'रिव्यू हेतु लंबित';
      case ProviderAccountStatus.approved:
        return 'एक्टिव व स्वीकृत';
      case ProviderAccountStatus.rejected:
        return 'अस्वीकृत';
      case ProviderAccountStatus.suspended:
        return 'निलंबित (Suspended)';
      case ProviderAccountStatus.blocked:
        return 'अकाउंट ब्लॉक है';
    }
  }
}

/// [ProviderProfileEntity] - JAMUI SERVICE सर्विस प्रोवाइडर का कोर डोमेन मॉडल (No Aadhaar / ID Required)
class ProviderProfileEntity extends Equatable {
  final String id;
  final String email;
  final String phoneNumber;
  final bool isMobileVerified;
  final bool isEmailVerified;
  final String fullName;
  final String businessName;
  final String businessDescription;
  final String businessType; // Individual, Small Business, Company, Agency
  final String primaryCategoryId;
  final String primaryCategoryTitle;
  final List<String> selectedCategoryIds;
  final int? adminCategoryOverrideLimit;
  final List<String> subServices;
  final int experienceYears;
  final double visitingCharge;
  final double serviceRadiusKm;
  final String jamuiArea;
  final String fullAddress;
  final double latitude;
  final double longitude;
  final String profileImageUrl;
  final String businessImageUrl;
  final String workingHours;

  // Experience Certificate Verification Fields
  final bool hasExperienceCertificate;
  final String experienceCertificateUrl;
  final String experienceCertificateStatus; // 'notUploaded', 'pendingReview', 'verified', 'rejected'
  final String previousOrganization;
  final String experienceDescription;
  final DateTime? certificateVerifiedAt;
  final String? certificateVerifiedBy;
  final String? certificateRejectionReason;

  final ProviderKycStatus kycStatus;
  final ProviderAccountStatus status;
  final String? rejectionReason;
  final String subscriptionPlan;
  final bool isSubscriptionActive;
  final DateTime? subscriptionExpiry;
  final bool paymentVerified;
  final String paymentStatus; // 'unpaid', 'pending_verification', 'success', 'failed'
  final String? paymentOrderId;
  final String? paymentId;
  final String? subscriptionApprovalStatus; // 'none', 'pending_approval', 'approved', 'rejected'
  final bool isActive;
  final String? deactivationReason;
  final bool isDeleted;
  final String? deletionReason;
  final int totalViews;
  final int totalCalls;
  final int totalWhatsAppClicks;
  final double rating;
  final int ratingCount;
  final bool isAvailable;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Other Service / Custom Category Fields
  final bool isOtherService;
  final String customServiceStatus; // 'none', 'pending_review', 'approved', 'rejected', 'more_info_required'
  final String customServiceName;
  final String customServiceDescription;
  final String customServiceOffered;
  final String? customServiceFeedback;

  // Registration Progress & Category Request Tracking Fields
  final String registrationStatus; // 'draft', 'pending_category_approval', 'category_approved', 'completed'
  final int currentStep; // 0 to 5
  final List<int> completedSteps;
  final String selectedCategoryId;
  final String categoryRequestStatus; // 'none', 'pending_review', 'approved', 'rejected'
  final String? categoryRequestId;
  final String? categoryRejectionReason;
  final String requestedCategoryId;
  final String requestedCategoryTitle;
  final String categoryApprovalStatus; // 'none', 'pending_review', 'approved', 'rejected'
  final DateTime? categoryRequestSubmittedAt;

  // Subscription & Premium Eligibility
  final bool isPremiumEligible;
  final String subscriptionPlanTier; // 'normal' | 'premium'
  final String categoryType; // 'general', 'premium', 'professional'
  final String premiumServiceDetails;
  final String generalServiceDetails;

  /// Authoritative helper: determines if this profile is in the professional seller category/business domain
  bool get isProfessional => categoryType.toLowerCase() == 'professional' ||
      categoryType.toLowerCase() == 'diamond' ||
      businessType.toLowerCase() == 'professional_seller' ||
      businessType.toLowerCase() == 'ecommerce_seller' ||
      businessType.toLowerCase() == 'shopkeeper';

  bool get isDiamond => isProfessional;

  // Unisex Salon & Rich Business Fields
  final List<String> galleryImages;
  final List<Map<String, dynamic>> servicesWithPricing;
  final String instagramUrl;
  final String facebookUrl;
  final String websiteUrl;

  const ProviderProfileEntity({
    required this.id,
    required this.email,
    required this.phoneNumber,
    this.isMobileVerified = true,
    this.isEmailVerified = true,
    required this.fullName,
    required this.businessName,
    this.businessDescription = '',
    this.businessType = 'Individual',
    required this.primaryCategoryId,
    required this.primaryCategoryTitle,
    this.selectedCategoryIds = const [],
    this.adminCategoryOverrideLimit,
    this.subServices = const [],
    this.experienceYears = 1,
    this.visitingCharge = 100.0,
    this.serviceRadiusKm = 10.0,
    this.jamuiArea = '',
    this.fullAddress = '',
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.profileImageUrl = '',
    this.businessImageUrl = '',
    this.workingHours = '09:00 AM - 08:00 PM',
    this.hasExperienceCertificate = false,
    this.experienceCertificateUrl = '',
    this.experienceCertificateStatus = 'notUploaded',
    this.previousOrganization = '',
    this.experienceDescription = '',
    this.certificateVerifiedAt,
    this.certificateVerifiedBy,
    this.certificateRejectionReason,
    this.kycStatus = ProviderKycStatus.notSubmitted,
    this.status = ProviderAccountStatus.draft,
    this.rejectionReason,
    this.subscriptionPlan = 'free_trial',
    this.subscriptionPlanTier = '',
    this.isSubscriptionActive = false,
    this.isPremiumEligible = false,
    this.subscriptionExpiry,
    this.paymentVerified = false,
    this.paymentStatus = 'unpaid',
    this.paymentOrderId,
    this.paymentId,
    this.subscriptionApprovalStatus,
    this.isActive = true,
    this.deactivationReason,
    this.isDeleted = false,
    this.deletionReason,
    this.totalViews = 0,
    this.totalCalls = 0,
    this.totalWhatsAppClicks = 0,
    this.rating = 5.0,
    this.ratingCount = 0,
    this.isAvailable = true,
    required this.createdAt,
    this.updatedAt,
    this.isOtherService = false,
    this.customServiceStatus = 'none',
    this.customServiceName = '',
    this.customServiceDescription = '',
    this.customServiceOffered = '',
    this.customServiceFeedback,
    this.registrationStatus = 'draft',
    this.currentStep = 0,
    this.completedSteps = const [],
    this.selectedCategoryId = '',
    this.categoryRequestStatus = 'none',
    this.categoryRequestId,
    this.categoryRejectionReason,
    this.requestedCategoryId = '',
    this.requestedCategoryTitle = '',
    this.categoryApprovalStatus = 'none',
    this.categoryRequestSubmittedAt,
    this.galleryImages = const [],
    this.servicesWithPricing = const [],
    this.instagramUrl = '',
    this.facebookUrl = '',
    this.websiteUrl = '',
    this.categoryType = 'general',
    this.premiumServiceDetails = '',
    this.generalServiceDetails = '',
  });

  /// [categoryLimit] - Subscription Plan या Admin Override के अनुसार कैटगरी की अधिकतम अनुमति संख्या
  int get categoryLimit {
    if (adminCategoryOverrideLimit != null && adminCategoryOverrideLimit! > 0) {
      return adminCategoryOverrideLimit!;
    }
    switch (subscriptionPlan.toLowerCase()) {
      case 'premium':
        return 5;
      case 'pro':
        return 3;
      case 'basic':
      case 'free_trial':
      default:
        return 1;
    }
  }

  /// Whether provider is currently on an active free trial (requires explicit unexpired date)
  bool get isTrialActive {
    if (subscriptionPlan.toLowerCase() != 'free_trial') return false;
    if (subscriptionExpiry == null) return false;
    return subscriptionExpiry!.isAfter(DateTime.now());
  }

  /// Whether provider has a paid active subscription (verified payment and unexpired)
  bool get hasPaidSubscription {
    if (!paymentVerified) return false;
    final plan = subscriptionPlan.toLowerCase();
    if (plan == 'free_trial' || plan == 'none' || plan.isEmpty) return false;
    if (!isSubscriptionActive) return false;
    if (subscriptionExpiry == null) return false;
    return subscriptionExpiry!.isAfter(DateTime.now());
  }

  /// Whether current subscription or free trial has expired or is unverified
  bool get isSubscriptionExpired {
    if (subscriptionExpiry == null) return true;
    return subscriptionExpiry!.isBefore(DateTime.now());
  }

  /// Whether subscription renewal is due within 7 days
  bool get isRenewalDue {
    if (subscriptionExpiry == null) return false;
    final now = DateTime.now();
    final remainingDays = subscriptionExpiry!.difference(now).inDays;
    return remainingDays >= 0 && remainingDays <= 7;
  }

  /// Whether payment has been verified by server but subscription is awaiting Admin manual activation
  bool get isSubscriptionPendingApproval {
    if (!paymentVerified) return false;
    return !isSubscriptionActive || subscriptionApprovalStatus == 'pending_approval';
  }

  /// Whether provider is fully eligible to receive leads and go online
  bool get isPermittedForLeads {
    if (isDeleted) return false;
    if (!isActive) return false;
    if (status != ProviderAccountStatus.approved) return false;
    if (kycStatus != ProviderKycStatus.approved) return false;
    return hasPaidSubscription && !isSubscriptionExpired;
  }


  bool get hasValidCoordinates => latitude != 0.0 && longitude != 0.0;
  bool get isLocationUnavailable => !hasValidCoordinates;

  /// List of uncompleted required profile field descriptions (NO Aadhaar / ID)
  List<String> get missingFields {
    final List<String> list = [];
    if (fullName.trim().isEmpty) list.add('प्रोवाइडर नाम (Full Name)');
    if (phoneNumber.trim().isEmpty || !isMobileVerified) list.add('मोबाइल वेरीफिकेशन (Mobile OTP)');
    if (email.trim().isEmpty || !isEmailVerified) list.add('ईमेल वेरीफिकेशन (Email Verification)');
    if (profileImageUrl.trim().isEmpty) list.add('प्रोफाइल फोटो (Real Profile Photo)');
    if (businessName.trim().isEmpty) list.add('दुकान / व्यापार नाम (Business Name)');
    if (primaryCategoryId.trim().isEmpty && selectedCategoryIds.isEmpty) list.add('सेवा श्रेणी (Category)');
    if (fullAddress.trim().isEmpty || !hasValidCoordinates) list.add('वास्तविक GPS स्थान (GPS Coordinates)');
    if (serviceRadiusKm <= 0) list.add('सेवा दायरा (Service Radius)');
    if (workingHours.trim().isEmpty) list.add('कार्य समय (Working Hours)');
    if (businessImageUrl.trim().isEmpty) list.add('व्यापार / वर्कप्लेस फोटो (Business Photo)');
    return list;
  }

  /// Calculated profile completion percentage (0% to 100%)
  int get completionPercentage {
    int score = 0;
    if (fullName.trim().isNotEmpty) score += 10;
    if (phoneNumber.trim().isNotEmpty && isMobileVerified) score += 10;
    if (email.trim().isNotEmpty && isEmailVerified) score += 10;
    if (profileImageUrl.trim().isNotEmpty) score += 10;
    if (businessName.trim().isNotEmpty) score += 10;
    if (primaryCategoryId.trim().isNotEmpty || selectedCategoryIds.isNotEmpty) score += 10;
    if (fullAddress.trim().isNotEmpty && hasValidCoordinates) score += 10;
    if (serviceRadiusKm > 0) score += 10;
    if (workingHours.trim().isNotEmpty) score += 10;
    if (businessImageUrl.trim().isNotEmpty) score += 10;
    return score.clamp(0, 100);
  }

  ProviderProfileEntity copyWith({
    String? id,
    String? email,
    String? phoneNumber,
    bool? isMobileVerified,
    bool? isEmailVerified,
    String? fullName,
    String? businessName,
    String? businessDescription,
    String? businessType,
    String? primaryCategoryId,
    String? primaryCategoryTitle,
    List<String>? selectedCategoryIds,
    int? adminCategoryOverrideLimit,
    List<String>? subServices,
    int? experienceYears,
    double? visitingCharge,
    double? serviceRadiusKm,
    String? jamuiArea,
    String? fullAddress,
    double? latitude,
    double? longitude,
    String? profileImageUrl,
    String? businessImageUrl,
    String? workingHours,
    bool? hasExperienceCertificate,
    String? experienceCertificateUrl,
    String? experienceCertificateStatus,
    String? previousOrganization,
    String? experienceDescription,
    DateTime? certificateVerifiedAt,
    String? certificateVerifiedBy,
    String? certificateRejectionReason,
    ProviderKycStatus? kycStatus,
    ProviderAccountStatus? status,
    String? rejectionReason,
    String? subscriptionPlan,
    String? subscriptionPlanTier,
    bool? isSubscriptionActive,
    bool? isPremiumEligible,
    DateTime? subscriptionExpiry,
    bool? paymentVerified,
    String? paymentStatus,
    String? paymentOrderId,
    String? paymentId,
    String? subscriptionApprovalStatus,
    bool? isActive,
    String? deactivationReason,
    bool? isDeleted,
    String? deletionReason,
    int? totalViews,
    int? totalCalls,
    int? totalWhatsAppClicks,
    double? rating,
    int? ratingCount,
    bool? isAvailable,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isOtherService,
    String? customServiceStatus,
    String? customServiceName,
    String? customServiceDescription,
    String? customServiceOffered,
    String? customServiceFeedback,
    String? registrationStatus,
    int? currentStep,
    List<int>? completedSteps,
    String? selectedCategoryId,
    String? categoryRequestStatus,
    String? categoryRequestId,
    String? categoryRejectionReason,
    String? requestedCategoryId,
    String? requestedCategoryTitle,
    String? categoryApprovalStatus,
    DateTime? categoryRequestSubmittedAt,
    List<String>? galleryImages,
    List<Map<String, dynamic>>? servicesWithPricing,
    String? instagramUrl,
    String? facebookUrl,
    String? websiteUrl,
    String? categoryType,
    String? premiumServiceDetails,
    String? generalServiceDetails,
  }) {
    return ProviderProfileEntity(
      id: id ?? this.id,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isMobileVerified: isMobileVerified ?? this.isMobileVerified,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      fullName: fullName ?? this.fullName,
      businessName: businessName ?? this.businessName,
      businessDescription: businessDescription ?? this.businessDescription,
      businessType: businessType ?? this.businessType,
      primaryCategoryId: primaryCategoryId ?? this.primaryCategoryId,
      primaryCategoryTitle: primaryCategoryTitle ?? this.primaryCategoryTitle,
      selectedCategoryIds: selectedCategoryIds ?? this.selectedCategoryIds,
      adminCategoryOverrideLimit: adminCategoryOverrideLimit ?? this.adminCategoryOverrideLimit,
      subServices: subServices ?? this.subServices,
      experienceYears: experienceYears ?? this.experienceYears,
      visitingCharge: visitingCharge ?? this.visitingCharge,
      serviceRadiusKm: serviceRadiusKm ?? this.serviceRadiusKm,
      jamuiArea: jamuiArea ?? this.jamuiArea,
      fullAddress: fullAddress ?? this.fullAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      businessImageUrl: businessImageUrl ?? this.businessImageUrl,
      workingHours: workingHours ?? this.workingHours,
      hasExperienceCertificate: hasExperienceCertificate ?? this.hasExperienceCertificate,
      experienceCertificateUrl: experienceCertificateUrl ?? this.experienceCertificateUrl,
      experienceCertificateStatus: experienceCertificateStatus ?? this.experienceCertificateStatus,
      previousOrganization: previousOrganization ?? this.previousOrganization,
      experienceDescription: experienceDescription ?? this.experienceDescription,
      certificateVerifiedAt: certificateVerifiedAt ?? this.certificateVerifiedAt,
      certificateVerifiedBy: certificateVerifiedBy ?? this.certificateVerifiedBy,
      certificateRejectionReason: certificateRejectionReason ?? this.certificateRejectionReason,
      kycStatus: kycStatus ?? this.kycStatus,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      subscriptionPlan: subscriptionPlan ?? this.subscriptionPlan,
      subscriptionPlanTier: subscriptionPlanTier ?? this.subscriptionPlanTier,
      isSubscriptionActive: isSubscriptionActive ?? this.isSubscriptionActive,
      isPremiumEligible: isPremiumEligible ?? this.isPremiumEligible,
      subscriptionExpiry: subscriptionExpiry ?? this.subscriptionExpiry,
      paymentVerified: paymentVerified ?? this.paymentVerified,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentOrderId: paymentOrderId ?? this.paymentOrderId,
      paymentId: paymentId ?? this.paymentId,
      subscriptionApprovalStatus: subscriptionApprovalStatus ?? this.subscriptionApprovalStatus,
      isActive: isActive ?? this.isActive,
      deactivationReason: deactivationReason ?? this.deactivationReason,
      isDeleted: isDeleted ?? this.isDeleted,
      deletionReason: deletionReason ?? this.deletionReason,
      totalViews: totalViews ?? this.totalViews,
      totalCalls: totalCalls ?? this.totalCalls,
      totalWhatsAppClicks: totalWhatsAppClicks ?? this.totalWhatsAppClicks,
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
      isAvailable: isAvailable ?? this.isAvailable,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isOtherService: isOtherService ?? this.isOtherService,
      customServiceStatus: customServiceStatus ?? this.customServiceStatus,
      customServiceName: customServiceName ?? this.customServiceName,
      customServiceDescription: customServiceDescription ?? this.customServiceDescription,
      customServiceOffered: customServiceOffered ?? this.customServiceOffered,
      customServiceFeedback: customServiceFeedback ?? this.customServiceFeedback,
      registrationStatus: registrationStatus ?? this.registrationStatus,
      currentStep: currentStep ?? this.currentStep,
      completedSteps: completedSteps ?? this.completedSteps,
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      categoryRequestStatus: categoryRequestStatus ?? this.categoryRequestStatus,
      categoryRequestId: categoryRequestId ?? this.categoryRequestId,
      categoryRejectionReason: categoryRejectionReason ?? this.categoryRejectionReason,
      requestedCategoryId: requestedCategoryId ?? this.requestedCategoryId,
      requestedCategoryTitle: requestedCategoryTitle ?? this.requestedCategoryTitle,
      categoryApprovalStatus: categoryApprovalStatus ?? this.categoryApprovalStatus,
      categoryRequestSubmittedAt: categoryRequestSubmittedAt ?? this.categoryRequestSubmittedAt,
      galleryImages: galleryImages ?? this.galleryImages,
      servicesWithPricing: servicesWithPricing ?? this.servicesWithPricing,
      instagramUrl: instagramUrl ?? this.instagramUrl,
      facebookUrl: facebookUrl ?? this.facebookUrl,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      categoryType: categoryType ?? this.categoryType,
      premiumServiceDetails: premiumServiceDetails ?? this.premiumServiceDetails,
      generalServiceDetails: generalServiceDetails ?? this.generalServiceDetails,
    );
  }

  /// Whether a category change request is currently submitted and awaiting admin approval
  bool get isCategoryChangePending =>
      (categoryApprovalStatus == 'pending_review' ||
          categoryApprovalStatus == 'pending' ||
          categoryRequestStatus == 'pending_review') &&
      requestedCategoryTitle.isNotEmpty;

  /// Whether the requested category was rejected by admin
  bool get isCategoryRejected =>
      categoryApprovalStatus == 'rejected' || categoryRequestStatus == 'rejected';

  /// Whether provider belongs to a premium category (explicitly configured or Unisex Salon)
  bool get isPremiumCategory => categoryType.toLowerCase() == 'premium' || isUnisexSalon;

  /// Authoritative provider subscription tier ('normal' | 'premium')
  /// Separates category from plan tier, validates admin approval & entitlement.
  /// Priority:
  /// 1. Current / historical subscription tier (locks renewal to that tier)
  /// 2. Explicit Admin Approval on profile (isPremiumEligible == true)
  /// 3. Provider whose category is premium (e.g. Unisex Salon, even while pending review)
  /// 4. Default: 'normal'
  String get resolvedPlanTier {
    final subTier = subscriptionPlanTier.trim().toLowerCase();
    if (subTier == 'premium') return 'premium';
    if (subTier == 'normal') return 'normal';
    if (isPremiumEligible || isPremiumCategory) return 'premium';
    return 'normal';
  }

  // --- SOCIAL & SALON HELPERS ---
  bool get hasInstagram => instagramUrl.trim().isNotEmpty;
  bool get hasFacebook => facebookUrl.trim().isNotEmpty;
  bool get hasWebsite => websiteUrl.trim().isNotEmpty;

  String get instagramHandle {
    final raw = instagramUrl.trim();
    if (raw.isEmpty) return '';
    if (raw.contains('instagram.com/')) {
      final parts = raw.split('instagram.com/');
      if (parts.length > 1) {
        final handle = parts[1].split('?').first.replaceAll('/', '').trim();
        return handle.isNotEmpty ? '@$handle' : raw;
      }
    }
    return raw.startsWith('@') ? raw : '@$raw';
  }

  String get instagramLaunchUrl {
    final raw = instagramUrl.trim();
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    final cleanHandle = raw.replaceAll('@', '').trim();
    return 'https://instagram.com/$cleanHandle';
  }

  String get facebookLaunchUrl {
    final raw = facebookUrl.trim();
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return 'https://facebook.com/$raw';
  }

  String get websiteLaunchUrl {
    final raw = websiteUrl.trim();
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return 'https://$raw';
  }

  /// Canonical category title with fallback resolution from ID or default neutral title
  String get resolvedCategoryTitle {
    final title = primaryCategoryTitle.trim();
    if (title.isNotEmpty) return title;
    final id = primaryCategoryId.trim();
    if (id.isNotEmpty) {
      switch (id.toLowerCase()) {
        case 'electrician':
          return 'इलेक्ट्रीशियन';
        case 'plumber':
          return 'प्लम्बर';
        case 'carpenter':
          return 'बढ़ई (कारपेंटर)';
        case 'painter':
          return 'पेंटर';
        case 'appliance_repair':
          return 'होम अप्लायंसेज रिपेयर';
        case 'ac_repair':
        case 'ac_service':
          return 'एसी सर्विस व रिपेयर';
        case 'cleaning':
          return 'क्लीनिंग सर्विस';
        case 'water_tank_cleaning':
          return 'पानी टंकी सफाई';
        case 'mechanic':
        case 'auto_mechanic':
          return 'ऑटो / बाइक मैकेनिक';
        case 'unisex_salon':
        case 'salon':
          return 'यूनिसेक्स सैलून';
        default:
          return id;
      }
    }
    return 'सेवा प्रदाता';
  }

  /// Whether provider is approved, active, and has an unexpired subscription
  bool get isApprovedAndLive {
    final isApproved = status == ProviderAccountStatus.approved;
    final isNotExpired = subscriptionExpiry == null || subscriptionExpiry!.isAfter(DateTime.now());
    return isApproved && isSubscriptionActive && isActive && !isDeleted && isNotExpired;
  }

  /// Whether provider genuinely qualifies for Premium showcase/badge
  bool get isPremiumApprovedAndLive => isApprovedAndLive && isPremiumEligible;

  bool get isUnisexSalon {
    final catId = primaryCategoryId.toLowerCase().trim();
    final catTitle = primaryCategoryTitle.toLowerCase().trim();
    return catId == 'unisex_salon' ||
        catId == 'salon' ||
        catTitle.contains('unisex salon') ||
        catTitle.contains('यूनिसेक्स');
  }

  @override
  List<Object?> get props => [
        id,
        email,
        phoneNumber,
        isMobileVerified,
        isEmailVerified,
        fullName,
        businessName,
        businessDescription,
        businessType,
        primaryCategoryId,
        primaryCategoryTitle,
        selectedCategoryIds,
        adminCategoryOverrideLimit,
        subServices,
        experienceYears,
        visitingCharge,
        serviceRadiusKm,
        jamuiArea,
        fullAddress,
        latitude,
        longitude,
        profileImageUrl,
        businessImageUrl,
        workingHours,
        hasExperienceCertificate,
        experienceCertificateUrl,
        experienceCertificateStatus,
        previousOrganization,
        experienceDescription,
        certificateVerifiedAt,
        certificateVerifiedBy,
        certificateRejectionReason,
        kycStatus,
        status,
        rejectionReason,
        subscriptionPlan,
        subscriptionPlanTier,
        isSubscriptionActive,
        isPremiumEligible,
        subscriptionExpiry,
        paymentVerified,
        paymentStatus,
        paymentOrderId,
        paymentId,
        subscriptionApprovalStatus,
        isActive,
        deactivationReason,
        isDeleted,
        deletionReason,
        totalViews,
        totalCalls,
        totalWhatsAppClicks,
        rating,
        ratingCount,
        isAvailable,
        createdAt,
        updatedAt,
        isOtherService,
        customServiceStatus,
        customServiceName,
        customServiceDescription,
        customServiceOffered,
        customServiceFeedback,
        registrationStatus,
        currentStep,
        completedSteps,
        selectedCategoryId,
        categoryRequestStatus,
        categoryRequestId,
        categoryRejectionReason,
        requestedCategoryId,
        requestedCategoryTitle,
        categoryApprovalStatus,
        categoryRequestSubmittedAt,
        galleryImages,
        servicesWithPricing,
        instagramUrl,
        facebookUrl,
        websiteUrl,
        categoryType,
        premiumServiceDetails,
        generalServiceDetails,
      ];
}
