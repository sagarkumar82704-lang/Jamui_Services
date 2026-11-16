import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/r2_upload_service.dart';
import '../../../../core/utils/app_image_utils.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../../../core/widgets/photo_source_picker.dart';
import '../../../auth/domain/entities/provider_profile_entity.dart';
import '../../data/models/provider_listing_model.dart';

class AddEditListingPage extends StatefulWidget {
  final ProviderProfileEntity profile;
  final ProviderListingModel? existingListing;
  final Map<String, dynamic> planLimits;
  final Map<String, dynamic> storageUsage;
  final int currentActiveListingsCount;

  const AddEditListingPage({
    super.key,
    required this.profile,
    this.existingListing,
    required this.planLimits,
    required this.storageUsage,
    required this.currentActiveListingsCount,
  });

  @override
  State<AddEditListingPage> createState() => _AddEditListingPageState();
}

class _AddEditListingPageState extends State<AddEditListingPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final R2UploadService _r2Service = R2UploadService();

  String _listingType = 'service';
  String? _selectedCategoryId;
  String? _selectedCategoryName;
  bool _isActive = true;
  bool _isSaving = false;
  bool _isUploadingImage = false;

  final List<String> _images = [];
  final List<String> _storageKeys = [];
  List<Map<String, dynamic>> _categories = [];
  bool _isLoadingCategories = true;

  @override
  void initState() {
    super.initState();
    _initFields();
    _loadCategories();
  }

  void _initFields() {
    final existing = widget.existingListing;
    if (existing != null) {
      _titleController.text = existing.title;
      _priceController.text = existing.price > 0 ? existing.price.toStringAsFixed(0) : '';
      _descriptionController.text = existing.description;
      _listingType = existing.listingType;
      _selectedCategoryId = existing.categoryId;
      _selectedCategoryName = existing.categoryName;
      _isActive = existing.isActive;
      _images.addAll(existing.images);
      _storageKeys.addAll(existing.storageKeys);
    } else {
      _selectedCategoryId = widget.profile.primaryCategoryId;
      _selectedCategoryName = widget.profile.primaryCategoryTitle;
    }
  }

  Future<void> _loadCategories() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('categories')
          .where('isActive', isEqualTo: true)
          .get();

      final list = snap.docs.map((d) {
        final data = d.data();
        return {
          'id': d.id,
          'name': (data['name'] ?? data['title'] ?? 'Category').toString(),
        };
      }).toList();

      if (mounted) {
        setState(() {
          _categories = list;
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingCategories = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    final maxPerListing = (widget.planLimits['maxImagesPerListing'] as num?)?.toInt() ?? 2;
    final maxPerProvider = (widget.planLimits['maxImagesPerProvider'] as num?)?.toInt() ?? 3;
    final maxTotalBytes = (widget.planLimits['maxTotalStorageBytes'] as num?)?.toInt() ?? (6 * 1024 * 1024);
    final maxSizePerImage = (widget.planLimits['maxSizePerImageBytes'] as num?)?.toInt() ?? (2 * 1024 * 1024);

    final totalImagesCount = (widget.storageUsage['totalImagesCount'] as num?)?.toInt() ?? 0;
    final totalBytesUsed = (widget.storageUsage['totalBytesUsed'] as num?)?.toInt() ?? 0;

    // Check count limits
    if (_images.length >= maxPerListing) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ प्रति लिस्टिंग अधिकतम $maxPerListing फ़ोटो की अनुमति है।'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (totalImagesCount >= maxPerProvider) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ आपके प्लान में अधिकतम $maxPerProvider फ़ोटोज़ की अनुमति पूरी हो चुकी है। पुरानी फ़ोटो हटाएं या प्लान अपग्रेड करें।'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    PhotoSourcePicker.show(
      context,
      title: 'लिस्टिंग फ़ोटो जोड़ें',
      enableCrop: false,
      isCircle: false,
      onImagePickedWithBytes: (path, bytes) async {
        if (bytes == null || bytes.isEmpty) return;
        await _uploadImageBytes(bytes, maxSizePerImage, maxTotalBytes, totalBytesUsed);
      },
      onImagePicked: (path) {},
    );
  }

  Future<void> _uploadImageBytes(
    Uint8List bytes,
    int maxSingleSizeBytes,
    int maxTotalBytes,
    int totalBytesUsed,
  ) async {
    if (bytes.length > maxSingleSizeBytes) {
      final mb = (maxSingleSizeBytes / (1024 * 1024)).toStringAsFixed(1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ फ़ोटो का साइज़ $mb MB से अधिक है। कृपया छोटी फ़ोटो चुनें।'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if ((totalBytesUsed + bytes.length) > maxTotalBytes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ स्टोरेज कोटा सीमा समाप्त हो गई है। कृपया प्लान अपग्रेड करें।'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isUploadingImage = true);

    try {
      final fileName = 'listing_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final listingId = widget.existingListing?.id ?? 'temp_${DateTime.now().millisecondsSinceEpoch}';

      final result = await _r2Service.uploadBytes(
        bytes: bytes,
        folder: 'listings',
        fileName: fileName,
        mimeType: 'image/jpeg',
        targetId: listingId,
      );

      setState(() {
        _images.add(result.objectKey);
        _storageKeys.add(result.objectKey);
        _isUploadingImage = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ फ़ोटो सफलतापूर्वक सुरक्षित अपलोड हो गई!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploadingImage = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('फ़ोटो अपलोड विफल: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteImage(int index) async {
    final key = _images[index];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('फ़ोटो हटाएं?'),
        content: const Text('क्या आप वाकई इस फ़ोटो को क्लाउड स्टोरेज से हमेशा के लिए हटाना चाहते हैं? यह क्रिया आपका स्टोरेज कोटा मुक्त कर देगी।'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('रद्द करें')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('हटाएं', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _r2Service.deleteStorageObject(
        objectKey: key,
        folder: 'listings',
        listingId: widget.existingListing?.id,
      );

      setState(() {
        _images.removeAt(index);
        _storageKeys.remove(key);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ फ़ोटो स्टोरेज से हटा दी गई।'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('डिलीशन विफल: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _saveListing() async {
    if (!_formKey.currentState!.validate()) return;

    final title = _titleController.text.trim();
    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
    final description = _descriptionController.text.trim();

    if (_selectedCategoryId == null || _selectedCategoryId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('कृपया श्रेणी चुनें'), backgroundColor: AppColors.warning),
      );
      return;
    }

    // Check active listing quota limit for new active listing
    if (widget.existingListing == null && _isActive) {
      final maxListings = (widget.planLimits['maxActiveListings'] as num?)?.toInt() ?? 1;
      if (widget.currentActiveListingsCount >= maxListings) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ एक्टिव लिस्टिंग सीमा ($maxListings) पूरी हो चुकी है। कृपया प्लान अपग्रेड करें।'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final providerName = widget.profile.businessName.isNotEmpty
          ? widget.profile.businessName
          : widget.profile.fullName;

      final data = <String, dynamic>{
        'providerId': widget.profile.id,
        'providerName': providerName,
        'providerPhone': widget.profile.phoneNumber,
        'title': title,
        'description': description,
        'listingType': _listingType,
        'categoryId': _selectedCategoryId,
        'categoryName': _selectedCategoryName ?? '',
        'price': price,
        'images': _images,
        'storageKeys': _storageKeys,
        'isActive': _isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.existingListing == null) {
        data['status'] = 'pending_review';
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('provider_listings').add(data);
      } else {
        await FirebaseFirestore.instance
            .collection('provider_listings')
            .doc(widget.existingListing!.id)
            .update(data);
      }

      setState(() => _isSaving = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existingListing == null
                ? '✓ लिस्टिंग सबमिट हो गई! एडमिन समीक्षा के बाद लाइव होगी।'
                : '✓ लिस्टिंग विवरण अपडेट हो गया!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('सेव करने में विफल: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxImages = (widget.planLimits['maxImagesPerListing'] as num?)?.toInt() ?? 2;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingListing == null ? 'नया लिस्टिंग जोड़ें' : 'लिस्टिंग संपादित करें'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        child: ResponsiveFormShell(
          maxWidth: 680,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Listing Type Selector (Service, Product, Job)
                const Text('लिस्टिंग प्रकार (Listing Type) *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'service', label: Text('सर्विस (Service)'), icon: Icon(Icons.handyman_outlined, size: 16)),
                        ButtonSegment(value: 'product', label: Text('उत्पाद (Product)'), icon: Icon(Icons.shopping_bag_outlined, size: 16)),
                        ButtonSegment(value: 'job', label: Text('नौकरी (Job)'), icon: Icon(Icons.work_outline, size: 16)),
                      ],
                      selected: {_listingType},
                      onSelectionChanged: (set) => setState(() => _listingType = set.first),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: _listingType == 'job' ? 'जॉब रोल / पद का नाम *' : 'शीर्षक / सर्विस का नाम *',
                    hintText: _listingType == 'job' ? 'उदा: इलेक्ट्रीशियन हेल्पर आवश्यक' : 'उदा: RO वाटर प्यूरीफायर सर्विसिंग',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (val) => (val == null || val.trim().isEmpty) ? 'शीर्षक अनिवार्य है' : null,
                ),
                const SizedBox(height: 14),

                // Category Selector
                if (_isLoadingCategories)
                  const LinearProgressIndicator()
                else
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategoryId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'सर्विस श्रेणी (Category) *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _categories.map((c) {
                      return DropdownMenuItem<String>(
                        value: c['id'].toString(),
                        child: Text(
                          c['name'].toString(),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedCategoryId = val;
                        final match = _categories.firstWhere((c) => c['id'] == val, orElse: () => {'name': ''});
                        _selectedCategoryName = match['name'];
                      });
                    },
                  ),
              const SizedBox(height: 14),

              // Price / Salary
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _listingType == 'job' ? 'वेतन / मासिक सैलरी (₹)' : 'मूल्य / सर्विस चार्ज (₹) *',
                  prefixText: '₹ ',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'शुल्क अनिवार्य है';
                  if (double.tryParse(val) == null) return 'अमान्य राशि';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Description
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'विस्तृत विवरण (Description)',
                  hintText: 'अपनी सेवा, उत्पाद या कार्य शर्तों के बारे में जानकारी दें...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),

              // Images Gallery Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'फ़ोटोज़ (${_images.length}/$maxImages)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  if (_images.length < maxImages)
                    TextButton.icon(
                      onPressed: _isUploadingImage ? null : _pickAndUploadImage,
                      icon: _isUploadingImage
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.add_photo_alternate_rounded, size: 18),
                      label: Text(_isUploadingImage ? 'अपलोडिंग...' : 'फ़ोटो जोड़ें'),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              if (_images.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.photo_library_outlined, size: 36, color: Colors.grey.shade400),
                      const SizedBox(height: 6),
                      Text('कोई फ़ोटो नहीं जोड़ी गई', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      Text('अधिकतम $maxImages फ़ोटो अपलोड कर सकते हैं', style: TextStyle(color: Colors.grey.shade400, fontSize: 10.5)),
                    ],
                  ),
                )
              else
                SizedBox(
                  height: 90,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _images.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, idx) {
                      final imgUrl = _images[idx];
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 90,
                              height: 90,
                              child: AppImageUtils.buildImage(imgUrl, fit: BoxFit.cover),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: InkWell(
                              onTap: () => _deleteImage(idx),
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                child: const Icon(Icons.close, size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),

              // Active Toggle
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('लिस्टिंग सक्रिय रखें (Active)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: const Text('सक्रिय रहने पर ही यह ग्राहकों को दिखाई देगी', style: TextStyle(fontSize: 11)),
                value: _isActive,
                activeThumbColor: AppColors.success,
                onChanged: (val) => setState(() => _isActive = val),
              ),
              const SizedBox(height: 24),

              // Save Button
              ElevatedButton(
                onPressed: _isSaving ? null : _saveListing,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        widget.existingListing == null ? 'लिस्टिंग सबमिट करें' : 'बदलाव सुरक्षित करें',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
