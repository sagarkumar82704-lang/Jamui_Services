import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/datasources/professional_provider_remote_data_source.dart';
import '../../domain/entities/seller_store_category_entity.dart';
import '../../domain/entities/product_variant_entity.dart';
import '../../domain/entities/professional_shop_profile_entity.dart';
import '../../domain/product_units.dart';
import '../../domain/professional_entitlement_resolver.dart';
import '../../../../core/localization/provider_locale_controller.dart';
import '../../../../core/localization/provider_strings.dart';
import 'professional_shop_subscription_page.dart';
import 'professional_shop_inventory_page.dart';
import '../../../../core/services/r2_upload_service.dart';
import '../../../../core/utils/app_image_utils.dart';
import '../../../../main.dart' show isProviderFirebaseInitialized;

/// Seller-First Mental Model Archetypes
enum ProductArchetype {
  piecePacket, // 📦 पैकेट / पीस — Piece / Packet
  loose,       // ⚖️ खुला सामान — Loose by Weight / Volume
  variants,    // 🏷️ साइज / अलग-अलग पैक — Sizes / Separate Packs
}

/// Helper model for Loose Goods Customer Buying Shortcuts
class LooseBuyingShortcut {
  final String label;
  final String unit;
  final double value;
  final double multiplierOfBase;
  bool isEnabled;
  double? customPrice;

  LooseBuyingShortcut({
    required this.label,
    required this.unit,
    required this.value,
    required this.multiplierOfBase,
    this.isEnabled = true,
    this.customPrice,
  });

  double effectivePrice(double basePrice) {
    if (customPrice != null && customPrice! > 0) return customPrice!;
    return (basePrice * multiplierOfBase).roundToDouble();
  }

  int get baseUnits {
    final u = unit.toLowerCase().trim();
    if (u == 'kg' || u == 'l') {
      return (value * 1000).round();
    }
    return value.round();
  }
}

