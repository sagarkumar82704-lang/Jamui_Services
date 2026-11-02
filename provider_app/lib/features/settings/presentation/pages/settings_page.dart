import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_image_utils.dart';
import '../../../auth/domain/entities/provider_profile_entity.dart';
import '../../../auth/presentation/bloc/provider_auth_bloc.dart';
import '../../../auth/presentation/bloc/provider_auth_event.dart';
import '../../../../core/services/web_host_bridge.dart';
import 'provider_business_profile_screen.dart';
import 'provider_edit_profile_page.dart';
import '../../../location/data/datasources/location_local_data_source.dart';
import '../../../location/data/datasources/location_remote_data_source.dart';
import '../../../location/data/repositories/location_repository_impl.dart';
import '../../../location/domain/entities/provider_location_entity.dart';
import '../../../location/presentation/bloc/location_bloc.dart';
import '../../../location/presentation/pages/provider_location_picker_screen.dart';

class SettingsPage extends StatelessWidget {
  final ProviderProfileEntity profile;

  const SettingsPage({super.key, required this.profile});

  Future<void> _openLocationPicker(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final repo = LocationRepositoryImpl(
      remoteDataSource: LocationRemoteDataSourceImpl(),
      localDataSource: LocationLocalDataSourceImpl(prefs: prefs),
    );

    if (!context.mounted) return;

    final result = await Navigator.push<ProviderLocationEntity>(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider<LocationBloc>(
          create: (_) => LocationBloc(locationRepository: repo),
          child: ProviderLocationPickerScreen(
            initialRadiusKm: profile.serviceRadiusKm > 0 ? profile.serviceRadiusKm : 10.0,
            initialLocation: ProviderLocationEntity(
              latitude: profile.latitude,
              longitude: profile.longitude,
              placeName: profile.jamuiArea,
              formattedAddress: profile.fullAddress,
              city: 'Jamui',
              district: 'Jamui',
              state: 'Bihar',
              pincode: '811307',
              serviceRadiusKm: profile.serviceRadiusKm > 0 ? profile.serviceRadiusKm : 10.0,
              timestamp: DateTime.now(),
            ),
          ),
        ),
      ),
    );

