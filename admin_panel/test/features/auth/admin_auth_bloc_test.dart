import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_admin/features/auth/domain/entities/admin_user_entity.dart';
import 'package:apna_jamui_admin/features/auth/domain/repositories/admin_auth_repository.dart';
import 'package:apna_jamui_admin/features/auth/presentation/bloc/admin_auth_bloc.dart';
import 'package:apna_jamui_admin/features/auth/presentation/bloc/admin_auth_event.dart';
import 'package:apna_jamui_admin/features/auth/presentation/bloc/admin_auth_state.dart';

class MockAdminAuthRepository implements AdminAuthRepository {
  AdminUserEntity? currentAdmin;

  MockAdminAuthRepository({this.currentAdmin});

  @override
  Future<AdminUserEntity?> getCurrentAdmin() async => currentAdmin;

  @override
  Future<AdminUserEntity?> checkCurrentSession() async => currentAdmin;

  @override
  Future<AdminUserEntity> loginWithEmailPassword(String email, String password) async {
    return signIn(email, password);
  }

  @override
  Future<AdminUserEntity> signIn(String email, String password) async {
    if (email == 'admin@jamuiservice.com' && password == 'admin123') {
      currentAdmin = const AdminUserEntity(
        uid: 'test_admin_uid',
        email: 'admin@jamuiservice.com',
        name: 'Master Admin',
        role: AdminRole.superAdmin,
      );
      return currentAdmin!;
    }
    throw Exception('अमान्य ईमेल या पासवर्ड।');
  }

  @override
  Future<AdminUserEntity> registerAdmin({
    required String name,
    required String email,
    required String password,
    String role = 'super_admin',
  }) async {
    currentAdmin = AdminUserEntity(
      uid: 'new_admin_uid',
      email: email,
      name: name,
      role: AdminRole.superAdmin,
    );
    return currentAdmin!;
  }

  @override
  Future<void> logout() async => signOut();

  @override
  Future<void> signOut() async {
    currentAdmin = null;
  }

  @override
  Future<void> sendPasswordReset(String email) async => resetPassword(email);

  @override
  Future<void> resetPassword(String email) async {}
}

void main() {
  group('AdminAuthBloc Unit Tests', () {
    late MockAdminAuthRepository mockRepo;
    late AdminAuthBloc bloc;

    setUp(() {
      mockRepo = MockAdminAuthRepository();
      bloc = AdminAuthBloc(authRepository: mockRepo);
    });

    tearDown(() {
      bloc.close();
    });

    test('Initial state is AdminAuthInitial', () {
      expect(bloc.state, equals(AdminAuthInitial()));
    });

    test('CheckSessionEvent emits unauthenticated when no session exists', () async {
      final expected = [
        AdminAuthLoading(),
        AdminUnauthenticated(),
      ];

      expectLater(bloc.stream, emitsInOrder(expected));
      bloc.add(CheckSessionEvent());
    });

    test('LoginEvent emits authenticated on valid credentials', () async {
      bloc.add(const LoginEvent(
        email: 'admin@jamuiservice.com',
        password: 'admin123',
      ));

      await expectLater(
        bloc.stream,
        emitsThrough(
          predicate<AdminAuthState>((state) {
            return state is AdminAuthenticated &&
                state.adminUser.email == 'admin@jamuiservice.com' &&
                state.adminUser.role == AdminRole.superAdmin;
          }),
        ),
      );
    });

    test('LoginEvent emits error on invalid credentials', () async {
      bloc.add(const LoginEvent(
        email: 'wrong@apnajamui.com',
        password: 'wrong',
      ));

      await expectLater(
        bloc.stream,
        emitsThrough(
          predicate<AdminAuthState>((state) {
            return state is AdminAuthError && state.message.contains('अमान्य');
          }),
        ),
      );
    });
  });
}
