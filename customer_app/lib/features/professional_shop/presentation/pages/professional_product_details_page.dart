import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/app_image_url_resolver.dart';
import '../../data/datasources/professional_shop_remote_data_source.dart';
import '../../data/services/shop_favorites_service.dart';
import '../../domain/entities/product_variant_entity.dart';
import '../../domain/entities/professional_product_entity.dart';
import '../../domain/entities/professional_shop_entity.dart';
import '../bloc/professional_cart_bloc.dart';
import '../localization/ecom_locale_controller.dart';
import '../localization/ecom_strings.dart';
import '../theme/ecom_theme.dart';
import 'professional_cart_page.dart';

class ProfessionalProductDetailsPage extends StatefulWidget {
  final ProfessionalShopEntity shop;
  final ProfessionalProductEntity product;

  const ProfessionalProductDetailsPage({
    super.key,
    required this.shop,
    required this.product,
  });

  @override
  State<ProfessionalProductDetailsPage> createState() => _ProfessionalProductDetailsPageState();
}

class _ProfessionalProductDetailsPageState extends State<ProfessionalProductDetailsPage> {
  final ProfessionalShopRemoteDataSource _dataSource = ProfessionalShopRemoteDataSource();

  int _localQuantity = 1;
  List<ProductVariantEntity> _variants = [];
  ProductVariantEntity? _selectedVariant;
  bool _isLoadingVariants = false;

  @override
  void initState() {
    super.initState();
    if (widget.product.hasVariants) {
      _loadVariants();
    }
  }

