import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import '../../data/datasources/location_remote_data_source.dart';
import '../../domain/entities/provider_location_entity.dart';
import '../../domain/repositories/location_repository.dart';
import 'location_event.dart';
import 'location_state.dart';

class LocationBloc extends Bloc<LocationEvent, LocationState> {
  final LocationRepository locationRepository;
  Timer? _debounceGeocodeTimer;

  LocationBloc({required this.locationRepository}) : super(const LocationInitial()) {
    on<LoadSavedLocationEvent>(_onLoadSavedLocation);
    on<FetchDeviceGpsLocationEvent>(_onFetchDeviceGps);
    on<SelectCoordinatesEvent>(_onSelectCoordinates);
    on<UpdateServiceRadiusEvent>(_onUpdateServiceRadius);
    on<SetExplicitLocationEvent>(_onSetExplicitLocation);
    on<UpdateCameraCenterCoordinatesEvent>(_onUpdateCameraCenterCoordinates);
    on<RequestLocationPermissionEvent>(_onRequestPermission);
    on<OpenGpsSettingsEvent>(_onOpenGpsSettings);
    on<OpenAppSettingsEvent>(_onOpenAppSettings);
    on<ConfirmSelectedLocationEvent>(_onConfirmSelectedLocation);
    on<SearchPlacesEvent>(_onSearchPlaces);
    on<ClearSearchSuggestionsEvent>(_onClearSearchSuggestions);
  }

  @override
  Future<void> close() {
    _debounceGeocodeTimer?.cancel();
    return super.close();
  }

  Future<void> _onLoadSavedLocation(
    LoadSavedLocationEvent event,
    Emitter<LocationState> emit,
  ) async {
    try {
      final cached = await locationRepository.getCachedProviderLocation(providerId: event.providerId);
      if (cached != null && cached.hasValidCoordinates) {
        emit(LocationLoaded(
          location: cached,
          isGpsLocked: false,
          cameraLatitude: cached.latitude,
          cameraLongitude: cached.longitude,
          zoom: 16.0,
          isConfirmed: false,
        ));
      } else {
        add(const FetchDeviceGpsLocationEvent());
      }
    } catch (e) {
      add(const FetchDeviceGpsLocationEvent());
    }
  }

  Future<void> _onSetExplicitLocation(
    SetExplicitLocationEvent event,
    Emitter<LocationState> emit,
  ) async {
    _debounceGeocodeTimer?.cancel();
    emit(LocationLoaded(
      location: event.location,
      isGpsLocked: false,
      cameraLatitude: event.location.latitude,
      cameraLongitude: event.location.longitude,
      zoom: event.zoom,
      isConfirmed: false,
      searchResults: const [],
      isSearching: false,
    ));
  }

  Future<void> _onUpdateCameraCenterCoordinates(
    UpdateCameraCenterCoordinatesEvent event,
    Emitter<LocationState> emit,
  ) async {
    final currentState = state;
    if (currentState is LocationLoaded) {
      final updatedLocation = currentState.location.copyWith(
        latitude: event.latitude,
        longitude: event.longitude,
      );
      emit(currentState.copyWith(
        location: updatedLocation,
        cameraLatitude: event.latitude,
        cameraLongitude: event.longitude,
      ));
    }
  }

  void _onUpdateServiceRadius(
    UpdateServiceRadiusEvent event,
    Emitter<LocationState> emit,
  ) {
    if (state is LocationLoaded) {
      final current = state as LocationLoaded;
      final updatedLocation = current.location.copyWith(
        serviceRadiusKm: event.serviceRadiusKm,
      );
      emit(current.copyWith(location: updatedLocation));
    }
  }

