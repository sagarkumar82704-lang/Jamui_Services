import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

/// [AuthRepositoryImpl] डोमेन [AuthRepository] को लागू करता है।
/// यह [AuthRemoteDataSource] का उपयोग करता है जिससे यह किसी भी बैकएंड (Firebase या API) से आसानी से जुड़ सकता है।
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  const AuthRepositoryImpl({required this.remoteDataSource});

  @override
  Future<void> sendOtp({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(String error) onError,
  }) async {
    return await remoteDataSource.sendOtp(
      phoneNumber: phoneNumber,
      onCodeSent: onCodeSent,
      onError: onError,
    );
  }

  @override
  Future<UserEntity> verifyOtp({
    required String verificationId,
    required String smsCode,
    required UserRole selectedRole,
  }) async {
    final userModel = await remoteDataSource.verifyOtpAndSyncUser(
      verificationId: verificationId,
      smsCode: smsCode,
      selectedRole: selectedRole,
    );
    return userModel.toEntity();
  }

  @override
  Future<UserEntity?> getCurrentUser() async {
    final userModel = await remoteDataSource.getCurrentUserModel();
    return userModel?.toEntity();
  }

  @override
  Future<void> signOut() async {
    return await remoteDataSource.signOut();
  }
}
