import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../bloc/provider_auth_bloc.dart';
import '../bloc/provider_auth_event.dart';

class AccountBlockedPage extends StatelessWidget {
  final String reason;

  const AccountBlockedPage({
    super.key,
    this.reason = 'आपका प्रोवाइडर खाता सुरक्षा कारणों से एडमिन द्वारा निलंबित/ब्लॉक कर दिया गया है।',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.block_rounded,
                  size: 72,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'खाता निलंबित / ब्लॉक',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.error,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  reason,
                  style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.4),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'सहायता या स्पष्टीकरण के लिए कृपया JAMUI SERVICE एडमिन सपोर्ट टीम से संपर्क करें।',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: () {
                  context.read<ProviderAuthBloc>().add(SignOutEvent());
                },
                icon: const Icon(Icons.logout, color: AppColors.error),
                label: const Text('साइन आउट करें', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
