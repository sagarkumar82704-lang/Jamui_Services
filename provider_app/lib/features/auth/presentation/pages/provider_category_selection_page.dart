import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../categories/data/models/service_category_model.dart';
import '../bloc/provider_auth_bloc.dart';
import 'provider_profile_setup_page.dart';

/// Screen 2: Category Selection Screen
/// - Displays Normal Provider Categories from 'categories' collection (UNTOUCHED)
/// - Displays Diamond E-Commerce Categories from 'diamond_categories' collection
/// - Displays Sub-Services when a category is selected
/// - Saves selection to providers/{uid} and advances to Screen 3 (Profile Setup)
/// - 100% English UI and error messages
class ProviderCategorySelectionPage extends StatefulWidget {
  final String providerUid;
  final String initialCategoryId;
  final String initialCategoryTitle;
  final String initialCategoryType;

  const ProviderCategorySelectionPage({
    super.key,
    required this.providerUid,
    this.initialCategoryId = '',
    this.initialCategoryTitle = '',
    this.initialCategoryType = 'general',
  });

  @override
  State<ProviderCategorySelectionPage> createState() => _ProviderCategorySelectionPageState();
}

class _ProviderCategorySelectionPageState extends State<ProviderCategorySelectionPage> {
  static const Color _themeGreen = Color(0xFF1B5E20);

  bool _isLoading = true;
  String? _errorMessage;

  List<ServiceCategoryModel> _normalCategories = [];
  List<ServiceCategoryModel> _premiumCategories = [];
  List<Map<String, dynamic>> _professionalCategories = [];

