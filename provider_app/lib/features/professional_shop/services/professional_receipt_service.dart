import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'professional_receipt_platform_stub.dart'
    if (dart.library.js_interop) 'professional_receipt_platform_web.dart'
    if (dart.library.io) 'professional_receipt_platform_io.dart';

export 'professional_receipt_platform_stub.dart' show ReceiptActionResult, ReceiptActionStatus;

/// Represents a single line item on a Professional Marketplace Order Receipt.
class ProfessionalReceiptItem {
  final String productId;
  final String title;
  final String? variantTitle;
  final String? sku;
  final String unit;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final bool isRecovered;
  final String? recoveredCatalogTitle;

  const ProfessionalReceiptItem({
    required this.productId,
    required this.title,
    this.variantTitle,
    this.sku,
    this.unit = '',
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.isRecovered = false,
    this.recoveredCatalogTitle,
  });

  /// Whether this line item has a selected variant.
  bool get hasVariant => variantTitle != null && variantTitle!.trim().isNotEmpty;

  /// Effective display name for UI presentation.
  String get effectiveTitle {
    if (isRecovered) {
      if (recoveredCatalogTitle != null && recoveredCatalogTitle!.trim().isNotEmpty) {
        return '${recoveredCatalogTitle!.trim()} [कैटलॉग]';
      }
      return 'उत्पाद का नाम उपलब्ध नहीं';
    }
    return title;
  }

  /// Effective title for standard Type1 ASCII PDF rendering.
  String get effectivePdfTitle {
    if (isRecovered) {
      if (recoveredCatalogTitle != null && recoveredCatalogTitle!.trim().isNotEmpty) {
        return '${recoveredCatalogTitle!.trim()} [Catalog]';
      }
      return 'Product Name Unavailable';
    }
    return title;
  }

  /// Returns clean product title with variant if present (e.g. "Tata Tea Gold (500g)").
  String get displayTitle {
    final t = effectiveTitle;
    if (hasVariant) {
      return '$t (${variantTitle!.trim()})';
    }
    return t;
  }

  /// Returns clean display label with unit suffix when appropriate,
  /// avoiding redundant duplication if the unit is already part of the variant title.
  String get displayTitleWithUnit {
    final t = effectiveTitle;
    if (hasVariant) {
      final cleanV = variantTitle!.trim();
      final cleanU = unit.trim();
      if (cleanU.isNotEmpty && !cleanV.toLowerCase().contains(cleanU.toLowerCase())) {
        return '$t ($cleanV, $cleanU)';
      }
      return '$t ($cleanV)';
    }
    if (unit.trim().isNotEmpty) {
      return '$t (${unit.trim()})';
    }
    return t;
  }

  /// PDF-safe label for Type1 font output.
  String get displayPdfTitleWithUnit {
    final t = effectivePdfTitle;
    if (hasVariant) {
      final cleanV = variantTitle!.trim();
      final cleanU = unit.trim();
      if (cleanU.isNotEmpty && !cleanV.toLowerCase().contains(cleanU.toLowerCase())) {
        return '$t ($cleanV, $cleanU)';
      }
      return '$t ($cleanV)';
    }
    if (unit.trim().isNotEmpty) {
      return '$t (${unit.trim()})';
    }
    return t;
  }

  factory ProfessionalReceiptItem.fromMap(Map<String, dynamic> map) {
    final price = (map['price'] as num?)?.toDouble() ??
        (map['pricePerUnit'] as num?)?.toDouble() ??
        (map['sellingPrice'] as num?)?.toDouble() ??
        0.0;

    // Safe quantity parsing: supports num, String, and defaults safely
    final rawQty = map['quantity'];
    final parsedQty = (rawQty is num)
        ? rawQty.toInt()
        : (int.tryParse(rawQty?.toString() ?? '') ?? 1);
    final qty = parsedQty > 0 ? parsedQty : 1;

    final total = (map['total'] as num?)?.toDouble() ??
        (map['itemTotal'] as num?)?.toDouble() ??
        (price * qty);

    final rawTitle = (map['title'] as String?) ??
        (map['productTitle'] as String?) ??
        (map['titleEnglish'] as String?) ??
        (map['name'] as String?) ??
        'Item';

    final rawVariantTitle = (map['variantTitle'] as String?)?.trim();
    final rawSku = (map['sku'] as String?)?.trim();
    final rawIsRecovered = map['isRecovered'] == true;
    final recoveredCatalogTitle = (map['recoveredCatalogTitle'] as String?)?.trim();

    return ProfessionalReceiptItem(
      productId: (map['productId'] as String?) ?? '',
      title: rawTitle.trim().isNotEmpty ? rawTitle.trim() : 'Item',
      variantTitle: (rawVariantTitle != null && rawVariantTitle.isNotEmpty) ? rawVariantTitle : null,
      sku: (rawSku != null && rawSku.isNotEmpty) ? rawSku : null,
      unit: ((map['unit'] as String?) ?? '').trim(),
      quantity: qty,
      unitPrice: price,
      totalPrice: total,
      isRecovered: rawIsRecovered || (recoveredCatalogTitle != null && recoveredCatalogTitle.isNotEmpty),
      recoveredCatalogTitle: recoveredCatalogTitle,
    );
  }
}

/// Verified, immutable order receipt data model.
///
/// Strictly preserves internal Firestore `orderId` separate from public `orderNumber`.
/// Never fabricates customer details, phone numbers, discounts, or taxes.
class ProfessionalReceiptData {
  final String orderId;
  final String orderNumber;
  final String? sellerOrderNumber;
  final String channelId;
  final String shopId;
  final String ownerUid;
  final String shopName;
  final String shopPhone;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String? customerCountryCode;
  final String fulfillmentType;
  final String deliveryAddressText;
  final String customerNotes;
  final List<ProfessionalReceiptItem> items;
  final double subtotal;
  final double deliveryCharge;
  final double discountAmount;
  final double totalAmount;
  final String paymentMode;
  final String paymentStatus;
  final String status;
  final DateTime createdAt;

