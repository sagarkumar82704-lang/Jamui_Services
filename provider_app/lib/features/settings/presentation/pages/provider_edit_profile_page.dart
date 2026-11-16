import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_image_utils.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../../../core/widgets/photo_source_picker.dart';
import '../../../auth/domain/entities/provider_profile_entity.dart';
import '../../../auth/presentation/bloc/provider_auth_bloc.dart';
import '../../../auth/presentation/bloc/provider_auth_event.dart';
import '../../../auth/presentation/bloc/provider_auth_state.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../categories/data/models/service_category_model.dart';
import '../../../auth/presentation/widgets/other_service_details_modal.dart';
import '../../../location/data/datasources/location_local_data_source.dart';
import '../../../location/data/datasources/location_remote_data_source.dart';
import '../../../location/data/repositories/location_repository_impl.dart';
import '../../../location/domain/entities/provider_location_entity.dart';
import '../../../location/presentation/bloc/location_bloc.dart';
import '../../../location/presentation/pages/provider_location_picker_screen.dart';

class ProviderEditProfilePage extends StatefulWidget {
  final ProviderProfileEntity profile;

  const ProviderEditProfilePage({super.key, required this.profile});

  @override
  State<ProviderEditProfilePage> createState() => _ProviderEditProfilePageState();
}

