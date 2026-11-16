import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Confidential vendor-only product pricing entity.
/// Strictly stored in `diamond_shops/{shopId}/products/{productId}/private_pricing/cost_data`
/// and protected by Firestore Security Rules to be 100% inaccessible to public customers.
class PrivateProductPricingEntity extends Equatable {
  final String productId;
  final double costPrice; // Purchase price paid by vendor
  final double sellingPrice; // Final selling price
  final double regularPrice; // MRP
  final String? supplierName;
  final String? purchaseNotes;
  final DateTime? updatedAt;

  const PrivateProductPricingEntity({
    required this.productId,
    required this.costPrice,
    required this.sellingPrice,
    required this.regularPrice,
    this.supplierName,
    this.purchaseNotes,
    this.updatedAt,
  });

  /// Profit Margin in Rupees: `sellingPrice - costPrice`
  double get profitMarginRupees => (sellingPrice > costPrice && costPrice > 0)
      ? (sellingPrice - costPrice)
      : 0.0;

  /// Profit Margin Percentage: `(profitMargin / sellingPrice) * 100`
  double get profitMarginPercentage => (sellingPrice > 0 && profitMarginRupees > 0)
      ? ((profitMarginRupees / sellingPrice) * 100)
      : 0.0;

  /// Markup Percentage: `(profitMargin / costPrice) * 100`
  double get markupPercentage => (costPrice > 0 && profitMarginRupees > 0)
      ? ((profitMarginRupees / costPrice) * 100)
      : 0.0;

  factory PrivateProductPricingEntity.fromMap(Map<String, dynamic> map, String productId) {
    DateTime? updated;
    final rawDate = map['updatedAt'];
    if (rawDate is Timestamp) {
      updated = rawDate.toDate();
    } else if (rawDate is String) {
      updated = DateTime.tryParse(rawDate);
    }

    return PrivateProductPricingEntity(
      productId: productId,
      costPrice: (map['costPrice'] as num?)?.toDouble() ?? 0.0,
      sellingPrice: (map['sellingPrice'] as num?)?.toDouble() ?? 0.0,
      regularPrice: (map['regularPrice'] as num?)?.toDouble() ?? 0.0,
      supplierName: map['supplierName']?.toString(),
      purchaseNotes: map['purchaseNotes']?.toString(),
      updatedAt: updated,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'costPrice': costPrice,
      'sellingPrice': sellingPrice,
      'regularPrice': regularPrice,
      'profitMarginRupees': profitMarginRupees,
      'profitMarginPercentage': profitMarginPercentage,
      if (supplierName != null && supplierName!.isNotEmpty) 'supplierName': supplierName,
      if (purchaseNotes != null && purchaseNotes!.isNotEmpty) 'purchaseNotes': purchaseNotes,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  @override
  List<Object?> get props => [
        productId,
        costPrice,
        sellingPrice,
        regularPrice,
        supplierName,
        purchaseNotes,
        updatedAt,
      ];
}

