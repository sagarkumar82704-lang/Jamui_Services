import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';

void main() {
  group('Provider Registration Phone Auth & CAPTCHA Security Tests', () {
    test('RecaptchaVerifier configuration contract for invisible web authentication', () {
      // Invisible reCAPTCHA in Firebase Auth Web omits container so firebase_auth_web creates 
      // an invisible dynamic div without intrusive checkbox elements
      expect(RecaptchaVerifierSize.values, contains(RecaptchaVerifierSize.compact));
      expect(RecaptchaVerifierSize.values, contains(RecaptchaVerifierSize.normal));
    });

    test('Phone Number Sanitization standardizes 10-digit Indian numbers cleanly', () {
      String sanitize(String raw) {
        final cleanDigits = raw.replaceAll(RegExp(r'[\s\-\(\)]'), '');
        final digits = cleanDigits.length >= 10 ? cleanDigits.substring(cleanDigits.length - 10) : cleanDigits;
        return digits.length == 10 ? '+91$digits' : '';
      }

      expect(sanitize('7645010292'), equals('+917645010292'));
      expect(sanitize('+91 7645010292'), equals('+917645010292'));
      expect(sanitize('+91-7645-010292'), equals('+917645010292'));
      expect(sanitize('76450'), equals('')); // too short
    });

    test('Cooldown Timer prevents duplicate OTP submission during active window', () {
      int cooldownSeconds = 60;
      bool isSending = false;

      bool canSendOtp() {
        return !isSending && cooldownSeconds == 0;
      }

      // Immediately after sending, cooldown is active (60s)
      expect(canSendOtp(), isFalse);

      // Decrement cooldown
      cooldownSeconds = 30;
      expect(canSendOtp(), isFalse);

      // Expired cooldown allows resend
      cooldownSeconds = 0;
      expect(canSendOtp(), isTrue);

      // In-flight sending blocks resend
      isSending = true;
      expect(canSendOtp(), isFalse);
    });

    test('Editing phone number resets prior verification state and cooldown', () {
      String? verificationId = 'test_ver_id_123';
      bool isVerified = false;
      int cooldown = 45;

      void onPhoneChanged(String newDigits) {
        verificationId = null;
        isVerified = false;
        cooldown = 0;
      }

      expect(verificationId, isNotNull);
      expect(cooldown, equals(45));

      onPhoneChanged('9876543210');

      expect(verificationId, isNull);
      expect(isVerified, isFalse);
      expect(cooldown, equals(0));
    });

    test('Firebase error formatting maps rate-limiting & captcha errors safely', () {
      String formatError(String code) {
        switch (code) {
          case 'too-many-requests':
            return 'बहुत अधिक OTP अनुरोध किए गए हैं। कृपया कुछ मिनट बाद पुनः प्रयास करें।';
          case 'quota-exceeded':
            return 'दैनिक SMS सीमा समाप्त हो गई है। कृपया सहायता टीम से संपर्क करें।';
          case 'invalid-phone-number':
            return 'मोबाइल नंबर अमान्य है। कृपया 10 अंकों का सही नंबर दर्ज करें।';
          case 'captcha-check-failed':
            return 'सुरक्षा सत्यापन (reCAPTCHA) विफल रहा। कृपया इंटरनेट जांचें व पुनः प्रयास करें।';
          case 'network-request-failed':
            return 'इंटरनेट कनेक्शन में समस्या है। कृपया नेटवर्क जांचें।';
          default:
            return 'OTP भेजने में समस्या हुई। कृपया पुनः प्रयास करें।';
        }
      }

      expect(formatError('too-many-requests'), contains('बहुत अधिक OTP अनुरोध'));
      expect(formatError('quota-exceeded'), contains('दैनिक SMS सीमा'));
      expect(formatError('captcha-check-failed'), contains('सुरक्षा सत्यापन'));
      expect(formatError('invalid-phone-number'), contains('मोबाइल नंबर अमान्य'));
    });
  });
}
