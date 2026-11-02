import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_network_or_base64_image.dart';
import '../../../../core/utils/admin_placeholder_images.dart';
import '../../../categories/presentation/widgets/universal_image_picker.dart';
import '../../data/datasources/banner_storage_remote_data_source.dart';
import '../../data/models/admin_banner_model.dart';
import '../../domain/entities/admin_banner_entity.dart';

class AddEditBannerDialog extends StatefulWidget {
  final AdminBannerEntity? banner;
  final Function(AdminBannerModel) onSave;

  const AddEditBannerDialog({
    super.key,
    this.banner,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    AdminBannerEntity? banner,
    required Function(AdminBannerModel) onSave,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddEditBannerDialog(banner: banner, onSave: onSave),
    );
  }

  @override
  State<AddEditBannerDialog> createState() => _AddEditBannerDialogState();
}

class _AddEditBannerDialogState extends State<AddEditBannerDialog> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;

  late TextEditingController _sponsorController;
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _imageUrlInputController;
  late TextEditingController _ctaController;
  late TextEditingController _targetIdController;
  late TextEditingController _priorityController;

  AdminBannerTargetType _targetType = AdminBannerTargetType.url;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isActive = true;
  bool _isSponsored = true;
  bool _isSaving = false;
  String _uploadStatus = '';

  // Dual Image Support: Laptop Upload vs Web Link
  int _imageSourceMode = 0; // 0 = Laptop Upload, 1 = Web URL
  Uint8List? _selectedImageBytes;
  String? _selectedImageFileName;
  String? _selectedImageMimeType;
  String _currentImageUrl = '';

  // Temporary Placeholder Preview State (Strictly for preview - never saved to Firestore)
  AdminPlaceholderItem? _activePlaceholder;
  bool _isPlaceholderPreviewActive = false;

  final BannerStorageRemoteDataSource _storageDataSource = R2BannerStorageRemoteDataSource();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    final b = widget.banner;
    _sponsorController = TextEditingController(text: b?.sponsorName ?? '');
    _titleController = TextEditingController(text: b?.title ?? '');
    _descController = TextEditingController(text: b?.description ?? '');
    _currentImageUrl = b?.imageUrl ?? '';
    _imageUrlInputController = TextEditingController(text: b?.imageUrl ?? '');
    _ctaController = TextEditingController(text: b?.ctaText ?? 'ऑफ़र देखें');
    _targetIdController = TextEditingController(text: b?.targetId ?? '');
    _priorityController = TextEditingController(text: (b?.priority ?? 1).toString());

    _targetType = b?.targetType ?? AdminBannerTargetType.url;
    _startDate = b?.startAt ?? DateTime.now();
    _endDate = b?.endAt ?? DateTime.now().add(const Duration(days: 30));
    _isActive = b?.isActive ?? true;
    _isSponsored = b?.isSponsored ?? true;

    // If existing banner has URL, default image source tab to web link
    if (_currentImageUrl.isNotEmpty) {
      _imageSourceMode = 1;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _sponsorController.dispose();
    _titleController.dispose();
    _descController.dispose();
    _imageUrlInputController.dispose();
    _ctaController.dispose();
    _targetIdController.dispose();
    _priorityController.dispose();
    super.dispose();
  }

  Future<bool> _confirmReplaceBannerImage({String? title, String? message}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.help_outline_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(title ?? 'मौजूदा बैनर बदलें?'),
          ],
        ),
        content: Text(
          message ?? 'क्या आप वाकई इस बैनर की मौजूदा इमेज को बदलना चाहते हैं? मूल इमेज संदर्भ सुरक्षित रखने के लिए पुष्टि करें।',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('रद्द करें (Cancel)'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('हाँ, बदलें (Proceed)', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _previewRandomPlaceholder() async {
    if (_currentImageUrl.isNotEmpty && !_isPlaceholderPreviewActive) {
      final confirmed = await _confirmReplaceBannerImage(
        title: 'डेमो प्लेसहोल्डर प्रिव्यू',
        message: 'क्या आप अस्थायी डेमो बैनर प्रिव्यू देखना चाहते हैं? आपकी मूल इमेज सुरक्षित रहेगी और डेटाबेस में तभी नई इमेज सेव होगी जब आप फ़ाइल अपलोड करेंगे।',
      );
      if (!confirmed) return;
    }
    setState(() {
      _activePlaceholder = AdminPlaceholderImages.getRandomBannerPlaceholder(excludeId: _activePlaceholder?.id);
      _isPlaceholderPreviewActive = true;
      _selectedImageBytes = null;
      _selectedImageFileName = null;
    });
  }

  void _revertPlaceholder() {
    setState(() {
      _isPlaceholderPreviewActive = false;
      _activePlaceholder = null;
    });
  }

  Future<void> _pickImageFromLaptop() async {
    if (_currentImageUrl.isNotEmpty && _selectedImageBytes == null && !_isPlaceholderPreviewActive) {
      final confirmed = await _confirmReplaceBannerImage(
        title: 'मौजूदा बैनर इमेज बदलें?',
        message: 'क्या आप इस बैनर की मौजूदा इमेज को नई फ़ाइल से बदलना चाहते हैं?',
      );
      if (!confirmed) return;
    }

    try {
      final picked = await UniversalImagePicker.pickImage();
      if (picked != null) {
        setState(() {
          _selectedImageBytes = picked.bytes;
          _selectedImageFileName = picked.fileName;
          _selectedImageMimeType = picked.mimeType;
          _imageSourceMode = 0;
          _isPlaceholderPreviewActive = false;
          _activePlaceholder = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('इमेज चुनने में त्रुटि: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      _tabController.animateTo(0);
      return;
    }

    final hasLaptopImage = _selectedImageBytes != null && _selectedImageBytes!.isNotEmpty;
    final hasUrlImage = _imageUrlInputController.text.trim().isNotEmpty;
    final hasExistingImage = _currentImageUrl.trim().isNotEmpty;
    final hasPlaceholder = _isPlaceholderPreviewActive;

    if (!hasLaptopImage && !hasUrlImage && !hasExistingImage && !hasPlaceholder) {
      _tabController.animateTo(1);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('कृपया लैपटॉप से इमेज अपलोड करें या इमेज URL दर्ज करें!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _uploadStatus = 'डेटा तैयार किया जा रहा है...';
    });

    String finalImageUrl = _currentImageUrl;

    // 1. If new image chosen from laptop, upload to Cloudflare R2 (R2-ONLY)
    if (hasLaptopImage) {
      try {
        setState(() => _uploadStatus = 'Cloudflare R2 में इमेज अपलोड हो रही है...');
        final bannerId = widget.banner?.id.isNotEmpty == true
            ? widget.banner!.id
            : 'banner_${DateTime.now().millisecondsSinceEpoch}';

        // Direct R2 upload via R2UploadService - ZERO Firebase Storage upload
        final uploadResult = await _storageDataSource.uploadBannerImage(
          bannerId: bannerId,
          bytes: _selectedImageBytes!,
          fileName: _selectedImageFileName ?? 'banner.jpg',
          mimeType: _selectedImageMimeType,
        );

        finalImageUrl = uploadResult.downloadUrl; // Canonical relative R2 objectKey
      } catch (r2Error) {
        debugPrint('❌ R2 Banner upload error: $r2Error');
        setState(() {
          _isSaving = false;
        });
        if (mounted) {
          final errorMsg = r2Error.toString().replaceFirst('Exception: ', '');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: Colors.red,
            ),
          );
        }
        return; // STOP! Never write broken key, never fallback to Firebase Storage, preserve existing image!
      }
    } else if (_isPlaceholderPreviewActive) {
      // STRICT SAFETY RULE: Placeholder is for preview ONLY - NEVER save to Firestore!
      // Preserve existing saved image
      finalImageUrl = _currentImageUrl;
    } else if (_imageSourceMode == 1 && hasUrlImage) {
      finalImageUrl = _imageUrlInputController.text.trim();
    }

    setState(() => _uploadStatus = 'बैनर सहेजा जा रहा है...');

    final model = AdminBannerModel(
      id: widget.banner?.id ?? '',
      sponsorName: _sponsorController.text.trim(),
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      imageUrl: finalImageUrl,
      ctaText: _ctaController.text.trim().isNotEmpty ? _ctaController.text.trim() : 'ऑफ़र देखें',
      targetType: _targetType,
      targetId: _targetIdController.text.trim(),
      startAt: _startDate,
      endAt: _endDate,
      priority: int.tryParse(_priorityController.text.trim()) ?? 1,
      isActive: _isActive,
      isSponsored: _isSponsored,
      impressions: widget.banner?.impressions ?? 0,
      clicks: widget.banner?.clicks ?? 0,
    );

    widget.onSave(model);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.banner != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 780,
        height: 680,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.campaign_outlined, color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEdit ? 'प्रायोजित बैनर संपादित करें' : 'नया प्रायोजित बैनर जोड़ें (Sponsor Banner)',
                            style: AppTextStyles.h3.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'लैपटॉप से फोटो या वेब लिंक और टारगेट एक्शन सेट करें',
                            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Tab Navigation
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey.shade700,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  tabs: const [
                    Tab(icon: Icon(Icons.info_outline, size: 16), text: '1. स्पॉन्सर विवरण'),
                    Tab(icon: Icon(Icons.image_outlined, size: 16), text: '2. इमेज (लैपटॉप / लिंक)'),
                    Tab(icon: Icon(Icons.link, size: 16), text: '3. एक्शन व लिंक'),
                    Tab(icon: Icon(Icons.preview, size: 16), text: '4. कार्ड प्रिव्यू व समय'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTab1BasicInfo(),
                    _buildTab2ImagePicker(),
                    _buildTab3ActionAndLinks(),
                    _buildTab4PreviewAndSchedule(),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Footer Actions
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_uploadStatus.isNotEmpty)
                    Row(
                      children: [
                        const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        const SizedBox(width: 8),
                        Text(_uploadStatus, style: const TextStyle(fontSize: 12, color: AppColors.primary)),
                      ],
                    )
                  else
                    const SizedBox.shrink(),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('रद्द करें'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _isSaving ? null : _submit,
                        icon: _isSaving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.check, size: 18),
                        label: Text(isEdit ? 'परिवर्तन सहेजें' : 'बैनर प्रकाशित करें'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // TAB 1: BASIC INFO & SPONSOR
  Widget _buildTab1BasicInfo() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _sponsorController,
                  decoration: const InputDecoration(
                    labelText: 'प्रायोजक / व्यापार का नाम (Sponsor / Business Name) *',
                    hintText: 'उदा. राज इलेक्ट्रॉनिक्स जमुई / शिवम फर्नीचर',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.storefront_outlined),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'प्रायोजक का नाम आवश्यक है' : null,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SwitchListTile(
                    title: const Text('Sponsored Badge', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    subtitle: const Text('बैनर पर "प्रायोजित" टैग दिखाएं', style: TextStyle(fontSize: 10)),
                    value: _isSponsored,
                    onChanged: (v) => setState(() => _isSponsored = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'बैनर मुख्य शीर्षक (Banner Title / Headline) *',
              hintText: 'उदा. स्पेशल समर AC सर्विस पर 20% तक की भारी छूट!',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.title_outlined),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'शीर्षक आवश्यक है' : null,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _descController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'बैनर विवरण / सबटाइटल (Subtitle / Offer Highlights)',
              hintText: 'उदा. जमुई के नंबर 1 सर्टिफाइड टेक्नीशियन द्वारा 100% गारंटीड सर्विस।',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.description_outlined),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _priorityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'प्राथमिकता क्रम (Priority: 1 = सबसे पहले)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.format_list_numbered),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SwitchListTile(
                    title: const Text('स्थिति (Status: Active)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    subtitle: const Text('अक्षम करने पर ऐप में नहीं दिखेगा', style: TextStyle(fontSize: 10)),
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // TAB 2: DUAL IMAGE PICKER (LAPTOP FILE UPLOAD & WEB URL)
  Widget _buildTab2ImagePicker() {
    final hasSelectedBytes = _selectedImageBytes != null && _selectedImageBytes!.isNotEmpty;
    final hasExistingUrl = _currentImageUrl.trim().isNotEmpty;
    final hasUrlInput = _imageUrlInputController.text.trim().isNotEmpty;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Source Switcher (Laptop Upload vs Web URL)
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _imageSourceMode = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _imageSourceMode == 0 ? AppColors.primary.withValues(alpha: 0.1) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _imageSourceMode == 0 ? AppColors.primary : Colors.grey.shade300,
                        width: _imageSourceMode == 0 ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.laptop_chromebook, color: _imageSourceMode == 0 ? AppColors.primary : Colors.grey.shade700),
                        const SizedBox(width: 8),
                        Text(
                          '💻 लैपटॉप / PC से फोटो अपलोड',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: _imageSourceMode == 0 ? AppColors.primary : Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _imageSourceMode = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _imageSourceMode == 1 ? AppColors.primary.withValues(alpha: 0.1) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _imageSourceMode == 1 ? AppColors.primary : Colors.grey.shade300,
                        width: _imageSourceMode == 1 ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.link, color: _imageSourceMode == 1 ? AppColors.primary : Colors.grey.shade700),
                        const SizedBox(width: 8),
                        Text(
                          '🔗 इमेज वेब लिंक (Web / CDN URL)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: _imageSourceMode == 1 ? AppColors.primary : Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // MODE 0: LAPTOP FILE PICKER
          if (_imageSourceMode == 0) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
              ),
              child: Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickImageFromLaptop,
                    icon: const Icon(Icons.file_upload_outlined, size: 20),
                    label: const Text('फ़ाइल चुनें (Choose Image File)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasSelectedBytes
                              ? 'चयनित फ़ाइल: ${_selectedImageFileName ?? "Image selected"} (${(_selectedImageBytes!.lengthInBytes / 1024).toStringAsFixed(1)} KB)'
                              : (_isPlaceholderPreviewActive
                                  ? 'डेमो प्लेसहोल्डर प्रिव्यू सक्रिय'
                                  : (hasExistingUrl ? 'वर्तमान इमेज पहले से सुरक्षित है' : 'कोई फ़ाइल चयनित नहीं है (JPG, PNG, WebP)')),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: hasSelectedBytes ? FontWeight.bold : FontWeight.normal,
                            color: hasSelectedBytes ? Colors.green.shade700 : (_isPlaceholderPreviewActive ? Colors.amber.shade800 : Colors.grey.shade700),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Cloudflare R2 में सुरक्षित अपलोड होकर कस्टमर ऐप में दिखेगा (शून्य स्टोरेज लागत)',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _previewRandomPlaceholder,
                              icon: const Icon(Icons.shuffle_rounded, size: 16, color: Colors.deepPurple),
                              label: const Text('🎲 रैंडम डेमो बैनर', style: TextStyle(fontSize: 12, color: Colors.deepPurple, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.deepPurple),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                            if (_isPlaceholderPreviewActive)
                              TextButton.icon(
                                onPressed: _revertPlaceholder,
                                icon: const Icon(Icons.undo_rounded, size: 16, color: Colors.teal),
                                label: const Text('↩️ मूल बैनर वापस लाएं', style: TextStyle(fontSize: 12, color: Colors.teal)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (hasSelectedBytes)
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      tooltip: 'हटाएं',
                      onPressed: () {
                        setState(() {
                          _selectedImageBytes = null;
                          _selectedImageFileName = null;
                        });
                      },
                    ),
                ],
              ),
            ),
          ] else ...[
            // MODE 1: WEB URL INPUT
            TextFormField(
              controller: _imageUrlInputController,
              decoration: InputDecoration(
                labelText: 'बैनर इमेज URL (Direct Web Image Link) *',
                hintText: 'https://images.unsplash.com/... या Firebase Storage URL',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.image_outlined),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _imageUrlInputController.clear();
                    setState(() {});
                  },
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: 20),

          // Live Image Preview Box Header with Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('इमेज लाइव प्रिव्यू (Aspect Ratio 16:9 / 2:1):', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold, fontSize: 13)),
              if (hasSelectedBytes)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.green.shade300)),
                  child: const Text('⚡ R2 अपलोड प्रतीक्षारत', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
                )
              else if (_isPlaceholderPreviewActive && _activePlaceholder != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.amber.shade400)),
                  child: const Text('⚠️ डेमो प्रिव्यू - Not Saved', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber)),
                )
              else if (hasExistingUrl)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.blue.shade200)),
                  child: const Text('✓ सहेजा गया बैनर', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (_isPlaceholderPreviewActive && _activePlaceholder != null) ? Colors.amber.shade500 : Colors.grey.shade300,
                width: (_isPlaceholderPreviewActive && _activePlaceholder != null) ? 2 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: hasSelectedBytes
                ? Image.memory(_selectedImageBytes!, fit: BoxFit.cover)
                : (_isPlaceholderPreviewActive && _activePlaceholder != null
                    ? AdminPlaceholderImages.buildPlaceholderWidget(
                        placeholder: _activePlaceholder!,
                        height: 180,
                        isBanner: true,
                      )
                    : (_imageSourceMode == 1 && hasUrlInput
                        ? AppNetworkOrBase64Image(
                            imageUrl: _imageUrlInputController.text.trim(),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image, color: Colors.grey, size: 36),
                                  SizedBox(height: 6),
                                  Text('इमेज लोड नहीं हो सकी। कृपया वैध URL जांचें।', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                ],
                              ),
                            ),
                          )
                        : (hasExistingUrl
                            ? AppNetworkOrBase64Image(
                                imageUrl: _currentImageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const Center(
                                  child: Icon(Icons.broken_image, color: Colors.grey, size: 36),
                                ),
                              )
                            : const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.image, size: 48, color: Colors.grey),
                                    SizedBox(height: 6),
                                    Text('लैपटॉप से फ़ाइल चुनें या रैंडम डेमो प्रिव्यू देखें', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  ],
                                ),
                              )))),
          ),
        ],
      ),
    );
  }

  // TAB 3: ACTION & REDIRECT LINKS
  Widget _buildTab3ActionAndLinks() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<AdminBannerTargetType>(
                  initialValue: _targetType,
                  decoration: const InputDecoration(
                    labelText: 'क्लिक करने पर एक्शन (Target Action Type) *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.touch_app_outlined),
                  ),
                  items: AdminBannerTargetType.values.map((t) {
                    return DropdownMenuItem(value: t, child: Text(t.label, style: const TextStyle(fontSize: 13)));
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _targetType = v;
                        if (_targetType == AdminBannerTargetType.url && _targetIdController.text.isEmpty) {
                          _targetIdController.text = 'https://';
                        }
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: TextFormField(
                  controller: _ctaController,
                  decoration: const InputDecoration(
                    labelText: 'बटन टेक्स्ट (CTA Button Label)',
                    hintText: 'उदा. ऑफ़र देखें / कॉल करें / बुक करें',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _targetIdController,
            decoration: InputDecoration(
              labelText: _getTargetLabel(),
              hintText: _getTargetPlaceholder(),
              border: const OutlineInputBorder(),
              prefixIcon: Icon(_getTargetIcon()),
            ),
            validator: (v) {
              if (_targetType == AdminBannerTargetType.url && (v == null || !v.startsWith('http'))) {
                return 'कृपया वैध लिंक (https://...) दर्ज करें';
              }
              return null;
            },
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          // Quick Preset Shortcuts for Redirects
          Text('त्वरित लिंक शॉर्टकट्स (Quick Shortcuts):', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildShortcutChip('🌐 वेबसाइट लिंक', () {
                setState(() {
                  _targetType = AdminBannerTargetType.url;
                  _targetIdController.text = 'https://';
                  _ctaController.text = 'वेबसाइट देखें';
                });
              }),
              _buildShortcutChip('💬 व्हाट्सएप चैट लिंक', () {
                setState(() {
                  _targetType = AdminBannerTargetType.url;
                  _targetIdController.text = 'https://wa.me/91';
                  _ctaController.text = 'व्हाट्सएप करें';
                });
              }),
              _buildShortcutChip('📞 सीधा फ़ोन कॉल', () {
                setState(() {
                  _targetType = AdminBannerTargetType.url;
                  _targetIdController.text = 'tel:+91';
                  _ctaController.text = 'अभी कॉल करें';
                });
              }),
              _buildShortcutChip('⚡ इलेक्ट्रीशियन कैटेगरी', () {
                setState(() {
                  _targetType = AdminBannerTargetType.category;
                  _targetIdController.text = 'electrician';
                  _ctaController.text = 'सर्विस बुक करें';
                });
              }),
              _buildShortcutChip('🔧 प्लंबर कैटेगरी', () {
                setState(() {
                  _targetType = AdminBannerTargetType.category;
                  _targetIdController.text = 'plumber';
                  _ctaController.text = 'सर्विस बुक करें';
                });
              }),
              _buildShortcutChip('❄️ एसी रिपेयर कैटेगरी', () {
                setState(() {
                  _targetType = AdminBannerTargetType.category;
                  _targetIdController.text = 'appliance';
                  _ctaController.text = 'सर्विस बुक करें';
                });
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      ),
    );
  }

  String _getTargetLabel() {
    switch (_targetType) {
      case AdminBannerTargetType.url:
        return 'वेबसाइट / व्हाट्सएप / कॉल URL (https:// / tel:) *';
      case AdminBannerTargetType.category:
        return 'कैटेगरी ID / Slug (उदा. electrician, plumber) *';
      case AdminBannerTargetType.provider:
        return 'कारीगर (Provider) Firebase UID *';
      case AdminBannerTargetType.service:
        return 'विशिष्ट सब-सर्विस नाम *';
      default:
        return 'आंतरिक स्क्रीन या पेज नाम *';
    }
  }

  String _getTargetPlaceholder() {
    switch (_targetType) {
      case AdminBannerTargetType.url:
        return 'https://example.com या https://wa.me/919876543210';
      case AdminBannerTargetType.category:
        return 'electrician / plumber / appliance / carpenter';
      case AdminBannerTargetType.provider:
        return 'provider_firebase_uid';
      default:
        return 'होम स्क्रीन / सर्च पेज';
    }
  }

  IconData _getTargetIcon() {
    switch (_targetType) {
      case AdminBannerTargetType.url:
        return Icons.language;
      case AdminBannerTargetType.category:
        return Icons.category_outlined;
      case AdminBannerTargetType.provider:
        return Icons.engineering_outlined;
      default:
        return Icons.open_in_new;
    }
  }

  // TAB 4: LIVE PREVIEW & SCHEDULE
  Widget _buildTab4PreviewAndSchedule() {
    final hasSelectedBytes = _selectedImageBytes != null && _selectedImageBytes!.isNotEmpty;
    final hasUrlInput = _imageUrlInputController.text.trim().isNotEmpty;
    final hasExistingUrl = _currentImageUrl.trim().isNotEmpty;

    final titleText = _titleController.text.trim().isNotEmpty ? _titleController.text.trim() : 'स्पेशल समर AC सर्विस पर 20% छूट';
    final descText = _descController.text.trim().isNotEmpty ? _descController.text.trim() : 'जमुई के सर्टिफाइड टेक्नीशियन द्वारा 100% गारंटीड सर्विस।';
    final ctaText = _ctaController.text.trim().isNotEmpty ? _ctaController.text.trim() : 'ऑफ़र देखें';
    final sponsorText = _sponsorController.text.trim().isNotEmpty ? _sponsorController.text.trim() : 'राज इलेक्ट्रॉनिक्स';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('कस्टमर ऐप में लाइव कार्ड कैसा दिखेगा (Mobile App Live Card Preview):', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 10),

          // Banner Card Mockup
          Container(
            height: 156,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withValues(alpha: 0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  // Background Image
                  if (hasSelectedBytes)
                    Positioned.fill(
                      child: Image.memory(_selectedImageBytes!, fit: BoxFit.cover),
                    )
                  else if (_imageSourceMode == 1 && hasUrlInput)
                    Positioned.fill(
                      child: AppNetworkOrBase64Image(imageUrl: _imageUrlInputController.text.trim(), fit: BoxFit.cover),
                    )
                  else if (hasExistingUrl)
                    Positioned.fill(
                      child: AppNetworkOrBase64Image(imageUrl: _currentImageUrl, fit: BoxFit.cover),
                    ),

                  // Overlay
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.80),
                            Colors.black.withValues(alpha: 0.35),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),
                  ),

                  // Content
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Sponsor badge
                              if (_isSponsored)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  margin: const EdgeInsets.only(bottom: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade400,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.star, size: 10, color: Colors.black),
                                      const SizedBox(width: 4),
                                      Text(
                                        'SPONSORED • $sponsorText',
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 9,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              Text(
                                titleText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                descText,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 11,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primary,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(ctaText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_forward_ios, size: 9),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Date Scheduling
          Text('अभियान समय सीमा (Campaign Schedule):', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _startDate ?? DateTime.now(),
                      firstDate: DateTime(2025),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) setState(() => _startDate = date);
                  },
                  icon: const Icon(Icons.date_range, size: 16),
                  label: Text(_startDate != null ? 'प्रारंभ: ${_startDate!.day}/${_startDate!.month}/${_startDate!.year}' : 'प्रारंभ तिथि'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _endDate ?? DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime(2025),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) setState(() => _endDate = date);
                  },
                  icon: const Icon(Icons.event_available, size: 16),
                  label: Text(_endDate != null ? 'समाप्ति: ${_endDate!.day}/${_endDate!.month}/${_endDate!.year}' : 'समाप्ति तिथि'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
