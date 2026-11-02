import 'package:geolocator/geolocator.dart';
import '../entities/customer_location_entity.dart';

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
  Future<CustomerLocationEntity> getCurrentGpsLocation();

  /// Reverse geocode given coordinates to human-readable address components
  Future<CustomerLocationEntity> reverseGeocode({
    required double latitude,
    required double longitude,
  });

  /// Search places by keyword query or village name (auto-suggest)
  Future<List<CustomerLocationEntity>> searchPlaces(
    String query, {
    double? customerLat,
    double? customerLng,
  });

  /// Persist confirmed customer location locally and to backend
  Future<void> saveCustomerLocation(CustomerLocationEntity location);

  /// Retrieve cached customer location if available
  Future<CustomerLocationEntity?> getCachedCustomerLocation();
}
