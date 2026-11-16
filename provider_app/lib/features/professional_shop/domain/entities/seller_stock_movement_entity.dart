import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Represents a single immutable stock movement event in the vendor's stock ledger.
class SellerStockMovementEntity extends Equatable {
  final String id;
  final String shopId;
  final String productId;
  final String productName;
  final int changeAmount; // e.g. +10, -2
  final int previousStock;
  final int newStock;
  final String movementType; // 'initial', 'manual_inward', 'manual_outward', 'manual_set', 'order_deduction', 'order_restoration'
  final String? orderId;
  final String? orderNumber;
  final String reason;
  final String actorRole; // 'shopkeeper', 'customer', 'admin'
  final DateTime createdAt;

  const SellerStockMovementEntity({
    required this.id,
    required this.shopId,
    required this.productId,
    required this.productName,
    required this.changeAmount,
    required this.previousStock,
    required this.newStock,
    required this.movementType,
    this.orderId,
    this.orderNumber,
    required this.reason,
    required this.actorRole,
    required this.createdAt,
  });

  bool get isInward => changeAmount > 0;
  bool get isOutward => changeAmount < 0;

  String get formattedChange => changeAmount > 0 ? '+$changeAmount' : '$changeAmount';

  String get movementTypeDisplayHindi {
    switch (movementType) {
      case 'initial':
        return 'प्रारंभिक स्टॉक (Initial Stock)';
      case 'manual_inward':
        return 'नया स्टॉक जोड़ा (Stock Inward)';
      case 'manual_outward':
        return 'स्टॉक घटाया (Stock Outward)';
      case 'manual_set':
        return 'स्टॉक सेट किया (Stock Set)';
      case 'order_deduction':
        return 'ऑर्डर बिक्री (Order Sale)';
      case 'order_restoration':
        return 'ऑर्डर रद्दीकरण वापसी (Restored)';
      default:
        return 'स्टॉक समायोजन (Adjustment)';
    }
  }

  factory SellerStockMovementEntity.fromMap(Map<String, dynamic> map, String docId, {required String shopId}) {
    DateTime parsedDate = DateTime.now();
    final rawDate = map['createdAt'];
    if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate();
    } else if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    }

    return SellerStockMovementEntity(
      id: docId,
      shopId: shopId,
      productId: (map['productId'] ?? '').toString(),
      productName: (map['productName'] ?? 'Product').toString(),
      changeAmount: (map['changeAmount'] as num?)?.toInt() ?? 0,
      previousStock: (map['previousStock'] as num?)?.toInt() ?? 0,
      newStock: (map['newStock'] as num?)?.toInt() ?? 0,
      movementType: (map['movementType'] ?? 'adjustment').toString(),
      orderId: map['orderId']?.toString(),
      orderNumber: map['orderNumber']?.toString(),
      reason: (map['reason'] ?? '').toString(),
      actorRole: (map['actorRole'] ?? 'shopkeeper').toString(),
      createdAt: parsedDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shopId': shopId,
      'productId': productId,
      'productName': productName,
      'changeAmount': changeAmount,
      'previousStock': previousStock,
      'newStock': newStock,
      'movementType': movementType,
      if (orderId != null) 'orderId': orderId,
      if (orderNumber != null) 'orderNumber': orderNumber,
      'reason': reason,
      'actorRole': actorRole,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        shopId,
        productId,
        productName,
        changeAmount,
        previousStock,
        newStock,
        movementType,
        orderId,
        orderNumber,
        reason,
        actorRole,
        createdAt,
      ];
}

