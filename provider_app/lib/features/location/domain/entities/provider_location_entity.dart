import 'package:equatable/equatable.dart';

class ProviderLocationEntity extends Equatable {
  final double latitude;
  final double longitude;
  final String placeName;
  final String formattedAddress;
  final String village;
  final String locality;
  final String city;
  final String district;
  final String state;
  final String pincode;
  final double? accuracy;
  final double serviceRadiusKm;
  final DateTime timestamp;
  final String source;

  const ProviderLocationEntity({
    required this.latitude,
    required this.longitude,
    required this.placeName,
    required this.formattedAddress,
    this.village = '',
    this.locality = '',
    required this.city,
    required this.district,
    required this.state,
    required this.pincode,
    this.accuracy,
    this.serviceRadiusKm = 10.0,
    required this.timestamp,
    this.source = 'native_gps',
  });

  ProviderLocationEntity copyWith({
    double? latitude,
    double? longitude,
    String? placeName,
    String? formattedAddress,
    String? village,
    String? locality,
    String? city,
    String? district,
    String? state,
    String? pincode,
    double? accuracy,
    double? serviceRadiusKm,
    DateTime? timestamp,
    String? source,
  }) {
    return ProviderLocationEntity(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      placeName: placeName ?? this.placeName,
      formattedAddress: formattedAddress ?? this.formattedAddress,
      village: village ?? this.village,
      locality: locality ?? this.locality,
      city: city ?? this.city,
      district: district ?? this.district,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      accuracy: accuracy ?? this.accuracy,
      serviceRadiusKm: serviceRadiusKm ?? this.serviceRadiusKm,
      timestamp: timestamp ?? this.timestamp,
      source: source ?? this.source,
    );
  }

  bool get hasValidCoordinates => latitude != 0.0 && longitude != 0.0;
  bool get isLocationUnavailable => !hasValidCoordinates;

  /// Accuracy classification
  bool get isAccurate => (accuracy ?? 0.0) <= 100.0;
  bool get isWarningAccuracy => (accuracy ?? 0.0) > 100.0 && (accuracy ?? 0.0) <= 150.0;
  bool get isPoorAccuracy => (accuracy ?? 0.0) > 150.0;

  Map<String, dynamic> toMap() {
    return {
      'latitude': hasValidCoordinates ? latitude : null,
      'longitude': hasValidCoordinates ? longitude : null,
      'isLocationAvailable': hasValidCoordinates,
      'placeName': placeName,
      'jamuiArea': placeName,
      'formattedAddress': formattedAddress,
      'fullAddress': formattedAddress,
      'address': formattedAddress,
      'village': village,
      'locality': locality,
      'city': city,
      'district': district,
      'state': state,
      'pincode': pincode,
      'accuracy': accuracy,
      'serviceRadiusKm': serviceRadiusKm,
      'timestamp': timestamp.toIso8601String(),
      'source': source,
    };
  }

  factory ProviderLocationEntity.fromMap(Map<String, dynamic> map) {
    return ProviderLocationEntity(
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      placeName: map['placeName'] as String? ?? map['jamuiArea'] as String? ?? '',
      formattedAddress: map['formattedAddress'] as String? ?? map['fullAddress'] as String? ?? map['address'] as String? ?? '',
      village: map['village'] as String? ?? '',
      locality: map['locality'] as String? ?? '',
      city: map['city'] as String? ?? '',
      district: map['district'] as String? ?? '',
      state: map['state'] as String? ?? '',
      pincode: map['pincode'] as String? ?? '',
      accuracy: (map['accuracy'] as num?)?.toDouble(),
      serviceRadiusKm: (map['serviceRadiusKm'] as num?)?.toDouble() ?? 10.0,
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      source: map['source'] as String? ?? 'native_gps',
    );
  }

  @override
  List<Object?> get props => [
        latitude,
        longitude,
        placeName,
        formattedAddress,
        village,
        locality,
        city,
        district,
        state,
        pincode,
        accuracy,
        serviceRadiusKm,
        timestamp,
        source,
      ];
}
