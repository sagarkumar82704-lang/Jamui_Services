import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:apna_jamui_admin/features/auth/presentation/pages/login_page.dart';
import 'package:apna_jamui_admin/features/auth/presentation/bloc/admin_auth_bloc.dart';
import 'package:apna_jamui_admin/features/auth/domain/entities/admin_user_entity.dart';
import 'package:apna_jamui_admin/features/auth/domain/repositories/admin_auth_repository.dart';

class MockAdminAuthRepo implements AdminAuthRepository {
  AdminUserEntity? currentAdmin;

  @override
  Future<AdminUserEntity?> getCurrentAdmin() async => currentAdmin;

  @override
  Future<AdminUserEntity?> checkCurrentSession() async => currentAdmin;

  @override
  Future<AdminUserEntity> loginWithEmailPassword(String email, String password) async => signIn(email, password);

  @override
  Future<AdminUserEntity> signIn(String email, String password) async {
    return const AdminUserEntity(
      uid: 'test_admin_uid',
      email: 'admin@jamuiservice.com',
      name: 'Master Admin',
      role: AdminRole.superAdmin,
    );
  }

  @override
  Future<AdminUserEntity> registerAdmin({
    required String name,
    required String email,
    required String password,
    String role = 'super_admin',
  }) async {
    return AdminUserEntity(
      uid: 'new_admin_uid',
      email: email,
      name: name,
      role: AdminRole.superAdmin,
    );
  }

  @override
  Future<void> logout() async => signOut();

  @override
  Future<void> signOut() async {}

  @override
  Future<void> sendPasswordReset(String email) async => resetPassword(email);

  @override
  Future<void> resetPassword(String email) async {}
}

void main() {
  testWidgets('Admin portal renders login screen smoke test', (WidgetTester tester) async {
    final mockRepo = MockAdminAuthRepo();
    final bloc = AdminAuthBloc(authRepository: mockRepo);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<AdminAuthBloc>.value(
          value: bloc,
          child: const LoginPage(),
        ),
      ),
    );

    expect(find.text('JAMUI SERVICE'), findsOneWidget);
    expect(find.text('Master Administration Portal'), findsOneWidget);
    expect(find.text('Admin Email'), findsOneWidget);
  });
}
