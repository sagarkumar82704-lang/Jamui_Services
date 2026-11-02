import 'package:geolocator/geolocator.dart';
import '../../domain/entities/customer_location_entity.dart';
import '../../domain/repositories/location_repository.dart';
import '../datasources/location_local_data_source.dart';
import '../datasources/location_remote_data_source.dart';

class LocationRepositoryImpl implements LocationRepository {
  final LocationRemoteDataSource remoteDataSource;
  final LocationLocalDataSource localDataSource;

  LocationRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<bool> isLocationServiceEnabled() async {
    return await remoteDataSource.isLocationServiceEnabled();
  }

  @override
  Future<LocationPermission> checkPermission() async {
    return await remoteDataSource.checkPermission();
  }

  @override
  Future<LocationPermission> requestPermission() async {
    return await remoteDataSource.requestPermission();
  }

  @override
  Future<bool> openAppSettings() async {
    return await remoteDataSource.openAppSettings();
  }

  @override
  Future<bool> openLocationSettings() async {
    return await remoteDataSource.openLocationSettings();
  }

  @override
  Future<CustomerLocationEntity> getCurrentGpsLocation() async {
    final position = await remoteDataSource.getCurrentPosition();
    return await remoteDataSource.reverseGeocode(
      position.latitude,
      position.longitude,
      accuracy: position.accuracy,
    );
  }

  @override
  Future<CustomerLocationEntity> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    return await remoteDataSource.reverseGeocode(latitude, longitude);
  }

  @override
  Future<List<CustomerLocationEntity>> searchPlaces(
    String query, {
    double? customerLat,
    double? customerLng,
  }) async {
    return await remoteDataSource.searchPlaces(
      query,
      customerLat: customerLat,
      customerLng: customerLng,
    );
  }

  @override
  Future<void> saveCustomerLocation(CustomerLocationEntity location) async {
    await localDataSource.cacheLocation(location);
  }

  @override
  Future<CustomerLocationEntity?> getCachedCustomerLocation() async {
    return await localDataSource.getCachedLocation();
  }
}
