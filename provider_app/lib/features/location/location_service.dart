import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class LocationResult {
  final double latitude;
  final double longitude;
  final String jamuiArea;
  final String fullAddress;
  final String pincode;
  final String city;

  const LocationResult({
    required this.latitude,
    required this.longitude,
    required this.jamuiArea,
    required this.fullAddress,
    required this.pincode,
    required this.city,
  });
}

class LocationService {
  /// Request GPS Location Permission and obtain real GPS coordinates & address
  Future<LocationResult> fetchCurrentGPSLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('GPS Location Service चालू नहीं है। कृपया अपने फोन की Location ON करें।');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('लोकेशन अनुमति (Permission) अस्वीकृत कर दी गई है।');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('लोकेशन अनुमति हमेशा के लिए ब्लॉक है। कृपया सिस्टम सेटिंग्स से Location अनुमति दें।');
    }

    // Get current position with high accuracy
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    String jamuiArea = 'जमुई मुख्य बाजार';
    String fullAddress = 'Jamui, Bihar, India';
    String pincode = '811307';
    String city = 'Jamui';

    try {
      // Use OpenStreetMap Nominatim for reverse geocoding (free, no API key needed)
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=18&addressdetails=1',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'ApnaJamuiProviderApp/1.0'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final address = data['address'] as Map<String, dynamic>?;

        if (address != null) {
          final suburb = address['suburb'] as String? ?? '';
          final neighbourhood = address['neighbourhood'] as String? ?? '';
          final road = address['road'] as String? ?? '';
          final locality = address['city'] as String? ??
              address['town'] as String? ??
              address['village'] as String? ??
              address['county'] as String? ??
              'Jamui';
          final state = address['state'] as String? ?? 'Bihar';
          final postcode = address['postcode'] as String? ?? '811307';

          pincode = postcode;
          city = locality;

          // Prefer neighbourhood/suburb as local area name
          jamuiArea = neighbourhood.isNotEmpty
              ? neighbourhood
              : suburb.isNotEmpty
                  ? suburb
                  : road.isNotEmpty
                      ? road
                      : locality;

          fullAddress = [
            if (road.isNotEmpty) road,
            if (suburb.isNotEmpty) suburb,
            locality,
            state,
            postcode,
          ].where((e) => e.isNotEmpty).join(', ');
        }
      }
    } catch (_) {
      // Geocoding failed — use defaults (Jamui center)
    }

    return LocationResult(
      latitude: position.latitude,
      longitude: position.longitude,
      jamuiArea: jamuiArea,
      fullAddress: fullAddress,
      pincode: pincode,
      city: city,
    );
  }
}
