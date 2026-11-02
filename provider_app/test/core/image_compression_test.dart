import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:apna_jamui_provider/core/utils/image_compression_helper.dart';

void main() {
  group('ImageCompressionHelper Comprehensive Unit Tests', () {
    test('1. PNG to true JPEG encoding and size reduction with photographic texture', () {
      // Create photographic pattern (1200x900) with realistic smooth spatial gradients and lighting
      final original = img.Image(width: 1200, height: 900, numChannels: 4);
      for (int y = 0; y < 900; y++) {
        for (int x = 0; x < 1200; x++) {
          final r = (200 * x ~/ 1200 + 55);
          final g = (160 * y ~/ 900 + 40);
          final b = ((x * y) ~/ (1200 * 900 / 180) + 30);
          original.setPixel(x, y, img.ColorRgba8(r.clamp(0, 255), g.clamp(0, 255), b.clamp(0, 255), 255));
        }
      }

      // Encode as uncompressed PNG (representative of cropper canvas export)
      final pngBytes = Uint8List.fromList(img.encodePng(original));
      expect(pngBytes, isNotEmpty);
      expect(pngBytes[0], equals(0x89));
      expect(pngBytes[1], equals(0x50)); // 'P'
      expect(pngBytes[2], equals(0x4E)); // 'N'
      expect(pngBytes[3], equals(0x47)); // 'G'
      final int pngSize = pngBytes.lengthInBytes;

      // Compress to JPEG using ImageCompressionHelper (maxDimension: 800, quality: 80)
      final jpegBytes = ImageCompressionHelper.compressToJpeg(
        pngBytes,
        quality: 80,
        maxDimension: 800,
      );

      // Verify JPEG SOI and EOI markers
      expect(jpegBytes, isNotEmpty);
      expect(jpegBytes[0], equals(0xFF));
      expect(jpegBytes[1], equals(0xD8)); // SOI
      expect(jpegBytes[jpegBytes.length - 2], equals(0xFF));
      expect(jpegBytes[jpegBytes.length - 1], equals(0xD9)); // EOI

      final int jpegSize = jpegBytes.lengthInBytes;
      expect(jpegSize, lessThan(pngSize));

      final double savings = ((pngSize - jpegSize) / pngSize) * 100;
      print('=== MEASURED RESULT (Photographic 1200x900 to 800x600 JPEG) ===');
      print('Original PNG Size: $pngSize bytes (${(pngSize / 1024).toStringAsFixed(1)} KB)');
      print('Compressed JPEG Size: $jpegSize bytes (${(jpegSize / 1024).toStringAsFixed(1)} KB)');
      print('Savings Percentage: ${savings.toStringAsFixed(2)}%');

      // Verify decodability and aspect-ratio preservation
      final decodedJpeg = img.decodeJpg(jpegBytes);
      expect(decodedJpeg, isNotNull);
      // 1200x900 scaled with maxDimension 800 -> 800x600
      expect(decodedJpeg!.width, equals(800));
      expect(decodedJpeg.height, equals(600));
    });

    test('2. Transparent PNG handles alpha channel without black background artifacts', () {
      // 400x400 transparent circle
      final transparentImg = img.Image(width: 400, height: 400, numChannels: 4);
      final center = 200;
      final radius = 180;
      for (int y = 0; y < 400; y++) {
        for (int x = 0; x < 400; x++) {
          final distSq = (x - center) * (x - center) + (y - center) * (y - center);
          if (distSq <= radius * radius) {
            transparentImg.setPixel(x, y, img.ColorRgba8(220, 100, 50, 255));
          } else {
            // Transparent corner
            transparentImg.setPixel(x, y, img.ColorRgba8(0, 0, 0, 0));
          }
        }
      }

      final pngBytes = Uint8List.fromList(img.encodePng(transparentImg));
      final jpegBytes = ImageCompressionHelper.compressToJpeg(
        pngBytes,
        quality: 80,
        maxDimension: 800,
      );

      final decoded = img.decodeJpg(jpegBytes);
      expect(decoded, isNotNull);
      // Corner pixel (0,0) was transparent -> composited on white
      final cornerPixel = decoded!.getPixel(5, 5);
      expect(cornerPixel.r, greaterThan(240));
      expect(cornerPixel.g, greaterThan(240));
      expect(cornerPixel.b, greaterThan(240));
    });

    test('3. File-based compression creates valid temporary JPEG file', () async {
      final testImg = img.Image(width: 500, height: 500, numChannels: 3);
      img.fill(testImg, color: img.ColorRgb8(100, 150, 200));
      final pngBytes = Uint8List.fromList(img.encodePng(testImg));

      final tempDir = Directory.systemTemp;
      final srcFile = File('${tempDir.path}/test_source_${DateTime.now().millisecondsSinceEpoch}.png');
      await srcFile.writeAsBytes(pngBytes);

      final compressedFile = await ImageCompressionHelper.compressFileToJpeg(
        srcFile,
        quality: 80,
        maxDimension: 800,
      );

      expect(await compressedFile.exists(), isTrue);
      expect(compressedFile.path.endsWith('.jpg'), isTrue);

      final compBytes = await compressedFile.readAsBytes();
      expect(compBytes[0], equals(0xFF));
      expect(compBytes[1], equals(0xD8));

      // Cleanup
      await srcFile.delete();
      await compressedFile.delete();
    });

    test('4. Safe fallback on corrupt or empty bytes', () {
      final empty = Uint8List(0);
      expect(ImageCompressionHelper.compressToJpeg(empty), equals(empty));

      final corruptBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final fallback = ImageCompressionHelper.compressToJpeg(corruptBytes);
      expect(fallback, equals(corruptBytes));
    });

    test('5. High-resolution mobile camera crop (1080x1080) to 800x800 JPEG', () {
      final phonePhoto = img.Image(width: 1080, height: 1080, numChannels: 4);
      for (int y = 0; y < 1080; y++) {
        for (int x = 0; x < 1080; x++) {
          final r = (x * 255 ~/ 1080);
          final g = (y * 255 ~/ 1080);
          final b = ((x + y) * 128 ~/ 1080);
          phonePhoto.setPixel(x, y, img.ColorRgba8(r, g, b, 255));
        }
      }

      final pngBytes = Uint8List.fromList(img.encodePng(phonePhoto));
      final int originalSize = pngBytes.lengthInBytes;

      final jpegBytes = ImageCompressionHelper.compressToJpeg(
        pngBytes,
        quality: 80,
        maxDimension: 800,
      );
      final int compressedSize = jpegBytes.lengthInBytes;

      final double savings = ((originalSize - compressedSize) / originalSize) * 100;
      print('=== HIGH-RES MOBILE CAMERA CROP (1080x1080 PNG -> 800x800 JPEG) ===');
      print('Original PNG Size: $originalSize bytes (${(originalSize / 1024).toStringAsFixed(1)} KB)');
      print('Compressed JPEG Size: $compressedSize bytes (${(compressedSize / 1024).toStringAsFixed(1)} KB)');
      print('Actual Savings: ${savings.toStringAsFixed(2)}%');

      expect(compressedSize, lessThan(originalSize));
      final decoded = img.decodeJpg(jpegBytes);
      expect(decoded, isNotNull);
      expect(decoded!.width, equals(800));
      expect(decoded.height, equals(800));
    });
  });
}
