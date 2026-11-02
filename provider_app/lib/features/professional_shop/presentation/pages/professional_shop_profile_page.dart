import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/datasources/professional_provider_remote_data_source.dart';
import '../../domain/entities/professional_shop_profile_entity.dart';
import 'professional_shop_settings_page.dart';
import 'professional_shop_subscription_page.dart';
import 'professional_manage_store_categories_page.dart';

/// Professional Seller Profile & Account Management Tab
/// Displays Shop Branding (Logo, Cover/Banner), Marketplace Category Badge,
/// Shop Address, Business Hours & Weekly Schedule, Open/Closed status toggle,
/// Delivery & Pickup settings, Subscription details with renewal navigation,
/// Store Categories shortcut, and Logout with confirmation.
class ProfessionalShopProfilePage extends StatefulWidget {
  final ProfessionalShopProfileEntity shop;
  final ProfessionalProviderRemoteDataSource? dataSource;

  const ProfessionalShopProfilePage({
    super.key,
    required this.shop,
    this.dataSource,
  });

  @override
  State<ProfessionalShopProfilePage> createState() => _ProfessionalShopProfilePageState();
}

class _ProfessionalShopProfilePageState extends State<ProfessionalShopProfilePage> {
  late final ProfessionalProviderRemoteDataSource _dataSource;
  late final Stream<ProfessionalShopProfileEntity?> _shopStream;
  late bool _isOpen;

  @override
  void initState() {
    super.initState();
    _dataSource = widget.dataSource ?? ProfessionalProviderRemoteDataSource();
    _isOpen = widget.shop.isOpen;
    _shopStream = _dataSource.streamShopProfile(widget.shop.id);
  }

  Future<void> _toggleOpen(bool val) async {
    setState(() => _isOpen = val);
    await _dataSource.toggleShopOpenStatus(widget.shop.id, val);
  }

