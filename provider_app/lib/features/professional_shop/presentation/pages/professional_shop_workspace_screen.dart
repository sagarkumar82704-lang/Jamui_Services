import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/datasources/professional_provider_remote_data_source.dart';
import '../../domain/entities/professional_shop_profile_entity.dart';
import 'professional_shop_dashboard_page.dart';
import 'professional_shop_products_page.dart';
import 'professional_shop_orders_page.dart';
import 'professional_shop_inventory_page.dart';
import 'professional_shop_profile_page.dart';
import '../widgets/professional_new_order_dialog.dart';

import '../../../../main.dart' show isProviderFirebaseInitialized;

/// Professional Seller Workspace Shell
/// Hosts exactly 5 tabs in the approved order:
/// 1. Home
/// 2. Products
/// 3. Orders
/// 4. Inventory
/// 5. Profile
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
      barrierDismissible: false,
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

        // Exactly 5 Pages in approved order
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
          ProfessionalShopProfilePage(
            shop: currentShop,
            dataSource: _dataSource,
          ),
        ];

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          body: SafeArea(child: pages[_currentIndex]),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (i) => setState(() => _currentIndex = i),
            selectedItemColor: const Color(0xFF0F766E), // Deep Teal
            unselectedItemColor: const Color(0xFF94A3B8),
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10.5),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded),
                activeIcon: Icon(Icons.home_filled),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.inventory_2_outlined),
                activeIcon: Icon(Icons.inventory_2_rounded),
                label: 'Products',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.receipt_long_outlined),
                activeIcon: Icon(Icons.receipt_long_rounded),
                label: 'Orders',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.warehouse_outlined),
                activeIcon: Icon(Icons.warehouse_rounded),
                label: 'Inventory',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded),
                activeIcon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }
}
