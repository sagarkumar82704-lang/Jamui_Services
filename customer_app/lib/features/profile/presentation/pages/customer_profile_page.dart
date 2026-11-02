import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/domain/entities/customer_entity.dart';
import '../../../auth/presentation/bloc/customer_auth_bloc.dart';
import '../../../auth/presentation/bloc/customer_auth_event.dart';
import '../../../auth/presentation/bloc/customer_auth_state.dart';
import '../../../auth/presentation/pages/customer_login_screen.dart';
import '../../../bookings/presentation/pages/customer_bookings_screen.dart';
import '../../../discovery/presentation/bloc/discovery_bloc.dart';
import '../../../discovery/presentation/bloc/discovery_event.dart';
import '../../../favourites/presentation/pages/favourite_providers_page.dart';
import '../../../location/domain/entities/customer_location_entity.dart';
import '../../../location/presentation/bloc/location_bloc.dart';
import '../../../location/presentation/bloc/location_event.dart';
import '../../../location/presentation/pages/location_picker_screen.dart';
import '../../../../core/services/provider_app_launcher_service.dart';
import 'customer_edit_profile_page.dart';

class CustomerProfilePage extends StatefulWidget {
  const CustomerProfilePage({super.key});

  @override
  State<CustomerProfilePage> createState() => _CustomerProfilePageState();
}