  const ProfessionalReceiptData({
    required this.orderId,
    required this.orderNumber,
    this.sellerOrderNumber,
    this.channelId = 'JAMUI_SERVICES',
    required this.shopId,
    this.ownerUid = '',
    required this.shopName,
    this.shopPhone = '',
    required this.customerId,
    this.customerName = '',
    this.customerPhone = '',
    this.customerCountryCode,
    this.fulfillmentType = 'delivery',
    this.deliveryAddressText = '',
    this.customerNotes = '',
    required this.items,
    required this.subtotal,
    this.deliveryCharge = 0.0,
    this.discountAmount = 0.0,
    required this.totalAmount,
    this.paymentMode = '',
    this.paymentStatus = '',
    this.status = 'placed',
    required this.createdAt,
  });

  factory ProfessionalReceiptData.fromMap(
    Map<String, dynamic> map, {
    String? docId,
    Map<String, String?>? catalogTitles,
  }) {
    DateTime created = DateTime.now();
    final rawCreated = map['createdAt'];
    if (rawCreated is Timestamp) {
      created = rawCreated.toDate();
    } else if (rawCreated is DateTime) {
      created = rawCreated;
    } else if (rawCreated is String) {
      created = DateTime.tryParse(rawCreated) ?? DateTime.now();
    } else if (rawCreated is int) {
      created = DateTime.fromMillisecondsSinceEpoch(rawCreated);
    }

    final effectiveDocId = (docId != null && docId.trim().isNotEmpty)
        ? docId.trim()
        : ((map['id'] as String?)?.trim().isNotEmpty == true
            ? (map['id'] as String).trim()
            : ((map['orderId'] as String?)?.trim() ?? ''));

    final rawOrderNum = (map['orderNumber'] as String?)?.trim();
    final effectiveOrderNumber = (rawOrderNum != null && rawOrderNum.isNotEmpty)
        ? rawOrderNum
        : ((map['orderId'] as String?)?.trim().isNotEmpty == true
            ? (map['orderId'] as String).trim()
            : effectiveDocId);

    final rawSellerOrderNum = (map['sellerOrderNumber'] as String?)?.trim();
    final sellerOrderNumber =
        (rawSellerOrderNum != null && rawSellerOrderNum.isNotEmpty) ? rawSellerOrderNum : null;

    final rawChannel = (map['channelId'] as String?)?.trim();
    final channelId = (rawChannel != null && rawChannel.isNotEmpty) ? rawChannel : 'JAMUI_SERVICES';

    final addressMap = map['deliveryAddress'] is Map
        ? Map<String, dynamic>.from(map['deliveryAddress'] as Map)
        : null;

    // Strictly read customerPhone from this exact order's customer fields only (NEVER fallback to shopPhone)
    String custPhone = ((map['customerPhone'] as String?) ?? '').trim();
    if (custPhone.isEmpty && addressMap != null) {
      custPhone = ((addressMap['contactPhone'] as String?) ??
              (addressMap['customerPhone'] as String?) ??
              '')
          .trim();
    }

    String? countryCode = (map['customerCountryCode'] as String?)?.trim() ??
        (map['countryCode'] as String?)?.trim();
    if ((countryCode == null || countryCode.isEmpty) && addressMap != null) {
      countryCode = (addressMap['countryCode'] as String?)?.trim() ??
          (addressMap['dialCode'] as String?)?.trim() ??
          (addressMap['country'] as String?)?.trim();
    }

    String formattedAddress = '';
    if (addressMap != null) {
      final baseAddr = ((addressMap['fullAddress'] as String?) ??
              (addressMap['address'] as String?) ??
              '')
          .trim();
      final landmark = ((addressMap['landmark'] as String?) ?? '').trim();
      final pincode = ((addressMap['pincode'] as String?) ?? '').trim();
      final parts = <String>[
        if (baseAddr.isNotEmpty) baseAddr,
        if (landmark.isNotEmpty) 'Near $landmark',
        if (pincode.isNotEmpty) pincode,
      ];
      formattedAddress = parts.join(', ');
    }

    final rawItems = (map['items'] as List<dynamic>?)
            ?.whereType<Map>()
            .map((e) {
              final itemMap = Map<String, dynamic>.from(e);
              final pId = (itemMap['productId'] as String?)?.trim() ?? '';
              if (catalogTitles != null && catalogTitles.containsKey(pId)) {
                itemMap['recoveredCatalogTitle'] = catalogTitles[pId];
                itemMap['isRecovered'] = true;
              }
              return ProfessionalReceiptItem.fromMap(itemMap);
            })
            .toList() ??
        const <ProfessionalReceiptItem>[];

    final computedItemsTotal = rawItems.fold<double>(0.0, (acc, item) => acc + item.totalPrice);
    final subtotal = (map['subtotal'] as num?)?.toDouble() ?? computedItemsTotal;
    final deliveryCharge = (map['deliveryCharge'] as num?)?.toDouble() ??
        (map['deliveryFee'] as num?)?.toDouble() ??
        0.0;
    final discountAmount = (map['discountAmount'] as num?)?.toDouble() ?? 0.0;
    final totalAmount = (map['totalAmount'] as num?)?.toDouble() ??
        (subtotal + deliveryCharge - discountAmount);

    final rawPaymentMode = ((map['paymentMode'] as String?) ??
            (map['paymentMethod'] as String?) ??
            '')
        .trim();

    return ProfessionalReceiptData(
      orderId: effectiveDocId,
      orderNumber: effectiveOrderNumber,
      sellerOrderNumber: sellerOrderNumber,
      channelId: channelId,
      shopId: ((map['shopId'] as String?) ?? '').trim(),
      ownerUid: ((map['ownerUid'] as String?) ?? '').trim(),
      shopName: ((map['shopName'] as String?) ?? '').trim(),
      shopPhone: ((map['shopPhone'] as String?) ?? '').trim(),
      customerId: ((map['customerId'] as String?) ?? '').trim(),
      customerName: ((map['customerName'] as String?) ?? '').trim(),
      customerPhone: custPhone,
      customerCountryCode: (countryCode != null && countryCode.isNotEmpty) ? countryCode : null,
      fulfillmentType: ((map['fulfillmentType'] as String?) ??
              (map['deliveryMethod'] as String?) ??
              'delivery')
          .trim(),
      deliveryAddressText: formattedAddress,
      customerNotes: ((map['customerNotes'] as String?) ?? '').trim(),
      items: rawItems,
      subtotal: subtotal,
      deliveryCharge: deliveryCharge,
      discountAmount: discountAmount,
      totalAmount: totalAmount,
      paymentMode: rawPaymentMode,
      paymentStatus: ((map['paymentStatus'] as String?) ?? '').trim(),
      status: ((map['status'] as String?) ?? 'placed').trim(),
      createdAt: created,
    );
  }
}

