import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/datasources/professional_provider_remote_data_source.dart';
import '../../domain/entities/professional_shop_profile_entity.dart';
import 'professional_shop_dashboard_page.dart';
import 'professional_shop_products_page.dart';
import 'professional_shop_orders_page.dart';
import 'professional_shop_inventory_page.dart';
import 'professional_shop_earnings_page.dart';
import 'professional_store_banner_management_page.dart';
import 'professional_shop_settings_page.dart';
import 'professional_shop_profile_page.dart';
import '../widgets/professional_new_order_dialog.dart';
import '../../../../core/widgets/responsive_shell.dart';
import '../../../../core/localization/provider_strings.dart';
import '../../../../core/localization/language_selection_modal.dart';

import '../../../../main.dart' show isProviderFirebaseInitialized;

/// Professional Seller Workspace Shell
/// Features complete responsive navigation:
/// - Desktop (>= 1024 px): 8 Full Navigation Items + Header Language Pill + Scrollable Footer
/// - Tablet (600 - 1023 px): Adaptive Navigation Rail with scrollable bounds
/// - Mobile (< 600 px): 5 Focused Bottom Navigation Tabs (Home, Products, Orders, Inventory, More/Profile)
class ProfessionalShopWorkspaceScreen extends StatefulWidget {
  final ProfessionalShopProfileEntity shop;
  final ProfessionalProviderRemoteDataSource? dataSource;

  const ProfessionalShopWorkspaceScreen({
    super.key,
    required this.shop,
    this.dataSource,
  });

  @override
  State<ProfessionalShopWorkspaceScreen> createState() => _ProfessionalShopWorkspaceScreenState();
}

class _ProfessionalShopWorkspaceScreenState extends State<ProfessionalShopWorkspaceScreen> {
  ProfessionalProviderRemoteDataSource? _dataSource;
  int _currentIndex = 0;
  StreamSubscription? _orderSub;
  String? _lastAlertedOrderId;
  late final Stream<ProfessionalShopProfileEntity?> _shopProfileStream;

  @override
  void initState() {
    super.initState();
    _dataSource = widget.dataSource ?? (isProviderFirebaseInitialized ? ProfessionalProviderRemoteDataSource() : null);
    if (_dataSource != null) {
      _shopProfileStream = _dataSource!.streamShopProfile(widget.shop.id);
      _listenForNewOrders();
    } else {
      _shopProfileStream = Stream.value(widget.shop);
    }
  }

  @override
  void dispose() {
    _orderSub?.cancel();
    super.dispose();
  }

  void _listenForNewOrders() {
    if (_dataSource == null) return;
    _orderSub = _dataSource!.streamShopOrders(widget.shop.id).listen((orders) {
      if (!mounted) return;
      // Find orders with status 'placed'
      final newOrders = orders.where((o) => (o['status'] as String?)?.toLowerCase().trim() == 'placed').toList();
      if (newOrders.isNotEmpty) {
        final newest = newOrders.first;
        final orderId = newest['orderId'] ?? newest['id'];
        if (_lastAlertedOrderId != orderId) {
          _lastAlertedOrderId = orderId;
          _showNewOrderAlert(newest);
        }
      }
    });
  }

