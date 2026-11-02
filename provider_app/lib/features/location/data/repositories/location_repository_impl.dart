import 'package:geolocator/geolocator.dart';
import '../../domain/entities/provider_location_entity.dart';
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
  Future<ProviderLocationEntity> getCurrentGpsLocation({double serviceRadiusKm = 10.0}) async {
    final position = await remoteDataSource.getCurrentPosition();
    return await remoteDataSource.reverseGeocode(
      position.latitude,
      position.longitude,
      accuracy: position.accuracy,
      serviceRadiusKm: serviceRadiusKm,
    );
  }

  @override
  Future<ProviderLocationEntity> reverseGeocode({
    required double latitude,
    required double longitude,
    double serviceRadiusKm = 10.0,
  }) async {
    return await remoteDataSource.reverseGeocode(
      latitude,
      longitude,
      serviceRadiusKm: serviceRadiusKm,
    );
  }

  @override
  Future<List<ProviderLocationEntity>> searchPlaces(
    String query, {
    double? providerLat,
    double? providerLng,
  }) async {
    return await remoteDataSource.searchPlaces(
      query,
      providerLat: providerLat,
      providerLng: providerLng,
    );
  }

  @override
  Future<void> saveProviderLocation(ProviderLocationEntity location, {String? providerId}) async {
    await localDataSource.cacheLocation(location, providerId: providerId);
  }

  @override
  Future<ProviderLocationEntity?> getCachedProviderLocation({String? providerId}) async {
    return await localDataSource.getCachedLocation(providerId: providerId);
  }

  @override
  Future<void> clearCachedProviderLocation({String? providerId}) async {
    await localDataSource.clearCachedLocation(providerId: providerId);
  }
}
