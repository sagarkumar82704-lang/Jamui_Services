import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_network_or_base64_image.dart';
import '../../domain/entities/professional_shop_entity.dart';
import '../pages/professional_shop_details_page.dart';

/// Clean, production vendor card for Jamui Services Professional (Pro) Marketplace.
///
/// Enforces:
/// 1. Real verified distance chip when GPS is valid; locality text badge fallback when distance is null (Never 0.0 km).
/// 2. Real-time Open Now chip evaluated in Asia/Kolkata timezone.
/// 3. Accurate fulfillment chips (Delivery & Pickup, Store Pickup Only, Home Delivery Only).
/// 4. Zero fake ratings: stars appear only if ratingCount > 0 and rating > 0.0.
/// 5. Network/Base64 image loading with graceful fallback.
class ProfessionalShopCard extends StatelessWidget {
  final ProfessionalShopEntity shop;
  final VoidCallback? onTap;

  const ProfessionalShopCard({
    super.key,
    required this.shop,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isOpenNow = shop.isOpenNowAt();
    final hasVerifiedDistance = shop.distanceKm != null;
    final hasRatings = shop.rating > 0.0 && shop.ratingCount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap ??
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfessionalShopDetailsPage(shop: shop),
                  ),
                );
              },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Shop Logo / Banner Image with Graceful Fallback
                _buildShopImage(),
                const SizedBox(width: 14),

                // Shop Metadata & Chips
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Shop Title + Verified Icon
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              shop.shopName,
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (shop.isVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified_rounded,
                              color: Color(0xFF10B981),
                              size: 16,
                            ),
                          ],
                        ],
                      ),
                      if (shop.demandCategoryTitle.isNotEmpty || shop.demandCategoryId.isNotEmpty || (hasVerifiedDistance && shop.jamuiArea.isNotEmpty)) ...[
                        const SizedBox(height: 3),
                        Text(
                          [
                            if (shop.demandCategoryTitle.isNotEmpty)
                              shop.demandCategoryTitle
                            else if (shop.demandCategoryId.isNotEmpty)
                              shop.demandCategoryId,
                            if (shop.jamuiArea.isNotEmpty && hasVerifiedDistance)
                              shop.jamuiArea,
                          ].join(' • '),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 5),

                      // Location / Distance & Rating Row
                      Row(
                        children: [
                          // Distance or Locality Badge (Never 0.0 km)
                          _buildDistanceOrLocalityBadge(hasVerifiedDistance),

                          if (hasRatings) ...[
                            const SizedBox(width: 8),
                            _buildRatingBadge(),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Fulfillment Badges Row
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _buildFulfillmentBadge(),
                          _buildOpenStatusBadge(isOpenNow),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Min Order & Delivery Cost Footer
                      _buildPricingFooter(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShopImage() {
    final imageUrl = shop.logoUrl.isNotEmpty ? shop.logoUrl : shop.bannerUrl;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 88,
        height: 88,
        child: AppNetworkOrBase64Image(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          width: 88,
          height: 88,
          errorBuilder: (context, error, stackTrace) => Container(
            color: const Color(0xFFE8F5E9),
            child: const Center(
              child: Icon(
                Icons.storefront_rounded,
                color: AppColors.primary,
                size: 38,
              ),
            ),
          ),
          placeholder: (context, url) => Container(
            color: const Color(0xFFF1F5F9),
          ),
        ),
      ),
    );
  }

  Widget _buildDistanceOrLocalityBadge(bool hasVerifiedDistance) {
    final badgeText = hasVerifiedDistance
        ? '${shop.distanceKm!.toStringAsFixed(1)} km'
        : (shop.jamuiArea.isNotEmpty ? shop.jamuiArea : 'Jamui, Bihar');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.location_on_rounded,
            size: 12,
            color: Color(0xFF64748B),
          ),
          const SizedBox(width: 3),
          Text(
            badgeText,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.star_rounded,
            size: 13,
            color: Color(0xFFD97706),
          ),
          const SizedBox(width: 3),
          Text(
            '${shop.rating.toStringAsFixed(1)} (${shop.ratingCount})',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF92400E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFulfillmentBadge() {
    final hasDistance = shop.distanceKm != null;
    final isDeliveryEligible = shop.isDeliveryEligibleForDistance(shop.distanceKm);
    final isPickupActive = shop.isPickupActive;

    String label;
    Color bgColor;
    Color textColor;

    if (isDeliveryEligible && isPickupActive) {
      label = 'Delivery & Pickup';
      bgColor = const Color(0xFFDCFCE7);
      textColor = const Color(0xFF166534);
    } else if (isDeliveryEligible && !isPickupActive) {
      label = 'Home Delivery Only';
      bgColor = const Color(0xFFE0E7FF);
      textColor = const Color(0xFF3730A3);
    } else if (!isDeliveryEligible && isPickupActive) {
      if (shop.isHomeDeliveryActive && hasDistance) {
        label = 'Store Pickup (Outside Delivery Zone)';
        bgColor = const Color(0xFFFFFBEB);
        textColor = const Color(0xFFB45309);
      } else {
        label = 'Store Pickup Only';
        bgColor = const Color(0xFFE0F2FE);
        textColor = const Color(0xFF0369A1);
      }
    } else {
      label = 'Storefront';
      bgColor = const Color(0xFFF1F5F9);
      textColor = const Color(0xFF64748B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildOpenStatusBadge(bool isOpenNow) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isOpenNow ? const Color(0xFFE8F5E9) : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOpenNow ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            isOpenNow ? 'Open Now' : 'Closed',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: isOpenNow ? const Color(0xFF166534) : const Color(0xFF991B1B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingFooter() {
    final deliveryText = shop.deliveryCharges == 0
        ? 'Free Delivery'
        : 'Delivery ₹${shop.deliveryCharges.toInt()}';

    return Row(
      children: [
        if (shop.isHomeDeliveryActive) ...[
          Text(
            'Min. ₹${shop.minOrderAmount.toInt()}',
            style: const TextStyle(
              fontSize: 11.5,
              color: Color(0xFF64748B),
            ),
          ),
          const Text(' • ', style: TextStyle(color: Color(0xFFCBD5E1))),
          Text(
            deliveryText,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF475569),
            ),
          ),
        ] else ...[
          const Text(
            'Walk-in orders available',
            style: TextStyle(
              fontSize: 11.5,
              color: Color(0xFF64748B),
            ),
          ),
        ],
        const Spacer(),
        Text(
          '${shop.estimatedDeliveryTimeMinutes}m',
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}
