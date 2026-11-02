import '../../domain/entities/subscription_plan.dart';

class SubscriptionPlanModel extends SubscriptionPlan {
  const SubscriptionPlanModel({
    required super.id,
    required super.name,
    required super.price,
    required super.durationDays,
    required super.features,
    super.isPopular,
    super.categoryLimit,
    super.targetAudience,
    super.discountPercentage,
    super.offerDescription,
    super.gracePeriodDays,
    super.isPaymentMandatory,
    super.maxActiveListings,
    super.maxImagesPerProvider,
    super.maxImagesPerListing,
    super.maxSizePerImageMb,
    super.maxTotalStorageMb,
    super.isPremiumCategoryEligible,
    super.planTier,
  });

  factory SubscriptionPlanModel.fromMap(Map<String, dynamic> map, String id) {
    final rawName = (map['name'] as String?)?.trim();
    final rawPrice = (map['price'] as num?)?.toDouble();
    final rawDuration = (map['durationDays'] as num?)?.toInt();
    final rawTier = (map['planTier'] as String?)?.trim().toLowerCase();
    final planTier = (rawTier == 'premium') ? 'premium' : 'normal';

    final rawMaxImageBytes = (map['maxSizePerImageBytes'] as num?)?.toDouble();
    final rawMaxStorageBytes = (map['maxTotalStorageBytes'] as num?)?.toDouble();

    final maxImageMb = (map['maxSizePerImageMb'] as num?)?.toDouble() ??
        (rawMaxImageBytes != null ? (rawMaxImageBytes / (1024 * 1024)) : 2.0);

    final maxStorageMb = (map['maxTotalStorageMb'] as num?)?.toDouble() ??
        (rawMaxStorageBytes != null ? (rawMaxStorageBytes / (1024 * 1024)) : 6.0);

    return SubscriptionPlanModel(
      id: id,
      name: (rawName != null && rawName.isNotEmpty) ? rawName : '',
      price: (rawPrice != null && rawPrice > 0) ? rawPrice : 0.0,
      durationDays: (rawDuration != null && rawDuration > 0) ? rawDuration : 0,
      categoryLimit: (map['categoryLimit'] as num?)?.toInt() ?? 1,
      targetAudience: (map['targetAudience'] as String?) ?? 'new_provider',
      discountPercentage: (map['discountPercentage'] as num?)?.toDouble() ?? 0.0,
      offerDescription: (map['offerDescription'] as String?) ?? '',
      gracePeriodDays: (map['gracePeriodDays'] as num?)?.toInt() ?? 0,
      isPaymentMandatory: (map['isPaymentMandatory'] as bool?) ?? true,
      maxActiveListings: (map['maxActiveListings'] as num?)?.toInt() ?? 1,
      maxImagesPerProvider: (map['maxImagesPerProvider'] as num?)?.toInt() ?? 3,
      maxImagesPerListing: (map['maxImagesPerListing'] as num?)?.toInt() ?? 2,
      maxSizePerImageMb: maxImageMb > 0 ? maxImageMb : 2.0,
      maxTotalStorageMb: maxStorageMb > 0 ? maxStorageMb : 6.0,
      isPremiumCategoryEligible: (map['isPremiumCategoryEligible'] as bool?) ?? false,
      features: (map['features'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      isPopular: (map['isPopular'] as bool?) ?? false,
      planTier: planTier,
    );
  }

  /// Check whether the plan has valid positive pricing and duration
  bool get isValid => id.isNotEmpty && name.isNotEmpty && price > 0 && durationDays > 0;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'durationDays': durationDays,
      'categoryLimit': categoryLimit,
      'targetAudience': targetAudience,
      'discountPercentage': discountPercentage,
      'offerDescription': offerDescription,
      'gracePeriodDays': gracePeriodDays,
      'isPaymentMandatory': isPaymentMandatory,
      'maxActiveListings': maxActiveListings,
      'maxImagesPerProvider': maxImagesPerProvider,
      'maxImagesPerListing': maxImagesPerListing,
      'maxSizePerImageMb': maxSizePerImageMb,
      'maxTotalStorageMb': maxTotalStorageMb,
      'isPremiumCategoryEligible': isPremiumCategoryEligible,
      'planTier': planTier,
      'features': features,
      'isPopular': isPopular,
    };
  }
}
