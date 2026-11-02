import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../bloc/customer_auth_bloc.dart';
import '../bloc/customer_auth_event.dart';
import '../bloc/customer_auth_state.dart';

/// A non-intrusive banner shown only to existing active Phone Auth customers
/// who have not yet linked an Email + Password credential.
/// Links credentials via `currentUser.linkWithCredential` preserving the exact same UID & booking history.
class PhoneAccountMigrationBanner extends StatefulWidget {
  const PhoneAccountMigrationBanner({super.key});

  @override
  State<PhoneAccountMigrationBanner> createState() => _PhoneAccountMigrationBannerState();
}

class _PhoneAccountMigrationBannerState extends State<PhoneAccountMigrationBanner> {
  bool _isDismissed = false;

  bool _isPhoneOnlyCustomer() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final hasEmail = user.email != null && user.email!.trim().isNotEmpty;
    final hasPasswordProvider = user.providerData.any((p) => p.providerId == 'password');
    return !hasEmail && !hasPasswordProvider;
  }

  void _openLinkAccountBottomSheet(BuildContext parentContext) {
    final formKey = GlobalKey<FormState>();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscurePassword = true;
    bool obscureConfirm = true;

    showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (bottomSheetContext, setModalState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Row(
                      children: [
                        Icon(Icons.shield_outlined, color: AppColors.primary, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'खाता सुरक्षित करें (Set Email & Password)',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'भविष्य में बिना SMS OTP के तुरंत लॉगिन करने के लिए अपना ईमेल और पासवर्ड सेट करें। आपकी पुरानी सभी बुकिंग्स व डेटा सुरक्षित रहेगा।',
                      style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4),
                    ),
                    const SizedBox(height: 16),

                    // Email Field
                    const Text(
                      'ईमेल पता (Email Address) *',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: 'उदा. yourname@gmail.com',
                        prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primary, size: 20),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'कृपया ईमेल पता लिखें';
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val.trim())) {
                          return 'कृपया सही ईमेल पता दर्ज करें';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Password Field
                    const Text(
                      'नया पासवर्ड (New Password) *',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        hintText: 'कम से कम 6 अक्षरों का पासवर्ड',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.primary, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility, size: 18),
                          onPressed: () => setModalState(() => obscurePassword = !obscurePassword),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'कृपया पासवर्ड दर्ज करें';
                        if (val.trim().length < 6) return 'पासवर्ड कम से कम 6 अक्षरों का होना चाहिए';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Confirm Password Field
                    const Text(
                      'पासवर्ड की पुष्टि (Confirm Password) *',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: confirmPasswordController,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        hintText: 'पासवर्ड दोबारा लिखें',
                        prefixIcon: const Icon(Icons.lock_clock_outlined, color: AppColors.primary, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility, size: 18),
                          onPressed: () => setModalState(() => obscureConfirm = !obscureConfirm),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'कृपया पासवर्ड की पुष्टि करें';
                        if (val.trim() != passwordController.text.trim()) return 'दोनों पासवर्ड मैच नहीं कर रहे हैं';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Submit Button
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          if (formKey.currentState?.validate() ?? false) {
                            final email = emailController.text.trim();
                            final pass = passwordController.text.trim();
                            Navigator.pop(ctx);
                            parentContext.read<CustomerAuthBloc>().add(
                                  LinkEmailToPhoneAccountEvent(email: email, password: pass),
                                );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('सुरक्षित लिंक करें (Save & Link)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isDismissed) return const SizedBox.shrink();

    return BlocConsumer<CustomerAuthBloc, CustomerAuthState>(
      listener: (context, state) {
        if (state is CustomerEmailLinkedSuccessState) {
          setState(() => _isDismissed = true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ईमेल ${state.email} सफलतापूर्वक लिंक हो गया! अब आप ईमेल/पासवर्ड से लॉगिन कर सकते हैं।',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      },
      builder: (context, state) {
        if (!_isPhoneOnlyCustomer()) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFFE8F5E9), Colors.green.shade50],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.green.shade200, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.security_update_good_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'खाता सुरक्षित करें — ईमेल व पासवर्ड सेट करें',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'बिना SMS OTP के आसानी से लॉगिन करने के लिए अपना ईमेल जोड़ें।',
                      style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.3),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => _openLinkAccountBottomSheet(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        minimumSize: const Size(80, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('अभी सेट करें (Set Up)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => setState(() => _isDismissed = true),
                tooltip: 'बंद करें',
              ),
            ],
          ),
        );
      },
    );
  }
}
