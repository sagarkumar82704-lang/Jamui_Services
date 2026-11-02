import '../../domain/entities/admin_user_entity.dart';

class AdminUserModel extends AdminUserEntity {
  const AdminUserModel({
    required super.uid,
    required super.email,
    required super.name,
    required super.role,
    super.permissions,
    super.status,
    super.createdAt,
    super.lastLogin,
  });

  factory AdminUserModel.fromMap(Map<String, dynamic> map, String uid) {
    return AdminUserModel(
      uid: uid,
      email: (map['email'] as String?) ?? '',
      name: (map['name'] as String?) ?? 'Master Admin',
      role: parseRole(map['role'] as String?),
      permissions: (map['permissions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const ['all'],
      status: (map['status'] as String?) ?? 'active',
      createdAt: map['createdAt'] != null ? DateTime.tryParse(map['createdAt'].toString()) : null,
      lastLogin: map['lastLogin'] != null ? DateTime.tryParse(map['lastLogin'].toString()) : null,
    );
  }

  static AdminRole parseRole(String? role) {
    switch (role) {
      case 'super_admin':
        return AdminRole.superAdmin;
      case 'admin':
        return AdminRole.admin;
      case 'moderator':
        return AdminRole.moderator;
      case 'support':
        return AdminRole.support;
      case 'finance':
        return AdminRole.finance;
      default:
        return AdminRole.admin;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'role': role.name,
      'permissions': permissions,
      'status': status,
      'createdAt': createdAt?.toIso8601String(),
      'lastLogin': lastLogin?.toIso8601String(),
    };
  }
}
