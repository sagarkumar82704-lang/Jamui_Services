import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class ProfessionalOrderItem extends Equatable {
  final String productId;
  final String title;
  final String unit;
  final String thumbnailUrl;
  final double price;
  final int quantity;
  final double total;

  const ProfessionalOrderItem({
    required this.productId,
    required this.title,
    required this.unit,
    this.thumbnailUrl = '',
    required this.price,
    required this.quantity,
    required this.total,
  });

  factory ProfessionalOrderItem.fromMap(Map<String, dynamic> map) {
    final pr = (map['price'] as num?)?.toDouble() ?? (map['pricePerUnit'] as num?)?.toDouble() ?? 0.0;
    final qty = (map['quantity'] as num?)?.toInt() ?? 1;
    return ProfessionalOrderItem(
      productId: (map['productId'] as String?) ?? '',
      title: (map['title'] as String?) ?? (map['titleEnglish'] as String?) ?? (map['name'] as String?) ?? '',
      unit: (map['unit'] as String?) ?? '',
      thumbnailUrl: (map['thumbnailUrl'] as String?) ?? '',
      price: pr,
      quantity: qty,
      total: (map['total'] as num?)?.toDouble() ?? (map['itemTotal'] as num?)?.toDouble() ?? (pr * qty),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'title': title,
      'unit': unit,
      'thumbnailUrl': thumbnailUrl,
      'price': price,
      'quantity': quantity,
      'total': total,
    };
  }

  @override
  List<Object?> get props => [productId, title, price, quantity, total];
}

class ProfessionalOrderEntity extends Equatable {
  final String orderId;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String shopId;
  final String shopName;
  final String shopPhone;
  final String fulfillmentType; // 'delivery' | 'pickup'
  final Map<String, dynamic>? deliveryAddress;
  final String customerNotes;
  final List<ProfessionalOrderItem> items;
  final double subtotal;
  final double deliveryCharge;
  final double discountAmount;
  final double totalAmount;
  final String paymentMode; // 'cod' | 'razorpay'
  final String paymentStatus; // 'pending' | 'completed' | 'failed'
  final String status; // 'placed', 'accepted', 'preparing', 'out_for_delivery', 'ready_for_pickup', 'delivered', 'collected', 'cancelled', 'rejected'
  final DateTime createdAt;
  final String? rejectionReason;
  final String? deliveryOtp;

  const ProfessionalOrderEntity({
    required this.orderId,
    required this.customerId,
    this.customerName = '',
    this.customerPhone = '',
    required this.shopId,
    required this.shopName,
    this.shopPhone = '',
    this.fulfillmentType = 'delivery',
    this.deliveryAddress,
    this.customerNotes = '',
    this.items = const [],
    required this.subtotal,
    this.deliveryCharge = 0.0,
    this.discountAmount = 0.0,
    required this.totalAmount,
    this.paymentMode = 'cod',
    this.paymentStatus = 'pending',
    this.status = 'placed',
    required this.createdAt,
    this.rejectionReason,
    this.deliveryOtp,
  });

  factory ProfessionalOrderEntity.fromMap(Map<String, dynamic> map, String id) {
    DateTime created = DateTime.now();
    final rawDate = map['createdAt'];
    if (rawDate is Timestamp) {
      created = rawDate.toDate();
    } else if (rawDate is String) {
      created = DateTime.tryParse(rawDate) ?? DateTime.now();
    }

    final rawItems = (map['items'] as List<dynamic>?)
            ?.map((e) => ProfessionalOrderItem.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        [];

    return ProfessionalOrderEntity(
      orderId: (map['orderId'] as String?) ?? (map['orderNumber'] as String?) ?? id,
      customerId: (map['customerId'] as String?) ?? '',
      customerName: (map['customerName'] as String?) ?? '',
      customerPhone: (map['customerPhone'] as String?) ?? '',
      shopId: (map['shopId'] as String?) ?? '',
      shopName: (map['shopName'] as String?) ?? 'Professional Shop',
      shopPhone: (map['shopPhone'] as String?) ?? '',
      fulfillmentType: (map['fulfillmentType'] as String?) ?? (map['deliveryMethod'] as String?) ?? 'delivery',
      deliveryAddress: map['deliveryAddress'] != null ? Map<String, dynamic>.from(map['deliveryAddress'] as Map) : null,
      customerNotes: (map['customerNotes'] as String?) ?? '',
      items: rawItems,
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      deliveryCharge: (map['deliveryCharge'] as num?)?.toDouble() ?? (map['deliveryFee'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (map['discountAmount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      paymentMode: (map['paymentMode'] as String?) ?? 'cod',
      paymentStatus: (map['paymentStatus'] as String?) ?? 'pending',
      status: (map['status'] as String?) ?? 'placed',
      createdAt: created,
      rejectionReason: map['rejectionReason'] as String?,
      deliveryOtp: map['deliveryOtp'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'shopId': shopId,
      'shopName': shopName,
      'shopPhone': shopPhone,
      'fulfillmentType': fulfillmentType,
      'deliveryAddress': deliveryAddress,
      'customerNotes': customerNotes,
      'items': items.map((e) => e.toMap()).toList(),
      'subtotal': subtotal,
      'deliveryCharge': deliveryCharge,
      'discountAmount': discountAmount,
      'totalAmount': totalAmount,
      'paymentMode': paymentMode,
      'paymentStatus': paymentStatus,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'rejectionReason': rejectionReason,
      'deliveryOtp': deliveryOtp,
    };
  }

  @override
  List<Object?> get props => [orderId, customerId, shopId, status, totalAmount];
}

