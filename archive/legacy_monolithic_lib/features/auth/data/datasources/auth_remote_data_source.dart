import '../models/user_model.dart';
import '../../domain/entities/user_entity.dart';

/// [AuthRemoteDataSource] रिमोट ऑथेंटिकेशन के लिए डेटा सोर्स इंटरफ़ेस है।
/// आज Firebase इसे इम्प्लीमेंट कर रहा है; कल हमारा Custom REST API इसे इम्प्लीमेंट करेगा।
abstract class AuthRemoteDataSource {
  Future<void> sendOtp({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(String error) onError,
  });

  Future<UserModel> verifyOtpAndSyncUser({
    required String verificationId,
    required String smsCode,
    required UserRole selectedRole,
  });

  Future<UserModel?> getCurrentUserModel();

  Future<void> signOut();
}
