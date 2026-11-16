import 'package:flutter/material.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../../../core/localization/provider_strings.dart';
import '../../../../core/localization/language_selection_modal.dart';
import '../../data/datasources/professional_provider_remote_data_source.dart';
import '../../domain/entities/seller_stock_movement_entity.dart';

/// Professional Seller Inventory Management Page
/// Features:
/// 1. 4 Stock KPI summary cards (Total units, In stock, Low stock with custom thresholds, Out of stock).
/// 2. Stock Items Tab with search, filter chips, dynamic low-stock alerts, and desktop data table.
/// 3. Stock Movement History Ledger Tab tracking all inward, outward, order sales, and returns.
/// 4. Atomic Stock Adjustment BottomSheet with server-side validation.
class ProfessionalShopInventoryPage extends StatefulWidget {
  final String shopId;
  final ProfessionalProviderRemoteDataSource? dataSource;

  const ProfessionalShopInventoryPage({
    super.key,
    required this.shopId,
    this.dataSource,
  });

  @override
  State<ProfessionalShopInventoryPage> createState() => _ProfessionalShopInventoryPageState();
}

class _ProfessionalShopInventoryPageState extends State<ProfessionalShopInventoryPage> {
  late final ProfessionalProviderRemoteDataSource _dataSource;
  late final Stream<List<Map<String, dynamic>>> _productsStream;
  late final Stream<List<SellerStockMovementEntity>> _movementsStream;

