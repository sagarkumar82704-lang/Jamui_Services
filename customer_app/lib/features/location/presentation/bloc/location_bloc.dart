import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/services/location_cache_policy.dart';
import '../../domain/entities/customer_location_entity.dart';
import '../../domain/repositories/location_repository.dart';
import 'location_event.dart';
import 'location_state.dart';

class LocationBloc extends Bloc<LocationEvent, LocationState> {
  final LocationRepository locationRepository;
  Timer? _debounceGeocodeTimer;

  // Monotonic sequence guards to prevent stale responses from overwriting newer user selections
  int _selectionSeq = 0;
  int _gpsSeq = 0;
  int _searchSeq = 0;

  LocationBloc({required this.locationRepository}) : super(const LocationInitial()) {
    on<LoadSavedLocationEvent>(_onLoadSavedLocation);
    on<FetchDeviceGpsLocationEvent>(_onFetchDeviceGps);
    on<SelectCoordinatesEvent>(_onSelectCoordinates);
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
      final cached = await locationRepository.getCachedCustomerLocation();
      if (cached != null && cached.hasValidCoordinates) {
        emit(LocationLoaded(
          location: cached,
          isGpsLocked: false,
          cameraLatitude: cached.latitude,
          cameraLongitude: cached.longitude,
          zoom: 14.3,
          isConfirmed: true,
        ));
        // If cached location is older than max age, fetch fresh device GPS in background
        if (!LocationCachePolicy.isFresh(cached)) {
          if (kDebugMode) {
            debugPrint('🔄 [GPS_DIAG] Saved location cache is stale (>6h). Fetching fresh device GPS...');
          }
          add(const FetchDeviceGpsLocationEvent());
        }
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
    _selectionSeq++; // Invalidate pending reverse geocodes
    _gpsSeq++; // Invalidate pending GPS requests
    _searchSeq++; // Invalidate pending search requests
    emit(LocationLoaded(
      location: event.location,
      isGpsLocked: false,
      cameraLatitude: event.location.latitude,
      cameraLongitude: event.location.longitude,
      zoom: event.zoom,
      isConfirmed: false,
      searchResults: const [],
      isSearching: false,
      searchQuery: '',
      hasSearched: false,
    ));
  }

  Future<void> _onUpdateCameraCenterCoordinates(
    UpdateCameraCenterCoordinatesEvent event,
    Emitter<LocationState> emit,
  ) async {
    final currentState = state;
    if (currentState is LocationLoaded) {
      // Only track the camera center during drag — do not overwrite location pin address
      emit(currentState.copyWith(
        cameraLatitude: event.latitude,
        cameraLongitude: event.longitude,
        isGpsLocked: false,
      ));
    }
  }

  Future<void> _onSearchPlaces(
    SearchPlacesEvent event,
    Emitter<LocationState> emit,
  ) async {
    final query = event.query.trim();
    if (query.isEmpty) {
      _searchSeq++;
      if (state is LocationLoaded) {
        final current = state as LocationLoaded;
        emit(current.copyWith(
          searchResults: const [],
          isSearching: false,
          searchQuery: '',
          hasSearched: false,
          clearSearchError: true,
        ));
      }
      return;
    }

    final mySearchSeq = ++_searchSeq;
    // Prevent slow background GPS acquisition from wiping out active search results
    _gpsSeq++;

    final LocationLoaded baseState;
    if (state is LocationLoaded) {
      baseState = state as LocationLoaded;
    } else {
      final initLat = (event.customerLat != null && event.customerLat != 0.0) ? event.customerLat! : 0.0;
      final initLng = (event.customerLng != null && event.customerLng != 0.0) ? event.customerLng! : 0.0;
      baseState = LocationLoaded(
        location: CustomerLocationEntity(
          latitude: initLat,
          longitude: initLng,
          placeName: 'Select Location',
          formattedAddress: 'Tap or drag the pin to select your location',
          city: '',
          district: '',
          state: '',
          pincode: '',
          timestamp: DateTime.now(),
        ),
        isGpsLocked: false,
        cameraLatitude: initLat != 0.0 ? initLat : 24.9213,
        cameraLongitude: initLng != 0.0 ? initLng : 86.2238,
        zoom: initLat != 0.0 ? 16.0 : 13.5,
        isConfirmed: false,
      );
    }

    emit(baseState.copyWith(
      isSearching: true,
      searchQuery: query,
      hasSearched: false,
      clearSearchError: true,
    ));

    final rawLat = event.customerLat ?? baseState.location.latitude;
    final rawLng = event.customerLng ?? baseState.location.longitude;
    final double? biasLat = (rawLat != 0.0 || rawLng != 0.0) ? rawLat : null;
    final double? biasLng = (rawLat != 0.0 || rawLng != 0.0) ? rawLng : null;

    try {
      final results = await locationRepository.searchPlaces(
        query,
        customerLat: biasLat,
        customerLng: biasLng,
      );
      if (mySearchSeq != _searchSeq) return;
      final currentLoaded = state is LocationLoaded ? state as LocationLoaded : baseState;
      emit(currentLoaded.copyWith(
        searchResults: results,
        isSearching: false,
        searchQuery: query,
        hasSearched: true,
        clearSearchError: true,
      ));
    } catch (e) {
      debugPrint('⚠️ [LocationBloc] Search failed: $e');
      if (mySearchSeq != _searchSeq) return;
      final currentLoaded = state is LocationLoaded ? state as LocationLoaded : baseState;
      emit(currentLoaded.copyWith(
        searchResults: const [],
        isSearching: false,
        searchQuery: query,
        hasSearched: true,
        searchError: 'Unable to search locations. Tap to retry.',
      ));
    }
  }

  void _onClearSearchSuggestions(
    ClearSearchSuggestionsEvent event,
    Emitter<LocationState> emit,
  ) {
    _searchSeq++;
    if (state is LocationLoaded) {
      final current = state as LocationLoaded;
      emit(current.copyWith(
        searchResults: const [],
        isSearching: false,
        searchQuery: '',
        hasSearched: false,
        clearSearchError: true,
      ));
    }
  }

  Future<void> _onFetchDeviceGps(
    FetchDeviceGpsLocationEvent event,
    Emitter<LocationState> emit,
  ) async {
    final myGpsSeq = ++_gpsSeq;
    emit(const LocationLoading(message: 'Detecting your current location...'));

    try {
      // 1. Check if GPS service is enabled
      final isGpsOn = await locationRepository.isLocationServiceEnabled();
      if (myGpsSeq != _gpsSeq) return;
      if (!isGpsOn) {
        emit(const LocationGpsDisabledState());
        return;
      }

      // 2. Check Permission
      LocationPermission permission = await locationRepository.checkPermission();
      if (myGpsSeq != _gpsSeq) return;
      if (permission == LocationPermission.denied) {
        permission = await locationRepository.requestPermission();
        if (myGpsSeq != _gpsSeq) return;
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
      final location = await locationRepository.getCurrentGpsLocation();

      // Stale GPS guard: if user selected a pin or newer GPS was initiated, do not overwrite!
      if (myGpsSeq != _gpsSeq) {
        if (kDebugMode) {
          debugPrint('🗑️ [GPS_DIAG] Stale GPS fix discarded: seq $myGpsSeq != current $_gpsSeq');
        }
        return;
      }

      if (kDebugMode) {
        debugPrint('📍 [GPS_DIAG] Live Device GPS Applied: Lat=${location.latitude}, Lng=${location.longitude}, Place=${location.placeName}, Acc=±${location.accuracy}m');
      }

      emit(LocationLoaded(
        location: location,
        isGpsLocked: true,
        cameraLatitude: location.latitude,
        cameraLongitude: location.longitude,
        zoom: 14.3,
        isConfirmed: false,
      ));
    } on LocationServiceDisabledException {
      if (myGpsSeq != _gpsSeq) return;
      emit(const LocationGpsDisabledState());
    } on PermissionDeniedException catch (e) {
      if (myGpsSeq != _gpsSeq) return;
      final msg = e.message?.toLowerCase() ?? '';
      if (msg.contains('permanently') || msg.contains('हमेशा')) {
        emit(const LocationPermissionPermanentlyDeniedState());
      } else {
        emit(const LocationPermissionDeniedState());
      }
    } on TimeoutException catch (e) {
      if (myGpsSeq != _gpsSeq) return;
      emit(LocationErrorState(
        userFriendlyMessage: 'GPS signal timed out. Please move to an open area, search your location, or select on the map.',
        technicalDetails: 'GPS Timeout: ${e.message}',
      ));
    } catch (e, stack) {
      debugPrint('⚠️ [GPS_DIAG] Fetch GPS Error: $e\n$stack');
      if (myGpsSeq != _gpsSeq) return;
      emit(LocationErrorState(
        userFriendlyMessage: 'Unable to detect location. Please try again or select on the map.',
        technicalDetails: e.toString(),
      ));
    }
  }

  Future<void> _onSelectCoordinates(
    SelectCoordinatesEvent event,
    Emitter<LocationState> emit,
  ) async {
    final currentState = state;
    final currentSeq = ++_selectionSeq;

    // Invalidate background GPS requests since user is manually selecting a location
    _gpsSeq++;

    // Reset address strings for newly selected coordinates — NEVER retain previous/cached Khaira address!
    final tempLocation = CustomerLocationEntity(
      latitude: event.latitude,
      longitude: event.longitude,
      placeName: 'Detecting location...',
      formattedAddress: 'GPS: ${event.latitude.toStringAsFixed(6)}, ${event.longitude.toStringAsFixed(6)}',
      city: '',
      district: '',
      state: '',
      pincode: '',
      accuracy: null,
      timestamp: DateTime.now(),
    );

    emit(LocationLoaded(
      location: tempLocation,
      isGpsLocked: false,
      cameraLatitude: event.latitude,
      cameraLongitude: event.longitude,
      zoom: currentState is LocationLoaded ? currentState.zoom : 14.3,
      isConfirmed: false,
    ));

    if (event.shouldReverseGeocode) {
      try {
        if (kDebugMode) {
          debugPrint('📍 [GEO_DIAG] Reverse geocoding requested for Pin: Lat=${event.latitude}, Lng=${event.longitude} (Seq: $currentSeq)');
        }
        final geocoded = await locationRepository.reverseGeocode(
          latitude: event.latitude,
          longitude: event.longitude,
        );

        // Sequence guard: if user tapped another coordinate while this network request was in flight, discard!
        if (currentSeq != _selectionSeq) {
          if (kDebugMode) {
            debugPrint('🗑️ [GEO_DIAG] Stale geocode discarded: req $currentSeq != current $_selectionSeq');
          }
          return;
        }

        // If geocoded returned empty or failed, show fallback coordinate address, NEVER stale Khaira
        final resolvedLocation = geocoded.placeName.isNotEmpty
            ? geocoded
            : tempLocation.copyWith(
                placeName: 'Location detected',
                formattedAddress: 'GPS: ${event.latitude.toStringAsFixed(6)}, ${event.longitude.toStringAsFixed(6)}',
              );

        emit(LocationLoaded(
          location: resolvedLocation,
          isGpsLocked: false,
          cameraLatitude: event.latitude,
          cameraLongitude: event.longitude,
          zoom: currentState is LocationLoaded ? currentState.zoom : 14.3,
          isConfirmed: false,
        ));
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ [GEO_DIAG] Reverse geocode on selection failed: $e');
        }
        if (currentSeq == _selectionSeq) {
          emit(LocationLoaded(
            location: tempLocation.copyWith(
              placeName: 'Location detected',
              formattedAddress: 'GPS: ${event.latitude.toStringAsFixed(6)}, ${event.longitude.toStringAsFixed(6)}',
            ),
            isGpsLocked: false,
            cameraLatitude: event.latitude,
            cameraLongitude: event.longitude,
            zoom: currentState is LocationLoaded ? currentState.zoom : 14.3,
            isConfirmed: false,
          ));
        }
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
    try {
      await locationRepository.saveCustomerLocation(event.location);

      if (state is LocationLoaded) {
        final current = state as LocationLoaded;
        emit(current.copyWith(isConfirmed: true, location: event.location));
      }
    } catch (e) {
      debugPrint('⚠️ [LocationBloc] Failed to save customer location: $e');
    }
  }
}
