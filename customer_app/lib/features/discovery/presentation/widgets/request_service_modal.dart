import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/bloc/customer_auth_bloc.dart';
import '../../../auth/presentation/bloc/customer_auth_state.dart';
import '../../../location/domain/entities/customer_location_entity.dart';
import '../../../location/presentation/bloc/location_bloc.dart';
import '../../../location/presentation/bloc/location_state.dart';
import '../../../location/presentation/pages/location_picker_screen.dart';
import '../../domain/entities/service_provider_entity.dart';

class RequestServiceModal extends StatefulWidget {
  final ServiceProviderEntity provider;

  const RequestServiceModal({super.key, required this.provider});

  static void show(BuildContext context, ServiceProviderEntity provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => RequestServiceModal(provider: provider),
    );
  }

  @override
  State<RequestServiceModal> createState() => _RequestServiceModalState();
}

class _RequestServiceModalState extends State<RequestServiceModal> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String _selectedTimeSlot = '10:00 AM - 01:00 PM';
  bool _isSubmitting = false;
  bool _isLoadingCustomerData = true;

  // Authenticated customer details
  String _customerName = 'ग्राहक';
  String _verifiedPhone = '';
  String _selectedArea = 'जमुई';
  String _selectedAddress = '';
  double? _latitude;
  double? _longitude;

  final List<String> _timeSlots = [
    '08:00 AM - 10:00 AM',
    '10:00 AM - 01:00 PM',
    '01:00 PM - 04:00 PM',
    '04:00 PM - 07:00 PM',
  ];

  @override
  void initState() {
    super.initState();
    _loadCustomerProfileAndLocation();
  }

  @override
  void dispose() {
    _descController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomerProfileAndLocation() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) setState(() => _isLoadingCustomerData = false);
      return;
    }

    String phone = currentUser.phoneNumber ?? '';
    String name = currentUser.displayName ?? '';
    String area = 'जमुई';
    String address = '';
    double? lat;
    double? lng;

    // Check CustomerAuthBloc state if available
    final authState = context.read<CustomerAuthBloc>().state;
    if (authState is CustomerAuthenticatedState) {
      final cust = authState.customer;
      if (cust.fullName.isNotEmpty) name = cust.fullName;
      if (phone.isEmpty && cust.phoneNumber.isNotEmpty) phone = cust.phoneNumber;
      if (cust.jamuiArea.isNotEmpty) area = cust.jamuiArea;
      if (cust.address.isNotEmpty) address = cust.address;
      lat = cust.latitude;
      lng = cust.longitude;
    }

    // Always fetch latest record from Firestore users/{uid} for freshest profile
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data()!;
        final dbName = data['fullName'] as String?;
        if (dbName != null && dbName.isNotEmpty) name = dbName;

        final dbPhone = data['phoneNumber'] as String?;
        // Priority to Firebase Auth verified phone, fallback to dbPhone
        if (phone.isEmpty && dbPhone != null && dbPhone.isNotEmpty) {
          phone = dbPhone;
        }

        final dbArea = data['jamuiArea'] as String?;
        if (dbArea != null && dbArea.isNotEmpty) area = dbArea;

        final dbAddress = (data['formattedAddress'] as String?) ?? (data['address'] as String?);
        if (dbAddress != null && dbAddress.isNotEmpty) address = dbAddress;

        if (lat == null && data['latitude'] is num) {
          lat = (data['latitude'] as num).toDouble();
        }
        if (lng == null && data['longitude'] is num) {
          lng = (data['longitude'] as num).toDouble();
        }
      }
    } catch (_) {}

    // Fallback location from LocationBloc if address is still empty
    if (mounted && (address.isEmpty || lat == null)) {
      try {
        final locationState = context.read<LocationBloc>().state;
        if (locationState is LocationLoaded) {
          if (area.isEmpty || area == 'जमुई') {
            area = locationState.location.placeName;
          }
          if (address.isEmpty) {
            address = locationState.location.formattedAddress;
          }
          lat ??= locationState.location.latitude;
          lng ??= locationState.location.longitude;
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _customerName = name.isNotEmpty ? name : 'ग्राहक';
        _verifiedPhone = phone;
        _selectedArea = area.isNotEmpty ? area : 'जमुई शहर';
        _selectedAddress = address;
        _latitude = lat;
        _longitude = lng;
        _isLoadingCustomerData = false;
      });
    }
  }

  /// Opens the interactive Google Map Location Picker for booking-specific location
  Future<void> _pickLocationOnMap() async {
    final result = await Navigator.push<CustomerLocationEntity>(
      context,
      MaterialPageRoute(
        builder: (_) => const LocationPickerScreen(isFromOnboarding: false),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        final cityOrDistrict = result.city.isNotEmpty ? result.city : (result.district.isNotEmpty ? result.district : '');
        _selectedArea = result.placeName.isNotEmpty
            ? result.placeName
            : (cityOrDistrict.isNotEmpty ? cityOrDistrict : 'GPS Location');
        _selectedAddress = result.formattedAddress.isNotEmpty
            ? result.formattedAddress
            : (result.placeName.isNotEmpty && cityOrDistrict.isNotEmpty
                ? '${result.placeName}, $cityOrDistrict'
                : 'Lat: ${result.latitude.toStringAsFixed(5)}, Lng: ${result.longitude.toStringAsFixed(5)}');
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(child: Text('सेवा स्थल का स्थान मैप से सेट हो गया! 📍')),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<bool> _promptCompleteProfileDialog(
    BuildContext context,
    String currentName,
    String currentPhone,
    String currentAddress,
  ) async {
    final nameCtrl = TextEditingController(text: currentName == 'ग्राहक' ? '' : currentName);
    final cleanCurrent = currentPhone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    final rawPhone = cleanCurrent.startsWith('+91') ? cleanCurrent.substring(3) : cleanCurrent;
    final phoneCtrl = TextEditingController(text: rawPhone);
    final addrCtrl = TextEditingController(text: currentAddress);
    final dialogFormKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.contact_phone_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('संपर्क विवरण भरें', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Form(
          key: dialogFormKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'कारीगर को आपसे संपर्क करने और सेवा स्थल तक पहुँचने के लिए आपका नाम, मोबाइल और पता आवश्यक है।',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 14),
                const Text('पूरा नाम (Full Name) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextFormField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    hintText: 'उदा. राहुल कुमार',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'कृपया अपना नाम लिखें' : null,
                ),
                const SizedBox(height: 12),
                const Text('मोबाइल नंबर (Mobile Number) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: InputDecoration(
                    prefixText: '+91 ',
                    hintText: '10 अंकों का नंबर',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().length != 10) return 'मान्य 10 अंकों का मोबाइल नंबर लिखें';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                const Text('सेवा का पता (Service Address) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextFormField(
                  controller: addrCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'उदा. वार्ड नं. 4, स्टेशन रोड, जमुई',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'कृपया सेवा का पता लिखें' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('रद्द करें', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (dialogFormKey.currentState?.validate() ?? false) {
                final user = FirebaseAuth.instance.currentUser;
                final cleanPhone = '+91${phoneCtrl.text.trim()}';
                final newName = nameCtrl.text.trim();
                final newAddr = addrCtrl.text.trim();

                if (user != null) {
                  try {
                    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                      'fullName': newName,
                      'name': newName,
                      'phoneNumber': cleanPhone,
                      'phone': cleanPhone,
                      'address': newAddr,
                      'formattedAddress': newAddr,
                      'updatedAt': FieldValue.serverTimestamp(),
                    }, SetOptions(merge: true));
                  } catch (_) {}
                }

                setState(() {
                  _customerName = newName;
                  _verifiedPhone = cleanPhone;
                  _selectedAddress = newAddr;
                });

                if (ctx.mounted) {
                  Navigator.pop(ctx, true);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('सुरक्षित करें और जारी रखें'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _submitRequest() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('सेवा अनुरोध के लिए कृपया पहले लॉगिन करें।'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // If mobile number or address is missing, prompt to complete profile inline!
    if (_verifiedPhone.trim().isEmpty || _selectedAddress.trim().isEmpty) {
      final completed = await _promptCompleteProfileDialog(
        context,
        _customerName,
        _verifiedPhone,
        _selectedAddress,
      );
      if (!completed || !mounted) return;
    }


    final verifiedPhone = _verifiedPhone.trim();
    if (verifiedPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('सेवा बुक करने के लिए मोबाइल नंबर आवश्यक है।'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedAddress.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('कृपया सेवा स्थल का पता दर्ज करें।'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final landmark = _landmarkController.text.trim();
      final fullAddress = landmark.isNotEmpty
          ? '$landmark, $_selectedAddress'
          : _selectedAddress;

      final leadRef = FirebaseFirestore.instance.collection('leads').doc();
      await leadRef.set({
        'leadId': leadRef.id,
        'customerId': currentUser.uid,
        'customerName': _customerName,
        'customerPhone': verifiedPhone, // Strictly authenticated verified number
        'customerArea': _selectedArea,
        'customerAddress': fullAddress,
        'address': fullAddress, // Used by provider_app LeadModel
        'latitude': _latitude ?? 0.0,
        'longitude': _longitude ?? 0.0,
        'customerLatitude': _latitude ?? 0.0,
        'customerLongitude': _longitude ?? 0.0,
        'providerId': widget.provider.id,
        'providerName': widget.provider.fullName,
        'businessName': widget.provider.businessName,
        'categoryId': widget.provider.categoryId,
        'categoryTitle': widget.provider.categoryTitle,
        'serviceName': '${widget.provider.categoryTitle} सेवा',
        'visitingCharge': widget.provider.visitingCharge,
        'description': _descController.text.trim(),
        'preferredDate': _selectedDate.toIso8601String(),
        'preferredTimeSlot': _selectedTimeSlot,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Dispatch real-time in-app notification to the service provider
      try {
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': widget.provider.id,
          'title': 'नया सेवा अनुरोध! 🔔',
          'message': '$_customerName ने ${widget.provider.categoryTitle} सेवा के लिए अनुरोध भेजा है।',
          'type': 'new_lead',
          'leadId': leadRef.id,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${widget.provider.fullName} को सेवा का अनुरोध भेज दिया गया है! 🟢'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('अनुरोध भेजने में त्रुटि: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'सेवा अनुरोध: ${widget.provider.fullName}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'श्रेणी: ${widget.provider.categoryTitle} • विजिट चार्ज: ₹${widget.provider.visitingCharge.toInt()}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 20),

              if (_isLoadingCustomerData)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
                // 1. Verified Customer Phone Card (Read-only security badge)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _verifiedPhone.isNotEmpty
                        ? Colors.green.shade50
                        : Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _verifiedPhone.isNotEmpty
                          ? Colors.green.shade200
                          : Colors.amber.shade300,
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _verifiedPhone.isNotEmpty
                              ? Colors.green.shade100
                              : Colors.amber.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _verifiedPhone.isNotEmpty
                              ? Icons.verified_user_rounded
                              : Icons.warning_amber_rounded,
                          color: _verifiedPhone.isNotEmpty
                              ? Colors.green.shade800
                              : Colors.amber.shade900,
                          size: 20,
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
                                  _verifiedPhone.isNotEmpty
                                      ? 'सत्यापित संपर्क नंबर'
                                      : 'सत्यापित नंबर अनुपलब्ध',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: _verifiedPhone.isNotEmpty
                                        ? Colors.green.shade900
                                        : Colors.amber.shade900,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                if (_verifiedPhone.isNotEmpty)
                                  const Icon(Icons.lock_rounded, size: 12, color: Colors.green),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _verifiedPhone.isNotEmpty
                                  ? _verifiedPhone
                                  : 'सेवा बुक करने के लिए वैध मोबाइल नंबर आवश्यक है',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _verifiedPhone.isNotEmpty
                                    ? Colors.black87
                                    : Colors.red.shade800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _verifiedPhone.isNotEmpty
                                  ? 'यह नंबर कारीगर (${widget.provider.fullName}) को सेवा संपर्क हेतु भेजा जाएगा।'
                                  : 'कृपया लॉगिन करके अपना नंबर सत्यापित करें।',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: _verifiedPhone.isNotEmpty
                                    ? Colors.green.shade800
                                    : Colors.amber.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 2. Service Address Card with Map Picker Button
                Container(
                  width: double.infinity,
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
                          const Row(
                            children: [
                              Icon(Icons.location_on, color: AppColors.primary, size: 18),
                              SizedBox(width: 6),
                              Text(
                                'सेवा स्थल का पता (Service Location)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          OutlinedButton.icon(
                            onPressed: _pickLocationOnMap,
                            icon: const Icon(Icons.map_rounded, size: 14, color: AppColors.primary),
                            label: const Text(
                              'नक्शे पर बदलें',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.primary),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _selectedArea,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                if (_latitude != null && _longitude != null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    'GPS: ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}',
                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _selectedAddress.isNotEmpty
                                  ? _selectedAddress
                                  : 'पता लोड नहीं हुआ है। कृपया "नक्शे पर बदलें" पर टैप करें।',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: _selectedAddress.isNotEmpty
                                    ? AppColors.textPrimary
                                    : Colors.orange.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Optional house no / landmark
                      TextFormField(
                        controller: _landmarkController,
                        style: const TextStyle(fontSize: 12.5),
                        decoration: InputDecoration(
                          hintText: 'घर/फ्लैट संख्या, लैंडमार्क (वैकल्पिक)',
                          prefixIcon: const Icon(Icons.home_outlined, size: 16),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 3. Work Description
                TextFormField(
                  controller: _descController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'काम का विवरण (Work Description) *',
                    hintText: 'उदाहरण: AC कूलिंग नहीं कर रहा / स्विच बोर्ड स्पार्क हो रहा है...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'कृपया अपने काम का विवरण लिखें' : null,
                ),
                const SizedBox(height: 14),

                // 4. Preferred Date & Time Slot
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 30)),
                          );
                          if (date != null) setState(() => _selectedDate = date);
                        },
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(
                          '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedTimeSlot,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: _timeSlots
                            .map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(s, style: const TextStyle(fontSize: 11)),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedTimeSlot = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 5. Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSubmitting || _verifiedPhone.trim().isEmpty
                        ? null
                        : _submitRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSubmitting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'अनुरोध भेजें (Submit Lead)',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
