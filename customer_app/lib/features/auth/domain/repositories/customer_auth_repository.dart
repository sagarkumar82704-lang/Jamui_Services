import 'package:firebase_auth/firebase_auth.dart';
import '../entities/customer_entity.dart';

abstract class CustomerAuthRepository {
  Future<CustomerEntity?> getCurrentCustomer();
  Future<CustomerEntity?> getCustomerProfile(String uid);
  Future<Map<String, dynamic>?> getProviderProfile(String uid);

  Future<void> sendPhoneOtp({
    required String phoneNumber,
    int? resendToken,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(String errorMessage) onError,
    required void Function(PhoneAuthCredential credential) onVerificationCompleted,
  });

  Future<UserCredential> verifyOtpCode({
    required String verificationId,
    required String smsCode,
  });

  Future<UserCredential> signInWithPhoneCredential(PhoneAuthCredential credential);

  Future<CustomerEntity?> signInWithEmail({
    required String email,
    required String password,
  });

  Future<CustomerEntity?> registerWithEmail({
    required String email,
    required String password,
    required String fullName,
    String? phoneNumber,
    String? jamuiArea,
    String? address,
    double? latitude,
    double? longitude,
  });

  Future<void> linkEmailToCurrentAccount({
    required String email,
    required String password,
  });

  Future<int> migrateOldCustomerData({
    required String phoneNumber,
    required String newUid,
  });

  bool isCurrentAccountPhoneOnly();

  Future<void> sendPasswordResetEmail(String email);
  Future<void> saveCustomerProfile(CustomerEntity customer);
  Future<void> signOut();
}


