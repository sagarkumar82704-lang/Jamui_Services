import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/auth_exception_handler.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../../../core/widgets/app_network_or_base64_image.dart';
import '../../../categories/data/models/service_category_model.dart';
import '../../../professional_shop/presentation/pages/professional_shop_registration_page.dart';
import '../../../location/data/datasources/location_remote_data_source.dart';
import '../../../location/domain/entities/provider_location_entity.dart';
import '../../../location/presentation/pages/provider_location_picker_screen.dart';
import '../../domain/entities/provider_profile_entity.dart';
import '../../domain/entities/custom_service_application_entity.dart';
import '../../data/models/custom_service_application_model.dart';
import '../../data/models/provider_profile_model.dart';
import '../widgets/other_service_details_modal.dart';
import '../bloc/provider_auth_bloc.dart';
import '../bloc/provider_auth_event.dart';
import '../../../../main.dart';

import 'dart:async';

class ProviderMultiStepRegistrationPage extends StatefulWidget {
  final ProviderProfileEntity? initialProfile;
  final int? initialStep;

  const ProviderMultiStepRegistrationPage({
    super.key,
    this.initialProfile,
    this.initialStep,
  });

  @override
  State<ProviderMultiStepRegistrationPage> createState() => _ProviderMultiStepRegistrationPageState();
}

