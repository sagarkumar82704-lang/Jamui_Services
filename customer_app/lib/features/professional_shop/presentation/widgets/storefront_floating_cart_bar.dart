import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/professional_shop_entity.dart';
import '../bloc/professional_cart_bloc.dart';
import '../localization/ecom_strings.dart';
import '../localization/ecom_locale_controller.dart';
import '../pages/professional_cart_page.dart';
import '../theme/ecom_theme.dart';

/// Floating Bottom Cart Bar for the Mini E-commerce Storefront.
///
/// Multi-Vendor Cart Safeguard:
/// When customer is browsing Store B but cart already holds items from Store A,
/// renders an amber notice bar identifying Store A with a shortcut to view that cart,
/// preventing order confusion while strictly enforcing single-store cart isolation.
class StorefrontFloatingCartBar extends StatelessWidget {
  final ProfessionalShopEntity browsingShop;

  const StorefrontFloatingCartBar({
    super.key,
    required this.browsingShop,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfessionalCartBloc, ProfessionalCartState>(
      builder: (context, state) {
        if (state.isEmpty) return const SizedBox.shrink();

        final isCartFromThisShop = state.currentShop == null || state.currentShop!.id == browsingShop.id;
        final targetShop = state.currentShop ?? browsingShop;
        final barColor = isCartFromThisShop ? EcomColors.primary : const Color(0xFFD97706);
        final isHindi = EcomLocaleController.instance.isHindi;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfessionalCartPage(shop: targetShop),
              ),
            );
          },
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: barColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: EcomColors.floatingBarShadow,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.white24,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isCartFromThisShop ? Icons.shopping_bag_rounded : Icons.storefront_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isCartFromThisShop
                              ? '${state.totalItemsCount} ${EcomStrings.items} • ₹${state.subtotal.toInt()}'
                              : (isHindi
                                  ? 'कार्ट: ${targetShop.shopName} (${state.totalItemsCount})'
                                  : 'Cart: ${targetShop.shopName} (${state.totalItemsCount})'),
                          style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Text(
                      isCartFromThisShop ? EcomStrings.viewCart : (isHindi ? 'कार्ट देखें' : 'View Cart'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
