import 'package:equatable/equatable.dart';

/// [Failure] सभी एप्लिकेशन एरर्स का बेस मॉडल है।
/// BLoC स्टेट्स में सीधे एक्सेप्शन पास करने के बजाय हम [Failure] का उपयोग करते हैं।
abstract class Failure extends Equatable {
  final String message;
  final String? code;

  const Failure(this.message, {this.code});

  @override
  List<Object?> get props => [message, code];
}

/// सर्वर या फायरबेस से संबंधित एरर्स
class ServerFailure extends Failure {
  const ServerFailure(super.message, {super.code});
}

/// नेटवर्क और इंटरनेट कनेक्टिविटी से संबंधित एरर्स
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'इंटरनेट कनेक्शन नहीं है। कृपया अपना नेटवर्क जांचें।']);
}

/// ऑथेंटिकेशन / लॉगिन से संबंधित एरर्स
class AuthFailure extends Failure {
  const AuthFailure(super.message, {super.code});
}

/// इनपुट वैलिडेशन एरर्स
class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}
