import 'package:equatable/equatable.dart';

/// Supported attribute input widget types
enum AttributeFieldType {
  text,
  number,
  date,
  dropdown,
  chips,
}

/// Definition of a dynamic category product attribute field
class CategoryAttributeDefinition extends Equatable {
  final String key;
  final String label;
  final String labelHindi;
  final AttributeFieldType type;
  final List<String> options;
  final bool isRequired;
  final String? helperText;
  final int displayOrder;

  const CategoryAttributeDefinition({
    required this.key,
    required this.label,
    required this.labelHindi,
    required this.type,
    this.options = const [],
    this.isRequired = false,
    this.helperText,
    this.displayOrder = 0,
  });

  @override
  List<Object?> get props => [key, label, labelHindi, type, options, isRequired, displayOrder];
}

/// Authoritative client-side registry providing dynamic attribute definitions
/// for all 8 supported Jamui Services marketplace categories.
/// Designed for easy future migration to Admin Panel Firestore-backed configs.
class CategoryAttributeRegistry {
  static const String categoryGrocery = 'Grocery';
  static const String categoryDairy = 'Milk & Dairy';
  static const String categoryVegetables = 'Vegetables';
  static const String categoryFruits = 'Fruits';
  static const String categoryClothing = 'Clothing';
  static const String categoryFootwear = 'Footwear';
  static const String categoryElectronics = 'Electronics';
  static const String categoryCosmetics = 'Cosmetics';

  /// All 8 canonical supported categories
  static const List<String> supportedCategories = [
    categoryGrocery,
    categoryDairy,
    categoryVegetables,
    categoryFruits,
    categoryClothing,
    categoryFootwear,
    categoryElectronics,
    categoryCosmetics,
  ];

  /// Returns attribute definitions for a given marketplace category name or ID
  static List<CategoryAttributeDefinition> getAttributesForCategory(String? categoryNameOrId) {
    if (categoryNameOrId == null || categoryNameOrId.isEmpty) {
      return _groceryAttributes; // Default fallback
    }

    final normalized = categoryNameOrId.trim().toLowerCase();

    if (normalized.contains('grocery') || normalized.contains('किराना')) {
      return _groceryAttributes;
    } else if (normalized.contains('dairy') || normalized.contains('milk') || normalized.contains('दूध')) {
      return _dairyAttributes;
    } else if (normalized.contains('vegetable') || normalized.contains('सब्जी') || normalized.contains('sabzi')) {
      return _vegetableAttributes;
    } else if (normalized.contains('fruit') || normalized.contains('फल')) {
      return _fruitAttributes;
    } else if (normalized.contains('cloth') || normalized.contains('garment') || normalized.contains('कपड़े')) {
      return _clothingAttributes;
    } else if (normalized.contains('footwear') || normalized.contains('shoe') || normalized.contains('जूते')) {
      return _footwearAttributes;
    } else if (normalized.contains('electronic') || normalized.contains('बिजली') || normalized.contains('device')) {
      return _electronicsAttributes;
    } else if (normalized.contains('cosmetic') || normalized.contains('beauty') || normalized.contains('श्रृंगार')) {
      return _cosmeticsAttributes;
    }

    // Default to grocery attributes for general grocery/retail
    return _groceryAttributes;
  }

  // --- 1. GROCERY ATTRIBUTES ---
  static const List<CategoryAttributeDefinition> _groceryAttributes = [
    CategoryAttributeDefinition(
      key: 'brand',
      label: 'Brand / Company',
      labelHindi: 'ब्रांड / कंपनी',
      type: AttributeFieldType.text,
      isRequired: false,
      helperText: 'e.g. Tata, Fortune, Aashirvaad',
      displayOrder: 1,
    ),
    CategoryAttributeDefinition(
      key: 'weight',
      label: 'Pack Weight / Net Qty',
      labelHindi: 'वजन / मात्रा',
      type: AttributeFieldType.text,
      isRequired: false,
      helperText: 'e.g. 500 gm, 1 kg, 5 liter',
      displayOrder: 2,
    ),
    CategoryAttributeDefinition(
      key: 'expiryDate',
      label: 'Expiry / Best Before Date',
      labelHindi: 'समाप्ति तिथि (Expiry Date)',
      type: AttributeFieldType.date,
      isRequired: false,
      helperText: 'YYYY-MM-DD',
      displayOrder: 3,
    ),
  ];

