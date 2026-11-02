import 'package:equatable/equatable.dart';

class SubscriptionPlan extends Equatable {
  final String id;
  final String name;
  final double price;
  final int durationDays;
  final List<String> features;
  final bool isPopular;
  final int categoryLimit;
  final String targetAudience; // 'new_provider' or 'existing_provider'
  final double discountPercentage;
  final String offerDescription;
  final int gracePeriodDays;
  final bool isPaymentMandatory;
  final int maxActiveListings;
  final int maxImagesPerProvider;
  final int maxImagesPerListing;
  final double maxSizePerImageMb;
  final double maxTotalStorageMb;
  final bool isPremiumCategoryEligible;
  final String planTier; // 'normal' or 'premium'

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.durationDays,
    required this.features,
    this.isPopular = false,
    this.categoryLimit = 1,
    this.targetAudience = 'new_provider',
    this.discountPercentage = 0.0,
    this.offerDescription = '',
    this.gracePeriodDays = 0,
    this.isPaymentMandatory = true,
    this.maxActiveListings = 1,
    this.maxImagesPerProvider = 3,
    this.maxImagesPerListing = 2,
    this.maxSizePerImageMb = 2.0,
    this.maxTotalStorageMb = 6.0,
    this.isPremiumCategoryEligible = false,
    this.planTier = 'normal',
  });

  @override
  List<Object?> get props => [
        id,
        name,
        price,
        durationDays,
        features,
        isPopular,
        categoryLimit,
        targetAudience,
        discountPercentage,
        offerDescription,
        gracePeriodDays,
        isPaymentMandatory,
        maxActiveListings,
        maxImagesPerProvider,
        maxImagesPerListing,
        maxSizePerImageMb,
        maxTotalStorageMb,
        isPremiumCategoryEligible,
        planTier,
      ];
}
