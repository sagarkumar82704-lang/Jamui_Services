import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  Future<CustomerEntity?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (shouldThrowOnVerify) {
      throw Exception(verifyErrorMessage);
    }
    return mockCustomer;
  }

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
  }) async {
    if (shouldThrowOnVerify) {
      throw Exception(verifyErrorMessage);
    }
    return mockCustomer;
  }

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
  group('CustomerAuthBloc - Email/Password & Profile Routing Tests', () {
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
      SharedPreferences.setMockInitialValues({});
      repository = FakeCustomerAuthRepository();
      authBloc = CustomerAuthBloc(authRepository: repository);
    });

    tearDown(() {
      authBloc.close();
    });

    test('Initial state is CustomerAuthInitialState', () {
      expect(authBloc.state, isA<CustomerAuthInitialState>());
    });

    test('SignInWithEmailEvent emits CustomerAuthenticatedState on success', () async {
      repository.mockCustomer = testCustomer;

      final expectedStates = [
        isA<CustomerAuthLoadingState>(),
        isA<CustomerAuthLoadingState>(),
        isA<CustomerAuthenticatedState>()
            .having((s) => s.customer.fullName, 'customer.fullName', 'सागर कुमार')
            .having((s) => s.customer.email, 'customer.email', 'sagar@example.com'),
      ];

      expectLater(authBloc.stream, emitsInOrder(expectedStates));

      authBloc.add(const SignInWithEmailEvent(
        email: 'sagar@example.com',
        password: 'password123',
      ));
    });

    test('SignInWithEmailEvent emits CustomerAuthFailureState on failure', () async {
      repository.shouldThrowOnVerify = true;
      repository.verifyErrorMessage = 'गलत पासवर्ड दर्ज किया गया है।';

      final expectedStates = [
        isA<CustomerAuthLoadingState>(),
        isA<CustomerAuthFailureState>()
            .having((s) => s.errorMessage, 'errorMessage', contains('गलत पासवर्ड')),
      ];

      expectLater(authBloc.stream, emitsInOrder(expectedStates));

      authBloc.add(const SignInWithEmailEvent(
        email: 'sagar@example.com',
        password: 'wrong_password',
      ));
    });

    test('RegisterWithEmailEvent emits CustomerAuthenticatedState on successful registration', () async {
      repository.mockCustomer = testCustomer;

      final expectedStates = [
        isA<CustomerAuthLoadingState>(),
        isA<CustomerAuthenticatedState>()
            .having((s) => s.customer.fullName, 'customer.fullName', 'सागर कुमार'),
      ];

      expectLater(authBloc.stream, emitsInOrder(expectedStates));

      authBloc.add(const RegisterWithEmailEvent(
        email: 'sagar@example.com',
        password: 'password123',
        fullName: 'सागर कुमार',
        phoneNumber: '+919876543210',
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