  // --- 2. MILK & DAIRY ATTRIBUTES ---
  static const List<CategoryAttributeDefinition> _dairyAttributes = [
    CategoryAttributeDefinition(
      key: 'brand',
      label: 'Dairy Brand',
      labelHindi: 'डेयरी ब्रांड',
      type: AttributeFieldType.text,
      isRequired: false,
      helperText: 'e.g. Sudha, Amul, Mother Dairy',
      displayOrder: 1,
    ),
    CategoryAttributeDefinition(
      key: 'quantity',
      label: 'Volume / Weight',
      labelHindi: 'मात्रा / वजन',
      type: AttributeFieldType.text,
      isRequired: true,
      helperText: 'e.g. 500 ml, 1 L, 200 gm',
      displayOrder: 2,
    ),
    CategoryAttributeDefinition(
      key: 'unit',
      label: 'Unit',
      labelHindi: 'इकाई',
      type: AttributeFieldType.dropdown,
      options: ['liter', 'ml', 'kg', 'gm', 'pouch'],
      isRequired: true,
      displayOrder: 3,
    ),
    CategoryAttributeDefinition(
      key: 'storageType',
      label: 'Storage Condition',
      labelHindi: 'भंडारण प्रकार',
      type: AttributeFieldType.dropdown,
      options: ['Keep Refrigerated (0-4°C)', 'Keep Frozen (-18°C)', 'Store in Cool & Dry Place'],
      isRequired: false,
      displayOrder: 4,
    ),
    CategoryAttributeDefinition(
      key: 'expiryDate',
      label: 'Use By / Expiry Date',
      labelHindi: 'समाप्ति तिथि (Use By Date)',
      type: AttributeFieldType.date,
      isRequired: true,
      displayOrder: 5,
    ),
  ];

  // --- 3. VEGETABLES ATTRIBUTES ---
  static const List<CategoryAttributeDefinition> _vegetableAttributes = [
    CategoryAttributeDefinition(
      key: 'freshness',
      label: 'Freshness Level',
      labelHindi: 'ताज़गी का स्तर',
      type: AttributeFieldType.dropdown,
      options: ['Farm Fresh Today (आज का ताज़ा)', 'Fresh (ताज़ा)', 'Stored Fresh (कोल्ड स्टोरेज)'],
      isRequired: true,
      displayOrder: 1,
    ),
    CategoryAttributeDefinition(
      key: 'pricePerKg',
      label: 'Price per KG (₹)',
      labelHindi: 'प्रति किलो मूल्य (₹)',
      type: AttributeFieldType.number,
      isRequired: true,
      displayOrder: 2,
    ),
    CategoryAttributeDefinition(
      key: 'harvestDate',
      label: 'Harvest / Arrival Date',
      labelHindi: 'आगमन तिथि',
      type: AttributeFieldType.date,
      isRequired: false,
      displayOrder: 3,
    ),
  ];

  // --- 4. FRUITS ATTRIBUTES ---
  static const List<CategoryAttributeDefinition> _fruitAttributes = [
    CategoryAttributeDefinition(
      key: 'variety',
      label: 'Fruit Variety / Origin',
      labelHindi: 'किस्म / उद्गम',
      type: AttributeFieldType.text,
      isRequired: false,
      helperText: 'e.g. Shimla Apple, Nagpur Orange, Desi',
      displayOrder: 1,
    ),
    CategoryAttributeDefinition(
      key: 'ripeness',
      label: 'Ripeness Status',
      labelHindi: 'पकाव की स्थिति',
      type: AttributeFieldType.dropdown,
      options: ['Ready to Eat (खाने के लिए तैयार)', 'Semi Ripe (आधा पका)', 'Fresh Harvest'],
      isRequired: false,
      displayOrder: 2,
    ),
    CategoryAttributeDefinition(
      key: 'unit',
      label: 'Unit of Sale',
      labelHindi: 'बिक्री इकाई',
      type: AttributeFieldType.dropdown,
      options: ['kg', 'dozen', 'piece', 'box'],
      isRequired: true,
      displayOrder: 3,
    ),
  ];

  // --- 5. CLOTHING ATTRIBUTES ---
  static const List<CategoryAttributeDefinition> _clothingAttributes = [
    CategoryAttributeDefinition(
      key: 'sizes',
      label: 'Available Sizes',
      labelHindi: 'उपलब्ध आकार (Sizes)',
      type: AttributeFieldType.chips,
      options: ['XS', 'S', 'M', 'L', 'XL', 'XXL', '3XL', 'Free Size'],
      isRequired: true,
      displayOrder: 1,
    ),
    CategoryAttributeDefinition(
      key: 'color',
      label: 'Color',
      labelHindi: 'रंग',
      type: AttributeFieldType.text,
      isRequired: false,
      helperText: 'e.g. Blue, Red, Black, Multi',
      displayOrder: 2,
    ),
    CategoryAttributeDefinition(
      key: 'fabric',
      label: 'Fabric Material',
      labelHindi: 'कपड़े का प्रकार (Fabric)',
      type: AttributeFieldType.text,
      isRequired: false,
      helperText: 'e.g. Pure Cotton, Linen, Silk, Denim',
      displayOrder: 3,
    ),
    CategoryAttributeDefinition(
      key: 'gender',
      label: 'Target Segment',
      labelHindi: 'वर्ग (Gender / Age)',
      type: AttributeFieldType.dropdown,
      options: ['Men (पुरुष)', 'Women (महिला)', 'Boys (लड़के)', 'Girls (लड़कियाँ)', 'Infant (शिशु)', 'Unisex'],
      isRequired: true,
      displayOrder: 4,
    ),
  ];

