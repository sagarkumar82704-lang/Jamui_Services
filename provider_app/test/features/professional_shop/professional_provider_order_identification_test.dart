import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_provider/features/professional_shop/domain/entities/professional_shop_profile_entity.dart';
import 'package:apna_jamui_provider/features/professional_shop/data/datasources/professional_provider_remote_data_source.dart';
import 'package:apna_jamui_provider/features/professional_shop/services/professional_receipt_service.dart';
import 'package:apna_jamui_provider/features/professional_shop/presentation/widgets/professional_provider_order_receipt_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Provider App Professional Order Identification & Shop Code Security Tests', () {
    test('ProfessionalShopProfileEntity properly loads shopCode and sellerOrderCounter', () {
      final map = {
        'id': 'shop_123',
        'shopName': 'Sagar Grocery Jamui',
        'shopCode': 'SGJ',
        'sellerOrderCounter': 19,
        'rating': 4.8,
        'ratingCount': 25,
      };

      final profile = ProfessionalShopProfileEntity.fromMap(map, 'shop_123');

      expect(profile.shopCode, 'SGJ');
      expect(profile.sellerOrderCounter, 19);

      final toMapResult = profile.toMap();
      expect(toMapResult['shopCode'], 'SGJ');
      expect(toMapResult['sellerOrderCounter'], 19);

      final updated = profile.copyWith(sellerOrderCounter: 20);
      expect(updated.sellerOrderCounter, 20);
      expect(updated.shopCode, 'SGJ');
    });

    test('immutableShopFields includes shopCode and sellerOrderCounter to prevent seller tamper', () {
      expect(ProfessionalProviderRemoteDataSource.immutableShopFields.contains('shopCode'), isTrue);
      expect(ProfessionalProviderRemoteDataSource.immutableShopFields.contains('sellerOrderCounter'), isTrue);

      final maliciousPayload = {
        'shopName': 'Updated Shop Name',
        'shopCode': 'HACKED_CODE',
        'sellerOrderCounter': 999999,
        'rating': 5.0,
        'isApproved': true,
      };

      final sanitized = ProfessionalProviderRemoteDataSource.sanitizeShopUpdatePayload(maliciousPayload);

      expect(sanitized.containsKey('shopCode'), isFalse, reason: 'shopCode must be stripped');
      expect(sanitized.containsKey('sellerOrderCounter'), isFalse, reason: 'sellerOrderCounter must be stripped');
      expect(sanitized.containsKey('rating'), isFalse, reason: 'rating must be stripped');
      expect(sanitized.containsKey('isApproved'), isFalse, reason: 'isApproved must be stripped');
      expect(sanitized['shopName'], 'Updated Shop Name', reason: 'Safe fields should remain');
    });
  });

  group('Receipt PDF Generation, E.164 Phone Normalization & WhatsApp Deep Link Tests', () {
    test('Generates valid PDF 1.4 with exact totals, items, channel, and non-tax notice', () {
      final orderMap = {
        'id': 'doc_internal_101',
        'orderNumber': 'JS-284731',
        'sellerOrderNumber': 'SGJ-019',
        'channelId': 'JAMUI_SERVICES',
        'shopId': 'shop_sagar',
        'shopName': 'Sagar Grocery Jamui',
        'shopPhone': '9111111111',
        'customerId': 'cust_101',
        'customerName': 'Rohan Verma',
        'customerPhone': '9876543210',
        'fulfillmentType': 'delivery',
        'deliveryAddress': {
          'fullAddress': 'Kachahari Road, Jamui',
          'pincode': '811307',
        },
        'items': [
          {
            'productId': 'p1',
            'title': 'Aashirvaad Atta',
            'unit': '5 kg',
            'price': 240.0,
            'quantity': 2,
            'total': 480.0,
          },
          {
            'productId': 'p2',
            'title': 'Mustard Oil',
            'unit': '1 L',
            'price': 160.0,
            'quantity': 1,
            'total': 160.0,
          },
        ],
        'subtotal': 640.0,
        'deliveryFee': 25.0,
        'totalAmount': 665.0,
        'paymentMode': 'cod',
        'createdAt': '2026-11-09T14:30:00.000Z',
      };

      final receipt = ProfessionalReceiptData.fromMap(orderMap);
      expect(receipt.orderId, 'doc_internal_101');
      expect(receipt.orderNumber, 'JS-284731');
      expect(receipt.sellerOrderNumber, 'SGJ-019');

      final fileName = ProfessionalReceiptPdfGenerator.buildFileName(receipt.orderNumber);
      expect(fileName, 'JamuiServices_JS-284731.pdf');

      final pdfBytes = ProfessionalReceiptPdfGenerator.generatePdfBytes(receipt);
      expect(pdfBytes.isNotEmpty, isTrue);

      final pdfContent = latin1.decode(pdfBytes);
      expect(pdfContent.startsWith('%PDF-1.4'), isTrue);
      expect(pdfContent.trim().endsWith('%%EOF'), isTrue);
      expect(pdfContent.contains('Channel: JAMUI SERVICES'), isTrue);
      expect(pdfContent.contains('Store: Sagar Grocery Jamui'), isTrue);
      expect(pdfContent.contains('Platform Order Number: #JS-284731'), isTrue);
      expect(pdfContent.contains('Seller Order Number: SGJ-019'), isTrue);
      expect(pdfContent.contains('Payment Method: COD'), isTrue);
      expect(pdfContent.contains(r'Aashirvaad Atta \(5 kg\)'), isTrue);
      expect(pdfContent.contains(r'Mustard Oil \(1 L\)'), isTrue);
      expect(pdfContent.contains('Rs. 640'), isTrue);
      expect(pdfContent.contains('Rs. 25'), isTrue);
      expect(pdfContent.contains('Rs. 665'), isTrue);
      expect(pdfContent.contains('Digital Order Receipt / Packing Slip - Not a Tax Invoice.'), isTrue);
    });

    test('Normalizes Indian and international phone numbers to E.164 and rejects invalid numbers', () {
      // 10-digit Indian mobile
      final in10 = ProfessionalReceiptPhoneValidator.validateAndNormalize('98765 43210');
      expect(in10.isValid, isTrue);
      expect(in10.e164Phone, '+919876543210');
      expect(in10.waMePhone, '919876543210');

      // 0-prefixed Indian mobile
      final in0 = ProfessionalReceiptPhoneValidator.validateAndNormalize('094312-88412');
      expect(in0.isValid, isTrue);
      expect(in0.e164Phone, '+919431288412');

      // Explicit +1 US number (does not assume Indian)
      final usPhone = ProfessionalReceiptPhoneValidator.validateAndNormalize('+1 (415) 555-2671');
      expect(usPhone.isValid, isTrue);
      expect(usPhone.e164Phone, '+14155552671');
      expect(usPhone.waMePhone, '14155552671');

      // Explicit country code metadata (UAE +971)
      final uaePhone = ProfessionalReceiptPhoneValidator.validateAndNormalize(
        '0501234567',
        countryCode: 'AE',
      );
      expect(uaePhone.isValid, isTrue);
      expect(uaePhone.e164Phone, '+971501234567');

      // Invalid/missing numbers rejected
      expect(ProfessionalReceiptPhoneValidator.validateAndNormalize('').isValid, isFalse);
      expect(ProfessionalReceiptPhoneValidator.validateAndNormalize('12345').isValid, isFalse);
      expect(ProfessionalReceiptPhoneValidator.validateAndNormalize('0000000000').isValid, isFalse);
      expect(ProfessionalReceiptPhoneValidator.validateAndNormalize('98765abc10').isValid, isFalse);
    });

    test('Never falls back to seller shopPhone when customerPhone is missing, and prevents cross-customer leakage', () {
      final orderWithoutCustomerPhone = ProfessionalReceiptData.fromMap({
        'id': 'doc_no_phone',
        'orderNumber': 'JS-284735',
        'shopId': 'shop_sagar',
        'shopName': 'Sagar Grocery Jamui',
        'shopPhone': '9999988888', // Seller phone present
        'customerId': 'cust_no_phone',
        'customerName': 'Customer Without Phone',
        // customerPhone is missing
        'items': [],
        'subtotal': 100.0,
        'totalAmount': 100.0,
      });

      expect(orderWithoutCustomerPhone.customerPhone, isEmpty);
      expect(orderWithoutCustomerPhone.shopPhone, '9999988888');
      expect(
        ProfessionalReceiptPhoneValidator.buildCustomerWhatsAppUri(orderWithoutCustomerPhone),
        isNull,
      );

      // Verify two distinct customer orders never leak phone numbers into each other
      final orderCustomerA = ProfessionalReceiptData.fromMap({
        'id': 'doc_A',
        'orderNumber': 'JS-284740',
        'shopId': 'shop_sagar',
        'shopName': 'Sagar Grocery Jamui',
        'customerId': 'cust_A',
        'customerPhone': '9876500001',
        'items': [],
        'subtotal': 50.0,
        'totalAmount': 50.0,
      });
      final orderCustomerB = ProfessionalReceiptData.fromMap({
        'id': 'doc_B',
        'orderNumber': 'JS-284741',
        'shopId': 'shop_sagar',
        'shopName': 'Sagar Grocery Jamui',
        'customerId': 'cust_B',
        'customerPhone': '9876500002',
        'items': [],
        'subtotal': 75.0,
        'totalAmount': 75.0,
      });

      final uriA = ProfessionalReceiptPhoneValidator.buildCustomerWhatsAppUri(orderCustomerA)!;
      final uriB = ProfessionalReceiptPhoneValidator.buildCustomerWhatsAppUri(orderCustomerB)!;

      expect(uriA.path, '/919876500001');
      expect(uriB.path, '/919876500002');
      expect(uriA.toString().contains('9876500002'), isFalse);
      expect(uriB.toString().contains('9876500001'), isFalse);

      final expectedMessageA =
          'नमस्ते! Jamui Services पर आपके ऑर्डर JS-284740 की रसीद तैयार है। दुकान: Sagar Grocery Jamui। धन्यवाद।';
      expect(uriA.queryParameters['text'], expectedMessageA);
    });

    test('Legacy orders missing orderNumber and sellerOrderNumber generate valid receipt and PDF', () {
      final legacyReceipt = ProfessionalReceiptData.fromMap({
        'orderId': 'ORD1731145600000',
        'shopId': 'shop_old',
        'shopName': 'Legacy Kirana',
        'customerId': 'cust_legacy',
        'items': [
          {'name': 'Sugar', 'quantity': 1, 'price': 45.0}
        ],
        'subtotal': 45.0,
        'totalAmount': 45.0,
      }, docId: 'doc_legacy_1');

      expect(legacyReceipt.orderId, 'doc_legacy_1');
      expect(legacyReceipt.orderNumber, 'ORD1731145600000');
      expect(legacyReceipt.sellerOrderNumber, isNull);

      final pdfBytes = ProfessionalReceiptPdfGenerator.generatePdfBytes(legacyReceipt);
      final pdfText = latin1.decode(pdfBytes);
      expect(pdfText.contains('Platform Order Number: #ORD1731145600000'), isTrue);
      expect(pdfText.contains('Seller Order Number:'), isFalse);
    });

    test('Receipt authorization blocks cross-shop provider access and cross-customer access', () async {
      final shopAReceipt = ProfessionalReceiptData.fromMap({
        'id': 'doc_shop_a',
        'orderNumber': 'JS-284731',
        'shopId': 'shop_sagar',
        'ownerUid': 'seller_sagar',
        'shopName': 'Sagar Grocery Jamui',
        'customerId': 'cust_real',
        'customerPhone': '9876543210',
        'items': [],
        'subtotal': 100.0,
        'totalAmount': 100.0,
      });

      final service = ProfessionalReceiptService(
        downloadHandler: ({required fileName, required pdfBytes}) async => ReceiptActionResult(
          success: true,
          status: ReceiptActionStatus.downloaded,
          fileName: fileName,
          message: 'Downloaded',
        ),
        shareHandler: ({required fileName, required pdfBytes, required subject, required text}) async =>
            ReceiptActionResult(
          success: true,
          status: ReceiptActionStatus.shared,
          fileName: fileName,
          message: 'Shared',
        ),
        urlLauncherHandler: (uri) async => true,
      );

      // Unauthorized seller (shop_other) must be blocked on Download, Share, and WhatsApp
      final unauthDownload = await service.downloadReceiptPdf(
        shopAReceipt,
        enforceProviderAuth: true,
        authenticatedShopId: 'shop_other',
      );
      expect(unauthDownload.success, isFalse);
      expect(unauthDownload.status, ReceiptActionStatus.unauthorized);

      final unauthShare = await service.shareReceiptPdf(
        shopAReceipt,
        enforceProviderAuth: true,
        authenticatedShopId: 'shop_other',
      );
      expect(unauthShare.success, isFalse);
      expect(unauthShare.status, ReceiptActionStatus.unauthorized);

      final unauthWhatsApp = await service.sendToCustomerOnWhatsApp(
        shopAReceipt,
        enforceProviderAuth: true,
        authenticatedShopId: 'shop_other',
      );
      expect(unauthWhatsApp.success, isFalse);
      expect(unauthWhatsApp.status, ReceiptActionStatus.unauthorized);

      // Authorized seller succeeds
      final authDownload = await service.downloadReceiptPdf(
        shopAReceipt,
        enforceProviderAuth: true,
        authenticatedShopId: 'shop_sagar',
      );
      expect(authDownload.success, isTrue);
      expect(authDownload.status, ReceiptActionStatus.downloaded);

      // Unauthorized customer blocked
      final unauthCust = await service.downloadReceiptPdf(
        shopAReceipt,
        enforceCustomerAuth: true,
        authenticatedCustomerUid: 'cust_attacker',
      );
      expect(unauthCust.success, isFalse);
      expect(unauthCust.status, ReceiptActionStatus.unauthorized);
    });
  });

  group('Provider App Receipt Widget & WhatsApp UI Tests', () {
    testWidgets('ProfessionalProviderOrderReceiptSheet executes Download, Share, and WhatsApp deep link for authorized seller', (tester) async {
      final receipt = ProfessionalReceiptData.fromMap({
        'id': 'doc_500',
        'orderNumber': 'JS-284731',
        'sellerOrderNumber': 'SGJ-019',
        'shopId': 'shop_sagar',
        'shopName': 'Sagar Grocery Jamui',
        'customerId': 'cust_500',
        'customerName': 'Priya Sharma',
        'customerPhone': '9876543210',
        'items': [
          {'title': 'Tata Salt', 'quantity': 1, 'unit': '1 kg', 'price': 28.0, 'total': 28.0}
        ],
        'subtotal': 28.0,
        'deliveryFee': 0.0,
        'totalAmount': 28.0,
      });

      Uri? launchedWhatsAppUri;
      String? downloadedFile;
      String? sharedFile;

      final mockService = ProfessionalReceiptService(
        downloadHandler: ({required fileName, required pdfBytes}) async {
          downloadedFile = fileName;
          return ReceiptActionResult(
            success: true,
            status: ReceiptActionStatus.downloaded,
            fileName: fileName,
            message: 'Saved $fileName',
          );
        },
        shareHandler: ({required fileName, required pdfBytes, required subject, required text}) async {
          sharedFile = fileName;
          return ReceiptActionResult(
            success: true,
            status: ReceiptActionStatus.webDownloadedFallback,
            fileName: fileName,
            message: 'PDF downloaded ($fileName). Please attach it in WhatsApp or Email.',
          );
        },
        urlLauncherHandler: (uri) async {
          launchedWhatsAppUri = uri;
          return true;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfessionalProviderOrderReceiptSheet(
              receipt: receipt,
              authenticatedShopId: 'shop_sagar',
              receiptService: mockService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Download PDF'), findsOneWidget);
      expect(find.text('Share PDF'), findsOneWidget);
      expect(find.text('Send to Customer on WhatsApp'), findsOneWidget);

      // Tap Download PDF
      await tester.ensureVisible(find.byKey(const Key('provider_receipt_download_pdf_button')));
      await tester.tap(find.byKey(const Key('provider_receipt_download_pdf_button')));
      await tester.pumpAndSettle();
      expect(downloadedFile, 'JamuiServices_JS-284731.pdf');

      // Tap Share PDF (testing Web download fallback behavior as well)
      await tester.ensureVisible(find.byKey(const Key('provider_receipt_share_pdf_button')));
      await tester.tap(find.byKey(const Key('provider_receipt_share_pdf_button')));
      await tester.pumpAndSettle();
      expect(sharedFile, 'JamuiServices_JS-284731.pdf');

      // Tap Send to Customer on WhatsApp
      await tester.ensureVisible(find.byKey(const Key('provider_receipt_whatsapp_button')));
      await tester.tap(find.byKey(const Key('provider_receipt_whatsapp_button')));
      await tester.pumpAndSettle();

      expect(launchedWhatsAppUri, isNotNull);
      expect(launchedWhatsAppUri!.host, 'wa.me');
      expect(launchedWhatsAppUri!.path, '/919876543210');
      expect(
        launchedWhatsAppUri!.queryParameters['text'],
        'नमस्ते! Jamui Services पर आपके ऑर्डर JS-284731 की रसीद तैयार है। दुकान: Sagar Grocery Jamui। धन्यवाद।',
      );
    });

    testWidgets('ProfessionalProviderOrderReceiptSheet disables WhatsApp button when customer phone is missing', (tester) async {
      final receiptMissingPhone = ProfessionalReceiptData.fromMap({
        'id': 'doc_501',
        'orderNumber': 'JS-284732',
        'sellerOrderNumber': 'SGJ-020',
        'shopId': 'shop_sagar',
        'shopName': 'Sagar Grocery Jamui',
        'shopPhone': '9123456789',
        'customerId': 'cust_501',
        'customerName': 'Anon Buyer',
        'customerPhone': '',
        'items': [],
        'subtotal': 100.0,
        'totalAmount': 100.0,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfessionalProviderOrderReceiptSheet(
              receipt: receiptMissingPhone,
              authenticatedShopId: 'shop_sagar',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final whatsappButton = tester.widget<ElevatedButton>(
        find.byKey(const Key('provider_receipt_whatsapp_button')),
      );
      expect(whatsappButton.onPressed, isNull);
      expect(find.byKey(const Key('provider_receipt_invalid_phone_notice')), findsOneWidget);
    });
  });
}
