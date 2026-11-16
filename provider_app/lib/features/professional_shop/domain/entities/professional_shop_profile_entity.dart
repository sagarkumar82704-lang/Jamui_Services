import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Promotional Banner Entity for a Professional Seller's Mini E-commerce Store.
/// Stored on `diamond_shops/{shopId}` under `promoBanner`.
class ShopPromoBannerEntity extends Equatable {
  final String imageUrl;
  final String title;
  final String subtitle;
  final String offerText;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;
  final DateTime? updatedAt;

  const ShopPromoBannerEntity({
    this.imageUrl = '',
    this.title = '',
    this.subtitle = '',
    this.offerText = '',
    this.startDate,
    this.endDate,
    this.isActive = false,
    this.updatedAt,
  });

  bool get hasContent =>
      title.trim().isNotEmpty ||
      subtitle.trim().isNotEmpty ||
      offerText.trim().isNotEmpty ||
      imageUrl.trim().isNotEmpty;

  /// Evaluates whether the promotional banner is active and within its scheduled date window.
  bool isCurrentlyLive([DateTime? now]) {
    if (!isActive || !hasContent) return false;
    final checkTime = now ?? DateTime.now();
    if (startDate != null) {
      final startOfDay = DateTime(startDate!.year, startDate!.month, startDate!.day);
      if (checkTime.isBefore(startOfDay)) return false;
    }
    if (endDate != null) {
      final endOfDay = DateTime(endDate!.year, endDate!.month, endDate!.day, 23, 59, 59, 999);
      if (checkTime.isAfter(endOfDay)) return false;
    }
    return true;
  }

  factory ShopPromoBannerEntity.fromMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return const ShopPromoBannerEntity();

    DateTime? parseDate(dynamic raw) {
      if (raw is Timestamp) return raw.toDate();
      if (raw is DateTime) return raw;
      if (raw is String && raw.trim().isNotEmpty) return DateTime.tryParse(raw.trim());
      return null;
    }

