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

/// [PhoneLoginPage] फोन नंबर दर्ज करने की स्क्रीन है।
class PhoneLoginPage extends StatefulWidget {
  final UserRole selectedRole;

  const PhoneLoginPage({
    super.key,
    required this.selectedRole,
  });

  @override
  State<PhoneLoginPage> createState() => _PhoneLoginPageState();
}

class _PhoneLoginPageState extends State<PhoneLoginPage> {
  final TextEditingController _phoneController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _onSendOtp() {
    if (_formKey.currentState?.validate() ?? false) {
      final phone = _phoneController.text.trim();
      context.read<AuthBloc>().add(
            SendOtpEvent(
              phoneNumber: phone,
              selectedRole: widget.selectedRole,
            ),
          );
    }
  }

  String _getRoleLabel() {
    switch (widget.selectedRole) {
      case UserRole.customer:
        return 'ग्राहक (Customer)';
      case UserRole.provider:
        return 'सर्विस प्रोवाइडर (Service Provider)';
      case UserRole.admin:
        return 'व्यवस्थापक (Admin)';
      default:
        return 'उपयोगकर्ता';
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
          if (state is OtpSentState) {
            UIHelpers.showSnackBar(context, message: 'OTP सफलतापूर्वक भेजा गया!');
            Navigator.of(context).pushNamed(
              AppRoutes.otpVerification,
              arguments: {
                'verificationId': state.verificationId,
                'phoneNumber': state.phoneNumber,
                'selectedRole': state.selectedRole,
                'resendToken': state.resendToken,
              },
            );
          } else if (state is AuthErrorState) {
            UIHelpers.showSnackBar(context, message: state.message, isError: true);
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Role Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _getRoleLabel(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'अपना मोबाइल नंबर दर्ज करें',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'हम आपके नंबर पर 6 अंकों का सत्यापन कोड (OTP) भेजेंगे।',
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 36),

                    // Phone Input Field with Indian Flag (+91)
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        letterSpacing: 1.5,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().length != 10) {
                          return AppStrings.phoneInvalid;
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        hintText: '98765 43210',
                        hintStyle: const TextStyle(letterSpacing: 0, color: AppColors.textMuted),
                        prefixIcon: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('🇮🇳', style: TextStyle(fontSize: 18)),
                              SizedBox(width: 8),
                              Text(
                                '+91',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(width: 8),
                              SizedBox(
                                height: 20,
                                child: VerticalDivider(color: AppColors.border, width: 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    CustomButton(
                      text: 'OTP प्राप्त करें',
                      isLoading: isLoading,
                      onPressed: isLoading ? null : _onSendOtp,
                    ),

                    const SizedBox(height: 24),

                    // Terms Note
                    const Center(
                      child: Text(
                        'आगे बढ़कर आप JAMUI SERVICE के नियम और शर्तों से सहमत होते हैं।',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.4),
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
}
