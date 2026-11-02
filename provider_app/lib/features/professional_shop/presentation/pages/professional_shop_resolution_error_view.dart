import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../auth/domain/entities/provider_profile_entity.dart';
import '../../../auth/presentation/bloc/provider_auth_bloc.dart';
import '../../../auth/presentation/bloc/provider_auth_event.dart';
import 'professional_shop_registration_page.dart';

/// 🛡️ PROFESSIONAL SHOP OWNERSHIP CONFLICT & RESOLUTION SCREEN
/// Renders safely when an authenticated user is marked as a Professional Seller,
/// but a valid shop record with matching `ownerUid == currentUser.uid` cannot be resolved.
/// STRICT GUARANTEE: Never leaks another vendor's store, and NEVER falls back to normal plumber leads.
class ProfessionalShopResolutionErrorView extends StatelessWidget {
  final ProviderProfileEntity profile;
  final VoidCallback? onRetry;

  const ProfessionalShopResolutionErrorView({
    super.key,
    required this.profile,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: const AppLogo(size: 32),
        ),
        title: const Text(
          'Jamui Services Partner',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'लॉग आउट',
            icon: const Icon(Icons.logout_rounded, color: Color(0xFF64748B)),
            onPressed: () {
              context.read<ProviderAuthBloc>().add(SignOutEvent());
            },
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Security / Alert Icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFECACA), width: 2),
                ),
                child: const Icon(
                  Icons.store_mall_directory_outlined,
                  color: Color(0xFFDC2626),
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                'दुकान का विवरण अधूरा है',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),

              // Explanation
              Text(
                'आपका खाता एक प्रोफेशनल सेलर के रूप में पंजीकृत है, परंतु आपकी दुकान का आधिकारिक डेटा या स्वामित्व सत्यापन लिंक नहीं हो सका।',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'User ID: ${profile.id}',
                  style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.grey.shade800),
                ),
              ),
              const SizedBox(height: 28),

              // Action 1: Complete / Re-link Shop Registration
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfessionalShopRegistrationPage(
                          initialEmail: profile.email,
                          initialPhone: profile.phoneNumber,
                          initialFullName: profile.fullName,
                          selectedCategoryId: profile.primaryCategoryId.isNotEmpty ? profile.primaryCategoryId : 'cat_grocery',
                          selectedCategoryTitle: profile.primaryCategoryTitle.isNotEmpty ? profile.primaryCategoryTitle : 'Grocery',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_business_rounded, color: Colors.white, size: 20),
                  label: const Text(
                    'दुकान का विवरण पूरा करें (Complete Setup)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Action 2: Retry Verification
              if (onRetry != null)
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0F766E), size: 18),
                    label: const Text(
                      'पुनः प्रयास करें (Retry Verification)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F766E)),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF0F766E)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              const SizedBox(height: 12),

              // Action 3: Contact Support
              SizedBox(
                width: double.infinity,
                height: 44,
                child: TextButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Jamui Services एडमिन सहायता: +91 98765 43210'),
                        backgroundColor: Color(0xFF0F766E),
                      ),
                    );
                  },
                  icon: const Icon(Icons.headset_mic_rounded, color: Color(0xFF475569), size: 18),
                  label: const Text(
                    'सपोर्ट टीम से संपर्क करें',
                    style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

