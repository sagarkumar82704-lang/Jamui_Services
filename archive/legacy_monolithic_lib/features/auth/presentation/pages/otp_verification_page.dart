import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/utils/ui_helpers.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../domain/entities/user_entity.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

/// [OtpVerificationPage] 6-अंकों के SMS OTP को सत्यापित करने की स्क्रीन है।
class OtpVerificationPage extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;
  final UserRole selectedRole;
  final int? resendToken;

  const OtpVerificationPage({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
    required this.selectedRole,
    this.resendToken,
  });

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  int _resendCountdown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _resendCountdown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _otpCode => _controllers.map((c) => c.text).join();

  void _onVerify() {
    final otp = _otpCode;
    if (otp.length != 6) {
      UIHelpers.showSnackBar(context, message: AppStrings.otpInvalid, isError: true);
      return;
    }

    context.read<AuthBloc>().add(
          VerifyOtpEvent(
            verificationId: widget.verificationId,
            smsCode: otp,
            selectedRole: widget.selectedRole,
          ),
        );
  }

  void _onResend() {
    if (_resendCountdown == 0) {
      context.read<AuthBloc>().add(
            ResendOtpEvent(
              phoneNumber: widget.phoneNumber,
              selectedRole: widget.selectedRole,
              resendToken: widget.resendToken,
            ),
          );
      _startTimer();
    }
  }

  void _routeToDashboard(UserRole role) {
    if (role == UserRole.provider) {
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.providerDashboard, (route) => false);
    } else if (role == UserRole.admin) {
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.adminDashboard, (route) => false);
    } else {
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.customerHome, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthenticatedState) {
            UIHelpers.showSnackBar(context, message: 'सफलतापूर्वक लॉग इन हुए!');
            _routeToDashboard(state.user.role);
          } else if (state is AuthErrorState) {
            UIHelpers.showSnackBar(context, message: state.message, isError: true);
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'OTP दर्ज करें',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'कोड +91 ${widget.phoneNumber} पर भेजा गया है',
                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 36),

                  // 6 Digit OTP Input Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, (index) {
                      return SizedBox(
                        width: 48,
                        height: 56,
                        child: TextFormField(
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(1),
                          ],
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.zero,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onChanged: (value) {
                            if (value.isNotEmpty && index < 5) {
                              _focusNodes[index + 1].requestFocus();
                            } else if (value.isEmpty && index > 0) {
                              _focusNodes[index - 1].requestFocus();
                            }
                            if (_otpCode.length == 6) {
                              _onVerify();
                            }
                          },
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 32),

                  CustomButton(
                    text: AppStrings.verifyOtp,
                    isLoading: isLoading,
                    onPressed: isLoading ? null : _onVerify,
                  ),

                  const SizedBox(height: 24),

                  // Resend Timer Row
                  Center(
                    child: _resendCountdown > 0
                        ? Text(
                            'पुनः कोड भेजें (00:${_resendCountdown.toString().padLeft(2, '0')})',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          )
                        : TextButton.icon(
                            onPressed: _onResend,
                            icon: const Icon(Icons.refresh, size: 16, color: AppColors.primary),
                            label: const Text(
                              AppStrings.resendOtp,
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
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
