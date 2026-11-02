import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../bloc/provider_auth_bloc.dart';
import '../bloc/provider_auth_event.dart';
import '../bloc/provider_auth_state.dart';
import 'provider_account_recovery_page.dart';

class ProviderForgotPasswordPage extends StatefulWidget {
  const ProviderForgotPasswordPage({super.key});

  @override
  State<ProviderForgotPasswordPage> createState() => _ProviderForgotPasswordPageState();
}

class _ProviderForgotPasswordPageState extends State<ProviderForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _sendResetEmail() {
    if (_formKey.currentState!.validate()) {
      context.read<ProviderAuthBloc>().add(
            SendPasswordResetEvent(_emailController.text.trim()),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('पासवर्ड पुनः प्राप्त करें', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: BlocConsumer<ProviderAuthBloc, ProviderAuthState>(
          listener: (context, state) {
            if (state is ProviderPasswordResetSentState) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message), backgroundColor: AppColors.success),
              );
              Navigator.pop(context);
            } else if (state is ProviderAuthError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message), backgroundColor: AppColors.error),
              );
            }
          },
          builder: (context, state) {
            final isLoading = state is ProviderAuthLoading;

            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.lock_reset_rounded, size: 64, color: AppColors.primary),
                    const SizedBox(height: 16),
                    const Text(
                      'पासवर्ड भूल गए?',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'अपना रजिस्टर्ड ईमेल दर्ज करें। हम आपको पासवर्ड रीसेट करने की सुरक्षित लिंक भेजेंगे।',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'रजिस्टर्ड ईमेल आईडी',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'कृपया ईमेल दर्ज करें';
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val.trim())) {
                          return 'वैध ईमेल दर्ज करें';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: isLoading ? null : _sendResetEmail,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('रीसेट लिंक भेजें', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BlocProvider.value(
                              value: context.read<ProviderAuthBloc>(),
                              child: const ProviderAccountRecoveryPage(),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.phonelink_lock_rounded, size: 18),
                      label: const Text(
                        'खाता केवल मोबाइल नंबर से है? OTP से पासवर्ड लिंक करें',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
