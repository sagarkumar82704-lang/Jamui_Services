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

  const LocationLoading({this.message = 'आपकी वर्तमान लोकेशन खोजी जा रही है...'});

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

  const LocationLoaded({
    required this.location,
    this.isGpsLocked = true,
    required this.cameraLatitude,
    required this.cameraLongitude,
    this.zoom = 16.0,
    this.isConfirmed = false,
    this.searchResults = const [],
    this.isSearching = false,
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
      ];
}

class LocationPermissionDeniedState extends LocationState {
  final String message;

  const LocationPermissionDeniedState({
    this.message = '📍 Location permission required\nNearby services दिखाने के लिए हमें आपकी current location की आवश्यकता है।',
  });

  @override
  List<Object?> get props => [message];
}

class LocationPermissionPermanentlyDeniedState extends LocationState {
  final String message;

  const LocationPermissionPermanentlyDeniedState({
    this.message = 'Location permission बंद है। कृपया Settings में जाकर location permission enable करें।',
  });

  @override
  List<Object?> get props => [message];
}

class LocationGpsDisabledState extends LocationState {
  final String message;

  const LocationGpsDisabledState({
    this.message = 'आपका Location/GPS बंद है। कृपया इसे चालू करके दोबारा प्रयास करें।',
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
