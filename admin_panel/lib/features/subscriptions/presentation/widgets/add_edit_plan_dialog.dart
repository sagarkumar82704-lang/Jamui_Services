import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class AddEditPlanDialog extends StatefulWidget {
  final Map<String, dynamic>? plan;
  final String defaultAudience;
  final String defaultTier;

  const AddEditPlanDialog({
    super.key,
    this.plan,
    this.defaultAudience = 'new_provider',
    this.defaultTier = 'normal',
  });

  static Future<void> show(
    BuildContext context, {
    Map<String, dynamic>? plan,
    String defaultAudience = 'new_provider',
    String defaultTier = 'normal',
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddEditPlanDialog(
        plan: plan,
        defaultAudience: defaultAudience,
        defaultTier: defaultTier,
      ),
    );
  }

  @override
  State<AddEditPlanDialog> createState() => _AddEditPlanDialogState();
}

class _AddEditPlanDialogState extends State<AddEditPlanDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _targetAudience; // 'new_provider' or 'existing_provider'
  late String _planTier; // 'normal' or 'premium'
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _durationController;
  late TextEditingController _categoryLimitController;
  late TextEditingController _featuresController;

  // Storage, Listing & Premium Quota Controllers
  late TextEditingController _maxListingsController;
  late TextEditingController _maxImagesController;
  late TextEditingController _maxImagesPerListingController;
  late TextEditingController _maxSizePerImageMbController;
  late TextEditingController _maxTotalStorageMbController;
  late TextEditingController _priorityController;
  bool _isPremiumCategoryEligible = false;

  // New Provider Specific
  bool _isPaymentMandatory = true;

  // Existing Provider Specific
  late TextEditingController _discountPercentageController;
  late TextEditingController _offerDescriptionController;
  late TextEditingController _gracePeriodController;

  bool _isPopular = false;
  bool _isActive = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.plan;
    _targetAudience = (p?['targetAudience'] as String?) ?? widget.defaultAudience;
    final rawTier = (p?['planTier'] as String?)?.trim().toLowerCase();
    _planTier = (rawTier == 'premium')
        ? 'premium'
        : (rawTier == 'normal'
            ? 'normal'
            : (widget.defaultTier.toLowerCase() == 'premium' ? 'premium' : 'normal'));
    _nameController = TextEditingController(text: p?['name'] ?? '');
    _priceController = TextEditingController(text: (p?['price'] ?? 199).toString());
    _durationController = TextEditingController(text: (p?['durationDays'] ?? 30).toString());
    _categoryLimitController = TextEditingController(text: (p?['categoryLimit'] ?? 1).toString());

    _maxListingsController = TextEditingController(text: (p?['maxActiveListings'] ?? 10).toString());
    _maxImagesController = TextEditingController(text: (p?['maxImagesPerProvider'] ?? 20).toString());
    _maxImagesPerListingController = TextEditingController(text: (p?['maxImagesPerListing'] ?? 5).toString());
    final sizeBytes = (p?['maxSizePerImageBytes'] as num?)?.toInt() ?? (5 * 1024 * 1024);
    _maxSizePerImageMbController = TextEditingController(text: (sizeBytes / (1024 * 1024)).round().toString());
    final storageBytes = (p?['maxTotalStorageBytes'] as num?)?.toInt() ?? (50 * 1024 * 1024);
    _maxTotalStorageMbController = TextEditingController(text: (storageBytes / (1024 * 1024)).round().toString());
    _priorityController = TextEditingController(text: (p?['displayPriority'] ?? 1).toString());
    _isPremiumCategoryEligible = p?['isPremiumCategoryEligible'] == true;

    _isPaymentMandatory = p?['isPaymentMandatory'] ?? true;
    _discountPercentageController = TextEditingController(text: (p?['discountPercentage'] ?? 0).toString());
    _offerDescriptionController = TextEditingController(text: p?['offerDescription'] ?? '');
    _gracePeriodController = TextEditingController(text: (p?['gracePeriodDays'] ?? 0).toString());

    final featuresList = p?['features'] as List<dynamic>? ?? [];
    _featuresController = TextEditingController(text: featuresList.join('\n'));

    _isPopular = p?['isPopular'] == true;
    _isActive = p?['isActive'] != false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _durationController.dispose();
    _categoryLimitController.dispose();
    _featuresController.dispose();
    _maxListingsController.dispose();
    _maxImagesController.dispose();
    _maxImagesPerListingController.dispose();
    _maxSizePerImageMbController.dispose();
    _maxTotalStorageMbController.dispose();
    _priorityController.dispose();
    _discountPercentageController.dispose();
    _offerDescriptionController.dispose();
    _gracePeriodController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);

    try {
      final features = _featuresController.text
          .split('\n')
          .map((f) => f.trim())
          .where((f) => f.isNotEmpty)
          .toList();

      final parsedPrice = double.tryParse(_priceController.text.trim());
      if (parsedPrice == null || parsedPrice <= 0) {
        throw Exception('कृपया मान्य प्लान मूल्य दर्ज करें (₹0 से अधिक)।');
      }

      final parsedDuration = int.tryParse(_durationController.text.trim());
      if (parsedDuration == null || parsedDuration <= 0) {
        throw Exception('कृपया मान्य सदस्यता अवधि (दिन) दर्ज करें (0 से अधिक)।');
      }

      final parsedCategoryLimit = int.tryParse(_categoryLimitController.text.trim());
      if (parsedCategoryLimit == null || parsedCategoryLimit <= 0) {
        throw Exception('कृपया मान्य श्रेणी सीमा दर्ज करें (कम-से-कम 1)।');
      }

      final maxListings = int.tryParse(_maxListingsController.text.trim()) ?? 10;
      final maxImages = int.tryParse(_maxImagesController.text.trim()) ?? 20;
      final maxImagesPerList = int.tryParse(_maxImagesPerListingController.text.trim()) ?? 5;
      final sizeMb = int.tryParse(_maxSizePerImageMbController.text.trim()) ?? 5;
      final storageMb = int.tryParse(_maxTotalStorageMbController.text.trim()) ?? 50;
      final priority = int.tryParse(_priorityController.text.trim()) ?? 1;

      final data = {
        'name': _nameController.text.trim(),
        'price': parsedPrice,
        'durationDays': parsedDuration,
        'categoryLimit': parsedCategoryLimit,
        'maxActiveListings': maxListings,
        'maxImagesPerProvider': maxImages,
        'maxImagesPerListing': maxImagesPerList,
        'maxSizePerImageBytes': sizeMb * 1024 * 1024,
        'maxTotalStorageBytes': storageMb * 1024 * 1024,
        'isPremiumCategoryEligible': _isPremiumCategoryEligible,
        'planTier': _planTier,
        'displayPriority': priority,
        'targetAudience': _targetAudience,
        'isPaymentMandatory': _targetAudience == 'new_provider' ? _isPaymentMandatory : false,
        'discountPercentage': _targetAudience == 'existing_provider' ? (double.tryParse(_discountPercentageController.text.trim()) ?? 0.0) : 0.0,
        'offerDescription': _targetAudience == 'existing_provider' ? _offerDescriptionController.text.trim() : '',
        'gracePeriodDays': _targetAudience == 'existing_provider' ? (int.tryParse(_gracePeriodController.text.trim()) ?? 0) : 0,
        'features': features,
        'isPopular': _isPopular,
        'isActive': _isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.plan != null && widget.plan!['id'] != null) {
        // Edit existing
        await FirebaseFirestore.instance
            .collection('subscription_plans')
            .doc(widget.plan!['id'])
            .update(data);
      } else {
        // Create new
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('subscription_plans').add(data);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('सब्सक्रिप्शन प्लान सफलतापूर्वक सहेजा गया! 🟢'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('प्लान सहेजने में त्रुटि: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.plan != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 580,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEdit ? 'सब्सक्रिप्शन प्लान संपादित करें' : 'नया सब्सक्रिप्शन प्लान जोड़ें',
                      style: AppTextStyles.h3.copyWith(fontSize: 18),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const Divider(height: 20),

                // 1. Plan Tier Selection (Normal vs Premium)
                const Text('योजना श्रेणी (Plan Tier: Normal vs Premium) *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _planTier = 'normal'),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                          decoration: BoxDecoration(
                            color: _planTier == 'normal' ? Colors.blueGrey.shade50 : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _planTier == 'normal' ? Colors.blueGrey.shade700 : Colors.grey.shade300,
                              width: _planTier == 'normal' ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.layers_rounded, size: 20, color: _planTier == 'normal' ? Colors.blueGrey.shade700 : Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Normal Plan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: _planTier == 'normal' ? Colors.blueGrey.shade900 : Colors.black87)),
                                    const Text('मानक सामान्य सेवा प्रदाता', style: TextStyle(fontSize: 10, color: Colors.black54)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _planTier = 'premium'),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                          decoration: BoxDecoration(
                            color: _planTier == 'premium' ? Colors.amber.shade50 : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _planTier == 'premium' ? Colors.amber.shade700 : Colors.grey.shade300,
                              width: _planTier == 'premium' ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.workspace_premium_rounded, size: 20, color: _planTier == 'premium' ? Colors.amber.shade700 : Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Premium Plan ⭐', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: _planTier == 'premium' ? Colors.amber.shade900 : Colors.black87)),
                                    const Text('उच्च प्राथमिकता / प्रीमियम', style: TextStyle(fontSize: 10, color: Colors.black54)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 2. Target Audience Selection (New vs Existing Provider)
                const Text('प्लान का प्रकार (Target Provider Type) *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _targetAudience = 'new_provider'),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                          decoration: BoxDecoration(
                            color: _targetAudience == 'new_provider' ? Colors.blue.shade50 : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _targetAudience == 'new_provider' ? Colors.blue.shade700 : Colors.grey.shade300,
                              width: _targetAudience == 'new_provider' ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.person_add_rounded, size: 20, color: _targetAudience == 'new_provider' ? Colors.blue.shade700 : Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('नए प्रोवाइडर (New)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: _targetAudience == 'new_provider' ? Colors.blue.shade900 : Colors.black87)),
                                    const Text('रजिस्ट्रेशन के तुरंत बाद', style: TextStyle(fontSize: 10, color: Colors.black54)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _targetAudience = 'existing_provider'),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                          decoration: BoxDecoration(
                            color: _targetAudience == 'existing_provider' ? Colors.amber.shade50 : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _targetAudience == 'existing_provider' ? Colors.amber.shade800 : Colors.grey.shade300,
                              width: _targetAudience == 'existing_provider' ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.autorenew_rounded, size: 20, color: _targetAudience == 'existing_provider' ? Colors.amber.shade800 : Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('पुराने प्रोवाइडर (Renewal)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: _targetAudience == 'existing_provider' ? Colors.amber.shade900 : Colors.black87)),
                                    const Text('मौजूदा / रिन्यूअल प्लान', style: TextStyle(fontSize: 10, color: Colors.black54)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Audience Specific Controls
                if (_targetAudience == 'new_provider') ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('रजिस्ट्रेशन के बाद पेमेंट अनिवार्य (Mandatory Payment)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      subtitle: const Text('पेमेंट सत्यापित होने के बाद ही एडमिन अप्रूवल हेतु सबमिट होगा', style: TextStyle(fontSize: 10.5, color: Colors.black54)),
                      value: _isPaymentMandatory,
                      onChanged: (v) => setState(() => _isPaymentMandatory = v),
                    ),
                  ),
                  const SizedBox(height: 14),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('पुराने प्रोवाइडर्स हेतु विशेष ऑफर व ग्रेस पीरियड', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.brown)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _discountPercentageController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'विशेष छूट (% Discount)',
                                  suffixText: '%',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _gracePeriodController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'ग्रेस पीरियड (Grace Days)',
                                  suffixText: 'दिन',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _offerDescriptionController,
                          decoration: const InputDecoration(
                            labelText: 'ऑफर विवरण (Special Offer Note)',
                            hintText: 'उदा. पुराने कारीगरों के लिए 15% विशेष छूट',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Plan Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'प्लान का नाम (Plan Name) *',
                    hintText: 'उदा. बेसिक स्टार्टर / प्रो रिन्यूअल / प्रीमियम वार्षिक',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'प्लान नाम आवश्यक है' : null,
                ),
                const SizedBox(height: 14),

                // Price, Duration & Category Limit
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: TextFormField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'कीमत (Price) *',
                          prefixText: '₹ ',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'कीमत आवश्यक है';
                          final val = double.tryParse(v.trim());
                          if (val == null || val <= 0) return 'मान्य मूल्य दर्ज करें (> ₹0)';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 4,
                      child: TextFormField(
                        controller: _durationController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'वैधता (Days) *',
                          suffixText: 'दिन',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'दिन आवश्यक हैं';
                          final val = int.tryParse(v.trim());
                          if (val == null || val <= 0) return 'मान्य दिन दर्ज करें (> 0)';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 4,
                      child: TextFormField(
                        controller: _categoryLimitController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'श्रेणी सीमा *',
                          suffixText: 'कैटगरी',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'सीमा आवश्यक है';
                          final val = int.tryParse(v.trim());
                          if (val == null || val <= 0) return 'कम-से-कम 1 श्रेणी आवश्यक है';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Storage, Listings & Premium Quotas Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.purple.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.cloud_upload_rounded, size: 18, color: Colors.purple.shade800),
                          const SizedBox(width: 8),
                          Text(
                            'लिस्टिंग, इमेज व स्टोरेज कोटा (Quotas & Limits)',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple.shade900),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _maxListingsController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'अधिकतम लिस्टिंग *',
                                suffixText: 'लिस्टिंग',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _maxImagesController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'कुल इमेज सीमा *',
                                suffixText: 'फोटो',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _maxImagesPerListingController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'प्रति लिस्टिंग इमेज *',
                                suffixText: 'फोटो',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _maxSizePerImageMbController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'प्रति फोटो साइज सीमा *',
                                suffixText: 'MB',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _maxTotalStorageMbController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'कुल स्टोरेज कोटा *',
                                suffixText: 'MB',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _priorityController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'प्राथमिकता क्रम *',
                                hintText: '1, 2, 3...',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('होमपेज प्रीमियम सर्विसेज पात्रता (Premium Category Eligible)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        subtitle: const Text('इस प्लान के प्रोवाइडर्स कस्टमर ऐप के होमपेज प्रीमियम सेक्शन में दिखेंगे', style: TextStyle(fontSize: 10.5, color: Colors.black54)),
                        value: _isPremiumCategoryEligible,
                        onChanged: (v) => setState(() => _isPremiumCategoryEligible = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Features list (Multi-line)
                TextFormField(
                  controller: _featuresController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'प्लान के फीचर्स (प्रति पंक्ति एक फीचर लिखें) *',
                    hintText: '100% डायरेक्ट लीड्स\n0% कमीशन\nजमुई में टॉप सर्च रैंकिंग\nवेरिफाइड बैच सपोर्ट',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'कम से कम एक फीचर लिखें' : null,
                ),
                const SizedBox(height: 14),

                // Is Popular Switch & Is Active Switch
                Row(
                  children: [
                    Expanded(
                      child: SwitchListTile(
                        title: const Text('Most Popular Tag', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        subtitle: const Text('हाइलाइटेड गोल्ड बैज', style: TextStyle(fontSize: 10)),
                        value: _isPopular,
                        onChanged: (v) => setState(() => _isPopular = v),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    Expanded(
                      child: SwitchListTile(
                        title: const Text('Active Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        subtitle: const Text('ऐप में दृश्यता', style: TextStyle(fontSize: 10)),
                        value: _isActive,
                        onChanged: (v) => setState(() => _isActive = v),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('रद्द करें')),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      ),
                      child: _isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(isEdit ? 'प्लान अपडेट करें' : 'प्लान बनाएं'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