/// Validates and normalizes customer phone numbers to international E.164 format.
class ValidatedCustomerPhone {
  final bool isValid;
  final String? e164Phone; // e.g. "+919876543210"
  final String? waMePhone; // e.g. "919876543210"
  final String? errorReason;

  const ValidatedCustomerPhone._({
    required this.isValid,
    this.e164Phone,
    this.waMePhone,
    this.errorReason,
  });

  factory ValidatedCustomerPhone.valid(String e164) {
    final digits = e164.replaceAll(RegExp(r'[^0-9]'), '');
    return ValidatedCustomerPhone._(
      isValid: true,
      e164Phone: '+$digits',
      waMePhone: digits,
    );
  }

  factory ValidatedCustomerPhone.invalid(String reason) {
    return ValidatedCustomerPhone._(
      isValid: false,
      errorReason: reason,
    );
  }
}

class ProfessionalReceiptPhoneValidator {
  static const Map<String, String> _isoToDialCode = <String, String>{
    'IN': '91',
    'IND': '91',
    'INDIA': '91',
    'US': '1',
    'USA': '1',
    'CA': '1',
    'GB': '44',
    'UK': '44',
    'AE': '971',
    'UAE': '971',
    'NP': '977',
    'BD': '880',
    'AU': '61',
    'SG': '65',
    'MY': '60',
    'SA': '966',
    'QA': '974',
    'OM': '968',
    'KW': '965',
  };

