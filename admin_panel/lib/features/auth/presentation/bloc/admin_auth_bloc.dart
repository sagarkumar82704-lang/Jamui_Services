import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/admin_auth_repository.dart';
import 'admin_auth_event.dart';
import 'admin_auth_state.dart';

class AdminAuthBloc extends Bloc<AdminAuthEvent, AdminAuthState> {
  final AdminAuthRepository _authRepository;

  AdminAuthBloc({required AdminAuthRepository authRepository})
      : _authRepository = authRepository,
        super(AdminAuthInitial()) {
    on<CheckSessionEvent>(_onCheckSession);
    on<LoginEvent>(_onLogin);
    on<RegisterAdminEvent>(_onRegisterAdmin);
    on<LogoutEvent>(_onLogout);
    on<ResetPasswordEvent>(_onResetPassword);
  }

  Future<void> _onRegisterAdmin(
    RegisterAdminEvent event,
    Emitter<AdminAuthState> emit,
  ) async {
    emit(AdminAuthLoading());
    try {
      final user = await _authRepository.registerAdmin(
        name: event.name,
        email: event.email,
        password: event.password,
        role: event.role,
      );
      emit(AdminAuthenticated(user));
    } catch (e) {
      emit(AdminAuthError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onCheckSession(
    CheckSessionEvent event,
    Emitter<AdminAuthState> emit,
  ) async {
    emit(AdminAuthLoading());
    try {
      final user = await _authRepository.checkCurrentSession();
      if (user != null) {
        emit(AdminAuthenticated(user));
      } else {
        emit(AdminUnauthenticated());
      }
    } catch (_) {
      emit(AdminUnauthenticated());
    }
  }

  Future<void> _onLogin(
    LoginEvent event,
    Emitter<AdminAuthState> emit,
  ) async {
    emit(AdminAuthLoading());
    try {
      final user = await _authRepository.signIn(event.email, event.password);
      emit(AdminAuthenticated(user));
    } catch (e) {
      emit(AdminAuthError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onLogout(
    LogoutEvent event,
    Emitter<AdminAuthState> emit,
  ) async {
    emit(AdminAuthLoading());
    try {
      await _authRepository.signOut();
    } catch (_) {}
    emit(AdminUnauthenticated());
  }

  Future<void> _onResetPassword(
    ResetPasswordEvent event,
    Emitter<AdminAuthState> emit,
  ) async {
    emit(AdminAuthLoading());
    try {
      await _authRepository.resetPassword(event.email);
      emit(const PasswordResetSent('पासवर्ड रीसेट लिंक आपके ईमेल पर भेज दिया गया है।'));
    } catch (e) {
      emit(AdminAuthError(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
