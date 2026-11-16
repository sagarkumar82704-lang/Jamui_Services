import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class ProfessionalOrderItem extends Equatable {
  final String productId;
  final String? variantId;
  final String? variantTitle;
  final String title;
  final String unit;
  final String thumbnailUrl;
  final double price;
  final int quantity;
  final double total;

  const ProfessionalOrderItem({
    required this.productId,
    this.variantId,
    this.variantTitle,
    required this.title,
    required this.unit,
    this.thumbnailUrl = '',
    required this.price,
    required this.quantity,
    required this.total,
  });

  /// Whether this line item has a selected variant.
  bool get hasVariant => variantTitle != null && variantTitle!.trim().isNotEmpty;

  /// Returns clean title with variant if present (e.g. "Tata Tea Gold (500g)").
  String get displayTitle {
    if (hasVariant) {
      return '$title (${variantTitle!.trim()})';
    }
    return title;
  }

  /// Returns clean display label with unit suffix when appropriate,
  /// avoiding redundant duplication if the unit is already part of the variant title.
  String get displayTitleWithUnit {
    if (hasVariant) {
      final cleanV = variantTitle!.trim();
      final cleanU = unit.trim();
      if (cleanU.isNotEmpty && !cleanV.toLowerCase().contains(cleanU.toLowerCase())) {
        return '$title ($cleanV, $cleanU)';
      }
      return '$title ($cleanV)';
    }
    if (unit.trim().isNotEmpty) {
      return '$title (${unit.trim()})';
    }
    return title;
  }

  /// Formats monetary amount cleanly:
  /// 49 -> ₹49, 49.50 -> ₹49.50, 100.00 -> ₹100
  static String formatCurrency(num value, {String prefix = '₹'}) {
    final d = value.toDouble();
    if (d == d.roundToDouble()) {
      return '$prefix${d.toInt()}';
    }
    return '$prefix${d.toStringAsFixed(2)}';
  }

  factory ProfessionalOrderItem.fromMap(Map<String, dynamic> map) {
    final pr = (map['price'] as num?)?.toDouble() ?? (map['pricePerUnit'] as num?)?.toDouble() ?? 0.0;
    final rawQty = map['quantity'];
    final parsedQty = (rawQty is num)
        ? rawQty.toInt()
        : (int.tryParse(rawQty?.toString() ?? '') ?? 1);
    final qty = parsedQty > 0 ? parsedQty : 1;
    return ProfessionalOrderItem(
      productId: (map['productId'] as String?) ?? '',
      variantId: map['variantId'] as String?,
      variantTitle: map['variantTitle'] as String?,
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
      if (variantId != null) 'variantId': variantId,
      if (variantTitle != null) 'variantTitle': variantTitle,
      'title': title,
      'unit': unit,
      'thumbnailUrl': thumbnailUrl,
      'price': price,
      'quantity': quantity,
      'total': total,
    };
  }

  @override
  List<Object?> get props => [productId, variantId, title, price, quantity, total];
}

class ProfessionalOrderEntity extends Equatable {
  final String orderId; // Internal Firestore Document ID (Primary Key for streams, status, database)
  final String orderNumber; // Public Platform Online Order ID (e.g. JS-284731)
  final String? sellerOrderNumber; // Shop-scoped Seller Order Number (e.g. SGJ-019)
  final String channelId; // Channel ID (e.g. JAMUI_SERVICES)
  final String? sellerToken; // Optional Packing / Pickup Token (null for now)
  final String? invoiceNumber; // Optional Legal Invoice Number (null for now)
  final String? shopCode; // Permanent Seller Shop Code (e.g. SGJ)
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
  final String? idempotencyKey;

  const ProfessionalOrderEntity({
    required this.orderId,
    String? orderNumber,
    this.sellerOrderNumber,
    this.channelId = 'JAMUI_SERVICES',
    this.sellerToken,
    this.invoiceNumber,
    this.shopCode,
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
    this.idempotencyKey,
  }) : orderNumber = orderNumber ?? orderId;

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

