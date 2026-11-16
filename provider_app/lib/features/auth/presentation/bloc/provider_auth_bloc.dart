import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/web_host_bridge.dart';
import '../../../../core/utils/auth_exception_handler.dart';
import '../../domain/entities/provider_profile_entity.dart';
import '../../domain/repositories/provider_repository.dart';
import 'provider_auth_event.dart';
import 'provider_auth_state.dart';

class ProviderAuthBloc extends Bloc<ProviderAuthEvent, ProviderAuthState> {
  final ProviderRepository providerRepository;
  StreamSubscription<ProviderProfileEntity?>? _profileSubscription;

  ProviderAuthBloc({required this.providerRepository}) : super(ProviderAuthInitial()) {
    on<CheckAuthStatusEvent>(_onCheckAuthStatus);
    on<ProviderProfileStreamUpdatedEvent>(_onProfileStreamUpdated);
    on<LoginWithEmailEvent>(_onLoginWithEmail);
    on<RegisterWithEmailEvent>(_onRegisterWithEmail);
    on<SendPasswordResetEvent>(_onSendPasswordReset);
    on<SendEmailVerificationEvent>(_onSendEmailVerification);
    on<SignOutEvent>(_onSignOut);
    on<LoadProviderProfileEvent>(_onLoadProfile);
    on<UpdateProviderProfileEvent>(_onUpdateProfile);
    on<UpdatePermittedProfileFieldsEvent>(_onUpdatePermittedProfileFields);
    on<ToggleAvailabilityEvent>(_onToggleAvailability);
    on<SubmitKycEvent>(_onSubmitKyc);
    on<UploadProfilePhotoEvent>(_onUploadProfilePhoto);
    on<SubmitCustomServiceApplicationEvent>(_onSubmitCustomServiceApplication);
    on<SubmitCategoryChangeRequestEvent>(_onSubmitCategoryChangeRequest);
  }

  void _startWatchingProfile(String uid) {
    _profileSubscription?.cancel();
    _profileSubscription = providerRepository.watchProfile(uid).listen(
      (profile) {
        if (profile != null) {
          add(ProviderProfileStreamUpdatedEvent(profile));
        }
      },
      onError: (err) {
        // stream error fallback
      },
    );
  }

  bool _isProfileIncomplete(ProviderProfileEntity profile) {
    if (profile.registrationStatus == 'completed' || profile.completedSteps.contains(5)) {
      return false;
    }
    if (profile.status == ProviderAccountStatus.pendingReview || profile.status == ProviderAccountStatus.approved) {
      return false;
    }
    return profile.status == ProviderAccountStatus.draft ||
        profile.registrationStatus == 'draft' ||
        profile.registrationStatus == 'pending_category_approval' ||
        profile.registrationStatus == 'category_approved' ||
        profile.businessName.trim().isEmpty ||
        profile.primaryCategoryId.trim().isEmpty;
  }

  void _onProfileStreamUpdated(
    ProviderProfileStreamUpdatedEvent event,
    Emitter<ProviderAuthState> emit,
  ) {
    final profile = event.profile;
    if (profile.status == ProviderAccountStatus.blocked || profile.status == ProviderAccountStatus.suspended) {
      if (state is! ProviderAccountBlockedState) {
        emit(ProviderAccountBlockedState(
          reason: profile.rejectionReason ?? 'Your account has been deactivated or suspended by admin.',
        ));
      }
      return;
    }

    if (_isProfileIncomplete(profile)) {
      if (state is ProviderProfileIncomplete) {
        final cur = (state as ProviderProfileIncomplete).profile;
        if (cur.id == profile.id &&
            cur.status == profile.status &&
            cur.kycStatus == profile.kycStatus &&
            cur.registrationStatus == profile.registrationStatus &&
            cur.primaryCategoryId == profile.primaryCategoryId &&
            cur.categoryType == profile.categoryType &&
            cur.currentStep == profile.currentStep &&
            cur.isDeleted == profile.isDeleted) {
          // No routing change, ignore duplicate stream emission
          return;
        }
      }
      emit(ProviderProfileIncomplete(profile));
      return;
    }

    if (state is ProviderAuthenticated) {
      final cur = (state as ProviderAuthenticated).profile;
      if (cur.id == profile.id &&
          cur.status == profile.status &&
          cur.isSubscriptionActive == profile.isSubscriptionActive &&
          cur.isActive == profile.isActive &&
          cur.categoryType == profile.categoryType &&
          cur.primaryCategoryId == profile.primaryCategoryId &&
          cur.businessName == profile.businessName &&
          cur.isDeleted == profile.isDeleted) {
        // No routing change, ignore duplicate stream emission
        return;
      }
    }

    emit(ProviderAuthenticated(profile));
  }

