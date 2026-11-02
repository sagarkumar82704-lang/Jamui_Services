import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../config/maps_config.dart';

// ──────────────────────────────────────────────
// GPS Accuracy Tiers for service feasibility
// ──────────────────────────────────────────────
enum LocationAccuracyTier {
  /// ≤ 25 m: Ideal for exact doorstep/shop location
  excellent,

  /// 25–100 m: Acceptable for building/street level
  acceptable,

  /// 100–600 m: Usable with caution
  warning,

  /// > 600 m: Poor — satellite fix insufficient
  poor,

  unknown,
}

class ProviderLocationResult {
  final double latitude;
  final double longitude;
  final String jamuiArea;
  final String fullAddress;
  final String village;
  final String locality;
  final String pincode;
  final String city;
  final double? accuracy;

  const ProviderLocationResult({
    required this.latitude,
    required this.longitude,
    required this.jamuiArea,
    required this.fullAddress,
    this.village = '',
    this.locality = '',
    required this.pincode,
    required this.city,
    this.accuracy,
  });
}

class LocationService {
  // ──────────────────────────────────────────────
  // Accuracy thresholds (meters)
  // ──────────────────────────────────────────────
  static const double thresholdExcellentMeters  = 25.0;
  static const double thresholdAcceptableMeters = 100.0;
  static const double thresholdMaxUsableMeters  = 600.0;

  static const _plusCodePattern = r'\b[A-Z0-9]{4,8}\+[A-Z0-9]{2,4}\b';

  /// Evaluate GPS horizontal accuracy against thresholds
  static LocationAccuracyTier evaluateAccuracy(double accuracyMeters) {
    if (accuracyMeters <= 0.0)                         return LocationAccuracyTier.unknown;
    if (accuracyMeters <= thresholdExcellentMeters)    return LocationAccuracyTier.excellent;
    if (accuracyMeters <= thresholdAcceptableMeters)   return LocationAccuracyTier.acceptable;
    if (accuracyMeters <= thresholdMaxUsableMeters)    return LocationAccuracyTier.warning;
    return LocationAccuracyTier.poor;
  }

