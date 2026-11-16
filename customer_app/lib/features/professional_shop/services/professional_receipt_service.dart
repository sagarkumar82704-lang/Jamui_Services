import 'package:apna_jamui_provider/features/professional_shop/services/professional_receipt_service.dart';
import '../domain/entities/professional_order_entity.dart';

export 'package:apna_jamui_provider/features/professional_shop/services/professional_receipt_service.dart';

extension ProfessionalOrderEntityReceiptExtension on ProfessionalOrderEntity {
  /// Converts a Customer App `ProfessionalOrderEntity` into the unified `ProfessionalReceiptData`
  /// used for PDF generation, native/web downloading, and sharing.
  ProfessionalReceiptData toReceiptData() {
    String formattedAddress = '';
    String? countryCode;
    String resolvedPhone = customerPhone.trim();

    if (deliveryAddress != null) {
      final baseAddr = ((deliveryAddress!['fullAddress'] as String?) ??
              (deliveryAddress!['address'] as String?) ??
              '')
          .trim();
      final landmark = ((deliveryAddress!['landmark'] as String?) ?? '').trim();
      final pincode = ((deliveryAddress!['pincode'] as String?) ?? '').trim();
      final parts = <String>[
        if (baseAddr.isNotEmpty) baseAddr,
        if (landmark.isNotEmpty) 'Near $landmark',
        if (pincode.isNotEmpty) pincode,
      ];
      formattedAddress = parts.join(', ');

      countryCode = (deliveryAddress!['countryCode'] as String?)?.trim() ??
          (deliveryAddress!['dialCode'] as String?)?.trim() ??
          (deliveryAddress!['country'] as String?)?.trim();

      if (resolvedPhone.isEmpty) {
        resolvedPhone = ((deliveryAddress!['contactPhone'] as String?) ??
                (deliveryAddress!['customerPhone'] as String?) ??
                '')
            .trim();
      }
    }

    return ProfessionalReceiptData(
      orderId: orderId,
      orderNumber: orderNumber,
      sellerOrderNumber: sellerOrderNumber,
      channelId: channelId,
      shopId: shopId,
      shopName: shopName,
      shopPhone: shopPhone,
      customerId: customerId,
      customerName: customerName,
      customerPhone: resolvedPhone,
      customerCountryCode:
          (countryCode != null && countryCode.isNotEmpty) ? countryCode : null,
      fulfillmentType: fulfillmentType,
      deliveryAddressText: formattedAddress,
      customerNotes: customerNotes,
      items: items
          .map(
            (it) => ProfessionalReceiptItem(
              productId: it.productId,
              title: it.title,
              unit: it.unit,
              quantity: it.quantity,
              unitPrice: it.price,
              totalPrice: it.total,
            ),
          )
          .toList(),
      subtotal: subtotal,
      deliveryCharge: deliveryCharge,
      discountAmount: discountAmount,
      totalAmount: totalAmount,
      paymentMode: paymentMode,
      paymentStatus: paymentStatus,
      status: status,
      createdAt: createdAt,
    );
  }
}

