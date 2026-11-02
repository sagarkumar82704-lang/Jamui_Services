import 'package:flutter/material.dart';
import 'customer_login_screen.dart';

/// Obsolete: Phone OTP verification is disabled in favour of zero-cost email/password auth.
class OtpVerificationScreen extends StatelessWidget {
  final String verificationId;
  final String phoneNumber;

  const OtpVerificationScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
  });

  @override
  Widget build(BuildContext context) {
    return const CustomerLoginScreen();
  }
}
