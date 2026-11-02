import '../../domain/entities/customer_entity.dart';

class CustomerModel extends CustomerEntity {
  const CustomerModel({
    required super.id,
    required super.phoneNumber,
    required super.fullName,
    super.email,
    super.jamuiArea,
    super.address,
    super.latitude,
    super.longitude,
    required super.createdAt,
    super.updatedAt,
  });

  factory CustomerModel.fromMap(Map<String, dynamic> map, String id) {
    return CustomerModel(
      id: id,
      phoneNumber: (map['phoneNumber'] as String?) ?? (map['phone'] as String?) ?? '',
      fullName: (map['fullName'] as String?) ?? (map['name'] as String?) ?? '',
      email: map['email'] as String?,
      jamuiArea: (map['jamuiArea'] as String?) ?? 'जमुई',
      address: (map['address'] as String?) ?? (map['formattedAddress'] as String?) ?? '',
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null ? DateTime.tryParse(map['updatedAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'role': 'customer',
      'phoneNumber': phoneNumber,
      'phone': phoneNumber,
      'fullName': fullName,
      'name': fullName,
      'email': email,
      'jamuiArea': jamuiArea,
      'address': address,
      'formattedAddress': address,
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}
