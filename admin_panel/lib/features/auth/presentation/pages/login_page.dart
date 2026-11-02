import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_logo.dart';
import '../bloc/admin_auth_bloc.dart';
import '../bloc/admin_auth_event.dart';
import '../bloc/admin_auth_state.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    context.read<AdminAuthBloc>().add(
          LoginEvent(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          ),
        );
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(text: _emailController.text.trim());
    final resetFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_reset_rounded, color: AppColors.primary, size: 26),
            SizedBox(width: 10),
            Text('पासवर्ड रीसेट करें (Reset Password)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Form(
          key: resetFormKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'अपना पंजीकृत एडमिन ईमेल दर्ज करें। पासवर्ड रीसेट करने का सुरक्षित लिंक आपके ईमेल पर भेज दिया जाएगा।',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: resetEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'एडमिन ईमेल',
                  hintText: 'admin@jamuiservice.com',
                  prefixIcon: Icon(Icons.email_outlined, size: 20),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'ईमेल दर्ज करें';
                  if (!v.contains('@')) return 'वैध ईमेल पता दर्ज करें';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('रद्द करें (Cancel)'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              if (resetFormKey.currentState?.validate() ?? false) {
                final email = resetEmailController.text.trim();
                Navigator.pop(dialogCtx);
                context.read<AdminAuthBloc>().add(ResetPasswordEvent(email: email));
              }
            },
            icon: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
            label: const Text('रीसेट लिंक भेजें', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.sidebarBackground,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Container(
            width: 440,
            padding: const EdgeInsets.all(36),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppLogo(
                    size: 80,
                    borderRadius: BorderRadius.all(Radius.circular(18)),
                    showShadow: true,
                  ),
                  const SizedBox(height: 16),
                  Text('JAMUI SERVICE', style: AppTextStyles.h1),
                  const SizedBox(height: 4),
                  Text(
                    'Master Administration Portal',
                    style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),

                  // Security notice badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.sidebarBackground.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.shield_outlined, size: 20, color: AppColors.primary),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'यह एक निजी व सुरक्षित एडमिन पोर्टल है। केवल अधिकृत एडमिन ही लॉगिन कर सकते हैं।',
                            style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  BlocConsumer<AdminAuthBloc, AdminAuthState>(
                    listener: (context, state) {
                      if (state is AdminAuthError) {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Expanded(child: Text(state.message)),
                              ],
                            ),
                            backgroundColor: AppColors.danger,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      } else if (state is PasswordResetSent) {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Expanded(child: Text(state.message)),
                              ],
                            ),
                            backgroundColor: AppColors.success,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      }
                    },
                    builder: (context, state) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Admin Email',
                              hintText: 'admin@jamuiservice.com',
                              prefixIcon: Icon(Icons.email_outlined, size: 20),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'कृपया एडमिन ईमेल दर्ज करें';
                              if (!v.contains('@')) return 'कृपया वैध ईमेल पता दर्ज करें';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Password (पासवर्ड)',
                              prefixIcon: const Icon(Icons.lock_outline, size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                  size: 18,
                                ),
                                onPressed: () {
                                  setState(() => _obscurePassword = !_obscurePassword);
                                },
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'कृपया पासवर्ड दर्ज करें';
                              return null;
                            },
                            onFieldSubmitted: (_) => _submit(),
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _showForgotPasswordDialog,
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              ),
                              child: const Text(
                                'पासवर्ड भूल गए? (Forgot Password)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: state is AdminAuthLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: state is AdminAuthLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(
                                    'लॉगिन करें (Sign In to Dashboard)',
                                    style: AppTextStyles.bodyBold.copyWith(color: Colors.white),
                                  ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock_outline, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Secure Enterprise 256-bit Encrypted Portal',
                          style: AppTextStyles.caption.copyWith(fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