    return ShopPromoBannerEntity(
      imageUrl: (map['imageUrl'] as String?)?.trim() ?? '',
      title: (map['title'] as String?)?.trim() ?? '',
      subtitle: (map['subtitle'] as String?)?.trim() ?? '',
      offerText: (map['offerText'] as String?)?.trim() ?? '',
      startDate: parseDate(map['startDate']),
      endDate: parseDate(map['endDate']),
      isActive: (map['isActive'] as bool?) ?? false,
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'imageUrl': imageUrl.trim(),
      'title': title.trim(),
      'subtitle': subtitle.trim(),
      'offerText': offerText.trim(),
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  ShopPromoBannerEntity copyWith({
    String? imageUrl,
    String? title,
    String? subtitle,
    String? offerText,
    DateTime? startDate,
    bool clearStartDate = false,
    DateTime? endDate,
    bool clearEndDate = false,
    bool? isActive,
  }) {
    return ShopPromoBannerEntity(
      imageUrl: imageUrl ?? this.imageUrl,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      offerText: offerText ?? this.offerText,
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      isActive: isActive ?? this.isActive,
      updatedAt: updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        imageUrl,
        title,
        subtitle,
        offerText,
        startDate,
        endDate,
        isActive,
      ];
}

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
  final String landmark;
  final double latitude;
  final double longitude;
  final String locationSource;
  final bool isLocationApproximate;
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
  final Map<String, dynamic>? weeklySchedule;
  final ShopPromoBannerEntity? promoBanner;
  final String status;
  final bool isApproved;
  final bool isVerified;
  final bool isActive;
  final bool isDeleted;
  final bool isSubscriptionActive;
  final DateTime? subscriptionExpiry;
  final String subscriptionPlanName;
  final int maxProductsLimit;
  final int maxVariantsPerProduct;
  final int imageLimit;
  final int storageLimitMb;
  final int subscriptionDurationDays;
  final bool paymentVerified;
  final String subscriptionPlanId;
  final Map<String, dynamic> features;
  final double rating;
  final int ratingCount;
  final int totalOrders;
  final double todaySales;
  final int todayOrdersCount;
  final int newOrdersCount;
  final double netEarnings;
  final String shopCode;
  final int sellerOrderCounter;

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
    this.landmark = '',
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.locationSource = '',
    this.isLocationApproximate = false,
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
    this.weeklySchedule,
    this.promoBanner,
    this.status = 'approved',
    this.isApproved = true,
    this.isVerified = true,
    this.isActive = true,
    this.isDeleted = false,
    this.isSubscriptionActive = true,
    this.subscriptionExpiry,
    this.subscriptionPlanName = 'Standard Plan',
    this.maxProductsLimit = 100,
    this.maxVariantsPerProduct = 5,
    this.imageLimit = 100,
    this.storageLimitMb = 500,
    this.subscriptionDurationDays = 30,
    this.paymentVerified = false,
    this.subscriptionPlanId = '',
    this.features = const {},
    this.rating = 0.0,
    this.ratingCount = 0,
    this.totalOrders = 0,
    this.todaySales = 0.0,
    this.todayOrdersCount = 0,
    this.newOrdersCount = 0,
    this.netEarnings = 0.0,
    this.shopCode = '',
    this.sellerOrderCounter = 0,
  });

  String get shopCategory =>
      demandCategoryTitle.isNotEmpty ? demandCategoryTitle : 'Marketplace Seller';

  factory ProfessionalShopProfileEntity.fromMap(Map<String, dynamic> map, String id) {
    DateTime? expiry;
    final rawExpiry = map['subscriptionExpiry'];
    if (rawExpiry is Timestamp) {
      expiry = rawExpiry.toDate();
    } else if (rawExpiry is String) {
      expiry = DateTime.tryParse(rawExpiry);
    }

    Map<String, dynamic>? parsedSchedule;
    final rawSchedule = map['weeklySchedule'];
    if (rawSchedule is Map<String, dynamic>) {
      parsedSchedule = rawSchedule;
    } else if (rawSchedule is Map) {
      parsedSchedule = Map<String, dynamic>.from(rawSchedule);
    }

    ShopPromoBannerEntity? parsedPromoBanner;
    if (map['promoBanner'] is Map) {
      parsedPromoBanner = ShopPromoBannerEntity.fromMap(
        Map<String, dynamic>.from(map['promoBanner'] as Map),
      );
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
      landmark: map['landmark'] as String? ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      locationSource: map['locationSource'] as String? ?? '',
      isLocationApproximate: map['isLocationApproximate'] as bool? ?? false,
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
      weeklySchedule: parsedSchedule,
      promoBanner: parsedPromoBanner,
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
      maxVariantsPerProduct: (map['maxVariantsPerProduct'] as num?)?.toInt() ??
          (map['variantLimit'] as num?)?.toInt() ??
          (map['maxVariants'] as num?)?.toInt() ??
          5,
      features: map['features'] is Map
          ? Map<String, dynamic>.from(map['features'] as Map)
          : const {},
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
      shopCode: (map['shopCode'] as String?)?.trim() ?? '',
      sellerOrderCounter: (map['sellerOrderCounter'] as num?)?.toInt() ?? 0,
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
      'landmark': landmark,
      'latitude': latitude,
      'longitude': longitude,
      'locationSource': locationSource,
      'isLocationApproximate': isLocationApproximate,
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
      if (weeklySchedule != null) 'weeklySchedule': weeklySchedule,
      if (promoBanner != null) 'promoBanner': promoBanner!.toMap(),
      'status': status,
      'isApproved': isApproved,
      'isVerified': isVerified,
      'isActive': isActive,
      'isDeleted': isDeleted,
      'isSubscriptionActive': isSubscriptionActive,
      'subscriptionExpiry': subscriptionExpiry != null ? Timestamp.fromDate(subscriptionExpiry!) : null,
      'subscriptionPlanName': subscriptionPlanName,
      'maxProductsLimit': maxProductsLimit,
      'maxVariantsPerProduct': maxVariantsPerProduct,
      'features': features,
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
      'shopCode': shopCode,
      'sellerOrderCounter': sellerOrderCounter,
    };
  }

  ProfessionalShopProfileEntity copyWith({
    String? ownerEmail,
    String? shopName,
    String? demandCategoryId,
    String? demandCategoryTitle,
    String? logoUrl,
    String? bannerUrl,
    String? description,
    String? fullAddress,
    String? jamuiArea,
    String? landmark,
    double? latitude,
    double? longitude,
    String? locationSource,
    bool? isLocationApproximate,
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
    ShopPromoBannerEntity? promoBanner,
    bool clearPromoBanner = false,
    String? status,
    bool? isApproved,
    bool? isVerified,
    bool? isActive,
    bool? isDeleted,
    bool? isSubscriptionActive,
    DateTime? subscriptionExpiry,
    String? subscriptionPlanName,
    int? maxProductsLimit,
    int? maxVariantsPerProduct,
    Map<String, dynamic>? features,
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
    String? shopCode,
    int? sellerOrderCounter,
  }) {
    return ProfessionalShopProfileEntity(
      id: id,
      ownerUid: ownerUid,
      ownerPhone: ownerPhone,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      shopName: shopName ?? this.shopName,
      demandCategoryId: demandCategoryId ?? this.demandCategoryId,
      demandCategoryTitle: demandCategoryTitle ?? this.demandCategoryTitle,
      logoUrl: logoUrl ?? this.logoUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      description: description ?? this.description,
      fullAddress: fullAddress ?? this.fullAddress,
      jamuiArea: jamuiArea ?? this.jamuiArea,
      landmark: landmark ?? this.landmark,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationSource: locationSource ?? this.locationSource,
      isLocationApproximate: isLocationApproximate ?? this.isLocationApproximate,
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
      promoBanner: clearPromoBanner ? null : (promoBanner ?? this.promoBanner),
      status: status ?? this.status,
      isApproved: isApproved ?? this.isApproved,
      isVerified: isVerified ?? this.isVerified,
      isActive: isActive ?? this.isActive,
      isDeleted: isDeleted ?? this.isDeleted,
      isSubscriptionActive: isSubscriptionActive ?? this.isSubscriptionActive,
      subscriptionExpiry: subscriptionExpiry ?? this.subscriptionExpiry,
      subscriptionPlanName: subscriptionPlanName ?? this.subscriptionPlanName,
      maxProductsLimit: maxProductsLimit ?? this.maxProductsLimit,
      maxVariantsPerProduct: maxVariantsPerProduct ?? this.maxVariantsPerProduct,
      features: features ?? this.features,
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
      shopCode: shopCode ?? this.shopCode,
      sellerOrderCounter: sellerOrderCounter ?? this.sellerOrderCounter,
    );
  }

  @override
  List<Object?> get props => [
        id,
        ownerUid,
        shopName,
        logoUrl,
        bannerUrl,
        description,
        fullAddress,
        jamuiArea,
        landmark,
        latitude,
        longitude,
        locationSource,
        isLocationApproximate,
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
        openingTime,
        closingTime,
        promoBanner,
        demandCategoryId,
        status,
        isApproved,
        isActive,
        isSubscriptionActive,
        subscriptionPlanId,
        paymentVerified,
        isOpen,
        shopCode,
        sellerOrderCounter,
      ];
}

