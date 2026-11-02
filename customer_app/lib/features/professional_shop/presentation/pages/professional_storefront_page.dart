import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/datasources/professional_shop_remote_data_source.dart';
import '../../domain/entities/professional_product_entity.dart';
import '../../domain/entities/professional_shop_entity.dart';
import '../bloc/professional_cart_bloc.dart';
import 'professional_cart_page.dart';
import 'professional_product_details_page.dart';

class ProfessionalStorefrontPage extends StatefulWidget {
  final ProfessionalShopEntity shop;

  const ProfessionalStorefrontPage({super.key, required this.shop});

  @override
  State<ProfessionalStorefrontPage> createState() => _ProfessionalStorefrontPageState();
}

class _ProfessionalStorefrontPageState extends State<ProfessionalStorefrontPage> {
  final ProfessionalShopRemoteDataSource _dataSource = ProfessionalShopRemoteDataSource();
  List<ProfessionalProductEntity> _allProducts = [];
  List<String> _categories = ['All'];
  String _selectedCategory = 'All';
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCatalog();
  }

  Future<void> _fetchCatalog() async {
    setState(() => _isLoading = true);
    final prods = await _dataSource.fetchShopProducts(widget.shop.id);
    final cats = await _dataSource.fetchShopProductCategories(widget.shop.id);

    if (mounted) {
      setState(() {
        _allProducts = prods;
        if (cats.isNotEmpty) {
          _categories = ['All', ...cats];
        }
        _isLoading = false;
      });
    }
  }

  List<ProfessionalProductEntity> get _filteredProducts {
    return _allProducts.where((p) {
      if (_selectedCategory != 'All' &&
          p.categoryName.toLowerCase() != _selectedCategory.toLowerCase() &&
          p.storeCategoryName.toLowerCase() != _selectedCategory.toLowerCase()) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!p.titleEnglish.toLowerCase().contains(q) &&
            !p.titleHindi.toLowerCase().contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  void _showShopConflictDialog(BuildContext context, ProfessionalShopEntity newShop, ProfessionalProductEntity product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear Cart & Switch Shop?'),
        content: Text(
          'Your cart currently contains items from another shop. Do you want to clear your cart and start an order from ${newShop.shopName}?',
          style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ProfessionalCartBloc>().add(
                    ConfirmClearAndSwitchShopEvent(newShop: newShop, newProduct: product),
                  );
            },
            child: const Text('Yes, Clear & Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProfessionalCartBloc, ProfessionalCartState>(
      listener: (context, state) {
        if (state.hasShopConflict && state.conflictingShop != null && state.conflictingProduct != null) {
          _showShopConflictDialog(context, state.conflictingShop!, state.conflictingProduct!);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E293B), size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.shop.shopName,
            style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          actions: [
            BlocBuilder<ProfessionalCartBloc, ProfessionalCartState>(
              builder: (context, state) {
                return Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF1E293B)),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProfessionalCartPage(shop: widget.shop),
                          ),
                        );
                      },
                    ),
                    if (state.totalItemsCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFF2E7D32),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${state.totalItemsCount}',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                // Search Bar + Fulfillment Switcher
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      // Search Bar
                      Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search_rounded, color: Colors.grey, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                onChanged: (v) => setState(() => _searchQuery = v),
                                decoration: InputDecoration(
                                  hintText: 'Search in ${widget.shop.shopName}...',
                                  hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Delivery / Pickup Mode Switcher (Matching Reference Image)
                      BlocBuilder<ProfessionalCartBloc, ProfessionalCartState>(
                        builder: (context, cartState) {
                          final mode = cartState.fulfillmentMode;
                          return Container(
                            height: 38,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      context.read<ProfessionalCartBloc>().add(const SetFulfillmentModeEvent('delivery'));
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: mode == 'delivery' ? Colors.white : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: mode == 'delivery'
                                            ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]
                                            : null,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        'Delivery',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                          color: mode == 'delivery' ? const Color(0xFF2E7D32) : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      context.read<ProfessionalCartBloc>().add(const SetFulfillmentModeEvent('pickup'));
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: mode == 'pickup' ? Colors.white : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: mode == 'pickup'
                                            ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]
                                            : null,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        'Pickup',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                          color: mode == 'pickup' ? const Color(0xFF1976D2) : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Promotional Store Offer Banner (Matching Reference Image)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'BIG SAVINGS',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF1B5E20)),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'UP TO 30% OFF ON DAILY ESSENTIALS',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('SHOP NOW', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ],
                  ),
                ),

                // Categories Scroll Filter
                Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (ctx, i) {
                      final c = _categories[i];
                      final isSel = c == _selectedCategory;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedCategory = c),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSel ? const Color(0xFF2E7D32) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isSel ? const Color(0xFF2E7D32) : Colors.grey.shade200),
                          ),
                          child: Text(
                            c,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSel ? Colors.white : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),

                // Products Grid / List (Matching Reference Image)
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                      : _filteredProducts.isEmpty
                          ? _buildEmptyProducts()
                          : GridView.builder(
                              padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 90),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.68,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemCount: _filteredProducts.length,
                              itemBuilder: (ctx, i) => _buildProductCard(_filteredProducts[i]),
                            ),
                ),
              ],
            ),

            // Floating Bottom Cart Bar (Matching Reference Image)
            BlocBuilder<ProfessionalCartBloc, ProfessionalCartState>(
              builder: (context, state) {
                if (state.isEmpty) return const SizedBox.shrink();
                return Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProfessionalCartPage(shop: widget.shop),
                        ),
                      );
                    },
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32), // Emerald Green
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.white24,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 18),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '${state.totalItemsCount} Items • ₹${state.subtotal.toInt()}',
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const Row(
                            children: [
                              Text('View Cart', style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold)),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(ProfessionalProductEntity product) {
    return BlocBuilder<ProfessionalCartBloc, ProfessionalCartState>(
      builder: (context, cartState) {
        final qty = cartState.getProductQuantity(product.id);

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfessionalProductDetailsPage(shop: widget.shop, product: product),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image with Discount Badge
                Expanded(
                  child: Stack(
                    children: [
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: product.thumbnailUrl.isNotEmpty
                              ? Image.network(
                                  product.thumbnailUrl,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => _buildFallbackProductImage(),
                                )
                              : _buildFallbackProductImage(),
                        ),
                      ),
                      if (product.discountPercentage > 0)
                        Positioned(
                          left: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE53935),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${product.discountPercentage.toInt()}% OFF',
                              style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Title
                Text(
                  product.displayName,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),

                // Unit
                Text(
                  product.unitLabel,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 6),

                // Price and Stepper
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '₹${product.sellingPrice.toInt()}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                        ),
                        if (product.regularPrice > product.sellingPrice)
                          Text(
                            '₹${product.regularPrice.toInt()}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: Colors.grey,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                      ],
                    ),

                    // Interactive Add Button or Stepper
                    if (!product.inStock)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6)),
                        child: const Text('Out of Stock', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      )
                    else if (qty == 0)
                      GestureDetector(
                        onTap: () {
                          context.read<ProfessionalCartBloc>().add(
                                AddToCartEvent(shop: widget.shop, product: product),
                              );
                        },
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF2E7D32)),
                          ),
                          child: const Icon(Icons.add_rounded, color: Color(0xFF2E7D32), size: 20),
                        ),
                      )
                    else
                      Container(
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                context.read<ProfessionalCartBloc>().add(
                                      UpdateQuantityEvent(productId: product.id, delta: -1),
                                    );
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child: Icon(Icons.remove_rounded, color: Colors.white, size: 16),
                              ),
                            ),
                            Text(
                              '$qty',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            GestureDetector(
                              onTap: () {
                                context.read<ProfessionalCartBloc>().add(
                                      UpdateQuantityEvent(productId: product.id, delta: 1),
                                    );
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child: Icon(Icons.add_rounded, color: Colors.white, size: 16),
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
        );
      },
    );
  }

  Widget _buildFallbackProductImage() {
    return Container(
      color: const Color(0xFFF1F5F9),
      child: const Center(
        child: Icon(Icons.shopping_bag_outlined, color: Colors.grey, size: 36),
      ),
    );
  }

  Widget _buildEmptyProducts() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 54, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'कोई उत्पाद नहीं मिला',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 4),
          Text(
            'दुकानदार जल्द ही उत्पाद जोड़ेंगे।',
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