  /// Check if location services (GPS hardware) are enabled on the device
  static Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Check current permission status
  static Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  /// Request permission from user
  static Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }

  /// Open app settings if permission is permanently denied
  static Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// Open location settings if GPS is disabled
  static Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Fetch real GPS position and reverse-geocode.
  /// NO HARDCODED FALLBACK COORDINATES.
  static Future<ProviderLocationResult> fetchCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('GPS बंद है। कृपया अपने फोन की Location/GPS चालू करें।');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('लोकेशन अनुमति (Location Permission) आवश्यक है।');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('लोकेशन अनुमति हमेशा के लिए ब्लॉक है। कृपया सेटिंग्स से अनुमति दें।');
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1,
        timeLimit: Duration(seconds: 20),
      ),
    );

    String jamuiArea = '';
    String fullAddress = '';
    String village = '';
    String locality = '';
    String pincode = '';
    String city = '';

    // ── Primary: Google Geocoding API
    if (MapsConfig.hasGoogleKey) {
      try {
        final googleUrl = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=${MapsConfig.googleMapsApiKey}&language=hi&region=IN',
        );
        final response = await http.get(googleUrl).timeout(const Duration(seconds: 6));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          if (data['status'] == 'OK') {
            final results = data['results'] as List<dynamic>? ?? [];
            if (results.isNotEmpty) {
              final first = results[0] as Map<String, dynamic>;
              final comps = first['address_components'] as List<dynamic>? ?? [];
              final formatted = (first['formatted_address'] as String? ?? '').trim();

              String gPoi = '';
              String gVillage = '';
              String gLocality = '';
              String gSubdistrict = '';
              String gDistrict = '';
              String gState = '';
              String gPin = '';

              for (final c in comps) {
                final types = (c['types'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
                final name = (c['long_name'] as String? ?? '').trim();
                if (types.contains('point_of_interest') || types.contains('establishment')) {
                  gPoi = name;
                } else if (types.contains('sublocality_level_2') || types.contains('sublocality_level_1') || types.contains('neighborhood')) {
                  if (gVillage.isEmpty) gVillage = name;
                } else if (types.contains('locality')) {
                  gLocality = name;
                } else if (types.contains('administrative_area_level_3')) {
                  gSubdistrict = name;
                } else if (types.contains('administrative_area_level_2')) {
                  gDistrict = name;
                } else if (types.contains('administrative_area_level_1')) {
                  gState = name;
                } else if (types.contains('postal_code')) {
                  gPin = name;
                }
              }

              if (gDistrict.contains('डिवीजन') || gDistrict.contains('Division') || gDistrict.isEmpty) {
                gDistrict = gSubdistrict.isNotEmpty ? gSubdistrict : 'जमुई';
              }

              jamuiArea = gPoi.isNotEmpty
                  ? gPoi
                  : (gVillage.isNotEmpty
                      ? gVillage
                      : (gLocality.isNotEmpty ? gLocality : (gSubdistrict.isNotEmpty ? gSubdistrict : gDistrict)));
              village = gVillage.isNotEmpty ? gVillage : jamuiArea;
              locality = gPoi.isNotEmpty ? gPoi : (gVillage.isNotEmpty ? gVillage : gLocality);
              pincode = gPin;
              city = gLocality.isNotEmpty ? gLocality : (gSubdistrict.isNotEmpty ? gSubdistrict : 'जमुई');

              String cleanFormatted = formatted.replaceFirst(RegExp(r'^[A-Z0-9\+]+\s*,\s*'), '').trim();
              if (cleanFormatted.isEmpty) {
                final parts = [jamuiArea, gSubdistrict, gDistrict, gState, gPin].where((s) => s.isNotEmpty).toSet().toList();
                cleanFormatted = parts.join(', ');
              }
              fullAddress = cleanFormatted;

              return ProviderLocationResult(
                latitude: position.latitude,
                longitude: position.longitude,
                jamuiArea: jamuiArea,
                fullAddress: fullAddress,
                village: village,
                locality: locality,
                pincode: pincode,
                city: city,
                accuracy: position.accuracy,
              );
            }
          }
        }
      } catch (_) {}
    }

    // ── Primary Zero-Cost Geocoder: BigDataCloud Client Reverse Geocoding API (100% Free for Client Apps)
    try {
      final bdcUrl = Uri.parse(
        'https://api-bdc.io/data/reverse-geocode-client?latitude=${position.latitude}&longitude=${position.longitude}&localityLanguage=en',
      );
      final bdcResp = await http.get(bdcUrl).timeout(const Duration(seconds: 5));
      if (bdcResp.statusCode == 200) {
        final bdcData = jsonDecode(bdcResp.body) as Map<String, dynamic>;
        final bdcLocality = (bdcData['locality'] as String? ?? '').trim();
        final bdcCity = (bdcData['city'] as String? ?? '').trim();
        final bdcSubdiv = (bdcData['principalSubdivision'] as String? ?? '').trim();
        final bdcPostcode = (bdcData['postcode'] as String? ?? '').trim();
        final bdcCountry = (bdcData['countryName'] as String? ?? '').trim();

        if (bdcLocality.isNotEmpty || bdcCity.isNotEmpty) {
          final chosenArea = bdcLocality.isNotEmpty ? bdcLocality : bdcCity;
          final addrParts = [bdcLocality, bdcCity, bdcSubdiv, bdcPostcode, bdcCountry].where((s) => s.isNotEmpty).toSet().toList();
          return ProviderLocationResult(
            latitude: position.latitude,
            longitude: position.longitude,
            jamuiArea: chosenArea,
            fullAddress: addrParts.join(', '),
            village: bdcLocality,
            locality: bdcCity,
            pincode: bdcPostcode,
            city: bdcCity.isNotEmpty ? bdcCity : bdcLocality,
            accuracy: position.accuracy,
          );
        }
      }
    } catch (_) {}

    // ── Secondary Fallback: Nominatim (OSM)
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=18&addressdetails=1',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'ApnaJamuiProviderApp/1.0 (contact: support@apnajamui.in)'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;
        final osmName = _cleanToken(data['name'] as String?);

        if (address != null) {
          final neighbourhood = _cleanToken(address['neighbourhood'] as String?);
          final suburb        = _cleanToken(address['suburb'] as String?);
          final road          = _cleanToken(address['road'] as String? ?? address['path'] as String?);
          final villageRaw    = _cleanToken(address['village'] as String? ?? address['hamlet'] as String?);
          final localityRaw   = _cleanToken(
            address['city'] as String? ??
            address['town'] as String? ??
            address['county'] as String? ??
            '',
          );
          final stateRaw  = _cleanToken(address['state'] as String?);
          final postcode  = _cleanToken(address['postcode'] as String?);

          village = villageRaw;
          locality = neighbourhood.isNotEmpty ? neighbourhood : (suburb.isNotEmpty ? suburb : road);
          pincode = postcode;
          city    = villageRaw.isNotEmpty ? villageRaw : localityRaw;

          if (osmName.isNotEmpty && osmName.toLowerCase() != localityRaw.toLowerCase()) {
            jamuiArea = osmName;
          } else if (neighbourhood.isNotEmpty) {
            jamuiArea = neighbourhood;
          } else if (suburb.isNotEmpty) {
            jamuiArea = suburb;
          } else if (villageRaw.isNotEmpty) {
            jamuiArea = villageRaw;
          } else if (road.isNotEmpty) {
            jamuiArea = road;
          } else if (localityRaw.isNotEmpty) {
            jamuiArea = localityRaw;
          } else {
            jamuiArea = 'वर्तमान स्थान';
          }

          fullAddress = cleanAddressString(
            street:      osmName != jamuiArea ? osmName : null,
            subLocality: neighbourhood.isNotEmpty ? neighbourhood : suburb,
            locality:    villageRaw.isNotEmpty ? villageRaw : localityRaw,
            state:       stateRaw,
            postalCode:  postcode,
          );
        }
      }
    } catch (_) {}

    if (jamuiArea.isEmpty) {
      jamuiArea = 'GPS (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
    }
    if (fullAddress.isEmpty) {
      fullAddress = 'GPS: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
    }

    return ProviderLocationResult(
      latitude:    position.latitude,
      longitude:   position.longitude,
      jamuiArea:   jamuiArea,
      fullAddress: fullAddress,
      village:     village,
      locality:    locality,
      pincode:     pincode,
      city:        city,
      accuracy:    position.accuracy,
    );
  }

  /// Calculate distance in kilometers between two GPS coordinates
  static double calculateDistanceKm({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    final distanceInMeters = Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
    return distanceInMeters / 1000.0;
  }

  // ──────────────────────────────────────────────
  // Address String Utilities
  // ──────────────────────────────────────────────

  /// Removes Plus Codes, 'Unnamed Road', null tokens, and leading/trailing punctuation
  static String _cleanToken(String? raw) {
    if (raw == null) return '';
    var t = raw.trim();
    if (t.isEmpty || t == 'Unnamed Road' || t == 'null' || t == 'N/A' || t == 'undefined') {
      return '';
    }
    t = t.replaceAll(RegExp(_plusCodePattern, caseSensitive: false), '').trim();
    t = t.replaceAll(RegExp(r'^[\s,.\-]+|[\s,.\-]+$'), '').trim();
    return t;
  }

  /// Builds a clean, de-duplicated address string.
  /// Skips empty tokens, Plus Codes, and duplicate substrings.
  static String cleanAddressString({
    String? street,
    String? subLocality,
    String? locality,
    String? state,
    String? postalCode,
    String? country,
  }) {
    final parts = <String>[];
    final seen  = <String>{};

    void add(String? token) {
      final clean = _cleanToken(token);
      if (clean.isEmpty) return;
      final key = clean.toLowerCase();
      if (seen.contains(key)) return;
      for (final existing in parts) {
        if (existing.toLowerCase().contains(key) && key.length > 4) return;
      }
      seen.add(key);
      parts.add(clean);
    }

    add(street);
    add(subLocality);
    add(locality);
    add(state);
    add(postalCode);
    add(country);

    return parts.isEmpty ? 'चुना हुआ स्थान' : parts.join(', ');
  }
}