class _ProviderEditProfilePageState extends State<ProviderEditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _businessNameController;
  late TextEditingController _fullNameController;
  late TextEditingController _businessDescController;
  late TextEditingController _emailController;
  late TextEditingController _visitingChargeController;
  late TextEditingController _experienceYearsController;
  late TextEditingController _workingHoursController;
  late TextEditingController _fullAddressController;
  late TextEditingController _instagramUrlController;
  late TextEditingController _facebookUrlController;
  late TextEditingController _websiteUrlController;

  String _profileImageUrl = '';
  String _businessImageUrl = '';
  List<String> _galleryImages = [];
  List<Map<String, dynamic>> _servicesWithPricing = [];
  String _businessType = 'Individual';
  String _jamuiArea = 'जमुई मुख्य बाजार';
  double _latitude = 0.0;
  double _longitude = 0.0;
  double _serviceRadiusKm = 10.0;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;

  // Category Edit & Re-Apply state
  List<ServiceCategoryModel> _adminCategories = [];
  bool _isLoadingCategories = false;
  ServiceCategoryModel? _selectedNewCategory;
  OtherServiceData? _selectedCustomServiceData;
  bool _isSubmittingCategoryChange = false;

  final List<String> _jamuiAreas = const [
    'जमुई मुख्य बाजार',
    'झाझा (Jhajha)',
    'सोनो (Sono)',
    'खैरा (Khaira)',
    'चकाई (Chakai)',
    'गिद्धौर (Gidhaur)',
    'बरहट (Barhat)',
    'अलीगंज (Aliganj)',
    'सिकंदरा (Sikandra)',
    'इस्लाम नगर (Islam Nagar)',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _businessNameController = TextEditingController(text: p.businessName);
    _fullNameController = TextEditingController(text: p.fullName);
    _businessDescController = TextEditingController(text: p.businessDescription);
    _emailController = TextEditingController(text: p.email);
    _visitingChargeController = TextEditingController(text: p.visitingCharge.toInt().toString());
    _experienceYearsController = TextEditingController(text: p.experienceYears.toString());
    _workingHoursController = TextEditingController(
      text: p.workingHours.isNotEmpty ? p.workingHours : '09:00 AM - 08:00 PM',
    );
    _fullAddressController = TextEditingController(text: p.fullAddress);
    _instagramUrlController = TextEditingController(text: p.instagramUrl);
    _facebookUrlController = TextEditingController(text: p.facebookUrl);
    _websiteUrlController = TextEditingController(text: p.websiteUrl);

    _profileImageUrl = p.profileImageUrl;
    _businessImageUrl = p.businessImageUrl;
    _galleryImages = List<String>.from(p.galleryImages);
    _servicesWithPricing = List<Map<String, dynamic>>.from(
      p.servicesWithPricing.map((item) => Map<String, dynamic>.from(item)),
    );
    _businessType = p.businessType.isNotEmpty ? p.businessType : 'Individual';
    _serviceRadiusKm = p.serviceRadiusKm > 0 ? p.serviceRadiusKm : 10.0;
    _latitude = p.latitude;
    _longitude = p.longitude;

    if (_jamuiAreas.contains(p.jamuiArea)) {
      _jamuiArea = p.jamuiArea;
    } else if (p.jamuiArea.isNotEmpty) {
      _jamuiArea = p.jamuiArea;
    }
    _fetchAdminCategories();
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _fullNameController.dispose();
    _businessDescController.dispose();
    _emailController.dispose();
    _visitingChargeController.dispose();
    _experienceYearsController.dispose();
    _workingHoursController.dispose();
    _fullAddressController.dispose();
    _instagramUrlController.dispose();
    _facebookUrlController.dispose();
    _websiteUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto({required bool isProfile}) async {
    final user = FirebaseAuth.instance.currentUser;
    PhotoSourcePicker.show(
      context,
      isCircle: isProfile,
      title: isProfile ? 'प्रोफाइल फोटो चुनें (Select Profile Photo)' : 'दुकान / वर्कप्लेस फोटो चुनें (Select Workplace Photo)',
      onImagePicked: (imagePath) {},
      onImagePickedWithBytes: (imagePath, imageBytes) async {
        setState(() => _isUploadingPhoto = true);
        final folder = isProfile ? 'profile' : 'business';
        final providerId = user?.uid ?? widget.profile.id;
        final repo = context.read<ProviderAuthBloc>().providerRepository;

        // 1. Strictly Cloudflare R2 Upload (Direct bytes - No HTTP fetch on blob URLs)
        String downloadUrl;
        try {
          if (imageBytes != null && imageBytes.isNotEmpty) {
            downloadUrl = await repo.uploadImageBytes(
              providerId: providerId,
              imageBytes: imageBytes,
              folder: folder,
              mimeType: 'image/jpeg',
            );
          } else if (imagePath.startsWith('data:image/')) {
            final comma = imagePath.indexOf('base64,');
            final bytes = base64Decode(imagePath.substring(comma + 7).trim());
            downloadUrl = await repo.uploadImageBytes(
              providerId: providerId,
              imageBytes: bytes,
              folder: folder,
              mimeType: 'image/jpeg',
            );
          } else if (kIsWeb) {
            throw Exception('वेब ब्राउज़र में फोटो डेटा लोड नहीं हो सका। कृपया पुनः प्रयास करें।');
          } else {
            final file = File(imagePath);
            downloadUrl = await repo.uploadImage(
              providerId: providerId,
              imageFile: file,
              folder: folder,
            );
          }
        } catch (r2Error) {
          debugPrint('❌ R2 Upload failed: $r2Error');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('क्लाउड स्टोरेज (R2) पर फोटो अपलोड विफल: $r2Error'),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
            setState(() => _isUploadingPhoto = false);
          }
          return;
        }

        // 2. Local State Update & Immediate Firestore Auto-Sync
        if (mounted) {
          setState(() {
            if (isProfile) {
              _profileImageUrl = downloadUrl;
            } else {
              _businessImageUrl = downloadUrl;
            }
            _isUploadingPhoto = false;
          });

          try {
            await repo.updatePermittedProfileFields(
              providerId: providerId,
              fields: {
                if (isProfile) 'profileImageUrl': downloadUrl else 'businessImageUrl': downloadUrl,
              },
            );
            if (mounted) {
              context.read<ProviderAuthBloc>().add(LoadProviderProfileEvent(providerId));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(isProfile
                          ? 'प्रोफाइल फोटो सफलतापूर्वक अपडेट हो गई!'
                          : 'वर्कप्लेस फोटो सफलतापूर्वक अपडेट हो गई!'),
                    ],
                  ),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          } catch (firestoreErr) {
            debugPrint('❌ Firestore profile auto-sync notice: $firestoreErr');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'फोटो R2 पर सुरक्षित हो गई, लेकिन प्रोफाइल में लिंक करने में अनुमति समस्या (Permission Issue) आई। कृपया "Save Changes" दबाकर पुनः प्रयास करें।',
                  ),
                  backgroundColor: Colors.orange.shade800,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          }
        }
      },
    );
  }

  Future<void> _pickAndUploadGalleryImage() async {
    final user = FirebaseAuth.instance.currentUser;
    PhotoSourcePicker.show(
      context,
      isCircle: false,
      title: 'बिजनेस फोटो जोड़ें (Add  Photo)',
      onImagePicked: (imagePath) {},
      onImagePickedWithBytes: (imagePath, imageBytes) async {
        setState(() => _isUploadingPhoto = true);
        final providerId = user?.uid ?? widget.profile.id;
        final repo = context.read<ProviderAuthBloc>().providerRepository;

        try {
          String downloadUrl;
          if (imageBytes != null && imageBytes.isNotEmpty) {
            downloadUrl = await repo.uploadImageBytes(
              providerId: providerId,
              imageBytes: imageBytes,
              folder: 'business',
              mimeType: 'image/jpeg',
            );
          } else if (imagePath.startsWith('data:image/')) {
            final comma = imagePath.indexOf('base64,');
            final bytes = base64Decode(imagePath.substring(comma + 7).trim());
            downloadUrl = await repo.uploadImageBytes(
              providerId: providerId,
              imageBytes: bytes,
              folder: 'business',
              mimeType: 'image/jpeg',
            );
          } else if (kIsWeb) {
            throw Exception('वेब ब्राउज़र में फोटो लोड नहीं हो सका।');
          } else {
            final file = File(imagePath);
            downloadUrl = await repo.uploadImage(
              providerId: providerId,
              imageFile: file,
              folder: 'business',
            );
          }

          if (mounted) {
            setState(() {
              _galleryImages.add(downloadUrl);
              _isUploadingPhoto = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('गैलरी में नई फोटो जुड़ गई!'),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            setState(() => _isUploadingPhoto = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('फोटो अपलोड में त्रुटि: $e'),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      },
    );
  }

  void _onSaveProfile() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_latitude == 0.0 || _longitude == 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('कृपया "मैप पर दुकान की सटीक लोकेशन सेट करें" बटन दबाकर पिन सेट करें।'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final double visitingCharge = double.tryParse(_visitingChargeController.text.trim()) ?? widget.profile.visitingCharge;
    final int experienceYears = int.tryParse(_experienceYearsController.text.trim()) ?? widget.profile.experienceYears;

    setState(() => _isSaving = true);

    final updatedProfile = widget.profile.copyWith(
      businessName: _businessNameController.text.trim(),
      fullName: _fullNameController.text.trim(),
      businessDescription: _businessDescController.text.trim(),
      email: _emailController.text.trim(),
      businessType: _businessType,
      visitingCharge: visitingCharge,
      experienceYears: experienceYears,
      workingHours: _workingHoursController.text.trim(),
      jamuiArea: _jamuiArea,
      fullAddress: _fullAddressController.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
      serviceRadiusKm: _serviceRadiusKm,
      profileImageUrl: _profileImageUrl,
      businessImageUrl: _businessImageUrl,
      galleryImages: _galleryImages,
      servicesWithPricing: _servicesWithPricing,
      instagramUrl: _instagramUrlController.text.trim(),
      facebookUrl: _facebookUrlController.text.trim(),
      websiteUrl: _websiteUrlController.text.trim(),
      updatedAt: DateTime.now(),
    );

    final permittedFields = <String, dynamic>{
      'businessName': _businessNameController.text.trim(),
      'fullName': _fullNameController.text.trim(),
      'ownerName': _fullNameController.text.trim(),
      'businessDescription': _businessDescController.text.trim(),
      'businessType': _businessType,
      'visitingCharge': visitingCharge,
      'experienceYears': experienceYears,
      'workingHours': _workingHoursController.text.trim(),
      'jamuiArea': _jamuiArea,
      'area': _jamuiArea,
      'fullAddress': _fullAddressController.text.trim(),
      'latitude': _latitude,
      'longitude': _longitude,
      'serviceRadiusKm': _serviceRadiusKm,
      'profileImageUrl': _profileImageUrl,
      'businessImageUrl': _businessImageUrl,
      'email': _emailController.text.trim(),
      'galleryImages': _galleryImages,
      'servicesWithPricing': _servicesWithPricing,
      'instagramUrl': _instagramUrlController.text.trim(),
      'facebookUrl': _facebookUrlController.text.trim(),
      'websiteUrl': _websiteUrlController.text.trim(),
    };

    context.read<ProviderAuthBloc>().add(
          UpdatePermittedProfileFieldsEvent(
            providerId: widget.profile.id,
            updatedFields: permittedFields,
            updatedProfile: updatedProfile,
          ),
        );
  }

  Future<void> _openMapLocationPicker() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final result = await Navigator.push<ProviderLocationEntity>(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => LocationBloc(
            locationRepository: LocationRepositoryImpl(
              remoteDataSource: LocationRemoteDataSourceImpl(),
              localDataSource: LocationLocalDataSourceImpl(
                prefs: prefs,
              ),
            ),
          ),
          child: ProviderLocationPickerScreen(
            initialRadiusKm: _serviceRadiusKm,
            providerId: widget.profile.id,
            initialLocation: (_latitude != 0.0 && _longitude != 0.0)
                ? ProviderLocationEntity(
                    latitude: _latitude,
                    longitude: _longitude,
                    placeName: _jamuiArea,
                    formattedAddress: _fullAddressController.text.trim(),
                    city: '',
                    district: 'Jamui',
                    state: 'Bihar',
                    pincode: '',
                    serviceRadiusKm: _serviceRadiusKm,
                    timestamp: DateTime.now(),
                    source: 'manual_pin',
                  )
                : null,
          ),
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _latitude = result.latitude;
        _longitude = result.longitude;
        if (result.placeName.isNotEmpty && _jamuiAreas.contains(result.placeName)) {
          _jamuiArea = result.placeName;
        } else if (result.placeName.isNotEmpty) {
          _jamuiArea = result.placeName;
        }
        if (result.formattedAddress.isNotEmpty) {
          _fullAddressController.text = result.formattedAddress;
        }
        _serviceRadiusKm = result.serviceRadiusKm;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📍 मैप पिन अपडेट हुआ: (${_latitude.toStringAsFixed(4)}, ${_longitude.toStringAsFixed(4)})'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProviderAuthBloc, ProviderAuthState>(
      listener: (context, state) {
        if (state is ProviderProfileUpdatedSuccessState || state is ProviderKycSubmittedSuccess) {
          setState(() => _isSaving = false);
          final msg = state is ProviderProfileUpdatedSuccessState
              ? state.message
              : 'आपकी प्रोफाइल सफलतापूर्वक अपडेट हो गई है!';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text(msg)),
                ],
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context);
        } else if (state is ProviderAuthenticated) {
          setState(() => _isSaving = false);
        } else if (state is ProviderAuthError) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text(
            'प्रोफाइल संपादित करें (Edit Profile)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textPrimary,
          elevation: 0.5,
          actions: [
            if (_isSaving)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  ),
                ),
              )
            else
              TextButton.icon(
                onPressed: _onSaveProfile,
                icon: const Icon(Icons.check, size: 18, color: AppColors.primary),
                label: const Text(
                  'सेव करें',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 15),
                ),
              ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.zero,
            child: ResponsiveContentContainer(
              maxWidth: 820,
              padding: ResponsiveLayout.pagePadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Photo Section: Shop Cover Photo & Profile Avatar
                  _buildPhotoCard(),
                  const SizedBox(height: 20),

                  // Category Section (Admin-Approved Category Lock)
                  _buildCategorySection(),
                  const SizedBox(height: 20),

                  // Shop Details
                  _buildSectionHeader('दुकान व व्यापार विवरण (Shop & Business Details)', Icons.storefront_rounded),
                  const SizedBox(height: 12),
                  _buildCard(
                    children: [
                      TextFormField(
                        controller: _businessNameController,
                        decoration: const InputDecoration(
                          labelText: 'दुकान / व्यापार का नाम (Shop Name) *',
                          hintText: 'उदा.  इलेक्ट्रिकल वर्क्स',
                          prefixIcon: Icon(Icons.store_mall_directory_rounded, color: AppColors.primary),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'दुकान / व्यापार का नाम दर्ज करें' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _fullNameController,
                        decoration: const InputDecoration(
                          labelText: 'मालिक / कारीगर का पूरा नाम (Owner Full Name) *',
                          hintText: 'उदा. s कुमार',
                          prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.primary),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'मालिक का नाम दर्ज करें' : null,
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: _businessType,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'व्यापार का प्रकार (Business Type)',
                          prefixIcon: Icon(Icons.business_center_outlined, color: AppColors.primary),
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Individual', child: Text('व्यक्तिगत / स्वरोजगार (Individual)', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'Shop', child: Text('स्थाई दुकान / वर्कशॉप (Shop/Workshop)', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'Small Business', child: Text('लघु उद्यम (Small Business)', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'Agency', child: Text('एजेंसी / सर्विस सेंटर (Agency)', overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _businessType = v);
                        },
                      ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _businessDescController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'दुकान / काम का विवरण (About Shop & Services)',
                      hintText: 'उदा. हमारे यहाँ सभी प्रकार के इलेक्ट्रिक उपकरण, पंखा, मोटर रिपेयर व वायरिंग की जाती है।',
                      prefixIcon: Icon(Icons.description_outlined, color: AppColors.primary),
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Contact Information
              _buildSectionHeader('संपर्क विवरण (Contact Details)', Icons.call_outlined),
              const SizedBox(height: 12),
              _buildCard(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified, color: Colors.green, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('पंजीकृत मोबाइल नंबर (Verified)', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Text(
                                widget.profile.phoneNumber,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('सत्यापित ✓', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'ईमेल पता (Email Address)',
                      hintText: 'उदा. ',
                      prefixIcon: Icon(Icons.email_outlined, color: AppColors.primary),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Fees & Working Hours
              _buildSectionHeader('फीस, अनुभव व कार्य समय (Fees & Timing)', Icons.access_time_rounded),
              const SizedBox(height: 12),
              _buildCard(
                children: [
                  if (ResponsiveLayout.isSmallMobile(context)) ...[
                    TextFormField(
                      controller: _visitingChargeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'विज़िटिंग चार्ज (₹) *',
                        hintText: '00',
                        prefixIcon: Icon(Icons.currency_rupee_rounded, color: AppColors.primary),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'फीस दर्ज करें' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _experienceYearsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'अनुभव (वर्ष में) *',
                        hintText: '3',
                        prefixIcon: Icon(Icons.work_history_outlined, color: AppColors.primary),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'अनुभव दर्ज करें' : null,
                    ),
                  ] else
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _visitingChargeController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'विज़िटिंग चार्ज (₹) *',
                              hintText: '00',
                              prefixIcon: Icon(Icons.currency_rupee_rounded, color: AppColors.primary),
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'फीस दर्ज करें' : null,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: TextFormField(
                            controller: _experienceYearsController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'अनुभव (वर्ष में) *',
                              hintText: '3',
                              prefixIcon: Icon(Icons.work_history_outlined, color: AppColors.primary),
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'अनुभव दर्ज करें' : null,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _workingHoursController,
                    decoration: const InputDecoration(
                      labelText: 'दुकान / कार्य का समय (Working Hours) *',
                      hintText: '09:00 AM - 08:00 PM',
                      prefixIcon: Icon(Icons.access_time_filled_rounded, color: AppColors.primary),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'कार्य समय दर्ज करें' : null,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Location & Shop Address
              _buildSectionHeader('दुकान का पता व कार्यक्षेत्र (Shop Location & Area)', Icons.location_on_outlined),
              const SizedBox(height: 12),
              _buildCard(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _jamuiAreas.contains(_jamuiArea) ? _jamuiArea : _jamuiAreas.first,
                    decoration: const InputDecoration(
                      labelText: 'जमुई क्षेत्र (Jamui Area) *',
                      prefixIcon: Icon(Icons.map_outlined, color: AppColors.primary),
                      border: OutlineInputBorder(),
                    ),
                    items: _jamuiAreas
                        .map((area) => DropdownMenuItem(value: area, child: Text(area)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _jamuiArea = v);
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _fullAddressController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'दुकान / प्रतिष्ठान का पूरा पता (Full Address) *',
                      hintText: 'उदा. मेन रोड, महाराजगंज चौक, जमुई - 811307',
                      prefixIcon: Icon(Icons.place_outlined, color: AppColors.primary),
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'पूरा पता दर्ज करें' : null,
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (_latitude != 0.0 && _longitude != 0.0)
                          ? Colors.green.shade50
                          : Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: (_latitude != 0.0 && _longitude != 0.0)
                            ? Colors.green.shade300
                            : Colors.amber.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          (_latitude != 0.0 && _longitude != 0.0)
                              ? Icons.check_circle_rounded
                              : Icons.warning_amber_rounded,
                          color: (_latitude != 0.0 && _longitude != 0.0)
                              ? Colors.green.shade700
                              : Colors.amber.shade800,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (_latitude != 0.0 && _longitude != 0.0)
                                    ? '📍 मैप पिन सेट है: (${_latitude.toStringAsFixed(4)}, ${_longitude.toStringAsFixed(4)})'
                                    : '⚠️ मैप पर GPS पिन सेट नहीं है',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: (_latitude != 0.0 && _longitude != 0.0)
                                      ? Colors.green.shade800
                                      : Colors.amber.shade900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'ग्राहकों को सही दूरी दिखाने हेतु मैप पिन आवश्यक है।',
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _openMapLocationPicker,
                    icon: const Icon(Icons.pin_drop_outlined, size: 18),
                    label: const Text('मैप पर दुकान की सटीक लोकेशन सेट करें (Adjust Pin on Map)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'सर्विस डिलीवरी दायरा (Radius):',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_serviceRadiusKm.toInt()} KM',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _serviceRadiusKm,
                    min: 2.0,
                    max: 30.0,
                    divisions: 14,
                    activeColor: AppColors.primary,
                    label: '${_serviceRadiusKm.toInt()} KM',
                    onChanged: (v) => setState(() => _serviceRadiusKm = v),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Salon & Business Gallery Photos
              _buildGalleryImagesSection(),
              const SizedBox(height: 20),

              // Social Media Links (Instagram, Facebook, Website)
              _buildSocialLinksSection(),
              const SizedBox(height: 20),

              // Salon Services & Pricing
              _buildServicesWithPricingSection(),
              const SizedBox(height: 28),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _onSaveProfile,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  label: Text(
                    _isSaving ? 'सेव हो रहा है...' : 'प्रोफाइल सेव करें (Save & Update)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 1,
                  ),
                ),
              ),
              const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Shop Cover Photo Banner
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Container(
                  height: 140,
                  width: double.infinity,
                  color: Colors.grey.shade200,
                  child: _businessImageUrl.isNotEmpty
                      ? AppImageUtils.buildImage(_businessImageUrl, fit: BoxFit.cover)
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.storefront_rounded, size: 40, color: Colors.grey.shade400),
                              const SizedBox(height: 4),
                              Text('दुकान की फोटो (Shop Photo)', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: ElevatedButton.icon(
                  onPressed: _isUploadingPhoto ? null : () => _pickAndUploadPhoto(isProfile: false),
                  icon: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                  label: const Text('दुकान की फोटो बदलें', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.7),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ),
            ],
          ),

          // Provider Profile Avatar Overlap
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _isUploadingPhoto ? null : () => _pickAndUploadPhoto(isProfile: true),
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 38,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        backgroundImage: _profileImageUrl.isNotEmpty ? AppImageUtils.getImageProvider(_profileImageUrl) : null,
                        onBackgroundImageError: _profileImageUrl.isNotEmpty
                            ? (e, s) => debugPrint('Profile avatar load error: $e')
                            : null,
                        child: _isUploadingPhoto
                            ? const CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary)
                            : (_profileImageUrl.isEmpty
                                ? const Icon(Icons.person, size: 40, color: AppColors.primary)
                                : null),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _businessNameController.text.isNotEmpty
                            ? _businessNameController.text
                            : 'दुकान का नाम दर्ज करें',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _fullNameController.text.isNotEmpty ? _fullNameController.text : 'प्रोवाइडर नाम',
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'प्राथमिक श्रेणी: ${widget.profile.primaryCategoryTitle.isNotEmpty ? widget.profile.primaryCategoryTitle : 'सर्विस प्रोवाइडर'}',
                        style: const TextStyle(fontSize: 11, color: AppColors.accent, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchAdminCategories() async {
    setState(() => _isLoadingCategories = true);
    try {
      final snap = await FirebaseFirestore.instance.collection('categories').get();
      final list = snap.docs
          .map((doc) => ServiceCategoryModel.fromMap(doc.data(), doc.id))
          .where((c) => !c.isDeleted && (c.status.toLowerCase() == 'active' || c.isActive == true))
          .toList();
      if (mounted) {
        setState(() {
          _adminCategories = list;
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingCategories = false);
    }
  }

  ProviderProfileEntity get _currentProfile {
    final authState = context.watch<ProviderAuthBloc>().state;
    if (authState is ProviderAuthenticated) {
      return authState.profile;
    } else if (authState is ProviderProfileIncomplete) {
      return authState.profile;
    } else if (authState is ProviderProfileUpdatedSuccessState) {
      return authState.profile;
    }
    return widget.profile;
  }

  Widget _buildCategorySection() {
    final profile = _currentProfile;
    final isApproved = profile.kycStatus == ProviderKycStatus.approved ||
        profile.status == ProviderAccountStatus.approved;
    final categoryName = profile.primaryCategoryTitle.isNotEmpty
        ? profile.primaryCategoryTitle
        : (profile.primaryCategoryId.isNotEmpty ? profile.primaryCategoryId : 'सर्विस पार्टनर');

    final bool isChangePending = profile.isCategoryChangePending;
    final bool isRejected = profile.isCategoryRejected;
    final String requestedTitle = profile.requestedCategoryTitle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('सेवा श्रेणी (Service Category) एवं अनुमोदन स्थिति', Icons.category_outlined),
        const SizedBox(height: 12),
        _buildCard(
          children: [
            // 1. Current Approved / Registered Category Line
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.handyman_rounded, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        categoryName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'वर्तमान श्रेणी ID: ${profile.primaryCategoryId.isNotEmpty ? profile.primaryCategoryId : "अनिर्धारित"}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isApproved ? const Color(0xFFF0FDF4) : Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isApproved ? const Color(0xFF86EFAC) : Colors.amber.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isApproved ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
                        size: 13,
                        color: isApproved ? const Color(0xFF15803D) : Colors.amber.shade900,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isApproved ? 'स्वीकृत (Approved)' : 'समीक्षाधीन (Pending)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isApproved ? const Color(0xFF15803D) : Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // 2. Pending Category Change Banner (If pending review)
            if (isChangePending && requestedTitle.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.hourglass_top_rounded, color: Color(0xFFD97706), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'अनुरोधित नई श्रेणी: $requestedTitle',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF92400E),
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'स्थिति: समीक्षाधीन (Pending Approval) • एडमिन की स्वीकृति के बाद यह श्रेणी आपकी मुख्य प्रोफाइल में सक्रिय होगी। तब तक आपकी वर्तमान सेवाएं चालू रहेंगी।',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFFB45309), height: 1.35),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 3. Rejected Category Banner (If rejected with reason)
            if (isRejected) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.cancel_outlined, color: Color(0xFFDC2626), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'श्रेणी आवेदन अस्वीकृत (Category Rejected)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF991B1B),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'कारण: ${profile.categoryRejectionReason ?? "विवरण उपलब्ध नहीं"}। कृपया नीचे दिए बटन से श्रेणी संशोधित करके पुनः आवेदन करें।',
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFFB91C1C), height: 1.35),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 4. Proposed New Category Selection Preview & Action Bar
            if (_selectedNewCategory != null || _selectedCustomServiceData != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF93C5FD)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.new_releases_rounded, color: Color(0xFF2563EB), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'प्रस्तावित नई श्रेणी: ${_selectedNewCategory?.titleHindi ?? _selectedCustomServiceData?.serviceName}',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E40AF),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'पुष्टि: यह श्रेणी अपडेट करने के बाद अनुमोदन हेतु एडमिन के पास जाएगी। आपके सब्सक्रिप्शन व पेमेंट्स सुरक्षित रहेंगे।',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF1E3A8A), height: 1.35),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isSubmittingCategoryChange ? null : _handleCategoryReApply,
                            icon: _isSubmittingCategoryChange
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.send_rounded, size: 16),
                            label: const Text('अपडेट करें व अनुमोदन हेतु पुनः आवेदन करें'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: _isSubmittingCategoryChange
                              ? null
                              : () {
                                  setState(() {
                                    _selectedNewCategory = null;
                                    _selectedCustomServiceData = null;
                                  });
                                },
                          child: const Text('रद्द करें', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else ...[
              // 5. Change Category Button
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showCategoryPickerModal,
                      icon: const Icon(Icons.edit_note_rounded, size: 18),
                      label: Text(
                        isRejected
                            ? 'श्रेणी में सुधार करें व पुनः आवेदन करें'
                            : (isChangePending ? 'अनुरोधित श्रेणी बदलें' : 'श्रेणी बदलें / नई श्रेणी चुनें'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    tooltip: 'एडमिन सपोर्ट से संपर्क करें',
                    icon: const Icon(Icons.support_agent_rounded, color: AppColors.primary),
                    onPressed: () => _contactAdminForCategoryChange(context),
                  ),
                ],
              ),
            ],
          ],
        ),
      ],
    );
  }

  void _showCategoryPickerModal() {
    final profile = _currentProfile;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (_, scrollController) {
                return Column(
                  children: [
                    // Handle Bar
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.category_rounded, color: AppColors.primary),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('उपलब्ध सेवा श्रेणियां चुनें', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text('Select Service Category', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),

                    // Category List
                    Expanded(
                      child: _isLoadingCategories
                          ? const Center(child: CircularProgressIndicator())
                          : ListView(
                              controller: scrollController,
                              padding: const EdgeInsets.all(16),
                              children: [
                                ..._adminCategories.map((cat) {
                                  final isCurrent = cat.id == profile.primaryCategoryId;
                                  final title = cat.titleHindi.isNotEmpty ? cat.titleHindi : cat.titleEnglish;

                                  return Card(
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: BorderSide(
                                        color: isCurrent ? AppColors.primary : Colors.grey.shade200,
                                        width: isCurrent ? 2 : 1,
                                      ),
                                    ),
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                        child: const Icon(Icons.handyman_rounded, color: AppColors.primary, size: 20),
                                      ),
                                      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      subtitle: Text(cat.titleEnglish, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                      trailing: isCurrent
                                          ? const Chip(
                                              label: Text('वर्तमान', style: TextStyle(fontSize: 10, color: Colors.white)),
                                              backgroundColor: AppColors.primary,
                                              padding: EdgeInsets.zero,
                                            )
                                          : const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
                                      onTap: () {
                                        Navigator.pop(ctx);
                                        setState(() {
                                          _selectedNewCategory = cat;
                                          _selectedCustomServiceData = null;
                                        });
                                      },
                                    ),
                                  );
                                }),

                                const SizedBox(height: 12),

                                // "None of these" Custom Service Option (Preserved Rules)
                                Card(
                                  elevation: 0,
                                  color: Colors.orange.shade50,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: Colors.orange.shade300),
                                  ),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.orange.shade100,
                                      child: Icon(Icons.add_business_rounded, color: Colors.orange.shade900, size: 22),
                                    ),
                                    title: const Text(
                                      'मेरी श्रेणी लिस्ट में नहीं है / इनमें से कोई नहीं',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF9A3412)),
                                    ),
                                    subtitle: const Text(
                                      'यदि आपका काम उपरोक्त लिस्ट में नहीं है, तो यहाँ टैप करके नई श्रेणी का अनुरोध करें।',
                                      style: TextStyle(fontSize: 11, color: Color(0xFFC2410C)),
                                    ),
                                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF9A3412)),
                                    onTap: () async {
                                      Navigator.pop(ctx);
                                      final customData = await OtherServiceDetailsModal.show(
                                        context,
                                        initialFullName: profile.fullName,
                                        initialPhoneNumber: profile.phoneNumber,
                                        initialFullAddress: profile.fullAddress,
                                        initialJamuiArea: profile.jamuiArea,
                                        initialExperienceYears: profile.experienceYears,
                                        initialVisitingCharge: profile.visitingCharge,
                                      );
                                      if (customData != null && mounted) {
                                        setState(() {
                                          _selectedCustomServiceData = customData;
                                          _selectedNewCategory = null;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _handleCategoryReApply() async {
    if (_selectedNewCategory == null && _selectedCustomServiceData == null) return;
    setState(() => _isSubmittingCategoryChange = true);

    try {
      final catId = _selectedNewCategory != null ? _selectedNewCategory!.id : 'custom';
      final catTitle = _selectedNewCategory != null
          ? (_selectedNewCategory!.titleHindi.isNotEmpty ? _selectedNewCategory!.titleHindi : _selectedNewCategory!.titleEnglish)
          : _selectedCustomServiceData!.serviceName;

      final Map<String, dynamic>? customDetails = _selectedCustomServiceData != null
          ? {
              'serviceName': _selectedCustomServiceData!.serviceName,
              'serviceDescription': _selectedCustomServiceData!.serviceDescription,
              'offeredServices': _selectedCustomServiceData!.offeredServices,
              'experienceYears': _selectedCustomServiceData!.experienceYears,
              'visitingCharge': _selectedCustomServiceData!.visitingCharge,
              'jamuiArea': _selectedCustomServiceData!.jamuiArea,
              'fullAddress': _selectedCustomServiceData!.fullAddress,
            }
          : null;

      context.read<ProviderAuthBloc>().add(
            SubmitCategoryChangeRequestEvent(
              providerId: _currentProfile.id,
              requestedCategoryId: catId,
              requestedCategoryTitle: catTitle,
              customServiceDetails: customDetails,
            ),
          );

      if (mounted) {
        setState(() {
          _selectedNewCategory = null;
          _selectedCustomServiceData = null;
          _isSubmittingCategoryChange = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('श्रेणी परिवर्तन आवेदन सफलतापूर्वक सबमिट हुआ। एडमिन समीक्षा के बाद यह स्वीकृत होगा।'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmittingCategoryChange = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('आवेदन सबमिट करने में विफल: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'पुनः प्रयास करें',
              textColor: Colors.white,
              onPressed: _handleCategoryReApply,
            ),
          ),
        );
      }
    }
  }

  void _contactAdminForCategoryChange(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_person_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('श्रेणी परिवर्तन नियम', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'आपकी वर्तमान सेवा श्रेणी एडमिन द्वारा सत्यापित (Admin-Approved) है।',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'ग्राहकों को सही कारीगर मिलने और फर्जीवाड़े से बचाव के लिए श्रेणी केवल Jamui Service एडमिन द्वारा बदली या बढ़ाई जा सकती है।',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📞 हेल्पलाइन: +91 9122334455', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  SizedBox(height: 4),
                  Text('✉️ ईमेल: support@jamuiservice.com', style: TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('समझ गया'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              final Uri whatsappUri = Uri.parse(
                'https://wa.me/918521301451?text=${Uri.encodeComponent('नमस्ते, मुझे Jamui Service में अपनी सर्विस श्रेणी (Category) बदलनी/अपडेट करनी है।\nप्रोवाइडर ID: ${widget.profile.id}\nफोन: ${widget.profile.phoneNumber}')}',
              );
              try {
                await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
              } catch (_) {}
            },
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Colors.white),
            label: const Text('WhatsApp सहायता', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _buildGalleryImagesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('कार्यस्थल फोटो गैलरी (Gallery Photos)', Icons.photo_library_outlined),
        const SizedBox(height: 12),
        _buildCard(
          children: [
            const Text(
              'ग्राहकों को अपनी दुकान,  व काम की वास्तविक तस्वीरें दिखाएं (अधिकतम 10 फोटो):',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 90,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ..._galleryImages.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final url = entry.value;
                    return Container(
                      width: 90,
                      height: 90,
                      margin: const EdgeInsets.only(right: 10),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              width: 90,
                              height: 90,
                              child: AppImageUtils.buildImage(url, fit: BoxFit.cover),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _galleryImages.removeAt(idx);
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (_galleryImages.length < 10)
                    InkWell(
                      onTap: _isUploadingPhoto ? null : _pickAndUploadGalleryImage,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300, width: 1.5),
                        ),
                        child: Center(
                          child: _isUploadingPhoto
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                )
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_a_photo_outlined, size: 24, color: AppColors.primary),
                                    SizedBox(height: 4),
                                    Text('फोटो जोड़ें', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                  ],
                                ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSocialLinksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('सोशल मीडिया प्रोफाइल्स (Social Links)', Icons.share_rounded),
        const SizedBox(height: 12),
        _buildCard(
          children: [
            const Text(
              'ग्राहक आपके काम की वीडियो व तस्वीरें देखने के लिए आपके इंस्टाग्राम व सोशल मीडिया से जुड़ सकते हैं:',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _instagramUrlController,
              decoration: const InputDecoration(
                labelText: 'Instagram (यूजरनेम या लिंक)',
                hintText: '@yourhandle या https://instagram.com/...',
                prefixIcon: Icon(Icons.camera_alt_outlined, color: Colors.pinkAccent),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _facebookUrlController,
              decoration: const InputDecoration(
                labelText: 'Facebook (पेज लिंक या नाम)',
                hintText: 'उदा. fb.com/yourbusiness',
                prefixIcon: Icon(Icons.facebook, color: Color(0xFF1877F2)),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _websiteUrlController,
              decoration: const InputDecoration(
                labelText: 'वेबसाइट (Website URL - Optional)',
                hintText: 'उदा. https://yourbusiness.com',
                prefixIcon: Icon(Icons.language_rounded, color: AppColors.primary),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildServicesWithPricingSection() {
    final isSalon = widget.profile.isUnisexSalon;

    // For non-salon providers with no custom services, hide section completely
    if (!isSalon && _servicesWithPricing.isEmpty) {
      return const SizedBox.shrink();
    }

    final sectionTitle = isSalon
        ? 'सैलून सेवाएं व मूल्य सूची (Services & Pricing)'
        : 'अतिरिक्त सेवाएं व मूल्य सूची (Custom Services)';
    final sectionIcon = isSalon ? Icons.content_cut_rounded : Icons.miscellaneous_services_rounded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(sectionTitle, sectionIcon),
        const SizedBox(height: 12),
        _buildCard(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    isSalon
                        ? 'अपनी सैलून सेवाओं की दर व समय सीमा दर्ज करें:'
                        : 'आपकी अतिरिक्त सेवाएं व दरें:',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
                TextButton.icon(
                  onPressed: _showAddServiceDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('नई सेवा जोड़ें', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_servicesWithPricing.isEmpty)
              if (isSalon)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'कोई कस्टम सेवा मूल्य सूची नहीं जुड़ी है। आप लोकप्रिय सैलून सेवाएं तुरंत जोड़ सकते हैं:',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF92400E)),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _buildQuickAddServiceChip('Haircut', 199, 30, 'Unisex'),
                          _buildQuickAddServiceChip('Hair Color', 999, 60, 'Unisex'),
                          _buildQuickAddServiceChip('Facial', 499, 45, 'Unisex'),
                          _buildQuickAddServiceChip('Beard Grooming', 149, 20, 'Men'),
                          _buildQuickAddServiceChip('Bridal Makeup', 2499, 90, 'Women'),
                        ],
                      ),
                    ],
                  ),
                )
              else
                const SizedBox.shrink()
            else
              Column(
                children: _servicesWithPricing.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  final name = item['name']?.toString() ?? 'Service';
                  final price = item['price']?.toString() ?? '0';
                  final duration = item['durationMinutes']?.toString() ?? '30';
                  final gender = item['gender']?.toString() ?? 'Unisex';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 2),
                              Text('₹$price • $duration मिनट • $gender', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                          onPressed: () {
                            setState(() {
                              _servicesWithPricing.removeAt(idx);
                            });
                          },
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickAddServiceChip(String name, int price, int duration, String gender) {
    return ActionChip(
      label: Text('+ $name (₹$price)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFFD97706)),
      onPressed: () {
        setState(() {
          _servicesWithPricing.add({
            'name': name,
            'price': price,
            'durationMinutes': duration,
            'gender': gender,
          });
        });
      },
    );
  }

  void _showAddServiceDialog() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final durationCtrl = TextEditingController(text: '30');
    String selectedGender = 'Unisex';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('नई सेवा जोड़ें (Add Service)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'सेवा का नाम (उदा. Hair Styling)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'मूल्य (₹)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: durationCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'समय (मिनट में)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedGender,
                  decoration: const InputDecoration(labelText: 'उपयुक्त (Target)', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'Unisex', child: Text('Unisex (सभी के लिए)')),
                    DropdownMenuItem(value: 'Men', child: Text('Men (पुरुष)')),
                    DropdownMenuItem(value: 'Women', child: Text('Women (महिला)')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedGender = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('रद्द करें'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final price = int.tryParse(priceCtrl.text.trim()) ?? 0;
                final duration = int.tryParse(durationCtrl.text.trim()) ?? 30;
                if (name.isNotEmpty && price > 0) {
                  setState(() {
                    _servicesWithPricing.add({
                      'name': name,
                      'price': price,
                      'durationMinutes': duration,
                      'gender': selectedGender,
                    });
                  });
                  Navigator.pop(ctx);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('जोड़ें', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
