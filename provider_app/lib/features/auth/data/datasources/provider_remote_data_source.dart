import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/provider_profile_model.dart';
import '../models/custom_service_application_model.dart';

abstract class ProviderRemoteDataSource {
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
  User? getCurrentFirebaseUser();

  // Firestore Profile Operations
  Future<ProviderProfileModel?> getProviderProfile(String id);
  Future<ProviderProfileModel?> findRegisteredProviderByPhone(String rawPhoneNumber);
  Future<ProviderProfileModel?> findRegisteredProviderByEmail(String email);
  Stream<ProviderProfileModel?> watchProviderProfile(String id);
  Future<void> saveProviderProfile(ProviderProfileModel profile);
  Future<void> updatePermittedProfileFields(String id, Map<String, dynamic> fields);
  Future<void> updateAvailability(String id, bool isAvailable);
  Future<void> updateKycStatus(String id, String status, {String? reason, String? aadhaarMasked});
  Future<void> incrementMetrics(String id, {bool isCall = false, bool isWhatsApp = false, bool isView = false});

  // Storage Operations
  Future<String> uploadProviderImage({
    required String providerId,
    required File imageFile,
    required String folder, // 'profile', 'business', 'work'
  });

  Future<String> uploadProviderImageBytes({
    required String providerId,
    required Uint8List imageBytes,
    required String folder,
    String mimeType = 'image/jpeg',
  });

  // Custom Service Operations
  Future<void> submitCustomServiceApplication(CustomServiceApplicationModel application);
  Stream<CustomServiceApplicationModel?> watchCustomServiceApplication(String providerId);
  Future<CustomServiceApplicationModel?> getCustomServiceApplication(String providerId);

  // Category Edit & Re-Apply Operations
  Future<void> submitCategoryChangeRequest({
    required String providerId,
    required String requestedCategoryId,
    required String requestedCategoryTitle,
    Map<String, dynamic>? customServiceDetails,
  });
}
