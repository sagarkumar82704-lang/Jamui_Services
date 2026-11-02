import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'app_image_url_resolver.dart';

/// Web-safe Image Utility for Admin Panel
/// Handles Network HTTPS URLs, Base64 Data URIs, Assets, and Default Avatars
/// WITHOUT calling FileImage or breaking on Flutter Web.
class AdminImageUtils {
  /// Extract raw bytes from a data:image/...;base64,... string
  static Uint8List? _parseBase64(String path) {
    try {
      final index = path.indexOf('base64,');
      if (index != -1) {
        final base64Str = path.substring(index + 7).trim();
        return base64Decode(base64Str);
      }
    } catch (e) {
      debugPrint('AdminImageUtils: Failed to decode base64 image: $e');
    }
    return null;
  }

  /// Get an ImageProvider suitable for CircleAvatar backgroundImage
  static ImageProvider? getImageProvider(String? path) {
    if (path == null || path.trim().isEmpty) return null;
    final cleanPath = AppImageUrlResolver.resolve(path);
    if (cleanPath.isEmpty) return null;

    if (cleanPath.startsWith('http://') || cleanPath.startsWith('https://')) {
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
      // Local mobile path (e.g. /data/user/0/... or C:\...)
      // On Web, FileImage will throw, so return null to let child render fallback Avatar
      return null;
    }
  }

  /// Build a robust, Web-safe Image widget with loading and error fallbacks
  static Widget buildImage(
    String? path, {
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    final cleanPath = AppImageUrlResolver.resolve(path);
    if (cleanPath.isEmpty) {
      return errorWidget ?? _defaultPlaceholder(width, height);
    }

    if (cleanPath.startsWith('http://') || cleanPath.startsWith('https://')) {
      return Image.network(
        cleanPath,
        fit: fit,
        width: width,
        height: height,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return placeholder ??
              Center(
                child: SizedBox(
                  width: (width != null && width < 30) ? 14 : 24,
                  height: (height != null && height < 30) ? 14 : 24,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
              );
        },
        errorBuilder: (context, error, stackTrace) {
          debugPrint('AdminImageUtils: Network image load error: $error for URL: $cleanPath');
          return errorWidget ?? _defaultErrorWidget(width, height);
        },
      );
    } else if (cleanPath.startsWith('data:image/')) {
      final bytes = _parseBase64(cleanPath);
      if (bytes != null && bytes.isNotEmpty) {
        return Image.memory(
          bytes,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (context, error, stackTrace) =>
              errorWidget ?? _defaultErrorWidget(width, height),
        );
      }
      return errorWidget ?? _defaultErrorWidget(width, height);
    } else if (cleanPath.startsWith('assets/')) {
      return Image.asset(
        cleanPath,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (context, error, stackTrace) =>
            errorWidget ?? _defaultErrorWidget(width, height),
      );
    } else {
      // Local path saved from phone that hasn't been uploaded to cloud storage yet
      return errorWidget ?? _defaultLocalPathFallback(cleanPath, width, height);
    }
  }

  static Widget _defaultPlaceholder(double? width, double? height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade200,
      child: const Icon(Icons.person, color: Colors.grey, size: 24),
    );
  }

  static Widget _defaultErrorWidget(double? width, double? height) {
    return Container(
      width: width,
      height: height,
      color: Colors.red.shade50,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image_rounded, color: Colors.redAccent, size: 24),
          SizedBox(height: 4),
          Text(
            'इमेज लोड त्रुटि',
            style: TextStyle(fontSize: 10, color: Colors.redAccent),
          ),
        ],
      ),
    );
  }

  static Widget _defaultLocalPathFallback(String path, double? width, double? height) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(8),
      color: Colors.amber.shade50,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_upload_outlined, color: Colors.amber, size: 24),
          const SizedBox(height: 4),
          Text(
            'लोकल फ़ाइल (Unsynced)',
            style: TextStyle(fontSize: 10, color: Colors.amber.shade900, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  /// Extract provider profile image URL with candidates fallback chain
  static String extractProfileImageUrl(Map<String, dynamic> providerData) {
    final candidates = [
      providerData['profileImageUrl'],
      providerData['profilePhotoUrl'],
      providerData['photoUrl'],
      providerData['profilePhoto'],
      providerData['imageUrl'],
      providerData['avatar'],
    ];

    for (final cand in candidates) {
      if (cand != null && cand.toString().trim().isNotEmpty) {
        return cand.toString().trim();
      }
    }
    return '';
  }
}