  /// Validates and normalizes an order's customer phone number to E.164 format.
  ///
  /// Never uses the seller's phone number as a fallback.
  /// Respects international `+` prefixes and explicit country codes when provided.
  static ValidatedCustomerPhone validateAndNormalize(
    String? rawCustomerPhone, {
    String? countryCode,
  }) {
    final trimmed = (rawCustomerPhone ?? '').trim();
    if (trimmed.isEmpty) {
      return ValidatedCustomerPhone.invalid('Customer WhatsApp phone number is missing.');
    }

    // Reject if the string contains alphabetic characters
    if (RegExp(r'[a-zA-Z]').hasMatch(trimmed)) {
      return ValidatedCustomerPhone.invalid('Customer phone number contains invalid characters.');
    }

    // 1. Explicit '+' international E.164 prefix
    if (trimmed.startsWith('+')) {
      final digits = trimmed.substring(1).replaceAll(RegExp(r'[\s\-().]'), '');
      if (!RegExp(r'^[1-9]\d{6,14}$').hasMatch(digits)) {
        return ValidatedCustomerPhone.invalid('Invalid international phone number format.');
      }
      if (_isAllSameDigit(digits)) {
        return ValidatedCustomerPhone.invalid('Placeholder phone number is not valid.');
      }
      if (digits.startsWith('91') && digits.length == 12) {
        final subscriber = digits.substring(2);
        if (!RegExp(r'^[6-9]\d{9}$').hasMatch(subscriber)) {
          return ValidatedCustomerPhone.invalid('Invalid Indian mobile subscriber number.');
        }
      }
      return ValidatedCustomerPhone.valid('+$digits');
    }

    // 2. Explicit '00' international prefix (e.g. 00447911123456)
    final strippedFormatting = trimmed.replaceAll(RegExp(r'[\s\-().]'), '');
    if (strippedFormatting.startsWith('00')) {
      final digits = strippedFormatting.substring(2);
      if (!RegExp(r'^[1-9]\d{6,14}$').hasMatch(digits) || _isAllSameDigit(digits)) {
        return ValidatedCustomerPhone.invalid('Invalid international phone number.');
      }
      return ValidatedCustomerPhone.valid('+$digits');
    }

    if (!RegExp(r'^\d+$').hasMatch(strippedFormatting)) {
      return ValidatedCustomerPhone.invalid('Phone number contains invalid symbols.');
    }

    // 3. Resolve dial code from countryCode metadata if available
    final resolvedDialCode = _resolveDialCode(countryCode);

    // If a non-India country code is explicitly specified
    if (resolvedDialCode != null && resolvedDialCode != '91') {
      String localDigits = strippedFormatting;
      if (localDigits.startsWith('0')) {
        localDigits = localDigits.substring(1);
      }
      final combined = localDigits.startsWith(resolvedDialCode)
          ? localDigits
          : '$resolvedDialCode$localDigits';
      if (!RegExp(r'^[1-9]\d{6,14}$').hasMatch(combined) || _isAllSameDigit(localDigits)) {
        return ValidatedCustomerPhone.invalid('Invalid phone number for country +$resolvedDialCode.');
      }
      return ValidatedCustomerPhone.valid('+$combined');
    }

    // 4. Default / India (+91) normalization
    String digits = strippedFormatting;
    if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    } else if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    }

    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digits) || _isAllSameDigit(digits)) {
      return ValidatedCustomerPhone.invalid('Valid 10-digit mobile number is required.');
    }

    return ValidatedCustomerPhone.valid('+91$digits');
  }

  static String? _resolveDialCode(String? rawCountry) {
    if (rawCountry == null || rawCountry.trim().isEmpty) return null;
    final clean = rawCountry.trim().toUpperCase();
    if (_isoToDialCode.containsKey(clean)) {
      return _isoToDialCode[clean];
    }
    final digits = clean.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isNotEmpty && digits.length <= 4) {
      return digits;
    }
    return null;
  }

  static bool _isAllSameDigit(String digits) {
    if (digits.isEmpty) return true;
    final first = digits[0];
    for (int i = 1; i < digits.length; i++) {
      if (digits[i] != first) return false;
    }
    return true;
  }

  /// Builds the dynamic Hindi pre-filled message for the customer's WhatsApp chat link.
  static String buildCustomerWhatsAppMessage({
    required String orderNumber,
    required String shopName,
  }) {
    final cleanOrderNumber = orderNumber.trim().replaceFirst(RegExp(r'^#'), '');
    final cleanShopName = shopName.trim().isNotEmpty ? shopName.trim() : 'Jamui Services Store';
    return 'नमस्ते! Jamui Services पर आपके ऑर्डर $cleanOrderNumber की रसीद तैयार है। दुकान: $cleanShopName। धन्यवाद।';
  }

  /// Builds a complete itemized WhatsApp receipt summary including variants,
  /// quantities, units, and final payable amount.
  static String buildReceiptWhatsAppSummary(ProfessionalReceiptData receipt) {
    final cleanOrderNumber = receipt.orderNumber.trim().replaceFirst(RegExp(r'^#'), '');
    final cleanShopName = receipt.shopName.trim().isNotEmpty ? receipt.shopName.trim() : 'Jamui Services Store';

    final buffer = StringBuffer();
    buffer.writeln('नमस्ते! Jamui Services पर आपके ऑर्डर $cleanOrderNumber की रसीद तैयार है।');
    buffer.writeln('दुकान: $cleanShopName');
    buffer.writeln('\nसामान की सूची:');
    for (final it in receipt.items) {
      buffer.writeln('• ${it.displayTitleWithUnit} x ${it.quantity} = Rs. ${ProfessionalReceiptService.formatAmount(it.totalPrice)}');
    }
    buffer.writeln('\nकुल राशि: Rs. ${ProfessionalReceiptService.formatAmount(receipt.totalAmount)}');
    buffer.write('धन्यवाद!');
    return buffer.toString();
  }

  /// Builds the official WhatsApp `https://wa.me/<e164>?text=...` deep link for an order.
  /// Returns null if the customer's phone number is missing or invalid.
  static Uri? buildCustomerWhatsAppUri(ProfessionalReceiptData receipt) {
    final validation = validateAndNormalize(
      receipt.customerPhone,
      countryCode: receipt.customerCountryCode,
    );
    if (!validation.isValid || validation.waMePhone == null) {
      return null;
    }
    final text = buildCustomerWhatsAppMessage(
      orderNumber: receipt.orderNumber,
      shopName: receipt.shopName,
    );
    return Uri.parse(
      'https://wa.me/${validation.waMePhone}?text=${Uri.encodeComponent(text)}',
    );
  }
}

/// Enforces seller and customer ownership rules before generating or sharing receipts.
class ProfessionalReceiptSecurityGuard {
  /// Verifies that the authenticated provider owns the shop associated with the order.
  static bool canProviderAccessReceipt({
    required ProfessionalReceiptData receipt,
    String? authenticatedShopId,
    String? authenticatedOwnerUid,
  }) {
    if (receipt.shopId.isEmpty && receipt.ownerUid.isEmpty) {
      return false;
    }
    final shopMatch = authenticatedShopId != null &&
        authenticatedShopId.trim().isNotEmpty &&
        receipt.shopId == authenticatedShopId.trim();
    final ownerMatch = authenticatedOwnerUid != null &&
        authenticatedOwnerUid.trim().isNotEmpty &&
        (receipt.ownerUid == authenticatedOwnerUid.trim() ||
            receipt.shopId == authenticatedOwnerUid.trim());
    return shopMatch || ownerMatch;
  }

  /// Verifies that the authenticated customer is the owner of the order.
  static bool canCustomerAccessReceipt({
    required ProfessionalReceiptData receipt,
    required String authenticatedCustomerUid,
  }) {
    final cleanUid = authenticatedCustomerUid.trim();
    if (cleanUid.isEmpty || receipt.customerId.isEmpty) {
      return false;
    }
    return receipt.customerId == cleanUid;
  }
}

/// Pure-Dart ISO 32000-1 PDF 1.4 generator for Professional Marketplace Order Receipts.
///
/// Produces a valid, self-contained vector PDF document using standard Type1 Helvetica fonts.
/// Zero external binary dependencies; works identically on Android, iOS, Web, and Desktop.
class ProfessionalReceiptPdfGenerator {
  static const String mandatoryNonTaxNotice =
      'Digital Order Receipt / Packing Slip — Not a Tax Invoice.';

