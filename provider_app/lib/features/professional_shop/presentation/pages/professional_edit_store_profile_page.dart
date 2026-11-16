import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/services/r2_upload_service.dart';
import '../../../../core/utils/app_image_url_resolver.dart';
import '../../../location/data/datasources/location_remote_data_source.dart';
import '../../data/datasources/professional_provider_remote_data_source.dart';
import '../../domain/entities/professional_shop_profile_entity.dart';
import 'professional_set_store_location_page.dart';

class ProfessionalEditStoreProfilePage extends StatefulWidget {
  final ProfessionalShopProfileEntity shop;
  final ProfessionalProviderRemoteDataSource? dataSource;

  const ProfessionalEditStoreProfilePage({
    super.key,
    required this.shop,
    this.dataSource,
  });

  @override
  State<ProfessionalEditStoreProfilePage> createState() =>
      _ProfessionalEditStoreProfilePageState();
}

class _ProfessionalEditStoreProfilePageState
    extends State<ProfessionalEditStoreProfilePage> {
  static const Color _primaryGreen = Color(0xFF15803D);
  static const Color _darkGreenHeader = Color(0xFF0B4F26);

  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  late final ProfessionalProviderRemoteDataSource _ds;

  // Store Identity & Media
  late final TextEditingController _shopNameController;
  late final TextEditingController _descriptionController;
  String _logoUrl = '';
  String _coverUrl = '';
  bool _isUploadingLogo = false;
  bool _isUploadingCover = false;

  // Business Hours
  bool _isOpen = true;
  String _openingTime = '09:00 AM';
  String _closingTime = '09:00 PM';

  // Contact Information
  late final TextEditingController _phoneController;
  late final TextEditingController _whatsAppController;
  late final TextEditingController _emailController;

  // Store Location (Preserved until seller explicitly confirms new location)
  double? _latitude;
  double? _longitude;
  late final TextEditingController _fullAddressController;
  late final TextEditingController _jamuiAreaController;
  late final TextEditingController _landmarkController;
  String _locationSource = '';
  bool _isLocationApproximate = false;

  // Delivery & Pickup Settings
  bool _isHomeDeliveryActive = true;
  bool _isPickupActive = true;
  late final TextEditingController _deliveryChargeController;
  late final TextEditingController _minOrderController;
  late final TextEditingController _freeDeliveryThresholdController;
  late final TextEditingController _serviceRadiusKmController;
  late final TextEditingController _estimatedMinutesController;
  late final TextEditingController _pickupInstructionsController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _ds = widget.dataSource ?? ProfessionalProviderRemoteDataSource();
    final s = widget.shop;

    _shopNameController = TextEditingController(text: s.shopName);
    _descriptionController = TextEditingController(text: s.description);
    _logoUrl = s.logoUrl;
    _coverUrl = s.bannerUrl;

    _isOpen = s.isOpen;
    _openingTime = s.openingTime.isNotEmpty ? s.openingTime : '09:00 AM';
    _closingTime = s.closingTime.isNotEmpty ? s.closingTime : '09:00 PM';

    _phoneController = TextEditingController(text: s.contactPhone);
    _whatsAppController = TextEditingController(text: s.whatsAppNumber);
    _emailController = TextEditingController(text: s.ownerEmail);

    _latitude = s.latitude;
    _longitude = s.longitude;
    _fullAddressController = TextEditingController(text: s.fullAddress);
    _jamuiAreaController = TextEditingController(text: s.jamuiArea);
    _landmarkController = TextEditingController(text: s.landmark);
    _locationSource = s.locationSource;
    _isLocationApproximate = s.isLocationApproximate;

    _isHomeDeliveryActive = s.isHomeDeliveryActive;
    _isPickupActive = s.isPickupActive;
    _deliveryChargeController = TextEditingController(
      text: s.deliveryCharges.toStringAsFixed(0),
    );
    _minOrderController = TextEditingController(
      text: s.minOrderAmount.toStringAsFixed(0),
    );
    _freeDeliveryThresholdController = TextEditingController(
      text: s.freeDeliveryThreshold.toStringAsFixed(0),
    );
    _serviceRadiusKmController = TextEditingController(
      text: s.serviceRadiusKm.toStringAsFixed(0),
    );
    _estimatedMinutesController = TextEditingController(
      text: s.estimatedDeliveryTimeMinutes.toString(),
    );
    _pickupInstructionsController = TextEditingController(
      text: s.pickupInstructions,
    );
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _whatsAppController.dispose();
    _emailController.dispose();
    _fullAddressController.dispose();
    _jamuiAreaController.dispose();
    _landmarkController.dispose();
    _deliveryChargeController.dispose();
    _minOrderController.dispose();
    _freeDeliveryThresholdController.dispose();
    _serviceRadiusKmController.dispose();
    _estimatedMinutesController.dispose();
    _pickupInstructionsController.dispose();
    super.dispose();
  }

  String get _effectiveOwnerUid {
    if (widget.shop.ownerUid.trim().isNotEmpty) {
      return widget.shop.ownerUid.trim();
    }
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && uid.isNotEmpty) return uid;
    } catch (_) {}
    return widget.shop.id;
  }

  Future<void> _pickAndUploadStoreImage({required bool isLogo}) async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: isLogo ? 700 : 1400,
        maxHeight: isLogo ? 700 : 900,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() {
        if (isLogo) {
          _isUploadingLogo = true;
        } else {
          _isUploadingCover = true;
        }
      });

      final bytes = await picked.readAsBytes();
      final ext = picked.name.contains('.')
          ? picked.name.split('.').last.toLowerCase()
          : 'jpg';
      final contentType = ext == 'png'
          ? 'image/png'
          : (ext == 'webp' ? 'image/webp' : 'image/jpeg');

      final uploaded = await R2UploadService().uploadBytes(
        bytes: bytes,
        folder: isLogo ? 'profile' : 'business',
        targetId: _effectiveOwnerUid,
        mimeType: contentType,
        fileName: picked.name,
      );

      if (!mounted) return;
      setState(() {
        if (isLogo) {
          _logoUrl = uploaded.objectKey;
          _isUploadingLogo = false;
        } else {
          _coverUrl = uploaded.objectKey;
          _isUploadingCover = false;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isLogo
                ? 'Store logo uploaded successfully!'
                : 'Store cover photo uploaded successfully!',
          ),
          backgroundColor: _primaryGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploadingLogo = false;
        _isUploadingCover = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Image upload failed: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _pickBusinessTime({required bool isOpening}) async {
    final initial = const TimeOfDay(hour: 9, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked == null || !mounted) return;

    final formatted = picked.format(context);
    setState(() {
      if (isOpening) {
        _openingTime = formatted;
      } else {
        _closingTime = formatted;
      }
    });
  }

  Future<void> _openSetStoreLocationScreen() async {
    final snapshotShop = widget.shop.copyWith(
      ownerEmail: _emailController.text.trim(),
      shopName: _shopNameController.text.trim(),
      description: _descriptionController.text.trim(),
      logoUrl: _logoUrl,
      bannerUrl: _coverUrl,
      fullAddress: _fullAddressController.text.trim(),
      jamuiArea: _jamuiAreaController.text.trim(),
      landmark: _landmarkController.text.trim(),
      latitude: _latitude ?? 0.0,
      longitude: _longitude ?? 0.0,
      locationSource: _locationSource,
      isLocationApproximate: _isLocationApproximate,
      contactPhone: _phoneController.text.trim(),
      whatsAppNumber: _whatsAppController.text.trim(),
      openingTime: _openingTime,
      closingTime: _closingTime,
      isOpen: _isOpen,
      isHomeDeliveryActive: _isHomeDeliveryActive,
      isPickupActive: _isPickupActive,
      pickupInstructions: _pickupInstructionsController.text.trim(),
    );

    final result = await Navigator.of(context).push<StoreLocationSelectionResult>(
      MaterialPageRoute(
        builder: (_) => ProfessionalSetStoreLocationPage(
          shop: snapshotShop,
          shopDataSource: _ds,
          persistImmediately: true,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _latitude = result.latitude;
        _longitude = result.longitude;
        _fullAddressController.text = result.fullAddress;
        if (result.jamuiArea.isNotEmpty) {
          _jamuiAreaController.text = result.jamuiArea;
        }
        _landmarkController.text = result.landmark;
        _locationSource = result.locationSource;
        _isLocationApproximate = result.isLocationApproximate;
      });
    }
  }

  Future<void> _saveStoreProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isHomeDeliveryActive && !_isPickupActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'At least one fulfillment option (Home Delivery or Store Pickup) must be enabled.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      String? currentUid;
      try {
        currentUid = FirebaseAuth.instance.currentUser?.uid;
      } catch (_) {}

      final payload = <String, dynamic>{
        'shopName': _shopNameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'logoUrl': _logoUrl.trim(),
        'bannerUrl': _coverUrl.trim(),
        'isOpen': _isOpen,
        'openingTime': _openingTime.trim(),
        'closingTime': _closingTime.trim(),
        'contactPhone': _phoneController.text.trim(),
        'whatsAppNumber': _whatsAppController.text.trim(),
        'ownerEmail': _emailController.text.trim(),
        'fullAddress': _fullAddressController.text.trim(),
        'jamuiArea': _jamuiAreaController.text.trim(),
        'landmark': _landmarkController.text.trim(),
        if (StoreCoordinateValidator.isValidNumbers(_latitude, _longitude)) ...{
          'latitude': _latitude,
          'longitude': _longitude,
          'locationSource': _locationSource,
          'isLocationApproximate': _isLocationApproximate,
        },
        'isHomeDeliveryActive': _isHomeDeliveryActive,
        'isPickupActive': _isPickupActive,
        'deliveryCharges':
            double.tryParse(_deliveryChargeController.text.trim()) ?? 0.0,
        'minOrderAmount':
            double.tryParse(_minOrderController.text.trim()) ?? 0.0,
        'freeDeliveryThreshold':
            double.tryParse(_freeDeliveryThresholdController.text.trim()) ??
                0.0,
        'serviceRadiusKm':
            double.tryParse(_serviceRadiusKmController.text.trim()) ?? 5.0,
        'estimatedDeliveryTimeMinutes':
            int.tryParse(_estimatedMinutesController.text.trim()) ?? 45,
        'pickupInstructions': _pickupInstructionsController.text.trim(),
      };

      await _ds.updateShopProfile(
        widget.shop.id,
        payload,
        currentUid: currentUid,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Store profile updated successfully!'),
          backgroundColor: _primaryGreen,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save store profile: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final resolvedLogo = AppImageUrlResolver.resolve(_logoUrl);
    final resolvedCover = AppImageUrlResolver.resolve(_coverUrl);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F9F5),
      appBar: AppBar(
        backgroundColor: _darkGreenHeader,
        foregroundColor: Colors.white,
        title: const Text(
          'Edit Store Profile',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLogoAndCoverSection(resolvedLogo, resolvedCover),
              const SizedBox(height: 16),
              _buildStoreIdentitySection(),
              const SizedBox(height: 16),
              _buildStoreLocationSection(),
              const SizedBox(height: 16),
              _buildBusinessHoursSection(),
              const SizedBox(height: 16),
              _buildContactInfoSection(),
              const SizedBox(height: 16),
              _buildDeliveryAndPickupSection(),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  key: const Key('btn_save_store_profile'),
                  onPressed: (_isSaving ||
                          _isUploadingLogo ||
                          _isUploadingCover)
                      ? null
                      : _saveStoreProfile,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_rounded),
                  label: Text(
                    _isSaving ? 'Saving Changes...' : 'Save Store Profile',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoAndCoverSection(String resolvedLogo, String resolvedCover) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 145,
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: _darkGreenHeader,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                ),
                child: resolvedCover.isNotEmpty
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(15),
                        ),
                        child: Image.network(
                          resolvedCover,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Center(
                            child: Icon(
                              Icons.storefront_rounded,
                              color: Colors.white54,
                              size: 40,
                            ),
                          ),
                        ),
                      )
                    : const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.panorama_outlined,
                              color: Colors.white70,
                              size: 32,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Store Cover Photo',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: ElevatedButton.icon(
                  key: const Key('btn_upload_store_cover'),
                  onPressed: _isUploadingCover
                      ? null
                      : () => _pickAndUploadStoreImage(isLogo: false),
                  icon: _isUploadingCover
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.camera_alt_outlined, size: 16),
                  label: Text(
                    _isUploadingCover ? 'Uploading...' : 'Cover Photo',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.65),
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                ),
              ),
              Positioned(
                bottom: -28,
                left: 16,
                child: Stack(
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: resolvedLogo.isNotEmpty
                            ? Image.network(
                                resolvedLogo,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.store_rounded,
                                  color: _primaryGreen,
                                  size: 34,
                                ),
                              )
                            : const Icon(
                                Icons.store_rounded,
                                color: _primaryGreen,
                                size: 34,
                              ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        key: const Key('btn_upload_store_logo'),
                        onTap: _isUploadingLogo
                            ? null
                            : () => _pickAndUploadStoreImage(isLogo: true),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: _primaryGreen,
                            shape: BoxShape.circle,
                          ),
                          child: _isUploadingLogo
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.edit,
                                  size: 13,
                                  color: Colors.white,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 36),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Category: ${widget.shop.shopCategory} (Verified Category)',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4B5563),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _isUploadingLogo
                      ? null
                      : () => _pickAndUploadStoreImage(isLogo: true),
                  icon: const Icon(Icons.upload_outlined, size: 15),
                  label: const Text(
                    'Change Logo',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreIdentitySection() {
    return _buildSectionCard(
      title: 'Store Identity & Description',
      icon: Icons.storefront_outlined,
      children: [
        TextFormField(
          key: const Key('field_edit_shop_name'),
          controller: _shopNameController,
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'Store name is required'
              : null,
          decoration: _inputDecoration(
            label: 'Store Name *',
            hint: 'Enter your shop name',
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const Key('field_edit_shop_description'),
          controller: _descriptionController,
          maxLines: 3,
          decoration: _inputDecoration(
            label: 'Store Description',
            hint: 'Describe your store, products and specialties...',
          ),
        ),
      ],
    );
  }

  Widget _buildStoreLocationSection() {
    final hasValidCoords =
        StoreCoordinateValidator.isValidNumbers(_latitude, _longitude);
    return _buildSectionCard(
      title: 'Store Address & GPS Coordinates',
      icon: Icons.location_on_outlined,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.pin_drop_rounded,
                    color: _primaryGreen,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      hasValidCoords
                          ? 'Coordinates: ${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}'
                          : 'No GPS coordinates set yet',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF14532D),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  key: const Key('btn_open_set_store_location'),
                  onPressed: _openSetStoreLocationScreen,
                  icon: const Icon(Icons.edit_location_alt_rounded, size: 18),
                  label: const Text(
                    'Set Store Location (GPS / Map / Lat-Lng)',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const Key('field_edit_full_address'),
          controller: _fullAddressController,
          maxLines: 2,
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'Store address is required'
              : null,
          decoration: _inputDecoration(
            label: 'Full Store Address *',
            hint: 'Shop building, road, bazaar, city',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _jamuiAreaController,
                decoration: _inputDecoration(
                  label: 'Area / Locality',
                  hint: 'e.g. Maharajganj',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _landmarkController,
                decoration: _inputDecoration(
                  label: 'Landmark',
                  hint: 'Near Main Chowk',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBusinessHoursSection() {
    return _buildSectionCard(
      title: 'Business Hours & Open Status',
      icon: Icons.access_time_rounded,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: _primaryGreen,
          title: const Text(
            'Store Currently Open for Orders',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          subtitle: Text(
            _isOpen ? 'Open • Accepting customer orders' : 'Closed right now',
            style: const TextStyle(fontSize: 12),
          ),
          value: _isOpen,
          onChanged: (v) => setState(() => _isOpen = v),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickBusinessTime(isOpening: true),
                icon: const Icon(Icons.wb_sunny_outlined, size: 16),
                label: Text('Opens: $_openingTime'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickBusinessTime(isOpening: false),
                icon: const Icon(Icons.nights_stay_outlined, size: 16),
                label: Text('Closes: $_closingTime'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContactInfoSection() {
    return _buildSectionCard(
      title: 'Seller Contact Information',
      icon: Icons.call_outlined,
      children: [
        TextFormField(
          key: const Key('field_edit_contact_phone'),
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          validator: (v) => (v == null || v.trim().length < 10)
              ? 'Enter a valid 10-digit phone number'
              : null,
          decoration: _inputDecoration(
            label: 'Primary Contact Phone *',
            hint: '10-digit mobile number',
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _whatsAppController,
          keyboardType: TextInputType.phone,
          decoration: _inputDecoration(
            label: 'WhatsApp Number',
            hint: 'WhatsApp contact number',
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: _inputDecoration(
            label: 'Business Email (Optional)',
            hint: 'seller@example.com',
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryAndPickupSection() {
    return _buildSectionCard(
      title: 'Delivery & Store Pickup Settings',
      icon: Icons.delivery_dining_outlined,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: _primaryGreen,
          title: const Text(
            'Enable Home Delivery',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          value: _isHomeDeliveryActive,
          onChanged: (v) => setState(() => _isHomeDeliveryActive = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: _primaryGreen,
          title: const Text(
            'Enable Store Pickup',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          value: _isPickupActive,
          onChanged: (v) => setState(() => _isPickupActive = v),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _deliveryChargeController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration(
                  label: 'Delivery Fee (₹)',
                  hint: '20',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _freeDeliveryThresholdController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration(
                  label: 'Free Delivery Above (₹)',
                  hint: '499',
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
                controller: _minOrderController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration(
                  label: 'Min Order Amount (₹)',
                  hint: '100',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _estimatedMinutesController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration(
                  label: 'Delivery ETA (Mins)',
                  hint: '45',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _pickupInstructionsController,
          decoration: _inputDecoration(
            label: 'Pickup Instructions (Optional)',
            hint: 'e.g. Ready in 10-15 mins at main counter',
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _primaryGreen, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

