import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../../location/data/datasources/location_remote_data_source.dart';
import '../bloc/provider_auth_bloc.dart';
import '../bloc/provider_auth_event.dart';

/// Screen 3 & 4: Profile Details & Location Confirmation Screen
/// Strictly matches Screen 3 and Screen 4 in the Reference Image:
/// - Step 1: Set Up Shop Profile (Shop Name, Logo, Cover, Description, Address, PIN, City)
/// - Step 2: Confirm Shop Location (Detect Location, Map Preview, Lat/Long, Address Confirmation)
/// - Submits to providers/{uid} and diamond_shops/{uid}
/// - 100% English UI
class ProviderProfileSetupPage extends StatefulWidget {
  final String providerUid;
  final String categoryId;
  final String categoryTitle;
  final String categoryType;
  final List<String> subServices;

  const ProviderProfileSetupPage({
    super.key,
    required this.providerUid,
    required this.categoryId,
    required this.categoryTitle,
    required this.categoryType,
    required this.subServices,
  });

  @override
  State<ProviderProfileSetupPage> createState() => _ProviderProfileSetupPageState();
}

class _ProviderProfileSetupPageState extends State<ProviderProfileSetupPage> {
  static const Color _themeGreen = Color(0xFF1B5E20);

  // Sub-step: 1 = Shop Details, 2 = Location Details
  int _subStep = 1;
  bool _isSubmitting = false;
  bool _isDetectingGps = false;

  // Owner contact details (synced from providers/{uid} / auth)
  String _ownerName = '';
  String _ownerPhone = '';
  String _ownerEmail = '';

  // Shop Details Form
  final _profileFormKey = GlobalKey<FormState>();
  late TextEditingController _shopNameController;
  final _shopDescController = TextEditingController();
  final _shopAddressController = TextEditingController();
  final _cityController = TextEditingController(text: 'Jamui');
  final _districtController = TextEditingController(text: 'Jamui');
  final _pinCodeController = TextEditingController(text: '811307');
  String _logoUrl = '';
  String _coverUrl = '';

  // Location Details
  double _latitude = 24.9273;
  double _longitude = 86.2238;
  String _selectedAddress = 'Main Bazaar, Jamui, Bihar 811307';
  final MapController _mapController = MapController();
  final LocationRemoteDataSource _locationDataSource = LocationRemoteDataSourceImpl();

  @override
  void initState() {
    super.initState();
    _shopNameController = TextEditingController(
      text: widget.categoryTitle.isNotEmpty ? '${widget.categoryTitle} Jamui' : '',
    );
    _loadExistingDraft();
  }

  Future<void> _loadExistingDraft() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('providers').doc(widget.providerUid).get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        _ownerName = (data['fullName'] as String?)?.trim() ??
            (data['name'] as String?)?.trim() ??
            (data['ownerName'] as String?)?.trim() ??
            '';
        _ownerPhone = (data['phone'] as String?)?.trim() ??
            (data['mobile'] as String?)?.trim() ??
            (data['ownerPhone'] as String?)?.trim() ??
            '';
        _ownerEmail = (data['email'] as String?)?.trim() ??
            (data['ownerEmail'] as String?)?.trim() ??
            '';