  String _selectedFilter = 'All'; // 'All', 'In Stock', 'Low Stock', 'Out of Stock'
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _dataSource = widget.dataSource ?? ProfessionalProviderRemoteDataSource();
    _productsStream = _dataSource.streamProducts(widget.shopId);
    _movementsStream = _dataSource.streamStockMovements(widget.shopId, limit: 100);
  }

  String _formatStock(num? val) {
    if (val == null) return '0';
    if (val % 1 == 0) return val.toInt().toString();
    return val.toStringAsFixed(3).replaceAll(RegExp(r'\.?0+$'), '');
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          title: Text(
            ProviderStrings.inventoryManagement,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          actions: [
            IconButton(
              tooltip: ProviderStrings.selectLanguage,
              icon: const Icon(Icons.language_rounded, color: Color(0xFF0F766E)),
              onPressed: () => LanguageSelectionModal.show(context),
            ),
            const SizedBox(width: 8),
          ],
          bottom: TabBar(
            labelColor: const Color(0xFF0F766E),
            unselectedLabelColor: const Color(0xFF64748B),
            indicatorColor: const Color(0xFF0F766E),
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            tabs: [
              Tab(
                icon: const Icon(Icons.inventory_2_rounded, size: 18),
                text: ProviderStrings.stockItems,
              ),
              Tab(
                icon: const Icon(Icons.history_rounded, size: 18),
                text: ProviderStrings.movementHistory,
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // TAB 1: STOCK ITEMS VIEW
            _buildStockItemsTab(),

            // TAB 2: STOCK MOVEMENT HISTORY LEDGER
            _buildStockHistoryTab(),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 1: STOCK ITEMS VIEW
  // ===========================================================================
  Widget _buildStockItemsTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _productsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF0F766E)),
          );
        }

        final allProducts = snapshot.data ?? [];

        // Calculate Inventory Metrics based on per-product threshold
        int totalStockUnits = 0;
        int inStockCount = 0;
        int lowStockCount = 0;
        int outOfStockCount = 0;

        for (final p in allProducts) {
          final qty = (p['stockQuantity'] as num?)?.toInt() ?? 0;
          final threshold = (p['lowStockThreshold'] as num?)?.toInt() ?? 5;
          final inStock = (p['inStock'] as bool?) ?? true;

          totalStockUnits += qty;

          if (!inStock || qty <= 0) {
            outOfStockCount++;
          } else if (qty <= threshold) {
            lowStockCount++;
            inStockCount++;
          } else {
            inStockCount++;
          }
        }

        // Apply filters
        final filtered = allProducts.where((p) {
          final qty = (p['stockQuantity'] as num?)?.toInt() ?? 0;
          final threshold = (p['lowStockThreshold'] as num?)?.toInt() ?? 5;
          final inStock = (p['inStock'] as bool?) ?? true;

          if (_selectedFilter == 'In Stock' && (!inStock || qty <= 0)) {
            return false;
          }
          if (_selectedFilter == 'Low Stock' && (!inStock || qty <= 0 || qty > threshold)) {
            return false;
          }
          if (_selectedFilter == 'Out of Stock' && (inStock && qty > 0)) {
            return false;
          }

          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            final title = (p['titleEnglish'] ?? p['titleHindi'] ?? p['title'] ?? '').toString().toLowerCase();
            if (!title.contains(q)) return false;
          }
          return true;
        }).toList();

        return Column(
          children: [
            // 4 Stock KPI Summary Cards
            Container(
              width: double.infinity,
              color: Colors.white,
              child: ResponsiveContentContainer(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: LayoutBuilder(
                  builder: (context, kpiConstraints) {
                    final cards = [
                      _buildKpiCard(
                        title: 'कुल स्टॉक यूनिट्स',
                        value: '$totalStockUnits',
                        icon: Icons.inventory_2_rounded,
                        iconColor: const Color(0xFF1D4ED8),
                        bgColor: const Color(0xFFEFF6FF),
                      ),
                      _buildKpiCard(
                        title: 'स्टॉक में उपलब्ध',
                        value: '$inStockCount',
                        icon: Icons.check_circle_rounded,
                        iconColor: const Color(0xFF2E7D32),
                        bgColor: const Color(0xFFE8F5E9),
                      ),
                      _buildKpiCard(
                        title: 'कम स्टॉक उत्पाद',
                        value: '$lowStockCount',
                        icon: Icons.warning_amber_rounded,
                        iconColor: const Color(0xFFE65100),
                        bgColor: const Color(0xFFFFF3E0),
                      ),
                      _buildKpiCard(
                        title: 'आउट ऑफ स्टॉक',
                        value: '$outOfStockCount',
                        icon: Icons.cancel_rounded,
                        iconColor: const Color(0xFFC62828),
                        bgColor: const Color(0xFFFFEBEE),
                      ),
                    ];
                    if (kpiConstraints.maxWidth >= 700) {
                      return Row(
                        children: cards
                            .map((c) => Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: c,
                                  ),
                                ))
                            .toList(),
                      );
                    } else {
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: cards[0]),
                              const SizedBox(width: 8),
                              Expanded(child: cards[1]),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(child: cards[2]),
                              const SizedBox(width: 8),
                              Expanded(child: cards[3]),
                            ],
                          ),
                        ],
                      );
                    }
                  },
                ),
              ),
            ),

            // Search Bar & Filters
            Container(
              color: Colors.white,
              child: ResponsiveContentContainer(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  children: [
                    Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search_rounded, color: Colors.grey, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              onChanged: (v) => setState(() => _searchQuery = v),
                              decoration: const InputDecoration(
                                hintText: 'उत्पाद खोजें...',
                                hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                          if (_searchQuery.isNotEmpty)
                            GestureDetector(
                              onTap: () => setState(() => _searchQuery = ''),
                              child: const Icon(Icons.clear_rounded, size: 18, color: Colors.grey),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('सभी (${allProducts.length})', 'All'),
                          const SizedBox(width: 8),
                          _buildFilterChip('उपलब्ध ($inStockCount)', 'In Stock'),
                          const SizedBox(width: 8),
                          _buildFilterChip('कम स्टॉक ($lowStockCount)', 'Low Stock'),
                          const SizedBox(width: 8),
                          _buildFilterChip('आउट ऑफ स्टॉक ($outOfStockCount)', 'Out of Stock'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Inventory List / Desktop Table
            Expanded(
              child: filtered.isEmpty
                  ? _buildEmptyState()
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final isDesktop = constraints.maxWidth >= 960;
                        if (isDesktop) {
                          return _buildDesktopInventoryTable(filtered);
                        }
                        return SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: ResponsiveContentContainer(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: ResponsiveCardGrid(
                              tabletColumns: 2,
                              desktopColumns: 2,
                              largeDesktopColumns: 3,
                              children: filtered.map(_buildInventoryTile).toList(),
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

  // ===========================================================================
  // TAB 2: STOCK MOVEMENT HISTORY LEDGER
  // ===========================================================================
  Widget _buildStockHistoryTab() {
    return StreamBuilder<List<SellerStockMovementEntity>>(
      stream: _movementsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF0F766E)),
          );
        }

        final movements = snapshot.data ?? [];

        if (movements.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.history_toggle_off_rounded, size: 56, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                const Text(
                  'कोई स्टॉक रिकॉर्ड मौजूद नहीं है',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 4),
                const Text(
                  'स्टॉक समायोजन या बिक्री होने पर यहाँ इतिहास दिखेगा।',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ResponsiveContentContainer(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: ListView.separated(
            itemCount: movements.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final m = movements[index];
              return _buildStockMovementCard(m);
            },
          ),
        );
      },
    );
  }

  Widget _buildStockMovementCard(SellerStockMovementEntity m) {
    Color typeBg;
    Color typeFg;
    IconData typeIcon;

    switch (m.movementType) {
      case 'order_deduction':
        typeBg = const Color(0xFFFFE4E6);
        typeFg = const Color(0xFFE11D48);
        typeIcon = Icons.shopping_bag_outlined;
        break;
      case 'order_restoration':
        typeBg = const Color(0xFFDCFCE7);
        typeFg = const Color(0xFF16A34A);
        typeIcon = Icons.replay_rounded;
        break;
      case 'initial':
        typeBg = const Color(0xFFEFF6FF);
        typeFg = const Color(0xFF2563EB);
        typeIcon = Icons.flag_rounded;
        break;
      case 'manual_inward':
        typeBg = const Color(0xFFDCFCE7);
        typeFg = const Color(0xFF16A34A);
        typeIcon = Icons.arrow_downward_rounded;
        break;
      case 'manual_outward':
        typeBg = const Color(0xFFFFF7ED);
        typeFg = const Color(0xFFEA580C);
        typeIcon = Icons.arrow_upward_rounded;
        break;
      default:
        typeBg = const Color(0xFFF1F5F9);
        typeFg = const Color(0xFF475569);
        typeIcon = Icons.tune_rounded;
    }

    final dateStr = '${m.createdAt.day.toString().padLeft(2, '0')}/${m.createdAt.month.toString().padLeft(2, '0')}/${m.createdAt.year} ${m.createdAt.hour.toString().padLeft(2, '0')}:${m.createdAt.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: typeBg,
            child: Icon(typeIcon, color: typeFg, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        m.productName,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      m.formattedChange,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: m.isInward ? const Color(0xFF16A34A) : const Color(0xFFE11D48),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: typeBg, borderRadius: BorderRadius.circular(4)),
                      child: Text(
                        m.movementTypeDisplayHindi,
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: typeFg),
                      ),
                    ),
                    if (m.orderNumber != null)
                      Text(
                        '#${m.orderNumber}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                      ),
                    Text(
                      '${m.previousStock} → ${m.newStock} इकाई',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                if (m.reason.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    m.reason,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  dateStr,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // DESKTOP INVENTORY DATA TABLE
  // ===========================================================================
  Widget _buildDesktopInventoryTable(List<Map<String, dynamic>> items) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ResponsiveContentContainer(
        padding: EdgeInsets.zero,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    columnSpacing: 20,
                    horizontalMargin: 16,
                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                    columns: const [
                      DataColumn(label: Text('उत्पाद (Product)', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('श्रेणी (Category)', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('मूल्य (Selling Price)', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('वर्तमान स्टॉक (Stock)', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('स्थिति (Status)', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('कार्रवाई (Action)', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: items.map((product) {
                      final title = product['titleEnglish'] ?? product['titleHindi'] ?? product['title'] ?? 'Product';
                      final category = product['storeCategoryName'] ?? product['categoryName'] ?? 'General';
                      final price = product['sellingPrice'] ?? product['price'] ?? 0;
                      final qty = (product['stockQuantity'] as num?)?.toDouble() ?? 0.0;
                      final threshold = (product['lowStockThreshold'] as num?)?.toDouble() ?? 5.0;
                      final unit = product['unit'] ?? 'इकाई';
                      final inStock = (product['inStock'] as bool?) ?? true;

                      Color statusBg;
                      Color statusFg;
                      String statusText;

                      if (!inStock || qty <= 0) {
                        statusBg = const Color(0xFFFFEBEE);
                        statusFg = const Color(0xFFC62828);
                        statusText = 'आउट ऑफ स्टॉक';
                      } else if (qty <= threshold) {
                        statusBg = const Color(0xFFFFF3E0);
                        statusFg = const Color(0xFFE65100);
                        statusText = 'कम स्टॉक (<= ${_formatStock(threshold)})';
                      } else {
                        statusBg = const Color(0xFFE8F5E9);
                        statusFg = const Color(0xFF2E7D32);
                        statusText = 'उपलब्ध';
                      }

                      return DataRow(
                        cells: [
                          DataCell(
                            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          ),
                          DataCell(Text(category, style: const TextStyle(fontSize: 12.5))),
                          DataCell(Text('₹$price / $unit', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)))),
                          DataCell(
                            Text(
                              '${_formatStock(qty)} $unit',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: qty <= threshold ? Colors.red.shade700 : const Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6)),
                              child: Text(statusText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusFg)),
                            ),
                          ),
                          DataCell(
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F766E),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: const Size(0, 32),
                              ),
                              icon: const Icon(Icons.edit_rounded, size: 14),
                              label: const Text('स्टॉक बदलें', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                              onPressed: () => _showStockAdjustmentDialog(product),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // WIDGET HELPERS
  // ===========================================================================
  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white,
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: iconColor,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
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

  Widget _buildFilterChip(String label, String key) {
    final isSelected = _selectedFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F766E) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildInventoryTile(Map<String, dynamic> product) {
    final title = product['titleEnglish'] ?? product['titleHindi'] ?? product['title'] ?? 'Product';
    final qty = (product['stockQuantity'] as num?)?.toDouble() ?? 0.0;
    final threshold = (product['lowStockThreshold'] as num?)?.toDouble() ?? 5.0;
    final unit = (product['unit'] as String?) ?? 'इकाई';
    final inStock = (product['inStock'] as bool?) ?? true;

    Color badgeBg;
    Color badgeFg;
    String badgeText;

    if (!inStock || qty <= 0) {
      badgeBg = const Color(0xFFFFEBEE);
      badgeFg = const Color(0xFFC62828);
      badgeText = 'आउट ऑफ स्टॉक (0)';
    } else if (qty <= threshold) {
      badgeBg = const Color(0xFFFFF3E0);
      badgeFg = const Color(0xFFE65100);
      badgeText = 'कम स्टॉक (${_formatStock(qty)} $unit)';
    } else {
      badgeBg = const Color(0xFFE8F5E9);
      badgeFg = const Color(0xFF2E7D32);
      badgeText = 'उपलब्ध (${_formatStock(qty)} $unit)';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: badgeFg,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              minimumSize: const Size(0, 34),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => _showStockAdjustmentDialog(product),
            child: const Text('स्टॉक बदलें', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            'कोई उत्पाद नहीं मिला',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 4),
          const Text(
            'खोज शब्द बदलें या नया उत्पाद जोड़ें।',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // STOCK ADJUSTMENT BOTTOM SHEET
  // ===========================================================================
  void _showStockAdjustmentDialog(Map<String, dynamic> product) {
    final productId = product['id'] ?? '';
    final title = product['titleEnglish'] ?? product['titleHindi'] ?? product['title'] ?? 'Product';
    final currentQty = (product['stockQuantity'] as num?)?.toDouble() ?? 0.0;
    final isBulk = product['stockType'] == 'bulk';
    final unit = product['unit'] ?? 'इकाई';

    final amountController = TextEditingController();
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    String operation = 'increment'; // 'increment', 'decrement', 'set'
    bool isSubmitting = false;
    String? errorMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          num? projectedStock;
          final inputAmount = isBulk
              ? double.tryParse(amountController.text.trim())
              : int.tryParse(amountController.text.trim())?.toDouble();
          if (inputAmount != null && inputAmount >= 0) {
            if (operation == 'increment') projectedStock = currentQty + inputAmount;
            if (operation == 'decrement') projectedStock = currentQty - inputAmount;
            if (operation == 'set') projectedStock = inputAmount;
          }

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'स्टॉक समायोजन: $title',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                          child: Text(
                            'वर्तमान: ${_formatStock(currentQty)} $unit',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (projectedStock != null) ...[
                          const Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF64748B)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: (projectedStock < 0) ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'नया: ${_formatStock(projectedStock)} $unit',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: (projectedStock < 0) ? const Color(0xFFC62828) : const Color(0xFF2E7D32),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Operation Chips
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('+ बढ़ाएं')),
                            selected: operation == 'increment',
                            selectedColor: const Color(0xFFDCFCE7),
                            labelStyle: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: operation == 'increment' ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                            ),
                            onSelected: isSubmitting ? null : (_) => setModalState(() => operation = 'increment'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('- घटाएं')),
                            selected: operation == 'decrement',
                            selectedColor: const Color(0xFFFFE4E6),
                            labelStyle: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: operation == 'decrement' ? const Color(0xFFE11D48) : const Color(0xFF64748B),
                            ),
                            onSelected: isSubmitting ? null : (_) => setModalState(() => operation = 'decrement'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('= सेट करें')),
                            selected: operation == 'set',
                            selectedColor: const Color(0xFFEFF6FF),
                            labelStyle: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: operation == 'set' ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                            ),
                            onSelected: isSubmitting ? null : (_) => setModalState(() => operation = 'set'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: amountController,
                      keyboardType: isBulk
                          ? const TextInputType.numberWithOptions(decimal: true)
                          : TextInputType.number,
                      enabled: !isSubmitting,
                      onChanged: (_) => setModalState(() {}),
                      decoration: InputDecoration(
                        labelText: operation == 'set'
                            ? 'नया कुल स्टॉक (Exact Stock Count) *'
                            : 'मात्रा दर्ज करें (Amount to ${operation == 'increment' ? 'Add' : 'Deduct'}) *',
                        hintText: isBulk ? 'उदा. 10.5 या 0.5' : 'उदा. 10',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'कृपया मात्रा दर्ज करें';
                        final parsed = double.tryParse(val.trim());
                        if (parsed == null) return 'कृपया वैध संख्या दर्ज करें';
                        if (parsed < 0) return 'मात्रा नकारात्मक नहीं हो सकती';
                        if (operation != 'set' && parsed <= 0) return 'मात्रा 0 से अधिक होनी चाहिए';
                        if (!isBulk && parsed % 1 != 0) return 'पैकेट या पीस वस्तुओं के लिए पूर्ण संख्या दर्ज करें';
                        final decParts = val.trim().split('.');
                        if (decParts.length > 1 && decParts[1].length > 3) {
                          return 'अधिकतम 3 दशमलव अंक मान्य हैं (उदा. 0.250)';
                        }
                        if (operation == 'decrement' && parsed > currentQty) {
                          return 'घटाने की मात्रा वर्तमान स्टॉक (${_formatStock(currentQty)}) से अधिक नहीं हो सकती';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: reasonController,
                      enabled: !isSubmitting,
                      decoration: InputDecoration(
                        labelText: 'समायोजन का कारण (Reason)',
                        hintText: operation == 'increment'
                            ? 'उदा. नया माल प्राप्त हुआ (New stock arrived)'
                            : operation == 'decrement'
                                ? 'उदा. खराब माल निकाला गया (Damaged stock removed)'
                                : 'उदा. भौतिक सत्यापन (Physical stock audit)',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    if (errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(errorMessage!, style: const TextStyle(fontSize: 12.5, color: Color(0xFFC62828))),
                      ),
                      const SizedBox(height: 14),
                    ],

                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final nav = Navigator.of(ctx);
                                final messenger = ScaffoldMessenger.of(context);
                                if (!formKey.currentState!.validate()) return;
                                final num amount = isBulk
                                    ? double.parse(amountController.text.trim())
                                    : int.parse(amountController.text.trim());

                                setModalState(() {
                                  isSubmitting = true;
                                  errorMessage = null;
                                });

                                try {
                                  final result = await _dataSource.adjustProductStock(
                                    shopId: widget.shopId,
                                    productId: productId,
                                    operation: operation,
                                    amount: amount,
                                    reason: reasonController.text.trim(),
                                  );

                                  if (mounted) {
                                    nav.pop();
                                    final finalStock = result['newStock'] != null
                                        ? _formatStock(result['newStock'] as num?)
                                        : _formatStock(amount);
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text('✓ स्टॉक सफलतापूर्वक $finalStock $unit पर अपडेट हो गया और लेजर में दर्ज हुआ!'),
                                        backgroundColor: const Color(0xFF16A34A),
                                      ),
                                    );
                                  }
                                } catch (err) {
                                  setModalState(() {
                                    isSubmitting = false;
                                    errorMessage = err.toString().replaceAll('Exception:', '').trim();
                                  });
                                }
                              },
                        child: isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('स्टॉक सहेजें (Save Stock)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
