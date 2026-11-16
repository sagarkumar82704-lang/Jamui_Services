import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Explicit Price Resolution Mode for Product Variants
enum VariantPriceMode {
  inherit, // Inherits basePrice and baseMrp from parent product document
  override; // Explicitly defines variant-specific price and mrp

  static VariantPriceMode fromString(String? val) {
    if (val == 'override') return VariantPriceMode.override;
    return VariantPriceMode.inherit;
  }

  String get asString => this == VariantPriceMode.override ? 'override' : 'inherit';
}

/// Represents a configurable variant option dimension (e.g. Size, Color, Pack, Weight)
class VariantOptionEntity extends Equatable {
  final String id;
  final String name; // e.g. "Size", "Color", "Pack"
  final String nameHindi; // e.g. "साइज", "रंग", "पैकेट"
  final String displayType; // "pills", "color_swatch", "dropdown"
  final List<String> values; // e.g. ["38", "40", "42"] or ["1 kg", "5 kg"]

  const VariantOptionEntity({
    required this.id,
    required this.name,
    this.nameHindi = '',
    this.displayType = 'pills',
    this.values = const [],
  });

  factory VariantOptionEntity.fromMap(Map<String, dynamic> map) {
    return VariantOptionEntity(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      nameHindi: (map['nameHindi'] ?? '').toString(),
      displayType: (map['displayType'] ?? 'pills').toString(),
      values: (map['values'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      if (nameHindi.isNotEmpty) 'nameHindi': nameHindi,
      'displayType': displayType,
      'values': values,
    };
  }

  @override
  List<Object?> get props => [id, name, nameHindi, displayType, values];
}

/// Represents an independent, first-class product variant entity stored in
/// `diamond_shops/{shopId}/products/{productId}/variants/{variantId}`
class ProductVariantEntity extends Equatable {
  final String id;
  final String productId;
  final String shopId;
  final String title; // e.g. "38 / Navy Blue" or "5 kg Pack"
  final String sku; // e.g. "RYM-SH-38-NVY"
  final String? barcode;
  final Map<String, String> selectedOptions; // e.g. {"Size": "38", "Color": "Navy Blue"}
  
  final VariantPriceMode priceMode;
  final double? price; // Selling price (when priceMode == override)
  final double? mrp; // MRP (when priceMode == override)
  
  final int stockQuantity; // Authoritative variant stock
  final int lowStockThreshold;
  final bool inStock;
  final bool trackInventory;
  
  final List<String> images; // Cloudflare R2 object keys
  final String thumbnailUrl;
  
  final int? weightGrams;
  final Map<String, num>? dimensions;
  final int? baseUnitsPerOption;
  final String? stockType;
  
  final bool isActive; // Soft deactivation (never hard-deleted if orders/ledger exist)
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProductVariantEntity({
    required this.id,
    required this.productId,
    required this.shopId,
    required this.title,
    this.sku = '',
    this.barcode,
    this.selectedOptions = const {},
    this.priceMode = VariantPriceMode.inherit,
    this.price,
    this.mrp,
    this.stockQuantity = 0,
    this.lowStockThreshold = 5,
    this.inStock = true,
    this.trackInventory = true,
    this.images = const [],
    this.thumbnailUrl = '',
    this.weightGrams,
    this.dimensions,
    this.baseUnitsPerOption,
    this.stockType,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  /// Resolves effective selling price: uses variant price if override, otherwise falls back to parent basePrice
  double resolvePrice(double parentBasePrice) {
    if (priceMode == VariantPriceMode.override && price != null && price! > 0) {
      return price!;
    }
    return parentBasePrice;
  }

  /// Resolves effective MRP: uses variant mrp if override, otherwise falls back to parent baseMrp
  double resolveMrp(double parentBaseMrp) {
    if (priceMode == VariantPriceMode.override && mrp != null && mrp! > 0) {
      return mrp!;
    }
    return parentBaseMrp;
  }

  /// Validates price override rules. Throws [ArgumentError] if invalid override is attempted.
  void validatePriceOverride(double parentBasePrice, double parentBaseMrp) {
    if (priceMode == VariantPriceMode.override) {
      if (price == null || price! <= 0) {
        throw ArgumentError('Override selling price must be greater than zero.');
      }
      final effectiveMrp = mrp ?? parentBaseMrp;
      if (effectiveMrp > 0 && price! > effectiveMrp) {
        throw ArgumentError('Selling price (₹$price) cannot exceed MRP (₹$effectiveMrp).');
      }
    }
  }

  factory ProductVariantEntity.fromMap(Map<String, dynamic> map, String id, {required String productId, required String shopId}) {
    DateTime? created;
    DateTime? updated;
    final rawCreated = map['createdAt'];
    if (rawCreated is Timestamp) created = rawCreated.toDate();
    if (rawCreated is String) created = DateTime.tryParse(rawCreated);
    final rawUpdated = map['updatedAt'];
    if (rawUpdated is Timestamp) updated = rawUpdated.toDate();
    if (rawUpdated is String) updated = DateTime.tryParse(rawUpdated);

    final rawOptions = map['selectedOptions'];
    final Map<String, String> parsedOptions = {};
    if (rawOptions is Map) {
      rawOptions.forEach((k, v) => parsedOptions[k.toString()] = v.toString());
    }

    final rawImages = (map['images'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [];
    final thumb = (map['thumbnailUrl'] as String?) ?? (rawImages.isNotEmpty ? rawImages.first : '');

    final qty = (map['stockQuantity'] as num?)?.toInt() ?? 0;
    final pMode = VariantPriceMode.fromString(map['priceMode']?.toString());

    return ProductVariantEntity(
      id: id,
      productId: productId,
      shopId: shopId,
      title: (map['title'] ?? '').toString(),
      sku: (map['sku'] ?? '').toString(),
      barcode: map['barcode']?.toString(),
      selectedOptions: parsedOptions,
      priceMode: pMode,
      price: (map['price'] as num?)?.toDouble(),
      mrp: (map['mrp'] as num?)?.toDouble(),
      stockQuantity: qty,
      lowStockThreshold: (map['lowStockThreshold'] as num?)?.toInt() ?? 5,
      inStock: (map['inStock'] as bool?) ?? (qty > 0),
      trackInventory: (map['trackInventory'] as bool?) ?? true,
      images: rawImages,
      thumbnailUrl: thumb,
      weightGrams: (map['weightGrams'] as num?)?.toInt(),
      dimensions: map['dimensions'] is Map ? Map<String, num>.from(map['dimensions'] as Map) : null,
      baseUnitsPerOption: (map['baseUnitsPerOption'] as num?)?.toInt(),
      stockType: map['stockType']?.toString(),
      isActive: (map['isActive'] as bool?) ?? true,
      createdAt: created,
      updatedAt: updated,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'shopId': shopId,
      'title': title,
      'sku': sku,
      if (barcode != null) 'barcode': barcode,
      'selectedOptions': selectedOptions,
      'priceMode': priceMode.asString,
      if (price != null) 'price': price,
      if (mrp != null) 'mrp': mrp,
      'stockQuantity': stockQuantity,
      'lowStockThreshold': lowStockThreshold,
      'inStock': inStock,
      'trackInventory': trackInventory,
      'images': images,
      'thumbnailUrl': thumbnailUrl,
      if (weightGrams != null) 'weightGrams': weightGrams,
      if (dimensions != null) 'dimensions': dimensions,
      if (baseUnitsPerOption != null) 'baseUnitsPerOption': baseUnitsPerOption,
      if (stockType != null) 'stockType': stockType,
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  ProductVariantEntity copyWith({
    String? id,
    String? productId,
    String? shopId,
    String? title,
    String? sku,
    String? barcode,
    Map<String, String>? selectedOptions,
    VariantPriceMode? priceMode,
    double? price,
    double? mrp,
    int? stockQuantity,
    int? lowStockThreshold,
    bool? inStock,
    bool? trackInventory,
    List<String>? images,
    String? thumbnailUrl,
    int? weightGrams,
    Map<String, num>? dimensions,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductVariantEntity(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      shopId: shopId ?? this.shopId,
      title: title ?? this.title,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      selectedOptions: selectedOptions ?? this.selectedOptions,
      priceMode: priceMode ?? this.priceMode,
      price: price ?? this.price,
      mrp: mrp ?? this.mrp,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      inStock: inStock ?? this.inStock,
      trackInventory: trackInventory ?? this.trackInventory,
      images: images ?? this.images,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      weightGrams: weightGrams ?? this.weightGrams,
      dimensions: dimensions ?? this.dimensions,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        productId,
        shopId,
        title,
        sku,
        priceMode,
        price,
        mrp,
        stockQuantity,
        lowStockThreshold,
        inStock,
        isActive,
      ];
}

