import 'package:flutter_test/flutter_test.dart';
import '../../../archive/legacy_monolithic_lib/features/auth/domain/entities/user_entity.dart';
import '../../../archive/legacy_monolithic_lib/features/auth/domain/repositories/auth_repository.dart';
import '../../../archive/legacy_monolithic_lib/features/auth/presentation/bloc/auth_bloc.dart';
import '../../../archive/legacy_monolithic_lib/features/auth/presentation/bloc/auth_event.dart';
import '../../../archive/legacy_monolithic_lib/features/auth/presentation/bloc/auth_state.dart';

class MockAuthRepository implements AuthRepository {
  bool shouldFail = false;

  @override
  Future<void> sendOtp({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(String error) onError,
  }) async {
    if (shouldFail) {
      onError('OTP भेजने में विफलता');
    } else {
      onCodeSent('mock_verification_id_123', 12345);
    }
  }

  @override
  Future<UserEntity> verifyOtp({
    required String verificationId,
    required String smsCode,
    required UserRole selectedRole,
  }) async {
    if (shouldFail) {
      throw Exception('Invalid OTP');
    }
    return UserEntity(
      id: 'mock_uid_123',
      phone: '+919876543210',
      role: selectedRole,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<UserEntity?> getCurrentUser() async {
    return null;
  }

  @override
  Future<void> signOut() async {}
}

void main() {
  late MockAuthRepository mockRepo;
  late AuthBloc authBloc;

  setUp(() {
    mockRepo = MockAuthRepository();
    authBloc = AuthBloc(authRepository: mockRepo);
  });

  tearDown(() {
    authBloc.close();
  });

  group('AuthBloc Tests (Backend-Independent)', () {
    test('Initial state should be AuthInitial', () {
      expect(authBloc.state, equals(const AuthInitial()));
    });

    test('SendOtpEvent emits [AuthLoading, OtpSentState] on success', () async {
      expectLater(
        authBloc.stream,
        emitsInOrder([
          const AuthLoading(message: 'OTP भेजा जा रहा है...'),
          const OtpSentState(
            verificationId: 'mock_verification_id_123',
            phoneNumber: '9876543210',
            selectedRole: UserRole.customer,
            resendToken: 12345,
          ),
        ]),
      );

      authBloc.add(const SendOtpEvent(
        phoneNumber: 'Mobile Number',
        selectedRole: UserRole.customer,
      ));
    });

    test('VerifyOtpEvent emits [AuthLoading, AuthenticatedState] on success', () async {
      expectLater(
        authBloc.stream,
        emitsInOrder([
          const AuthLoading(message: 'OTP सत्यापित किया जा रहा है...'),
          predicate<AuthState>((state) {
            return state is AuthenticatedState &&
                state.user.id == 'mock_uid_123' &&
                state.user.role == UserRole.provider;
          }),
        ]),
      );

      authBloc.add(const VerifyOtpEvent(
        verificationId: 'mock_verification_id_123',
        smsCode: '123456',
        selectedRole: UserRole.provider,
      ));
    });
  });
}
