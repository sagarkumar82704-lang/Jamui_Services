import 'package:equatable/equatable.dart';

/// [UserRole] सिस्टम में यूजर की भूमिका (Role) तय करता है।
enum UserRole {
  customer,
  provider,
  admin,
  unknown,
}

/// [UserEntity] शुद्ध डाट (Pure Dart) इकाई है।
/// इसमें कोई भी Firebase या थर्ड-पार्टी क्लास नहीं है।
/// इससे यह गारंटी मिलती है कि बैकएंड बदलने पर भी हमारा बिज़नेस मॉडल नहीं बदलेगा।
class UserEntity extends Equatable {
  final String id;
  final String phone;
  final String name;
  final UserRole role;
  final bool isProfileComplete;
  final bool isVerified;
  final DateTime createdAt;

  const UserEntity({
    required this.id,
    required this.phone,
    this.name = '',
    required this.role,
    this.isProfileComplete = false,
    this.isVerified = false,
    required this.createdAt,
  });

  bool get isCustomer => role == UserRole.customer;
  bool get isProvider => role == UserRole.provider;
  bool get isAdmin => role == UserRole.admin;

  UserEntity copyWith({
    String? id,
    String? phone,
    String? name,
    UserRole? role,
    bool? isProfileComplete,
    bool? isVerified,
    DateTime? createdAt,
  }) {
    return UserEntity(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      name: name ?? this.name,
      role: role ?? this.role,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        phone,
        name,
        role,
        isProfileComplete,
        isVerified,
        createdAt,
      ];
}
