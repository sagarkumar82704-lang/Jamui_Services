import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_provider/features/auth/domain/entities/provider_profile_entity.dart';
import 'package:apna_jamui_provider/features/auth/domain/entities/custom_service_application_entity.dart';
import 'package:apna_jamui_provider/features/auth/domain/repositories/provider_repository.dart';
import 'package:apna_jamui_provider/features/auth/presentation/bloc/provider_auth_bloc.dart';
import 'package:apna_jamui_provider/features/auth/presentation/bloc/provider_auth_event.dart';
import 'package:apna_jamui_provider/features/auth/presentation/bloc/provider_auth_state.dart';

class MockProviderRepository implements ProviderRepository {
  ProviderProfileEntity? currentProfile;

  MockProviderRepository({this.currentProfile});

  @override
  User? getCurrentUser() => null;

  @override
  Future<User?> loginWithEmail({required String email, required String password}) async => null;

  @override
  Future<User?> registerWithEmail({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
  }) async => null;

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<ProviderProfileEntity?> getProfile(String providerId) async {
    return currentProfile;
  }

  @override
  Future<ProviderProfileEntity?> findRegisteredProviderByPhone(String rawPhoneNumber) async {
    if (currentProfile != null && (currentProfile!.phoneNumber == rawPhoneNumber || rawPhoneNumber.contains(currentProfile!.phoneNumber.replaceAll('+91', '')))) {
      return currentProfile;
    }
    return null;
  }

  @override
  Future<ProviderProfileEntity?> findRegisteredProviderByEmail(String email) async {
    if (currentProfile != null && currentProfile!.email == email) {
      return currentProfile;
    }
    return null;
  }

  @override
  Stream<ProviderProfileEntity?> watchProfile(String providerId) {
    return Stream.value(currentProfile);
  }

  @override
  Future<void> saveProfile(ProviderProfileEntity profile) async {
    currentProfile = profile;
  }

  @override
  Future<void> updatePermittedProfileFields({
    required String providerId,
    required Map<String, dynamic> fields,
  }) async {
    if (currentProfile == null) {
      throw Exception('प्रोफाइल नहीं मिली');
    }

    final isApproved = currentProfile!.kycStatus == ProviderKycStatus.approved ||
        currentProfile!.status == ProviderAccountStatus.approved;

    // Strict backend-style category lock validation
    if (isApproved) {
      const categoryKeys = [
        'primaryCategoryId',
        'categoryId',
        'category',
        'primaryCategoryTitle',
        'categoryTitle',
        'selectedCategoryIds',
      ];
      for (final key in categoryKeys) {
        if (fields.containsKey(key)) {
          final requestedVal = fields[key];
          if (requestedVal != currentProfile!.primaryCategoryId &&
              requestedVal != currentProfile!.primaryCategoryTitle) {
            throw Exception('यह श्रेणी एडमिन द्वारा स्वीकृत (Admin-Approved) है और इसे बदला नहीं जा सकता।');
          }
        }
      }
    }

    // Whitelist allowed fields only (never overwrite kycStatus, status, rating, etc.)
    currentProfile = currentProfile!.copyWith(
      businessName: fields['businessName'] as String? ?? currentProfile!.businessName,
      fullName: fields['fullName'] as String? ?? (fields['ownerName'] as String? ?? currentProfile!.fullName),
      businessDescription: fields['businessDescription'] as String? ?? currentProfile!.businessDescription,
      visitingCharge: fields['visitingCharge'] != null
          ? (fields['visitingCharge'] as num).toDouble()
          : currentProfile!.visitingCharge,
      jamuiArea: fields['jamuiArea'] as String? ?? currentProfile!.jamuiArea,
      fullAddress: fields['fullAddress'] as String? ?? currentProfile!.fullAddress,
      email: fields['email'] as String? ?? currentProfile!.email,
      isAvailable: fields['isAvailable'] as bool? ?? currentProfile!.isAvailable,
      profileImageUrl: fields['profileImageUrl'] as String? ?? currentProfile!.profileImageUrl,
      businessImageUrl: fields['businessImageUrl'] as String? ?? currentProfile!.businessImageUrl,
    );
  }