class _CustomerProfilePageState extends State<CustomerProfilePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authBloc = context.read<CustomerAuthBloc>();
      if (authBloc.state is! CustomerAuthenticatedState &&
          FirebaseAuth.instance.currentUser != null) {
        authBloc.add(const CheckCustomerAuthStatusEvent());
      }
    });
  }

  Future<void> _changeLocation(
    BuildContext context,
    CustomerEntity customer,
  ) async {
    final result = await Navigator.push<CustomerLocationEntity>(
      context,
      MaterialPageRoute(
        builder: (_) => const LocationPickerScreen(isFromOnboarding: false),
      ),
    );

    if (result != null && context.mounted) {
      // 1. Update LocationBloc & Local Storage Cache
      context.read<LocationBloc>().add(ConfirmSelectedLocationEvent(result));

      // 2. Update DiscoveryBloc
      final pinOrDistrict = result.pincode.isNotEmpty
          ? result.pincode
          : (result.district.isNotEmpty ? result.district : result.city);
      final areaName = result.placeName.isNotEmpty
          ? (pinOrDistrict.isNotEmpty ? '${result.placeName} ($pinOrDistrict)' : result.placeName)
          : (result.formattedAddress.isNotEmpty
              ? result.formattedAddress
              : 'GPS (${result.latitude.toStringAsFixed(4)}, ${result.longitude.toStringAsFixed(4)})');
      context.read<DiscoveryBloc>().add(
        UpdateCustomerLocationEvent(
          latitude: result.latitude,
          longitude: result.longitude,
          areaName: areaName,
        ),
      );

      // 3. Update Customer profile in AuthBloc & Firestore
      final cityOrDistrict = result.city.isNotEmpty ? result.city : (result.district.isNotEmpty ? result.district : '');
      final updatedCustomer = customer.copyWith(
        jamuiArea: result.placeName.isNotEmpty
            ? result.placeName
            : (cityOrDistrict.isNotEmpty ? cityOrDistrict : customer.jamuiArea),
        address: result.formattedAddress.isNotEmpty
            ? result.formattedAddress
            : customer.address,
        latitude: result.latitude,
        longitude: result.longitude,
        updatedAt: DateTime.now(),
      );

      context.read<CustomerAuthBloc>().add(
        SaveCustomerProfileEvent(updatedCustomer),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('स्थान और पता सफलतापूर्वक अपडेट किया गया! 📍'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showSignOutConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text(
              'लॉगआउट की पुष्टि',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'क्या आप वाकई अपने खाते से लॉगआउट करना चाहते हैं?',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('रद्द करें (Cancel)'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<CustomerAuthBloc>().add(
                const CustomerSignOutEvent(),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('हाँ, लॉगआउट करें'),
          ),
        ],
      ),
    );
  }

  Future<void> _openPrivacyPolicy() async {
    final uri = Uri.parse('https://jamui-services.web.app/#privacy');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  Future<void> _showDeleteAccountConfirmDialog(
    BuildContext context,
    String customerId,
  ) async {
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
                'खाता हटाने की पुष्टि',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: const Text(
          'क्या आप वाकई अपना Jamui Services खाता हमेशा के लिए हटाना चाहते हैं?\n\n'
          '⚠️ चेतावनी: आपकी सभी बुकिंग, पता, और व्यक्तिगत विवरण सर्वर से स्थायी रूप से हटा दिए जाएंगे। इसे वापस रिकवर नहीं किया जा सकेगा।',
          style: TextStyle(
            fontSize: 13.5,
            color: AppColors.textSecondary,
            height: 1.45,
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('रद्द करें (Cancel)'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
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
          builder: (_) =>
              const Center(child: CircularProgressIndicator(color: Colors.red)),
        );

        final user = FirebaseAuth.instance.currentUser;
        if (customerId.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(customerId)
              .delete();
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
          context.read<CustomerAuthBloc>().add(const CustomerSignOutEvent());

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'आपका खाता और डेटा सफलतापूर्वक हमेशा के लिए हटा दिया गया है।',
              ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'मेरी प्रोफाइल (My Profile)',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: AppColors.creamWhite,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: BlocBuilder<CustomerAuthBloc, CustomerAuthState>(
        builder: (context, state) {
          final currentUser = FirebaseAuth.instance.currentUser;
          if (state is CustomerAuthenticatedState || currentUser != null) {
            final customer = (state is CustomerAuthenticatedState)
                ? state.customer
                : CustomerEntity(
                    id: currentUser!.uid,
                    fullName:
                        (currentUser.displayName != null &&
                            currentUser.displayName!.isNotEmpty)
                        ? currentUser.displayName!
                        : 'Jamui ग्राहक',
                    phoneNumber: currentUser.phoneNumber ?? '',
                    email: currentUser.email,
                    createdAt: DateTime.now(),
                  );
            final verifiedPhone = customer.phoneNumber.isNotEmpty
                ? customer.phoneNumber
                : (currentUser?.phoneNumber ?? '');

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Profile Header Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: AppColors.primary.withValues(
                            alpha: 0.1,
                          ),
                          child: Text(
                            customer.fullName.isNotEmpty
                                ? customer.fullName[0].toUpperCase()
                                : 'C',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          customer.fullName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          alignment: WrapAlignment.center,
                          children: [
                            if (verifiedPhone.isNotEmpty)
                              Chip(
                                avatar: const Icon(
                                  Icons.phone_android,
                                  size: 14,
                                  color: Colors.green,
                                ),
                                label: Text(
                                  verifiedPhone,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                backgroundColor: Colors.green.shade50,
                                visualDensity: VisualDensity.compact,
                              ),
                            if (customer.email != null &&
                                customer.email!.isNotEmpty)
                              Chip(
                                avatar: const Icon(
                                  Icons.email_outlined,
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                                label: Text(
                                  customer.email!,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                backgroundColor: AppColors.primary.withValues(
                                  alpha: 0.08,
                                ),
                                visualDensity: VisualDensity.compact,
                              )
                            else
                              ActionChip(
                                avatar: const Icon(
                                  Icons.add,
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                                label: const Text(
                                  'ईमेल जोड़ें (Add Email)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                backgroundColor: AppColors.primary.withValues(
                                  alpha: 0.08,
                                ),
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CustomerEditProfilePage(
                                        customer: customer,
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // Prominent Edit Profile Button
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    CustomerEditProfilePage(customer: customer),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.edit_note_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          label: const Text(
                            'प्रोफ़ाइल संपादित करें (Edit Profile)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.primary,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: AppColors.primary,
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Saved Location & Address Card (Persistent Local Cache & Zero API Cost)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.pin_drop,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'सुरक्षित स्थान व पता (Saved Location)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                            TextButton.icon(
                              onPressed: () =>
                                  _changeLocation(context, customer),
                              icon: const Icon(
                                Icons.edit_location_alt,
                                size: 16,
                              ),
                              label: const Text(
                                'बदलें',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.location_city,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          title: const Text(
                            'इलाका / शहर (Jamui Area)',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          subtitle: Text(
                            customer.jamuiArea.isNotEmpty
                                ? customer.jamuiArea
                                : 'जमुई',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.home,
                              color: Colors.blue,
                              size: 20,
                            ),
                          ),
                          title: const Text(
                            'पूरा पता (Full Address)',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          subtitle: Text(
                            customer.address.isNotEmpty
                                ? customer.address
                                : 'पता दर्ज नहीं है',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (customer.email != null &&
                            customer.email!.isNotEmpty)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.email,
                                color: Colors.orange,
                                size: 20,
                              ),
                            ),
                            title: const Text(
                              'ईमेल आईडी (Email ID)',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            subtitle: Text(customer.email!),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.edit_outlined,
                                size: 18,
                                color: AppColors.primary,
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CustomerEditProfilePage(
                                      customer: customer,
                                    ),
                                  ),
                                );
                              },
                            ),
                          )
                        else
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.email_outlined,
                                color: Colors.orange,
                                size: 20,
                              ),
                            ),
                            title: const Text(
                              'ईमेल आईडी (Email ID)',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            subtitle: const Text(
                              'जोड़ा नहीं गया (Not added)',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                            trailing: TextButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CustomerEditProfilePage(
                                      customer: customer,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.add, size: 14),
                              label: const Text(
                                'जोड़ें',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primary,
                              ),
                            ),
                          ),
                        // Verified Mobile Number ListTile
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.phone_android_rounded,
                              color: Colors.green,
                              size: 20,
                            ),
                          ),
                          title: const Row(
                            children: [
                              Text(
                                'सत्यापित मोबाइल नंबर (Verified Mobile)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.lock_rounded, size: 12, color: Colors.green),
                            ],
                          ),
                          subtitle: Text(
                            verifiedPhone.isNotEmpty ? verifiedPhone : 'नंबर उपलब्ध नहीं है',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              color: verifiedPhone.isNotEmpty ? AppColors.textPrimary : Colors.red,
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: const Text(
                              'सत्यापित 🔒',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Quick Actions Card (History, Favourites & Support)
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.history_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          title: const Text(
                            'मेरी बुकिंग्स व सेवा इतिहास',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: const Text(
                            'अनुरोध की स्थिति, विवरण और रसीद देखें',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: Colors.grey,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CustomerBookingsScreen(),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.favorite_rounded,
                              color: Colors.red,
                              size: 20,
                            ),
                          ),
                          title: const Text(
                            'पसंदीदा कारीगर (Saved Providers)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: const Text(
                            'आपके द्वारा सहेजे गए पसंदीदा कारीगर',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: Colors.grey,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const FavouriteProvidersPage(),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.privacy_tip_outlined,
                              color: Colors.teal,
                              size: 20,
                            ),
                          ),
                          title: const Text(
                            'गोपनीयता नीति (Privacy Policy)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: const Text(
                            'डेटा सुरक्षा व ऐप अनुमतियाँ विवरण पढ़ें',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.open_in_new_rounded,
                            size: 14,
                            color: Colors.grey,
                          ),
                          onTap: _openPrivacyPolicy,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E3A8A)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.handyman_rounded,
                              color: Color(0xFF1E3A8A),
                              size: 20,
                            ),
                          ),
                          title: const Text(
                            'कारीगर / सर्विस प्रोवाइडर बनें',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: const Text(
                            '0% कमीशन • Jamui Services से अपने बिजनेस को बढ़ाएं',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFBBF24),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Join >',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          onTap: () =>
                              ProviderAppLauncherService.showJoinProviderModal(
                                context,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Sign Out Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showSignOutConfirmDialog(context),
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: const Text(
                        'लॉगआउट करें (Sign Out)',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Delete Account Option
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () =>
                          _showDeleteAccountConfirmDialog(context, customer.id),
                      icon: Icon(
                        Icons.delete_forever_rounded,
                        color: Colors.red.shade700,
                        size: 20,
                      ),
                      label: Text(
                        'खाता व सारा डेटा हटाएं (Delete Account)',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            );
          } else if (state is CustomerAuthLoadingState) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text(
                    'प्रोफाइल लोड हो रही है...',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          } else {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.account_circle_outlined,
                      size: 72,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'साइन इन नहीं हैं',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'अपनी बुकिंग देखने और सेवा अनुरोध के लिए लॉगिन करें',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CustomerLoginScreen(),
                          ),
                          (route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'मोबाइल OTP से लॉगिन करें',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        },
      ),
    );
  }
}
