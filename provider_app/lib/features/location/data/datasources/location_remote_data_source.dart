import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/config/maps_config.dart';
import '../../../../core/services/web_host_bridge.dart';
import '../../domain/entities/provider_location_entity.dart';

class InaccurateLocationException implements Exception {
  final double accuracy;
  final String message;

  const InaccurateLocationException({
    required this.accuracy,
    this.message = 'आपकी GPS Location अभी सटीक नहीं मिल रही है। कृपया खुले स्थान पर जाएँ और दोबारा Location Fetch करें। आप Map पर Pin Adjust भी कर सकते हैं।',
  });

  @override
  String toString() => message;
}

abstract class LocationRemoteDataSource {
  Future<bool> isLocationServiceEnabled();
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Future<bool> openAppSettings();
  Future<bool> openLocationSettings();
  Future<Position> getCurrentPosition();
  Future<ProviderLocationEntity> reverseGeocode(double latitude, double longitude, {double? accuracy, double serviceRadiusKm = 10.0});
  Future<List<ProviderLocationEntity>> searchPlaces(
    String query, {
    double? providerLat,
    double? providerLng,
  });
}

class LocationRemoteDataSourceImpl implements LocationRemoteDataSource {
  final http.Client _client;

  // In-memory Coordinate Cache: Prevents duplicate geocoding API calls for nearby coordinates (~11m grid)
  static final Map<String, ProviderLocationEntity> _inMemoryReverseGeocodeCache = {};
  static const int _maxCacheEntries = 200;

  // In-memory search query cache to prevent repeat network calls
  static final Map<String, List<ProviderLocationEntity>> _searchQueryCache = {};

  static String _coordCacheKey(double lat, double lng) {
    return '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';
  }

  static void _addToCache(String key, ProviderLocationEntity entity) {
    if (_inMemoryReverseGeocodeCache.length >= _maxCacheEntries) {
      _inMemoryReverseGeocodeCache.remove(_inMemoryReverseGeocodeCache.keys.first);
    }
    _inMemoryReverseGeocodeCache[key] = entity;
    _saveToDiskCache(key, entity);
  }

