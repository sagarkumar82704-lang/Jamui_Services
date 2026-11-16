import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/datasources/professional_shop_remote_data_source.dart';
import '../../data/services/shop_favorites_service.dart';
import '../../domain/entities/professional_product_entity.dart';
import '../../domain/entities/professional_shop_entity.dart';
import '../bloc/professional_cart_bloc.dart';
import '../localization/ecom_locale_controller.dart';
import '../localization/ecom_strings.dart';
import '../theme/ecom_theme.dart';
import '../widgets/ecom_product_card.dart';
import 'professional_cart_page.dart';
import 'professional_product_details_page.dart';

/// Shop-Specific Favorites page matching the reference design.
/// Allows the customer to quickly browse and re-order saved products from this store.
class ShopFavoritesPage extends StatefulWidget {
  final ProfessionalShopEntity shop;

  const ShopFavoritesPage({super.key, required this.shop});

  @override
  State<ShopFavoritesPage> createState() => _ShopFavoritesPageState();
}

class _ShopFavoritesPageState extends State<ShopFavoritesPage> {
  final ProfessionalShopRemoteDataSource _dataSource = ProfessionalShopRemoteDataSource();
  List<ProfessionalProductEntity> _allShopProducts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    await ShopFavoritesService.instance.loadFavorites(widget.shop.id);

    try {
      final all = await _dataSource.fetchShopProducts(widget.shop.id);
      if (mounted) {
        setState(() {
          _allShopProducts = all;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: EcomLocaleController.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: EcomColors.background,
          appBar: AppBar(
            backgroundColor: EcomColors.primary,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              EcomStrings.myFavorites,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            actions: [
              BlocBuilder<ProfessionalCartBloc, ProfessionalCartState>(
                builder: (context, state) {
                  return Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.shopping_bag_outlined, color: Colors.white),
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
                              color: EcomColors.accentOrange,
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
          body: _isLoading
              ? const Center(child: CircularProgressIndicator(color: EcomColors.primary))
              : ValueListenableBuilder<Set<String>>(
                  valueListenable: ShopFavoritesService.instance.getFavoritesNotifier(widget.shop.id),
                  builder: (context, favIds, _) {
                    final favoriteProducts = _allShopProducts.where((p) => favIds.contains(p.id)).toList();

                    if (favoriteProducts.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: const BoxDecoration(
                                  color: EcomColors.softGreen,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.favorite_border_rounded,
                                  size: 54,
                                  color: EcomColors.primary,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                EcomStrings.noFavoritesTitle,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: EcomColors.textPrimary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                EcomStrings.noFavoritesSubtitle,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: EcomColors.textSecondary,
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return BlocBuilder<ProfessionalCartBloc, ProfessionalCartState>(
                      builder: (context, cartState) {
                        return GridView.builder(
                          padding: const EdgeInsets.all(14),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.68,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: favoriteProducts.length,
                          itemBuilder: (context, index) {
                            final prod = favoriteProducts[index];
                            final qty = cartState.getProductQuantity(prod.id);

                            return EcomProductCard(
                              shop: widget.shop,
                              product: prod,
                              cartQuantity: qty,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ProfessionalProductDetailsPage(
                                      shop: widget.shop,
                                      product: prod,
                                    ),
                                  ),
                                );
                              },
                              onAddToCart: () {
                                context.read<ProfessionalCartBloc>().add(
                                      AddToCartEvent(shop: widget.shop, product: prod),
                                    );
                              },
                              onIncrement: () {
                                context.read<ProfessionalCartBloc>().add(
                                      UpdateQuantityEvent(productId: prod.id, delta: 1),
                                    );
                              },
                              onDecrement: () {
                                context.read<ProfessionalCartBloc>().add(
                                      UpdateQuantityEvent(productId: prod.id, delta: -1),
                                    );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
        );
      },
    );
  }
}

