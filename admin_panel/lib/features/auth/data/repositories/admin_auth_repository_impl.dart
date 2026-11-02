import '../../domain/entities/admin_user_entity.dart';
import '../../domain/repositories/admin_auth_repository.dart';
import '../datasources/admin_auth_remote_data_source.dart';

class AdminAuthRepositoryImpl implements AdminAuthRepository {
  final AdminAuthRemoteDataSource remoteDataSource;

  AdminAuthRepositoryImpl({required this.remoteDataSource});

  @override
  Future<AdminUserEntity?> getCurrentAdmin() async {
    return await remoteDataSource.checkCurrentSession();
  }

  @override
  Future<AdminUserEntity?> checkCurrentSession() async {
    return await remoteDataSource.checkCurrentSession();
  }

  @override
  Future<AdminUserEntity> loginWithEmailPassword(String email, String password) async {
    return await remoteDataSource.signIn(email, password);
  }

  @override
  Future<AdminUserEntity> signIn(String email, String password) async {
    return await remoteDataSource.signIn(email, password);
  }

  @override
  Future<AdminUserEntity> registerAdmin({
    required String name,
    required String email,
    required String password,
    String role = 'super_admin',
  }) async {
    return await remoteDataSource.registerAdmin(
      name: name,
      email: email,
      password: password,
      role: role,
    );
  }

  @override
  Future<void> logout() async {
    await remoteDataSource.signOut();
  }

  @override
  Future<void> signOut() async {
    await remoteDataSource.signOut();
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    await remoteDataSource.resetPassword(email);
  }

  @override
  Future<void> resetPassword(String email) async {
    await remoteDataSource.resetPassword(email);
  }
}