    if (result != null && context.mounted) {
      final updated = profile.copyWith(
        latitude: result.latitude,
        longitude: result.longitude,
        jamuiArea: result.placeName.isNotEmpty ? result.placeName : profile.jamuiArea,
        fullAddress: result.formattedAddress.isNotEmpty ? result.formattedAddress : profile.fullAddress,
        serviceRadiusKm: result.serviceRadiusKm,
      );
      context.read<ProviderAuthBloc>().add(UpdateProviderProfileEvent(updated));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ नई सर्विस लोकेशन (${result.placeName}) व दायरा (${result.serviceRadiusKm.toInt()} KM) अपडेट हो गया!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('खाता व ऐप सेटिंग्स', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Summary Card
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BlocProvider.value(
                    value: context.read<ProviderAuthBloc>(),
                    child: ProviderEditProfilePage(profile: profile),
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    backgroundImage: AppImageUtils.getImageProvider(profile.profileImageUrl),
                    onBackgroundImageError: profile.profileImageUrl.isNotEmpty
                        ? (e, s) => debugPrint('Settings avatar load notice: $e')
                        : null,
                    child: profile.profileImageUrl.isEmpty
                        ? const Icon(Icons.person, color: AppColors.primary, size: 32)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profile.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(profile.phoneNumber, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        Text(profile.email.isNotEmpty ? profile.email : 'ईमेल दर्ज नहीं है', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit_rounded, color: AppColors.primary, size: 18),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Business Profile Showcase Card (Unisex Salon / Premium Category)
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BlocProvider.value(
                    value: context.read<ProviderAuthBloc>(),
                    child: ProviderBusinessProfileScreen(profile: profile),
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E1B2E), Color(0xFF2D2545)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E1B2E).withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: profile.isUnisexSalon
                            ? Colors.pinkAccent.withValues(alpha: 0.3)
                            : const Color(0xFF60A5FA).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Icon(
                      profile.isUnisexSalon ? Icons.content_cut_rounded : Icons.storefront_rounded,
                      color: profile.isUnisexSalon ? Colors.pinkAccent : const Color(0xFF60A5FA),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              profile.isUnisexSalon
                                  ? 'Unisex Salon Profile'
                                  : (profile.resolvedCategoryTitle.isNotEmpty
                                      ? '${profile.resolvedCategoryTitle} प्रोफाइल'
                                      : 'Business Profile'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                              ),
                            ),
                            if (profile.isPremiumApprovedAndLive) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'PREMIUM',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 8.5,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          profile.businessName.trim().isNotEmpty
                              ? profile.businessName.trim()
                              : 'बिजनेस प्रोफाइल व गैलरी देखें',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          _buildSectionTitle('व्यवसाय व प्रोफाइल प्रबन्धन'),
          _buildSettingsItem(
            icon: Icons.storefront_rounded,
            title: 'बिजनेस प्रोफाइल (Business Profile)',
            subtitle: 'प्रीमियम बिजनेस कार्ड, फोटो गैलरी व सोशल लिंक्स',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BlocProvider.value(
                    value: context.read<ProviderAuthBloc>(),
                    child: ProviderBusinessProfileScreen(profile: profile),
                  ),
                ),
              );
            },
          ),
          _buildSettingsItem(
            icon: Icons.edit_note_rounded,
            title: 'प्रोफाइल संपादित करें (Edit Profile)',
            subtitle: 'व्यापार विवरण, सेवा श्रेणियां व पता अपडेट करें',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BlocProvider.value(
                    value: context.read<ProviderAuthBloc>(),
                    child: ProviderEditProfilePage(profile: profile),
                  ),
                ),
              );
            },
          ),
          _buildSettingsItem(
            icon: Icons.map_outlined,
            title: 'सर्विस लोकेशन व मैप (Google Maps Location)',
            subtitle: '${profile.jamuiArea.isNotEmpty ? profile.jamuiArea : 'जमुई'} | दायरा: ${profile.serviceRadiusKm.toInt()} KM',
            onTap: () => _openLocationPicker(context),
          ),
          const SizedBox(height: 12),

          _buildSectionTitle('खाता सुरक्षा व गोपनीयता'),
          _buildSettingsItem(
            icon: Icons.lock_outline,
            title: 'पासवर्ड बदलें',
            subtitle: 'ईमेल रीसेट लिंक भेजें',
            onTap: () {
              if (profile.email.isNotEmpty) {
                context.read<ProviderAuthBloc>().add(SendPasswordResetEvent(profile.email));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('पासवर्ड रीसेट लिंक आपके ईमेल (${profile.email}) पर भेज दी गई है।'), backgroundColor: AppColors.success),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('कृपया अपनी प्रोफाइल में ईमेल अपडेट करें।'), backgroundColor: AppColors.error),
                );
              }
            },
          ),
          _buildSettingsItem(
            icon: Icons.privacy_tip_outlined,
            title: 'गोपनीयता नीति (Privacy Policy)',
            subtitle: 'डेटा सुरक्षा और उपयोग शर्तें पढ़ें',
            onTap: () => _openWebUrl('https://jamui-services.web.app/#provider-policy'),
          ),

          const SizedBox(height: 16),
          _buildSectionTitle('ऐप सहायता व शर्तें'),
          _buildSettingsItem(
            icon: Icons.help_outline,
            title: 'नियम व शर्तें (Terms & Conditions)',
            subtitle: 'JAMUI SERVICE पार्टनर सर्विस एग्रीमेंट',
            onTap: () => _openWebUrl('https://jamui-services.web.app/#terms'),
          ),

          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => _handleSignOut(context),
            icon: const Icon(Icons.logout, color: AppColors.error),
            label: const Text('साइन आउट करें (Sign Out)', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: AppColors.error),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),

          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => _showDeleteProviderAccountDialog(context, profile.id),
            icon: Icon(Icons.delete_forever_rounded, color: Colors.red.shade700, size: 20),
            label: Text(
              'प्रोफाइल व खाता हमेशा के लिए हटाएं (Delete Profile)',
              style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600, fontSize: 13),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openWebUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  Future<void> _showDeleteProviderAccountDialog(BuildContext context, String providerId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 26),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'पार्टनर खाता हटाने की पुष्टि',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: const Text(
          'क्या आप वाकई अपनी Jamui Services पार्टनर प्रोफाइल और खाता स्थायी रूप से हटाना चाहते हैं?\n\n'
          '⚠️ चेतावनी: आपकी सभी सेवाएं, लिस्टिंग, KYC दस्तावेज और कमाई का इतिहास हमेशा के लिए मिटा दिया जाएगा। यह प्रक्रिया वापस नहीं की जा सकती।',
          style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.45),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('रद्द करें (Cancel)'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('हाँ, खाता हटाएं (Delete)'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.red)),
        );

        final user = FirebaseAuth.instance.currentUser;
        if (providerId.isNotEmpty) {
          await FirebaseFirestore.instance.collection('service_providers').doc(providerId).delete();
          try {
            await FirebaseFirestore.instance.collection('providers').doc(providerId).delete();
          } catch (_) {}
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        if (user != null) {
          try {
            await user.delete();
          } catch (_) {
            await FirebaseAuth.instance.signOut();
          }
        }

        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          context.read<ProviderAuthBloc>().add(SignOutEvent());

          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('आपकी पार्टनर प्रोफाइल और डेटा सफलतापूर्वक हटा दिया गया है।'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('खाता हटाने में त्रुटि: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          leading: Icon(icon, color: AppColors.primary),
          title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
          onTap: onTap,
        ),
      ),
    );
  }

  Future<void> _handleSignOut(BuildContext context) async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppColors.error),
            SizedBox(width: 10),
            Text('साइन आउट', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text(
          'क्या आप वाकई अपने पार्टनर अकाउंट से साइन आउट करना चाहते हैं?',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('रद्द करें (Cancel)', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('साइन आउट', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (shouldSignOut != true || !context.mounted) return;

    // Show non-dismissible loading dialog while sign-out completes
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.primary),
                SizedBox(width: 20),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'लॉगआउट हो रहा है...',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'कृपया प्रतीक्षा करें (Logging out...)',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Notify host webview immediately so host can transition UI smoothly
    WebHostBridge.notify('PROVIDER_LOGOUT_STARTED');

    // Dispatch sign out
    context.read<ProviderAuthBloc>().add(SignOutEvent());
  }
}
