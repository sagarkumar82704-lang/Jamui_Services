import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// [AuthExceptionHandler] फ़ायरबेस प्रमाणीकरण के सभी Exceptions को User-Friendly हिंदी संदेशों में
/// और Actionable Technical Diagnostics के साथ मैप करता है।
class AuthExceptionHandler {
  static String handleException(dynamic exception) {
    debugPrint('🔥 [AuthExceptionHandler] Raw Exception: $exception');

    if (exception is FirebaseAuthException) {
      final friendly = _mapFirebaseCode(exception.code, exception.message);
      final diagnosticHint = _getDiagnosticHint(exception.code);
      final rawDetails = exception.message != null ? '\nDetails: ${exception.message}' : '';
      final hint = diagnosticHint.isNotEmpty ? '\n💡 समाधान (Fix): $diagnosticHint' : '';
      return '$friendly\n\n[Technical Code: ${exception.code}$rawDetails$hint]';
    }

    final str = exception.toString();
    final lower = str.toLowerCase();
    if (lower.contains('network') || lower.contains('socket') || lower.contains('connection')) {
      return 'इंटरनेट कनेक्शन की समस्या है। कृपया अपना मोबाइल डेटा या वाई-फाई कनेक्शन जांचें।\n\n[Technical Code: network_error]\n💡 समाधान: इंटरनेट जांचें या VPN बंद करें।';
    }
    if (lower.contains('too-many-requests') || lower.contains('blocked')) {
      return 'बहुत अधिक OTP requests भेजी गई हैं। कृपया कुछ समय बाद पुनः प्रयास करें।\n\n[Technical Code: too_many_requests]\n💡 समाधान: 15-30 मिनट प्रतीक्षा करें या दूसरा नंबर प्रयोग करें।';
    }
    if (lower.contains('invalid-phone') || lower.contains('format')) {
      return 'कृपया सही 10 अंकों का मोबाइल नंबर दर्ज करें।\n\n[Technical Code: invalid_format]';
    }
    if (lower.contains('invalid-verification-code') || lower.contains('invalid-otp')) {
      return 'गलत OTP कोड दर्ज किया गया है। कृपया 6 अंकों का सही OTP जांचें।\n\n[Technical Code: invalid_verification_code]';
    }
    if (lower.contains('session-expired')) {
      return 'OTP की समय सीमा समाप्त हो गई है। कृपया "पुनः OTP भेजें" पर टैप करें।\n\n[Technical Code: session_expired]';
    }

    return 'तकनीकी त्रुटि: ${str.replaceAll('Exception: ', '').trim()}';
  }

  static String _getDiagnosticHint(String code) {
    switch (code) {
      case 'app-not-authorized':
      case 'invalid-app-credential':
      case 'missing-client-identifier':
        return 'Firebase Console में SHA-1 / SHA-256 fingerprint और Google Play Integrity add करें।';
      case 'operation-not-allowed':
        return 'Firebase Console > Authentication > Sign-in method में "Phone" Provider को Enable करें।';
      case 'quota-exceeded':
        return 'Firebase Free SMS Quota पूरा हो गया है। Firebase Console में Test Phone Number (e.g. +91 9999999999 -> 123456) जोड़ें।';
      case 'captcha-check-failed':
        return 'reCAPTCHA सत्यापन विफल हुआ। Google Play Services और इंटरनेट कनेक्शन जांचें।';
      case 'network-request-failed':
        return 'Firebase सर्वर से संपर्क नहीं हो पाया। इंटरनेट कनेक्शन व फ़ायरवॉल जांचें।';
      case 'invalid-phone-number':
        return 'नंबर के आगे +91 सही से लगा है या नहीं जांचें।';
      default:
        return '';
    }
  }

  static String _mapFirebaseCode(String code, String? rawMessage) {
    switch (code) {
      case 'invalid-phone-number':
        return 'कृपया सही 10 अंकों का वैध भारतीय मोबाइल नंबर दर्ज करें।';
      case 'too-many-requests':
      case 'activity-blocked':
        return 'बहुत अधिक अनुरोध भेजे गए हैं। सुरक्षा कारणों से कुछ समय बाद पुनः प्रयास करें।';
      case 'network-request-failed':
        return 'इंटरनेट कनेक्शन की समस्या है। कृपया अपना मोबाइल डाटा या वाई-फाई कनेक्शन जांचें।';
      case 'quota-exceeded':
        return 'दैनिक SMS सीमा समाप्त हो गई है। कृपया कुछ समय बाद प्रयास करें या टेस्ट नंबर का उपयोग करें।';
      case 'invalid-verification-code':
      case 'invalid-otp':
        return 'गलत OTP कोड दर्ज किया गया है। कृपया 6 अंकों का सही कोड जांचें।';
      case 'session-expired':
        return 'OTP सत्र समाप्त हो गया है। कृपया "पुनः OTP भेजें" पर टैप करें।';
      case 'invalid-verification-id':
        return 'सत्यापन सत्र अमान्य है। कृपया दोबारा OTP प्राप्त करें।';
      case 'user-disabled':
        return 'यह प्रोवाइडर खाता व्यवस्थापक (Admin) द्वारा ब्लॉक या निष्क्रिय कर दिया गया है।';
      case 'operation-not-allowed':
        return 'फोन सत्यापन सेवा Firebase में सक्रिय नहीं है।';
      case 'credential-already-in-use':
        return 'यह फोन नंबर पहले से किसी अन्य खाते से जुड़ा हुआ है।';
      case 'captcha-check-failed':
        return 'सुरक्षा सत्यापन (reCAPTCHA) विफल रहा। कृपया इंटरनेट कनेक्शन जांच कर दोबारा प्रयास करें।';
      case 'app-not-authorized':
        return 'एप्लिकेशन प्रमाणीकरण त्रुटि (SHA-1 / Package mismatch)।';
      case 'user-not-found':
        return 'इस विवरण से कोई प्रोवाइडर खाता पंजीकृत नहीं है। कृपया नया रजिस्ट्रेशन करें।';
      case 'wrong-password':
      case 'invalid-credential':
        return 'गलत पासवर्ड या लॉगिन विवरण दर्ज किया गया है। कृपया जांचें।';
      case 'email-already-in-use':
        return 'यह ईमेल आईडी पहले से पंजीकृत है। कृपया सीधे लॉगिन करें।';
      case 'weak-password':
        return 'पासवर्ड बहुत कमजोर है। कृपया कम से कम 6 अक्षरों का मजबूत पासवर्ड बनाएं।';
      case 'invalid-email':
        return 'अमान्य ईमेल पता दर्ज किया गया है।';
      default:
        if (rawMessage != null && rawMessage.isNotEmpty) {
          return rawMessage;
        }
        return 'OTP प्रक्रिया में समस्या हुई। कृपया कुछ समय बाद पुनः प्रयास करें।';
    }
  }
}
