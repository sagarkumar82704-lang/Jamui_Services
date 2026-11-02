import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'app_image_url_resolver.dart';

class AppImageUtils {
  static Uint8List? _parseBase64(String path) {
    try {
      final index = path.indexOf('base64,');
      if (index != -1) {
        final base64Str = path.substring(index + 7).trim();
        return base64Decode(base64Str);
      }
    } catch (e) {
      debugPrint('AppImageUtils: Failed to decode base64 image: $e');
    }
    return null;
  }

  static ImageProvider? getImageProvider(String path) {
    if (path.trim().isEmpty) return null;
    final cleanPath = AppImageUrlResolver.resolve(path);
    if (cleanPath.startsWith('http://') || cleanPath.startsWith('https://') || cleanPath.startsWith('blob:')) {
      return NetworkImage(cleanPath);
    } else if (cleanPath.startsWith('data:image/')) {
      final bytes = _parseBase64(cleanPath);
      if (bytes != null && bytes.isNotEmpty) {
        return MemoryImage(bytes);
      }
      return null;
    } else if (cleanPath.startsWith('assets/')) {
      return AssetImage(cleanPath);
    } else {
      if (kIsWeb) {
        return NetworkImage(cleanPath);
      }
      return FileImage(File(cleanPath));
    }
  }

  static Widget buildImage(
    String path, {
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
    Widget? errorWidget,
  }) {
    final cleanPath = AppImageUrlResolver.resolve(path);
    if (cleanPath.isEmpty) {
      return errorWidget ?? const Icon(Icons.image_not_supported, size: 40);
    }
    if (cleanPath.startsWith('http://') || cleanPath.startsWith('https://') || cleanPath.startsWith('blob:')) {
      return Image.network(
        cleanPath,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (c, e, s) => errorWidget ?? const Icon(Icons.broken_image, size: 40),
      );
    } else if (cleanPath.startsWith('data:image/')) {
      final bytes = _parseBase64(cleanPath);
      if (bytes != null && bytes.isNotEmpty) {
        return Image.memory(
          bytes,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (c, e, s) => errorWidget ?? const Icon(Icons.broken_image, size: 40),
        );
      }
      return errorWidget ?? const Icon(Icons.broken_image, size: 40);
    } else if (cleanPath.startsWith('assets/')) {
      return Image.asset(
        cleanPath,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (c, e, s) => errorWidget ?? const Icon(Icons.image_not_supported, size: 40),
      );
    } else {
      if (kIsWeb) {
        return Image.network(
          cleanPath,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (c, e, s) => errorWidget ?? const Icon(Icons.broken_image, size: 40),
        );
      }
      return Image.file(
        File(cleanPath),
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (c, e, s) => errorWidget ?? const Icon(Icons.broken_image, size: 40),
      );
    }
  }
}

