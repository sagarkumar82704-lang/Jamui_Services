import '../config/app_environment.dart';
import '../services/remote_config_service.dart';

/// Centralized, non-breaking image URL resolver for Jamui Services (Provider App).
///
/// Resolves image paths across legacy Firebase Storage URLs, external CDN URLs,
/// inline Base64 strings, local Flutter asset paths, and future Cloudflare R2 relative keys.
class AppImageUrlResolver {
  AppImageUrlResolver._();

  static String? _overrideBaseUrl;

  /// Sets an explicit override for the image base URL (useful for testing or scoped environments).
  static void setOverrideBaseUrl(String? url) {
    _overrideBaseUrl = url?.trim();
  }

  /// Resolves the currently active image base URL.
  /// Priority:
  /// 1. Explicit in-memory override (e.g. from unit tests)
  /// 2. RemoteConfigService.imageBaseUrl (Firestore/Remote Config synced)
  /// 3. AppEnvironmentConfig.defaultImageBaseUrl (environment-aware fallback)
  static String get activeBaseUrl {
    if (_overrideBaseUrl != null) {
      return _overrideBaseUrl!;
    }
    try {
      final configUrl = RemoteConfigService().imageBaseUrl.trim();
      if (configUrl.isNotEmpty) {
        return configUrl;
      }
    } catch (_) {}
    return AppEnvironmentConfig.defaultImageBaseUrl;
  }

  /// Resolves any raw image URL, key, or path into a ready-to-load URI string.
  ///
  /// Rules:
  /// - Null or whitespace input -> returns empty string `""`.
  /// - Absolute HTTP/HTTPS URLs (including existing Firebase Storage download URLs) -> returns unchanged.
  /// - Base64 data URIs (`data:image/...`) -> returns unchanged.
  /// - Local Flutter asset paths (`assets/...`) -> returns unchanged.
  /// - Web blob URIs (`blob:...`) -> returns unchanged.
  /// - Relative R2 object keys (e.g. `providers/uid/profile.webp`) ->
  ///   prepends [customBaseUrl] or [activeBaseUrl] with normalized slashes.
  ///   If no base URL is configured, returns the relative key unchanged.
  static String resolve(String? rawUrl, {String? customBaseUrl}) {
    if (rawUrl == null) return '';
    final clean = rawUrl.trim();
    if (clean.isEmpty) return '';

    // 1. Keep absolute URLs, data URIs, local assets, and blob URIs unchanged
    if (clean.startsWith('http://') ||
        clean.startsWith('https://') ||
        clean.startsWith('data:image') ||
        clean.startsWith('assets/') ||
        clean.startsWith('blob:')) {
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
