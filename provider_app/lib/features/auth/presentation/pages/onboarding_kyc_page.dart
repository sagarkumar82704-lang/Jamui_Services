import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/image_compression_helper.dart';
import '../../../categories/data/datasources/firebase_category_remote_data_source.dart';
import '../../../categories/data/repositories/category_repository_impl.dart';
import '../../../categories/domain/entities/service_category.dart';
import '../../../categories/presentation/bloc/category_bloc.dart';
import '../../../categories/presentation/bloc/category_event.dart';
import '../../../categories/presentation/bloc/category_state.dart';
import '../../../location/domain/entities/provider_location_entity.dart';
import '../../../location/data/datasources/location_remote_data_source.dart';
import '../../../location/data/datasources/location_local_data_source.dart';
import '../../../location/data/repositories/location_repository_impl.dart';
import '../../../location/presentation/bloc/location_bloc.dart';
import '../../../location/presentation/pages/provider_location_picker_screen.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/widgets/photo_source_picker.dart';
import '../../../../core/widgets/whatsapp_image_viewer.dart';
import '../../../../core/widgets/app_network_or_base64_image.dart';
import '../../../../core/utils/app_image_utils.dart';
import '../../../../core/services/r2_upload_service.dart';
import '../../domain/entities/provider_profile_entity.dart';
import '../bloc/provider_auth_bloc.dart';
import '../bloc/provider_auth_event.dart';
import '../bloc/provider_auth_state.dart';

class OnboardingKycPage extends StatefulWidget {
  final ProviderProfileEntity currentProfile;

  const OnboardingKycPage({super.key, required this.currentProfile});

  @override
  State<OnboardingKycPage> createState() => _OnboardingKycPageState();
}

class _OnboardingKycPageState extends State<OnboardingKycPage> {
  int _currentStep = 0;

  late TextEditingController _nameController;
  late TextEditingController _businessNameController;
  late TextEditingController _businessDescController;
  late TextEditingController _visitingChargeController;
  late TextEditingController _experienceController;
  late TextEditingController _addressController;
  late TextEditingController _workingHoursController;
  late TextEditingController _orgController;
  late TextEditingController _certDescController;

  String _profilePhotoUrl = '';
  String _businessImageUrl = '';
  String _experienceCertUrl = '';
  bool _hasExpCert = false;
  String _selectedCategory = '';
  String _selectedCategoryTitle = '';
  List<String> _selectedCategoryIds = [];
  String _selectedArea = '';
  double _latitude = 0.0;
  double _longitude = 0.0;
  double _serviceRadiusKm = 10.0;
  double? _locationAccuracy;
  bool _isFetchingLocation = false;
  bool _isLocationConfirmed = false;

