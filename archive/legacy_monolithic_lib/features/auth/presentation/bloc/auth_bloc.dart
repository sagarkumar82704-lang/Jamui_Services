import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// [AuthBloc] ऑथेंटिकेशन के संपूर्ण स्टेट्स को मैनेज करता है।
/// यह केवल [AuthRepository] इंटरफ़ेस पर निर्भर करता है, सीधे Firebase पर नहीं।
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;

  AuthBloc({required this.authRepository})
      : super(const AuthInitial()) {
    on<SendOtpEvent>(_onSendOtp);
    on<VerifyOtpEvent>(_onVerifyOtp);
    on<ResendOtpEvent>(_onResendOtp);
    on<CheckAuthStatusEvent>(_onCheckAuthStatus);
    on<SignOutEvent>(_onSignOut);
  }

  /// 1. OTP भेजना
  Future<void> _onSendOtp(SendOtpEvent event, Emitter<AuthState> emit) async {
    emit(const AuthLoading(message: 'OTP भेजा जा रहा है...'));

    try {
      await authRepository.sendOtp(
        phoneNumber: event.phoneNumber,
        onCodeSent: (verificationId, resendToken) {
          emit(OtpSentState(
            verificationId: verificationId,
            phoneNumber: event.phoneNumber,
            selectedRole: event.selectedRole,
            resendToken: resendToken,
          ));
        },
        onError: (errorMsg) {
          emit(AuthErrorState(errorMsg));
        },
      );
    } catch (e) {
      emit(AuthErrorState(e.toString()));
    }
  }

  /// 2. OTP सत्यापित करना
  Future<void> _onVerifyOtp(VerifyOtpEvent event, Emitter<AuthState> emit) async {
    emit(const AuthLoading(message: 'OTP सत्यापित किया जा रहा है...'));

    try {
      final user = await authRepository.verifyOtp(
        verificationId: event.verificationId,
        smsCode: event.smsCode,
        selectedRole: event.selectedRole,
      );
      emit(AuthenticatedState(user));
    } catch (e) {
      emit(AuthErrorState(e.toString()));
    }
  }

  /// 3. OTP पुनः भेजना
  Future<void> _onResendOtp(ResendOtpEvent event, Emitter<AuthState> emit) async {
    emit(const AuthLoading(message: 'पुनः OTP भेजा जा रहा है...'));

    try {
      await authRepository.sendOtp(
        phoneNumber: event.phoneNumber,
        onCodeSent: (verificationId, resendToken) {
          emit(OtpSentState(
            verificationId: verificationId,
            phoneNumber: event.phoneNumber,
            selectedRole: event.selectedRole,
            resendToken: resendToken,
          ));
        },
        onError: (errorMsg) {
          emit(AuthErrorState(errorMsg));
        },
      );
    } catch (e) {
      emit(AuthErrorState(e.toString()));
    }
  }

  /// 4. लॉगिन स्थिति जाँचना
  Future<void> _onCheckAuthStatus(CheckAuthStatusEvent event, Emitter<AuthState> emit) async {
    try {
      final currentUser = await authRepository.getCurrentUser();
      if (currentUser != null) {
        emit(AuthenticatedState(currentUser));
      } else {
        emit(const UnauthenticatedState());
      }
    } catch (e) {
      emit(const UnauthenticatedState());
    }
  }

  /// 5. लॉगआउट करना
  Future<void> _onSignOut(SignOutEvent event, Emitter<AuthState> emit) async {
    emit(const AuthLoading(message: 'लॉगआउट किया जा रहा है...'));
    await authRepository.signOut();
    emit(const UnauthenticatedState());
  }
}
