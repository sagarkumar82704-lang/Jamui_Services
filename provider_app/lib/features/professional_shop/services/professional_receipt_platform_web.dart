import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'professional_receipt_platform_stub.dart';

export 'professional_receipt_platform_stub.dart' show ReceiptActionResult, ReceiptActionStatus;

Future<ReceiptActionResult> platformDownloadPdf({
  required String fileName,
  required Uint8List pdfBytes,
}) async {
  final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  try {
    final parts = <JSAny>[pdfBytes.toJS].toJS;
    final blob = web.Blob(parts, web.BlobPropertyBag(type: 'application/pdf'));
    final objectUrl = web.URL.createObjectURL(blob);

    final anchor = web.HTMLAnchorElement()
      ..href = objectUrl
      ..download = safeName
      ..style.display = 'none';

    web.document.body?.appendChild(anchor);
    anchor.click();
    anchor.remove();
    web.URL.revokeObjectURL(objectUrl);

    return ReceiptActionResult(
      success: true,
      status: ReceiptActionStatus.downloaded,
      fileName: safeName,
      savedLocation: 'Browser Downloads/$safeName',
      message: 'Browser download started for $safeName',
    );
  } catch (_) {
    return ReceiptActionResult(
      success: false,
      status: ReceiptActionStatus.failed,
      fileName: safeName,
      message: 'Unable to trigger browser PDF download.',
    );
  }
}

Future<ReceiptActionResult> platformSharePdf({
  required String fileName,
  required Uint8List pdfBytes,
  required String subject,
  required String text,
}) async {
  final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

  // Web browsers often restrict programmatic file sharing via Web Share API on desktop;
  // download the PDF cleanly and instruct the user to attach it in WhatsApp Web or Email.
  final downloadResult = await platformDownloadPdf(
    fileName: safeName,
    pdfBytes: pdfBytes,
  );
  if (downloadResult.success) {
    return ReceiptActionResult(
      success: true,
      status: ReceiptActionStatus.webDownloadedFallback,
      fileName: safeName,
      savedLocation: downloadResult.savedLocation,
      message: 'Receipt PDF downloaded ($safeName). Please attach it in WhatsApp or Email.',
    );
  }
  return ReceiptActionResult(
    success: false,
    status: ReceiptActionStatus.failed,
    fileName: safeName,
    message: 'Unable to share or download receipt PDF on Web.',
  );
}

