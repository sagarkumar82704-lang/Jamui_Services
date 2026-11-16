import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/location_service.dart';
import '../../domain/entities/provider_location_entity.dart';
import '../bloc/location_bloc.dart';
import '../bloc/location_event.dart';
import '../bloc/location_state.dart';

enum MapStyleType {
  googleRoadmap,
  googleSatellite,
  googleTerrain,
}

class ProviderLocationPickerScreen extends StatefulWidget {
  final double initialRadiusKm;
  final ProviderLocationEntity? initialLocation;
  final String? providerId;

  const ProviderLocationPickerScreen({
    super.key,
    this.initialRadiusKm = 10.0,
    this.initialLocation,
    this.providerId,
  });

  @override
  State<ProviderLocationPickerScreen> createState() => _ProviderLocationPickerScreenState();
}

class _ProviderLocationPickerScreenState extends State<ProviderLocationPickerScreen> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounceTimer;
  Timer? _mapDragDebounceTimer;

  MapStyleType _mapStyle = MapStyleType.googleRoadmap;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late double _serviceRadiusKm;

  // Free & Legal Open-Source Tiles (OpenStreetMap & CARTO Basemaps)
  String get _currentTileUrl {
    switch (_mapStyle) {
      case MapStyleType.googleRoadmap:
        return 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';
      case MapStyleType.googleSatellite:
        return 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';
      case MapStyleType.googleTerrain:
        return 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png';
    }
  }

  List<String> get _currentSubdomains {
    switch (_mapStyle) {
      case MapStyleType.googleRoadmap:
        return const ['a', 'b', 'c'];
      case MapStyleType.googleSatellite:
        return const ['a', 'b', 'c', 'd'];
      case MapStyleType.googleTerrain:
        return const ['a', 'b', 'c', 'd'];
    }
  }

  @override
  void initState() {
    super.initState();
    _serviceRadiusKm = widget.initialRadiusKm;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.initialLocation != null && widget.initialLocation!.latitude != 0.0) {
      context.read<LocationBloc>().add(SetExplicitLocationEvent(
        location: widget.initialLocation!,
        moveCamera: true,
        zoom: 16.5,
      ));
    } else {
      context.read<LocationBloc>().add(FetchDeviceGpsLocationEvent(serviceRadiusKm: _serviceRadiusKm));
    }
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _mapDragDebounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _pulseController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _searchDebounceTimer?.cancel();
    final clean = query.trim();
    if (clean.length < 3) {
      context.read<LocationBloc>().add(const ClearSearchSuggestionsEvent());
      return;
    }
    _searchDebounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        final currentState = context.read<LocationBloc>().state;
        double? lat;
        double? lng;
        if (currentState is LocationLoaded) {
          lat = currentState.location.latitude;
          lng = currentState.location.longitude;
        }
        context.read<LocationBloc>().add(SearchPlacesEvent(clean, providerLat: lat, providerLng: lng));
      }
    });
  }

  void _onSelectSearchResult(ProviderLocationEntity result) {
    _searchFocusNode.unfocus();
    _searchController.text = result.placeName.isNotEmpty ? result.placeName : result.formattedAddress;
    context.read<LocationBloc>().add(const ClearSearchSuggestionsEvent());
    final locWithRadius = result.copyWith(serviceRadiusKm: _serviceRadiusKm);
    context.read<LocationBloc>().add(SetExplicitLocationEvent(
          location: locWithRadius,
          moveCamera: true,
          zoom: 16.5,
        ));
    _mapController.move(LatLng(result.latitude, result.longitude), 16.5);
  }

  void _clearSearch() {
    _searchController.clear();
    context.read<LocationBloc>().add(const ClearSearchSuggestionsEvent());
  }

  void _onConfirmLocation(ProviderLocationEntity location) {
    final confirmedLoc = location.copyWith(serviceRadiusKm: _serviceRadiusKm);
    context.read<LocationBloc>().add(ConfirmSelectedLocationEvent(confirmedLoc, providerId: widget.providerId));
    Navigator.of(context).pop(confirmedLoc);
  }

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, (currentZoom + 1.0).clamp(3.0, 20.0));
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, (currentZoom - 1.0).clamp(3.0, 20.0));
  }

  void _recenterToGps(ProviderLocationEntity? location) {
    _searchFocusNode.unfocus();
    context.read<LocationBloc>().add(FetchDeviceGpsLocationEvent(forceRefresh: true, serviceRadiusKm: _serviceRadiusKm));
    if (location != null && location.latitude != 0.0) {
      _mapController.move(LatLng(location.latitude, location.longitude), 16.5);
    }
  }

  void _toggleMapLayer() {
    setState(() {
      if (_mapStyle == MapStyleType.googleRoadmap) {
        _mapStyle = MapStyleType.googleSatellite;
      } else if (_mapStyle == MapStyleType.googleSatellite) {
        _mapStyle = MapStyleType.googleTerrain;
      } else {
        _mapStyle = MapStyleType.googleRoadmap;
      }
    });
  }

  void _onMapPositionChanged(MapCamera camera, bool hasGesture) {
    if (hasGesture) {
      context.read<LocationBloc>().add(
            UpdateCameraCenterCoordinatesEvent(
              latitude: camera.center.latitude,
              longitude: camera.center.longitude,
            ),
          );

      _mapDragDebounceTimer?.cancel();
      _mapDragDebounceTimer = Timer(const Duration(milliseconds: 350), () {
        if (mounted) {
          context.read<LocationBloc>().add(
                SelectCoordinatesEvent(
                  latitude: camera.center.latitude,
                  longitude: camera.center.longitude,
                  shouldReverseGeocode: true,
                  serviceRadiusKm: _serviceRadiusKm,
                ),
              );
        }
      });
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
      backgroundColor: Colors.white,
      body: BlocConsumer<LocationBloc, LocationState>(
        listener: (context, state) {
          if (state is LocationLoaded) {
            if (state.searchResults.isEmpty) {
              try {
                _mapController.move(
                  LatLng(state.cameraLatitude, state.cameraLongitude),
                  state.zoom,
                );
              } catch (_) {}
            }
          }
        },
        builder: (context, state) {
          if (state is LocationLoading) {
            return _buildLoadingView(state.message);
          }

          if (state is LocationPermissionDeniedState) {
            return _buildPermissionDeniedView(context, state.message);
          }

          if (state is LocationPermissionPermanentlyDeniedState) {
            return _buildPermanentlyDeniedView(context, state.message);
          }

          if (state is LocationGpsDisabledState) {
            return _buildGpsDisabledView(context, state.message);
          }

          if (state is LocationErrorState) {
            return _buildErrorView(context, state);
          }

          if (state is LocationLoaded) {
            return _buildGoogleMapsView(context, state);
          }

          return _buildLoadingView('लोकेशन लोड हो रही है...');
        },
      ),
    );
  }

  Widget _buildGoogleMapsView(BuildContext context, LocationLoaded state) {
    final loc = state.location;
    final markerLatLng = LatLng(loc.latitude, loc.longitude);
    final hasSearchResults = state.searchResults.isNotEmpty;

    return Stack(
      children: [
        // 1. Real Google Maps Render
        GestureDetector(
          onTap: () {
            if (_searchFocusNode.hasFocus) {
              _searchFocusNode.unfocus();
              context.read<LocationBloc>().add(const ClearSearchSuggestionsEvent());
            }
          },
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: markerLatLng,
              initialZoom: state.zoom,
              minZoom: 3.0,
              maxZoom: 20.0,
              onPositionChanged: _onMapPositionChanged,
              onTap: (tapPosition, point) {
                _searchFocusNode.unfocus();
                context.read<LocationBloc>().add(const ClearSearchSuggestionsEvent());
                context.read<LocationBloc>().add(SelectCoordinatesEvent(
                      latitude: point.latitude,
                      longitude: point.longitude,
                      shouldReverseGeocode: true,
                      serviceRadiusKm: _serviceRadiusKm,
                    ));
              },
            ),
            children: [
              TileLayer(
                key: ValueKey(_currentTileUrl),
                urlTemplate: _currentTileUrl,
                fallbackUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: _currentSubdomains,
                maxZoom: 19,
                userAgentPackageName: 'in.apnajamui.app',
              ),
              const SimpleAttributionWidget(
                source: Text('© OpenStreetMap contributors, © CARTO'),
                alignment: Alignment.bottomLeft,
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: markerLatLng,
                    width: 56,
                    height: 56,
                    child: ScaleTransition(
                      scale: _pulseAnimation,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFFEA4335), // Google Red Pin
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black38,
                                  blurRadius: 8,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.storefront_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.black45,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 2. Search Bar & Dropdown
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 14,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87, size: 22),
                        onPressed: () {
                          if (_searchFocusNode.hasFocus) {
                            _searchFocusNode.unfocus();
                            context.read<LocationBloc>().add(const ClearSearchSuggestionsEvent());
                          } else {
                            Navigator.maybePop(context);
                          }
                        },
                      ),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          onChanged: _onSearchChanged,
                          textInputAction: TextInputAction.search,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87),
                          decoration: InputDecoration(
                            hintText: 'दुकान, गाँव या Lat, Long खोजें...',
                            hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade500, fontWeight: FontWeight.normal),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onSubmitted: (val) => _onSearchChanged(val),
                        ),
                      ),
                      if (state.isSearching)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4285F4)),
                          ),
                        )
                      else if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.cancel, size: 20, color: Colors.black54),
                          onPressed: _clearSearch,
                        ),
                      IconButton(
                        tooltip: 'Map Layer',
                        icon: const Icon(Icons.layers_outlined, color: Color(0xFF1A73E8), size: 22),
                        onPressed: _toggleMapLayer,
                      ),
                    ],
                  ),
                ),

                if (hasSearchResults) ...[
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 340),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: state.searchResults.length,
                        separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
                        itemBuilder: (context, index) {
                          final item = state.searchResults[index];
                          final distStr = _formatDistance(loc.latitude, loc.longitude, item.latitude, item.longitude);

                          return InkWell(
                            onTap: () => _onSelectSearchResult(item),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.location_on_outlined, color: Colors.black87, size: 20),
                                      ),
                                      if (distStr.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          distStr,
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.placeName.isNotEmpty ? item.placeName : item.formattedAddress,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                            color: Colors.black87,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          item.formattedAddress,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                            height: 1.2,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(Icons.north_west_rounded, size: 18, color: Colors.grey.shade500),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
              ),
            ),
          ),
        ),

        // 3. Floating Map Controls
        Positioned(
          right: 16,
          bottom: 270,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildControlButton(
                icon: Icons.add,
                tooltip: 'Zoom In',
                onPressed: _zoomIn,
              ),
              const SizedBox(height: 8),
              _buildControlButton(
                icon: Icons.remove,
                tooltip: 'Zoom Out',
                onPressed: _zoomOut,
              ),
              const SizedBox(height: 12),
              _buildControlButton(
                icon: Icons.my_location_rounded,
                tooltip: 'My Location (GPS)',
                color: const Color(0xFF1A73E8),
                iconColor: Colors.white,
                onPressed: () => _recenterToGps(loc),
              ),
            ],
          ),
        ),

        // 4. Bottom Location Card with Service Radius Slider
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 18,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Place Header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEA4335).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.storefront_rounded, color: Color(0xFFEA4335), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              loc.placeName.isNotEmpty ? loc.placeName : 'सर्विस लोकेशन (Service Location)',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              loc.formattedAddress.isNotEmpty
                                  ? loc.formattedAddress
                                  : 'Lat: ${loc.latitude.toStringAsFixed(5)}, Lng: ${loc.longitude.toStringAsFixed(5)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Exact Coordinates Lat / Long Bar & Accuracy Badge
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            'Lat: ${loc.latitude.toStringAsFixed(6)}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            'Lng: ${loc.longitude.toStringAsFixed(6)}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F0FE),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF1A73E8).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.gps_fixed, size: 12, color: Color(0xFF1A73E8)),
                            const SizedBox(width: 4),
                            Text(
                              loc.accuracy != null ? '±${loc.accuracy!.toStringAsFixed(1)}m' : '±1.0m',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1A73E8)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Service Radius Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'सर्विस दायरा (Service Radius):',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${_serviceRadiusKm.toInt()} KM',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.accent),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _serviceRadiusKm,
                    min: 3,
                    max: 30,
                    divisions: 9,
                    activeColor: const Color(0xFF1A73E8),
                    onChanged: (val) {
                      setState(() => _serviceRadiusKm = val);
                      context.read<LocationBloc>().add(UpdateServiceRadiusEvent(val));
                    },
                  ),

                  // Confirm Location CTA
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => _onConfirmLocation(loc),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A73E8),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline_rounded, size: 20),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'यह स्थान और दायरा कन्फर्म करें',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
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
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    Color color = Colors.white,
    Color iconColor = AppColors.textPrimary,
  }) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: iconColor, size: 22),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFF1A73E8)),
            const SizedBox(height: 20),
            Text(
              message,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'कृपया प्रतीक्षा करें, डिवाइस GPS से कनेक्ट हो रहा है...',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionDeniedView(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEA4335).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.location_off_rounded, size: 48, color: Color(0xFFEA4335)),
            ),
            const SizedBox(height: 18),
            const Text(
              'लोकेशन अनुमति आवश्यक है',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  context.read<LocationBloc>().add(const RequestLocationPermissionEvent());
                },
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('अनुमति दें (Allow Permission)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A73E8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            _buildManualPickButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildPermanentlyDeniedView(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.settings_suggest_rounded, size: 48, color: Colors.orange),
            ),
            const SizedBox(height: 18),
            const Text(
              'सेटिंग्स से अनुमति चालू करें',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  context.read<LocationBloc>().add(const OpenAppSettingsEvent());
                },
                icon: const Icon(Icons.settings),
                label: const Text('ऐप सेटिंग्स खोलें (Open Settings)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A73E8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            _buildManualPickButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildGpsDisabledView(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.location_disabled_rounded, size: 48, color: Colors.amber),
            ),
            const SizedBox(height: 18),
            const Text(
              'फोन का GPS बंद है',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  context.read<LocationBloc>().add(const OpenGpsSettingsEvent());
                },
                icon: const Icon(Icons.gps_fixed),
                label: const Text('GPS चालू करें (Enable GPS)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A73E8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                context.read<LocationBloc>().add(FetchDeviceGpsLocationEvent(forceRefresh: true, serviceRadiusKm: _serviceRadiusKm));
              },
              child: const Text('पुनः प्रयास करें (Retry)'),
            ),
            _buildManualPickButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, LocationErrorState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
            ),
            const SizedBox(height: 18),
            const Text(
              'लोकेशन त्रुटि (Error)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 10),
            Text(
              state.userFriendlyMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  context.read<LocationBloc>().add(FetchDeviceGpsLocationEvent(forceRefresh: true, serviceRadiusKm: _serviceRadiusKm));
                },
                icon: const Icon(Icons.refresh),
                label: const Text('पुनः प्रयास करें (Retry)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A73E8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            _buildManualPickButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildManualPickButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: OutlinedButton.icon(
        onPressed: () {
          final fallbackLoc = (widget.initialLocation != null && widget.initialLocation!.latitude != 0.0)
              ? widget.initialLocation!
              : ProviderLocationEntity(
                  latitude: 24.9200,
                  longitude: 86.2200,
                  placeName: 'स्थान चुनें',
                  formattedAddress: 'कृपया पिन को अपने कार्यस्थल पर ले जाएं या ऊपर सर्च करें',
                  city: '',
                  district: '',
                  state: '',
                  pincode: '',
                  serviceRadiusKm: _serviceRadiusKm,
                  timestamp: DateTime.now(),
                );
          context.read<LocationBloc>().add(SetExplicitLocationEvent(
                location: fallbackLoc,
                moveCamera: true,
                zoom: 15.0,
              ));
        },
        icon: const Icon(Icons.touch_app_outlined),
        label: const Text('मैप पर खुद स्थान चुनें (Select on Map)'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1A73E8),
          side: const BorderSide(color: Color(0xFF1A73E8)),
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
