import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../location/data/datasources/location_remote_data_source.dart';
import '../../../location/domain/entities/provider_location_entity.dart';
import '../../data/datasources/professional_provider_remote_data_source.dart';
import '../../domain/entities/professional_shop_profile_entity.dart';

enum StoreLocationMethod {
  currentLocation,
  googleMapPin,
  manualLatLng,
}

class StoreLocationSelectionResult {
  final double latitude;
  final double longitude;
  final String fullAddress;
  final String jamuiArea;
  final String landmark;
  final String locationSource;
  final bool isLocationApproximate;

  const StoreLocationSelectionResult({
    required this.latitude,
    required this.longitude,
    required this.fullAddress,
    required this.jamuiArea,
    required this.landmark,
    required this.locationSource,
    required this.isLocationApproximate,
  });
}

class ProfessionalSetStoreLocationPage extends StatefulWidget {
  final ProfessionalShopProfileEntity shop;
  final LocationRemoteDataSource? locationDataSource;
  final ProfessionalProviderRemoteDataSource? shopDataSource;
  final bool persistImmediately;

  const ProfessionalSetStoreLocationPage({
    super.key,
    required this.shop,
    this.locationDataSource,
    this.shopDataSource,
    this.persistImmediately = true,
  });

  @override
  State<ProfessionalSetStoreLocationPage> createState() =>
      _ProfessionalSetStoreLocationPageState();
}

