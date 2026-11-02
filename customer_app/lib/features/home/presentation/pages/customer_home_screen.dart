import 'dart:async';

import 'package:apna_jamui_customer/features/professional_shop/data/datasources/professional_shop_remote_data_source.dart';
import 'package:apna_jamui_customer/features/professional_shop/domain/entities/professional_category_entity.dart';
import 'package:apna_jamui_customer/features/professional_shop/domain/entities/professional_shop_entity.dart';
import 'package:apna_jamui_customer/features/professional_shop/presentation/pages/professional_shop_details_page.dart';
import 'package:apna_jamui_customer/features/professional_shop/presentation/pages/professional_shops_listing_page.dart';
import 'package:apna_jamui_customer/features/professional_shop/presentation/pages/professional_customer_orders_page.dart';

import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/category_image_widget.dart';
import '../../../../core/widgets/provider_avatar_widget.dart';
import '../../../../core/widgets/provider_category_badge.dart';
import '../../../auth/presentation/bloc/customer_auth_bloc.dart';
import '../../../auth/presentation/bloc/customer_auth_state.dart';
import '../../../auth/presentation/widgets/phone_account_migration_banner.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../banners/presentation/widgets/sponsor_banner_carousel.dart';
import '../../../bookings/presentation/pages/customer_bookings_screen.dart';
import '../../../discovery/domain/entities/service_category_entity.dart';
import '../../../discovery/domain/entities/service_provider_entity.dart';
import '../../../discovery/presentation/bloc/discovery_bloc.dart';
import '../../../discovery/presentation/bloc/discovery_event.dart';
import '../../../discovery/presentation/bloc/discovery_state.dart';
import '../../../discovery/presentation/pages/all_categories_page.dart';
import '../../../discovery/presentation/pages/category_providers_page.dart';
import '../../../discovery/presentation/pages/provider_details_page.dart';
import '../../../discovery/presentation/pages/premium_category_providers_page.dart';
import '../../../../core/widgets/app_network_or_base64_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../discovery/presentation/widgets/ai_smart_search_bar.dart';
import '../../../location/domain/entities/customer_location_entity.dart';
import '../../../location/presentation/bloc/location_bloc.dart';
import '../../../location/presentation/bloc/location_state.dart';
import '../../../location/presentation/pages/location_picker_screen.dart';
import '../../../favourites/presentation/pages/favourite_providers_page.dart';
import '../../../notifications/presentation/pages/customer_notifications_page.dart';
import '../../../profile/presentation/pages/customer_profile_page.dart';
import '../../../support/presentation/pages/customer_support_page.dart';
import '../../../../core/services/provider_app_launcher_service.dart';
import '../../../../core/services/customer_app_settings_service.dart';
import '../../../../core/widgets/optional_update_banner.dart';
import '../widgets/join_provider_banner_card.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();

  static const List<Color> _pastelBgColors = [
    Color(0xFFFFF3E0), // Soft Peach
    Color(0xFFE3F2FD), // Soft Sky
    Color(0xFFFCE4EC), // Soft Pink
    Color(0xFFF3E5F5), // Soft Lavender
    Color(0xFFFFF8E1), // Soft Amber
    Color(0xFFE8F5E9), // Soft Mint
    Color(0xFFE0F7FA), // Soft Cyan
    Color(0xFFF8BBD0), // Soft Rose
  ];

  static const List<Color> _pastelIconColors = [
    Color(0xFFE65100),
    Color(0xFF1565C0),
    Color(0xFFC2185B),
    Color(0xFF7B1FA2),
    Color(0xFFF57C00),
    Color(0xFF00838F),
    Color(0xFF2E7D32),
    Color(0xFFAD1457),
  ];

  // ignore: unused_element
  IconData _getCategoryIcon(String iconName) {
    switch (iconName.toLowerCase().trim()) {
      case 'ac_unit':
      case 'ac':
      case 'hvac':
        return Icons.ac_unit_rounded;
      case 'cleaning_services':
      case 'cleaning':
      case 'clean':
        return Icons.cleaning_services_rounded;
      case 'format_paint':
      case 'paint':
      case 'painting':
        return Icons.format_paint_rounded;
      case 'bolt':
      case 'electric':
      case 'electrician':
        return Icons.bolt_rounded;
      case 'plumbing':
      case 'plumber':
      case 'water_drop':
        return Icons.plumbing_rounded;
      case 'handyman':
      case 'build':
      case 'repair':
      case 'home_repair_service':
        return Icons.home_repair_service_rounded;
      case 'pest_control':
      case 'pest':
        return Icons.pest_control_rounded;
      case 'carpenter':
      case 'carpentry':
        return Icons.carpenter_rounded;
      case 'two_wheeler':
      case 'bike':
      case 'motorcycle':
        return Icons.two_wheeler_rounded;
      case 'local_laundry_service':
      case 'laundry':
        return Icons.local_laundry_service_rounded;
      case 'content_cut':
      case 'salon':
      case 'unisex_salon':
      case 'scissors':
      case 'hair':
      case 'barber':
        return Icons.content_cut_rounded;
      default:
        return Icons.handyman_rounded;
    }
  }

  AppUpdateDecision? _updateDecision;
  final ProfessionalShopRemoteDataSource _professionalDataSource = ProfessionalShopRemoteDataSource();
  List<ProfessionalCategoryEntity> _professionalCategories = [];
  List<ProfessionalShopEntity> _nearbyProfessionalShops = [];
  bool _isLoadingProfessional = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    _checkAppUpdateStatus();
    _fetchProfessionalData();
  }

  Future<void> _fetchProfessionalData({double? lat, double? lng, String? area}) async {
    if (!mounted) return;
    setState(() => _isLoadingProfessional = true);
    try {
      double? customerLat = lat;
      double? customerLng = lng;
      String? customerArea = area;
      if (customerLat == null || customerLng == null) {
        try {
          final discState = context.read<DiscoveryBloc>().state;
          if (discState is DiscoveryLoaded) {
            customerLat = discState.customerLatitude;
            customerLng = discState.customerLongitude;
            customerArea = discState.customerAreaName;
          }
        } catch (_) {}
      }

      final cats = await _professionalDataSource.fetchProfessionalCategories();
      final shops = await _professionalDataSource.fetchNearbyShops(
        customerLat: customerLat,
        customerLng: customerLng,
        jamuiArea: customerArea,
        limit: 6,
      );
      if (mounted) {
        setState(() {
          _professionalCategories = cats;
          _nearbyProfessionalShops = shops;
          _isLoadingProfessional = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingProfessional = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAppUpdateStatus();
    }
  }

  Future<void> _checkAppUpdateStatus() async {
    try {
      final decision = await CustomerAppSettingsService().evaluateUpdateStatus();
      if (!mounted) return;

      if (decision.isOptional) {
        setState(() => _updateDecision = decision);
      } else {
        if (_updateDecision != null) {
          setState(() => _updateDecision = null);
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      if (maxScroll > 0 && currentScroll >= maxScroll * 0.85) {
        final state = context.read<DiscoveryBloc>().state;
        if (state is DiscoveryLoaded &&
            !state.isLoadingMore &&
            state.hasMoreProviders) {
          context.read<DiscoveryBloc>().add(const LoadMoreProvidersEvent());
        }
      }
    }
  }

  Future<void> _openLiveLocationPicker(BuildContext context) async {
    final result = await Navigator.push<CustomerLocationEntity>(
      context,
      MaterialPageRoute(
        builder: (_) => const LocationPickerScreen(isFromOnboarding: false),
      ),
    );
    if (result != null && context.mounted) {
      final pinOrDistrict = result.pincode.isNotEmpty
          ? result.pincode
          : (result.district.isNotEmpty ? result.district : result.city);
      final areaName = result.placeName.isNotEmpty
          ? (pinOrDistrict.isNotEmpty ? '${result.placeName} ($pinOrDistrict)' : result.placeName)
          : (result.formattedAddress.isNotEmpty
              ? result.formattedAddress
              : 'GPS (${result.latitude.toStringAsFixed(4)}, ${result.longitude.toStringAsFixed(4)})');
      context.read<DiscoveryBloc>().add(
        UpdateCustomerLocationEvent(
          latitude: result.latitude,
          longitude: result.longitude,
          areaName: areaName,
        ),
      );
    }
  }

  Future<void> _refreshGPSLocation(BuildContext context) async {
    _openLiveLocationPicker(context);
  }

  Widget _buildCustomerDrawer(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isGuest = user == null;
    final authState = context.read<CustomerAuthBloc>().state;
    final customer = authState is CustomerAuthenticatedState ? authState.customer : null;

    final displayName = customer?.fullName.isNotEmpty == true
        ? customer!.fullName
        : (user?.displayName?.isNotEmpty == true
            ? user!.displayName!
            : (user?.phoneNumber?.isNotEmpty == true ? user!.phoneNumber! : 'ग्राहक (Guest)'));

    final userPhone = user?.phoneNumber ?? '';
    final subtitleText = isGuest
        ? 'अतिथि ग्राहक • Jamui Services'
        : (userPhone.isNotEmpty
            ? userPhone
            : (customer?.phoneNumber.isNotEmpty == true
                ? customer!.phoneNumber
                : (customer?.email?.isNotEmpty == true ? customer!.email! : 'सत्यापित ग्राहक')));

    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          // Drawer Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(
              top: 50,
              bottom: 20,
              left: 20,
              right: 20,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                const AppLogo(
                  size: 54,
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                  showShadow: true,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitleText,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Drawer Navigation List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildDrawerTile(
                  icon: Icons.home_rounded,
                  title: 'मुख्य पृष्ठ (Home)',
                  onTap: () => Navigator.pop(context),
                ),
                _buildDrawerTile(
                  icon: Icons.category_rounded,
                  title: 'सभी श्रेणियाँ (All Categories)',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BlocProvider.value(
                          value: context.read<DiscoveryBloc>(),
                          child: const AllCategoriesPage(),
                        ),
                      ),
                    );
                  },
                ),
                _buildDrawerTile(
                  icon: Icons.history_rounded,
                  title: 'मेरी बुकिंग्स व सेवा इतिहास (History)',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CustomerBookingsScreen(),
                      ),
                    );
                  },
                ),
                _buildDrawerTile(
                  icon: Icons.shopping_bag_rounded,
                  title: 'मेरे दुकान ऑर्डर्स (My Pro Orders)',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProfessionalCustomerOrdersPage(),
                      ),
                    );
                  },
                ),
                _buildDrawerTile(
                  icon: Icons.favorite_rounded,
                  title: 'पसंदीदा कारीगर (Saved Providers)',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FavouriteProvidersPage(),
                      ),
                    );
                  },
                ),
                _buildDrawerTile(
                  icon: Icons.notifications_rounded,
                  title: 'सूचनाएं (Notifications)',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CustomerNotificationsPage(),
                      ),
                    );
                  },
                ),
                _buildDrawerTile(
                  icon: Icons.person_rounded,
                  title: 'मेरी प्रोफाइल (My Profile)',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CustomerProfilePage(),
                      ),
                    );
                  },
                ),
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A8A).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF1E3A8A).withValues(alpha: 0.2),
                    ),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A8A).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.handyman_rounded,
                        color: Color(0xFF1E3A8A),
                        size: 18,
                      ),
                    ),
                    title: const Text(
                      'कारीगर / प्रोवाइडर बनें',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    subtitle: const Text(
                      '0% कमीशन • Jamui Services Partner',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBBF24),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Join >',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      ProviderAppLauncherService.showJoinProviderModal(context);
                    },
                  ),
                ),
                const Divider(),
                _buildDrawerTile(
                  icon: Icons.headset_mic_rounded,
                  title: 'सहायता एवं संपर्क (Help & Support)',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CustomerSupportPage(),
                      ),
                    );
                  },
                ),
                _buildDrawerTile(
                  icon: Icons.policy_rounded,
                  title: 'नियम व गोपनीयता नीति (Terms & Privacy)',
                  onTap: () {
                    Navigator.pop(context);
                    _showTermsDialog(context);
                  },
                ),
                _buildDrawerTile(
                  icon: Icons.info_outline_rounded,
                  title: 'जमुई सर्विस के बारे में (About Us)',
                  onTap: () {
                    Navigator.pop(context);
                    _showAboutDialog(context);
                  },
                ),
              ],
            ),
          ),

          // Drawer Footer
          Container(
            padding: const EdgeInsets.all(16),
            child: isGuest
                ? ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.login_rounded, size: 18),
                    label: const Text('लॉगिन करें'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  )
                : OutlinedButton.icon(
                    onPressed: () => _confirmDrawerSignOut(context),
                    icon: const Icon(
                      Icons.logout_rounded,
                      size: 18,
                      color: Colors.red,
                    ),
                    label: const Text(
                      'लॉगआउट',
                      style: TextStyle(color: Colors.red),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _confirmDrawerSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text(
              'लॉगआउट की पुष्टि',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'क्या आप वाकई अपने खाते से लॉगआउट करना चाहते हैं?',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('रद्द करें (Cancel)'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
              await FirebaseAuth.instance.signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('हाँ, लॉगआउट करें'),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary, size: 22),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      onTap: onTap,
      dense: true,
      horizontalTitleGap: 12,
    );
  }

  void _showTermsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('नियम एवं गोपनीयता नीति (Terms & Privacy)'),
        content: const SingleChildScrollView(
          child: Text(
            'JAMUI SERVICE जमुई जिले के स्थानीय सेवा प्रदाताओं और ग्राहकों को जोड़ने वाला निष्पक्ष मंच है।\n\n'
            '1. ग्राहकों से कोई बुकिंग कमीशन नहीं लिया जाता है।\n'
            '2. कार्य और भुगतान का अंतिम समझौता ग्राहक और कारीगर के बीच होता है।\n'
            '3. ग्राहकों का व्यक्तिगत डेटा पूरी तरह सुरक्षित रखा जाता है।\n\n'
            'JAMUI SERVICE, Jamui (Bihar) - 811307',
            style: TextStyle(fontSize: 13, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              launchUrl(
                Uri.parse('https://jamui-services.web.app/#privacy'),
                mode: LaunchMode.externalApplication,
              );
            },
            child: const Text('पूरी प्राइवेसी पॉलिसी पढ़ें'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ठीक है'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('JAMUI SERVICE — स्थानीय सेवा मंच'),
        content: const Text(
          'जमुई सर्विस हमारे अपने शहर जमुई का डिजिटल सर्विस हब है।\n\n'
          'वर्जन: 2.0.0 (Production Ready)\n'
          'लोकल कारीगरों को सशक्त बनाना और ग्राहकों को तुरंत विश्वसनीय सेवाएं उपलब्ध कराना हमारा मुख्य उद्देश्य है।',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('बंद करें'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      drawer: _buildCustomerDrawer(context),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
            tooltip: 'मेनू (Menu)',
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: BlocBuilder<DiscoveryBloc, DiscoveryState>(
          builder: (context, state) {
            String areaName = state is DiscoveryLoaded
                ? state.customerAreaName
                : 'स्थान चुनें (GPS)';
            if (areaName == 'स्थान चुनें (GPS)') {
              final locState = context.watch<LocationBloc>().state;
              if (locState is LocationLoaded &&
                  locState.location.placeName.isNotEmpty) {
                areaName = locState.location.placeName;
              }
            }

            return GestureDetector(
              onTap: () => _refreshGPSLocation(context),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppLogo(
                    size: 34,
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'JAMUI SERVICES',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                areaName,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(
                              Icons.arrow_drop_down,
                              size: 14,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.notifications_none_rounded,
                  color: Colors.white,
                  size: 26,
                ),
                Positioned(
                  right: 1,
                  top: 1,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
            tooltip: 'सूचनाएं (Notifications)',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CustomerNotificationsPage(),
                ),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: BlocListener<LocationBloc, LocationState>(
        listener: (context, locState) {
          if (locState is LocationLoaded &&
              locState.location.placeName.isNotEmpty) {
            final discState = context.read<DiscoveryBloc>().state;
            if (discState is DiscoveryLoaded) {
              final latDiff = discState.customerLatitude != locState.location.latitude;
              final lngDiff = discState.customerLongitude != locState.location.longitude;
              if (discState.customerLatitude == null || latDiff || lngDiff) {
                context.read<DiscoveryBloc>().add(
                  UpdateCustomerLocationEvent(
                    latitude: locState.location.latitude,
                    longitude: locState.location.longitude,
                    areaName: locState.location.placeName,
                  ),
                );
                _fetchProfessionalData(
                  lat: locState.location.latitude,
                  lng: locState.location.longitude,
                  area: locState.location.placeName,
                );
              }
            }
          }
        },
        child: RefreshIndicator(
          onRefresh: () async {
            _checkAppUpdateStatus();
            _fetchProfessionalData();
            final state = context.read<DiscoveryBloc>().state;
            if (state is DiscoveryLoaded) {
              context.read<DiscoveryBloc>().add(
                LoadDiscoveryDataEvent(
                  customerLatitude: state.customerLatitude,
                  customerLongitude: state.customerLongitude,
                  customerAreaName: state.customerAreaName,
                ),
              );
            } else {
              context.read<DiscoveryBloc>().add(const LoadDiscoveryDataEvent());
            }
          },
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 14.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 0. Optional App Update Banner if supported update available
                if (_updateDecision != null && _updateDecision!.isOptional)
                  OptionalUpdateBanner(
                    decision: _updateDecision!,
                    onDismiss: () => setState(() => _updateDecision = null),
                  ),

                // Account Migration Banner for existing Phone Auth users
                const PhoneAccountMigrationBanner(),

                // 1. Prominent Search Bar directly below App Bar
                const AISmartSearchBar(
                  hintText: 'Search services or karigars...',
                ),

                const SizedBox(height: 14),

                // 2. Promotional Banner / Carousel Section (Real Firestore Banners or Valid On-Demand Hero)
                _buildPromotionalBannerSection(context),

                const SizedBox(height: 14),

                // 2.1 Professional Categories Section (Matching Reference Image)
                _buildProfessionalCategoriesSection(context),

                const SizedBox(height: 14),

                // 2.2 Nearby Local Professional Shops (Matching Reference Image)
                _buildNearbyProfessionalShopsSection(context),

                const SizedBox(height: 14),

                // 2.5 Admin-Configured Premium Services Section
                _buildPremiumServicesSection(context),

                const SizedBox(height: 14),

                // 3. Services Header (Reference Image Style)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Services',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BlocProvider.value(
                              value: context.read<DiscoveryBloc>(),
                              child: const AllCategoriesPage(),
                            ),
                          ),
                        );
                      },
                      child: const Text(
                        'See All >',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // 4. Real Service Categories Grid (5 columns on standard mobile screens, pastel cards)
                BlocBuilder<DiscoveryBloc, DiscoveryState>(
                  builder: (context, state) {
                    return _buildRealCategoriesGrid(context, state);
                  },
                ),

                const SizedBox(height: 18),

                // 5. Top Service Providers Section (Reference Image Layout: Side-by-side cards)
                BlocBuilder<DiscoveryBloc, DiscoveryState>(
                  builder: (context, state) {
                    return _buildTopServiceProvidersSection(context, state);
                  },
                ),

                // 6. Trust Badges Bar directly below Top Providers (Reference Image: Verified | Quick Booking | Secure)
                _buildTrustBadgesBar(),

                const SizedBox(height: 10),

                // 7. Dynamic Area Filter Chips (Jamui Areas from Real Active Providers)
                BlocBuilder<DiscoveryBloc, DiscoveryState>(
                  builder: (context, state) {
                    final selectedArea = state is DiscoveryLoaded
                        ? state.selectedArea
                        : 'सभी इलाके';
                    final providers = state is DiscoveryLoaded
                        ? state.providers
                        : <ServiceProviderEntity>[];
                    final dynamicAreas = [
                      'सभी इलाके',
                      ...providers
                          .map((p) => p.jamuiArea.trim())
                          .where((a) => a.isNotEmpty)
                          .toSet(),
                    ];

                    if (dynamicAreas.length <= 1) {
                      return const SizedBox.shrink();
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: SizedBox(
                        height: 38,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: dynamicAreas.length,
                          itemBuilder: (context, index) {
                            final area = dynamicAreas[index];
                            final isSelected = selectedArea == area;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: FilterChip(
                                selected: isSelected,
                                label: Text(area),
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                ),
                                selectedColor: AppColors.accent,
                                backgroundColor: Colors.white,
                                onSelected: (_) {
                                  context.read<DiscoveryBloc>().add(
                                    SelectAreaFilterEvent(area),
                                  );
                                },
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),

                // 8. All Verified Providers Header
                BlocBuilder<DiscoveryBloc, DiscoveryState>(
                  builder: (context, state) {
                    final providers = state is DiscoveryLoaded
                        ? state.providers
                        : <ServiceProviderEntity>[];
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'सभी वेरिफाइड कारीगर (${providers.length})',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),

                // 9. Real Providers List (2-column grid with identical exact card design, zero squishing)
                BlocBuilder<DiscoveryBloc, DiscoveryState>(
                  builder: (context, state) {
                    if (state is DiscoveryLoading &&
                        state is! DiscoveryLoaded) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    final providers = state is DiscoveryLoaded
                        ? state.providers
                        : <ServiceProviderEntity>[];

                    // Clean Empty State (NO DUMMY DATA)
                    if (providers.isEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 56,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'कोई कारीगर उपलब्ध नहीं है',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'आपके आसपास इस श्रेणी या इलाके में अभी कोई सक्रिय वेरिफाइड कारीगर उपलब्ध नहीं है।',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: () {
                                context.read<DiscoveryBloc>().add(
                                  const SelectCategoryFilterEvent('all'),
                                );
                                context.read<DiscoveryBloc>().add(
                                  const SelectAreaFilterEvent('सभी इलाके'),
                                );
                              },
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('सभी सेवाएं देखें'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  ProviderAppLauncherService.showJoinProviderModal(
                                    context,
                                  ),
                              icon: const Icon(
                                Icons.handyman_rounded,
                                size: 16,
                                color: Color(0xFF1E3A8A),
                              ),
                              label: const Text(
                                'क्या आप सर्विस प्रोवाइडर हैं? यहाँ जुड़ें',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E3A8A),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color(0xFF1E3A8A),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final isLoadingMore =
                        state is DiscoveryLoaded && state.isLoadingMore;
                    final hasMore =
                        state is DiscoveryLoaded && state.hasMoreProviders;

                    return Column(
                      children: [
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: providers.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 0.84,
                              ),
                          itemBuilder: (context, index) {
                            final p = providers[index];
                            return _buildExactProviderCard(context, p);
                          },
                        ),
                        if (isLoadingMore) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.0),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'और कारीगर लोड हो रहे हैं...',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ] else if (!hasMore && providers.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20.0),
                            child: Center(
                              child: Text(
                                '✓ सभी उपलब्ध कारीगर दिखा दिए गए हैं',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        const JoinProviderBannerCard(),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Top Service Providers Section (Matches Reference Image with horizontal cards)
  Widget _buildTopServiceProvidersSection(
    BuildContext context,
    DiscoveryState state,
  ) {
    final providers = state is DiscoveryLoaded
        ? state.providers
        : <ServiceProviderEntity>[];
    if (providers.isEmpty) {
      return const SizedBox.shrink();
    }

    final topProviders = providers.take(8).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Top Service Providers',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            GestureDetector(
              onTap: () {
                if (_scrollController.hasClients) {
                  _scrollController.animateTo(
                    _scrollController.position.maxScrollExtent * 0.45,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOut,
                  );
                }
              },
              child: const Text(
                'See All >',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 198,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: topProviders.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              return SizedBox(
                width: 160,
                child: _buildExactProviderCard(context, topProviders[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Trust Badges Bar directly below Top Providers
  /// Verified Professionals | Quick Booking | Secure & Safe (Reference Image Style)
  Widget _buildTrustBadgesBar() {
    return Container(
      margin: const EdgeInsets.only(top: 14, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.verified_user_rounded,
                  color: Color(0xFF16A34A),
                  size: 15,
                ),
                const SizedBox(width: 4),
                const Flexible(
                  child: Text(
                    'Verified Professionals',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 18,
            color: const Color(0xFFE2E8F0),
            margin: const EdgeInsets.symmetric(horizontal: 4),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.bolt_rounded,
                  color: AppColors.accent,
                  size: 16,
                ),
                const SizedBox(width: 3),
                const Flexible(
                  child: Text(
                    'Quick Booking',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 18,
            color: const Color(0xFFE2E8F0),
            margin: const EdgeInsets.symmetric(horizontal: 4),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.shield_rounded,
                  color: Color(0xFF2563EB),
                  size: 15,
                ),
                const SizedBox(width: 4),
                const Flexible(
                  child: Text(
                    'Secure & Safe',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Exact Provider Card matching Reference Image:
  /// - Circular Avatar on left
  /// - Name (bold, 2 lines) & Category on right
  /// - Star rating row: ★ 4.8 (128)
  /// - Location row: 📍 Jamui, Bihar
  /// - Bottom row: ₹150 Starting on left, circular green phone call button on right
  Widget _buildExactProviderCard(
    BuildContext context,
    ServiceProviderEntity provider,
  ) {
    final displayName = provider.fullName.isNotEmpty
        ? provider.fullName
        : provider.businessName;
    final displayService = provider.resolvedCategoryTitle;
    final locationText = provider.jamuiArea.trim().isNotEmpty
        ? '${provider.jamuiArea.trim()}, Bihar'
        : 'Jamui, Bihar';

    // Formatted distance badge from precalculated provider distance
    String? distanceBadge;
    if (provider.distanceKm != null) {
      distanceBadge = provider.distanceKm! < 1.0
          ? '${(provider.distanceKm! * 1000).round()} m'
          : '${provider.distanceKm!.toStringAsFixed(1)} km';
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: context.read<DiscoveryBloc>(),
              child: ProviderDetailsPage(provider: provider),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Circular Avatar (left) + Provider Name & Category (right)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ProviderAvatarWidget(
                  provider: provider,
                  size: 38,
                  isCircular: true,
                  showVerifiedBadge: false,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          height: 1.15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      ProviderCategoryBadge(
                        categoryTitle: displayService,
                        additionalCategoriesCount:
                            provider.selectedCategoryIds.length > 1
                                ? provider.selectedCategoryIds.length - 1
                                : 0,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Row 2: Star rating + Rating score + (review count)
            Row(
              children: [
                const Icon(
                  Icons.star_rounded,
                  color: AppColors.accent,
                  size: 15,
                ),
                const SizedBox(width: 3),
                Text(
                  provider.rating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  provider.ratingCount > 0
                      ? '(${provider.ratingCount})'
                      : '(0)',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Row 3: Location pin icon + Jamui, Bihar + Approximate Distance Badge
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.grey.shade500, size: 13),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    locationText,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (distanceBadge != null) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 0.8),
                    ),
                    child: Text(
                      distanceBadge,
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const Spacer(),

            // Row 4: Price on left + Green call button on right
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: provider.visitingCharge > 0
                              ? '₹${provider.visitingCharge.toInt()} '
                              : 'निःशुल्क ',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                        TextSpan(
                          text: provider.visitingCharge > 0 ? 'Starting' : '',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _handleCallProvider(context, provider),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Color(0xFFDCFCE7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.phone,
                        color: Color(0xFF16A34A),
                        size: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Launch Provider Telephone Call via Native Dialer
  Future<void> _handleCallProvider(
    BuildContext context,
    ServiceProviderEntity provider,
  ) async {
    final phone = provider.phoneNumber.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('फोन नंबर उपलब्ध नहीं है')));
      return;
    }
    final uri = Uri.parse('tel:$phone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('कॉल शुरू नहीं की जा सकी')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('कॉल त्रुटि: $e')));
      }
    }
  }

  Widget _buildPromotionalBannerSection(BuildContext context) {
    return SponsorBannerCarousel(
      fallbackHeroCard: _buildNonPromotionalHeroCard(context),
    );
  }

  Widget _buildProfessionalCategoriesSection(BuildContext context) {
    if (_isLoadingProfessional) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Professional Categories',
            style: TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 96,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
              ),
            ),
          ),
        ],
      );
    }

    if (_professionalCategories.isEmpty) {
      return const SizedBox.shrink();
    }

    final categories = _professionalCategories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Professional Categories',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ProfessionalShopsListingPage(category: null),
                  ),
                );
              },
              child: const Text(
                'View all',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 102,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (ctx, i) {
              final cat = categories[i];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfessionalShopsListingPage(category: cat),
                    ),
                  );
                },
                child: SizedBox(
                  width: 76,
                  child: Column(
                    children: [
                      _buildCategoryIconVisual(cat, i),
                      const SizedBox(height: 6),
                      Text(
                        cat.displayName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryIconVisual(ProfessionalCategoryEntity cat, int index) {
    if (cat.iconUrl.isNotEmpty && (cat.iconUrl.startsWith('http://') || cat.iconUrl.startsWith('https://'))) {
      return Container(
        width: 60,
        height: 60,
        decoration: const BoxDecoration(
          color: Color(0xFFF1F5F9),
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: Image.network(
            cat.iconUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallbackCategoryIcon(cat, index),
          ),
        ),
      );
    }
    return _buildFallbackCategoryIcon(cat, index);
  }

  Widget _buildFallbackCategoryIcon(ProfessionalCategoryEntity cat, int index) {
    final title = (cat.titleEnglish.isNotEmpty ? cat.titleEnglish : cat.displayName).toLowerCase();
    final slug = cat.slug.toLowerCase();
    final id = cat.id.toLowerCase();

    IconData icon;
    Color bgColor;
    Color iconColor;

    if (title.contains('groc') || slug.contains('groc') || id.contains('groc') || cat.displayName.contains('किराना') || cat.displayName.contains('राशन')) {
      icon = Icons.shopping_basket_rounded;
      bgColor = const Color(0xFFFFF3E0);
      iconColor = const Color(0xFFE65100);
    } else if (title.contains('sabji') || title.contains('veg') || slug.contains('veg') || id.contains('veg') || cat.displayName.contains('सब्जी')) {
      icon = Icons.eco_rounded;
      bgColor = const Color(0xFFE8F5E9);
      iconColor = const Color(0xFF2E7D32);
    } else if (title.contains('fruit') || slug.contains('fruit') || id.contains('fruit') || cat.displayName.contains('फल')) {
      icon = Icons.apple_rounded;
      bgColor = const Color(0xFFFFEBEE);
      iconColor = const Color(0xFFC62828);
    } else if (title.contains('meat') || title.contains('chicken') || title.contains('fish') || cat.displayName.contains('मीट') || cat.displayName.contains('मांस')) {
      icon = Icons.restaurant_menu_rounded;
      bgColor = const Color(0xFFFBE9E7);
      iconColor = const Color(0xFFD84315);
    } else if (title.contains('baker') || title.contains('cake') || title.contains('bread') || cat.displayName.contains('बेकरी')) {
      icon = Icons.bakery_dining_rounded;
      bgColor = const Color(0xFFFFF8E1);
      iconColor = const Color(0xFFF57F17);
    } else if (title.contains('dairy') || title.contains('milk') || cat.displayName.contains('डेयरी') || cat.displayName.contains('दूध')) {
      icon = Icons.local_drink_rounded;
      bgColor = const Color(0xFFE1F5FE);
      iconColor = const Color(0xFF0288D1);
    } else if (title.contains('cloth') || title.contains('garment') || title.contains('wear') || cat.displayName.contains('कपड़े')) {
      icon = Icons.checkroom_rounded;
      bgColor = const Color(0xFFE0F2F1);
      iconColor = const Color(0xFF00796B);
    } else if (title.contains('footwear') || title.contains('shoe') || cat.displayName.contains('चप्पल') || cat.displayName.contains('जूते')) {
      icon = Icons.hiking_rounded;
      bgColor = const Color(0xFFEDE7F6);
      iconColor = const Color(0xFF512DA8);
    } else if (title.contains('cosmetic') || title.contains('beauty') || cat.displayName.contains('ब्यूटी')) {
      icon = Icons.spa_rounded;
      bgColor = const Color(0xFFFCE4EC);
      iconColor = const Color(0xFFC2185B);
    } else if (title.contains('elect') || title.contains('mobile') || cat.displayName.contains('इलेक्ट्रॉनिक')) {
      icon = Icons.devices_rounded;
      bgColor = const Color(0xFFE0F7FA);
      iconColor = const Color(0xFF0097A7);
    } else {
      const palette = [
        Color(0xFFFFF3E0),
        Color(0xFFE8F5E9),
        Color(0xFFFFEBEE),
        Color(0xFFEDE7F6),
        Color(0xFFE3F2FD),
      ];
      const iconPalette = [
        Color(0xFFE65100),
        Color(0xFF2E7D32),
        Color(0xFFC62828),
        Color(0xFF512DA8),
        Color(0xFF0288D1),
      ];
      icon = Icons.storefront_rounded;
      bgColor = palette[index % palette.length];
      iconColor = iconPalette[index % iconPalette.length];
    }

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(icon, color: iconColor, size: 28),
      ),
    );
  }

  Widget _buildNearbyProfessionalShopsSection(BuildContext context) {
    if (_isLoadingProfessional) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nearby Professional Shops',
            style: TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 110,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
              ),
            ),
          ),
        ],
      );
    }

    if (_nearbyProfessionalShops.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nearby Professional Shops',
            style: TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.storefront_outlined, size: 28, color: Colors.grey.shade400),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'No professional shops available near you.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final shops = _nearbyProfessionalShops;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Nearby Professional Shops',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ProfessionalShopsListingPage(category: null),
                  ),
                );
              },
              child: const Text(
                'See All',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 116,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: shops.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (ctx, i) {
              final s = shops[i];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfessionalShopDetailsPage(shop: s),
                    ),
                  );
                },
                child: Container(
                  width: 250,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 58,
                          height: 58,
                          color: const Color(0xFFF1F5F9),
                          child: s.logoUrl.isNotEmpty
                              ? Image.network(
                                  s.logoUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.storefront_rounded,
                                    color: Color(0xFF2E7D32),
                                    size: 30,
                                  ),
                                )
                              : const Icon(
                                  Icons.storefront_rounded,
                                  color: Color(0xFF2E7D32),
                                  size: 30,
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    s.shopName,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E293B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (s.isVerified)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 3),
                                    child: Icon(Icons.verified_rounded, color: Color(0xFF2E7D32), size: 14),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                if (s.rating > 0 && s.ratingCount > 0) ...[
                                  const Icon(Icons.star_rounded, color: Color(0xFFFFA000), size: 14),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${s.rating.toStringAsFixed(1)} (${s.ratingCount})',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                  ),
                                  const Text(' • ', style: TextStyle(color: Colors.grey)),
                                ],
                                Expanded(
                                  child: Text(
                                    s.distanceKm != null
                                        ? '${s.distanceKm!.toStringAsFixed(1)} km'
                                        : (s.jamuiArea.isNotEmpty ? s.jamuiArea : 'Jamui'),
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  'Min ₹${s.minOrderAmount.toInt()} • ${s.deliveryCharges == 0 ? "Free Del." : "₹${s.deliveryCharges.toInt()} Del."}',
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: s.isOpen ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    s.isOpen ? 'Open' : 'Closed',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: s.isOpen ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
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
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumServicesSection(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('premium_categories')
          .where('isActive', isEqualTo: true)
          .where('showOnHome', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final rawDocs = snapshot.data!.docs.map((d) {
          final data = d.data() as Map<String, dynamic>;
          return {
            'id': d.id,
            ...data,
          };
        }).toList();

        // Sort by priority ascending (1 first, then 2, etc.)
        rawDocs.sort((a, b) {
          final pA = (a['priority'] as num?)?.toInt() ?? 999;
          final pB = (b['priority'] as num?)?.toInt() ?? 999;
          return pA.compareTo(pB);
        });

        final displayDocs = List<Map<String, dynamic>>.from(rawDocs);
        if (displayDocs.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.workspace_premium, color: AppColors.gold, size: 22),
                    SizedBox(width: 6),
                    Text(
                      'Premium Categories',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AllCategoriesPage(),
                      ),
                    );
                  },
                  child: const Text(
                    'View all',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 122,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: displayDocs.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final cat = displayDocs[index];
                  final title = cat['customTitle']?.toString() ??
                      cat['title']?.toString() ??
                      cat['categoryName']?.toString() ??
                      'प्रीमियम सेवा';
                  final imgUrl = cat['imageUrl']?.toString() ?? '';
                  final isUnisex = cat['categoryId'] == 'unisex_salon' ||
                      cat['isNew'] == true ||
                      title.toLowerCase().contains('unisex') ||
                      title.contains('यूनिसेक्स');

                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PremiumCategoryProvidersPage(premiumCategory: cat),
                        ),
                      );
                    },
                    child: SizedBox(
                      width: 95,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              // Main Box Container
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: isUnisex ? const Color(0xFF18181B) : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isUnisex ? const Color(0xFFF43F5E) : AppColors.gold.withValues(alpha: 0.35),
                                    width: isUnisex ? 1.8 : 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isUnisex
                                          ? const Color(0xFFF43F5E).withValues(alpha: 0.25)
                                          : Colors.black.withValues(alpha: 0.05),
                                      blurRadius: isUnisex ? 8 : 6,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: isUnisex
                                      ? const Icon(
                                          Icons.content_cut_rounded,
                                          color: Color(0xFFF43F5E),
                                          size: 30,
                                        )
                                      : ClipOval(
                                          child: imgUrl.isNotEmpty
                                              ? SizedBox(
                                                  width: 50,
                                                  height: 50,
                                                  child: AppNetworkOrBase64Image(imageUrl: imgUrl, fit: BoxFit.cover),
                                                )
                                              : const Icon(Icons.workspace_premium, color: AppColors.gold, size: 28),
                                        ),
                                ),
                              ),

                              // "NEW" Badge on top-right for Unisex Salon (as in reference image)
                              if (isUnisex)
                                Positioned(
                                  top: -6,
                                  right: -4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.red.withValues(alpha: 0.4),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: const Text(
                                      'NEW',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 7),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Text(
                              title,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: isUnisex ? const Color(0xFF0F172A) : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNonPromotionalHeroCard(BuildContext context) {
    // Valid Non-Promotional On-Demand Hero Card (Reference Image Visual Style)
    // Warm Peach / Cream background with bold typography and Book Now button
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      padding: const EdgeInsets.fromLTRB(16, 16, 14, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFF7ED), // Soft Warm Cream
            Color(0xFFFED7AA), // Light Amber Peach
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFED7AA), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Reliable Services',
                      style: TextStyle(
                        fontSize: 18.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFEA580C),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const Text(
                      'At Your Doorstep',
                      style: TextStyle(
                        fontSize: 18.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Find trusted professionals\nfor every need',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF475569),
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BlocProvider.value(
                              value: context.read<DiscoveryBloc>(),
                              child: const AllCategoriesPage(),
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text(
                        'Book Now',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: Center(
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.65),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFF97316)
                            .withValues(alpha: 0.25),
                        width: 2,
                      ),
                    ),
                    child: const Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.engineering_rounded,
                          size: 46,
                          color: AppColors.accent,
                        ),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Icon(
                            Icons.verified_rounded,
                            size: 18,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Pagination Dots from Reference Image
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 14,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 5,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 5,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRealCategoriesGrid(BuildContext context, DiscoveryState state) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth >= 600 ? 6 : 4;

    if (state is DiscoveryLoading && state is! DiscoveryLoaded) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: crossAxisCount * 2,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.76,
        ),
        itemBuilder: (context, index) {
          return Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _pastelBgColors[index % _pastelBgColors.length],
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 10,
                width: 44,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          );
        },
      );
    }

    final categories = state is DiscoveryLoaded
        ? state.categories.where((c) => c.isActive && !c.isPremiumCategory).toList()
        : <ServiceCategoryEntity>[];

    // Real Empty State (Zero Fake Categories)
    if (categories.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Column(
          children: [
            Icon(Icons.category_outlined, size: 36, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'कोई श्रेणी उपलब्ध नहीं है',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    // Display 8 active categories (2 clean rows of 4) or 12 on tablet
    final maxCount = crossAxisCount * 2;
    final displayCategories = categories.take(maxCount).toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: displayCategories.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.76,
      ),
      itemBuilder: (context, index) {
        final cat = displayCategories[index];
        final bgColor = _pastelBgColors[index % _pastelBgColors.length];
        final iconColor = _pastelIconColors[index % _pastelIconColors.length];
        final label = cat.titleEnglish.isNotEmpty
            ? cat.titleEnglish
            : cat.titleHindi;

        return GestureDetector(
          onTap: () {
            if (cat.isPremiumCategory) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PremiumCategoryProvidersPage(
                    premiumCategory: {
                      'categoryId': cat.id,
                      'categoryName': cat.titleEnglish.isNotEmpty ? cat.titleEnglish : cat.titleHindi,
                      'customTitle': cat.titleHindi.isNotEmpty ? cat.titleHindi : cat.titleEnglish,
                      'imageUrl': cat.imageUrl,
                    },
                  ),
                ),
              );
              return;
            }

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: context.read<DiscoveryBloc>(),
                  child: CategoryProvidersPage(category: cat),
                ),
              ),
            );
          },
          child: Column(
            children: [
              CategoryImageWidget(
                imageUrl: cat.imageUrl,
                categoryTitle: cat.titleEnglish.isNotEmpty ? cat.titleEnglish : cat.titleHindi,
                iconName: cat.iconName,
                size: 56,
                imageSize: 44,
                backgroundColor: bgColor,
                iconColor: iconColor,
                borderRadius: BorderRadius.circular(16),
                fit: BoxFit.cover,
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.15,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
