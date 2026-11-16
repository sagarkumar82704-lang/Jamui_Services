import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_provider/features/professional_shop/services/professional_receipt_service.dart';
import 'package:apna_jamui_provider/features/professional_shop/presentation/widgets/professional_provider_order_receipt_sheet.dart';
import 'package:apna_jamui_provider/features/professional_shop/presentation/pages/professional_shop_orders_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Professional Order Variant & Receipt Fix Comprehensive Unit & Widget Tests', () {
    // Test Data
    final variantOrderMap = {
      'id': 'doc_var_order_101',
      'orderNumber': 'JS-284731',
      'sellerOrderNumber': 'SGJ-019',
      'channelId': 'JAMUI_SERVICES',
      'shopId': 'shop_sagar_1',
      'ownerUid': 'seller_sagar_1',
      'shopName': 'Sagar Grocery Jamui',
      'shopPhone': '9111111111',
      'customerId': 'cust_101',
      'customerName': 'Rohan Verma',
      'customerPhone': '9876543210',
      'fulfillmentType': 'delivery',
      'items': [
        {
          'productId': 'p_tea_1',
          'variantId': 'var_500g',
          'variantTitle': '500g',
          'sku': 'SKU-TEA-500G',
          'name': 'Tata Tea Gold',
          'unit': 'g',
          'price': 49.50,
          'quantity': 2,
          'itemTotal': 99.00,
        },
        {
          'productId': 'p_oil_1',
          'variantId': 'var_1L',
          'variantTitle': '1 Litre',
          'sku': 'SKU-OIL-1L',
          'name': 'Fortune Mustard Oil',
          'unit': 'L',
          'price': 165.25,
          'quantity': 1,
          'itemTotal': 165.25,
        },
      ],
      'subtotal': 264.25,
      'deliveryCharge': 25.50,
      'discountAmount': 0.0,
      'totalAmount': 289.75,
      'status': 'placed',
      'createdAt': '2026-11-09T14:30:00.000Z',
    };

    final simpleOrderMap = {
      'id': 'doc_simple_order_102',
      'orderNumber': 'JS-284732',
      'shopId': 'shop_sagar_1',
      'shopName': 'Sagar Grocery Jamui',
      'customerName': 'Priya Sharma',
      'customerPhone': '9876543211',
      'items': [
        {
          'productId': 'p_apple_1',
          'name': 'Fresh Apples',
          'unit': 'kg',
          'price': 100.0,
          'quantity': 3,
          'itemTotal': 300.0,
        },
      ],
      'subtotal': 300.0,
      'deliveryCharge': 0.0,
      'totalAmount': 300.0,
      'status': 'placed',
    };

    // 1. Variant parsing & displayTitle
    test('ProfessionalReceiptItem correctly extracts variantTitle and sku without duplicate unit', () {
      final item = ProfessionalReceiptItem.fromMap((variantOrderMap['items'] as List)[0] as Map<String, dynamic>);
      expect(item.title, 'Tata Tea Gold');
      expect(item.variantTitle, '500g');
      expect(item.sku, 'SKU-TEA-500G');
      expect(item.hasVariant, isTrue);
      expect(item.quantity, 2);
      expect(item.unitPrice, 49.50);
      expect(item.totalPrice, 99.00);
      // Avoids duplicate units like "500g (g)"
      expect(item.displayTitle, 'Tata Tea Gold (500g)');
      expect(item.displayTitleWithUnit, 'Tata Tea Gold (500g)');
    });

    // 2. Simple products without variant
    test('Simple products display cleanly without variant tags or empty parentheses', () {
      final item = ProfessionalReceiptItem.fromMap((simpleOrderMap['items'] as List)[0] as Map<String, dynamic>);
      expect(item.title, 'Fresh Apples');
      expect(item.variantTitle, isNull);
      expect(item.sku, isNull);
      expect(item.hasVariant, isFalse);
      expect(item.displayTitle, 'Fresh Apples');
      expect(item.displayTitleWithUnit, 'Fresh Apples (kg)');
    });

    // 3. Currency precision: ₹49.50 remains ₹49.50, ₹100 remains ₹100
    test('Currency Formatter preserves decimal values without truncation or over-rounding', () {
      expect(ProfessionalReceiptService.formatCurrency(49), '₹49');
      expect(ProfessionalReceiptService.formatCurrency(49.50), '₹49.50');
      expect(ProfessionalReceiptService.formatCurrency(49.75), '₹49.75');
      expect(ProfessionalReceiptService.formatCurrency(100.00), '₹100');
      expect(ProfessionalReceiptService.formatCurrency(264.25), '₹264.25');
      expect(ProfessionalReceiptService.formatCurrency(289.75), '₹289.75');
    });

    // 4. Safe Quantity Parsing handles int, double, String, and defaults
    test('Safe quantity parsing prevents crashes and handles non-standard numeric types', () {
      final itDouble = ProfessionalReceiptItem.fromMap({'title': 'Tea', 'quantity': 3.0, 'price': 50});
      expect(itDouble.quantity, 3);

      final itString = ProfessionalReceiptItem.fromMap({'title': 'Coffee', 'quantity': '4', 'price': 80});
      expect(itString.quantity, 4);

      final itNegative = ProfessionalReceiptItem.fromMap({'title': 'Milk', 'quantity': -2, 'price': 30});
      expect(itNegative.quantity, 1, reason: 'Negative qty should default safely to 1');

      final itNull = ProfessionalReceiptItem.fromMap({'title': 'Sugar', 'quantity': null, 'price': 40});
      expect(itNull.quantity, 1, reason: 'Null qty should default safely to 1');
    });

    // 5. PDF packing slip includes variant 500g and 1 Litre with formatted currency
    test('PDF packing slip generates with variant titles and exact decimals', () {
      final receipt = ProfessionalReceiptData.fromMap(variantOrderMap);
      final pdfBytes = ProfessionalReceiptPdfGenerator.generatePdfBytes(receipt);
      expect(pdfBytes.isNotEmpty, isTrue);

      final pdfContent = latin1.decode(pdfBytes);
      expect(pdfContent.contains(r'Tata Tea Gold \(500g\)'), isTrue);
      expect(pdfContent.contains(r'Fortune Mustard Oil \(1 Litre\)'), isTrue);
      expect(pdfContent.contains('Rs. 49.50'), isTrue);
      expect(pdfContent.contains('Rs. 99'), isTrue);
      expect(pdfContent.contains('Rs. 165.25'), isTrue);
      expect(pdfContent.contains('Rs. 264.25'), isTrue);
      expect(pdfContent.contains('Rs. 289.75'), isTrue);
    });

    // 6. WhatsApp summary includes items and variants
    test('WhatsApp message builder includes detailed items and variant names', () {
      final receipt = ProfessionalReceiptData.fromMap(variantOrderMap);
      final msg = ProfessionalReceiptPhoneValidator.buildReceiptWhatsAppSummary(receipt);

      expect(msg.contains('JS-284731'), isTrue);
      expect(msg.contains('Sagar Grocery Jamui'), isTrue);
      expect(msg.contains('Tata Tea Gold (500g) x 2 = Rs. 99'), isTrue);
      expect(msg.contains('Fortune Mustard Oil (1 Litre) x 1 = Rs. 165.25'), isTrue);
      expect(msg.contains('कुल राशि: Rs. 289.75'), isTrue);
    });

    // 7. Historical order backward compatibility
    test('Historical legacy order without variant and legacy field names deserializes cleanly', () {
      final legacyMap = {
        'orderId': 'ORD1731145600000',
        'shopId': 'shop_old',
        'shopName': 'Old Kirana',
        'customerId': 'cust_old',
        'items': [
          {
            'productTitle': 'Legacy Besan',
            'sellingPrice': 49.50,
            'quantity': 2,
            'total': 99.00,
          }
        ],
        'subtotal': 99.00,
        'totalAmount': 99.00,
      };

      final legacyReceipt = ProfessionalReceiptData.fromMap(legacyMap, docId: 'doc_leg_1');
      expect(legacyReceipt.orderId, 'doc_leg_1');
      expect(legacyReceipt.orderNumber, 'ORD1731145600000');
      expect(legacyReceipt.items.length, 1);
      expect(legacyReceipt.items[0].title, 'Legacy Besan');
      expect(legacyReceipt.items[0].hasVariant, isFalse);
      expect(legacyReceipt.items[0].unitPrice, 49.50);
      expect(legacyReceipt.items[0].totalPrice, 99.00);
    });

    // 8. Cross-shop isolation remains strictly enforced
    test('Cross-shop provider cannot access or share receipts of another shop', () async {
      final receipt = ProfessionalReceiptData.fromMap(variantOrderMap);
      final service = ProfessionalReceiptService(
        downloadHandler: ({required fileName, required pdfBytes}) async =>
            const ReceiptActionResult(success: true, status: ReceiptActionStatus.downloaded, fileName: '', message: ''),
      );

      final result = await service.downloadReceiptPdf(
        receipt,
        enforceProviderAuth: true,
        authenticatedShopId: 'other_hacker_shop',
      );

      expect(result.success, isFalse);
      expect(result.status, ReceiptActionStatus.unauthorized);
    });

    // 9. Widget Test: Provider Order Receipt Sheet displays variants and formatted decimals
    testWidgets('ProfessionalProviderOrderReceiptSheet displays variant titles and clean currency', (tester) async {
      final receipt = ProfessionalReceiptData.fromMap(variantOrderMap);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfessionalProviderOrderReceiptSheet(
              receipt: receipt,
              authenticatedShopId: 'shop_sagar_1',
            ),
          ),
        ),
      );

      // Verify variant and clean amount display
      expect(find.text('Tata Tea Gold (500g) x 2'), findsOneWidget);
      expect(find.text('Fortune Mustard Oil (1 Litre) x 1'), findsOneWidget);
      expect(find.text('₹99'), findsOneWidget);
      expect(find.text('₹165.25'), findsOneWidget);
      expect(find.text('₹264.25'), findsOneWidget); // Subtotal
      expect(find.text('₹25.50'), findsOneWidget); // Delivery charge
      expect(find.text('₹289.75'), findsOneWidget); // Total
    });
  });
}
