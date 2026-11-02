import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../../core/services/r2_upload_service.dart';
import '../../../../core/utils/auth_exception_handler.dart';
import '../../../../core/utils/image_compression_helper.dart';
import '../../domain/entities/provider_profile_entity.dart';
import '../models/provider_profile_model.dart';
import '../models/custom_service_application_model.dart';
import 'provider_remote_data_source.dart';

/// Real Firebase implementation of [ProviderRemoteDataSource]
/// Uses FirebaseAuth, FirebaseFirestore, and Cloudflare R2 with ZERO DUMMY DATA.
class FirebaseProviderRemoteDataSource implements ProviderRemoteDataSource {
  final FirebaseAuth? _injectedFirebaseAuth;
  final FirebaseFirestore? _injectedFirestore;
  final R2UploadService _r2Service;
  String? _lastPhoneNumber;
  ConfirmationResult? _webConfirmationResult;
  RecaptchaVerifier? _webRecaptchaVerifier;

  FirebaseAuth get _firebaseAuth => _injectedFirebaseAuth ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore => _injectedFirestore ?? FirebaseFirestore.instance;

  static const String _collectionName = 'providers';

  FirebaseProviderRemoteDataSource({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    R2UploadService? r2Service,
  })  : _injectedFirebaseAuth = auth,
        _injectedFirestore = firestore,
        _r2Service = r2Service ?? R2UploadService();

  @override
  User? getCurrentFirebaseUser() {
    return _firebaseAuth.currentUser;
  }

  @override
  Future<User?> registerWithEmail({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();
    final cleanFullName = fullName.trim();
    final cleanPhone = phoneNumber.trim();

    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: cleanEmail,
      password: cleanPassword,
    );
    final user = credential.user;

    if (user != null) {
      await user.updateDisplayName(cleanFullName);

      // Create initial draft provider profile document
      final newProfile = ProviderProfileModel(
        id: user.uid,
        email: cleanEmail,
        phoneNumber: cleanPhone.startsWith('+91') ? cleanPhone : '+91$cleanPhone',
        fullName: cleanFullName,
        businessName: '',
        primaryCategoryId: '',
        primaryCategoryTitle: '',
        kycStatus: ProviderKycStatus.notSubmitted,
        status: ProviderAccountStatus.draft,
        createdAt: DateTime.now(),
      );

      await saveProviderProfile(newProfile);
    }

    return user;
  }