  final LocationRemoteDataSource _remoteDataSource = LocationRemoteDataSourceImpl();
  final R2UploadService _r2UploadService = R2UploadService();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentProfile.fullName);
    _businessNameController = TextEditingController(text: widget.currentProfile.businessName);
    _businessDescController = TextEditingController(text: widget.currentProfile.businessDescription);
    _visitingChargeController = TextEditingController(text: widget.currentProfile.visitingCharge.toInt().toString());
    _experienceController = TextEditingController(text: widget.currentProfile.experienceYears.toString());
    _addressController = TextEditingController(text: widget.currentProfile.fullAddress);
    _workingHoursController = TextEditingController(text: widget.currentProfile.workingHours);
    _orgController = TextEditingController(text: widget.currentProfile.previousOrganization);
    _certDescController = TextEditingController(text: widget.currentProfile.experienceDescription);

    _profilePhotoUrl = widget.currentProfile.profileImageUrl;
    _businessImageUrl = widget.currentProfile.businessImageUrl;
    _experienceCertUrl = widget.currentProfile.experienceCertificateUrl;
    _hasExpCert = widget.currentProfile.hasExperienceCertificate || widget.currentProfile.experienceCertificateUrl.isNotEmpty;

    _selectedCategory = widget.currentProfile.primaryCategoryId;
    _selectedCategoryTitle = widget.currentProfile.primaryCategoryTitle;
    _selectedCategoryIds = List<String>.from(widget.currentProfile.selectedCategoryIds);
    _selectedArea = widget.currentProfile.jamuiArea.isNotEmpty ? widget.currentProfile.jamuiArea : '';
    _latitude = widget.currentProfile.latitude;
    _longitude = widget.currentProfile.longitude;
    _serviceRadiusKm = widget.currentProfile.serviceRadiusKm;
    if (_latitude != 0.0 && _longitude != 0.0 && widget.currentProfile.fullAddress.isNotEmpty) {
      _isLocationConfirmed = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _businessNameController.dispose();
    _businessDescController.dispose();
    _visitingChargeController.dispose();
    _experienceController.dispose();
    _addressController.dispose();
    _workingHoursController.dispose();
    _orgController.dispose();
    _certDescController.dispose();
    super.dispose();
  }

  Future<void> _fetchGPSLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      final pos = await _remoteDataSource.getCurrentPosition();
      final loc = await _remoteDataSource.reverseGeocode(
        pos.latitude,
        pos.longitude,
        accuracy: pos.accuracy,
        serviceRadiusKm: _serviceRadiusKm,
      );
      setState(() {
        _latitude = loc.latitude;
        _longitude = loc.longitude;
        _selectedArea = loc.placeName;
        _addressController.text = loc.formattedAddress;
        _locationAccuracy = loc.accuracy;
        _isLocationConfirmed = true;
        _isFetchingLocation = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📍 GPS स्थान प्राप्त: ${loc.placeName} (${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)})'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() => _isFetchingLocation = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _openGoogleMapPicker() async {
    final prefs = await SharedPreferences.getInstance();
    final repo = LocationRepositoryImpl(
      remoteDataSource: _remoteDataSource,
      localDataSource: LocationLocalDataSourceImpl(prefs: prefs),
    );

    if (!mounted) return;

    final result = await Navigator.push<ProviderLocationEntity>(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider<LocationBloc>(
          create: (_) => LocationBloc(locationRepository: repo),
          child: ProviderLocationPickerScreen(
            initialRadiusKm: _serviceRadiusKm,
            initialLocation: (_isLocationConfirmed && _latitude != 0.0)
                ? ProviderLocationEntity(
                    latitude: _latitude,
                    longitude: _longitude,
                    placeName: _selectedArea,
                    formattedAddress: _addressController.text,
                    city: '',
                    district: '',
                    state: '',
                    pincode: '',
                    serviceRadiusKm: _serviceRadiusKm,
                    timestamp: DateTime.now(),
                  )
                : null,
          ),
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _latitude = result.latitude;
        _longitude = result.longitude;
        _selectedArea = result.placeName.isNotEmpty ? result.placeName : _selectedArea;
        _addressController.text = result.formattedAddress.isNotEmpty ? result.formattedAddress : _addressController.text;
        _serviceRadiusKm = result.serviceRadiusKm;
        _locationAccuracy = result.accuracy;
        _isLocationConfirmed = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ मैप से स्थान सेट: $_selectedArea (दायरा: ${_serviceRadiusKm.toInt()} KM)'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final int categoryLimit = widget.currentProfile.categoryLimit;

    return BlocProvider<CategoryBloc>(
      create: (_) => CategoryBloc(
        categoryRepository: CategoryRepositoryImpl(
          remoteDataSource: FirebaseCategoryRemoteDataSource(),
        ),
      )..add(FetchCategoriesEvent()),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'प्रोवाइडर प्रोफाइल व व्यावसायिक विवरण',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
          ),
        ),
        body: BlocConsumer<ProviderAuthBloc, ProviderAuthState>(
          listener: (context, state) {
            if (state is ProviderKycSubmittedSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message), backgroundColor: AppColors.success),
              );
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            } else if (state is ProviderAuthError) {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Row(
                    children: [
                      Icon(Icons.error_outline, color: AppColors.error),
                      SizedBox(width: 8),
                      Text('सबमिशन त्रुटि (Error)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  content: Text(
                    state.message,
                    style: const TextStyle(fontSize: 13),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('ठीक है (OK)'),
                    ),
                  ],
                ),
              );
            }
          },
          builder: (context, state) {
            if (state is ProviderAuthLoading) {
              return const Center(child: CircularProgressIndicator(color: AppColors.accent));
            }

            return Stepper(
              type: StepperType.vertical,
              currentStep: _currentStep,
              onStepTapped: (step) => setState(() => _currentStep = step),
              onStepContinue: () {
                if (_currentStep < 2) {
                  setState(() => _currentStep += 1);
                } else {
                  _submitAllDetails();
                }
              },
              onStepCancel: () {
                if (_currentStep > 0) {
                  setState(() => _currentStep -= 1);
                } else {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                }
              },
              controlsBuilder: (context, details) {
                return Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    children: [
                      ElevatedButton(
                        onPressed: details.onStepContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(_currentStep == 2 ? 'सत्यापन के लिए सबमिट करें' : 'आगे बढ़ें'),
                      ),
                      const SizedBox(width: 12),
                      if (_currentStep > 0)
                        OutlinedButton(
                          onPressed: details.onStepCancel,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('पीछे जाएं'),
                        ),
                    ],
                  ),
                );
              },
              steps: [
                // Step 1: Personal & Category Details
                Step(
                  title: const Text('1. नाम व मल्टी-सर्विस श्रेणी (Categories)', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('आप अधिकतम $categoryLimit कैटगरी चुन सकते हैं'),
                  isActive: _currentStep >= 0,
                  state: _currentStep > 0 ? StepState.complete : StepState.indexed,
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Round Circular Profile Photo Avatar
                      Center(
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    if (_profilePhotoUrl.isNotEmpty) {
                                      WhatsAppImageViewerDialog.show(
                                        context,
                                        imageUrl: _profilePhotoUrl,
                                        title: 'प्रोफाइल फोटो (Profile Photo)',
                                        subtitle: _nameController.text.isNotEmpty ? _nameController.text : widget.currentProfile.fullName,
                                      );
                                    } else {
                                      PhotoSourcePicker.show(context, onImagePicked: (path) {
                                        setState(() => _profilePhotoUrl = path);
                                      });
                                    }
                                  },
                                  child: CircleAvatar(
                                    radius: 46,
                                    backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                                    backgroundImage: AppImageUtils.getImageProvider(_profilePhotoUrl),
                                    child: _profilePhotoUrl.isEmpty
                                        ? const Icon(Icons.person, size: 50, color: AppColors.accent)
                                        : null,
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: () {
                                      PhotoSourcePicker.show(context, onImagePicked: (path) {
                                        setState(() => _profilePhotoUrl = path);
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.accent,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _profilePhotoUrl.isNotEmpty ? 'इमेज टैप करके पूरी फोटो देखें (WhatsApp style)' : 'प्रोफाइल फोटो: कैमरा या गैलरी से चुनें',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'प्रोवाइडर का नाम (Full Name)',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _businessNameController,
                        decoration: InputDecoration(
                          labelText: 'दुकान / सर्विस का नाम (Business Name)',
                          prefixIcon: const Icon(Icons.storefront_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Multi-Category Selection Banner
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.category, color: AppColors.accent),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'प्लान: ${widget.currentProfile.subscriptionPlan.toUpperCase()} | अनुमति सीमित: $categoryLimit कैटगरी (चुनी: ${_selectedCategoryIds.length}/$categoryLimit)',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Firestore Dynamic Categories Checkbox List
                      BlocBuilder<CategoryBloc, CategoryState>(
                        builder: (context, catState) {
                          if (catState is CategoryLoading) {
                            return Container(
                              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(color: AppColors.accent),
                                  SizedBox(height: 12),
                                  Text(
                                    'कैटगरीज लोड हो रही हैं... (Loading categories...)',
                                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            );
                          }

                          if (catState is CategoryError) {
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'कैटगरीज लोड करने में असमर्थ: ${catState.message}',
                                          style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      context.read<CategoryBloc>().add(FetchCategoriesEvent());
                                    },
                                    icon: const Icon(Icons.refresh, size: 14),
                                    label: const Text('पुनः प्रयास करें (Retry)', style: TextStyle(fontSize: 12)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.error,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          List<ServiceCategory> categories = [];
                          if (catState is CategoryLoaded) {
                            categories = catState.categories;
                          }

                          // STRICT REQUIREMENT: ZERO DUMMY/STATIC FALLBACK CATEGORIES.
                          if (categories.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.amber.shade300),
                              ),
                              child: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.category_outlined, color: Colors.amber, size: 36),
                                  SizedBox(height: 10),
                                  Text(
                                    'वर्तमान में कोई सेवा या श्रेणी उपलब्ध नहीं है।\nकृपया बाद में प्रयास करें।',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'No services/categories are currently available. Please try again later.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                  ),
                                ],
                              ),
                            );
                          }

                          if (_selectedCategory.isEmpty && categories.isNotEmpty) {
                            _selectedCategory = categories.first.id;
                            _selectedCategoryTitle = categories.first.titleHindi;
                            if (!_selectedCategoryIds.contains(_selectedCategory)) {
                              _selectedCategoryIds.add(_selectedCategory);
                            }
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: categories.map((cat) {
                              final isSelected = _selectedCategoryIds.contains(cat.id);
                              final isPrimary = _selectedCategory == cat.id;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.accent.withValues(alpha: 0.05) : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: isSelected ? AppColors.accent : Colors.grey.shade300),
                                ),
                                child: CheckboxListTile(
                                  dense: true,
                                  secondary: Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: AppColors.accent.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: cat.imageUrl.isNotEmpty
                                        ? AppNetworkOrBase64Image(
                                            imageUrl: cat.imageUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (ctx, err, stack) => const Icon(Icons.handyman, size: 20, color: AppColors.accent),
                                          )
                                        : const Icon(Icons.handyman, size: 20, color: AppColors.accent),
                                  ),
                                  title: Text(
                                    '${cat.titleHindi} (${cat.titleEnglish})',
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  subtitle: isPrimary
                                      ? const Text('मुख्य श्रेणी (Primary Category)', style: TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.bold))
                                      : (cat.subServices.isNotEmpty
                                          ? Text(cat.subServices.take(3).join(', '), style: TextStyle(color: Colors.grey.shade600, fontSize: 11))
                                          : null),
                                  value: isSelected,
                                  activeColor: AppColors.accent,
                                  onChanged: (bool? checked) {
                                    setState(() {
                                      if (checked == true) {
                                        if (_selectedCategoryIds.length >= categoryLimit) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('आपकी वर्तमान योजना में अधिकतम $categoryLimit कैटगरी की अनुमति है। अधिक कैटगरी के लिए प्लान अपग्रेड करें।'),
                                              backgroundColor: AppColors.warning,
                                            ),
                                          );
                                          return;
                                        }
                                        _selectedCategoryIds.add(cat.id);
                                        if (_selectedCategory.isEmpty) {
                                          _selectedCategory = cat.id;
                                          _selectedCategoryTitle = cat.titleHindi;
                                        }
                                      } else {
                                        if (_selectedCategoryIds.length <= 1) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('कम से कम एक श्रेणी (Category) चुनना अनिवार्य है।'),
                                              backgroundColor: AppColors.warning,
                                            ),
                                          );
                                          return;
                                        }
                                        _selectedCategoryIds.remove(cat.id);
                                        if (_selectedCategory == cat.id && _selectedCategoryIds.isNotEmpty) {
                                          _selectedCategory = _selectedCategoryIds.first;
                                          final nextPrimary = categories.firstWhere(
                                            (c) => c.id == _selectedCategory,
                                            orElse: () => cat,
                                          );
                                          _selectedCategoryTitle = nextPrimary.titleHindi;
                                        }
                                      }
                                    });
                                  },
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _businessDescController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'व्यापार विवरण (Business Description)',
                          prefixIcon: const Icon(Icons.description_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),

                // Step 2: Rate & Real GPS Location
                Step(
                  title: const Text('2. फीस एवं रियल GPS लोकेशन', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('विज़िटिंग चार्ज व लाइव GPS स्थान'),
                  isActive: _currentStep >= 1,
                  state: _currentStep > 1 ? StepState.complete : StepState.indexed,
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'विज़िटिंग फीस (₹)',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _visitingChargeController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: 'उदा. 100',
                                    prefixIcon: const Icon(Icons.currency_rupee, size: 20),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'अनुभव (वर्ष)',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _experienceController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: 'उदा. 5',
                                    prefixIcon: const Icon(Icons.work_history_outlined, size: 20),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Google Maps & GPS Location Section
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _isLocationConfirmed ? const Color(0xFF1A73E8).withValues(alpha: 0.5) : Colors.grey.shade300),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Header with Status Badge
                            Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEA4335).withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.location_on, color: Color(0xFFEA4335), size: 20),
                                      ),
                                      const SizedBox(width: 8),
                                      const Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'सर्विस लोकेशन (Google Maps)',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                                          ),
                                          Text(
                                            'ग्राहक आपको इसी लोकेशन से खोजेंगे',
                                            style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _isLocationConfirmed ? const Color(0xFFE6F4EA) : Colors.amber.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: _isLocationConfirmed ? const Color(0xFF137333) : Colors.amber.shade400,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _isLocationConfirmed ? Icons.verified : Icons.info_outline,
                                          size: 12,
                                          color: _isLocationConfirmed ? const Color(0xFF137333) : Colors.amber.shade800,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _isLocationConfirmed ? 'वेरीफाइड' : 'सेट करें',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: _isLocationConfirmed ? const Color(0xFF137333) : Colors.amber.shade800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Interactive Mini Google Map Preview
                            if (_latitude != 0.0 && _longitude != 0.0) ...[
                              ClipRRect(
                                child: SizedBox(
                                  height: 140,
                                  width: double.infinity,
                                  child: Stack(
                                    children: [
                                      FlutterMap(
                                        options: MapOptions(
                                          initialCenter: LatLng(_latitude, _longitude),
                                          initialZoom: 15.0,
                                          interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
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
                                          MarkerLayer(
                                            markers: [
                                              Marker(
                                                point: LatLng(_latitude, _longitude),
                                                width: 40,
                                                height: 40,
                                                child: Container(
                                                  decoration: const BoxDecoration(
                                                    color: Color(0xFFEA4335),
                                                    shape: BoxShape.circle,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black38,
                                                        blurRadius: 6,
                                                        offset: Offset(0, 2),
                                                      ),
                                                    ],
                                                  ),
                                                  child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 20),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: InkWell(
                                          onTap: _openGoogleMapPicker,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.92),
                                              borderRadius: BorderRadius.circular(6),
                                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.fullscreen, size: 14, color: Color(0xFF1A73E8)),
                                                SizedBox(width: 4),
                                                Text('फुल मैप देखें', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1A73E8))),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],

                            // Location Details & Action Buttons
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'Lat: ${_latitude.toStringAsFixed(6)}',
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'Lng: ${_longitude.toStringAsFixed(6)}',
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                          ),
                                        ),
                                      ),
                                      if (_locationAccuracy != null) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE8F0FE),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '±${_locationAccuracy!.toStringAsFixed(1)}m',
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1A73E8)),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // Two Action Buttons: 1. Current GPS, 2. Open Google Map
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: _isFetchingLocation ? null : _fetchGPSLocation,
                                          icon: _isFetchingLocation
                                              ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                              : const Icon(Icons.my_location, size: 16),
                                          label: Text(_isFetchingLocation ? 'खोज रहे हैं...' : 'GPS से लें'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: const Color(0xFF1A73E8),
                                            side: const BorderSide(color: Color(0xFF1A73E8)),
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: _openGoogleMapPicker,
                                          icon: const Icon(Icons.map_outlined, size: 16),
                                          label: const Text('Google मैप पर चुनें'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF1A73E8),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: _addressController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'पूरा पता व लैंडमार्क (Full Address)',
                          prefixIcon: const Icon(Icons.location_on_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Service Radius Slider
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'सर्विस दायरा (Service Radius):',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1A73E8),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${_serviceRadiusKm.toInt()} KM',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'आप अपनी लोकेशन से ${_serviceRadiusKm.toInt()} किमी तक के ग्राहकों को सर्विस प्रदान करेंगे',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                            Slider(
                              value: _serviceRadiusKm,
                              min: 3,
                              max: 30,
                              divisions: 9,
                              activeColor: const Color(0xFF1A73E8),
                              onChanged: (val) => setState(() => _serviceRadiusKm = val),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Step 3: Workplace Photo, Working Hours & Experience Certificate
                Step(
                  title: const Text('3. वर्कप्लेस फोटो व अनुभव प्रमाण पत्र', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('दुकान की फोटो, समय एवं अनुभव सर्टिफिकेट (ऑप्शनल)'),
                  isActive: _currentStep >= 2,
                  state: _currentStep >= 2 ? StepState.indexed : StepState.indexed,
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.shield_outlined, color: AppColors.accent, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'JAMUI SERVICE पर आधार या किसी ID की आवश्यकता नहीं है। अपने कार्यक्षेत्र/दुकान की फोटो और कार्य समय दर्ज करें।',
                                style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Workplace Photo (Camera / Gallery Picker)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.storefront_outlined, color: AppColors.accent, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'दुकान / कार्यक्षेत्र की फोटो (Workplace Photo)',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'अपने काम के सेटअप, दुकान, टूलबॉक्स या वर्कशॉप की फोटो अपलोड करें। (इमेज टैप कर फुल स्क्रीन देखें)',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 12),
                            if (_businessImageUrl.isNotEmpty) ...[
                              GestureDetector(
                                onTap: () {
                                  WhatsAppImageViewerDialog.show(
                                    context,
                                    imageUrl: _businessImageUrl,
                                    title: 'दुकान / कार्यक्षेत्र फोटो (Workplace Photo)',
                                  );
                                },
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        height: 150,
                                        width: double.infinity,
                                        color: Colors.grey.shade100,
                                        child: AppNetworkOrBase64Image(
                                          imageUrl: _businessImageUrl,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      right: 8,
                                      top: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.75),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.zoom_in, color: Colors.white, size: 14),
                                            SizedBox(width: 4),
                                            Text('ज़ूम देखें (WhatsApp)', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      PhotoSourcePicker.show(
                                        context,
                                        isCircle: false,
                                        title: 'दुकान / वर्कप्लेस फोटो चुनें',
                                        onImagePicked: (path) {
                                          setState(() => _businessImageUrl = path);
                                        },
                                      );
                                    },
                                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                                    label: Text(_businessImageUrl.isNotEmpty ? 'फोटो बदलें (Camera/Gallery)' : 'फोटो चुनें (Camera 📷 / Gallery 🖼️)'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.accent,
                                      side: const BorderSide(color: AppColors.accent),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Working Hours
                      TextField(
                        controller: _workingHoursController,
                        decoration: InputDecoration(
                          labelText: 'कार्य समय (Working Hours)',
                          hintText: 'उदा. 09:00 AM - 08:00 PM',
                          prefixIcon: const Icon(Icons.access_time_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Experience Certificate Section
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'अनुभव प्रमाण पत्र (Experience Certificate)',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.accent),
                                      ),
                                      Text(
                                        'क्या आपके पास किसी संस्था/कंपनी/ठेकेदार का सर्टिफिकेट है?',
                                        style: TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: _hasExpCert,
                                  activeThumbColor: AppColors.accent,
                                  onChanged: (val) => setState(() => _hasExpCert = val),
                                ),
                              ],
                            ),
                            if (_hasExpCert) ...[
                              const Divider(height: 20),
                              TextField(
                                controller: _orgController,
                                decoration: InputDecoration(
                                  labelText: 'पूर्व कंपनी / संस्थान (Organization/Employer)',
                                  hintText: 'उदा. ABC Electrical Services / Jamui Rail Corp',
                                  prefixIcon: const Icon(Icons.business_center_outlined),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'सर्टिफिकेट फ़ाइल (Certificate Image/PDF):',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              if (_experienceCertUrl.isNotEmpty) ...[
                                GestureDetector(
                                  onTap: () {
                                    WhatsAppImageViewerDialog.show(
                                      context,
                                      imageUrl: _experienceCertUrl,
                                      title: 'अनुभव प्रमाण पत्र (Experience Certificate)',
                                      subtitle: _orgController.text,
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.blue.shade200),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.verified_rounded, color: Colors.blue),
                                        const SizedBox(width: 8),
                                        const Expanded(
                                          child: Text(
                                            'सर्टिफिकेट फ़ाइल तैयार ✓ (टैप कर ज़ूम देखें)',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue),
                                          ),
                                        ),
                                        const Icon(Icons.zoom_in, color: Colors.blue, size: 20),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        PhotoSourcePicker.show(
                                          context,
                                          isCircle: false,
                                          title: 'अनुभव प्रमाण पत्र चुनें',
                                          onImagePicked: (path) {
                                            setState(() => _experienceCertUrl = path);
                                          },
                                        );
                                      },
                                      icon: const Icon(Icons.file_upload_outlined, size: 18),
                                      label: Text(_experienceCertUrl.isNotEmpty ? 'सर्टिफिकेट बदलें' : 'सर्टिफिकेट अपलोड (Camera 📷 / Gallery 🖼️)'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.accent,
                                        side: const BorderSide(color: AppColors.accent),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _certDescController,
                                maxLines: 2,
                                decoration: InputDecoration(
                                  labelText: 'सर्टिफिकेट व काम का विवरण (Description)',
                                  hintText: 'उदा. 5 साल का औद्योगिक वायरिंग और मेंटेनेंस का प्रमाण पत्र',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  isDense: true,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _submitAllDetails() async {
    final name = _nameController.text.trim();
    final businessName = _businessNameController.text.trim();
    final visitingCharge = double.tryParse(_visitingChargeController.text.trim()) ?? 100.0;
    final experience = int.tryParse(_experienceController.text.trim()) ?? 1;

    if (name.isEmpty || businessName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('कृपया नाम और दुकान का नाम भरें')),
      );
      return;
    }

    if (_selectedCategoryIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('कृपया कम से कम एक सेवा श्रेणी (Category) चुनें')),
      );
      return;
    }

    if (!_isLocationConfirmed || _latitude == 0.0 || _longitude == 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('कृपया मैप से अपना वास्तविक GPS कार्यक्षेत्र स्थान चुनें।'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Show loading indicator dialog while uploading images
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(color: AppColors.accent),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                'प्रोफाइल विवरण एवं तस्वीरें सुरक्षित रूप से अपलोड हो रही हैं...',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );

    String profilePhoto = _profilePhotoUrl.isNotEmpty ? _profilePhotoUrl : widget.currentProfile.profileImageUrl;
    String bizImg = _businessImageUrl.isNotEmpty
        ? _businessImageUrl
        : (widget.currentProfile.businessImageUrl.isNotEmpty
            ? widget.currentProfile.businessImageUrl
            : 'https://images.unsplash.com/photo-1581092918056-0c4c3acd3789?w=600');
    String certUrl = _experienceCertUrl.isNotEmpty
        ? _experienceCertUrl
        : widget.currentProfile.experienceCertificateUrl;

    try {
      profilePhoto = await _uploadImageToStorage(profilePhoto, 'profile');
      bizImg = await _uploadImageToStorage(bizImg, 'business');
      if (_hasExpCert) {
        certUrl = await _uploadImageToStorage(certUrl, 'certificates');
      }
    } catch (e) {
      debugPrint('Upload error: $e');
      if (mounted) {
        Navigator.pop(context); // Dismiss loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('फोटो या दस्तावेज अपलोड विफल रहा: ${e.toString().replaceFirst("Exception: ", "")}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'पुनः प्रयास (Retry)',
              textColor: Colors.white,
              onPressed: _submitAllDetails,
            ),
          ),
        );
      }
      return; // Abort submission: Never write broken references or unuploaded files to Firestore
    }

    if (mounted) {
      Navigator.pop(context); // Dismiss loading dialog
    }

    final updatedProfile = widget.currentProfile.copyWith(
      fullName: name,
      businessName: businessName,
      businessDescription: _businessDescController.text.trim(),
      profileImageUrl: profilePhoto,
      primaryCategoryId: _selectedCategory,
      primaryCategoryTitle: _selectedCategoryTitle,
      selectedCategoryIds: _selectedCategoryIds,
      visitingCharge: visitingCharge,
      experienceYears: experience,
      jamuiArea: _selectedArea,
      fullAddress: _addressController.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
      serviceRadiusKm: _serviceRadiusKm,
      businessImageUrl: bizImg,
      workingHours: _workingHoursController.text.trim().isNotEmpty
          ? _workingHoursController.text.trim()
          : '09:00 AM - 08:00 PM',
      hasExperienceCertificate: _hasExpCert,
      experienceCertificateUrl: _hasExpCert ? certUrl : '',
      previousOrganization: _hasExpCert ? _orgController.text.trim() : '',
      experienceDescription: _hasExpCert ? _certDescController.text.trim() : '',
      experienceCertificateStatus: _hasExpCert
          ? (certUrl.isNotEmpty ? 'pendingReview' : 'notUploaded')
          : 'notUploaded',
      kycStatus: ProviderKycStatus.pendingReview,
      status: ProviderAccountStatus.pendingReview,
    );

    // Save Profile & Submit KYC atomically
    if (mounted) {
      context.read<ProviderAuthBloc>().add(UpdateProviderProfileEvent(updatedProfile));
    }
  }

  Future<String> _uploadImageToStorage(String localOrNetworkPath, String folder) async {
    if (localOrNetworkPath.isEmpty ||
        localOrNetworkPath.startsWith('http://') ||
        localOrNetworkPath.startsWith('https://') ||
        localOrNetworkPath.startsWith('data:image/')) {
      return localOrNetworkPath;
    }
    if (kIsWeb) {
      return localOrNetworkPath;
    }
    final file = File(localOrNetworkPath);
    if (!await file.exists()) {
      return localOrNetworkPath;
    }

    if (folder == 'profile' || folder == 'business') {
      // 1. Strictly Cloudflare R2 ONLY for public images.
      // Zero Firebase Storage fallback to prevent stealth storage costs.
      try {
        final fileToUpload = await ImageCompressionHelper.compressFileToJpeg(
          file,
          quality: 80,
          maxDimension: 800,
        );

        final r2Result = await _r2UploadService.uploadFile(
          fileToUpload,
          folder: folder,
          targetId: widget.currentProfile.id,
          mimeType: 'image/jpeg',
        );
        return r2Result.objectKey; // Canonical relative R2 objectKey
      } catch (r2Error) {
        debugPrint('❌ [OnboardingKycPage] R2 upload failed for public folder $folder: $r2Error');
        throw Exception('Cloudflare R2 पर $folder फोटो अपलोड विफल रहा: ${r2Error.toString().replaceFirst("Exception: ", "")}');
      }
    } else if (folder == 'certificates') {
      // Direct Cloudflare R2 upload for certificate documents.
      // Private document access is secured via server-verified presigned GET URLs (getSecureDocumentViewUrl).
      try {
        final r2Result = await _r2UploadService.uploadFile(
          file,
          folder: folder,
          targetId: widget.currentProfile.id,
        );
        debugPrint('Cloudflare R2 certificate upload success: ${r2Result.objectKey}');
        return r2Result.objectKey; // Canonical relative R2 objectKey
      } catch (e) {
        debugPrint('Cloudflare R2 certificate upload failed: $e');
        throw Exception('सर्टिफिकेट अपलोड विफल रहा: ${e.toString().replaceFirst("Exception: ", "")}');
      }
    } else {
      throw ArgumentError('Unsupported folder: $folder');
    }
  }
}
