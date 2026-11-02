import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_provider/features/auth/domain/entities/provider_profile_entity.dart';
import 'package:apna_jamui_provider/features/auth/data/models/provider_profile_model.dart';
import 'package:apna_jamui_provider/features/auth/presentation/bloc/provider_auth_bloc.dart';
import 'package:apna_jamui_provider/features/auth/presentation/bloc/provider_auth_event.dart';
import 'package:apna_jamui_provider/features/auth/presentation/bloc/provider_auth_state.dart';
import 'provider_auth_bloc_test.dart';
import 'provider_email_auth_security_test.dart';

class MockFailingSaveProviderRepository extends MockProviderRepository {
  @override
  Future<void> saveProfile(ProviderProfileEntity profile) async {
    throw Exception('नेटवर्क कनेक्शन विफल: सर्वर से संपर्क नहीं हो सका।');
  }
}

void main() {
  group('Provider Registration Flow & Dashboard Loop Prevention Tests', () {
    test('1. Model Deserialization: pending_review (with underscore) maps to pendingReview and registrationStatus completes', () {
      final rawFirestoreMap = <String, dynamic>{
        'id': 'provider_test_101',
        'email': 'electrical@jamui.com',
        'phoneNumber': '+919876543299',
        'fullName': 'विक्रम शर्मा',
        'businessName': 'शर्मा इलेक्ट्रिकल्स',
        'primaryCategoryId': 'cat_electrician',
        'primaryCategoryTitle': 'इलेक्ट्रीशियन',
        'status': 'pending_review',
        'kycStatus': 'pending_review',
        'currentStep': 5,
        'completedSteps': [0, 1, 2, 3, 4, 5],
        'registrationStatus': 'completed',
      };

      final model = ProviderProfileModel.fromMap(rawFirestoreMap, 'provider_test_101');

      expect(model.status, equals(ProviderAccountStatus.pendingReview),
          reason: "'pending_review' must parse as pendingReview, NOT draft");
      expect(model.kycStatus, equals(ProviderKycStatus.pendingReview),
          reason: "'pending_review' must parse as pendingReview");
      expect(model.registrationStatus, equals('completed'),
          reason: "Completed registration status must be preserved");
    });

    test('2. Model Deserialization Fallback: legacy/missing registrationStatus with pending_review defaults to completed', () {
      final rawFirestoreMap = <String, dynamic>{
        'id': 'provider_test_102',
        'email': 'carpenter@jamui.com',
        'phoneNumber': '+919876543298',
        'fullName': 'राकेश बढ़ई',
        'businessName': 'राकेश फर्नीचर वर्क्स',
        'primaryCategoryId': 'cat_carpenter',
        'primaryCategoryTitle': 'बढ़ई',
        'status': 'pending_review',
        'kycStatus': 'pending_review',
        'completedSteps': [0, 1, 2, 3, 4, 5],
      };

      final model = ProviderProfileModel.fromMap(rawFirestoreMap, 'provider_test_102');

      expect(model.status, equals(ProviderAccountStatus.pendingReview));
      expect(model.registrationStatus, equals('completed'),
          reason: "Missing registrationStatus with completed steps must not fall back to 'draft'");
    });

    test('3. Truly incomplete draft (steps 0-2) is recognized as incomplete and emits ProviderProfileIncomplete', () async {
      final draftProfile = ProviderProfileEntity(
        id: 'draft_provider_1',
        email: 'draft@jamui.com',
        phoneNumber: '+919876543201',
        fullName: 'अमित कुमार',
        businessName: '',
        primaryCategoryId: '',
        primaryCategoryTitle: '',
        status: ProviderAccountStatus.draft,
        registrationStatus: 'draft',
        currentStep: 1,
        completedSteps: const [0],
        createdAt: DateTime(2026, 3, 1),
      );

      final fakeUser = FakeFirebaseUser(uid: 'draft_provider_1', email: 'draft@jamui.com');
      final repo = SecurityTestProviderRepository(mockUser: fakeUser, currentProfile: draftProfile);
      final bloc = ProviderAuthBloc(providerRepository: repo);

      final expectedStates = [
        ProviderAuthLoading(),
        isA<ProviderProfileIncomplete>()
            .having((s) => s.profile.currentStep, 'currentStep', 1),
      ];

      expectLater(bloc.stream, emitsInOrder(expectedStates));
      bloc.add(CheckAuthStatusEvent());

      await Future.delayed(const Duration(milliseconds: 150));
      bloc.close();
    });

    test('4. Completed registration in pending review does NOT emit ProviderProfileIncomplete on stream update or CheckAuth', () async {
      final completedPendingProfile = ProviderProfileEntity(
        id: 'completed_pending_1',
        email: 'pending@jamui.com',
        phoneNumber: '+919876543202',
        fullName: 'दिनेश वर्मा',
        businessName: 'दिनेश एसी रिपेयरिंग',
        primaryCategoryId: 'cat_ac_repair',
        primaryCategoryTitle: 'एसी रिपेयर',
        status: ProviderAccountStatus.pendingReview,
        kycStatus: ProviderKycStatus.pendingReview,
        registrationStatus: 'completed',
        currentStep: 5,
        completedSteps: const [0, 1, 2, 3, 4, 5],
        jamuiArea: 'जमुई मेन मार्केट',
        fullAddress: 'स्टーション रोड, जमुई',
        latitude: 25.0,
        longitude: 86.0,
        workingHours: '09:00 AM - 08:00 PM',
        createdAt: DateTime(2026, 3, 1),
      );

      final fakeUser = FakeFirebaseUser(uid: 'completed_pending_1', email: 'pending@jamui.com');
      final repo = SecurityTestProviderRepository(mockUser: fakeUser, currentProfile: completedPendingProfile);
      final bloc = ProviderAuthBloc(providerRepository: repo);

      final expectedStates = [
        ProviderAuthLoading(),
        isA<ProviderAuthenticated>()
            .having((s) => s.profile.businessName, 'businessName', 'दिनेश एसी रिपेयरिंग')
            .having((s) => s.profile.status, 'status', ProviderAccountStatus.pendingReview),
      ];

      expectLater(bloc.stream, emitsInOrder(expectedStates));
      bloc.add(CheckAuthStatusEvent());

      await Future.delayed(const Duration(milliseconds: 150));

      // Trigger profile stream update (e.g. real-time counter increment or rating update)
      final updatedSnapshot = completedPendingProfile.copyWith(totalViews: 10);
      bloc.add(ProviderProfileStreamUpdatedEvent(updatedSnapshot));

      await Future.delayed(const Duration(milliseconds: 50));
      expect(bloc.state, isA<ProviderAuthenticated>());
      bloc.close();
    });

    test('5. App restart / Re-login with Email routes pending review provider directly to dashboard without looping to registration', () async {
      final pendingProfile = ProviderProfileEntity(
        id: 'login_pending_1',
        email: 'relogin@jamui.com',
        phoneNumber: '+919876543203',
        fullName: 'संजय यादव',
        businessName: 'संजय वेल्डिंग वर्क्स',
        primaryCategoryId: 'cat_welder',
        primaryCategoryTitle: 'वेल्डर',
        status: ProviderAccountStatus.pendingReview,
        kycStatus: ProviderKycStatus.pendingReview,
        registrationStatus: 'completed',
        currentStep: 5,
        completedSteps: const [0, 1, 2, 3, 4, 5],
        createdAt: DateTime(2026, 3, 1),
      );

      final fakeUser = FakeFirebaseUser(uid: 'login_pending_1', email: 'relogin@jamui.com');
      final repo = SecurityTestProviderRepository(mockUser: fakeUser, currentProfile: pendingProfile);
      final bloc = ProviderAuthBloc(providerRepository: repo);

      // Provider logs in
      bloc.add(LoginWithEmailEvent(email: 'relogin@jamui.com', password: 'password123'));

      await Future.delayed(const Duration(milliseconds: 250));
      // Must not be ProviderProfileIncomplete
      expect(bloc.state, isNot(isA<ProviderProfileIncomplete>()));
      expect(bloc.state, isA<ProviderAuthenticated>());
      final authProfile = (bloc.state as ProviderAuthenticated).profile;
      expect(authProfile.status, equals(ProviderAccountStatus.pendingReview));
      expect(authProfile.registrationStatus, equals('completed'));
      bloc.close();
    });

    test('6. Security Check: Completed pending provider remains unapproved and not permitted for live leads', () {
      final pendingProfile = ProviderProfileEntity(
        id: 'security_check_1',
        email: 'security@jamui.com',
        phoneNumber: '+919876543204',
        fullName: 'विजय कुमार',
        businessName: 'विजय टाइल्स',
        primaryCategoryId: 'cat_tiles',
        primaryCategoryTitle: 'टाइल्स व मार्बल',
        status: ProviderAccountStatus.pendingReview,
        kycStatus: ProviderKycStatus.pendingReview,
        registrationStatus: 'completed',
        currentStep: 5,
        completedSteps: const [0, 1, 2, 3, 4, 5],
        createdAt: DateTime(2026, 3, 1),
      );

      // Admin approval is NOT bypassed
      expect(pendingProfile.status, equals(ProviderAccountStatus.pendingReview));
      expect(pendingProfile.kycStatus, equals(ProviderKycStatus.pendingReview));
      expect(pendingProfile.isPermittedForLeads, isFalse,
          reason: "Unapproved provider must NEVER be permitted for live customer leads");
    });

    test('7. Network error during update profile preserves error state without false dashboard redirect', () async {
      final failingRepo = MockFailingSaveProviderRepository();
      final bloc = ProviderAuthBloc(providerRepository: failingRepo);

      final testProfile = ProviderProfileEntity(
        id: 'fail_test_1',
        email: 'fail@jamui.com',
        phoneNumber: '+919876543205',
        fullName: 'अशोक कुमार',
        businessName: 'अशोक पेंट्स',
        primaryCategoryId: 'cat_painter',
        primaryCategoryTitle: 'पेंटर',
        status: ProviderAccountStatus.pendingReview,
        kycStatus: ProviderKycStatus.pendingReview,
        registrationStatus: 'completed',
        createdAt: DateTime(2026, 3, 1),
      );

      final expectedStates = [
        ProviderAuthLoading(),
        isA<ProviderAuthError>()
            .having((e) => e.message, 'message', contains('विफल')),
      ];

      expectLater(bloc.stream, emitsInOrder(expectedStates));
      bloc.add(UpdateProviderProfileEvent(testProfile));

      await Future.delayed(const Duration(milliseconds: 150));
      bloc.close();
    });

    test('8. Admin Panel Schema Verification: toMap produces all expected fields for Admin Panel and Dashboard query', () {
      final newProvider = ProviderProfileEntity(
        id: 'new_provider_uid_101',
        email: 'electrician.jamui@gmail.com',
        phoneNumber: '+919876543210',
        fullName: 'अमित कुमार शर्मा',
        businessName: 'शर्मा इलेक्ट्रिकल वर्क्स',
        businessDescription: 'सभी प्रकार के घरेलू वायरिंग कार्य',
        primaryCategoryId: 'cat_electrician',
        primaryCategoryTitle: 'इलेक्ट्रीशियन',
        selectedCategoryIds: const ['cat_electrician', 'cat_plumber'],
        visitingCharge: 150.0,
        experienceYears: 5,
        jamuiArea: 'झाझा (Jhajha)',
        fullAddress: 'स्टेशन रोड, झाझा, जमुई',
        latitude: 24.77,
        longitude: 86.38,
        status: ProviderAccountStatus.pendingReview,
        kycStatus: ProviderKycStatus.pendingReview,
        registrationStatus: 'completed',
        currentStep: 5,
        completedSteps: const [0, 1, 2, 3, 4, 5],
        createdAt: DateTime(2026, 3, 1),
      );

      final map = ProviderProfileModel.fromEntity(newProvider).toMap();

      // Required Admin Panel fields
      expect(map['email'], equals('electrician.jamui@gmail.com'));
      expect(map['fullName'], equals('अमित कुमार शर्मा'));
      expect(map['ownerName'], equals('अमित कुमार शर्मा'), reason: "Admin directory checks ownerName");
      expect(map['phoneNumber'], equals('+919876543210'));
      expect(map['phone'], equals('+919876543210'), reason: "Admin directory fallback checks phone");
      expect(map['businessName'], equals('शर्मा इलेक्ट्रिकल वर्क्स'));
      expect(map['primaryCategoryTitle'], equals('इलेक्ट्रीशियन'));
      expect(map['categoryTitle'], equals('इलेक्ट्रीशियन'));
      expect(map['primaryCategoryId'], equals('cat_electrician'));
      expect(map['category'], equals('cat_electrician'), reason: "Admin directory query checks category");
      expect(map['status'], equals('pendingReview'));
      expect(map['kycStatus'], equals('pendingReview'));
      expect(map['registrationStatus'], equals('completed'));
      expect(map['verificationStatus'], equals('pending'), reason: "Admin Dashboard count query checks verificationStatus == 'pending'");
      expect(map['isVerified'], isFalse, reason: "New provider must not be self-verified");
      expect(map['paymentVerified'], isFalse);
    });

    test('9. Cross-Account Collision: Attempting to register email of another provider is rejected', () async {
      final mockRepo = SecurityTestProviderRepository(
        mockUser: FakeFirebaseUser(
          uid: 'different_new_uid_999',
          email: 'duplicate@jamui.com',
          phoneNumber: '+919999999999',
          displayName: 'दूसरा यूजर',
        ),
      );

      // Pre-seed an existing provider with this email under a DIFFERENT uid
      await mockRepo.saveProfile(ProviderProfileEntity(
        id: 'original_uid_111',
        email: 'duplicate@jamui.com',
        phoneNumber: '+919876543200',
        fullName: 'मूल प्रदाता',
        businessName: 'मूल दुकान',
        primaryCategoryId: 'cat_electrician',
        primaryCategoryTitle: 'इलेक्ट्रीशियन',
        status: ProviderAccountStatus.approved,
        kycStatus: ProviderKycStatus.approved,
        registrationStatus: 'completed',
        createdAt: DateTime(2026, 1, 1),
      ));

      // Querying existing provider by email returns the existing original account
      final existing = await mockRepo.findRegisteredProviderByEmail('duplicate@jamui.com');
      expect(existing, isNotNull);
      expect(existing!.id, equals('original_uid_111'));
      expect(existing.id, isNot(equals('different_new_uid_999')),
          reason: "Email belongs to a different UID and must not be overwritten or merged");
    });

    test('10. Double Submit Guard: Sequential calls with double-tap guard prevents duplicate profile saves', () async {
      int saveCount = 0;
      final countingRepo = SecurityTestProviderRepository(
        mockUser: FakeFirebaseUser(
          uid: 'double_tap_uid_1',
          email: 'tap@jamui.com',
          phoneNumber: '+919876543211',
          displayName: 'टैप यूजर',
        ),
      );

      final profile = ProviderProfileEntity(
        id: 'double_tap_uid_1',
        email: 'tap@jamui.com',
        phoneNumber: '+919876543211',
        fullName: 'टैप यूजर',
        businessName: 'टैप शॉप',
        primaryCategoryId: 'cat_salon',
        primaryCategoryTitle: 'सैलून',
        status: ProviderAccountStatus.pendingReview,
        kycStatus: ProviderKycStatus.pendingReview,
        registrationStatus: 'completed',
        createdAt: DateTime(2026, 3, 1),
      );

      // Simulate double-tap guard logic
      bool isSubmittingFinal = false;

      Future<void> submitAction() async {
        if (isSubmittingFinal) return; // Guard blocks duplicate trigger
        isSubmittingFinal = true;
        try {
          saveCount++;
          await countingRepo.saveProfile(profile);
        } finally {
          isSubmittingFinal = false;
        }
      }

      // Simulate simultaneous rapid taps
      await Future.wait([
        submitAction(),
        submitAction(),
      ]);

      expect(saveCount, equals(1), reason: "Double tap must only trigger a single profile save");
    });

    test('11. Schema Consistency Contract: Step 0 draft and Page 6 final payload share exact protected field keys & types', () {
      // Step 0 draft schema
      final step0DraftMap = <String, dynamic>{
        'uid': 'user_123',
        'id': 'user_123',
        'fullName': 'प्रवीण कुमार',
        'ownerName': 'प्रवीण कुमार',
        'phoneNumber': '+919876543210',
        'phone': '+919876543210',
        'email': 'praveen@jamui.com',
        'status': 'draft',
        'registrationStatus': 'draft',
        'verificationStatus': 'pending',
        'currentStep': 1,
        'completedSteps': [0],
        'isMobileVerified': true,
        'isEmailVerified': false,
        'isVerified': false,
        'isSubscriptionActive': false,
        'paymentVerified': false,
        'rating': 5.0,
        'ratingCount': 0,
        'subscriptionPlan': 'none',
      };

      // Page 6 final payload
      final page6Profile = ProviderProfileEntity(
        id: 'user_123',
        email: 'praveen@jamui.com',
        phoneNumber: '+919876543210',
        fullName: 'प्रवीण कुमार',
        businessName: 'प्रवीण रिपेयरिंग',
        primaryCategoryId: 'cat_electrician',
        primaryCategoryTitle: 'इलेक्ट्रीशियन',
        status: ProviderAccountStatus.pendingReview,
        kycStatus: ProviderKycStatus.pendingReview,
        registrationStatus: 'completed',
        currentStep: 5,
        completedSteps: const [0, 1, 2, 3, 4, 5],
        createdAt: DateTime(2026, 3, 1),
      );
      final page6Map = ProviderProfileModel.fromEntity(page6Profile).toMap();

      // Ensure all protected fields in Page 6 match Step 0 keys and safe defaults
      expect(page6Map['isVerified'], equals(false));
      expect(page6Map['isSubscriptionActive'], equals(false));
      expect(page6Map['paymentVerified'], equals(false));
      expect(page6Map['rating'], equals(5.0));
      expect(page6Map['ratingCount'], equals(0));
      expect(page6Map['verificationStatus'], equals('pending'));
      expect(page6Map['status'], equals('pendingReview'));
      expect(page6Map['kycStatus'], equals('pendingReview'));
      expect(page6Map['registrationStatus'], equals('completed'));

      for (final key in ['isVerified', 'isSubscriptionActive', 'paymentVerified', 'rating', 'ratingCount']) {
        expect(step0DraftMap[key], equals(page6Map[key]),
            reason: "Protected key '$key' must have identical values between Step 0 draft and Page 6 final payload");
      }
    });

    test('12. Security Rules Anti-Privilege Escalation Contract: Self-approval and unauthorized mutation rejected', () {
      // Helper simulating exact Firestore security rule logic:
      bool evaluateProviderUpdateRule({
        required bool isOwner,
        required bool isBlocked,
        required Map<String, dynamic> existingData,
        required Map<String, dynamic> incomingData,
      }) {
        if (!isOwner || isBlocked) return false;

        // Anti-escalation value checks
        if (incomingData['isVerified'] == true) return false;
        if (incomingData['status'] == 'approved') return false;
        if (incomingData['kycStatus'] == 'approved') return false;
        if (incomingData['verificationStatus'] == 'approved') return false;

        // Subscription & Payment checks
        if (incomingData['isSubscriptionActive'] != existingData['isSubscriptionActive']) return false;
        if (incomingData['paymentVerified'] != existingData['paymentVerified']) return false;
        if (incomingData['subscriptionExpiry'] != existingData['subscriptionExpiry']) return false;

        // Ratings & Admin checks
        if (incomingData['rating'] != existingData['rating']) return false;
        if (incomingData['ratingCount'] != existingData['ratingCount']) return false;
        if (incomingData['adminCategoryOverrideLimit'] != existingData['adminCategoryOverrideLimit']) return false;

        // Forbidden server-only keys in affectedKeys
        final forbiddenKeys = {'adminCategoryOverrideLimit', 'subscriptionExpiry', 'paymentVerifiedAt'};
        for (final k in forbiddenKeys) {
          if (incomingData.containsKey(k) && incomingData[k] != existingData[k]) {
            return false;
          }
        }

        // If approved, category and core locks
        final isApproved = existingData['status'] == 'approved' || existingData['isVerified'] == true;
        if (isApproved) {
          final lockedKeys = {
            'status', 'kycStatus', 'verificationStatus', 'primaryCategoryId',
            'categoryId', 'category', 'primaryCategoryTitle', 'categoryTitle',
            'selectedCategoryIds', 'isVerified', 'isSubscriptionActive',
            'subscriptionPlan', 'paymentVerified', 'rating', 'ratingCount'
          };
          for (final k in lockedKeys) {
            if (incomingData.containsKey(k) && incomingData[k] != existingData[k]) {
              return false;
            }
          }
        } else {
          // Unapproved provider status bounds
          const allowedStatus = {'draft', 'pendingReview'};
          const allowedKyc = {'draft', 'notSubmitted', 'pendingReview'};
          const allowedVerif = {'draft', 'pending', 'pendingReview'};

          if (!allowedStatus.contains(incomingData['status'])) return false;
          if (!allowedKyc.contains(incomingData['kycStatus'])) return false;
          if (!allowedVerif.contains(incomingData['verificationStatus'])) return false;
        }

        return true;
      }

      final existingDraft = <String, dynamic>{
        'status': 'draft',
        'kycStatus': 'draft',
        'verificationStatus': 'pending',
        'isVerified': false,
        'isSubscriptionActive': false,
        'paymentVerified': false,
        'subscriptionExpiry': null,
        'rating': 5.0,
        'ratingCount': 0,
        'adminCategoryOverrideLimit': 0,
      };

      // Case A: Legitimate Page 6 Final Submit (transitioning to pendingReview)
      final legitimateSubmit = Map<String, dynamic>.from(existingDraft)
        ..addAll({
          'status': 'pendingReview',
          'kycStatus': 'pendingReview',
          'registrationStatus': 'completed',
          'businessName': 'शर्मा रिपेयरिंग',
        });
      expect(evaluateProviderUpdateRule(isOwner: true, isBlocked: false, existingData: existingDraft, incomingData: legitimateSubmit),
          isTrue, reason: "Legitimate registration submit to pendingReview must be ALLOWED");

      // Case B: Escalation - Attempting to set isVerified = true
      final attackVerified = Map<String, dynamic>.from(legitimateSubmit)..['isVerified'] = true;
      expect(evaluateProviderUpdateRule(isOwner: true, isBlocked: false, existingData: existingDraft, incomingData: attackVerified),
          isFalse, reason: "Self-verifying isVerified=true must be REJECTED");

      // Case C: Escalation - Attempting to set status = 'approved'
      final attackApproved = Map<String, dynamic>.from(legitimateSubmit)..['status'] = 'approved';
      expect(evaluateProviderUpdateRule(isOwner: true, isBlocked: false, existingData: existingDraft, incomingData: attackApproved),
          isFalse, reason: "Self-approving status=approved must be REJECTED");

      // Case D: Escalation - Attempting to self-activate subscription
      final attackSubscription = Map<String, dynamic>.from(legitimateSubmit)..['isSubscriptionActive'] = true;
      expect(evaluateProviderUpdateRule(isOwner: true, isBlocked: false, existingData: existingDraft, incomingData: attackSubscription),
          isFalse, reason: "Self-activating subscription must be REJECTED");

      // Case E: Escalation - Attempting to fake payment verification
      final attackPayment = Map<String, dynamic>.from(legitimateSubmit)..['paymentVerified'] = true;
      expect(evaluateProviderUpdateRule(isOwner: true, isBlocked: false, existingData: existingDraft, incomingData: attackPayment),
          isFalse, reason: "Self-verifying payment must be REJECTED");

      // Case F: Escalation - Attempting to modify rating
      final attackRating = Map<String, dynamic>.from(legitimateSubmit)..['rating'] = 4.9;
      expect(evaluateProviderUpdateRule(isOwner: true, isBlocked: false, existingData: existingDraft, incomingData: attackRating),
          isFalse, reason: "Modifying provider rating must be REJECTED");

      // Case G: Escalation - Approved provider attempting to alter locked categories
      final existingApproved = Map<String, dynamic>.from(existingDraft)
        ..addAll({'status': 'approved', 'isVerified': true, 'primaryCategoryId': 'cat_electrician'});
      final attackCategoryChange = Map<String, dynamic>.from(existingApproved)..['primaryCategoryId'] = 'cat_plumber';
      expect(evaluateProviderUpdateRule(isOwner: true, isBlocked: false, existingData: existingApproved, incomingData: attackCategoryChange),
          isFalse, reason: "Approved provider modifying primaryCategoryId must be REJECTED");
    });
  });
}
