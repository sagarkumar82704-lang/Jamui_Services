import 'package:firebase_auth/firebase_auth.dart';

/// [AuthExceptionHandler] फ़ायरबेस प्रमाणीकरण के सभी Exceptions को User-Friendly हिंदी संदेशों में मैप करता है।
class AuthExceptionHandler {
  static String handleException(dynamic exception) {
    if (exception is FirebaseAuthException) {
      final friendly = _mapFirebaseCode(exception.code, exception.message);
      final rawDetails = exception.message != null ? ' (${exception.message})' : '';
      return '$friendly\n[Technical Code: ${exception.code}$rawDetails]';
    }
    
    final str = exception.toString().toLowerCase();
    if (str.contains('network') || str.contains('socket') || str.contains('connection')) {
      return 'इंटरनेट कनेक्शन की समस्या है। कृपया अपना इंटरनेट कनेक्शन जांच कर दोबारा प्रयास करें。\n[Technical Code: network_error]';
    }
    if (str.contains('too-many-requests') || str.contains('blocked')) {
      return 'बहुत अधिक OTP requests भेजी गई हैं। कृपया कुछ समय बाद पुनः प्रयास करें。\n[Technical Code: too_many_requests]';
    }
    if (str.contains('invalid-phone') || str.contains('format')) {
      return 'कृपया सही 10 अंकों का मोबाइल नंबर दर्ज करें。\n[Technical Code: invalid_format]';
    }

    return 'तकनीकी समस्या: $exception';
  }

  static String _mapFirebaseCode(String code, String? rawMessage) {
    switch (code) {
      case 'invalid-phone-number':
        return 'कृपया सही 10 अंकों का वैध मोबाइल नंबर दर्ज करें।';
      case 'too-many-requests':
      case 'activity-blocked':
        return 'बहुत अधिक OTP requests भेजी गई हैं। कृपया कुछ समय बाद पुनः प्रयास करें।';
      case 'network-request-failed':
        return 'इंटरनेट कनेक्शन की समस्या है। कृपया अपना इंटरनेट कनेक्शन जांच कर दोबारा प्रयास करें।';
      case 'quota-exceeded':
        return 'दैनिक SMS सीमा समाप्त हो गई है। कृपया कुछ समय बाद प्रयास करें।';
      case 'invalid-verification-code':
      case 'invalid-otp':
        return 'अमान्य OTP कोड। कृपया सही 6 अंकों का OTP दर्ज करें।';
      case 'session-expired':
        return 'OTP सत्र समाप्त हो गया है। कृपया "पुनः OTP भेजें" पर क्लिक करें।';
      case 'invalid-verification-id':
        return 'सत्यापन सत्र अमान्य है। कृपया दोबारा OTP प्राप्त करें।';
      case 'user-disabled':
        return 'यह खाता व्यवस्थापक द्वारा अक्षम कर दिया गया है।';
      case 'operation-not-allowed':
        return 'फोन सत्यापन सेवा वर्तमान में सक्रिय नहीं है। कृपया व्यवस्थापक से संपर्क करें।';
      case 'credential-already-in-use':
        return 'यह फोन नंबर पहले से किसी अन्य खाते से जुड़ा हुआ है।';
      case 'captcha-check-failed':
        return 'सुरक्षा सत्यापन (reCAPTCHA) विफल रहा। कृपया दोबारा प्रयास करें।';
      case 'app-not-authorized':
        return 'एप्लिकेशन प्रमाणीकरण त्रुटि। कृपया ऐप अपडेट करें या पुनः प्रयास करें।';
      case 'invalid-email':
        return 'कृपया एक वैध ईमेल पता दर्ज करें।';
      case 'user-not-found':
        return 'इस ईमेल से कोई खाता पंजीकृत नहीं है। कृपया नया खाता बनाएं।';
      case 'wrong-password':
        return 'गलत पासवर्ड दर्ज किया गया है। कृपया पुनः प्रयास करें या पासवर्ड रीसेट करें।';
      case 'invalid-credential':
        return 'ईमेल या पासवर्ड अमान्य है। कृपया पुनः जाँचें।';
      case 'email-already-in-use':
        return 'यह ईमेल पहले से किसी खाते से जुड़ा है। कृपया लॉगिन करें।';
      case 'weak-password':
        return 'पासवर्ड बहुत कमजोर है। कम से कम 6 अक्षर का पासवर्ड रखें।';
      default:
        return 'प्रमाणीकरण में समस्या हुई। कृपया पुनः प्रयास करें।';
    }
  }
}