  Future<void> _onCheckAuthStatus(
    CheckAuthStatusEvent event,
    Emitter<ProviderAuthState> emit,
  ) async {
    emit(ProviderAuthLoading());
    try {
      final user = providerRepository.getCurrentUser();
      if (user == null) {
        _profileSubscription?.cancel();
        emit(ProviderUnauthenticated());
        WebHostBridge.notify('PROVIDER_READY');
        return;
      }

      ProviderProfileEntity? profile;
      try {
        profile = await providerRepository.getProfile(user.uid).timeout(const Duration(seconds: 6));
      } catch (err) {
        debugPrint('⚠️ [ProviderAuthBloc] getProfile error or timeout: $err');
      }

      if (profile == null && user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
        try {
          profile = await providerRepository.findRegisteredProviderByPhone(user.phoneNumber!).timeout(const Duration(seconds: 4));
        } catch (_) {}
      }

      // If user does not have a provider profile in providers collection, sign out to clean orphan tokens
      if (profile == null) {
        _profileSubscription?.cancel();
        try {
          await providerRepository.signOut();
        } catch (_) {}
        emit(ProviderUnauthenticated());
        WebHostBridge.notify('PROVIDER_READY');
        return;
      }

      _startWatchingProfile(profile.id);

      if (profile.status == ProviderAccountStatus.blocked || profile.status == ProviderAccountStatus.suspended) {
        emit(ProviderAccountBlockedState(
          reason: profile.rejectionReason ?? 'आपका अकाउंट एडमिन द्वारा ब्लॉक या निलंबित कर दिया गया है।',
        ));
        WebHostBridge.notify('PROVIDER_READY');
        return;
      }

      // Seamless Registration Resume: If profile is genuinely incomplete draft, resume registration
      if (_isProfileIncomplete(profile)) {
        emit(ProviderProfileIncomplete(profile));
        WebHostBridge.notify('PROVIDER_READY');
        return;
      }

      // Store provider role in local namespace
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('provider_active_uid', profile.id);
        await prefs.setString('provider_active_role', 'provider');
      } catch (_) {}

      emit(ProviderAuthenticated(profile));
      WebHostBridge.notify('PROVIDER_READY');
    } catch (e) {
      _profileSubscription?.cancel();
      emit(ProviderUnauthenticated());
      WebHostBridge.notify('PROVIDER_READY');
    }
  }

  Future<void> _onLoginWithEmail(
    LoginWithEmailEvent event,
    Emitter<ProviderAuthState> emit,
  ) async {
    emit(ProviderAuthLoading());
    try {
      final cleanEmail = event.email.trim().toLowerCase();
      final cleanPassword = event.password.trim();
      final user = await providerRepository.loginWithEmail(
        email: cleanEmail,
        password: cleanPassword,
      );

      if (user != null) {
        var profile = await providerRepository.getProfile(user.uid);
        if (profile == null && cleanEmail.isNotEmpty) {
          profile = await providerRepository.findRegisteredProviderByEmail(cleanEmail);
          if (profile != null && profile.id != user.uid) {
            await providerRepository.saveProfile(profile.copyWith(id: user.uid));
          }
        }

        if (profile == null && user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
          profile = await providerRepository.findRegisteredProviderByPhone(user.phoneNumber!);
          if (profile != null && profile.id != user.uid) {
            await providerRepository.saveProfile(profile.copyWith(id: user.uid));
          }
        }

        if (profile == null) {
          await providerRepository.signOut();
          emit(ProviderNotRegisteredErrorState(
            userId: user.uid,
            phoneNumber: cleanEmail,
            message: 'इस ईमेल से कोई प्रोवाइडर खाता पंजीकृत नहीं है। यदि आप ग्राहक हैं तो ग्राहक ऐप का उपयोग करें, या नया रजिस्ट्रेशन करें।',
          ));
          return;
        }

        _startWatchingProfile(profile.id);

        if (profile.status == ProviderAccountStatus.blocked || profile.status == ProviderAccountStatus.suspended) {
          emit(ProviderAccountBlockedState(
            reason: profile.rejectionReason ?? 'Account is blocked or suspended.',
          ));
          WebHostBridge.notify('PROVIDER_READY');
          return;
        }

        // Resume Incomplete/Draft Registration directly upon login
        if (_isProfileIncomplete(profile)) {
          emit(ProviderProfileIncomplete(profile));
          WebHostBridge.notify('PROVIDER_READY');
          return;
        }

        // Store provider role in local namespace
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('provider_active_uid', profile.id);
          await prefs.setString('provider_active_role', 'provider');
        } catch (_) {}

        emit(ProviderAuthenticated(profile));
        WebHostBridge.notify('PROVIDER_READY');
      } else {
        emit(const ProviderAuthError('Login failed. Please check your email and password.'));
      }
    } catch (e) {
      emit(ProviderAuthError(_formatAuthException(e)));
    }
  }

  Future<void> _onRegisterWithEmail(
    RegisterWithEmailEvent event,
    Emitter<ProviderAuthState> emit,
  ) async {
    emit(ProviderAuthLoading());
    try {
      final cleanEmail = event.email.trim().toLowerCase();
      final cleanPassword = event.password.trim();
      final cleanFullName = event.fullName.trim();
      final cleanPhoneNumber = event.phoneNumber.trim();

      final user = await providerRepository.registerWithEmail(
        email: cleanEmail,
        password: cleanPassword,
        fullName: cleanFullName,
        phoneNumber: cleanPhoneNumber,
      );

      if (user != null) {
        final profile = await providerRepository.getProfile(user.uid);
        if (profile != null) {
          emit(ProviderProfileIncomplete(profile));
        } else {
          add(CheckAuthStatusEvent());
        }
      } else {
        emit(const ProviderAuthError('रजिस्ट्रेशन करने में विफल।'));
      }
    } catch (e) {
      emit(ProviderAuthError(_formatAuthException(e)));
    }
  }

  Future<void> _onSendPasswordReset(
    SendPasswordResetEvent event,
    Emitter<ProviderAuthState> emit,
  ) async {
    emit(ProviderAuthLoading());
    try {
      await providerRepository.sendPasswordReset(event.email.trim());
      emit(ProviderPasswordResetSentState('पासवर्ड रीसेट लिंक आपके ईमेल (${event.email}) पर भेज दिया गया है।'));
    } catch (e) {
      emit(ProviderAuthError(_formatAuthException(e)));
    }
  }

  Future<void> _onSendEmailVerification(
    SendEmailVerificationEvent event,
    Emitter<ProviderAuthState> emit,
  ) async {
    try {
      await providerRepository.sendEmailVerification();
      emit(const ProviderEmailVerificationSentState('ईमेल सत्यापन लिंक सफलतापूर्वक भेज दिया गया है।'));
    } catch (e) {
      emit(ProviderAuthError(_formatAuthException(e)));
    }
  }

  Future<void> _onSignOut(
    SignOutEvent event,
    Emitter<ProviderAuthState> emit,
  ) async {
    WebHostBridge.notify('PROVIDER_LOGOUT_STARTED');
    emit(ProviderAuthLoading());
    try {
      _profileSubscription?.cancel();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('provider_active_uid');
        await prefs.remove('provider_active_role');
      } catch (_) {}
      await providerRepository.signOut();
      WebHostBridge.notify('PROVIDER_LOGOUT_SUCCESS');
      emit(ProviderUnauthenticated());
    } catch (e) {
      WebHostBridge.notify('PROVIDER_LOGOUT_ERROR');
      emit(ProviderAuthError(_formatAuthException(e)));
    }
  }

  @override
  Future<void> close() {
    _profileSubscription?.cancel();
    return super.close();
  }

  Future<void> _onLoadProfile(
    LoadProviderProfileEvent event,
    Emitter<ProviderAuthState> emit,
  ) async {
    emit(ProviderAuthLoading());
    try {
      final profile = await providerRepository.getProfile(event.providerId);
      if (profile != null) {
        if (profile.status == ProviderAccountStatus.blocked) {
          emit(ProviderAccountBlockedState(reason: profile.rejectionReason ?? 'अकाउंट ब्लॉक है'));
        } else {
          emit(ProviderAuthenticated(profile));
        }
      } else {
        emit(const ProviderAuthError('प्रोफाइल नहीं मिली।'));
      }
    } catch (e) {
      emit(ProviderAuthError(_formatAuthException(e)));
    }
  }

  Future<void> _onUpdateProfile(
    UpdateProviderProfileEvent event,
    Emitter<ProviderAuthState> emit,
  ) async {
    emit(ProviderAuthLoading());
    try {
      final isApproved = event.profile.kycStatus == ProviderKycStatus.approved ||
                         event.profile.status == ProviderAccountStatus.approved;

      if (isApproved) {
        // Instant updates for approved providers: do NOT re-submit KYC or trigger admin approval
        final permittedMap = <String, dynamic>{
          'businessName': event.profile.businessName,
          'fullName': event.profile.fullName,
          'ownerName': event.profile.fullName,
          'businessDescription': event.profile.businessDescription,
          'businessType': event.profile.businessType,
          'visitingCharge': event.profile.visitingCharge,
          'experienceYears': event.profile.experienceYears,
          'workingHours': event.profile.workingHours,
          'jamuiArea': event.profile.jamuiArea,
          'area': event.profile.jamuiArea,
          'fullAddress': event.profile.fullAddress,
          'latitude': event.profile.latitude,
          'longitude': event.profile.longitude,
          'serviceRadiusKm': event.profile.serviceRadiusKm,
          'profileImageUrl': event.profile.profileImageUrl,
          'businessImageUrl': event.profile.businessImageUrl,
          'email': event.profile.email,
          'isAvailable': event.profile.isAvailable,
        };

        await providerRepository.updatePermittedProfileFields(
          providerId: event.profile.id,
          fields: permittedMap,
        );
        emit(ProviderAuthenticated(event.profile));
        emit(ProviderProfileUpdatedSuccessState(
          message: 'आपकी प्रोफाइल सफलतापूर्वक अपडेट हो गई!',
          profile: event.profile,
        ));
      } else {
        // Pending/Draft provider: submit profile and kyc
        await providerRepository.saveProfile(event.profile);
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('provider_active_uid', event.profile.id);
          await prefs.setString('provider_active_role', 'provider');
        } catch (_) {}
        emit(ProviderAuthenticated(event.profile));
        emit(ProviderKycSubmittedSuccess(
          message: 'आपका प्रोफाइल व सत्यापन विवरण (KYC) सफलतापूर्वक सबमिट हो गया है!',
          profile: event.profile,
        ));
      }
    } catch (e) {
      emit(ProviderAuthError('प्रोफाइल अपडेट करने में विफल: ${_formatAuthException(e)}'));
    }
  }

  Future<void> _onUpdatePermittedProfileFields(
    UpdatePermittedProfileFieldsEvent event,
    Emitter<ProviderAuthState> emit,
  ) async {
    emit(ProviderAuthLoading());
    try {
      await providerRepository.updatePermittedProfileFields(
        providerId: event.providerId,
        fields: event.updatedFields,
      );
      emit(ProviderAuthenticated(event.updatedProfile));
      emit(ProviderProfileUpdatedSuccessState(
        message: 'आपकी प्रोफाइल सफलतापूर्वक अपडेट हो गई!',
        profile: event.updatedProfile,
      ));
    } catch (e) {
      emit(ProviderAuthError('प्रोफाइल अपडेट करने में विफल: ${_formatAuthException(e)}'));
    }
  }

  Future<void> _onToggleAvailability(
    ToggleAvailabilityEvent event,
    Emitter<ProviderAuthState> emit,
  ) async {
    if (state is ProviderAuthenticated) {
      final current = (state as ProviderAuthenticated).profile;
      if (event.isAvailable && !current.isActive) {
        emit(const ProviderAuthError('एडमिन द्वारा आपका खाता निष्क्रिय किया गया है। आप ऑनलाइन नहीं हो सकते।'));
        return;
      }
      if (event.isAvailable && !current.hasPaidSubscription) {
        emit(const ProviderAuthError('ऑनलाइन होने हेतु सक्रिय पेड सब्सक्रिप्शन अनिवार्य है।'));
        return;
      }
      final updated = current.copyWith(isAvailable: event.isAvailable);
      emit(ProviderAuthenticated(updated));

      try {
        await providerRepository.updateAvailability(current.id, event.isAvailable);
      } catch (e) {
        emit(ProviderAuthenticated(current));
        emit(ProviderAuthError(_formatAuthException(e)));
      }
    }
  }

  Future<void> _onSubmitKyc(
    SubmitKycEvent event,
    Emitter<ProviderAuthState> emit,
  ) async {
    final current = state is ProviderAuthenticated
        ? (state as ProviderAuthenticated).profile
        : (state is ProviderProfileIncomplete ? (state as ProviderProfileIncomplete).profile : null);

    if (current != null) {
      final updated = current.copyWith(
        kycStatus: ProviderKycStatus.pendingReview,
        status: ProviderAccountStatus.pendingReview,
      );

      emit(ProviderAuthLoading());
      try {
        await providerRepository.submitKyc(
          providerId: current.id,
        );
        emit(ProviderAuthenticated(updated));
        emit(ProviderKycSubmittedSuccess(profile: updated));
      } catch (e) {
        emit(ProviderAuthError(_formatAuthException(e)));
      }
    }
  }

  Future<void> _onUploadProfilePhoto(
    UploadProfilePhotoEvent event,
    Emitter<ProviderAuthState> emit,
  ) async {
    if (state is ProviderAuthenticated) {
      final current = (state as ProviderAuthenticated).profile;
      emit(ProviderAuthLoading());
      try {
        final url = await providerRepository.uploadImage(
          providerId: current.id,
          imageFile: event.imageFile,
          folder: 'profile',
        );
        final updated = current.copyWith(profileImageUrl: url);
        await providerRepository.saveProfile(updated);
        emit(ProviderAuthenticated(updated));
      } catch (e) {
        emit(ProviderAuthError('फोटो अपलोड करने में विफलता: ${_formatAuthException(e)}'));
      }
    }
  }

  Future<void> _onSubmitCustomServiceApplication(
    SubmitCustomServiceApplicationEvent event,
    Emitter<ProviderAuthState> emit,
  ) async {
    emit(ProviderAuthLoading());
    try {
      await providerRepository.submitCustomServiceApplication(event.application);

      if (state is ProviderAuthenticated) {
        final current = (state as ProviderAuthenticated).profile;
        final updated = current.copyWith(
          isOtherService: true,
          customServiceStatus: 'pending_review',
          customServiceName: event.application.serviceName,
          customServiceDescription: event.application.serviceDescription,
          customServiceOffered: event.application.offeredServices,
          primaryCategoryTitle: event.application.serviceName,
          primaryCategoryId: 'custom_pending',
          kycStatus: ProviderKycStatus.pendingReview,
          status: ProviderAccountStatus.pendingReview,
        );
        emit(ProviderAuthenticated(updated));
      }

      emit(ProviderCustomServiceSubmittedSuccessState(
        application: event.application,
      ));
    } catch (e) {
      emit(ProviderAuthError('कस्टम सेवा आवेदन सबमिट करने में विफल: ${_formatAuthException(e)}'));
    }
  }

  Future<void> _onSubmitCategoryChangeRequest(
    SubmitCategoryChangeRequestEvent event,
    Emitter<ProviderAuthState> emit,
  ) async {
    emit(ProviderAuthLoading());
    try {
      await providerRepository.submitCategoryChangeRequest(
        providerId: event.providerId,
        requestedCategoryId: event.requestedCategoryId,
        requestedCategoryTitle: event.requestedCategoryTitle,
        customServiceDetails: event.customServiceDetails,
      );

      final freshProfile = await providerRepository.getProfile(event.providerId);
      if (freshProfile != null) {
        emit(ProviderProfileUpdatedSuccessState(
          message: 'श्रेणी परिवर्तन आवेदन सफलतापूर्वक सबमिट हुआ। एडमिन समीक्षा के बाद यह स्वीकृत होगा।',
          profile: freshProfile,
        ));
        emit(ProviderAuthenticated(freshProfile));
      } else if (state is ProviderAuthenticated) {
        final current = (state as ProviderAuthenticated).profile;
        final updated = current.copyWith(
          requestedCategoryId: event.requestedCategoryId,
          requestedCategoryTitle: event.requestedCategoryTitle,
          categoryApprovalStatus: 'pending_review',
          categoryRequestStatus: 'pending_review',
        );
        emit(ProviderProfileUpdatedSuccessState(
          message: 'श्रेणी परिवर्तन आवेदन सफलतापूर्वक सबमिट हुआ। एडमिन समीक्षा के बाद यह स्वीकृत होगा।',
          profile: updated,
        ));
        emit(ProviderAuthenticated(updated));
      }
    } catch (e) {
      emit(ProviderAuthError('श्रेणी परिवर्तन आवेदन सबमिट करने में विफल: ${_formatAuthException(e)}'));
    }
  }

  String _formatAuthException(dynamic e) {
    return AuthExceptionHandler.handleException(e);
  }
}
