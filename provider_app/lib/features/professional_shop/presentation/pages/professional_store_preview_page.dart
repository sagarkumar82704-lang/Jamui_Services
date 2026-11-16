import 'package:flutter/material.dart';

import '../../../../core/utils/app_image_url_resolver.dart';
import '../../../../core/localization/provider_strings.dart';
import '../../data/datasources/professional_provider_remote_data_source.dart';
import '../../domain/entities/professional_shop_profile_entity.dart';
import '../widgets/professional_storefront_promo_banner.dart';

class ProfessionalStorePreviewPage extends StatefulWidget {
  final ProfessionalShopProfileEntity shop;
  final ProfessionalProviderRemoteDataSource? dataSource;

  const ProfessionalStorePreviewPage({
    super.key,
    required this.shop,
    this.dataSource,
  });

  @override
  State<ProfessionalStorePreviewPage> createState() =>
      _ProfessionalStorePreviewPageState();
}

class _ProfessionalStorePreviewPageState
    extends State<ProfessionalStorePreviewPage> {
  static const Color _primaryGreen = Color(0xFF15803D);
  static const Color _darkGreenHeader = Color(0xFF0B4F26);

  late final ProfessionalProviderRemoteDataSource _ds;
  String _selectedCategory = 'All';
  String _searchQuery = '';
  bool _isDeliveryMode = true;

  @override
  void initState() {
    super.initState();
    _ds = widget.dataSource ?? ProfessionalProviderRemoteDataSource();
    _isDeliveryMode = widget.shop.isHomeDeliveryActive ||
        !widget.shop.isPickupActive;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.shop;
    final resolvedLogo = AppImageUrlResolver.resolve(s.logoUrl);
    final resolvedCover = AppImageUrlResolver.resolve(s.bannerUrl);
    final activeBanner =
        (s.promoBanner != null && s.promoBanner!.isCurrentlyLive())
            ? s.promoBanner
            : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F9F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF073B1B),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.visibility_outlined, size: 18),
            const SizedBox(width: 8),
            Text(
              ProviderStrings.previewStore,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _ds.streamProducts(s.id),
        builder: (context, snapshot) {
          final rawProducts = snapshot.data ?? const [];
          final activeProducts = rawProducts
              .where((p) => p['isAvailable'] != false)
              .toList();

          final categories = <String>{'All'};
          for (final p in activeProducts) {
            final c = (p['category'] ?? '').toString().trim();
            if (c.isNotEmpty) categories.add(c);
          }

          final filteredProducts = activeProducts.where((p) {
            final cat = (p['category'] ?? '').toString().trim();
            final title = (p['name'] ?? p['title'] ?? '')
                .toString()
                .toLowerCase();
            final matchesCat =
                _selectedCategory == 'All' || cat == _selectedCategory;
            final matchesSearch = _searchQuery.isEmpty ||
                title.contains(_searchQuery.toLowerCase());
            return matchesCat && matchesSearch;
          }).toList();

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _buildStoreHeader(s, resolvedLogo, resolvedCover),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSearchField(),
                      const SizedBox(height: 12),
                      _buildFulfillmentModeToggle(s),
                      if (activeBanner != null) ...[
                        const SizedBox(height: 12),
                        _buildPromoBannerCard(activeBanner),
                      ],
                      const SizedBox(height: 12),
                      _buildCategoryRow(categories.toList()),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedCategory == 'All'
                                ? 'All Products (${filteredProducts.length})'
                                : '$_selectedCategory (${filteredProducts.length})',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                          if (_selectedCategory != 'All')
                            TextButton(
                              onPressed: () =>
                                  setState(() => _selectedCategory = 'All'),
                              child: const Text('See All'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              if (filteredProducts.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'No active products to preview in this category.',
                        style: TextStyle(color: Color(0xFF6B7280)),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.72,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          _buildPreviewProductCard(filteredProducts[index]),
                      childCount: filteredProducts.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStoreHeader(
    ProfessionalShopProfileEntity s,
    String resolvedLogo,
    String resolvedCover,
  ) {
    final hasGenuineRating = s.rating > 0 && s.ratingCount > 0;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _darkGreenHeader,
        image: resolvedCover.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(resolvedCover),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  _darkGreenHeader.withValues(alpha: 0.78),
                  BlendMode.srcOver,
                ),
              )
            : null,
      ),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: ClipOval(
              child: resolvedLogo.isNotEmpty
                  ? Image.network(
                      resolvedLogo,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.storefront_rounded,
                        color: _primaryGreen,
                        size: 30,
                      ),
                    )
                  : const Icon(
                      Icons.storefront_rounded,
                      color: _primaryGreen,
                      size: 30,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (s.isApproved) ...[
                      const Icon(
                        Icons.verified_rounded,
                        color: Color(0xFF4ADE80),
                        size: 17,
                      ),
                      const SizedBox(width: 5),
                    ],
                    Expanded(
                      child: Text(
                        s.shopName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (hasGenuineRating || s.jamuiArea.isNotEmpty)
                  Row(
                    children: [
                      if (hasGenuineRating) ...[
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFFACC15),
                          size: 16,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${s.rating.toStringAsFixed(1)} (${s.ratingCount})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      if (hasGenuineRating && s.jamuiArea.isNotEmpty)
                        const Text(
                          '  •  ',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      if (s.jamuiArea.isNotEmpty)
                        Expanded(
                          child: Text(
                            s.jamuiArea,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: s.isOpen
                            ? const Color(0xFF4ADE80)
                            : Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      s.isOpen
                          ? 'Open • Closes at ${s.closingTime}'
                          : 'Closed • Opens at ${s.openingTime}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      onChanged: (v) => setState(() => _searchQuery = v),
      decoration: InputDecoration(
        hintText: 'Search in this store...',
        prefixIcon: const Icon(Icons.search_rounded, color: _primaryGreen),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildFulfillmentModeToggle(ProfessionalShopProfileEntity s) {
    return Row(
      children: [
        if (s.isHomeDeliveryActive)
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _isDeliveryMode = true),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: _isDeliveryMode ? _primaryGreen : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isDeliveryMode
                        ? _primaryGreen
                        : const Color(0xFFD1D5DB),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.delivery_dining_rounded,
                      size: 18,
                      color: _isDeliveryMode
                          ? Colors.white
                          : const Color(0xFF374151),
                    ),
                    const SizedBox(width: 6),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delivery',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: _isDeliveryMode
                                ? Colors.white
                                : const Color(0xFF111827),
                          ),
                        ),
                        Text(
                          '${s.estimatedDeliveryTimeMinutes} min',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: _isDeliveryMode
                                ? Colors.white70
                                : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (s.isHomeDeliveryActive && s.isPickupActive)
          const SizedBox(width: 10),
        if (s.isPickupActive)
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _isDeliveryMode = false),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: !_isDeliveryMode ? _primaryGreen : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: !_isDeliveryMode
                        ? _primaryGreen
                        : const Color(0xFFD1D5DB),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.store_mall_directory_outlined,
                      size: 18,
                      color: !_isDeliveryMode
                          ? Colors.white
                          : const Color(0xFF374151),
                    ),
                    const SizedBox(width: 6),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pickup',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: !_isDeliveryMode
                                ? Colors.white
                                : const Color(0xFF111827),
                          ),
                        ),
                        Text(
                          'Store Pickup',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: !_isDeliveryMode
                                ? Colors.white70
                                : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCategoryRow(List<String> categories) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final active = cat == _selectedCategory;
          return ChoiceChip(
            label: Text(cat),
            selected: active,
            onSelected: (_) => setState(() => _selectedCategory = cat),
            selectedColor: _primaryGreen,
            backgroundColor: Colors.white,
            labelStyle: TextStyle(
              color: active ? Colors.white : const Color(0xFF374151),
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          );
        },
      ),
    );
  }

  Widget _buildPromoBannerCard(ShopPromoBannerEntity banner) {
    return ProfessionalStorefrontPromoBanner(
      banner: banner,
      freeDeliveryThreshold: widget.shop.freeDeliveryThreshold,
      margin: EdgeInsets.zero,
    );
  }

  Widget _buildPreviewProductCard(Map<String, dynamic> p) {
    final name = (p['name'] ?? p['title'] ?? 'Product').toString();
    final unit = (p['unit'] ?? '').toString();
    final sellingPrice =
        (p['sellingPrice'] ?? p['price'] ?? 0).toDouble();
    final regularPrice =
        (p['regularPrice'] ?? p['mrp'] ?? sellingPrice).toDouble();
    final rawImg = (p['imageUrl'] ??
            ((p['images'] is List && (p['images'] as List).isNotEmpty)
                ? (p['images'] as List).first
                : ''))
        .toString();
    final resolvedImg = AppImageUrlResolver.resolve(rawImg);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Center(
              child: resolvedImg.isNotEmpty
                  ? Image.network(
                      resolvedImg,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.inventory_2_outlined,
                        color: Color(0xFF9CA3AF),
                        size: 36,
                      ),
                    )
                  : const Icon(
                      Icons.inventory_2_outlined,
                      color: Color(0xFF9CA3AF),
                      size: 36,
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              color: Color(0xFF111827),
            ),
          ),
          if (unit.isNotEmpty)
            Text(
              unit,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
            ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    '₹${sellingPrice.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                      color: Color(0xFF111827),
                    ),
                  ),
                  if (regularPrice > sellingPrice) ...[
                    const SizedBox(width: 4),
                    Text(
                      '₹${regularPrice.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9CA3AF),
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                ],
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: _primaryGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