        if ((data['businessName'] as String?)?.isNotEmpty ?? false) {
          _shopNameController.text = data['businessName'] as String;
        }
        if ((data['businessDescription'] as String?)?.isNotEmpty ?? false) {
          _shopDescController.text = data['businessDescription'] as String;
        }
        if ((data['fullAddress'] as String?)?.isNotEmpty ?? false) {
          _shopAddressController.text = data['fullAddress'] as String;
        }
        if (data['latitude'] != null && (data['latitude'] as num) != 0) {
          _latitude = (data['latitude'] as num).toDouble();
        }
        if (data['longitude'] != null && (data['longitude'] as num) != 0) {
          _longitude = (data['longitude'] as num).toDouble();
        }
      }

      // Check current FirebaseAuth user for contact fallbacks
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser != null) {
        if (_ownerPhone.isEmpty && (authUser.phoneNumber?.trim().isNotEmpty ?? false)) {
          _ownerPhone = authUser.phoneNumber!.trim();
        }
        if (_ownerEmail.isEmpty && (authUser.email?.trim().isNotEmpty ?? false)) {
          _ownerEmail = authUser.email!.trim();
        }
        if (_ownerName.isEmpty && (authUser.displayName?.trim().isNotEmpty ?? false)) {
          _ownerName = authUser.displayName!.trim();
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _shopDescController.dispose();
    _shopAddressController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _pinCodeController.dispose();
    super.dispose();
  }

  void _handleNextToLocation() {
    if (_profileFormKey.currentState?.validate() ?? false) {
      setState(() => _subStep = 2);
    }
  }

  Future<void> _detectCurrentLocation() async {
    setState(() => _isDetectingGps = true);
    try {
      final loc = await _locationDataSource.getCurrentPosition();
      final geocoded = await _locationDataSource.reverseGeocode(loc.latitude, loc.longitude);
      if (mounted) {
        setState(() {
          _latitude = loc.latitude;
          _longitude = loc.longitude;
          _selectedAddress = geocoded.formattedAddress.isNotEmpty
              ? geocoded.formattedAddress
              : '${geocoded.placeName}, Jamui';
          _isDetectingGps = false;
        });
        try {
          _mapController.move(LatLng(_latitude, _longitude), 16.0);
        } catch (_) {}
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDetectingGps = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not detect GPS location: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _submitRegistration() async {
    setState(() => _isSubmitting = true);
    try {
      final shopName = _shopNameController.text.trim();
      final shopDesc = _shopDescController.text.trim();
      final shopAddress = _shopAddressController.text.trim();
      final city = _cityController.text.trim();
      final district = _districtController.text.trim();
      final pinCode = _pinCodeController.text.trim();
      final fullAddr = '$shopAddress, $city, $district - $pinCode';

      // 1. Update providers/{uid} document with completed registration
      await FirebaseFirestore.instance.collection('providers').doc(widget.providerUid).set({
        'businessName': shopName,
        'businessDescription': shopDesc,
        'primaryCategoryId': widget.categoryId,
        'primaryCategoryTitle': widget.categoryTitle,
        'categoryType': widget.categoryType,
        'isPremiumCategory': widget.categoryType == 'premium',
        'isDiamond': widget.categoryType == 'diamond' || widget.categoryType == 'professional',
        'isProfessional': widget.categoryType == 'diamond' || widget.categoryType == 'professional',
        'businessType': (widget.categoryType == 'diamond' || widget.categoryType == 'professional')
            ? 'professional_seller'
            : 'service_provider',
        'subServices': widget.subServices,
        'selectedService': widget.subServices.isNotEmpty ? widget.subServices.first : widget.categoryTitle,
        'fullAddress': fullAddr,
        'jamuiArea': city.isNotEmpty ? city : 'Jamui',
        'city': city,
        'district': district,
        'pincode': pinCode,
        'latitude': _latitude,
        'longitude': _longitude,
        'status': 'pendingReview',
        'kycStatus': 'pendingReview',
        'registrationStatus': 'completed',
        'completedSteps': [0, 1, 2, 3],
        'currentStep': 3,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 2. If Diamond or Professional category, create/update diamond_shops/{uid} document
      if (widget.categoryType == 'diamond' || widget.categoryType == 'professional') {
        final shopDocRef = FirebaseFirestore.instance.collection('diamond_shops').doc(widget.providerUid);
        final existingShopDoc = await shopDocRef.get();
        final existingData = existingShopDoc.data() ?? {};

        // Resolve owner contact details safely without overwriting valid data
        final resolvedOwnerName = _ownerName.isNotEmpty
            ? _ownerName
            : ((existingData['ownerName'] as String?)?.trim().isNotEmpty == true
                ? (existingData['ownerName'] as String).trim()
                : shopName);
        final resolvedOwnerPhone = _ownerPhone.isNotEmpty
            ? _ownerPhone
            : ((existingData['ownerPhone'] as String?)?.trim().isNotEmpty == true
                ? (existingData['ownerPhone'] as String).trim()
                : '');
        final resolvedOwnerEmail = _ownerEmail.isNotEmpty
            ? _ownerEmail
            : ((existingData['ownerEmail'] as String?)?.trim().isNotEmpty == true
                ? (existingData['ownerEmail'] as String).trim()
                : '');

        final shopPayload = <String, dynamic>{
          'id': widget.providerUid,
          'shopId': widget.providerUid,
          'ownerUid': widget.providerUid,
          'shopName': shopName,
          'category': widget.categoryTitle,
          'categoryId': widget.categoryId,
          'demandCategoryId': widget.categoryId,
          'demandCategoryTitle': widget.categoryTitle,
          'description': shopDesc,
          'address': fullAddr,
          'fullAddress': fullAddr,
          'jamuiArea': city.isNotEmpty ? city : 'Jamui',
          'city': city,
          'district': district,
          'pincode': pinCode,
          'latitude': _latitude,
          'longitude': _longitude,
          'logoUrl': _logoUrl,
          'coverImageUrl': _coverUrl,
          'isOpen': true,
          'status': existingData['status'] ?? 'pending', // Under Admin Review
          'isApproved': existingData['isApproved'] ?? false,
          'isActive': existingData['isActive'] ?? true,
          'isDeleted': existingData['isDeleted'] ?? false,
          'isSubscriptionActive': existingData['isSubscriptionActive'] ?? false,
          'paymentVerified': existingData['paymentVerified'] ?? false,
          'rating': (existingData['rating'] as num?)?.toDouble() ?? 0.0,
          'ratingCount': (existingData['ratingCount'] as num?)?.toInt() ?? 0,
          'totalOrders': (existingData['totalOrders'] as num?)?.toInt() ?? 0,
          'totalRevenue': (existingData['totalRevenue'] as num?)?.toDouble() ?? 0,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (resolvedOwnerName.isNotEmpty) {
          shopPayload['ownerName'] = resolvedOwnerName;
        }
        if (resolvedOwnerPhone.isNotEmpty) {
          shopPayload['ownerPhone'] = resolvedOwnerPhone;
        }
        if (resolvedOwnerEmail.isNotEmpty) {
          shopPayload['ownerEmail'] = resolvedOwnerEmail;
        }

        if (!existingShopDoc.exists) {
          shopPayload['createdAt'] = FieldValue.serverTimestamp();
        }

        await shopDocRef.set(shopPayload, SetOptions(merge: true));
      }

      setState(() => _isSubmitting = false);

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit registration: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: _themeGreen, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Registration Submitted!',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your business profile has been successfully registered.',
              style: TextStyle(fontSize: 14, height: 1.4, color: Color(0xFF1E293B)),
            ),
            SizedBox(height: 10),
            Text(
              'Your profile is currently under admin verification. Once approved, your listings will be live on Jamui Services.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.35),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              try {
                context.read<ProviderAuthBloc>().add(CheckAuthStatusEvent());
              } catch (_) {}
              Navigator.pop(ctx);
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _themeGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _themeGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_subStep > 1) {
              setState(() => _subStep = 1);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: const Column(
          children: [
            Text(
              'JAMUI SERVICES',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 1),
            Text(
              '— PROVIDER APP',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white70,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveFormShell(
            maxWidth: 620,
            child: _subStep == 1 ? _buildStep1ShopDetails() : _buildStep2Location(),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // STEP 1: SHOP DETAILS — Screen 3 in Reference Image
  // -------------------------------------------------------------
  Widget _buildStep1ShopDetails() {
    return Form(
      key: _profileFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Set Up Shop Profile',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 4),
          Text(
            'Step 3 of 3: Business Information (${widget.categoryTitle})',
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),

          // Category confirmation pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _themeGreen.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: _themeGreen, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Category: ${widget.categoryTitle}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _themeGreen),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          _buildInputField(
            controller: _shopNameController,
            label: 'Shop Name',
            hint: 'Enter your business / shop name',
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your shop name' : null,
          ),
          const SizedBox(height: 16),

          // Shop Logo Upload Card
          const Text('Shop Logo Upload', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: const Icon(Icons.storefront_rounded, color: _themeGreen, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Business Logo Selected',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ),
                const Icon(Icons.check_circle, color: _themeGreen, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _buildInputField(
            controller: _shopDescController,
            label: 'Shop Description',
            hint: 'Brief description of your products or services',
            maxLines: 2,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a shop description' : null,
          ),
          const SizedBox(height: 16),

          _buildInputField(
            controller: _shopAddressController,
            label: 'Shop Address',
            hint: 'Shop No., Market / Street Name',
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your shop address' : null,
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildInputField(
                  controller: _cityController,
                  label: 'City',
                  hint: 'Jamui',
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter city' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInputField(
                  controller: _districtController,
                  label: 'District',
                  hint: 'Jamui',
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter district' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildInputField(
            controller: _pinCodeController,
            label: 'PIN Code',
            hint: '811307',
            keyboardType: TextInputType.number,
            validator: (v) => (v == null || v.length < 6) ? 'Please enter a valid 6-digit PIN' : null,
          ),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _handleNextToLocation,
              style: ElevatedButton.styleFrom(
                backgroundColor: _themeGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                'Next: Set Location',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // STEP 2: SET LOCATION — Screen 4 in Reference Image
  // -------------------------------------------------------------
  Widget _buildStep2Location() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Confirm Shop Location',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 4),
        const Text(
          'Step 4 of 4: GPS Coordinates & Pin',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 20),

        // Detect Location Button
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton.icon(
            onPressed: _isDetectingGps ? null : _detectCurrentLocation,
            icon: _isDetectingGps
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.my_location_rounded, size: 18),
            label: Text(
              _isDetectingGps ? 'Detecting GPS...' : 'Detect Current Location',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _themeGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Permission Status
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 4,
          children: [
            const Text(
              'Location Permission Status:',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: const Text(
                'Enabled',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _themeGreen),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Map Preview
        const Text('Map Preview', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
        const SizedBox(height: 8),
        Container(
          height: 220,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(_latitude, _longitude),
                    initialZoom: 15.0,
                    onTap: (tapPosition, point) {
                      setState(() {
                        _latitude = point.latitude;
                        _longitude = point.longitude;
                      });
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.jamuiservices.provider',
                    ),
                  ],
                ),
                const Center(
                  child: Icon(Icons.location_on, color: _themeGreen, size: 40),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Selected Address & Coordinates Box
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Selected Address', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
              const SizedBox(height: 4),
              Text(
                _selectedAddress,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
              ),
              const Divider(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Latitude', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        Text('${_latitude.toStringAsFixed(4)}° N', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Longitude', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        Text('${_longitude.toStringAsFixed(4)}° E', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Submit Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submitRegistration,
            style: ElevatedButton.styleFrom(
              backgroundColor: _themeGreen,
              disabledBackgroundColor: _themeGreen.withValues(alpha: 0.6),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _isSubmitting
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                      SizedBox(width: 12),
                      Text('Submitting Profile...', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ],
                  )
                : const Text(
                    'Confirm Location & Submit',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
        const SizedBox(height: 12),

        Center(
          child: TextButton(
            onPressed: () => setState(() => _subStep = 1),
            child: const Text('Back to Shop Details', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
              borderSide: BorderSide(color: _themeGreen, width: 1.8),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}

