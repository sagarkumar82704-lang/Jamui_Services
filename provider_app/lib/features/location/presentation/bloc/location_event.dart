import 'package:equatable/equatable.dart';
import '../../domain/entities/provider_location_entity.dart';

abstract class LocationEvent extends Equatable {
  const LocationEvent();

  @override
  List<Object?> get props => [];
}

class FetchDeviceGpsLocationEvent extends LocationEvent {
  final bool forceRefresh;
  final double serviceRadiusKm;

  const FetchDeviceGpsLocationEvent({this.forceRefresh = false, this.serviceRadiusKm = 10.0});

  @override
  List<Object?> get props => [forceRefresh, serviceRadiusKm];
}

class SelectCoordinatesEvent extends LocationEvent {
  final double latitude;
  final double longitude;
  final bool shouldReverseGeocode;
  final double serviceRadiusKm;

  const SelectCoordinatesEvent({
    required this.latitude,
    required this.longitude,
    this.shouldReverseGeocode = true,
    this.serviceRadiusKm = 10.0,
  });

  @override
  List<Object?> get props => [latitude, longitude, shouldReverseGeocode, serviceRadiusKm];
}

class UpdateServiceRadiusEvent extends LocationEvent {
  final double serviceRadiusKm;

  const UpdateServiceRadiusEvent(this.serviceRadiusKm);

  @override
  List<Object?> get props => [serviceRadiusKm];
}

class RequestLocationPermissionEvent extends LocationEvent {
  const RequestLocationPermissionEvent();
}

class OpenGpsSettingsEvent extends LocationEvent {
  const OpenGpsSettingsEvent();
}

class OpenAppSettingsEvent extends LocationEvent {
  const OpenAppSettingsEvent();
}

class ConfirmSelectedLocationEvent extends LocationEvent {
  final ProviderLocationEntity location;
  final String? providerId;

  const ConfirmSelectedLocationEvent(this.location, {this.providerId});

  @override
  List<Object?> get props => [location, providerId];
}

class LoadSavedLocationEvent extends LocationEvent {
  final String? providerId;

  const LoadSavedLocationEvent({this.providerId});

  @override
  List<Object?> get props => [providerId];
}

class SearchPlacesEvent extends LocationEvent {
  final String query;
  final double? providerLat;
  final double? providerLng;

  const SearchPlacesEvent(
    this.query, {
    this.providerLat,
    this.providerLng,
  });

  @override
  List<Object?> get props => [query, providerLat, providerLng];
}

class ClearSearchSuggestionsEvent extends LocationEvent {
  const ClearSearchSuggestionsEvent();
}

class SetExplicitLocationEvent extends LocationEvent {
  final ProviderLocationEntity location;
  final bool moveCamera;
  final double zoom;

  const SetExplicitLocationEvent({
    required this.location,
    this.moveCamera = true,
    this.zoom = 16.5,
  });

  @override
  List<Object?> get props => [location, moveCamera, zoom];
}

class UpdateCameraCenterCoordinatesEvent extends LocationEvent {
  final double latitude;
  final double longitude;

  const UpdateCameraCenterCoordinatesEvent({
    required this.latitude,
    required this.longitude,
  });

  @override
  List<Object?> get props => [latitude, longitude];
}
