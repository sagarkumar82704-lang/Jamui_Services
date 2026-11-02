import 'package:equatable/equatable.dart';

class CustomerLocationEntity extends Equatable {
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
  final DateTime timestamp;

  const CustomerLocationEntity({
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
    required this.timestamp,
  });

  CustomerLocationEntity copyWith({
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
    DateTime? timestamp,
  }) {
    return CustomerLocationEntity(
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
      timestamp: timestamp ?? this.timestamp,
    );
  }

  bool get hasValidCoordinates => latitude != 0.0 && longitude != 0.0;
  bool get isLocationUnavailable => !hasValidCoordinates;

  Map<String, dynamic> toMap() {
    return {
      'latitude': hasValidCoordinates ? latitude : null,
      'longitude': hasValidCoordinates ? longitude : null,
      'isLocationAvailable': hasValidCoordinates,
      'placeName': placeName,
      'formattedAddress': formattedAddress,
      'village': village,
      'locality': locality,
      'city': city,
      'district': district,
      'state': state,
      'pincode': pincode,
      'accuracy': accuracy,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory CustomerLocationEntity.fromMap(Map<String, dynamic> map) {
    return CustomerLocationEntity(
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      placeName: map['placeName'] as String? ?? '',
      formattedAddress: map['formattedAddress'] as String? ?? '',
      village: map['village'] as String? ?? '',
      locality: map['locality'] as String? ?? '',
      city: map['city'] as String? ?? '',
      district: map['district'] as String? ?? '',
      state: map['state'] as String? ?? '',
      pincode: map['pincode'] as String? ?? '',
      accuracy: (map['accuracy'] as num?)?.toDouble(),
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
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
        timestamp,
      ];
}

