import 'package:equatable/equatable.dart';
import '../../domain/entities/customer_location_entity.dart';

abstract class LocationEvent extends Equatable {
  const LocationEvent();

  @override
  List<Object?> get props => [];
}

class FetchDeviceGpsLocationEvent extends LocationEvent {
  final bool forceRefresh;

  const FetchDeviceGpsLocationEvent({this.forceRefresh = false});

  @override
  List<Object?> get props => [forceRefresh];
}

class SelectCoordinatesEvent extends LocationEvent {
  final double latitude;
  final double longitude;
  final bool shouldReverseGeocode;

  const SelectCoordinatesEvent({
    required this.latitude,
    required this.longitude,
    this.shouldReverseGeocode = true,
  });

  @override
  List<Object?> get props => [latitude, longitude, shouldReverseGeocode];
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
  final CustomerLocationEntity location;

  const ConfirmSelectedLocationEvent(this.location);

  @override
  List<Object?> get props => [location];
}

class LoadSavedLocationEvent extends LocationEvent {
  const LoadSavedLocationEvent();
}

class SearchPlacesEvent extends LocationEvent {
  final String query;
  final double? customerLat;
  final double? customerLng;

  const SearchPlacesEvent(
    this.query, {
    this.customerLat,
    this.customerLng,
  });

  @override
  List<Object?> get props => [query, customerLat, customerLng];
}

class ClearSearchSuggestionsEvent extends LocationEvent {
  const ClearSearchSuggestionsEvent();
}

class SetExplicitLocationEvent extends LocationEvent {
  final CustomerLocationEntity location;
  final bool moveCamera;
  final double zoom;

  const SetExplicitLocationEvent({
    required this.location,
    this.moveCamera = true,
    this.zoom = 14.3,
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
