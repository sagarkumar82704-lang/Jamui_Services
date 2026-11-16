import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../data/datasources/professional_provider_remote_data_source.dart';
import '../../domain/entities/professional_shop_profile_entity.dart';

/// Professional Seller Earnings & Reports Page.
/// All KPIs are computed from real Firestore diamond_orders data.
/// Month filter is functional — switches between current month and last month.
class ProfessionalShopEarningsPage extends StatefulWidget {
  final ProfessionalShopProfileEntity shop;
  final ProfessionalProviderRemoteDataSource? dataSource;

  const ProfessionalShopEarningsPage({
    super.key,
    required this.shop,
    this.dataSource,
  });

  @override
  State<ProfessionalShopEarningsPage> createState() =>
      _ProfessionalShopEarningsPageState();
}

enum _EarningsPeriod { thisMonth, lastMonth, last7Days, allTime }

class _ProfessionalShopEarningsPageState
    extends State<ProfessionalShopEarningsPage> {
  _EarningsPeriod _period = _EarningsPeriod.thisMonth;
  bool _isLoading = true;
  String? _error;

  // Computed KPIs from real orders
  double _totalSales = 0;
  int _totalOrders = 0;
  int _deliveredOrders = 0;
  int _cancelledOrders = 0;
  double _netEarnings = 0;
  List<Map<String, dynamic>> _recentOrders = [];

  @override
  void initState() {
    super.initState();
    _loadEarnings();
  }

  Future<void> _loadEarnings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      DateTime? startDate;
      DateTime? endDate;

      switch (_period) {
        case _EarningsPeriod.thisMonth:
          startDate = DateTime(now.year, now.month, 1);
          endDate = DateTime(now.year, now.month + 1, 1);
          break;
        case _EarningsPeriod.lastMonth:
          startDate = DateTime(now.year, now.month - 1, 1);
          endDate = DateTime(now.year, now.month, 1);
          break;
        case _EarningsPeriod.last7Days:
          startDate =
              DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
          endDate = DateTime(now.year, now.month, now.day + 1);
          break;
        case _EarningsPeriod.allTime:
          startDate = null;
          endDate = null;
          break;
      }

      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('diamond_orders')
          .where('shopId', isEqualTo: widget.shop.id);

      if (startDate != null) {
        query = query.where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );
      }
      if (endDate != null) {
        query = query.where(
          'createdAt',
          isLessThan: Timestamp.fromDate(endDate),
        );
      }

      final snap = await query
          .orderBy('createdAt', descending: true)
          .get()
          .timeout(const Duration(seconds: 10));

      double totalSales = 0;
      int deliveredOrders = 0;
      int cancelledOrders = 0;

      for (final doc in snap.docs) {
        final data = doc.data();
        final status =
            (data['status'] as String? ?? '').toLowerCase().trim();
        if (status == 'delivered' || status == 'collected') {
          deliveredOrders++;
          final sub = (data['subtotal'] as num?)?.toDouble() ??
              (((data['totalAmount'] as num?)?.toDouble() ?? 0.0) -
                  ((data['deliveryFee'] as num?)?.toDouble() ?? 0.0));
          totalSales += sub > 0 ? sub : 0;
        } else if (status == 'cancelled' || status == 'rejected') {
          cancelledOrders++;
        }
      }

      // JAMUI Services operates on a 100% Zero-Commission / subscription-based model.
      // Net Merchant Revenue = Delivered Product Subtotal (No commission deducted).
      final net = totalSales;

      final recentOrders = snap.docs
          .take(10)
          .map((d) => {'id': d.id, ...d.data()})
          .toList();

      if (mounted) {
        setState(() {
          _totalSales = totalSales;
          _totalOrders = snap.docs.length;
          _deliveredOrders = deliveredOrders;
          _cancelledOrders = cancelledOrders;
          _netEarnings = net;
          _recentOrders = recentOrders;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'डेटा लोड करने में त्रुटि: ${e.toString().split('\n').first}';
          _isLoading = false;
        });
      }
    }
  }

  String get _periodLabel {
    switch (_period) {
      case _EarningsPeriod.thisMonth:
        return 'इस महीने';
      case _EarningsPeriod.lastMonth:
        return 'पिछले महीने';
      case _EarningsPeriod.last7Days:
        return 'पिछले 7 दिन';
      case _EarningsPeriod.allTime:
        return 'सभी समय';
    }
  }

  void _showPeriodPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'अवधि चुनें',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ..._EarningsPeriod.values.map((p) {
              final labels = {
                _EarningsPeriod.thisMonth: 'इस महीने',
                _EarningsPeriod.lastMonth: 'पिछले महीने',
                _EarningsPeriod.last7Days: 'पिछले 7 दिन',
                _EarningsPeriod.allTime: 'सभी समय',
              };
              return ListTile(
                title: Text(labels[p]!),
                trailing:
                    _period == p ? const Icon(Icons.check, color: Color(0xFF0F766E)) : null,
                onTap: () {
                  Navigator.pop(ctx);
                  if (_period != p) {
                    setState(() => _period = p);
                    _loadEarnings();
                  }
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Earnings & Reports',
          style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B)),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadEarnings,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          child: ResponsiveContentContainer(
            maxWidth: 960,
            padding: ResponsiveLayout.pagePadding(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Period Filter Row
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    const Text(
                      'बिक्री प्रदर्शन (Sales Performance)',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B)),
                    ),
                    GestureDetector(
                      onTap: _showPeriodPicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _periodLabel,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF475569)),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.keyboard_arrow_down_rounded,
                                size: 16, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(
                          color: Color(0xFF0F766E)),
                    ),
                  )
                else if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Color(0xFFDC2626)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _error!,
                            style:
                                const TextStyle(color: Color(0xFFDC2626)),
                          ),
                        ),
                        TextButton(
                          onPressed: _loadEarnings,
                          child: const Text('पुनः प्रयास'),
                        ),
                      ],
                    ),
                  )
                else ...[
                  // KPI Overview Cards Row
                  Row(
                    children: [
                      Expanded(child: _buildKpiCard('कुल बिक्री', '₹${_totalSales.toInt()}', const Color(0xFF1E293B))),
                      const SizedBox(width: 12),
                      Expanded(child: _buildKpiCard('कुल ऑर्डर', '$_totalOrders', const Color(0xFF0F766E))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildKpiCard('डिलीवर्ड', '$_deliveredOrders', const Color(0xFF059669))),
                      const SizedBox(width: 12),
                      Expanded(child: _buildKpiCard('रद्द', '$_cancelledOrders', const Color(0xFFDC2626))),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Net Earnings Highlight Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F766E),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'कुल सफल बिक्री राजस्व (0% कमीशन • सीधा विक्रेता)',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                '(उत्पाद बिक्री राजस्व • 0% प्लेटफ़ॉर्म कमीशन • शुद्ध लाभ नहीं)',
                                style: TextStyle(
                                    color: Colors.white60, fontSize: 10),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₹${_netEarnings.toInt()}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                            Icons.account_balance_wallet_rounded,
                            color: Colors.white54,
                            size: 36),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Recent Orders Section
                  const Text(
                    'हालिया ऑर्डर (Recent Orders)',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 10),

                  if (_recentOrders.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'इस अवधि में कोई ऑर्डर नहीं मिला।',
                          style: TextStyle(
                              color: Color(0xFF64748B), fontSize: 13),
                        ),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 3)),
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _recentOrders.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, indent: 16),
                        itemBuilder: (ctx, i) {
                          final order = _recentOrders[i];
                          final status = (order['status'] as String? ?? '').toLowerCase();
                          final amount = (order['totalAmount'] as num?)?.toDouble() ?? 0;
                          final ts = order['createdAt'];
                          DateTime? dt;
                          if (ts is Timestamp) dt = ts.toDate();
                          final dateStr = dt != null
                              ? '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}'
                              : '—';
                          final orderId = (order['orderId'] ?? order['id'] ?? '').toString();
                          final shortId = orderId.length > 8
                              ? '#${orderId.substring(orderId.length - 8).toUpperCase()}'
                              : '#${orderId.toUpperCase()}';

                          Color statusColor;
                          if (status == 'delivered' || status == 'collected') {
                            statusColor = const Color(0xFF059669);
                          } else if (status == 'cancelled' || status == 'rejected') {
                            statusColor = const Color(0xFFDC2626);
                          } else if (status == 'placed') {
                            statusColor = const Color(0xFFD97706);
                          } else {
                            statusColor = const Color(0xFF0284C7);
                          }

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            title: Text(
                              shortId,
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B)),
                            ),
                            subtitle: Text(
                              dateStr,
                              style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF64748B)),
                            ),
                            trailing: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₹${amount.toInt()}',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E293B)),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color:
                                        statusColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: statusColor),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard(String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: valueColor),
          ),
        ],
      ),
    );
  }
}
