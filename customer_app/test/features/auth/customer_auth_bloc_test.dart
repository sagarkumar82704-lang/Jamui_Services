import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:apna_jamui_customer/features/auth/domain/entities/customer_entity.dart';
import 'package:apna_jamui_customer/features/auth/domain/repositories/customer_auth_repository.dart';
import 'package:apna_jamui_customer/features/auth/presentation/bloc/customer_auth_bloc.dart';
import 'package:apna_jamui_customer/features/auth/presentation/bloc/customer_auth_event.dart';
import 'package:apna_jamui_customer/features/auth/presentation/bloc/customer_auth_state.dart';

class FakeUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? phoneNumber;
  @override
  final String? email;

  FakeUser({
    required this.uid,
    this.phoneNumber,
    this.email,
  });
}

class FakeUserCredential extends Fake implements UserCredential {
  @override
  final User? user;

  FakeUserCredential({this.user});
}

class FakeCustomerAuthRepository implements CustomerAuthRepository {
  CustomerEntity? mockCustomer;
  Map<String, dynamic>? mockProvider;
  bool shouldThrowOnVerify = false;
  String verifyErrorMessage = 'Invalid OTP';
  bool signOutCalled = false;

  @override
  Future<CustomerEntity?> getCurrentCustomer() async => mockCustomer;

  @override
  Future<CustomerEntity?> getCustomerProfile(String uid) async => mockCustomer;

  @override
  Future<Map<String, dynamic>?> getProviderProfile(String uid) async => mockProvider;

  @override
  Future<void> sendPhoneOtp({
    required String phoneNumber,
    int? resendToken,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(String errorMessage) onError,
    required void Function(PhoneAuthCredential credential) onVerificationCompleted,
  }) async {
    onCodeSent('test_verification_id_123', resendToken ?? 999);
  }

  @override
  Future<UserCredential> verifyOtpCode({
    required String verificationId,
    required String smsCode,
  }) async {
    if (shouldThrowOnVerify) {
      throw Exception(verifyErrorMessage);
    }
    return FakeUserCredential(
      user: FakeUser(
        uid: 'test_uid_456',
        phoneNumber: '+919876543210',
      ),
    );
  }

  @override
  Future<UserCredential> signInWithPhoneCredential(PhoneAuthCredential credential) async {
    return FakeUserCredential(
      user: FakeUser(
        uid: 'test_uid_456',
        phoneNumber: '+919876543210',
      ),
    );
  }

  @override
  Future<CustomerEntity?> signInWithEmail({
    required String email,
    required String password,
  }) async => mockCustomer;

  @override
  Future<CustomerEntity?> registerWithEmail({
    required String email,
    required String password,
    required String fullName,
    String? phoneNumber,
    String? jamuiArea,
    String? address,
    double? latitude,
    double? longitude,
  }) async => mockCustomer;

  @override
  Future<void> linkEmailToCurrentAccount({
    required String email,
    required String password,
  }) async {}

  @override
  Future<int> migrateOldCustomerData({
    required String phoneNumber,
    required String newUid,
  }) async => 0;

  @override
  bool isCurrentAccountPhoneOnly() => false;

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> saveCustomerProfile(CustomerEntity customer) async {
    mockCustomer = customer;
  }

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }
}

