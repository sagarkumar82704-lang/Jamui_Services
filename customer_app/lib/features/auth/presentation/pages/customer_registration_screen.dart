import 'package:flutter/material.dart';
import 'customer_login_screen.dart';

/// [CustomerRegistrationScreen]
/// Unified with [CustomerLoginScreen] with `initialIsSignUp = true`
/// to guarantee identical visual design and authentication behavior.
class CustomerRegistrationScreen extends StatelessWidget {
  const CustomerRegistrationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomerLoginScreen(initialIsSignUp: true);
  }
}
