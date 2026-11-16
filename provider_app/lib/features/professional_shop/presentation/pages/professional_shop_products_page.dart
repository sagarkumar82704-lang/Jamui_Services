import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../../../core/utils/app_image_utils.dart';
import '../../data/datasources/professional_provider_remote_data_source.dart';
import '../../domain/entities/seller_store_category_entity.dart';
import '../../../../core/localization/provider_strings.dart';
import '../../../../core/localization/language_selection_modal.dart';
import 'professional_add_edit_product_page.dart';
import 'professional_manage_store_categories_page.dart';

/// Professional Seller Products Management Page
/// Scalable cursor-based pagination (page size: 25)
/// Supports search, category filter, in-stock filter, stock quantity badge, and delete.
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
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _products = [];
  DocumentSnapshot? _lastDoc;
  bool _hasMore = true;
  bool _isLoading = false;
  bool _isLoadingMore = false;

  String _activeTab = 'All'; // 'All', 'In Stock', 'Out of Stock'
  String _selectedStoreCategoryId = 'All';
  String _searchQuery = '';

  late final Stream<List<SellerStoreCategoryEntity>> _categoriesStream;

  @override
  void initState() {
    super.initState();
    _dataSource = widget.dataSource ?? ProfessionalProviderRemoteDataSource();
    _categoriesStream = _dataSource.streamStoreCategories(widget.shopId);
    _scrollController.addListener(_onScroll);
    _loadProducts(isRefresh: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.85) {
      if (!_isLoadingMore && _hasMore && !_isLoading) {
        _loadMoreProducts();
      }
    }
  }

  Future<void> _loadProducts({bool isRefresh = false}) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      if (isRefresh) {
        _lastDoc = null;
        _hasMore = true;
      }
    });

    final result = await _dataSource.fetchProductsPaginated(
      widget.shopId,
      limit: 25,
      startAfter: null,
      filterStatus: _activeTab,
      storeCategoryId: _selectedStoreCategoryId != 'All' ? _selectedStoreCategoryId : null,
      searchQuery: _searchQuery,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        _products.clear();
        _products.addAll(List<Map<String, dynamic>>.from(result['products'] as List));
        _lastDoc = result['lastDoc'] as DocumentSnapshot?;
        _hasMore = result['hasMore'] as bool? ?? false;
      });
    }
  }

  Future<void> _loadMoreProducts() async {
    if (_isLoadingMore || !_hasMore || _lastDoc == null) return;
    setState(() => _isLoadingMore = true);

    final result = await _dataSource.fetchProductsPaginated(
      widget.shopId,
      limit: 25,
      startAfter: _lastDoc,
      filterStatus: _activeTab,
      storeCategoryId: _selectedStoreCategoryId != 'All' ? _selectedStoreCategoryId : null,
      searchQuery: _searchQuery,
    );

    if (mounted) {
      final newItems = List<Map<String, dynamic>>.from(result['products'] as List);
      setState(() {
        _isLoadingMore = false;
        _products.addAll(newItems);
        _lastDoc = result['lastDoc'] as DocumentSnapshot?;
        _hasMore = result['hasMore'] as bool? ?? false;
      });
    }
  }

  Future<void> _deleteProduct(String productId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('उत्पाद हटाएं? (Delete Product)'),
        content: Text('क्या आप वाकई "$title" को हटाना चाहते हैं? यह उत्पाद ग्राहकों को नहीं दिखेगा।'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('रद्द करें')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('हटाएं', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _dataSource.deleteProduct(widget.shopId, productId);
      setState(() {
        _products.removeWhere((p) => p['id'] == productId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('उत्पाद सफलतापूर्वक हटा दिया गया।'), backgroundColor: Color(0xFF16A34A)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('त्रुटि: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text(
          ProviderStrings.productCatalogue,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        actions: [
          IconButton(
            tooltip: ProviderStrings.selectLanguage,
            icon: const Icon(Icons.language_rounded, color: Color(0xFF0F766E)),
            onPressed: () => LanguageSelectionModal.show(context),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfessionalManageStoreCategoriesPage(shopId: widget.shopId, dataSource: _dataSource),
                ),
              );
            },
            icon: const Icon(Icons.category_rounded, size: 18, color: Color(0xFF0F766E)),
            label: Text(
              ProviderStrings.manageCategories,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs (All, In Stock, Out of Stock)
          Container(
            width: double.infinity,
            color: Colors.white,
            child: ResponsiveContentContainer(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTabPill(ProviderStrings.all, 'All'),
                    const SizedBox(width: 8),
                    _buildTabPill(ProviderStrings.inStock, 'In Stock'),
                    const SizedBox(width: 8),
                    _buildTabPill(ProviderStrings.outOfStock, 'Out of Stock'),
                  ],
                ),
              ),
            ),
          ),

          // Search Bar & Store Category Filter Chips
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
                            onChanged: (v) {
                              _searchQuery = v;
                              _loadProducts(isRefresh: true);
                            },
                            decoration: const InputDecoration(
                              hintText: 'उत्पाद का नाम खोजें...',
                              hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                        if (_searchQuery.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchQuery = '';
                              _loadProducts(isRefresh: true);
                            },
                            child: const Icon(Icons.clear_rounded, size: 18, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Store Categories Stream Pills
                  StreamBuilder<List<SellerStoreCategoryEntity>>(
                    stream: _categoriesStream,
                    builder: (context, catSnap) {
                      final categories = catSnap.data ?? [];
                      if (categories.isEmpty) return const SizedBox.shrink();

                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildCategoryChip('सभी श्रेणियां', 'All'),
                            const SizedBox(width: 6),
                            ...categories.map((c) => Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: _buildCategoryChip(c.displayTitle, c.id),
                                )),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Paginated Products List
          Expanded(
            child: _isLoading && _products.isEmpty
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F766E)))
                : RefreshIndicator(
                    color: const Color(0xFF0F766E),
                    onRefresh: () => _loadProducts(isRefresh: true),
                    child: _products.isEmpty
                        ? _buildEmptyState()
                        : ListView.separated(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            itemCount: _products.length + (_isLoadingMore ? 1 : 0),
                            separatorBuilder: (context, index) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              if (index >= _products.length) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(12),
                                    child: CircularProgressIndicator(color: Color(0xFF0F766E), strokeWidth: 2),
                                  ),
                                );
                              }
                              return _buildProductRow(_products[index]);
                            },
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0F766E),
        onPressed: () async {
          final added = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => ProfessionalAddEditProductPage(shopId: widget.shopId, dataSource: _dataSource),
            ),
          );
          if (added == true) {
            _loadProducts(isRefresh: true);
          }
        },
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('नया उत्पाद', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildTabPill(String label, String tabKey) {
    final isSelected = _activeTab == tabKey;
    return GestureDetector(
      onTap: () {
        if (_activeTab != tabKey) {
          setState(() => _activeTab = tabKey);
          _loadProducts(isRefresh: true);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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

  Widget _buildCategoryChip(String label, String categoryId) {
    final isSelected = _selectedStoreCategoryId == categoryId;
    return GestureDetector(
      onTap: () {
        if (_selectedStoreCategoryId != categoryId) {
          setState(() => _selectedStoreCategoryId = categoryId);
          _loadProducts(isRefresh: true);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFCCFBF1) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? const Color(0xFF0F766E) : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? const Color(0xFF0F766E) : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildProductRow(Map<String, dynamic> p) {
    final pid = p['id'] ?? '';
    final title = p['titleEnglish'] ?? p['titleHindi'] ?? p['title'] ?? 'Product';
    final price = (p['sellingPrice'] as num?)?.toInt() ?? (p['price'] as num?)?.toInt() ?? 0;
    final mrp = (p['regularPrice'] as num?)?.toInt() ?? (p['mrp'] as num?)?.toInt() ?? price;
    final unit = (p['unit'] as String?) ?? 'kg';
    final thumb = (p['thumbnailUrl'] as String?) ?? '';
    final inStock = (p['inStock'] as bool?) ?? true;
    final qty = (p['stockQuantity'] as num?)?.toInt() ?? 0;
    final threshold = (p['lowStockThreshold'] as num?)?.toInt() ?? 5;
    final storeCategoryName = (p['storeCategoryName'] as String?) ?? '';

    Color stockBadgeBg;
    Color stockBadgeFg;
    String stockBadgeText;

    if (!inStock || qty <= 0) {
      stockBadgeBg = const Color(0xFFFFEBEE);
      stockBadgeFg = const Color(0xFFC62828);
      stockBadgeText = '0 $unit';
    } else if (qty <= threshold) {
      stockBadgeBg = const Color(0xFFFFF3E0);
      stockBadgeFg = const Color(0xFFE65100);
      stockBadgeText = '$qty $unit (कम स्टॉक)';
    } else {
      stockBadgeBg = const Color(0xFFE8F5E9);
      stockBadgeFg = const Color(0xFF2E7D32);
      stockBadgeText = '$qty $unit';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 56,
              height: 56,
              color: const Color(0xFFF1F5F9),
              child: thumb.isNotEmpty
                  ? AppImageUtils.buildImage(thumb, fit: BoxFit.cover, errorWidget: const Icon(Icons.inventory_2_outlined, color: Colors.grey))
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '₹$price / $unit',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                    ),
                    if (mrp > price)
                      Text(
                        'MRP ₹$mrp',
                        style: const TextStyle(fontSize: 11, color: Colors.grey, decoration: TextDecoration.lineThrough),
                      ),
                    if (storeCategoryName.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(4)),
                        child: Text(storeCategoryName, style: const TextStyle(fontSize: 10, color: Color(0xFF1D4ED8), fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: stockBadgeBg, borderRadius: BorderRadius.circular(4)),
                  child: Text(
                    'स्टॉक: $stockBadgeText',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: stockBadgeFg),
                  ),
                ),
              ],
            ),
          ),
          // In Stock / Out of Stock Toggle
          Column(
            children: [
              Switch(
                value: inStock,
                activeThumbColor: const Color(0xFF0F766E),
                onChanged: (val) async {
                  await _dataSource.toggleProductStock(widget.shopId, pid, val);
                  setState(() {
                    p['inStock'] = val;
                  });
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF64748B), size: 20),
            onSelected: (action) async {
              if (action == 'edit') {
                final updated = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfessionalAddEditProductPage(
                      shopId: widget.shopId,
                      existingProduct: p,
                      dataSource: _dataSource,
                    ),
                  ),
                );
                if (updated == true) _loadProducts(isRefresh: true);
              } else if (action == 'delete') {
                _deleteProduct(pid, title);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('संपादित करें (Edit)')])),
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, color: Colors.red, size: 18), SizedBox(width: 8), Text('हटाएं (Delete)', style: TextStyle(color: Colors.red))])),
            ],
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
