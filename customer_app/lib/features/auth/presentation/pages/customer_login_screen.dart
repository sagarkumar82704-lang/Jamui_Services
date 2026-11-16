import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/provider_app_launcher_service.dart';
import '../../../home/presentation/pages/customer_main_shell.dart';
import '../bloc/customer_auth_bloc.dart';
import '../bloc/customer_auth_event.dart';
import '../bloc/customer_auth_state.dart';
import 'customer_profile_setup_screen.dart';

/// [CustomerLoginScreen]
/// Pixel-perfect implementation matching `jamui-login-v2.svg` design:
/// - Screen 1: "Create your account" (Sign Up)
/// - Screen 2: "Welcome back" (Log In)
/// Preserves 100% of existing authentication logic, controllers,
/// bloc events, navigation routes, and provider separation.
class CustomerLoginScreen extends StatefulWidget {
  final bool initialIsSignUp;

  const CustomerLoginScreen({
    super.key,
    this.initialIsSignUp = true,
  });

  @override
  State<CustomerLoginScreen> createState() => _CustomerLoginScreenState();
}

class _CustomerLoginScreenState extends State<CustomerLoginScreen> {
  // Theme Palette derived from jamui-login-v2.svg
  static const Color _cardBgColor = Color(0xFFFBF6EA);
  static const Color _canvasBgColor = Color(0xFFE9E2CF);
  static const Color _cardBorderColor = Color(0xFFCFC6AE);
  static const Color _primaryGreen = Color(0xFF1F4D3A);
  static const Color _accentOrange = Color(0xFFF28C28);
  static const Color _burntOrange = Color(0xFFB35A08);
  static const Color _subtitleColor = Color(0xFF6B6B5E);
  static const Color _fieldBorderColor = Color(0xFFDDD3BA);
  static const Color _placeholderColor = Color(0xFF7C7C6C);
  static const Color _switchTextColor = Color(0xFF5A5A4E);

  final _formKey = GlobalKey<FormState>();

  // Input Controllers
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  late bool _isSignUp;
  bool _obscurePassword = true;
  String? _errorMessage;
  DateTime? _lastBackPressTime;

