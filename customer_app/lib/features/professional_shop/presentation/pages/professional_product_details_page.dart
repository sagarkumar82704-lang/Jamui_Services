import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/professional_product_entity.dart';
import '../../domain/entities/professional_shop_entity.dart';
import '../bloc/professional_cart_bloc.dart';
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
  int _localQuantity = 1;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E293B), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Product Details',
          style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Color(0xFF1E293B)),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Hero Image Carousel (Matching Reference Image)
                Container(
                  height: 260,
                  width: double.infinity,
                  color: Colors.white,
                  child: Center(
                    child: p.thumbnailUrl.isNotEmpty
                        ? Image.network(
                            p.thumbnailUrl,
                            fit: BoxFit.contain,
                            height: 220,
                            errorBuilder: (_, __, ___) => _buildFallbackImage(),
                          )
                        : _buildFallbackImage(),
                  ),
                ),
                const SizedBox(height: 12),

                // Product Information Card
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        p.displayName,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Price and Discount
                      Row(
                        children: [
                          Text(
                            '₹${p.sellingPrice.toInt()}/${p.unit}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (p.regularPrice > p.sellingPrice) ...[
                            Text(
                              '₹${p.regularPrice.toInt()}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (p.discountPercentage > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEBEE),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${p.discountPercentage.toInt()}% OFF',
                                style: const TextStyle(
                                  color: Color(0xFFC62828),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // In Stock Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: p.inStock ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          p.inStock ? 'In Stock' : 'Out of Stock',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: p.inStock ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Description
                      Text(
                        p.description.isNotEmpty
                            ? p.description
                            : 'Fresh and juicy handpicked quality items from ${widget.shop.shopName}. Clean, hygienic and packed with utmost care.',
                        style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Weight / Pack Info Card
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pack / Unit',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF2E7D32)),
                        ),
                        child: Text(
                          p.unitLabel,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Dynamic Firestore Category Attributes (e.g., Brand, Weight, Size, Fabric, Warranty)
                _buildDynamicAttributesSection(p.attributes),
                const SizedBox(height: 12),

                // Quantity Selector Card (Matching Reference Image)
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Quantity',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_rounded, size: 18),
                              onPressed: () {
                                if (_localQuantity > 1) {
                                  setState(() => _localQuantity--);
                                }
                              },
                            ),
                            Text(
                              '$_localQuantity',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_rounded, size: 18),
                              onPressed: () {
                                setState(() => _localQuantity++);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Sticky Bottom "Add to Cart" Bar (Matching Reference Image)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: !p.inStock
                        ? null
                        : () {
                            for (int i = 0; i < _localQuantity; i++) {
                              context.read<ProfessionalCartBloc>().add(
                                    AddToCartEvent(shop: widget.shop, product: p),
                                  );
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${p.displayName} added to cart!'),
                                backgroundColor: const Color(0xFF2E7D32),
                                duration: const Duration(seconds: 2),
                                action: SnackBarAction(
                                  label: 'VIEW CART',
                                  textColor: Colors.white,
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ProfessionalCartPage(shop: widget.shop),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                            Navigator.pop(context);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32), // Emerald Green
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Add to Cart • ₹${(p.sellingPrice * _localQuantity).toInt()}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackImage() {
    return Container(
      color: const Color(0xFFF1F5F9),
      child: const Center(
        child: Icon(Icons.shopping_bag_outlined, color: Colors.grey, size: 72),
      ),
    );
  }

  Widget _buildDynamicAttributesSection(Map<String, dynamic> attributes) {
    final validEntries = attributes.entries.where((e) {
      if (e.value == null) return false;
      if (e.value is String && (e.value as String).trim().isEmpty) return false;
      if (e.value is List && (e.value as List).isEmpty) return false;
      return true;
    }).toList();

    if (validEntries.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Product Specifications',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
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
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _formatAttributeValue(e.value),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF1E293B),
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

