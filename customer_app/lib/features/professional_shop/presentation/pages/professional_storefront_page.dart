import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/utils/app_image_url_resolver.dart';
import '../../data/datasources/professional_shop_remote_data_source.dart';
import '../../data/services/shop_favorites_service.dart';
import '../../domain/entities/professional_product_entity.dart';
import '../../domain/entities/professional_shop_entity.dart';
import '../bloc/professional_cart_bloc.dart';
import '../localization/ecom_locale_controller.dart';
import '../localization/ecom_strings.dart';
import '../theme/ecom_theme.dart';
import '../widgets/ecom_product_card.dart';
import '../widgets/professional_storefront_promo_banner.dart';
import '../widgets/storefront_floating_cart_bar.dart';
import 'professional_cart_page.dart';
import 'professional_customer_orders_page.dart';
import 'professional_product_details_page.dart';
import 'shop_favorites_page.dart';

/// Redesigned Storefront page matching Screen 2 of the reference design:
/// - Dark Forest Green AppBar (#087443) with store name, rating badge, language switcher & favorites
/// - Soft Green Search & Delivery estimate pill
/// - Horizontal scrollable Category Chips with active green state
/// - 2-Column responsive Product Grid using EcomProductCard
/// - Slide-up Floating Cart bar when items are in cart
class ProfessionalStorefrontPage extends StatefulWidget {
  final ProfessionalShopEntity shop;
  final ProfessionalShopRemoteDataSource? dataSource;

  const ProfessionalStorefrontPage({
    super.key,
    required this.shop,
    this.dataSource,
  });

  @override
  State<ProfessionalStorefrontPage> createState() => _ProfessionalStorefrontPageState();
}

