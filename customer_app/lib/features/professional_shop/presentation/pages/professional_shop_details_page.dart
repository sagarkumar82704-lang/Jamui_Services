import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/professional_shop_entity.dart';
import 'professional_storefront_page.dart';

class ProfessionalShopDetailsPage extends StatelessWidget {
  final ProfessionalShopEntity shop;

  const ProfessionalShopDetailsPage({super.key, required this.shop});

  Future<void> _makePhoneCall(String phoneNumber) async {
    final clean = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.isNotEmpty) {
      final uri = Uri.parse('tel:$clean');
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final international = clean.startsWith('91') ? clean : '91$clean';
    final uri = Uri.parse('https://wa.me/$international?text=Hello%20${Uri.encodeComponent(shop.shopName)},%20I%20have%20an%20inquiry.');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openDirections(double lat, double lng, String address) async {
    if (lat != 0.0 && lng != 0.0) {
      final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
      if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (address.isNotEmpty) {
      final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent("$address, Jamui, Bihar")}');
      if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Stack(
        children: [
          // Scrollable Content
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 90),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Hero Banner (Matching Reference Image)
                Stack(
                  children: [
                    Container(
                      height: 220,
                      width: double.infinity,
                      color: const Color(0xFFE2E8F0),
                      child: shop.bannerUrl.isNotEmpty
                          ? Image.network(
                              shop.bannerUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildFallbackBanner(),
                            )
                          : _buildFallbackBanner(),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.white,
                              radius: 18,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Color(0xFF1E293B)),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                            CircleAvatar(
                              backgroundColor: Colors.white,
                              radius: 18,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.share_outlined, size: 18, color: Color(0xFF1E293B)),
                                onPressed: () {},
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Floating Shop Profile Card (Overlapping Banner)
                Transform.translate(
                  offset: const Offset(0, -30),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              // Square Logo
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  color: const Color(0xFFE8F5E9),
                                  child: shop.logoUrl.isNotEmpty
                                      ? Image.network(
                                          shop.logoUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 30),
                                        )
                                      : const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 30),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            shop.shopName,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                        ),
                                        if (shop.isVerified)
                                          const Icon(Icons.verified_rounded, color: Color(0xFF2E7D32), size: 18),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        if (shop.rating > 0) ...[
                                          const Icon(Icons.star_rounded, color: Color(0xFFFFA000), size: 16),
                                          const SizedBox(width: 3),
                                          Text(
                                            '${shop.rating.toStringAsFixed(1)} (${shop.ratingCount} Reviews)',
                                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                          ),
                                          const Text(' • ', style: TextStyle(color: Colors.grey)),
                                        ],
                                        Text(
                                          shop.distanceKm != null ? '${shop.distanceKm!.toStringAsFixed(1)} km' : (shop.jamuiArea.isNotEmpty ? shop.jamuiArea : 'Jamui'),
                                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24, thickness: 0.8),

                          // Fulfillment Modes Row (Delivery / Pickup)
                          Row(
                            children: [
                              if (shop.isHomeDeliveryActive) ...[
                                _buildBadgePill(Icons.delivery_dining_rounded, 'Delivery', const Color(0xFFE8F5E9), const Color(0xFF2E7D32)),
                                const SizedBox(width: 8),
                              ],
                              if (shop.isPickupActive)
                                _buildBadgePill(Icons.store_rounded, 'Pickup', const Color(0xFFE3F2FD), const Color(0xFF1976D2)),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Terms: Min order, Delivery fee, ETA, Timings
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Min. Order ₹${shop.minOrderAmount.toInt()} • Delivery ${shop.deliveryCharges == 0 ? "Free" : "₹${shop.deliveryCharges.toInt()}"}',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${shop.estimatedDeliveryTimeMinutes}-${shop.estimatedDeliveryTimeMinutes + 15} mins',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                              Text(
                                'Open till ${shop.closingTime}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2E7D32)),
                              ),
                            ],
                          ),
                          if (shop.isPickupActive && shop.pickupInstructions.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFBBF7D0)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.storefront_rounded, size: 16, color: Color(0xFF15803D)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Store Pickup Instructions',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF15803D),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          shop.pickupInstructions,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF166534),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),

                          // Quick Actions Buttons Row (Call, WhatsApp, Directions, Share)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildActionCircle(Icons.call_rounded, 'Call', () => _makePhoneCall(shop.contactPhone.isNotEmpty ? shop.contactPhone : shop.ownerPhone)),
                              _buildActionCircle(Icons.chat_bubble_rounded, 'WhatsApp', () => _openWhatsApp(shop.whatsAppNumber.isNotEmpty ? shop.whatsAppNumber : shop.ownerPhone)),
                              _buildActionCircle(Icons.directions_rounded, 'Directions', () => _openDirections(shop.latitude, shop.longitude, shop.fullAddress)),
                              _buildActionCircle(Icons.share_rounded, 'Share', () {}),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // About Shop Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'About Shop',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        shop.description.isNotEmpty
                            ? shop.description
                            : '${shop.shopName} provides fresh essentials, daily grocery, fruits, vegetables, and daily products directly to your doorstep in Jamui.',
                        style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 20),

                      // Store Information
                      const Text(
                        'Store Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        Icons.category_rounded,
                        'Category',
                        shop.demandCategoryTitle.isNotEmpty
                            ? shop.demandCategoryTitle
                            : (shop.demandCategoryId.isNotEmpty ? shop.demandCategoryId : 'General Marketplace'),
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        Icons.location_on_rounded,
                        'Address',
                        shop.fullAddress.isNotEmpty
                            ? shop.fullAddress
                            : (shop.jamuiArea.isNotEmpty ? shop.jamuiArea : 'Jamui, Bihar'),
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        Icons.access_time_filled_rounded,
                        'Hours',
                        '${shop.openingTime} - ${shop.closingTime}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Sticky Bottom Bar: "Open Shop" Button (Matching Reference Image)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProfessionalStorefrontPage(shop: shop),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32), // Emerald Green from Reference
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'Shop Now',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.3,
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

  Widget _buildFallbackBanner() {
    return Container(
      color: const Color(0xFF1E293B),
      child: const Center(
        child: Icon(Icons.storefront_rounded, size: 64, color: Colors.white24),
      ),
    );
  }

  Widget _buildBadgePill(IconData icon, String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: fg)),
        ],
      ),
    );
  }

  Widget _buildActionCircle(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFF1F5F9),
            child: Icon(icon, color: const Color(0xFF2E7D32), size: 20),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