  /// Returns a safe, standardized PDF filename such as `JamuiServices_JS-284731.pdf`.
  static String buildFileName(String orderNumber) {
    final clean = orderNumber
        .trim()
        .replaceFirst(RegExp(r'^#'), '')
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final effective = clean.isNotEmpty ? clean : 'Order';
    return 'JamuiServices_$effective.pdf';
  }

  /// Generates a complete PDF 1.4 document (`Uint8List`) from verified receipt data.
  static Uint8List generatePdfBytes(ProfessionalReceiptData receipt) {
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(receipt.createdAt);
    final channelDisplay = receipt.channelId.trim().isNotEmpty
        ? receipt.channelId.trim().replaceAll('_', ' ')
        : 'JAMUI SERVICES';
    final isDelivery = receipt.fulfillmentType.toLowerCase() == 'delivery';

    // Calculate dynamic page height so long item lists fit cleanly
    final baseHeight = 520.0;
    final itemsHeight = (receipt.items.length * 22.0);
    final pageHeight = (baseHeight + itemsHeight).clamp(560.0, 1400.0);
    const pageWidth = 420.0;

    final stream = StringBuffer();
    double y = pageHeight - 36.0;

    // 1. Top Header Banner Box (Deep Emerald #0F766E -> RGB 0.059, 0.463, 0.431)
    stream.writeln('0.059 0.463 0.431 rg');
    stream.writeln('24 ${(y - 44).toStringAsFixed(1)} ${pageWidth - 48} 54 re f');

    // Channel Badge & Title in White
    stream.writeln('1 1 1 rg');
    _writeText(stream, font: 'F2', size: 13, x: 36, y: y - 14, text: 'Channel: $channelDisplay');
    _writeText(
      stream,
      font: 'F1',
      size: 9.5,
      x: 36,
      y: y - 30,
      text: 'PROFESSIONAL ORDER RECEIPT & PACKING SLIP',
    );

    // Store Order Number Badge on right of header if present
    if (receipt.sellerOrderNumber != null && receipt.sellerOrderNumber!.trim().isNotEmpty) {
      _writeText(
        stream,
        font: 'F2',
        size: 11,
        x: pageWidth - 150,
        y: y - 22,
        text: 'Store Order: ${receipt.sellerOrderNumber!.trim()}',
      );
    }

    y -= 64;

    // 2. Store Name & Contact
    stream.writeln('0.118 0.161 0.231 rg');
    final storeTitle = receipt.shopName.isNotEmpty ? receipt.shopName : 'Professional Store';
    _writeText(stream, font: 'F2', size: 13, x: 28, y: y, text: 'Store: $storeTitle');
    y -= 15;

    if (receipt.shopPhone.isNotEmpty) {
      stream.writeln('0.392 0.455 0.545 rg');
      _writeText(stream, font: 'F1', size: 9.5, x: 28, y: y, text: 'Store Phone: ${receipt.shopPhone}');
      y -= 14;
    }

    // Divider line
    _writeDivider(stream, x1: 24, x2: pageWidth - 24, y: y);
    y -= 16;

    // 3. Order Identification & Metadata Block
    stream.writeln('0.118 0.161 0.231 rg');
    _writeText(
      stream,
      font: 'F2',
      size: 11,
      x: 28,
      y: y,
      text: 'Platform Order Number: #${receipt.orderNumber}',
    );
    y -= 15;

    if (receipt.sellerOrderNumber != null && receipt.sellerOrderNumber!.trim().isNotEmpty) {
      _writeText(
        stream,
        font: 'F2',
        size: 10.5,
        x: 28,
        y: y,
        text: 'Seller Order Number: ${receipt.sellerOrderNumber!.trim()}',
      );
      y -= 15;
    }

    stream.writeln('0.200 0.255 0.333 rg');
    _writeText(stream, font: 'F1', size: 10, x: 28, y: y, text: 'Order Date: $dateStr');
    y -= 14;

    _writeText(
      stream,
      font: 'F1',
      size: 10,
      x: 28,
      y: y,
      text: 'Fulfillment Type: ${isDelivery ? "Store Delivery" : "Store Pickup"}',
    );
    y -= 14;

    if (receipt.paymentMode.isNotEmpty) {
      _writeText(
        stream,
        font: 'F1',
        size: 10,
        x: 28,
        y: y,
        text: 'Payment Method: ${receipt.paymentMode.toUpperCase()}',
      );
      y -= 14;
    }

    // 4. Customer Details (Strictly hidden when empty — never fabricated)
    final hasCustomerName = receipt.customerName.trim().isNotEmpty;
    final hasCustomerPhone = receipt.customerPhone.trim().isNotEmpty;
    final hasAddress = isDelivery && receipt.deliveryAddressText.trim().isNotEmpty;

    if (hasCustomerName || hasCustomerPhone || hasAddress) {
      _writeDivider(stream, x1: 24, x2: pageWidth - 24, y: y);
      y -= 15;
      stream.writeln('0.118 0.161 0.231 rg');
      if (hasCustomerName) {
        _writeText(
          stream,
          font: 'F2',
          size: 10,
          x: 28,
          y: y,
          text: 'Customer: ${receipt.customerName.trim()}',
        );
        y -= 14;
      }
      if (hasCustomerPhone) {
        _writeText(
          stream,
          font: 'F1',
          size: 9.5,
          x: 28,
          y: y,
          text: 'Customer Phone: ${receipt.customerPhone.trim()}',
        );
        y -= 14;
      }
      if (hasAddress) {
        _writeText(
          stream,
          font: 'F1',
          size: 9.5,
          x: 28,
          y: y,
          text: 'Delivery Address: ${_truncate(receipt.deliveryAddressText.trim(), 68)}',
        );
        y -= 14;
      }
    }

    _writeDivider(stream, x1: 24, x2: pageWidth - 24, y: y);
    y -= 16;

    // 5. Items Table Header
    stream.writeln('0.059 0.463 0.431 rg');
    _writeText(stream, font: 'F2', size: 10, x: 28, y: y, text: 'ITEM DESCRIPTION');
    _writeText(stream, font: 'F2', size: 10, x: 245, y: y, text: 'QTY');
    _writeText(stream, font: 'F2', size: 10, x: 285, y: y, text: 'PRICE');
    _writeText(stream, font: 'F2', size: 10, x: 345, y: y, text: 'TOTAL');
    y -= 8;
    _writeDivider(stream, x1: 24, x2: pageWidth - 24, y: y);
    y -= 15;

    // 6. Items Rows
    stream.writeln('0.118 0.161 0.231 rg');
    for (final item in receipt.items) {
      final itemLabel = _truncate(item.displayPdfTitleWithUnit, 36);
      _writeText(stream, font: 'F1', size: 9.5, x: 28, y: y, text: itemLabel);
      _writeText(stream, font: 'F1', size: 9.5, x: 248, y: y, text: '${item.quantity}');
      _writeText(
        stream,
        font: 'F1',
        size: 9.5,
        x: 285,
        y: y,
        text: 'Rs. ${_formatAmount(item.unitPrice)}',
      );
      _writeText(
        stream,
        font: 'F2',
        size: 9.5,
        x: 345,
        y: y,
        text: 'Rs. ${_formatAmount(item.totalPrice)}',
      );
      y -= 16;
    }

    _writeDivider(stream, x1: 24, x2: pageWidth - 24, y: y);
    y -= 16;

    // 7. Totals Summary
    stream.writeln('0.200 0.255 0.333 rg');
    _writeText(stream, font: 'F1', size: 10, x: 220, y: y, text: 'Item Subtotal:');
    _writeText(
      stream,
      font: 'F2',
      size: 10,
      x: 335,
      y: y,
      text: 'Rs. ${_formatAmount(receipt.subtotal)}',
    );
    y -= 15;

    _writeText(stream, font: 'F1', size: 10, x: 220, y: y, text: 'Delivery Charges:');
    _writeText(
      stream,
      font: 'F2',
      size: 10,
      x: 335,
      y: y,
      text: receipt.deliveryCharge > 0
          ? 'Rs. ${_formatAmount(receipt.deliveryCharge)}'
          : 'FREE (Rs. 0)',
    );
    y -= 15;

    if (receipt.discountAmount > 0) {
      _writeText(stream, font: 'F1', size: 10, x: 220, y: y, text: 'Discount:');
      _writeText(
        stream,
        font: 'F2',
        size: 10,
        x: 335,
        y: y,
        text: '-Rs. ${_formatAmount(receipt.discountAmount)}',
      );
      y -= 15;
    }

    _writeDivider(stream, x1: 215, x2: pageWidth - 24, y: y + 4);
    y -= 12;

    stream.writeln('0.059 0.463 0.431 rg');
    _writeText(stream, font: 'F2', size: 11.5, x: 220, y: y, text: 'TOTAL AMOUNT:');
    _writeText(
      stream,
      font: 'F2',
      size: 12,
      x: 335,
      y: y,
      text: 'Rs. ${_formatAmount(receipt.totalAmount)}',
    );
    y -= 28;

    // 8. Mandatory Legal Non-Tax Disclaimer Box
    stream.writeln('0.996 0.953 0.780 rg');
    stream.writeln('24 ${(y - 24).toStringAsFixed(1)} ${pageWidth - 48} 34 re f');
    stream.writeln('0.573 0.251 0.055 rg');
    _writeText(
      stream,
      font: 'F2',
      size: 9,
      x: 34,
      y: y - 10,
      text: 'Digital Order Receipt / Packing Slip - Not a Tax Invoice.',
    );

    final contentBytes = latin1.encode(stream.toString());
    return _assemblePdfDocument(
      pageWidth: pageWidth,
      pageHeight: pageHeight,
      contentBytes: contentBytes,
      title: 'Jamui Services Receipt #${receipt.orderNumber}',
    );
  }

