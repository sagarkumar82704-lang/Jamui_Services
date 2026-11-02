import 'package:flutter/material.dart';
import '../../data/datasources/professional_admin_remote_data_source.dart';

class ProfessionalAdminDashboardPage extends StatefulWidget {
  const ProfessionalAdminDashboardPage({super.key});

  @override
  State<ProfessionalAdminDashboardPage> createState() => _ProfessionalAdminDashboardPageState();
}

class _ProfessionalAdminDashboardPageState extends State<ProfessionalAdminDashboardPage> {
  final ProfessionalAdminRemoteDataSource _dataSource = ProfessionalAdminRemoteDataSource();
  Map<String, dynamic>? _selectedShop;
  Map<String, dynamic>? _shopInspectionData;
  bool _isLoadingInspection = false;
  Map<String, dynamic> _metrics = {
    'totalShops': 0,
    'activeShops': 0,
    'totalOrders': 0,
    'totalSales': 0.0,
  };
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  void _onSelectShop(Map<String, dynamic> shop) {
    setState(() {
      _selectedShop = shop;
      _isLoadingInspection = true;
      _shopInspectionData = null;
    });

    _dataSource.fetchShopInspectionDetails(
      shop['id'].toString(),
      ownerUid: shop['ownerUid'] as String?,
    ).then((details) {
      if (mounted && _selectedShop?['id'] == shop['id']) {
        setState(() {
          _shopInspectionData = details;
          _isLoadingInspection = false;
        });
      }
    }).catchError((_) {
      if (mounted) setState(() => _isLoadingInspection = false);
    });
  }

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return 'N/A';
    DateTime? dt;
    if (ts is DateTime) {
      dt = ts;
    } else if (ts is String) {
      dt = DateTime.tryParse(ts);
    } else {
      try {
        // Handle Cloud Firestore Timestamp
        final dynamic dynamicTs = ts;
        dt = dynamicTs.toDate() as DateTime?;
      } catch (_) {}
    }
    if (dt == null) return 'N/A';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _loadMetrics() async {
    final m = await _dataSource.fetchDashboardMetrics();
    if (mounted) {
      setState(() {
        _metrics = m;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Slate 100
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isLoading) const LinearProgressIndicator(),
            // Top Page Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Professional (Pro) Marketplace Dashboard',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Full Control & Management of Local Professional Shops, Products & Subscriptions',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _openAddCategoryModal(context),
                  icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                  label: const Text('Add Category', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5), // Indigo / Purple from Reference
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 1. Top 4 KPI Metrics Row (Matching Reference Image #3)
            LayoutBuilder(
              builder: (ctx, constraints) {
                final isWide = constraints.maxWidth > 900;
                return GridView.count(
                  crossAxisCount: isWide ? 4 : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: isWide ? 2.3 : 1.8,
                  children: [
                    _buildKpiCard('Total Professional Shops', '${_metrics['totalShops']}', Icons.storefront_rounded, const Color(0xFF4F46E5)),
                    _buildKpiCard('Active Shops', '${_metrics['activeShops']}', Icons.verified_rounded, const Color(0xFF059669)),
                    _buildKpiCard('Total Orders', '${_metrics['totalOrders']}', Icons.receipt_long_rounded, const Color(0xFF0284C7)),
                    _buildKpiCard('Total Sales', '₹${((_metrics['totalSales'] as num?) ?? 0).toInt()}', Icons.currency_rupee_rounded, const Color(0xFFD97706)),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // 2. Charts Section (Sales Overview & Orders Overview)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sales Overview Chart Card
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Sales Overview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            Text('Monthly Trends', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Container(
                          height: 160,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _buildBarColumn('Oct 1', 0.4),
                                _buildBarColumn('Oct 8', 0.65),
                                _buildBarColumn('Oct 15', 0.5),
                                _buildBarColumn('Oct 22', 0.85),
                                _buildBarColumn('Oct 29', 0.7),
                                _buildBarColumn('Nov 5', 0.95),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Orders Overview Donut/Pie Card
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Orders Overview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        const SizedBox(height: 16),
                        Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 130,
                                height: 130,
                                child: CircularProgressIndicator(
                                  value: 0.78,
                                  strokeWidth: 16,
                                  backgroundColor: const Color(0xFFE2E8F0),
                                  color: const Color(0xFF059669),
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('${_metrics['totalOrders']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                                  const Text('Total', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildLegendItem('Delivered', const Color(0xFF059669)),
                            _buildLegendItem('Preparing', const Color(0xFF0284C7)),
                            _buildLegendItem('Pending', const Color(0xFFD97706)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 3. Three-Column Management Grid (Categories, Shops, Shop Details)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Diamond Categories Table (Matching Reference Image)
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Professional Categories', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            ElevatedButton(
                              onPressed: () => _openAddCategoryModal(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4F46E5),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              child: const Text('+ Add', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        StreamBuilder<List<Map<String, dynamic>>>(
                          stream: _dataSource.streamCategories(),
                          builder: (context, snap) {
                            final cats = snap.data ?? [];
                            if (cats.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Center(
                                  child: Text('No categories found. Click "Add Category" above to create one.', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                                ),
                              );
                            }
                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: cats.length,
                              separatorBuilder: (_, __) => const Divider(height: 14),
                              itemBuilder: (ctx, i) {
                                final c = cats[i];
                                final isAct = (c['isActive'] as bool?) ?? true;
                                return Row(
                                  children: [
                                    const Icon(Icons.shopping_bag_outlined, color: Color(0xFF4F46E5), size: 18),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            c['titleEnglish'] ?? c['name'] ?? '',
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                          ),
                                          if (c['titleHindi'] != null && c['titleHindi'].toString().isNotEmpty)
                                            Text(
                                              c['titleHindi'],
                                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                            ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF64748B)),
                                      onPressed: () => _openEditCategoryModal(context, c),
                                      tooltip: 'Edit Category',
                                    ),
                                    Switch(
                                      value: isAct,
                                      activeColor: const Color(0xFF059669),
                                      onChanged: (val) {
                                        _dataSource.toggleCategoryActive(c['id'] ?? c['slug'], val);
                                      },
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Shops (Diamond) Directory (Matching Reference Image)
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Shops (Professional)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        const Divider(height: 20),
                        StreamBuilder<List<Map<String, dynamic>>>(
                          stream: _dataSource.streamShops(),
                          builder: (context, snap) {
                            final shops = snap.data ?? [];
                            if (shops.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 30),
                                child: Center(
                                  child: Text('No professional shops registered yet.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                                ),
                              );
                            }
                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: shops.length,
                              separatorBuilder: (_, __) => const Divider(height: 14),
                              itemBuilder: (ctx, i) {
                                final s = shops[i];
                                final isSelected = _selectedShop?['id'] == s['id'];
                                return InkWell(
                                  onTap: () => _onSelectShop(s),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFFEEF2FF) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: const Color(0xFFE0E7FF),
                                          child: const Icon(Icons.storefront_rounded, color: Color(0xFF4F46E5), size: 18),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(s['shopName'] ?? '', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                                              Text(s['jamuiArea'] ?? 'Jamui', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                                            ],
                                          ),
                                        ),
                                        _buildShopStatusBadge(s['status'] ?? 'pending', s['isActive'] ?? true, isSubscriptionActive: s['isSubscriptionActive'] as bool?),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Shop Details Inspector (Phase 2H Complete Admin Inspector)
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: _selectedShop == null
                        ? _buildSelectShopPrompt()
                        : _buildDetailedShopInspector(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 4. Bottom Row: Subscription Plans & Orders Monitoring
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Subscription Plans Management Table (Matching Reference Image)
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Subscription Plans (Dynamic)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            ElevatedButton.icon(
                              onPressed: () => _openAddPlanModal(context),
                              icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                              label: const Text('Add Plan', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        StreamBuilder<List<Map<String, dynamic>>>(
                          stream: _dataSource.streamPlans(),
                          builder: (context, snap) {
                            final plans = snap.data ?? [];
                            if (plans.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                  child: Text('No subscription plans created yet. Click "Add Plan" above to create one.', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                                ),
                              );
                            }
                            return Table(
                              columnWidths: const {
                                0: FlexColumnWidth(2),
                                1: FlexColumnWidth(1.1),
                                2: FlexColumnWidth(1.4),
                                3: FlexColumnWidth(1.3),
                                4: FlexColumnWidth(1.3),
                                5: FlexColumnWidth(1.2),
                                6: FlexColumnWidth(1.8),
                              },
                              children: [
                                TableRow(
                                  decoration: BoxDecoration(color: Colors.grey.shade100),
                                  children: const [
                                    Padding(padding: EdgeInsets.all(8), child: Text('Plan Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                    Padding(padding: EdgeInsets.all(8), child: Text('Price', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                    Padding(padding: EdgeInsets.all(8), child: Text('Duration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                    Padding(padding: EdgeInsets.all(8), child: Text('Products', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                    Padding(padding: EdgeInsets.all(8), child: Text('Images/Mo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                    Padding(padding: EdgeInsets.all(8), child: Text('Storage', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                    Padding(padding: EdgeInsets.all(8), child: Text('Status & Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                  ],
                                ),
                                ...plans.map((p) {
                                  final isAct = (p['isActive'] as bool?) ?? true;
                                  final duration = p['durationDays'];
                                  return TableRow(
                                    children: [
                                      Padding(padding: const EdgeInsets.all(8), child: Text(p['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5))),
                                      Padding(padding: const EdgeInsets.all(8), child: Text('₹${p['price']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF059669), fontSize: 12.5))),
                                      Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: duration != null
                                            ? Text('$duration Days', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))
                                            : Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFEF3C7),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: const Color(0xFFF59E0B)),
                                                ),
                                                child: const Text('Not Configured', style: TextStyle(color: Color(0xFFB45309), fontSize: 10, fontWeight: FontWeight.bold)),
                                              ),
                                      ),
                                      Padding(padding: const EdgeInsets.all(8), child: Text('${p['maxProducts']} prods', style: const TextStyle(fontSize: 12))),
                                      Padding(padding: const EdgeInsets.all(8), child: Text('${p['maxImagesPerMonth']}', style: const TextStyle(fontSize: 12))),
                                      Padding(padding: const EdgeInsets.all(8), child: Text('${p['storageMb']} MB', style: const TextStyle(fontSize: 12))),
                                      Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Switch(
                                              value: isAct,
                                              activeColor: const Color(0xFF059669),
                                              onChanged: (val) {
                                                if (p['id'] != null) {
                                                  _dataSource.togglePlanActive(p['id'], val);
                                                }
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF64748B)),
                                              onPressed: () => _openEditPlanModal(context, p),
                                              tooltip: 'Edit Plan',
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // City-Wide Orders Monitoring (Matching Reference Image)
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Orders Monitoring', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        const Divider(height: 20),
                        StreamBuilder<List<Map<String, dynamic>>>(
                          stream: _dataSource.streamOrders(),
                          builder: (context, snap) {
                            final orders = snap.data ?? [];
                            if (orders.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                  child: Text('No orders placed yet.', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                                ),
                              );
                            }
                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: orders.take(4).length,
                              separatorBuilder: (_, __) => const Divider(height: 12),
                              itemBuilder: (ctx, i) {
                                final o = orders[i];
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('#${o['id']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                        Text(o['shopName'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                      ],
                                    ),
                                    Text('₹${o['totalAmount']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF059669), fontSize: 13)),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ],
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

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(title, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
            ],
          ),
          CircleAvatar(
            radius: 22,
            backgroundColor: color.withOpacity(0.12),
            child: Icon(icon, color: color, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildBarColumn(String label, double pct) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 24,
          height: 100 * pct,
          decoration: BoxDecoration(
            color: const Color(0xFF4F46E5),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildShopStatusBadge(String status, bool isActive, {bool? isSubscriptionActive}) {
    final s = status.toLowerCase();
    String label = 'Pending';
    Color bg = const Color(0xFFFFF3E0);
    Color fg = const Color(0xFFE65100);

    if (!isActive || s == 'suspended') {
      label = 'Suspended';
      bg = const Color(0xFFFFEBEE);
      fg = const Color(0xFFC62828);
    } else if (s == 'rejected') {
      label = 'Rejected';
      bg = const Color(0xFFFFEBEE);
      fg = const Color(0xFFC62828);
    } else if (isSubscriptionActive == false) {
      label = 'Unpaid / Expired';
      bg = const Color(0xFFF3E5F5);
      fg = const Color(0xFF7B1FA2);
    } else if (s == 'approved' && isActive) {
      label = 'Live / Approved';
      bg = const Color(0xFFE0F2F1);
      fg = const Color(0xFF00796B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildDetailedShopInspector() {
    final s = _selectedShop!;
    final ownerName = (s['ownerName'] as String?)?.trim().isNotEmpty == true
        ? (s['ownerName'] as String).trim()
        : ((s['fullName'] as String?)?.trim().isNotEmpty == true
            ? (s['fullName'] as String).trim()
            : ((s['name'] as String?)?.trim().isNotEmpty == true
                ? (s['name'] as String).trim()
                : 'N/A'));
    final ownerPhone = (s['ownerPhone'] as String?)?.trim().isNotEmpty == true
        ? (s['ownerPhone'] as String).trim()
        : ((s['phone'] as String?)?.trim().isNotEmpty == true
            ? (s['phone'] as String).trim()
            : ((s['mobile'] as String?)?.trim().isNotEmpty == true
                ? (s['mobile'] as String).trim()
                : ((s['contactPhone'] as String?)?.trim().isNotEmpty == true
                    ? (s['contactPhone'] as String).trim()
                    : 'N/A')));
    final ownerEmail = (s['ownerEmail'] as String?)?.trim().isNotEmpty == true
        ? (s['ownerEmail'] as String).trim()
        : ((s['email'] as String?)?.trim().isNotEmpty == true
            ? (s['email'] as String).trim()
            : 'N/A');
    final ownerUid = (s['ownerUid'] as String?)?.trim().isNotEmpty == true
        ? (s['ownerUid'] as String).trim()
        : (s['id'] as String);

    final status = (s['status'] ?? 'pending').toString().toLowerCase();
    final isActive = (s['isActive'] as bool?) ?? false;
    final isSubscriptionActive = (s['isSubscriptionActive'] as bool?) ?? false;

    final pay = _shopInspectionData?['latestPayment'] as Map<String, dynamic>?;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Shop Icon, Name & ID
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFE0E7FF),
                child: const Icon(Icons.store_mall_directory_rounded, color: Color(0xFF4F46E5), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s['shopName'] ?? 'Shop', style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
                    Text('UID: $ownerUid', style: const TextStyle(fontSize: 10.5, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              _buildShopStatusBadge(status, isActive, isSubscriptionActive: isSubscriptionActive),
            ],
          ),
          const Divider(height: 18),

          // Section 1: Seller & Owner Verification
          _buildInspectorSectionHeader('Seller & Owner Verification', Icons.badge_outlined),
          _buildInspectorRow('Owner Name:', ownerName),
          _buildInspectorRow('Owner Mobile:', ownerPhone),
          _buildInspectorRow('Owner Email:', ownerEmail),
          _buildInspectorRow('Owner UID:', ownerUid),
          const SizedBox(height: 10),

          // Section 2: Shop & Locality
          _buildInspectorSectionHeader('Shop Profile & Locality', Icons.storefront_outlined),
          _buildInspectorRow('Category:', (s['demandCategoryTitle'] ?? s['demandCategoryId'] ?? 'General').toString()),
          _buildInspectorRow('Locality:', (s['jamuiArea'] ?? 'Jamui').toString()),
          _buildInspectorRow('Address:', (s['fullAddress'] ?? 'Jamui, Bihar').toString()),
          _buildInspectorRow('Shop Phone:', (s['contactPhone'] ?? s['phone'] ?? ownerPhone).toString()),
          if ((s['whatsAppNumber'] as String?)?.isNotEmpty == true)
            _buildInspectorRow('WhatsApp:', s['whatsAppNumber'].toString()),
          const SizedBox(height: 10),

          // Section 3: Subscription & Pro Plan
          _buildInspectorSectionHeader('Subscription & Pro Plan', Icons.card_membership_outlined),
          _buildInspectorRow('Pro Plan:', (s['planName'] ?? s['planId'] ?? 'No Plan Selected').toString()),
          _buildInspectorRow(
            'Plan Price:',
            s['planPrice'] != null ? '₹${s['planPrice']} / ${s['planDurationDays'] ?? 30} days' : 'Free / Pending',
          ),
          _buildInspectorRow(
            'Subscription:',
            isSubscriptionActive ? 'ACTIVE' : 'INACTIVE / EXPIRED',
            valueColor: isSubscriptionActive ? const Color(0xFF059669) : const Color(0xFFDC2626),
          ),
          _buildInspectorRow('Expires On:', _formatTimestamp(s['subscriptionExpiresAt'] ?? s['subscriptionExpiry'])),
          const SizedBox(height: 10),

          // Section 4: Razorpay Payment Verification
          _buildInspectorSectionHeader('Razorpay Payment Verification', Icons.payments_outlined),
          if (pay != null) ...[
            _buildInspectorRow(
              'Payment Status:',
              (pay['status'] ?? 'verified').toString().toUpperCase(),
              valueColor: (pay['status'] == 'captured' || pay['status'] == 'verified') ? const Color(0xFF059669) : const Color(0xFFD97706),
            ),
            _buildInspectorRow('Payment ID:', (pay['paymentId'] ?? pay['razorpay_payment_id'] ?? 'N/A').toString()),
            _buildInspectorRow('Razorpay Order:', (pay['orderId'] ?? pay['razorpay_order_id'] ?? 'N/A').toString()),
            _buildInspectorRow('Verified At:', _formatTimestamp(pay['verifiedAt'] ?? pay['createdAt'])),
          ] else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'No Razorpay payment records on file.',
                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
              ),
            ),
          const SizedBox(height: 10),

          // Section 5: Real-time Catalog & Categories
          _buildInspectorSectionHeader('Catalog & Store Categories', Icons.inventory_2_outlined),
          if (_isLoadingInspection)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else ...[
            _buildInspectorRow(
              'Store Categories:',
              '${_shopInspectionData?['totalStoreCategories'] ?? 0} (${_shopInspectionData?['activeStoreCategories'] ?? 0} Active)',
            ),
            _buildInspectorRow(
              'Products Count:',
              '${_shopInspectionData?['totalProducts'] ?? 0} (${_shopInspectionData?['activeProducts'] ?? 0} Live, ${_shopInspectionData?['inactiveProducts'] ?? 0} Off)',
            ),
            _buildInspectorRow('Total Orders:', '${_shopInspectionData?['totalOrders'] ?? 0}'),
            _buildInspectorRow(
              'Delivered / Cancel:',
              '${_shopInspectionData?['deliveredOrders'] ?? 0} / ${_shopInspectionData?['cancelledOrders'] ?? 0}',
            ),
            _buildInspectorRow(
              'Gross Order Value:',
              '₹${((_shopInspectionData?['totalOrderValue'] as num?) ?? 0).toInt()}',
              valueColor: const Color(0xFF059669),
            ),
          ],
          const SizedBox(height: 10),

          // Section 6: Audit Timestamps
          _buildInspectorSectionHeader('Audit Timestamps', Icons.history_rounded),
          _buildInspectorRow('Created At:', _formatTimestamp(s['createdAt'])),
          _buildInspectorRow('Last Updated:', _formatTimestamp(s['updatedAt'])),
          const SizedBox(height: 16),

          // Section 7: Admin Actions
          Row(
            children: [
              if (status != 'approved')
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      _dataSource.updateShopStatus(s['id'], 'approved', isActive: true);
                      _onSelectShop({...s, 'status': 'approved', 'isActive': true, 'isApproved': true});
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: const Text('Approve Shop', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              if (status == 'approved' && isActive) ...[
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      _dataSource.updateShopStatus(s['id'], 'suspended', isActive: false);
                      _onSelectShop({...s, 'status': 'suspended', 'isActive': false});
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: const Text('Suspend Shop', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
              if (status == 'suspended' || !isActive) ...[
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      _dataSource.updateShopStatus(s['id'], 'approved', isActive: true);
                      _onSelectShop({...s, 'status': 'approved', 'isActive': true, 'isApproved': true});
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: const Text('Reactivate Shop', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
              if (status == 'pending') ...[
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      _dataSource.updateShopStatus(s['id'], 'rejected', isActive: false);
                      _onSelectShop({...s, 'status': 'rejected', 'isActive': false, 'isApproved': false});
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: const Text('Reject', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInspectorSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF4F46E5)),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF4F46E5), letterSpacing: 0.2),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectShopPrompt() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.touch_app_outlined, size: 40, color: Colors.grey),
          SizedBox(height: 10),
          Text('Select a shop to inspect details', style: TextStyle(color: Colors.grey, fontSize: 12.5)),
        ],
      ),
    );
  }

  Widget _buildInspectorRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: valueColor ?? const Color(0xFF1E293B),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _openAddCategoryModal(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final hindiCtrl = TextEditingController();
    final slugCtrl = TextEditingController();
    final iconCtrl = TextEditingController(text: 'shopping_bag');
    final priorityCtrl = TextEditingController(text: '10');
    bool isSaving = false;
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Add Professional Category', style: TextStyle(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 440,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFEF4444)),
                          ),
                          child: Text(
                            errorMessage!,
                            style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12.5),
                          ),
                        ),
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Category Name (English) *',
                          hintText: 'e.g. Bakery & Sweets',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter category name' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: hindiCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Category Name (Hindi) (Optional)',
                          hintText: 'e.g. बेकरी और मिठाई',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: slugCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Slug (Unique Identifier) *',
                          hintText: 'e.g. bakery_sweets',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter a slug' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: iconCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Icon URL / Identifier',
                          hintText: 'e.g. bakery or https://...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: priorityCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Priority Order (Lower shows first)',
                          hintText: '10',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return null;
                          if (int.tryParse(val.trim()) == null) return 'Must be a valid integer';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() {
                          isSaving = true;
                          errorMessage = null;
                        });

                        try {
                          await _dataSource.addCategory(
                            titleEnglish: nameCtrl.text.trim(),
                            titleHindi: hindiCtrl.text.trim().isNotEmpty ? hindiCtrl.text.trim() : nameCtrl.text.trim(),
                            slug: slugCtrl.text.trim().toLowerCase(),
                            iconUrl: iconCtrl.text.trim(),
                            priority: int.tryParse(priorityCtrl.text.trim()) ?? 10,
                          );
                          if (ctx.mounted) {
                            Navigator.of(ctx).pop();
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Category added successfully!'),
                                backgroundColor: Color(0xFF059669),
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() {
                            isSaving = false;
                            errorMessage = 'Failed to save category: $e';
                          });
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Add Category', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openEditCategoryModal(BuildContext context, Map<String, dynamic> category) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: category['titleEnglish'] ?? category['name'] ?? '');
    final hindiCtrl = TextEditingController(text: category['titleHindi'] ?? '');
    final iconCtrl = TextEditingController(text: category['iconUrl'] ?? '');
    final priorityCtrl = TextEditingController(text: (category['priorityOrder'] ?? 10).toString());
    final slug = (category['slug'] ?? category['id'] ?? '').toString();
    bool isSaving = false;
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text('Edit Category: $slug', style: const TextStyle(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 440,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFEF4444)),
                          ),
                          child: Text(
                            errorMessage!,
                            style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12.5),
                          ),
                        ),
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Category Name (English) *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter category name' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: hindiCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Category Name (Hindi)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: iconCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Icon URL / Identifier',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: priorityCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Priority Order',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return null;
                          if (int.tryParse(val.trim()) == null) return 'Must be a valid integer';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() {
                          isSaving = true;
                          errorMessage = null;
                        });

                        try {
                          await _dataSource.updateCategory(
                            slug: slug,
                            titleEnglish: nameCtrl.text.trim(),
                            titleHindi: hindiCtrl.text.trim().isNotEmpty ? hindiCtrl.text.trim() : nameCtrl.text.trim(),
                            iconUrl: iconCtrl.text.trim(),
                            priority: int.tryParse(priorityCtrl.text.trim()) ?? 10,
                          );
                          if (ctx.mounted) {
                            Navigator.of(ctx).pop();
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Category updated successfully!'),
                                backgroundColor: Color(0xFF059669),
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() {
                            isSaving = false;
                            errorMessage = 'Failed to update category: $e';
                          });
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save Changes', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openAddPlanModal(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final durationCtrl = TextEditingController(text: '30');
    final prodsCtrl = TextEditingController(text: '100');
    final imagesCtrl = TextEditingController(text: '200');
    final storageCtrl = TextEditingController(text: '250');
    bool isSaving = false;
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Add Subscription Plan', style: TextStyle(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 440,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFEF4444)),
                          ),
                          child: Text(
                            errorMessage!,
                            style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12.5),
                          ),
                        ),
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Plan Name *',
                          hintText: 'e.g. Gold Seller Plan',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter plan name' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Price (₹) *',
                          hintText: 'e.g. 299',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Please enter price';
                          final num = double.tryParse(val.trim());
                          if (num == null || num < 0) return 'Please enter a valid price (>= 0)';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: durationCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Duration in Days *',
                          hintText: 'e.g. 30, 90, 365',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Please enter duration in days';
                          final num = int.tryParse(val.trim());
                          if (num == null || num <= 0) return 'Must be a positive integer';
                          if (num > 3650) return 'Duration cannot exceed 3650 days (10 years)';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: prodsCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Max Products *',
                          hintText: '100',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Please enter product limit';
                          final num = int.tryParse(val.trim());
                          if (num == null || num <= 0) return 'Must be a positive integer';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: imagesCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Images / Month *',
                          hintText: '200',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Please enter images limit';
                          final num = int.tryParse(val.trim());
                          if (num == null || num < 0) return 'Must be an integer >= 0';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: storageCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Storage (MB) *',
                          hintText: '250',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Please enter storage in MB';
                          final num = int.tryParse(val.trim());
                          if (num == null || num <= 0) return 'Must be a positive integer';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() {
                          isSaving = true;
                          errorMessage = null;
                        });

                        try {
                          await _dataSource.addPlan(
                            name: nameCtrl.text.trim(),
                            price: double.parse(priceCtrl.text.trim()),
                            durationDays: int.parse(durationCtrl.text.trim()),
                            maxProducts: int.parse(prodsCtrl.text.trim()),
                            maxImagesPerMonth: int.parse(imagesCtrl.text.trim()),
                            storageMb: int.parse(storageCtrl.text.trim()),
                          );
                          if (ctx.mounted) {
                            Navigator.of(ctx).pop();
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Subscription plan published successfully!'),
                                backgroundColor: Color(0xFF059669),
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() {
                            isSaving = false;
                            errorMessage = 'Failed to publish plan: $e';
                          });
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Publish Plan', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openEditPlanModal(BuildContext context, Map<String, dynamic> plan) {
    final formKey = GlobalKey<FormState>();
    final planId = (plan['id'] ?? '').toString();
    final nameCtrl = TextEditingController(text: plan['name'] ?? '');
    final priceCtrl = TextEditingController(text: (plan['price'] ?? 0).toString());
    final durationCtrl = TextEditingController(
      text: plan['durationDays'] != null ? plan['durationDays'].toString() : '',
    );
    final prodsCtrl = TextEditingController(text: (plan['maxProducts'] ?? 100).toString());
    final imagesCtrl = TextEditingController(text: (plan['maxImagesPerMonth'] ?? 200).toString());
    final storageCtrl = TextEditingController(text: (plan['storageMb'] ?? 250).toString());
    bool isSaving = false;
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text('Edit Plan: ${plan['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 440,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFEF4444)),
                          ),
                          child: Text(
                            errorMessage!,
                            style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12.5),
                          ),
                        ),
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Plan Name *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter plan name' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Price (₹) *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Please enter price';
                          final num = double.tryParse(val.trim());
                          if (num == null || num < 0) return 'Please enter a valid price (>= 0)';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: durationCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Duration in Days *',
                          hintText: 'e.g. 30, 90, 365',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Please enter duration in days';
                          final num = int.tryParse(val.trim());
                          if (num == null || num <= 0) return 'Must be a positive integer';
                          if (num > 3650) return 'Duration cannot exceed 3650 days (10 years)';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: prodsCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Max Products *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Please enter product limit';
                          final num = int.tryParse(val.trim());
                          if (num == null || num <= 0) return 'Must be a positive integer';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: imagesCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Images / Month *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Please enter images limit';
                          final num = int.tryParse(val.trim());
                          if (num == null || num < 0) return 'Must be an integer >= 0';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: storageCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Storage (MB) *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Please enter storage in MB';
                          final num = int.tryParse(val.trim());
                          if (num == null || num <= 0) return 'Must be a positive integer';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() {
                          isSaving = true;
                          errorMessage = null;
                        });

                        try {
                          await _dataSource.updatePlan(
                            planId: planId,
                            name: nameCtrl.text.trim(),
                            price: double.parse(priceCtrl.text.trim()),
                            durationDays: int.parse(durationCtrl.text.trim()),
                            maxProducts: int.parse(prodsCtrl.text.trim()),
                            maxImagesPerMonth: int.parse(imagesCtrl.text.trim()),
                            storageMb: int.parse(storageCtrl.text.trim()),
                          );
                          if (ctx.mounted) {
                            Navigator.of(ctx).pop();
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Subscription plan updated successfully!'),
                                backgroundColor: Color(0xFF059669),
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() {
                            isSaving = false;
                            errorMessage = 'Failed to update plan: $e';
                          });
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save Changes', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }
}

