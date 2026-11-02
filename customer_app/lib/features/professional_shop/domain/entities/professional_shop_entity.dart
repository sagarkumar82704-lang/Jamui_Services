import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:apna_jamui_customer/core/utils/jamui_geo_validator.dart';
import 'package:apna_jamui_customer/core/utils/jamui_time_utils.dart';

class ProfessionalShopEntity extends Equatable {
  final String id;
  final String ownerUid;
  final String ownerPhone;
  final String ownerEmail;
  final String shopName;
  final String demandCategoryId;
  final String demandCategoryTitle;
  final String logoUrl;
  final String bannerUrl;
  final String description;
  final String fullAddress;
  final String jamuiArea;
  final String areaId;
  final String districtId;
  final double latitude;
  final double longitude;
  final double? serviceRadiusKm;
  final String contactPhone;
  final String whatsAppNumber;
  final bool isHomeDeliveryActive;
  final bool isPickupActive;
  final double minOrderAmount;
  final double deliveryCharges;
  final double freeDeliveryThreshold;
  final int estimatedDeliveryTimeMinutes;
  final String pickupInstructions;
  final bool isOpen;
  final String openingTime;
  final String closingTime;
  final Map<String, dynamic>? weeklySchedule;
  final String status;
  final bool isVerified;
  final bool isActive;
  final bool isDeleted;
  final bool isSubscriptionActive;
  final DateTime? subscriptionExpiresAt;
  final double rating;
  final int ratingCount;
  final int totalOrders;
  final int totalProductsCount;
  final double? distanceKm;

  const ProfessionalShopEntity({
    required this.id,
    this.ownerUid = '',
    this.ownerPhone = '',
    this.ownerEmail = '',
    required this.shopName,
    this.demandCategoryId = '',
    this.demandCategoryTitle = '',
    this.logoUrl = '',
    this.bannerUrl = '',
    this.description = '',
    this.fullAddress = '',
    this.jamuiArea = '',
    this.areaId = '',
    this.districtId = '',
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.serviceRadiusKm,
    this.contactPhone = '',
    this.whatsAppNumber = '',
    this.isHomeDeliveryActive = false,
    this.isPickupActive = false,
    this.minOrderAmount = 0.0,
    this.deliveryCharges = 0.0,
    this.freeDeliveryThreshold = 0.0,
    this.estimatedDeliveryTimeMinutes = 30,
    this.pickupInstructions = '',
    this.isOpen = true,
    this.openingTime = '08:00 AM',
    this.closingTime = '09:00 PM',
    this.weeklySchedule,
    this.status = 'approved',
    this.isVerified = true,
    this.isActive = false,
    this.isDeleted = false,
    this.isSubscriptionActive = false,
    this.subscriptionExpiresAt,
    this.rating = 0.0,
    this.ratingCount = 0,
    this.totalOrders = 0,
    this.totalProductsCount = 0,
    this.distanceKm,
  });

  /// Backward-compatible alias for subscription expiration timestamp.
  DateTime? get subscriptionExpiry => subscriptionExpiresAt;

  /// Validates coordinates against precision sentinel (0,0) and boundaries.
  bool get hasValidLocation => JamuiGeoValidator.isValidCoordinates(latitude, longitude);

  /// Validates real-time subscription status against dynamic timestamp.
  bool get isSubscriptionValid =>
      isSubscriptionActive &&
      subscriptionExpiresAt != null &&
      subscriptionExpiresAt!.isAfter(DateTime.now());

  /// Comprehensive approval, active, non-deleted and subscription live gate.
  bool get isApprovedAndLive =>
      !isDeleted &&
      isActive &&
      status.toLowerCase() == 'approved' &&
      status.toLowerCase() != 'suspended' &&
      status.toLowerCase() != 'blocked' &&
      isSubscriptionActive &&
      (subscriptionExpiresAt == null || subscriptionExpiresAt!.isAfter(DateTime.now()));

  /// Evaluates Store Pickup eligibility (independent of delivery radius).
  bool get isPickupEligible => isPickupActive;

