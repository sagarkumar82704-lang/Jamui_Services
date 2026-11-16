import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/datasources/professional_shop_remote_data_source.dart';
import '../../domain/entities/professional_order_entity.dart';
import '../localization/ecom_locale_controller.dart';
import '../localization/ecom_strings.dart';
import '../theme/ecom_theme.dart';
import 'professional_order_tracking_page.dart';
import 'professional_shops_listing_page.dart';

class ProfessionalCustomerOrdersPage extends StatefulWidget {
  const ProfessionalCustomerOrdersPage({super.key});

  @override
  State<ProfessionalCustomerOrdersPage> createState() => _ProfessionalCustomerOrdersPageState();
}

class _ProfessionalCustomerOrdersPageState extends State<ProfessionalCustomerOrdersPage> {
  final ProfessionalShopRemoteDataSource _dataSource = ProfessionalShopRemoteDataSource();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: EcomLocaleController.instance,
      builder: (context, _) {
        final user = _auth.currentUser;

        if (user == null) {
          return Scaffold(
            backgroundColor: EcomColors.background,
            appBar: AppBar(
              backgroundColor: EcomColors.primary,
              elevation: 0,
              title: Text(EcomStrings.myOrdersTitle,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(EcomStrings.loginRequired,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: EcomColors.textPrimary)),
                    const SizedBox(height: 8),
                    Text(EcomStrings.pleaseSignInOrders,
                        textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: EcomColors.textSecondary)),
                  ],
                ),
              ),
            ),
          );
        }

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            backgroundColor: EcomColors.background,
            appBar: AppBar(
              backgroundColor: EcomColors.primary,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(EcomStrings.myOrdersTitle,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
              bottom: TabBar(
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                tabs: [
                  Tab(text: EcomStrings.activeOrdersTab),
                  Tab(text: EcomStrings.pastOrdersTab),
                ],
              ),
            ),
            body: StreamBuilder<List<ProfessionalOrderEntity>>(
              stream: _dataSource.streamCustomerOrders(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: EcomColors.primary));
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 56, color: Colors.redAccent),
                          const SizedBox(height: 12),
                          Text(EcomStrings.errorLoadingOrders,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: EcomColors.textPrimary)),
                          const SizedBox(height: 6),
                          Text('${snapshot.error}', textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12, color: EcomColors.textSecondary)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => setState(() {}),
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: Text(EcomStrings.retry),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: EcomColors.primary, foregroundColor: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final allOrders = snapshot.data ?? [];
                final activeOrders = allOrders.where((o) => _isActiveOrder(o.status)).toList();
                final pastOrders = allOrders.where((o) => !_isActiveOrder(o.status)).toList();

                return TabBarView(
                  children: [
                    _buildOrdersList(activeOrders, isActiveTab: true),
                    _buildOrdersList(pastOrders, isActiveTab: false),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  bool _isActiveOrder(String status) {
    final s = status.toLowerCase();
    return s == 'placed' || s == 'accepted' || s == 'confirmed' || s == 'preparing' || s == 'out_for_delivery' || s == 'ready_for_pickup';
  }

  Widget _buildOrdersList(List<ProfessionalOrderEntity> orders, {required bool isActiveTab}) {
    if (orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(color: EcomColors.softGreen, shape: BoxShape.circle),
                child: const Icon(Icons.shopping_bag_outlined, color: EcomColors.primary, size: 36),
              ),
              const SizedBox(height: 18),
              Text(isActiveTab ? EcomStrings.noActiveOrders : EcomStrings.noPastOrders,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: EcomColors.textPrimary)),
              const SizedBox(height: 8),
              Text(EcomStrings.exploreShopsHint,
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: EcomColors.textSecondary)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfessionalShopsListingPage())),
                style: ElevatedButton.styleFrom(
                  backgroundColor: EcomColors.primary, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(EcomStrings.browseProducts, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (ctx, i) => _buildOrderCard(orders[i]),
    );
  }

  Widget _buildOrderCard(ProfessionalOrderEntity order) {
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt);
    final isDelivery = order.fulfillmentType == 'delivery';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EcomColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: EcomColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shop + Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(color: EcomColors.softGreen, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.storefront_rounded, color: EcomColors.primary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(order.shopName,
                              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: EcomColors.textPrimary),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(
                            order.sellerOrderNumber != null && order.sellerOrderNumber!.isNotEmpty
                                ? '#${order.orderNumber} (${order.sellerOrderNumber}) • $dateStr'
                                : '#${order.orderNumber} • $dateStr',
                            style: const TextStyle(fontSize: 11, color: EcomColors.textTertiary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(order.status),
            ],
          ),
          const Divider(color: EcomColors.divider, height: 20),

          // Items Summary
          Text(
            '${order.items.length} ${order.items.length == 1 ? 'item' : 'items'} • ${isDelivery ? EcomStrings.deliveryOption : EcomStrings.pickupOption}',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: EcomColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            order.items.map((it) => '${it.displayTitleWithUnit} (${it.quantity}x)').join(', '),
            style: const TextStyle(fontSize: 12, color: EcomColors.textSecondary),
            maxLines: 2, overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),

          // Total + Track button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(EcomStrings.totalPayable, style: const TextStyle(fontSize: 11, color: EcomColors.textTertiary)),
                  Text(ProfessionalOrderItem.formatCurrency(order.totalAmount),
                      style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900, color: EcomColors.primaryDark)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ProfessionalOrderTrackingPage(orderId: order.orderId, initialOrder: order)),
                ),
                icon: const Icon(Icons.local_shipping_outlined, size: 16),
                label: Text(EcomStrings.trackOrder),
                style: ElevatedButton.styleFrom(
                  backgroundColor: EcomColors.primary, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg; Color fg; String label;
    switch (status.toLowerCase()) {
      case 'placed':
        bg = const Color(0xFFEFF6FF); fg = const Color(0xFF1D4ED8);
        label = EcomStrings.orderStatusPlaced; break;
      case 'accepted': case 'confirmed': case 'preparing':
        bg = const Color(0xFFF0FDF4); fg = const Color(0xFF15803D);
        label = EcomStrings.orderStatusPacked; break;
      case 'ready_for_pickup':
        bg = const Color(0xFFFEF3C7); fg = const Color(0xFFB45309);
        label = EcomStrings.orderStatusReadyForPickup; break;
      case 'out_for_delivery':
        bg = const Color(0xFFFEF3C7); fg = const Color(0xFFB45309);
        label = EcomStrings.orderStatusOutForDelivery; break;
      case 'delivered': case 'completed': case 'collected':
        bg = const Color(0xFFDCFCE7); fg = const Color(0xFF166534);
        label = EcomStrings.orderStatusDelivered; break;
      case 'cancelled':
        bg = const Color(0xFFFEE2E2); fg = const Color(0xFFB91C1C);
        label = EcomStrings.orderStatusCancelled; break;
      case 'rejected':
        bg = const Color(0xFFFEE2E2); fg = const Color(0xFFB91C1C);
        label = EcomStrings.orderStatusRejected; break;
      default:
        bg = const Color(0xFFF1F5F9); fg = const Color(0xFF475569);
        label = status.toUpperCase();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg)),
    );
  }
}