  Future<void> _loadVariants() async {
    setState(() => _isLoadingVariants = true);
    try {
      final list = await _dataSource.fetchProductVariants(widget.shop.id, widget.product.id);
      if (mounted) {
        setState(() {
          _variants = list;
          _isLoadingVariants = false;
          if (list.isNotEmpty) {
            _selectedVariant = list.firstWhere((v) => v.isActive && v.inStock, orElse: () => list.first);
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingVariants = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: EcomLocaleController.instance,
      builder: (context, _) {
        final p = widget.product;
        final isHindi = EcomLocaleController.instance.isHindi;
        final localizedTitle = isHindi && p.titleHindi.isNotEmpty
            ? p.titleHindi
            : (p.titleEnglish.isNotEmpty ? p.titleEnglish : p.titleHindi);
        final localizedUnit = (_selectedVariant != null && _selectedVariant!.title.trim().isNotEmpty)
            ? _selectedVariant!.title.trim()
            : EcomStrings.formatUnit(p.unitValue, p.unit);

        final hasVariants = p.hasVariants && _variants.isNotEmpty;

        final double effectiveSellingPrice = (hasVariants && _selectedVariant != null)
            ? _selectedVariant!.resolvePrice(p.sellingPrice)
            : p.sellingPrice;

        final double effectiveRegularPrice = (hasVariants && _selectedVariant != null)
            ? _selectedVariant!.resolveMrp(p.regularPrice)
            : p.regularPrice;

        final bool isBulk = p.stockType == 'bulk';
        final bool inStock = (hasVariants && _selectedVariant != null)
            ? (_selectedVariant!.isActive && _selectedVariant!.inStock && (!isBulk || p.inStock))
            : p.inStock;

        final int discountPct = (effectiveRegularPrice > effectiveSellingPrice && effectiveRegularPrice > 0)
            ? (((effectiveRegularPrice - effectiveSellingPrice) / effectiveRegularPrice) * 100).round()
            : 0;

        final String rawImageUrl = (_selectedVariant != null && _selectedVariant!.thumbnailUrl.isNotEmpty)
            ? _selectedVariant!.thumbnailUrl
            : (_selectedVariant != null && _selectedVariant!.images.isNotEmpty)
                ? _selectedVariant!.images.first
                : p.thumbnailUrl;

        final resolvedImageUrl = AppImageUrlResolver.resolve(rawImageUrl);

        final descriptionLines = p.description
            .split(RegExp(r'\r?\n'))
            .map((line) => line.replaceFirst(RegExp(r'^[\-\•\*]\s*'), '').trim())
            .where((line) => line.isNotEmpty)
            .toList();

        final factualCategory = p.storeCategoryName.trim().isNotEmpty
            ? p.storeCategoryName.trim()
            : p.categoryName.trim();

        return Scaffold(
          backgroundColor: EcomColors.background,
          appBar: AppBar(
            backgroundColor: EcomColors.surface,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: EcomColors.textPrimary, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(EcomStrings.productDetails,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: EcomColors.textPrimary)),
            actions: [
              // Favorites Heart
              ValueListenableBuilder<Set<String>>(
                valueListenable: ShopFavoritesService.instance.getFavoritesNotifier(widget.shop.id),
                builder: (context, favorites, _) {
                  final isFav = favorites.contains(p.id);
                  return IconButton(
                    icon: Icon(
                      isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: isFav ? const Color(0xFFE53935) : EcomColors.textSecondary,
                      size: 24,
                    ),
                    onPressed: () => ShopFavoritesService.instance.toggleFavorite(widget.shop.id, p.id),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.shopping_bag_outlined, color: EcomColors.textPrimary),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BlocProvider.value(
                        value: context.read<ProfessionalCartBloc>(),
                        child: ProfessionalCartPage(shop: widget.shop),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          body: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero Image
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: EcomColors.surface,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: EcomColors.cardShadow,
                      ),
                      child: Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: resolvedImageUrl.isNotEmpty
                              ? Image.network(resolvedImageUrl, height: 230, fit: BoxFit.contain,
                                  errorBuilder: (_, _, _) => _buildFallbackHero())
                              : _buildFallbackHero(),
                        ),
                      ),
                    ),

                    // Details Card (Matching Reference Screen 3)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: EcomColors.surface,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: EcomColors.cardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title + Unit + Inline Favorite Heart (Reference Screen 3)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  '$localizedTitle ($localizedUnit)',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: EcomColors.textPrimary,
                                    height: 1.25,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ValueListenableBuilder<Set<String>>(
                                valueListenable: ShopFavoritesService.instance.getFavoritesNotifier(widget.shop.id),
                                builder: (context, favorites, _) {
                                  final isFav = favorites.contains(p.id);
                                  return InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () => ShopFavoritesService.instance.toggleFavorite(widget.shop.id, p.id),
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Icon(
                                        isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                        color: isFav ? const Color(0xFFE53935) : EcomColors.textSecondary,
                                        size: 24,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Price + MRP + Genuine Discount Badge Row (Reference Screen 3)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                '₹${effectiveSellingPrice.toStringAsFixed(effectiveSellingPrice.truncateToDouble() == effectiveSellingPrice ? 0 : 2)}',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: EcomColors.textPrimary,
                                ),
                              ),
                              if (effectiveRegularPrice > effectiveSellingPrice && discountPct > 0) ...[
                                const SizedBox(width: 10),
                                Text(
                                  '₹${effectiveRegularPrice.toStringAsFixed(effectiveRegularPrice.truncateToDouble() == effectiveRegularPrice ? 0 : 2)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: EcomColors.textTertiary,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: EcomColors.accentOrange,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '$discountPct% OFF',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Quantity Stepper Pill (Dedicated Row below Price matching Reference Screen 3)
                          Container(
                            decoration: BoxDecoration(
                              color: EcomColors.softGreen,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: EcomColors.primary.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_rounded, size: 20, color: EcomColors.primary),
                                  onPressed: _localQuantity > 1 ? () => setState(() => _localQuantity--) : null,
                                  splashRadius: 20,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  constraints: const BoxConstraints(),
                                ),
                                Container(
                                  constraints: const BoxConstraints(minWidth: 36),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '$_localQuantity',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: EcomColors.primaryDark,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_rounded, size: 20, color: EcomColors.primary),
                                  onPressed: () => setState(() => _localQuantity++),
                                  splashRadius: 20,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),

                          if (_isLoadingVariants) ...[
                            const SizedBox(height: 16),
                            const Center(child: CircularProgressIndicator(color: EcomColors.primary)),
                          ] else if (hasVariants) ...[
                            const SizedBox(height: 20),
                            const Divider(color: EcomColors.divider),
                            const SizedBox(height: 10),
                            Text(EcomStrings.packagingOptions,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: EcomColors.textPrimary)),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8, runSpacing: 8,
                              children: _variants.map((variant) {
                                final isSelected = _selectedVariant?.id == variant.id;
                                return ChoiceChip(
                                  label: Text('${variant.title} - ₹${variant.resolvePrice(p.sellingPrice).toInt()}'),
                                  selected: isSelected,
                                  selectedColor: EcomColors.softGreen,
                                  backgroundColor: Colors.white,
                                  labelStyle: TextStyle(
                                    color: isSelected ? EcomColors.primary : EcomColors.textSecondary,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 12.5,
                                  ),
                                  side: BorderSide(color: isSelected ? EcomColors.primary : EcomColors.cardBorder),
                                  onSelected: variant.inStock ? (val) { if (val) setState(() => _selectedVariant = variant); } : null,
                                );
                              }).toList(),
                            ),
                          ],

                          const SizedBox(height: 20),
                          const Divider(color: EcomColors.divider),
                          const SizedBox(height: 14),

                          // Product Details Section (Strictly Real Product Data — Zero Hardcoded Claims)
                          Text(EcomStrings.productDetails,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: EcomColors.textPrimary)),
                          const SizedBox(height: 12),
                          if (descriptionLines.isNotEmpty)
                            ...descriptionLines.map((line) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _buildDetailBullet(line),
                                ))
                          else ...[
                            if (factualCategory.isNotEmpty) ...[
                              _buildDetailBullet('${EcomStrings.categoryLabel}: $factualCategory'),
                              const SizedBox(height: 8),
                            ],
                            if (localizedUnit.isNotEmpty) ...[
                              _buildDetailBullet('${EcomStrings.packSizeLabel}: $localizedUnit'),
                              const SizedBox(height: 8),
                            ],
                            _buildDetailBullet(
                              '${EcomStrings.availabilityLabel}: ${inStock ? EcomStrings.inStock : EcomStrings.outOfStock}',
                            ),
                          ],
                        ],
                      ),
                    ),

                    if (p.attributes.isNotEmpty)
                      _buildDynamicAttributesSection(p.attributes, p),
                  ],
                ),
              ),