  /// Evaluates Home Delivery eligibility for a given verified distance.
  bool isDeliveryEligibleForDistance(double? distance) {
    if (!hasValidLocation) return false;
    if (!isHomeDeliveryActive) return false;
    if (serviceRadiusKm == null) return false;
    if (distance == null) return false;
    return distance <= serviceRadiusKm!;
  }

  /// Evaluates whether the shop is open right now in Asia/Kolkata timezone.
  bool isOpenNowAt([DateTime? nowIST]) {
    return JamuiTimeUtils.isOpenNow(
      isMasterOpen: isOpen,
      weeklySchedule: weeklySchedule,
      legacyOpeningTime: openingTime,
      legacyClosingTime: closingTime,
      currentTimeIST: nowIST,
    );
  }

  factory ProfessionalShopEntity.fromMap(Map<String, dynamic> map, String id) {
    // 1. Parse Subscription Expiry Timestamp (supporting Timestamp, DateTime, String)
    DateTime? expiry;
    final rawExpiry = map['subscriptionExpiresAt'] ?? map['subscriptionExpiry'] ?? map['planExpiryDate'];
    if (rawExpiry is Timestamp) {
      expiry = rawExpiry.toDate();
    } else if (rawExpiry is DateTime) {
      expiry = rawExpiry;
    } else if (rawExpiry is String) {
      expiry = DateTime.tryParse(rawExpiry);
    }

    // 2. Parse Fail-Closed Service Radius (must be a positive finite number > 0)
    final rawRadius = map['serviceRadiusKm'] ?? map['deliveryRadiusKm'];
    double? parsedRadius;
    if (rawRadius is num && rawRadius > 0 && rawRadius.isFinite && !rawRadius.isNaN) {
      parsedRadius = rawRadius.toDouble().clamp(0.1, 25.0);
    }

    // 3. Parse Weekly Schedule
    Map<String, dynamic>? parsedSchedule;
    final rawSchedule = map['weeklySchedule'];
    if (rawSchedule is Map<String, dynamic>) {
      parsedSchedule = rawSchedule;
    } else if (rawSchedule is Map) {
      parsedSchedule = Map<String, dynamic>.from(rawSchedule);
    }

    return ProfessionalShopEntity(
      id: id,
      ownerUid: (map['ownerUid'] as String?) ?? id,
      ownerPhone: (map['ownerPhone'] as String?) ?? (map['phone'] as String?) ?? '',
      ownerEmail: (map['ownerEmail'] as String?) ?? '',
      shopName: (map['shopName'] as String?) ?? (map['name'] as String?) ?? (map['businessName'] as String?) ?? 'Professional Shop',
      demandCategoryId: (map['demandCategoryId'] as String?) ?? (map['categoryId'] as String?) ?? '',
      demandCategoryTitle: (map['demandCategoryTitle'] as String?) ?? (map['categoryTitle'] as String?) ?? '',
      logoUrl: (map['logoUrl'] as String?) ?? (map['profileImageUrl'] as String?) ?? '',
      bannerUrl: (map['bannerUrl'] as String?) ?? (map['businessImageUrl'] as String?) ?? '',
      description: (map['description'] as String?) ?? (map['businessDescription'] as String?) ?? '',
      fullAddress: (map['fullAddress'] as String?) ?? (map['address'] as String?) ?? '',
      jamuiArea: (map['jamuiArea'] as String?) ?? (map['area'] as String?) ?? '',
      areaId: (map['areaId'] as String?) ?? '',
      districtId: (map['districtId'] as String?) ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      serviceRadiusKm: parsedRadius,
      contactPhone: (map['contactPhone'] as String?) ?? (map['phone'] as String?) ?? '',
      whatsAppNumber: (map['whatsAppNumber'] as String?) ?? (map['whatsapp'] as String?) ?? '',
      isHomeDeliveryActive: (map['isHomeDeliveryActive'] as bool?) ?? false,
      isPickupActive: (map['isPickupActive'] as bool?) ?? (map['pickupEnabled'] as bool?) ?? false,
      minOrderAmount: (map['minOrderAmount'] as num?)?.toDouble() ?? 0.0,
      deliveryCharges: (map['deliveryCharges'] as num?)?.toDouble() ?? 0.0,
      freeDeliveryThreshold: (map['freeDeliveryThreshold'] as num?)?.toDouble() ?? 0.0,
      estimatedDeliveryTimeMinutes: (map['estimatedDeliveryTimeMinutes'] as num?)?.toInt() ?? 30,
      pickupInstructions: (map['pickupInstructions'] as String?) ?? '',
      isOpen: (map['isOpen'] as bool?) ?? (map['isAvailable'] as bool?) ?? true,
      openingTime: (map['openingTime'] as String?) ?? '08:00 AM',
      closingTime: (map['closingTime'] as String?) ?? '09:00 PM',
      weeklySchedule: parsedSchedule,
      status: (map['status'] as String?) ?? 'pending',
      isVerified: (map['isVerified'] as bool?) ?? false,
      isActive: (map['isActive'] as bool?) ?? false,
      isDeleted: (map['isDeleted'] as bool?) ?? false,
      isSubscriptionActive: (map['isSubscriptionActive'] as bool?) ?? false,
      subscriptionExpiresAt: expiry,
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      ratingCount: (map['ratingCount'] as num?)?.toInt() ?? 0,
      totalOrders: (map['totalOrders'] as num?)?.toInt() ?? 0,
      totalProductsCount: (map['totalProductsCount'] as num?)?.toInt() ?? 0,
      distanceKm: (map['distanceKm'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerUid': ownerUid,
      'ownerPhone': ownerPhone,
      'ownerEmail': ownerEmail,
      'shopName': shopName,
      'demandCategoryId': demandCategoryId,
      'demandCategoryTitle': demandCategoryTitle,
      'logoUrl': logoUrl,
      'bannerUrl': bannerUrl,
      'description': description,
      'fullAddress': fullAddress,
      'jamuiArea': jamuiArea,
      'areaId': areaId,
      'districtId': districtId,
      'latitude': latitude,
      'longitude': longitude,
      'serviceRadiusKm': serviceRadiusKm,
      'contactPhone': contactPhone,
      'whatsAppNumber': whatsAppNumber,
      'isHomeDeliveryActive': isHomeDeliveryActive,
      'isPickupActive': isPickupActive,
      'minOrderAmount': minOrderAmount,
      'deliveryCharges': deliveryCharges,
      'freeDeliveryThreshold': freeDeliveryThreshold,
      'estimatedDeliveryTimeMinutes': estimatedDeliveryTimeMinutes,
      'pickupInstructions': pickupInstructions,
      'isOpen': isOpen,
      'openingTime': openingTime,
      'closingTime': closingTime,
      'weeklySchedule': weeklySchedule,
      'status': status,
      'isVerified': isVerified,
      'isActive': isActive,
      'isDeleted': isDeleted,
      'isSubscriptionActive': isSubscriptionActive,
      'subscriptionExpiresAt': subscriptionExpiresAt != null ? Timestamp.fromDate(subscriptionExpiresAt!) : null,
      'rating': rating,
      'ratingCount': ratingCount,
      'totalOrders': totalOrders,
      'totalProductsCount': totalProductsCount,
    };
  }

  ProfessionalShopEntity copyWith({
    String? id,
    String? ownerUid,
    String? ownerPhone,
    String? ownerEmail,
    String? shopName,
    String? demandCategoryId,
    String? demandCategoryTitle,
    String? logoUrl,
    String? bannerUrl,
    String? description,
    String? fullAddress,
    String? jamuiArea,
    String? areaId,
    String? districtId,
    double? latitude,
    double? longitude,
    double? serviceRadiusKm,
    String? contactPhone,
    String? whatsAppNumber,
    bool? isHomeDeliveryActive,
    bool? isPickupActive,
    double? minOrderAmount,
    double? deliveryCharges,
    double? freeDeliveryThreshold,
    int? estimatedDeliveryTimeMinutes,
    String? pickupInstructions,
    bool? isOpen,
    String? openingTime,
    String? closingTime,
    Map<String, dynamic>? weeklySchedule,
    String? status,
    bool? isVerified,
    bool? isActive,
    bool? isDeleted,
    bool? isSubscriptionActive,
    DateTime? subscriptionExpiresAt,
    double? rating,
    int? ratingCount,
    int? totalOrders,
    int? totalProductsCount,
    double? distanceKm,
  }) {
    return ProfessionalShopEntity(
      id: id ?? this.id,
      ownerUid: ownerUid ?? this.ownerUid,
      ownerPhone: ownerPhone ?? this.ownerPhone,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      shopName: shopName ?? this.shopName,
      demandCategoryId: demandCategoryId ?? this.demandCategoryId,
      demandCategoryTitle: demandCategoryTitle ?? this.demandCategoryTitle,
      logoUrl: logoUrl ?? this.logoUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      description: description ?? this.description,
      fullAddress: fullAddress ?? this.fullAddress,
      jamuiArea: jamuiArea ?? this.jamuiArea,
      areaId: areaId ?? this.areaId,
      districtId: districtId ?? this.districtId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      serviceRadiusKm: serviceRadiusKm ?? this.serviceRadiusKm,
      contactPhone: contactPhone ?? this.contactPhone,
      whatsAppNumber: whatsAppNumber ?? this.whatsAppNumber,
      isHomeDeliveryActive: isHomeDeliveryActive ?? this.isHomeDeliveryActive,
      isPickupActive: isPickupActive ?? this.isPickupActive,
      minOrderAmount: minOrderAmount ?? this.minOrderAmount,
      deliveryCharges: deliveryCharges ?? this.deliveryCharges,
      freeDeliveryThreshold: freeDeliveryThreshold ?? this.freeDeliveryThreshold,
      estimatedDeliveryTimeMinutes: estimatedDeliveryTimeMinutes ?? this.estimatedDeliveryTimeMinutes,
      pickupInstructions: pickupInstructions ?? this.pickupInstructions,
      isOpen: isOpen ?? this.isOpen,
      openingTime: openingTime ?? this.openingTime,
      closingTime: closingTime ?? this.closingTime,
      weeklySchedule: weeklySchedule ?? this.weeklySchedule,
      status: status ?? this.status,
      isVerified: isVerified ?? this.isVerified,
      isActive: isActive ?? this.isActive,
      isDeleted: isDeleted ?? this.isDeleted,
      isSubscriptionActive: isSubscriptionActive ?? this.isSubscriptionActive,
      subscriptionExpiresAt: subscriptionExpiresAt ?? this.subscriptionExpiresAt,
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
      totalOrders: totalOrders ?? this.totalOrders,
      totalProductsCount: totalProductsCount ?? this.totalProductsCount,
      distanceKm: distanceKm ?? this.distanceKm,
    );
  }

  @override
  List<Object?> get props => [
        id,
        ownerUid,
        ownerPhone,
        ownerEmail,
        shopName,
        demandCategoryId,
        demandCategoryTitle,
        logoUrl,
        bannerUrl,
        description,
        fullAddress,
        jamuiArea,
        areaId,
        districtId,
        latitude,
        longitude,
        serviceRadiusKm,
        contactPhone,
        whatsAppNumber,
        isHomeDeliveryActive,
        isPickupActive,
        minOrderAmount,
        deliveryCharges,
        freeDeliveryThreshold,
        estimatedDeliveryTimeMinutes,
        pickupInstructions,
        isOpen,
        openingTime,
        closingTime,
        weeklySchedule,
        status,
        isVerified,
        isActive,
        isDeleted,
        isSubscriptionActive,
        subscriptionExpiresAt,
        rating,
        ratingCount,
        totalOrders,
        totalProductsCount,
        distanceKm,
      ];
}
