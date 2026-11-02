import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import '../entities/provider_profile_entity.dart';
import '../entities/custom_service_application_entity.dart';

/// [ProviderRepository] — Provider Domain Repository Interface
abstract class ProviderRepository {
  // Auth Operations
  Future<User?> registerWithEmail({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
  });

  Future<User?> loginWithEmail({
    required String email,
    required String password,
  });

  Future<void> sendPasswordReset(String email);
  Future<void> sendEmailVerification();
  Future<void> signOut();
  User? getCurrentUser();

  // Credential Linking & Safe Migration
  Future<User> linkEmailPasswordCredential({
    required String email,
    required String password,
  });

  Future<ProviderProfileEntity> safeMigratePhoneAccount({
    required String providerId,
    required String email,
    required String password,
  });

  // Phone OTP
  Future<void> sendPhoneOtp({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(String errorMessage) onError,
    required void Function(PhoneAuthCredential credential) onVerificationCompleted,
  });

  Future<UserCredential> verifyOtpCode({
    required String verificationId,
    required String smsCode,
  });

  // Profile Operations
  Future<ProviderProfileEntity?> getProfile(String providerId);
  Future<ProviderProfileEntity?> findRegisteredProviderByPhone(String rawPhoneNumber);
  Future<ProviderProfileEntity?> findRegisteredProviderByEmail(String email);
  Stream<ProviderProfileEntity?> watchProfile(String providerId);
  Future<void> saveProfile(ProviderProfileEntity profile);
  Future<void> updatePermittedProfileFields({
    required String providerId,
    required Map<String, dynamic> fields,
  });
  Future<void> updateAvailability(String providerId, bool isAvailable);
  Future<void> submitKyc({
    required String providerId,
  });
  Future<void> incrementLeadCount({
    required String providerId,
    required bool isCall,
  });

  // Storage
  Future<String> uploadImage({
    required String providerId,
    required File imageFile,
    required String folder,
  });

  Future<String> uploadImageBytes({
    required String providerId,
    required Uint8List imageBytes,
    required String folder,
    String mimeType = 'image/jpeg',
  });

  // Custom Service (Other Service) Operations
  Future<void> submitCustomServiceApplication(CustomServiceApplicationEntity application);
  Stream<CustomServiceApplicationEntity?> watchCustomServiceApplication(String providerId);
  Future<CustomServiceApplicationEntity?> getCustomServiceApplication(String providerId);

  // Category Edit & Re-Apply Operations
  Future<void> submitCategoryChangeRequest({
    required String providerId,
    required String requestedCategoryId,
    required String requestedCategoryTitle,
    Map<String, dynamic>? customServiceDetails,
  });
}
