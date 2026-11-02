import 'package:flutter/material.dart';
import '../../data/datasources/professional_provider_remote_data_source.dart';
import 'professional_add_edit_product_page.dart';
import 'professional_manage_store_categories_page.dart';

/// Professional Seller Products Management Page
/// Integrates with Checkpoint 2A Store Categories & Dynamic Attributes.
/// Supports search, in-stock filtering, quick stock toggle, and store category navigation.
class ProfessionalShopProductsPage extends StatefulWidget {
  final String shopId;
  final ProfessionalProviderRemoteDataSource? dataSource;

  const ProfessionalShopProductsPage({
    super.key,
    required this.shopId,
    this.dataSource,
  });

  @override
  State<ProfessionalShopProductsPage> createState() => _ProfessionalShopProductsPageState();
}

class _ProfessionalShopProductsPageState extends State<ProfessionalShopProductsPage> {
  late final ProfessionalProviderRemoteDataSource _dataSource;
  String _activeTab = 'All'; // 'All', 'In Stock', 'Out of Stock'
  String _searchQuery = '';
  late final Stream<List<Map<String, dynamic>>> _productsStream;

  @override
  void initState() {
    super.initState();
    _dataSource = widget.dataSource ?? ProfessionalProviderRemoteDataSource();
    _productsStream = _dataSource.streamProducts(widget.shopId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'उत्पाद सूची (Products)',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfessionalManageStoreCategoriesPage(shopId: widget.shopId),
                ),
              );
            },
            icon: const Icon(Icons.category_rounded, size: 18, color: Color(0xFF1D4ED8)),
            label: const Text(
              'स्टोर श्रेणियां',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _productsStream,
        builder: (context, snapshot) {
          final allProducts = snapshot.data ?? [];
          final inStockCount = allProducts.where((p) => (p['inStock'] as bool?) ?? true).length;
          final outStockCount = allProducts.length - inStockCount;

          final filtered = allProducts.where((p) {
            final inStock = (p['inStock'] as bool?) ?? true;
            if (_activeTab == 'In Stock' && !inStock) return false;
            if (_activeTab == 'Out of Stock' && inStock) return false;
            if (_searchQuery.isNotEmpty) {
              final q = _searchQuery.toLowerCase();
              final t = (p['titleEnglish'] ?? p['titleHindi'] ?? p['title'] ?? '').toString().toLowerCase();
              if (!t.contains(q)) return false;
            }
            return true;
          }).toList();

          return Column(
            children: [
              // Tabs: All (X), In Stock (Y), Out of Stock (Z)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    _buildTabPill('सभी (${allProducts.length})', 'All'),
                    const SizedBox(width: 8),
                    _buildTabPill('उपलब्ध ($inStockCount)', 'In Stock'),
                    const SizedBox(width: 8),
                    _buildTabPill('आउट ऑफ स्टॉक ($outStockCount)', 'Out of Stock'),
                  ],
                ),
              ),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
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
                    ],
                  ),
                ),
              ),

              // Products List
              Expanded(
                child: filtered.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) => _buildProductRow(filtered[i]),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0F766E),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProfessionalAddEditProductPage(shopId: widget.shopId),
            ),
          );
        },
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('नया उत्पाद', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildTabPill(String label, String tabKey) {
    final isSelected = _activeTab == tabKey;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = tabKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F766E) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
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

  Widget _buildProductRow(Map<String, dynamic> p) {
    final pid = p['id'] ?? '';
    final title = p['titleEnglish'] ?? p['titleHindi'] ?? p['title'] ?? 'Product';
    final price = (p['sellingPrice'] as num?)?.toInt() ?? (p['price'] as num?)?.toInt() ?? 0;
    final unit = (p['unit'] as String?) ?? 'kg';
    final thumb = (p['thumbnailUrl'] as String?) ?? '';
    final inStock = (p['inStock'] as bool?) ?? true;
    final storeCategoryName = (p['storeCategoryName'] as String?) ?? '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 52,
              height: 52,
              color: const Color(0xFFF1F5F9),
              child: thumb.isNotEmpty
                  ? Image.network(thumb, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.inventory_2_outlined, color: Colors.grey))
                  : const Icon(Icons.inventory_2_outlined, color: Colors.grey),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '₹$price / $unit',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                    ),
                    if (storeCategoryName.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          storeCategoryName,
                          style: const TextStyle(fontSize: 10, color: Color(0xFF1D4ED8), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // In Stock / Out of Stock Switch
          Column(
            children: [
              Switch(
                value: inStock,
                activeThumbColor: const Color(0xFF0F766E),
                onChanged: (val) {
                  _dataSource.toggleProductStock(widget.shopId, pid, val);
                },
              ),
              Text(
                inStock ? 'उपलब्ध' : 'आउट ऑफ स्टॉक',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: inStock ? const Color(0xFF2E7D32) : Colors.grey,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Color(0xFF64748B), size: 20),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfessionalAddEditProductPage(shopId: widget.shopId, existingProduct: p),
                ),
              );
            },
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
          Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text('कोई उत्पाद नहीं मिला', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
          const SizedBox(height: 4),
          const Text('नया उत्पाद जोड़ने के लिए नीचे दिए गए बटन पर टैप करें।', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}
