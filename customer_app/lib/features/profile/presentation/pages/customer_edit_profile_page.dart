import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/location_service.dart';
import '../../../auth/domain/entities/customer_entity.dart';
import '../../../auth/presentation/bloc/customer_auth_bloc.dart';
import '../../../auth/presentation/bloc/customer_auth_event.dart';
import '../../../discovery/presentation/bloc/discovery_bloc.dart';
import '../../../discovery/presentation/bloc/discovery_event.dart';
import '../../../location/domain/entities/customer_location_entity.dart';
import '../../../location/presentation/bloc/location_bloc.dart';
import '../../../location/presentation/bloc/location_event.dart';
import '../../../location/presentation/pages/location_picker_screen.dart';

class CustomerEditProfilePage extends StatefulWidget {
  final CustomerEntity customer;

  const CustomerEditProfilePage({
    super.key,
    required this.customer,
  });

  @override
  State<CustomerEditProfilePage> createState() => _CustomerEditProfilePageState();
}

class _CustomerEditProfilePageState extends State<CustomerEditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  String _selectedJamuiArea = 'जमुई शहर';
  double? _latitude;
  double? _longitude;

  bool _isSaving = false;
  bool _isFetchingGps = false;

  static const List<String> _jamuiAreas = [
    'जमुई शहर',
    'गिद्धौर',
    'झाझा',
    'सोनो',
    'चकाई',
    'बरहट',
    'खैरा',
    'सिकंदरा',
    'अलीगंज',
    'लक्ष्मीपुर',
    'इस्लाम नगर',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.customer.fullName);
    String rawPhone = widget.customer.phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (rawPhone.startsWith('+91')) {
      rawPhone = rawPhone.substring(3);
    }
    _phoneController = TextEditingController(text: rawPhone);
    _emailController = TextEditingController(text: widget.customer.email ?? '');
    _addressController = TextEditingController(text: widget.customer.address);
    _latitude = widget.customer.latitude;
    _longitude = widget.customer.longitude;

    if (widget.customer.jamuiArea.isNotEmpty && _jamuiAreas.contains(widget.customer.jamuiArea)) {
      _selectedJamuiArea = widget.customer.jamuiArea;
    } else if (widget.customer.jamuiArea.isNotEmpty) {
      _selectedJamuiArea = widget.customer.jamuiArea;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    final nameChanged = _nameController.text.trim() != widget.customer.fullName.trim();
    String rawExisting = widget.customer.phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (rawExisting.startsWith('+91')) rawExisting = rawExisting.substring(3);
    final phoneChanged = _phoneController.text.trim() != rawExisting;
    final currentEmail = (widget.customer.email ?? '').trim();
    final newEmail = _emailController.text.trim();
    final emailChanged = currentEmail != newEmail;
    final areaChanged = _selectedJamuiArea != widget.customer.jamuiArea;
    final addressChanged = _addressController.text.trim() != widget.customer.address.trim();
    final coordsChanged = _latitude != widget.customer.latitude || _longitude != widget.customer.longitude;

    return nameChanged || phoneChanged || emailChanged || areaChanged || addressChanged || coordsChanged;
  }

  /// Opens the interactive Google Map Location Picker
  Future<void> _openMapLocationPicker() async {
    final result = await Navigator.push<CustomerLocationEntity>(
      context,
      MaterialPageRoute(
        builder: (_) => const LocationPickerScreen(isFromOnboarding: false),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _latitude = result.latitude;
        _longitude = result.longitude;
        if (result.placeName.isNotEmpty) {
          _selectedJamuiArea = result.placeName;
        }
        final cityOrDistrict = result.city.isNotEmpty ? result.city : (result.district.isNotEmpty ? result.district : '');
        _addressController.text = result.formattedAddress.isNotEmpty
            ? result.formattedAddress
            : (result.placeName.isNotEmpty && cityOrDistrict.isNotEmpty
                ? '${result.placeName}, $cityOrDistrict'
                : 'Lat: ${result.latitude.toStringAsFixed(5)}, Lng: ${result.longitude.toStringAsFixed(5)}');
      });

      // Update LocationBloc and DiscoveryBloc
      context.read<LocationBloc>().add(ConfirmSelectedLocationEvent(result));
      context.read<DiscoveryBloc>().add(UpdateCustomerLocationEvent(
            latitude: result.latitude,
            longitude: result.longitude,
            areaName: '${result.placeName} (${result.pincode})',
          ));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(child: Text('नक्शे से स्थान सफलतापूर्वक चुना गया! 📍')),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Quick action: fetch device GPS location directly
  Future<void> _fetchDeviceGpsLocation() async {
    setState(() => _isFetchingGps = true);

    try {
      final loc = await LocationService.fetchCurrentLocation();
      if (!mounted) return;

      final place = loc.jamuiArea.isNotEmpty ? loc.jamuiArea : '';
      final fullAddr = loc.fullAddress.isNotEmpty
          ? loc.fullAddress
          : (place.isNotEmpty ? place : 'GPS: ${loc.latitude.toStringAsFixed(6)}, ${loc.longitude.toStringAsFixed(6)}');

      setState(() {
        _latitude = loc.latitude;
        _longitude = loc.longitude;
        if (place.isNotEmpty) {
          _selectedJamuiArea = place;
        }
        _addressController.text = fullAddr;
        _isFetchingGps = false;
      });

      final locationEntity = CustomerLocationEntity(
        latitude: loc.latitude,
        longitude: loc.longitude,
        placeName: place.isNotEmpty ? place : 'वर्तमान स्थान',
        formattedAddress: fullAddr,
        city: loc.city,
        district: loc.district,
        state: loc.state,
        pincode: loc.pincode,
        timestamp: DateTime.now(),
      );

      context.read<LocationBloc>().add(ConfirmSelectedLocationEvent(locationEntity));
      context.read<DiscoveryBloc>().add(UpdateCustomerLocationEvent(
            latitude: loc.latitude,
            longitude: loc.longitude,
            areaName: place.isNotEmpty
                ? '$place (${loc.pincode.isNotEmpty ? loc.pincode : 'GPS'})'
                : 'GPS (${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)})',
          ));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('वर्तमान GPS स्थान लोड हो गया! 🛰️'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isFetchingGps = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('GPS लोकेशन प्राप्त करने में विफल: $e. कृपया नक्शे से स्थान चुनें।'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'नक्शा खोलें',
              textColor: Colors.white,
              onPressed: _openMapLocationPicker,
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleSave() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_hasChanges) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('प्रोफ़ाइल में कोई बदलाव नहीं हुआ है।'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final newName = _nameController.text.trim();
      final rawEntered = _phoneController.text.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
      final finalPhone = rawEntered.startsWith('+91')
          ? rawEntered
          : (rawEntered.isNotEmpty ? '+91$rawEntered' : widget.customer.phoneNumber);
      final newEmailText = _emailController.text.trim();
      final newEmail = newEmailText.isNotEmpty ? newEmailText : null;
      final newAddress = _addressController.text.trim();

      final updatedCustomer = CustomerEntity(
        id: widget.customer.id,
        phoneNumber: finalPhone,
        fullName: newName,
        email: newEmail,
        jamuiArea: _selectedJamuiArea,
        address: newAddress,
        latitude: _latitude,
        longitude: _longitude,
        createdAt: widget.customer.createdAt,
        updatedAt: DateTime.now(),
      );

      // Save via CustomerAuthBloc
      context.read<CustomerAuthBloc>().add(SaveCustomerProfileEvent(updatedCustomer));

      // Also update Firebase Auth displayName for synchronized greetings
      try {
        final currentFirebaseUser = FirebaseAuth.instance.currentUser;
        if (currentFirebaseUser != null && newName.isNotEmpty) {
          await currentFirebaseUser.updateDisplayName(newName);
        }
      } catch (_) {}

      if (!mounted) return;

      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('आपकी प्रोफ़ाइल सफलतापूर्वक अपडेट हो गई! ✅', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      Navigator.pop(context, updatedCustomer);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('प्रोफ़ाइल अपडेट करने में समस्या हुई: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'पुनः प्रयास',
            textColor: Colors.white,
            onPressed: _handleSave,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'प्रोफ़ाइल संपादित करें',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Avatar Indicator
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 46,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                        child: Text(
                          _nameController.text.trim().isNotEmpty
                              ? _nameController.text.trim()[0].toUpperCase()
                              : 'C',
                          style: const TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
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
                          child: const Icon(Icons.edit, size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Personal Info Card
                Container(
                  padding: const EdgeInsets.all(20),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Full Name
                      const Text(
                        'ग्राहक का पूरा नाम (Full Name) *',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'उदा. राहुल कुमार',
                          prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.primary),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'कृपया अपना पूरा नाम दर्ज करें';
                          }
                          if (value.trim().length < 2) {
                            return 'नाम कम से कम 2 अक्षरों का होना चाहिए';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),

                      // Email Address (Optional / Add Email)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'ईमेल आईडी (Email ID)',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          Text(
                            '(वैकल्पिक / Optional)',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'उदा. rahul@example.com',
                          prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primary),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
                          ),
                        ),
                        validator: (value) {
                          if (value != null && value.trim().isNotEmpty) {
                            final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                            if (!regex.hasMatch(value.trim())) {
                              return 'कृपया सही ईमेल पता दर्ज करें';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),

                      // Mobile Number (Editable with validation)
                      const Text(
                        'मोबाइल नंबर (Mobile Number) *',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration: InputDecoration(
                          hintText: '10 अंकों का मोबाइल नंबर',
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
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'कृपया मोबाइल नंबर दर्ज करें';
                          }
                          final clean = value.replaceAll(RegExp(r'[\s\-\(\)]'), '').trim();
                          if (clean.length != 10) {
                            return 'मान्य 10 अंकों का मोबाइल नंबर लिखें';
                          }
                          if (!RegExp(r'^[6-9]\d{9}$').hasMatch(clean)) {
                            return 'मोबाइल नंबर 6, 7, 8 या 9 से शुरू होना चाहिए';
                          }
                          return null;
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 6, left: 4),
                        child: Text(
                          '📞 बुकिंग के समय कारीगर आपसे संपर्क करने के लिए इसी नंबर का उपयोग करेंगे।',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Interactive Map-Based Location Card
                Container(
                  padding: const EdgeInsets.all(20),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.map_rounded, color: AppColors.primary, size: 22),
                              SizedBox(width: 8),
                              Text(
                                'सेवा स्थान (Service Location)',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                          if (_latitude != null && _longitude != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F0FE),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF1A73E8).withValues(alpha: 0.3)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.gps_fixed, size: 12, color: Color(0xFF1A73E8)),
                                  SizedBox(width: 4),
                                  Text(
                                    'GPS Verified',
                                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF1A73E8)),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Interactive Map Picker Trigger Button
                      InkWell(
                        onTap: _openMapLocationPicker,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF1A73E8).withValues(alpha: 0.08),
                                const Color(0xFF1A73E8).withValues(alpha: 0.03),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF1A73E8).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1A73E8),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.add_location_alt_rounded, color: Colors.white, size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _latitude != null
                                          ? 'नक्शे पर स्थान बदलें (Change on Map)'
                                          : 'नक्शे पर स्थान चुनें (Pick on Map)',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1A73E8),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    const Text(
                                      'Google Maps से अपना सटीक घर / दुकान का पता चुनें',
                                      style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF1A73E8)),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Quick GPS Fetch Action
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _isFetchingGps ? null : _fetchDeviceGpsLocation,
                          icon: _isFetchingGps
                              ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.my_location_rounded, size: 16, color: AppColors.primary),
                          label: Text(
                            _isFetchingGps ? 'GPS से खोजा जा रहा है...' : 'वर्तमान GPS स्थान प्राप्त करें',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ),
                      ),

                      const Divider(height: 20),

                      // Selected Jamui Area Display / Selector
                      const Text(
                        'इलाका / ब्लॉक (Jamui Area) *',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _jamuiAreas.contains(_selectedJamuiArea) ? _selectedJamuiArea : _jamuiAreas.first,
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
                            items: _jamuiAreas.map((area) {
                              return DropdownMenuItem<String>(
                                value: area,
                                child: Row(
                                  children: [
                                    const Icon(Icons.location_on_outlined, size: 18, color: AppColors.primary),
                                    const SizedBox(width: 8),
                                    Text(
                                      area,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedJamuiArea = val);
                              }
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Full Detailed Address (Filled automatically from Map or editable)
                      const Text(
                        'पूरा पता / लैंडमार्क (Full Address from Map) *',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _addressController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'नक्शे से चुना गया पता या मकान संख्या/लैंडमार्क दर्ज करें',
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(bottom: 24),
                            child: Icon(Icons.home_outlined, color: AppColors.primary),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'कृपया सेवा का पता दर्ज करें';
                          }
                          return null;
                        },
                      ),

                      if (_latitude != null && _longitude != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.pin_drop_outlined, size: 14, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Text(
                                'Lat: ${_latitude!.toStringAsFixed(5)}, Lng: ${_longitude!.toStringAsFixed(5)}',
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Save Changes Button
                ElevatedButton(
                  onPressed: _isSaving ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 1,
                  ),
                  child: _isSaving
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'सहेजा जा रहा है...',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        )
                      : const Text(
                          'बदलाव सहेजें (Save Changes)',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