class _ProfessionalStorefrontPageState extends State<ProfessionalStorefrontPage> {
  late final ProfessionalShopRemoteDataSource _dataSource;
  List<ProfessionalProductEntity> _allProducts = [];
  List<String> _categories = [];
  String _selectedCategory = '';
  String _searchQuery = '';
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _dataSource = widget.dataSource ?? ProfessionalShopRemoteDataSource();
    _initLocaleAndCatalog();
  }

  Future<void> _initLocaleAndCatalog() async {
    await EcomLocaleController.instance.init();
    await ShopFavoritesService.instance.loadFavorites(widget.shop.id);
    await _fetchCatalog();
  }

  Future<void> _fetchCatalog() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prods = await _dataSource.fetchShopProducts(widget.shop.id);
      final cats = await _dataSource.fetchShopProductCategories(widget.shop.id);

      if (mounted) {
        setState(() {
          _allProducts = prods;
          _categories = [EcomStrings.all, ...cats];
          _selectedCategory = EcomStrings.all;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
        });
      }
    }
  }

  List<ProfessionalProductEntity> get _filteredProducts {
    return _allProducts.where((p) {
      if (_selectedCategory.isNotEmpty &&
          _selectedCategory != EcomStrings.all &&
          _selectedCategory != 'All' &&
          _selectedCategory != 'सभी') {
        if (p.categoryName.toLowerCase() != _selectedCategory.toLowerCase() &&
            p.storeCategoryName.toLowerCase() != _selectedCategory.toLowerCase()) {
          return false;
        }
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
        title: Text(EcomStrings.clearCartTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(
          EcomStrings.clearCartMessage(newShop.shopName),
          style: const TextStyle(fontSize: 13.5, color: EcomColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(EcomStrings.cancel, style: const TextStyle(color: EcomColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: EcomColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ProfessionalCartBloc>().add(
                    ConfirmClearAndSwitchShopEvent(newShop: newShop, newProduct: product),
                  );
            },
            child: Text(EcomStrings.clearAndAdd, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      EcomStrings.languageTitle,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: EcomColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(),
                ListTile(
                  leading: const Text('🇮🇳', style: TextStyle(fontSize: 22)),
                  title: const Text('हिन्दी (Hindi)', style: TextStyle(fontWeight: FontWeight.bold)),
                  trailing: EcomLocaleController.instance.isHindi
                      ? const Icon(Icons.check_circle_rounded, color: EcomColors.primary)
                      : null,
                  onTap: () {
                    EcomLocaleController.instance.setLanguage('hi');
                    Navigator.pop(ctx);
                    setState(() {});
                  },
                ),
                ListTile(
                  leading: const Text('🌐', style: TextStyle(fontSize: 22)),
                  title: const Text('English', style: TextStyle(fontWeight: FontWeight.bold)),
                  trailing: !EcomLocaleController.instance.isHindi
                      ? const Icon(Icons.check_circle_rounded, color: EcomColors.primary)
                      : null,
                  onTap: () {
                    EcomLocaleController.instance.setLanguage('en');
                    Navigator.pop(ctx);
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _callSeller(String phoneNumber) async {
    final clean = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.isNotEmpty) {
      final uri = Uri.parse('tel:$clean');
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    }
  }

  Future<void> _whatsappSeller(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.isEmpty) return;
    final international = clean.startsWith('91') ? clean : '91$clean';
    final uri = Uri.parse(
      'https://wa.me/$international?text=Hello%20${Uri.encodeComponent(widget.shop.shopName)},%20I%20have%20an%20inquiry.',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showStoreQuickMenu() {
    final user = FirebaseAuth.instance.currentUser;
    final userName = (user?.displayName != null && user!.displayName!.trim().isNotEmpty)
        ? user.displayName!.trim()
        : EcomStrings.guestCustomer;
    final userContact = (user?.phoneNumber != null && user!.phoneNumber!.trim().isNotEmpty)
        ? user.phoneNumber!.trim()
        : (user?.email ?? '');

    final callPhone = widget.shop.contactPhone.trim().isNotEmpty
        ? widget.shop.contactPhone.trim()
        : widget.shop.ownerPhone.trim();
    final whatsAppPhone = widget.shop.whatsAppNumber.trim().isNotEmpty
        ? widget.shop.whatsAppNumber.trim()
        : widget.shop.ownerPhone.trim();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return AnimatedBuilder(
          animation: EcomLocaleController.instance,
          builder: (context, _) {
            return Container(
              decoration: const BoxDecoration(
                color: EcomColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dark Green Header matching Reference Screen 6 ("मेरा खाता")
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      decoration: const BoxDecoration(
                        color: EcomColors.primary,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.storefront_rounded, color: Colors.white, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                EcomStrings.storeMenuTitle,
                                style: const TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),

                    // User Info Row (Real Auth User — No Fake Name/Phone)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      decoration: const BoxDecoration(
                        color: EcomColors.background,
                        border: Border(bottom: BorderSide(color: EcomColors.divider)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: EcomColors.softGreen,
                            child: const Icon(Icons.person_rounded, color: EcomColors.primary, size: 26),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: EcomColors.textPrimary,
                                  ),
                                ),
                                if (userContact.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    userContact,
                                    style: const TextStyle(fontSize: 12, color: EcomColors.textSecondary),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Menu Items matching Reference Screen 6
                    _buildStoreMenuTile(
                      icon: Icons.receipt_long_rounded,
                      iconColor: EcomColors.primary,
                      title: EcomStrings.myOrdersTitle,
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ProfessionalCustomerOrdersPage()),
                        );
                      },
                    ),
                    const Divider(height: 1, color: EcomColors.divider),
                    _buildStoreMenuTile(
                      icon: Icons.favorite_rounded,
                      iconColor: const Color(0xFFE53935),
                      title: EcomStrings.myFavorites,
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ShopFavoritesPage(shop: widget.shop)),
                        );
                      },
                    ),
                    const Divider(height: 1, color: EcomColors.divider),
                    _buildStoreMenuTile(
                      icon: Icons.info_outline_rounded,
                      iconColor: EcomColors.primary,
                      title: EcomLocaleController.instance.isHindi
                          ? 'दुकान की जानकारी (Store Information)'
                          : 'Store Information',
                      subtitle: [
                        if (widget.shop.description.trim().isNotEmpty)
                          widget.shop.description.trim(),
                        '${EcomStrings.storeTimings}: ${widget.shop.openingTime} - ${widget.shop.closingTime}',
                      ].join(' • '),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showStoreInformationSheet();
                      },
                    ),
                    const Divider(height: 1, color: EcomColors.divider),
                    _buildStoreMenuTile(
                      icon: Icons.location_on_rounded,
                      iconColor: EcomColors.primary,
                      title: EcomLocaleController.instance.isHindi
                          ? 'दुकान का पता (Store Address)'
                          : 'Store Address',
                      subtitle: [
                        if (widget.shop.fullAddress.isNotEmpty)
                          widget.shop.fullAddress
                        else if (widget.shop.jamuiArea.isNotEmpty)
                          widget.shop.jamuiArea,
                        if (widget.shop.landmark.trim().isNotEmpty)
                          'Landmark: ${widget.shop.landmark.trim()}',
                      ].join(' • '),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showStoreInformationSheet();
                      },
                    ),
                    if (callPhone.isNotEmpty || whatsAppPhone.isNotEmpty) ...[
                      const Divider(height: 1, color: EcomColors.divider),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: EcomColors.softGreen,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.help_outline_rounded, color: EcomColors.primary, size: 18),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  EcomStrings.contactSellerHelp,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: EcomColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                if (callPhone.isNotEmpty)
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        _callSeller(callPhone);
                                      },
                                      icon: const Icon(Icons.call_rounded, size: 16, color: EcomColors.primary),
                                      label: Text(
                                        EcomStrings.callSeller,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: EcomColors.primary),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: EcomColors.primary),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                                if (callPhone.isNotEmpty && whatsAppPhone.isNotEmpty) const SizedBox(width: 10),
                                if (whatsAppPhone.isNotEmpty)
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        _whatsappSeller(whatsAppPhone);
                                      },
                                      icon: const Icon(Icons.chat_bubble_rounded, size: 16, color: Colors.white),
                                      label: Text(
                                        EcomStrings.whatsappSeller,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: EcomColors.primary,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    const Divider(height: 1, color: EcomColors.divider),
                    _buildStoreMenuTile(
                      icon: Icons.settings_outlined,
                      iconColor: EcomColors.textSecondary,
                      title: EcomStrings.appLanguageSettings,
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: EcomColors.softGreen,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          EcomLocaleController.instance.isHindi ? 'हिन्दी' : 'English',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: EcomColors.primary,
                          ),
                        ),
                      ),
                      onTap: () {
                        EcomLocaleController.instance.toggleLanguage();
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStoreMenuTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 19),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: EcomColors.textPrimary,
        ),
      ),
      subtitle: (subtitle != null && subtitle.isNotEmpty)
          ? Text(
              subtitle,
              style: const TextStyle(fontSize: 11.5, color: EcomColors.textSecondary),
            )
          : null,
      trailing: trailing ??
          (onTap != null
              ? const Icon(Icons.chevron_right_rounded, color: EcomColors.textSecondary, size: 20)
              : null),
    );
  }

  void _showStoreInformationSheet() {
    final s = widget.shop;
    final isHindi = EcomLocaleController.instance.isHindi;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.storefront_rounded, color: EcomColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.shopName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: EcomColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const Divider(),
                if (s.description.trim().isNotEmpty) ...[
                  Text(
                    s.description.trim(),
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: EcomColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined, size: 18, color: EcomColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        [
                          if (s.fullAddress.isNotEmpty) s.fullAddress,
                          if (s.landmark.trim().isNotEmpty) 'Landmark: ${s.landmark.trim()}',
                          if (s.jamuiArea.isNotEmpty && !s.fullAddress.contains(s.jamuiArea)) s.jamuiArea,
                        ].join('\n'),
                        style: const TextStyle(fontSize: 13, color: EcomColors.textPrimary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 18, color: EcomColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      '${EcomStrings.storeTimings}: ${s.openingTime} - ${s.closingTime}',
                      style: const TextStyle(fontSize: 13, color: EcomColors.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.local_shipping_outlined, size: 18, color: EcomColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        [
                          if (s.isHomeDeliveryActive)
                            (isHindi ? 'होम डिलीवरी उपलब्ध' : 'Home Delivery Available'),
                          if (s.isPickupActive)
                            (isHindi ? 'स्टोर पिकअप उपलब्ध' : 'Store Pickup Available'),
                          if (s.freeDeliveryThreshold > 0)
                            (isHindi
                                ? '₹${s.freeDeliveryThreshold.toInt()} से ऊपर मुफ़्त डिलीवरी'
                                : 'Free Delivery Above ₹${s.freeDeliveryThreshold.toInt()}'),
                        ].join(' • '),
                        style: const TextStyle(fontSize: 12.5, color: EcomColors.textSecondary),
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

  Widget _buildRealPromoBanner(ShopPromoBannerEntity banner) {
    return ProfessionalStorefrontPromoBanner(
      banner: banner,
      freeDeliveryThreshold: widget.shop.freeDeliveryThreshold,
      isHindi: EcomLocaleController.instance.isHindi,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rawShopLogo = widget.shop.logoUrl.isNotEmpty ? widget.shop.logoUrl : widget.shop.bannerUrl;
    final resolvedShopLogo = AppImageUrlResolver.resolve(rawShopLogo);
    final hasGenuineShopRating = widget.shop.rating > 0 && widget.shop.ratingCount > 0;
    final isOpenNow = widget.shop.isOpenNowAt();
    final activePromoBanner =
        (widget.shop.promoBanner != null && widget.shop.promoBanner!.isCurrentlyLive())
            ? widget.shop.promoBanner
            : null;

    return AnimatedBuilder(
      animation: EcomLocaleController.instance,
      builder: (context, _) {
        return BlocListener<ProfessionalCartBloc, ProfessionalCartState>(
          listener: (context, state) {
            if (state.hasShopConflict && state.conflictingShop != null && state.conflictingProduct != null) {
              _showShopConflictDialog(context, state.conflictingShop!, state.conflictingProduct!);
            }
          },
          child: Scaffold(
            backgroundColor: EcomColors.background,
            appBar: AppBar(
              backgroundColor: EcomColors.primary,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              titleSpacing: 0,
              title: Row(
                children: [
                  // Real Shop Logo Thumbnail (Matching Reference Screen 2)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 38,
                      height: 38,
                      color: Colors.white.withValues(alpha: 0.18),
                      child: resolvedShopLogo.isNotEmpty
                          ? Image.network(
                              resolvedShopLogo,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const Icon(Icons.storefront_rounded, color: Colors.white, size: 20),
                            )
                          : const Icon(Icons.storefront_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (widget.shop.isApproved) ...[
                              const Icon(
                                Icons.verified_rounded,
                                color: Color(0xFF4ADE80),
                                size: 15,
                              ),
                              const SizedBox(width: 4),
                            ],
                            Expanded(
                              child: Text(
                                widget.shop.shopName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            // Show Seller Rating ONLY when shop.rating > 0 && shop.ratingCount > 0
                            if (hasGenuineShopRating) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star_rounded, color: EcomColors.ratingGold, size: 13),
                                    const SizedBox(width: 3),
                                    Text(
                                      widget.shop.rating.toStringAsFixed(1),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      ' (${widget.shop.ratingCount})',
                                      style: const TextStyle(color: Colors.white70, fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            if (widget.shop.distanceKm != null && widget.shop.distanceKm! > 0) ...[
                              Text(
                                '${widget.shop.distanceKm!.toStringAsFixed(1)} km • ',
                                style: const TextStyle(color: Colors.white70, fontSize: 10.5),
                              ),
                            ],
                            Expanded(
                              child: Text(
                                isOpenNow
                                    ? (widget.shop.closingTime.isNotEmpty
                                        ? '${EcomStrings.shopOpen} • ${widget.shop.closingTime}'
                                        : EcomStrings.shopOpen)
                                    : EcomStrings.shopClosed,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isOpenNow ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                // Language Switcher Pill (Option A)
                InkWell(
                  onTap: _showLanguageDialog,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.translate_rounded, color: Colors.white, size: 13),
                        const SizedBox(width: 3),
                        Text(
                          EcomLocaleController.instance.isHindi ? 'हिन्दी' : 'EN',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Shop Favorites Shortcut
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.favorite_border_rounded, color: Colors.white, size: 22),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ShopFavoritesPage(shop: widget.shop),
                      ),
                    );
                  },
                ),

                // Cart Icon with Badge
                BlocBuilder<ProfessionalCartBloc, ProfessionalCartState>(
                  builder: (context, state) {
                    return Stack(
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 22),
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
                            right: 6,
                            top: 6,
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

                // Store Quick Menu Icon (Reference Screen 6 Adaptation)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 23),
                  onPressed: _showStoreQuickMenu,
                ),
              ],
            ),
            body: Stack(
              children: [
                Column(
                  children: [
                    // Search & Delivery Banner Pill (Matching Reference Screen 2)
                    Container(
                      color: EcomColors.primary,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Search Icon
                            const Icon(Icons.search_rounded, color: EcomColors.textSecondary, size: 20),
                            const SizedBox(width: 8),

                            // Search TextField
                            Expanded(
                              child: TextField(
                                onChanged: (v) => setState(() => _searchQuery = v),
                                style: const TextStyle(fontSize: 13, color: EcomColors.textPrimary),
                                decoration: InputDecoration(
                                  hintText: EcomStrings.searchStorePlaceholder,
                                  hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),

                            // Actual Delivery Estimate or Pickup Tag (only when supported by real shop settings)
                            if (widget.shop.isHomeDeliveryActive && widget.shop.estimatedDeliveryTimeMinutes > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: EcomColors.softGreen,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.delivery_dining_rounded, color: EcomColors.primary, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      EcomLocaleController.instance.isHindi
                                          ? 'डिलीवरी ${widget.shop.estimatedDeliveryTimeMinutes}-${widget.shop.estimatedDeliveryTimeMinutes + 15} मि.'
                                          : 'Delivery ${widget.shop.estimatedDeliveryTimeMinutes}-${widget.shop.estimatedDeliveryTimeMinutes + 15}m',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: EcomColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (widget.shop.isPickupActive)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: EcomColors.softGreen,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.storefront_rounded, color: EcomColors.primary, size: 13),
                                    const SizedBox(width: 4),
                                    Text(
                                      EcomStrings.pickupOption,
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: EcomColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // Real Seller Promotional Banner (NEW LOCATION: directly below Store Header & above Category Chips)
                    if (activePromoBanner != null)
                      _buildRealPromoBanner(activePromoBanner),

                    // Horizontal Category Filter Chips (Matching Reference Screen 2)
                    if (_categories.isNotEmpty)
                      Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        color: EcomColors.background,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _categories.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (ctx, i) {
                            final rawCat = _categories[i];
                            final isAllChip = i == 0 || rawCat == 'All' || rawCat == 'सभी';
                            final displayLabel = isAllChip ? EcomStrings.all : rawCat;
                            final isSel = isAllChip
                                ? (_selectedCategory.isEmpty ||
                                    _selectedCategory == 'All' ||
                                    _selectedCategory == 'सभी' ||
                                    _selectedCategory == EcomStrings.all)
                                : (rawCat == _selectedCategory);
                            return GestureDetector(
                              onTap: () => setState(() => _selectedCategory = isAllChip ? EcomStrings.all : rawCat),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                                decoration: BoxDecoration(
                                  color: isSel ? EcomColors.primary : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSel ? EcomColors.primary : EcomColors.border,
                                  ),
                                  boxShadow: isSel
                                      ? [
                                          BoxShadow(
                                            color: EcomColors.primary.withValues(alpha: 0.25),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Text(
                                  displayLabel,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                                    color: isSel ? Colors.white : EcomColors.textSecondary,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                    // Products Grid / Empty / Error State
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator(color: EcomColors.primary))
                          : _errorMessage != null
                              ? _buildErrorState(_errorMessage!)
                              : _filteredProducts.isEmpty
                                  ? _buildEmptyState()
                                  : BlocBuilder<ProfessionalCartBloc, ProfessionalCartState>(
                                      builder: (context, cartState) {
                                        return GridView.builder(
                                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 90),
                                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 2,
                                            childAspectRatio: 0.68,
                                            crossAxisSpacing: 12,
                                            mainAxisSpacing: 12,
                                          ),
                                          itemCount: _filteredProducts.length,
                                          itemBuilder: (ctx, i) {
                                            final prod = _filteredProducts[i];
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
                                    ),
                    ),
                  ],
                ),

                // Floating Bottom Cart Bar (Matching Reference Design with Multi-Vendor Isolation)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: StorefrontFloatingCartBar(browsingShop: widget.shop),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
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
              child: const Icon(Icons.search_off_rounded, size: 48, color: EcomColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              EcomStrings.noProductsFound,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: EcomColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              EcomStrings.tryAnotherCategory,
              style: const TextStyle(fontSize: 12.5, color: EcomColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 54, color: Color(0xFFE53935)),
            const SizedBox(height: 14),
            Text(
              EcomStrings.errorLoadingCatalog,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: EcomColors.textPrimary),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: EcomColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _fetchCatalog,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              label: Text(EcomStrings.retry, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
