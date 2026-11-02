import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/web_host_bridge.dart';
import '../../../../core/widgets/app_logo.dart';
import '../bloc/provider_auth_bloc.dart';
import '../bloc/provider_auth_event.dart';
import '../bloc/provider_auth_state.dart';
import 'provider_forgot_password_page.dart';
import 'provider_register_page.dart';

/// Provider Login Screen
/// Strictly matches the Reference Image (Right Screen: SELLER LOGIN):
/// - Clean white background
/// - Centered Jamui Services Logo
/// - "Jamui Services" branding
/// - "Login to Your Shop" subtitle
/// - Email Address input
/// - Password input with visibility toggle
/// - "Forgot Password?" right-aligned link
/// - Green full-width "Login" button with in-button loader
/// - "New Seller? Register Your Shop" footer navigation
/// - 100% English labels, validations, and dialogs
class ProviderLoginPage extends StatefulWidget {
  const ProviderLoginPage({super.key});

  @override
  State<ProviderLoginPage> createState() => _ProviderLoginPageState();
}

class _ProviderLoginPageState extends State<ProviderLoginPage> {
  static const Color _themeGreen = Color(0xFF1B5E20);

  String? _lastErrorMessage;

  final _emailFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WebHostBridge.notify('PROVIDER_READY');
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitEmailLogin() {
    FocusScope.of(context).unfocus();
    setState(() => _lastErrorMessage = null);
    if (_emailFormKey.currentState?.validate() ?? false) {
      context.read<ProviderAuthBloc>().add(
            LoginWithEmailEvent(
              email: _emailController.text.trim().toLowerCase(),
              password: _passwordController.text.trim(),
            ),
          );
    }
  }

  void _showNotRegisteredDialog(BuildContext context, String identifier, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Account Not Found',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(fontSize: 14, height: 1.4, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: _themeGreen, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'If you are a new seller or service provider, please create a new account to register.',
                      style: TextStyle(fontSize: 12, color: _themeGreen, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BlocProvider.value(
                    value: context.read<ProviderAuthBloc>(),
                    child: const ProviderRegisterPage(),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18, color: Colors.white),
            label: const Text('Register Now', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _themeGreen,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: BlocConsumer<ProviderAuthBloc, ProviderAuthState>(
          listener: (context, state) {
            if (state is ProviderNotRegisteredErrorState) {
              setState(() => _lastErrorMessage = state.message);
              _showNotRegisteredDialog(context, state.phoneNumber, state.message);
            } else if (state is ProviderAuthError) {
              setState(() => _lastErrorMessage = state.message);
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(state.message, style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            } else if (state is ProviderAuthenticated || state is ProviderAccountBlockedState) {
              if (Navigator.canPop(context)) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            }
          },
          builder: (context, state) {
            final isLoading = state is ProviderAuthLoading;

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (Navigator.canPop(context))
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
                          tooltip: 'Back',
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),

                    const SizedBox(height: 10),

                    // Header Logo & Branding matching Reference Image
                    const Center(
                      child: AppLogo(
                        size: 76,
                        showShadow: true,
                        borderRadius: BorderRadius.all(Radius.circular(18)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Jamui Services',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: _themeGreen,
                        letterSpacing: 0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Login to Your Shop',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Inline Error Banner
                    if (_lastErrorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade300),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: AppColors.error,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _lastErrorMessage!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Direct Email & Password Login Form
                    Form(
                      key: _emailFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _emailController,
                            enabled: !isLoading,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Email Address',
                              hintText: 'seller@example.com',
                              prefixIcon: const Icon(Icons.email_outlined, color: _themeGreen),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: _themeGreen, width: 1.8),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) return 'Please enter your email address';
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                                return 'Please enter a valid email address';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            enabled: !isLoading,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              hintText: '••••••••',
                              prefixIcon: const Icon(Icons.lock_outline, color: _themeGreen),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: _themeGreen, width: 1.8),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey.shade600),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Please enter your password';
                              if (value.length < 6) return 'Password must be at least 6 characters';
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const ProviderForgotPasswordPage()),
                                );
                              },
                              child: const Text(
                                'Forgot Password?',
                                style: TextStyle(fontSize: 13.5, color: _themeGreen, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : _submitEmailLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _themeGreen,
                                disabledBackgroundColor: _themeGreen.withValues(alpha: 0.6),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: isLoading
                                  ? const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Text(
                                          'Logging in...',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    )
                                  : const Text(
                                      'Login',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 36),

                    // New Registration Navigation matching Reference Image
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'New Seller? ',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BlocProvider.value(
                                  value: context.read<ProviderAuthBloc>(),
                                  child: const ProviderRegisterPage(),
                                ),
                              ),
                            );
                          },
                          child: const Text(
                            'Register Your Shop',
                            style: TextStyle(
                              color: _themeGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
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
