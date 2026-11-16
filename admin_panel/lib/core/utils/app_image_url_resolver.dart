import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_environment.dart';

/// Centralized, non-breaking image URL resolver for Jamui Services (Admin Panel).
///
/// Resolves image paths across legacy Firebase Storage URLs, external CDN URLs,
/// inline Base64 strings, local Flutter asset paths, and future Cloudflare R2 relative keys.
class AppImageUrlResolver {
  AppImageUrlResolver._();

  static String? _overrideBaseUrl;
  static String _cachedBaseUrl = '';
  static bool _hasAttemptedFetch = false;

  /// Sets an explicit override for the image base URL (useful for testing or custom environments).
  static void setOverrideBaseUrl(String? url) {
    _overrideBaseUrl = url?.trim();
  }

  /// Sets the in-memory cached base URL directly.
  static void setBaseUrl(String url) {
    _cachedBaseUrl = url.trim();
  }

  /// Resolves the currently active image base URL.
  /// Priority:
  /// 1. Explicit override (e.g. from unit tests)
  /// 2. In-memory cached value
  /// 3. Lazy initial fetch from Firestore `app_settings/customer_app`
  /// 4. AppEnvironmentConfig.defaultImageBaseUrl (environment-aware fallback)
  static String get activeBaseUrl {
    if (_overrideBaseUrl != null) {
      return _overrideBaseUrl!;
    }
    if (_cachedBaseUrl.isNotEmpty) {
      return _cachedBaseUrl;
    }
    if (!_hasAttemptedFetch) {
      _hasAttemptedFetch = true;
      _fetchBaseUrlFromFirestore();
    }
    if (_cachedBaseUrl.isNotEmpty) {
      return _cachedBaseUrl;
    }
    return AppEnvironmentConfig.defaultImageBaseUrl;
  }

  static void _fetchBaseUrlFromFirestore() {
    try {
      FirebaseFirestore.instance
          .collection('app_settings')
          .doc('customer_app')
          .get()
          .then((doc) {
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final val = data['imageBaseUrl'] ?? data['image_base_url'];
          if (val != null && val.toString().trim().isNotEmpty) {
            _cachedBaseUrl = val.toString().trim();
          }
        }
      }).catchError((_) {});
    } catch (_) {
      // Safe fallback when Firebase is not initialized (e.g. during early startup or testing)
    }
  }

  /// Resolves any raw image URL, key, or path into a ready-to-load URI string.
  ///
  /// Rules:
  /// - Null or whitespace input -> returns empty string `""`.
  /// - Absolute HTTP/HTTPS URLs (including existing Firebase Storage download URLs) -> returns unchanged.
  /// - Base64 data URIs (`data:image/...`) -> returns unchanged.
  /// - Local Flutter asset paths (`assets/...`) -> returns unchanged.
  /// - Web blob URIs (`blob:...`) -> returns unchanged.
  /// - Relative R2 object keys (e.g. `categories/cat_1.webp`, `sponsor_banners/b1.jpg`) ->
  ///   prepends [customBaseUrl] or [activeBaseUrl] with normalized slashes.
  ///   If no base URL is configured, returns the relative key unchanged.
  static String resolve(String? rawUrl, {String? customBaseUrl}) {
    if (rawUrl == null) return '';
    final clean = rawUrl.trim();
    if (clean.isEmpty) return '';

    // 1. Keep absolute URLs, data URIs, local assets, blob URIs, and placeholder URIs unchanged
    if (clean.startsWith('http://') ||
        clean.startsWith('https://') ||
        clean.startsWith('data:image') ||
        clean.startsWith('assets/') ||
        clean.startsWith('blob:') ||
        clean.startsWith('placeholder://')) {
      return clean;
    }

    // 2. Resolve relative object key with active or custom base URL
    final base = (customBaseUrl != null && customBaseUrl.trim().isNotEmpty)
        ? customBaseUrl.trim()
        : activeBaseUrl.trim();

    if (base.isEmpty) {
      return clean;
    }

    // Normalize slashes: strip trailing slashes from base and leading slashes from key
    final normalizedBase = base.replaceAll(RegExp(r'/+$'), '');
    final normalizedKey = clean.replaceAll(RegExp(r'^/+'), '');

    return '$normalizedBase/$normalizedKey';
  }
}
