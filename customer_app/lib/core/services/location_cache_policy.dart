import '../../features/location/domain/entities/customer_location_entity.dart';

/// Centralized Location Cache & Freshness Policy
/// Eliminates unnecessary GPS and Reverse Geocoding API costs.
class LocationCachePolicy {
  /// Maximum age for cached customer location before considering background refresh (default: 6 hours)
  static const Duration maxCacheAge = Duration(hours: 6);

  /// Key used in local storage (SharedPreferences / Local DB)
  static const String locationPrefsKey = 'cached_customer_location_v2';

  /// Determines whether the cached location is valid for immediate UI rendering without GPS
  static bool isCacheValid(CustomerLocationEntity? location) {
    if (location == null) return false;
    if (location.latitude == 0.0 && location.longitude == 0.0) return false;
    if (location.placeName.trim().isEmpty) return false;
    return true;
  }

  /// Determines whether the cached location is considered fresh
  static bool isFresh(CustomerLocationEntity? location, {Duration? customMaxAge}) {
    if (!isCacheValid(location)) return false;
    final ageLimit = customMaxAge ?? maxCacheAge;
    final now = DateTime.now();
    final locationTime = location!.timestamp;
    return now.difference(locationTime) < ageLimit;
  }
}
