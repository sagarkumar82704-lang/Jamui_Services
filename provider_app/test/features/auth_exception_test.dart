import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_provider/core/utils/auth_exception_handler.dart';

void main() {
  group('Provider AuthExceptionHandler Tests', () {
    test('Translates invalid-phone-number correctly', () {
      final ex = FirebaseAuthException(code: 'invalid-phone-number', message: 'The format of the phone number provided is incorrect.');
      final result = AuthExceptionHandler.handleException(ex);
      expect(result, contains('कृपया सही 10 अंकों का वैध भारतीय मोबाइल नंबर दर्ज करें'));
      expect(result, contains('invalid-phone-number'));
    });

    test('Translates invalid-verification-code correctly', () {
      final ex = FirebaseAuthException(code: 'invalid-verification-code', message: 'SMS verification code is invalid.');
      final result = AuthExceptionHandler.handleException(ex);
      expect(result, contains('गलत OTP कोड दर्ज किया गया है'));
    });

    test('Translates session-expired correctly', () {
      final ex = FirebaseAuthException(code: 'session-expired', message: 'The sms code has expired.');
      final result = AuthExceptionHandler.handleException(ex);
      expect(result, contains('OTP सत्र समाप्त हो गया है'));
    });

    test('Translates too-many-requests correctly', () {
      final ex = FirebaseAuthException(code: 'too-many-requests');
      final result = AuthExceptionHandler.handleException(ex);
      expect(result, contains('बहुत अधिक अनुरोध भेजे गए हैं'));
    });

    test('Translates network-request-failed correctly', () {
      final ex = FirebaseAuthException(code: 'network-request-failed');
      final result = AuthExceptionHandler.handleException(ex);
      expect(result, contains('इंटरनेट कनेक्शन की समस्या है'));
    });

    test('Translates non-firebase SocketException string correctly', () {
      final result = AuthExceptionHandler.handleException('SocketException: OS Error: Connection refused');
      expect(result, contains('इंटरनेट कनेक्शन की समस्या है'));
    });
  });
}
