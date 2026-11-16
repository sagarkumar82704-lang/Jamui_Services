import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'product_variant_entity.dart';

/// Comprehensive, Universal Product Entity representing
/// `diamond_shops/{shopId}/products/{productId}` in the Hybrid Product Architecture.
/// Fully backward-compatible with legacy simple products.
class ProfessionalProductItemEntity extends Equatable {
  final String id;
  final String shopId;
  final String title;
  final String titleHindi;
  final String description;
  final String storeCategoryId;
  final String storeCategoryName;
  final String marketplaceCategory;

  // Hybrid Variant Architecture Flags & Aggregates
  final bool hasVariants;
  final int variantCount;
  final List<VariantOptionEntity> variantOptions;

  // Base Pricing (Authoritative for Simple products, Baseline for Variant products)
  final double basePrice;
  final double baseMrp;
  final String unit; // 'kg', 'liter', 'piece', 'pack', etc.

  // Catalog Display Aggregates (Single-Read Optimization for Shoppers)
  final double minPrice;
  final double maxPrice;
  final int totalStockQuantity;
  final bool inStock;
  final int lowStockThreshold;

  // Media (Cloudflare R2 Object Keys)
  final List<String> images;
  final String thumbnailUrl;

  // Universal Dynamic Attributes (Provider-Defined)
  final Map<String, dynamic> attributes;

  // Status & Timestamps
  final bool isAvailable;
  final bool isDeleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProfessionalProductItemEntity({
    required this.id,
    required this.shopId,
    required this.title,
    this.titleHindi = '',
    this.description = '',
    this.storeCategoryId = '',
    this.storeCategoryName = 'General',
    this.marketplaceCategory = 'General',
    this.hasVariants = false,
    this.variantCount = 0,
    this.variantOptions = const [],
    required this.basePrice,
    required this.baseMrp,
    this.unit = 'piece',
    double? minPrice,
    double? maxPrice,
    int? totalStockQuantity,
    bool? inStock,
    this.lowStockThreshold = 5,
    this.images = const [],
    this.thumbnailUrl = '',
    this.attributes = const {},
    this.isAvailable = true,
    this.isDeleted = false,
    this.createdAt,
    this.updatedAt,
  })  : minPrice = minPrice ?? basePrice,
        maxPrice = maxPrice ?? basePrice,
        totalStockQuantity = totalStockQuantity ?? 0,
        inStock = inStock ?? true;

  /// User-facing display title (English title with optional Hindi title)
  String get displayName => title.isNotEmpty ? title : titleHindi;

  /// Safe Catalog Aggregation: Computes parent product aggregates from active variants
  ProfessionalProductItemEntity withRecomputedAggregates(List<ProductVariantEntity> variants) {
    if (!hasVariants || variants.isEmpty) {
      return this;
    }

    final activeVariants = variants.where((v) => v.isActive).toList();
    if (activeVariants.isEmpty) {
      return copyWith(
        variantCount: variants.length,
        minPrice: basePrice,
        maxPrice: basePrice,
        totalStockQuantity: 0,
        inStock: false,
      );
    }

    double resolvedMin = double.infinity;
    double resolvedMax = 0.0;
    int resolvedStock = 0;

    for (final v in activeVariants) {
      final effPrice = v.resolvePrice(basePrice);
      if (effPrice < resolvedMin) resolvedMin = effPrice;
      if (effPrice > resolvedMax) resolvedMax = effPrice;
      resolvedStock += v.stockQuantity;
    }

    return copyWith(
      variantCount: variants.length,
      minPrice: resolvedMin.isFinite ? resolvedMin : basePrice,
      maxPrice: resolvedMax > 0 ? resolvedMax : basePrice,
      totalStockQuantity: resolvedStock,
      inStock: resolvedStock > 0,
    );
  }

