import 'package:equatable/equatable.dart';

class CustomerEntity extends Equatable {
  final String id;
  final String phoneNumber;
  final String fullName;
  final String? email;
  final String jamuiArea;
  final String address;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const CustomerEntity({
    required this.id,
    this.phoneNumber = '',
    required this.fullName,
    this.email,
    this.jamuiArea = 'जमुई',
    this.address = '',
    this.latitude,
    this.longitude,
    required this.createdAt,
    this.updatedAt,
  });

  CustomerEntity copyWith({
    String? id,
    String? phoneNumber,
    String? fullName,
    String? email,
    String? jamuiArea,
    String? address,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomerEntity(
      id: id ?? this.id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      jamuiArea: jamuiArea ?? this.jamuiArea,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        phoneNumber,
        fullName,
        email,
        jamuiArea,
        address,
        latitude,
        longitude,
        createdAt,
        updatedAt,
      ];
}