class _ProviderMultiStepRegistrationPageState extends State<ProviderMultiStepRegistrationPage>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  final int _totalSteps = 6;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _mapDragDebounceTimer;

  // Step 1 Form & Controllers (Account - Email + Password Authentication)
  final _step1FormKey = GlobalKey<FormState>();
  late TextEditingController _fullNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _passwordController;
  late TextEditingController _confirmPasswordController;
  bool _obscurePassword = true;
  bool _termsAccepted = false;
  bool _isPhoneVerified = false;
  bool _isEmailVerified = false;

  // Step 2 Controllers (Business Profile)
  final _step2FormKey = GlobalKey<FormState>();
  late TextEditingController _businessNameController;
  late TextEditingController _businessDescController;
  late TextEditingController _visitingChargeController;
  late TextEditingController _experienceYearsController;
  String _businessType = 'Individual';
  String _profileImageUrl = '';
  String _businessImageUrl = '';
  bool _isUploadingProfilePhoto = false;
  bool _isUploadingBusinessPhoto = false;

  // Step 3 (Location & GPS)
  double _latitude = 0.0;
  double _longitude = 0.0;
  double _serviceRadiusKm = 10.0;
  String _jamuiArea = '';
  String _fullAddress = '';
  String _pincode = '';
  String _city = '';
  bool _isFetchingGPS = false;
  bool _isLocationSelected = false;
  final MapController _mapController = MapController();
  final LocationRemoteDataSource _locationDataSource = LocationRemoteDataSourceImpl();

  // Step 2 (Admin Categories & Services)
  List<ServiceCategoryModel> _adminCategories = [];
  List<ServiceCategoryModel> _premiumCategories = [];
  List<Map<String, dynamic>> _professionalCategories = [];
  bool _isLoadingCategories = true;
  String? _categoriesError;
  String _primaryCategoryId = '';
  String _primaryCategoryTitle = '';
  String _selectedCategoryType = 'general'; // 'general' or 'premium'
  List<String> _selectedCategoryIds = [];
  List<String> _selectedSubServices = [];
  int get _maxAllowedCategories => widget.initialProfile?.categoryLimit ?? 1;
  bool _isOtherService = false;
  OtherServiceData? _otherServiceData;

  // Dedicated service details text controllers
  late TextEditingController _premiumServiceDetailsController;
  late TextEditingController _generalServiceDetailsController;

  // Category Request State
  String _categoryRequestStatus = 'none'; // 'none', 'pending_review', 'approved', 'rejected'
  String _categoryRequestId = '';
  String? _categoryRejectionReason;
  bool _isSavingDraft = false;
  bool _isSubmittingCategoryRequest = false;

  // Step 5 (Working Details & Documents)
  final _step5FormKey = GlobalKey<FormState>();
  late TextEditingController _workingHoursController;
  late TextEditingController _previousOrgController;
  late TextEditingController _experienceDescController;
  bool _isEmergencyAvailable = false;
  bool _hasExperienceCert = false;
  String _experienceCertUrl = '';
  bool _isUploadingCert = false;

  // Step 6 (Submission Status)
  bool _isSubmittingFinal = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    final p = widget.initialProfile;
    final currentUser = FirebaseAuth.instance.currentUser;

    if (p != null) {
      final bool isAlreadyComplete = p.registrationStatus == 'completed' ||
          p.status == ProviderAccountStatus.pendingReview ||
          p.status == ProviderAccountStatus.approved ||
          p.completedSteps.contains(5);
      if (isAlreadyComplete) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: context.read<ProviderAuthBloc>(),
                  child: ProviderRoleAwareWorkspace(profile: p),
                ),
              ),
              (route) => false,
            );
          }
        });
        return;
      }

      _categoryRequestStatus = p.categoryRequestStatus.isNotEmpty
          ? p.categoryRequestStatus
          : (p.isOtherService ? 'pending_review' : 'none');
      _categoryRequestId = p.categoryRequestId ?? '';
      _categoryRejectionReason = p.categoryRejectionReason;
    } else if (currentUser != null) {
      _restoreDraftFromFirestore(currentUser.uid);
    }

    _fullNameController = TextEditingController(text: p?.fullName ?? '');
    _emailController = TextEditingController(text: p?.email ?? '');
    _phoneController = TextEditingController(text: p?.phoneNumber.replaceAll('+91', '') ?? '');
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();

    _businessNameController = TextEditingController(text: p?.businessName ?? '');
    _businessDescController = TextEditingController(text: p?.businessDescription ?? '');
    _visitingChargeController = TextEditingController(text: (p?.visitingCharge ?? 100.0).toInt().toString());
    _experienceYearsController = TextEditingController(text: (p?.experienceYears ?? 1).toString());
    _businessType = (p?.businessType.isNotEmpty ?? false) ? p!.businessType : 'Individual';
    _profileImageUrl = p?.profileImageUrl ?? '';
    _businessImageUrl = p?.businessImageUrl ?? '';

    if (p != null && p.latitude != 0.0 && p.longitude != 0.0) {
      _latitude = p.latitude;
      _longitude = p.longitude;
      _jamuiArea = p.jamuiArea;
      _fullAddress = p.fullAddress;
      _serviceRadiusKm = p.serviceRadiusKm;
      _isLocationSelected = true;
    }

    _primaryCategoryId = p?.primaryCategoryId ?? '';
    _primaryCategoryTitle = p?.primaryCategoryTitle ?? '';
    _selectedCategoryType = (p != null && p.categoryType.isNotEmpty)
        ? p.categoryType
        : (p?.isUnisexSalon == true ? 'premium' : 'general');
    _selectedCategoryIds = List<String>.from(p?.selectedCategoryIds ?? []);
    _selectedSubServices = List<String>.from(p?.subServices ?? []);
    _premiumServiceDetailsController = TextEditingController(text: p?.premiumServiceDetails ?? '');
    _generalServiceDetailsController = TextEditingController(text: p?.generalServiceDetails ?? '');

    if (p != null && p.isOtherService) {
      _isOtherService = true;
      if (p.customServiceName.isNotEmpty) {
        _otherServiceData = OtherServiceData(
          serviceName: p.customServiceName,
          serviceDescription: p.customServiceDescription,
          offeredServices: p.customServiceOffered,
          fullName: p.fullName,
          phoneNumber: p.phoneNumber,
          fullAddress: p.fullAddress,
          jamuiArea: p.jamuiArea,
          experienceYears: p.experienceYears,
          visitingCharge: p.visitingCharge,
        );
      }
    }

    _workingHoursController = TextEditingController(text: (p?.workingHours.isNotEmpty ?? false) ? p!.workingHours : '09:00 AM - 08:00 PM');
    _previousOrgController = TextEditingController(text: p?.previousOrganization ?? '');
    _experienceDescController = TextEditingController(text: p?.experienceDescription ?? '');
    _hasExperienceCert = p?.hasExperienceCertificate ?? false;
    _experienceCertUrl = p?.experienceCertificateUrl ?? '';
    _isEmergencyAvailable = p?.isAvailable ?? false;

    if (p != null) {
      _isPhoneVerified = p.isMobileVerified;
      _isEmailVerified = p.isEmailVerified;
      _termsAccepted = true;
    }

    // Smart Incomplete Step Resume: Opens directly to the incomplete step based on new 6-step ordering
    if (widget.initialStep != null) {
      _currentStep = widget.initialStep!.clamp(0, _totalSteps - 1);
    } else if (p != null) {
      if (_categoryRequestStatus == 'pending_review') {
        _currentStep = 1; // Stay on Step 1: Category Selection (Pending Review Dashboard)
      } else if (p.currentStep > 0) {
        _currentStep = p.currentStep.clamp(0, _totalSteps - 1);
      } else if (p.primaryCategoryId.trim().isEmpty) {
        _currentStep = 1; // Step 1: Category Selection
      } else if (p.businessName.trim().isEmpty || p.businessImageUrl.trim().isEmpty) {
        _currentStep = 2; // Step 2: Business Profile
      } else if (p.latitude == 0.0 || p.longitude == 0.0 || p.fullAddress.trim().isEmpty) {
        _currentStep = 3; // Step 3: Location & Live GPS
      } else if (p.workingHours.trim().isEmpty) {
        _currentStep = 4; // Step 4: Working Hours & Details
      } else {
        _currentStep = 5; // Step 5: Review & Final Submit
      }
    }

    // Auto-fetch real GPS location on screen open if not already set
    if (!_isLocationSelected || _latitude == 0.0) {
      _fetchRealGPSLocation(showFeedback: false);
    }
    _fetchAdminCategories();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _mapDragDebounceTimer?.cancel();
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _businessNameController.dispose();
    _businessDescController.dispose();
    _visitingChargeController.dispose();
    _experienceYearsController.dispose();
    _workingHoursController.dispose();
    _previousOrgController.dispose();
    _experienceDescController.dispose();
    _premiumServiceDetailsController.dispose();
    _generalServiceDetailsController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _fetchAdminCategories() async {
    setState(() {
      _isLoadingCategories = true;
      _categoriesError = null;
    });

    try {
      // 1. Fetch general categories from Firestore 'categories' collection
      final snap = await FirebaseFirestore.instance.collection('categories').get();
      final allCats = snap.docs
          .map((doc) => ServiceCategoryModel.fromMap(doc.data(), doc.id))
          .where((c) {
            if (c.isDeleted || (c.status.toLowerCase() != 'active' && !c.isActive)) return false;
            final id = c.id.toLowerCase();
            final titleEng = c.titleEnglish.toLowerCase();
            final titleHin = c.titleHindi.toLowerCase();
            // Strictly exclude Diamond E-Commerce from Normal Provider Categories
            if (id.contains('diamond') || titleEng.contains('diamond') || titleHin.contains('diamond') || c.categoryType == 'diamond') {
              return false;
            }
            return true;
          })
          .toList();

      // 2. Fetch admin-configured premium categories from Firestore 'premium_categories' collection
      final List<ServiceCategoryModel> premiumList = [];
      try {
        final premSnap = await FirebaseFirestore.instance.collection('premium_categories').get();
        for (final doc in premSnap.docs) {
          final data = doc.data();
          final isActive = (data['isActive'] as bool?) ?? true;
          if (!isActive) continue;

          final catId = (data['categoryId'] as String?) ?? doc.id;
          final title = (data['customTitle'] as String?) ??
              (data['title'] as String?) ??
              (data['categoryName'] as String?) ??
              'प्रीमियम सेवा';
          final priority = (data['priority'] as num?)?.toInt() ?? 99;
          final imgUrl = (data['imageUrl'] as String?) ?? '';

          // Look up underlying category in allCats to inherit subServices / icons
          final underlying = allCats.where((c) => c.id == catId).toList();
          final List<String> subServices = underlying.isNotEmpty && underlying.first.subServices.isNotEmpty
              ? underlying.first.subServices
              : ((data['subServices'] is List)
                  ? (data['subServices'] as List).map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
                  : const <String>[]);

          premiumList.add(ServiceCategoryModel(
            id: catId,
            titleHindi: title,
            titleEnglish: (data['categoryName'] as String?) ?? (underlying.isNotEmpty ? underlying.first.titleEnglish : title),
            description: (data['description'] as String?) ?? (underlying.isNotEmpty ? underlying.first.description : 'प्रीमियम सेवा श्रेणी'),
            imageUrl: imgUrl.isNotEmpty ? imgUrl : (underlying.isNotEmpty ? underlying.first.imageUrl : ''),
            iconName: (data['iconName'] as String?) ?? (underlying.isNotEmpty ? underlying.first.iconName : 'workspace_premium'),
            colorHex: (data['colorHex'] as String?) ?? '#D4AF37',
            priorityOrder: priority,
            subServices: subServices,
            isPremium: true,
            categoryType: 'premium',
          ));
        }
      } catch (e) {
        debugPrint('ℹ️ [CategoryFetch] Error fetching premium_categories: $e');
      }

      // Check if any category inside 'categories' collection itself is flagged as premium
      for (final cat in allCats) {
        if (cat.isPremium || cat.categoryType == 'premium') {
          if (!premiumList.any((p) => p.id == cat.id)) {
            premiumList.add(cat);
          }
        }
      }

      // Strict segregation: exclude premium categories from general categories
      final generalList = allCats
          .where((c) => !c.isPremium && c.categoryType != 'premium' && !premiumList.any((p) => p.id == c.id))
          .toList();

      generalList.sort((a, b) => a.priorityOrder.compareTo(b.priorityOrder));
      premiumList.sort((a, b) => a.priorityOrder.compareTo(b.priorityOrder));

      // 3. Fetch dynamic Professional categories from Firestore 'diamond_categories' collection
      final List<Map<String, dynamic>> proList = [];
      try {
        final dSnap = await FirebaseFirestore.instance
            .collection('diamond_categories')
            .where('isActive', isEqualTo: true)
            .get();
        for (final doc in dSnap.docs) {
          final data = doc.data();
          final isActive = (data['isActive'] as bool?) ?? true;
          if (isActive) {
            proList.add({'id': doc.id, ...data});
          }
        }
        proList.sort((a, b) => ((a['priorityOrder'] as num?) ?? 0).compareTo((b['priorityOrder'] as num?) ?? 0));
      } catch (e) {
        debugPrint('ℹ️ [CategoryFetch] Error fetching diamond_categories: $e');
      }

      if (mounted) {
        setState(() {
          _adminCategories = generalList;
          _premiumCategories = premiumList;
          _professionalCategories = proList;
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingCategories = false;
          _categoriesError = 'श्रेणियाँ लोड नहीं हो सकीं: $e';
        });
      }
    }
  }

  Future<void> _restoreDraftFromFirestore(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('providers').doc(uid).get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        final regStatus = data['registrationStatus']?.toString().toLowerCase().trim();
        final statusStr = data['status']?.toString().toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '');
        final List<dynamic> completedSteps = (data['completedSteps'] as List<dynamic>?) ?? [];
        final bool isAlreadyComplete = regStatus == 'completed' ||
            statusStr == 'pendingreview' ||
            statusStr == 'approved' ||
            completedSteps.contains(5);

        if (isAlreadyComplete) {
          final profile = ProviderProfileModel.fromMap(data, uid);
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: context.read<ProviderAuthBloc>(),
                child: ProviderRoleAwareWorkspace(profile: profile),
              ),
            ),
            (route) => false,
          );
          return;
        }

        setState(() {
          if (_fullNameController.text.isEmpty && data['fullName'] != null) {
            _fullNameController.text = data['fullName'].toString();
          }
          if (_phoneController.text.isEmpty && data['phoneNumber'] != null) {
            _phoneController.text = data['phoneNumber'].toString().replaceAll('+91', '');
            _isPhoneVerified = true;
          }
          if (_emailController.text.isEmpty && data['email'] != null) {
            _emailController.text = data['email'].toString();
          }
          if (data['businessName'] != null && _businessNameController.text.isEmpty) {
            _businessNameController.text = data['businessName'].toString();
          }
          if (data['businessDescription'] != null && _businessDescController.text.isEmpty) {
            _businessDescController.text = data['businessDescription'].toString();
          }
          if (data['primaryCategoryId'] != null) {
            _primaryCategoryId = data['primaryCategoryId'].toString();
          }
          if (data['primaryCategoryTitle'] != null) {
            _primaryCategoryTitle = data['primaryCategoryTitle'].toString();
          }
          if (data['categoryType'] != null) {
            _selectedCategoryType = data['categoryType'].toString();
          }
          if (data['premiumServiceDetails'] != null && _premiumServiceDetailsController.text.isEmpty) {
            _premiumServiceDetailsController.text = data['premiumServiceDetails'].toString();
          }
          if (data['generalServiceDetails'] != null && _generalServiceDetailsController.text.isEmpty) {
            _generalServiceDetailsController.text = data['generalServiceDetails'].toString();
          }
          if (data['subServices'] is List) {
            _selectedSubServices = List<String>.from((data['subServices'] as List).map((e) => e.toString()));
          }
          if (data['categoryRequestStatus'] != null) {
            _categoryRequestStatus = data['categoryRequestStatus'].toString();
          }
          if (data['categoryRequestId'] != null) {
            _categoryRequestId = data['categoryRequestId'].toString();
          }
          if (data['categoryRejectionReason'] != null) {
            _categoryRejectionReason = data['categoryRejectionReason'].toString();
          }
          final savedStep = data['currentStep'] as int?;
          if (savedStep != null && widget.initialStep == null) {
            _currentStep = savedStep.clamp(0, _totalSteps - 1);
          }

          // Restore saved location draft
          final restoredLat = (data['latitude'] as num?)?.toDouble() ?? 0.0;
          final restoredLng = (data['longitude'] as num?)?.toDouble() ?? 0.0;
          if (restoredLat != 0.0 && restoredLng != 0.0) {
            _latitude = restoredLat;
            _longitude = restoredLng;
            _isLocationSelected = true;
            if (data['jamuiArea'] != null) _jamuiArea = data['jamuiArea'].toString();
            if (data['fullAddress'] != null) _fullAddress = data['fullAddress'].toString();
            if (data['pincode'] != null) _pincode = data['pincode'].toString();
            if (data['city'] != null) _city = data['city'].toString();
            if (data['serviceRadiusKm'] != null) {
              _serviceRadiusKm = (data['serviceRadiusKm'] as num).toDouble();
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error restoring draft: $e');
    }
  }

  Future<void> _checkCategoryRequestStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('providers').doc(user.uid).get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        final status = data['categoryRequestStatus']?.toString().toLowerCase() ?? '';
        final approvedCatId = data['selectedCategoryId']?.toString() ?? data['primaryCategoryId']?.toString() ?? '';
        final reason = data['categoryRejectionReason']?.toString();

        setState(() {
          if (status.isNotEmpty) _categoryRequestStatus = status;
          if (reason != null) _categoryRejectionReason = reason;
          if (status == 'approved' && approvedCatId.isNotEmpty) {
            _primaryCategoryId = approvedCatId;
            final catMatch = _adminCategories.where((c) => c.id == approvedCatId);
            if (catMatch.isNotEmpty) {
              _primaryCategoryTitle = catMatch.first.titleHindi.isNotEmpty
                  ? catMatch.first.titleHindi
                  : catMatch.first.titleEnglish;
            }
          }
        });

        if (status == 'approved') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 बधाई! आपकी Category Request स्वीकृत कर ली गई है। अब आप आगे का रजिस्ट्रेशन पूरा कर सकते हैं।'),
              backgroundColor: AppColors.success,
            ),
          );
        } else if (status == 'rejected') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ अनुरोध अस्वीकृत: ${reason ?? "कृपया विवरण संशोधित करें"}'),
              backgroundColor: AppColors.error,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ℹ️ आपका अनुरोध अभी भी समीक्षाधीन (Pending Review) है। Admin द्वारा स्वीकृति मिलने पर सूचना मिलेगी।'),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking category request status: $e');
    }
  }

  Future<void> _showCategoryRequestForm() async {
    final user = FirebaseAuth.instance.currentUser;
    final cleanFullName = _fullNameController.text.trim();
    final cleanPhone = _phoneController.text.trim().startsWith('+91')
        ? _phoneController.text.trim()
        : '+91${_phoneController.text.trim()}';

    final result = await OtherServiceDetailsModal.show(
      context,
      initialFullName: cleanFullName,
      initialPhoneNumber: cleanPhone,
      initialFullAddress: _fullAddress,
      initialJamuiArea: _jamuiArea,
      initialExperienceYears: int.tryParse(_experienceYearsController.text.trim()) ?? 1,
      initialVisitingCharge: double.tryParse(_visitingChargeController.text.trim()) ?? 100.0,
      existingData: _otherServiceData,
    );

    if (result != null) {
      setState(() => _isSubmittingCategoryRequest = true);
      try {
        final uid = user?.uid ?? 'temp_${DateTime.now().millisecondsSinceEpoch}';
        final reqRef = FirebaseFirestore.instance.collection('category_requests').doc();
        final now = FieldValue.serverTimestamp();

        await reqRef.set({
          'id': reqRef.id,
          'requestId': reqRef.id,
          'providerId': uid,
          'providerName': cleanFullName,
          'fullName': cleanFullName,
          'phoneNumber': cleanPhone,
          'email': _emailController.text.trim(),
          'serviceName': result.serviceName,
          'requestedCategoryName': result.serviceName,
          'serviceDescription': result.serviceDescription,
          'offeredServices': result.offeredServices,
          'experienceYears': result.experienceYears,
          'visitingCharge': result.visitingCharge,
          'fullAddress': result.fullAddress,
          'jamuiArea': result.jamuiArea,
          'status': 'pending_review',
          'categoryRequestStatus': 'pending_review',
          'requestType': 'category_request',
          'createdAt': now,
          'updatedAt': now,
        });

        if (user != null) {
          await FirebaseFirestore.instance.collection('providers').doc(user.uid).set({
            'categoryRequestStatus': 'pending_review',
            'categoryRequestId': reqRef.id,
            'registrationStatus': 'pending_category_approval',
            'customServiceName': result.serviceName,
            'customServiceDescription': result.serviceDescription,
            'currentStep': 1,
            'updatedAt': now,
          }, SetOptions(merge: true));
        }

        if (mounted) {
          setState(() {
            _otherServiceData = result;
            _isOtherService = true;
            _categoryRequestStatus = 'pending_review';
            _categoryRequestId = reqRef.id;
            _isSubmittingCategoryRequest = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Category Request सफलतापूर्वक सबमिट की गई! Admin समीक्षा के बाद सूचना मिलेगी।'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSubmittingCategoryRequest = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('अनुरोध सबमिट करने में विफलता: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleStep0AuthSetup() async {
    if (!_step1FormKey.currentState!.validate()) return;
    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('कृपया नियम एवं शर्तों को स्वीकार करें।'), backgroundColor: AppColors.error),
      );
      return;
    }

    final cleanEmail = _emailController.text.trim().toLowerCase();
    final cleanPassword = _passwordController.text.trim();
    final cleanFullName = _fullNameController.text.trim();
    final rawPhone = _phoneController.text.trim().replaceAll(RegExp(r'\D'), '');
    final cleanPhone = rawPhone.isNotEmpty
        ? '+91${rawPhone.length >= 10 ? rawPhone.substring(rawPhone.length - 10) : rawPhone}'
        : '';

    setState(() => _isSavingDraft = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;

      // 1. Cross-account collision guard for email
      if (cleanEmail.isNotEmpty) {
        final emailQuery = await FirebaseFirestore.instance
            .collection('providers')
            .where('email', isEqualTo: cleanEmail)
            .limit(1)
            .get();
        if (emailQuery.docs.isNotEmpty && emailQuery.docs.first.id != user?.uid) {
          throw 'यह ईमेल ($cleanEmail) पहले से किसी अन्य प्रदाता खाते से जुड़ा हुआ है। कृपया लॉगिन करें या दूसरा ईमेल दर्ज करें।';
        }
      }

      // 2. Cross-account collision guard for phone
      if (cleanPhone.isNotEmpty) {
        final phoneQuery = await FirebaseFirestore.instance
            .collection('providers')
            .where('phoneNumber', isEqualTo: cleanPhone)
            .limit(1)
            .get();
        if (phoneQuery.docs.isNotEmpty && phoneQuery.docs.first.id != user?.uid) {
          throw 'यह मोबाइल नंबर ($cleanPhone) पहले से किसी अन्य प्रदाता खाते से जुड़ा हुआ है। कृपया सीधे लॉगिन करें।';
        }
      }

      if (user == null) {
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: cleanEmail,
          password: cleanPassword,
        );
        user = cred.user;
      } else {
        if (cleanEmail.isNotEmpty && cleanPassword.isNotEmpty) {
          final emailAuthCredential = EmailAuthProvider.credential(
            email: cleanEmail,
            password: cleanPassword,
          );

          final existingProviders = user.providerData.map((p) => p.providerId).toSet();
          if (!existingProviders.contains('password')) {
            try {
              final linkResult = await user.linkWithCredential(emailAuthCredential);
              user = linkResult.user ?? user;
            } on FirebaseAuthException catch (linkErr) {
              debugPrint('⚠️ [Registration] linkWithCredential error: ${linkErr.code} - ${linkErr.message}');
              if (linkErr.code == 'credential-already-in-use' || linkErr.code == 'email-already-in-use') {
                throw 'यह ईमेल ($cleanEmail) पहले से किसी अन्य खाते से जुड़ा हुआ है। कृपया कोई दूसरा ईमेल दर्ज करें।';
              } else if (linkErr.code == 'provider-already-linked') {
                try {
                  await user?.updatePassword(cleanPassword);
                } catch (_) {}
              } else {
                throw AuthExceptionHandler.handleException(linkErr);
              }
            }
          } else {
            try {
              await user.updatePassword(cleanPassword);
            } catch (_) {}
          }
        }
      }

      if (user != null) {
        if (cleanFullName.isNotEmpty) {
          try {
            await user.updateDisplayName(cleanFullName);
          } catch (_) {}
        }
        if (!user.emailVerified && cleanEmail.isNotEmpty) {
          try {
            await user.sendEmailVerification();
          } catch (_) {}
        }

        // Check if provider already has completed registration before writing draft
        final existingDoc = await FirebaseFirestore.instance.collection('providers').doc(user.uid).get();
        if (existingDoc.exists) {
          final data = existingDoc.data()!;
          final regStatus = data['registrationStatus']?.toString().toLowerCase().trim();
          final statusStr = data['status']?.toString().toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '');
          final List<dynamic> completedSteps = (data['completedSteps'] as List<dynamic>?) ?? [];
          final bool isComplete = regStatus == 'completed' ||
              statusStr == 'pendingreview' ||
              statusStr == 'approved' ||
              completedSteps.contains(5);

          if (isComplete) {
            final profile = ProviderProfileModel.fromMap(data, user.uid);
            if (mounted) {
              setState(() => _isSavingDraft = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('यह प्रदाता खाता पहले ही पंजीकृत हो चुका है। डैशबोर्ड पर भेजा जा रहा है...'),
                  backgroundColor: AppColors.info,
                ),
              );
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => BlocProvider.value(
                    value: context.read<ProviderAuthBloc>(),
                    child: ProviderRoleAwareWorkspace(profile: profile),
                  ),
                ),
                (route) => false,
              );
            }
            return;
          }
        }

        await FirebaseFirestore.instance.collection('providers').doc(user.uid).set({
          'uid': user.uid,
          'id': user.uid,
          'fullName': cleanFullName,
          'ownerName': cleanFullName,
          'phoneNumber': cleanPhone,
          'phone': cleanPhone,
          'email': cleanEmail,
          'status': 'draft',
          'registrationStatus': 'draft',
          'verificationStatus': 'pending',
          'currentStep': 1,
          'completedSteps': [0],
          'isMobileVerified': cleanPhone.isNotEmpty,
          'isEmailVerified': user.emailVerified,
          'isVerified': false,
          'isSubscriptionActive': false,
          'paymentVerified': false,
          'rating': 5.0,
          'ratingCount': 0,
          'subscriptionPlan': 'none',
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt': existingDoc.exists && existingDoc.data()?['createdAt'] != null
              ? existingDoc.data()!['createdAt']
              : FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (mounted) {
          setState(() {
            _isSavingDraft = false;
            _currentStep = 1;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ खाता सुरक्षित रूप से स्थापित हो गया! अब अपनी सेवा श्रेणी चुनें।'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingDraft = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AuthExceptionHandler.handleException(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // Real GPS acquisition
  Future<void> _fetchRealGPSLocation({bool showFeedback = true}) async {
    setState(() => _isFetchingGPS = true);
    try {
      final position = await _locationDataSource.getCurrentPosition();
      final geocoded = await _locationDataSource.reverseGeocode(
        position.latitude,
        position.longitude,
        accuracy: position.accuracy,
        serviceRadiusKm: _serviceRadiusKm,
      );

      if (mounted) {
        setState(() {
          _latitude = geocoded.latitude;
          _longitude = geocoded.longitude;
          _jamuiArea = geocoded.placeName.isNotEmpty
              ? geocoded.placeName
              : (geocoded.locality.isNotEmpty ? geocoded.locality : (geocoded.village.isNotEmpty ? geocoded.village : ''));
          _fullAddress = geocoded.formattedAddress;
          _pincode = geocoded.pincode;
          _city = geocoded.city.isNotEmpty ? geocoded.city : (geocoded.district.isNotEmpty ? geocoded.district : '');
          _isLocationSelected = true;
          _isFetchingGPS = false;
        });

        // Safely move map pin only if FlutterMap is already mounted (i.e. user is on Location Step 3)
        try {
          if (_currentStep == 2) {
            _mapController.move(LatLng(_latitude, _longitude), 16.0);
          }
        } catch (_) {
          // MapController not yet mounted; coordinates are saved in state and FlutterMap
          // will automatically initialize with LatLng(_latitude, _longitude) when rendered
        }

        if (showFeedback && _currentStep == 2) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('📍 GPS स्थान प्राप्त: $_jamuiArea (${_latitude.toStringAsFixed(4)}, ${_longitude.toStringAsFixed(4)})'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFetchingGPS = false);
        if (showFeedback && _currentStep == 2) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('GPS त्रुटि: ${e.toString().replaceAll('Exception: ', '')}'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  // Step Validation & Navigation
  Future<void> _goToNextStep() async {
    if (_currentStep == 0) {
      await _handleStep0AuthSetup();
      return;
    } else if (_currentStep == 1) {
      if (_categoryRequestStatus == 'pending_review') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('आपकी Category Request अभी निरीक्षण में है। Admin की स्वीकृति के बाद ही आप registration जारी रख सकेंगे।'),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }
      if (_categoryRequestStatus == 'rejected') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('आपकी Category Request अस्वीकृत हो चुकी है। कृपया संशोधित अनुरोध सबमिट करें या उपलब्ध श्रेणी चुनें।'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      if (_primaryCategoryId.isEmpty && !_isOtherService) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('कृपया कम से कम एक मुख्य सेवा श्रेणी चुनें या "मेरी श्रेणी उपलब्ध नहीं है" पर टैप करें।'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      // If Professional (Pro) Category is chosen, route directly to dedicated Professional Shop Registration Flow
      if (_selectedCategoryType == 'professional' || _selectedCategoryType == 'diamond') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfessionalShopRegistrationPage(
              initialFullName: _fullNameController.text.trim(),
              initialEmail: _emailController.text.trim().toLowerCase(),
              initialPhone: _phoneController.text.trim(),
              selectedCategoryId: _primaryCategoryId,
              selectedCategoryTitle: _primaryCategoryTitle,
            ),
          ),
        );
        return;
      }


      // If Premium Category is chosen, validate that the dedicated premium details field is filled
      if (_selectedCategoryType == 'premium' && !_isOtherService) {
        if (_premiumServiceDetailsController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('कृपया $_primaryCategoryTitle के लिए अपनी प्रीमियम सेवा का विवरण दर्ज करें।'),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }
      }

      // Save Step 1 draft to Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          final isPremCat = _selectedCategoryType == 'premium' || _primaryCategoryId == 'unisex_salon';
          await FirebaseFirestore.instance.collection('providers').doc(user.uid).set({
            'primaryCategoryId': _primaryCategoryId,
            'primaryCategoryTitle': _primaryCategoryTitle,
            'selectedCategoryId': _primaryCategoryId,
            'selectedCategoryIds': _selectedCategoryIds,
            'categoryType': isPremCat ? 'premium' : 'general',
            'isPremiumCategory': isPremCat,
            'premiumServiceDetails': isPremCat ? _premiumServiceDetailsController.text.trim() : '',
            'generalServiceDetails': !isPremCat ? _generalServiceDetailsController.text.trim() : '',
            'subServices': _selectedSubServices,
            'currentStep': 2,
            'completedSteps': FieldValue.arrayUnion([0, 1]),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('Error saving step 1 draft: $e');
        }
      }
    } else if (_currentStep == 2) {
      if (!_step2FormKey.currentState!.validate()) return;
      // Save Step 2 draft to Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await FirebaseFirestore.instance.collection('providers').doc(user.uid).set({
            'businessName': _businessNameController.text.trim(),
            'businessDescription': _businessDescController.text.trim(),
            'businessType': _businessType,
            'visitingCharge': double.tryParse(_visitingChargeController.text.trim()) ?? 100.0,
            'experienceYears': int.tryParse(_experienceYearsController.text.trim()) ?? 1,
            'profileImageUrl': _profileImageUrl,
            'businessImageUrl': _businessImageUrl,
            'currentStep': 3,
            'completedSteps': FieldValue.arrayUnion([0, 1, 2]),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('Error saving step 2 draft: $e');
        }
      }
    } else if (_currentStep == 3) {
      if (!_isLocationSelected || _latitude == 0.0 || _longitude == 0.0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('कृपया अपना वास्तविक GPS स्थान चुनें।'), backgroundColor: AppColors.error),
        );
        return;
      }
      // Save Step 3 draft to Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await FirebaseFirestore.instance.collection('providers').doc(user.uid).set({
            'latitude': _latitude,
            'longitude': _longitude,
            'jamuiArea': _jamuiArea,
            'fullAddress': _fullAddress,
            'pincode': _pincode,
            'city': _city,
            'serviceRadiusKm': _serviceRadiusKm,
            'currentStep': 4,
            'completedSteps': FieldValue.arrayUnion([0, 1, 2, 3]),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('Error saving step 3 draft: $e');
        }
      }
    } else if (_currentStep == 4) {
      if (!_step5FormKey.currentState!.validate()) return;
      // Save Step 4 draft to Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await FirebaseFirestore.instance.collection('providers').doc(user.uid).set({
            'workingHours': _workingHoursController.text.trim(),
            'previousOrganization': _previousOrgController.text.trim(),
            'experienceDescription': _experienceDescController.text.trim(),
            'hasExperienceCertificate': _hasExperienceCert,
            'experienceCertificateUrl': _experienceCertUrl,
            'isAvailable': _isEmergencyAvailable,
            'currentStep': 5,
            'completedSteps': FieldValue.arrayUnion([0, 1, 2, 3, 4]),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('Error saving step 4 draft: $e');
        }
      }
    }

    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
    }
  }

  void _goToPreviousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  Uint8List? _localProfileImageBytes;
  Uint8List? _localBusinessImageBytes;
  Uint8List? _localCertBytes;

  // Final Registration Submission
  Future<void> _submitFullRegistration() async {
    if (_isSubmittingFinal) return;
    setState(() => _isSubmittingFinal = true);

    try {
      final cleanEmail = _emailController.text.trim().toLowerCase();
      final cleanPassword = _passwordController.text.trim();
      final cleanFullName = _fullNameController.text.trim();
      final rawPhone = _phoneController.text.trim().replaceAll(RegExp(r'\D'), '');
      final cleanPhone = rawPhone.isNotEmpty
          ? '+91${rawPhone.length >= 10 ? rawPhone.substring(rawPhone.length - 10) : rawPhone}'
          : '';

      // 1. Mandatory Cross-Step Form Validations
      if (cleanFullName.isEmpty) {
        throw 'रजिस्ट्रेशन के लिए पूरा नाम अनिवार्य है। कृपया स्टेप 1 पर नाम दर्ज करें।';
      }
      if (cleanPhone.isEmpty || rawPhone.length < 10) {
        throw 'कृपया 10 अंकों का वैध मोबाइल नंबर दर्ज करें (स्टेप 1)।';
      }
      if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
        throw 'कृपया एक वैध ईमेल पता दर्ज करें (स्टेप 1)।';
      }
      if (_businessNameController.text.trim().isEmpty) {
        throw 'कृपया अपनी दुकान या व्यवसाय का नाम दर्ज करें (स्टेप 2)।';
      }
      if (!_isOtherService && _primaryCategoryId.isEmpty) {
        throw 'कृपया अपनी प्राथमिक सेवा श्रेणी चुनें (स्टेप 3)।';
      }
      if (_fullAddress.trim().isEmpty || _latitude == 0.0 || _longitude == 0.0) {
        throw 'कृपया अपने कार्यक्षेत्र का स्थान और पता दर्ज करें (स्टेप 4)।';
      }

      User? user = FirebaseAuth.instance.currentUser;

      // 2. Cross-account collision prevention for email
      final emailQuery = await FirebaseFirestore.instance
          .collection('providers')
          .where('email', isEqualTo: cleanEmail)
          .limit(1)
          .get();
      if (emailQuery.docs.isNotEmpty && emailQuery.docs.first.id != user?.uid) {
        throw 'यह ईमेल ($cleanEmail) पहले से किसी अन्य प्रदाता खाते से जुड़ा हुआ है। कृपया लॉगिन करें या दूसरा ईमेल उपयोग करें।';
      }

      // 3. Cross-account collision prevention for phone
      final phoneQuery = await FirebaseFirestore.instance
          .collection('providers')
          .where('phoneNumber', isEqualTo: cleanPhone)
          .limit(1)
          .get();
      if (phoneQuery.docs.isNotEmpty && phoneQuery.docs.first.id != user?.uid) {
        throw 'यह मोबाइल नंबर ($cleanPhone) पहले से किसी अन्य प्रदाता खाते से जुड़ा हुआ है। कृपया सीधे लॉगिन करें।';
      }

      // If user not signed in, register with Email & Password
      if (user == null) {
        if (cleanEmail.isEmpty || cleanPassword.isEmpty) {
          throw 'रजिस्ट्रेशन पूरा करने के लिए वैध ईमेल और कम से कम 6 अक्षरों का पासवर्ड आवश्यक है।';
        }
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: cleanEmail,
          password: cleanPassword,
        );
        user = cred.user;
        if (user != null) {
          try {
            await user.updateDisplayName(cleanFullName);
          } catch (_) {}
          try {
            await user.sendEmailVerification();
          } catch (_) {}
        }
      } else {
        // User is already signed in (e.g. via Phone OTP in Step 0).
        // Link Email & Password credential so provider can log in with Email/Password.
        if (cleanEmail.isNotEmpty && cleanPassword.isNotEmpty) {
          final emailAuthCredential = EmailAuthProvider.credential(
            email: cleanEmail,
            password: cleanPassword,
          );

          final existingProviders = user.providerData.map((p) => p.providerId).toSet();
          if (!existingProviders.contains('password')) {
            try {
              final linkResult = await user.linkWithCredential(emailAuthCredential);
              user = linkResult.user ?? user;
            } on FirebaseAuthException catch (linkErr) {
              debugPrint('⚠️ [Registration] linkWithCredential error: ${linkErr.code} - ${linkErr.message}');
              if (linkErr.code == 'credential-already-in-use' || linkErr.code == 'email-already-in-use') {
                throw 'यह ईमेल ($cleanEmail) पहले से किसी अन्य खाते से जुड़ा हुआ है। कृपया कोई दूसरा ईमेल दर्ज करें या सीधे लॉगिन करें।';
              } else if (linkErr.code == 'provider-already-linked') {
                try {
                  await user?.updatePassword(cleanPassword);
                } catch (_) {}
              } else {
                throw AuthExceptionHandler.handleException(linkErr);
              }
            }
          } else {
            // Password provider already linked, update password
            try {
              await user.updatePassword(cleanPassword);
            } catch (_) {}
          }
        }

        if (cleanFullName.isNotEmpty) {
          try {
            await user?.updateDisplayName(cleanFullName);
          } catch (_) {}
        }

        if (cleanEmail.isNotEmpty && (user?.emailVerified == false)) {
          try {
            await user?.sendEmailVerification();
          } catch (_) {}
        }
      }

      if (user != null) {
        if (!mounted) return;
        final repo = context.read<ProviderAuthBloc>().providerRepository;
        final existingProfile = await repo.getProfile(user.uid);

        // 4. Already Registered Guard: Redirect to Dashboard if already completed
        final bool isAlreadyRegistered = existingProfile?.registrationStatus == 'completed' ||
            existingProfile?.status == ProviderAccountStatus.approved ||
            existingProfile?.status == ProviderAccountStatus.pendingReview ||
            (existingProfile?.completedSteps.contains(5) ?? false);

        if (isAlreadyRegistered) {
          setState(() => _isSubmittingFinal = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('यह प्रदाता खाता पहले ही पंजीकृत हो चुका है। डैशबोर्ड पर भेजा जा रहा है...'),
                backgroundColor: AppColors.info,
              ),
            );
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: context.read<ProviderAuthBloc>(),
                  child: ProviderRoleAwareWorkspace(profile: existingProfile!),
                ),
              ),
              (route) => false,
            );
          }
          return;
        }

        if (_localProfileImageBytes != null) {
          try {
            _profileImageUrl = await repo.uploadImageBytes(
              providerId: user.uid,
              imageBytes: _localProfileImageBytes!,
              folder: 'profile',
              mimeType: 'image/jpeg',
            );
          } catch (e) {
            debugPrint('Profile photo upload error: $e');
          }
        }

        if (_localBusinessImageBytes != null) {
          try {
            _businessImageUrl = await repo.uploadImageBytes(
              providerId: user.uid,
              imageBytes: _localBusinessImageBytes!,
              folder: 'business',
              mimeType: 'image/jpeg',
            );
          } catch (e) {
            debugPrint('Business photo upload error: $e');
          }
        }

        if (_localCertBytes != null) {
          try {
            _experienceCertUrl = await repo.uploadImageBytes(
              providerId: user.uid,
              imageBytes: _localCertBytes!,
              folder: 'certificates',
              mimeType: 'image/jpeg',
            );
          } catch (e) {
            debugPrint('Certificate upload error: $e');
          }
        }

        // If Other Service selected, submit the Custom Service Application
        if (_isOtherService && _otherServiceData != null) {
          final customApp = CustomServiceApplicationModel(
            id: user.uid,
            providerId: user.uid,
            providerName: cleanFullName.isNotEmpty
                ? cleanFullName
                : _otherServiceData!.fullName,
            phoneNumber: cleanPhone,
            serviceName: _otherServiceData!.serviceName,
            serviceDescription: _otherServiceData!.serviceDescription,
            offeredServices: _otherServiceData!.offeredServices,
            experienceYears: _otherServiceData!.experienceYears,
            visitingCharge: _otherServiceData!.visitingCharge,
            fullAddress: _fullAddress.isNotEmpty ? _fullAddress : _otherServiceData!.fullAddress,
            jamuiArea: _jamuiArea.isNotEmpty ? _jamuiArea : _otherServiceData!.jamuiArea,
            status: CustomServiceStatus.pendingReview,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          await repo.submitCustomServiceApplication(customApp);
        }

        final profile = ProviderProfileEntity(
          id: user.uid,
          email: cleanEmail,
          phoneNumber: cleanPhone,
          fullName: cleanFullName,
          isMobileVerified: _isPhoneVerified,
          isEmailVerified: user.emailVerified || _isEmailVerified,
          businessName: _businessNameController.text.trim(),
          businessDescription: _businessDescController.text.trim(),
          businessType: _businessType,
          primaryCategoryId: _isOtherService ? 'custom_pending' : _primaryCategoryId,
          primaryCategoryTitle: _isOtherService
              ? (_otherServiceData?.serviceName ?? 'अन्य सेवा (समीक्षाधीन)')
              : _primaryCategoryTitle,
          selectedCategoryIds: _isOtherService ? ['custom_pending'] : _selectedCategoryIds,
          categoryType: (_selectedCategoryType == 'premium' || _primaryCategoryId == 'unisex_salon') ? 'premium' : 'general',
          premiumServiceDetails: _selectedCategoryType == 'premium' ? _premiumServiceDetailsController.text.trim() : '',
          generalServiceDetails: _selectedCategoryType == 'general' ? _generalServiceDetailsController.text.trim() : '',
          subServices: _selectedSubServices,
          experienceYears: int.tryParse(_experienceYearsController.text.trim()) ?? 1,
          visitingCharge: double.tryParse(_visitingChargeController.text.trim()) ?? 100.0,
          serviceRadiusKm: _serviceRadiusKm,
          jamuiArea: _jamuiArea,
          fullAddress: _fullAddress,
          latitude: _latitude,
          longitude: _longitude,
          profileImageUrl: _profileImageUrl,
          businessImageUrl: _businessImageUrl,
          workingHours: _workingHoursController.text.trim(),
          hasExperienceCertificate: _hasExperienceCert,
          experienceCertificateUrl: _experienceCertUrl,
          experienceCertificateStatus: _hasExperienceCert && _experienceCertUrl.isNotEmpty ? 'pendingReview' : 'notUploaded',
          previousOrganization: _previousOrgController.text.trim(),
          experienceDescription: _experienceDescController.text.trim(),
          isAvailable: true,
          isOtherService: _isOtherService,
          customServiceStatus: _isOtherService ? 'pending_review' : 'none',
          customServiceName: _isOtherService ? (_otherServiceData?.serviceName ?? '') : '',
          customServiceDescription: _isOtherService ? (_otherServiceData?.serviceDescription ?? '') : '',
          customServiceOffered: _isOtherService ? (_otherServiceData?.offeredServices ?? '') : '',
          kycStatus: _isOtherService
              ? ProviderKycStatus.pendingReview
              : ((existingProfile?.kycStatus == ProviderKycStatus.approved || widget.initialProfile?.kycStatus == ProviderKycStatus.approved)
                  ? ProviderKycStatus.approved
                  : ProviderKycStatus.pendingReview),
          status: _isOtherService
              ? ProviderAccountStatus.pendingReview
              : ((existingProfile?.status == ProviderAccountStatus.approved || widget.initialProfile?.status == ProviderAccountStatus.approved)
                  ? ProviderAccountStatus.approved
                  : ProviderAccountStatus.pendingReview),
          registrationStatus: 'completed',
          currentStep: 5,
          completedSteps: const [0, 1, 2, 3, 4, 5],
          selectedCategoryId: _isOtherService ? 'custom_pending' : _primaryCategoryId,
          categoryRequestStatus: _categoryRequestStatus,
          categoryRequestId: _categoryRequestId,
          categoryRejectionReason: _categoryRejectionReason,
          subscriptionPlan: existingProfile?.subscriptionPlan ?? (widget.initialProfile?.subscriptionPlan ?? 'none'),
          isSubscriptionActive: existingProfile?.isSubscriptionActive ?? (widget.initialProfile?.isSubscriptionActive ?? false),
          subscriptionExpiry: existingProfile?.subscriptionExpiry ?? widget.initialProfile?.subscriptionExpiry,
          paymentVerified: existingProfile?.paymentVerified ?? (widget.initialProfile?.paymentVerified ?? false),
          createdAt: existingProfile?.createdAt ?? (widget.initialProfile?.createdAt ?? DateTime.now()),
          updatedAt: DateTime.now(),
        );

        // Persist profile to Firestore directly first to ensure document is saved before triggering navigation
        await repo.saveProfile(profile);

        if (mounted) {
          context.read<ProviderAuthBloc>().add(UpdateProviderProfileEvent(profile));
          setState(() => _isSubmittingFinal = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ रजिस्ट्रेशन विवरण सफलतापूर्वक दर्ज हो गया! डैशबोर्ड पर भेजा जा रहा है...'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: context.read<ProviderAuthBloc>(),
                child: ProviderRoleAwareWorkspace(profile: profile),
              ),
            ),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmittingFinal = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('रजिस्ट्रेशन त्रुटि: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: _goToPreviousStep,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('प्रोवाइडर रजिस्ट्रेशन', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
            Text('चरण ${_currentStep + 1} / $_totalSteps: ${_getStepTitle(_currentStep)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Linear Progress Indicator
            LinearProgressIndicator(
              value: (_currentStep + 1) / _totalSteps,
              backgroundColor: Colors.grey.shade200,
              color: AppColors.primary,
              minHeight: 4,
            ),

            // Step Indicator Header
            _buildStepIndicatorHeader(),

            // Step Content
            Expanded(
              child: SingleChildScrollView(
                child: ResponsiveFormShell(
                  maxWidth: 740,
                  child: _buildCurrentStepContent(),
                ),
              ),
            ),

            // Bottom Navigation Actions
            _buildBottomActionBar(),
          ],
        ),
      ),
    );
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'खाता विवरण (Account Setup)';
      case 1:
        return 'सेवा श्रेणी (Category Selection)';
      case 2:
        return 'व्यवसाय प्रोफ़ाइल (Business Profile)';
      case 3:
        return 'स्थान व GPS (Location & GPS)';
      case 4:
        return 'कार्य समय व अनुभव (Working Details)';
      case 5:
        return 'समीक्षा व सबमिशन (Review & Submit)';
      default:
        return '';
    }
  }

  Widget _buildStepIndicatorHeader() {
    final isSmall = ResponsiveLayout.isSmallMobile(context);
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isSmall ? 10 : 16, vertical: 12),
      child: ResponsiveContentContainer(
        maxWidth: 680,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(_totalSteps, (index) {
            final isPassed = index < _currentStep;
            final isCurrent = index == _currentStep;

            return InkWell(
              onTap: isPassed ? () => setState(() => _currentStep = index) : null,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: isSmall ? 10 : 12,
                    backgroundColor: isPassed
                        ? AppColors.success
                        : isCurrent
                            ? AppColors.primary
                            : Colors.grey.shade300,
                    child: isPassed
                        ? Icon(Icons.check, size: isSmall ? 12 : 14, color: Colors.white)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: isSmall ? 10 : 11,
                              fontWeight: FontWeight.bold,
                              color: isCurrent ? Colors.white : Colors.grey.shade700,
                            ),
                          ),
                  ),
                  if (index < _totalSteps - 1)
                    Container(
                      width: isSmall ? 12 : 20,
                      height: 2,
                      color: index < _currentStep ? AppColors.success : Colors.grey.shade300,
                      margin: EdgeInsets.symmetric(horizontal: isSmall ? 2 : 4),
                    ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Account();
      case 1:
        return _buildStep2Categories();
      case 2:
        return _buildStep3BusinessProfile();
      case 3:
        return _buildStep4Location();
      case 4:
        return _buildStep5WorkingDetails();
      case 5:
        return _buildStep6ReviewAndSubmit();
      default:
        return const SizedBox();
    }
  }

  // ---------------- SCREEN 1: ACCOUNT ----------------
  Widget _buildStep1Account() {
    return Form(
      key: _step1FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader('👤 व्यक्तिगत खाता विवरण', 'अपने नाम, मोबाइल व ईमेल के साथ सुरक्षित खाता बनाएं।'),
          const SizedBox(height: 16),

          // Full Name
          TextFormField(
            controller: _fullNameController,
            decoration: InputDecoration(
              labelText: 'पूरा नाम (Full Name) *',
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'कृपया अपना पूरा नाम लिखें' : null,
          ),
          const SizedBox(height: 16),

          // Business Contact Mobile Number (Used for customer leads & Razorpay receipts; no OTP verification needed)
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            decoration: InputDecoration(
              labelText: 'संपर्क मोबाइल नंबर (Business Contact Mobile)',
              hintText: '9876543210',
              helperText: 'ग्राहकों एवं पेमेंट रसीद हेतु संपर्क नंबर (OTP की आवश्यकता नहीं)',
              prefixText: '+91 ',
              prefixIcon: const Icon(Icons.phone_android_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (v) {
              if (v != null && v.trim().isNotEmpty && v.trim().length < 10) {
                return 'कृपया 10 अंकों का वैध मोबाइल नंबर दर्ज करें';
              }
              return null;
            },
          ),


        // ================= SECTION 2.5: PROFESSIONAL MARKETPLACE CATEGORIES =================
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(Icons.storefront_outlined, color: Color(0xFF0D6E57), size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                '🏬 प्रोफेशनल श्रेणियाँ (Professional Pro Categories)',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'एडमिन द्वारा प्रोफेशनल मार्केटप्लेस में बनाई गई श्रेणियां (दुकानें, किराना, सब्जी, ज्वैलरी आदि)',
          style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 10),

        if (_professionalCategories.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.teal.shade50.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.teal.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.storefront_outlined, color: Colors.teal.shade800, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'वर्तमान में कोई प्रोफेशनल श्रेणी सक्रिय नहीं है। एडमिन पैनल के प्रोफेशनल सेक्शन से श्रेणियाँ जोड़ी जा सकती हैं।',
                    style: TextStyle(fontSize: 12, color: Colors.teal.shade900, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _professionalCategories.length,
            itemBuilder: (context, index) {
              final cat = _professionalCategories[index];
              final catId = (cat['id'] as String?) ?? '';
              final titleEng = (cat['titleEnglish'] as String?) ?? (cat['name'] as String?) ?? catId;
              final titleHin = (cat['titleHindi'] as String?) ?? (cat['nameHindi'] as String?) ?? titleEng;
              final isSelected = _primaryCategoryId == catId && _selectedCategoryType == 'diamond';

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isSelected ? const Color(0xFF0D6E57) : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                color: isSelected ? const Color(0xFFE8F5E9) : Colors.white,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    setState(() {
                      _isOtherService = false;
                      _primaryCategoryId = catId;
                      _primaryCategoryTitle = titleHin.isNotEmpty ? titleHin : titleEng;
                      _selectedCategoryIds = [catId];
                      _selectedCategoryType = 'diamond';
                      _selectedSubServices = [titleEng];
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: const Color(0xFF0D6E57).withValues(alpha: 0.12),
                          child: const Icon(Icons.storefront_rounded, color: Color(0xFF0D6E57), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      titleHin.isNotEmpty ? titleHin : titleEng,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: isSelected ? const Color(0xFF1B5E20) : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0D6E57).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'PRO',
                                      style: TextStyle(color: Color(0xFF0D6E57), fontSize: 9, fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                titleEng,
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? const Color(0xFF0D6E57) : Colors.grey.shade400,
                              width: 2,
                            ),
                            color: isSelected ? const Color(0xFF0D6E57) : Colors.transparent,
                          ),
                          child: isSelected
                              ? const Center(
                                  child: Icon(Icons.check, size: 14, color: Colors.white),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Email
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'ईमेल आईडी (Email) *',
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


        // ================= SECTION 2.5: PROFESSIONAL MARKETPLACE CATEGORIES =================
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(Icons.storefront_outlined, color: Color(0xFF0D6E57), size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                '🏬 प्रोफेशनल श्रेणियाँ (Professional Pro Categories)',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'एडमिन द्वारा प्रोफेशनल मार्केटप्लेस में बनाई गई श्रेणियां (दुकानें, किराना, सब्जी, ज्वैलरी आदि)',
          style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 10),

        if (_professionalCategories.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.teal.shade50.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.teal.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.storefront_outlined, color: Colors.teal.shade800, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'वर्तमान में कोई प्रोफेशनल श्रेणी सक्रिय नहीं है। एडमिन पैनल के प्रोफेशनल सेक्शन से श्रेणियाँ जोड़ी जा सकती हैं।',
                    style: TextStyle(fontSize: 12, color: Colors.teal.shade900, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _professionalCategories.length,
            itemBuilder: (context, index) {
              final cat = _professionalCategories[index];
              final catId = (cat['id'] as String?) ?? '';
              final titleEng = (cat['titleEnglish'] as String?) ?? (cat['name'] as String?) ?? catId;
              final titleHin = (cat['titleHindi'] as String?) ?? (cat['nameHindi'] as String?) ?? titleEng;
              final isSelected = _primaryCategoryId == catId && _selectedCategoryType == 'diamond';

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isSelected ? const Color(0xFF0D6E57) : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                color: isSelected ? const Color(0xFFE8F5E9) : Colors.white,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    setState(() {
                      _isOtherService = false;
                      _primaryCategoryId = catId;
                      _primaryCategoryTitle = titleHin.isNotEmpty ? titleHin : titleEng;
                      _selectedCategoryIds = [catId];
                      _selectedCategoryType = 'diamond';
                      _selectedSubServices = [titleEng];
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: const Color(0xFF0D6E57).withValues(alpha: 0.12),
                          child: const Icon(Icons.storefront_rounded, color: Color(0xFF0D6E57), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      titleHin.isNotEmpty ? titleHin : titleEng,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: isSelected ? const Color(0xFF1B5E20) : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0D6E57).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'PRO',
                                      style: TextStyle(color: Color(0xFF0D6E57), fontSize: 9, fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                titleEng,
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? const Color(0xFF0D6E57) : Colors.grey.shade400,
                              width: 2,
                            ),
                            color: isSelected ? const Color(0xFF0D6E57) : Colors.transparent,
                          ),
                          child: isSelected
                              ? const Center(
                                  child: Icon(Icons.check, size: 14, color: Colors.white),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Password
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'पासवर्ड (कम से कम 6 अक्षर) *',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (v) {
              if (widget.initialProfile == null) {
                if (v == null || v.trim().isEmpty) return 'कृपया पासवर्ड दर्ज करें';
                if (v.trim().length < 6) return 'पासवर्ड कम से कम 6 अक्षरों का होना चाहिए';
              }
              return null;
            },
          ),


        // ================= SECTION 2.5: PROFESSIONAL MARKETPLACE CATEGORIES =================
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(Icons.storefront_outlined, color: Color(0xFF0D6E57), size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                '🏬 प्रोफेशनल श्रेणियाँ (Professional Pro Categories)',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'एडमिन द्वारा प्रोफेशनल मार्केटप्लेस में बनाई गई श्रेणियां (दुकानें, किराना, सब्जी, ज्वैलरी आदि)',
          style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 10),

        if (_professionalCategories.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.teal.shade50.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.teal.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.storefront_outlined, color: Colors.teal.shade800, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'वर्तमान में कोई प्रोफेशनल श्रेणी सक्रिय नहीं है। एडमिन पैनल के प्रोफेशनल सेक्शन से श्रेणियाँ जोड़ी जा सकती हैं।',
                    style: TextStyle(fontSize: 12, color: Colors.teal.shade900, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _professionalCategories.length,
            itemBuilder: (context, index) {
              final cat = _professionalCategories[index];
              final catId = (cat['id'] as String?) ?? '';
              final titleEng = (cat['titleEnglish'] as String?) ?? (cat['name'] as String?) ?? catId;
              final titleHin = (cat['titleHindi'] as String?) ?? (cat['nameHindi'] as String?) ?? titleEng;
              final isSelected = _primaryCategoryId == catId && _selectedCategoryType == 'diamond';

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isSelected ? const Color(0xFF0D6E57) : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                color: isSelected ? const Color(0xFFE8F5E9) : Colors.white,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    setState(() {
                      _isOtherService = false;
                      _primaryCategoryId = catId;
                      _primaryCategoryTitle = titleHin.isNotEmpty ? titleHin : titleEng;
                      _selectedCategoryIds = [catId];
                      _selectedCategoryType = 'diamond';
                      _selectedSubServices = [titleEng];
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: const Color(0xFF0D6E57).withValues(alpha: 0.12),
                          child: const Icon(Icons.storefront_rounded, color: Color(0xFF0D6E57), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      titleHin.isNotEmpty ? titleHin : titleEng,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: isSelected ? const Color(0xFF1B5E20) : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0D6E57).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'PRO',
                                      style: TextStyle(color: Color(0xFF0D6E57), fontSize: 9, fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                titleEng,
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? const Color(0xFF0D6E57) : Colors.grey.shade400,
                              width: 2,
                            ),
                            color: isSelected ? const Color(0xFF0D6E57) : Colors.transparent,
                          ),
                          child: isSelected
                              ? const Center(
                                  child: Icon(Icons.check, size: 14, color: Colors.white),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Confirm Password
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'पासवर्ड पुनः दर्ज करें (Confirm Password) *',
              prefixIcon: const Icon(Icons.lock_outline),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (v) {
              if (widget.initialProfile == null && v != _passwordController.text) {
                return 'पासवर्ड मेल नहीं खाता है';
              }
              return null;
            },
          ),


        // ================= SECTION 2.5: PROFESSIONAL MARKETPLACE CATEGORIES =================
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(Icons.storefront_outlined, color: Color(0xFF0D6E57), size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                '🏬 प्रोफेशनल श्रेणियाँ (Professional Pro Categories)',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'एडमिन द्वारा प्रोफेशनल मार्केटप्लेस में बनाई गई श्रेणियां (दुकानें, किराना, सब्जी, ज्वैलरी आदि)',
          style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 10),

        if (_professionalCategories.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.teal.shade50.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.teal.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.storefront_outlined, color: Colors.teal.shade800, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'वर्तमान में कोई प्रोफेशनल श्रेणी सक्रिय नहीं है। एडमिन पैनल के प्रोफेशनल सेक्शन से श्रेणियाँ जोड़ी जा सकती हैं।',
                    style: TextStyle(fontSize: 12, color: Colors.teal.shade900, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _professionalCategories.length,
            itemBuilder: (context, index) {
              final cat = _professionalCategories[index];
              final catId = (cat['id'] as String?) ?? '';
              final titleEng = (cat['titleEnglish'] as String?) ?? (cat['name'] as String?) ?? catId;
              final titleHin = (cat['titleHindi'] as String?) ?? (cat['nameHindi'] as String?) ?? titleEng;
              final isSelected = _primaryCategoryId == catId && _selectedCategoryType == 'diamond';

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isSelected ? const Color(0xFF0D6E57) : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                color: isSelected ? const Color(0xFFE8F5E9) : Colors.white,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    setState(() {
                      _isOtherService = false;
                      _primaryCategoryId = catId;
                      _primaryCategoryTitle = titleHin.isNotEmpty ? titleHin : titleEng;
                      _selectedCategoryIds = [catId];
                      _selectedCategoryType = 'diamond';
                      _selectedSubServices = [titleEng];
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: const Color(0xFF0D6E57).withValues(alpha: 0.12),
                          child: const Icon(Icons.storefront_rounded, color: Color(0xFF0D6E57), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      titleHin.isNotEmpty ? titleHin : titleEng,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: isSelected ? const Color(0xFF1B5E20) : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0D6E57).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'PRO',
                                      style: TextStyle(color: Color(0xFF0D6E57), fontSize: 9, fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                titleEng,
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? const Color(0xFF0D6E57) : Colors.grey.shade400,
                              width: 2,
                            ),
                            color: isSelected ? const Color(0xFF0D6E57) : Colors.transparent,
                          ),
                          child: isSelected
                              ? const Center(
                                  child: Icon(Icons.check, size: 14, color: Colors.white),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Terms & Conditions Checkbox
          CheckboxListTile(
            value: _termsAccepted,
            onChanged: (val) => setState(() => _termsAccepted = val ?? false),
            title: const Text('मैं JAMUI SERVICE के नियम व गोपनीयता नीति (Terms & Privacy Policy) से सहमत हूँ।', style: TextStyle(fontSize: 12)),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  // ---------------- SCREEN 3: BUSINESS PROFILE ----------------
  Widget _buildStep3BusinessProfile() {
    return Form(
      key: _step2FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader('🏢 व्यवसाय प्रोफ़ाइल', 'दुकान या सेवा का नाम, अनुभव व कार्य विवरण भरें।'),
          const SizedBox(height: 16),

          // Business Name
          TextFormField(
            controller: _businessNameController,
            decoration: InputDecoration(
              labelText: 'दुकान / व्यवसाय का नाम (Business Name) *',
              prefixIcon: const Icon(Icons.storefront_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'कृपया व्यवसाय का नाम लिखें' : null,
          ),
          const SizedBox(height: 16),

          // Business Type Segment
          const Text('व्यवसाय का प्रकार (Business Type) *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Individual', label: Text('कारीगर / Single')),
              ButtonSegment(value: 'Small Business', label: Text('दुकानदार')),
              ButtonSegment(value: 'Agency', label: Text('एजेंसी / फर्म')),
            ],
            selected: {_businessType},
            onSelectionChanged: (set) => setState(() => _businessType = set.first),
          ),
          const SizedBox(height: 16),

          // Experience & Visiting Charge Row
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _experienceYearsController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'अनुभव (वर्ष)',
                    prefixIcon: const Icon(Icons.history_edu_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'अनुभव भरें' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _visitingChargeController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'विजिटिंग शुल्क (₹)',
                    prefixIcon: const Icon(Icons.currency_rupee),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'शुल्क भरें' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Business Description
          TextFormField(
            controller: _businessDescController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'कार्य विवरण व विशेषज्ञता (Description)',
              hintText: 'उदा. 10 साल का अनुभव, 24 घंटे प्लंबिंग व वायरिंग सेवा उपलब्ध...',
              prefixIcon: const Icon(Icons.description_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 20),

          // Photos Upload Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade300)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📸 प्रोफ़ाइल व वर्कशॉप फोटो', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('स्पष्ट फोटो अपलोड करने से ग्राहकों का विश्वास बढ़ता है।', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildPhotoUploadBox(
                        title: 'प्रोफाइल फोटो',
                        imageUrl: _profileImageUrl,
                        localBytes: _localProfileImageBytes,
                        isLoading: _isUploadingProfilePhoto,
                        onPick: () => _pickAndUploadPhoto(isProfile: true),
                        isCircle: true,
                      ),
                      _buildPhotoUploadBox(
                        title: 'दुकान/कार्य फोटो',
                        imageUrl: _businessImageUrl,
                        localBytes: _localBusinessImageBytes,
                        isLoading: _isUploadingBusinessPhoto,
                        onPick: () => _pickAndUploadPhoto(isProfile: false),
                        isCircle: false,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoUploadBox({
    required String title,
    required String imageUrl,
    Uint8List? localBytes,
    required bool isLoading,
    required VoidCallback onPick,
    bool isCircle = false,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onPick,
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
            ),
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : localBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: Image.memory(localBytes, fit: BoxFit.cover, width: 110, height: 110),
                      )
                    : imageUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: AppNetworkOrBase64Image(imageUrl: imageUrl, fit: BoxFit.cover, width: 110, height: 110),
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo_outlined, color: AppColors.primary, size: 28),
                              SizedBox(height: 6),
                              Text('फोटो चुनें', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold)),
                            ],
                          ),
          ),
        ),
        const SizedBox(height: 6),
        Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Future<void> _pickAndUploadPhoto({required bool isProfile}) async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isProfile ? 'प्रोफाइल फोटो स्रोत चुनें' : 'दुकान/कार्य फोटो स्रोत चुनें',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: Colors.blue),
                  ),
                  title: const Text('कैमरा से फोटो खींचें (Camera 📷)', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('मोबाइल कैमरा खोलकर तुरंत फोटो लें'),
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                ),
                const Divider(),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_library_rounded, color: Colors.purple),
                  ),
                  title: const Text('गैलरी से फोटो चुनें (Gallery 🖼️)', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('फोन की गैलरी से सहेजी गई फोटो चुनें'),
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null || !mounted) return;

    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (picked == null || !mounted) return;

      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty || !mounted) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // User is in registration flow (not yet signed in). Save local bytes for instant preview
        // and upload smoothly upon final submission after user account is created.
        setState(() {
          if (isProfile) {
            _localProfileImageBytes = bytes;
          } else {
            _localBusinessImageBytes = bytes;
          }
        });
        return;
      }

      setState(() {
        if (isProfile) {
          _isUploadingProfilePhoto = true;
        } else {
          _isUploadingBusinessPhoto = true;
        }
      });

      final folder = isProfile ? 'profile' : 'business';
      final url = await context.read<ProviderAuthBloc>().providerRepository.uploadImageBytes(
        providerId: user.uid,
        imageBytes: bytes,
        folder: folder,
        mimeType: 'image/jpeg',
      );

      if (mounted) {
        setState(() {
          if (isProfile) {
            _profileImageUrl = url;
            _localProfileImageBytes = bytes;
            _isUploadingProfilePhoto = false;
          } else {
            _businessImageUrl = url;
            _localBusinessImageBytes = bytes;
            _isUploadingBusinessPhoto = false;
          }
        });
      }
    } catch (e) {
      debugPrint('Photo upload error: $e');
      if (mounted) {
        setState(() {
          if (isProfile) {
            _isUploadingProfilePhoto = false;
          } else {
            _isUploadingBusinessPhoto = false;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('फोटो अपलोड विफल: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  // ---------------- SCREEN 4: LOCATION & REAL GPS ----------------
  Widget _buildStep4Location() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader('📍 वास्तविक GPS स्थान व सेवा दायरा', 'अपने कार्यस्थल का सटीक स्थान चुनें ताकि आस-पास के ग्राहक आपको खोज सकें।'),
        const SizedBox(height: 16),

        // GPS Fetch Button
        ElevatedButton.icon(
          onPressed: _isFetchingGPS ? null : _fetchRealGPSLocation,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: _isFetchingGPS
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.my_location),
          label: Text(
            _isFetchingGPS ? 'GPS सिग्नल खोजा जा रहा है...' : '📍 वर्तमान GPS स्थान प्राप्त करें',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 16),

        // Interactive Map Card (Matching Customer App Live Center Pin & Dragging)
        Container(
          height: 260,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: (_latitude != 0.0 && _longitude != 0.0)
                        ? LatLng(_latitude, _longitude)
                        : const LatLng(24.9200, 86.2200),
                    initialZoom: 16.0,
                    onPositionChanged: (camera, hasGesture) {
                      if (hasGesture) {
                        _mapDragDebounceTimer?.cancel();
                        _mapDragDebounceTimer = Timer(const Duration(milliseconds: 300), () async {
                          final center = camera.center;
                          setState(() {
                            _latitude = center.latitude;
                            _longitude = center.longitude;
                            _isLocationSelected = true;
                          });
                          final geocoded = await _locationDataSource.reverseGeocode(
                            center.latitude,
                            center.longitude,
                            serviceRadiusKm: _serviceRadiusKm,
                          );
                          if (mounted) {
                            setState(() {
                              _jamuiArea = geocoded.placeName;
                              _fullAddress = geocoded.formattedAddress;
                            });
                          }
                        });
                      }
                    },
                    onTap: (tapPosition, point) async {
                      setState(() {
                        _latitude = point.latitude;
                        _longitude = point.longitude;
                        _isLocationSelected = true;
                      });
                      try {
                        _mapController.move(point, _mapController.camera.zoom);
                      } catch (_) {}
                      final geocoded = await _locationDataSource.reverseGeocode(point.latitude, point.longitude, serviceRadiusKm: _serviceRadiusKm);
                      if (mounted) {
                        setState(() {
                          _jamuiArea = geocoded.placeName;
                          _fullAddress = geocoded.formattedAddress;
                        });
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      fallbackUrl: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                      maxZoom: 19,
                      userAgentPackageName: 'in.apnajamui.app',
                    ),
                    const SimpleAttributionWidget(
                      source: Text('© OpenStreetMap contributors, © CARTO'),
                      alignment: Alignment.bottomLeft,
                    ),
                  ],
                ),

                // Center Pin Indicator (Matching Customer App)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 35.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ScaleTransition(
                          scale: _pulseAnimation,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.error.withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.location_on, color: Colors.white, size: 24),
                          ),
                        ),
                        Container(
                          width: 4,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Map Control Buttons: Recenter GPS & Fullscreen
                Positioned(
                  top: 10,
                  right: 10,
                  child: Column(
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'recenter_gps_btn',
                        backgroundColor: Colors.white,
                        onPressed: _fetchRealGPSLocation,
                        child: const Icon(Icons.my_location_rounded, color: AppColors.primary),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'fullscreen_map',
                        backgroundColor: Colors.white,
                        child: const Icon(Icons.fullscreen, color: AppColors.primary),
                        onPressed: () async {
                          final result = await Navigator.push<ProviderLocationEntity>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProviderLocationPickerScreen(
                                initialRadiusKm: _serviceRadiusKm,
                                providerId: widget.initialProfile?.id ?? FirebaseAuth.instance.currentUser?.uid,
                                initialLocation: (_isLocationSelected && _latitude != 0.0)
                                    ? ProviderLocationEntity(
                                        latitude: _latitude,
                                        longitude: _longitude,
                                        placeName: _jamuiArea,
                                        formattedAddress: _fullAddress,
                                        city: _city,
                                        district: '',
                                        state: '',
                                        pincode: _pincode,
                                        timestamp: DateTime.now(),
                                      )
                                    : null,
                              ),
                            ),
                          );
                          if (result != null) {
                            setState(() {
                              _latitude = result.latitude;
                              _longitude = result.longitude;
                              _jamuiArea = result.placeName;
                              _fullAddress = result.formattedAddress;
                              _serviceRadiusKm = result.serviceRadiusKm;
                              _isLocationSelected = true;
                            });
                              try {
                                _mapController.move(LatLng(_latitude, _longitude), 16.0);
                              } catch (_) {}
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Geocoded Address Display Card
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.place, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _jamuiArea.isNotEmpty ? _jamuiArea : 'स्थान चुनें',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _fullAddress.isNotEmpty ? _fullAddress : 'मैप पर टैप करके या ऊपर बटन दबाकर लोकेशन सेट करें।',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const Divider(height: 16),
                Text('GPS: ${_latitude.toStringAsFixed(5)}, ${_longitude.toStringAsFixed(5)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Service Radius Slider
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('सेवा दायरा (Service Radius)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('${_serviceRadiusKm.toInt()} km', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 14)),
                  ],
                ),
                Slider(
                  value: _serviceRadiusKm,
                  min: 1.0,
                  max: 50.0,
                  divisions: 49,
                  activeColor: AppColors.primary,
                  onChanged: (v) => setState(() => _serviceRadiusKm = v),
                ),
                const Text('आप अपने केंद्र से कितनी दूरी तक सेवा प्रदान कर सकते हैं।', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  ServiceCategoryModel? _getCategoryById(String id) {
    try {
      return _premiumCategories.firstWhere(
        (c) => c.id == id,
        orElse: () => _adminCategories.firstWhere((c) => c.id == id),
      );
    } catch (_) {
      return null;
    }
  }

  void _selectCategory(ServiceCategoryModel cat) {
    setState(() {
      _isOtherService = false;
      final bool isDiffCat = _primaryCategoryId != cat.id;
      final bool isPrem = cat.id == 'unisex_salon' ||
          cat.categoryType == 'premium' ||
          cat.isPremium ||
          cat.titleEnglish.toLowerCase().contains('unisex');
      final String resolvedType = isPrem ? 'premium' : cat.categoryType;
      final bool isDiffType = _selectedCategoryType != resolvedType;

      _primaryCategoryId = cat.id;
      _primaryCategoryTitle = cat.titleHindi.isNotEmpty ? cat.titleHindi : cat.titleEnglish;
      _selectedCategoryIds = [cat.id];
      _selectedCategoryType = resolvedType;

      // When switching category, reset previous sub-services
      if (isDiffCat) {
        _selectedSubServices.clear();
      }

      // When switching between General and Premium, clear the other text field to prevent bleeding
      if (isDiffType) {
        if (resolvedType == 'premium') {
          _generalServiceDetailsController.clear();
        } else {
          _premiumServiceDetailsController.clear();
        }
      }
    });
  }

  // ---------------- SCREEN 2: CATEGORY SELECTION ----------------
  Widget _buildStep2Categories() {
    if (_categoryRequestStatus == 'pending_review') {
      return _buildCategoryRequestPendingDashboard();
    }

    if (_categoryRequestStatus == 'rejected') {
      return _buildCategoryRequestRejectedDashboard();
    }

    if (_isLoadingCategories) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: Column(
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 16),
              Text('एडमिन अधिकृत श्रेणियाँ लोड हो रही हैं...', style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
    }

    if (_categoriesError != null) {
      return Center(
        child: Column(
          children: [
            Text(_categoriesError!, style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _fetchAdminCategories, child: const Text('पुनः प्रयास करें')),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader('🛠️ सेवा श्रेणी (Category Selection)', 'एडमिन द्वारा अधिकृत सामान्य या प्रीमियम श्रेणी चुनें जिनमें आप कार्य करते हैं।'),
        const SizedBox(height: 8),

        // Plan Limit Info Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _maxAllowedCategories == 1 ? Colors.amber.shade50 : AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _maxAllowedCategories == 1 ? Colors.amber.shade300 : AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: _maxAllowedCategories == 1 ? Colors.amber.shade900 : AppColors.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _maxAllowedCategories == 1
                      ? 'प्रारंभिक रजिस्ट्रेशन में 1 ही मुख्य श्रेणी चुन सकते हैं। (चयनित: ${_primaryCategoryId.isNotEmpty ? 1 : 0}/1)\nअतिरिक्त श्रेणियों के लिए बाद में सब्सक्रिप्शन प्लान अपग्रेड कर सकेंगे।'
                      : 'सब्सक्रिप्शन / एडमिन प्लान सीमा: ${_selectedCategoryIds.length} / $_maxAllowedCategories श्रेणियाँ चुनी गई हैं।',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _maxAllowedCategories == 1 ? Colors.amber.shade900 : AppColors.primary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ================= SECTION 1: PREMIUM CATEGORIES =================
        Row(
          children: [
            const Icon(Icons.workspace_premium, color: Color(0xFFD4AF37), size: 20),
            const SizedBox(width: 8),
            const Text(
              '🌟 प्रीमियम श्रेणियाँ (Premium Categories)',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'एडमिन द्वारा अधिकृत विशेष प्रीमियम व्यवसाय श्रेणियाँ (Salon, Studio आदि)',
          style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 10),

        if (_premiumCategories.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.amber.shade50.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.workspace_premium_outlined, color: Colors.amber.shade800, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'वर्तमान में कोई प्रीमियम श्रेणी सक्रिय नहीं है। कृपया नीचे दी गई सामान्य श्रेणियों में से चुनें।',
                    style: TextStyle(fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _premiumCategories.length,
            itemBuilder: (context, index) {
              final cat = _premiumCategories[index];
              final isSelected = _primaryCategoryId == cat.id;

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isSelected ? const Color(0xFFD4AF37) : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                color: isSelected ? const Color(0xFFFFFDF5) : Colors.white,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _selectCategory(cat),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                          child: const Icon(Icons.workspace_premium, color: Color(0xFFD4AF37), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      cat.titleHindi.isNotEmpty ? cat.titleHindi : cat.titleEnglish,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: isSelected ? const Color(0xFF92400E) : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFFD4AF37), Color(0xFFF3E5AB)],
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'PREMIUM',
                                      style: TextStyle(color: Colors.black87, fontSize: 9, fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                cat.titleEnglish,
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? const Color(0xFFD4AF37) : Colors.grey.shade400,
                              width: 2,
                            ),
                            color: isSelected ? const Color(0xFFD4AF37) : Colors.transparent,
                          ),
                          child: isSelected
                              ? const Center(
                                  child: Icon(Icons.check, size: 14, color: Colors.white),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),


        // ================= SECTION 2.5: PROFESSIONAL MARKETPLACE CATEGORIES =================
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(Icons.storefront_outlined, color: Color(0xFF0D6E57), size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                '🏬 प्रोफेशनल श्रेणियाँ (Professional Pro Categories)',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'एडमिन द्वारा प्रोफेशनल मार्केटप्लेस में बनाई गई श्रेणियां (दुकानें, किराना, सब्जी, ज्वैलरी आदि)',
          style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 10),

        if (_professionalCategories.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.teal.shade50.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.teal.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.storefront_outlined, color: Colors.teal.shade800, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'वर्तमान में कोई प्रोफेशनल श्रेणी सक्रिय नहीं है। एडमिन पैनल के प्रोफेशनल सेक्शन से श्रेणियाँ जोड़ी जा सकती हैं।',
                    style: TextStyle(fontSize: 12, color: Colors.teal.shade900, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _professionalCategories.length,
            itemBuilder: (context, index) {
              final cat = _professionalCategories[index];
              final catId = (cat['id'] as String?) ?? '';
              final titleEng = (cat['titleEnglish'] as String?) ?? (cat['name'] as String?) ?? catId;
              final titleHin = (cat['titleHindi'] as String?) ?? (cat['nameHindi'] as String?) ?? titleEng;
              final isSelected = _primaryCategoryId == catId && _selectedCategoryType == 'diamond';

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isSelected ? const Color(0xFF0D6E57) : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                color: isSelected ? const Color(0xFFE8F5E9) : Colors.white,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    setState(() {
                      _isOtherService = false;
                      _primaryCategoryId = catId;
                      _primaryCategoryTitle = titleHin.isNotEmpty ? titleHin : titleEng;
                      _selectedCategoryIds = [catId];
                      _selectedCategoryType = 'diamond';
                      _selectedSubServices = [titleEng];
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: const Color(0xFF0D6E57).withValues(alpha: 0.12),
                          child: const Icon(Icons.storefront_rounded, color: Color(0xFF0D6E57), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      titleHin.isNotEmpty ? titleHin : titleEng,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: isSelected ? const Color(0xFF1B5E20) : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0D6E57).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'PRO',
                                      style: TextStyle(color: Color(0xFF0D6E57), fontSize: 9, fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                titleEng,
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? const Color(0xFF0D6E57) : Colors.grey.shade400,
                              width: 2,
                            ),
                            color: isSelected ? const Color(0xFF0D6E57) : Colors.transparent,
                          ),
                          child: isSelected
                              ? const Center(
                                  child: Icon(Icons.check, size: 14, color: Colors.white),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

        const SizedBox(height: 16),

        // ================= SECTION 2: GENERAL CATEGORIES =================
        Row(
          children: [
            const Icon(Icons.build_circle_outlined, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            const Text(
              '🛠️ सामान्य श्रेणियाँ (General Categories)',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'दैनिक घरेलू व व्यावसायिक तकनीकी सेवाएं (इलेक्ट्रीशियन, प्लम्बर, बढ़ई, पेंटर आदि)',
          style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 10),

        if (_adminCategories.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Center(
              child: Text(
                'कोई सामान्य श्रेणी उपलब्ध नहीं है।',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _adminCategories.length,
            itemBuilder: (context, index) {
              final cat = _adminCategories[index];
              final isSelected = _primaryCategoryId == cat.id;

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                color: isSelected ? AppColors.primary.withValues(alpha: 0.04) : Colors.white,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _selectCategory(cat),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          child: const Icon(Icons.handyman, color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cat.titleHindi.isNotEmpty ? cat.titleHindi : cat.titleEnglish,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                cat.titleEnglish,
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? AppColors.primary : Colors.grey.shade400,
                              width: 2,
                            ),
                            color: isSelected ? AppColors.primary : Colors.transparent,
                          ),
                          child: isSelected
                              ? const Center(
                                  child: Icon(Icons.check, size: 14, color: Colors.white),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

        // ================= SECTION 2.5: PROFESSIONAL MARKETPLACE CATEGORIES =================
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(Icons.storefront_outlined, color: Color(0xFF0D6E57), size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                '🏬 प्रोफेशनल श्रेणियाँ (Professional Pro Categories)',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'एडमिन द्वारा प्रोफेशनल मार्केटप्लेस में बनाई गई श्रेणियां (दुकानें, किराना, सब्जी, ज्वैलरी आदि)',
          style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 10),

        if (_professionalCategories.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.teal.shade50.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.teal.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.storefront_outlined, color: Colors.teal.shade800, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'वर्तमान में कोई प्रोफेशनल श्रेणी सक्रिय नहीं है। एडमिन पैनल के प्रोफेशनल सेक्शन से श्रेणियाँ जोड़ी जा सकती हैं।',
                    style: TextStyle(fontSize: 12, color: Colors.teal.shade900, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _professionalCategories.length,
            itemBuilder: (context, index) {
              final cat = _professionalCategories[index];
              final catId = (cat['id'] as String?) ?? '';
              final titleEng = (cat['titleEnglish'] as String?) ?? (cat['name'] as String?) ?? catId;
              final titleHin = (cat['titleHindi'] as String?) ?? (cat['nameHindi'] as String?) ?? titleEng;
              final isSelected = _primaryCategoryId == catId && _selectedCategoryType == 'diamond';

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isSelected ? const Color(0xFF0D6E57) : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                color: isSelected ? const Color(0xFFE8F5E9) : Colors.white,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    setState(() {
                      _isOtherService = false;
                      _primaryCategoryId = catId;
                      _primaryCategoryTitle = titleHin.isNotEmpty ? titleHin : titleEng;
                      _selectedCategoryIds = [catId];
                      _selectedCategoryType = 'diamond';
                      _selectedSubServices = [titleEng];
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: const Color(0xFF0D6E57).withValues(alpha: 0.12),
                          child: const Icon(Icons.storefront_rounded, color: Color(0xFF0D6E57), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      titleHin.isNotEmpty ? titleHin : titleEng,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: isSelected ? const Color(0xFF1B5E20) : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0D6E57).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'PRO',
                                      style: TextStyle(color: Color(0xFF0D6E57), fontSize: 9, fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                titleEng,
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? const Color(0xFF0D6E57) : Colors.grey.shade400,
                              width: 2,
                            ),
                            color: isSelected ? const Color(0xFF0D6E57) : Colors.transparent,
                          ),
                          child: isSelected
                              ? const Center(
                                  child: Icon(Icons.check, size: 14, color: Colors.white),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

        // ================= SECTION 3: DYNAMIC SERVICE DETAILS =================
        if (_primaryCategoryId.isNotEmpty && !_isOtherService) ...[
          const SizedBox(height: 16),
          if (_selectedCategoryType == 'premium') ...[
            // DEDICATED PREMIUM SERVICE CARD
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFDF5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.workspace_premium, color: Color(0xFFD4AF37), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '⭐ प्रीमियम सेवा विवरण ($_primaryCategoryTitle)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Enter your premium service details — यह विवरण ग्राहकों को प्रीमियम सूची में विशेष रूप से दिखेगा।',
                    style: TextStyle(fontSize: 11.5, color: Colors.brown),
                  ),
                  if (_getCategoryById(_primaryCategoryId)?.subServices.isNotEmpty == true) ...[
                    const SizedBox(height: 12),
                    const Text('उपलब्ध सेवाएं (चुनें):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _getCategoryById(_primaryCategoryId)!.subServices.map((sub) {
                        final isSubSelected = _selectedSubServices.contains(sub);
                        return FilterChip(
                          label: Text(sub, style: const TextStyle(fontSize: 12)),
                          selected: isSubSelected,
                          selectedColor: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                          checkmarkColor: const Color(0xFF92400E),
                          onSelected: (val) {
                            setState(() {
                              if (val) {
                                _selectedSubServices.add(sub);
                              } else {
                                _selectedSubServices.remove(sub);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 14),
                  // DEDICATED PREMIUM TEXT FIELD
                  TextFormField(
                    controller: _premiumServiceDetailsController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'प्रीमियम सेवा विवरण ($_primaryCategoryTitle) *',
                      hintText: 'उदा. $_primaryCategoryTitle से संबंधित विशेष सेवाएं, उत्पाद, पैकेज या विशेषज्ञता विवरण दर्ज करें...',
                      helperText: 'Enter your premium service details (अनिवार्य)',
                      prefixIcon: const Icon(Icons.star_rounded, color: Color(0xFFD4AF37)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // DEDICATED GENERAL SERVICE CARD
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.build_circle_outlined, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '🛠️ सामान्य सेवा विवरण ($_primaryCategoryTitle)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'अपनी श्रेणी से संबंधित सेवाएं चुनें या विवरण लिखें।',
                    style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                  if (_getCategoryById(_primaryCategoryId)?.subServices.isNotEmpty == true) ...[
                    const SizedBox(height: 12),
                    const Text('उप-सेवाएं (Sub-Services):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _getCategoryById(_primaryCategoryId)!.subServices.map((sub) {
                        final isSubSelected = _selectedSubServices.contains(sub);
                        return FilterChip(
                          label: Text(sub, style: const TextStyle(fontSize: 12)),
                          selected: isSubSelected,
                          selectedColor: AppColors.primary.withValues(alpha: 0.15),
                          checkmarkColor: AppColors.primary,
                          onSelected: (val) {
                            setState(() {
                              if (val) {
                                _selectedSubServices.add(sub);
                              } else {
                                _selectedSubServices.remove(sub);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 14),
                  // GENERAL SERVICE TEXT FIELD
                  TextFormField(
                    controller: _generalServiceDetailsController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'सेवा विवरण / कार्य विशेषज्ञता ($_primaryCategoryTitle)',
                      hintText: 'उदा. $_primaryCategoryTitle में प्रदान की जाने वाली मुख्य सेवाओं का विवरण लिखें...',
                      helperText: 'सामान्य सेवाओं का संक्षिप्त विवरण (वैकल्पिक)',
                      prefixIcon: const Icon(Icons.handyman_outlined, color: AppColors.primary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],

        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),

        // Option B: "मेरी श्रेणी उपलब्ध नहीं है / इनमें से कोई नहीं"
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Colors.orange.shade300,
              width: 1.5,
            ),
          ),
          color: Colors.orange.shade50.withValues(alpha: 0.5),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _isSubmittingCategoryRequest ? null : _showCategoryRequestForm,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _isSubmittingCategoryRequest
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(
                            Icons.add_business_rounded,
                            color: Colors.orange.shade900,
                            size: 26,
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'मेरी श्रेणी उपलब्ध नहीं है / इनमें से कोई नहीं',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'यदि आपका काम उपरोक्त लिस्ट में नहीं है, तो यहाँ टैप करके नई श्रेणी का अनुरोध सबमिट करें। एडमिन समीक्षा के बाद इसे जोड़ेंगे।',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.grey.shade700,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.orange.shade800),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryRequestPendingDashboard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader('⏳ श्रेणी अनुरोध समीक्षाधीन (Under Review)', 'आपकी नई श्रेणी का अनुरोध एडमिन के पास समीक्षाधीन है।'),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.amber.shade300),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.hourglass_top_rounded, color: Colors.amber.shade900, size: 40),
              ),
              const SizedBox(height: 16),
              Text(
                'आपकी Category Request का निरीक्षण किया जा रहा है। Admin की स्वीकृति मिलने के बाद आप registration जारी रख सकेंगे।',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.brown.shade900,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.shade200,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time_rounded, size: 14, color: Colors.brown.shade900),
                    const SizedBox(width: 6),
                    Text(
                      'Status: Pending Review (समीक्षाधीन)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.brown.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('अनुरोधित सेवा विवरण:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                const Divider(height: 16),
                _buildDetailRow('सेवा का नाम:', _otherServiceData?.serviceName ?? widget.initialProfile?.customServiceName ?? 'अनुरोधित श्रेणी'),
                const SizedBox(height: 6),
                _buildDetailRow('विवरण:', _otherServiceData?.serviceDescription ?? widget.initialProfile?.customServiceDescription ?? 'विवरण उपलब्ध नहीं'),
                const SizedBox(height: 6),
                _buildDetailRow('कार्य क्षेत्र:', _otherServiceData?.jamuiArea ?? (_jamuiArea.isNotEmpty ? _jamuiArea : 'जमुई')),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _checkCategoryRequestStatus,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('स्थिति जांचें (Check Status / Refresh)', style: TextStyle(fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              _categoryRequestStatus = 'none';
              _isOtherService = false;
            });
          },
          icon: const Icon(Icons.category_outlined, size: 16),
          label: const Text('उपलब्ध श्रेणियों में से चुनें', style: TextStyle(fontSize: 13)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryRequestRejectedDashboard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader('❌ श्रेणी अनुरोध अस्वीकृत (Request Rejected)', 'एडमिन द्वारा आपके श्रेणी अनुरोध की समीक्षा के बाद यह निर्णय लिया गया है।'),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.shade300),
          ),
          child: Column(
            children: [
              Icon(Icons.cancel_outlined, color: Colors.red.shade700, size: 40),
              const SizedBox(height: 12),
              Text(
                'आपका Category Request अस्वीकृत कर दिया गया है।',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red.shade900),
              ),
              const SizedBox(height: 8),
              Text(
                'कारण: ${_categoryRejectionReason ?? widget.initialProfile?.categoryRejectionReason ?? "एडमिन द्वारा कोई विशेष कारण दर्ज नहीं किया गया है।"}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.red.shade800),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _showCategoryRequestForm,
          icon: const Icon(Icons.edit_note_rounded, size: 18),
          label: const Text('संशोधित अनुरोध पुनः सबमिट करें (Retry)', style: TextStyle(fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () {
            setState(() {
              _categoryRequestStatus = 'none';
              _isOtherService = false;
            });
          },
          child: const Text('उपलब्ध श्रेणियों में से कोई श्रेणी चुनें'),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        ),
      ],
    );
  }

  // ---------------- SCREEN 5: WORKING DETAILS & DOCUMENTS ----------------
  Widget _buildStep5WorkingDetails() {
    return Form(
      key: _step5FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader('⏰ कार्य समय व दस्तावेज', 'अपनी उपलब्धता का समय और यदि कोई प्रमाण पत्र हो तो जोड़ें।'),
          const SizedBox(height: 16),

          // Working Hours
          TextFormField(
            controller: _workingHoursController,
            decoration: InputDecoration(
              labelText: 'कार्य के घंटे (Working Hours) *',
              hintText: 'उदा. 09:00 AM - 08:00 PM',
              prefixIcon: const Icon(Icons.access_time),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'कार्य समय भरें' : null,
          ),
          const SizedBox(height: 16),

          // Emergency Service Switch Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
            child: SwitchListTile(
              value: _isEmergencyAvailable,
              activeThumbColor: AppColors.primary,
              title: const Text('24x7 इमरजेंसी सेवा उपलब्ध', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text('आपातकालीन स्थिति में ग्राहक सीधे कॉल कर सकते हैं।', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              onChanged: (val) => setState(() => _isEmergencyAvailable = val),
            ),
          ),
          const SizedBox(height: 20),

          // Optional Certificate Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey.shade300)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CheckboxListTile(
                    value: _hasExperienceCert,
                    onChanged: (val) => setState(() => _hasExperienceCert = val ?? false),
                    title: const Text('मेरे पास अनुभव / आईटीआई / प्रशिक्षण प्रमाण पत्र है', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (_hasExperienceCert) ...[
                    const Divider(),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _previousOrgController,
                      decoration: InputDecoration(
                        labelText: 'पिछली संस्था / कंपनी / दुकान का नाम',
                        prefixIcon: const Icon(Icons.apartment_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _experienceDescController,
                      decoration: InputDecoration(
                        labelText: 'सर्टिफिकेट या अनुभव का विवरण',
                        prefixIcon: const Icon(Icons.card_membership_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: _buildPhotoUploadBox(
                        title: 'सर्टिफिकेट फोटो अपलोड',
                        imageUrl: _experienceCertUrl,
                        localBytes: _localCertBytes,
                        isLoading: _isUploadingCert,
                        onPick: () async {
                          final ImageSource? source = await showModalBottomSheet<ImageSource>(
                            context: context,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                            ),
                            builder: (ctx) {
                              return SafeArea(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'सर्टिफिकेट फोटो स्रोत चुनें',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      const SizedBox(height: 16),
                                      ListTile(
                                        leading: Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.camera_alt_rounded, color: Colors.blue),
                                        ),
                                        title: const Text('कैमरा से फोटो खींचें (Camera 📷)', style: TextStyle(fontWeight: FontWeight.w600)),
                                        subtitle: const Text('मोबाइल कैमरा खोलकर तुरंत फोटो लें'),
                                        onTap: () => Navigator.pop(ctx, ImageSource.camera),
                                      ),
                                      const Divider(),
                                      ListTile(
                                        leading: Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: Colors.purple.shade50,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.photo_library_rounded, color: Colors.purple),
                                        ),
                                        title: const Text('गैलरी से फोटो चुनें (Gallery 🖼️)', style: TextStyle(fontWeight: FontWeight.w600)),
                                        subtitle: const Text('फोन की गैलरी से सहेजी गई फोटो चुनें'),
                                        onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );

                          if (source == null || !mounted) return;

                          try {
                            final picker = ImagePicker();
                            final XFile? picked = await picker.pickImage(
                              source: source,
                              maxWidth: 1024,
                              maxHeight: 1024,
                              imageQuality: 80,
                            );

                            if (picked == null || !mounted) return;

                            final bytes = await picked.readAsBytes();
                            if (bytes.isEmpty || !mounted) return;

                            final user = FirebaseAuth.instance.currentUser;
                            if (user == null) {
                              setState(() => _localCertBytes = bytes);
                              return;
                            }

                            setState(() => _isUploadingCert = true);
                            final url = await context.read<ProviderAuthBloc>().providerRepository.uploadImageBytes(
                              providerId: user.uid,
                              imageBytes: bytes,
                              folder: 'certificates',
                              mimeType: 'image/jpeg',
                            );
                            if (mounted) {
                              setState(() {
                                _experienceCertUrl = url;
                                _localCertBytes = bytes;
                                _isUploadingCert = false;
                              });
                            }
                          } catch (e) {
                            debugPrint('Certificate upload error: $e');
                            if (!mounted) return;
                            setState(() => _isUploadingCert = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('सर्टिफिकेट अपलोड विफल: $e'), backgroundColor: AppColors.error),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- SCREEN 6: REVIEW & SUBMIT ----------------
  Widget _buildStep6ReviewAndSubmit() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader('📋 समीक्षा व अंतिम सबमिशन', 'कृपया सभी जानकारी की पुष्टि करें। किसी भी विवरण को बदलने के लिए "बदलें" पर टैप करें।'),
        const SizedBox(height: 16),

        // Section 1: Account
        _buildReviewCard(
          title: '👤 व्यक्तिगत खाता',
          stepIndex: 0,
          items: [
            'नाम: ${_fullNameController.text.trim()}',
            'मोबाइल: +91 ${_phoneController.text.trim()} ${_isPhoneVerified ? "(✅ सत्यापित)" : "(अपुष्ट)"}',
            'ईमेल: ${_emailController.text.trim()}',
          ],
        ),

        // Section 2: Categories
        _buildReviewCard(
          title: '🛠️ सेवा श्रेणियाँ',
          stepIndex: 1,
          items: [
            if (_isOtherService) ...[
              'प्रकार: विशेष कस्टम सेवा (Admin Review Required)',
              'प्रस्तावित सेवा: ${_otherServiceData?.serviceName ?? _primaryCategoryTitle}',
              if (_otherServiceData != null) 'विवरण: ${_otherServiceData!.serviceDescription}',
              if (_selectedSubServices.isNotEmpty) 'सेवाएं: ${_selectedSubServices.join(", ")}',
            ] else ...[
              'श्रेणी प्रकार: ${_selectedCategoryType == "premium" ? "🌟 प्रीमियम श्रेणी (Premium)" : "🛠️ सामान्य श्रेणी (General)"}',
              'मुख्य श्रेणी: $_primaryCategoryTitle',
              if (_selectedCategoryType == 'premium' && _premiumServiceDetailsController.text.trim().isNotEmpty)
                'प्रीमियम सेवा विवरण: ${_premiumServiceDetailsController.text.trim()}',
              if (_selectedCategoryType == 'general' && _generalServiceDetailsController.text.trim().isNotEmpty)
                'सामान्य सेवा विवरण: ${_generalServiceDetailsController.text.trim()}',
              if (_selectedSubServices.isNotEmpty) 'उप-सेवाएं: ${_selectedSubServices.join(", ")}',
            ],
          ],
        ),

        // Section 3: Business Profile
        _buildReviewCard(
          title: '🏢 व्यवसाय प्रोफ़ाइल',
          stepIndex: 2,
          items: [
            'व्यवसाय नाम: ${_businessNameController.text.trim()}',
            'प्रकार: $_businessType',
            'अनुभव: ${_experienceYearsController.text.trim()} वर्ष',
            'विजिटिंग शुल्क: ₹${_visitingChargeController.text.trim()}',
            if (_profileImageUrl.isNotEmpty) 'प्रोफ़ाइल फोटो: संलग्न ✅',
            if (_businessImageUrl.isNotEmpty) 'वर्कशॉप फोटो: संलग्न ✅',
          ],
        ),

        // Section 4: Location
        _buildReviewCard(
          title: '📍 स्थान व सेवा दायरा',
          stepIndex: 3,
          items: [
            'एरिया: $_jamuiArea',
            'पता: $_fullAddress',
            'सेवा दायरा: ${_serviceRadiusKm.toInt()} km',
            'GPS: ${_latitude.toStringAsFixed(4)}, ${_longitude.toStringAsFixed(4)}',
          ],
        ),

        // Section 5: Working Details
        _buildReviewCard(
          title: '⏰ कार्य समय व प्रमाण पत्र',
          stepIndex: 4,
          items: [
            'समय: ${_workingHoursController.text.trim()}',
            '24x7 इमरजेंसी: ${_isEmergencyAvailable ? "हाँ" : "नहीं"}',
            if (_hasExperienceCert) 'प्रमाण पत्र: संलग्न (${_previousOrgController.text.trim()})',
          ],
        ),
      ],
    );
  }

  Widget _buildReviewCard({
    required String title,
    required int stepIndex,
    required List<String> items,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey.shade300)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                TextButton.icon(
                  onPressed: () => setState(() => _currentStep = stepIndex),
                  icon: const Icon(Icons.edit, size: 14, color: AppColors.primary),
                  label: const Text('बदलें', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ),
              ],
            ),
            const Divider(height: 8),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Text(item, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildBottomActionBar() {
    final isLastStep = _currentStep == _totalSteps - 1;
    final isPendingCategory = _currentStep == 1 && _categoryRequestStatus == 'pending_review';

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4)),
        ],
      ),
      child: ResponsiveContentContainer(
        maxWidth: 740,
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  onPressed: _goToPreviousStep,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: AppColors.primary),
                  ),
                  child: const Text('पीछे', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: isPendingCategory
                    ? null
                    : (isLastStep
                        ? (_isSubmittingFinal ? null : _submitFullRegistration)
                        : (_isSavingDraft ? null : _goToNextStep)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPendingCategory
                      ? Colors.grey.shade400
                      : (isLastStep ? AppColors.accent : AppColors.primary),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: (_isSubmittingFinal || _isSavingDraft)
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        isPendingCategory
                            ? 'निरीक्षण जारी है (Under Review)'
                            : (isLastStep ? 'आवेदन सबमिट करें (Submit)' : 'आगे बढ़ें (Next)'),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
