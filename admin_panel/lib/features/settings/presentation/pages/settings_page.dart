import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _whatsappController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _websiteController;
  late TextEditingController _hoursController;
  bool _maintenanceMode = false;

  // Direct Cloud Firestore Version Control & Settings (app_settings/customer_app)
  late TextEditingController _custMinVersionController;
  late TextEditingController _custLatestVersionController;
  late TextEditingController _custUpdateTitleController;
  late TextEditingController _custUpdateMessageController;
  late TextEditingController _custUpdateButtonTextController;
  late TextEditingController _custPlayStoreUrlController;
  late TextEditingController _custMaintenanceMessageController;
  bool _custForceUpdate = false;

  late TextEditingController _provMinVersionController;
  late TextEditingController _provLatestVersionController;
  late TextEditingController _provUpdateMessageController;
  late TextEditingController _provPlayStoreUrlController;
  bool _provForceUpdate = false;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _lastUpdatedInfo;

  static const String _defaultName = 'JAMUI SERVICE';
  static const String _defaultPhone = '+91 94312 88412';
  static const String _defaultWhatsapp = '+91 94312 88412';
  static const String _defaultEmail = 'support@jamuiservice.in';
  static const String _defaultAddress = 'Jamui, Bihar - 811307';
  static const String _defaultWebsite = 'https://jamuiservice.in';
  static const String _defaultHours = '09:00 AM - 08:00 PM';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _defaultName);
    _phoneController = TextEditingController(text: _defaultPhone);
    _whatsappController = TextEditingController(text: _defaultWhatsapp);
    _emailController = TextEditingController(text: _defaultEmail);
    _addressController = TextEditingController(text: _defaultAddress);
    _websiteController = TextEditingController(text: _defaultWebsite);
    _hoursController = TextEditingController(text: _defaultHours);

    _custMinVersionController = TextEditingController(text: '1.0.0');
    _custLatestVersionController = TextEditingController(text: '1.2.4');
    _custUpdateTitleController = TextEditingController(text: 'New Update Available');
    _custUpdateMessageController = TextEditingController(
      text: 'जमुई सर्विस ऐप का नया और सुरक्षित संस्करण उपलब्ध है। कृपया ऐप अभी अपडेट करें।',
    );
    _custUpdateButtonTextController = TextEditingController(text: 'Update Now');
    _custPlayStoreUrlController = TextEditingController(
      text: 'https://play.google.com/store/apps/details?id=com.jamuiservice.customer',
    );
    _custMaintenanceMessageController = TextEditingController(
      text: 'जमुई सर्विस में तकनीकी सुधार कार्य प्रगति पर है। कृपया थोड़ी देर बाद पुनः प्रयास करें।',
    );

    _provMinVersionController = TextEditingController(text: '1.0.0');
    _provLatestVersionController = TextEditingController(text: '1.0.0');
    _provUpdateMessageController = TextEditingController(
      text: 'जमुई सर्विस पार्टनर ऐप का नया संस्करण उपलब्ध है। कृपया ऐप अभी अपडेट करें।',
    );
    _provPlayStoreUrlController = TextEditingController(
      text: 'https://play.google.com/store/apps/details?id=com.jamuiservice.provider',
    );

    _loadSettings();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _websiteController.dispose();
    _hoursController.dispose();

    _custMinVersionController.dispose();
    _custLatestVersionController.dispose();
    _custUpdateTitleController.dispose();
    _custUpdateMessageController.dispose();
    _custUpdateButtonTextController.dispose();
    _custPlayStoreUrlController.dispose();
    _custMaintenanceMessageController.dispose();

    _provMinVersionController.dispose();
    _provLatestVersionController.dispose();
    _provUpdateMessageController.dispose();
    _provPlayStoreUrlController.dispose();

    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      // 1. Load canonical app_settings/company
      final doc = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('company')
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _nameController.text = data['companyName']?.toString() ?? _defaultName;
        _phoneController.text = data['supportPhone']?.toString() ?? _defaultPhone;
        _whatsappController.text =
            data['supportWhatsapp']?.toString() ?? _defaultWhatsapp;
        _emailController.text = data['supportEmail']?.toString() ?? _defaultEmail;
        _addressController.text =
            data['companyAddress']?.toString() ?? _defaultAddress;
        _websiteController.text =
            data['websiteUrl']?.toString() ?? _defaultWebsite;
        _hoursController.text =
            data['workingHours']?.toString() ?? _defaultHours;
        _maintenanceMode = data['maintenanceMode'] == true;

        final updatedBy = data['updatedBy']?.toString() ?? 'Admin';
        final ts = data['updatedAt'];
        String timeStr = '';
        if (ts is Timestamp) {
          final dt = ts.toDate();
          timeStr = ' at ${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
        }
        _lastUpdatedInfo = 'Last updated by $updatedBy$timeStr';
      }

      // 2. Load Canonical Customer App Settings from app_settings/customer_app
      try {
        final custDoc = await FirebaseFirestore.instance
            .collection('app_settings')
            .doc('customer_app')
            .get();

        if (custDoc.exists && custDoc.data() != null) {
          final cd = custDoc.data()!;
          _custForceUpdate = cd['forceUpdateEnabled'] == true || cd['force_update_enabled'] == true;
          _custMinVersionController.text = cd['minimumSupportedVersion']?.toString() ??
              cd['minimum_supported_version']?.toString() ??
              '1.0.0';
          _custLatestVersionController.text = cd['latestVersion']?.toString() ??
              cd['latest_version']?.toString() ??
              '1.2.4';
          _custUpdateTitleController.text = cd['updateTitle']?.toString() ??
              cd['update_title']?.toString() ??
              'New Update Available';
          _custUpdateMessageController.text = cd['updateMessage']?.toString() ??
              cd['update_message']?.toString() ??
              'जमुई सर्विस ऐप का नया और सुरक्षित संस्करण उपलब्ध है। कृपया ऐप अभी अपडेट करें।';
          _custUpdateButtonTextController.text = cd['updateButtonText']?.toString() ??
              cd['update_button_text']?.toString() ??
              'Update Now';
          _custPlayStoreUrlController.text = cd['playStoreUrl']?.toString() ??
              cd['play_store_url']?.toString() ??
              'https://play.google.com/store/apps/details?id=com.jamuiservice.customer';
          if (cd['maintenanceMode'] != null) {
            _maintenanceMode = cd['maintenanceMode'] == true;
          }
          if (cd['maintenanceMessage'] != null && cd['maintenanceMessage'].toString().isNotEmpty) {
            _custMaintenanceMessageController.text = cd['maintenanceMessage'].toString();
          }
        } else {
          // Fallback to legacy app_config/version_control if app_settings/customer_app doc doesn't exist yet
          final vcDoc = await FirebaseFirestore.instance.collection('app_config').doc('version_control').get();
          if (vcDoc.exists && vcDoc.data() != null) {
            final d = vcDoc.data()!;
            _custMinVersionController.text = d['minimum_supported_version']?.toString() ?? '1.0.0';
            _custLatestVersionController.text = d['latest_version']?.toString() ?? '1.2.4';
            _custForceUpdate = d['force_update_enabled'] == true;
            if (d['update_title'] != null) {
              _custUpdateTitleController.text = d['update_title'].toString();
            }
            if (d['update_message'] != null) {
              _custUpdateMessageController.text = d['update_message'].toString();
            }
            if (d['update_button_text'] != null) {
              _custUpdateButtonTextController.text = d['update_button_text'].toString();
            }
            if (d['play_store_url'] != null) {
              _custPlayStoreUrlController.text = d['play_store_url'].toString();
            }
            if (d['maintenance_message'] != null) {
              _custMaintenanceMessageController.text = d['maintenance_message'].toString();
            }
          }
        }
      } catch (custErr) {
        debugPrint('⚠️ [SettingsPage] Error loading customer_app settings: $custErr');
      }

      // 3. Load Provider Partner App Version Settings
      try {
        final vcDoc = await FirebaseFirestore.instance.collection('app_config').doc('version_control').get();
        if (vcDoc.exists && vcDoc.data() != null) {
          final d = vcDoc.data()!;
          _provMinVersionController.text = d['min_required_provider_app_version']?.toString() ?? '1.0.0';
          _provLatestVersionController.text = d['latest_provider_app_version']?.toString() ?? '1.0.0';
          _provForceUpdate = d['provider_force_update_enabled'] == true || d['provider_force_update'] == true;
          if (d['provider_update_message'] != null) {
            _provUpdateMessageController.text = d['provider_update_message'].toString();
          }
          if (d['provider_play_store_url'] != null) {
            _provPlayStoreUrlController.text = d['provider_play_store_url'].toString();
          }
        }
      } catch (vcErr) {
        debugPrint('⚠️ [SettingsPage] Error loading provider version_control: $vcErr');
      }
    } catch (e) {
      debugPrint('⚠️ [SettingsPage] Error loading settings: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveSettings() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final adminIdentifier = user?.email ?? user?.phoneNumber ?? 'Super Admin';

      // 1. Canonical Firestore Document for Customer App: app_settings/customer_app
      final customerAppSettingsPayload = {
        'forceUpdateEnabled': _custForceUpdate,
        'minimumSupportedVersion': _custMinVersionController.text.trim().replaceAll('"', '').replaceAll("'", ''),
        'latestVersion': _custLatestVersionController.text.trim().replaceAll('"', '').replaceAll("'", ''),
        'updateTitle': _custUpdateTitleController.text.trim(),
        'updateMessage': _custUpdateMessageController.text.trim(),
        'updateButtonText': _custUpdateButtonTextController.text.trim(),
        'playStoreUrl': _custPlayStoreUrlController.text.trim(),
        'maintenanceMode': _maintenanceMode,
        'maintenanceMessage': _custMaintenanceMessageController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': adminIdentifier,
      };

      await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('customer_app')
          .set(customerAppSettingsPayload, SetOptions(merge: true));

      // 2. Canonical Firestore document for Company info: app_settings/company
      final companyPayload = {
        'companyName': _nameController.text.trim(),
        'supportPhone': _phoneController.text.trim(),
        'supportWhatsapp': _whatsappController.text.trim(),
        'supportEmail': _emailController.text.trim(),
        'companyAddress': _addressController.text.trim(),
        'websiteUrl': _websiteController.text.trim(),
        'workingHours': _hoursController.text.trim(),
        'maintenanceMode': _maintenanceMode,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': adminIdentifier,
      };

      await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('company')
          .set(companyPayload, SetOptions(merge: true));

      // Also mirror company to app_config/company for backwards compatibility
      try {
        await FirebaseFirestore.instance
            .collection('app_config')
            .doc('company')
            .set(companyPayload, SetOptions(merge: true));
      } catch (_) {}

      // 3. Backward Compatibility Sync with app_config/version_control (Provider App & legacy clients)
      final legacyVersionPayload = {
        'minimum_supported_version': _custMinVersionController.text.trim().replaceAll('"', '').replaceAll("'", ''),
        'latest_version': _custLatestVersionController.text.trim().replaceAll('"', '').replaceAll("'", ''),
        'force_update_enabled': _custForceUpdate,
        'update_title': _custUpdateTitleController.text.trim(),
        'update_message': _custUpdateMessageController.text.trim(),
        'update_button_text': _custUpdateButtonTextController.text.trim(),
        'play_store_url': _custPlayStoreUrlController.text.trim(),
        'maintenance_mode': _maintenanceMode,
        'customer_maintenance_mode': _maintenanceMode,
        'maintenance_message': _custMaintenanceMessageController.text.trim(),

        'min_required_provider_app_version': _provMinVersionController.text.trim().replaceAll('"', '').replaceAll("'", ''),
        'latest_provider_app_version': _provLatestVersionController.text.trim().replaceAll('"', '').replaceAll("'", ''),
        'provider_force_update_enabled': _provForceUpdate,
        'provider_force_update': _provForceUpdate,
        'provider_update_message': _provUpdateMessageController.text.trim(),
        'provider_play_store_url': _provPlayStoreUrlController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': adminIdentifier,
      };

      await FirebaseFirestore.instance
          .collection('app_config')
          .doc('version_control')
          .set(legacyVersionPayload, SetOptions(merge: true));

      // Mirror to app_config/customer for maximum compatibility
      try {
        await FirebaseFirestore.instance
            .collection('app_config')
            .doc('customer')
            .set(legacyVersionPayload, SetOptions(merge: true));
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Settings and Customer App Version Control saved to app_settings/customer_app successfully! Live stream will update customer app instantly.'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 4),
          ),
        );
        _loadSettings();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to save settings: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48.0),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Platform Configuration & Company Settings', style: AppTextStyles.h2),
                      const SizedBox(height: 6),
                      Text(
                        'Canonical source of truth for Customer App, Provider App, and Website support details.',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                  if (_lastUpdatedInfo != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _lastUpdatedInfo!,
                        style: TextStyle(fontSize: 12, color: Colors.blue.shade900, fontWeight: FontWeight.w500),
                      ),
                    ),
                ],
              ),
              const Divider(height: 36),

              // Section: Company Info
              Text('🏢 Company Profile', style: AppTextStyles.bodyBold),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Company / Platform Name',
                        prefixIcon: Icon(Icons.business_rounded, size: 20),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Company name is required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _websiteController,
                      decoration: const InputDecoration(
                        labelText: 'Official Website URL',
                        prefixIcon: Icon(Icons.language_rounded, size: 20),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Section: Support Helpline & Contact Details
              Text('📞 Canonical Support Contact Details (Shown across all apps)', style: AppTextStyles.bodyBold),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Support Helpline Phone',
                        hintText: '+91 94312 88412',
                        prefixIcon: Icon(Icons.phone_in_talk_rounded, size: 20),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Support phone is required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _whatsappController,
                      decoration: const InputDecoration(
                        labelText: 'Support WhatsApp Number',
                        hintText: '+91 94312 88412',
                        prefixIcon: Icon(Icons.chat_bubble_rounded, size: 20),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'WhatsApp number is required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Support Email Address',
                        hintText: 'support@jamuiservice.in',
                        prefixIcon: Icon(Icons.email_outlined, size: 20),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Support email is required';
                        if (!v.contains('@')) return 'Enter a valid email address';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _hoursController,
                      decoration: const InputDecoration(
                        labelText: 'Support / Business Operating Hours',
                        hintText: '09:00 AM - 08:00 PM',
                        prefixIcon: Icon(Icons.schedule_rounded, size: 20),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Headquarters / Registered Address',
                  prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Address is required' : null,
              ),

              const Divider(height: 36),

              // Section: Direct Firestore Version Control (Force Update)
              Row(
                children: [
                  const Icon(Icons.system_update_rounded, color: AppColors.primary, size: 22),
                  const SizedBox(width: 8),
                  Text('📱 App Version Control & Force Update (Direct Firestore — Zero Delay)', style: AppTextStyles.bodyBold),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'यहाँ से आप Customer App और Provider App के लिए सीधे Firestore (app_config/version_control) से Force Update कंट्रोल कर सकते हैं। Remote Config की कोई जरूरत नहीं है।',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 16),

              // Customer App Version Settings Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('🛍️ Customer App Version Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
                        Row(
                          children: [
                            const Text('Force Update Screen: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Switch(
                              value: _custForceUpdate,
                              activeTrackColor: Colors.red,
                              onChanged: (v) => setState(() => _custForceUpdate = v),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _custMinVersionController,
                            decoration: const InputDecoration(
                              labelText: 'Minimum Required Version *',
                              hintText: '1.3.0',
                              helperText: 'इस वर्जन से कम वाले ऐप को Force Screen दिखेगी',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: TextFormField(
                            controller: _custLatestVersionController,
                            decoration: const InputDecoration(
                              labelText: 'Latest Available Version *',
                              hintText: '1.3.0',
                              helperText: 'प्ले स्टोर पर उपलब्ध नया वर्जन',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _custUpdateTitleController,
                            decoration: const InputDecoration(
                              labelText: 'Update Dialog / Screen Title',
                              hintText: 'New Update Available',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: TextFormField(
                            controller: _custUpdateButtonTextController,
                            decoration: const InputDecoration(
                              labelText: 'Update Button Text',
                              hintText: 'Update Now',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _custUpdateMessageController,
                            decoration: const InputDecoration(
                              labelText: 'Update Alert Message',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _custPlayStoreUrlController,
                            decoration: const InputDecoration(
                              labelText: 'Play Store URL',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Provider App Version Settings Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('🛠️ Provider Partner App Version Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.brown)),
                        Row(
                          children: [
                            const Text('Force Update Screen: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Switch(
                              value: _provForceUpdate,
                              activeTrackColor: Colors.red,
                              onChanged: (v) => setState(() => _provForceUpdate = v),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _provMinVersionController,
                            decoration: const InputDecoration(
                              labelText: 'Minimum Required Version *',
                              hintText: '1.0.0',
                              helperText: 'इस वर्जन से कम वाले कारीगर को Force Screen दिखेगी',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: TextFormField(
                            controller: _provLatestVersionController,
                            decoration: const InputDecoration(
                              labelText: 'Latest Available Version *',
                              hintText: '1.0.0',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _provUpdateMessageController,
                            decoration: const InputDecoration(
                              labelText: 'Update Alert Message',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _provPlayStoreUrlController,
                            decoration: const InputDecoration(
                              labelText: 'Play Store URL',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Divider(height: 36),

              // Section: Maintenance Mode Switch
              Text('⚙️ System Controls', style: AppTextStyles.bodyBold),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _maintenanceMode ? Colors.red.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _maintenanceMode ? Colors.red.shade300 : AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Switch(
                          value: _maintenanceMode,
                          activeTrackColor: Colors.red,
                          onChanged: (val) => setState(() => _maintenanceMode = val),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('System Maintenance Mode', style: AppTextStyles.bodyBold),
                            Text(
                              _maintenanceMode
                                  ? '⚠️ Platform is currently flagged under maintenance (apps will show maintenance screen).'
                                  : 'Normal operating status. Platform active.',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (_maintenanceMode) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _custMaintenanceMessageController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Maintenance Alert Message (Shown to Customers)',
                          hintText: 'जमुई सर्विस में तकनीकी सुधार कार्य प्रगति पर है...',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Action Buttons
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveSettings,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.save_rounded, size: 20),
                    label: Text(_isSaving ? 'Saving...' : 'Save & Publish Settings'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: _isLoading || _isSaving ? null : _loadSettings,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Reload from Firestore'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
