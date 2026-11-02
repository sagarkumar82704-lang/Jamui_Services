import 'dart:io';
import 'package:equatable/equatable.dart';
import '../../domain/entities/provider_profile_entity.dart';
import '../../domain/entities/custom_service_application_entity.dart';

abstract class ProviderAuthEvent extends Equatable {
  const ProviderAuthEvent();

  @override
  List<Object?> get props => [];
}

class CheckAuthStatusEvent extends ProviderAuthEvent {}

class LoginWithEmailEvent extends ProviderAuthEvent {
  final String email;
  final String password;
  const LoginWithEmailEvent({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class RegisterWithEmailEvent extends ProviderAuthEvent {
  final String email;
  final String password;
  final String fullName;
  final String phoneNumber;

  const RegisterWithEmailEvent({
    required this.email,
    required this.password,
    required this.fullName,
    required this.phoneNumber,
  });

  @override
  List<Object?> get props => [email, password, fullName, phoneNumber];
}

class SendPasswordResetEvent extends ProviderAuthEvent {
  final String email;
  const SendPasswordResetEvent(this.email);

  @override
  List<Object?> get props => [email];
}

class SendEmailVerificationEvent extends ProviderAuthEvent {}

class SignOutEvent extends ProviderAuthEvent {}

class LoadProviderProfileEvent extends ProviderAuthEvent {
  final String providerId;
  const LoadProviderProfileEvent(this.providerId);

  @override
  List<Object?> get props => [providerId];
}

class ProviderProfileStreamUpdatedEvent extends ProviderAuthEvent {
  final ProviderProfileEntity profile;
  const ProviderProfileStreamUpdatedEvent(this.profile);

  @override
  List<Object?> get props => [profile];
}

class UpdateProviderProfileEvent extends ProviderAuthEvent {
  final ProviderProfileEntity profile;
  const UpdateProviderProfileEvent(this.profile);

  @override
  List<Object?> get props => [profile];
}

class UpdatePermittedProfileFieldsEvent extends ProviderAuthEvent {
  final String providerId;
  final Map<String, dynamic> updatedFields;
  final ProviderProfileEntity updatedProfile;

  const UpdatePermittedProfileFieldsEvent({
    required this.providerId,
    required this.updatedFields,
    required this.updatedProfile,
  });

  @override
  List<Object?> get props => [providerId, updatedFields, updatedProfile];
}

class ToggleAvailabilityEvent extends ProviderAuthEvent {
  final bool isAvailable;
  const ToggleAvailabilityEvent(this.isAvailable);

  @override
  List<Object?> get props => [isAvailable];
}

class SubmitKycEvent extends ProviderAuthEvent {
  final String aadhaarNumber;
  const SubmitKycEvent(this.aadhaarNumber);

  @override
  List<Object?> get props => [aadhaarNumber];
}

class UploadProfilePhotoEvent extends ProviderAuthEvent {
  final File imageFile;
  const UploadProfilePhotoEvent(this.imageFile);

  @override
  List<Object?> get props => [imageFile];
}

class SendProviderOtpEvent extends ProviderAuthEvent {
  final String phoneNumber;
  const SendProviderOtpEvent(this.phoneNumber);

  @override
  List<Object?> get props => [phoneNumber];
}

class VerifyProviderOtpEvent extends ProviderAuthEvent {
  final String verificationId;
  final String smsCode;
  const VerifyProviderOtpEvent({required this.verificationId, required this.smsCode});

  @override
  List<Object?> get props => [verificationId, smsCode];
}

class SubmitCustomServiceApplicationEvent extends ProviderAuthEvent {
  final CustomServiceApplicationEntity application;
  const SubmitCustomServiceApplicationEvent(this.application);

  @override
  List<Object?> get props => [application];
}

class SubmitCategoryChangeRequestEvent extends ProviderAuthEvent {
  final String providerId;
  final String requestedCategoryId;
  final String requestedCategoryTitle;
  final Map<String, dynamic>? customServiceDetails;

  const SubmitCategoryChangeRequestEvent({
    required this.providerId,
    required this.requestedCategoryId,
    required this.requestedCategoryTitle,
    this.customServiceDetails,
  });

  @override
  List<Object?> get props => [
        providerId,
        requestedCategoryId,
        requestedCategoryTitle,
        customServiceDetails,
      ];
}

class MigratePhoneAccountEvent extends ProviderAuthEvent {
  final String providerId;
  final String email;
  final String password;

  const MigratePhoneAccountEvent({
    required this.providerId,
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [providerId, email, password];
}