  Future<void> _onSearchPlaces(
    SearchPlacesEvent event,
    Emitter<LocationState> emit,
  ) async {
    final query = event.query.trim();
    if (query.isEmpty) {
      if (state is LocationLoaded) {
        final current = state as LocationLoaded;
        emit(current.copyWith(searchResults: [], isSearching: false));
      }
      return;
    }

    if (state is LocationLoaded) {
      final current = state as LocationLoaded;
      emit(current.copyWith(isSearching: true));

      final biasLat = event.providerLat ?? current.location.latitude;
      final biasLng = event.providerLng ?? current.location.longitude;

      try {
        final results = await locationRepository.searchPlaces(
          query,
          providerLat: biasLat,
          providerLng: biasLng,
        );
        emit(current.copyWith(searchResults: results, isSearching: false));
      } catch (e) {
        debugPrint('⚠️ [LocationBloc] Search failed: $e');
        emit(current.copyWith(searchResults: [], isSearching: false));
      }
    }
  }

  void _onClearSearchSuggestions(
    ClearSearchSuggestionsEvent event,
    Emitter<LocationState> emit,
  ) {
    if (state is LocationLoaded) {
      final current = state as LocationLoaded;
      emit(current.copyWith(searchResults: [], isSearching: false));
    }
  }

  Future<void> _onFetchDeviceGps(
    FetchDeviceGpsLocationEvent event,
    Emitter<LocationState> emit,
  ) async {
    emit(const LocationLoading(message: 'GPS से वास्तविक स्थान खोजा जा रहा है...'));

    try {
      // 1. Check if GPS hardware service is enabled
      final isGpsOn = await locationRepository.isLocationServiceEnabled();
      if (!isGpsOn) {
        emit(const LocationGpsDisabledState());
        return;
      }

      // 2. Check Permission
      LocationPermission permission = await locationRepository.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await locationRepository.requestPermission();
        if (permission == LocationPermission.denied) {
          emit(const LocationPermissionDeniedState());
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        emit(const LocationPermissionPermanentlyDeniedState());
        return;
      }

      // 3. Fetch real GPS position & reverse geocode
      final location = await locationRepository.getCurrentGpsLocation(serviceRadiusKm: event.serviceRadiusKm);

      emit(LocationLoaded(
        location: location,
        isGpsLocked: true,
        cameraLatitude: location.latitude,
        cameraLongitude: location.longitude,
        zoom: 16.5,
        isConfirmed: false,
      ));
    } on InaccurateLocationException catch (e) {
      emit(LocationErrorState(
        userFriendlyMessage: e.message,
        technicalDetails: 'GPS Accuracy low: ±${e.accuracy.toStringAsFixed(1)}m (>150m)',
      ));
    } on LocationServiceDisabledException {
      emit(const LocationGpsDisabledState());
    } on PermissionDeniedException catch (e) {
      if (e.message?.contains('हमेशा') ?? false) {
        emit(const LocationPermissionPermanentlyDeniedState());
      } else {
        emit(const LocationPermissionDeniedState());
      }
    } on TimeoutException catch (e) {
      emit(LocationErrorState(
        userFriendlyMessage: 'GPS सिग्नल मिलने में 25 सेकंड से अधिक समय लग रहा है। कृपया खुले स्थान में जाएं या मैप पर स्थान चुनें।',
        technicalDetails: 'GPS Timeout: ${e.message}',
      ));
    } catch (e, stack) {
      debugPrint('⚠️ [LocationBloc] Fetch GPS Error: $e\n$stack');
      emit(LocationErrorState(
        userFriendlyMessage: 'लोकेशन प्राप्त करने में त्रुटि हुई। कृपया दोबारा प्रयास करें।',
        technicalDetails: e.toString(),
      ));
    }
  }

