import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/auth_exception_handler.dart';
import '../../domain/entities/provider_profile_entity.dart';
import '../bloc/provider_auth_bloc.dart';
import '../bloc/provider_auth_event.dart';
import 'provider_register_page.dart';

/// [ProviderAccountRecoveryPage] — Safe recovery & credential linking for existing phone-only providers.
/// Preserves existing Firestore UID, profile, KYC status, subscriptions, and Razorpay payment history.
class ProviderAccountRecoveryPage extends StatefulWidget {
  final String? initialPhoneNumber;

  const ProviderAccountRecoveryPage({super.key, this.initialPhoneNumber});

  @override
  State<ProviderAccountRecoveryPage> createState() => _ProviderAccountRecoveryPageState();
}

class _ProviderAccountRecoveryPageState extends State<ProviderAccountRecoveryPage> {
  final _phoneFormKey = GlobalKey<FormState>();
  final _linkFormKey = GlobalKey<FormState>();

  late TextEditingController _phoneController;
  final _otpController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  bool _isPhoneVerified = false;
  bool _isLinkingCredentials = false;
  bool _obscurePassword = true;

  String? _phoneVerificationId;
  ConfirmationResult? _webConfirmationResult;
  ProviderProfileEntity? _matchedProviderProfile;
  int _secondsRemaining = 0;
  Timer? _countdownTimer;
  RecaptchaVerifier? _webRecaptchaVerifier;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialPhoneNumber?.replaceAll('+91', '').trim() ?? '';
    _phoneController = TextEditingController(text: initial);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _clearWebRecaptcha();
    _phoneController.dispose();
    _otpController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _clearWebRecaptcha() {
    if (kIsWeb) {
      try {
        _webRecaptchaVerifier?.clear();
      } catch (_) {}
      _webRecaptchaVerifier = null;
    }
  }

