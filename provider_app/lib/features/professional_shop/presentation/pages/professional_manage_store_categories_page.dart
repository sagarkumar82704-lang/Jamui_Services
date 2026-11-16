import 'package:flutter/material.dart';
import '../../data/datasources/professional_provider_remote_data_source.dart';
import '../../domain/entities/seller_store_category_entity.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../../../core/localization/provider_strings.dart';
import '../../../../main.dart' show isProviderFirebaseInitialized;

/// UI for managing a seller's private store categories (Level 2).
/// Storage Path: diamond_shops/{shopId}/store_categories/{categoryId}
class ProfessionalManageStoreCategoriesPage extends StatefulWidget {
  final String shopId;
  final ProfessionalProviderRemoteDataSource? dataSource;

  const ProfessionalManageStoreCategoriesPage({
    super.key,
    required this.shopId,
    this.dataSource,
  });

  @override
  State<ProfessionalManageStoreCategoriesPage> createState() =>
      _ProfessionalManageStoreCategoriesPageState();
}

class _ProfessionalManageStoreCategoriesPageState
    extends State<ProfessionalManageStoreCategoriesPage> {
  late final ProfessionalProviderRemoteDataSource _dataSource;
  late final Stream<List<SellerStoreCategoryEntity>> _categoriesStream;

  @override
  void initState() {
    super.initState();
    _dataSource = widget.dataSource ??
        (isProviderFirebaseInitialized
            ? ProfessionalProviderRemoteDataSource()
            : ProfessionalProviderRemoteDataSource());
    _categoriesStream = _dataSource.streamStoreCategories(widget.shopId);
  }

  void _openAddEditCategoryDialog(
      List<SellerStoreCategoryEntity> currentCategories,
      [SellerStoreCategoryEntity? existing]) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final nameHindiCtrl = TextEditingController(text: existing?.nameHindi ?? '');
    final orderCtrl = TextEditingController(
        text: existing != null ? '${existing.displayOrder}' : '1');
    bool isActive = existing?.isActive ?? true;
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
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
                        Text(
                          existing != null
                              ? 'श्रेणी संपादित करें (Edit Category)'
                              : 'नई श्रेणी जोड़ें (Add Category)',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Category Name (Required & Unique within shop)
                    TextFormField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'श्रेणी का नाम (Category Name) *',
                        hintText: 'उदा. दाल, आटा, चावल, मसाले',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'कृपया श्रेणी का नाम दर्ज करें';
                        }
                        final cleanName = val.trim().toLowerCase();
                        final isDuplicate = currentCategories.any((c) =>
                            c.id != existing?.id &&
                            c.name.trim().toLowerCase() == cleanName);
                        if (isDuplicate) {
                          return 'इस नाम की श्रेणी पहले से मौजूद है';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Hindi Name (Optional)
                    TextFormField(
                      controller: nameHindiCtrl,
                      decoration: InputDecoration(
                        labelText: 'हिंदी नाम (वैकल्पिक / Optional)',
                        hintText: 'उदा. दाल एवं दलहन',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Display Order & Active Toggle Row
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: orderCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'क्रम संख्या (Order)',
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Row(
                          children: [
                            const Text(
                              'सक्रिय (Active):',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            Switch(
                              value: isActive,
                              activeThumbColor: const Color(0xFF1D4ED8),
                              onChanged: (val) {
                                setModalState(() => isActive = val);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1D4ED8),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          final newOrder = int.tryParse(orderCtrl.text.trim()) ?? 1;
                          final catId = existing?.id.isNotEmpty == true
                              ? existing!.id
                              : 'sc_${DateTime.now().millisecondsSinceEpoch}';

                          final entity = SellerStoreCategoryEntity(
                            id: catId,
                            shopId: widget.shopId,
                            name: nameCtrl.text.trim(),
                            nameHindi: nameHindiCtrl.text.trim(),
                            displayOrder: newOrder,
                            isActive: isActive,
                          );

                          final messenger = ScaffoldMessenger.of(context);
                          final nav = Navigator.of(ctx);

                          try {
                            await _dataSource.saveStoreCategory(
                                widget.shopId, entity);
                            if (mounted) {
                              nav.pop();
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    existing != null
                                        ? 'श्रेणी अपडेट हो गई'
                                        : 'नई श्रेणी सफलतापूर्वक जुड़ गई',
                                  ),
                                  backgroundColor: const Color(0xFF16A34A),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('त्रुटि: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        child: Text(
                          existing != null ? 'अपडेट करें (Update)' : 'सहेजें (Save)',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
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

  void _showDeactivationWarning(SellerStoreCategoryEntity cat) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('श्रेणी निष्क्रिय करें? (Deactivate)'),
        content: Text(
          'यदि आप "${cat.name}" को निष्क्रिय करते हैं, तो नए उत्पाद इसमें नहीं जोड़े जा सकेंगे। पहले से मौजूद उत्पाद सुरक्षित रहेंगे।',
          style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('रद्द करें'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
            onPressed: () async {
              Navigator.pop(ctx);
              await _dataSource.toggleStoreCategoryActive(widget.shopId, cat.id, false);
            },
            child: const Text('निष्क्रिय करें', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteCategory(SellerStoreCategoryEntity cat) async {
    final refCount = await _dataSource.countProductsReferencingCategory(widget.shopId, cat.id);

    if (!mounted) return;

    if (refCount > 0) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'हटाना संभव नहीं है',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            'इस श्रेणी ("${cat.name}") से वर्तमान में $refCount उत्पाद जुड़े हुए हैं।\n\n'
            'उत्पादों की अखंडता बनाए रखने के लिए यह श्रेणी सीधे नहीं हटाई जा सकती। '
            'कृपया उत्पादों को दूसरी श्रेणी में स्थानांतरित करें, या इस श्रेणी को "निष्क्रिय (Deactivate)" कर दें।',
            style: const TextStyle(fontSize: 13.5, height: 1.45, color: Color(0xFF334155)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('समझ गया (OK)'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('श्रेणी हटाएं? (Delete Category)'),
          content: Text(
            'क्या आप वाकई श्रेणी "${cat.name}" को हटाना चाहते हैं? यह क्रिया वापस नहीं ली जा सकती।',
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('रद्द करें'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await _dataSource.deleteStoreCategory(widget.shopId, cat.id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('श्रेणी "${cat.name}" सफलतापूर्वक हटा दी गई'),
                        backgroundColor: const Color(0xFF16A34A),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('हटाने में विफल: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('हटाएं (Delete)', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF1E293B), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          ProviderStrings.manageCategories,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
      ),
      body: StreamBuilder<List<SellerStoreCategoryEntity>>(
        stream: _categoriesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF1D4ED8),
                strokeWidth: 2,
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'श्रेणियां लोड करने में त्रुटि:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            );
          }

          final allCategories = snapshot.data ?? [];
          final activeCategories = allCategories.where((c) => c.isActive).toList();
          final inactiveCategories = allCategories.where((c) => !c.isActive).toList();

          return Column(
            children: [
              // Informative Banner
              ResponsiveContentContainer(
                maxWidth: 960,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: Color(0xFF1D4ED8), size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'ये आपकी दुकान की अपनी श्रेणियां हैं (जैसे: दाल, आटा, तेल)। उत्पाद जोड़ते समय आप इन्हीं में से श्रेणी चुन सकेंगे।',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1E40AF),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Categories Display: Active and Inactive shown separately with distinct sections
              Expanded(
                child: allCategories.isEmpty
                    ? _buildEmptyState()
                    : SingleChildScrollView(
                        padding: EdgeInsets.zero,
                        child: ResponsiveContentContainer(
                          maxWidth: 960,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (activeCategories.isNotEmpty) ...[
                                _buildSectionHeader('सक्रिय श्रेणियां (Active)', activeCategories.length, const Color(0xFF16A34A)),
                                const SizedBox(height: 8),
                                ...activeCategories.map((c) => _buildCategoryTile(c, allCategories)),
                              ],
                              if (inactiveCategories.isNotEmpty) ...[
                                const SizedBox(height: 18),
                                _buildSectionHeader('निष्क्रिय श्रेणियां (Inactive)', inactiveCategories.length, const Color(0xFFD97706)),
                                const SizedBox(height: 8),
                                ...inactiveCategories.map((c) => _buildCategoryTile(c, allCategories)),
                              ],
                            ],
                          ),
                        ),
                      ),
              ),

              // Bottom Action: Add Category
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: ResponsiveContentContainer(
                  maxWidth: 960,
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D4ED8),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => _openAddEditCategoryDialog(allCategories),
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text(
                        '+ नई श्रेणी जोड़ें (Add Store Category)',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count, Color accentColor) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$title ($count)',
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF334155),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.category_outlined, size: 54, color: Colors.grey.shade400),
            const SizedBox(height: 14),
            const Text(
              'अभी कोई श्रेणी नहीं बनी है',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'नीचे दिए गए बटन से अपनी पहली स्टोर श्रेणी (जैसे: आटा, दाल) जोड़ें।',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTile(SellerStoreCategoryEntity cat, List<SellerStoreCategoryEntity> allCategories) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Display Order Pill
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              '#${cat.displayOrder}',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF475569),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Titles
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cat.name,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                if (cat.nameHindi.isNotEmpty && cat.nameHindi != cat.name) ...[
                  const SizedBox(height: 2),
                  Text(
                    cat.nameHindi,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Status Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: cat.isActive
                  ? const Color(0xFFDCFCE7)
                  : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              cat.isActive ? 'Active' : 'Inactive',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: cat.isActive
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFD97706),
              ),
            ),
          ),
          const SizedBox(width: 4),

          // Edit Action
          IconButton(
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: const EdgeInsets.all(4),
            icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF64748B)),
            onPressed: () => _openAddEditCategoryDialog(allCategories, cat),
          ),

          // Delete Action
          IconButton(
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: const EdgeInsets.all(4),
            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
            onPressed: () => _handleDeleteCategory(cat),
          ),

          // Active/Inactive Toggle
          Switch(
            value: cat.isActive,
            activeThumbColor: const Color(0xFF1D4ED8),
            onChanged: (val) {
              if (!val) {
                _showDeactivationWarning(cat);
              } else {
                _dataSource.toggleStoreCategoryActive(widget.shopId, cat.id, true);
              }
            },
          ),
        ],
      ),
    );
  }
}
