import 'dart:math' as math;

/// Production Geolocation Validator & Mathematical Engine for Jamui Services.
///
/// Enforces:
/// 1. Precision Sentinel `(0.0, 0.0)` Null Island rejection.
/// 2. NaN, Infinity, null, and mathematical out-of-range rejection.
/// 3. Validates single 0.0 values (Equator / Prime Meridian) as mathematically legal.
/// 4. Haversine distance calculation in kilometers.
/// 5. Standard Geohash encoder (precision 7: ~153m x 153m bounding box).
class JamuiGeoValidator {
  const JamuiGeoValidator._();

  static const double earthRadiusKm = 6371.0;
  static const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

  /// Validates latitude and longitude coordinates.
  ///
  /// Returns `true` if and only if:
  /// - Both values are non-null and finite (not NaN, not Infinite).
  /// - `lat` is within `[-90.0, 90.0]`.
  /// - `lng` is within `[-180.0, 180.0]`.
  /// - The pair is NOT the uninitialized Null Island sentinel `(0.0, 0.0)`.
  ///
  /// Note: A point on the Equator (`lat == 0.0, lng != 0.0`) or on the
  /// Prime Meridian (`lat != 0.0, lng == 0.0`) is mathematically valid.
  static bool isValidCoordinates(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    if (lat.isNaN || lng.isNaN) return false;
    if (lat.isInfinite || lng.isInfinite) return false;

    if (lat < -90.0 || lat > 90.0) return false;
    if (lng < -180.0 || lng > 180.0) return false;

    // Reject Null Island (0.0, 0.0) sentinel
    if (lat.abs() < 1e-7 && lng.abs() < 1e-7) {
      return false;
    }

    return true;
  }

  /// Calculates the great-circle distance between two points in kilometers
  /// using the Haversine formula.
  static double calculateHaversineDistanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final rLat1 = _toRadians(lat1);
    final rLat2 = _toRadians(lat2);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rLat1) * math.cos(rLat2) * math.sin(dLon / 2) * math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  /// Calculates displacement between two points in meters.
  static double calculateDisplacementMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return calculateHaversineDistanceKm(lat1, lon1, lat2, lon2) * 1000.0;
  }

  /// Encodes latitude and longitude into a standard Geohash string.
  ///
  /// Precision 7 produces an approximate bounding box of ~153m x ~153m.
  static String encodeGeohash(double lat, double lng, {int precision = 7}) {
    if (lat.isNaN || lng.isNaN || lat.isInfinite || lng.isInfinite) {
      return '';
    }

    final latInterval = <double>[-90.0, 90.0];
    final lngInterval = <double>[-180.0, 180.0];

    final buffer = StringBuffer();
    var isEven = true;
    var bit = 0;
    var ch = 0;

    while (buffer.length < precision) {
      if (isEven) {
        final mid = (lngInterval[0] + lngInterval[1]) / 2;
        if (lng >= mid) {
          ch |= (1 << (4 - bit));
          lngInterval[0] = mid;
        } else {
          lngInterval[1] = mid;
        }
      } else {
        final mid = (latInterval[0] + latInterval[1]) / 2;
        if (lat >= mid) {
          ch |= (1 << (4 - bit));
          latInterval[0] = mid;
        } else {
          latInterval[1] = mid;
        }
      }

      isEven = !isEven;

      if (bit < 4) {
        bit++;
      } else {
        buffer.write(_base32[ch]);
        bit = 0;
        ch = 0;
      }
    }

    return buffer.toString();
  }

  static double _toRadians(double degree) => degree * (math.pi / 180.0);
}