/// Seller-First Professional Provider Add / Edit Product Page.
/// Replaces technical Pack vs Bulk options with an intuitive, 3-archetype mental model.
/// Preserves 100% backend compatibility, Phase 1 stock integrity, and zero-overflow responsiveness.
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
  final R2UploadService _r2Service = R2UploadService();

  // Archetype Selection
  ProductArchetype _archetype = ProductArchetype.piecePacket;

  // Basic Information Controllers
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _costPriceController;
  late TextEditingController _lowStockController;

  String? _selectedStoreCategoryId;
  String? _selectedStoreCategoryName;
  final List<String> _images = [];
  bool _isUploadingImage = false;
  bool _isSaving = false;
  bool _isLoadingData = false;
  bool _isAdvancedExpanded = false;

  // Archetype 1: Piece / Packet State
  late TextEditingController _pieceSellingPriceController;
  late TextEditingController _pieceMrpController;
  late TextEditingController _pieceStockController;
  String _pieceUnit = 'piece';

  // Archetype 2: Loose Goods State
  String _looseMeasurementUnit = 'kg'; // 'kg' or 'L'
  late TextEditingController _loosePricePerUnitController;
  late TextEditingController _looseMrpController;
  late TextEditingController _looseStockController;
  List<LooseBuyingShortcut> _looseShortcuts = [];

  // Archetype 3: Sizes / Separate Packs State
  List<ProductUnitOption> _variantOptions = [];
  final List<String> _deletedVariantIds = [];

  ProfessionalShopProfileEntity? _shopProfile;
  ProfessionalEntitlements? _entitlements;
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

    // Resolve Initial Archetype
    if (p != null) {
      final stockType = p['stockType']?.toString().toLowerCase().trim();
      final hasVariants = p['hasVariants'] == true;
      if (stockType == 'bulk') {
        _archetype = ProductArchetype.loose;
      } else if (hasVariants) {
        _archetype = ProductArchetype.variants;
      } else {
        _archetype = ProductArchetype.piecePacket;
      }
    }

    _nameController = TextEditingController(
        text: p?['titleEnglish'] ?? p?['title'] ?? p?['name'] ?? '');
    _descriptionController =
        TextEditingController(text: p?['description'] ?? '');
    _costPriceController = TextEditingController();
    _lowStockController = TextEditingController(
        text: p?['lowStockThreshold'] != null
            ? '${p!['lowStockThreshold']}'
            : '5');

    _selectedStoreCategoryId = p?['storeCategoryId'];
    _selectedStoreCategoryName =
        p?['storeCategoryName'] ?? p?['categoryName'];

    // Prepopulate images
    if (p?['images'] is List) {
      _images.addAll(List<String>.from(p!['images'] as List));
    } else if (p?['thumbnailUrl'] != null &&
        p!['thumbnailUrl'].toString().isNotEmpty) {
      _images.add(p['thumbnailUrl'].toString());
    }

    // Piece / Packet Controllers
    final sPrice = (p?['sellingPrice'] as num?)?.toDouble() ??
        (p?['price'] as num?)?.toDouble() ??
        0.0;
    final mPrice = (p?['regularPrice'] as num?)?.toDouble() ??
        (p?['mrp'] as num?)?.toDouble() ??
        0.0;
    final currentStock = p?['stockQuantity'];

    _pieceSellingPriceController = TextEditingController(
      text: sPrice > 0 ? (sPrice % 1 == 0 ? sPrice.toInt().toString() : sPrice.toString()) : '',
    );
    _pieceMrpController = TextEditingController(
      text: (mPrice > 0 && mPrice > sPrice)
          ? (mPrice % 1 == 0 ? mPrice.toInt().toString() : mPrice.toString())
          : '',
    );
    _pieceStockController = TextEditingController(
      text: currentStock != null ? '$currentStock' : '10',
    );
    _pieceUnit = p?['unit']?.toString() ?? 'piece';

    // Loose Goods Controllers
    final pUnit = p?['unit']?.toString().toLowerCase().trim() ?? 'kg';
    _looseMeasurementUnit = (pUnit == 'l' || pUnit == 'liter' || pUnit == 'litre' || pUnit == 'ltr') ? 'L' : 'kg';
    _loosePricePerUnitController = TextEditingController(
      text: sPrice > 0 ? (sPrice % 1 == 0 ? sPrice.toInt().toString() : sPrice.toString()) : '',
    );
    _looseMrpController = TextEditingController(
      text: (mPrice > 0 && mPrice > sPrice)
          ? (mPrice % 1 == 0 ? mPrice.toInt().toString() : mPrice.toString())
          : '',
    );
    _looseStockController = TextEditingController(
      text: currentStock != null ? '$currentStock' : '25',
    );
    _looseShortcuts = _buildDefaultShortcuts(_looseMeasurementUnit);

    // Initial Variant Options
    if (p != null && _archetype == ProductArchetype.variants) {
      _variantOptions = [
        ProductUnitOption(
          unit: 'piece',
          value: 'Default',
          sellingPrice: sPrice,
          mrp: mPrice > 0 ? mPrice : sPrice,
          stock: (currentStock as num?)?.toInt() ?? 0,
        )
      ];
    } else {
      _variantOptions = [
        ProductUnitOption(
          unit: 'piece',
          value: 'Standard',
          sellingPrice: 100,
          mrp: 120,
          stock: 10,
        )
      ];
    }

    if (p != null) {
      _loadExistingProductData();
    }

    _loadShopProfile();
  }

  List<LooseBuyingShortcut> _buildDefaultShortcuts(String looseUnit) {
    if (looseUnit == 'L') {
      return [
        LooseBuyingShortcut(label: '250 ml', unit: 'ml', value: 250, multiplierOfBase: 0.25),
        LooseBuyingShortcut(label: '500 ml', unit: 'ml', value: 500, multiplierOfBase: 0.50),
        LooseBuyingShortcut(label: '1 L', unit: 'L', value: 1, multiplierOfBase: 1.0),
        LooseBuyingShortcut(label: '5 L', unit: 'L', value: 5, multiplierOfBase: 5.0, isEnabled: false),
      ];
    } else {
      return [
        LooseBuyingShortcut(label: '250 g', unit: 'g', value: 250, multiplierOfBase: 0.25),
        LooseBuyingShortcut(label: '500 g', unit: 'g', value: 500, multiplierOfBase: 0.50),
        LooseBuyingShortcut(label: '1 kg', unit: 'kg', value: 1, multiplierOfBase: 1.0),
        LooseBuyingShortcut(label: '5 kg', unit: 'kg', value: 5, multiplierOfBase: 5.0, isEnabled: false),
      ];
    }
  }

  Future<void> _loadShopProfile() async {
    try {
      final s = await _dataSource.fetchShopProfile(widget.shopId);
      if (s != null && mounted) {
        setState(() {
          _shopProfile = s;
          _entitlements = ProfessionalEntitlementResolver.resolve(s);
        });
      }
    } catch (_) {}
  }

  Future<void> _loadExistingProductData() async {
    final productId = widget.existingProduct?['id']?.toString();
    if (productId == null || productId.isEmpty) return;

    setState(() => _isLoadingData = true);

    try {
      // Load confidential vendor-only private pricing
      final pricing =
          await _dataSource.fetchProductPrivatePricing(widget.shopId, productId);
      if (pricing != null && pricing.costPrice > 0) {
        _costPriceController.text = pricing.costPrice % 1 == 0
            ? pricing.costPrice.toInt().toString()
            : pricing.costPrice.toString();
      }

      // If product has variants, fetch them
      if (widget.existingProduct?['hasVariants'] == true) {
        final variants =
            await _dataSource.fetchProductVariants(widget.shopId, productId);
        if (variants.isNotEmpty && mounted) {
          if (_archetype == ProductArchetype.variants) {
            final loaded = <ProductUnitOption>[];
            for (final v in variants) {
              loaded.add(ProductUnitOption(
                id: v.id,
                unit: v.selectedOptions['Unit'] ?? 'piece',
                value: v.selectedOptions['Value'] ?? v.title,
                sellingPrice: v.price ?? 0.0,
                mrp: v.mrp ?? (v.price ?? 0.0),
                stock: v.stockQuantity,
                isActive: v.isActive,
              ));
            }
            setState(() {
              _variantOptions = loaded;
              _isLoadingData = false;
            });
            return;
          } else if (_archetype == ProductArchetype.loose) {
            // Match existing shortcuts
            final updatedShortcuts = _buildDefaultShortcuts(_looseMeasurementUnit);
            for (final s in updatedShortcuts) {
              final match = variants.firstWhere(
                (v) => (v.title == s.label) || (v.selectedOptions['Value'] == s.value.toString()),
                orElse: () => const ProductVariantEntity(
                  id: '', productId: '', shopId: '', title: '',
                ),
              );
              if (match.id.isNotEmpty) {
                s.isEnabled = match.isActive;
                if (match.price != null && match.price! > 0) {
                  s.customPrice = match.price;
                }
              }
            }
            setState(() {
              _looseShortcuts = updatedShortcuts;
              _isLoadingData = false;
            });
            return;
          }
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoadingData = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _costPriceController.dispose();
    _lowStockController.dispose();
    _pieceSellingPriceController.dispose();
    _pieceMrpController.dispose();
    _pieceStockController.dispose();
    _loosePricePerUnitController.dispose();
    _looseMrpController.dispose();
    _looseStockController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ProviderLocaleController.instance.isHindi ? 'छवि का स्रोत चुनें' : 'Select Image Source',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEFF6FF),
                  child: Icon(Icons.camera_alt_rounded, color: Color(0xFF1D4ED8)),
                ),
                title: Text(
                  ProviderLocaleController.instance.isHindi ? 'कैमरा' : 'Camera',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFF0FDF4),
                  child: Icon(Icons.photo_library_rounded, color: Color(0xFF16A34A)),
                ),
                title: Text(
                  ProviderLocaleController.instance.isHindi ? 'गैलरी' : 'Gallery',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    final pickedFile = await picker.pickImage(source: source, imageQuality: 85);
    if (pickedFile == null) return;

    setState(() => _isUploadingImage = true);

    try {
      final bytes = await pickedFile.readAsBytes();
      final fileName =
          'prod_${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}';
      final mimeType = pickedFile.mimeType ?? 'image/jpeg';

      final result = await _r2Service.uploadBytes(
        bytes: bytes,
        folder: 'products',
        fileName: fileName,
        mimeType: mimeType,
        targetId: widget.shopId,
      );

      if (mounted) {
        setState(() {
          _images.add(result.objectKey);
          _isUploadingImage = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ProviderLocaleController.instance.isHindi ? 'छवि सफलतापूर्वक अपलोड हो गई' : 'Image uploaded successfully'),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _quickAddStoreCategory() async {
    final catController = TextEditingController();
    final catFormKey = GlobalKey<FormState>();

    final createdCategoryName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          ProviderLocaleController.instance.isHindi ? 'नई श्रेणी जोड़ें' : 'Add New Category',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        content: Form(
          key: catFormKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: catController,
                decoration: InputDecoration(
                  hintText: 'e.g. Vegetables, Dairy, Bakery',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? (ProviderLocaleController.instance.isHindi ? 'कृपया श्रेणी का नाम दर्ज करें' : 'Please enter category name')
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              ProviderLocaleController.instance.isHindi ? 'रद्द करें' : 'Cancel',
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D4ED8),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              if (catFormKey.currentState!.validate()) {
                Navigator.pop(ctx, catController.text.trim());
              }
            },
            child: Text(ProviderLocaleController.instance.isHindi ? 'श्रेणी जोड़ें' : 'Add Category'),
          ),
        ],
      ),
    );

    if (createdCategoryName != null && createdCategoryName.isNotEmpty) {
      try {
        final newCat = SellerStoreCategoryEntity(
          id: '',
          shopId: widget.shopId,
          name: createdCategoryName,
          nameHindi: '',
          isActive: true,
        );
        await _dataSource.saveStoreCategory(widget.shopId, newCat);
        if (mounted) {
          setState(() {
            _selectedStoreCategoryName = createdCategoryName;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Category "$createdCategoryName" created'),
              backgroundColor: const Color(0xFF16A34A),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _showAddVariantDialog({ProductUnitOption? existingOption, int? index}) {
    final titleCtrl = TextEditingController(text: existingOption?.value ?? '');
    final priceCtrl = TextEditingController(
      text: existingOption != null && existingOption.sellingPrice > 0
          ? (existingOption.sellingPrice % 1 == 0
              ? existingOption.sellingPrice.toInt().toString()
              : existingOption.sellingPrice.toString())
          : '',
    );
    final mrpCtrl = TextEditingController(
      text: existingOption != null && existingOption.mrp > 0
          ? (existingOption.mrp % 1 == 0
              ? existingOption.mrp.toInt().toString()
              : existingOption.mrp.toString())
          : '',
    );
    final stockCtrl = TextEditingController(
      text: existingOption != null ? '${existingOption.stock}' : '10',
    );
    final dialogKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          existingOption != null
              ? (ProviderLocaleController.instance.isHindi ? 'विकल्प संपादित करें' : 'Edit Option')
              : (ProviderLocaleController.instance.isHindi ? 'नया विकल्प जोड़ें' : 'Add New Option'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Form(
          key: dialogKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ProviderLocaleController.instance.isHindi ? 'विकल्प का नाम / साइज *' : 'Option Title / Size *',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                TextFormField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    hintText: 'e.g. S, M, L or 200 ml, 500 ml',
                    filled: true,
                    fillColor: Color(0xFFF8FAFC),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ProviderLocaleController.instance.isHindi ? 'बिक्री मूल्य (₹) *' : 'Selling Price (₹) *',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: priceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              hintText: '99',
                              filled: true,
                              fillColor: Color(0xFFF8FAFC),
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) {
                              final p = double.tryParse(v?.trim() ?? '');
                              if (p == null || p <= 0) return 'Required (> 0)';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ProviderLocaleController.instance.isHindi ? 'MRP (₹)' : 'MRP (₹)',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: mrpCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              hintText: '120',
                              filled: true,
                              fillColor: Color(0xFFF8FAFC),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (widget.existingProduct == null) ...[
                  const SizedBox(height: 12),
                  Text(
                    ProviderLocaleController.instance.isHindi ? 'उपलब्ध स्टॉक *' : 'Available Stock *',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: stockCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: '10',
                      filled: true,
                      fillColor: Color(0xFFF8FAFC),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final s = int.tryParse(v?.trim() ?? '');
                      if (s == null || s < 0) return 'Valid integer required';
                      return null;
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              ProviderLocaleController.instance.isHindi ? 'रद्द करें' : 'Cancel',
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D4ED8),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (!dialogKey.currentState!.validate()) return;
              final sp = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
              final mp = double.tryParse(mrpCtrl.text.trim()) ?? sp;
              final st = int.tryParse(stockCtrl.text.trim()) ?? 0;

              setState(() {
                if (existingOption != null && index != null) {
                  _variantOptions[index] = existingOption.copyWith(
                    value: titleCtrl.text.trim(),
                    sellingPrice: sp,
                    mrp: mp > 0 ? mp : sp,
                    stock: st,
                  );
                } else {
                  _variantOptions.add(ProductUnitOption(
                    unit: 'piece',
                    value: titleCtrl.text.trim(),
                    sellingPrice: sp,
                    mrp: mp > 0 ? mp : sp,
                    stock: st,
                  ));
                }
              });
              Navigator.pop(ctx);
            },
            child: Text(ProviderLocaleController.instance.isHindi ? 'सहेजें' : 'Save'),
          ),
        ],
      ),
    );
  }

  void _showUpgradeLimitDialog({required String title, required String message}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.lock_outline_rounded, color: Color(0xFF1D4ED8)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 13, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              ProviderLocaleController.instance.isHindi ? 'रद्द करें' : 'Cancel',
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          if (_shopProfile != null)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D4ED8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfessionalShopSubscriptionPage(shop: _shopProfile!),
                  ),
                ).then((_) => _loadShopProfile());
              },
              child: Text(ProviderLocaleController.instance.isHindi ? 'प्लान अपग्रेड करें' : 'Upgrade Plan'),
            ),
        ],
      ),
    );
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedStoreCategoryId == null || _selectedStoreCategoryId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ProviderLocaleController.instance.isHindi ? 'कृपया एक श्रेणी चुनें' : 'Please select a product category'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final isNew = widget.existingProduct == null;

    // Enforce subscription product capacity limit for new products
    if (isNew && _entitlements != null) {
      try {
        final existingProducts = await _dataSource.fetchShopProducts(widget.shopId);
        if (!mounted) return;
        if (!_entitlements!.canAddProduct(existingProducts.length)) {
          _showUpgradeLimitDialog(
            title: ProviderLocaleController.instance.isHindi ? 'उत्पाद सीमा समाप्त' : 'Product Limit Reached',
            message: ProviderLocaleController.instance.isHindi
                ? 'आपने अपने वर्तमान प्लान (${_entitlements!.planName}) की अधिकतम उत्पाद क्षमता (${_entitlements!.maxProducts} उत्पाद) पूरी कर ली है। कृपया अधिक उत्पाद जोड़ने के लिए अपना प्लान अपग्रेड करें।'
                : 'You have reached the maximum product capacity (${_entitlements!.maxProducts} products) for your current plan (${_entitlements!.planName}). Please upgrade your subscription to add more products.',
          );
          return;
        }
      } catch (_) {}
    }

    // Archetype specific validation
    double effectiveSellingPrice = 0.0;
    double effectiveMrp = 0.0;
    num effectiveInitialStock = 0;
    String effectiveParentUnit = 'piece';
    String effectiveStockType = 'pack';
    bool hasVariants = false;
    int baseStockUnits = 0;
    double minPrice = 0.0;
    double maxPrice = 0.0;

    if (_archetype == ProductArchetype.piecePacket) {
      final sp = double.tryParse(_pieceSellingPriceController.text.trim()) ?? 0.0;
      if (sp <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ProviderStrings.invalidPriceError),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      final mrp = double.tryParse(_pieceMrpController.text.trim()) ?? sp;
      if (mrp > 0 && mrp < sp) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ProviderStrings.mrpLowerThanPriceError),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      int stockVal = 0;
      if (isNew) {
        final parsedStock = int.tryParse(_pieceStockController.text.trim());
        if (parsedStock == null || parsedStock < 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(ProviderStrings.invalidStockError),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        stockVal = parsedStock;
      }

      effectiveSellingPrice = sp;
      effectiveMrp = mrp > 0 ? mrp : sp;
      effectiveInitialStock = stockVal;
      effectiveParentUnit = _pieceUnit;
      effectiveStockType = 'pack';
      hasVariants = false;
      minPrice = sp;
      maxPrice = sp;
    } else if (_archetype == ProductArchetype.loose) {
      final basePrice = double.tryParse(_loosePricePerUnitController.text.trim()) ?? 0.0;
      if (basePrice <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ProviderStrings.invalidPriceError),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      final mrp = double.tryParse(_looseMrpController.text.trim()) ?? basePrice;
      if (mrp > 0 && mrp < basePrice) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ProviderStrings.mrpLowerThanPriceError),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      double looseStock = 0.0;
      if (isNew) {
        final parsedStock = double.tryParse(_looseStockController.text.trim());
        if (parsedStock == null || parsedStock < 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(ProviderStrings.invalidStockError),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        looseStock = parsedStock;
      }

      effectiveSellingPrice = basePrice;
      effectiveMrp = mrp > 0 ? mrp : basePrice;
      effectiveInitialStock = looseStock;
      effectiveParentUnit = _looseMeasurementUnit; // STRICTLY 'kg' or 'L'
      effectiveStockType = 'bulk';
      baseStockUnits = (looseStock * 1000).round();
      hasVariants = _looseShortcuts.any((s) => s.isEnabled);
      minPrice = basePrice;
      maxPrice = basePrice;
    } else {
      // Sizes / Separate Packs
      if (_variantOptions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ProviderLocaleController.instance.isHindi ? 'कृपया कम से कम एक विकल्प जोड़ें' : 'Please add at least one option'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      int totalStock = 0;
      minPrice = _variantOptions.first.sellingPrice;
      maxPrice = _variantOptions.first.sellingPrice;
      double maxMrp = _variantOptions.first.mrp;

      for (final opt in _variantOptions) {
        if (opt.sellingPrice <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Option "${opt.displayTitle}" must have a valid selling price'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        if (opt.mrp > 0 && opt.mrp < opt.sellingPrice) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Option "${opt.displayTitle}" MRP cannot be less than selling price'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        if (opt.sellingPrice < minPrice) minPrice = opt.sellingPrice;
        if (opt.sellingPrice > maxPrice) maxPrice = opt.sellingPrice;
        if (opt.mrp > maxMrp) maxMrp = opt.mrp;
        totalStock += opt.stock;
      }

      effectiveSellingPrice = minPrice;
      effectiveMrp = maxMrp > 0 ? maxMrp : minPrice;
      effectiveInitialStock = totalStock;
      effectiveParentUnit = 'piece';
      effectiveStockType = 'pack';
      hasVariants = true;
    }

    setState(() => _isSaving = true);

    try {
      final discount = (effectiveMrp > effectiveSellingPrice && effectiveMrp > 0)
          ? (((effectiveMrp - effectiveSellingPrice) / effectiveMrp) * 100).roundToDouble()
          : 0.0;
      final thumb = _images.isNotEmpty ? _images.first : '';
      final costPrice = double.tryParse(_costPriceController.text.trim());
      final lowStock = int.tryParse(_lowStockController.text.trim()) ?? 5;

      final payload = {
        'shopId': widget.shopId,
        'titleEnglish': _nameController.text.trim(),
        'title': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'storeCategoryId': _selectedStoreCategoryId,
        'storeCategoryName': _selectedStoreCategoryName ?? '',
        'categoryName': _selectedStoreCategoryName ?? 'General',
        'unit': effectiveParentUnit,
        'unitValue': 1.0,
        'sellingPrice': effectiveSellingPrice,
        'regularPrice': effectiveMrp > 0 ? effectiveMrp : effectiveSellingPrice,
        'discountPercentage': discount,
        'thumbnailUrl': thumb,
        'images': _images,
        'stockType': effectiveStockType,
        if (_archetype == ProductArchetype.loose)
          'baseUnit': _looseMeasurementUnit == 'L' ? 'ml' : 'g',
        if (isNew) ...{
          if (_archetype == ProductArchetype.loose)
            'baseStockQuantity': baseStockUnits,
          'inStock': effectiveInitialStock > 0,
          'stockQuantity': effectiveInitialStock,
          if (_archetype == ProductArchetype.variants)
            'totalStockQuantity': effectiveInitialStock,
        },
        'lowStockThreshold': lowStock,
        'hasVariants': hasVariants,
        'minPrice': minPrice,
        'maxPrice': maxPrice,
      };

      final savedProductId = await _dataSource.saveProduct(
        widget.shopId,
        payload,
        productId: widget.existingProduct?['id'],
        costPrice: costPrice != null && costPrice > 0 ? costPrice : null,
        initialStock: effectiveInitialStock,
        lowStockThreshold: lowStock,
      );

      // Save subcollection variants
      if (hasVariants && savedProductId.isNotEmpty) {
        if (_archetype == ProductArchetype.loose) {
          for (final s in _looseShortcuts) {
            if (!s.isEnabled) continue;
            final calculatedPrice = s.effectivePrice(effectiveSellingPrice);
            final variant = ProductVariantEntity(
              id: '',
              productId: savedProductId,
              shopId: widget.shopId,
              title: s.label,
              priceMode: VariantPriceMode.override,
              price: calculatedPrice,
              mrp: calculatedPrice,
              stockQuantity: baseStockUnits,
              inStock: baseStockUnits > 0,
              baseUnitsPerOption: s.baseUnits,
              stockType: 'bulk',
              isActive: true,
              selectedOptions: {
                'Unit': s.unit,
                'Value': s.value % 1 == 0 ? s.value.toInt().toString() : s.value.toString(),
              },
            );
            await _dataSource.saveProductVariant(widget.shopId, savedProductId, variant);
          }
        } else if (_archetype == ProductArchetype.variants) {
          for (final opt in _variantOptions) {
            final variant = ProductVariantEntity(
              id: opt.id,
              productId: savedProductId,
              shopId: widget.shopId,
              title: opt.displayTitle,
              priceMode: VariantPriceMode.override,
              price: opt.sellingPrice,
              mrp: opt.mrp > 0 ? opt.mrp : opt.sellingPrice,
              stockQuantity: opt.stock,
              inStock: opt.stock > 0,
              baseUnitsPerOption: opt.baseUnitsPerOption,
              stockType: 'pack',
              isActive: opt.isActive,
              selectedOptions: {
                'Unit': opt.effectiveUnit,
                'Value': opt.value,
              },
            );
            await _dataSource.saveProductVariant(widget.shopId, savedProductId, variant);
          }

          for (final vid in _deletedVariantIds) {
            await _dataSource.toggleVariantActive(
                widget.shopId, savedProductId, vid, false);
          }
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existingProduct != null
                ? (ProviderLocaleController.instance.isHindi ? 'उत्पाद सफलतापूर्वक अपडेट किया गया' : 'Product updated successfully')
                : (ProviderLocaleController.instance.isHindi ? 'उत्पाद सफलतापूर्वक जोड़ा गया' : 'Product added successfully')),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving product: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingProduct != null;

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
          isEdit ? ProviderStrings.editProduct : 'उत्पाद जोड़ें (Add Product)',
          style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B)),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: TextButton.icon(
              onPressed: _isSaving ? null : _saveProduct,
              icon: _isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF1D4ED8)),
                    )
                  : const Icon(Icons.check_rounded,
                      size: 18, color: Color(0xFF1D4ED8)),
              label: Text(
                isEdit
                    ? (ProviderLocaleController.instance.isHindi ? 'अपडेट करें' : 'Update')
                    : (ProviderLocaleController.instance.isHindi ? 'सहेजें' : 'Save'),
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1D4ED8),
                    fontSize: 14),
              ),
            ),
          ),
        ],
      ),
      body: _isLoadingData
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1D4ED8)),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 960;

                return Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 20),
                    child: Center(
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(maxWidth: isWide ? 1040 : 680),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ===============================================
                            // STEP 1: BASIC INFORMATION CARD
                            // ===============================================
                            _buildCardWrapper(
                              title: 'उत्पाद की मुख्य जानकारी (Basic Information)',
                              icon: Icons.info_outline_rounded,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Product Name
                                  Text(
                                    '${ProviderStrings.productName} *',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E293B)),
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _nameController,
                                    decoration: InputDecoration(
                                      hintText: ProviderLocaleController.instance.isHindi
                                          ? 'उदा: बासमती चावल, लक्स साबुन, लाल मिर्च'
                                          : 'e.g. Basmati Rice, Lux Soap, Red Chilli',
                                      filled: true,
                                      fillColor: const Color(0xFFF8FAFC),
                                      contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 12),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                            color: Colors.grey.shade300),
                                      ),
                                    ),
                                    validator: (v) => v == null ||
                                            v.trim().isEmpty
                                        ? (ProviderLocaleController.instance.isHindi ? 'कृपया उत्पाद का नाम दर्ज करें' : 'Please enter product name')
                                        : null,
                                  ),
                                  const SizedBox(height: 16),

                                  // Category Dropdown + Add Category
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        ProviderLocaleController.instance.isHindi ? 'दुकान की श्रेणी *' : 'Category *',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1E293B)),
                                      ),
                                      TextButton.icon(
                                        onPressed: _quickAddStoreCategory,
                                        icon: const Icon(
                                            Icons.add_circle_outline_rounded,
                                            size: 15,
                                            color: Color(0xFF1D4ED8)),
                                        label: Text(
                                          ProviderLocaleController.instance.isHindi ? '+ नई श्रेणी' : '+ Add Category',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1D4ED8)),
                                        ),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  StreamBuilder<List<SellerStoreCategoryEntity>>(
                                    stream: _storeCategoriesStream,
                                    builder: (context, snapshot) {
                                      final categories =
                                          snapshot.data ?? const [];

                                      if (_selectedStoreCategoryId == null &&
                                          _selectedStoreCategoryName != null) {
                                        final matched = categories.firstWhere(
                                          (c) =>
                                              c.name.toLowerCase() ==
                                              _selectedStoreCategoryName!
                                                  .toLowerCase(),
                                          orElse: () =>
                                              const SellerStoreCategoryEntity(
                                                  id: '',
                                                  shopId: '',
                                                  name: '',
                                                  nameHindi: ''),
                                        );
                                        if (matched.id.isNotEmpty) {
                                          _selectedStoreCategoryId = matched.id;
                                        }
                                      }

                                      return DropdownButtonFormField<String>(
                                        key: ValueKey(_selectedStoreCategoryId),
                                        initialValue: _selectedStoreCategoryId,
                                        decoration: InputDecoration(
                                          hintText: ProviderLocaleController.instance.isHindi ? 'श्रेणी चुनें' : 'Select category',
                                          filled: true,
                                          fillColor: const Color(0xFFF8FAFC),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 14,
                                                  vertical: 12),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            borderSide: BorderSide(
                                                color: Colors.grey.shade300),
                                          ),
                                        ),
                                        items: categories.map((cat) {
                                          return DropdownMenuItem<String>(
                                            value: cat.id,
                                            child: Text(cat.name),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          setState(() {
                                            _selectedStoreCategoryId = val;
                                            final selected =
                                                categories.firstWhere(
                                              (c) => c.id == val,
                                              orElse: () =>
                                                  const SellerStoreCategoryEntity(
                                                      id: '',
                                                      shopId: '',
                                                      name: '',
                                                      nameHindi: ''),
                                            );
                                            _selectedStoreCategoryName =
                                                selected.name;
                                          });
                                        },
                                        validator: (v) => v == null ||
                                                v.trim().isEmpty
                                            ? (ProviderLocaleController.instance.isHindi ? 'कृपया एक श्रेणी चुनें' : 'Please select a category')
                                            : null,
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // Product Images
                                  Text(
                                    ProviderLocaleController.instance.isHindi ? 'सामान की फोटो' : 'Product Images',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E293B)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    ProviderLocaleController.instance.isHindi
                                        ? 'स्पष्ट फोटो जोड़ें। पहली फोटो दुकान पर मुख्य थंबनेल बनेगी।'
                                        : 'Upload clear photos. The first image will be used as the primary thumbnail.',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B)),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      // Upload Button
                                      InkWell(
                                        onTap: _isUploadingImage
                                            ? null
                                            : _pickAndUploadImage,
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        child: Container(
                                          width: 90,
                                          height: 90,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEFF6FF),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                                color: const Color(0xFF93C5FD)),
                                          ),
                                          child: Center(
                                            child: _isUploadingImage
                                                ? const CircularProgressIndicator(
                                                    color: Color(0xFF1D4ED8),
                                                    strokeWidth: 2)
                                                : Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                          Icons
                                                              .add_a_photo_rounded,
                                                          color:
                                                              Color(0xFF1D4ED8),
                                                          size: 26),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                          ProviderLocaleController.instance.isHindi ? 'फोटो जोड़ें' : 'Add Photo',
                                                          style: const TextStyle(
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: Color(
                                                                  0xFF1D4ED8))),
                                                    ],
                                                  ),
                                          ),
                                        ),
                                      ),

                                      // Uploaded Previews
                                      ..._images.asMap().entries.map((entry) {
                                        final idx = entry.key;
                                        final imgKey = entry.value;
                                        final isMain = idx == 0;

                                        return Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            Container(
                                              width: 90,
                                              height: 90,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: isMain
                                                      ? const Color(0xFF0F766E)
                                                      : Colors.grey.shade300,
                                                  width: isMain ? 2 : 1,
                                                ),
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                child: AppImageUtils.buildImage(
                                                  imgKey,
                                                  fit: BoxFit.cover,
                                                  errorWidget: const Icon(
                                                      Icons.broken_image,
                                                      color: Colors.grey),
                                                ),
                                              ),
                                            ),
                                            if (isMain)
                                              Positioned(
                                                bottom: 0,
                                                left: 0,
                                                right: 0,
                                                child: Container(
                                                  decoration: const BoxDecoration(
                                                    color: Color(0xFF0F766E),
                                                    borderRadius:
                                                        BorderRadius.vertical(
                                                            bottom:
                                                                Radius.circular(
                                                                    10)),
                                                  ),
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 2),
                                                  child: const Text(
                                                    'Primary',
                                                    textAlign:
                                                        TextAlign.center,
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 9.5,
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  ),
                                                ),
                                              ),
                                            Positioned(
                                              top: -6,
                                              right: -6,
                                              child: GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    _images.removeAt(idx);
                                                  });
                                                },
                                                child: Container(
                                                  decoration:
                                                      const BoxDecoration(
                                                    color: Colors.red,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  padding:
                                                      const EdgeInsets.all(3),
                                                  child: const Icon(
                                                      Icons.close,
                                                      size: 13,
                                                      color: Colors.white),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      }),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // ===============================================
                            // STEP 2: PRICING & PRODUCT TYPE SELECTION CARD
                            // ===============================================
                            _buildCardWrapper(
                              title: 'मूल्य एवं निजी लागत (Pricing & Private Costing)',
                              icon: Icons.sell_outlined,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ProviderStrings.productTypeHeading,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E293B)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    ProviderStrings.productTypeSubheading,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B)),
                                  ),
                                  const SizedBox(height: 12),

                                  // Archetype Selection Cards
                                  if (isEdit)
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.grey.shade300),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.lock_rounded, size: 18, color: Color(0xFF475569)),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _getArchetypeTitle(_archetype),
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF1E293B)),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE2E8F0),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'Locked',
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    Column(
                                      children: [
                                        _buildArchetypeRadioCard(
                                          archetype: ProductArchetype.piecePacket,
                                          title: ProviderStrings.archetypePieceTitle,
                                          subtitle: ProviderStrings.archetypePieceSubtitle,
                                          icon: Icons.inventory_2_outlined,
                                        ),
                                        const SizedBox(height: 8),
                                        _buildArchetypeRadioCard(
                                          archetype: ProductArchetype.loose,
                                          title: ProviderStrings.archetypeLooseTitle,
                                          subtitle: ProviderStrings.archetypeLooseSubtitle,
                                          icon: Icons.scale_outlined,
                                        ),
                                        const SizedBox(height: 8),
                                        _buildArchetypeRadioCard(
                                          archetype: ProductArchetype.variants,
                                          title: ProviderStrings.archetypeVariantsTitle,
                                          subtitle: ProviderStrings.archetypeVariantsSubtitle,
                                          icon: Icons.style_outlined,
                                        ),
                                      ],
                                    ),

                                  const SizedBox(height: 20),

                                  // Context-Sensitive Sub-form based on selected archetype
                                  if (_archetype == ProductArchetype.piecePacket)
                                    _buildPiecePacketForm(isEdit)
                                  else if (_archetype == ProductArchetype.loose)
                                    _buildLooseForm(isEdit)
                                  else
                                    _buildVariantsForm(isEdit),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // ===============================================
                            // STEP 3: OPTIONAL ADVANCED SECTION (EXPANDABLE)
                            // ===============================================
                            _buildCardWrapper(
                              title: 'निजी लागत और मुनाफा (Confidential — Vendor Only)',
                              icon: Icons.tune_rounded,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          ProviderStrings.advancedOptionalFields,
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1E293B)),
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          _isAdvancedExpanded
                                              ? Icons.keyboard_arrow_up_rounded
                                              : Icons.keyboard_arrow_down_rounded,
                                          color: const Color(0xFF1D4ED8),
                                        ),
                                        onPressed: () => setState(() =>
                                            _isAdvancedExpanded = !_isAdvancedExpanded),
                                      ),
                                    ],
                                  ),
                                  if (_isAdvancedExpanded) ...[
                                    const SizedBox(height: 12),
                                    // Description
                                    Text(
                                      ProviderLocaleController.instance.isHindi ? 'विवरण (Description)' : 'Description',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1E293B)),
                                    ),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _descriptionController,
                                      maxLines: 3,
                                      decoration: InputDecoration(
                                        hintText: ProviderLocaleController.instance.isHindi
                                            ? 'सामान की खासियत, ताजा होने की गारंटी आदि लिखें...'
                                            : 'Describe product features, quality, specifications...',
                                        filled: true,
                                        fillColor: const Color(0xFFF8FAFC),
                                        contentPadding: const EdgeInsets.all(14),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: BorderSide(
                                              color: Colors.grey.shade300),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Cost Price & Low Stock Threshold
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    ProviderStrings.costPricePerUnit,
                                                    style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,
                                                        color: Color(0xFF475569)),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  const Icon(Icons.lock_outline_rounded,
                                                      size: 13, color: Color(0xFF64748B)),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              TextFormField(
                                                controller: _costPriceController,
                                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                decoration: InputDecoration(
                                                  prefixText: '₹ ',
                                                  hintText: '30',
                                                  filled: true,
                                                  fillColor: const Color(0xFFF8FAFC),
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                ProviderStrings.lowStockThreshold,
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF475569)),
                                              ),
                                              const SizedBox(height: 6),
                                              TextFormField(
                                                controller: _lowStockController,
                                                keyboardType: TextInputType.number,
                                                decoration: InputDecoration(
                                                  hintText: '5',
                                                  filled: true,
                                                  fillColor: const Color(0xFFF8FAFC),
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Bottom Save Action
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1D4ED8),
                                foregroundColor: Colors.white,
                                elevation: 1,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _isSaving ? null : _saveProduct,
                              child: _isSaving
                                  ? Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                            ProviderLocaleController.instance.isHindi ? 'सहेजा जा रहा है...' : 'Saving Product...',
                                            style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold)),
                                      ],
                                    )
                                  : Text(
                                      isEdit
                                          ? (ProviderLocaleController.instance.isHindi ? 'उत्पाद विवरण अपडेट करें' : 'Update Product & Pricing')
                                          : 'उत्पाद जोड़ें (Add Product)',
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold),
                                    ),
                            ),
                            const SizedBox(height: 30),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  // ===========================================================================
  // SUB-FORMS PER ARCHETYPE
  // ===========================================================================

  Widget _buildPiecePacketForm(bool isEdit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Unit Selector
        Text(
          ProviderStrings.measurementUnit,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _pieceUnit,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          items: const [
            DropdownMenuItem(value: 'piece', child: Text('पीस (Piece)')),
            DropdownMenuItem(value: 'packet', child: Text('पैकेट (Packet)')),
            DropdownMenuItem(value: 'bottle', child: Text('बोतल (Bottle)')),
            DropdownMenuItem(value: 'box', child: Text('डिब्बा / बॉक्स (Box)')),
            DropdownMenuItem(value: 'dozen', child: Text('दर्जन (Dozen - 12 pcs)')),
            DropdownMenuItem(value: 'plate', child: Text('प्लेट (Plate)')),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _pieceUnit = val);
          },
        ),
        const SizedBox(height: 14),

        // Selling Price & MRP
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${ProviderStrings.pricePerPiece} *',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _pieceSellingPriceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      prefixText: '₹ ',
                      hintText: '40',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    validator: (v) {
                      final p = double.tryParse(v?.trim() ?? '');
                      if (p == null || p <= 0) return ProviderStrings.invalidPriceError;
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ProviderStrings.mrpOptional,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _pieceMrpController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      prefixText: '₹ ',
                      hintText: '50',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Stock input or Safe Edit Notice
        if (isEdit)
          _buildLockedStockNotice()
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${ProviderStrings.totalStockAvailable} *',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _pieceStockController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: '20',
                  helperText: ProviderLocaleController.instance.isHindi
                      ? 'दुकान में कितने पीस/पैकेट उपलब्ध हैं'
                      : 'Initial stock available in shop',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (v) {
                  final s = int.tryParse(v?.trim() ?? '');
                  if (s == null || s < 0) return ProviderStrings.invalidStockError;
                  return null;
                },
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildLooseForm(bool isEdit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Measurement Unit Toggle (kg vs L)
        Text(
          ProviderStrings.measurementUnit,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: isEdit
                    ? null
                    : () {
                        setState(() {
                          _looseMeasurementUnit = 'kg';
                          _looseShortcuts = _buildDefaultShortcuts('kg');
                        });
                      },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _looseMeasurementUnit == 'kg' ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _looseMeasurementUnit == 'kg' ? const Color(0xFF1D4ED8) : Colors.grey.shade300,
                      width: _looseMeasurementUnit == 'kg' ? 1.5 : 1.0,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      ProviderStrings.kilogram,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _looseMeasurementUnit == 'kg' ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: isEdit
                    ? null
                    : () {
                        setState(() {
                          _looseMeasurementUnit = 'L';
                          _looseShortcuts = _buildDefaultShortcuts('L');
                        });
                      },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _looseMeasurementUnit == 'L' ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _looseMeasurementUnit == 'L' ? const Color(0xFF1D4ED8) : Colors.grey.shade300,
                      width: _looseMeasurementUnit == 'L' ? 1.5 : 1.0,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      ProviderStrings.liter,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _looseMeasurementUnit == 'L' ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Selling Price per Unit & MRP
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _looseMeasurementUnit == 'L'
                        ? '${ProviderStrings.pricePerLitre} *'
                        : '${ProviderStrings.pricePerKg} *',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _loosePricePerUnitController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      prefixText: '₹ ',
                      hintText: '50',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      final p = double.tryParse(v?.trim() ?? '');
                      if (p == null || p <= 0) return ProviderStrings.invalidPriceError;
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ProviderStrings.mrpOptional,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _looseMrpController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      prefixText: '₹ ',
                      hintText: '60',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Total Available Stock (supports decimals like 25.5 kg)
        if (isEdit)
          _buildLockedStockNotice()
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${ProviderStrings.totalStockAvailable} ($_looseMeasurementUnit) *',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _looseStockController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: '25.5',
                  helperText: ProviderStrings.decimalStockHint,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (v) {
                  final s = double.tryParse(v?.trim() ?? '');
                  if (s == null || s < 0) return ProviderStrings.invalidStockError;
                  return null;
                },
              ),
            ],
          ),

        const SizedBox(height: 16),

        // Customer Buying Shortcuts
        Text(
          ProviderStrings.customerBuyingShortcuts,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 4),
        Text(
          ProviderStrings.customerBuyingShortcutsHelp,
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 10),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _looseShortcuts.map((shortcut) {
            final basePrice = double.tryParse(_loosePricePerUnitController.text.trim()) ?? 0.0;
            final price = shortcut.effectivePrice(basePrice);

            return FilterChip(
              selected: shortcut.isEnabled,
              onSelected: (selected) {
                setState(() => shortcut.isEnabled = selected);
              },
              label: Text('${shortcut.label} (₹${price % 1 == 0 ? price.toInt() : price})'),
              selectedColor: const Color(0xFFDBEAFE),
              checkmarkColor: const Color(0xFF1D4ED8),
              labelStyle: TextStyle(
                fontWeight: shortcut.isEnabled ? FontWeight.bold : FontWeight.normal,
                color: shortcut.isEnabled ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildVariantsForm(bool isEdit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              ProviderStrings.archetypeVariantsTitle,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            TextButton.icon(
              onPressed: () => _showAddVariantDialog(),
              icon: const Icon(Icons.add_circle_outline_rounded, size: 16, color: Color(0xFF1D4ED8)),
              label: Text(
                ProviderStrings.addOption,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8), fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (_variantOptions.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Center(
              child: Text(
                ProviderLocaleController.instance.isHindi
                    ? 'कोई विकल्प नहीं जोड़ा गया है। ऊपर दिए गए "+ नया विकल्प जोड़ें" बटन पर टैप करें।'
                    : 'No options added yet. Tap "+ Add Option" above to add your first size or pack.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _variantOptions.length,
            separatorBuilder: (_, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final opt = _variantOptions[index];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        opt.displayTitle,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('₹${opt.sellingPrice % 1 == 0 ? opt.sellingPrice.toInt() : opt.sellingPrice}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    if (!isEdit)
                      Text('${opt.stock} in stock',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF15803D), fontWeight: FontWeight.w600)),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF475569)),
                      onPressed: () => _showAddVariantDialog(existingOption: opt, index: index),
                      visualDensity: VisualDensity.compact,
                    ),
                    if (_variantOptions.length > 1)
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            if (opt.id.isNotEmpty) _deletedVariantIds.add(opt.id);
                            _variantOptions.removeAt(index);
                          });
                        },
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildArchetypeRadioCard({
    required ProductArchetype archetype,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _archetype == archetype;

    return InkWell(
      onTap: () => setState(() => _archetype = archetype),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF1D4ED8) : Colors.grey.shade300,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? const Color(0xFF1D4ED8) : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 10),
            Icon(icon, color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF64748B), size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getArchetypeTitle(ProductArchetype archetype) {
    switch (archetype) {
      case ProductArchetype.piecePacket:
        return ProviderStrings.archetypePieceTitle;
      case ProductArchetype.loose:
        return ProviderStrings.archetypeLooseTitle;
      case ProductArchetype.variants:
        return ProviderStrings.archetypeVariantsTitle;
    }
  }

  Widget _buildLockedStockNotice() {
    final currentStock = widget.existingProduct?['stockQuantity'] ?? 0;
    final unit = widget.existingProduct?['unit'] ?? '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2_rounded, color: Color(0xFF15803D), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${ProviderStrings.totalStockAvailable}: $currentStock $unit',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            ProviderStrings.stockLockedNotice,
            style: const TextStyle(fontSize: 11, color: Color(0xFF166534)),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfessionalShopInventoryPage(shopId: widget.shopId),
                  ),
                );
              },
              icon: const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF15803D)),
              label: Text(
                ProviderStrings.goToInventory,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF15803D)),
              ),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardWrapper({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF1D4ED8), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24, thickness: 1, color: Color(0xFFF1F5F9)),
          child,
        ],
      ),
    );
  }
}
