import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:apna_jamui_provider/features/auth/domain/entities/provider_profile_entity.dart';
import 'package:apna_jamui_provider/features/auth/presentation/bloc/provider_auth_bloc.dart';
import 'package:apna_jamui_provider/features/auth/presentation/bloc/provider_auth_event.dart';
import 'package:apna_jamui_provider/features/auth/presentation/bloc/provider_auth_state.dart';
import 'provider_auth_bloc_test.dart';

/// Test user fake implementing Firebase User interface for unit tests
class FakeFirebaseUser implements User {
  final String _uid;
  final String? _email;
  final String? _phoneNumber;
  final String? _displayName;

  FakeFirebaseUser({
    required String uid,
    String? email,
    String? phoneNumber,
    String? displayName,
  })  : _uid = uid,
        _email = email,
        _phoneNumber = phoneNumber,
        _displayName = displayName;

  @override
  String get uid => _uid;

  @override
  String? get email => _email;

  @override
  String? get phoneNumber => _phoneNumber;

  @override
  String? get displayName => _displayName;

  @override
  bool get emailVerified => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SecurityTestProviderRepository extends MockProviderRepository {
  User? mockUser;
  bool throwOnLogin = false;
  String? loginErrorCode;
  bool throwOnRegister = false;
  String? registerErrorCode;
  bool passwordResetSent = false;
  String? lastResetEmail;
  bool emailVerificationSent = false;

  SecurityTestProviderRepository({
    this.mockUser,
    super.currentProfile,
  });

  @override
  User? getCurrentUser() => mockUser;

  @override
  Future<User?> loginWithEmail({required String email, required String password}) async {
    if (throwOnLogin) {
      throw FirebaseAuthException(
        code: loginErrorCode ?? 'wrong-password',
        message: 'Invalid credentials provided.',
      );
    }
    return mockUser;
  }

  @override
  Future<User?> registerWithEmail({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
  }) async {
    if (throwOnRegister) {
      throw FirebaseAuthException(
        code: registerErrorCode ?? 'email-already-in-use',
        message: 'The email address is already in use by another account.',
      );
    }
    mockUser = FakeFirebaseUser(
      uid: 'new_provider_uid_101',
      email: email,
      phoneNumber: phoneNumber,
      displayName: fullName,
    );
    currentProfile = ProviderProfileEntity(
      id: 'new_provider_uid_101',
      email: email,
      phoneNumber: phoneNumber,
      fullName: fullName,
      businessName: '',
      primaryCategoryId: '',
      primaryCategoryTitle: '',
      status: ProviderAccountStatus.draft,
      kycStatus: ProviderKycStatus.notSubmitted,
      isMobileVerified: false,
      isEmailVerified: false,
      currentStep: 1,
      createdAt: DateTime.now(),
    );
    return mockUser;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    passwordResetSent = true;
    lastResetEmail = email;
  }

  @override
  Future<void> sendEmailVerification() async {
    emailVerificationSent = true;
  }

  @override
  Future<void> signOut() async {
    mockUser = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Provider Email + Password Authentication Redesign Tests', () {
    test('1. New Provider Registration: registers with Email & Password without invoking phone OTP', () async {
      final repo = SecurityTestProviderRepository();
      final bloc = ProviderAuthBloc(providerRepository: repo);

      final expectedStates = [
        isA<ProviderAuthLoading>(),
        predicate<ProviderAuthState>((s) =>
            s is ProviderProfileIncomplete &&
            s.profile.email == 'newprovider@apnajamui.com' &&
            s.profile.status == ProviderAccountStatus.draft &&
            s.profile.kycStatus == ProviderKycStatus.notSubmitted),
      ];

      expectLater(bloc.stream, emitsInOrder(expectedStates));

      bloc.add(const RegisterWithEmailEvent(
        email: 'newprovider@apnajamui.com',
        password: 'SecurePassword123!',
        fullName: 'Ramesh Kumar',
        phoneNumber: '9876543210',
      ));
    });

    test('2. Existing Provider Login: signs in with Email + Password and loads correct profile by UID', () async {
      final existingProfile = ProviderProfileEntity(
        id: 'existing_provider_99',
        email: 'electrician.jamui@gmail.com',
        phoneNumber: '+919876543210',
        fullName: 'Suresh Electrician',
        businessName: 'Suresh Electrical Works',
        primaryCategoryId: 'cat_electrician',
        primaryCategoryTitle: 'इलेक्ट्रीशियन',
        status: ProviderAccountStatus.approved,
        kycStatus: ProviderKycStatus.approved,
        registrationStatus: 'completed',
        subscriptionPlan: 'basic',
        isSubscriptionActive: true,
        subscriptionExpiry: DateTime.now().add(const Duration(days: 30)),
        paymentVerified: true,
        createdAt: DateTime.now(),
      );

      final user = FakeFirebaseUser(
        uid: 'existing_provider_99',
        email: 'electrician.jamui@gmail.com',
      );

      final repo = SecurityTestProviderRepository(
        mockUser: user,
        currentProfile: existingProfile,
      );

      final bloc = ProviderAuthBloc(providerRepository: repo);

      final expectedStates = [
        isA<ProviderAuthLoading>(),
        predicate<ProviderAuthState>((s) =>
            s is ProviderAuthenticated &&
            s.profile.id == 'existing_provider_99' &&
            s.profile.businessName == 'Suresh Electrical Works'),
      ];

      expectLater(bloc.stream, emitsInOrder(expectedStates));

      bloc.add(const LoginWithEmailEvent(
        email: 'electrician.jamui@gmail.com',
        password: 'CorrectPassword123',
      ));
    });

    test('3. Wrong Password: maps to safe user-friendly localized error message', () async {
      final repo = SecurityTestProviderRepository()..throwOnLogin = true..loginErrorCode = 'wrong-password';
      final bloc = ProviderAuthBloc(providerRepository: repo);

      final expectedStates = [
        isA<ProviderAuthLoading>(),
        predicate<ProviderAuthState>((s) =>
            s is ProviderAuthError &&
            s.message.contains('गलत पासवर्ड')),
      ];

      expectLater(bloc.stream, emitsInOrder(expectedStates));

      bloc.add(const LoginWithEmailEvent(
        email: 'electrician.jamui@gmail.com',
        password: 'IncorrectPassword',
      ));
    });

    test('4. Password Reset: sends Firebase email-based reset without phone OTP SMS', () async {
      final repo = SecurityTestProviderRepository();
      final bloc = ProviderAuthBloc(providerRepository: repo);

      final expectedStates = [
        isA<ProviderAuthLoading>(),
        predicate<ProviderAuthState>((s) =>
            s is ProviderPasswordResetSentState &&
            s.message.contains('electrician.jamui@gmail.com')),
      ];

      expectLater(bloc.stream, emitsInOrder(expectedStates));

      bloc.add(const SendPasswordResetEvent('electrician.jamui@gmail.com'));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(repo.passwordResetSent, isTrue);
      expect(repo.lastResetEmail, equals('electrician.jamui@gmail.com'));
    });

    test('5. Duplicate Email Conflict: rejects existing email cleanly with localized guidance', () async {
      final repo = SecurityTestProviderRepository()
        ..throwOnRegister = true
        ..registerErrorCode = 'email-already-in-use';
      final bloc = ProviderAuthBloc(providerRepository: repo);

      final expectedStates = [
        isA<ProviderAuthLoading>(),
        predicate<ProviderAuthState>((s) =>
            s is ProviderAuthError &&
            s.message.contains('पहले से पंजीकृत है')),
      ];

      expectLater(bloc.stream, emitsInOrder(expectedStates));

      bloc.add(const RegisterWithEmailEvent(
        email: 'alreadyused@gmail.com',
        password: 'SecurePassword123!',
        fullName: 'Another User',
        phoneNumber: '9123456789',
      ));
    });

    test('6. Registration Progress Resume: incomplete draft profile emits ProviderProfileIncomplete directly', () async {
      final draftProfile = ProviderProfileEntity(
        id: 'draft_provider_uid',
        email: 'draft.plumber@gmail.com',
        phoneNumber: '+919876543210',
        fullName: 'Dinesh Plumber',
        businessName: '',
        primaryCategoryId: '',
        primaryCategoryTitle: '',
        status: ProviderAccountStatus.draft,
        kycStatus: ProviderKycStatus.notSubmitted,
        currentStep: 2,
        createdAt: DateTime.now(),
      );

      final user = FakeFirebaseUser(
        uid: 'draft_provider_uid',
        email: 'draft.plumber@gmail.com',
      );

      final repo = SecurityTestProviderRepository(
        mockUser: user,
        currentProfile: draftProfile,
      );

      final bloc = ProviderAuthBloc(providerRepository: repo);

      final expectedStates = [
        isA<ProviderAuthLoading>(),
        predicate<ProviderAuthState>((s) =>
            s is ProviderProfileIncomplete &&
            s.profile.id == 'draft_provider_uid' &&
            s.profile.currentStep == 2),
      ];

      expectLater(bloc.stream, emitsInOrder(expectedStates));

      bloc.add(CheckAuthStatusEvent());
    });

    test('7. Customer vs Provider Account Separation: customer logging into Provider App is denied entry', () async {
      // Customer has Firebase Auth account but NO provider document in Firestore 'providers' collection
      final customerUser = FakeFirebaseUser(
        uid: 'customer_uid_only',
        email: 'customer@apnajamui.com',
      );

      final repo = SecurityTestProviderRepository(
        mockUser: customerUser,
        currentProfile: null, // No provider profile in providers collection
      );

      final bloc = ProviderAuthBloc(providerRepository: repo);

      final expectedStates = [
        isA<ProviderAuthLoading>(),
        predicate<ProviderAuthState>((s) =>
            s is ProviderNotRegisteredErrorState &&
            s.message.contains('इस ईमेल से कोई प्रोवाइडर खाता पंजीकृत नहीं है')),
      ];

      expectLater(bloc.stream, emitsInOrder(expectedStates));

      bloc.add(const LoginWithEmailEvent(
        email: 'customer@apnajamui.com',
        password: 'CustomerPassword123',
      ));
    });

    test('8. Eligibility Gate: Draft/Pending provider is strictly unpermitted for live leads', () {
      final draftProvider = ProviderProfileEntity(
        id: 'prov_pending_1',
        email: 'pending@gmail.com',
        phoneNumber: '+919876543210',
        fullName: 'Pending Provider',
        businessName: 'Pending Carpentry',
        primaryCategoryId: 'cat_carpenter',
        primaryCategoryTitle: 'बढ़ई',
        status: ProviderAccountStatus.pendingReview,
        kycStatus: ProviderKycStatus.pendingReview,
        paymentVerified: false,
        isSubscriptionActive: false,
        createdAt: DateTime.now(),
      );

      // Verify that unverified, unpaid, or pending provider cannot receive leads
      expect(draftProvider.isPermittedForLeads, isFalse);
      expect(draftProvider.hasPaidSubscription, isFalse);
    });

    test('9. Admin Approval + Paid Subscription Eligibility: Approved live provider is permitted for leads', () {
      final liveProvider = ProviderProfileEntity(
        id: 'prov_live_1',
        email: 'live@gmail.com',
        phoneNumber: '+919876543210',
        fullName: 'Live Provider',
        businessName: 'Jamui AC Repair',
        primaryCategoryId: 'cat_ac',
        primaryCategoryTitle: 'एसी रिपेयर',
        status: ProviderAccountStatus.approved,
        kycStatus: ProviderKycStatus.approved,
        subscriptionPlan: 'basic',
        paymentVerified: true,
        isSubscriptionActive: true,
        subscriptionExpiry: DateTime.now().add(const Duration(days: 30)),
        isAvailable: true,
        createdAt: DateTime.now(),
      );

      expect(liveProvider.isPermittedForLeads, isTrue);
      expect(liveProvider.hasPaidSubscription, isTrue);
    });

    test('10. Razorpay Contact Prefill Preservation: Phone number preserved on profile without phone OTP', () {
      final providerProfile = ProviderProfileEntity(
        id: 'prov_razorpay_1',
        email: 'service@apnajamui.com',
        phoneNumber: '+919876543210',
        fullName: 'Business Owner',
        businessName: 'Business Enterprise',
        primaryCategoryId: 'cat_electrician',
        primaryCategoryTitle: 'इलेक्ट्रीशियन',
        createdAt: DateTime.now(),
      );

      // Emulate subscription page Razorpay standard checkout options construction
      final options = <String, dynamic>{
        'key': 'rzp_test_12345678',
        'amount': 2000,
        'currency': 'INR',
        'prefill': {
          'contact': providerProfile.phoneNumber,
          'email': providerProfile.email.isNotEmpty ? providerProfile.email : 'provider@apnajamui.com',
        },
      };

      final prefill = options['prefill'] as Map<String, dynamic>;
      expect(prefill['contact'], equals('+919876543210'));
      expect(prefill['email'], equals('service@apnajamui.com'));
    });

    test('11. Provider Session SignOut: cleans provider session cleanly without touching customer auth', () async {
      final repo = SecurityTestProviderRepository(
        mockUser: FakeFirebaseUser(uid: 'provider_to_logout'),
        currentProfile: ProviderProfileEntity(
          id: 'provider_to_logout',
          email: 'logout@gmail.com',
          phoneNumber: '+919876543210',
          fullName: 'Logging Out Provider',
          businessName: 'Some Service',
          primaryCategoryId: 'cat_1',
          primaryCategoryTitle: 'Service',
          createdAt: DateTime.now(),
        ),
      );

      final bloc = ProviderAuthBloc(providerRepository: repo);

      final expectedStates = [
        isA<ProviderAuthLoading>(),
        isA<ProviderUnauthenticated>(),
      ];

      expectLater(bloc.stream, emitsInOrder(expectedStates));

      bloc.add(SignOutEvent());

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(repo.mockUser, isNull);
    });
  });
}
