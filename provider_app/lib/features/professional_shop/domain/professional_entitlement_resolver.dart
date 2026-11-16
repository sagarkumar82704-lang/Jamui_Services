import 'entities/professional_shop_profile_entity.dart';

/// Resolved entitlements for a Professional Seller based on their active subscription plan
class ProfessionalEntitlements {
  final String planId;
  final String planName;
  final bool isSubscriptionActive;
  final DateTime? subscriptionExpiry;
  final int maxProducts;
  final int maxVariantsPerProduct;
  final int maxImagesPerProduct;
  final int storageLimitMb;
  final bool advancedAnalytics;
  final bool promotionalTools;
  final bool lowStockAlerts;
  final bool customAttributes;

  const ProfessionalEntitlements({
    required this.planId,
    required this.planName,
    required this.isSubscriptionActive,
    this.subscriptionExpiry,
    required this.maxProducts,
    required this.maxVariantsPerProduct,
    required this.maxImagesPerProduct,
    required this.storageLimitMb,
    required this.advancedAnalytics,
    required this.promotionalTools,
    required this.lowStockAlerts,
    required this.customAttributes,
  });

  /// True if the subscription is expired based on current timestamp
  bool get isExpired {
    if (!isSubscriptionActive) return true;
    if (subscriptionExpiry == null) return false;
    return subscriptionExpiry!.isBefore(DateTime.now());
  }

  /// True if the seller has an active, unexpired subscription
  bool get isValid => isSubscriptionActive && !isExpired;

  /// Checks if seller can add a new product given their current product count
  bool canAddProduct(int currentProductCount) {
    if (!isValid) return false;
    return currentProductCount < maxProducts;
  }

  /// Checks if seller can add a new variant given their current variant count
  bool canAddVariant(int currentVariantCount) {
    if (!isValid) return false;
    return currentVariantCount < maxVariantsPerProduct;
  }
}

/// Centralized Entitlement Resolver for Professional Marketplace.
/// Translates shop data and subscription plan into real, enforceable feature entitlements.
class ProfessionalEntitlementResolver {
  // Default limits for fallback / non-subscribed shops
  static const int defaultMaxProducts = 10;
  /// Technical abuse safeguard only (NOT subscription-based).
  static const int technicalMaxVariantsPerProduct = 50;
  static const int defaultMaxImagesPerProduct = 5;
  static const int defaultStorageMb = 100;

  /// Resolves the effective entitlements for a professional shop
  static ProfessionalEntitlements resolve(ProfessionalShopProfileEntity shop) {
    final bool isActive = shop.isSubscriptionActive;
    final DateTime? expiry = shop.subscriptionExpiry;

    // Read plan limits stored on shop document
    final int maxProds = shop.maxProductsLimit > 0
        ? shop.maxProductsLimit
        : defaultMaxProducts;
    // Legacy `maxVariantsPerProduct` on the shop/plan is preserved in data for backward
    // compatibility but is NOT a commercial limit: size/weight/colour/pack options are never
    // restricted by subscription. Only a technical abuse cap applies.
    const int maxVariants = technicalMaxVariantsPerProduct;
    final int maxImages = shop.imageLimit > 0
        ? shop.imageLimit
        : defaultMaxImagesPerProduct;
    final int storageMb = shop.storageLimitMb > 0
        ? shop.storageLimitMb
        : defaultStorageMb;

    // Read feature flags
    final features = shop.features;
    final bool advancedAnalytics = features['advancedAnalytics'] == true;
    final bool promotionalTools = features['promotionalTools'] == true;
    final bool lowStockAlerts = features['lowStockAlerts'] != false;
    final bool customAttributes = features['customAttributes'] != false;

    return ProfessionalEntitlements(
      planId: shop.subscriptionPlanId,
      planName: shop.subscriptionPlanName.isNotEmpty
          ? shop.subscriptionPlanName
          : (isActive ? 'Standard Plan' : 'Free / Inactive Plan'),
      isSubscriptionActive: isActive,
      subscriptionExpiry: expiry,
      maxProducts: maxProds,
      maxVariantsPerProduct: maxVariants,
      maxImagesPerProduct: maxImages,
      storageLimitMb: storageMb,
      advancedAnalytics: advancedAnalytics,
      promotionalTools: promotionalTools,
      lowStockAlerts: lowStockAlerts,
      customAttributes: customAttributes,
    );
  }
}

