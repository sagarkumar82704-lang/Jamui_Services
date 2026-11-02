import 'package:flutter/material.dart';
import 'customer_login_screen.dart';

/// Backward-compatible alias pointing to the cost-free [CustomerLoginScreen].
class PhoneLoginScreen extends StatelessWidget {
  const PhoneLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomerLoginScreen();
  }
}