  static String _formatAmount(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }

  static String _truncate(String input, int maxChars) {
    if (input.length <= maxChars) return input;
    return '${input.substring(0, maxChars - 3)}...';
  }

  static void _writeDivider(
    StringBuffer stream, {
    required double x1,
    required double x2,
    required double y,
  }) {
    stream.writeln('0.886 0.910 0.941 RG');
    stream.writeln('0.8 w');
    stream.writeln('${x1.toStringAsFixed(1)} ${y.toStringAsFixed(1)} m ${x2.toStringAsFixed(1)} ${y.toStringAsFixed(1)} l S');
  }

  static void _writeText(
    StringBuffer stream, {
    required String font,
    required double size,
    required double x,
    required double y,
    required String text,
  }) {
    final safe = _escapePdfText(text);
    stream.writeln('BT /$font ${size.toStringAsFixed(1)} Tf ${x.toStringAsFixed(1)} ${y.toStringAsFixed(1)} Td ($safe) Tj ET');
  }

  static String _escapePdfText(String input) {
    final asciiBuffer = StringBuffer();
    for (final codeUnit in input.codeUnits) {
      if (codeUnit == 0x2014 || codeUnit == 0x2013) {
        asciiBuffer.write('-');
      } else if (codeUnit == 0x20B9) {
        asciiBuffer.write('Rs. ');
      } else if (codeUnit >= 32 && codeUnit <= 126) {
        final ch = String.fromCharCode(codeUnit);
        if (ch == '(' || ch == ')' || ch == r'\') {
          asciiBuffer.write('\\$ch');
        } else {
          asciiBuffer.write(ch);
        }
      } else {
        // Omit non-ASCII glyphs from Type1 Helvetica stream to prevent garbled boxes
      }
    }
    return asciiBuffer.toString();
  }