  Future<void> _onSelectCoordinates(
    SelectCoordinatesEvent event,
    Emitter<LocationState> emit,
  ) async {
    final currentState = state;
    ProviderLocationEntity tempLocation;

    if (currentState is LocationLoaded) {
      tempLocation = currentState.location.copyWith(
        latitude: event.latitude,
        longitude: event.longitude,
        serviceRadiusKm: event.serviceRadiusKm,
        source: 'manual_pin',
      );
    } else {
      tempLocation = ProviderLocationEntity(
        latitude: event.latitude,
        longitude: event.longitude,
        placeName: 'चयनित स्थान',
        formattedAddress: 'Lat: ${event.latitude.toStringAsFixed(6)}, Lng: ${event.longitude.toStringAsFixed(6)}',
        city: '',
        district: '',
        state: '',
        pincode: '',
        serviceRadiusKm: event.serviceRadiusKm,
        timestamp: DateTime.now(),
        source: 'manual_pin',
      );
    }

    emit(LocationLoaded(
      location: tempLocation,
      isGpsLocked: false,
      cameraLatitude: event.latitude,
      cameraLongitude: event.longitude,
      zoom: currentState is LocationLoaded ? currentState.zoom : 16.5,
      isConfirmed: false,
    ));

    if (event.shouldReverseGeocode) {
      try {
        final geocoded = await locationRepository.reverseGeocode(
          latitude: event.latitude,
          longitude: event.longitude,
          serviceRadiusKm: event.serviceRadiusKm,
        );

        if (geocoded.placeName.isEmpty) return;

        emit(LocationLoaded(
          location: geocoded.copyWith(source: 'manual_pin'),
          isGpsLocked: false,
          cameraLatitude: event.latitude,
          cameraLongitude: event.longitude,
          zoom: currentState is LocationLoaded ? currentState.zoom : 16.5,
          isConfirmed: false,
        ));
      } catch (e) {
        debugPrint('⚠️ [LocationBloc] Reverse geocode on selection failed: $e');
      }
    }
  }

  Future<void> _onRequestPermission(
    RequestLocationPermissionEvent event,
    Emitter<LocationState> emit,
  ) async {
    final permission = await locationRepository.requestPermission();
    if (permission == LocationPermission.denied) {
      emit(const LocationPermissionDeniedState());
    } else if (permission == LocationPermission.deniedForever) {
      emit(const LocationPermissionPermanentlyDeniedState());
    } else {
      add(const FetchDeviceGpsLocationEvent(forceRefresh: true));
    }
  }

  Future<void> _onOpenGpsSettings(
    OpenGpsSettingsEvent event,
    Emitter<LocationState> emit,
  ) async {
    await locationRepository.openLocationSettings();
  }

  Future<void> _onOpenAppSettings(
    OpenAppSettingsEvent event,
    Emitter<LocationState> emit,
  ) async {
    await locationRepository.openAppSettings();
  }

  Future<void> _onConfirmSelectedLocation(
    ConfirmSelectedLocationEvent event,
    Emitter<LocationState> emit,
  ) async {
    // Strict accuracy check: accuracy > 150m rejected unless confirmed via manual map pin
    if (event.location.accuracy != null &&
        event.location.accuracy! > 150.0 &&
        event.location.source != 'manual_pin') {
      emit(const LocationErrorState(
        userFriendlyMessage: 'आपकी GPS Location अभी सटीक नहीं मिल रही है। कृपया खुले स्थान पर जाएँ और दोबारा Location Fetch करें। आप Map पर Pin Adjust भी कर सकते हैं।',
        technicalDetails: 'Accuracy > 150m cannot be auto-confirmed without manual map pin placement.',
      ));
      return;
    }

    try {
      await locationRepository.saveProviderLocation(event.location, providerId: event.providerId);

      if (state is LocationLoaded) {
        final current = state as LocationLoaded;
        emit(current.copyWith(isConfirmed: true, location: event.location));
      }
    } catch (e) {
      debugPrint('⚠️ [LocationBloc] Failed to save provider location: $e');
      emit(LocationErrorState(
        userFriendlyMessage: 'लोकेशन सेव करने में समस्या हुई: $e',
        technicalDetails: e.toString(),
      ));
    }
  }
}