              // Sticky Add to Cart button (Pill shape matching Reference Screen 3)
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: EcomColors.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: EcomColors.floatingBarShadow,
                  ),
                  child: SafeArea(
                    top: false,
                    child: BlocBuilder<ProfessionalCartBloc, ProfessionalCartState>(
                      builder: (context, cartState) {
                        return SizedBox(
                          width: double.infinity, height: 52,
                          child: ElevatedButton(
                            onPressed: inStock
                                ? () {
                                    for (int i = 0; i < _localQuantity; i++) {
                                      context.read<ProfessionalCartBloc>().add(
                                        AddToCartEvent(
                                          shop: widget.shop,
                                          product: p,
                                          variantId: _selectedVariant?.id,
                                          variantTitle: _selectedVariant?.title,
                                          priceOverride: _selectedVariant?.resolvePrice(p.sellingPrice),
                                          mrpOverride: _selectedVariant?.resolveMrp(p.regularPrice),
                                          selectedImageUrl: rawImageUrl.isNotEmpty ? rawImageUrl : null,
                                        ),
                                      );
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('$localizedTitle ($_localQuantity) ${EcomStrings.addedToCart}'),
                                        backgroundColor: EcomColors.primary,
                                        duration: const Duration(seconds: 2),
                                        action: SnackBarAction(
                                          label: EcomStrings.viewCart,
                                          textColor: Colors.white,
                                          onPressed: () {
                                            Navigator.push(context, MaterialPageRoute(
                                              builder: (_) => BlocProvider.value(
                                                value: context.read<ProfessionalCartBloc>(),
                                                child: ProfessionalCartPage(shop: widget.shop),
                                              ),
                                            ));
                                          },
                                        ),
                                      ),
                                    );
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: inStock ? EcomColors.primary : Colors.grey.shade400,
                              foregroundColor: Colors.white, elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                            ),
                            child: Text(
                              inStock ? EcomStrings.addToCart : EcomStrings.outOfStock,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailBullet(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle_rounded, size: 18, color: EcomColors.primary),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5, color: EcomColors.textPrimary, fontWeight: FontWeight.w500))),
      ],
    );
  }

  Widget _buildFallbackHero() {
    return Container(
      height: 220, width: double.infinity,
      color: EcomColors.cardBorder.withValues(alpha: 0.3),
      child: const Center(child: Icon(Icons.inventory_2_outlined, size: 72, color: EcomColors.textTertiary)),
    );
  }

  Widget _buildDynamicAttributesSection(Map<String, dynamic> attributes, ProfessionalProductEntity p) {
    final validEntries = attributes.entries.where((e) {
      if (e.value == null) return false;
      if (e.value is String && (e.value as String).trim().isEmpty) return false;
      if (e.value is List && (e.value as List).isEmpty) return false;
      return true;
    }).toList();

    if (validEntries.isEmpty) return const SizedBox.shrink();

    final rawPackUnit = '${p.unitValue == p.unitValue.toInt() ? p.unitValue.toInt() : p.unitValue} ${p.unit}'.trim();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: EcomColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: EcomColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Product Specifications',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: EcomColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (rawPackUnit.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    width: 120,
                    child: Text(
                      'Pack / Unit',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: EcomColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      rawPackUnit,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: EcomColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ...validEntries.map((e) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      _formatAttributeKey(e.key),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: EcomColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _formatAttributeValue(e.value),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: EcomColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _formatAttributeKey(String key) {
    switch (key.toLowerCase()) {
      case 'brand':
        return 'Brand';
      case 'weight':
        return 'Weight';
      case 'size':
        return 'Size';
      case 'fabric':
        return 'Fabric';
      case 'warranty':
      case 'warrantymonths':
        return 'Warranty';
      case 'material':
        return 'Material';
      case 'color':
        return 'Color';
      case 'dietarytype':
        return 'Dietary Type';
      case 'shelflifedays':
        return 'Shelf Life';
      case 'storagetype':
        return 'Storage Type';
      case 'origin':
      case 'countryoforigin':
        return 'Origin';
      case 'model':
        return 'Model';
      default:
        final result = key.replaceAllMapped(
          RegExp(r'([A-Z])'),
          (match) => ' ${match.group(0)}',
        );
        return result.isNotEmpty
            ? result[0].toUpperCase() + result.substring(1).trim()
            : key;
    }
  }

  String _formatAttributeValue(dynamic val) {
    if (val is bool) {
      return val ? 'Yes' : 'No';
    }
    if (val is List) {
      return val.join(', ');
    }
    return val.toString();
  }
}