    final effectiveOrderId = id.isNotEmpty ? id : ((map['id'] as String?) ?? (map['orderId'] as String?) ?? '');
    final effectiveOrderNumber = (map['orderNumber'] as String?) ?? (map['orderId'] as String?) ?? effectiveOrderId;

    return ProfessionalOrderEntity(
      orderId: effectiveOrderId,
      orderNumber: effectiveOrderNumber,
      sellerOrderNumber: map['sellerOrderNumber'] as String?,
      channelId: (map['channelId'] as String?) ?? 'JAMUI_SERVICES',
      sellerToken: map['sellerToken'] as String?,
      invoiceNumber: map['invoiceNumber'] as String?,
      shopCode: map['shopCode'] as String?,
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
      idempotencyKey: map['idempotencyKey'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'id': orderId,
      'orderNumber': orderNumber,
      if (sellerOrderNumber != null) 'sellerOrderNumber': sellerOrderNumber,
      'channelId': channelId,
      if (sellerToken != null) 'sellerToken': sellerToken,
      if (invoiceNumber != null) 'invoiceNumber': invoiceNumber,
      if (shopCode != null) 'shopCode': shopCode,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'shopId': shopId,
      'shopName': shopName,
      'shopPhone': shopPhone,
      'fulfillmentType': fulfillmentType,
      'deliveryMethod': fulfillmentType,
      if (deliveryAddress != null) 'deliveryAddress': deliveryAddress,
      'customerNotes': customerNotes,
      'items': items.map((e) => e.toMap()).toList(),
      'subtotal': subtotal,
      'deliveryCharge': deliveryCharge,
      'deliveryFee': deliveryCharge,
      'discountAmount': discountAmount,
      'totalAmount': totalAmount,
      'paymentMode': paymentMode,
      'paymentStatus': paymentStatus,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'rejectionReason': rejectionReason,
      'deliveryOtp': deliveryOtp,
      if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
    };
  }

  ProfessionalOrderEntity copyWith({
    String? orderId,
    String? orderNumber,
    String? sellerOrderNumber,
    String? channelId,
    String? sellerToken,
    String? invoiceNumber,
    String? shopCode,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? shopId,
    String? shopName,
    String? shopPhone,
    String? fulfillmentType,
    Map<String, dynamic>? deliveryAddress,
    String? customerNotes,
    List<ProfessionalOrderItem>? items,
    double? subtotal,
    double? deliveryCharge,
    double? discountAmount,
    double? totalAmount,
    String? paymentMode,
    String? paymentStatus,
    String? status,
    DateTime? createdAt,
    String? rejectionReason,
    String? deliveryOtp,
    String? idempotencyKey,
  }) {
    return ProfessionalOrderEntity(
      orderId: orderId ?? this.orderId,
      orderNumber: orderNumber ?? this.orderNumber,
      sellerOrderNumber: sellerOrderNumber ?? this.sellerOrderNumber,
      channelId: channelId ?? this.channelId,
      sellerToken: sellerToken ?? this.sellerToken,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      shopCode: shopCode ?? this.shopCode,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      shopId: shopId ?? this.shopId,
      shopName: shopName ?? this.shopName,
      shopPhone: shopPhone ?? this.shopPhone,
      fulfillmentType: fulfillmentType ?? this.fulfillmentType,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      customerNotes: customerNotes ?? this.customerNotes,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      deliveryCharge: deliveryCharge ?? this.deliveryCharge,
      discountAmount: discountAmount ?? this.discountAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentMode: paymentMode ?? this.paymentMode,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      deliveryOtp: deliveryOtp ?? this.deliveryOtp,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    );
  }

  @override
  List<Object?> get props => [
        orderId,
        orderNumber,
        sellerOrderNumber,
        channelId,
        customerId,
        shopId,
        status,
        totalAmount,
        createdAt,
        idempotencyKey,
      ];
}