  Future<void> _handleSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('लॉग आउट करें?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('क्या आप सचमुच अपने प्रोफेशनल सेलर खाते से लॉग आउट करना चाहते हैं?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('रद्द करें', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC62828)),
            child: const Text('लॉग आउट', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseAuth.instance.signOut();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('लॉग आउट विफल: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'दुकान प्रोफ़ाइल (Shop Profile)',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
      ),
      body: StreamBuilder<ProfessionalShopProfileEntity?>(
        stream: _shopStream,
        initialData: widget.shop,
        builder: (context, snapshot) {
          final shop = snapshot.data ?? widget.shop;
          final categoryBadge = shop.demandCategoryTitle.isNotEmpty ? shop.demandCategoryTitle : 'Marketplace Seller';
          final fullAddress = shop.fullAddress.isNotEmpty ? shop.fullAddress : (shop.jamuiArea.isNotEmpty ? shop.jamuiArea : 'जमुई, बिहार');

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Shop Branding & Cover Image Container
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cover / Banner Image
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: Container(
                        height: 110,
                        width: double.infinity,
                        color: const Color(0xFF0F766E),
                        child: shop.bannerUrl.isNotEmpty
                            ? Image.network(
                                shop.bannerUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => _buildBannerFallback(),
                              )
                            : _buildBannerFallback(),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Superimposed Logo
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  color: const Color(0xFFEFF6FF),
                                  child: shop.logoUrl.isNotEmpty
                                      ? Image.network(
                                          shop.logoUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) =>
                                              const Icon(Icons.storefront_rounded, color: Color(0xFF1D4ED8), size: 32),
                                        )
                                      : const Icon(Icons.storefront_rounded, color: Color(0xFF1D4ED8), size: 32),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      shop.shopName,
                                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                                        const SizedBox(width: 3),
                                        Expanded(
                                          child: Text(
                                            fullAddress,
                                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        // Marketplace Category Badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEFF6FF),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFFBFDBFE)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.category_rounded, size: 12, color: Color(0xFF1D4ED8)),
                                              const SizedBox(width: 4),
                                              Text(
                                                categoryBadge,
                                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Verified Badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE8F5E9),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.verified_rounded, size: 12, color: Color(0xFF2E7D32)),
                                              const SizedBox(width: 4),
                                              Text(
                                                shop.isApproved ? 'सत्यापित विक्रेता' : 'प्रतीक्षारत',
                                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (shop.rating > 0)
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                                              Text(
                                                ' ${shop.rating.toStringAsFixed(1)}',
                                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),

                          // Open / Closed Status Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _isOpen ? Icons.door_sliding_rounded : Icons.lock_outline_rounded,
                                    color: _isOpen ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                                    size: 22,
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _isOpen ? 'दुकान खुली है (Shop Open)' : 'दुकान बंद है (Shop Closed)',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.bold,
                                          color: _isOpen ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                                        ),
                                      ),
                                      Text(
                                        _isOpen ? 'ग्राहक नए ऑर्डर दे सकते हैं' : 'नए ऑर्डर अस्थायी रूप से रोके गए हैं',
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Switch(
                                value: _isOpen,
                                activeThumbColor: const Color(0xFF2E7D32),
                                onChanged: _toggleOpen,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Business Hours & Weekly Schedule
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 20, color: Color(0xFF0F766E)),
                        SizedBox(width: 8),
                        Text(
                          'कार्य समय (Business Hours)',
                          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildTimeInfo('खुलने का समय', shop.openingTime.isNotEmpty ? shop.openingTime : '08:00 AM'),
                        _buildTimeInfo('बंद होने का समय', shop.closingTime.isNotEmpty ? shop.closingTime : '09:00 PM'),
                        _buildTimeInfo('साप्ताहिक अवकाश', 'कोई अवकाश नहीं (7 दिन खुला)'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Delivery & Pickup Settings Summary Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.local_shipping_outlined, size: 20, color: Color(0xFF1D4ED8)),
                            SizedBox(width: 8),
                            Text(
                              'डिलीवरी एवं पिकअप सेटिंग्स',
                              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => ProfessionalShopSettingsPage(shop: shop)),
                            );
                          },
                          child: const Text('बदलें', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildSettingRow('होम डिलीवरी', shop.isHomeDeliveryActive ? 'सक्रिय (Active)' : 'निष्क्रिय (Inactive)'),
                    _buildSettingRow('स्टोर पिकअप', shop.isPickupActive ? 'सक्रिय (Active)' : 'निष्क्रिय (Inactive)'),
                    _buildSettingRow('डिलीवरी शुल्क', '₹${shop.deliveryCharges.toInt()}'),
                    _buildSettingRow('न्यूनतम ऑर्डर मूल्य', '₹${shop.minOrderAmount.toInt()}'),
                    _buildSettingRow('सेवा दायरा', '${shop.serviceRadiusKm.toInt()} किमी'),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Subscription & Limits Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.card_membership_rounded, size: 20, color: Color(0xFFE65100)),
                            SizedBox(width: 8),
                            Text(
                              'सब्सक्रिप्शन एवं प्लान',
                              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => ProfessionalShopSubscriptionPage(shop: shop)),
                            );
                          },
                          child: const Text('प्लान नवीनीकरण', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE65100))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildSettingRow('प्लान का नाम', shop.subscriptionPlanName.isNotEmpty ? shop.subscriptionPlanName : 'Professional Seller'),
                    _buildSettingRow('प्लान स्थिति', shop.isSubscriptionActive ? 'सक्रिय (Active)' : 'समाप्त (Expired)'),
                    _buildSettingRow(
                      'वैधता (Expiry Date)',
                      shop.subscriptionExpiry != null
                          ? '${shop.subscriptionExpiry!.day}/${shop.subscriptionExpiry!.month}/${shop.subscriptionExpiry!.year}'
                          : 'आजीवन / स्वतः नवीनीकरण',
                    ),
                    _buildSettingRow('अधिकतम उत्पाद सीमा', '${shop.maxProductsLimit} उत्पाद'),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Store Categories Management Tile (Checkpoint 2A Integration)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3)),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFEFF6FF),
                      child: Icon(Icons.category_rounded, color: Color(0xFF1D4ED8), size: 20),
                    ),
                    title: const Text(
                      'मेरी स्टोर श्रेणियां (Store Categories)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    subtitle: const Text(
                      'अपनी दुकान की श्रेणियां और उपश्रेणियां प्रबंधित करें',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProfessionalManageStoreCategoriesPage(shopId: shop.id),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Log Out Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _handleSignOut,
                  icon: const Icon(Icons.logout_rounded, color: Color(0xFFC62828)),
                  label: const Text(
                    'लॉग आउट (Sign Out)',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFFC62828)),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFC62828)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBannerFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF134E4A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storefront_rounded, color: Colors.white.withValues(alpha: 0.3), size: 36),
            const SizedBox(width: 8),
            Text(
              'JAMUI SERVICES SELLER',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeInfo(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        ],
      ),
    );
  }

  Widget _buildSettingRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
          Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
        ],
      ),
    );
  }
}
