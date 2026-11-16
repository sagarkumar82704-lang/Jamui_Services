import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/provider_profile_entity.dart';
import '../../domain/entities/custom_service_application_entity.dart';
import '../../domain/repositories/provider_repository.dart';
import '../datasources/provider_remote_data_source.dart';
import '../models/provider_profile_model.dart';
import '../models/custom_service_application_model.dart';

class ProviderRepositoryImpl implements ProviderRepository {
  final ProviderRemoteDataSource remoteDataSource;

  ProviderRepositoryImpl({required this.remoteDataSource});

  @override
  User? getCurrentUser() {
    return remoteDataSource.getCurrentFirebaseUser();
  }

  @override
  Future<User?> registerWithEmail({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
  }) async {
    return await remoteDataSource.registerWithEmail(
      email: email,
      password: password,
      fullName: fullName,
      phoneNumber: phoneNumber,
    );
  }

  @override
  Future<User?> loginWithEmail({
    required String email,
    required String password,
  }) async {
    return await remoteDataSource.loginWithEmail(
      email: email,
      password: password,
    );
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    await remoteDataSource.sendPasswordReset(email);
  }

  @override
  Future<void> sendEmailVerification() async {
    await remoteDataSource.sendEmailVerification();
  }

  @override
  Future<void> signOut() async {
    await remoteDataSource.signOut();
  }

  @override
  Future<ProviderProfileEntity?> getProfile(String providerId) async {
    return await remoteDataSource.getProviderProfile(providerId);
  }

  @override
  Future<ProviderProfileEntity?> findRegisteredProviderByPhone(String rawPhoneNumber) async {
    return await remoteDataSource.findRegisteredProviderByPhone(rawPhoneNumber);
  }

  @override
  Future<ProviderProfileEntity?> findRegisteredProviderByEmail(String email) async {
    return await remoteDataSource.findRegisteredProviderByEmail(email);
  }

  @override
  Stream<ProviderProfileEntity?> watchProfile(String providerId) {
    return remoteDataSource.watchProviderProfile(providerId);
  }

  @override
  Future<void> saveProfile(ProviderProfileEntity profile) async {
    final model = ProviderProfileModel.fromEntity(profile);
    await remoteDataSource.saveProviderProfile(model);
  }

  @override
  Future<void> updatePermittedProfileFields({
    required String providerId,
    required Map<String, dynamic> fields,
  }) async {
    await remoteDataSource.updatePermittedProfileFields(providerId, fields);
  }

  @override
  Future<void> updateAvailability(String providerId, bool isAvailable) async {
    await remoteDataSource.updateAvailability(providerId, isAvailable);
  }

  @override
  Future<void> submitKyc({
    required String providerId,
  }) async {
    await remoteDataSource.updateKycStatus(
      providerId,
      ProviderKycStatus.pendingReview.name,
    );
  }

  @override
  Future<void> incrementLeadCount({
    required String providerId,
    required bool isCall,
  }) async {
    await remoteDataSource.incrementMetrics(
      providerId,
      isCall: isCall,
      isWhatsApp: !isCall,
    );
  }

  @override
  Future<String> uploadImage({
    required String providerId,
    required File imageFile,
    required String folder,
  }) async {
    return await remoteDataSource.uploadProviderImage(
      providerId: providerId,
      imageFile: imageFile,
      folder: folder,
    );
  }

  @override
  Future<String> uploadImageBytes({
    required String providerId,
    required Uint8List imageBytes,
    required String folder,
    String mimeType = 'image/jpeg',
  }) async {
    return await remoteDataSource.uploadProviderImageBytes(
      providerId: providerId,
      imageBytes: imageBytes,
      folder: folder,
      mimeType: mimeType,
    );
  }

  @override
  Future<void> submitCustomServiceApplication(CustomServiceApplicationEntity application) async {
    final model = CustomServiceApplicationModel(
      id: application.id,
      providerId: application.providerId,
      providerName: application.providerName,
      phoneNumber: application.phoneNumber,
      serviceName: application.serviceName,
      serviceDescription: application.serviceDescription,
      offeredServices: application.offeredServices,
      experienceYears: application.experienceYears,
      visitingCharge: application.visitingCharge,
      fullAddress: application.fullAddress,
      jamuiArea: application.jamuiArea,
      status: application.status,
      adminFeedback: application.adminFeedback,
      mappedCategoryId: application.mappedCategoryId,
      mappedCategoryTitle: application.mappedCategoryTitle,
      createdAt: application.createdAt,
      updatedAt: application.updatedAt,
      reviewedAt: application.reviewedAt,
      reviewedBy: application.reviewedBy,
    );
    await remoteDataSource.submitCustomServiceApplication(model);
  }

  @override
  Stream<CustomServiceApplicationEntity?> watchCustomServiceApplication(String providerId) {
    return remoteDataSource.watchCustomServiceApplication(providerId);
  }

  @override
  Future<CustomServiceApplicationEntity?> getCustomServiceApplication(String providerId) async {
    return await remoteDataSource.getCustomServiceApplication(providerId);
  }

  @override
  Future<void> submitCategoryChangeRequest({
    required String providerId,
    required String requestedCategoryId,
    required String requestedCategoryTitle,
    Map<String, dynamic>? customServiceDetails,
  }) async {
    await remoteDataSource.submitCategoryChangeRequest(
      providerId: providerId,
      requestedCategoryId: requestedCategoryId,
      requestedCategoryTitle: requestedCategoryTitle,
      customServiceDetails: customServiceDetails,
    );
  }
}