  void _showNewOrderAlert(Map<String, dynamic> order) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ProfessionalNewOrderDialog(
        order: order,
        onDismiss: () => Navigator.pop(ctx),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ProfessionalShopProfileEntity?>(
      stream: _shopProfileStream,
      initialData: widget.shop,
      builder: (context, snapshot) {
        final currentShop = snapshot.data ?? widget.shop;

        // Authoritative 8 Workspace Pages
        final pages = [
          ProfessionalShopDashboardPage(
            shop: currentShop,
            onNavigateTab: (tabIdx) => setState(() => _currentIndex = tabIdx),
            dataSource: _dataSource,
          ),
          ProfessionalShopProductsPage(
            shopId: currentShop.id,
            dataSource: _dataSource,
          ),
          ProfessionalShopOrdersPage(
            shopId: currentShop.id,
            dataSource: _dataSource,
          ),
          ProfessionalShopInventoryPage(
            shopId: currentShop.id,
            dataSource: _dataSource,
          ),
          ProfessionalShopEarningsPage(
            shop: currentShop,
            dataSource: _dataSource,
          ),
          ProfessionalStoreBannerManagementPage(
            shop: currentShop,
            dataSource: _dataSource,
          ),
          ProfessionalShopSettingsPage(
            shop: currentShop,
          ),
          ProfessionalShopProfilePage(
            shop: currentShop,
            dataSource: _dataSource,
          ),
        ];

        // 8 Full Navigation Destinations for Desktop & Tablet
        final destinations = [
          WorkspaceNavDestination(
            icon: Icons.home_rounded,
            activeIcon: Icons.home_filled,
            label: ProviderStrings.navHome,
          ),
          WorkspaceNavDestination(
            icon: Icons.inventory_2_outlined,
            activeIcon: Icons.inventory_2_rounded,
            label: ProviderStrings.navProducts,
          ),
          WorkspaceNavDestination(
            icon: Icons.receipt_long_outlined,
            activeIcon: Icons.receipt_long_rounded,
            label: ProviderStrings.navOrders,
          ),
          WorkspaceNavDestination(
            icon: Icons.warehouse_outlined,
            activeIcon: Icons.warehouse_rounded,
            label: ProviderStrings.navInventory,
          ),
          WorkspaceNavDestination(
            icon: Icons.trending_up_rounded,
            activeIcon: Icons.trending_up_rounded,
            label: ProviderStrings.navEarnings,
          ),
          WorkspaceNavDestination(
            icon: Icons.campaign_outlined,
            activeIcon: Icons.campaign_rounded,
            label: ProviderStrings.navBanner,
          ),
          WorkspaceNavDestination(
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings_rounded,
            label: ProviderStrings.navSettings,
          ),
          WorkspaceNavDestination(
            icon: Icons.person_outline_rounded,
            activeIcon: Icons.person_rounded,
            label: ProviderStrings.navProfile,
          ),
        ];

        // 5 Focused Mobile Destinations (< 600 px)
        final mobileDestinations = [
          WorkspaceNavDestination(
            icon: Icons.home_rounded,
            activeIcon: Icons.home_filled,
            label: ProviderStrings.navHome,
          ),
          WorkspaceNavDestination(
            icon: Icons.inventory_2_outlined,
            activeIcon: Icons.inventory_2_rounded,
            label: ProviderStrings.navProducts,
          ),
          WorkspaceNavDestination(
            icon: Icons.receipt_long_outlined,
            activeIcon: Icons.receipt_long_rounded,
            label: ProviderStrings.navOrders,
          ),
          WorkspaceNavDestination(
            icon: Icons.warehouse_outlined,
            activeIcon: Icons.warehouse_rounded,
            label: ProviderStrings.navInventory,
          ),
          WorkspaceNavDestination(
            icon: Icons.storefront_rounded,
            activeIcon: Icons.storefront_rounded,
            label: ProviderStrings.navMore,
          ),
        ];

        return ResponsiveWorkspaceShell(
          backgroundColor: const Color(0xFFF8F9FA),
          body: SafeArea(child: pages[_currentIndex]),
          currentIndex: _currentIndex,
          onSelectIndex: (i) => setState(() => _currentIndex = i),
          destinations: destinations,
          mobileDestinations: mobileDestinations,
          mobileDestinationIndices: const [0, 1, 2, 3, 7],
          selectedColor: const Color(0xFF0F766E),
          unselectedColor: const Color(0xFF94A3B8),
          brandTitle: currentShop.shopName.isNotEmpty ? currentShop.shopName : 'Jamui Seller',
          brandSubtitle: currentShop.demandCategoryTitle.isNotEmpty
              ? currentShop.demandCategoryTitle
              : ProviderStrings.professionalStore,
          statusBadgeText: currentShop.isOpen ? ProviderStrings.shopOpenBadge : ProviderStrings.shopClosedBadge,
          isStatusPositive: currentShop.isOpen,
          headerAction: InkWell(
            key: const Key('sidebar_header_lang_btn'),
            onTap: () => LanguageSelectionModal.show(context),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF0F766E).withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.language_rounded, size: 13, color: Color(0xFF0F766E)),
                  const SizedBox(width: 4),
                  Text(
                    ProviderStrings.isHindi ? 'हिन्दी' : 'EN',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                  ),
                ],
              ),
            ),
          ),
          sidebarFooter: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: InkWell(
              key: const Key('sidebar_language_btn'),
              onTap: () => LanguageSelectionModal.show(context),
              borderRadius: BorderRadius.circular(10),
              child: Row(
                children: [
                  const Icon(Icons.language_rounded, color: Color(0xFF0F766E), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ProviderStrings.languageSettingTitle,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                        Text(
                          ProviderStrings.isHindi ? 'हिन्दी (सक्रिय)' : 'English (Active)',
                          style: const TextStyle(fontSize: 10.5, color: Color(0xFF0F766E), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F766E),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      ProviderStrings.switchLanguageBtn,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
