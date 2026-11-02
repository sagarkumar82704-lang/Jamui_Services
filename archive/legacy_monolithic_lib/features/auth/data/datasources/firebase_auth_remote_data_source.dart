import '../../../../core/errors/failures.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../domain/entities/user_entity.dart';
import '../models/user_model.dart';
import 'auth_remote_data_source.dart';

/// [FirebaseAuthRemoteDataSource] Firebase Phone Auth और Cloud Firestore के साथ डेटा इंटरैक्शन करता है।
class FirebaseAuthRemoteDataSource implements AuthRemoteDataSource {
  final AuthService _authService;
  final FirestoreService _firestoreService;

  FirebaseAuthRemoteDataSource({
    AuthService? authService,
    FirestoreService? firestoreService,
  })  : _authService = authService ?? AuthService(),
        _firestoreService = firestoreService ?? FirestoreService();

  static const String _usersCollection = 'users';

  @override
  Future<void> sendOtp({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(String error) onError,
  }) async {
    try {
      await _authService.sendOtp(
        phoneNumber: phoneNumber,
        onCodeSent: onCodeSent,
        onVerificationFailed: (e) => onError(e.message ?? 'OTP सत्यापन विफल रहा'),
        onVerificationCompleted: (_) {},
        onCodeAutoRetrievalTimeout: (_) {},
      );
    } catch (e) {
      onError(e.toString());
    }
  }

  @override
  Future<UserModel> verifyOtpAndSyncUser({
    required String verificationId,
    required String smsCode,
    required UserRole selectedRole,
  }) async {
    final userCredential = await _authService.verifyOtpAndSignIn(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    final firebaseUser = userCredential.user;
    if (firebaseUser == null) {
      throw const AuthFailure('उपयोगकर्ता प्रमाणीकरण असफल रहा।');
    }

    final uid = firebaseUser.uid;
    final phone = firebaseUser.phoneNumber ?? '';

    // Firestore में यूजर रिकॉर्ड चेक या क्रिएट करें
    final existingData = await _firestoreService.getDocument(
      collectionName: _usersCollection,
      documentId: uid,
    );

    if (existingData != null) {
      return UserModel.fromMap(existingData, uid);
    }

    // नया यूजर बनाएं
    String roleStr = 'customer';
    if (selectedRole == UserRole.provider) {
      roleStr = 'provider';
    } else if (selectedRole == UserRole.admin) {
      roleStr = 'admin';
    }

    final newUser = UserModel(
      id: uid,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      phone: phone,
      name: '',
      roleString: roleStr,
      isProfileComplete: false,
      isVerified: false,
    );

    await _firestoreService.setDocument(
      collectionName: _usersCollection,
      documentId: uid,
      data: newUser.toMap(),
      merge: true,
    );

    return newUser;
  }

  @override
  Future<UserModel?> getCurrentUserModel() async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return null;

    final data = await _firestoreService.getDocument(
      collectionName: _usersCollection,
      documentId: currentUser.uid,
    );

    if (data == null) return null;
    return UserModel.fromMap(data, currentUser.uid);
  }

  @override
  Future<void> signOut() async {
    await _authService.signOut();
  }
}
