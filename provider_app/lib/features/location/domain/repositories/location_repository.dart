import 'package:geolocator/geolocator.dart';
import '../entities/provider_location_entity.dart';

abstract class LocationRepository {
  /// Check if location service (GPS hardware) is turned on
  Future<bool> isLocationServiceEnabled();

  /// Check permission status
  Future<LocationPermission> checkPermission();

  /// Request permission from user
  Future<LocationPermission> requestPermission();

  /// Open application system settings
  Future<bool> openAppSettings();

  /// Open device GPS/Location settings
  Future<bool> openLocationSettings();

  /// Get current real GPS location from device hardware and reverse geocode
  Future<ProviderLocationEntity> getCurrentGpsLocation({double serviceRadiusKm = 10.0});

  /// Reverse geocode given coordinates to human-readable address components
  Future<ProviderLocationEntity> reverseGeocode({
    required double latitude,
    required double longitude,
    double serviceRadiusKm = 10.0,
  });

  /// Search places by keyword query or village name (auto-suggest)
  Future<List<ProviderLocationEntity>> searchPlaces(
    String query, {
    double? providerLat,
    double? providerLng,
  });

  /// Persist confirmed provider location locally and to backend
  Future<void> saveProviderLocation(ProviderLocationEntity location, {String? providerId});

  /// Retrieve cached provider location if available
  Future<ProviderLocationEntity?> getCachedProviderLocation({String? providerId});

  /// Invalidate cached provider location
  Future<void> clearCachedProviderLocation({String? providerId});
}
