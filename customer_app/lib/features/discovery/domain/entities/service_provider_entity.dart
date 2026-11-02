import 'package:equatable/equatable.dart';

class ServiceProviderEntity extends Equatable {
  final String id;
  final String fullName;
  final String businessName;
  final String phoneNumber;
  final String categoryId;
  final String categoryTitle;
  final List<String> selectedCategoryIds;
  final double visitingCharge;
  final int experienceYears;
  final String jamuiArea;
  final String fullAddress;
  final double latitude;
  final double longitude;
  final double serviceRadiusKm;
  final String profileImageUrl;
  final String businessImageUrl;
  final String businessDescription;
  final String workingHours;
  final double rating;
  final int ratingCount;
  final bool isAvailable;
  final bool isVerified;
  final bool hasExperienceCertificate;
  final String experienceCertificateStatus;
  final String status;
  final String kycStatus;
  final bool isSubscriptionActive;
  final bool paymentVerified;
  final DateTime? subscriptionExpiry;
  final List<String> subServices;
  final double? distanceKm; // Calculated relative to customer GPS

  // --- ADMIN LIFECYCLE & SOFT-DELETE GUARDS ---
  final bool isActive;
  final bool isDeleted;

  // --- ML RANKING FEATURES: Engagement counters (read-only from customer app) ---
  final int totalViews;
  final int totalCalls;
  final int totalWhatsAppClicks;

  // --- ML RANKING FEATURE: Subscription tier for ranking boost ---
  final String subscriptionPlan;
  final bool isPremiumEligible;

  // --- UNISEX SALON & RICH BUSINESS FIELDS ---
  final List<String> galleryImages;
  final List<Map<String, dynamic>> servicesWithPricing;
  final String instagramUrl;
  final String facebookUrl;
  final String websiteUrl;

  const ServiceProviderEntity({
    required this.id,
    required this.fullName,
    required this.businessName,
    required this.phoneNumber,
    required this.categoryId,
    required this.categoryTitle,
    this.selectedCategoryIds = const [],
    required this.visitingCharge,
    required this.experienceYears,
    this.jamuiArea = '',
    this.fullAddress = '',
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.serviceRadiusKm = 10.0,
    this.profileImageUrl = '',
    this.businessImageUrl = '',
    this.businessDescription = '',
    this.workingHours = '09:00 AM - 08:00 PM',
    this.rating = 5.0,
    this.ratingCount = 0,
    this.isAvailable = true,
    this.isVerified = true,
    this.hasExperienceCertificate = false,
    this.experienceCertificateStatus = 'notUploaded',
    this.status = 'approved',
    this.kycStatus = 'approved',
    this.isSubscriptionActive = false,
    this.paymentVerified = false,
    this.subscriptionExpiry,
    this.subServices = const [],
    this.distanceKm,
    this.isActive = true,
    this.isDeleted = false,
    this.totalViews = 0,
    this.totalCalls = 0,
    this.totalWhatsAppClicks = 0,
    this.subscriptionPlan = 'free_trial',
    this.isPremiumEligible = false,
    this.galleryImages = const [],
    this.servicesWithPricing = const [],
    this.instagramUrl = '',
    this.facebookUrl = '',
    this.websiteUrl = '',
  });

  ServiceProviderEntity copyWith({
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
    return ServiceProviderEntity(
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

  /// Strict Authoritative Approval Check:
  /// A provider is visible in Customer App IF AND ONLY IF:
  /// 1. NOT Deleted / Soft-deleted (`isDeleted != true`)
  /// 2. Explicitly Enabled by Admin (`isActive != false`)
  /// 3. Explicitly Approved by Admin (`isVerified == true` OR status is 'approved'/'active' OR kycStatus is 'approved')
  /// 4. NOT in rejected, suspended, or blocked state
  /// 5. Marked as available/online (`isAvailable == true`)
  /// 6. Has a verified paid subscription (`paymentVerified == true` AND `isSubscriptionActive == true`)
  /// 7. Current subscription is not expired (`subscriptionExpiry != null` AND `subscriptionExpiry!.isAfter(DateTime.now())`)
  bool get isApprovedAndLive {
    // 1. Soft-delete check
    if (isDeleted) return false;

    // 2. Admin Active check
    if (!isActive) return false;

    final s = status.toLowerCase().trim();
    final k = kycStatus.toLowerCase().trim();

    final isExplicitlyApproved = isVerified || s == 'approved' || s == 'active' || k == 'approved';
    final isBlockedOrSuspended = s == 'rejected' ||
        s == 'suspended' ||
        s == 'blocked' ||
        k == 'rejected';

    if (!isExplicitlyApproved || isBlockedOrSuspended) return false;

    // Strict Requirement: Admin Approved + Not Blocked + Available + Verified Paid Subscription + Unexpired
    if (!isAvailable) return false;
    if (!paymentVerified) return false;
    if (!isSubscriptionActive) return false;
    if (subscriptionExpiry == null || subscriptionExpiry!.isBefore(DateTime.now())) return false;

    return true;
  }

  /// Whether provider is strictly eligible for Premium category showcase
  bool get isPremiumApprovedAndLive => isApprovedAndLive && isPremiumEligible;

  // --- SOCIAL & SALON HELPERS ---
  bool get hasInstagram => instagramUrl.trim().isNotEmpty;
  bool get hasFacebook => facebookUrl.trim().isNotEmpty;
  bool get hasWebsite => websiteUrl.trim().isNotEmpty;

  /// Returns clean Instagram launch URL
  String get instagramLaunchUrl {
    final raw = instagramUrl.trim();
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    final cleanHandle = raw.replaceAll('@', '').trim();
    return 'https://instagram.com/$cleanHandle';
  }

  /// Returns display handle e.g. @stylestudio.salon
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

  /// Returns clean Facebook launch URL
  String get facebookLaunchUrl {
    final raw = facebookUrl.trim();
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return 'https://facebook.com/$raw';
  }

  /// Returns clean Website launch URL
  String get websiteLaunchUrl {
    final raw = websiteUrl.trim();
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return 'https://$raw';
  }

  /// Canonical category title with fallback resolution from ID or default neutral title
  String get resolvedCategoryTitle {
    final title = categoryTitle.trim();
    if (title.isNotEmpty) return title;
    final id = categoryId.trim();
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

  /// Checks if business is Unisex Salon category
  bool get isUnisexSalon {
    final catId = categoryId.toLowerCase().trim();
    final catTitle = categoryTitle.toLowerCase().trim();
    return catId == 'unisex_salon' ||
        catId == 'salon' ||
        catTitle.contains('unisex salon') ||
        catTitle.contains('यूनिसेक्स');
  }

  @override
  List<Object?> get props => [
        id,
        fullName,
        businessName,
        phoneNumber,
        categoryId,
        categoryTitle,
        selectedCategoryIds,
        visitingCharge,
        experienceYears,
        jamuiArea,
        fullAddress,
        latitude,
        longitude,
        serviceRadiusKm,
        profileImageUrl,
        businessImageUrl,
        businessDescription,
        workingHours,
        rating,
        ratingCount,
        isAvailable,
        isVerified,
        hasExperienceCertificate,
        experienceCertificateStatus,
        status,
        kycStatus,
        isSubscriptionActive,
        paymentVerified,
        subscriptionExpiry,
        subServices,
        distanceKm,
        isActive,
        isDeleted,
        totalViews,
        totalCalls,
        totalWhatsAppClicks,
        subscriptionPlan,
        isPremiumEligible,
        galleryImages,
        servicesWithPricing,
        instagramUrl,
        facebookUrl,
        websiteUrl,
      ];
}