  @override
  void initState() {
    super.initState();
    _isSignUp = widget.initialIsSignUp;

    // Verify existing active session on mount
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && mounted) {
          context.read<CustomerAuthBloc>().add(const CheckCustomerAuthStatusEvent());
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitLogin() {
    FocusScope.of(context).unfocus();
    setState(() => _errorMessage = null);

    if (_formKey.currentState?.validate() ?? false) {
      context.read<CustomerAuthBloc>().add(
            SignInWithEmailEvent(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
            ),
          );
    }
  }

  void _submitRegistration() {
    FocusScope.of(context).unfocus();
    setState(() => _errorMessage = null);

    if (_formKey.currentState?.validate() ?? false) {
      final rawPhone = _phoneController.text.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
      final formattedPhone = rawPhone.startsWith('+91')
          ? rawPhone
          : (rawPhone.length == 10 ? '+91$rawPhone' : rawPhone);

      context.read<CustomerAuthBloc>().add(
            RegisterWithEmailEvent(
              fullName: _fullNameController.text.trim(),
              phoneNumber: formattedPhone,
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
            ),
          );
    }
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(text: _emailController.text.trim());
    final resetFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: _cardBorderColor, width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.lock_reset_rounded, color: _primaryGreen),
            SizedBox(width: 10),
            Text(
              'Forgot password?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: _primaryGreen,
              ),
            ),
          ],
        ),
        content: Form(
          key: resetFormKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter your registered email address to receive a secure password reset link.',
                style: TextStyle(fontSize: 13, color: _subtitleColor, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: resetEmailController,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                style: const TextStyle(fontSize: 14, color: _primaryGreen),
                decoration: InputDecoration(
                  hintText: 'Email address',
                  hintStyle: const TextStyle(fontSize: 14, color: _placeholderColor),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _fieldBorderColor, width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _fieldBorderColor, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _primaryGreen, width: 2),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter your email';
                  }
                  final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                  if (!regex.hasMatch(val.trim())) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: _subtitleColor)),
          ),
          ElevatedButton(
            onPressed: () {
              if (resetFormKey.currentState?.validate() ?? false) {
                final email = resetEmailController.text.trim();
                Navigator.pop(ctx);
                context.read<CustomerAuthBloc>().add(SendPasswordResetEvent(email));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: const Text('Send Reset Link', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Press back again to exit'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              backgroundColor: _primaryGreen,
            ),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: _canvasBgColor,
        body: BlocConsumer<CustomerAuthBloc, CustomerAuthState>(
          listener: (context, state) {
            if (state is CustomerAuthenticatedState) {
              setState(() => _errorMessage = null);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const CustomerMainShell()),
                (route) => false,
              );
            } else if (state is CustomerProfileSetupRequiredState) {
              setState(() => _errorMessage = null);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => CustomerProfileSetupScreen(
                    userId: state.userId,
                    email: state.email,
                    phoneNumber: state.phoneNumber,
                  ),
                ),
              );
            } else if (state is CustomerPasswordResetSentState) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.mark_email_read_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Password reset link sent to ${state.email}. Check your inbox.',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: _primaryGreen,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  duration: const Duration(seconds: 5),
                ),
              );
            } else if (state is CustomerAuthFailureState) {
              setState(() => _errorMessage = state.errorMessage);
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(state.errorMessage, style: const TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            }
          },
          builder: (context, state) {
            final isLoading = state is CustomerAuthLoadingState;
            final loadingMessage = state is CustomerAuthLoadingState ? state.message : null;

            return SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWideScreen = constraints.maxWidth > 480;

                  return Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        vertical: isWideScreen ? 24 : 0,
                        horizontal: isWideScreen ? 16 : 0,
                      ),
                      child: Container(
                        width: isWideScreen ? 380 : double.infinity,
                        constraints: const BoxConstraints(maxWidth: 420),
                        decoration: BoxDecoration(
                          color: _cardBgColor,
                          borderRadius: BorderRadius.circular(isWideScreen ? 36 : 0),
                          border: isWideScreen
                              ? Border.all(color: _cardBorderColor, width: 2)
                              : null,
                          boxShadow: isWideScreen
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                ]
                              : null,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 1. Brand Logo & Name Header
                              _buildLogoHeader(),

                              const SizedBox(height: 38),

                              // 2. Heading & Subtitle
                              Text(
                                _isSignUp ? 'Create your account' : 'Welcome back',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  color: _primaryGreen,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _isSignUp
                                    ? 'Book trusted services near you'
                                    : 'Log in to continue',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: _subtitleColor,
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Error Banner
                              if (_errorMessage != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.red.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          style: TextStyle(color: Colors.red.shade800, fontSize: 12.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // 3. Form Input Fields
                              if (_isSignUp) ...[
                                // Full name
                                _buildInputField(
                                  controller: _fullNameController,
                                  hintText: 'Full name',
                                  keyboardType: TextInputType.name,
                                  enabled: !isLoading,
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Please enter your full name';
                                    }
                                    if (val.trim().length < 2) {
                                      return 'Name must be at least 2 characters';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),

                                // Mobile number
                                _buildInputField(
                                  controller: _phoneController,
                                  hintText: 'Mobile number',
                                  keyboardType: TextInputType.phone,
                                  enabled: !isLoading,
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Please enter your mobile number';
                                    }
                                    final digits = val.replaceAll(RegExp(r'\D'), '');
                                    if (digits.length < 10) {
                                      return 'Please enter a valid 10-digit number';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                              ],

                              // Email
                              _buildInputField(
                                controller: _emailController,
                                hintText: 'Email',
                                keyboardType: TextInputType.emailAddress,
                                enabled: !isLoading,
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Please enter your email';
                                  }
                                  final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                                  if (!regex.hasMatch(val.trim())) {
                                    return 'Please enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),

                              // Password (with Show/Hide)
                              _buildInputField(
                                controller: _passwordController,
                                hintText: 'Password',
                                obscureText: _obscurePassword,
                                enabled: !isLoading,
                                suffix: GestureDetector(
                                  onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 16),
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      widthFactor: 1,
                                      child: Text(
                                        _obscurePassword ? 'Show' : 'Hide',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: _burntOrange,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Please enter your password';
                                  }
                                  if (val.trim().length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                  return null;
                                },
                              ),

                              // Forgot Password (only in Log in view)
                              if (!_isSignUp) ...[
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: GestureDetector(
                                    onTap: isLoading ? null : _showForgotPasswordDialog,
                                    child: const Text(
                                      'Forgot password?',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _burntOrange,
                                      ),
                                    ),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 24),

                              // 4. Primary Button (Pill shape, 52px height)
                              SizedBox(
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: isLoading
                                      ? null
                                      : (_isSignUp ? _submitRegistration : _submitLogin),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _primaryGreen,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(26),
                                    ),
                                  ),
                                  child: isLoading
                                      ? Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              loadingMessage ?? (_isSignUp ? 'Creating account...' : 'Logging in...'),
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        )
                                      : Text(
                                          _isSignUp ? 'Create account' : 'Log in',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // 5. Switch prompt link
                              Center(
                                child: GestureDetector(
                                  onTap: isLoading
                                      ? null
                                      : () {
                                          setState(() {
                                            _isSignUp = !_isSignUp;
                                            _errorMessage = null;
                                          });
                                        },
                                  child: RichText(
                                    text: TextSpan(
                                      text: _isSignUp
                                          ? 'Already have an account? '
                                          : 'New here? ',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: _switchTextColor,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: _isSignUp ? 'Log in' : 'Create account',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: _burntOrange,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 44),

                              // 6. Partner Portal Card (Orange #F28C28)
                              _buildPartnerPortalCard(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  // BRAND LOGO & TITLE
  Widget _buildLogoHeader() {
    return Row(
      children: [
        // Green square badge (44x44, rx=12) with orange "J"
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _primaryGreen,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: const Text(
            'J',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: _accentOrange,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          'Jamui Services',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _primaryGreen,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  // INPUT TEXT FIELD COMPONENT MATCHING SVG SPECS
  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    bool enabled = true,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      enabled: enabled,
      style: const TextStyle(
        fontSize: 14,
        color: _primaryGreen,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          fontSize: 14,
          color: _placeholderColor,
          fontWeight: FontWeight.normal,
        ),
        filled: true,
        fillColor: Colors.white,
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _fieldBorderColor, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _fieldBorderColor, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _primaryGreen, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 1.8),
        ),
      ),
      validator: validator,
    );
  }

  // BOTTOM PARTNER PORTAL CARD
  Widget _buildPartnerPortalCard() {
    return GestureDetector(
      onTap: () {
        ProviderAppLauncherService.openProviderLoginWebView(context);
      },
      child: Container(
        height: 84,
        decoration: BoxDecoration(
          color: _accentOrange,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Partner Portal',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _primaryGreen,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Shop owner or service provider? Log in here',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: _primaryGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
