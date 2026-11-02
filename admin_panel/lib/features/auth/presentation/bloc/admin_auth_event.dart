import 'package:equatable/equatable.dart';

abstract class AdminAuthEvent extends Equatable {
  const AdminAuthEvent();

  @override
  List<Object?> get props => [];
}

class CheckSessionEvent extends AdminAuthEvent {}

class LoginEvent extends AdminAuthEvent {
  final String email;
  final String password;

  const LoginEvent({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class RegisterAdminEvent extends AdminAuthEvent {
  final String name;
  final String email;
  final String password;
  final String role;

  const RegisterAdminEvent({
    required this.name,
    required this.email,
    required this.password,
    this.role = 'super_admin',
  });

  @override
  List<Object?> get props => [name, email, password, role];
}

class LogoutEvent extends AdminAuthEvent {}

class ResetPasswordEvent extends AdminAuthEvent {
  final String email;

  const ResetPasswordEvent({required this.email});

  @override
  List<Object?> get props => [email];
}
