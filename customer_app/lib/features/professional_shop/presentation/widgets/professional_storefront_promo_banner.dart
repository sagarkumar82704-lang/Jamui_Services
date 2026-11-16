import 'package:flutter/material.dart';

import '../../../../core/utils/app_image_url_resolver.dart';
import '../../../../core/widgets/app_network_or_base64_image.dart';
import '../../domain/entities/professional_shop_entity.dart';

/// Reusable full-width landscape promotional banner widget for Professional Mini E-commerce Storefront.
///
/// Features:
/// - 2.4:1 responsive aspect ratio matching the final promotional banner specifications.
/// - Two distinct modes:
///   1. **Image Banner:** Full-bleed landscape marketing creative with rounded corners and high visual fidelity.
///   2. **Text-Only Banner:** Rich golden/green gradient card with styled title, subtitle, and offer badge.
/// - Graceful fallback to Text-Only mode if the remote image fails to load.
/// - Responsive scaling for compact mobile (320-360dp), standard mobile (390-412dp), and desktop/tablets (up to 800dp).
class ProfessionalStorefrontPromoBanner extends StatelessWidget {
  final ShopPromoBannerEntity banner;
  final double freeDeliveryThreshold;
  final bool isHindi;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry margin;
  final double maxWidth;
  final Key? bannerKey;

  static const double bannerAspectRatio = 2.4;
  static const double bannerBorderRadius = 16.0;

  const ProfessionalStorefrontPromoBanner({
    super.key,
    required this.banner,
    this.freeDeliveryThreshold = 0.0,
    this.isHindi = false,
    this.onTap,
    this.margin = const EdgeInsets.fromLTRB(16, 10, 16, 10),
    this.maxWidth = 800.0,
    this.bannerKey,
  });

  String get _effectiveOfferBadge {
    if (banner.offerText.trim().isNotEmpty) {
      return banner.offerText.trim();
    }
    if (freeDeliveryThreshold > 0) {
      return isHindi
          ? '₹${freeDeliveryThreshold.toInt()} के ऊपर मुफ़्त डिलीवरी'
          : 'Free Delivery Above ₹${freeDeliveryThreshold.toInt()}';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final resolvedImg = AppImageUrlResolver.resolve(banner.imageUrl);
    final hasImage = resolvedImg.isNotEmpty;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: margin,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(bannerBorderRadius),
            clipBehavior: Clip.antiAlias,
            elevation: 0,
            child: InkWell(
              key: bannerKey ?? const Key('storefront_real_promo_banner'),
              onTap: onTap,
              borderRadius: BorderRadius.circular(bannerBorderRadius),
              child: AspectRatio(
                aspectRatio: bannerAspectRatio,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(bannerBorderRadius),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(bannerBorderRadius),
                    child: hasImage
                        ? _buildImageBanner(context, resolvedImg)
                        : _buildTextOnlyBanner(context),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Mode 1: Full-width landscape image creative
  Widget _buildImageBanner(BuildContext context, String imageUrl) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background placeholder / canvas
        Container(
          color: const Color(0xFFF3F4F6),
        ),
        // Image with smooth loading and error fallback
        AppNetworkOrBase64Image(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, _, _) => _buildTextOnlyBanner(context),
        ),
      ],
    );
  }

  /// Mode 2: Professional text-only gradient card
  Widget _buildTextOnlyBanner(BuildContext context) {
    final offerBadge = _effectiveOfferBadge;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFEF3C7), // Warm golden amber top-left
            Color(0xFFFDE68A), // Rich sunburst amber
            Color(0xFFDCFCE7), // Soft fresh mint green bottom-right
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: const Color(0xFFFCD34D).withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 360;

          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 14 : 18,
              vertical: isCompact ? 10 : 12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Offer Badge Pill
                if (offerBadge.isNotEmpty) ...[
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 8 : 10,
                      vertical: isCompact ? 3 : 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626), // Urgent / Prominent Red Badge
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.25),
                          blurRadius: 4,
                          offset: const Offset(0, 1.5),
                        ),
                      ],
                    ),
                    child: Text(
                      offerBadge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isCompact ? 9.5 : 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  SizedBox(height: isCompact ? 4 : 6),
                ],

                // Main Promotional Title
                if (banner.title.trim().isNotEmpty)
                  Text(
                    banner.title.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isCompact ? 15 : 18,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF14532D), // Deep Forest Green
                      height: 1.15,
                    ),
                  ),

                // Subtitle
                if (banner.subtitle.trim().isNotEmpty) ...[
                  SizedBox(height: isCompact ? 2 : 4),
                  Text(
                    banner.subtitle.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isCompact ? 11 : 12.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1F2937), // Dark slate
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

