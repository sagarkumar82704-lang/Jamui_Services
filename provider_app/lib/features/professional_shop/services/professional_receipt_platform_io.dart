import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'professional_receipt_platform_stub.dart';

export 'professional_receipt_platform_stub.dart' show ReceiptActionResult, ReceiptActionStatus;

const MethodChannel _receiptChannel = MethodChannel('com.jamuiservice.receipt/file_actions');

Future<ReceiptActionResult> platformDownloadPdf({
  required String fileName,
  required Uint8List pdfBytes,
}) async {
  final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

  if (Platform.isAndroid) {
    try {
      final response = await _receiptChannel.invokeMapMethod<String, dynamic>(
        'savePdfToDownloads',
        <String, dynamic>{
          'fileName': safeName,
          'bytes': pdfBytes,
        },
      );
      final savedPath = (response?['path'] as String?) ?? 'Downloads/$safeName';
      return ReceiptActionResult(
        success: true,
        status: ReceiptActionStatus.downloaded,
        fileName: safeName,
        savedLocation: savedPath,
        message: 'Receipt PDF saved to $savedPath',
      );
    } on MissingPluginException {
      // Fallback to local directory below when running in test or non-host isolate
    } catch (_) {
      // Fallback to local app directory if MediaStore fails
    }
  }

  try {
    Directory targetDir;
    try {
      targetDir = await getApplicationDocumentsDirectory();
    } catch (_) {
      targetDir = Directory.systemTemp;
    }
    final receiptsDir = Directory('${targetDir.path}${Platform.pathSeparator}jamui_receipts');
    if (!await receiptsDir.exists()) {
      await receiptsDir.create(recursive: true);
    }
    final outFile = File('${receiptsDir.path}${Platform.pathSeparator}$safeName');
    await outFile.writeAsBytes(pdfBytes, flush: true);
    return ReceiptActionResult(
      success: true,
      status: ReceiptActionStatus.downloaded,
      fileName: safeName,
      savedLocation: outFile.path,
      message: 'Receipt PDF saved ($safeName)',
    );
  } catch (_) {
    return ReceiptActionResult(
      success: false,
      status: ReceiptActionStatus.failed,
      fileName: safeName,
      message: 'Unable to save receipt PDF on this device.',
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

  if (Platform.isAndroid) {
    try {
      await _receiptChannel.invokeMapMethod<String, dynamic>(
        'sharePdfFile',
        <String, dynamic>{
          'fileName': safeName,
          'bytes': pdfBytes,
          'subject': subject,
          'text': text,
        },
      );
      return ReceiptActionResult(
        success: true,
        status: ReceiptActionStatus.shared,
        fileName: safeName,
        message: 'Opened share sheet for $safeName',
      );
    } on MissingPluginException {
      // Fallback for test environments
    } catch (_) {
      return ReceiptActionResult(
        success: false,
        status: ReceiptActionStatus.failed,
        fileName: safeName,
        message: 'Unable to open share sheet for receipt PDF.',
      );
    }
  }

  // Fallback on desktop/non-Android IO: save file so user can attach it
  final downloaded = await platformDownloadPdf(
    fileName: safeName,
    pdfBytes: pdfBytes,
  );
  if (downloaded.success) {
    return ReceiptActionResult(
      success: true,
      status: ReceiptActionStatus.webDownloadedFallback,
      fileName: safeName,
      savedLocation: downloaded.savedLocation,
      message: 'Receipt PDF saved ($safeName). You can now attach it in WhatsApp or Email.',
    );
  }
  return ReceiptActionResult(
    success: false,
    status: ReceiptActionStatus.failed,
    fileName: safeName,
    message: 'Unable to share receipt PDF.',
  );
}