  void _startTimer() {
    setState(() => _secondsRemaining = 60);
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _countdownTimer?.cancel();
      }
    });
  }

  Future<void> _sendOtp() async {
    FocusScope.of(context).unfocus();
    if (!_phoneFormKey.currentState!.validate()) return;

    final raw = _phoneController.text.trim();
    final clean = raw.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    final digits = clean.length >= 10 ? clean.substring(clean.length - 10) : clean;
    final formattedPhone = '+91$digits';

    setState(() => _isSendingOtp = true);

    try {
      // 1. Verify that this phone number belongs to an existing registered provider in Firestore
      final repo = context.read<ProviderAuthBloc>().providerRepository;
      final profile = await repo.findRegisteredProviderByPhone(formattedPhone);

      if (profile == null) {
        setState(() => _isSendingOtp = false);
        if (!mounted) return;
        _showNoAccountDialog(digits);
        return;
      }

      setState(() {
        _matchedProviderProfile = profile;
        if (profile.email.isNotEmpty && _emailController.text.trim().isEmpty) {
          _emailController.text = profile.email;
        }
      });

      // 2. Send Firebase Phone Auth OTP
      if (kIsWeb) {
        _clearWebRecaptcha();
        _webRecaptchaVerifier = RecaptchaVerifier(
          auth: FirebaseAuthPlatform.instance,
          onSuccess: () => debugPrint('✅ [AccountRecovery] Web invisible reCAPTCHA passed'),
          onError: (err) => debugPrint('❌ [AccountRecovery] Web reCAPTCHA error: $err'),
          onExpired: () => debugPrint('⌛ [AccountRecovery] Web reCAPTCHA expired'),
        );

        _webConfirmationResult = await FirebaseAuth.instance.signInWithPhoneNumber(
          formattedPhone,
          _webRecaptchaVerifier!,
        );

        if (mounted) {
          setState(() {
            _isSendingOtp = false;
            _phoneVerificationId = _webConfirmationResult!.verificationId;
          });
          _startTimer();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('📲 OTP कोड $formattedPhone पर भेजा गया है।'),
              backgroundColor: AppColors.primary,
            ),
          );
        }
        return;
      }

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            final currentUser = FirebaseAuth.instance.currentUser;
            if (currentUser != null) {
              await currentUser.linkWithCredential(credential);
            } else {
              await FirebaseAuth.instance.signInWithCredential(credential);
            }
            if (mounted) {
              setState(() {
                _isPhoneVerified = true;
                _isSendingOtp = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ मोबाइल नंबर स्वतः सत्यापित हो गया!'),
                  backgroundColor: AppColors.success,
                ),
              );
            }
          } catch (e) {
            debugPrint('Auto-verification error: $e');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            setState(() => _isSendingOtp = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('❌ OTP भेजने में विफलता: ${AuthExceptionHandler.handleException(e)}'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            setState(() {
              _isSendingOtp = false;
              _phoneVerificationId = verificationId;
            });
            _startTimer();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('📲 OTP कोड $formattedPhone पर भेजा गया है।'),
                backgroundColor: AppColors.primary,
              ),
            );
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _phoneVerificationId = verificationId;
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSendingOtp = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('त्रुटि: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if ((_phoneVerificationId == null && _webConfirmationResult == null) || otp.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('कृपया 6 अंकों का OTP दर्ज करें।'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isVerifyingOtp = true);

    if (kIsWeb && _webConfirmationResult != null) {
      try {
        await _webConfirmationResult!.confirm(otp);
        if (mounted) {
          setState(() {
            _isPhoneVerified = true;
            _isVerifyingOtp = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 मोबाइल नंबर सफलतापूर्वक सत्यापित हो गया! अब ईमेल व पासवर्ड सेट करें।'),
              backgroundColor: AppColors.success,
            ),
          );
        }
        return;
      } catch (e) {
        if (mounted) {
          setState(() => _isVerifyingOtp = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('अमान्य OTP कोड: $e'), backgroundColor: AppColors.error),
          );
        }
        return;
      }
    }

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _phoneVerificationId!,
        smsCode: otp,
      );

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        try {
          await currentUser.linkWithCredential(credential);
        } on FirebaseAuthException catch (linkErr) {
          if (linkErr.code == 'provider-already-linked' || linkErr.code == 'credential-already-in-use') {
            await FirebaseAuth.instance.signInWithCredential(credential);
          } else {
            rethrow;
          }
        }
      } else {
        await FirebaseAuth.instance.signInWithCredential(credential);
      }

      if (mounted) {
        _countdownTimer?.cancel();
        _clearWebRecaptcha();
        setState(() {
          _isPhoneVerified = true;
          _isVerifyingOtp = false;
          _secondsRemaining = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 मोबाइल नंबर सफलतापूर्वक सत्यापित हो गया! अब ईमेल व पासवर्ड सेट करें।'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isVerifyingOtp = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('अमान्य OTP कोड: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _submitCredentialLinking() async {
    FocusScope.of(context).unfocus();
    if (!_linkFormKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !_isPhoneVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('सत्र समाप्त हो गया है। कृपया OTP पुनः सत्यापित करें।'), backgroundColor: AppColors.error),
      );
      return;
    }

    if (_matchedProviderProfile != null && _matchedProviderProfile!.id != user.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('सुरक्षा त्रुटि: फ़ोन नंबर और ऑथेंटिकेशन खाता मेल नहीं खा रहे हैं।'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    final targetProfileId = user.uid;

    setState(() => _isLinkingCredentials = true);

    try {
      final repo = context.read<ProviderAuthBloc>().providerRepository;
      final updatedProfile = await repo.safeMigratePhoneAccount(
        providerId: targetProfileId,
        email: _emailController.text.trim().toLowerCase(),
        password: _passwordController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isLinkingCredentials = false);

      // Show success dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.verified, color: AppColors.success, size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text('खाता सुरक्षित हो गया!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'बधाई हो ${updatedProfile.businessName}! आपका ईमेल और पासवर्ड आपके प्रोवाइडर खाते से सफलतापूर्वक लिंक कर दिया गया है।',
                style: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('रजिस्टर्ड ईमेल: ${updatedProfile.email}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    const Text('अब आप हर बार सीधे इसी ईमेल और पासवर्ड से बिना OTP के लॉगिन कर सकते हैं।', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                // Trigger auth status check to navigate into main dashboard
                context.read<ProviderAuthBloc>().add(CheckAuthStatusEvent());
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('डैशबोर्ड में प्रवेश करें →', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLinkingCredentials = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showNoAccountDialog(String digits) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
            SizedBox(width: 10),
            Expanded(child: Text('अकाउंट नहीं मिला', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17))),
          ],
        ),
        content: Text(
          'मोबाइल नंबर +91 $digits से कोई सेवा प्रदाता (Provider) खाता पंजीकृत नहीं है।\n\nयदि आप नए कारीगर या सेवा प्रदाता हैं, तो कृपया नया रजिस्ट्रेशन करें।',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ठीक है'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => BlocProvider.value(
                    value: context.read<ProviderAuthBloc>(),
                    child: const ProviderRegisterPage(),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            child: const Text('नया रजिस्ट्रेशन करें', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'प्रोवाइडर खाता रिकवरी एवं पासवर्ड लिंक',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.phonelink_lock_rounded, color: AppColors.primary, size: 36),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'पुराने प्रोवाइडर खातों के लिए पासवर्ड लिंक',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'अपने रजिस्टर्ड मोबाइल नंबर पर OTP प्राप्त कर ईमेल व पासवर्ड सेट करें। आपका पुराना प्रोफाइल व डेटा सुरक्षित रहेगा।',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // STEP 1: Phone OTP Verification
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Form(
                    key: _phoneFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _isPhoneVerified ? Colors.green.shade100 : Colors.blue.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _isPhoneVerified ? Icons.check : Icons.phone_android,
                                color: _isPhoneVerified ? Colors.green : AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'चरण 1: मोबाइल नंबर सत्यापन',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: _isPhoneVerified ? Colors.green.shade800 : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneController,
                          enabled: !_isPhoneVerified && !_isSendingOtp,
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          decoration: InputDecoration(
                            labelText: 'रजिस्टर्ड मोबाइल नंबर (10 Digit)',
                            prefixText: '+91 ',
                            prefixIcon: const Icon(Icons.phone),
                            suffixIcon: _isPhoneVerified
                                ? const Icon(Icons.verified, color: AppColors.success)
                                : null,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'कृपया मोबाइल नंबर दर्ज करें';
                            if (v.trim().length < 10) return '10 अंकों का नंबर लिखें';
                            return null;
                          },
                          onChanged: (val) {
                            if (_isPhoneVerified) {
                              setState(() {
                                _isPhoneVerified = false;
                                _phoneVerificationId = null;
                                _matchedProviderProfile = null;
                              });
                            }
                          },
                        ),

                        if (!_isPhoneVerified) ...[
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: _isSendingOtp ? null : _sendOtp,
                            icon: _isSendingOtp
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.send_rounded, size: 18),
                            label: Text(
                              _secondsRemaining > 0
                                  ? 'पुनः भेजें ($_secondsRemaining s)'
                                  : (_phoneVerificationId == null ? 'OTP भेजें' : 'OTP पुनः भेजें'),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],

                        if (_phoneVerificationId != null && !_isPhoneVerified) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _otpController,
                                  keyboardType: TextInputType.number,
                                  maxLength: 6,
                                  decoration: InputDecoration(
                                    labelText: '6 अंकों का OTP कोड',
                                    prefixIcon: const Icon(Icons.sms_outlined),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                onPressed: _isVerifyingOtp ? null : _verifyOtp,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: _isVerifyingOtp
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Text('सत्यापित करें'),
                              ),
                            ],
                          ),
                        ],

                        if (_matchedProviderProfile != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.amber.shade300),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.storefront_rounded, color: Colors.amber, size: 24),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'पहचाना गया खाता: ${_matchedProviderProfile!.businessName} (${_matchedProviderProfile!.fullName})',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // STEP 2: Email & Password Setup (Active only after OTP verified)
              if (_isPhoneVerified) ...[
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Form(
                      key: _linkFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.lock_outline, color: AppColors.accent, size: 22),
                              SizedBox(width: 10),
                              Text(
                                'चरण 2: ईमेल व पासवर्ड सेट करें',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'ईमेल आईडी (Email ID) *',
                              hintText: 'provider@example.com',
                              prefixIcon: const Icon(Icons.email_outlined),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'कृपया ईमेल दर्ज करें';
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) {
                                return 'कृपया सही ईमेल दर्ज करें';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'नया पासवर्ड (कम से कम 6 अक्षर) *',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'कृपया पासवर्ड दर्ज करें';
                              if (v.trim().length < 6) return 'पासवर्ड कम से कम 6 अक्षरों का होना चाहिए';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'पासवर्ड पुनः दर्ज करें *',
                              prefixIcon: const Icon(Icons.lock_outline),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (v) {
                              if (v != _passwordController.text) {
                                return 'पासवर्ड मेल नहीं खाता है';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          ElevatedButton(
                            onPressed: _isLinkingCredentials ? null : _submitCredentialLinking,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: _isLinkingCredentials
                                ? const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                                      SizedBox(width: 12),
                                      Text('लिंक किया जा रहा है...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                    ],
                                  )
                                : const Text(
                                    'ईमेल व पासवर्ड सुरक्षित लिंक करें →',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
