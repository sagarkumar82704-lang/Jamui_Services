import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../data/datasources/professional_provider_remote_data_source.dart';
import '../../domain/entities/professional_shop_profile_entity.dart';
import '../../domain/professional_entitlement_resolver.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../../../core/localization/provider_strings.dart';
import 'professional_add_edit_product_page.dart';
import 'professional_manage_store_categories_page.dart';
import 'professional_shop_subscription_page.dart';
import 'professional_store_preview_page.dart';
import '../../../../core/localization/language_selection_modal.dart';

/// Professional Seller Home Dashboard Page
/// Displays Shop Branding Header, 6 real Firestore KPIs, 7-Day IST Delivered Sales Chart,
/// Quick Navigation Actions, and Real-time Recent Orders.
class ProfessionalShopDashboardPage extends StatefulWidget {
  final ProfessionalShopProfileEntity shop;
  final Function(int) onNavigateTab;
  final ProfessionalProviderRemoteDataSource? dataSource;

  const ProfessionalShopDashboardPage({
    super.key,
    required this.shop,
    required this.onNavigateTab,
    this.dataSource,
  });

  @override
  State<ProfessionalShopDashboardPage> createState() => _ProfessionalShopDashboardPageState();
}

class _ProfessionalShopDashboardPageState extends State<ProfessionalShopDashboardPage> {
  late final ProfessionalProviderRemoteDataSource _dataSource;
  late bool _isOpen;
  late final Stream<List<Map<String, dynamic>>> _ordersStream;
  late final Stream<List<Map<String, dynamic>>> _productsStream;

  @override
  void initState() {
    super.initState();
    _dataSource = widget.dataSource ?? ProfessionalProviderRemoteDataSource();
    _isOpen = widget.shop.isOpen;
    _ordersStream = _dataSource.streamShopOrders(widget.shop.id);
    _productsStream = _dataSource.streamProducts(widget.shop.id);
  }

