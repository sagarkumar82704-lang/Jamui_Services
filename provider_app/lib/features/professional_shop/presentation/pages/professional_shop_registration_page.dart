import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../location/data/datasources/location_remote_data_source.dart';

/// 💎 PROFESSIONAL (PRO) SELLER REGISTRATION SCREEN
/// Designed strictly adhering to the Layout, Section Structure, and UI pattern
/// of the Reference Image:
/// - Screen 1: Seller Registration (Email & Password / Owner Details)
/// - Screen 2: Shop Details (Shop Name, Description, Address, PIN, City)
/// - Screen 3: Set Your Shop Location (GPS Detect, Lat/Long, Address Confirmation)
class ProfessionalShopRegistrationPage extends StatefulWidget {
  final String? initialEmail;
  final String? initialPhone;
  final String? initialFullName;
  final String? selectedCategoryId;
  final String? selectedCategoryTitle;

  const ProfessionalShopRegistrationPage({
    super.key,
    this.initialEmail,
    this.initialPhone,
    this.initialFullName,
    this.selectedCategoryId,
    this.selectedCategoryTitle,
  });

  @override
  State<ProfessionalShopRegistrationPage> createState() => _ProfessionalShopRegistrationPageState();
}

class _ProfessionalShopRegistrationPageState extends State<ProfessionalShopRegistrationPage> {
  // Step tracker: 1 = Owner Details, 2 = Shop Details, 3 = Location
  int _currentStep = 1;
  bool _isLoading = false;

  // Step 1: Owner Details
  final _step1FormKey = GlobalKey<FormState>();
  late TextEditingController _fullNameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late TextEditingController _confirmPasswordController;
  late TextEditingController _phoneController;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Step 2: Shop Details
  final _step2FormKey = GlobalKey<FormState>();
  final _shopNameController = TextEditingController();
  final _shopDescController = TextEditingController();
  final _shopAddressController = TextEditingController();
  final _cityController = TextEditingController(text: 'Jamui');
  final _districtController = TextEditingController(text: 'Jamui');
  final _pinCodeController = TextEditingController(text: '811307');
  String _logoUrl = '';
  String _bannerUrl = '';

  // Step 3: Location Details
  double _latitude = 24.9273;
  double _longitude = 86.2238;
  String _selectedAddress = 'Main Bazaar, Jamui, Bihar';
  bool _isGpsDetected = false;
  final LocationRemoteDataSource _locationDataSource = LocationRemoteDataSourceImpl();
  late String _selectedCategoryId;
  late String _selectedCategoryTitle;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.selectedCategoryId ?? 'cat_grocery';
    _selectedCategoryTitle = widget.selectedCategoryTitle ?? 'Grocery Shop';
    _fullNameController = TextEditingController(text: widget.initialFullName ?? '');
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
    _phoneController = TextEditingController(text: widget.initialPhone ?? '');
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();

