import 'package:apna_jamui_provider/features/auth/presentation/bloc/provider_auth_bloc.dart';
import 'package:apna_jamui_provider/features/auth/presentation/bloc/provider_auth_event.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/responsive_layout.dart';
import 'provider_category_selection_page.dart';

/// Screen 1: Seller Registration (Email & Password / Owner Details)
/// Strictly matches the Reference Image (Left Screen):
/// - Green Header '#1B5E20' with Back Arrow, centered "JAMUI SERVICES — PROVIDER APP"
/// - "Create Seller Account" Title
/// - "Step 1 of 3: Owner Details" Subtitle
/// - Full Name
/// - Email Address
/// - Create Password with eye toggle
/// - Confirm Password with eye toggle
/// - Mobile Number (business contact)
/// - "Next: Shop Details" / "Next: Category Selection" action button
/// - "Already have an account? Login" footer link
/// - 100% English UI and error validation
class ProviderRegisterPage extends StatefulWidget {
  const ProviderRegisterPage({super.key});

  @override
  State<ProviderRegisterPage> createState() => _ProviderRegisterPageState();
}

class _ProviderRegisterPageState extends State<ProviderRegisterPage> {
  static const Color _themeGreen = Color(0xFF1B5E20);

  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleRegisterNext() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();
    final phone = _phoneController.text.trim();
    final cleanPhone = phone.startsWith('+91') ? phone : '+91$phone';

    setState(() => _isLoading = true);

    try {
      // 1. Authenticate user: reuse existing session or sign in if already created
      User? user;
      final currentAuthUser = FirebaseAuth.instance.currentUser;
      if (currentAuthUser != null && currentAuthUser.email?.toLowerCase() == email) {
        user = currentAuthUser;
      } else {
        try {
          final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
          user = credential.user;
        } on FirebaseAuthException catch (authErr) {
          if (authErr.code == 'email-already-in-use') {
            // User was created in a previous step attempt; sign in to resume
            try {
              final signInCred = await FirebaseAuth.instance.signInWithEmailAndPassword(
                email: email,
                password: password,
              );
              user = signInCred.user;
            } catch (_) {
              throw 'This email is already registered. Please login with your existing account.';
            }
          } else if (authErr.code == 'weak-password') {
            throw 'The password is too weak. Please use at least 6 characters.';
          } else if (authErr.code == 'invalid-email') {
            throw 'Please enter a valid email address.';
          } else {
            throw authErr.message ?? 'Registration failed. Please try again.';
          }
        }
      }

      if (user == null) throw 'Failed to create or authenticate user account.';

      try {
        await user.updateDisplayName(fullName);
      } catch (_) {}

      // 2. Initialize draft provider profile in Firestore providers/{uid}
      await FirebaseFirestore.instance.collection('providers').doc(user.uid).set({
        'id': user.uid,
        'email': email,
        'phoneNumber': cleanPhone,
        'fullName': fullName,
        'name': fullName,
        'businessName': '',
        'primaryCategoryId': '',
        'primaryCategoryTitle': '',
        'categoryType': 'general',
        'subServices': <String>[],
        'status': 'draft',
        'kycStatus': 'notSubmitted',
        'verificationStatus': 'pending',
        'registrationStatus': 'draft',
        'isVerified': false,
        'isSubscriptionActive': false,
        'paymentVerified': false,
        'subscriptionPlan': 'none',
        'rating': 5.0,
        'ratingCount': 0,
        'currentStep': 1, // Step 1: Category Selection
        'completedSteps': [0],
        'isDeleted': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() => _isLoading = false);

      // 3. Move to Screen 2: Category Selection with Bloc context
      if (mounted) {
        final bloc = context.read<ProviderAuthBloc>();
        bloc.add(CheckAuthStatusEvent());
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: bloc,
              child: ProviderCategorySelectionPage(providerUid: user!.uid),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _themeGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          children: [
            Text(
              'JAMUI SERVICES',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 1),
            Text(
              '— PROVIDER APP',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white70,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveFormShell(
            maxWidth: 500,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                const Text(
                  'Create Seller Account',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Step 1 of 3: Owner Details',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 24),

                // Full Name
                _buildField(
                  controller: _fullNameController,
                  label: 'Full Name',
                  hint: 'Your Name',
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your full name' : null,
                ),
                const SizedBox(height: 16),

                // Email Address
                _buildField(
                  controller: _emailController,
                  label: 'Email Address',
                  hint: 'seller@example.com',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Please enter your email address';
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Create Password
                _buildField(
                  controller: _passwordController,
                  label: 'Create Password',
                  hint: '••••••••',
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey.shade600),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Please enter a password';
                    if (v.length < 6) return 'Password must be at least 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Confirm Password
                _buildField(
                  controller: _confirmPasswordController,
                  label: 'Confirm Password',
                  hint: '••••••••',
                  obscureText: _obscureConfirmPassword,
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey.shade600),
                    onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Please confirm your password';
                    if (v != _passwordController.text) return 'Passwords do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Mobile Number
                _buildField(
                  controller: _phoneController,
                  label: 'Mobile Number (business contact)',
                  hint: '9876543210',
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    final clean = (v ?? '').replaceAll(RegExp(r'\D'), '');
                    if (clean.length < 10) return 'Please enter a valid 10-digit mobile number';
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                // Action Button matching Reference Image
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegisterNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _themeGreen,
                      disabledBackgroundColor: _themeGreen.withValues(alpha: 0.6),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isLoading
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              ),
                              SizedBox(width: 12),
                              Text('Creating Account...', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            ],
                          )
                        : const Text(
                            'Next: Shop Details',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Footer link matching Reference Image
                Center(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                          children: [
                            TextSpan(text: 'Already have an account? '),
                            TextSpan(
                              text: 'Login',
                              style: TextStyle(
                                color: _themeGreen,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
              borderSide: BorderSide(color: _themeGreen, width: 1.8),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}
