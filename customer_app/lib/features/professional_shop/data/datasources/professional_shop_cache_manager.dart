import 'dart:collection';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:apna_jamui_customer/core/utils/jamui_geo_validator.dart';
import '../../domain/entities/professional_shop_entity.dart';

/// Single cache entry storing raw category documents and fetch coordinates.
class ProfessionalShopCacheEntry {
  final String categoryId;
  final String geohash;
  final double baseLat;
  final double baseLng;
  final List<ProfessionalShopEntity> rawShops;
  final DocumentSnapshot? lastDoc;
  final bool hasMore;
  final DateTime cachedAt;

  const ProfessionalShopCacheEntry({
    required this.categoryId,
    required this.geohash,
    required this.baseLat,
    required this.baseLng,
    required this.rawShops,
    this.lastDoc,
    required this.hasMore,
    required this.cachedAt,
  });

  /// Evaluates whether the entry has exceeded the TTL duration.
  bool isExpired(Duration ttl) {
    return DateTime.now().difference(cachedAt) > ttl;
  }

  /// Evaluates whether customer has moved beyond displacement threshold in meters.
  bool isDisplaced(double currentLat, double currentLng, double thresholdMeters) {
    final displacement = JamuiGeoValidator.calculateDisplacementMeters(
      currentLat,
      currentLng,
      baseLat,
      baseLng,
    );
    return displacement > thresholdMeters;
  }
}

/// Client-Side In-Memory Cache Manager for Professional Shop Listings.
///
/// Enforces:
/// 1. Performance-only caching (Never authoritative for security or eligibility).
/// 2. Geohash-7 location-aware cache keys (`${categoryId}_${geohash7}`).
/// 3. 200-meter displacement invalidation against base coordinates.
/// 4. 5-minute Time-To-Live (TTL) eviction.
/// 5. LRU eviction bounded to 20 entries maximum.
/// 6. Forced eviction on Pull-To-Refresh.
class ProfessionalShopCacheManager {
  static const Duration defaultTtl = Duration(minutes: 5);
  static const double defaultDisplacementThresholdMeters = 200.0;
  static const int maxEntries = 20;

  // LinkedHashMap maintains insertion order for LRU eviction
  final LinkedHashMap<String, ProfessionalShopCacheEntry> _cache =
      LinkedHashMap<String, ProfessionalShopCacheEntry>();

  /// Builds a deterministic Geohash-7 based cache key.
  String buildCacheKey(String categoryId, double lat, double lng) {
    final cleanCategory = (categoryId.isEmpty || categoryId == 'all') ? 'all' : categoryId;
    final geohash = JamuiGeoValidator.isValidCoordinates(lat, lng)
        ? JamuiGeoValidator.encodeGeohash(lat, lng, precision: 7)
        : 'nogps';
    return '${cleanCategory}_$geohash';
  }

  /// Retrieves a cache entry if present, unexpired, and undisplaced.
  ///
  /// Returns `null` on cache miss, TTL expiry, or displacement > 200m.
  ProfessionalShopCacheEntry? get({
    required String categoryId,
    required double lat,
    required double lng,
    Duration ttl = defaultTtl,
    double displacementMeters = defaultDisplacementThresholdMeters,
  }) {
    final key = buildCacheKey(categoryId, lat, lng);
    final entry = _cache[key];
    if (entry == null) return null;

    // Check TTL
    if (entry.isExpired(ttl)) {
      _cache.remove(key);
      return null;
    }

    // Check 200m displacement if GPS is valid
    if (JamuiGeoValidator.isValidCoordinates(lat, lng) &&
        JamuiGeoValidator.isValidCoordinates(entry.baseLat, entry.baseLng)) {
      if (entry.isDisplaced(lat, lng, displacementMeters)) {
        _cache.remove(key);
        return null;
      }
    }

    // Refresh LRU order (re-insert at the end)
    _cache.remove(key);
    _cache[key] = entry;
    return entry;
  }

  /// Stores raw shop entities and coordinates in the cache.
  void put({
    required String categoryId,
    required double lat,
    required double lng,
    required List<ProfessionalShopEntity> rawShops,
    DocumentSnapshot? lastDoc,
    required bool hasMore,
  }) {
    final key = buildCacheKey(categoryId, lat, lng);

    // Evict oldest if LRU cap reached
    if (_cache.length >= maxEntries && !_cache.containsKey(key)) {
      _cache.remove(_cache.keys.first);
    }

    final geohash = JamuiGeoValidator.isValidCoordinates(lat, lng)
        ? JamuiGeoValidator.encodeGeohash(lat, lng, precision: 7)
        : 'nogps';

    _cache[key] = ProfessionalShopCacheEntry(
      categoryId: categoryId,
      geohash: geohash,
      baseLat: lat,
      baseLng: lng,
      rawShops: List.unmodifiable(rawShops),
      lastDoc: lastDoc,
      hasMore: hasMore,
      cachedAt: DateTime.now(),
    );
  }

  /// Forced eviction for a category (used on Pull-To-Refresh).
  void forceEvict(String categoryId) {
    final cleanCategory = (categoryId.isEmpty || categoryId == 'all') ? 'all' : categoryId;
    _cache.removeWhere((key, _) => key.startsWith('${cleanCategory}_'));
  }

  /// Clears the entire cache.
  void clearAll() {
    _cache.clear();
  }

  /// Returns current cache size (used for unit tests).
  int get size => _cache.length;
}

