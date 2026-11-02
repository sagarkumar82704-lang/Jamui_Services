import 'package:equatable/equatable.dart';
import '../../domain/entities/admin_user_entity.dart';

abstract class AdminAuthState extends Equatable {
  const AdminAuthState();

  @override
  List<Object?> get props => [];
}

class AdminAuthInitial extends AdminAuthState {}

class AdminAuthLoading extends AdminAuthState {}

class AdminAuthenticated extends AdminAuthState {
  final AdminUserEntity adminUser;

  const AdminAuthenticated(this.adminUser);

  @override
  List<Object?> get props => [adminUser];
}

class AdminUnauthenticated extends AdminAuthState {}

class AdminAuthError extends AdminAuthState {
  final String message;

  const AdminAuthError(this.message);

  @override
  List<Object?> get props => [message];
}

class PasswordResetSent extends AdminAuthState {
  final String message;

  const PasswordResetSent(this.message);

  @override
  List<Object?> get props => [message];
}
