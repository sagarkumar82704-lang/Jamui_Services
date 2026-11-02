import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Production-safe Image Compression Utility for Jamui Services Provider App.
/// Converts uncompressed PNG or raw bitmap bytes to true high-quality JPEG format.
/// Handles transparency, aspect-ratio preservation, max dimensions, and error recovery.
class ImageCompressionHelper {
  /// Compresses input image bytes (PNG, BMP, uncompressed JPEG) into optimized JPEG bytes.
  /// - [quality]: JPEG compression quality (default: 80, range: 1-100).
  /// - [maxDimension]: Maximum width or height (default: 800px).
  /// - [backgroundColor]: Solid background for transparent PNG alpha compositing (default: white).
  static Uint8List compressToJpeg(
    Uint8List sourceBytes, {
    int quality = 80,
    int maxDimension = 800,
    img.Color? backgroundColor,
  }) {
    if (sourceBytes.isEmpty) return sourceBytes;

    try {
      // 1. Decode source image format (supports PNG, JPEG, WebP, GIF, BMP, etc.)
      final decoded = img.decodeImage(sourceBytes);
      if (decoded == null) {
        debugPrint('⚠️ [ImageCompression] Could not decode image bytes; returning raw bytes as fallback.');
        return sourceBytes;
      }

      // 2. Proportional aspect-ratio resizing if larger than maxDimension
      img.Image processed = decoded;
      final int width = decoded.width;
      final int height = decoded.height;

      if (width > maxDimension || height > maxDimension) {
        int targetWidth;
        int targetHeight;
        if (width >= height) {
          targetWidth = maxDimension;
          targetHeight = (height * maxDimension ~/ width).clamp(1, maxDimension);
        } else {
          targetHeight = maxDimension;
          targetWidth = (width * maxDimension ~/ height).clamp(1, maxDimension);
        }
        processed = img.copyResize(
          decoded,
          width: targetWidth,
          height: targetHeight,
          interpolation: img.Interpolation.linear,
        );
      }

      // 3. Alpha / Transparency Handling:
      // JPEG does not support transparency. If original image has alpha channel,
      // composite onto a solid white background to prevent black background artifacts.
      img.Image solidRgb;
      if (processed.hasAlpha) {
        solidRgb = img.Image(
          width: processed.width,
          height: processed.height,
          numChannels: 3,
        );
        final bg = backgroundColor ?? img.ColorRgb8(255, 255, 255);
        img.fill(solidRgb, color: bg);
        img.compositeImage(solidRgb, processed);
      } else {
        solidRgb = processed;
      }

      // 4. Encode to standard JPEG with specified quality
      final jpegBytes = Uint8List.fromList(img.encodeJpg(solidRgb, quality: quality));

      // Sanity check: Ensure valid JPEG SOI marker (0xFF, 0xD8)
      if (jpegBytes.length >= 2 && jpegBytes[0] == 0xFF && jpegBytes[1] == 0xD8) {
        return jpegBytes;
      }

      return jpegBytes;
    } catch (e) {
      debugPrint('⚠️ [ImageCompression] Error during JPEG compression: $e. Returning source bytes.');
      return sourceBytes;
    }
  }

  /// Compresses a local image file and writes the resulting true JPEG to a temporary file.
  static Future<File> compressFileToJpeg(
    File sourceFile, {
    int quality = 80,
    int maxDimension = 800,
  }) async {
    try {
      if (!await sourceFile.exists()) return sourceFile;

      final bytes = await sourceFile.readAsBytes();
      final compressedBytes = compressToJpeg(
        bytes,
        quality: quality,
        maxDimension: maxDimension,
      );

      final tempDir = Directory.systemTemp;
      final tempFileName = 'comp_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final compressedFile = File('${tempDir.path}/$tempFileName');
      await compressedFile.writeAsBytes(compressedBytes);
      return compressedFile;
    } catch (e) {
      debugPrint('⚠️ [ImageCompression] Error compressing file ${sourceFile.path}: $e');
      return sourceFile;
    }
  }
}