void main() {
  group('CustomerAuthBloc - Phone OTP & Dual Profile Routing Tests', () {
    late FakeCustomerAuthRepository repository;
    late CustomerAuthBloc authBloc;

    final testCustomer = CustomerEntity(
      id: 'test_uid_456',
      fullName: 'सागर कुमार',
      email: 'sagar@example.com',
      phoneNumber: '+919876543210',
      jamuiArea: 'जमुई स्टेशन रोड',
      address: 'स्टेशन रोड, जमुई, बिहार',
      createdAt: DateTime.now(),
    );

    setUp(() {
      repository = FakeCustomerAuthRepository();
      authBloc = CustomerAuthBloc(authRepository: repository);
    });

    tearDown(() {
      authBloc.close();
    });

    test('Initial state is CustomerAuthInitialState', () {
      expect(authBloc.state, isA<CustomerAuthInitialState>());
    });

    test('SendCustomerPhoneOtpEvent triggers CustomerOtpSentState', () async {
      final expectedStates = [
        isA<CustomerAuthLoadingState>(),
        isA<CustomerOtpSentState>()
            .having((s) => s.verificationId, 'verificationId', 'test_verification_id_123')
            .having((s) => s.phoneNumber, 'phoneNumber', '+919876543210'),
      ];

      expectLater(authBloc.stream, emitsInOrder(expectedStates));

      authBloc.add(const SendCustomerPhoneOtpEvent('+919876543210'));
    });

    test('VerifyCustomerPhoneOtpEvent routes to CustomerAuthenticatedState when user has BOTH profiles (Strict Separation)', () async {
      repository.mockCustomer = testCustomer;
      repository.mockProvider = {
        'id': 'test_uid_456',
        'businessName': 'सागर इलेक्ट्रॉनिक्स',
        'status': 'approved',
        'isVerified': true,
      };

      // Even if provider profile exists, Customer App MUST route to CustomerAuthenticatedState
      final expectedStates = [
        isA<CustomerAuthLoadingState>(),
        isA<CustomerAuthLoadingState>(),
        isA<CustomerAuthenticatedState>()
            .having((s) => s.customer.fullName, 'customer.fullName', 'सागर कुमार'),
      ];

      expectLater(authBloc.stream, emitsInOrder(expectedStates));

      authBloc.add(const VerifyCustomerPhoneOtpEvent(
        verificationId: 'test_verification_id_123',
        smsCode: '123456',
      ));
    });

    test('VerifyCustomerPhoneOtpEvent routes to CustomerAuthenticatedState when user has CUSTOMER profile only', () async {
      repository.mockCustomer = testCustomer;
      repository.mockProvider = null;

      final expectedStates = [
        isA<CustomerAuthLoadingState>(),
        isA<CustomerAuthLoadingState>(),
        isA<CustomerAuthenticatedState>()
            .having((s) => s.customer.fullName, 'customer.fullName', 'सागर कुमार'),
      ];

      expectLater(authBloc.stream, emitsInOrder(expectedStates));

      authBloc.add(const VerifyCustomerPhoneOtpEvent(
        verificationId: 'test_verification_id_123',
        smsCode: '123456',
      ));
    });

    test('VerifyCustomerPhoneOtpEvent routes to CustomerProfileSetupRequiredState with null email when user is PROVIDER only (Never hijacks or leaks email)', () async {
      repository.mockCustomer = null;
      repository.mockProvider = {
        'id': 'test_uid_456',
        'businessName': 'जमुई प्लंबिंग सर्विसेज',
        'email': 'provider@plumbing.com',
        'status': 'approved',
        'isVerified': true,
      };

      // In Customer App, if no customer doc exists, user must set up customer profile.
      // Provider email is strictly NOT leaked!
      final expectedStates = [
        isA<CustomerAuthLoadingState>(),
        isA<CustomerAuthLoadingState>(),
        isA<CustomerProfileSetupRequiredState>()
            .having((s) => s.userId, 'userId', 'test_uid_456')
            .having((s) => s.email, 'email', isNull),
      ];

      expectLater(authBloc.stream, emitsInOrder(expectedStates));

      authBloc.add(const VerifyCustomerPhoneOtpEvent(
        verificationId: 'test_verification_id_123',
        smsCode: '123456',
      ));
    });

    test('VerifyCustomerPhoneOtpEvent routes to CustomerProfileSetupRequiredState when neither profile exists', () async {
      repository.mockCustomer = null;
      repository.mockProvider = null;

      final expectedStates = [
        isA<CustomerAuthLoadingState>(),
        isA<CustomerAuthLoadingState>(),
        isA<CustomerProfileSetupRequiredState>()
            .having((s) => s.userId, 'userId', 'test_uid_456'),
      ];

      expectLater(authBloc.stream, emitsInOrder(expectedStates));

      authBloc.add(const VerifyCustomerPhoneOtpEvent(
        verificationId: 'test_verification_id_123',
        smsCode: '123456',
      ));
    });

    test('VerifyCustomerPhoneOtpEvent emits CustomerAuthFailureState on wrong OTP', () async {
      repository.shouldThrowOnVerify = true;
      repository.verifyErrorMessage = 'दर्ज किया गया OTP कोड गलत है';

      final expectedStates = [
        isA<CustomerAuthLoadingState>(),
        isA<CustomerAuthFailureState>()
            .having((s) => s.errorMessage, 'errorMessage', contains('गलत है')),
      ];

      expectLater(authBloc.stream, emitsInOrder(expectedStates));

      authBloc.add(const VerifyCustomerPhoneOtpEvent(
        verificationId: 'test_verification_id_123',
        smsCode: '000000',
      ));
    });

    test('CustomerSignOutEvent signs out and emits CustomerUnauthenticatedState', () async {
      expectLater(
        authBloc.stream,
        emitsInOrder([isA<CustomerUnauthenticatedState>()]),
      );

      authBloc.add(const CustomerSignOutEvent());
      await pumpEventQueue();
      expect(repository.signOutCalled, isTrue);
    });
  });
}
