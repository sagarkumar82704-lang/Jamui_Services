import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../data/datasources/professional_shop_remote_data_source.dart';
import '../../domain/entities/professional_order_entity.dart';
import '../../domain/entities/professional_product_entity.dart';
import '../bloc/professional_cart_bloc.dart';
import 'professional_cart_page.dart';
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
  bool _isReordering = false;

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          title: const Text(
            'My Pro Orders',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E293B), size: 20),
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
                const Text(
                  'Login Required',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please sign in to view your Professional (Pro) marketplace orders and track deliveries.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E293B), size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'My Pro Orders',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          bottom: const TabBar(
            indicatorColor: Color(0xFF2E7D32),
            labelColor: Color(0xFF2E7D32),
            unselectedLabelColor: Color(0xFF64748B),
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            tabs: [
              Tab(text: 'Active Orders'),
              Tab(text: 'Past Orders'),
            ],
          ),
        ),
        body: StreamBuilder<List<ProfessionalOrderEntity>>(
          stream: _dataSource.streamCustomerOrders(user.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)));
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
                      const Text(
                        'Unable to load orders',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => setState(() {}),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Try Again'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                        ),
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
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF2E7D32), size: 36),
              ),
              const SizedBox(height: 18),
              Text(
                isActiveTab ? 'No active orders right now' : 'You haven\'t placed any orders yet.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 8),
              Text(
                isActiveTab
                    ? 'Orders you place from local grocery, fruit, and bakery shops will appear here.'
                    : 'Discover fresh groceries, daily essentials, and local shops with doorstep delivery.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ProfessionalShopsListingPage(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Explore Professional Marketplace', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (ctx, i) => _buildOrderCard(orders[i], isActiveTab: isActiveTab),
    );
  }

  Widget _buildOrderCard(ProfessionalOrderEntity order, {required bool isActiveTab}) {
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt);
    final isDelivery = order.fulfillmentType == 'delivery';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Shop Name & Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.storefront_rounded, color: Color(0xFF2E7D32), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.shopName,
                            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            dateStr,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
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
          const Divider(height: 20),

          // Order Items Summary
          Text(
            '${order.items.length} ${order.items.length == 1 ? 'item' : 'items'} • ${isDelivery ? 'Home Delivery' : 'Store Pickup'}',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 6),
          Text(
            order.items.map((it) => '${it.title} (${it.quantity}x)').join(', '),
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),

          // Total & Actions Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Amount', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  Text(
                    '₹${order.totalAmount.toInt()}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF2E7D32)),
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () => _showOrderDetailsBottomSheet(context, order),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                  ),
                  const SizedBox(width: 8),
                  if (isActiveTab)
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProfessionalOrderTrackingPage(orderId: order.orderId, initialOrder: order),
                          ),
                        );
                      },
                      icon: const Icon(Icons.navigation_rounded, size: 14, color: Colors.white),
                      label: const Text('Track', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: _isReordering ? null : () => _handleReorder(context, order),
                      icon: const Icon(Icons.repeat_rounded, size: 14, color: Colors.white),
                      label: const Text('Re-order', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = const Color(0xFFE2E8F0);
    Color fg = const Color(0xFF475569);
    String label = status.toUpperCase();

    switch (status.toLowerCase()) {
      case 'placed':
        bg = const Color(0xFFE0F2FE);
        fg = const Color(0xFF0369A1);
        label = 'PLACED';
        break;
      case 'accepted':
      case 'confirmed':
        bg = const Color(0xFFE0E7FF);
        fg = const Color(0xFF4338CA);
        label = 'ACCEPTED';
        break;
      case 'preparing':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        label = 'PREPARING';
        break;
      case 'out_for_delivery':
      case 'ready_for_pickup':
        bg = const Color(0xFFCCFBF1);
        fg = const Color(0xFF0F766E);
        label = status == 'out_for_delivery' ? 'OUT FOR DELIVERY' : 'READY FOR PICKUP';
        break;
      case 'delivered':
      case 'collected':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        label = 'DELIVERED';
        break;
      case 'rejected':
      case 'cancelled':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFB91C1C);
        label = status.toUpperCase();
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  void _showOrderDetailsBottomSheet(BuildContext context, ProfessionalOrderEntity order) {
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt);
    final isDelivery = order.fulfillmentType == 'delivery';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order Details (#${order.orderId})',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                _buildStatusBadge(order.status),
              ],
            ),
            Text(dateStr, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            const Divider(height: 24),
            Expanded(
              child: ListView(
                children: [
                  // Shop Info
                  const Text('Shop Information', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                  const SizedBox(height: 4),
                  Text(order.shopName, style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
                  if (order.shopPhone.isNotEmpty) Text('Phone: ${order.shopPhone}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 16),

                  // Delivery Address
                  if (isDelivery && order.deliveryAddress != null) ...[
                    const Text('Delivery Address', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                    const SizedBox(height: 4),
                    Text(
                      '${order.deliveryAddress!['address'] ?? ''} ${order.deliveryAddress!['area'] ?? ''}',
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Items Historical Snapshot
                  const Text('Ordered Items (Historical Snapshot)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                  const SizedBox(height: 8),
                  ...order.items.map((it) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${it.title}  x${it.quantity} (${it.unit})',
                                style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
                              ),
                            ),
                            Text(
                              '₹${it.total.toInt()}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                          ],
                        ),
                      )),
                  const Divider(height: 24),

                  // Bill Breakdown
                  _buildPriceRow('Items Subtotal', '₹${order.subtotal.toInt()}'),
                  if (isDelivery) _buildPriceRow('Delivery Fee', '₹${order.deliveryCharge.toInt()}'),
                  if (order.discountAmount > 0) _buildPriceRow('Discount', '-₹${order.discountAmount.toInt()}', color: const Color(0xFF2E7D32)),
                  const Divider(height: 16),
                  _buildPriceRow('Total Paid', '₹${order.totalAmount.toInt()}', isBold: true, fontSize: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isBold = false, double fontSize = 13, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: const Color(0xFF64748B))),
          Text(value, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.w900 : FontWeight.w600, color: color ?? const Color(0xFF1E293B))),
        ],
      ),
    );
  }

  /// Authoritative Re-Order:
  /// - Queries current live shop products from Firestore.
  /// - Never trusts old order prices.
  /// - Validates live product availability and stock.
  /// - Informs customer of any price change or unavailable item.
  /// - Adds available items with CURRENT prices to cart.
  Future<void> _handleReorder(BuildContext context, ProfessionalOrderEntity order) async {
    setState(() => _isReordering = true);

    try {
      final shop = await _dataSource.fetchShopById(order.shopId);
      if (shop == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This shop is no longer available on Jamui Services.'), backgroundColor: Colors.red),
        );
        setState(() => _isReordering = false);
        return;
      }

      final liveProducts = await _dataSource.fetchShopProducts(order.shopId);
      final liveProductMap = {for (var p in liveProducts) p.id: p};

      final List<ProfessionalProductEntity> eligibleProducts = [];
      final List<String> unavailableNames = [];
      final List<String> priceChangedAlerts = [];

      for (final orderedItem in order.items) {
        final liveP = liveProductMap[orderedItem.productId];
        if (liveP == null || !liveP.isActive || !liveP.inStock) {
          unavailableNames.add(orderedItem.title);
        } else {
          eligibleProducts.add(liveP);
          if (liveP.sellingPrice != orderedItem.price) {
            priceChangedAlerts.add('${liveP.name}: ₹${orderedItem.price.toInt()} → ₹${liveP.sellingPrice.toInt()}');
          }
        }
      }

      if (eligibleProducts.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('None of the ordered products are currently in stock.'), backgroundColor: Colors.red),
        );
        setState(() => _isReordering = false);
        return;
      }

      if (!mounted) return;

      // Add eligible products to cart with LIVE prices
      final cartBloc = context.read<ProfessionalCartBloc>();
      // Enforce single-shop cart by resetting or checking current cart shop
      if (cartBloc.state.shopId.isNotEmpty && cartBloc.state.shopId != order.shopId) {
        cartBloc.add(ClearCartEvent());
      }

      for (final prod in eligibleProducts) {
        cartBloc.add(AddToCartEvent(product: prod, shop: shop));
      }

      setState(() => _isReordering = false);

      // Alert customer about modified prices or unavailable items
      if (unavailableNames.isNotEmpty || priceChangedAlerts.isNotEmpty) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Re-order Notice', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (unavailableNames.isNotEmpty) ...[
                  const Text('Out of Stock Products:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                  const SizedBox(height: 4),
                  Text(unavailableNames.join(', '), style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 12),
                ],
                if (priceChangedAlerts.isNotEmpty) ...[
                  const Text('Current Updated Prices Applied:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                  const SizedBox(height: 4),
                  Text(priceChangedAlerts.join('\n'), style: const TextStyle(fontSize: 12)),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Proceed to Cart', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
              ),
            ],
          ),
        );
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProfessionalCartPage(shop: shop),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isReordering = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to re-order: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

