import 'package:firebase_auth/firebase_auth.dart';
import '../errors/failures.dart';

/// [AuthService] Firebase Authentication (Phone Number + OTP) को मैनेज करता है।
class AuthService {
  final FirebaseAuth _firebaseAuth;

  AuthService({FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  /// वर्तमान लॉग-इन यूजर प्राप्त करें
  User? get currentUser => _firebaseAuth.currentUser;

  /// यूजर ऑथेंटिकेशन स्टेट स्ट्रीम (रियल-टाइम लॉगिन स्थिति)
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// फोन नंबर पर OTP भेजें (Send OTP to Indian mobile number)
  Future<void> sendOtp({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(FirebaseAuthException error) onVerificationFailed,
    required void Function(PhoneAuthCredential credential) onVerificationCompleted,
    required void Function(String verificationId) onCodeAutoRetrievalTimeout,
    int? resendToken,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    try {
      // भारत का कोड +91 सुनिश्चित करें
      String formattedPhone = phoneNumber.trim();
      if (!formattedPhone.startsWith('+')) {
        formattedPhone = '+91$formattedPhone';
      }

      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        timeout: timeout,
        forceResendingToken: resendToken,
        verificationCompleted: onVerificationCompleted,
        verificationFailed: onVerificationFailed,
        codeSent: onCodeSent,
        codeAutoRetrievalTimeout: onCodeAutoRetrievalTimeout,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(e.message ?? 'OTP भेजने में त्रुटि हुई', code: e.code);
    } catch (e) {
      throw AuthFailure('OTP सेवा में तकनीकी समस्या: $e');
    }
  }

  /// OTP सत्यापित करें और लॉगिन पूरा करें (Verify OTP)
  Future<UserCredential> verifyOtpAndSignIn({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode.trim(),
      );
      return await _firebaseAuth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-verification-code') {
        throw const AuthFailure('गलत OTP दर्ज किया गया है। कृपया पुनः जाँचें।', code: 'invalid-otp');
      } else if (e.code == 'session-expired') {
        throw const AuthFailure('OTP की समय सीमा समाप्त हो गई है। कृपया पुनः OTP भेजें।', code: 'session-expired');
      }
      throw AuthFailure(e.message ?? 'लॉगिन विफल रहा', code: e.code);
    } catch (e) {
      throw AuthFailure('लॉगिन करने में असमर्थ: $e');
    }
  }

  /// लॉगआउट करें (Sign Out)
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      throw AuthFailure('लॉगआउट करने में असमर्थ: $e');
    }
  }
}
