import 'package:flutter/material.dart';
import '../../data/datasources/professional_provider_remote_data_source.dart';

/// Professional Seller Inventory Management Page
/// Displays 4 stock KPI summary cards, product inventory list with stock badges,
/// search and filtering, and stock adjustment dialog with safe disabled write state.
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

  String _selectedFilter = 'All'; // 'All', 'In Stock', 'Low Stock', 'Out of Stock'
  String _searchQuery = '';

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
          'इन्वेंट्री प्रबंधन (Inventory)',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _productsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF0F766E)),
            );
          }

          final allProducts = snapshot.data ?? [];

          // Calculate Inventory Metrics
          int totalStockUnits = 0;
          int inStockCount = 0;
          int lowStockCount = 0;
          int outOfStockCount = 0;

          for (final p in allProducts) {
            final qty = (p['stockQuantity'] as num?)?.toInt() ?? 0;
            final inStock = (p['inStock'] as bool?) ?? true;

            totalStockUnits += qty;

            if (!inStock || qty <= 0) {
              outOfStockCount++;
            } else if (qty <= 5) {
              lowStockCount++;
              inStockCount++;
            } else {
              inStockCount++;
            }
          }

          // Apply filters
          final filtered = allProducts.where((p) {
            final qty = (p['stockQuantity'] as num?)?.toInt() ?? 0;
            final inStock = (p['inStock'] as bool?) ?? true;

            if (_selectedFilter == 'In Stock' && (!inStock || qty <= 0)) {
              return false;
            }
            if (_selectedFilter == 'Low Stock' && (!inStock || qty <= 0 || qty > 5)) {
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
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildKpiCard(
                            title: 'कुल स्टॉक यूनिट्स',
                            value: '$totalStockUnits',
                            icon: Icons.inventory_2_rounded,
                            iconColor: const Color(0xFF1D4ED8),
                            bgColor: const Color(0xFFEFF6FF),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildKpiCard(
                            title: 'स्टॉक में उपलब्ध',
                            value: '$inStockCount',
                            icon: Icons.check_circle_rounded,
                            iconColor: const Color(0xFF2E7D32),
                            bgColor: const Color(0xFFE8F5E9),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildKpiCard(
                            title: 'कम स्टॉक (<= 5)',
                            value: '$lowStockCount',
                            icon: Icons.warning_amber_rounded,
                            iconColor: const Color(0xFFE65100),
                            bgColor: const Color(0xFFFFF3E0),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildKpiCard(
                            title: 'आउट ऑफ स्टॉक',
                            value: '$outOfStockCount',
                            icon: Icons.cancel_rounded,
                            iconColor: const Color(0xFFC62828),
                            bgColor: const Color(0xFFFFEBEE),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Filter Tabs
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: SingleChildScrollView(
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
              ),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                            hintText: 'इन्वेंट्री में उत्पाद खोजें...',
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

              // Products Inventory List
              Expanded(
                child: filtered.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) => _buildInventoryTile(filtered[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

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
    final qty = (product['stockQuantity'] as num?)?.toInt() ?? 0;
    final unit = (product['unit'] as String?) ?? 'इकाई';
    final inStock = (product['inStock'] as bool?) ?? true;
    final thumb = (product['thumbnailUrl'] as String?) ?? '';

    Color badgeBg;
    Color badgeFg;
    String badgeText;

    if (!inStock || qty <= 0) {
      badgeBg = const Color(0xFFFFEBEE);
      badgeFg = const Color(0xFFC62828);
      badgeText = 'आउट ऑफ स्टॉक (0)';
    } else if (qty <= 5) {
      badgeBg = const Color(0xFFFFF3E0);
      badgeFg = const Color(0xFFE65100);
      badgeText = 'कम स्टॉक ($qty $unit)';
    } else {
      badgeBg = const Color(0xFFE8F5E9);
      badgeFg = const Color(0xFF2E7D32);
      badgeText = 'स्टॉक में ($qty $unit)';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 50,
              height: 50,
              color: const Color(0xFFF1F5F9),
              child: thumb.isNotEmpty
                  ? Image.network(
                      thumb,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(Icons.inventory_2_outlined, color: Colors.grey),
                    )
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
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
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
          OutlinedButton.icon(
            onPressed: () => _showAdjustmentDialog(product),
            icon: const Icon(Icons.tune_rounded, size: 16, color: Color(0xFF0F766E)),
            label: const Text(
              'समायोजित करें',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF0F766E)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  void _showAdjustmentDialog(Map<String, dynamic> product) {
    final productId = (product['id'] as String?) ?? '';
    final title = product['titleEnglish'] ?? product['titleHindi'] ?? product['title'] ?? 'Product';
    final currentQty = (product['stockQuantity'] as num?)?.toInt() ?? 0;
    final unit = (product['unit'] as String?) ?? 'इकाई';

    String operation = 'increment'; // 'increment', 'decrement', 'set'
    final amountController = TextEditingController();
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        bool isSubmitting = false;
        String? errorMessage;

        return StatefulBuilder(
          builder: (context, setModalState) {
            final enteredAmount = int.tryParse(amountController.text.trim()) ?? 0;
            int? projectedStock;
            if (operation == 'increment') {
              projectedStock = currentQty + enteredAmount;
            } else if (operation == 'decrement') {
              projectedStock = currentQty - enteredAmount;
            } else if (operation == 'set') {
              projectedStock = enteredAmount;
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'स्टॉक समायोजन: $title',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'वर्तमान स्टॉक: $currentQty $unit',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF334155),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (projectedStock != null && amountController.text.trim().isNotEmpty) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF64748B)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: (projectedStock < 0)
                                  ? const Color(0xFFFFEBEE)
                                  : const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'नया: $projectedStock $unit',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: (projectedStock < 0)
                                    ? const Color(0xFFC62828)
                                    : const Color(0xFF2E7D32),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Operation Selector
                    const Text(
                      'समायोजन प्रकार (Operation):',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                    ),
                    const SizedBox(height: 8),
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
                            onSelected: isSubmitting
                                ? null
                                : (selected) {
                                    if (selected) setModalState(() => operation = 'increment');
                                  },
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
                            onSelected: isSubmitting
                                ? null
                                : (selected) {
                                    if (selected) setModalState(() => operation = 'decrement');
                                  },
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
                            onSelected: isSubmitting
                                ? null
                                : (selected) {
                                    if (selected) setModalState(() => operation = 'set');
                                  },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Amount Input
                    TextFormField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      enabled: !isSubmitting,
                      onChanged: (_) => setModalState(() {}),
                      decoration: InputDecoration(
                        labelText: operation == 'set'
                            ? 'नया कुल स्टॉक (Exact Stock Count) *'
                            : 'मात्रा दर्ज करें (Amount to ${operation == 'increment' ? 'Add' : 'Deduct'}) *',
                        hintText: 'उदा. 10',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'कृपया मात्रा दर्ज करें';
                        }
                        final parsed = int.tryParse(val.trim());
                        if (parsed == null) {
                          return 'कृपया केवल वैध पूर्णांक संख्या दर्ज करें';
                        }
                        if (operation == 'set' && parsed < 0) {
                          return 'स्टॉक 0 या 0 से अधिक होना चाहिए';
                        }
                        if (operation != 'set' && parsed <= 0) {
                          return 'मात्रा 0 से अधिक होनी चाहिए';
                        }
                        if (operation == 'decrement' && parsed > currentQty) {
                          return 'घटाने की मात्रा वर्तमान स्टॉक ($currentQty) से अधिक नहीं हो सकती';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Reason Input (Optional)
                    TextFormField(
                      controller: reasonController,
                      enabled: !isSubmitting,
                      decoration: InputDecoration(
                        labelText: 'समायोजन का कारण (वैकल्पिक / Optional Reason)',
                        hintText: operation == 'increment'
                            ? 'उदा. नया माल प्राप्त हुआ (New stock arrived)'
                            : operation == 'decrement'
                                ? 'उदा. खराब माल निकाला गया (Damaged stock removed)'
                                : 'उदा. भौतिक सत्यापन (Physical stock audit)',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Error Message Banner
                    if (errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: const TextStyle(fontSize: 12.5, color: Color(0xFFC62828)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Submit Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                final amount = int.parse(amountController.text.trim());

                                // Confirmation for Set and Decrement
                                if (operation == 'decrement' || operation == 'set') {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (confirmCtx) => AlertDialog(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      title: const Text('स्टॉक पुष्टि (Confirm Stock)'),
                                      content: Text(
                                        operation == 'decrement'
                                            ? 'क्या आप वाकई "$title" से $amount $unit स्टॉक घटाना चाहते हैं?'
                                            : 'क्या आप वाकई "$title" का कुल स्टॉक $amount $unit पर सेट करना चाहते हैं?',
                                        style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155)),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(confirmCtx, false),
                                          child: const Text('रद्द करें'),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF0F766E),
                                          ),
                                          onPressed: () => Navigator.pop(confirmCtx, true),
                                          child: const Text('पुष्टि करें', style: TextStyle(color: Colors.white)),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirmed != true) return;
                                }

                                setModalState(() {
                                  isSubmitting = true;
                                  errorMessage = null;
                                });

                                final nav = Navigator.of(ctx);
                                final messenger = ScaffoldMessenger.of(context);

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
                                    final finalStock = result['newStock'] ?? amount;
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'स्टॉक सफलतापूर्वक अपडेट किया गया! नया स्टॉक: $finalStock $unit',
                                        ),
                                        backgroundColor: const Color(0xFF16A34A),
                                      ),
                                    );
                                  }
                                } catch (err) {
                                  if (mounted) {
                                    setModalState(() {
                                      isSubmitting = false;
                                      errorMessage = err.toString().replaceAll('Exception: ', '');
                                    });
                                  }
                                }
                              },
                        child: isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.2,
                                ),
                              )
                            : const Text(
                                'स्टॉक अपडेट करें (Submit Stock)',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 54, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            'कोई उत्पाद नहीं मिला',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
          ),
        ],
      ),
    );
  }
}