  @override
  Future<void> updateAvailability(String providerId, bool isAvailable) async {
    if (currentProfile != null) {
      currentProfile = currentProfile!.copyWith(isAvailable: isAvailable);
    }
  }

  @override
  Future<void> submitKyc({required String providerId}) async {
    if (currentProfile != null) {
      currentProfile = currentProfile!.copyWith(
        kycStatus: ProviderKycStatus.pendingReview,
      );
    }
  }

  @override
  Future<void> incrementLeadCount({required String providerId, required bool isCall}) async {
    if (currentProfile != null) {
      currentProfile = currentProfile!.copyWith(
        totalCalls: isCall ? currentProfile!.totalCalls + 1 : currentProfile!.totalCalls,
        totalWhatsAppClicks: !isCall ? currentProfile!.totalWhatsAppClicks + 1 : currentProfile!.totalWhatsAppClicks,
      );
    }
  }

  @override
  Future<String> uploadImage({required String providerId, required File imageFile, required String folder}) async {
    return 'https://example.com/photo.jpg';
  }

  @override
  Future<String> uploadImageBytes({
    required String providerId,
    required Uint8List imageBytes,
    required String folder,
    String mimeType = 'image/jpeg',
  }) async {
    return 'https://example.com/photo.jpg';
  }

  @override
  Future<void> submitCustomServiceApplication(CustomServiceApplicationEntity application) async {}

  @override
  Future<void> submitCategoryChangeRequest({
    required String providerId,
    required String requestedCategoryId,
    required String requestedCategoryTitle,
    Map<String, dynamic>? customServiceDetails,
  }) async {
    if (currentProfile != null) {
      currentProfile = currentProfile!.copyWith(
        requestedCategoryId: requestedCategoryId,
        requestedCategoryTitle: requestedCategoryTitle,
        categoryApprovalStatus: 'pending_review',
      );
    }
  }

  @override
  Stream<CustomServiceApplicationEntity?> watchCustomServiceApplication(String providerId) {
    return Stream.value(null);
  }

  @override
  Future<CustomServiceApplicationEntity?> getCustomServiceApplication(String providerId) async {
    return null;
  }
}

