import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../../core/services/r2_upload_service.dart';

class BannerStorageUploadResult {
  final String downloadUrl;
  final String storagePath;

  const BannerStorageUploadResult({
    required this.downloadUrl,
    required this.storagePath,
  });
}

abstract class BannerStorageRemoteDataSource {
  Future<BannerStorageUploadResult> uploadBannerImage({
    required String bannerId,
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  });

  Future<void> deleteBannerImage(String storagePath);
}

/// R2-Only Banner Storage Remote Data Source.
///
/// STRICT ARCHITECTURE:
/// - Direct Cloudflare R2 Uploads via [R2UploadService].
/// - ZERO Firebase Storage uploads.
/// - NO Firebase Storage fallback (eliminates accidental Firebase Storage costs).
/// - Returns canonical relative objectKey `banners/{bannerId}/banner_....jpg`.
class R2BannerStorageRemoteDataSource implements BannerStorageRemoteDataSource {
  final R2UploadService _r2Service;

  R2BannerStorageRemoteDataSource({
    R2UploadService? r2Service,
  }) : _r2Service = r2Service ?? R2UploadService();

  @override
  Future<BannerStorageUploadResult> uploadBannerImage({
    required String bannerId,
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'jpg';
    final cleanExt = (ext == 'jpeg' || ext == 'jpg' || ext == 'png' || ext == 'webp') ? ext : 'jpg';
    final contentType = mimeType ?? 'image/$cleanExt';
    final safeId = bannerId.isNotEmpty ? bannerId : 'draft_${DateTime.now().millisecondsSinceEpoch}';

    // R2-ONLY Direct Upload: Strictly NO Firebase Storage upload or fallback
    try {
      final r2Result = await _r2Service.uploadBytes(
        bytes: bytes,
        folder: 'banners',
        fileName: fileName,
        mimeType: contentType,
        targetId: safeId,
      );

      // Return canonical relative objectKey for persistence in Firestore
      return BannerStorageUploadResult(
        downloadUrl: r2Result.objectKey,
        storagePath: r2Result.objectKey,
      );
    } catch (r2Error) {
      debugPrint('❌ [R2BannerStorageRemoteDataSource] Cloudflare R2 banner upload failed: $r2Error');
      // STRICT: Rethrow immediately without Firebase Storage fallback to prevent unwanted costs
      throw Exception('Cloudflare R2 पर बैनर इमेज अपलोड विफल रहा: ${r2Error.toString().replaceFirst("Exception: ", "")}');
    }
  }

  @override
  Future<void> deleteBannerImage(String storagePath) async {
    // Client-side direct R2 deletion is disabled for security.
    debugPrint('ℹ️ [R2BannerStorageRemoteDataSource] deleteBannerImage called for key: $storagePath');
  }
}

/// Backward compatibility alias for existing consumers
typedef FirebaseBannerStorageRemoteDataSource = R2BannerStorageRemoteDataSource;
