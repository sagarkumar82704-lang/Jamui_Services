import 'package:equatable/equatable.dart';
import '../../domain/entities/provider_profile_entity.dart';
import '../../domain/entities/custom_service_application_entity.dart';

abstract class ProviderAuthState extends Equatable {
  const ProviderAuthState();

  @override
  List<Object?> get props => [];
}

class ProviderAuthInitial extends ProviderAuthState {}

class ProviderAuthLoading extends ProviderAuthState {}

class ProviderUnauthenticated extends ProviderAuthState {}

class ProviderAuthenticated extends ProviderAuthState {
  final ProviderProfileEntity profile;
  const ProviderAuthenticated(this.profile);

  @override
  List<Object?> get props => [
        profile.id,
        profile.status,
        profile.kycStatus,
        profile.isSubscriptionActive,
        profile.isActive,
        profile.categoryType,
        profile.primaryCategoryId,
        profile.businessName,
        profile.isDeleted,
        profile.isAvailable,
      ];
}

class ProviderProfileIncomplete extends ProviderAuthState {
  final ProviderProfileEntity profile;
  const ProviderProfileIncomplete(this.profile);

  @override
  List<Object?> get props => [
        profile.id,
        profile.status,
        profile.kycStatus,
        profile.registrationStatus,
        profile.primaryCategoryId,
        profile.categoryType,
        profile.businessName,
        profile.currentStep,
        profile.isDeleted,
      ];
}

class ProviderEmailUnverified extends ProviderAuthState {
  final String email;
  const ProviderEmailUnverified(this.email);

  @override
  List<Object?> get props => [email];
}

class ProviderAccountBlockedState extends ProviderAuthState {
  final String reason;
  const ProviderAccountBlockedState({this.reason = 'आपका प्रोवाइडर अकाउंट एडमिन द्वारा ब्लॉक कर दिया गया है।'});

  @override
  List<Object?> get props => [reason];
}

class ProviderAuthError extends ProviderAuthState {
  final String message;
  const ProviderAuthError(this.message);

  @override
  List<Object?> get props => [message];
}

class ProviderPasswordResetSentState extends ProviderAuthState {
  final String message;
  const ProviderPasswordResetSentState(this.message);

  @override
  List<Object?> get props => [message];
}

class ProviderEmailVerificationSentState extends ProviderAuthState {
  final String message;
  const ProviderEmailVerificationSentState(this.message);

  @override
  List<Object?> get props => [message];
}

class ProviderKycSubmittedSuccess extends ProviderAuthState {
  final String message;
  final ProviderProfileEntity? profile;

  const ProviderKycSubmittedSuccess({
    this.message = 'KYC सफलतापूर्वक समीक्षा के लिए भेजा गया!',
    this.profile,
  });

  @override
  List<Object?> get props => [message, profile];
}

class ProviderProfileUpdatedSuccessState extends ProviderAuthState {
  final String message;
  final ProviderProfileEntity profile;

  const ProviderProfileUpdatedSuccessState({
    required this.message,
    required this.profile,
  });

  @override
  List<Object?> get props => [message, profile];
}

class ProviderOtpSentState extends ProviderAuthState {
  final String verificationId;
  final String phoneNumber;

  const ProviderOtpSentState({
    required this.verificationId,
    required this.phoneNumber,
  });

  @override
  List<Object?> get props => [verificationId, phoneNumber];
}

class ProviderNotRegisteredErrorState extends ProviderAuthState {
  final String userId;
  final String phoneNumber;
  final String message;

  const ProviderNotRegisteredErrorState({
    required this.userId,
    required this.phoneNumber,
    this.message = 'इस मोबाइल नंबर से कोई सेवा प्रदाता (Provider) खाता पंजीकृत नहीं है। कृपया नया रजिस्ट्रेशन करें।',
  });

  @override
  List<Object?> get props => [userId, phoneNumber, message];
}

class ProviderCustomServiceSubmittedSuccessState extends ProviderAuthState {
  final String message;
  final CustomServiceApplicationEntity application;

  const ProviderCustomServiceSubmittedSuccessState({
    this.message = 'आपकी नई सेवा का प्रस्ताव सफलतापूर्वक एडमिन समीक्षा के लिए भेज दिया गया है!',
    required this.application,
  });

  @override
  List<Object?> get props => [message, application];
}

class ProviderAccountMigratedSuccessState extends ProviderAuthState {
  final String message;
  final ProviderProfileEntity profile;

  const ProviderAccountMigratedSuccessState({
    required this.message,
    required this.profile,
  });

  @override
  List<Object?> get props => [message, profile];
}


