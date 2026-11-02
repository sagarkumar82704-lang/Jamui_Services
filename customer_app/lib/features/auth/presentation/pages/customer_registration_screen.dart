import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../discovery/presentation/bloc/discovery_bloc.dart';
import '../../../discovery/presentation/bloc/discovery_event.dart';
import '../../../home/presentation/pages/customer_main_shell.dart';
import '../../../location/domain/entities/customer_location_entity.dart';
import '../../../location/presentation/bloc/location_bloc.dart';
import '../../../location/presentation/bloc/location_event.dart';
import '../../../location/presentation/pages/location_picker_screen.dart';
import '../bloc/customer_auth_bloc.dart';
import '../bloc/customer_auth_event.dart';
import '../bloc/customer_auth_state.dart';

class CustomerRegistrationScreen extends StatefulWidget {
  const CustomerRegistrationScreen({super.key});

  @override
  State<CustomerRegistrationScreen> createState() => _CustomerRegistrationScreenState();
}

class _CustomerRegistrationScreenState extends State<CustomerRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  CustomerLocationEntity? _selectedLocation;
  bool _isDetectingLocation = false;
  String? _locationError;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Auto-detect current GPS location immediately on screen opening
    _autoDetectGpsLocation();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _areaController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  /// Automatically fetch GPS location and reverse geocode without hardcoded text
  Future<void> _autoDetectGpsLocation() async {
    setState(() {
      _isDetectingLocation = true;
      _locationError = null;
    });

    try {
      final loc = await LocationService.fetchCurrentLocation();
      if (!mounted) return;

      final placeName = loc.jamuiArea.isNotEmpty ? loc.jamuiArea : '';
      final fullAddr = loc.fullAddress.isNotEmpty
          ? loc.fullAddress
          : (placeName.isNotEmpty ? placeName : 'GPS: ${loc.latitude.toStringAsFixed(6)}, ${loc.longitude.toStringAsFixed(6)}');

      setState(() {
        _selectedLocation = CustomerLocationEntity(
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

        _areaController.text = placeName;
        _addressController.text = fullAddr;
        _isDetectingLocation = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDetectingLocation = false;
          _locationError = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  /// Open full interactive Google Maps picker screen to select or fine-tune pin
  Future<void> _openMapPicker() async {
    setState(() => _locationError = null);
    final result = await Navigator.push<CustomerLocationEntity>(
      context,
      MaterialPageRoute(
        builder: (_) => const LocationPickerScreen(isFromOnboarding: false),
      ),
    );

    if (result != null && mounted) {
      setState(() {
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

  String _cleanIndianPhoneNumber(String raw) {
    String clean = raw.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (clean.startsWith('+91')) {
      clean = clean.substring(3);
    } else if (clean.startsWith('0')) {
      clean = clean.substring(1);
    }
    return clean;
  }

  void _onRegisterSubmit() {
    FocusScope.of(context).unfocus();
    setState(() => _errorMessage = null);

    // Validate that location has been fetched from Map/GPS
    if (_selectedLocation == null || _areaController.text.trim().isEmpty) {
      setState(() {
        _locationError = 'कृपया गूगल मैप या GPS से अपना ब्लॉक / इलाका चुनें';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.location_off, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text('कृपया मैप से अपना ब्लॉक/स्थान चुनें ताकि नजदीकी कारीगर मिल सकें।', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    if (_formKey.currentState?.validate() ?? false) {
      final cleanPhone = _cleanIndianPhoneNumber(_phoneController.text.trim());
      final fullPhoneNumber = '+91$cleanPhone';

      final finalArea = _areaController.text.trim().isNotEmpty
          ? _areaController.text.trim()
          : (_selectedLocation!.placeName.isNotEmpty ? _selectedLocation!.placeName : 'जमुई');

      final finalAddress = _addressController.text.trim().isNotEmpty
          ? _addressController.text.trim()
          : _selectedLocation!.formattedAddress;

      // Synchronize with local state blocs for instant home page personalization
      context.read<LocationBloc>().add(ConfirmSelectedLocationEvent(_selectedLocation!));
      context.read<DiscoveryBloc>().add(
            UpdateCustomerLocationEvent(
              latitude: _selectedLocation!.latitude,
              longitude: _selectedLocation!.longitude,
              areaName: '$finalArea (${_selectedLocation!.pincode.isNotEmpty ? _selectedLocation!.pincode : 'जमुई'})',
            ),
          );

      context.read<CustomerAuthBloc>().add(
            RegisterWithEmailEvent(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
              fullName: _fullNameController.text.trim(),
              phoneNumber: fullPhoneNumber,
              jamuiArea: finalArea,
              address: finalAddress,
              latitude: _selectedLocation!.latitude,
              longitude: _selectedLocation!.longitude,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      body: BlocConsumer<CustomerAuthBloc, CustomerAuthState>(
        listener: (context, state) {
          if (state is CustomerAuthenticatedState) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const CustomerMainShell()),
              (route) => false,
            );
          } else if (state is CustomerAuthFailureState) {
            setState(() => _errorMessage = state.errorMessage);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text(state.errorMessage, style: const TextStyle(fontSize: 13))),
                  ],
                ),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is CustomerAuthLoadingState;
          final loadingMessage = state is CustomerAuthLoadingState ? state.message : null;

          return SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // Header Hero Gradient Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(top: 24, bottom: 22, left: 20, right: 20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, Color(0xFF0F8A6D)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                              onPressed: () => Navigator.pop(context),
                              tooltip: 'लॉगिन स्क्रीन पर वापस जाएं',
                            ),
                            const Spacer(),
                            const AppLogo(size: 52, showShadow: true),
                            const Spacer(),
                            const SizedBox(width: 48),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'नया ग्राहक खाता बनाएं',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'जमुई की भरोसेमंद लोकल सेवाओं से जुड़ें',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.92),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Main Registration Form Card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 16,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(22),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_errorMessage != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: TextStyle(color: Colors.red.shade800, fontSize: 12.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // 1. Full Name
                            const Text(
                              'पूरा नाम (Full Name) *',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _fullNameController,
                              textCapitalization: TextCapitalization.words,
                              enabled: !isLoading,
                              decoration: _inputDecoration(
                                hint: 'उदा. राहुल कुमार',
                                prefixIcon: Icons.person_outline_rounded,
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'कृपया अपना पूरा नाम लिखें';
                                }
                                if (val.trim().length < 2) {
                                  return 'नाम कम से कम 2 अक्षरों का होना चाहिए';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // 2. Mobile Number
                            const Text(
                              'मोबाइल नंबर (Mobile Number) *',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              enabled: !isLoading,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              decoration: InputDecoration(
                                hintText: '10 अंकों का मोबाइल नंबर',
                                hintStyle: TextStyle(fontSize: 13.5, color: Colors.grey.shade400),
                                prefixIcon: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  margin: const EdgeInsets.only(right: 10),
                                  decoration: BoxDecoration(
                                    border: Border(right: BorderSide(color: Colors.grey.shade300, width: 1.2)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('🇮🇳', style: TextStyle(fontSize: 16)),
                                      SizedBox(width: 6),
                                      Text(
                                        '+91',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF9FBFA),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.error),
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'कृपया मोबाइल नंबर दर्ज करें';
                                }
                                final clean = _cleanIndianPhoneNumber(val);
                                if (clean.length != 10) {
                                  return 'मान्य 10 अंकों का मोबाइल नंबर लिखें';
                                }
                                if (!RegExp(r'^[6-9]\d{9}$').hasMatch(clean)) {
                                  return 'मोबाइल नंबर 6, 7, 8 या 9 से शुरू होना चाहिए';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // 3. Email Address
                            const Text(
                              'ईमेल पता (Email Address) *',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              enabled: !isLoading,
                              decoration: _inputDecoration(
                                hint: 'उदा. rahul@gmail.com',
                                prefixIcon: Icons.email_outlined,
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'कृपया अपना ईमेल पता दर्ज करें';
                                }
                                final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                                if (!regex.hasMatch(val.trim())) {
                                  return 'कृपया सही ईमेल पता दर्ज करें';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // 4. Password
                            const Text(
                              'पासवर्ड (Password) *',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              enabled: !isLoading,
                              decoration: _inputDecoration(
                                hint: 'कम से कम 6 अक्षर का पासवर्ड',
                                prefixIcon: Icons.lock_outline_rounded,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    color: Colors.grey.shade600,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'कृपया पासवर्ड दर्ज करें';
                                }
                                if (val.trim().length < 6) {
                                  return 'पासवर्ड कम से कम 6 अक्षरों का होना चाहिए';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // 5. Confirm Password
                            const Text(
                              'पासवर्ड की पुष्टि (Confirm Password) *',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              enabled: !isLoading,
                              decoration: _inputDecoration(
                                hint: 'पासवर्ड दोबारा लिखें',
                                prefixIcon: Icons.lock_clock_outlined,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    color: Colors.grey.shade600,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'कृपया पासवर्ड की पुष्टि करें';
                                }
                                if (val.trim() != _passwordController.text.trim()) {
                                  return 'दोनों पासवर्ड मैच नहीं कर रहे हैं';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // ──────────────────────────────────────────────
                            // 6. REAL MAP & GPS LOCATION ACTION BAR (NO HARDCODING)
                            // ──────────────────────────────────────────────
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F7F4),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.map_rounded, color: AppColors.primary, size: 20),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Text(
                                          'मैप से लाइव लोकेशन फेच करें',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                                        ),
                                      ),
                                      if (_isDetectingLocation)
                                        const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _selectedLocation != null
                                        ? '📍 मैप द्वारा चुना गया: ${_selectedLocation!.placeName} (Lat: ${_selectedLocation!.latitude.toStringAsFixed(3)}, Lng: ${_selectedLocation!.longitude.toStringAsFixed(3)})'
                                        : 'ब्लॉक / इलाका और पूरा पता गूगल मैप से स्वतः भरें',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: _selectedLocation != null ? FontWeight.w600 : FontWeight.normal,
                                      color: _selectedLocation != null ? const Color(0xFF0F8A6D) : Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: isLoading ? null : _openMapPicker,
                                          icon: const Icon(Icons.location_on, size: 16),
                                          label: const Text('मैप पर चुनें', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF1A73E8), // Google Blue
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            padding: const EdgeInsets.symmetric(vertical: 9),
                                            elevation: 1,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: isLoading || _isDetectingLocation ? null : _autoDetectGpsLocation,
                                          icon: const Icon(Icons.my_location_rounded, size: 16),
                                          label: const Text('GPS ऑटो', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.primary,
                                            side: const BorderSide(color: AppColors.primary, width: 1.2),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            padding: const EdgeInsets.symmetric(vertical: 9),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 7. Area / Block field (Fetched from Map, NOT hardcoded)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'क्षेत्र / ब्लॉक (Area / Block from Map) *',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                                if (_selectedLocation != null)
                                  const Text(
                                    '✓ मैप से फेच हुआ',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F8A6D)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _areaController,
                              enabled: !isLoading,
                              decoration: InputDecoration(
                                hintText: _isDetectingLocation ? 'GPS से खोजा जा रहा है...' : 'उदा. गिद्धौर, झाझा, जमुई शहर',
                                hintStyle: TextStyle(fontSize: 13.5, color: Colors.grey.shade400),
                                prefixIcon: const Icon(Icons.location_city_rounded, color: AppColors.primary, size: 20),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.map_outlined, color: Color(0xFF1A73E8)),
                                  tooltip: 'गूगल मैप पर चुनें',
                                  onPressed: _openMapPicker,
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF9FBFA),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: _locationError != null ? AppColors.error : Colors.grey.shade300,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'कृपया ऊपर मैप बटन से अपना ब्लॉक / इलाका चुनें';
                                }
                                return null;
                              },
                            ),
                            if (_locationError != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                _locationError!,
                                style: const TextStyle(fontSize: 11.5, color: AppColors.error, fontWeight: FontWeight.w500),
                              ),
                            ],
                            const SizedBox(height: 16),

                            // 8. Full Address / Landmark (Fetched from Map)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'घर का पता / लैंडमार्क (Address from Map) *',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                                Text(
                                  'मैप से स्वतः भरा हुआ',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _addressController,
                              maxLines: 2,
                              enabled: !isLoading,
                              decoration: _inputDecoration(
                                hint: 'उदा. स्टेशन रोड, वार्ड नं. 4, जमुई',
                                prefixIcon: Icons.home_outlined,
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.gps_fixed, color: AppColors.primary, size: 20),
                                  tooltip: 'GPS रिफ्रेश करें',
                                  onPressed: _autoDetectGpsLocation,
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'कृपया घर का पता / लैंडमार्क दर्ज करें';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),

                            // Register Button
                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: isLoading ? null : _onRegisterSubmit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 2,
                                ),
                                child: isLoading
                                    ? Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            loadingMessage ?? 'कृपया प्रतीक्षा करें...',
                                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      )
                                    : const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.person_add_alt_1_rounded, size: 20),
                                          SizedBox(width: 8),
                                          Text(
                                            'खाता बनाएं (Register)',
                                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Already have account? Login link
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'पहले से खाता मौजूद है? ',
                                  style: TextStyle(fontSize: 13.5, color: Colors.grey.shade700),
                                ),
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: const Text(
                                    'लॉगिन करें',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13.5, color: Colors.grey.shade400),
      prefixIcon: Icon(prefixIcon, color: AppColors.primary, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF9FBFA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
    );
  }
}
