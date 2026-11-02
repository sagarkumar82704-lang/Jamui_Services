import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/location_service.dart';
import '../../../discovery/presentation/bloc/discovery_bloc.dart';
import '../../../discovery/presentation/bloc/discovery_event.dart';
import '../../../home/presentation/pages/customer_main_shell.dart';
import '../../../location/domain/entities/customer_location_entity.dart';
import '../../../location/presentation/bloc/location_bloc.dart';
import '../../../location/presentation/bloc/location_event.dart';
import '../../../location/presentation/pages/location_picker_screen.dart';
import '../../domain/entities/customer_entity.dart';
import '../bloc/customer_auth_bloc.dart';
import '../bloc/customer_auth_event.dart';
import '../bloc/customer_auth_state.dart';

class CustomerProfileSetupScreen extends StatefulWidget {
  final String userId;
  final String? email;
  final String phoneNumber;

  const CustomerProfileSetupScreen({
    super.key,
    required this.userId,
    this.email,
    this.phoneNumber = '',
  });

  @override
  State<CustomerProfileSetupScreen> createState() => _CustomerProfileSetupScreenState();
}

class _CustomerProfileSetupScreenState extends State<CustomerProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  bool _isDetectingLocation = false;
  CustomerLocationEntity? _detectedLocation;

  @override
  void initState() {
    super.initState();
    String rawPhone = widget.phoneNumber;
    if (rawPhone.isEmpty) {
      rawPhone = FirebaseAuth.instance.currentUser?.phoneNumber ?? '';
    }
    rawPhone = rawPhone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (rawPhone.startsWith('+91')) rawPhone = rawPhone.substring(3);
    _phoneController.text = rawPhone;

    if (widget.email != null && widget.email!.isNotEmpty) {
      _emailController.text = widget.email!;
    } else if (FirebaseAuth.instance.currentUser?.email != null) {
      _emailController.text = FirebaseAuth.instance.currentUser!.email!;
    }
    _autoDetectGpsLocation();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _areaController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _autoDetectGpsLocation() async {
    setState(() => _isDetectingLocation = true);
    try {
      final loc = await LocationService.fetchCurrentLocation();
      if (!mounted) return;

      final placeName = loc.jamuiArea.isNotEmpty ? loc.jamuiArea : '';
      final fullAddr = loc.fullAddress.isNotEmpty
          ? loc.fullAddress
          : (placeName.isNotEmpty ? placeName : 'GPS: ${loc.latitude.toStringAsFixed(6)}, ${loc.longitude.toStringAsFixed(6)}');

      setState(() {
        _detectedLocation = CustomerLocationEntity(
          latitude: loc.latitude,
          longitude: loc.longitude,
          placeName: placeName.isNotEmpty ? placeName : 'वर्तमान स्थान',
          formattedAddress: fullAddr,
          city: loc.city,
          district: loc.district,
          state: loc.state,
          pincode: loc.pincode,
          timestamp: DateTime.now(),
        );

        if (_areaController.text.trim().isEmpty && placeName.isNotEmpty) {
          _areaController.text = placeName;
        }
        if (_addressController.text.trim().isEmpty) {
          _addressController.text = fullAddr;
        }
        _isDetectingLocation = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isDetectingLocation = false);
      }
    }
  }

  Future<void> _openMapPicker() async {
    final result = await Navigator.push<CustomerLocationEntity>(
      context,
      MaterialPageRoute(builder: (_) => const LocationPickerScreen(isFromOnboarding: false)),
    );

    if (result != null && mounted) {
      setState(() {
        _detectedLocation = result;
        final cityOrDistrict = result.city.isNotEmpty ? result.city : (result.district.isNotEmpty ? result.district : '');
        _areaController.text = result.placeName.isNotEmpty
            ? result.placeName
            : (cityOrDistrict.isNotEmpty ? cityOrDistrict : 'GPS Location');
        _addressController.text = result.formattedAddress.isNotEmpty
            ? result.formattedAddress
            : (result.placeName.isNotEmpty && cityOrDistrict.isNotEmpty
                ? '${result.placeName}, $cityOrDistrict'
                : 'Lat: ${result.latitude.toStringAsFixed(5)}, Lng: ${result.longitude.toStringAsFixed(5)}');
      });
    }
  }

  void _onSaveProfile() {
    if (_formKey.currentState?.validate() ?? false) {
      final user = FirebaseAuth.instance.currentUser;
      final rawEntered = _phoneController.text.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
      final cleanPhone = rawEntered.startsWith('+91')
          ? rawEntered
          : (rawEntered.isNotEmpty ? '+91$rawEntered' : (widget.phoneNumber.isNotEmpty ? widget.phoneNumber : (user?.phoneNumber ?? '')));

      final customer = CustomerEntity(
        id: widget.userId,
        phoneNumber: cleanPhone,
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : user?.email,
        jamuiArea: _areaController.text.trim().isNotEmpty ? _areaController.text.trim() : 'जमुई',
        address: _addressController.text.trim(),
        createdAt: DateTime.now(),
      );

      // Save to local cache & DiscoveryBloc if location was detected
      if (_detectedLocation != null) {
        context.read<LocationBloc>().add(ConfirmSelectedLocationEvent(_detectedLocation!));
        context.read<DiscoveryBloc>().add(UpdateCustomerLocationEvent(
              latitude: _detectedLocation!.latitude,
              longitude: _detectedLocation!.longitude,
              areaName: '${_detectedLocation!.placeName} (${_detectedLocation!.pincode})',
            ));
      }

      context.read<CustomerAuthBloc>().add(SaveCustomerProfileEvent(customer));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('प्रोफ़ाइल बनाएं', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: BlocListener<CustomerAuthBloc, CustomerAuthState>(
        listener: (context, state) {
          if (state is CustomerAuthenticatedState) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const CustomerMainShell()),
              (route) => false,
            );
          } else if (state is CustomerAuthFailureState) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage), backgroundColor: Colors.red),
            );
          }
        },
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'अपनी जानकारी दर्ज करें',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'जमुई में नजदीकी कारीगर से संपर्क करने के लिए अपनी प्रोफ़ाइल पूरी करें',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 20),

                  // GPS Auto-Detect Location Banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: _isDetectingLocation
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.my_location, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isDetectingLocation
                                    ? 'GPS से लोकेशन खोजी जा रही है...'
                                    : (_detectedLocation != null
                                        ? '📍 स्थान पहचाना गया: ${_detectedLocation!.placeName}'
                                        : 'GPS से वर्तमान स्थान ऑटो-डिटेक्ट करें'),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                              ),
                              Text(
                                _detectedLocation != null ? 'इलाका और पता स्वतः भर गया है' : '1-क्लिक में इलाका और पता भरें',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: _isDetectingLocation ? null : _openMapPicker,
                          child: const Text('मैप देखें', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'पूरा नाम (Full Name) *',
                      hintText: 'उदा. अमित कुमार',
                      prefixIcon: const Icon(Icons.person_outline, color: AppColors.primary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'कृपया अपना पूरा नाम लिखें' : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    decoration: InputDecoration(
                      labelText: 'मोबाइल नंबर (Mobile Number) *',
                      hintText: '10 अंकों का नंबर',
                      prefixText: '+91 ',
                      prefixIcon: const Icon(Icons.phone_android_outlined, color: AppColors.primary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'कृपया मोबाइल नंबर दर्ज करें';
                      final clean = v.replaceAll(RegExp(r'[\s\-\(\)]'), '').trim();
                      if (clean.length != 10) return 'मान्य 10 अंकों का मोबाइल नंबर लिखें';
                      if (!RegExp(r'^[6-9]\d{9}$').hasMatch(clean)) return 'मोबाइल नंबर 6, 7, 8 या 9 से शुरू होना चाहिए';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _areaController,
                    decoration: InputDecoration(
                      labelText: 'इलाका / मोहल्ला / ग्राम / शहर (Area / City) *',
                      hintText: 'उदा. मलयपुर, झाझा, जमुई शहर',
                      prefixIcon: const Icon(Icons.location_city_outlined, color: AppColors.primary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.gps_fixed, color: AppColors.primary, size: 20),
                        tooltip: 'GPS से रिफ्रेश करें',
                        onPressed: _autoDetectGpsLocation,
                      ),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'कृपया अपना इलाका या शहर लिखें' : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _addressController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'पूरा पता (House No / Landmark / Colony) *',
                      hintText: 'उदा. स्टेशन रोड, नियर दुर्गा मंदिर, मलयपुर, जमुई',
                      prefixIcon: const Icon(Icons.home_outlined, color: AppColors.primary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'कृपया अपना पता लिखें' : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'ईमेल आईडी (Optional)',
                      hintText: 'उदा. yourname@gmail.com',
                      prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 28),

                  BlocBuilder<CustomerAuthBloc, CustomerAuthState>(
                    builder: (context, state) {
                      final isLoading = state is CustomerAuthLoadingState;
                      return SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _onSaveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  'प्रोफ़ाइल सहेजें और शुरू करें →',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
