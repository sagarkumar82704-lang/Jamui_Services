import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Exception thrown when an R2 upload operation fails in Provider App.
class R2UploadException implements Exception {
  final String message;
  final int? statusCode;

  const R2UploadException(this.message, [this.statusCode]);

  @override
  String toString() => 'R2UploadException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
}

/// Result returned after a successful upload to Cloudflare R2.
class R2UploadResult {
  /// The relative canonical object key stored in R2 (e.g., `providers/{uid}/profile/profile_123.jpg`).
  final String objectKey;

  /// The exact byte length uploaded.
  final int byteLength;

  const R2UploadResult({
    required this.objectKey,
    required this.byteLength,
  });
}

/// Production-grade direct Cloudflare R2 Upload Service for Jamui Services (Provider App).
///
/// Workflow:
/// 1. Verifies caller is authenticated via Firebase Auth.
/// 2. Requests an authenticated short-lived presigned PUT URL from `getStorageUploadUrl` in `asia-south1`.
/// 3. Uploads the exact bytes to Cloudflare R2 matching signed `Content-Length` and `Content-Type`.
/// 4. Returns only the relative [R2UploadResult.objectKey] for Firestore persistence.
/// 5. Never prints presigned URLs or credentials in logs.
class R2UploadService {
  final FirebaseFunctions? _functionsInstance;
  final FirebaseAuth? _authInstance;
  final http.Client _httpClient;

  R2UploadService({
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
    http.Client? httpClient,
  })  : _functionsInstance = functions,
        _authInstance = auth,
        _httpClient = httpClient ?? http.Client();

  FirebaseFunctions get _functions {
    return _functionsInstance ?? FirebaseFunctions.instanceFor(region: 'asia-south1');
  }