  @override
  Future<User?> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password.trim(),
    );
    return credential.user;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    await _firebaseAuth.sendPasswordResetEmail(email: email.trim().toLowerCase());
  }

  @override
  Future<void> sendEmailVerification() async {
    final user = _firebaseAuth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  @override
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  @override
  Future<User> linkEmailPasswordCredential({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw 'सत्र समाप्त हो गया है। कृपया पहले फोन OTP पुनः सत्यापित करें।';
    }

    final credential = EmailAuthProvider.credential(
      email: cleanEmail,
      password: cleanPassword,
    );

    final providerIds = user.providerData.map((p) => p.providerId).toSet();
    if (!providerIds.contains('password')) {
      try {
        final linkResult = await user.linkWithCredential(credential);
        return linkResult.user ?? user;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use' || e.code == 'email-already-in-use') {
          throw 'यह ईमेल ($cleanEmail) पहले से किसी अन्य खाते से जुड़ा हुआ है। कृपया कोई दूसरा ईमेल दर्ज करें या सीधे लॉगिन करें।';
        } else if (e.code == 'provider-already-linked') {
          await user.updatePassword(cleanPassword);
          return user;
        } else if (e.code == 'operation-not-allowed' || e.code == 'admin-restricted-operation') {
          // Bypasses client-side Email Enumeration Protection restriction via secure Admin Cloud Function
          try {
            final callable = FirebaseFunctions.instanceFor(region: 'asia-south1').httpsCallable('linkProviderEmailPassword');
            await callable.call(<String, dynamic>{
              'email': cleanEmail,
              'password': cleanPassword,
            });
            await user.reload();
            return _firebaseAuth.currentUser ?? user;
          } catch (funcErr) {
            debugPrint('Cloud Function linking error: $funcErr');
            throw 'सुरक्षित रूप से ईमेल लिंक करने में विफल: ${funcErr.toString().replaceAll("FirebaseException: ", "")}';
          }
        } else {
          throw AuthExceptionHandler.handleException(e);
        }
      }
    } else {
      try {
        await user.updatePassword(cleanPassword);
      } catch (e) {
        debugPrint('Password update note: $e');
      }
      return user;
    }
  }

  @override
  Future<ProviderProfileModel> safeMigratePhoneAccount({
    required String providerId,
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final user = await linkEmailPasswordCredential(email: cleanEmail, password: password);
    if (user.uid != providerId) {
      throw 'सुरक्षा त्रुटि: ऑथेंटिकेशन खाता आईडी और प्रोवाइडर आईडी मेल नहीं खा रहे हैं। (Security Error: Account ID mismatch)';
    }

    final docSnap = await _firestore.collection(_collectionName).doc(providerId).get();
    if (!docSnap.exists || docSnap.data() == null) {
      throw 'प्रोवाइडर खाता डेटाबेस में नहीं मिला।';
    }

    // Safely update email and verification flags while strictly preserving existing profile, status, kyc, and subscriptions
    await _firestore.collection(_collectionName).doc(providerId).update({
      'email': cleanEmail,
      'isMobileVerified': true,
      'isEmailVerified': user.emailVerified,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final updatedDoc = await _firestore.collection(_collectionName).doc(providerId).get();
    return ProviderProfileModel.fromMap(updatedDoc.data()!, updatedDoc.id);
  }

  @override
  Future<void> sendPhoneOtp({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(String errorMessage) onError,
    required void Function(PhoneAuthCredential credential) onVerificationCompleted,
  }) async {
    _lastPhoneNumber = phoneNumber.trim();
    String formattedPhone = _lastPhoneNumber!;
    if (!formattedPhone.startsWith('+')) {
      formattedPhone = '+91$formattedPhone';
    }

    if (kIsWeb) {
      try {
        try {
          _webRecaptchaVerifier?.clear();
        } catch (_) {}
        _webRecaptchaVerifier = RecaptchaVerifier(
          auth: FirebaseAuthPlatform.instance,
          onSuccess: () => debugPrint('✅ [FIREBASE AUTH] Web invisible reCAPTCHA passed'),
          onError: (err) => debugPrint('❌ [FIREBASE AUTH] Web reCAPTCHA error: $err'),
          onExpired: () => debugPrint('⌛ [FIREBASE AUTH] Web reCAPTCHA expired'),
        );

        _webConfirmationResult = await _firebaseAuth.signInWithPhoneNumber(
          formattedPhone,
          _webRecaptchaVerifier!,
        );

        onCodeSent(_webConfirmationResult!.verificationId, null);
      } catch (e) {
        try {
          _webRecaptchaVerifier?.clear();
        } catch (_) {}
        _webRecaptchaVerifier = null;
        onError(AuthExceptionHandler.handleException(e));
      }
      return;
    }

    try {
      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          if (kDebugMode) {
            debugPrint('✅ [FIREBASE AUTH] Phone auto-verification completed');
          }
          onVerificationCompleted(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          if (kDebugMode) {
            debugPrint('❌ [FIREBASE AUTH] Phone verification failed: ${e.message}');
          }
          onError(AuthExceptionHandler.handleException(e));
        },
        codeSent: (String verificationId, int? resendToken) {
          if (kDebugMode) {
            debugPrint('🚀 [FIREBASE AUTH] OTP Code sent to $formattedPhone, VerificationID: $verificationId');
          }
          onCodeSent(verificationId, resendToken);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (kDebugMode) {
            debugPrint('⌛ [FIREBASE AUTH] Auto-retrieval timeout for $verificationId');
          }
        },
      );
    } catch (e) {
      onError(AuthExceptionHandler.handleException(e));
    }
  }

  @override
  Future<UserCredential> verifyOtpCode({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      UserCredential userCred;

      if (kIsWeb && _webConfirmationResult != null) {
        userCred = await _webConfirmationResult!.confirm(smsCode.trim());
      } else {
        final credential = PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: smsCode.trim(),
        );

        final currentUser = _firebaseAuth.currentUser;
        if (currentUser != null) {
          try {
            userCred = await currentUser.linkWithCredential(credential);
          } catch (linkError) {
            userCred = await _firebaseAuth.signInWithCredential(credential);
          }
        } else {
          userCred = await _firebaseAuth.signInWithCredential(credential);
        }
      }

      final user = userCred.user;
      if (user != null) {
        final doc = await _firestore.collection(_collectionName).doc(user.uid).get();
        if (doc.exists) {
          await _firestore.collection(_collectionName).doc(user.uid).update({
            'isMobileVerified': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      return userCred;
    } catch (e) {
      throw AuthExceptionHandler.handleException(e);
    }
  }

  @override
  Future<ProviderProfileModel?> getProviderProfile(String id) async {
    try {
      final doc = await _firestore.collection(_collectionName).doc(id).get().timeout(const Duration(seconds: 5));
      if (doc.exists && doc.data() != null) {
        return ProviderProfileModel.fromMap(doc.data()!, doc.id);
      }

      // Seamless Diamond Seller fallback: If profile is registered under diamond_shops
      final shopDoc = await _firestore.collection('diamond_shops').doc(id).get().timeout(const Duration(seconds: 4));
      if (shopDoc.exists && shopDoc.data() != null) {
        final data = shopDoc.data()!;
        final isApproved = data['status'] == 'approved' || data['isApproved'] == true;
        return ProviderProfileModel(
          id: shopDoc.id,
          email: (data['ownerEmail'] ?? data['email'] ?? '').toString(),
          phoneNumber: (data['phone'] ?? data['ownerPhone'] ?? '').toString(),
          fullName: (data['shopName'] ?? '').toString(),
          businessName: (data['shopName'] ?? '').toString(),
          businessDescription: (data['description'] ?? 'Professional Merchant').toString(),
          primaryCategoryId: (data['demandCategoryId'] ?? data['categoryId'] ?? 'cat_grocery').toString(),
          primaryCategoryTitle: (data['demandCategoryTitle'] ?? data['categoryTitle'] ?? data['category'] ?? 'Professional Shop').toString(),
          status: isApproved ? ProviderAccountStatus.approved : ProviderAccountStatus.pendingReview,
          kycStatus: isApproved ? ProviderKycStatus.approved : ProviderKycStatus.pendingReview,
          registrationStatus: 'completed',
          isSubscriptionActive: data['isSubscriptionActive'] == true,
          isActive: data['isActive'] != false,
          isDeleted: data['isDeleted'] == true,
          fullAddress: (data['address'] ?? data['fullAddress'] ?? '').toString(),
          createdAt: DateTime.now(),
        );
      }
    } catch (e) {
      debugPrint('⚠️ [FirebaseProviderRemoteDataSource] getProviderProfile error: $e');
    }
    return null;
  }

  @override
  Future<ProviderProfileModel?> findRegisteredProviderByPhone(String rawPhoneNumber) async {
    final clean = rawPhoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    final digits = clean.length >= 10 ? clean.substring(clean.length - 10) : clean;
    final formats = ['+91$digits', digits];

    for (final fmt in formats) {
      try {
        final query1 = await _firestore
            .collection(_collectionName)
            .where('phoneNumber', isEqualTo: fmt)
            .limit(1)
            .get();
        if (query1.docs.isNotEmpty) {
          final doc = query1.docs.first;
          final model = ProviderProfileModel.fromMap(doc.data(), doc.id);
          if (_isProfileRegistered(model)) {
            return model;
          }
        }
      } catch (e) {
        debugPrint('⚠️ [FIREBASE PROVIDER] query1 phone check note: $e');
      }

      try {
        final query2 = await _firestore
            .collection(_collectionName)
            .where('phone', isEqualTo: fmt)
            .limit(1)
            .get();
        if (query2.docs.isNotEmpty) {
          final doc = query2.docs.first;
          final model = ProviderProfileModel.fromMap(doc.data(), doc.id);
          if (_isProfileRegistered(model)) {
            return model;
          }
        }
      } catch (e) {
        debugPrint('⚠️ [FIREBASE PROVIDER] query2 phone check note: $e');
      }
    }
    return null;
  }

  @override
  Future<ProviderProfileModel?> findRegisteredProviderByEmail(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    final rawEmail = email.trim();
    if (cleanEmail.isEmpty) return null;

    try {
      var query = await _firestore
          .collection(_collectionName)
          .where('email', isEqualTo: cleanEmail)
          .limit(1)
          .get();

      if (query.docs.isEmpty && rawEmail != cleanEmail) {
        query = await _firestore
            .collection(_collectionName)
            .where('email', isEqualTo: rawEmail)
            .limit(1)
            .get();
      }

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        final model = ProviderProfileModel.fromMap(doc.data(), doc.id);
        if (_isProfileRegistered(model)) {
          return model;
        }
      }

      // Fallback check in diamond_shops
      final shopQuery = await _firestore
          .collection('diamond_shops')
          .where('ownerEmail', isEqualTo: cleanEmail)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 4));
      if (shopQuery.docs.isNotEmpty) {
        final shopDoc = shopQuery.docs.first;
        final data = shopDoc.data();
        final isApproved = data['status'] == 'approved' || data['isApproved'] == true;
        return ProviderProfileModel(
          id: shopDoc.id,
          email: (data['ownerEmail'] ?? data['email'] ?? cleanEmail).toString(),
          phoneNumber: (data['phone'] ?? data['ownerPhone'] ?? '').toString(),
          fullName: (data['shopName'] ?? '').toString(),
          businessName: (data['shopName'] ?? '').toString(),
          businessDescription: (data['description'] ?? 'Professional Merchant').toString(),
          primaryCategoryId: (data['demandCategoryId'] ?? data['categoryId'] ?? 'cat_grocery').toString(),
          primaryCategoryTitle: (data['demandCategoryTitle'] ?? data['categoryTitle'] ?? data['category'] ?? 'Professional Shop').toString(),
          status: isApproved ? ProviderAccountStatus.approved : ProviderAccountStatus.pendingReview,
          kycStatus: isApproved ? ProviderKycStatus.approved : ProviderKycStatus.pendingReview,
          registrationStatus: 'completed',
          isSubscriptionActive: data['isSubscriptionActive'] == true,
          isActive: data['isActive'] != false,
          isDeleted: data['isDeleted'] == true,
          fullAddress: (data['address'] ?? data['fullAddress'] ?? '').toString(),
          createdAt: DateTime.now(),
        );
      }
    } catch (e) {
      debugPrint('⚠️ [FIREBASE PROVIDER] email query note: $e');
    }
    return null;
  }

  bool _isProfileRegistered(ProviderProfileModel profile) {
    return profile.businessName.trim().isNotEmpty &&
           profile.primaryCategoryId.trim().isNotEmpty;
  }

  @override
  Stream<ProviderProfileModel?> watchProviderProfile(String id) {
    return _firestore.collection(_collectionName).doc(id).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return ProviderProfileModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    });
  }

  @override
  Future<void> saveProviderProfile(ProviderProfileModel profile) async {
    final map = profile.toMap();
    map['updatedAt'] = FieldValue.serverTimestamp();

    // Strictly strip server-only and admin-managed protected fields to comply with Firestore Security Rules
    map.remove('planLimits');
    map.remove('isPremiumEligible');
    map.remove('storageUsage');
    map.remove('adminCategoryOverrideLimit');
    map.remove('subscriptionExpiry');
    map.remove('paymentVerifiedAt');
    map.remove('subscriptionPlan');
    map.remove('subscriptionPlanTier');
    map.remove('planTier');
    map.remove('subscriptionStatus');
    map.remove('rating');
    map.remove('ratingCount');
    map.remove('isSubscriptionActive');
    map.remove('paymentVerified');
    map.remove('createdAt');

    // Remove null entries to prevent creating null fields in Firestore documents
    map.removeWhere((key, value) => value == null);

    await _firestore.collection(_collectionName).doc(profile.id).set(
          map,
          SetOptions(merge: true),
        );
  }

  @override
  Future<void> updatePermittedProfileFields(String id, Map<String, dynamic> fields) async {
    final docSnap = await _firestore.collection(_collectionName).doc(id).get();
    if (!docSnap.exists) {
      throw Exception('प्रोफाइल डेटाबेस में मौजूद नहीं है।');
    }

    final currentData = docSnap.data() ?? {};
    final isApproved = currentData['kycStatus'] == 'approved' ||
                       currentData['status'] == 'approved' ||
                       currentData['isVerified'] == true;

    // Category lock enforcement: If provider is Admin-approved, reject any attempt to alter category fields
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
          final existingVal = currentData[key];
          final requestedVal = fields[key];
          if (existingVal != null && requestedVal != null && existingVal != requestedVal) {
            throw Exception('यह श्रेणी एडमिन द्वारा स्वीकृत (Admin-Approved) है और इसे बदला नहीं जा सकता। श्रेणी बदलने के लिए कृपया एडमिन से संपर्क करें।');
          }
        }
      }
    }

    // Strictly whitelist permitted fields only (Protection of admin approval, rating, limits, and subscriptions)
    const allowedFields = {
      'businessName',
      'fullName',
      'ownerName',
      'businessDescription',
      'businessType',
      'visitingCharge',
      'experienceYears',
      'workingHours',
      'jamuiArea',
      'area',
      'fullAddress',
      'latitude',
      'longitude',
      'serviceRadiusKm',
      'profileImageUrl',
      'businessImageUrl',
      'email',
      'isAvailable',
      'isOnline',
      'galleryImages',
      'servicesWithPricing',
      'instagramUrl',
      'facebookUrl',
      'websiteUrl',
    };

    final updatePayload = <String, dynamic>{};
    for (final entry in fields.entries) {
      if (allowedFields.contains(entry.key)) {
        updatePayload[entry.key] = entry.value;
      }
    }

    updatePayload['updatedAt'] = FieldValue.serverTimestamp();

    await _firestore.collection(_collectionName).doc(id).update(updatePayload);
  }

  @override
  Future<void> updateAvailability(String id, bool isAvailable) async {
    await _firestore.collection(_collectionName).doc(id).update({
      'isAvailable': isAvailable,
      'isOnline': isAvailable,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updateKycStatus(String id, String status, {String? reason, String? aadhaarMasked}) async {
    final updateData = <String, dynamic>{
      'kycStatus': status,
      'status': status == 'approved' ? ProviderAccountStatus.approved.name : ProviderAccountStatus.pendingReview.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (reason != null) updateData['rejectionReason'] = reason;
    if (aadhaarMasked != null) updateData['aadhaarNumberMasked'] = aadhaarMasked;

    await _firestore.collection(_collectionName).doc(id).update(updateData);
  }

  @override
  Future<void> incrementMetrics(String id, {bool isCall = false, bool isWhatsApp = false, bool isView = false}) async {
    final updateMap = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (isCall) updateMap['totalCalls'] = FieldValue.increment(1);
    if (isWhatsApp) updateMap['totalWhatsAppClicks'] = FieldValue.increment(1);
    if (isView) updateMap['totalViews'] = FieldValue.increment(1);

    if (updateMap.length > 1) {
      await _firestore.collection(_collectionName).doc(id).update(updateMap);
    }
  }

  @override
  Future<String> uploadProviderImage({
    required String providerId,
    required File imageFile,
    required String folder,
  }) async {
    if (kIsWeb) {
      final bytes = await imageFile.readAsBytes();
      return uploadProviderImageBytes(
        providerId: providerId,
        imageBytes: bytes,
        folder: folder,
      );
    }

    if (folder == 'profile' || folder == 'business' || folder == 'workplace') {
      final fileToUpload = await ImageCompressionHelper.compressFileToJpeg(
        imageFile,
        quality: 80,
        maxDimension: 800,
      );

      // Strictly Cloudflare R2 ONLY for public images.
      // Firebase Storage fallback is completely removed to prevent stealth storage costs.
      try {
        final r2Result = await _r2Service.uploadFile(
          fileToUpload,
          folder: folder,
          targetId: providerId,
          mimeType: 'image/jpeg',
        );
        return r2Result.objectKey; // Canonical relative R2 objectKey
      } catch (r2Error) {
        debugPrint('❌ [FirebaseProviderRemoteDataSource] R2 upload failed for public folder $folder (NO fallback permitted): $r2Error');
        throw Exception('Cloudflare R2 पर $folder फोटो अपलोड विफल रहा: ${r2Error.toString().replaceFirst("Exception: ", "")}');
      }
    } else if (folder == 'certificates' || folder == 'kyc') {
      // Documents (Certificates/KYC) uploaded directly to Cloudflare R2.
      // Private document access is secured via server-verified presigned GET URLs (getSecureDocumentViewUrl).
      try {
        final r2Result = await _r2Service.uploadFile(
          imageFile,
          folder: folder,
          targetId: providerId,
        );
        return r2Result.objectKey; // Canonical relative R2 objectKey
      } catch (r2Error) {
        debugPrint('❌ [FirebaseProviderRemoteDataSource] R2 upload failed for document folder $folder: $r2Error');
        throw Exception('Cloudflare R2 पर $folder दस्तावेज अपलोड विफल रहा: ${r2Error.toString().replaceFirst("Exception: ", "")}');
      }
    } else {
      throw ArgumentError('Unsupported folder for provider upload: $folder');
    }
  }

  @override
  Future<String> uploadProviderImageBytes({
    required String providerId,
    required Uint8List imageBytes,
    required String folder,
    String mimeType = 'image/jpeg',
  }) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';

    if (folder == 'profile' || folder == 'business' || folder == 'workplace') {
      final bytesToUpload = ImageCompressionHelper.compressToJpeg(
        imageBytes,
        quality: 80,
        maxDimension: 800,
      );

      // Strictly Cloudflare R2 ONLY for public images.
      // Firebase Storage fallback is completely removed to prevent stealth storage costs.
      try {
        final r2Result = await _r2Service.uploadBytes(
          bytes: bytesToUpload,
          folder: folder,
          fileName: fileName,
          mimeType: mimeType,
          targetId: providerId,
        );
        return r2Result.objectKey; // Canonical relative R2 objectKey
      } catch (r2Error) {
        debugPrint('❌ [FirebaseProviderRemoteDataSource] R2 bytes upload failed for public folder $folder (NO fallback permitted): $r2Error');
        throw Exception('Cloudflare R2 पर $folder फोटो अपलोड विफल रहा: ${r2Error.toString().replaceFirst("Exception: ", "")}');
      }
    } else if (folder == 'certificates' || folder == 'kyc') {
      // Documents (Certificates/KYC) uploaded directly to Cloudflare R2.
      // Private document access is secured via server-verified presigned GET URLs (getSecureDocumentViewUrl).
      try {
        final r2Result = await _r2Service.uploadBytes(
          bytes: imageBytes,
          folder: folder,
          fileName: fileName,
          mimeType: mimeType,
          targetId: providerId,
        );
        return r2Result.objectKey; // Canonical relative R2 objectKey
      } catch (r2Error) {
        debugPrint('❌ [FirebaseProviderRemoteDataSource] R2 bytes upload failed for document folder $folder: $r2Error');
        throw Exception('Cloudflare R2 पर $folder दस्तावेज अपलोड विफल रहा: ${r2Error.toString().replaceFirst("Exception: ", "")}');
      }
    } else {
      throw ArgumentError('Unsupported folder for provider upload: $folder');
    }
  }

  static const String _customServiceCollection = 'custom_service_applications';

  @override
  Future<void> submitCustomServiceApplication(CustomServiceApplicationModel application) async {
    final batch = _firestore.batch();

    // 1. Write application to custom_service_applications/{providerId}
    final appRef = _firestore.collection(_customServiceCollection).doc(application.providerId);
    final appData = application.toMap();
    appData['createdAt'] = FieldValue.serverTimestamp();
    appData['updatedAt'] = FieldValue.serverTimestamp();
    // Strip admin review fields to adhere to Firestore Security Rules
    appData.remove('mappedCategoryId');
    appData.remove('mappedCategoryTitle');
    appData.remove('adminFeedback');
    appData.remove('reviewedAt');
    appData.remove('reviewedBy');
    appData.removeWhere((k, v) => v == null);
    batch.set(appRef, appData, SetOptions(merge: true));

    // 2. Update provider profile to reflect pending custom service
    final provRef = _firestore.collection(_collectionName).doc(application.providerId);
    batch.set(provRef, {
      'isOtherService': true,
      'customServiceStatus': 'pending_review',
      'customServiceName': application.serviceName,
      'customServiceDescription': application.serviceDescription,
      'customServiceOffered': application.offeredServices,
      'primaryCategoryTitle': application.serviceName,
      'primaryCategoryId': 'custom_pending',
      'kycStatus': 'pendingReview',
      'status': 'pendingReview',
      'isVerified': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  @override
  Stream<CustomServiceApplicationModel?> watchCustomServiceApplication(String providerId) {
    return _firestore.collection(_customServiceCollection).doc(providerId).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return CustomServiceApplicationModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    });
  }

  @override
  Future<CustomServiceApplicationModel?> getCustomServiceApplication(String providerId) async {
    final doc = await _firestore.collection(_customServiceCollection).doc(providerId).get();
    if (doc.exists && doc.data() != null) {
      return CustomServiceApplicationModel.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  @override
  Future<void> submitCategoryChangeRequest({
    required String providerId,
    required String requestedCategoryId,
    required String requestedCategoryTitle,
    Map<String, dynamic>? customServiceDetails,
  }) async {
    // 1. Try Cloud Function
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-south1')
          .httpsCallable('requestProviderCategoryChange');
      await callable.call({
        'providerId': providerId,
        'requestedCategoryId': requestedCategoryId,
        'requestedCategoryTitle': requestedCategoryTitle,
        'customServiceDetails': customServiceDetails,
      });
      return;
    } catch (e) {
      debugPrint('⚠️ [FirebaseProviderRemoteDataSource] Cloud Function requestProviderCategoryChange failed, using direct Firestore batch: $e');
    }

    // 2. Direct Firestore fallback (idempotent, atomic batch)
    final batch = _firestore.batch();
    final now = FieldValue.serverTimestamp();
    final reqRef = _firestore.collection('category_requests').doc('req_$providerId');
    final provRef = _firestore.collection(_collectionName).doc(providerId);

    // Fetch existing provider details if possible for request metadata
    String providerName = '';
    String phoneNumber = '';
    String currentApprovedCategoryId = '';
    String currentApprovedCategoryTitle = '';
    try {
      final provSnap = await provRef.get();
      if (provSnap.exists && provSnap.data() != null) {
        final data = provSnap.data()!;
        providerName = (data['businessName'] ?? data['fullName'] ?? '').toString();
        phoneNumber = (data['phoneNumber'] ?? data['phone'] ?? '').toString();
        currentApprovedCategoryId = (data['primaryCategoryId'] ?? '').toString();
        currentApprovedCategoryTitle = (data['primaryCategoryTitle'] ?? '').toString();
      }
    } catch (_) {}

    final reqData = <String, dynamic>{
      'id': 'req_$providerId',
      'requestId': 'req_$providerId',
      'providerId': providerId,
      'providerName': providerName,
      'phoneNumber': phoneNumber,
      'currentApprovedCategoryId': currentApprovedCategoryId,
      'currentApprovedCategoryTitle': currentApprovedCategoryTitle,
      'requestedCategoryId': requestedCategoryId,
      'requestedCategoryTitle': requestedCategoryTitle,
      'serviceName': requestedCategoryTitle,
      'status': 'pending_review',
      'categoryRequestStatus': 'pending_review',
      'requestType': 'category_change_request',
      'updatedAt': now,
    };
    if (customServiceDetails != null) {
      reqData.addAll(customServiceDetails);
    }
    batch.set(reqRef, reqData, SetOptions(merge: true));

    // Update provider profile with pending category request
    batch.set(provRef, {
      'requestedCategoryId': requestedCategoryId,
      'requestedCategoryTitle': requestedCategoryTitle,
      'categoryApprovalStatus': 'pending_review',
      'categoryRequestStatus': 'pending_review',
      'categoryRequestId': 'req_$providerId',
      'categoryRejectionReason': FieldValue.delete(),
      'categoryRequestSubmittedAt': now,
      'updatedAt': now,
    }, SetOptions(merge: true));

    await batch.commit();
  }
}
