import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../bloc/provider_auth_bloc.dart';
import '../bloc/provider_auth_event.dart';
import '../bloc/provider_auth_state.dart';
import 'provider_register_page.dart';

class ProviderOtpScreen extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;

  const ProviderOtpScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
  });

  @override
  State<ProviderOtpScreen> createState() => _ProviderOtpScreenState();
}

class _ProviderOtpScreenState extends State<ProviderOtpScreen> {
  final TextEditingController _otpController = TextEditingController();
  int _secondsRemaining = 60;
  Timer? _timer;
  String? _lastErrorMessage;
  late String _currentVerificationId;

  @override
  void initState() {
    super.initState();
    _currentVerificationId = widget.verificationId;
    _startTimer();
  }

  void _startTimer() {
    _secondsRemaining = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _onVerifyOtp() {
    FocusScope.of(context).unfocus();
    final code = _otpController.text.trim();
    if (code.length == 6) {
      setState(() => _lastErrorMessage = null);
      context.read<ProviderAuthBloc>().add(
            VerifyProviderOtpEvent(
              verificationId: _currentVerificationId,
              smsCode: code,
            ),
          );
    } else {
      setState(() {
        _lastErrorMessage = 'कृपया 6 अंकों का सही OTP कोड दर्ज करें।';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('कृपया 6 अंकों का सही OTP कोड दर्ज करें'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _onResendOtp() {
    if (_secondsRemaining == 0) {
      setState(() {
        _lastErrorMessage = null;
        _otpController.clear();
      });
      context.read<ProviderAuthBloc>().add(SendProviderOtpEvent(widget.phoneNumber));
      _startTimer();
    }
  }

  void _showNotRegisteredDialog(BuildContext context, String phoneNumber, String message) {
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
                'अकाउंट नहीं मिला',
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
              style: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'यदि आप नए कारीगर या सर्विस प्रोवाइडर हैं, तो नीचे दिए बटन से तुरंत नया रजिस्ट्रेशन करें।',
                      style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pop(); // Back to login page
            },
            child: const Text('दूसरा नंबर डालें', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton.icon(
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
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18, color: Colors.white),
            label: const Text('नया रजिस्ट्रेशन करें', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'OTP सत्यापन',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: BlocConsumer<ProviderAuthBloc, ProviderAuthState>(
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
          } else if (state is ProviderOtpSentState) {
            setState(() {
              _currentVerificationId = state.verificationId;
              _lastErrorMessage = null;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('नया OTP आपके नंबर ${widget.phoneNumber} पर भेज दिया गया है।'),
                backgroundColor: Colors.green.shade700,
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (state is ProviderAuthenticated ||
              state is ProviderAccountBlockedState) {
            // Pop back to root router screen
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        },
        builder: (context, state) {
          final isLoading = state is ProviderAuthLoading;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.message_rounded,
                        size: 38,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'सुरक्षा कोड (OTP) दर्ज करें',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'मोबाइल: ${widget.phoneNumber}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: isLoading ? null : () => Navigator.of(context).pop(),
                        child: const Text(
                          '(बदलें)',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.accent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
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
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _lastErrorMessage!));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('तकनीकी त्रुटि (Technical Error) क्लिपबोर्ड पर कॉपी हो गई है।'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.copy_rounded, size: 14, color: AppColors.error),
                              label: const Text(
                                'त्रुटि कॉपी करें (Copy Details)',
                                style: TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.bold),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.red.shade300),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // OTP Input
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _lastErrorMessage != null ? AppColors.error : AppColors.border,
                        width: _lastErrorMessage != null ? 1.5 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _otpController,
                      enabled: !isLoading,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 14,
                        color: AppColors.textPrimary,
                      ),
                      decoration: const InputDecoration(
                        counterText: '',
                        hintText: '••••••',
                        hintStyle: TextStyle(
                          letterSpacing: 14,
                          color: AppColors.textMuted,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 16),
                      ),
                      onChanged: (val) {
                        if (val.trim().length == 6 && !isLoading) {
                          _onVerifyOtp();
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Verify Button with Spinner
                  ElevatedButton(
                    onPressed: isLoading ? null : _onVerifyOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
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
                                'सत्यापित किया जा रहा है...',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          )
                        : const Text(
                            'सत्यापित करें एवं आगे बढ़ें →',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  const SizedBox(height: 20),

                  // Resend Timer & Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _secondsRemaining > 0
                            ? 'पुनः कोड भेजें ($_secondsRemaining सेकंड)'
                            : 'कोड नहीं मिला? ',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (_secondsRemaining == 0)
                        TextButton(
                          onPressed: isLoading ? null : _onResendOtp,
                          child: const Text(
                            'पुनः OTP भेजें',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.accent,
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
    );
  }
}

