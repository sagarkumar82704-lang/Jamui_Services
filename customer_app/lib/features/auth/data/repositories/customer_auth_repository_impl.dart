import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/customer_entity.dart';
import '../../domain/repositories/customer_auth_repository.dart';
import '../datasources/firebase_customer_auth_remote_data_source.dart';
import '../models/customer_model.dart';

class CustomerAuthRepositoryImpl implements CustomerAuthRepository {
  final FirebaseCustomerAuthRemoteDataSource remoteDataSource;

  CustomerAuthRepositoryImpl({required this.remoteDataSource});

  @override
  Future<CustomerEntity?> getCurrentCustomer() async {
    return await remoteDataSource.getCurrentCustomerProfile();
  }

  @override
  Future<CustomerEntity?> getCustomerProfile(String uid) async {
    return await remoteDataSource.getCustomerProfile(uid);
  }

  @override
  Future<Map<String, dynamic>?> getProviderProfile(String uid) async {
    return await remoteDataSource.getProviderProfile(uid);
  }

  @override
  Future<void> sendPhoneOtp({
    required String phoneNumber,
    int? resendToken,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(String errorMessage) onError,
    required void Function(PhoneAuthCredential credential) onVerificationCompleted,
  }) async {
    await remoteDataSource.sendPhoneOtp(
      phoneNumber: phoneNumber,
      resendToken: resendToken,
      onCodeSent: onCodeSent,
      onError: onError,
      onVerificationCompleted: onVerificationCompleted,
    );
  }

  @override
  Future<UserCredential> verifyOtpCode({
    required String verificationId,
    required String smsCode,
  }) async {
    return await remoteDataSource.verifyOtpCode(
      verificationId: verificationId,
      smsCode: smsCode,
    );
  }

  @override
  Future<UserCredential> signInWithPhoneCredential(PhoneAuthCredential credential) async {
    return await remoteDataSource.signInWithPhoneCredential(credential);
  }

  @override
  Future<CustomerEntity?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final userCred = await remoteDataSource.signInWithEmail(
      email: email,
      password: password,
    );
    if (userCred.user != null) {
      return await remoteDataSource.getCurrentCustomerProfile();
    }
    return null;
  }

  @override
  Future<CustomerEntity?> registerWithEmail({
    required String email,
    required String password,
    required String fullName,
    String? phoneNumber,
    String? jamuiArea,
    String? address,
    double? latitude,
    double? longitude,
  }) async {
    final userCred = await remoteDataSource.registerWithEmail(
      email: email,
      password: password,
      fullName: fullName,
      phoneNumber: phoneNumber,
      jamuiArea: jamuiArea,
      address: address,
      latitude: latitude,
      longitude: longitude,
    );
    if (userCred.user != null) {
      return await remoteDataSource.getCurrentCustomerProfile();
    }
    return null;
  }

  @override
  Future<void> linkEmailToCurrentAccount({
    required String email,
    required String password,
  }) async {
    await remoteDataSource.linkEmailToCurrentAccount(
      email: email,
      password: password,
    );
  }

  @override
  Future<int> migrateOldCustomerData({
    required String phoneNumber,
    required String newUid,
  }) async {
    return await remoteDataSource.migrateOldCustomerData(
      phoneNumber: phoneNumber,
      newUid: newUid,
    );
  }

  @override
  bool isCurrentAccountPhoneOnly() {
    return remoteDataSource.isCurrentAccountPhoneOnly();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await remoteDataSource.sendPasswordResetEmail(email);
  }

  @override
  Future<void> saveCustomerProfile(CustomerEntity customer) async {
    final model = CustomerModel(
      id: customer.id,
      phoneNumber: customer.phoneNumber,
      fullName: customer.fullName,
      email: customer.email,
      jamuiArea: customer.jamuiArea,
      address: customer.address,
      latitude: customer.latitude,
      longitude: customer.longitude,
      createdAt: customer.createdAt,
      updatedAt: DateTime.now(),
    );
    await remoteDataSource.saveCustomerProfile(model);
  }

  @override
  Future<void> signOut() async {
    await remoteDataSource.signOut();
  }
}