    // If owner details already entered in Step 1 or user authenticated, go to Step 2
    if ((widget.initialFullName != null && widget.initialFullName!.isNotEmpty) ||
        FirebaseAuth.instance.currentUser != null) {
      _currentStep = 2;
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        if (_emailController.text.isEmpty && currentUser.email != null) {
          _emailController.text = currentUser.email!;
        }
        if (_fullNameController.text.isEmpty && currentUser.displayName != null) {
          _fullNameController.text = currentUser.displayName!;
        }
        _loadExistingProviderDoc(currentUser.uid);
      }
    }
  }

  Future<void> _loadExistingProviderDoc(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('providers').doc(uid).get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        final pName = (data['fullName'] as String?)?.trim() ??
            (data['name'] as String?)?.trim() ??
            (data['ownerName'] as String?)?.trim() ??
            '';
        final pPhone = (data['phoneNumber'] as String?)?.trim() ??
            (data['phone'] as String?)?.trim() ??
            (data['mobile'] as String?)?.trim() ??
            (data['ownerPhone'] as String?)?.trim() ??
            '';
        final pEmail = (data['email'] as String?)?.trim() ??
            (data['ownerEmail'] as String?)?.trim() ??
            '';
        if (_fullNameController.text.isEmpty && pName.isNotEmpty) {
          _fullNameController.text = pName;
        }
        if (_phoneController.text.isEmpty && pPhone.isNotEmpty) {
          _phoneController.text = pPhone;
        }
        if (_emailController.text.isEmpty && pEmail.isNotEmpty) {
          _emailController.text = pEmail;
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _shopNameController.dispose();
    _shopDescController.dispose();
    _shopAddressController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _pinCodeController.dispose();
    super.dispose();
  }

  // Deep Emerald / Forest Green matching Reference Image Header
  static const Color _themeGreen = Color(0xFF1B5E20);
  static const Color _buttonGreen = Color(0xFF1B5E20);

  Future<void> _handleStep1Next() async {
    FocusScope.of(context).unfocus();
    if (!_step1FormKey.currentState!.validate()) return;

    if (_passwordController.text.trim() != _confirmPasswordController.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('पासवर्ड और कन्फर्म पासवर्ड मेल नहीं खा रहे हैं।'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final cleanEmail = _emailController.text.trim().toLowerCase();
      final cleanPassword = _passwordController.text.trim();
      final cleanName = _fullNameController.text.trim();
      final cleanPhone = _phoneController.text.trim();

      // Check if user is already signed in
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: cleanEmail,
          password: cleanPassword,
        );
        user = cred.user;
        if (user != null) {
          await user.updateDisplayName(cleanName);
        }
      }

      if (user != null) {
        // Save initial provider record draft
        await FirebaseFirestore.instance.collection('providers').doc(user.uid).set({
          'id': user.uid,
          'email': cleanEmail,
          'fullName': cleanName,
          'phoneNumber': cleanPhone.startsWith('+91') ? cleanPhone : '+91$cleanPhone',
          'primaryCategoryId': _selectedCategoryId,
          'primaryCategoryTitle': _selectedCategoryTitle,
          'categoryType': 'professional',
          'isProfessional': true,
          'isDiamond': true, // compatibility layer
          'status': 'draft',
          'kycStatus': 'notSubmitted',
          'registrationStatus': 'draft',
          'currentStep': 2,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        setState(() {
          _currentStep = 2;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('त्रुटि: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _handleStep2Next() {
    FocusScope.of(context).unfocus();
    if (!_step2FormKey.currentState!.validate()) return;
    setState(() => _currentStep = 3);
  }

  Future<void> _detectLocation() async {
    setState(() => _isLoading = true);
    try {
      final pos = await _locationDataSource.getCurrentPosition();
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
        _isGpsDetected = true;
        _selectedAddress = 'Lat: ${_latitude.toStringAsFixed(4)}, Long: ${_longitude.toStringAsFixed(4)}, Jamui, Bihar';
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _isGpsDetected = true;
        _latitude = 24.9273;
        _longitude = 86.2238;
        _selectedAddress = 'Main Bazaar, Jamui, Bihar';
        _isLoading = false;
      });
    }
  }

  Future<void> _submitProfessionalRegistration() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw 'सत्र अमान्य है। कृपया पुनः लॉगिन करें।';
      }

      final shopName = _shopNameController.text.trim();
      final shopDesc = _shopDescController.text.trim();
      final address = _shopAddressController.text.trim();
      final city = _cityController.text.trim();
      final district = _districtController.text.trim();
      final pinCode = _pinCodeController.text.trim();
      final fullAddr = '$address, $city, $district - $pinCode';

      // 1. Create / Update diamond_shops/{uid} document (Safe for Emulator & Firestore Rules)
      // Read existing shop document if it exists to preserve valid contact details
      DocumentSnapshot<Map<String, dynamic>>? existingShopDoc;
      try {
        existingShopDoc = await FirebaseFirestore.instance.collection('diamond_shops').doc(user.uid).get();
      } catch (_) {}
      final existingShopData = existingShopDoc?.data() ?? <String, dynamic>{};
      final existingOwnerName = (existingShopData['ownerName'] as String?)?.trim() ?? '';
      final existingOwnerPhone = (existingShopData['ownerPhone'] as String?)?.trim() ??
          (existingShopData['contactPhone'] as String?)?.trim() ??
          '';
      final existingOwnerEmail = (existingShopData['ownerEmail'] as String?)?.trim() ?? '';

      // Read authenticated provider profile from providers/{uid}
      DocumentSnapshot<Map<String, dynamic>>? providerDoc;
      try {
        providerDoc = await FirebaseFirestore.instance.collection('providers').doc(user.uid).get();
      } catch (_) {}
      final providerData = providerDoc?.data() ?? <String, dynamic>{};

      // Resolve ownerName from providers/{uid} schema ('fullName' / 'name' / 'ownerName') -> _fullNameController -> auth displayName -> existing shop
      final profileName = (providerData['fullName'] as String?)?.trim() ??
          (providerData['name'] as String?)?.trim() ??
          (providerData['ownerName'] as String?)?.trim() ??
          (providerData['providerName'] as String?)?.trim() ??
          '';
      String resolvedOwnerName = '';
      if (profileName.isNotEmpty) {
        resolvedOwnerName = profileName;
      } else if (_fullNameController.text.trim().isNotEmpty) {
        resolvedOwnerName = _fullNameController.text.trim();
      } else if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
        resolvedOwnerName = user.displayName!.trim();
      } else if (existingOwnerName.isNotEmpty) {
        resolvedOwnerName = existingOwnerName;
      }

      // Resolve ownerPhone from providers/{uid} schema ('phoneNumber' / 'phone' / 'mobile' / 'ownerPhone') -> _phoneController -> existing shop
      // Note: Authoritative mobile number comes from providers/{uid}. Phone OTP fallback is strictly removed.
      final profilePhone = (providerData['phoneNumber'] as String?)?.trim() ??
          (providerData['phone'] as String?)?.trim() ??
          (providerData['mobile'] as String?)?.trim() ??
          (providerData['ownerPhone'] as String?)?.trim() ??
          '';
      String resolvedOwnerPhone = '';
      if (profilePhone.isNotEmpty) {
        resolvedOwnerPhone = profilePhone;
      } else if (_phoneController.text.trim().isNotEmpty) {
        resolvedOwnerPhone = _phoneController.text.trim();
      } else if (existingOwnerPhone.isNotEmpty) {
        resolvedOwnerPhone = existingOwnerPhone;
      }

      // Resolve ownerEmail from providers/{uid} schema ('email' / 'ownerEmail') -> auth email fallback -> _emailController -> existing shop
      final profileEmail = (providerData['email'] as String?)?.trim() ??
          (providerData['ownerEmail'] as String?)?.trim() ??
          '';
      String resolvedOwnerEmail = '';
      if (profileEmail.isNotEmpty) {
        resolvedOwnerEmail = profileEmail.toLowerCase();
      } else if (user.email != null && user.email!.trim().isNotEmpty) {
        resolvedOwnerEmail = user.email!.trim().toLowerCase();
      } else if (_emailController.text.trim().isNotEmpty) {
        resolvedOwnerEmail = _emailController.text.trim().toLowerCase();
      } else if (existingOwnerEmail.isNotEmpty) {
        resolvedOwnerEmail = existingOwnerEmail.toLowerCase();
      }

      final shopPayload = <String, dynamic>{
        'id': user.uid,
        'ownerUid': user.uid,
        'shopName': shopName,
        'demandCategoryId': _selectedCategoryId,
        'demandCategoryTitle': _selectedCategoryTitle,
        'category': _selectedCategoryTitle,
        'categoryId': _selectedCategoryId,
        'description': shopDesc,
        'fullAddress': fullAddr,
        'jamuiArea': city.isNotEmpty ? city : 'Jamui',
        'latitude': _latitude,
        'longitude': _longitude,
        'serviceRadiusKm': 10.0,
        'logoUrl': _logoUrl,
        'bannerUrl': _bannerUrl,
        'isOpen': true,
        'status': 'pending', // Under Admin Review
        'isApproved': false,
        'isVerified': false,
        'isActive': true,
        'isDeleted': false,
        'isSubscriptionActive': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Only assign non-empty values to prevent overwriting existing valid contact data
      if (resolvedOwnerName.isNotEmpty) {
        shopPayload['ownerName'] = resolvedOwnerName;
      }
      if (resolvedOwnerPhone.isNotEmpty) {
        shopPayload['ownerPhone'] = resolvedOwnerPhone;
        shopPayload['contactPhone'] = resolvedOwnerPhone;
      }
      if (resolvedOwnerEmail.isNotEmpty) {
        shopPayload['ownerEmail'] = resolvedOwnerEmail;
      }

      await FirebaseFirestore.instance.collection('diamond_shops').doc(user.uid).set(
        shopPayload,
        SetOptions(merge: true),
      );

      // 2. Update providers/{uid} document with completed registration
      await FirebaseFirestore.instance.collection('providers').doc(user.uid).set({
        'businessName': shopName,
        'businessDescription': shopDesc,
        'primaryCategoryId': _selectedCategoryId,
        'primaryCategoryTitle': _selectedCategoryTitle,
        'categoryType': 'professional',
        'isProfessional': true,
        'isDiamond': true, // compatibility layer
        'subServices': [_selectedCategoryTitle],
        'selectedService': _selectedCategoryTitle,
        'fullAddress': fullAddr,
        'jamuiArea': city.isNotEmpty ? city : 'Jamui',
        'latitude': _latitude,
        'longitude': _longitude,
        'status': 'pendingReview',
        'kycStatus': 'pendingReview',
        'registrationStatus': 'completed',
        'completedSteps': [0, 1, 2, 3, 4, 5],
        'currentStep': 5,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() => _isLoading = false);

      if (mounted) {
        _showSuccessPendingDialog();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('रजिस्ट्रेशन सबमिट करने में विफल: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showSuccessPendingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF1B5E20), size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'पंजीकरण सफल!',
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
              'आपकी प्रोफेशनल दुकान का पंजीकरण सफलतापूर्वक सबमिट हो गया है।',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
            SizedBox(height: 10),
            Text(
              'एडमिन द्वारा सत्यापन (Review) के पश्चात आपकी दुकान कस्टमर ऐप पर लाइव कर दी जाएगी।',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // Return to login / root
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _buttonGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('ठीक है', style: TextStyle(fontWeight: FontWeight.bold)),
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
            if (_currentStep > 1) {
              setState(() => _currentStep--);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Column(
          children: [
            const Text(
              'JAMUI SERVICES',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.8),
            ),
            Text(
              '— PROFESSIONAL SELLER APP —',
              style: TextStyle(fontSize: 9.5, color: Colors.green.shade100, letterSpacing: 1),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _themeGreen))
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: _buildCurrentStepView(),
              ),
      ),
    );
  }

  Widget _buildCurrentStepView() {
    switch (_currentStep) {
      case 1:
        return _buildStep1OwnerDetails();
      case 2:
        return _buildStep2ShopDetails();
      case 3:
        return _buildStep3Location();
      default:
        return _buildStep1OwnerDetails();
    }
  }

  // -------------------------------------------------------------
  // STEP 1: SELLER REGISTRATION (EMAIL & PASSWORD) — Column 1 in Image
  // -------------------------------------------------------------
  Widget _buildStep1OwnerDetails() {
    return Form(
      key: _step1FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Create Seller Account',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Step 1 of 3: Owner Details',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 24),

          _buildInputField(
            controller: _fullNameController,
            label: 'Full Name',
            hint: 'Your Name',
            validator: (v) => (v == null || v.trim().isEmpty) ? 'नाम दर्ज करें' : null,
          ),
          const SizedBox(height: 16),

          _buildInputField(
            controller: _emailController,
            label: 'Email Address',
            hint: 'seller@example.com',
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || !v.contains('@')) return 'मान्य ईमेल दर्ज करें';
              return null;
            },
          ),
          const SizedBox(height: 16),

          _buildInputField(
            controller: _passwordController,
            label: 'Create Password',
            hint: '••••••••',
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (v) => (v == null || v.length < 6) ? 'कम से कम 6 अक्षर का पासवर्ड रखें' : null,
          ),
          const SizedBox(height: 16),

          _buildInputField(
            controller: _confirmPasswordController,
            label: 'Confirm Password',
            hint: '••••••••',
            obscureText: _obscureConfirmPassword,
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
            validator: (v) => (v == null || v.isEmpty) ? 'पासवर्ड दोबारा दर्ज करें' : null,
          ),
          const SizedBox(height: 16),

          _buildInputField(
            controller: _phoneController,
            label: 'Mobile Number (business contact)',
            hint: '9876543210',
            keyboardType: TextInputType.phone,
            validator: (v) {
              final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
              if (digits.length < 10) return '10 अंकों का मोबाइल नंबर दर्ज करें';
              return null;
            },
          ),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _handleStep1Next,
              style: ElevatedButton.styleFrom(
                backgroundColor: _buttonGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: const Text(
                'Next: Shop Details',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Already have an account? Login',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // STEP 2: SHOP DETAILS — Column 3 in Image
  // -------------------------------------------------------------
  Widget _buildStep2ShopDetails() {
    return Form(
      key: _step2FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Set Up Shop Profile',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Step 2 of 3: Business Information',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),

          // Selected Professional Category Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF1B5E20).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.storefront_rounded, color: Color(0xFF1B5E20), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'श्रेणी (Category): $_selectedCategoryTitle',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF1B5E20)),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B5E20),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('PRO', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _buildInputField(
            controller: _shopNameController,
            label: 'Shop Name (दुकान का नाम)',
            hint: 'उदा. $_selectedCategoryTitle या दुकान का नाम दर्ज करें',
            validator: (v) => (v == null || v.trim().isEmpty) ? 'दुकान का नाम दर्ज करें' : null,
          ),
          const SizedBox(height: 16),

          // Shop Logo Upload Mock Card (Visual Match to Reference)
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
                    color: const Color(0xFFE0F2F1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF0F766E).withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.storefront_rounded, color: Color(0xFF0F766E), size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Default Professional Logo Selected',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ),
                const Icon(Icons.check_circle, color: Color(0xFF1B5E20), size: 20),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _buildInputField(
            controller: _shopDescController,
            label: 'Shop Description',
            hint: 'Quality Professional & Grocery Store',
            maxLines: 2,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'दुकान का विवरण दर्ज करें' : null,
          ),
          const SizedBox(height: 16),

          _buildInputField(
            controller: _shopAddressController,
            label: 'Shop Address',
            hint: 'Shop No., Market / Street Name',
            validator: (v) => (v == null || v.trim().isEmpty) ? 'पता दर्ज करें' : null,
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildInputField(
                  controller: _cityController,
                  label: 'City',
                  hint: 'Jamui',
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'शहर दर्ज करें' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInputField(
                  controller: _districtController,
                  label: 'District',
                  hint: 'Jamui',
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'जिला दर्ज करें' : null,
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
            validator: (v) => (v == null || v.length < 6) ? '6 अंकों का पिन कोड दर्ज करें' : null,
          ),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _handleStep2Next,
              style: ElevatedButton.styleFrom(
                backgroundColor: _buttonGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: const Text(
                'Next: Set Location',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // STEP 3: SET YOUR SHOP LOCATION — Column 4 in Image
  // -------------------------------------------------------------
  Widget _buildStep3Location() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Confirm Shop Location',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 4),
        const Text(
          'Step 3 of 3: GPS & Geolocation',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 20),

        // "Detect Current Location" Button (Matching Reference)
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton.icon(
            onPressed: _detectLocation,
            icon: const Icon(Icons.my_location_rounded, size: 18),
            label: const Text('Detect Current Location', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _buttonGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Location Permission Status Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF1B5E20), size: 18),
              const SizedBox(width: 8),
              Text(
                'Location Status: ${_isGpsDetected ? "Enabled (Accurate GPS)" : "Default Jamui Coords"}',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Map Preview Box (Matching Visual Container in Reference Image)
        Container(
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade300),
            color: const Color(0xFFE2E8F0),
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
                      ),
                      child: const Icon(Icons.location_on, color: Colors.red, size: 32),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                      ),
                      child: Text(
                        '${_shopNameController.text.trim().isNotEmpty ? _shopNameController.text.trim() : "Professional Shop"}, Jamui',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Google Map Jamui', style: TextStyle(fontSize: 10, color: Colors.black54)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Selected Address Card (Matching Reference Image)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
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
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 6),
              Text(
                'Latitude: ${_latitude.toStringAsFixed(4)}° N | Longitude: ${_longitude.toStringAsFixed(4)}° E',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Confirm Location Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _submitProfessionalRegistration,
            style: ElevatedButton.styleFrom(
              backgroundColor: _buttonGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text(
              'Confirm Location & Register',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 12),

        Center(
          child: TextButton(
            onPressed: _detectLocation,
            child: const Text(
              'Adjust Pin / Refresh GPS',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
            suffixIcon: suffixIcon,
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
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _themeGreen, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

