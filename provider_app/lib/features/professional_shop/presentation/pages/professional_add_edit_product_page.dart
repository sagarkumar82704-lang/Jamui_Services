import 'package:flutter/material.dart';
import '../../data/datasources/professional_provider_remote_data_source.dart';
import '../../domain/category_attribute_registry.dart';
import '../../domain/entities/seller_store_category_entity.dart';
import 'professional_manage_store_categories_page.dart';
import '../../../../main.dart' show isProviderFirebaseInitialized;

class ProfessionalAddEditProductPage extends StatefulWidget {
  final String shopId;
  final String? marketplaceCategory;
  final Map<String, dynamic>? existingProduct;
  final ProfessionalProviderRemoteDataSource? dataSource;

  const ProfessionalAddEditProductPage({
    super.key,
    required this.shopId,
    this.marketplaceCategory,
    this.existingProduct,
    this.dataSource,
  });

  @override
  State<ProfessionalAddEditProductPage> createState() =>
      _ProfessionalAddEditProductPageState();
}

class _ProfessionalAddEditProductPageState
    extends State<ProfessionalAddEditProductPage> {
  final _formKey = GlobalKey<FormState>();
  late final ProfessionalProviderRemoteDataSource _dataSource;

  late TextEditingController _nameController;
  late TextEditingController _nameHindiController;
  late TextEditingController _sellingPriceController;
  late TextEditingController _mrpController;
  late TextEditingController _descriptionController;
  late TextEditingController _imageUrlController;

  String? _selectedStoreCategoryId;
  String? _selectedStoreCategoryName;
  String _selectedUnit = 'kg';
  bool _inStock = true;
  bool _isSaving = false;

  final Map<String, dynamic> _attributes = {};
  final Map<String, TextEditingController> _attrControllers = {};

  final List<String> _units = [
    'kg',
    'gm',
    'liter',
    'ml',
    'piece',
    'pack',
    'dozen',
    'pair',
    'box'
  ];

  late final Stream<List<SellerStoreCategoryEntity>> _storeCategoriesStream;

  @override
  void initState() {
    super.initState();
    _dataSource = widget.dataSource ??
        (isProviderFirebaseInitialized
            ? ProfessionalProviderRemoteDataSource()
            : ProfessionalProviderRemoteDataSource());

    _storeCategoriesStream = _dataSource.streamStoreCategories(widget.shopId);

    final p = widget.existingProduct;
    _nameController = TextEditingController(
        text: p?['titleEnglish'] ?? p?['title'] ?? p?['name'] ?? '');
    _nameHindiController = TextEditingController(
        text: p?['titleHindi'] ?? p?['nameHindi'] ?? '');
    _sellingPriceController = TextEditingController(
        text: p?['sellingPrice'] != null
            ? '${p!['sellingPrice']}'
            : (p?['price'] != null ? '${p!['price']}' : ''));
    _mrpController = TextEditingController(
        text: p?['regularPrice'] != null
            ? '${p!['regularPrice']}'
            : (p?['mrp'] != null ? '${p!['mrp']}' : ''));
    _descriptionController =
        TextEditingController(text: p?['description'] ?? '');
    _imageUrlController =
        TextEditingController(text: p?['thumbnailUrl'] ?? '');
    _selectedUnit = p?['unit'] ?? 'kg';
    _inStock = p?['inStock'] ?? true;

    // Existing Store Category assignment
    _selectedStoreCategoryId = p?['storeCategoryId'];
    _selectedStoreCategoryName =
        p?['storeCategoryName'] ?? p?['categoryName'];

    // Prepopulate attributes map
    if (p?['attributes'] is Map) {
      final existingAttrs = Map<String, dynamic>.from(p!['attributes'] as Map);
      _attributes.addAll(existingAttrs);
    }

    // Initialize attribute controllers for dynamic fields
    final dynamicDefs =
        CategoryAttributeRegistry.getAttributesForCategory(widget.marketplaceCategory);
    for (final def in dynamicDefs) {
      if (def.type == AttributeFieldType.text ||
          def.type == AttributeFieldType.number ||
          def.type == AttributeFieldType.date) {
        final initialVal = _attributes[def.key]?.toString() ?? '';
        _attrControllers[def.key] = TextEditingController(text: initialVal);
      } else if (def.type == AttributeFieldType.chips) {
        if (_attributes[def.key] == null) {
          _attributes[def.key] = <String>[];
        } else if (_attributes[def.key] is List) {
          _attributes[def.key] = List<String>.from(_attributes[def.key] as List);
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameHindiController.dispose();
    _sellingPriceController.dispose();
    _mrpController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    for (final ctrl in _attrControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedStoreCategoryId == null || _selectedStoreCategoryId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('कृपया अपनी दुकान की एक श्रेणी (Store Category) चुनें'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    // Sync attribute text controllers into map
    for (final entry in _attrControllers.entries) {
      final val = entry.value.text.trim();
      if (val.isNotEmpty) {
        _attributes[entry.key] = val;
      }
    }

    final sellPrice =
        double.tryParse(_sellingPriceController.text.trim()) ?? 0.0;
    final mrp =
        double.tryParse(_mrpController.text.trim()) ?? sellPrice;
    final discount = (mrp > sellPrice && mrp > 0)
        ? ((mrp - sellPrice) / mrp * 100).roundToDouble()
        : 0.0;
    final img = _imageUrlController.text.trim();

    final payload = {
      'shopId': widget.shopId,
      'titleEnglish': _nameController.text.trim(),
      'titleHindi': _nameHindiController.text.trim(),
      'storeCategoryId': _selectedStoreCategoryId,
      'storeCategoryName': _selectedStoreCategoryName ?? '',
      'categoryName': _selectedStoreCategoryName ?? 'General',
      'unit': _selectedUnit,
      'unitValue': 1.0,
      'sellingPrice': sellPrice,
      'regularPrice': mrp,
      'discountPercentage': discount,
      'description': _descriptionController.text.trim(),
      'thumbnailUrl': img,
      'images': img.isNotEmpty ? [img] : [],
      'inStock': _inStock,
      'attributes': _attributes,
    };

    try {
      await _dataSource.saveProduct(
        widget.shopId,
        payload,
        productId: widget.existingProduct?['id'],
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existingProduct != null
                ? 'उत्पाद सफलतापूर्वक अपडेट हो गया'
                : 'नया उत्पाद सफलतापूर्वक जुड़ गया'),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('त्रुटि: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingProduct != null;
    final dynamicDefs =
        CategoryAttributeRegistry.getAttributesForCategory(widget.marketplaceCategory);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF1E293B), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEdit ? 'उत्पाद संपादित करें (Edit Product)' : 'नया उत्पाद जोड़ें (Add Product)',
          style: const TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B)),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Store Category Selector (Level 2 Architecture)
              const Text(
                'दुकान श्रेणी (Store Category) *',
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 6),

              StreamBuilder<List<SellerStoreCategoryEntity>>(
                stream: _storeCategoriesStream,
                builder: (context, snapshot) {
                  final allCategories = snapshot.data ?? [];
                  final activeCategories =
                      allCategories.where((c) => c.isActive).toList();

                  // Backward-compatibility: if existing product has a deactivated category, keep it selectable
                  if (_selectedStoreCategoryId != null &&
                      !activeCategories.any((c) => c.id == _selectedStoreCategoryId)) {
                    final existingCat = allCategories
                        .where((c) => c.id == _selectedStoreCategoryId)
                        .firstOrNull;
                    if (existingCat != null) {
                      activeCategories.add(existingCat);
                    }
                  }

                  if (allCategories.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'आपकी कोई स्टोर श्रेणी नहीं बनी है।',
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF92400E)),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'उत्पाद जोड़ने से पहले अपनी दुकान की श्रेणी (जैसे: आटा, दाल, चावल) बनाएं।',
                            style: TextStyle(
                                fontSize: 11.5, color: Color(0xFF78350F)),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1D4ED8),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text(
                              '+ श्रेणी बनाएं (Manage Categories)',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ProfessionalManageStoreCategoriesPage(
                                    shopId: widget.shopId,
                                    dataSource: _dataSource,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedStoreCategoryId != null &&
                                activeCategories.any(
                                    (c) => c.id == _selectedStoreCategoryId)
                            ? _selectedStoreCategoryId
                            : null,
                        hint: const Text('श्रेणी चुनें (Select Store Category)'),
                        items: activeCategories.map((c) {
                          return DropdownMenuItem<String>(
                            value: c.id,
                            child: Text(
                              c.isActive
                                  ? c.displayTitle
                                  : '${c.displayTitle} (Inactive)',
                              style: TextStyle(
                                color: c.isActive
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedStoreCategoryId = val;
                            final selected = activeCategories
                                .where((c) => c.id == val)
                                .firstOrNull;
                            _selectedStoreCategoryName = selected?.name;
                          });
                        },
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                        ),
                        validator: (v) => v == null || v.isEmpty
                            ? 'कृपया श्रेणी चुनें'
                            : null,
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 30),
                          ),
                          icon: const Icon(Icons.settings_rounded,
                              size: 14, color: Color(0xFF1D4ED8)),
                          label: const Text(
                            'श्रेणियां प्रबंधित करें (Manage Categories)',
                            style: TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF1D4ED8),
                                fontWeight: FontWeight.bold),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ProfessionalManageStoreCategoriesPage(
                                  shopId: widget.shopId,
                                  dataSource: _dataSource,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),

              // 2. Product Name (English & Hindi)
              const Text('उत्पाद का नाम (Product Name in English) *',
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B))),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'उदा. Tata Sampann Toor Dal, Aashirvaad Atta',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'कृपया उत्पाद का नाम दर्ज करें'
                    : null,
              ),
              const SizedBox(height: 12),

              const Text('उत्पाद का हिंदी नाम (वैकल्पिक / Optional)',
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B))),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameHindiController,
                decoration: InputDecoration(
                  hintText: 'उदा. टाटा सम्पन्न तोअर दाल',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),

              // 3. Selling Price & MRP Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('विक्रय मूल्य / Selling Price (₹) *',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B))),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _sellingPriceController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: '120',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                          ),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'मूल्य दर्ज करें' : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('MRP / Regular Price (₹)',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B))),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _mrpController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: '140',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 4. Unit Selection
              const Text('इकाई (Unit Type) *',
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B))),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _units.contains(_selectedUnit) ? _selectedUnit : 'kg',
                items: _units
                    .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedUnit = v ?? 'kg'),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 20),

              // 5. DYNAMIC CATEGORY ATTRIBUTES (Part 4 Architecture)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.tune_rounded,
                            color: Color(0xFF1D4ED8), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.marketplaceCategory ?? "श्रेणी"} विशेष विवरण (Dynamic Attributes)',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                    const Divider(height: 20),

                    // Render dynamic fields based on CategoryAttributeRegistry
                    ...dynamicDefs.map((def) => _buildDynamicAttributeField(def)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 6. In-Stock Availability Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('उपलब्ध है (In Stock)',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B))),
                  Switch(
                    value: _inStock,
                    activeThumbColor: const Color(0xFF1D4ED8),
                    onChanged: (v) => setState(() => _inStock = v),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 7. Save / Update Product Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProduct,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2)
                      : Text(
                          isEdit ? 'बदलाव सहेजें (Save Changes)' : 'उत्पाद जोड़ें (Add Product)',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDynamicAttributeField(CategoryAttributeDefinition def) {
    switch (def.type) {
      case AttributeFieldType.text:
      case AttributeFieldType.number:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${def.label} (${def.labelHindi})${def.isRequired ? " *" : ""}',
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155)),
              ),
              const SizedBox(height: 4),
              TextFormField(
                controller: _attrControllers[def.key],
                keyboardType: def.type == AttributeFieldType.number
                    ? TextInputType.number
                    : TextInputType.text,
                decoration: InputDecoration(
                  hintText: def.helperText,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                validator: (v) {
                  if (def.isRequired && (v == null || v.trim().isEmpty)) {
                    return '${def.label} आवश्यक है';
                  }
                  return null;
                },
              ),
            ],
          ),
        );

      case AttributeFieldType.date:
        final currentText = _attrControllers[def.key]?.text ?? '';
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${def.label} (${def.labelHindi})${def.isRequired ? " *" : ""}',
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155)),
              ),
              const SizedBox(height: 4),
              InkWell(
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: now.add(const Duration(days: 30)),
                    firstDate: now.subtract(const Duration(days: 365)),
                    lastDate: now.add(const Duration(days: 365 * 5)),
                  );
                  if (picked != null) {
                    final formatted =
                        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                    setState(() {
                      _attrControllers[def.key]?.text = formatted;
                      _attributes[def.key] = formatted;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        currentText.isNotEmpty
                            ? currentText
                            : (def.helperText ?? 'तिथि चुनें (Select Date)'),
                        style: TextStyle(
                          fontSize: 13,
                          color: currentText.isNotEmpty
                              ? const Color(0xFF1E293B)
                              : Colors.grey,
                        ),
                      ),
                      const Icon(Icons.calendar_today_rounded,
                          size: 16, color: Color(0xFF1D4ED8)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );

      case AttributeFieldType.dropdown:
        final currentVal = _attributes[def.key] as String?;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${def.label} (${def.labelHindi})${def.isRequired ? " *" : ""}',
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155)),
              ),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: def.options.contains(currentVal) ? currentVal : null,
                hint: Text('चुनें (${def.label})'),
                items: def.options
                    .map((opt) =>
                        DropdownMenuItem(value: opt, child: Text(opt)))
                    .toList(),
                onChanged: (val) {
                  setState(() => _attributes[def.key] = val);
                },
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                validator: (v) {
                  if (def.isRequired && (v == null || v.isEmpty)) {
                    return '${def.label} चुनें';
                  }
                  return null;
                },
              ),
            ],
          ),
        );

      case AttributeFieldType.chips:
        final currentList = (_attributes[def.key] as List?)?.cast<String>() ?? [];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${def.label} (${def.labelHindi})${def.isRequired ? " *" : ""}',
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155)),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: def.options.map((opt) {
                  final isSelected = currentList.contains(opt);
                  return FilterChip(
                    label: Text(opt,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF334155))),
                    selected: isSelected,
                    selectedColor: const Color(0xFF1D4ED8),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isSelected
                            ? const Color(0xFF1D4ED8)
                            : Colors.grey.shade300,
                      ),
                    ),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          currentList.add(opt);
                        } else {
                          currentList.remove(opt);
                        }
                        _attributes[def.key] = currentList;
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        );
    }
  }
}