  Future<void> _toggleOpenStatus(bool val) async {
    setState(() => _isOpen = val);
    await _dataSource.toggleShopOpenStatus(widget.shop.id, val);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _ordersStream,
      builder: (context, ordersSnap) {
        final allOrders = ordersSnap.data ?? [];

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _productsStream,
          builder: (context, productsSnap) {
            final allProducts = productsSnap.data ?? [];

            // Calculate 6 Live Firestore KPIs
            double totalSales = 0.0;
            int pendingOrdersCount = 0;

            final qualifyingDeliveredOrders = <Map<String, dynamic>>[];

            for (final o in allOrders) {
              final status = (o['status'] as String?)?.toLowerCase().trim() ?? '';
              if (status == 'delivered' || status == 'collected') {
                qualifyingDeliveredOrders.add(o);
                // Subtotal verified (strictly excluding delivery charges)
                final sub = (o['subtotal'] as num?)?.toDouble() ??
                    (((o['totalAmount'] as num?)?.toDouble() ?? 0.0) - ((o['deliveryFee'] as num?)?.toDouble() ?? 0.0));
                totalSales += (sub > 0 ? sub : 0.0);
              } else if (status == 'placed' || status == 'accepted' || status == 'preparing') {
                pendingOrdersCount++;
              }
            }

            final int totalOrdersCount = allOrders.length;
            final int totalProductsCount = allProducts.length;

            int activeProductsCount = 0;
            int outOfStockCount = 0;

            for (final p in allProducts) {
              final qty = (p['stockQuantity'] as num?)?.toInt() ?? 1;
              final inStock = (p['inStock'] as bool?) ?? true;
              if (inStock && qty > 0) {
                activeProductsCount++;
              } else {
                outOfStockCount++;
              }
            }

            return SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: ResponsiveContentContainer(
                padding: ResponsiveLayout.pagePadding(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Shop Name & Open/Closed Status Switch
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 48,
                                height: 48,
                                color: const Color(0xFFEFF6FF),
                                child: widget.shop.logoUrl.isNotEmpty
                                    ? Image.network(
                                        widget.shop.logoUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) =>
                                            const Icon(Icons.storefront_rounded, color: Color(0xFF1D4ED8), size: 28),
                                      )
                                    : const Icon(Icons.storefront_rounded, color: Color(0xFF1D4ED8), size: 28),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 260),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.shop.shopName,
                                    style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.shop.jamuiArea.isNotEmpty ? widget.shop.jamuiArea : 'जमुई, बिहार',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        // Open / Closed Toggle Pill
                        GestureDetector(
                          onTap: () => _toggleOpenStatus(!_isOpen),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _isOpen ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _isOpen ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _isOpen ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _isOpen ? ProviderStrings.shopOpenBadge : ProviderStrings.shopClosedBadge,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: _isOpen ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Language Switcher Pill
                        GestureDetector(
                          key: const Key('btn_dashboard_language'),
                          onTap: () => LanguageSelectionModal.show(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.language_rounded, color: Color(0xFF1D4ED8), size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  ProviderStrings.isHindi ? '🌐 हिन्दी' : '🌐 English',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1D4ED8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Professional Subscription Status Banner
                    Builder(
                      builder: (ctx) {
                        final ent = ProfessionalEntitlementResolver.resolve(widget.shop);
                        return _buildSubscriptionBanner(ctx, ent, totalProductsCount);
                      },
                    ),
                    const SizedBox(height: 14),

                    // 6 Real Firestore KPIs Grid
                    Text(
                      ProviderStrings.businessOverview,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, kpiConstraints) {
                        final kpiTiles = [
                          _buildKpiTile(
                            title: ProviderStrings.totalSales,
                            value: '₹${totalSales.toInt()}',
                            icon: Icons.payments_rounded,
                            color: const Color(0xFF0F766E),
                            bgColor: const Color(0xFFE0F2F1),
                          ),
                          _buildKpiTile(
                            title: ProviderStrings.totalOrders,
                            value: '$totalOrdersCount',
                            icon: Icons.receipt_long_rounded,
                            color: const Color(0xFF1D4ED8),
                            bgColor: const Color(0xFFEFF6FF),
                          ),
                          _buildKpiTile(
                            title: ProviderStrings.pendingOrders,
                            value: '$pendingOrdersCount',
                            icon: Icons.pending_actions_rounded,
                            color: const Color(0xFFD97706),
                            bgColor: const Color(0xFFFFFBEB),
                          ),
                          _buildKpiTile(
                            title: ProviderStrings.totalProducts,
                            value: '$totalProductsCount',
                            icon: Icons.inventory_2_rounded,
                            color: const Color(0xFF6366F1),
                            bgColor: const Color(0xFFEEF2FF),
                          ),
                          _buildKpiTile(
                            title: ProviderStrings.activeProducts,
                            value: '$activeProductsCount',
                            icon: Icons.check_circle_rounded,
                            color: const Color(0xFF2E7D32),
                            bgColor: const Color(0xFFE8F5E9),
                          ),
                          _buildKpiTile(
                            title: ProviderStrings.outOfStock,
                            value: '$outOfStockCount',
                            icon: Icons.cancel_rounded,
                            color: const Color(0xFFC62828),
                            bgColor: const Color(0xFFFFEBEE),
                          ),
                        ];
                        if (kpiConstraints.maxWidth >= 720) {
                          return Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(child: kpiTiles[0]),
                                  const SizedBox(width: 12),
                                  Expanded(child: kpiTiles[1]),
                                  const SizedBox(width: 12),
                                  Expanded(child: kpiTiles[2]),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(child: kpiTiles[3]),
                                  const SizedBox(width: 12),
                                  Expanded(child: kpiTiles[4]),
                                  const SizedBox(width: 12),
                                  Expanded(child: kpiTiles[5]),
                                ],
                              ),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: kpiTiles[0]),
                                const SizedBox(width: 10),
                                Expanded(child: kpiTiles[1]),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(child: kpiTiles[2]),
                                const SizedBox(width: 10),
                                Expanded(child: kpiTiles[3]),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(child: kpiTiles[4]),
                                const SizedBox(width: 10),
                                Expanded(child: kpiTiles[5]),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    // Quick Actions
                    Text(
                      ProviderStrings.quickActions,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: _buildQuickActionItem(ProviderStrings.addNewProduct, Icons.add_box_rounded, () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProfessionalAddEditProductPage(shopId: widget.shop.id),
                              ),
                            );
                          }),
                        ),
                        Expanded(
                          child: _buildQuickActionItem(ProviderStrings.manageCategories, Icons.category_rounded, () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProfessionalManageStoreCategoriesPage(shopId: widget.shop.id),
                              ),
                            );
                          }),
                        ),
                        Expanded(
                          child: _buildQuickActionItem(ProviderStrings.navOrders, Icons.receipt_long_rounded, () {
                            widget.onNavigateTab(2); // Go to Orders tab (index 2)
                          }),
                        ),
                        Expanded(
                          child: _buildQuickActionItem(ProviderStrings.navInventory, Icons.warehouse_rounded, () {
                            widget.onNavigateTab(3); // Go to Inventory tab (index 3)
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: _buildQuickActionItem(ProviderStrings.promotionalBanner, Icons.campaign_rounded, () {
                            widget.onNavigateTab(5); // Go to Promotional Banner tab (index 5)
                          }),
                        ),
                        Expanded(
                          child: _buildQuickActionItem(ProviderStrings.shopSettings, Icons.settings_rounded, () {
                            widget.onNavigateTab(6); // Go to Store Settings tab (index 6)
                          }),
                        ),
                        Expanded(
                          child: _buildQuickActionItem(ProviderStrings.navEarnings, Icons.trending_up_rounded, () {
                            widget.onNavigateTab(4); // Go to Earnings tab (index 4)
                          }),
                        ),
                        Expanded(
                          child: _buildQuickActionItem(ProviderStrings.previewStore, Icons.storefront_rounded, () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProfessionalStorePreviewPage(shop: widget.shop),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // 7-Day Delivered Sales Chart & Recent Orders Feed (2-column on wide screens)
                    LayoutBuilder(
                      builder: (context, bottomConstraints) {
                        final ent = ProfessionalEntitlementResolver.resolve(widget.shop);
                        final salesChartWidget = ent.advancedAnalytics
                            ? _buildSevenDaySalesChart(qualifyingDeliveredOrders)
                            : _buildLockedAnalyticsCard(context);
                        final recentOrdersWidget = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    ProviderStrings.recentOrders,
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => widget.onNavigateTab(2), // Jump to Orders tab
                                  child: Text(
                                    ProviderStrings.viewAllOrders,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (allOrders.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Column(
                                  children: [
                                    Icon(Icons.inbox_outlined, size: 36, color: Colors.grey.shade400),
                                    const SizedBox(height: 8),
                                    Text(
                                      ProviderStrings.noOrdersYet,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: allOrders.take(4).length,
                                separatorBuilder: (_, _) => const SizedBox(height: 10),
                                itemBuilder: (ctx, i) => _buildOrderTile(allOrders[i]),
                              ),
                          ],
                        );

                        if (bottomConstraints.maxWidth >= 900) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 5, child: salesChartWidget),
                              const SizedBox(width: 20),
                              Expanded(flex: 5, child: recentOrdersWidget),
                            ],
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            salesChartWidget,
                            const SizedBox(height: 22),
                            recentOrdersWidget,
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildKpiTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: bgColor,
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  title,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the 7-day Delivered Sales Chart with 7 IST calendar-day buckets
  Widget _buildSevenDaySalesChart(List<Map<String, dynamic>> deliveredOrders) {
    // 7 IST calendar-day buckets (UTC + 5:30)
    const istOffset = Duration(hours: 5, minutes: 30);
    final nowUtc = DateTime.now().toUtc();
    final nowIst = nowUtc.add(istOffset);
    final todayMidnightIst = DateTime.utc(nowIst.year, nowIst.month, nowIst.day);

    final List<DateTime> bucketDates = List.generate(7, (i) {
      return todayMidnightIst.subtract(Duration(days: 6 - i));
    });

    final List<double> bucketSales = List.filled(7, 0.0);

    for (final order in deliveredOrders) {
      DateTime? orderDate;
      final rawCreated = order['createdAt'];
      if (rawCreated is Timestamp) {
        orderDate = rawCreated.toDate();
      } else if (rawCreated is String) {
        orderDate = DateTime.tryParse(rawCreated);
      } else if (rawCreated is int) {
        orderDate = DateTime.fromMillisecondsSinceEpoch(rawCreated);
      }

      if (orderDate != null) {
        final orderIst = orderDate.toUtc().add(istOffset);
        final orderDayMidnight = DateTime.utc(orderIst.year, orderIst.month, orderIst.day);

        for (int i = 0; i < 7; i++) {
          if (bucketDates[i].isAtSameMomentAs(orderDayMidnight)) {
            // Strictly exclude delivery charges by using verified subtotal
            final subtotal = (order['subtotal'] as num?)?.toDouble() ??
                (((order['totalAmount'] as num?)?.toDouble() ?? 0.0) - ((order['deliveryFee'] as num?)?.toDouble() ?? 0.0));
            bucketSales[i] += (subtotal > 0 ? subtotal : 0.0);
            break;
          }
        }
      }
    }

    final bool hasAnySales = bucketSales.any((s) => s > 0.0);
    final double maxSale = bucketSales.fold(0.0, (prev, s) => s > prev ? s : prev);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.bar_chart_rounded, color: Color(0xFF0F766E), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '7 दिनों की डिलीवरी बिक्री (Sales)',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2F1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'IST दैनिक',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (!hasAnySales)
            Container(
              height: 120,
              width: double.infinity,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.query_stats_rounded, size: 36, color: Colors.grey.shade300),
                  const SizedBox(height: 6),
                  const Text(
                    'पिछले 7 दिनों में कोई डिलीवरी बिक्री दर्ज नहीं हुई।',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 150,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(7, (i) {
                  final sale = bucketSales[i];
                  final date = bucketDates[i];
                  final isToday = i == 6;

                  final ratio = maxSale > 0 ? (sale / maxSale) : 0.0;
                  final barHeight = (ratio * 80).clamp(6.0, 80.0);

                  final dayLabel = isToday ? 'आज' : _getDayName(date.weekday);

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (sale > 0)
                        Text(
                          '₹${sale.toInt()}',
                          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                        ),
                      const SizedBox(height: 4),
                      Container(
                        width: 22,
                        height: barHeight,
                        decoration: BoxDecoration(
                          color: isToday ? const Color(0xFF0F766E) : const Color(0xFF64748B),
                          borderRadius: BorderRadius.circular(6),
                          gradient: isToday
                              ? const LinearGradient(
                                  colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        dayLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                          color: isToday ? const Color(0xFF0F766E) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'सोम';
      case 2:
        return 'मंगल';
      case 3:
        return 'बुध';
      case 4:
        return 'गुरु';
      case 5:
        return 'शुक्र';
      case 6:
        return 'शनि';
      case 7:
        return 'रवि';
      default:
        return '';
    }
  }

  Widget _buildQuickActionItem(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
              ],
            ),
            child: Icon(icon, color: const Color(0xFF0F766E), size: 26),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
        ],
      ),
    );
  }

  Widget _buildOrderTile(Map<String, dynamic> o) {
    final id = o['orderId'] ?? o['id'] ?? 'ORD';
    final name = o['customerName'] ?? 'Customer';
    final amt = (o['totalAmount'] as num?)?.toInt() ?? 0;
    final st = (o['status'] as String?) ?? 'placed';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(0xFFE0F2F1),
                  child: Icon(Icons.person_rounded, color: Color(0xFF0F766E), size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('#$id', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(name, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      _buildStatusChip(st),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('₹$amt', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F766E))),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bg = const Color(0xFFE0F2F1);
    Color fg = const Color(0xFF0F766E);
    if (status == 'preparing') {
      bg = const Color(0xFFFFF3E0);
      fg = const Color(0xFFE65100);
    } else if (status == 'delivered') {
      bg = const Color(0xFFE8F5E9);
      fg = const Color(0xFF2E7D32);
    } else if (status == 'rejected' || status == 'cancelled') {
      bg = const Color(0xFFFFEBEE);
      fg = const Color(0xFFC62828);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  Widget _buildSubscriptionBanner(BuildContext context, ProfessionalEntitlements ent, int totalProducts) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: ent.isValid ? const Color(0xFFEFF6FF) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              ent.isValid ? Icons.workspace_premium_rounded : Icons.lock_clock_outlined,
              color: ent.isValid ? const Color(0xFF1D4ED8) : const Color(0xFFDC2626),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [
                    Text(
                      ent.planName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: ent.isValid ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        ent.isValid ? 'ACTIVE' : 'EXPIRED',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: ent.isValid ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  'Products: $totalProducts / ${ent.maxProducts}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1D4ED8),
              side: const BorderSide(color: Color(0xFF93C5FD)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ProfessionalShopSubscriptionPage(shop: widget.shop)),
              );
            },
            child: const Text('Manage', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedAnalyticsCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.lock_outline_rounded, color: Color(0xFF64748B), size: 30),
            ),
            const SizedBox(height: 12),
            const Text(
              'Advanced Analytics Locked',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 4),
            const Text(
              'Upgrade to a Pro Plan to unlock 7-Day sales trends, IST analytics, and revenue insights.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D4ED8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ProfessionalShopSubscriptionPage(shop: widget.shop)),
                );
              },
              child: const Text('Upgrade Plan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