  User? _getCurrentUser() {
    if (_authInstance != null) {
      return _authInstance.currentUser;
    }
    try {
      return FirebaseAuth.instance.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// Uploads raw bytes to Cloudflare R2.
  Future<R2UploadResult> uploadBytes({
    required Uint8List bytes,
    required String folder,
    required String fileName,
    required String mimeType,
    String? targetId,
  }) async {
    final fileSize = bytes.length;
    if (fileSize <= 0) {
      throw const R2UploadException('Cannot upload empty file: byte length is 0.');
    }

    // 1. Verify caller authentication
    final currentUser = _getCurrentUser();
    if (currentUser == null) {
      throw const R2UploadException('User must be authenticated to upload media.');
    }

    final cleanFolder = folder.trim().toLowerCase();
    final cleanMime = mimeType.trim().toLowerCase();

    // 2. Request short-lived presigned PUT URL from Cloud Functions
    HttpsCallableResult callableResult;
    try {
      final callable = _functions.httpsCallable('getStorageUploadUrl');
      callableResult = await callable.call(<String, dynamic>{
        'folder': cleanFolder,
        'fileName': fileName.trim(),
        'mimeType': cleanMime,
        'fileSize': fileSize,
        if (targetId != null && targetId.trim().isNotEmpty) 'targetId': targetId.trim(),
      }).timeout(const Duration(seconds: 12));
    } on FirebaseFunctionsException catch (fe) {
      throw R2UploadException('Backend validation error: ${fe.message ?? fe.code}');
    } catch (e) {
      throw R2UploadException('Failed to request upload authorization: $e');
    }

    final data = callableResult.data;
    if (data is! Map) {
      throw const R2UploadException('Invalid response structure received from getStorageUploadUrl.');
    }

    final resMap = Map<String, dynamic>.from(data);
    final uploadUrl = resMap['uploadUrl'] as String?;
    final objectKey = resMap['objectKey'] as String?;
    final requiredHeaders = resMap['requiredHeaders'] is Map
        ? Map<String, dynamic>.from(resMap['requiredHeaders'] as Map)
        : <String, dynamic>{};

    if (uploadUrl == null || uploadUrl.isEmpty || objectKey == null || objectKey.isEmpty) {
      throw const R2UploadException('Upload URL or object key missing from authorization response.');
    }

    // 3. Assemble exact HTTP headers required by SigV4
    final headers = <String, String>{};
    for (final entry in requiredHeaders.entries) {
      // Browsers (WHATWG fetch standard) strictly forbid manually setting Content-Length
      if (kIsWeb && entry.key.toLowerCase() == 'content-length') {
        continue;
      }
      headers[entry.key] = entry.value.toString();
    }
    // Ensure exact Content-Type is present
    headers['Content-Type'] = cleanMime;
    if (!kIsWeb) {
      headers['Content-Length'] = fileSize.toString();
    }

    // 4. Perform direct presigned PUT to Cloudflare R2
    http.Response putResponse;
    try {
      putResponse = await _httpClient.put(
        Uri.parse(uploadUrl),
        headers: headers,
        body: bytes,
      ).timeout(const Duration(seconds: 30));
    } catch (e) {
      throw R2UploadException('Network error during R2 direct upload: $e');
    }

    if (putResponse.statusCode != 200 && putResponse.statusCode != 204) {
      final bodySnippet = putResponse.body.isNotEmpty
          ? ': ${putResponse.body.length > 250 ? putResponse.body.substring(0, 250) : putResponse.body}'
          : '';
      throw R2UploadException(
        'R2 direct upload rejected ($putResponse.statusCode)$bodySnippet',
        putResponse.statusCode,
      );
    }

    debugPrint('🔒 [R2UploadService] Provider upload successful for objectKey: $objectKey ($fileSize bytes)');

    // 4. Server-Side Verification: Checks actual byte length on R2 and purges oversized (>8MB) files
    try {
      final verifyCallable = _functions.httpsCallable('verifyUploadedStorageObject');
      await verifyCallable.call(<String, dynamic>{
        'objectKey': objectKey,
      }).timeout(const Duration(seconds: 12));
    } catch (verifyError) {
      final errStr = verifyError.toString();
      if (errStr.contains('exceeds') || errStr.contains('purged') || errStr.contains('not permitted')) {
        throw R2UploadException('सर्वर सत्यापन विफल: फ़ाइल का आकार या प्रकार अमान्य है। ($errStr)');
      }
      debugPrint('ℹ️ [R2UploadService] Post-upload verification status: $verifyError');
    }

    return R2UploadResult(
      objectKey: objectKey,
      byteLength: fileSize,
    );
  }

  /// Uploads a local [File] to Cloudflare R2.
  Future<R2UploadResult> uploadFile(
    File file, {
    required String folder,
    String? targetId,
    String? mimeType,
  }) async {
    if (!await file.exists()) {
      throw R2UploadException('File does not exist at path: ${file.path}');
    }

    final bytes = await file.readAsBytes();
    final fileName = file.path.split(Platform.pathSeparator).last;
    final resolvedMime = mimeType ?? _guessMimeType(fileName);

    return uploadBytes(
      bytes: bytes,
      folder: folder,
      fileName: fileName,
      mimeType: resolvedMime,
      targetId: targetId,
    );
  }

  /// Deletes an object from Cloudflare R2 and reconciles quota on the backend.
  Future<void> deleteStorageObject({
    required String objectKey,
    String folder = 'listings',
    String? listingId,
  }) async {
    final cleanKey = objectKey.trim();
    if (cleanKey.isEmpty) return;

    try {
      final callable = _functions.httpsCallable('deleteStorageObject');
      await callable.call(<String, dynamic>{
        'objectKey': cleanKey,
        'folder': folder,
        if (listingId != null && listingId.isNotEmpty) 'listingId': listingId,
      }).timeout(const Duration(seconds: 15));
      debugPrint('🗑️ [R2UploadService] Successfully deleted object: $cleanKey');
    } on FirebaseFunctionsException catch (fe) {
      throw R2UploadException('Delete rejected: ${fe.message ?? fe.code}');
    } catch (e) {
      throw R2UploadException('Failed to delete storage object: $e');
    }
  }

  static String _guessMimeType(String fileName) {
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase().trim() : '';
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }
}
