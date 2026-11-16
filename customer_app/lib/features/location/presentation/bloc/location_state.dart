import 'package:equatable/equatable.dart';
import '../../domain/entities/customer_location_entity.dart';

abstract class LocationState extends Equatable {
  const LocationState();

  @override
  List<Object?> get props => [];
}

class LocationInitial extends LocationState {
  const LocationInitial();
}

class LocationLoading extends LocationState {
  final String message;

  const LocationLoading({this.message = 'Detecting your current location...'});

  @override
  List<Object?> get props => [message];
}

class LocationLoaded extends LocationState {
  final CustomerLocationEntity location;
  final bool isGpsLocked;
  final double cameraLatitude;
  final double cameraLongitude;
  final double zoom;
  final bool isConfirmed;
  final List<CustomerLocationEntity> searchResults;
  final bool isSearching;
  final String searchQuery;
  final bool hasSearched;
  final String? searchError;

  const LocationLoaded({
    required this.location,
    this.isGpsLocked = true,
    required this.cameraLatitude,
    required this.cameraLongitude,
    this.zoom = 16.0,
    this.isConfirmed = false,
    this.searchResults = const [],
    this.isSearching = false,
    this.searchQuery = '',
    this.hasSearched = false,
    this.searchError,
  });

  LocationLoaded copyWith({
    CustomerLocationEntity? location,
    bool? isGpsLocked,
    double? cameraLatitude,
    double? cameraLongitude,
    double? zoom,
    bool? isConfirmed,
    List<CustomerLocationEntity>? searchResults,
    bool? isSearching,
    String? searchQuery,
    bool? hasSearched,
    String? searchError,
    bool clearSearchError = false,
  }) {
    return LocationLoaded(
      location: location ?? this.location,
      isGpsLocked: isGpsLocked ?? this.isGpsLocked,
      cameraLatitude: cameraLatitude ?? this.cameraLatitude,
      cameraLongitude: cameraLongitude ?? this.cameraLongitude,
      zoom: zoom ?? this.zoom,
      isConfirmed: isConfirmed ?? this.isConfirmed,
      searchResults: searchResults ?? this.searchResults,
      isSearching: isSearching ?? this.isSearching,
      searchQuery: searchQuery ?? this.searchQuery,
      hasSearched: hasSearched ?? this.hasSearched,
      searchError: clearSearchError ? null : (searchError ?? this.searchError),
    );
  }

  @override
  List<Object?> get props => [
        location,
        isGpsLocked,
        cameraLatitude,
        cameraLongitude,
        zoom,
        isConfirmed,
        searchResults,
        isSearching,
        searchQuery,
        hasSearched,
        searchError,
      ];
}

class LocationPermissionDeniedState extends LocationState {
  final String message;

  const LocationPermissionDeniedState({
    this.message = 'Location permission denied',
  });

  @override
  List<Object?> get props => [message];
}

class LocationPermissionPermanentlyDeniedState extends LocationState {
  final String message;

  const LocationPermissionPermanentlyDeniedState({
    this.message = 'Location permission denied',
  });

  @override
  List<Object?> get props => [message];
}

class LocationGpsDisabledState extends LocationState {
  final String message;

  const LocationGpsDisabledState({
    this.message = 'Enable GPS to detect your location',
  });

  @override
  List<Object?> get props => [message];
}

class LocationErrorState extends LocationState {
  final String userFriendlyMessage;
  final String technicalDetails;

  const LocationErrorState({
    required this.userFriendlyMessage,
    required this.technicalDetails,
  });

  @override
  List<Object?> get props => [userFriendlyMessage, technicalDetails];
}
