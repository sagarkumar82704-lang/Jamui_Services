import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class ProfessionalShopProfileEntity extends Equatable {
  final String id; // Matches provider auth UID
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
  final double latitude;
  final double longitude;
  final double serviceRadiusKm;
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
  final String status;
  final bool isApproved;
  final bool isVerified;
  final bool isActive;
  final bool isDeleted;
  final bool isSubscriptionActive;
  final DateTime? subscriptionExpiry;
  final String subscriptionPlanName;
  final int maxProductsLimit;
  final int imageLimit;
  final int storageLimitMb;
  final int subscriptionDurationDays;
  final bool paymentVerified;
  final String subscriptionPlanId;
  final double rating;
  final int ratingCount;
  final int totalOrders;
  final double todaySales;
  final int todayOrdersCount;
  final int newOrdersCount;
  final double netEarnings;

  const ProfessionalShopProfileEntity({
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
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.serviceRadiusKm = 5.0,
    this.contactPhone = '',
    this.whatsAppNumber = '',
    this.isHomeDeliveryActive = true,
    this.isPickupActive = true,
    this.minOrderAmount = 0.0,
    this.deliveryCharges = 0.0,
    this.freeDeliveryThreshold = 0.0,
    this.estimatedDeliveryTimeMinutes = 30,
    this.pickupInstructions = '',
    this.isOpen = true,
    this.openingTime = '08:00 AM',
    this.closingTime = '09:00 PM',
    this.status = 'approved',
    this.isApproved = true,
    this.isVerified = true,
    this.isActive = true,
    this.isDeleted = false,
    this.isSubscriptionActive = true,
    this.subscriptionExpiry,
    this.subscriptionPlanName = 'Standard Plan',
    this.maxProductsLimit = 100,
    this.imageLimit = 100,
    this.storageLimitMb = 500,
    this.subscriptionDurationDays = 30,
    this.paymentVerified = false,
    this.subscriptionPlanId = '',
    this.rating = 0.0,
    this.ratingCount = 0,
    this.totalOrders = 0,
    this.todaySales = 0.0,
    this.todayOrdersCount = 0,
    this.newOrdersCount = 0,
    this.netEarnings = 0.0,
  });

  factory ProfessionalShopProfileEntity.fromMap(Map<String, dynamic> map, String id) {
    DateTime? expiry;
    final rawExpiry = map['subscriptionExpiry'];
    if (rawExpiry is Timestamp) {
      expiry = rawExpiry.toDate();
    } else if (rawExpiry is String) {
      expiry = DateTime.tryParse(rawExpiry);
    }

    return ProfessionalShopProfileEntity(
      id: id,
      ownerUid: map['ownerUid'] as String? ?? id,
      ownerPhone: map['ownerPhone'] as String? ?? '',
      ownerEmail: map['ownerEmail'] as String? ?? '',
      shopName: map['shopName'] as String? ?? '',
      demandCategoryId: map['demandCategoryId'] as String? ?? map['categoryId'] as String? ?? '',
      demandCategoryTitle: map['demandCategoryTitle'] as String? ?? map['categoryTitle'] as String? ?? '',
      logoUrl: map['logoUrl'] as String? ?? '',
      bannerUrl: map['bannerUrl'] as String? ?? '',
      description: map['description'] as String? ?? '',
      fullAddress: map['fullAddress'] as String? ?? map['address'] as String? ?? '',
      jamuiArea: map['jamuiArea'] as String? ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      serviceRadiusKm: (map['serviceRadiusKm'] as num?)?.toDouble() ?? 5.0,
      contactPhone: map['contactPhone'] as String? ?? '',
      whatsAppNumber: map['whatsAppNumber'] as String? ?? '',
      isHomeDeliveryActive: map['isHomeDeliveryActive'] as bool? ?? true,
      isPickupActive: map['isPickupActive'] as bool? ?? true,
      minOrderAmount: (map['minOrderAmount'] as num?)?.toDouble() ?? 0.0,
      deliveryCharges: (map['deliveryCharges'] as num?)?.toDouble() ?? 0.0,
      freeDeliveryThreshold: (map['freeDeliveryThreshold'] as num?)?.toDouble() ?? 0.0,
      estimatedDeliveryTimeMinutes: (map['estimatedDeliveryTimeMinutes'] as num?)?.toInt() ?? 30,
      pickupInstructions: map['pickupInstructions'] as String? ?? '',
      isOpen: map['isOpen'] as bool? ?? true,
      openingTime: map['openingTime'] as String? ?? '08:00 AM',
      closingTime: map['closingTime'] as String? ?? '09:00 PM',
      status: map['status'] as String? ?? 'pending',
      isApproved: (map['isApproved'] as bool?) ?? ((map['status'] as String?)?.toLowerCase() == 'approved'),
      isVerified: map['isVerified'] as bool? ?? false,
      isActive: map['isActive'] as bool? ?? false,
      isDeleted: map['isDeleted'] as bool? ?? false,
      isSubscriptionActive: map['isSubscriptionActive'] as bool? ?? false,
      subscriptionExpiry: expiry,
      subscriptionPlanName: map['subscriptionPlanName'] as String? ?? 'Free Plan',
      maxProductsLimit: (map['maxProductsLimit'] as num?)?.toInt() ??
          (map['productLimit'] as num?)?.toInt() ??
          (map['maxProducts'] as num?)?.toInt() ??
          100,
      imageLimit: (map['imageLimit'] as num?)?.toInt() ??
          (map['maxImagesPerMonth'] as num?)?.toInt() ??
          100,
      storageLimitMb: (map['storageLimitMb'] as num?)?.toInt() ??
          (map['storageMb'] as num?)?.toInt() ??
          500,
      subscriptionDurationDays: (map['subscriptionDurationDays'] as num?)?.toInt() ??
          (map['durationDays'] as num?)?.toInt() ??
          30,
      paymentVerified: map['paymentVerified'] as bool? ?? false,
      subscriptionPlanId: map['subscriptionPlanId'] as String? ??
          map['planId'] as String? ??
          '',
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      ratingCount: (map['ratingCount'] as num?)?.toInt() ?? 0,
      totalOrders: (map['totalOrders'] as num?)?.toInt() ?? 0,
      todaySales: (map['todaySales'] as num?)?.toDouble() ?? 0.0,
      todayOrdersCount: (map['todayOrdersCount'] as num?)?.toInt() ?? 0,
      newOrdersCount: (map['newOrdersCount'] as num?)?.toInt() ?? 0,
      netEarnings: (map['netEarnings'] as num?)?.toDouble() ?? 0.0,
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
      'status': status,
      'isApproved': isApproved,
      'isVerified': isVerified,
      'isActive': isActive,
      'isDeleted': isDeleted,
      'isSubscriptionActive': isSubscriptionActive,
      'subscriptionExpiry': subscriptionExpiry != null ? Timestamp.fromDate(subscriptionExpiry!) : null,
      'subscriptionPlanName': subscriptionPlanName,
      'maxProductsLimit': maxProductsLimit,
      'imageLimit': imageLimit,
      'storageLimitMb': storageLimitMb,
      'subscriptionDurationDays': subscriptionDurationDays,
      'paymentVerified': paymentVerified,
      'subscriptionPlanId': subscriptionPlanId,
      'rating': rating,
      'ratingCount': ratingCount,
      'totalOrders': totalOrders,
      'todaySales': todaySales,
      'todayOrdersCount': todayOrdersCount,
      'newOrdersCount': newOrdersCount,
      'netEarnings': netEarnings,
    };
  }

  ProfessionalShopProfileEntity copyWith({
    String? shopName,
    String? demandCategoryId,
    String? demandCategoryTitle,
    String? logoUrl,
    String? bannerUrl,
    String? description,
    String? fullAddress,
    String? jamuiArea,
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
    String? status,
    bool? isApproved,
    bool? isVerified,
    bool? isActive,
    bool? isDeleted,
    bool? isSubscriptionActive,
    DateTime? subscriptionExpiry,
    String? subscriptionPlanName,
    int? maxProductsLimit,
    int? imageLimit,
    int? storageLimitMb,
    int? subscriptionDurationDays,
    bool? paymentVerified,
    String? subscriptionPlanId,
    double? rating,
    int? ratingCount,
    int? totalOrders,
    double? todaySales,
    int? todayOrdersCount,
    int? newOrdersCount,
    double? netEarnings,
  }) {
    return ProfessionalShopProfileEntity(
      id: id,
      ownerUid: ownerUid,
      ownerPhone: ownerPhone,
      ownerEmail: ownerEmail,
      shopName: shopName ?? this.shopName,
      demandCategoryId: demandCategoryId ?? this.demandCategoryId,
      demandCategoryTitle: demandCategoryTitle ?? this.demandCategoryTitle,
      logoUrl: logoUrl ?? this.logoUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      description: description ?? this.description,
      fullAddress: fullAddress ?? this.fullAddress,
      jamuiArea: jamuiArea ?? this.jamuiArea,
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
      status: status ?? this.status,
      isApproved: isApproved ?? this.isApproved,
      isVerified: isVerified ?? this.isVerified,
      isActive: isActive ?? this.isActive,
      isDeleted: isDeleted ?? this.isDeleted,
      isSubscriptionActive: isSubscriptionActive ?? this.isSubscriptionActive,
      subscriptionExpiry: subscriptionExpiry ?? this.subscriptionExpiry,
      subscriptionPlanName: subscriptionPlanName ?? this.subscriptionPlanName,
      maxProductsLimit: maxProductsLimit ?? this.maxProductsLimit,
      imageLimit: imageLimit ?? this.imageLimit,
      storageLimitMb: storageLimitMb ?? this.storageLimitMb,
      subscriptionDurationDays: subscriptionDurationDays ?? this.subscriptionDurationDays,
      paymentVerified: paymentVerified ?? this.paymentVerified,
      subscriptionPlanId: subscriptionPlanId ?? this.subscriptionPlanId,
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
      totalOrders: totalOrders ?? this.totalOrders,
      todaySales: todaySales ?? this.todaySales,
      todayOrdersCount: todayOrdersCount ?? this.todayOrdersCount,
      newOrdersCount: newOrdersCount ?? this.newOrdersCount,
      netEarnings: netEarnings ?? this.netEarnings,
    );
  }

  @override
  List<Object?> get props => [
        id,
        ownerUid,
        shopName,
        demandCategoryId,
        status,
        isApproved,
        isActive,
        isSubscriptionActive,
        subscriptionPlanId,
        paymentVerified,
        isOpen,
      ];
}

