import 'package:equatable/equatable.dart';
import '../../domain/entities/user_entity.dart';

/// [AuthState] ऑथेंटिकेशन के विभिन्न स्टेट्स को दर्शाता है।
abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// 1. प्रारंभिक स्थिति (Initial)
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// 2. लोडिंग स्थिति (Loading - जब OTP भेजा या जांचा जा रहा हो)
class AuthLoading extends AuthState {
  final String message;
  const AuthLoading({this.message = 'कृपया प्रतीक्षा करें...'});

  @override
  List<Object?> get props => [message];
}

/// 3. OTP भेजा जा चुका है (OTP Sent)
class OtpSentState extends AuthState {
  final String verificationId;
  final String phoneNumber;
  final UserRole selectedRole;
  final int? resendToken;

  const OtpSentState({
    required this.verificationId,
    required this.phoneNumber,
    required this.selectedRole,
    this.resendToken,
  });

  @override
  List<Object?> get props => [verificationId, phoneNumber, selectedRole, resendToken];
}

/// 4. यूजर सफलतापूर्वक प्रमाणित हो गया (Authenticated)
class AuthenticatedState extends AuthState {
  final UserEntity user;
  const AuthenticatedState(this.user);

  @override
  List<Object?> get props => [user];
}

/// 5. यूजर लॉग-इन नहीं है (Unauthenticated)
class UnauthenticatedState extends AuthState {
  const UnauthenticatedState();
}

/// 6. एरर स्थिति (Error)
class AuthErrorState extends AuthState {
  final String message;
  const AuthErrorState(this.message);

  @override
  List<Object?> get props => [message];
}
