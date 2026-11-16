import 'package:equatable/equatable.dart';

class ProfessionalProductEntity extends Equatable {
  final String id;
  final String shopId;
  final String categoryName;
  final String storeCategoryId;
  final String storeCategoryName;
  final String titleHindi;
  final String titleEnglish;
  final String description;
  final String unit; // 'kg', 'gm', 'liter', 'piece', 'pack'
  final double unitValue; // e.g. 1, 500, 250
  final double regularPrice; // MRP
  final double sellingPrice; // Final customer price
  final double discountPercentage;
  final List<String> images;
  final String thumbnailUrl;
  final bool inStock;
  final bool trackInventory;
  final int stockQuantity;
  final bool isBestSeller;
  final bool isFeatured;
  final bool isActive;
  final bool isDeleted;
  final Map<String, dynamic> attributes;
  final bool hasVariants;
  final double minPrice;
  final double maxPrice;
  final List<Map<String, dynamic>> variantOptions;
  final String stockType; // 'pack' or 'bulk'
  final String baseUnit; // 'g', 'ml', 'piece'
  final int baseStockQuantity; // Integer base units for bulk inventory

  const ProfessionalProductEntity({
    required this.id,
    required this.shopId,
    this.categoryName = 'General',
    this.storeCategoryId = '',
    this.storeCategoryName = '',
    required this.titleHindi,
    required this.titleEnglish,
    this.description = '',
    this.unit = 'kg',
    this.unitValue = 1.0,
    required this.regularPrice,
    required this.sellingPrice,
    this.discountPercentage = 0.0,
    this.images = const [],
    this.thumbnailUrl = '',
    this.inStock = true,
    this.trackInventory = false,
    this.stockQuantity = 0,
    this.isBestSeller = false,
    this.isFeatured = false,
    this.isActive = true,
    this.isDeleted = false,
    this.attributes = const {},
    this.hasVariants = false,
    double? minPrice,
    double? maxPrice,
    this.variantOptions = const [],
    this.stockType = 'pack',
    this.baseUnit = 'piece',
    this.baseStockQuantity = 0,
  })  : minPrice = minPrice ?? sellingPrice,
        maxPrice = maxPrice ?? sellingPrice;

  String get displayName => titleEnglish.isNotEmpty ? titleEnglish : titleHindi;
  String get name => displayName;

  String get unitLabel {
    if (unitValue == 1.0) {
      return '1 $unit';
    }
    final formattedVal = unitValue % 1 == 0 ? unitValue.toInt().toString() : unitValue.toString();
    return '$formattedVal $unit';
  }

  factory ProfessionalProductEntity.fromMap(Map<String, dynamic> map, String id, String shopId) {
    final regPrice = (map['regularPrice'] as num?)?.toDouble() ??
        (map['mrp'] as num?)?.toDouble() ??
        (map['price'] as num?)?.toDouble() ??
        0.0;
    final sellPrice = (map['sellingPrice'] as num?)?.toDouble() ??
        (map['price'] as num?)?.toDouble() ??
        regPrice;

    double disc = (map['discountPercentage'] as num?)?.toDouble() ?? 0.0;
    if (disc == 0.0 && regPrice > sellPrice && regPrice > 0) {
      disc = ((regPrice - sellPrice) / regPrice * 100).roundToDouble();
    }

    final rawImages = (map['images'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final thumb = (map['thumbnailUrl'] as String?) ?? (rawImages.isNotEmpty ? rawImages.first : '');

    final rawAttrs = map['attributes'];
    Map<String, dynamic> parsedAttrs = const {};
    if (rawAttrs is Map<String, dynamic>) {
      parsedAttrs = rawAttrs;
    } else if (rawAttrs is Map) {
      parsedAttrs = Map<String, dynamic>.from(rawAttrs);
    }

    final storeCatName = (map['storeCategoryName'] as String?) ?? (map['categoryName'] as String?) ?? (map['category'] as String?) ?? 'General';

    return ProfessionalProductEntity(
      id: id,
      shopId: shopId,
      categoryName: storeCatName,
      storeCategoryId: (map['storeCategoryId'] as String?) ?? '',
      storeCategoryName: storeCatName,
      titleHindi: (map['titleHindi'] as String?) ?? (map['nameHindi'] as String?) ?? '',
      titleEnglish: (map['titleEnglish'] as String?) ?? (map['title'] as String?) ?? (map['name'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      unit: (map['unit'] as String?) ?? 'kg',
      unitValue: (map['unitValue'] as num?)?.toDouble() ?? 1.0,
      regularPrice: regPrice,
      sellingPrice: sellPrice,
      discountPercentage: disc,
      images: rawImages,
      thumbnailUrl: thumb,
      inStock: (map['inStock'] as bool?) ?? (map['isAvailable'] as bool?) ?? true,
      trackInventory: (map['trackInventory'] as bool?) ?? false,
      stockQuantity: (map['stockQuantity'] as num?)?.toInt() ?? 0,
      isBestSeller: (map['isBestSeller'] as bool?) ?? false,
      isFeatured: (map['isFeatured'] as bool?) ?? false,
      isActive: (map['isActive'] as bool?) ?? true,
      isDeleted: (map['isDeleted'] as bool?) ?? false,
      attributes: parsedAttrs,
      hasVariants: (map['hasVariants'] as bool?) ?? false,
      minPrice: (map['minPrice'] as num?)?.toDouble() ?? sellPrice,
      maxPrice: (map['maxPrice'] as num?)?.toDouble() ?? sellPrice,
      variantOptions: (map['variantOptions'] as List<dynamic>?)
              ?.whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          const [],
      stockType: (map['stockType'] as String?) ?? 'pack',
      baseUnit: (map['baseUnit'] as String?) ?? 'piece',
      baseStockQuantity: (map['baseStockQuantity'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'shopId': shopId,
      'categoryName': categoryName,
      'storeCategoryId': storeCategoryId,
      'storeCategoryName': storeCategoryName,
      'titleHindi': titleHindi,
      'titleEnglish': titleEnglish,
      'description': description,
      'unit': unit,
      'unitValue': unitValue,
      'regularPrice': regularPrice,
      'sellingPrice': sellingPrice,
      'discountPercentage': discountPercentage,
      'images': images,
      'thumbnailUrl': thumbnailUrl,
      'inStock': inStock,
      'trackInventory': trackInventory,
      'stockQuantity': stockQuantity,
      'isBestSeller': isBestSeller,
      'isFeatured': isFeatured,
      'isActive': isActive,
      'isDeleted': isDeleted,
      'attributes': attributes,
      'hasVariants': hasVariants,
      'minPrice': minPrice,
      'maxPrice': maxPrice,
      'variantOptions': variantOptions,
      'stockType': stockType,
      'baseUnit': baseUnit,
      'baseStockQuantity': baseStockQuantity,
    };
  }

  @override
  List<Object?> get props => [id, shopId, titleEnglish, sellingPrice, inStock, isActive, attributes];
}

