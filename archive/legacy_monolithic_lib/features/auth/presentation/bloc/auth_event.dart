import 'package:equatable/equatable.dart';
import '../../domain/entities/user_entity.dart';

/// [AuthEvent] ऑथेंटिकेशन BLoC के सभी यूजर इवेंट्स का बेस मॉडल है।
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// 1. फोन नंबर पर OTP भेजने का इवेंट
class SendOtpEvent extends AuthEvent {
  final String phoneNumber;
  final UserRole selectedRole;

  const SendOtpEvent({
    required this.phoneNumber,
    required this.selectedRole,
  });

  @override
  List<Object?> get props => [phoneNumber, selectedRole];
}

/// 2. OTP सत्यापित करने का इवेंट
class VerifyOtpEvent extends AuthEvent {
  final String verificationId;
  final String smsCode;
  final UserRole selectedRole;

  const VerifyOtpEvent({
    required this.verificationId,
    required this.smsCode,
    required this.selectedRole,
  });

  @override
  List<Object?> get props => [verificationId, smsCode, selectedRole];
}

/// 3. OTP पुनः भेजने का इवेंट
class ResendOtpEvent extends AuthEvent {
  final String phoneNumber;
  final UserRole selectedRole;
  final int? resendToken;

  const ResendOtpEvent({
    required this.phoneNumber,
    required this.selectedRole,
    this.resendToken,
  });

  @override
  List<Object?> get props => [phoneNumber, selectedRole, resendToken];
}

/// 4. वर्तमान ऑथेंटिकेशन स्थिति जाँचने का इवेंट
class CheckAuthStatusEvent extends AuthEvent {
  const CheckAuthStatusEvent();
}

/// 5. लॉगआउट इवेंट
class SignOutEvent extends AuthEvent {
  const SignOutEvent();
}