  // --- 6. FOOTWEAR ATTRIBUTES ---
  static const List<CategoryAttributeDefinition> _footwearAttributes = [
    CategoryAttributeDefinition(
      key: 'shoeSizes',
      label: 'Shoe Sizes (UK / India)',
      labelHindi: 'जूते का आकार (Size)',
      type: AttributeFieldType.chips,
      options: ['4', '5', '6', '7', '8', '9', '10', '11', '12'],
      isRequired: true,
      displayOrder: 1,
    ),
    CategoryAttributeDefinition(
      key: 'brand',
      label: 'Brand',
      labelHindi: 'ब्रांड',
      type: AttributeFieldType.text,
      isRequired: false,
      helperText: 'e.g. Bata, Sparx, Campus',
      displayOrder: 2,
    ),
    CategoryAttributeDefinition(
      key: 'color',
      label: 'Color',
      labelHindi: 'रंग',
      type: AttributeFieldType.text,
      isRequired: false,
      displayOrder: 3,
    ),
    CategoryAttributeDefinition(
      key: 'material',
      label: 'Upper Material',
      labelHindi: 'मटेरियल',
      type: AttributeFieldType.dropdown,
      options: ['Leather', 'Synthetic', 'Mesh / Fabric', 'Rubber', 'Canvas'],
      isRequired: false,
      displayOrder: 4,
    ),
  ];

  // --- 7. ELECTRONICS ATTRIBUTES ---
  static const List<CategoryAttributeDefinition> _electronicsAttributes = [
    CategoryAttributeDefinition(
      key: 'brand',
      label: 'Brand',
      labelHindi: 'ब्रांड',
      type: AttributeFieldType.text,
      isRequired: true,
      helperText: 'e.g. Samsung, boAt, Realme, Philips',
      displayOrder: 1,
    ),
    CategoryAttributeDefinition(
      key: 'model',
      label: 'Model Name / Number',
      labelHindi: 'मॉडल नंबर',
      type: AttributeFieldType.text,
      isRequired: false,
      helperText: 'e.g. M14 5G, Bassheads 100',
      displayOrder: 2,
    ),
    CategoryAttributeDefinition(
      key: 'warranty',
      label: 'Warranty Period',
      labelHindi: 'वारंटी अवधि',
      type: AttributeFieldType.dropdown,
      options: ['No Warranty', '6 Months Manufacturer Warranty', '1 Year Manufacturer Warranty', '2 Years Warranty'],
      isRequired: true,
      displayOrder: 3,
    ),
  ];

  // --- 8. COSMETICS ATTRIBUTES ---
  static const List<CategoryAttributeDefinition> _cosmeticsAttributes = [
    CategoryAttributeDefinition(
      key: 'brand',
      label: 'Brand',
      labelHindi: 'ब्रांड',
      type: AttributeFieldType.text,
      isRequired: true,
      helperText: 'e.g. Lakme, Maybelline, Nivea, Himalaya',
      displayOrder: 1,
    ),
    CategoryAttributeDefinition(
      key: 'netContent',
      label: 'Net Content / Quantity',
      labelHindi: 'मात्रा',
      type: AttributeFieldType.text,
      isRequired: true,
      helperText: 'e.g. 50 ml, 100 gm, 1 Piece',
      displayOrder: 2,
    ),
    CategoryAttributeDefinition(
      key: 'targetType',
      label: 'Skin / Hair Type',
      labelHindi: 'त्वचा / बालों का प्रकार',
      type: AttributeFieldType.dropdown,
      options: ['All Skin Types', 'Oily Skin', 'Dry Skin', 'Normal Skin', 'Sensitive Skin', 'All Hair Types'],
      isRequired: false,
      displayOrder: 3,
    ),
    CategoryAttributeDefinition(
      key: 'expiryDate',
      label: 'Expiry / Best Before Date',
      labelHindi: 'समाप्ति तिथि (Expiry Date)',
      type: AttributeFieldType.date,
      isRequired: true,
      displayOrder: 4,
    ),
  ];
}