void main() {
  group('ProviderAuthBloc Tests', () {
    late MockProviderRepository mockRepository;
    late ProviderAuthBloc bloc;

    final dummyApprovedProfile = ProviderProfileEntity(
      id: 'test_provider_1',
      email: 'provider@jamui.com',
      phoneNumber: '+919876543210',
      fullName: 'सुनील कुमार',
      businessName: 'सुनील प्लंबिंग वर्क्स',
      primaryCategoryId: 'cat_plumber',
      primaryCategoryTitle: 'प्लंबर',
      kycStatus: ProviderKycStatus.approved,
      status: ProviderAccountStatus.approved,
      rating: 4.8,
      ratingCount: 25,
      createdAt: DateTime(2026, 1, 1),
    );

    final dummyPendingProfile = ProviderProfileEntity(
      id: 'test_pending_provider',
      email: 'newprovider@jamui.com',
      phoneNumber: '+919876543211',
      fullName: 'रमेश कुमार',
      businessName: 'रमेश इलेक्ट्रीशियन',
      primaryCategoryId: 'cat_electrician',
      primaryCategoryTitle: 'इलेक्ट्रीशियन',
      kycStatus: ProviderKycStatus.pendingReview,
      status: ProviderAccountStatus.pendingReview,
      createdAt: DateTime(2026, 2, 1),
    );

    setUp(() {
      mockRepository = MockProviderRepository(currentProfile: dummyApprovedProfile);
      bloc = ProviderAuthBloc(providerRepository: mockRepository);
    });

    tearDown(() {
      bloc.close();
    });

    test('Initial state is ProviderAuthInitial', () {
      expect(bloc.state, equals(ProviderAuthInitial()));
    });

    test('LoadProviderProfileEvent emits [ProviderAuthLoading, ProviderAuthenticated]', () async {
      final expectedStates = [
        ProviderAuthLoading(),
        ProviderAuthenticated(dummyApprovedProfile),
      ];

      expectLater(bloc.stream, emitsInOrder(expectedStates));
      bloc.add(const LoadProviderProfileEvent('test_provider_1'));
    });

    test('ProviderAuthenticated props include isAvailable and distinguish state when isAvailable changes', () {
      final stateOnline = ProviderAuthenticated(dummyApprovedProfile.copyWith(isAvailable: true));
      final stateOffline = ProviderAuthenticated(dummyApprovedProfile.copyWith(isAvailable: false));

      expect(stateOnline.props.contains(true), isTrue);
      expect(stateOffline.props.contains(false), isTrue);
      expect(stateOnline, isNot(equals(stateOffline)));
    });

    test('ToggleAvailabilityEvent updates availability status and emits distinct ProviderAuthenticated states', () async {
      final activeSubProfile = dummyApprovedProfile.copyWith(
        isSubscriptionActive: true,
        paymentVerified: true,
        subscriptionPlan: 'monthly',
        subscriptionExpiry: DateTime.now().add(const Duration(days: 30)),
        isAvailable: true,
      );
      mockRepository.currentProfile = activeSubProfile;

      bloc.add(const LoadProviderProfileEvent('test_provider_1'));
      await bloc.stream.firstWhere((s) => s is ProviderAuthenticated);

      expect(bloc.state, isA<ProviderAuthenticated>());
      expect((bloc.state as ProviderAuthenticated).profile.isAvailable, isTrue);
      expect(mockRepository.currentProfile?.isAvailable, isTrue);

      // 1. Toggle availability to false: expect distinct emitted state on bloc.stream
      expectLater(
        bloc.stream,
        emits(isA<ProviderAuthenticated>().having(
          (s) => s.profile.isAvailable,
          'profile.isAvailable',
          false,
        )),
      );
      bloc.add(const ToggleAvailabilityEvent(false));
      await pumpEventQueue();

      expect((bloc.state as ProviderAuthenticated).profile.isAvailable, isFalse);
      expect(mockRepository.currentProfile?.isAvailable, isFalse);

      // 2. Toggle availability back to true: expect distinct emitted state on bloc.stream
      expectLater(
        bloc.stream,
        emits(isA<ProviderAuthenticated>().having(
          (s) => s.profile.isAvailable,
          'profile.isAvailable',
          true,
        )),
      );
      bloc.add(const ToggleAvailabilityEvent(true));
      await pumpEventQueue();

      expect((bloc.state as ProviderAuthenticated).profile.isAvailable, isTrue);
      expect(mockRepository.currentProfile?.isAvailable, isTrue);
    });

    test('1 & 2. Approved Provider edits permitted fields via UpdatePermittedProfileFieldsEvent -> saved instantly and remains approved', () async {
      final updatedProfile = dummyApprovedProfile.copyWith(
        businessName: 'सुनील सुपर प्लंबिंग',
        fullAddress: 'स्टेशन रोड, जमुई',
      );

      final expectedStates = [
        ProviderAuthLoading(),
        ProviderAuthenticated(updatedProfile),
        isA<ProviderProfileUpdatedSuccessState>()
            .having((s) => s.profile.kycStatus, 'kycStatus', ProviderKycStatus.approved)
            .having((s) => s.profile.businessName, 'businessName', 'सुनील सुपर प्लंबिंग'),
      ];

      expectLater(bloc.stream, emitsInOrder(expectedStates));

      bloc.add(UpdatePermittedProfileFieldsEvent(
        providerId: dummyApprovedProfile.id,
        updatedFields: {
          'businessName': 'सुनील सुपर प्लंबिंग',
          'fullAddress': 'स्टेशन रोड, जमुई',
        },
        updatedProfile: updatedProfile,
      ));
    });

    test('1 & 2. Approved Provider edits profile via UpdateProviderProfileEvent -> preserved approved status without resetting to pendingReview', () async {
      final updatedProfile = dummyApprovedProfile.copyWith(
        businessName: 'सुनील प्रीमियम सर्विसेज',
      );

      final expectedStates = [
        ProviderAuthLoading(),
        ProviderAuthenticated(updatedProfile),
        isA<ProviderProfileUpdatedSuccessState>()
            .having((s) => s.profile.kycStatus, 'kycStatus', ProviderKycStatus.approved)
            .having((s) => s.profile.businessName, 'businessName', 'सुनील प्रीमियम सर्विसेज'),
      ];

      expectLater(bloc.stream, emitsInOrder(expectedStates));
      bloc.add(UpdateProviderProfileEvent(updatedProfile));
    });

    test('3 & 4. Approved Provider attempts to change approved category -> rejected and emits ProviderAuthError', () async {
      final invalidUpdatedProfile = dummyApprovedProfile.copyWith(
        primaryCategoryId: 'cat_electrician',
        primaryCategoryTitle: 'इलेक्ट्रीशियन',
      );

      final expectedStates = [
        ProviderAuthLoading(),
        isA<ProviderAuthError>().having(
          (s) => s.message,
          'message',
          contains('यह श्रेणी एडमिन द्वारा स्वीकृत (Admin-Approved) है और इसे बदला नहीं जा सकता।'),
        ),
      ];

      expectLater(bloc.stream, emitsInOrder(expectedStates));

      bloc.add(UpdatePermittedProfileFieldsEvent(
        providerId: dummyApprovedProfile.id,
        updatedFields: {
          'primaryCategoryId': 'cat_electrician',
        },
        updatedProfile: invalidUpdatedProfile,
      ));
    });

    test('7. Pending Provider submitting profile -> continues existing admin approval workflow with ProviderKycSubmittedSuccess', () async {
      final pendingRepo = MockProviderRepository(currentProfile: dummyPendingProfile);
      final pendingBloc = ProviderAuthBloc(providerRepository: pendingRepo);

      final updatedPendingProfile = dummyPendingProfile.copyWith(
        businessName: 'रमेश सुपर इलेक्ट्रीशियन',
      );

      final expectedStates = [
        ProviderAuthLoading(),
        ProviderAuthenticated(updatedPendingProfile),
        isA<ProviderKycSubmittedSuccess>()
            .having((s) => s.profile?.kycStatus, 'kycStatus', ProviderKycStatus.pendingReview),
      ];

      expectLater(pendingBloc.stream, emitsInOrder(expectedStates));
      pendingBloc.add(UpdateProviderProfileEvent(updatedPendingProfile));

      await Future.delayed(const Duration(milliseconds: 100));
      pendingBloc.close();
    });

    test('9. Partial update does not overwrite unrelated fields such as rating and creation date', () async {
      await mockRepository.updatePermittedProfileFields(
        providerId: dummyApprovedProfile.id,
        fields: {
          'businessName': 'सुनील न्यू नेम',
          'rating': 1.0, // should be ignored by whitelist
          'kycStatus': 'pendingReview', // should be ignored by whitelist
        },
      );

      final current = mockRepository.currentProfile!;
      expect(current.businessName, equals('सुनील न्यू नेम'));
      expect(current.rating, equals(4.8)); // Preserved
      expect(current.ratingCount, equals(25)); // Preserved
      expect(current.kycStatus, equals(ProviderKycStatus.approved)); // Preserved
    });

    test('10. Network failure preserves error and emits ProviderAuthError without false success', () async {
      final failingRepo = FailingMockProviderRepository();
      final failingBloc = ProviderAuthBloc(providerRepository: failingRepo);

      final expectedStates = [
        ProviderAuthLoading(),
        isA<ProviderAuthError>().having(
          (s) => s.message,
          'message',
          contains('नेटवर्क कनेक्शन विफल'),
        ),
      ];

      expectLater(failingBloc.stream, emitsInOrder(expectedStates));

      failingBloc.add(UpdatePermittedProfileFieldsEvent(
        providerId: 'provider_123',
        updatedFields: {'businessName': 'टेस्ट'},
        updatedProfile: dummyApprovedProfile,
      ));

      await Future.delayed(const Duration(milliseconds: 100));
      failingBloc.close();
    });
  });
}

class FailingMockProviderRepository extends MockProviderRepository {
  @override
  Future<void> updatePermittedProfileFields({
    required String providerId,
    required Map<String, dynamic> fields,
  }) async {
    throw Exception('नेटवर्क कनेक्शन विफल: सर्वर से संपर्क नहीं हो सका।');
  }
}