  static Future<void> _saveToDiskCache(String key, ProviderLocationEntity entity) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('geo_cache_$key', jsonEncode(entity.toMap()));
    } catch (_) {}
  }

  static Future<ProviderLocationEntity?> _getFromDiskCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('geo_cache_$key');
      if (str != null && str.isNotEmpty) {
        final map = jsonDecode(str) as Map<String, dynamic>;
        return ProviderLocationEntity.fromMap(map);
      }
    } catch (_) {}
    return null;
  }

  LocationRemoteDataSourceImpl({http.Client? client}) : _client = client ?? http.Client();

  @override
  Future<bool> isLocationServiceEnabled() async {
    if (kIsWeb && WebHostBridge.isHostAvailable) {
      return true; // Host Customer App validates device GPS on native side
    }
    return await Geolocator.isLocationServiceEnabled();
  }

  @override
  Future<LocationPermission> checkPermission() async {
    if (kIsWeb && WebHostBridge.isHostAvailable) {
      return LocationPermission.whileInUse; // Host bridge manages Android runtime permission
    }
    return await Geolocator.checkPermission();
  }

  @override
  Future<LocationPermission> requestPermission() async {
    if (kIsWeb && WebHostBridge.isHostAvailable) {
      return LocationPermission.whileInUse;
    }
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
    // 1. If running on Web inside Host WebView, prioritize Native Location Bridge with 28s timeout
    if (kIsWeb && WebHostBridge.isHostAvailable) {
      try {
        final hostLocation = await WebHostBridge.requestNativeLocation(
          timeout: const Duration(seconds: 28),
        );
        if (hostLocation != null) {
          final success = hostLocation['success'] as bool? ?? false;
          if (success) {
            final lat = (hostLocation['latitude'] as num?)?.toDouble();
            final lng = (hostLocation['longitude'] as num?)?.toDouble();
            final acc = (hostLocation['accuracy'] as num?)?.toDouble() ?? 5.0;
            if (lat != null &&
                lng != null &&
                lat >= -90.0 &&
                lat <= 90.0 &&
                lng >= -180.0 &&
                lng <= 180.0 &&
                (lat != 0.0 || lng != 0.0)) {
              if (acc > 150.0) {
                throw InaccurateLocationException(accuracy: acc);
              }
              if (kDebugMode) {
                debugPrint('📍 [PROVIDER LOCATION] Native Host GPS Position Fetched: Lat=$lat, Lng=$lng, Acc=±$acc m');
              }
              return Position(
                latitude: lat,
                longitude: lng,
                timestamp: DateTime.now(),
                accuracy: acc,
                altitude: 0.0,
                altitudeAccuracy: 0.0,
                heading: 0.0,
                headingAccuracy: 0.0,
                speed: 0.0,
                speedAccuracy: 0.0,
              );
            }
          } else {
            final errCode = hostLocation['error'] as String? ?? '';
            final errMsg = hostLocation['message'] as String? ?? '';
            if (errCode == 'PERMISSION_DENIED') {
              throw PermissionDeniedException(
                errMsg.isNotEmpty ? errMsg : 'लोकेशन अनुमति (Location Permission) अस्वीकृत की गई।',
              );
            } else if (errCode == 'LOCATION_DISABLED') {
              throw const LocationServiceDisabledException();
            } else if (errCode == 'LOCATION_TIMEOUT') {
              throw TimeoutException(errMsg.isNotEmpty ? errMsg : 'GPS लोकेशन प्राप्त करने में समय सीमा समाप्त हो गई।');
            }
          }
        }
      } catch (e) {
        if (e is PermissionDeniedException ||
            e is LocationServiceDisabledException ||
            e is InaccurateLocationException ||
            e is TimeoutException) {
          rethrow;
        }
        debugPrint('⚠️ [PROVIDER LOCATION] Native host location failed ($e). Falling back to browser geolocation with strict validation.');
      }
    }

    // 2. Direct Browser HTML5 / Device Geolocation Fallback
    final serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceDisabledException();
    }

    LocationPermission permission = await checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await requestPermission();
      if (permission == LocationPermission.denied) {
        throw const PermissionDeniedException('लोकेशन अनुमति (Location Permission) अस्वीकृत की गई।');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw const PermissionDeniedException('लोकेशन अनुमति हमेशा के लिए ब्लॉक है। कृपया सेटिंग्स से अनुमति दें।');
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1,
        timeLimit: Duration(seconds: 25),
      ),
    );

    // Strict accuracy check for browser fallback (no cell tower/IP >150m accepted)
    if (pos.accuracy > 150.0) {
      throw InaccurateLocationException(accuracy: pos.accuracy);
    }
    if (pos.latitude == 0.0 && pos.longitude == 0.0) {
      throw Exception('अमान्य लोकेशन कोर्डिनेट्स प्राप्त हुए।');
    }

    if (kDebugMode) {
      debugPrint('📍 [PROVIDER LOCATION] Real GPS Position Fetched:');
      debugPrint('   Lat: ${pos.latitude}, Lng: ${pos.longitude}');
      debugPrint('   Accuracy: ±${pos.accuracy.toStringAsFixed(1)} meters');
    }

    return pos;
  }

  int _geocodeSeq = 0;

  @override
  Future<ProviderLocationEntity> reverseGeocode(
    double latitude,
    double longitude, {
    double? accuracy,
    double serviceRadiusKm = 10.0,
  }) async {
    // 1. In-Memory Coordinate Cache Check (Avoid redundant geocoding API calls)
    final cacheKey = _coordCacheKey(latitude, longitude);
    if (_inMemoryReverseGeocodeCache.containsKey(cacheKey)) {
      final cached = _inMemoryReverseGeocodeCache[cacheKey]!;
      if (kDebugMode) {
        debugPrint('⚡ [PROVIDER LOCATION] In-memory cache hit for ($cacheKey): ${cached.placeName}');
      }
      return cached.copyWith(
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy ?? cached.accuracy,
        serviceRadiusKm: serviceRadiusKm,
        timestamp: DateTime.now(),
      );
    }

    // 2. Persistent Disk Cache Check (SharedPreferences)
    final diskCached = await _getFromDiskCache(cacheKey);
    if (diskCached != null) {
      _inMemoryReverseGeocodeCache[cacheKey] = diskCached;
      if (kDebugMode) {
        debugPrint('⚡ [PROVIDER LOCATION] Disk cache hit for ($cacheKey): ${diskCached.placeName}');
      }
      return diskCached.copyWith(
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy ?? diskCached.accuracy,
        serviceRadiusKm: serviceRadiusKm,
        timestamp: DateTime.now(),
      );
    }

    final mySeq = ++_geocodeSeq;

    String placeName = '';
    String village = '';
    String locality = '';
    String city = '';
    String subdistrict = '';
    String district = '';
    String state = '';
    String pincode = '';
    String formattedAddress = '';

    if (kDebugMode) {
      debugPrint('📍 [PROVIDER LOCATION] REVERSE GEOCODING INPUT: Lat=$latitude, Lng=$longitude');
    }

    // Lazy Cloud Sync: only fetch if paid Google Geocoding is enabled
    if (MapsConfig.enablePaidGoogleGeocoding && !MapsConfig.hasGoogleKey) {
      await MapsConfig.fetchFromCloud();
    }

    // ── STEP 0: Google Geocoding API (Ultra Accurate POI / Village / Tola level)
    if (MapsConfig.hasGoogleKey) {
      try {
        final googleUrl = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=$latitude,$longitude&key=${MapsConfig.googleMapsApiKey}&language=hi&region=IN',
        );
        final Map<String, String> headers = {};
        if (!kIsWeb) {
          headers['X-Android-Package'] = 'com.jamuiservice.provider';
          headers['X-Android-Cert'] = '5CB44C62DB96B43508899DC295437DE2A16741F0';
        }
        final response = await _client.get(
          googleUrl,
          headers: headers,
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
                return ProviderLocationEntity(
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
                debugPrint('📍 [PROVIDER LOCATION] Google Geocoding Success: placeTitle=$placeTitle, address=$cleanFormatted');
              }

              final googleEntity = ProviderLocationEntity(
                latitude: latitude,
                longitude: longitude,
                placeName: placeTitle,
                formattedAddress: cleanFormatted,
                village: specificVillage.isNotEmpty ? specificVillage : placeTitle,
                locality: gPoi.isNotEmpty ? gPoi : (specificVillage.isNotEmpty ? specificVillage : placeTitle),
                city: resolvedCity,
                district: resolvedDistrict,
                state: resolvedState,
                pincode: gPincode,
                accuracy: accuracy,
                serviceRadiusKm: serviceRadiusKm,
                timestamp: DateTime.now(),
              );
              _addToCache(cacheKey, googleEntity);
              return googleEntity;
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ [PROVIDER LOCATION] Google Geocoding error: $e');
      }
    }

    // ── STEP 1: Nominatim (OSM) — Fallback / Enrichment
    if (village.isEmpty || district.isEmpty) {
      try {
        final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=$latitude&lon=$longitude&zoom=18&addressdetails=1',
        );
        final response = await _client.get(
          uri,
          headers: {
            'User-Agent': 'ApnaJamuiProviderApp/1.0 (contact: support@apnajamui.in)',
            'Accept': 'application/json',
            'Accept-Language': 'hi,en',
          },
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final address = data['address'] as Map<String, dynamic>?;
          final osmName = (data['name'] as String? ?? '').trim();

          if (address != null) {
            final vRaw = (address['village'] as String? ??
                    address['hamlet'] as String? ??
                    address['isolated_dwelling'] as String? ??
                    address['allotments'] as String? ??
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

            village = vRaw;

            if (osmName.isNotEmpty &&
                osmName.toLowerCase() != subdistrictRaw.toLowerCase() &&
                osmName.toLowerCase() != districtRaw.toLowerCase()) {
              locality = osmName;
            } else if (nRaw.isNotEmpty) {
              locality = nRaw;
            } else if (roadRaw.isNotEmpty) {
              locality = roadRaw;
            }

            city = townRaw.isNotEmpty ? townRaw : subdistrictRaw;
            subdistrict = subdistrictRaw;
            district = districtRaw;
            state = stateRaw;
            pincode = postcodeRaw;
          }
        }
      } catch (e) {
        debugPrint('⚠️ [PROVIDER LOCATION] Nominatim reverse error: $e');
      }
    }

    // ── STEP 2: Photon (Komoot) — only if village and locality are still empty
    if (village.isEmpty && locality.isEmpty) {
      try {
        final photonUrl = 'https://photon.komoot.io/reverse?lat=$latitude&lon=$longitude';
        final photonRes = await _client.get(
          Uri.parse(photonUrl),
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 5));

        if (photonRes.statusCode == 200) {
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
            final pVillage = (props['village'] as String? ??
                    props['hamlet'] as String? ??
                    props['locality'] as String? ??
                    '')
                .trim();
            final pCity = (props['city'] as String? ?? props['town'] as String? ?? '').trim();
            final pDistrict = (props['district'] as String? ?? props['county'] as String? ?? '').trim();
            final pPostcode = (props['postcode'] as String? ?? '').trim();

            if (village.isEmpty && pVillage.isNotEmpty) village = pVillage;

            if (locality.isEmpty &&
                pName.isNotEmpty &&
                pName.toLowerCase() != subdistrict.toLowerCase() &&
                pName.toLowerCase() != district.toLowerCase()) {
              locality = pName;
            }
            if (city.isEmpty && pCity.isNotEmpty && pCity.toLowerCase() != district.toLowerCase()) {
              city = pCity;
            }
            if (district.isEmpty && pDistrict.isNotEmpty) district = pDistrict;
            if (pincode.isEmpty && pPostcode.isNotEmpty) pincode = pPostcode;
          }
        }
      } catch (e) {
        debugPrint('⚠️ [PROVIDER LOCATION] Photon reverse error: $e');
      }
    }

    // ── STEP 3: BigDataCloud — last-resort fallback
    if (village.isEmpty || district.isEmpty || state.isEmpty) {
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

            if (subdistrict.isEmpty && bdcLocality.isNotEmpty) subdistrict = bdcLocality;
            if (city.isEmpty && bdcCity.isNotEmpty) city = bdcCity;
            if (state.isEmpty && bdcPrincipal.isNotEmpty) state = bdcPrincipal;
            if (pincode.isEmpty && bdcPostcode.isNotEmpty) pincode = bdcPostcode;
          }
        }
      } catch (e) {
        debugPrint('⚠️ [PROVIDER LOCATION] BigDataCloud reverse error: $e');
      }
    }

    // Guard against stale response
    if (mySeq != _geocodeSeq) {
      return ProviderLocationEntity(
        latitude: latitude,
        longitude: longitude,
        placeName: '',
        formattedAddress: '',
        city: '',
        district: '',
        state: '',
        pincode: '',
        serviceRadiusKm: serviceRadiusKm,
        timestamp: DateTime.now(),
      );
    }

    // ── STEP 4: Resolve placeName & sanitize
    if (district.toLowerCase().contains('hanoi') || district.toLowerCase().contains('vietnam')) {
      district = '';
    }
    if (state.toLowerCase().contains('hanoi') || state.toLowerCase().contains('vietnam')) {
      state = '';
    }

    if (locality.isNotEmpty &&
        village.isNotEmpty &&
        locality.toLowerCase() != village.toLowerCase() &&
        locality.toLowerCase() != subdistrict.toLowerCase() &&
        !locality.contains('Phúc') &&
        !locality.contains('Hà Nội')) {
      placeName = locality;
    } else if (village.isNotEmpty && !village.contains('Phúc') && !village.contains('Hà Nội')) {
      placeName = village;
    } else if (locality.isNotEmpty && !locality.contains('Phúc') && !locality.contains('Hà Nội')) {
      placeName = locality;
    } else if (subdistrict.isNotEmpty &&
        subdistrict.toLowerCase() != district.toLowerCase()) {
      placeName = subdistrict;
    } else if (city.isNotEmpty && !city.contains('Phúc') && !city.contains('Hà Nội')) {
      placeName = city;
    } else if (district.isNotEmpty) {
      placeName = district;
    } else {
      placeName = 'वर्तमान स्थान';
    }

    // ── STEP 5: Build clean formatted address
    final seen = <String>{};
    final addressParts = <String>[];

    void addPart(String v) {
      final key = v.toLowerCase().trim();
      if (v.trim().isNotEmpty && !seen.contains(key) && !v.toLowerCase().startsWith('unnamed')) {
        seen.add(key);
        addressParts.add(v.trim());
      }
    }

    addPart(placeName != 'वर्तमान स्थान' ? placeName : '');
    if (village.isNotEmpty && village.toLowerCase() != placeName.toLowerCase()) { addPart(village); }
    if (locality.isNotEmpty &&
        locality.toLowerCase() != placeName.toLowerCase() &&
        locality.toLowerCase() != village.toLowerCase()) {
      addPart(locality);
    }
    addPart(subdistrict);
    if (city.isNotEmpty && city.toLowerCase() != subdistrict.toLowerCase()) {
      addPart(city);
    }
    addPart(district);
    addPart(state);
    addPart(pincode);

    formattedAddress = addressParts.isNotEmpty
        ? addressParts.join(', ')
        : 'GPS: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';

    final resolvedEntity = ProviderLocationEntity(
      latitude: latitude,
      longitude: longitude,
      placeName: placeName,
      formattedAddress: formattedAddress,
      village: village,
      locality: locality,
      city: city,
      district: district,
      state: state,
      pincode: pincode,
      accuracy: accuracy,
      serviceRadiusKm: serviceRadiusKm,
      timestamp: DateTime.now(),
    );
    _addToCache(cacheKey, resolvedEntity);
    return resolvedEntity;
  }

  @override
  Future<List<ProviderLocationEntity>> searchPlaces(
    String query, {
    double? providerLat,
    double? providerLng,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.length < 3) return [];

    final cacheQueryKey = cleanQuery.toLowerCase();
    if (_searchQueryCache.containsKey(cacheQueryKey)) {
      if (kDebugMode) {
        debugPrint('⚡ [PROVIDER LOCATION] Search cache hit for query: $cleanQuery');
      }
      return _searchQueryCache[cacheQueryKey]!;
    }

    final List<ProviderLocationEntity> results = [];
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
            ProviderLocationEntity(
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

    // 1. High-speed Fuzzy Search via Photon API (Open-Source OSM Indian POIs & Towns - ZERO COST)
    try {
      String photonUrl = 'https://photon.komoot.io/api/?q=${Uri.encodeComponent(cleanQuery)}&limit=10';
      if (providerLat != null && providerLng != null) {
        photonUrl += '&lat=$providerLat&lon=$providerLng';
      }

      final photonRes = await _client.get(
        Uri.parse(photonUrl),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 6));

      if (photonRes.statusCode == 200) {
        final data = jsonDecode(photonRes.body) as Map<String, dynamic>;
        final features = data['features'] as List<dynamic>? ?? [];

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
            final lon = (coords[0] as num).toDouble();
            final lat = (coords[1] as num).toDouble();

            final name = (props['name'] as String? ?? '').trim();
            final street = (props['street'] as String? ?? '').trim();
            final district = (props['district'] as String? ?? props['county'] as String? ?? '').trim();
            final city = (props['city'] as String? ?? props['town'] as String? ?? props['village'] as String? ?? '').trim();
            final state = (props['state'] as String? ?? '').trim();
            final postcode = (props['postcode'] as String? ?? '').trim();

            final placeName = name.isNotEmpty
                ? name
                : street.isNotEmpty
                    ? street
                    : city.isNotEmpty
                        ? city
                        : district;

            if (placeName.contains('Phúc') || placeName.contains('Hà Nội')) {
              continue;
            }

            final addressParts = <String>[
              if (placeName.isNotEmpty && placeName != street && street.isNotEmpty) street,
              if (city.isNotEmpty && city != placeName) city,
              if (district.isNotEmpty && district != city && district != placeName) district,
              if (state.isNotEmpty) state,
              if (postcode.isNotEmpty) postcode,
              'भारत',
            ];

            final formattedAddress = addressParts.isNotEmpty
                ? addressParts.join(', ')
                : (state.isNotEmpty ? '$state, भारत' : (placeName.isNotEmpty ? '$placeName, भारत' : 'भारत'));

            final key = '${lat.toStringAsFixed(5)}_${lon.toStringAsFixed(5)}';
            if (placeName.isNotEmpty && !seenKeys.contains(key)) {
              seenKeys.add(key);
              results.add(ProviderLocationEntity(
                latitude: lat,
                longitude: lon,
                placeName: placeName,
                formattedAddress: formattedAddress,
                city: city,
                district: district,
                state: state,
                pincode: postcode,
                timestamp: DateTime.now(),
              ));
            }
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ [PROVIDER LOCATION] Photon search error: $e');
    }

    // 2. Nominatim API Search (OpenStreetMap Fallback - ZERO COST)
    if (results.length < 5) {
      try {
        final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(cleanQuery)}&format=jsonv2&addressdetails=1&limit=8&countrycodes=in',
        );

        final response = await _client.get(
          uri,
          headers: {
            'User-Agent': 'ApnaJamuiProviderApp/1.0 (contact: support@apnajamui.in)',
            'Accept': 'application/json',
            'Accept-Language': 'hi,en',
          },
        ).timeout(const Duration(seconds: 6));

        if (response.statusCode == 200) {
          final List<dynamic> list = jsonDecode(response.body) as List<dynamic>;
          for (final item in list) {
            final data = item as Map<String, dynamic>;
            final lat = double.tryParse(data['lat']?.toString() ?? '') ?? 0.0;
            final lon = double.tryParse(data['lon']?.toString() ?? '') ?? 0.0;
            final address = data['address'] as Map<String, dynamic>?;

            if (lat != 0.0 && lon != 0.0) {
              final key = '${lat.toStringAsFixed(5)}_${lon.toStringAsFixed(5)}';
              if (!seenKeys.contains(key)) {
                seenKeys.add(key);

                String placeName = (data['name'] as String? ?? '').trim();
                String village = '';
                String city = '';
                String district = '';
                String state = '';
                String pincode = '';

                if (address != null) {
                  final road = (address['road'] as String? ?? '').trim();
                  final neighbourhood = (address['neighbourhood'] as String? ?? '').trim();
                  final suburb = (address['suburb'] as String? ?? '').trim();
                  final town = (address['town'] as String? ?? '').trim();
                  final cityVal = (address['city'] as String? ?? '').trim();
                  final villageVal = (address['village'] as String? ?? address['hamlet'] as String? ?? '').trim();
                  final countyVal = (address['county'] as String? ?? '').trim();
                  final stateDist = (address['state_district'] as String? ?? '').trim();
                  final stateVal = (address['state'] as String? ?? '').trim();
                  final postcode = (address['postcode'] as String? ?? '').trim();

                  village = villageVal;
                  city = cityVal.isNotEmpty
                      ? cityVal
                      : town.isNotEmpty
                          ? town
                          : villageVal.isNotEmpty
                              ? villageVal
                              : countyVal;

                  district = stateDist.isNotEmpty ? stateDist : countyVal;
                  state = stateVal;
                  pincode = postcode;

                  if (placeName.isEmpty) {
                    placeName = villageVal.isNotEmpty
                        ? villageVal
                        : neighbourhood.isNotEmpty
                            ? neighbourhood
                            : suburb.isNotEmpty
                                ? suburb
                                : road.isNotEmpty
                                    ? road
                                    : city;
                  }
                }

                if (placeName.isEmpty) {
                  placeName = (data['display_name'] as String? ?? 'चयनित स्थान').split(',').first;
                }

                results.add(ProviderLocationEntity(
                  latitude: lat,
                  longitude: lon,
                  placeName: placeName,
                  formattedAddress: data['display_name'] as String? ?? '',
                  village: village,
                  city: city,
                  district: district,
                  state: state,
                  pincode: pincode,
                  timestamp: DateTime.now(),
                ));
              }
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ [PROVIDER LOCATION] Nominatim search error: $e');
      }
    }

    // 3. Optional Paid Google Places / Geocoding Search (ONLY if explicitly enabled via feature flag)
    if (results.isEmpty && MapsConfig.hasGoogleKey) {
      try {
        final googleUrl = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(cleanQuery)}&key=${MapsConfig.googleMapsApiKey}&language=hi&region=IN&components=country:IN',
        );
        final Map<String, String> googleHeaders = {};
        if (!kIsWeb) {
          googleHeaders['X-Android-Package'] = 'com.jamuiservice.provider';
          googleHeaders['X-Android-Cert'] = '5CB44C62DB96B43508899DC295437DE2A16741F0';
        }
        final res = await _client.get(
          googleUrl,
          headers: googleHeaders,
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
                results.add(ProviderLocationEntity(
                  latitude: lat,
                  longitude: lng,
                  placeName: placeName,
                  formattedAddress: formatted,
                  village: gVillage,
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
        debugPrint('⚠️ [PROVIDER LOCATION] Google search error: $e');
      }
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
