import '../entities/admin_user_entity.dart';

abstract class AdminAuthRepository {
  Future<AdminUserEntity?> getCurrentAdmin();
  Future<AdminUserEntity?> checkCurrentSession();
  Future<AdminUserEntity> loginWithEmailPassword(String email, String password);
  Future<AdminUserEntity> signIn(String email, String password);
  Future<AdminUserEntity> registerAdmin({
    required String name,
    required String email,
    required String password,
    String role = 'super_admin',
  });
  Future<void> logout();
  Future<void> signOut();
  Future<void> sendPasswordReset(String email);
  Future<void> resetPassword(String email);
}