  static Uint8List _assemblePdfDocument({
    required double pageWidth,
    required double pageHeight,
    required List<int> contentBytes,
    required String title,
  }) {
    final builder = BytesBuilder();
    final offsets = <int>[0]; // 1-indexed object offsets

    void writeStr(String s) {
      builder.add(latin1.encode(s));
    }

    void startObj(int id) {
      offsets.add(builder.length);
      writeStr('$id 0 obj\n');
    }

    void endObj() {
      writeStr('endobj\n');
    }

    // PDF 1.4 Header
    writeStr('%PDF-1.4\n%\xE2\xE3\xCF\xD3\n');

    // Object 1: Catalog
    startObj(1);
    writeStr('<< /Type /Catalog /Pages 2 0 R >>\n');
    endObj();

    // Object 2: Pages
    startObj(2);
    writeStr('<< /Type /Pages /Kids [3 0 R] /Count 1 >>\n');
    endObj();

    // Object 3: Page
    startObj(3);
    writeStr(
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${pageWidth.toStringAsFixed(1)} ${pageHeight.toStringAsFixed(1)}] '
      '/Resources << /Font << /F1 4 0 R /F2 5 0 R >> >> /Contents 6 0 R >>\n',
    );
    endObj();

    // Object 4: Font F1 (Helvetica)
    startObj(4);
    writeStr('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>\n');
    endObj();

    // Object 5: Font F2 (Helvetica-Bold)
    startObj(5);
    writeStr('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>\n');
    endObj();

    // Object 6: Page Content Stream
    startObj(6);
    writeStr('<< /Length ${contentBytes.length} >>\nstream\n');
    builder.add(contentBytes);
    writeStr('\nendstream\n');
    endObj();

    // Object 7: Document Info
    startObj(7);
    final safeTitle = _escapePdfText(title);
    writeStr(
      '<< /Title ($safeTitle) /Producer (Jamui Services Professional Marketplace) '
      '/Subject (Digital Order Receipt / Packing Slip - Not a Tax Invoice.) >>\n',
    );
    endObj();

    // Cross-Reference Table (xref)
    final xrefOffset = builder.length;
    writeStr('xref\n0 ${offsets.length}\n');
    writeStr('0000000000 65535 f \n');
    for (int i = 1; i < offsets.length; i++) {
      final padded = offsets[i].toString().padLeft(10, '0');
      writeStr('$padded 00000 n \n');
    }

    // Trailer
    writeStr(
      'trailer\n<< /Size ${offsets.length} /Root 1 0 R /Info 7 0 R >>\n'
      'startxref\n$xrefOffset\n%%EOF\n',
    );

    return builder.toBytes();
  }
}

typedef PdfDownloadHandler = Future<ReceiptActionResult> Function({
  required String fileName,
  required Uint8List pdfBytes,
});

typedef PdfShareHandler = Future<ReceiptActionResult> Function({
  required String fileName,
  required Uint8List pdfBytes,
  required String subject,
  required String text,
});

typedef UrlLauncherHandler = Future<bool> Function(Uri uri);

/// Unified controller for Receipt PDF Download, Native/Web Share, and Customer WhatsApp actions.
class ProfessionalReceiptService {
  final PdfDownloadHandler _downloadHandler;
  final PdfShareHandler _shareHandler;
  final UrlLauncherHandler _urlLauncherHandler;

  ProfessionalReceiptService({
    PdfDownloadHandler? downloadHandler,
    PdfShareHandler? shareHandler,
    UrlLauncherHandler? urlLauncherHandler,
  })  : _downloadHandler = downloadHandler ?? platformDownloadPdf,
        _shareHandler = shareHandler ?? platformSharePdf,
        _urlLauncherHandler = urlLauncherHandler ?? _defaultLaunchUrl;

