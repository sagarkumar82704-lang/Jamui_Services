import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../../core/services/r2_upload_service.dart';

class CategoryStorageUploadResult {
  final String downloadUrl;
  final String storagePath;

  const CategoryStorageUploadResult({
    required this.downloadUrl,
    required this.storagePath,
  });
}

abstract class CategoryStorageRemoteDataSource {
  Future<CategoryStorageUploadResult> uploadCategoryImage({
    required String categoryId,
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  });

  Future<void> deleteCategoryImage(String storagePath);
}

/// R2-Only Category Storage Remote Data Source.
///
/// STRICT ARCHITECTURE:
/// - Direct Cloudflare R2 Uploads via [R2UploadService].
/// - ZERO Firebase Storage uploads.
/// - NO Firebase Storage fallback (eliminates accidental Firebase Storage costs).
/// - Returns canonical relative objectKey `categories/{categoryId}/cover_....webp`.
class R2CategoryStorageRemoteDataSource implements CategoryStorageRemoteDataSource {
  final R2UploadService _r2Service;

  R2CategoryStorageRemoteDataSource({
    R2UploadService? r2Service,
  }) : _r2Service = r2Service ?? R2UploadService();

  @override
  Future<CategoryStorageUploadResult> uploadCategoryImage({
    required String categoryId,
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'jpg';
    final cleanExt = (ext == 'jpeg' || ext == 'jpg' || ext == 'png' || ext == 'webp') ? ext : 'jpg';
    final contentType = mimeType ?? 'image/$cleanExt';

    // R2-ONLY Direct Upload: Strictly NO Firebase Storage upload or fallback
    try {
      final r2Result = await _r2Service.uploadBytes(
        bytes: bytes,
        folder: 'categories',
        fileName: fileName,
        mimeType: contentType,
        targetId: categoryId,
      );

      // Return canonical relative objectKey for persistence in Firestore
      return CategoryStorageUploadResult(
        downloadUrl: r2Result.objectKey,
        storagePath: r2Result.objectKey,
      );
    } catch (r2Error) {
      debugPrint('❌ [R2CategoryStorageRemoteDataSource] Cloudflare R2 category upload failed: $r2Error');
      // STRICT: Rethrow immediately without Firebase Storage fallback to prevent unwanted costs
      throw Exception('Cloudflare R2 पर कैटेगरी इमेज अपलोड विफल रहा: ${r2Error.toString().replaceFirst("Exception: ", "")}');
    }
  }

  @override
  Future<void> deleteCategoryImage(String storagePath) async {
    // Client-side direct R2 deletion is disabled for security.
    debugPrint('ℹ️ [R2CategoryStorageRemoteDataSource] deleteCategoryImage called for key: $storagePath');
  }
}

/// Backward compatibility alias for existing consumers
typedef FirebaseCategoryStorageRemoteDataSource = R2CategoryStorageRemoteDataSource;