  String _selectedCategoryId = '';
  String _selectedCategoryTitle = '';
  String _selectedCategoryType = 'general'; // 'general', 'premium', or 'professional'
  final List<String> _selectedSubServices = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.initialCategoryId;
    _selectedCategoryTitle = widget.initialCategoryTitle;
    _selectedCategoryType = widget.initialCategoryType;
    _loadAllCategories();
  }

  Future<void> _loadAllCategories() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Load Normal Categories from 'categories' collection
      final normalSnap = await FirebaseFirestore.instance.collection('categories').get();
      final allNormal = normalSnap.docs
          .map((doc) => ServiceCategoryModel.fromMap(doc.data(), doc.id))
          .where((c) => !c.isDeleted && (c.isActive || c.status.toLowerCase() == 'active'))
          .toList();

      final general = allNormal.where((c) => !c.isPremium && c.categoryType != 'premium').toList();
      final premium = allNormal.where((c) => c.isPremium || c.categoryType == 'premium').toList();
      general.sort((a, b) => a.priorityOrder.compareTo(b.priorityOrder));
      premium.sort((a, b) => a.priorityOrder.compareTo(b.priorityOrder));

      // 2. Load Professional Categories from 'diamond_categories' collection (compatibility preserved)
      // STRICT FIRESTORE SECURITY RULES REQUIREMENT:
      // Non-admins only have read permission when 'isActive == true'.
      // Therefore, the Firestore query MUST include .where('isActive', isEqualTo: true).
      // Unconstrained .get() causes Firestore PERMISSION_DENIED.
      List<Map<String, dynamic>> proList = [];
      try {
        final proSnap = await FirebaseFirestore.instance
            .collection('diamond_categories')
            .where('isActive', isEqualTo: true)
            .get();
        proList = proSnap.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();
        proList.sort((a, b) =>
            ((a['priorityOrder'] as num?) ?? (a['displayOrder'] as num?) ?? 0)
                .compareTo((b['priorityOrder'] as num?) ?? (b['displayOrder'] as num?) ?? 0));
      } catch (proErr) {
        debugPrint('[ProviderCategorySelection] diamond_categories load error: $proErr');
      }

      if (mounted) {
        setState(() {
          _normalCategories = general;
          _premiumCategories = premium;
          _professionalCategories = proList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load categories. Please check connection and try again.';
        });
      }
    }
  }

  void _selectNormalCategory(ServiceCategoryModel cat, bool isPremium) {
    setState(() {
      _selectedCategoryId = cat.id;
      _selectedCategoryTitle = cat.titleEnglish.isNotEmpty ? cat.titleEnglish : cat.titleHindi;
      _selectedCategoryType = isPremium ? 'premium' : 'general';
      _selectedSubServices.clear();
      if (cat.subServices.isNotEmpty) {
        _selectedSubServices.add(cat.subServices.first);
      }
    });
  }

  void _selectProfessionalCategory(Map<String, dynamic> cat) {
    final catId = (cat['id'] as String?) ?? '';
    final titleEng = (cat['titleEnglish'] as String?) ??
        (cat['name'] as String?) ??
        (cat['title'] as String?) ??
        catId;
    setState(() {
      _selectedCategoryId = catId;
      _selectedCategoryTitle = titleEng;
      _selectedCategoryType = 'professional';
      _selectedSubServices.clear();
      _selectedSubServices.add(titleEng);
    });
  }

  Future<void> _handleContinue() async {
    if (_selectedCategoryId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a business category to continue'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final isPro = _selectedCategoryType == 'professional' || _selectedCategoryType == 'diamond';
      // Save draft category selection to Firestore providers/{uid}
      await FirebaseFirestore.instance.collection('providers').doc(widget.providerUid).set({
        'primaryCategoryId': _selectedCategoryId,
        'primaryCategoryTitle': _selectedCategoryTitle,
        'selectedCategoryId': _selectedCategoryId,
        'selectedCategoryIds': [_selectedCategoryId],
        'categoryType': _selectedCategoryType,
        'isProfessional': isPro,
        'isDiamond': isPro,
        'businessType': isPro ? 'professional_seller' : 'service_provider',
        'subServices': _selectedSubServices,
        'selectedService': _selectedSubServices.isNotEmpty ? _selectedSubServices.first : _selectedCategoryTitle,
        'currentStep': 2, // Step 2: Profile Setup
        'completedSteps': [0, 1],
        'registrationStatus': 'draft',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() => _isSaving = false);

      if (mounted) {
        ProviderAuthBloc? bloc;
        try {
          bloc = context.read<ProviderAuthBloc>();
        } catch (_) {}

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) {
              final setupPage = ProviderProfileSetupPage(
                providerUid: widget.providerUid,
                categoryId: _selectedCategoryId,
                categoryTitle: _selectedCategoryTitle,
                categoryType: _selectedCategoryType,
                subServices: _selectedSubServices,
              );
              if (bloc != null) {
                return BlocProvider.value(value: bloc, child: setupPage);
              }
              return setupPage;
            },
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save category: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
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
          onPressed: () => Navigator.pop(context),
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _themeGreen))
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_errorMessage!, style: const TextStyle(color: AppColors.error), textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _loadAllCategories,
                            style: ElevatedButton.styleFrom(backgroundColor: _themeGreen),
                            child: const Text('Try Again', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Business Category',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Step 2 of 3: Choose Your Service or Category',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Selected Category Banner
                        if (_selectedCategoryId.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _themeGreen.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: _themeGreen, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Selected: $_selectedCategoryTitle (${_selectedCategoryType.toUpperCase()})',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: _themeGreen),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                        ],

                        // ================= SECTION 1: NORMAL GENERAL CATEGORIES =================
                        const Row(
                          children: [
                            Icon(Icons.handyman_outlined, color: _themeGreen, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Standard Service Categories',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Home and technical services (Electrician, Plumber, Painter, etc.)',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 10),

                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _normalCategories.length,
                          itemBuilder: (context, index) {
                            final cat = _normalCategories[index];
                            final isSelected = _selectedCategoryId == cat.id && _selectedCategoryType == 'general';

                            return _buildCategoryCard(
                              title: cat.titleEnglish.isNotEmpty ? cat.titleEnglish : cat.titleHindi,
                              subtitle: cat.description,
                              icon: Icons.build_circle_outlined,
                              isSelected: isSelected,
                              onTap: () => _selectNormalCategory(cat, false),
                              tag: 'STANDARD',
                              tagColor: Colors.grey.shade700,
                            );
                          },
                        ),

                        // ================= SECTION 2: NORMAL PREMIUM CATEGORIES =================
                        if (_premiumCategories.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          const Row(
                            children: [
                              Icon(Icons.workspace_premium, color: Color(0xFFD4AF37), size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Premium Categories',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Premium salon, studio, and specialty businesses',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 10),

                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _premiumCategories.length,
                            itemBuilder: (context, index) {
                              final cat = _premiumCategories[index];
                              final isSelected = _selectedCategoryId == cat.id && _selectedCategoryType == 'premium';

                              return _buildCategoryCard(
                                title: cat.titleEnglish.isNotEmpty ? cat.titleEnglish : cat.titleHindi,
                                subtitle: cat.description,
                                icon: Icons.workspace_premium,
                                isSelected: isSelected,
                                onTap: () => _selectNormalCategory(cat, true),
                                tag: 'PREMIUM',
                                tagColor: const Color(0xFFD4AF37),
                              );
                            },
                          ),
                        ],

                        // ================= SECTION 3: PROFESSIONAL (PRO) CATEGORIES =================
                        const SizedBox(height: 20),
                        const Row(
                          children: [
                            Icon(Icons.storefront_rounded, color: _themeGreen, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Professional (Pro) Categories',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Shops and retail businesses (Grocery, Vegetables, Fruits, Retail, etc.)',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 10),

                        if (_professionalCategories.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline, color: Color(0xFF64748B), size: 18),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'No active professional shop categories found.',
                                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
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
                              final titleEng = (cat['titleEnglish'] as String?) ??
                                  (cat['name'] as String?) ??
                                  (cat['title'] as String?) ??
                                  catId;
                              final titleHin = (cat['titleHindi'] as String?) ?? (cat['nameHindi'] as String?) ?? '';
                              final desc = (cat['description'] as String?) ??
                                  (titleHin.isNotEmpty ? titleHin : 'Local store / retail business');
                              final isSelected = _selectedCategoryId == catId && (_selectedCategoryType == 'professional' || _selectedCategoryType == 'diamond');

                              return _buildCategoryCard(
                                title: titleEng,
                                subtitle: desc,
                                icon: Icons.storefront_rounded,
                                isSelected: isSelected,
                                onTap: () => _selectProfessionalCategory(cat),
                                tag: 'PRO',
                                tagColor: _themeGreen,
                              );
                            },
                          ),

                        const SizedBox(height: 28),

                        // Action Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _handleContinue,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _themeGreen,
                              disabledBackgroundColor: _themeGreen.withValues(alpha: 0.6),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text(
                                    'Next: Shop Details',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildCategoryCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required String tag,
    required Color tagColor,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? _themeGreen : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
      ),
      color: isSelected ? const Color(0xFFF1F8E9) : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: isSelected ? _themeGreen.withValues(alpha: 0.15) : Colors.grey.shade100,
                child: Icon(icon, color: isSelected ? _themeGreen : Colors.grey.shade700, size: 20),
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
                            title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isSelected ? _themeGreen : const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: tagColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(color: tagColor, fontSize: 9, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? _themeGreen : Colors.grey.shade400,
                    width: 2,
                  ),
                  color: isSelected ? _themeGreen : Colors.transparent,
                ),
                child: isSelected
                    ? const Center(child: Icon(Icons.check, size: 13, color: Colors.white))
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

