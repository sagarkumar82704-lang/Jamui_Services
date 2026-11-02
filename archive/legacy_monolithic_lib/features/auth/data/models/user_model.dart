import '../../../../shared/models/base_firestore_model.dart';
import '../../domain/entities/user_entity.dart';

/// [UserModel] डेटाबेस (Firestore या REST API JSON) और डोमेन [UserEntity] के बीच अनुवादक (Mapper) का कार्य करता है।
class UserModel extends BaseFirestoreModel {
  final String phone;
  final String name;
  final String roleString;
  final bool isProfileComplete;
  final bool isVerified;

  const UserModel({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    super.schemaVersion = 1,
    required this.phone,
    this.name = '',
    required this.roleString,
    this.isProfileComplete = false,
    this.isVerified = false,
  });

  /// Map (Firestore / JSON) से सुरक्षित रूप से UserModel बनाना
  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      createdAt: BaseFirestoreModel.parseDateTime(map['createdAt']),
      updatedAt: BaseFirestoreModel.parseDateTime(map['updatedAt']),
      schemaVersion: BaseFirestoreModel.parseInt(map['schemaVersion'], 1),
      phone: BaseFirestoreModel.parseString(map['phone']),
      name: BaseFirestoreModel.parseString(map['name']),
      roleString: BaseFirestoreModel.parseString(map['role'], 'customer'),
      isProfileComplete: BaseFirestoreModel.parseBool(map['isProfileComplete'], false),
      isVerified: BaseFirestoreModel.parseBool(map['isVerified'], false),
    );
  }

  /// डेटाबेस में लिखने के लिए Map तैयार करना
  @override
  Map<String, dynamic> toMap() {
    return {
      'schemaVersion': schemaVersion,
      'phone': phone,
      'name': name,
      'role': roleString,
      'isProfileComplete': isProfileComplete,
      'isVerified': isVerified,
    };
  }

  /// [UserEntity] में कनवर्ट करना (Domain Layer के लिए)
  UserEntity toEntity() {
    UserRole role = UserRole.unknown;
    if (roleString == 'customer') {
      role = UserRole.customer;
    } else if (roleString == 'provider') {
      role = UserRole.provider;
    } else if (roleString == 'admin') {
      role = UserRole.admin;
    }

    return UserEntity(
      id: id,
      phone: phone,
      name: name,
      role: role,
      isProfileComplete: isProfileComplete,
      isVerified: isVerified,
      createdAt: createdAt,
    );
  }

  /// [UserEntity] से [UserModel] बनाना
  factory UserModel.fromEntity(UserEntity entity) {
    String roleStr = 'customer';
    if (entity.role == UserRole.provider) {
      roleStr = 'provider';
    } else if (entity.role == UserRole.admin) {
      roleStr = 'admin';
    }

    return UserModel(
      id: entity.id,
      createdAt: entity.createdAt,
      updatedAt: DateTime.now(),
      phone: entity.phone,
      name: entity.name,
      roleString: roleStr,
      isProfileComplete: entity.isProfileComplete,
      isVerified: entity.isVerified,
    );
  }
}
