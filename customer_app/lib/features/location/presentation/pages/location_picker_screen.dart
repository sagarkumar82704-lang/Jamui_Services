import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/location_service.dart';
import '../../../discovery/presentation/bloc/discovery_bloc.dart';
import '../../../discovery/presentation/bloc/discovery_event.dart';
import '../../domain/entities/customer_location_entity.dart';
import '../bloc/location_bloc.dart';
import '../bloc/location_event.dart';
import '../bloc/location_state.dart';

/// Dedicated HTTP client for OpenStreetMap tile requests with bounded timeout
/// and OSM policy-compliant identification headers.
class _OsmTileHttpClient extends http.BaseClient {
  final http.Client _inner;
  static const Duration _timeout = Duration(seconds: 10);

  _OsmTileHttpClient(this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    request.headers['User-Agent'] =
        'JamuiServicesCustomerApp/1.2.7 (https://jamui-services.web.app; contact: support@apnajamui.in)';
    request.headers.putIfAbsent('Accept', () => 'image/png,image/*;q=0.8,*/*;q=0.5');

    final response = await _inner.send(request).timeout(_timeout);
    if (kDebugMode && response.statusCode != 200) {
      debugPrint('⚠️ [OSM_TILE] HTTP ${response.statusCode} for ${request.url}');
    }
    return response;
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

class LocationPickerScreen extends StatefulWidget {
  final bool isFromOnboarding;
  final Object? tileProvider;

  const LocationPickerScreen({
    super.key,
    this.isFromOnboarding = false,
    this.tileProvider,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  static const LatLng _defaultMapViewportCenter = LatLng(24.9213, 86.2238);
  static const String _osmTileUrlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const double _defaultActiveZoom = 14.3;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final MapController _mapController = MapController();
  Timer? _searchDebounceTimer;
  Timer? _mapDragDebounceTimer;

  // Persistent network tile provider so widget rebuilds do not reset active HTTP connections
  late TileProvider _networkTileProvider;
  int _mapRetryCount = 0;
  bool _isMapLoading = true;
  bool _hasMapError = false;
  int _loadedTilesCount = 0;

  // Fraction of body height occupied by the draggable bottom address sheet (0.30..0.54).
  // Default 0.36 means the interactive map occupies ~64% of the available screen height.
  double _bottomSheetHeightFraction = 0.36;

  // Live pin coordinates tracked during pan/drag gestures
  LatLng? _liveDragCenter;

  // Active location displayed on the card (retained across loading/error states)
  late CustomerLocationEntity _activeLocation;

  TileProvider _createNetworkTileProvider() {
    return NetworkTileProvider(
      headers: <String, String>{
        'User-Agent':
            'JamuiServicesCustomerApp/1.2.7 (https://jamui-services.web.app; contact: support@apnajamui.in)',
        'Accept': 'image/png,image/*;q=0.8,*/*;q=0.5',
      },
      httpClient: RetryClient(
        _OsmTileHttpClient(http.Client()),
        retries: 2,
        when: (response) => response.statusCode == 408 || response.statusCode == 429 || response.statusCode >= 500,
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    _networkTileProvider = _createNetworkTileProvider();
    if (widget.tileProvider != null) {
      _isMapLoading = false;
    }

    final currentBlocState = context.read<LocationBloc>().state;
    if (currentBlocState is LocationLoaded && currentBlocState.location.hasValidCoordinates) {
      _activeLocation = currentBlocState.location;
    } else {
      _activeLocation = CustomerLocationEntity(
        latitude: 0.0,
        longitude: 0.0,
        placeName: 'Select Location',
        formattedAddress: 'Tap or drag the pin to select your location',
        city: '',
        district: '',
        state: '',
        pincode: '',
        timestamp: DateTime.now(),
      );
    }

    // Automatically trigger fresh device hardware GPS acquisition on screen open
    context.read<LocationBloc>().add(const FetchDeviceGpsLocationEvent(forceRefresh: true));
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _mapDragDebounceTimer?.cancel();
    _mapController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _safeMoveMap(double lat, double lng, {double zoom = _defaultActiveZoom}) {
    if (lat == 0.0 && lng == 0.0) return;
    try {
      _mapController.move(LatLng(lat, lng), zoom);
    } catch (_) {}
  }

  void _zoomIn() {
    try {
      final cam = _mapController.camera;
      final nextZoom = (cam.zoom + 1.0).clamp(5.0, 18.5);
      _mapController.move(cam.center, nextZoom);
    } catch (_) {}
  }

  void _zoomOut() {
    try {
      final cam = _mapController.camera;
      final nextZoom = (cam.zoom - 1.0).clamp(5.0, 18.5);
      _mapController.move(cam.center, nextZoom);
    } catch (_) {}
  }

  void _retryMapTiles() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    setState(() {
      _networkTileProvider = _createNetworkTileProvider();
      _mapRetryCount++;
      _loadedTilesCount = 0;
      _hasMapError = false;
      _isMapLoading = widget.tileProvider == null;
    });
  }

  Widget _buildMapTile(BuildContext context, Widget tileWidget, TileImage tile) {
    if (tile.loadStarted == null && !tile.loadError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && tile.loadStarted == null && !tile.loadError) {
          try {
            tile.load();
          } catch (_) {}
        }
      });
    }
    if (!tile.loadError && tile.imageInfo != null) {
      if (_isMapLoading || _hasMapError) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && (_isMapLoading || _hasMapError)) {
            setState(() {
              _loadedTilesCount++;
              _isMapLoading = false;
              _hasMapError = false;
            });
          }
        });
      } else {
        _loadedTilesCount++;
      }
    }
    return tileWidget;
  }

  void _onTileLoadError(TileImage tile, Object error, StackTrace? stackTrace) {
    if (kDebugMode) {
      debugPrint('⚠️ [OSM_TILE_ERROR] Tile ${tile.coordinates} failed: $error');
    }
    if (_loadedTilesCount == 0 && !_hasMapError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _loadedTilesCount == 0 && !_hasMapError) {
          setState(() {
            _hasMapError = true;
            _isMapLoading = false;
          });
        }
      });
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    _searchFocusNode.unfocus();
    _mapDragDebounceTimer?.cancel();
    setState(() {
      _liveDragCenter = point;
    });
    double currentZoom = _defaultActiveZoom;
    try {
      currentZoom = _mapController.camera.zoom;
    } catch (_) {}
    _safeMoveMap(point.latitude, point.longitude, zoom: currentZoom);
    context.read<LocationBloc>().add(
          SelectCoordinatesEvent(
            latitude: point.latitude,
            longitude: point.longitude,
            shouldReverseGeocode: true,
          ),
        );
  }

  void _onMapPositionChanged(MapCamera camera, bool hasGesture) {
    if (!hasGesture) return;
    final center = camera.center;
    setState(() {
      _liveDragCenter = center;
    });
    context.read<LocationBloc>().add(
          UpdateCameraCenterCoordinatesEvent(
            latitude: center.latitude,
            longitude: center.longitude,
          ),
        );
    _mapDragDebounceTimer?.cancel();
    _mapDragDebounceTimer = Timer(const Duration(milliseconds: 550), () {
      if (mounted) {
        context.read<LocationBloc>().add(
              SelectCoordinatesEvent(
                latitude: center.latitude,
                longitude: center.longitude,
                shouldReverseGeocode: true,
              ),
            );
      }
    });
  }

  void _onSearchChanged(String query) {
    _searchDebounceTimer?.cancel();
    setState(() {});
    final clean = query.trim();
    if (clean.length < 2) {
      context.read<LocationBloc>().add(const ClearSearchSuggestionsEvent());
      return;
    }
    _searchDebounceTimer = Timer(const Duration(milliseconds: 450), () {
      if (mounted) {
        _dispatchSearch(clean);
      }
    });
  }

  void _onSearchSubmitted(String query) {
    _searchDebounceTimer?.cancel();
    final clean = query.trim();
    if (clean.length < 2) {
      context.read<LocationBloc>().add(const ClearSearchSuggestionsEvent());
      return;
    }
    _dispatchSearch(clean);
  }

  void _dispatchSearch(String cleanQuery) {
    context.read<LocationBloc>().add(
          SearchPlacesEvent(
            cleanQuery,
            customerLat: _activeLocation.hasValidCoordinates ? _activeLocation.latitude : null,
            customerLng: _activeLocation.hasValidCoordinates ? _activeLocation.longitude : null,
          ),
        );
  }

  void _onSelectSearchResult(CustomerLocationEntity result) {
    _searchDebounceTimer?.cancel();
    _searchFocusNode.unfocus();
    _searchController.text = result.placeName.isNotEmpty ? result.placeName : result.formattedAddress;
    context.read<LocationBloc>().add(const ClearSearchSuggestionsEvent());
    context.read<LocationBloc>().add(SetExplicitLocationEvent(
          location: result,
          moveCamera: true,
          zoom: _defaultActiveZoom,
        ));
    setState(() {
      _activeLocation = result;
      _liveDragCenter = LatLng(result.latitude, result.longitude);
    });
    _safeMoveMap(result.latitude, result.longitude, zoom: _defaultActiveZoom);
  }

  void _clearSearch() {
    _searchDebounceTimer?.cancel();
    _searchController.clear();
    setState(() {});
    context.read<LocationBloc>().add(const ClearSearchSuggestionsEvent());
  }

  void _fetchCurrentGps() {
    _searchFocusNode.unfocus();
    setState(() {
      _liveDragCenter = null;
    });
    context.read<LocationBloc>().add(const FetchDeviceGpsLocationEvent(forceRefresh: true));
  }

  void _onConfirmLocation(CustomerLocationEntity location) {
    if (!location.hasValidCoordinates ||
        (location.latitude == 0.0 && location.longitude == 0.0) ||
        location.placeName == 'Select Location') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a location on the map, search for a place, or tap Use Current Location.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmedLocation = (location.placeName == 'Detecting location...' || location.placeName.isEmpty)
        ? location.copyWith(
            placeName: 'Location detected',
            formattedAddress: 'GPS: ${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
          )
        : location;

    context.read<LocationBloc>().add(ConfirmSelectedLocationEvent(confirmedLocation));

    final areaDisplay = confirmedLocation.placeName.isNotEmpty && confirmedLocation.placeName != 'Select Location'
        ? (confirmedLocation.pincode.isNotEmpty
            ? '${confirmedLocation.placeName} (${confirmedLocation.pincode})'
            : confirmedLocation.placeName)
        : 'GPS (${confirmedLocation.latitude.toStringAsFixed(4)}, ${confirmedLocation.longitude.toStringAsFixed(4)})';

    context.read<DiscoveryBloc>().add(UpdateCustomerLocationEvent(
          latitude: confirmedLocation.latitude,
          longitude: confirmedLocation.longitude,
          areaName: areaDisplay,
          village: confirmedLocation.village,
          block: confirmedLocation.block,
        ));

    if (widget.isFromOnboarding) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } else {
      Navigator.of(context).pop(confirmedLocation);
    }
  }

  String _formatDistance(double? userLat, double? userLng, double targetLat, double targetLng) {
    if (userLat == null || userLng == null || (userLat == 0 && userLng == 0)) return '';
    final distanceKm = LocationService.calculateDistanceKm(
      startLatitude: userLat,
      startLongitude: userLng,
      endLatitude: targetLat,
      endLongitude: targetLng,
    );
    if (distanceKm < 1.0) {
      return '${(distanceKm * 1000).round()} m';
    } else if (distanceKm < 10.0) {
      return '${distanceKm.toStringAsFixed(1)} km';
    } else {
      return '${distanceKm.round()} km';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        toolbarHeight: 52,
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: widget.isFromOnboarding
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
                onPressed: () => Navigator.maybePop(context),
              ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Location',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              'Accurate location for better service',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Use Current Location',
            icon: const Icon(Icons.my_location_rounded, color: Color(0xFF1A73E8)),
            onPressed: _fetchCurrentGps,
          ),
        ],
      ),
      body: BlocConsumer<LocationBloc, LocationState>(
        listener: (context, state) {
          if (state is LocationLoaded) {
            final prevLat = _activeLocation.latitude;
            final prevLng = _activeLocation.longitude;
            if (state.location.hasValidCoordinates) {
              setState(() {
                _activeLocation = state.location;
                _liveDragCenter = LatLng(state.location.latitude, state.location.longitude);
              });
            }
            if (state.isGpsLocked &&
                state.location.hasValidCoordinates &&
                (prevLat != state.location.latitude || prevLng != state.location.longitude)) {
              _safeMoveMap(state.location.latitude, state.location.longitude, zoom: state.zoom);
            }
          }
        },
        builder: (context, state) {
          final loc = (state is LocationLoaded && state.location.hasValidCoordinates)
              ? state.location
              : _activeLocation;
          final isGpsLocked = (state is LocationLoaded) && state.isGpsLocked;
          final isLoading = state is LocationLoading;
          final isSearching = (state is LocationLoaded) && state.isSearching;
          final hasSearchResults = (state is LocationLoaded) && state.searchResults.isNotEmpty;
          final hasSearched = (state is LocationLoaded) && state.hasSearched;
          final searchError = (state is LocationLoaded) ? state.searchError : null;
          final activeQuery = _searchController.text.trim();

          return SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final totalHeight = constraints.maxHeight;
                // Map occupies ~64% of screen height by default (adjustable via bottom sheet drag handle)
                final sheetHeight = math.max(
                  210.0,
                  math.min(totalHeight * 0.52, totalHeight * _bottomSheetHeightFraction),
                );
                final mapHeight = math.max(220.0, totalHeight - sheetHeight);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. FULL-BLEED INTERACTIVE MAP AREA (~64% of screen height)
                    SizedBox(
                      height: mapHeight,
                      child: _buildFullBleedMapStack(
                        context: context,
                        loc: loc,
                        state: state,
                        isSearching: isSearching,
                        hasSearchResults: hasSearchResults,
                        hasSearched: hasSearched,
                        searchError: searchError,
                        activeQuery: activeQuery,
                      ),
                    ),

                    // 2. DRAGGABLE BOTTOM ADDRESS SHEET (~36% of screen height)
                    SizedBox(
                      height: totalHeight - mapHeight,
                      child: _buildBottomAddressSheet(
                        context: context,
                        loc: loc,
                        isGpsLocked: isGpsLocked,
                        isLoading: isLoading,
                        totalHeight: totalHeight,
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildFullBleedMapStack({
    required BuildContext context,
    required CustomerLocationEntity loc,
    required LocationState state,
    required bool isSearching,
    required bool hasSearchResults,
    required bool hasSearched,
    required String? searchError,
    required String activeQuery,
  }) {
    final hasCoords = loc.hasValidCoordinates && (loc.latitude != 0.0 || loc.longitude != 0.0);
    final double mapLat = (state is LocationLoaded && state.cameraLatitude != 0.0)
        ? state.cameraLatitude
        : (hasCoords ? loc.latitude : _defaultMapViewportCenter.latitude);
    final double mapLng = (state is LocationLoaded && state.cameraLongitude != 0.0)
        ? state.cameraLongitude
        : (hasCoords ? loc.longitude : _defaultMapViewportCenter.longitude);
    final LatLng pinLatLng = _liveDragCenter ??
        (hasCoords ? LatLng(loc.latitude, loc.longitude) : LatLng(mapLat, mapLng));

    final TileProvider activeTileProvider =
        widget.tileProvider is TileProvider ? widget.tileProvider as TileProvider : _networkTileProvider;

    return Stack(
      children: [
        // OpenStreetMap Interactive Map
        Positioned.fill(
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(mapLat, mapLng),
              initialZoom: hasCoords ? _defaultActiveZoom : 13.5,
              minZoom: 5.0,
              maxZoom: 18.5,
              backgroundColor: const Color(0xFFEEF2F6),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onTap: _onMapTap,
              onPositionChanged: _onMapPositionChanged,
            ),
            children: [
              TileLayer(
                key: ValueKey<int>(_mapRetryCount),
                urlTemplate: _osmTileUrlTemplate,
                userAgentPackageName: 'com.jamuiservice.customer',
                tileProvider: activeTileProvider,
                tileDisplay: const TileDisplay.instantaneous(),
                panBuffer: 1,
                keepBuffer: 3,
                evictErrorTileStrategy: EvictErrorTileStrategy.notVisibleRespectMargin,
                additionalOptions: <String, String>{'retry': '$_mapRetryCount'},
                tileBuilder: _buildMapTile,
                errorTileCallback: _onTileLoadError,
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: pinLatLng,
                    width: 56,
                    height: 56,
                    alignment: Alignment.topCenter,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          bottom: 2,
                          child: Container(
                            width: 14,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.location_on_rounded,
                          color: Color(0xFFD93025),
                          size: 46,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // FLOATING TOP OVERLAY: Search Bar + Suggestions Dropdown / Instruction Pill / Status Banner
        Positioned(
          top: 10,
          left: 12,
          right: 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildFloatingSearchBar(isSearching),
              if (isSearching) ...[
                const SizedBox(height: 6),
                _buildSearchingStatusCard(),
              ] else if (searchError != null && activeQuery.length >= 2) ...[
                const SizedBox(height: 6),
                _buildSearchErrorCard(searchError, activeQuery),
              ] else if (hasSearchResults && state is LocationLoaded) ...[
                const SizedBox(height: 6),
                _buildSearchResultsDropdown(state.searchResults, loc),
              ] else if (hasSearched && activeQuery.length >= 2) ...[
                const SizedBox(height: 6),
                _buildNoLocationsFoundCard(),
              ] else ...[
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.touch_app_rounded, size: 14, color: Color(0xFF1A73E8)),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Tap or drag the pin to select your location',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                _buildStatusBanner(context, state),
              ],
            ],
          ),
        ),

        // Map tile loading indicator
        if (_isMapLoading && !_hasMapError)
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Map loading...',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Map tile failure & retry state
        if (_hasMapError)
          Positioned(
            bottom: 48,
            left: 16,
            right: 16,
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _retryMapTiles,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.red.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh_rounded, size: 16, color: Color(0xFFD93025)),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Unable to load map. Tap to retry.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFD93025),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

        // Google Maps style Zoom In / Zoom Out Controls on right side
        Positioned(
          right: 12,
          bottom: 34,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: _zoomIn,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: const SizedBox(
                    width: 38,
                    height: 38,
                    child: Icon(Icons.add_rounded, size: 20, color: Colors.black87),
                  ),
                ),
                Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
                InkWell(
                  onTap: _zoomOut,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                  child: const SizedBox(
                    width: 38,
                    height: 38,
                    child: Icon(Icons.remove_rounded, size: 20, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Floating "Current Location" GPS control on bottom-left of map
        Positioned(
          bottom: 10,
          left: 12,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _fetchCurrentGps,
                borderRadius: BorderRadius.circular(22),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.my_location_rounded, size: 15, color: Color(0xFF1A73E8)),
                      SizedBox(width: 6),
                      Text(
                        'Current Location',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A73E8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Required OpenStreetMap Attribution
        Positioned(
          bottom: 6,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.90),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              '© OpenStreetMap contributors',
              style: TextStyle(
                fontSize: 9,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingSearchBar(bool isSearching) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: _onSearchChanged,
        onSubmitted: _onSearchSubmitted,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: Colors.black87),
        decoration: InputDecoration(
          hintText: 'Search village, locality or city...',
          hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF1A73E8), size: 20),
          suffixIcon: isSearching
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A73E8)),
                  ),
                )
              : (_searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.cancel_rounded, color: Colors.grey, size: 18),
                      onPressed: _clearSearch,
                    )
                  : null),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        ),
      ),
    );
  }

  Widget _buildSearchingStatusCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A73E8)),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Searching locations...',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoLocationsFoundCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.search_off_rounded, color: Colors.grey.shade600, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'No locations found',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchErrorCard(String errorMsg, String activeQuery) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _dispatchSearch(activeQuery),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.orange.shade300),
          ),
          child: Row(
            children: [
              Icon(Icons.wifi_off_rounded, color: Colors.orange.shade800, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  errorMsg,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.orange.shade900),
                ),
              ),
              Icon(Icons.refresh_rounded, color: Colors.orange.shade800, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResultsDropdown(List<CustomerLocationEntity> results, CustomerLocationEntity loc) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: results.length,
          separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
          itemBuilder: (context, index) {
            final item = results[index];
            final distStr = _formatDistance(loc.latitude, loc.longitude, item.latitude, item.longitude);

            return Material(
              color: Colors.white,
              child: InkWell(
                onTap: () => _onSelectSearchResult(item),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE8F0FE),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.location_on_outlined, color: Color(0xFF1A73E8), size: 17),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.placeName.isNotEmpty ? item.placeName : item.formattedAddress,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.formattedAddress,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (distStr.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          distStr,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBottomAddressSheet({
    required BuildContext context,
    required CustomerLocationEntity loc,
    required bool isGpsLocked,
    required bool isLoading,
    required double totalHeight,
  }) {
    final hasCoords = loc.hasValidCoordinates && (loc.latitude != 0.0 || loc.longitude != 0.0);
    final isPlaceholder = !hasCoords || loc.placeName == 'Select Location';

    Color statusColor;
    Color statusBgColor;
    IconData statusIcon;
    String statusText;

    if (isLoading) {
      statusColor = const Color(0xFF1A73E8);
      statusBgColor = const Color(0xFFE8F0FE);
      statusIcon = Icons.hourglass_top_rounded;
      statusText = 'Detecting your current location...';
    } else if (isGpsLocked && hasCoords) {
      statusColor = const Color(0xFF1E8E3E);
      statusBgColor = const Color(0xFFE6F4EA);
      statusIcon = Icons.gps_fixed;
      statusText = 'Current Location';
    } else if (hasCoords) {
      statusColor = const Color(0xFF1A73E8);
      statusBgColor = const Color(0xFFE8F0FE);
      statusIcon = Icons.pin_drop_rounded;
      statusText = 'Location detected';
    } else {
      statusColor = Colors.orange.shade800;
      statusBgColor = Colors.orange.shade50;
      statusIcon = Icons.location_searching_rounded;
      statusText = 'Select Location';
    }

    final placeTitle = isPlaceholder
        ? 'Select Location'
        : (loc.placeName.isNotEmpty ? loc.placeName : 'Location detected');

    final addressDisplay = isPlaceholder
        ? 'Tap or drag the pin to select your location'
        : (loc.formattedAddress.isNotEmpty
            ? loc.formattedAddress
            : (hasCoords ? 'GPS: ${loc.latitude.toStringAsFixed(6)}, ${loc.longitude.toStringAsFixed(6)}' : '--'));

    final villageOrLocality = loc.village.isNotEmpty ? loc.village : loc.locality;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Draggable Sheet Handle Bar
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: (details) {
              if (totalHeight <= 0) return;
              setState(() {
                final deltaFraction = -details.primaryDelta! / totalHeight;
                _bottomSheetHeightFraction = (_bottomSheetHeightFraction + deltaFraction).clamp(0.30, 0.52);
              });
            },
            child: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 6),
              child: Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),

          // Scrollable Address Details
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Pill Badge + Accuracy Badge
                  Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusBgColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon, size: 13, color: statusColor),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    statusText,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: statusColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (loc.accuracy != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            'Accuracy: ±${loc.accuracy!.toStringAsFixed(1)}m',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Place Name
                  Text(
                    placeTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 2),

                  // Formatted Address
                  Text(
                    addressDisplay,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.grey.shade700,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  if (hasCoords &&
                      (villageOrLocality.isNotEmpty ||
                          loc.suburb.isNotEmpty ||
                          loc.block.isNotEmpty ||
                          loc.district.isNotEmpty ||
                          loc.state.isNotEmpty ||
                          loc.pincode.isNotEmpty)) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: [
                        if (villageOrLocality.isNotEmpty)
                          _buildAddressChip('Village / Locality: $villageOrLocality', Icons.home_work_outlined),
                        if (loc.suburb.isNotEmpty && loc.suburb.toLowerCase() != villageOrLocality.toLowerCase())
                          _buildAddressChip('Suburb: ${loc.suburb}', Icons.place_outlined),
                        if (loc.block.isNotEmpty)
                          _buildAddressChip('Block: ${loc.block}', Icons.account_balance_outlined),
                        if (loc.district.isNotEmpty)
                          _buildAddressChip('District: ${loc.district}', Icons.map_outlined),
                        if (loc.state.isNotEmpty)
                          _buildAddressChip('State: ${loc.state}', Icons.flag_outlined),
                        if (loc.pincode.isNotEmpty)
                          _buildAddressChip('PIN Code: ${loc.pincode}', Icons.pin_outlined),
                      ],
                    ),
                  ],

                  const SizedBox(height: 8),

                  // Coordinates Data Grid
                  Row(
                    children: [
                      Expanded(
                        child: _buildTelemetryTile(
                          label: 'Latitude',
                          value: hasCoords ? '${loc.latitude.toStringAsFixed(6)}°' : '--',
                          icon: Icons.north_rounded,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTelemetryTile(
                          label: 'Longitude',
                          value: hasCoords ? '${loc.longitude.toStringAsFixed(6)}°' : '--',
                          icon: Icons.east_rounded,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Pinned Bottom Action Controls (Use Current Location + Confirm Location)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Row(
              children: [
                Expanded(
                  flex: 46,
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: isLoading ? null : _fetchCurrentGps,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1A73E8),
                        side: const BorderSide(color: Color(0xFF1A73E8), width: 1.3),
                        backgroundColor: const Color(0xFFF1F7FF),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.my_location_rounded, size: 16),
                          SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'Use Current Location',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 54,
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: isPlaceholder ? null : () => _onConfirmLocation(loc),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A73E8),
                        disabledBackgroundColor: Colors.grey.shade300,
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.grey.shade600,
                        elevation: isPlaceholder ? 0 : 2,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            size: 18,
                            color: isPlaceholder ? Colors.grey.shade600 : Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Confirm Location',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                                color: isPlaceholder ? Colors.grey.shade600 : Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11.5, color: const Color(0xFF1A73E8)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryTile({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(BuildContext context, LocationState state) {
    if (state is LocationLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1A73E8).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A73E8)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                state.message.isNotEmpty ? state.message : 'Detecting your current location...',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF1A73E8), fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    if (state is LocationGpsDisabledState) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.orange.shade50.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: Row(
          children: [
            const Icon(Icons.gps_off_rounded, color: Colors.orange, size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Enable GPS to detect your location',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11.5, color: Colors.black87),
              ),
            ),
            TextButton(
              onPressed: () => context.read<LocationBloc>().add(const OpenGpsSettingsEvent()),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                visualDensity: VisualDensity.compact,
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Enable GPS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    if (state is LocationPermissionDeniedState) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.blue.shade50.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade300),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_off_rounded, color: Color(0xFF1A73E8), size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Location permission denied',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11.5, color: Colors.black87),
              ),
            ),
            TextButton(
              onPressed: () => context.read<LocationBloc>().add(const RequestLocationPermissionEvent()),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                visualDensity: VisualDensity.compact,
                backgroundColor: const Color(0xFF1A73E8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Allow', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    if (state is LocationPermissionPermanentlyDeniedState) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.amber.shade50.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.shade400),
        ),
        child: Row(
          children: [
            const Icon(Icons.settings_suggest_rounded, color: Colors.amber, size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Location permission denied',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11.5, color: Colors.black87),
              ),
            ),
            TextButton(
              onPressed: () => context.read<LocationBloc>().add(const OpenAppSettingsEvent()),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                visualDensity: VisualDensity.compact,
                backgroundColor: Colors.amber.shade800,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Settings', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    if (state is LocationErrorState) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.red.shade50.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade300),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                state.userFriendlyMessage,
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11.5, color: Colors.black87),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () => context.read<LocationBloc>().add(const FetchDeviceGpsLocationEvent(forceRefresh: true)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                visualDensity: VisualDensity.compact,
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Retry', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
