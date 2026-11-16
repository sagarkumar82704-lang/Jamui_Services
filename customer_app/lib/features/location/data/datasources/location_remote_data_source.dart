import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/config/maps_config.dart';
import '../../domain/entities/customer_location_entity.dart';

abstract class LocationRemoteDataSource {
  Future<bool> isLocationServiceEnabled();
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Future<bool> openAppSettings();
  Future<bool> openLocationSettings();
  Future<Position> getCurrentPosition();
  Future<CustomerLocationEntity> reverseGeocode(double latitude, double longitude, {double? accuracy});
  Future<List<CustomerLocationEntity>> searchPlaces(
    String query, {
    double? customerLat,
    double? customerLng,
  });
}

class LocationRemoteDataSourceImpl implements LocationRemoteDataSource {
  final http.Client _client;
  final bool enforceNominatimRateLimit;

  LocationRemoteDataSourceImpl({
    http.Client? client,
    this.enforceNominatimRateLimit = true,
  }) : _client = client ?? http.Client();

  static DateTime? _lastNominatimCall;

  @visibleForTesting
  static void clearCachesForTesting() {
    _inMemoryReverseGeocodeCache.clear();
    _searchQueryCache.clear();
    _lastNominatimCall = null;
  }

  @override
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  @override
  Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  @override
  Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }

  @override
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  @override
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  @override
  Future<Position> getCurrentPosition() async {
    final serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceDisabledException();
    }

    LocationPermission permission = await checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await requestPermission();
      if (permission == LocationPermission.denied) {
        throw const PermissionDeniedException('Location permission denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw const PermissionDeniedException('Location permission permanently denied. Please enable location permission in Settings.');
    }

    Position pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, // FusedLocationProvider (Wi-Fi + Cell + GPS)
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (kDebugMode) {
        debugPrint('📍 [GPS_DIAG] Fresh GPS Position Acquired:');
        debugPrint('   Lat: ${pos.latitude}, Lng: ${pos.longitude}');
        debugPrint('   Accuracy: ±${pos.accuracy.toStringAsFixed(1)}m, Timestamp: ${pos.timestamp}');
      }
    } on TimeoutException {
      if (kDebugMode) {
        debugPrint('⚠️ [GPS_DIAG] Fresh GPS acquisition timed out (12s). Checking last known location...');
      }
      final lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null && (lastPos.latitude != 0.0 || lastPos.longitude != 0.0)) {
        if (kDebugMode) {
          final age = DateTime.now().difference(lastPos.timestamp).inSeconds;
          debugPrint('📍 [GPS_DIAG] Using last known position (age: ${age}s, acc: ±${lastPos.accuracy.toStringAsFixed(1)}m)');
        }
        return lastPos;
      }
      rethrow;
    }

    return pos;
  }

  // In-memory reverse geocoding cache (~11m grid resolution) to eliminate duplicate API requests
  static final Map<String, CustomerLocationEntity> _inMemoryReverseGeocodeCache = {};
  static const int _maxCacheEntries = 200;

  // In-memory search query cache to prevent repeat network calls
  static final Map<String, List<CustomerLocationEntity>> _searchQueryCache = {};

  static String _coordCacheKey(double lat, double lng) {
    return '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';
  }

  static void _addToCache(String key, CustomerLocationEntity entity) {
    if (_inMemoryReverseGeocodeCache.length >= _maxCacheEntries) {
      _inMemoryReverseGeocodeCache.remove(_inMemoryReverseGeocodeCache.keys.first);
    }
    _inMemoryReverseGeocodeCache[key] = entity;
    _saveToDiskCache(key, entity);
  }

  static Future<void> _saveToDiskCache(String key, CustomerLocationEntity entity) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('geo_cache_v5_$key', jsonEncode(entity.toMap()));
    } catch (_) {}
  }

  static Future<void> _removeFromDiskCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('geo_cache_v5_$key');
    } catch (_) {}
  }

  static Future<CustomerLocationEntity?> _getFromDiskCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('geo_cache_v5_$key');
      if (str != null && str.isNotEmpty) {
        final map = jsonDecode(str) as Map<String, dynamic>;
        return CustomerLocationEntity.fromMap(map);
      }
    } catch (_) {}
    return null;
  }

  // Monotonically-increasing counter so we can detect stale responses
  int _geocodeSeq = 0;

  @override
  Future<CustomerLocationEntity> reverseGeocode(double latitude, double longitude, {double? accuracy}) async {
    // Capture sequence at start; if a newer call arrives we discard this result
    final mySeq = ++_geocodeSeq;
    final corrId = 'LOC_CORR_${DateTime.now().millisecondsSinceEpoch}_$mySeq';
    final cacheKey = _coordCacheKey(latitude, longitude);

    final distToKhaira = Geolocator.distanceBetween(latitude, longitude, 24.8490, 86.2130);
    final cached = _inMemoryReverseGeocodeCache[cacheKey];
    if (cached != null) {
      final isStaleKhaira = (cached.placeName.toLowerCase().contains('khaira') ||
              cached.placeName.contains('खैरा') ||
              cached.pincode == '811317') &&
          distToKhaira > 3500.0;

      if (!isStaleKhaira &&
          cached.placeName.isNotEmpty &&
          cached.placeName != 'Detecting location...' &&
          cached.placeName != 'स्थान खोजा जा रहा है...') {
        if (kDebugMode) {
          debugPrint('⚡ [$corrId] Memory Cache HIT: $cacheKey -> "${cached.placeName}" | "${cached.formattedAddress}"');
        }
        return cached;
      } else {
        _inMemoryReverseGeocodeCache.remove(cacheKey);
        _removeFromDiskCache(cacheKey);
      }
    }

    final diskCached = await _getFromDiskCache(cacheKey);
    if (diskCached != null) {
      final isStaleKhaira = (diskCached.placeName.toLowerCase().contains('khaira') ||
              diskCached.placeName.contains('खैरा') ||
              diskCached.pincode == '811317') &&
          distToKhaira > 3500.0;

      if (!isStaleKhaira &&
          diskCached.placeName.isNotEmpty &&
          diskCached.placeName != 'Detecting location...' &&
          diskCached.placeName != 'स्थान खोजा जा रहा है...') {
        _inMemoryReverseGeocodeCache[cacheKey] = diskCached;
        if (kDebugMode) {
          debugPrint('⚡ [$corrId] Disk Cache HIT: $cacheKey -> "${diskCached.placeName}" | "${diskCached.formattedAddress}"');
        }
        return diskCached;
      } else {
        _removeFromDiskCache(cacheKey);
      }
    }

    String placeName = '';
    String poi = '';
    String road = '';
    String neighbourhood = '';
    String suburb = '';
    String hamlet = '';
    String village = '';
    String town = '';
    String subdistrict = '';
    String district = '';
    String state = '';
    String pincode = '';
    String formattedAddress = '';

    if (kDebugMode) {
      debugPrint('🔍 [$corrId] REVERSE GEOCODE START: Lat=$latitude, Lng=$longitude (Cache MISS)');
    }

    // ── Lazy Cloud Sync: only fetch if paid Google Geocoding is enabled
    if (MapsConfig.enablePaidGoogleGeocoding && !MapsConfig.hasGoogleKey) {
      await MapsConfig.fetchFromCloud();
    }

    // ── STEP 0: Google Geocoding API (Ultra Accurate POI / Village / Tola level)
    if (MapsConfig.hasGoogleKey) {
      try {
        final googleUrl = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=$latitude,$longitude&key=${MapsConfig.googleMapsApiKey}&language=hi&region=IN',
        );
        final response = await _client.get(
          googleUrl,
          headers: {
            'X-Android-Package': 'com.jamuiservice.customer',
            'X-Android-Cert': '5CB44C62DB96B43508899DC295437DE2A16741F0',
          },
        ).timeout(const Duration(seconds: 6));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final status = data['status'] as String? ?? '';
          if (status == 'OK') {
            final results = data['results'] as List<dynamic>? ?? [];
            if (results.isNotEmpty) {
              final firstResult = results[0] as Map<String, dynamic>;
              final addressComponents = firstResult['address_components'] as List<dynamic>? ?? [];
              final googleFormatted = (firstResult['formatted_address'] as String? ?? '').trim();

              String gPoi = '';
              String gSublocality2 = '';
              String gSublocality1 = '';
              String gSublocality = '';
              String gNeighborhood = '';
              String gLocality = '';
              String gSubdistrict = '';
              String gDistrict = '';
              String gState = '';
              String gPincode = '';
              String gPremise = '';

              for (final comp in addressComponents) {
                final types = (comp['types'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
                final longName = (comp['long_name'] as String? ?? '').trim();

                if (types.contains('point_of_interest') || types.contains('establishment')) {
                  if (gPoi.isEmpty) gPoi = longName;
                } else if (types.contains('subpremise') || types.contains('premise')) {
                  if (gPremise.isEmpty) gPremise = longName;
                } else if (types.contains('sublocality_level_2')) {
                  gSublocality2 = longName;
                } else if (types.contains('sublocality_level_1')) {
                  gSublocality1 = longName;
                } else if (types.contains('sublocality')) {
                  gSublocality = longName;
                } else if (types.contains('neighborhood')) {
                  gNeighborhood = longName;
                } else if (types.contains('locality')) {
                  gLocality = longName;
                } else if (types.contains('administrative_area_level_3')) {
                  gSubdistrict = longName;
                } else if (types.contains('administrative_area_level_2')) {
                  gDistrict = longName;
                } else if (types.contains('administrative_area_level_1')) {
                  gState = longName;
                } else if (types.contains('postal_code')) {
                  gPincode = longName;
                }
              }

              final specificVillage = gSublocality2.isNotEmpty
                  ? gSublocality2
                  : (gSublocality1.isNotEmpty
                      ? gSublocality1
                      : (gSublocality.isNotEmpty ? gSublocality : (gNeighborhood.isNotEmpty ? gNeighborhood : gLocality)));

              // Determine District (If admin_2 is Division, use admin_3)
              String resolvedDistrict = gDistrict;
              if (resolvedDistrict.contains('डिवीजन') || resolvedDistrict.contains('Division') || resolvedDistrict.isEmpty) {
                resolvedDistrict = gSubdistrict.isNotEmpty ? gSubdistrict : '';
              }

              final resolvedCity = gLocality.isNotEmpty ? gLocality : (gSubdistrict.isNotEmpty ? gSubdistrict : resolvedDistrict);
              final resolvedState = gState;

              String placeTitle = '';
              if (gPoi.isNotEmpty) {
                placeTitle = gPoi;
              } else if (specificVillage.isNotEmpty) {
                placeTitle = specificVillage;
              } else if (gLocality.isNotEmpty) {
                placeTitle = gLocality;
              } else if (gSubdistrict.isNotEmpty) {
                placeTitle = gSubdistrict;
              } else {
                placeTitle = resolvedDistrict;
              }

              // Strip plus code (e.g. "R6X7+V8V, ") if present at start of googleFormatted
              String cleanFormatted = googleFormatted.replaceFirst(RegExp(r'^[A-Z0-9\+]+\s*,\s*'), '').trim();
              if (cleanFormatted.isEmpty || !cleanFormatted.contains(placeTitle)) {
                final parts = <String>[];
                if (placeTitle.isNotEmpty) parts.add(placeTitle);
                if (gSubdistrict.isNotEmpty && gSubdistrict != placeTitle) parts.add(gSubdistrict);
                if (resolvedDistrict.isNotEmpty && resolvedDistrict != placeTitle && resolvedDistrict != gSubdistrict) {
                  parts.add(resolvedDistrict);
                }
                if (resolvedState.isNotEmpty) parts.add(resolvedState);
                if (gPincode.isNotEmpty) parts.add(gPincode);
                cleanFormatted = parts.join(', ');
              }

              // Stale check
              if (mySeq != _geocodeSeq) {
                return CustomerLocationEntity(
                  latitude: latitude,
                  longitude: longitude,
                  placeName: '',
                  formattedAddress: '',
                  city: '',
                  district: '',
                  state: '',
                  pincode: '',
                  timestamp: DateTime.now(),
                );
              }

              if (kDebugMode) {
                debugPrint('📍 [LOCATION DEBUG] Google Geocoding Success: placeTitle=$placeTitle, address=$cleanFormatted');
              }

              final googleEntity = CustomerLocationEntity(
                latitude: latitude,
                longitude: longitude,
                placeName: placeTitle,
                formattedAddress: cleanFormatted,
                village: specificVillage.isNotEmpty ? specificVillage : placeTitle,
                locality: gPoi.isNotEmpty ? gPoi : (specificVillage.isNotEmpty ? specificVillage : placeTitle),
                suburb: gNeighborhood.isNotEmpty ? gNeighborhood : gSublocality1,
                block: gSubdistrict,
                city: resolvedCity,
                district: resolvedDistrict,
                state: resolvedState,
                pincode: gPincode,
                accuracy: accuracy,
                timestamp: DateTime.now(),
              );
              _addToCache(cacheKey, googleEntity);
              return googleEntity;
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ [LOCATION DEBUG] Google Geocoding error: $e');
      }
    }

    // ── STEP 1: Nominatim (OSM) — Reverse geocode with high zoom (Respecting 1 req/sec public usage policy)
    bool nominatimSucceeded = false;
    if (poi.isEmpty && village.isEmpty && town.isEmpty) {
      try {
        if (enforceNominatimRateLimit && _lastNominatimCall != null) {
          final elapsedMs = DateTime.now().difference(_lastNominatimCall!).inMilliseconds;
          if (elapsedMs < 1000 && elapsedMs >= 0) {
            await Future.delayed(Duration(milliseconds: 1000 - elapsedMs));
          }
        }
        _lastNominatimCall = DateTime.now();

        final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=$latitude&lon=$longitude&zoom=18&addressdetails=1',
        );
        final response = await _client.get(
          uri,
          headers: {
            'User-Agent': 'ApnaJamuiCustomerApp/1.0 (contact: support@apnajamui.in)',
            'Accept': 'application/json',
            'Accept-Language': 'en',
          },
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          nominatimSucceeded = true;
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final address = data['address'] as Map<String, dynamic>?;
          final osmName = (data['name'] as String? ?? '').trim();

          if (address != null) {
            final vRaw = (address['village'] as String? ?? '').trim();
            final hamletRaw = (address['hamlet'] as String? ??
                    address['isolated_dwelling'] as String? ??
                    address['allotments'] as String? ??
                    '')
                .trim();
            final suburbRaw = (address['suburb'] as String? ??
                    address['neighbourhood'] as String? ??
                    address['residential'] as String? ??
                    address['quarter'] as String? ??
                    '')
                .trim();
            final nRaw = (address['neighbourhood'] as String? ??
                    address['suburb'] as String? ??
                    address['residential'] as String? ??
                    address['quarter'] as String? ??
                    address['locality'] as String? ??
                    address['amenity'] as String? ??
                    address['building'] as String? ??
                    address['shop'] as String? ??
                    address['place'] as String? ??
                    '')
                .trim();
            final roadRaw = (address['road'] as String? ??
                    address['path'] as String? ??
                    address['pedestrian'] as String? ??
                    '')
                .trim();
            final townRaw = (address['town'] as String? ??
                    address['city'] as String? ??
                    address['municipality'] as String? ??
                    '')
                .trim();
            final subdistrictRaw = (address['subdistrict'] as String? ??
                    address['county'] as String? ??
                    address['tehsil'] as String? ??
                    address['taluk'] as String? ??
                    '')
                .trim();
            final districtRaw = (address['state_district'] as String? ??
                    address['district'] as String? ??
                    '')
                .trim();
            final stateRaw = (address['state'] as String? ?? '').trim();
            final postcodeRaw = (address['postcode'] as String? ?? '').trim();

            if (kDebugMode) {
              debugPrint('🌐 [$corrId] Nominatim HTTP 200 | Raw: osmName="$osmName", road="$roadRaw", nbh="$nRaw", suburb="$suburbRaw", hamlet="$hamletRaw", v="$vRaw", town="$townRaw", county="$subdistrictRaw", dist="$districtRaw", pin="$postcodeRaw"');
            }

            if (vRaw.isNotEmpty) village = vRaw;
            if (hamletRaw.isNotEmpty) hamlet = hamletRaw;
            if (suburbRaw.isNotEmpty) suburb = suburbRaw;
            if (nRaw.isNotEmpty) neighbourhood = nRaw;
            if (roadRaw.isNotEmpty) road = roadRaw;
            if (townRaw.isNotEmpty) town = townRaw;
            if (subdistrictRaw.isNotEmpty) subdistrict = subdistrictRaw;
            if (districtRaw.isNotEmpty) district = districtRaw;
            if (stateRaw.isNotEmpty) state = stateRaw;
            if (postcodeRaw.isNotEmpty) pincode = postcodeRaw;

            if (osmName.isNotEmpty &&
                osmName.toLowerCase() != subdistrictRaw.toLowerCase() &&
                osmName.toLowerCase() != districtRaw.toLowerCase()) {
              poi = osmName;
            }
          }
        } else {
          if (kDebugMode) {
            debugPrint('⚠️ [$corrId] Nominatim HTTP ${response.statusCode}');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ [$corrId] Nominatim reverse error: $e');
        }
      }
    }

    // ── STEP 2: Photon (Komoot) — Enrich with local POIs, hamlets, streets
    bool photonSucceeded = false;
    if (poi.isEmpty || village.isEmpty) {
      try {
        final photonUrl = 'https://photon.komoot.io/reverse?lat=$latitude&lon=$longitude';
        final photonRes = await _client.get(
          Uri.parse(photonUrl),
          headers: {
            'User-Agent': 'ApnaJamuiCustomerApp/1.0 (contact: support@apnajamui.in)',
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 5));

        if (photonRes.statusCode == 200) {
          photonSucceeded = true;
          final pData = jsonDecode(photonRes.body) as Map<String, dynamic>;
          final features = pData['features'] as List<dynamic>? ?? [];

          for (final feat in features) {
            final props = (feat['properties'] as Map<String, dynamic>?) ?? {};
            final country = (props['country'] as String? ?? '').toLowerCase().trim();
            final countryCode = (props['countrycode'] as String? ?? '').toLowerCase().trim();
            // Strictly reject non-Indian results
            if (country.isNotEmpty && country != 'india' && country != 'भारत' && countryCode != 'in') {
              continue;
            }

            final pName = (props['name'] as String? ?? '').trim();
            final pStreet = (props['street'] as String? ?? '').trim();
            final pSuburb = (props['suburb'] as String? ?? props['locality'] as String? ?? '').trim();
            final pVillage = (props['village'] as String? ?? '').trim();
            final pHamlet = (props['hamlet'] as String? ?? props['locality'] as String? ?? '').trim();
            final pTown = (props['city'] as String? ?? props['town'] as String? ?? '').trim();
            final pBlock = (props['county'] as String? ?? props['subdistrict'] as String? ?? '').trim();
            final pDistrict = (props['district'] as String? ?? props['state_district'] as String? ?? '').trim();
            final pState = (props['state'] as String? ?? '').trim();
            final pPostcode = (props['postcode'] as String? ?? '').trim();

            if (kDebugMode) {
              debugPrint('🌐 [$corrId] Photon HTTP 200 | Raw: name="$pName", street="$pStreet", v="$pVillage", hamlet="$pHamlet", town="$pTown", block="$pBlock", dist="$pDistrict", pin="$pPostcode"');
            }

            if (poi.isEmpty &&
                pName.isNotEmpty &&
                pName.toLowerCase() != subdistrict.toLowerCase() &&
                pName.toLowerCase() != district.toLowerCase()) {
              poi = pName;
            }
            if (road.isEmpty && pStreet.isNotEmpty) road = pStreet;
            if (suburb.isEmpty && pSuburb.isNotEmpty) suburb = pSuburb;
            if (village.isEmpty && pVillage.isNotEmpty) village = pVillage;
            if (hamlet.isEmpty && pHamlet.isNotEmpty) hamlet = pHamlet;
            if (subdistrict.isEmpty && pBlock.isNotEmpty) subdistrict = pBlock;
            if (town.isEmpty && pTown.isNotEmpty && pTown.toLowerCase() != district.toLowerCase()) {
              town = pTown;
            }
            if (district.isEmpty && pDistrict.isNotEmpty) district = pDistrict;
            if (state.isEmpty && pState.isNotEmpty) state = pState;
            if (pincode.isEmpty && pPostcode.isNotEmpty) pincode = pPostcode;
          }
        } else {
          if (kDebugMode) {
            debugPrint('⚠️ [$corrId] Photon HTTP ${photonRes.statusCode}');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ [$corrId] Photon reverse error: $e');
        }
      }
    }

    // ── STEP 3: BigDataCloud — last-resort for administrative fields if still completely empty
    if (village.isEmpty && town.isEmpty && district.isEmpty) {
      try {
        final bdcUrl = 'https://api-bdc.io/data/reverse-geocode-client?latitude=$latitude&longitude=$longitude&localityLanguage=en';
        final bdcRes = await _client.get(
          Uri.parse(bdcUrl),
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 6));

        if (bdcRes.statusCode == 200) {
          final bdcData = jsonDecode(bdcRes.body) as Map<String, dynamic>;
          final countryCode = (bdcData['countryCode'] as String? ?? '').toLowerCase().trim();
          if (countryCode == 'in' || countryCode.isEmpty) {
            final bdcLocality = (bdcData['locality'] as String? ?? '').trim();
            final bdcCity = (bdcData['city'] as String? ?? '').trim();
            final bdcPrincipal = (bdcData['principalSubdivision'] as String? ?? '').trim();
            final bdcPostcode = (bdcData['postcode'] as String? ?? '').trim();

            if (kDebugMode) {
              debugPrint('🌐 [$corrId] BigDataCloud HTTP 200 | Raw: loc="$bdcLocality", city="$bdcCity", state="$bdcPrincipal", pin="$bdcPostcode"');
            }

            if (subdistrict.isEmpty && bdcLocality.isNotEmpty) subdistrict = bdcLocality;
            if (town.isEmpty && bdcCity.isNotEmpty) town = bdcCity;
            if (state.isEmpty && bdcPrincipal.isNotEmpty) state = bdcPrincipal;
            if (pincode.isEmpty && bdcPostcode.isNotEmpty) pincode = bdcPostcode;
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ [$corrId] BigDataCloud reverse error: $e');
        }
      }
    }

    // ── STALE RESPONSE GUARD: discard this result if a newer geocode started
    if (mySeq != _geocodeSeq) {
      if (kDebugMode) debugPrint('🗑️ [$corrId] Discarding stale geocode result (seq $mySeq, current $_geocodeSeq)');
      return CustomerLocationEntity(
        latitude: latitude,
        longitude: longitude,
        placeName: '',
        formattedAddress: '',
        city: '',
        district: '',
        state: '',
        pincode: '',
        timestamp: DateTime.now(),
      );
    }

    // ── STEP 4: Distance Sanity Check & Khaira Boundary Sanitization
    // Khaira block center is ~ (24.8490, 86.2130).
    // If geocoder returns Khaira/811317 due to loose rural bounding boxes, verify distance!
    final distToKhairaMeters = Geolocator.distanceBetween(latitude, longitude, 24.8490, 86.2130);
    if (distToKhairaMeters > 3500.0) {
      if (village.toLowerCase().contains('khaira') || village.contains('खैरा')) village = '';
      if (hamlet.toLowerCase().contains('khaira') || hamlet.contains('खैरा')) hamlet = '';
      if (suburb.toLowerCase().contains('khaira') || suburb.contains('खैरा')) suburb = '';
      if (neighbourhood.toLowerCase().contains('khaira') || neighbourhood.contains('खैरा')) neighbourhood = '';
      if (poi.toLowerCase().contains('khaira') || poi.contains('खैरा')) poi = '';
      if (road.toLowerCase().contains('khaira') || road.contains('खैरा')) road = '';
      if (town.toLowerCase().contains('khaira') || town.contains('खैरा')) town = '';
      if (subdistrict.toLowerCase().contains('khaira') || subdistrict.contains('खैरा')) subdistrict = '';
      if (pincode == '811317') pincode = '';
    }

    if (district.toLowerCase().contains('hanoi') || district.toLowerCase().contains('vietnam')) {
      district = '';
    }
    if (state.toLowerCase().contains('hanoi') || state.toLowerCase().contains('vietnam')) {
      state = '';
    }

    // Determine the most accurate place title prioritizing:
    // 1. POI / Specific Landmark
    // 2. Neighbourhood / Mohalla
    // 3. Hamlet / Tola
    // 4. Street / Road
    // 5. Village
    // 6. Town / City
    // 7. Subdistrict / Block
    // 8. If none available, do NOT guess Khaira -> return 'Location detected'
    if (poi.isNotEmpty) {
      placeName = poi;
    } else if (neighbourhood.isNotEmpty) {
      placeName = neighbourhood;
    } else if (hamlet.isNotEmpty) {
      placeName = hamlet;
    } else if (road.isNotEmpty) {
      placeName = road;
    } else if (village.isNotEmpty) {
      placeName = village;
    } else if (town.isNotEmpty) {
      placeName = town;
    } else if (subdistrict.isNotEmpty) {
      placeName = subdistrict;
    } else {
      placeName = 'Location detected';
    }

    // ── STEP 5: Build clean formatted address
    final seen = <String>{};
    final addressParts = <String>[];

    void addPart(String v) {
      final trimmed = v.trim();
      final key = trimmed.toLowerCase();
      if (trimmed.isNotEmpty &&
          !seen.contains(key) &&
          !key.startsWith('unnamed') &&
          key != 'location detected' &&
          key != 'स्थानीय पता उपलब्ध नहीं') {
        seen.add(key);
        addressParts.add(trimmed);
      }
    }

    if (placeName != 'Location detected' &&
        placeName != 'Current Location' &&
        placeName != 'Selected Location' &&
        placeName != 'स्थानीय पता उपलब्ध नहीं' &&
        placeName != 'वर्तमान स्थान' &&
        placeName != 'चयनित स्थान') {
      addPart(placeName);
    }
    if (poi.isNotEmpty) addPart(poi);
    if (neighbourhood.isNotEmpty) addPart(neighbourhood);
    if (suburb.isNotEmpty) addPart(suburb);
    if (hamlet.isNotEmpty) addPart(hamlet);
    if (road.isNotEmpty) addPart(road);
    if (village.isNotEmpty) addPart(village);
    if (town.isNotEmpty) addPart(town);
    if (subdistrict.isNotEmpty) addPart(subdistrict);
    if (district.isNotEmpty) addPart(district);
    if (state.isNotEmpty) addPart(state);
    if (pincode.isNotEmpty) addPart(pincode);

    formattedAddress = addressParts.isNotEmpty
        ? addressParts.join(', ')
        : 'GPS: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';

    final String providerUsed = (poi.isNotEmpty || village.isNotEmpty || road.isNotEmpty)
        ? (nominatimSucceeded ? 'Nominatim/OSM' : (photonSucceeded ? 'Photon' : 'DirectGPS'))
        : (town.isNotEmpty ? 'Nominatim/OSM' : (district.isNotEmpty ? 'BigDataCloud' : 'DirectGPS'));

    if (kDebugMode) {
      debugPrint('📍 [$corrId] RESOLVED: Provider=$providerUsed | Place="$placeName" | Addr="$formattedAddress" | Village="$village" | Block="$subdistrict" | Lat=${latitude.toStringAsFixed(5)}, Lng=${longitude.toStringAsFixed(5)} | DistToKhaira=${(distToKhairaMeters / 1000).toStringAsFixed(2)}km');
    }

    final resolvedEntity = CustomerLocationEntity(
      latitude: latitude,
      longitude: longitude,
      placeName: placeName,
      formattedAddress: formattedAddress,
      village: village.isNotEmpty ? village : hamlet,
      locality: poi.isNotEmpty ? poi : (neighbourhood.isNotEmpty ? neighbourhood : road),
      suburb: suburb.isNotEmpty ? suburb : neighbourhood,
      block: subdistrict,
      city: town.isNotEmpty ? town : subdistrict,
      district: district,
      state: state,
      pincode: pincode,
      accuracy: accuracy,
      timestamp: DateTime.now(),
    );

    if (placeName != 'Detecting location...' && placeName != 'स्थान खोजा जा रहा है...') {
      _addToCache(cacheKey, resolvedEntity);
    }
    return resolvedEntity;
  }

  @override
  Future<List<CustomerLocationEntity>> searchPlaces(
    String query, {
    double? customerLat,
    double? customerLng,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.length < 2) return [];

    final cacheQueryKey = cleanQuery.toLowerCase();
    if (_searchQueryCache.containsKey(cacheQueryKey)) {
      if (kDebugMode) {
        debugPrint('⚡ [CUSTOMER LOCATION] Search cache hit for query: $cleanQuery');
      }
      return _searchQueryCache[cacheQueryKey]!;
    }

    final List<CustomerLocationEntity> results = [];
    final Set<String> seenKeys = {};

    final latLngRegExp = RegExp(r'^([-+]?\d{1,2}(?:\.\d+)?)[,\s]+([-+]?\d{1,3}(?:\.\d+)?)$');
    final coordMatch = latLngRegExp.firstMatch(cleanQuery);
    if (coordMatch != null) {
      final parsedLat = double.tryParse(coordMatch.group(1) ?? '');
      final parsedLng = double.tryParse(coordMatch.group(2) ?? '');
      if (parsedLat != null && parsedLng != null && parsedLat >= -90 && parsedLat <= 90 && parsedLng >= -180 && parsedLng <= 180) {
        try {
          final geocoded = await reverseGeocode(parsedLat, parsedLng);
          return [geocoded];
        } catch (_) {
          return [
            CustomerLocationEntity(
              latitude: parsedLat,
              longitude: parsedLng,
              placeName: 'GPS (${parsedLat.toStringAsFixed(6)}, ${parsedLng.toStringAsFixed(6)})',
              formattedAddress: 'Latitude: ${parsedLat.toStringAsFixed(6)}, Longitude: ${parsedLng.toStringAsFixed(6)}',
              city: '',
              district: '',
              state: '',
              pincode: '',
              timestamp: DateTime.now(),
            ),
          ];
        }
      }
    }

    // Use customer coordinates if valid and non-zero; otherwise bias toward Jamui, Bihar (24.9213, 86.2238)
    // Never pass (0.0, 0.0) to Photon as that biases search results to the Atlantic Ocean.
    final bool hasValidCustomerBias = customerLat != null &&
        customerLng != null &&
        (customerLat != 0.0 || customerLng != 0.0) &&
        customerLat >= -90.0 &&
        customerLat <= 90.0 &&
        customerLng >= -180.0 &&
        customerLng <= 180.0;
    final double biasLat = hasValidCustomerBias ? customerLat : 24.9213;
    final double biasLng = hasValidCustomerBias ? customerLng : 86.2238;

    void parsePhotonFeatures(List<dynamic> features) {
      for (final item in features) {
        final props = (item['properties'] as Map<String, dynamic>?) ?? {};
        final country = (props['country'] as String? ?? '').trim();
        final countryLower = country.toLowerCase();
        final countryCode = (props['countrycode'] as String? ?? '').toLowerCase().trim();

        // Strictly skip all foreign results
        if (countryLower.isNotEmpty && countryLower != 'india' && countryLower != 'भारत' && countryCode != 'in') {
          continue;
        }

        final geometry = (item['geometry'] as Map<String, dynamic>?) ?? {};
        final coords = (geometry['coordinates'] as List<dynamic>?) ?? [];

        if (coords.length >= 2) {
          // GeoJSON order: [longitude, latitude]
          final lon = (coords[0] as num).toDouble();
          final lat = (coords[1] as num).toDouble();

          final name = (props['name'] as String? ?? '').trim();
          final osmValue = (props['osm_value'] as String? ?? props['type'] as String? ?? '').toLowerCase().trim();
          final street = (props['street'] as String? ?? '').trim();
          final localityProp = (props['locality'] as String? ?? '').trim();
          final suburbProp = (props['suburb'] as String? ?? '').trim();
          final villageProp = (props['village'] as String? ?? props['hamlet'] as String? ?? '').trim();
          final blockProp = (props['county'] as String? ?? props['subdistrict'] as String? ?? '').trim();
          final districtProp = (props['district'] as String? ?? props['state_district'] as String? ?? '').trim();
          final cityProp = (props['city'] as String? ?? props['town'] as String? ?? '').trim();
          final state = (props['state'] as String? ?? '').trim();
          final postcode = (props['postcode'] as String? ?? '').trim();

          final resolvedVillage = villageProp.isNotEmpty
              ? villageProp
              : ((osmValue == 'village' || osmValue == 'hamlet') ? name : '');
          final resolvedSuburb = suburbProp.isNotEmpty
              ? suburbProp
              : (localityProp.isNotEmpty
                  ? localityProp
                  : ((osmValue == 'suburb' || osmValue == 'neighbourhood' || osmValue == 'locality') ? name : ''));
          final resolvedBlock = blockProp;
          final resolvedCity = cityProp.isNotEmpty
              ? cityProp
              : ((osmValue == 'city' || osmValue == 'town') ? name : '');
          final resolvedDistrict = districtProp;

          final placeName = name.isNotEmpty
              ? name
              : street.isNotEmpty
                  ? street
                  : resolvedVillage.isNotEmpty
                      ? resolvedVillage
                      : resolvedCity.isNotEmpty
                          ? resolvedCity
                          : resolvedBlock.isNotEmpty
                              ? resolvedBlock
                              : resolvedDistrict.isNotEmpty
                                  ? resolvedDistrict
                                  : (postcode.isNotEmpty ? postcode : state);

          if (placeName.contains('Phúc') || placeName.contains('Hà Nội')) {
            continue;
          }

          final seenAddr = <String>{};
          final addressParts = <String>[];
          void addPart(String v) {
            final t = v.trim();
            if (t.isNotEmpty && !seenAddr.contains(t.toLowerCase())) {
              seenAddr.add(t.toLowerCase());
              addressParts.add(t);
            }
          }

          addPart(placeName);
          if (street.isNotEmpty) addPart(street);
          if (resolvedSuburb.isNotEmpty) addPart(resolvedSuburb);
          if (resolvedVillage.isNotEmpty) addPart(resolvedVillage);
          if (resolvedCity.isNotEmpty) addPart(resolvedCity);
          if (resolvedBlock.isNotEmpty) addPart(resolvedBlock);
          if (resolvedDistrict.isNotEmpty) addPart(resolvedDistrict);
          if (state.isNotEmpty) addPart(state);
          if (postcode.isNotEmpty) addPart(postcode);

          final formattedAddress = addressParts.isNotEmpty
              ? addressParts.join(', ')
              : (state.isNotEmpty ? '$state, India' : (placeName.isNotEmpty ? '$placeName, India' : 'India'));

          final key = '${lat.toStringAsFixed(5)}_${lon.toStringAsFixed(5)}';
          if (placeName.isNotEmpty && !seenKeys.contains(key)) {
            seenKeys.add(key);
            results.add(CustomerLocationEntity(
              latitude: lat,
              longitude: lon,
              placeName: placeName,
              formattedAddress: formattedAddress,
              village: resolvedVillage,
              locality: localityProp.isNotEmpty ? localityProp : street,
              suburb: resolvedSuburb,
              block: resolvedBlock,
              city: resolvedCity,
              district: resolvedDistrict,
              state: state,
              pincode: postcode,
              timestamp: DateTime.now(),
            ));
          }
        }
      }
    }

    // 1. High-speed Fuzzy Search via Photon API ONLY (Open-Source OSM Indian POIs, Villages, Towns & PIN codes)
    // NOTE: Public Nominatim is strictly NEVER used for keystroke-by-keystroke search/autocomplete.
    bool photonSucceeded = false;
    Object? lastPhotonError;

    try {
      final String photonUrl =
          'https://photon.komoot.io/api/?q=${Uri.encodeComponent(cleanQuery)}&limit=15&lang=en&lat=$biasLat&lon=$biasLng';

      final photonRes = await _client.get(
        Uri.parse(photonUrl),
        headers: {
          'User-Agent': 'ApnaJamuiCustomerApp/1.0 (contact: support@apnajamui.in)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));

      if (photonRes.statusCode == 200) {
        photonSucceeded = true;
        final data = jsonDecode(photonRes.body) as Map<String, dynamic>;
        final features = data['features'] as List<dynamic>? ?? [];
        parsePhotonFeatures(features);

        // If a local village or 6-digit PIN code returned only global foreign matches on the first pass,
        // query Photon scoped to India so Indian villages and PIN codes are not crowded out by global results.
        if (results.isEmpty && !cleanQuery.toLowerCase().contains('india')) {
          final String indiaScopedUrl =
              'https://photon.komoot.io/api/?q=${Uri.encodeComponent('$cleanQuery India')}&limit=15&lang=en&lat=$biasLat&lon=$biasLng';
          final scopedRes = await _client.get(
            Uri.parse(indiaScopedUrl),
            headers: {
              'User-Agent': 'ApnaJamuiCustomerApp/1.0 (contact: support@apnajamui.in)',
              'Accept': 'application/json',
            },
          ).timeout(const Duration(seconds: 8));

          if (scopedRes.statusCode == 200) {
            final scopedData = jsonDecode(scopedRes.body) as Map<String, dynamic>;
            final scopedFeatures = scopedData['features'] as List<dynamic>? ?? [];
            parsePhotonFeatures(scopedFeatures);
          }
        }
      } else {
        lastPhotonError = Exception('Photon HTTP ${photonRes.statusCode}');
      }
    } catch (e) {
      lastPhotonError = e;
      debugPrint('⚠️ [LocationRemoteDataSource] Photon search error: $e');
    }

    // 2. Optional Paid Google Geocoding Search (ONLY if explicitly enabled via feature flag)
    if (results.isEmpty && MapsConfig.hasGoogleKey) {
      try {
        final googleUrl = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(cleanQuery)}&key=${MapsConfig.googleMapsApiKey}&language=en&region=IN&components=country:IN',
        );
        final res = await _client.get(
          googleUrl,
          headers: {
            'X-Android-Package': 'com.jamuiservice.customer',
            'X-Android-Cert': '5CB44C62DB96B43508899DC295437DE2A16741F0',
          },
        ).timeout(const Duration(seconds: 6));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          if (data['status'] == 'OK') {
            final resultsList = data['results'] as List<dynamic>? ?? [];
            for (final item in resultsList) {
              final geom = item['geometry'] as Map<String, dynamic>? ?? {};
              final loc = geom['location'] as Map<String, dynamic>? ?? {};
              final lat = (loc['lat'] as num?)?.toDouble() ?? 0.0;
              final lng = (loc['lng'] as num?)?.toDouble() ?? 0.0;
              final formatted = item['formatted_address'] as String? ?? '';
              final comps = item['address_components'] as List<dynamic>? ?? [];

              String gCity = '';
              String gDist = '';
              String gBlock = '';
              String gState = '';
              String gPin = '';
              String gVillage = '';

              for (final comp in comps) {
                final types = (comp['types'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
                final name = (comp['long_name'] as String? ?? '').trim();
                if (types.contains('sublocality') ||
                    types.contains('sublocality_level_1') ||
                    types.contains('sublocality_level_2') ||
                    types.contains('neighborhood')) {
                  gVillage = name;
                } else if (types.contains('locality')) {
                  gCity = name;
                } else if (types.contains('administrative_area_level_3')) {
                  gBlock = name;
                } else if (types.contains('administrative_area_level_2')) {
                  gDist = name;
                } else if (types.contains('administrative_area_level_1')) {
                  gState = name;
                } else if (types.contains('postal_code')) {
                  gPin = name;
                }
              }

              final placeName = gVillage.isNotEmpty
                  ? gVillage
                  : (gCity.isNotEmpty ? gCity : (formatted.isNotEmpty ? formatted.split(',').first : cleanQuery));
              final key = '${lat.toStringAsFixed(5)}_${lng.toStringAsFixed(5)}';

              if (lat != 0.0 && lng != 0.0 && !seenKeys.contains(key)) {
                seenKeys.add(key);
                results.add(CustomerLocationEntity(
                  latitude: lat,
                  longitude: lng,
                  placeName: placeName,
                  formattedAddress: formatted,
                  village: gVillage,
                  block: gBlock,
                  city: gCity,
                  district: gDist,
                  state: gState,
                  pincode: gPin,
                  timestamp: DateTime.now(),
                ));
              }
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ [LocationRemoteDataSource] Google search error: $e');
      }
    }

    if (!photonSucceeded && results.isEmpty && lastPhotonError != null) {
      throw Exception('Unable to search locations: $lastPhotonError');
    }

    if (results.isNotEmpty) {
      if (_searchQueryCache.length >= 100) {
        _searchQueryCache.remove(_searchQueryCache.keys.first);
      }
      _searchQueryCache[cacheQueryKey] = results;
    }

    return results;
  }
}
