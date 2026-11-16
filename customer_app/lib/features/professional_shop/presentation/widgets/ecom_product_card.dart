import 'package:flutter/material.dart';
import '../../../../core/utils/app_image_url_resolver.dart';
import '../../data/services/shop_favorites_service.dart';
import '../../domain/entities/professional_product_entity.dart';
import '../../domain/entities/professional_shop_entity.dart';
import '../localization/ecom_locale_controller.dart';
import '../localization/ecom_strings.dart';
import '../theme/ecom_theme.dart';

/// Premium, responsive 2-column Product Card matching the reference design:
/// - Rounded borders and soft card shadow
/// - Top-left orange discount badge
/// - Top-right favorite toggle
/// - Cloudflare R2 image via AppImageUrlResolver
/// - Selling price in bold, MRP with strikethrough
/// - Vibrant green '+' Add to Cart button or inline stepper
class EcomProductCard extends StatelessWidget {
  final ProfessionalShopEntity shop;
  final ProfessionalProductEntity product;
  final int cartQuantity;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const EcomProductCard({
    super.key,
    required this.shop,
    required this.product,
    required this.cartQuantity,
    required this.onTap,
    required this.onAddToCart,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final hasGenuineDiscount = product.regularPrice > product.sellingPrice && product.regularPrice > 0;
    final discount = hasGenuineDiscount
        ? (product.discountPercentage > 0
            ? product.discountPercentage.round()
            : (((product.regularPrice - product.sellingPrice) / product.regularPrice) * 100).round())
        : 0;

    return AnimatedBuilder(
      animation: EcomLocaleController.instance,
      builder: (context, _) => _buildCard(context, discount),
    );
  }

  Widget _buildCard(BuildContext context, int discount) {
    final isHindi = EcomLocaleController.instance.isHindi;
    final title = isHindi && product.titleHindi.isNotEmpty
        ? product.titleHindi
        : (product.titleEnglish.isNotEmpty ? product.titleEnglish : product.titleHindi);
    final unitText = EcomStrings.formatUnit(product.unitValue, product.unit);

    return Container(
      decoration: BoxDecoration(
        color: EcomColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: EcomColors.border),
        boxShadow: EcomColors.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Stack: Image + Discount Badge + Favorite Button
              Stack(
                children: [
                  // Product Image Area
                  Container(
                    height: 125,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFBFDFB),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Center(
                      child: product.thumbnailUrl.isNotEmpty
                          ? Image.network(
                              AppImageUrlResolver.resolve(product.thumbnailUrl),
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => _buildFallbackIcon(),
                            )
                          : _buildFallbackIcon(),
                    ),
                  ),

                  // Top Left: Orange Discount Badge
                  if (discount > 0)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: EcomColors.accentOrange,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$discount% OFF',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),

                  // Top Right: Favorite Button
                  Positioned(
                    top: 6,
                    right: 6,
                    child: ValueListenableBuilder<Set<String>>(
                      valueListenable: ShopFavoritesService.instance.getFavoritesNotifier(shop.id),
                      builder: (context, favs, _) {
                        final isFav = favs.contains(product.id);
                        return Material(
                          color: Colors.white.withValues(alpha: 0.85),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () {
                              ShopFavoritesService.instance.toggleFavorite(shop.id, product.id);
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(5.5),
                              child: Icon(
                                isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                size: 17,
                                color: isFav ? const Color(0xFFE53935) : EcomColors.textSecondary,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

              // Bottom Section: Details & Price Action
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Title
                    Text(
                      title.isNotEmpty ? title : 'Product',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: EcomColors.textPrimary,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),

                    // Unit / Pack info
                    Text(
                      unitText,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: EcomColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 8),

                    // Pricing Row & Add to Cart
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Price & MRP
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '₹${product.sellingPrice.toStringAsFixed(product.sellingPrice.truncateToDouble() == product.sellingPrice ? 0 : 2)}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: EcomColors.primary,
                                ),
                              ),
                              if (product.regularPrice > product.sellingPrice)
                                Text(
                                  '₹${product.regularPrice.toStringAsFixed(product.regularPrice.truncateToDouble() == product.regularPrice ? 0 : 2)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: EcomColors.textSecondary.withValues(alpha: 0.8),
                                    decoration: TextDecoration.lineThrough,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Action: Add Button OR Quantity Stepper
                        if (!product.inStock)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              EcomStrings.outOfStock,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF94A3B8),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        else if (cartQuantity <= 0)
                          Material(
                            color: EcomColors.primary,
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: onAddToCart,
                              child: Container(
                                width: 34,
                                height: 34,
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.add_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              color: EcomColors.softGreen,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: EcomColors.primary.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: onDecrement,
                                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                    child: Icon(Icons.remove_rounded, size: 16, color: EcomColors.primary),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 5),
                                  child: Text(
                                    '$cartQuantity',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                      color: EcomColors.primary,
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: onIncrement,
                                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                    child: Icon(Icons.add_rounded, size: 16, color: EcomColors.primary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackIcon() {
    return const Icon(
      Icons.inventory_2_outlined,
      size: 40,
      color: Color(0xFFCBD5E1),
    );
  }
}

