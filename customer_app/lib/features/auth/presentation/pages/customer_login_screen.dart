import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/provider_app_launcher_service.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../home/presentation/pages/customer_main_shell.dart';
import '../bloc/customer_auth_bloc.dart';
import '../bloc/customer_auth_event.dart';
import '../bloc/customer_auth_state.dart';
import 'customer_profile_setup_screen.dart';
import 'customer_registration_screen.dart';

/// [CustomerLoginScreen]
/// Dedicated 100% Email + Password Authentication for Jamui Services Customer App.
/// Zero Firebase Phone SMS costs. Pure customer role isolated session.
class CustomerLoginScreen extends StatefulWidget {
  const CustomerLoginScreen({super.key});

  @override
  State<CustomerLoginScreen> createState() => _CustomerLoginScreenState();
}

class _CustomerLoginScreenState extends State<CustomerLoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  String? _errorMessage;
  DateTime? _lastBackPressTime;

  // 0 = Login as Customer, 1 = Login as Provider
  int _selectedLoginRoleIndex = 0;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward();

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
    _animController.dispose();
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

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(text: _emailController.text.trim());
    final resetFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.lock_reset_rounded, color: AppColors.primary),
            SizedBox(width: 10),
            Text('पासवर्ड रीसेट करें', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Form(
          key: resetFormKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'अपना पंजीकृत ईमेल पता लिखें। हम आपको पासवर्ड रीसेट करने का लिंक भेजेंगे।',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: resetEmailController,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'उदा. customer@example.com',
                  prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primary, size: 20),
                  filled: true,
                  fillColor: const Color(0xFFF9FBFA),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'कृपया ईमेल पता दर्ज करें';
                  }
                  final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                  if (!regex.hasMatch(val.trim())) {
                    return 'कृपया सही ईमेल पता दर्ज करें';
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
            child: const Text('रद्द करें', style: TextStyle(color: Colors.grey)),
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
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('रीसेट लिंक भेजें'),
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
              content: const Text('ऐप बंद करने के लिए दोबारा बैक बटन दबाएं'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.grey.shade900,
            ),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAF9),
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
                          'पासवर्ड रीसेट लिंक ${state.email} पर भेजा गया। कृपया अपना इनबॉक्स चेक करें।',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: AppColors.primary,
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
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    // Top Hero Branding Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.only(top: 28, bottom: 24, left: 24, right: 24),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary, Color(0xFF0F8A6D)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
                      ),
                      child: Column(
                        children: [
                          const AppLogo(
                            size: 64,
                            showShadow: true,
                            borderRadius: BorderRadius.all(Radius.circular(18)),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'JAMUI SERVICES',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedLoginRoleIndex == 0
                                ? 'ग्राहक लॉगिन — ईमेल व पासवर्ड द्वारा सुरक्षित प्रवेश'
                                : 'सर्विस प्रोवाइडर लॉगिन — पार्टनर पोर्टल',
                            style: TextStyle(
                              fontSize: 13.5,
                              color: Colors.white.withValues(alpha: 0.92),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Main Authentication Card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 18,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(22),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Top Two-Option Role Selector
                                _buildRoleSelector(),
                                const SizedBox(height: 20),

                                if (_selectedLoginRoleIndex == 0)
                                  _buildEmailLoginForm(isLoading, loadingMessage)
                                else
                                  _buildProviderLaunchView(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Trust Badges
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildTrustPill(
                            icon: Icons.verified_user_outlined,
                            text: '100% वेरिफाइड',
                          ),
                          _buildTrustPill(
                            icon: Icons.speed_rounded,
                            text: 'तुरंत सेवा',
                          ),
                          _buildTrustPill(
                            icon: Icons.lock_outline_rounded,
                            text: 'सुरक्षित खाता',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // TOP SEGMENTED ROLE SELECTOR
  Widget _buildRoleSelector() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F3),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          // Option 1: Customer Login
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_selectedLoginRoleIndex != 0) {
                  setState(() {
                    _selectedLoginRoleIndex = 0;
                    _errorMessage = null;
                  });
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedLoginRoleIndex == 0 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: _selectedLoginRoleIndex == 0
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_rounded,
                      size: 17,
                      color: _selectedLoginRoleIndex == 0 ? AppColors.primary : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Login as Customer',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: _selectedLoginRoleIndex == 0 ? FontWeight.bold : FontWeight.w600,
                        color: _selectedLoginRoleIndex == 0 ? AppColors.primary : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Option 2: Provider Login
          Expanded(
            child: GestureDetector(
              onTap: () {
                ProviderAppLauncherService.openProviderLoginWebView(context);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.handyman_rounded,
                      size: 17,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Login as Provider',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // CUSTOMER EMAIL + PASSWORD LOGIN FORM
  Widget _buildEmailLoginForm(bool isLoading, String? loadingMessage) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'ग्राहक लॉगिन (Customer Login)',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'कृपया अपना ईमेल और पासवर्ड दर्ज करें',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),

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

          // Email Field
          const Text(
            'ईमेल पता (Email Address) *',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            enabled: !isLoading,
            decoration: InputDecoration(
              hintText: 'उदा. customer@example.com',
              hintStyle: TextStyle(fontSize: 13.5, color: Colors.grey.shade400),
              prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primary, size: 20),
              filled: true,
              fillColor: const Color(0xFFF9FBFA),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.error),
              ),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'कृपया ईमेल पता दर्ज करें';
              }
              final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
              if (!regex.hasMatch(val.trim())) {
                return 'कृपया सही ईमेल पता दर्ज करें';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Password Field
          const Text(
            'पासवर्ड (Password) *',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            enabled: !isLoading,
            decoration: InputDecoration(
              hintText: 'अपना पासवर्ड लिखें',
              hintStyle: TextStyle(fontSize: 13.5, color: Colors.grey.shade400),
              prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.primary, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Colors.grey.shade600,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              filled: true,
              fillColor: const Color(0xFFF9FBFA),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.error),
              ),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'कृपया पासवर्ड दर्ज करें';
              }
              if (val.trim().length < 6) {
                return 'पासवर्ड कम से कम 6 अक्षरों का होना चाहिए';
              }
              return null;
            },
          ),

          // Forgot Password Row
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: isLoading ? null : _showForgotPasswordDialog,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'पासवर्ड भूल गए? (Forgot Password)',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Login Button
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: isLoading ? null : _submitLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
              ),
              child: isLoading
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          loadingMessage ?? 'लॉगिन हो रहा है...',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.login_rounded, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'लॉगिन करें (Login)',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 20),

          // Don't have an account? Register Now button
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F3),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'नया ग्राहक खाता चाहिए? ',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CustomerRegistrationScreen()),
                    );
                  },
                  child: const Text(
                    'रजिस्टर करें (Register Now)',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // OPTION 2: PROVIDER PORTAL LAUNCH VIEW
  Widget _buildProviderLaunchView() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          const Icon(Icons.handyman_rounded, color: AppColors.primary, size: 40),
          const SizedBox(height: 10),
          const Text(
            'कारीगर व सर्विस पार्टनर पोर्टल',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            'यदि आप प्लंबर, इलेक्ट्रीशियन या अन्य सेवा प्रदाता हैं, तो Jamui Provider पोर्टल खोलें।',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: () {
                ProviderAppLauncherService.openProviderLoginWebView(context);
              },
              icon: const Icon(Icons.open_in_browser_rounded, size: 18),
              label: const Text('कारीगर पोर्टल खोलें', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustPill({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
