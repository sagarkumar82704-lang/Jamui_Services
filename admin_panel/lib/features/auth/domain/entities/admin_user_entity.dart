import 'package:equatable/equatable.dart';

enum AdminRole {
  superAdmin,
  admin,
  moderator,
  support,
  finance;

  String get displayNameHindi {
    switch (this) {
      case AdminRole.superAdmin:
        return 'मास्टर एडमिन (Super Admin)';
      case AdminRole.admin:
        return 'एडमिनिस्ट्रेटर (Admin)';
      case AdminRole.moderator:
        return 'मॉडरेटर (Moderator)';
      case AdminRole.support:
        return 'सपोर्ट टीम (Support)';
      case AdminRole.finance:
        return 'फाइनेंस / अकाउंट्स (Finance)';
    }
  }
}

class AdminUserEntity extends Equatable {
  final String uid;
  final String email;
  final String name;
  final AdminRole role;
  final List<String> permissions;
  final String status;
  final DateTime? createdAt;
  final DateTime? lastLogin;

  const AdminUserEntity({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.permissions = const ['all'],
    this.status = 'active',
    this.createdAt,
    this.lastLogin,
  });

  bool get isSuperAdmin => role == AdminRole.superAdmin;
  bool get isAdminOrAbove => role == AdminRole.superAdmin || role == AdminRole.admin;

  @override
  List<Object?> get props => [uid, email, name, role, permissions, status, createdAt, lastLogin];
}
