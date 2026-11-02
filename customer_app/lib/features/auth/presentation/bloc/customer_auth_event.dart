import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/customer_entity.dart';

abstract class CustomerAuthEvent extends Equatable {
  const CustomerAuthEvent();

  @override
  List<Object?> get props => [];
}

class CheckCustomerAuthStatusEvent extends CustomerAuthEvent {
  const CheckCustomerAuthStatusEvent();
}

class SendCustomerPhoneOtpEvent extends CustomerAuthEvent {
  final String phoneNumber;
  final int? resendToken;
  const SendCustomerPhoneOtpEvent(this.phoneNumber, {this.resendToken});

  @override
  List<Object?> get props => [phoneNumber, resendToken];
}

class CustomerOtpCodeSentEvent extends CustomerAuthEvent {
  final String verificationId;
  final int? resendToken;
  final String phoneNumber;

  const CustomerOtpCodeSentEvent({
    required this.verificationId,
    this.resendToken,
    required this.phoneNumber,
  });

  @override
  List<Object?> get props => [verificationId, resendToken, phoneNumber];
}

class VerifyCustomerPhoneOtpEvent extends CustomerAuthEvent {
  final String verificationId;
  final String smsCode;

  const VerifyCustomerPhoneOtpEvent({
    required this.verificationId,
    required this.smsCode,
  });

  @override
  List<Object?> get props => [verificationId, smsCode];
}

class CustomerAutoVerifiedEvent extends CustomerAuthEvent {
  final PhoneAuthCredential credential;

  const CustomerAutoVerifiedEvent(this.credential);

  @override
  List<Object?> get props => [credential];
}

class CheckCustomerProfilesAfterAuthEvent extends CustomerAuthEvent {
  final String uid;
  final String? phoneNumber;

  const CheckCustomerProfilesAfterAuthEvent({
    required this.uid,
    this.phoneNumber,
  });

  @override
  List<Object?> get props => [uid, phoneNumber];
}

class SignInWithEmailEvent extends CustomerAuthEvent {
  final String email;
  final String password;

  const SignInWithEmailEvent({
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [email, password];
}

class RegisterWithEmailEvent extends CustomerAuthEvent {
  final String email;
  final String password;
  final String fullName;
  final String phoneNumber;
  final String jamuiArea;
  final String address;
  final double? latitude;
  final double? longitude;

  const RegisterWithEmailEvent({
    required this.email,
    required this.password,
    required this.fullName,
    required this.phoneNumber,
    this.jamuiArea = 'जमुई',
    this.address = '',
    this.latitude,
    this.longitude,
  });

  @override
  List<Object?> get props => [
        email,
        password,
        fullName,
        phoneNumber,
        jamuiArea,
        address,
        latitude,
        longitude,
      ];
}

class LinkEmailToPhoneAccountEvent extends CustomerAuthEvent {
  final String email;
  final String password;

  const LinkEmailToPhoneAccountEvent({
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [email, password];
}


class SendPasswordResetEvent extends CustomerAuthEvent {
  final String email;
  const SendPasswordResetEvent(this.email);

  @override
  List<Object?> get props => [email];
}

class SaveCustomerProfileEvent extends CustomerAuthEvent {
  final CustomerEntity customer;
  const SaveCustomerProfileEvent(this.customer);

  @override
  List<Object?> get props => [customer];
}

class CustomerSignOutEvent extends CustomerAuthEvent {
  const CustomerSignOutEvent();
}