class _ProfessionalSetStoreLocationPageState
    extends State<ProfessionalSetStoreLocationPage> {
  static const Color _primaryGreen = Color(0xFF15803D);
  static const Color _darkGreenHeader = Color(0xFF0B4F26);
  static const LatLng _defaultMapCenter = LatLng(24.9195, 86.2208);

  late final LocationRemoteDataSource _locationDs;
  late final ProfessionalProviderRemoteDataSource _shopDs;
  final MapController _mapController = MapController();

  StoreLocationMethod _selectedMethod = StoreLocationMethod.currentLocation;

  // Map layer switcher ('m' = Standard Roadmap, 'y' = Hybrid Satellite, 'p' = Terrain)
  String _mapLayerCode = 'm';

  // Existing saved shop location (never overwritten automatically on screen open)
  late final bool _hasSavedCoordinates;
  late final double? _savedLatitude;
  late final double? _savedLongitude;
  late final String _savedAddress;
  late final String _savedLandmark;
  late final String _savedArea;

  // Option A — Current GPS state
  bool _isFetchingGps = false;
  String? _gpsError;
  bool _isGpsPermissionDeniedForever = false;
  bool _isGpsServiceDisabled = false;
  double? _gpsAccuracyMeters;
  double? _optionALat;
  double? _optionALng;
  StoreReverseGeocodeResult? _optionAGeocode;

  // Option B — Select on Google Map state
  late LatLng _mapPinPosition;
  bool _isMapReverseGeocoding = false;
  StoreReverseGeocodeResult? _optionBGeocode;
  final TextEditingController _mapSearchController = TextEditingController();
  Timer? _searchDebounce;
  Timer? _mapMoveDebounce;
  bool _isSearchingPlaces = false;
  List<ProviderLocationEntity> _placeSearchResults = const [];

  // Option C — Manual Latitude & Longitude state
  late final TextEditingController _manualLatController;
  late final TextEditingController _manualLngController;
  String? _manualLatError;
  String? _manualLngError;
  String? _manualGeneralError;
  bool _isManualGeocoding = false;
  StoreReverseGeocodeResult? _optionCGeocode;
  bool _showManualMapPreview = false;

  // Shared Landmark & Editable Address refinement
  late final TextEditingController _landmarkController;
  late final TextEditingController _areaController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _locationDs = widget.locationDataSource ?? LocationRemoteDataSourceImpl();
    _shopDs =
        widget.shopDataSource ?? ProfessionalProviderRemoteDataSource();

    final rawLat = widget.shop.latitude;
    final rawLng = widget.shop.longitude;
    _hasSavedCoordinates =
        StoreCoordinateValidator.isValidNumbers(rawLat, rawLng);
    _savedLatitude = _hasSavedCoordinates ? rawLat : null;
    _savedLongitude = _hasSavedCoordinates ? rawLng : null;
    _savedAddress = widget.shop.fullAddress.trim();
    _savedLandmark = widget.shop.landmark.trim();
    _savedArea = widget.shop.jamuiArea.trim();

    _mapPinPosition = _hasSavedCoordinates
        ? LatLng(_savedLatitude!, _savedLongitude!)
        : _defaultMapCenter;

    _manualLatController = TextEditingController(
      text: _hasSavedCoordinates ? _savedLatitude!.toStringAsFixed(6) : '',
    );
    _manualLngController = TextEditingController(
      text: _hasSavedCoordinates ? _savedLongitude!.toStringAsFixed(6) : '',
    );
    _landmarkController = TextEditingController(text: _savedLandmark);
    _areaController = TextEditingController(text: _savedArea);

    if (widget.shop.locationSource == 'manual_lat_lng') {
      _selectedMethod = StoreLocationMethod.manualLatLng;
    } else if (widget.shop.locationSource == 'google_map_pin') {
      _selectedMethod = StoreLocationMethod.googleMapPin;
    } else {
      _selectedMethod = StoreLocationMethod.currentLocation;
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _mapMoveDebounce?.cancel();
    _mapSearchController.dispose();
    _manualLatController.dispose();
    _manualLngController.dispose();
    _landmarkController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // OPTION A — USE CURRENT LOCATION
  // ===========================================================================

  Future<void> _fetchCurrentGpsLocation() async {
    setState(() {
      _isFetchingGps = true;
      _gpsError = null;
      _isGpsPermissionDeniedForever = false;
      _isGpsServiceDisabled = false;
    });

    try {
      final pos = await _locationDs.getCurrentPosition();
      if (!mounted) return;

      final geocode = await _locationDs.reverseGeocodeForStoreLocation(
        pos.latitude,
        pos.longitude,
        accuracy: pos.accuracy,
      );
      if (!mounted) return;

      setState(() {
        _optionALat = pos.latitude;
        _optionALng = pos.longitude;
        _gpsAccuracyMeters = pos.accuracy;
        _optionAGeocode = geocode;
        if (_areaController.text.trim().isEmpty && geocode.area.isNotEmpty) {
          _areaController.text = geocode.area;
        }
        _isFetchingGps = false;
      });

      try {
        _mapController.move(LatLng(pos.latitude, pos.longitude), 17.0);
      } catch (_) {}
    } on LocationServiceDisabledException {
      if (!mounted) return;
      setState(() {
        _isFetchingGps = false;
        _isGpsServiceDisabled = true;
        _gpsError =
            'Device GPS / Location Service is disabled. Please enable GPS or use Map / Manual Coordinates.';
      });
    } on PermissionDeniedException catch (e) {
      final perm = await _locationDs.checkPermission();
      if (!mounted) return;
      setState(() {
        _isFetchingGps = false;
        _isGpsPermissionDeniedForever =
            perm == LocationPermission.deniedForever;
        _gpsError = e.message?.trim().isNotEmpty == true
            ? e.message!
            : 'Location permission was denied. Please grant location permission to fetch current GPS coordinates.';
      });
    } on InaccurateLocationException catch (e) {
      if (!mounted) return;
      setState(() {
        _isFetchingGps = false;
        _gpsAccuracyMeters = e.accuracy;
        _gpsError =
            'GPS signal is inaccurate (±${e.accuracy.toStringAsFixed(0)}m). Move to an open area and retry, or select exact shop entrance on Map / Manual Lat-Lng.';
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _isFetchingGps = false;
        _gpsError =
            'Timed out while acquiring GPS signal. Please retry or use Select on Google Map / Manual Coordinates.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isFetchingGps = false;
        _gpsError = 'Could not fetch current GPS location: $e';
      });
    }
  }

  // ===========================================================================
  // OPTION B — SELECT ON GOOGLE MAP
  // ===========================================================================

  void _onMapPositionChanged(LatLng newCenter) {
    setState(() {
      _mapPinPosition = newCenter;
    });
    _mapMoveDebounce?.cancel();
    _mapMoveDebounce = Timer(const Duration(milliseconds: 550), () {
      _reverseGeocodeMapPin(newCenter);
    });
  }

  Future<void> _reverseGeocodeMapPin(LatLng target) async {
    if (!StoreCoordinateValidator.isValidNumbers(
        target.latitude, target.longitude)) {
      return;
    }
    setState(() {
      _isMapReverseGeocoding = true;
    });
    try {
      final result = await _locationDs.reverseGeocodeForStoreLocation(
        target.latitude,
        target.longitude,
      );
      if (!mounted) return;
      setState(() {
        _optionBGeocode = result;
        if (_areaController.text.trim().isEmpty && result.area.isNotEmpty) {
          _areaController.text = result.area;
        }
        _isMapReverseGeocoding = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isMapReverseGeocoding = false;
        _optionBGeocode = StoreReverseGeocodeResult(
          latitude: target.latitude,
          longitude: target.longitude,
          formattedAddress: 'Address not found',
          isNotFound: true,
        );
      });
    }
  }

  void _onSearchQueryChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().length < 3) {
      setState(() {
        _placeSearchResults = const [];
        _isSearchingPlaces = false;
      });
      return;
    }
    setState(() => _isSearchingPlaces = true);
    _searchDebounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final results = await _locationDs.searchPlaces(
          query.trim(),
          providerLat: _mapPinPosition.latitude,
          providerLng: _mapPinPosition.longitude,
        );
        if (!mounted) return;
        setState(() {
          _placeSearchResults = results;
          _isSearchingPlaces = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _placeSearchResults = const [];
          _isSearchingPlaces = false;
        });
      }
    });
  }

  void _selectSearchedPlace(ProviderLocationEntity place) {
    final target = LatLng(place.latitude, place.longitude);
    FocusScope.of(context).unfocus();
    setState(() {
      _placeSearchResults = const [];
      _mapSearchController.text = place.placeName;
      _mapPinPosition = target;
    });
    try {
      _mapController.move(target, 17.5);
    } catch (_) {}
    _reverseGeocodeMapPin(target);
  }

  // ===========================================================================
  // OPTION C — MANUAL LATITUDE AND LONGITUDE
  // ===========================================================================

  Future<void> _findAddressFromManualCoordinates() async {
    FocusScope.of(context).unfocus();
    final validation = StoreCoordinateValidator.validateStrings(
      _manualLatController.text,
      _manualLngController.text,
    );

    if (!validation.isValid) {
      setState(() {
        _manualLatError = validation.latitudeError;
        _manualLngError = validation.longitudeError;
        _manualGeneralError = validation.generalError;
        _optionCGeocode = null;
      });
      return;
    }

    final lat = validation.latitude!;
    final lng = validation.longitude!;

    setState(() {
      _manualLatError = null;
      _manualLngError = null;
      _manualGeneralError = null;
      _isManualGeocoding = true;
    });

    try {
      final result =
          await _locationDs.reverseGeocodeForStoreLocation(lat, lng);
      if (!mounted) return;
      setState(() {
        _optionCGeocode = result;
        if (_areaController.text.trim().isEmpty && result.area.isNotEmpty) {
          _areaController.text = result.area;
        }
        _isManualGeocoding = false;
      });
      if (_showManualMapPreview) {
        try {
          _mapController.move(LatLng(lat, lng), 17.0);
        } catch (_) {}
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isManualGeocoding = false;
        _optionCGeocode = StoreReverseGeocodeResult(
          latitude: lat,
          longitude: lng,
          formattedAddress: 'Address not found',
          isNotFound: true,
        );
      });
    }
  }

  void _previewManualCoordinatesOnMap() {
    final validation = StoreCoordinateValidator.validateStrings(
      _manualLatController.text,
      _manualLngController.text,
    );
    if (!validation.isValid) {
      setState(() {
        _manualLatError = validation.latitudeError;
        _manualLngError = validation.longitudeError;
        _manualGeneralError = validation.generalError;
      });
      return;
    }
    setState(() {
      _manualLatError = null;
      _manualLngError = null;
      _manualGeneralError = null;
      _showManualMapPreview = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        _mapController.move(
          LatLng(validation.latitude!, validation.longitude!),
          17.0,
        );
      } catch (_) {}
    });
    if (_optionCGeocode == null ||
        _optionCGeocode!.latitude != validation.latitude ||
        _optionCGeocode!.longitude != validation.longitude) {
      _findAddressFromManualCoordinates();
    }
  }

  // ===========================================================================
  // CONFIRM & SAVE LOCATION
  // ===========================================================================

  StoreLocationSelectionResult? _buildPendingSelection() {
    final landmark = _landmarkController.text.trim();
    final customArea = _areaController.text.trim();

    switch (_selectedMethod) {
      case StoreLocationMethod.currentLocation:
        if (_optionALat == null ||
            _optionALng == null ||
            _optionAGeocode == null ||
            _optionAGeocode!.isNotFound) {
          return null;
        }
        return StoreLocationSelectionResult(
          latitude: _optionALat!,
          longitude: _optionALng!,
          fullAddress: _optionAGeocode!.formattedAddress,
          jamuiArea:
              customArea.isNotEmpty ? customArea : _optionAGeocode!.area,
          landmark: landmark,
          locationSource: 'current_gps',
          isLocationApproximate: _optionAGeocode!.isApproximate,
        );

      case StoreLocationMethod.googleMapPin:
        if (_optionBGeocode == null || _optionBGeocode!.isNotFound) {
          return null;
        }
        return StoreLocationSelectionResult(
          latitude: _optionBGeocode!.latitude,
          longitude: _optionBGeocode!.longitude,
          fullAddress: _optionBGeocode!.formattedAddress,
          jamuiArea:
              customArea.isNotEmpty ? customArea : _optionBGeocode!.area,
          landmark: landmark,
          locationSource: 'google_map_pin',
          isLocationApproximate: _optionBGeocode!.isApproximate,
        );

      case StoreLocationMethod.manualLatLng:
        final validation = StoreCoordinateValidator.validateStrings(
          _manualLatController.text,
          _manualLngController.text,
        );
        if (!validation.isValid ||
            _optionCGeocode == null ||
            _optionCGeocode!.isNotFound ||
            (_optionCGeocode!.latitude - validation.latitude!).abs() >
                0.00001 ||
            (_optionCGeocode!.longitude - validation.longitude!).abs() >
                0.00001) {
          return null;
        }
        return StoreLocationSelectionResult(
          latitude: validation.latitude!,
          longitude: validation.longitude!,
          fullAddress: _optionCGeocode!.formattedAddress,
          jamuiArea:
              customArea.isNotEmpty ? customArea : _optionCGeocode!.area,
          landmark: landmark,
          locationSource: 'manual_lat_lng',
          isLocationApproximate: _optionCGeocode!.isApproximate,
        );
    }
  }

  Future<void> _confirmAndSaveLocation() async {
    final selection = _buildPendingSelection();
    if (selection == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please detect a valid address for the selected location before confirming.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (!widget.persistImmediately) {
      Navigator.of(context).pop(selection);
      return;
    }

    setState(() => _isSaving = true);
    try {
      String? currentUid;
      try {
        currentUid = FirebaseAuth.instance.currentUser?.uid;
      } catch (_) {}

      await _shopDs.updateStoreLocation(
        shopId: widget.shop.id,
        latitude: selection.latitude,
        longitude: selection.longitude,
        fullAddress: selection.fullAddress,
        jamuiArea: selection.jamuiArea,
        landmark: selection.landmark,
        locationSource: selection.locationSource,
        isLocationApproximate: selection.isLocationApproximate,
        currentUid: currentUid,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Store location confirmed and saved successfully!'),
          backgroundColor: _primaryGreen,
        ),
      );
      Navigator.of(context).pop(selection);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save store location: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // ===========================================================================
  // UI BUILDERS
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final pendingSelection = _buildPendingSelection();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F9F5),
      appBar: AppBar(
        backgroundColor: _darkGreenHeader,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Set Store Location',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSavedLocationBanner(),
                  const SizedBox(height: 14),
                  _buildMethodSelectorTabs(),
                  const SizedBox(height: 16),
                  if (_selectedMethod == StoreLocationMethod.currentLocation)
                    _buildOptionACurrentLocationCard()
                  else if (_selectedMethod == StoreLocationMethod.googleMapPin)
                    _buildOptionBGoogleMapCard()
                  else
                    _buildOptionCManualLatLngCard(),
                  const SizedBox(height: 16),
                  _buildLandmarkAndAreaCard(),
                ],
              ),
            ),
          ),
          _buildBottomConfirmBar(pendingSelection),
        ],
      ),
    );
  }

  Widget _buildSavedLocationBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD1E7D6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: _primaryGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Saved Store Location',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _primaryGreen,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _savedAddress.isNotEmpty
                      ? _savedAddress
                      : 'No store address saved yet',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                if (_savedLandmark.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Landmark: $_savedLandmark',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF4B5563),
                    ),
                  ),
                ],
                if (_hasSavedCoordinates) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Saved Coordinates: ${_savedLatitude!.toStringAsFixed(6)}, ${_savedLongitude!.toStringAsFixed(6)}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontFamily: 'monospace',
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodSelectorTabs() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD1E7D6)),
      ),
      child: Row(
        children: [
          _buildMethodTab(
            method: StoreLocationMethod.currentLocation,
            icon: Icons.my_location_rounded,
            label: 'Current GPS',
            keyName: 'tab_option_a_current_gps',
          ),
          const SizedBox(width: 6),
          _buildMethodTab(
            method: StoreLocationMethod.googleMapPin,
            icon: Icons.map_rounded,
            label: 'Google Map',
            keyName: 'tab_option_b_google_map',
          ),
          const SizedBox(width: 6),
          _buildMethodTab(
            method: StoreLocationMethod.manualLatLng,
            icon: Icons.pin_drop_outlined,
            label: 'Manual Lat/Lng',
            keyName: 'tab_option_c_manual_lat_lng',
          ),
        ],
      ),
    );
  }

  Widget _buildMethodTab({
    required StoreLocationMethod method,
    required IconData icon,
    required String label,
    required String keyName,
  }) {
    final isSelected = _selectedMethod == method;
    return Expanded(
      child: InkWell(
        key: Key(keyName),
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          setState(() {
            _selectedMethod = method;
          });
          if (method == StoreLocationMethod.googleMapPin &&
              _optionBGeocode == null) {
            _reverseGeocodeMapPin(_mapPinPosition);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected ? _primaryGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : const Color(0xFF374151),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : const Color(0xFF374151),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // OPTION A CARD
  // ---------------------------------------------------------------------------

  Widget _buildOptionACurrentLocationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.gps_fixed_rounded, color: _primaryGreen, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Option A — Use Current Location',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Use this option when you are physically at your shop. Your existing saved store location will not change unless you confirm below.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF4B5563)),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const Key('btn_fetch_current_gps'),
              onPressed: _isFetchingGps ? null : _fetchCurrentGpsLocation,
              icon: _isFetchingGps
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.my_location_rounded, size: 18),
              label: Text(
                _isFetchingGps
                    ? 'Detecting GPS Coordinates...'
                    : 'Use Current GPS Location',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          if (_gpsError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Color(0xFFB91C1C),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _gpsError!,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF991B1B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_isGpsPermissionDeniedForever ||
                      _isGpsServiceDisabled) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          if (_isGpsServiceDisabled) {
                            _locationDs.openLocationSettings();
                          } else {
                            _locationDs.openAppSettings();
                          }
                        },
                        icon: const Icon(Icons.settings_outlined, size: 16),
                        label: Text(
                          _isGpsServiceDisabled
                              ? 'Open GPS Settings'
                              : 'Open App Permissions',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (_optionALat != null && _optionALng != null) ...[
            const SizedBox(height: 14),
            _buildCoordinatesReadoutBox(
              latitude: _optionALat!,
              longitude: _optionALng!,
              accuracyMeters: _gpsAccuracyMeters,
            ),
            const SizedBox(height: 12),
            if (_optionAGeocode != null)
              _buildDetectedAddressBox(_optionAGeocode!),
            const SizedBox(height: 12),
            SizedBox(
              height: 210,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildInteractiveGoogleTileMap(
                  center: LatLng(_optionALat!, _optionALng!),
                  interactive: false,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // OPTION B CARD
  // ---------------------------------------------------------------------------

  Widget _buildOptionBGoogleMapCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.map_rounded, color: _primaryGreen, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Option B — Select on Google Map',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Search for a place or drag/tap the map to position the pin at your exact shop entrance.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF4B5563)),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('field_map_place_search'),
            controller: _mapSearchController,
            onChanged: _onSearchQueryChanged,
            decoration: InputDecoration(
              hintText: 'Search area, bazaar, landmark or road...',
              prefixIcon: const Icon(Icons.search_rounded, color: _primaryGreen),
              suffixIcon: _isSearchingPlaces
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : (_mapSearchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _mapSearchController.clear();
                            setState(() => _placeSearchResults = const []);
                          },
                        )
                      : null),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
              ),
            ),
          ),
          if (_placeSearchResults.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _placeSearchResults.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = _placeSearchResults[index];
                  return ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.place_outlined,
                      color: _primaryGreen,
                      size: 18,
                    ),
                    title: Text(
                      item.placeName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Text(
                      item.formattedAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    onTap: () => _selectSearchedPlace(item),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 260,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: _buildInteractiveGoogleTileMap(
                center: _mapPinPosition,
                interactive: true,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildCoordinatesReadoutBox(
            latitude: _mapPinPosition.latitude,
            longitude: _mapPinPosition.longitude,
          ),
          const SizedBox(height: 12),
          if (_isMapReverseGeocoding)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _primaryGreen,
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Fetching address for selected map pin...',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF4B5563)),
                  ),
                ],
              ),
            )
          else if (_optionBGeocode != null)
            _buildDetectedAddressBox(_optionBGeocode!),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // OPTION C CARD (MANDATORY MANUAL LATITUDE & LONGITUDE)
  // ---------------------------------------------------------------------------

  Widget _buildOptionCManualLatLngCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.pin_drop_rounded, color: _primaryGreen, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Option C — Manual Latitude and Longitude',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Enter your shop\'s exact coordinates, tap Find Address to verify the reverse-geocoded address, and preview on the map before saving.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF4B5563)),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  key: const Key('field_manual_latitude'),
                  controller: _manualLatController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Latitude',
                    hintText: '24.9195',
                    errorText: _manualLatError,
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  key: const Key('field_manual_longitude'),
                  controller: _manualLngController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Longitude',
                    hintText: '86.2208',
                    errorText: _manualLngError,
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_manualGeneralError != null) ...[
            const SizedBox(height: 8),
            Text(
              _manualGeneralError!,
              style: const TextStyle(
                color: Color(0xFFB91C1C),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  key: const Key('btn_manual_find_address'),
                  onPressed: _isManualGeocoding
                      ? null
                      : _findAddressFromManualCoordinates,
                  icon: _isManualGeocoding
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.travel_explore_rounded, size: 18),
                  label: Text(
                    _isManualGeocoding ? 'Finding...' : 'Find Address',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                key: const Key('btn_manual_view_on_map'),
                onPressed: _previewManualCoordinatesOnMap,
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text(
                  'View on Map',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primaryGreen,
                  side: const BorderSide(color: _primaryGreen),
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          if (_optionCGeocode != null) ...[
            const SizedBox(height: 14),
            _buildDetectedAddressBox(_optionCGeocode!),
          ],
          if (_showManualMapPreview) ...[
            const SizedBox(height: 14),
            Builder(
              builder: (context) {
                final v = StoreCoordinateValidator.validateStrings(
                  _manualLatController.text,
                  _manualLngController.text,
                );
                if (!v.isValid) return const SizedBox.shrink();
                return SizedBox(
                  height: 200,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildInteractiveGoogleTileMap(
                      center: LatLng(v.latitude!, v.longitude!),
                      interactive: false,
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SHARED WIDGETS (DETECTED ADDRESS BOX, COORDINATES READOUT, MAP, LANDMARK)
  // ---------------------------------------------------------------------------

  Widget _buildCoordinatesReadoutBox({
    required double latitude,
    required double longitude,
    double? accuracyMeters,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.explore_outlined, color: _primaryGreen, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Latitude: ${latitude.toStringAsFixed(6)}   •   Longitude: ${longitude.toStringAsFixed(6)}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
                color: Color(0xFF14532D),
              ),
            ),
          ),
          if (accuracyMeters != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '±${accuracyMeters.toStringAsFixed(0)}m',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: _primaryGreen,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetectedAddressBox(StoreReverseGeocodeResult result) {
    final isNotFound = result.isNotFound;
    final isApproximate = result.isApproximate && !isNotFound;

    return Container(
      key: const Key('box_detected_address'),
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isNotFound
            ? const Color(0xFFFEF2F2)
            : (isApproximate
                ? const Color(0xFFFFFBEB)
                : const Color(0xFFF0FDF4)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isNotFound
              ? const Color(0xFFFECACA)
              : (isApproximate
                  ? const Color(0xFFFDE68A)
                  : const Color(0xFF86EFAC)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isNotFound
                    ? Icons.location_off_outlined
                    : (isApproximate
                        ? Icons.info_outline_rounded
                        : Icons.check_circle_outline_rounded),
                size: 17,
                color: isNotFound
                    ? const Color(0xFFB91C1C)
                    : (isApproximate
                        ? const Color(0xFFB45309)
                        : _primaryGreen),
              ),
              const SizedBox(width: 6),
              const Text(
                'Detected Address:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF374151),
                ),
              ),
              if (isApproximate) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Approximate Area-Level Address',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isNotFound ? 'Address not found' : result.formattedAddress,
            key: const Key('text_detected_formatted_address'),
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: isNotFound
                  ? const Color(0xFFB91C1C)
                  : const Color(0xFF111827),
            ),
          ),
          if (isNotFound) ...[
            const SizedBox(height: 4),
            const Text(
              'No address was returned for these coordinates. Please adjust the coordinates or select your shop entrance on the map.',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF991B1B)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInteractiveGoogleTileMap({
    required LatLng center,
    required bool interactive,
  }) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 16.5,
            interactionOptions: InteractionOptions(
              flags: interactive ? InteractiveFlag.all : InteractiveFlag.none,
            ),
            onTap: interactive
                ? (_, point) {
                    _onMapPositionChanged(point);
                  }
                : null,
            onPositionChanged: interactive
                ? (pos, hasGesture) {
                    if (hasGesture) {
                      _onMapPositionChanged(pos.center);
                    }
                  }
                : null,
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://mt1.google.com/vt/lyrs=$_mapLayerCode&x={x}&y={y}&z={z}',
              userAgentPackageName: 'com.jamuiservice.provider',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: center,
                  width: 48,
                  height: 48,
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: Color(0xFFDC2626),
                    size: 42,
                  ),
                ),
              ],
            ),
          ],
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMapLayerChip('m', 'Map'),
                _buildMapLayerChip('y', 'Satellite'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMapLayerChip(String code, String label) {
    final active = _mapLayerCode == code;
    return InkWell(
      onTap: () => setState(() => _mapLayerCode = code),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: active ? _primaryGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : const Color(0xFF374151),
          ),
        ),
      ),
    );
  }

  Widget _buildLandmarkAndAreaCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Shop Entrance & Landmark Details',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            key: const Key('field_store_landmark'),
            controller: _landmarkController,
            decoration: InputDecoration(
              labelText: 'Landmark / Shop Entrance Details (Optional)',
              hintText: 'e.g. Ground Floor, Near Main Post Office',
              prefixIcon: const Icon(Icons.store_mall_directory_outlined),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('field_store_area'),
            controller: _areaController,
            decoration: InputDecoration(
              labelText: 'Area / Locality',
              hintText: 'Auto-filled from geocoding or enter locality',
              prefixIcon: const Icon(Icons.location_city_outlined),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomConfirmBar(StoreLocationSelectionResult? selection) {
    final canSave = selection != null && !_isSaving;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            key: const Key('btn_confirm_and_save_location'),
            onPressed: canSave ? _confirmAndSaveLocation : null,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_circle_rounded, size: 20),
            label: Text(
              _isSaving ? 'Saving Location...' : 'Confirm & Save Location',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryGreen,
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFD1D5DB),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

