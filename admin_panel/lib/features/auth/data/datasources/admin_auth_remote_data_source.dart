import '../models/admin_user_model.dart';

abstract class AdminAuthRemoteDataSource {
  Future<AdminUserModel?> checkCurrentSession();
  Future<AdminUserModel> signIn(String email, String password);
  Future<AdminUserModel> registerAdmin({
    required String name,
    required String email,
    required String password,
    String role = 'super_admin',
  });
  Future<void> signOut();
  Future<void> resetPassword(String email);
}
