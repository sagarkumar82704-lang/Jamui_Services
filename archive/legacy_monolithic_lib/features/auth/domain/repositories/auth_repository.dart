import '../entities/user_entity.dart';

/// [AuthRepository] ऑथेंटिकेशन के लिए एक शुद्ध एब्सट्रैक्ट कॉन्ट्रैक्ट (Interface) है।
/// BLoC केवल इस इंटरफ़ेस से बात करता है।
abstract class AuthRepository {
  /// फोन नंबर पर OTP भेजें
  Future<void> sendOtp({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(String error) onError,
  });

  /// OTP सत्यापित करें और यूजर को लॉगिन करें
  Future<UserEntity> verifyOtp({
    required String verificationId,
    required String smsCode,
    required UserRole selectedRole,
  });

  /// वर्तमान लॉग-इन यूजर प्राप्त करें
  Future<UserEntity?> getCurrentUser();

  /// लॉगआउट करें
  Future<void> signOut();
}
