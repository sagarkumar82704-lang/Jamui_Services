import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_brand.dart';

/// Immutable entity holding canonical company settings & support contact details
class CompanySettingsEntity {
  final String companyName;
  final String supportPhone;
  final String supportWhatsapp;
  final String supportEmail;
  final String companyAddress;
  final String websiteUrl;
  final String workingHours;
  final bool maintenanceMode;

  const CompanySettingsEntity({
    required this.companyName,
    required this.supportPhone,
    required this.supportWhatsapp,
    required this.supportEmail,
    required this.companyAddress,
    required this.websiteUrl,
    required this.workingHours,
    required this.maintenanceMode,
  });

  /// Compile-time safe fallback defaults
  factory CompanySettingsEntity.fallback() {
    return const CompanySettingsEntity(
      companyName: AppBrand.shortName,
      supportPhone: '+91 94312 88412',
      supportWhatsapp: '+91 94312 88412',
      supportEmail: AppBrand.supportEmail,
      companyAddress: 'Jamui, Bihar - 811307',
      websiteUrl: 'https://jamuiservice.in',
      workingHours: '09:00 AM - 08:00 PM',
      maintenanceMode: false,
    );
  }

  factory CompanySettingsEntity.fromMap(Map<String, dynamic> data) {
    final fallback = CompanySettingsEntity.fallback();
    return CompanySettingsEntity(
      companyName: data['companyName']?.toString().trim().isNotEmpty == true
          ? data['companyName'].toString().trim()
          : fallback.companyName,
      supportPhone: data['supportPhone']?.toString().trim().isNotEmpty == true
          ? data['supportPhone'].toString().trim()
          : fallback.supportPhone,
      supportWhatsapp: data['supportWhatsapp']?.toString().trim().isNotEmpty == true
          ? data['supportWhatsapp'].toString().trim()
          : fallback.supportWhatsapp,
      supportEmail: data['supportEmail']?.toString().trim().isNotEmpty == true
          ? data['supportEmail'].toString().trim()
          : fallback.supportEmail,
      companyAddress: data['companyAddress']?.toString().trim().isNotEmpty == true
          ? data['companyAddress'].toString().trim()
          : fallback.companyAddress,
      websiteUrl: data['websiteUrl']?.toString().trim().isNotEmpty == true
          ? data['websiteUrl'].toString().trim()
          : fallback.websiteUrl,
      workingHours: data['workingHours']?.toString().trim().isNotEmpty == true
          ? data['workingHours'].toString().trim()
          : fallback.workingHours,
      maintenanceMode: data['maintenanceMode'] == true,
    );
  }
}

/// Singleton Service delivering unified Company Profile & Support details for Provider App
class CompanySettingsService {
  static final CompanySettingsService _instance = CompanySettingsService._internal();
  factory CompanySettingsService() => _instance;
  CompanySettingsService._internal();

  CompanySettingsEntity _cachedSettings = CompanySettingsEntity.fallback();
  CompanySettingsEntity get currentSettings => _cachedSettings;

  /// Stream of live company settings from Firestore `app_settings/company`
  Stream<CompanySettingsEntity> getSettingsStream() {
    return FirebaseFirestore.instance
        .collection('app_settings')
        .doc('company')
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        _cachedSettings = CompanySettingsEntity.fromMap(snapshot.data()!);
      }
      return _cachedSettings;
    }).handleError((e) {
      debugPrint('⚠️ [CompanySettingsService] Stream error (using fallback): $e');
      return _cachedSettings;
    });
  }

  /// One-shot fetch of latest settings
  Future<CompanySettingsEntity> fetchSettings({Duration timeout = const Duration(seconds: 4)}) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('company')
          .get()
          .timeout(timeout);

      if (doc.exists && doc.data() != null) {
        _cachedSettings = CompanySettingsEntity.fromMap(doc.data()!);
      }
    } catch (e) {
      debugPrint('⚠️ [CompanySettingsService] Fetch notice (using cached/fallback): $e');
    }
    return _cachedSettings;
  }

  /// Launch native phone dialer for helpline
  static Future<bool> launchCall(String? rawPhone) async {
    final phone = (rawPhone ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
    if (phone.isEmpty) return false;
    final uri = Uri.parse('tel:$phone');
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('⚠️ [CompanySettingsService] Failed to launch phone: $e');
    }
    return false;
  }

  /// Launch WhatsApp chat with prefilled message
  static Future<bool> launchWhatsApp(String? rawPhone, {String? message}) async {
    final cleanPhone = (rawPhone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.isEmpty) return false;
    final msg = Uri.encodeComponent(message ?? 'नमस्ते Jamui Service टीम, मुझे सहायता की आवश्यकता है।');
    final uri = Uri.parse('https://wa.me/$cleanPhone?text=$msg');
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('⚠️ [CompanySettingsService] Failed to launch WhatsApp: $e');
    }
    return false;
  }

  /// Launch email client for support email
  static Future<bool> launchEmail(String? rawEmail, {String? subject, String? body}) async {
    final email = (rawEmail ?? '').trim();
    if (email.isEmpty) return false;
    final subj = Uri.encodeComponent(subject ?? 'Jamui Services Partner Support Inquiry');
    final b = Uri.encodeComponent(body ?? '');
    final uri = Uri.parse('mailto:$email?subject=$subj&body=$b');
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('⚠️ [CompanySettingsService] Failed to launch email: $e');
    }
    return false;
  }
}