  static Future<bool> _defaultLaunchUrl(Uri uri) async {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Formats a monetary number into clean Indian Rupee currency text.
  /// Examples:
  /// - 49 -> "₹49"
  /// - 49.50 -> "₹49.50"
  /// - 49.75 -> "₹49.75"
  /// - 100.00 -> "₹100"
  static String formatCurrency(num value, {String prefix = '₹'}) {
    final d = value.toDouble();
    if (d == d.roundToDouble()) {
      return '$prefix${d.toInt()}';
    }
    return '$prefix${d.toStringAsFixed(2)}';
  }

  /// Formats amount without prefix (e.g. "49", "49.50", "100").
  static String formatAmount(num value) {
    final d = value.toDouble();
    if (d == d.roundToDouble()) {
      return d.toInt().toString();
    }
    return d.toStringAsFixed(2);
  }

  /// Generates and downloads the receipt PDF (`JamuiServices_<orderNumber>.pdf`).
  Future<ReceiptActionResult> downloadReceiptPdf(
    ProfessionalReceiptData receipt, {
    bool enforceProviderAuth = false,
    String? authenticatedShopId,
    String? authenticatedOwnerUid,
    bool enforceCustomerAuth = false,
    String? authenticatedCustomerUid,
  }) async {
    final fileName = ProfessionalReceiptPdfGenerator.buildFileName(receipt.orderNumber);

    if (enforceProviderAuth &&
        !ProfessionalReceiptSecurityGuard.canProviderAccessReceipt(
          receipt: receipt,
          authenticatedShopId: authenticatedShopId,
          authenticatedOwnerUid: authenticatedOwnerUid,
        )) {
      return ReceiptActionResult(
        success: false,
        status: ReceiptActionStatus.unauthorized,
        fileName: fileName,
        message: 'Unauthorized: You can only download receipts for your own store orders.',
      );
    }

    if (enforceCustomerAuth &&
        !ProfessionalReceiptSecurityGuard.canCustomerAccessReceipt(
          receipt: receipt,
          authenticatedCustomerUid: authenticatedCustomerUid ?? '',
        )) {
      return ReceiptActionResult(
        success: false,
        status: ReceiptActionStatus.unauthorized,
        fileName: fileName,
        message: 'Unauthorized: You can only download receipts for your own orders.',
      );
    }

    final pdfBytes = ProfessionalReceiptPdfGenerator.generatePdfBytes(receipt);
    return await _downloadHandler(
      fileName: fileName,
      pdfBytes: pdfBytes,
    );
  }

  /// Generates and shares the receipt PDF via the native share sheet (or Web download fallback).
  Future<ReceiptActionResult> shareReceiptPdf(
    ProfessionalReceiptData receipt, {
    bool enforceProviderAuth = false,
    String? authenticatedShopId,
    String? authenticatedOwnerUid,
    bool enforceCustomerAuth = false,
    String? authenticatedCustomerUid,
  }) async {
    final fileName = ProfessionalReceiptPdfGenerator.buildFileName(receipt.orderNumber);

    if (enforceProviderAuth &&
        !ProfessionalReceiptSecurityGuard.canProviderAccessReceipt(
          receipt: receipt,
          authenticatedShopId: authenticatedShopId,
          authenticatedOwnerUid: authenticatedOwnerUid,
        )) {
      return ReceiptActionResult(
        success: false,
        status: ReceiptActionStatus.unauthorized,
        fileName: fileName,
        message: 'Unauthorized: You can only share receipts for your own store orders.',
      );
    }

    if (enforceCustomerAuth &&
        !ProfessionalReceiptSecurityGuard.canCustomerAccessReceipt(
          receipt: receipt,
          authenticatedCustomerUid: authenticatedCustomerUid ?? '',
        )) {
      return ReceiptActionResult(
        success: false,
        status: ReceiptActionStatus.unauthorized,
        fileName: fileName,
        message: 'Unauthorized: You can only share receipts for your own orders.',
      );
    }

    final pdfBytes = ProfessionalReceiptPdfGenerator.generatePdfBytes(receipt);
    final subject = 'Jamui Services Receipt #${receipt.orderNumber}';
    final shareText = ProfessionalReceiptPhoneValidator.buildReceiptWhatsAppSummary(receipt);

    return await _shareHandler(
      fileName: fileName,
      pdfBytes: pdfBytes,
      subject: subject,
      text: shareText,
    );
  }

  /// Validates the order's customer phone number and opens the customer's WhatsApp chat
  /// with a pre-filled Hindi message.
  ///
  /// Strictly restricted to the Provider App. Never uses the seller's phone number as a fallback.
  Future<ReceiptActionResult> sendToCustomerOnWhatsApp(
    ProfessionalReceiptData receipt, {
    bool enforceProviderAuth = false,
    String? authenticatedShopId,
    String? authenticatedOwnerUid,
  }) async {
    final fileName = ProfessionalReceiptPdfGenerator.buildFileName(receipt.orderNumber);

    if (enforceProviderAuth &&
        !ProfessionalReceiptSecurityGuard.canProviderAccessReceipt(
          receipt: receipt,
          authenticatedShopId: authenticatedShopId,
          authenticatedOwnerUid: authenticatedOwnerUid,
        )) {
      return ReceiptActionResult(
        success: false,
        status: ReceiptActionStatus.unauthorized,
        fileName: fileName,
        message: 'Unauthorized: You can only contact customers for your own store orders.',
      );
    }

    final phoneValidation = ProfessionalReceiptPhoneValidator.validateAndNormalize(
      receipt.customerPhone,
      countryCode: receipt.customerCountryCode,
    );

    if (!phoneValidation.isValid || phoneValidation.waMePhone == null) {
      return ReceiptActionResult(
        success: false,
        status: ReceiptActionStatus.invalidPhone,
        fileName: fileName,
        message: phoneValidation.errorReason ??
            'Valid customer WhatsApp number is not available for this order.',
      );
    }

    final uri = ProfessionalReceiptPhoneValidator.buildCustomerWhatsAppUri(receipt);
    if (uri == null) {
      return ReceiptActionResult(
        success: false,
        status: ReceiptActionStatus.invalidPhone,
        fileName: fileName,
        message: 'Valid customer WhatsApp number is not available for this order.',
      );
    }

    try {
      final launched = await _urlLauncherHandler(uri);
      if (!launched) {
        return ReceiptActionResult(
          success: false,
          status: ReceiptActionStatus.failed,
          fileName: fileName,
          launchedUri: uri,
          message: 'Could not open WhatsApp on this device.',
        );
      }
      return ReceiptActionResult(
        success: true,
        status: ReceiptActionStatus.whatsappOpened,
        fileName: fileName,
        launchedUri: uri,
        message:
            'WhatsApp chat opened with pre-filled message. Tap "Share PDF" to attach the receipt file in WhatsApp.',
      );
    } catch (_) {
      return ReceiptActionResult(
        success: false,
        status: ReceiptActionStatus.failed,
        fileName: fileName,
        launchedUri: uri,
        message: 'Unable to launch WhatsApp.',
      );
    }
  }
}

