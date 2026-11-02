import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/location_service.dart';
import '../../../discovery/presentation/bloc/discovery_bloc.dart';
import '../../../discovery/presentation/bloc/discovery_event.dart';
import '../../domain/entities/customer_location_entity.dart';
import '../bloc/location_bloc.dart';
import '../bloc/location_event.dart';
import '../bloc/location_state.dart';

class LocationPickerScreen extends StatefulWidget {
  final bool isFromOnboarding;
  // Deprecated: Kept as optional Object? for backward compatibility with existing tests
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
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounceTimer;

  // Active location displayed on the card (retained across loading/error states)
  late CustomerLocationEntity _activeLocation;

  @override
  void initState() {
    super.initState();

    // Initialize with current loaded location if it has real valid coordinates
    final currentBlocState = context.read<LocationBloc>().state;
    if (currentBlocState is LocationLoaded && currentBlocState.location.hasValidCoordinates) {
      _activeLocation = currentBlocState.location;
    } else {
      _activeLocation = CustomerLocationEntity(
        latitude: 0.0,
        longitude: 0.0,
        placeName: 'स्थान का चयन करें',
        formattedAddress: 'कृपया "वर्तमान स्थान खोजें" बटन दबाकर वास्तविक GPS स्थान प्राप्त करें',
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
    _searchController.dispose();
    _searchFocusNode.dispose();
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
        context.read<LocationBloc>().add(
              SearchPlacesEvent(
                clean,
                customerLat: _activeLocation.hasValidCoordinates ? _activeLocation.latitude : null,
                customerLng: _activeLocation.hasValidCoordinates ? _activeLocation.longitude : null,
              ),
            );
      }
    });
  }

  void _onSelectSearchResult(CustomerLocationEntity result) {
    _searchFocusNode.unfocus();
    _searchController.text = result.placeName.isNotEmpty ? result.placeName : result.formattedAddress;
    context.read<LocationBloc>().add(const ClearSearchSuggestionsEvent());
    context.read<LocationBloc>().add(SetExplicitLocationEvent(
          location: result,
          moveCamera: false,
        ));
    setState(() {
      _activeLocation = result;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    context.read<LocationBloc>().add(const ClearSearchSuggestionsEvent());
  }

  void _fetchCurrentGps() {
    _searchFocusNode.unfocus();
    context.read<LocationBloc>().add(const FetchDeviceGpsLocationEvent(forceRefresh: true));
  }

  void _onConfirmLocation(CustomerLocationEntity location) {
    // Strict Guard: Ensure coordinates are real and valid, not 0.0 or initial placeholder
    if (!location.hasValidCoordinates || (location.latitude == 0.0 && location.longitude == 0.0) || location.placeName == 'स्थान का चयन करें') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('कृपया पहले "वर्तमान स्थान खोजें" बटन दबाकर वास्तविक GPS स्थान प्राप्त करें।'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmedLocation = location.placeName == 'स्थान खोजा जा रहा है...'
        ? location.copyWith(
            placeName: 'चयनित स्थान',
            formattedAddress: 'GPS: ${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
          )
        : location;

    // 1. Confirm and save real coordinates in LocationBloc / Firestore
    context.read<LocationBloc>().add(ConfirmSelectedLocationEvent(confirmedLocation));

    // 2. Update DiscoveryBloc with confirmed real coordinates
    final areaDisplay = confirmedLocation.placeName.isNotEmpty && confirmedLocation.placeName != 'स्थान का चयन करें'
        ? (confirmedLocation.pincode.isNotEmpty ? '${confirmedLocation.placeName} (${confirmedLocation.pincode})' : confirmedLocation.placeName)
        : 'GPS (${confirmedLocation.latitude.toStringAsFixed(4)}, ${confirmedLocation.longitude.toStringAsFixed(4)})';

    context.read<DiscoveryBloc>().add(UpdateCustomerLocationEvent(
          latitude: confirmedLocation.latitude,
          longitude: confirmedLocation.longitude,
          areaName: areaDisplay,
        ));

    // 3. Navigation
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
      appBar: AppBar(
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
              'लोकेशन चयन (Select Location)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              'सटीक सेवा के लिए वास्तविक GPS स्थान',
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
            tooltip: 'GPS रिफ्रेश करें',
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF1A73E8)),
            onPressed: _fetchCurrentGps,
          ),
        ],
      ),
      body: BlocConsumer<LocationBloc, LocationState>(
        listener: (context, state) {
          if (state is LocationLoaded) {
            setState(() {
              _activeLocation = state.location;
            });
          }
        },
        builder: (context, state) {
          final loc = (state is LocationLoaded) ? state.location : _activeLocation;
          final isGpsLocked = (state is LocationLoaded) && state.isGpsLocked;
          final isLoading = state is LocationLoading;
          final hasSearchResults = (state is LocationLoaded) && state.searchResults.isNotEmpty;
          final isSearching = (state is LocationLoaded) && state.isSearching;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Search Bar for Place, Town, or Landmark
                  _buildSearchBar(isSearching),

                  // Search Suggestions List Dropdown
                  if (hasSearchResults) ...[
                    const SizedBox(height: 8),
                    _buildSearchResultsDropdown(state.searchResults, loc),
                  ],

                  const SizedBox(height: 12),

                  // 2. Status / Error / Permission Banners
                  _buildStatusBanner(context, state),

                  const SizedBox(height: 12),

                  // 3. Hero GPS Coordinates & Location Card
                  _buildHeroLocationCard(loc, isGpsLocked, isLoading),

                  const SizedBox(height: 16),

                  // 4. Primary Action: "वर्तमान स्थान खोजें (Use Current Location)"
                  SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: isLoading ? null : _fetchCurrentGps,
                      icon: isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A73E8)),
                            )
                          : const Icon(Icons.my_location_rounded, size: 20, color: Color(0xFF1A73E8)),
                      label: const Text(
                        'वर्तमान स्थान खोजें (Use Current Location)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A73E8),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFFE8F0FE),
                        side: const BorderSide(color: Color(0xFF1A73E8), width: 1.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 5. Confirm Location CTA Button
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () => _onConfirmLocation(loc),
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 22, color: Colors.white),
                      label: const Text(
                        'यह स्थान चुनें (Confirm Location)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A73E8),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 6. Security & Transparency Notice
                  _buildSecurityNoticeCard(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar(bool isSearching) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Icon(Icons.search_rounded, color: Colors.black54, size: 22),
          ),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87),
              decoration: InputDecoration(
                hintText: 'गाँव, जगह या शहर खोजें...',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onSubmitted: (val) => _onSearchChanged(val),
            ),
          ),
          if (isSearching)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A73E8)),
              ),
            )
          else if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.cancel, size: 18, color: Colors.black45),
              onPressed: _clearSearch,
            ),
        ],
      ),
    );
  }

  Widget _buildSearchResultsDropdown(List<CustomerLocationEntity> results, CustomerLocationEntity loc) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: results.length,
          separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
          itemBuilder: (context, index) {
            final item = results[index];
            final distStr = _formatDistance(loc.latitude, loc.longitude, item.latitude, item.longitude);

            return InkWell(
              onTap: () => _onSelectSearchResult(item),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.location_on_outlined, color: Color(0xFF1A73E8), size: 18),
                    ),
                    const SizedBox(width: 12),
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
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeroLocationCard(CustomerLocationEntity loc, bool isGpsLocked, bool isLoading) {
    final hasCoords = loc.hasValidCoordinates && (loc.latitude != 0.0 || loc.longitude != 0.0);
    final isPlaceholder = loc.placeName == 'स्थान का चयन करें';

    // Status Chip Configuration
    Color statusColor;
    Color statusBgColor;
    IconData statusIcon;
    String statusText;

    if (isLoading) {
      statusColor = const Color(0xFF1A73E8);
      statusBgColor = const Color(0xFFE8F0FE);
      statusIcon = Icons.hourglass_top_rounded;
      statusText = 'GPS सिग्नल खोजा जा रहा है...';
    } else if (isGpsLocked && hasCoords) {
      statusColor = const Color(0xFF1E8E3E);
      statusBgColor = const Color(0xFFE6F4EA);
      statusIcon = Icons.gps_fixed;
      statusText = 'लाइव GPS लॉक (Hardware Fix)';
    } else if (hasCoords) {
      statusColor = const Color(0xFF1A73E8);
      statusBgColor = const Color(0xFFE8F0FE);
      statusIcon = Icons.pin_drop_rounded;
      statusText = 'चयनित स्थान (Selected Location)';
    } else {
      statusColor = Colors.orange.shade800;
      statusBgColor = Colors.orange.shade50;
      statusIcon = Icons.location_searching_rounded;
      statusText = 'स्थान उपलब्ध नहीं';
    }

    // Determine place display
    final placeTitle = isPlaceholder
        ? 'स्थान का चयन करें'
        : (loc.placeName.isNotEmpty && loc.placeName != 'स्थान खोजा जा रहा है...'
            ? loc.placeName
            : 'GPS स्थान');

    // Determine address display
    final addressDisplay = isPlaceholder
        ? 'कृपया "वर्तमान स्थान खोजें" बटन दबाकर GPS स्थान प्राप्त करें'
        : (loc.formattedAddress.isNotEmpty
            ? loc.formattedAddress
            : (hasCoords ? 'GPS: ${loc.latitude.toStringAsFixed(6)}, ${loc.longitude.toStringAsFixed(6)}' : '--'));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Pill Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (loc.accuracy != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    'Accuracy: ±${loc.accuracy!.toStringAsFixed(1)}m',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 14),

          // Place Name
          Text(
            placeTitle,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 4),

          // Formatted Address
          Text(
            addressDisplay,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              height: 1.35,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          const SizedBox(height: 14),

          // Coordinates Data Grid
          Row(
            children: [
              Expanded(
                child: _buildTelemetryTile(
                  label: 'अक्षांश (Latitude)',
                  value: hasCoords ? '${loc.latitude.toStringAsFixed(6)}°' : '--',
                  icon: Icons.north_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTelemetryTile(
                  label: 'देशांतर (Longitude)',
                  value: hasCoords ? '${loc.longitude.toStringAsFixed(6)}°' : '--',
                  icon: Icons.east_rounded,
                ),
              ),
            ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: AppColors.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(BuildContext context, LocationState state) {
    if (state is LocationLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F0FE),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1A73E8).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A73E8)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                state.message.isNotEmpty ? state.message : 'GPS से वास्तविक स्थान खोजा जा रहा है...',
                style: const TextStyle(fontSize: 12, color: Color(0xFF1A73E8), fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    if (state is LocationGpsDisabledState) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: Row(
          children: [
            const Icon(Icons.gps_off_rounded, color: Colors.orange, size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'डिवाइस GPS बंद है। कृपया चालू करें।',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.black87),
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
              child: const Text('GPS चालू करें', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    if (state is LocationPermissionDeniedState) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade300),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_off_rounded, color: Color(0xFF1A73E8), size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'सटीक GPS के लिए लोकेशन अनुमति दें।',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.black87),
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
              child: const Text('अनुमति दें', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    if (state is LocationPermissionPermanentlyDeniedState) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.shade400),
        ),
        child: Row(
          children: [
            const Icon(Icons.settings_suggest_rounded, color: Colors.amber, size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'अनुमति सेटिंग्स से बंद है।',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.black87),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade300),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                state.userFriendlyMessage,
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: Colors.black87),
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
              child: const Text('पुनः प्रयास', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildSecurityNoticeCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.security_rounded, size: 16, color: Colors.grey.shade700),
              const SizedBox(width: 8),
              const Text(
                'सटीक GPS एवं सुरक्षा',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '• आपकी वास्तविक GPS लोकेशन का उपयोग केवल आपके निकटतम सेवा प्रदाता खोजने और सेवा डिलीवरी के लिए किया जाता है।\n'
            '• बिना GPS फिक्स के कोई काल्पनिक गाँव या पुरानी अमान्य लोकेशन सेव नहीं की जाती है।',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.4),
          ),
        ],
      ),
    );
  }
}