  factory ProfessionalProductItemEntity.fromMap(Map<String, dynamic> map, String id, {required String shopId}) {
    DateTime? created;
    DateTime? updated;
    final rawCreated = map['createdAt'];
    if (rawCreated is Timestamp) created = rawCreated.toDate();
    if (rawCreated is String) created = DateTime.tryParse(rawCreated);
    final rawUpdated = map['updatedAt'];
    if (rawUpdated is Timestamp) updated = rawUpdated.toDate();
    if (rawUpdated is String) updated = DateTime.tryParse(rawUpdated);

    final rawImages = (map['images'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [];
    final thumb = (map['thumbnailUrl'] as String?) ?? (rawImages.isNotEmpty ? rawImages.first : '');

    // Backward-Compatible Pricing Extraction
    final bPrice = (map['basePrice'] as num?)?.toDouble() ??
        (map['sellingPrice'] as num?)?.toDouble() ??
        (map['price'] as num?)?.toDouble() ??
        0.0;
    final bMrp = (map['baseMrp'] as num?)?.toDouble() ??
        (map['regularPrice'] as num?)?.toDouble() ??
        (map['mrp'] as num?)?.toDouble() ??
        bPrice;

    final hasVars = (map['hasVariants'] as bool?) ?? false;

    // Parse Variant Options Definitions if present
    final rawOptions = (map['variantOptions'] as List<dynamic>?) ?? const [];
    final parsedOptions = rawOptions
        .whereType<Map>()
        .map((m) => VariantOptionEntity.fromMap(Map<String, dynamic>.from(m)))
        .toList();

    final rawAttrs = map['attributes'];
    Map<String, dynamic> parsedAttrs = const {};
    if (rawAttrs is Map<String, dynamic>) {
      parsedAttrs = rawAttrs;
    } else if (rawAttrs is Map) {
      parsedAttrs = Map<String, dynamic>.from(rawAttrs);
    }

    final stock = (map['totalStockQuantity'] as num?)?.toInt() ??
        (map['stockQuantity'] as num?)?.toInt() ??
        (map['stock'] as num?)?.toInt() ??
        0;

    return ProfessionalProductItemEntity(
      id: id,
      shopId: shopId,
      title: (map['title'] ?? map['titleEnglish'] ?? map['name'] ?? '').toString(),
      titleHindi: (map['titleHindi'] ?? map['nameHindi'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      storeCategoryId: (map['storeCategoryId'] ?? '').toString(),
      storeCategoryName: (map['storeCategoryName'] ?? map['categoryName'] ?? 'General').toString(),
      marketplaceCategory: (map['marketplaceCategory'] ?? map['category'] ?? 'General').toString(),
      hasVariants: hasVars,
      variantCount: (map['variantCount'] as num?)?.toInt() ?? (hasVars ? parsedOptions.length : 0),
      variantOptions: parsedOptions,
      basePrice: bPrice,
      baseMrp: bMrp,
      unit: (map['unit'] ?? 'piece').toString(),
      minPrice: (map['minPrice'] as num?)?.toDouble() ?? bPrice,
      maxPrice: (map['maxPrice'] as num?)?.toDouble() ?? bPrice,
      totalStockQuantity: stock,
      inStock: (map['inStock'] as bool?) ?? (map['isAvailable'] as bool?) ?? (stock > 0),
      lowStockThreshold: (map['lowStockThreshold'] as num?)?.toInt() ?? 5,
      images: rawImages,
      thumbnailUrl: thumb,
      attributes: parsedAttrs,
      isAvailable: (map['isAvailable'] as bool?) ?? true,
      isDeleted: (map['isDeleted'] as bool?) ?? false,
      createdAt: created,
      updatedAt: updated,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shopId': shopId,
      'title': title,
      'titleHindi': titleHindi,
      'description': description,
      'storeCategoryId': storeCategoryId,
      'storeCategoryName': storeCategoryName,
      'marketplaceCategory': marketplaceCategory,
      'hasVariants': hasVariants,
      'variantCount': variantCount,
      'variantOptions': variantOptions.map((o) => o.toMap()).toList(),
      'basePrice': basePrice,
      'baseMrp': baseMrp,
      // Backward compatibility mirror keys for existing simple product readers
      'price': basePrice,
      'sellingPrice': basePrice,
      'mrp': baseMrp,
      'regularPrice': baseMrp,
      'stockQuantity': totalStockQuantity,
      'stock': totalStockQuantity,
      'unit': unit,
      'minPrice': minPrice,
      'maxPrice': maxPrice,
      'totalStockQuantity': totalStockQuantity,
      'inStock': inStock,
      'lowStockThreshold': lowStockThreshold,
      'images': images,
      'thumbnailUrl': thumbnailUrl,
      'attributes': attributes,
      'isAvailable': isAvailable,
      'isDeleted': isDeleted,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  ProfessionalProductItemEntity copyWith({
    String? id,
    String? shopId,
    String? title,
    String? titleHindi,
    String? description,
    String? storeCategoryId,
    String? storeCategoryName,
    String? marketplaceCategory,
    bool? hasVariants,
    int? variantCount,
    List<VariantOptionEntity>? variantOptions,
    double? basePrice,
    double? baseMrp,
    String? unit,
    double? minPrice,
    double? maxPrice,
    int? totalStockQuantity,
    bool? inStock,
    int? lowStockThreshold,
    List<String>? images,
    String? thumbnailUrl,
    Map<String, dynamic>? attributes,
    bool? isAvailable,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProfessionalProductItemEntity(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      title: title ?? this.title,
      titleHindi: titleHindi ?? this.titleHindi,
      description: description ?? this.description,
      storeCategoryId: storeCategoryId ?? this.storeCategoryId,
      storeCategoryName: storeCategoryName ?? this.storeCategoryName,
      marketplaceCategory: marketplaceCategory ?? this.marketplaceCategory,
      hasVariants: hasVariants ?? this.hasVariants,
      variantCount: variantCount ?? this.variantCount,
      variantOptions: variantOptions ?? this.variantOptions,
      basePrice: basePrice ?? this.basePrice,
      baseMrp: baseMrp ?? this.baseMrp,
      unit: unit ?? this.unit,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      totalStockQuantity: totalStockQuantity ?? this.totalStockQuantity,
      inStock: inStock ?? this.inStock,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      images: images ?? this.images,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      attributes: attributes ?? this.attributes,
      isAvailable: isAvailable ?? this.isAvailable,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        shopId,
        title,
        hasVariants,
        variantCount,
        basePrice,
        minPrice,
        maxPrice,
        totalStockQuantity,
        inStock,
        isActiveOrAvailable,
      ];

  bool get isActiveOrAvailable => isAvailable && !isDeleted;
}

