import 'dart:typed_data';

enum ReceiptActionStatus {
  downloaded,
  shared,
  webDownloadedFallback,
  whatsappOpened,
  unauthorized,
  invalidPhone,
  failed,
}

class ReceiptActionResult {
  final bool success;
  final ReceiptActionStatus status;
  final String fileName;
  final String message;
  final String? savedLocation;
  final Uri? launchedUri;

  const ReceiptActionResult({
    required this.success,
    required this.status,
    required this.fileName,
    required this.message,
    this.savedLocation,
    this.launchedUri,
  });
}

Future<ReceiptActionResult> platformDownloadPdf({
  required String fileName,
  required Uint8List pdfBytes,
}) async {
  return ReceiptActionResult(
    success: false,
    status: ReceiptActionStatus.failed,
    fileName: fileName,
    message: 'PDF download is not supported on this platform.',
  );
}

Future<ReceiptActionResult> platformSharePdf({
  required String fileName,
  required Uint8List pdfBytes,
  required String subject,
  required String text,
}) async {
  return ReceiptActionResult(
    success: false,
    status: ReceiptActionStatus.failed,
    fileName: fileName,
    message: 'PDF sharing is not supported on this platform.',
  );
}

