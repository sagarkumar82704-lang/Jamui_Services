import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_network_or_base64_image.dart';
import '../../../reviews/data/services/customer_review_service.dart';
import '../../../reviews/domain/entities/customer_review_entity.dart';

class SubmitReviewDialog extends StatefulWidget {
  final String providerId;
  final String providerName;
  final String? leadId;
  final String? serviceTitle;
  final CustomerReviewEntity? existingReview;
  final VoidCallback? onReviewSubmitted;

  const SubmitReviewDialog({
    super.key,
    required this.providerId,
    required this.providerName,
    this.leadId,
    this.serviceTitle,
    this.existingReview,
    this.onReviewSubmitted,
  });

  static Future<void> show(
    BuildContext context, {
    required String providerId,
    required String providerName,
    String? leadId,
    String? serviceTitle,
    CustomerReviewEntity? existingReview,
    VoidCallback? onReviewSubmitted,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: SubmitReviewDialog(
          providerId: providerId,
          providerName: providerName,
          leadId: leadId,
          serviceTitle: serviceTitle,
          existingReview: existingReview,
          onReviewSubmitted: onReviewSubmitted,
        ),
      ),
    );
  }

  @override
  State<SubmitReviewDialog> createState() => _SubmitReviewDialogState();
}

class _SubmitReviewDialogState extends State<SubmitReviewDialog> {
  final CustomerReviewService _reviewService = CustomerReviewService();
  late int _rating;
  late TextEditingController _commentController;
  final Set<String> _selectedTags = {};
  final List<String> _photoUrls = [];
  final List<File> _newLocalPhotos = [];

  bool _isSubmitting = false;
  String _uploadStatus = '';

  final List<String> _quickTags = [
    'समय पर पहुंचे ⏱️',
    'वाजिब दाम 💰',
    'उत्कृष्ट काम 🛠️',
    'अच्छा व्यवहार 🤝',
    'साफ-सफाई से काम 🧹',
    'संतुष्ट ग्राहक 👍',
  ];

  @override
  void initState() {
    super.initState();
    final rev = widget.existingReview;
    _rating = rev?.rating ?? 5;
    _commentController = TextEditingController(text: rev?.comment ?? '');
    if (rev != null) {
      _selectedTags.addAll(rev.tags);
      _photoUrls.addAll(rev.photoUrls);
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    if ((_photoUrls.length + _newLocalPhotos.length) >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('अधिकतम 3 तस्वीरें ही जोड़ी जा सकती हैं।')),
      );
      return;
    }

    try {
      final file = await _reviewService.pickReviewImage(source: source);
      if (file != null && mounted) {
        setState(() {
          _newLocalPhotos.add(file);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('$e')),
        );
      }
    }
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'काम की फ़ोटो जोड़ें (Add Photo)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                title: const Text('कैमरा से फ़ोटो लें (Camera)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
                title: const Text('गैलरी से चुनें (Gallery)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitReview() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('समीक्षा देने के लिए कृपया पहले लॉगिन करें')),
      );
      return;
    }

    final bookingId = widget.leadId ?? widget.existingReview?.bookingId ?? 'direct_${widget.providerId}';

    setState(() {
      _isSubmitting = true;
      _uploadStatus = 'समीक्षा प्रोसेस की जा रही है...';
    });

    try {
      // 1. Upload new local photos to Storage if any
      final finalPhotoUrls = List<String>.from(_photoUrls);
      if (_newLocalPhotos.isNotEmpty) {
        for (int i = 0; i < _newLocalPhotos.length; i++) {
          if (!mounted) return;
          setState(() {
            _uploadStatus = 'फ़ोटो अपलोड हो रही है (${i + 1}/${_newLocalPhotos.length})...';
          });
          final url = await _reviewService.uploadReviewPhoto(
            customerId: user.uid,
            bookingId: bookingId,
            file: _newLocalPhotos[i],
          );
          finalPhotoUrls.add(url);
        }
      }

      if (!mounted) return;
      setState(() => _uploadStatus = 'रेटिंग अपडेट की जा रही है...');

      // 2. Save / Edit Review Document & recalculate provider rating
      await _reviewService.submitOrEditReview(
        bookingId: bookingId,
        providerId: widget.providerId,
        providerName: widget.providerName,
        rating: _rating,
        comment: _commentController.text.trim(),
        tags: _selectedTags.toList(),
        photoUrls: finalPhotoUrls,
        existingReview: widget.existingReview,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text(
              widget.existingReview != null
                  ? 'आपकी समीक्षा सफलतापूर्वक अपडेट कर दी गई है!'
                  : 'आपकी रेटिंग व समीक्षा सफलतापूर्वक दर्ज हो गई है! धन्यवाद।',
            ),
          ),
        );
        widget.onReviewSubmitted?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('त्रुटि: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingReview != null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header Title
            Text(
              isEditing ? 'समीक्षा में सुधार करें (Edit Review)' : 'सेवा अनुभव की समीक्षा करें',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              widget.providerName + (widget.serviceTitle != null ? ' • ${widget.serviceTitle}' : ''),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 18),

            // 1-5 Star Rating Selector
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  final starVal = index + 1;
                  return IconButton(
                    iconSize: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    icon: Icon(
                      starVal <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: AppColors.gold,
                    ),
                    onPressed: () {
                      setState(() {
                        _rating = starVal;
                      });
                    },
                  );
                }),
              ),
            ),

            Center(
              child: Text(
                _getRatingLabel(_rating),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 18),

            // Quick feedback tags
            const Text(
              'अनुभव कैसा रहा? (टैग चुनें)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quickTags.map((tag) {
                final isSelected = _selectedTags.contains(tag);
                return FilterChip(
                  label: Text(tag, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : AppColors.textPrimary)),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.backgroundLight,
                  checkmarkColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _selectedTags.add(tag);
                      } else {
                        _selectedTags.remove(tag);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Detailed comment input
            TextField(
              controller: _commentController,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'कारीगर के काम के बारे में विस्तार से लिखें (वैकल्पिक)...',
                hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 12),

            // Customer Review Photos Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.add_a_photo_outlined, size: 16, color: AppColors.primary),
                    SizedBox(width: 6),
                    Text(
                      'काम की तस्वीरें (Photos)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                if ((_photoUrls.length + _newLocalPhotos.length) < 3)
                  TextButton.icon(
                    onPressed: _showImageSourcePicker,
                    icon: const Icon(Icons.add_circle_outline, size: 15, color: AppColors.primary),
                    label: const Text('फ़ोटो जोड़ें', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Photos Preview List
            if (_photoUrls.isNotEmpty || _newLocalPhotos.isNotEmpty) ...[
              SizedBox(
                height: 74,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    // Remote URLs
                    ..._photoUrls.map((url) => _buildPhotoThumbnail(
                          imageWidget: AppNetworkOrBase64Image(
                            imageUrl: url,
                            width: 70,
                            height: 70,
                            fit: BoxFit.cover,
                          ),
                          onDelete: () {
                            setState(() {
                              _photoUrls.remove(url);
                            });
                          },
                        )),
                    // Local Files
                    ..._newLocalPhotos.map((file) => _buildPhotoThumbnail(
                          imageWidget: Image.file(
                            file,
                            width: 70,
                            height: 70,
                            fit: BoxFit.cover,
                          ),
                          onDelete: () {
                            setState(() {
                              _newLocalPhotos.remove(file);
                            });
                          },
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.camera_alt_outlined, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'काम की फ़ोटो जोड़ने से अन्य ग्राहकों का विश्वास बढ़ता है (वैकल्पिक)',
                        style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                      ),
                    ),
                    TextButton(
                      onPressed: _showImageSourcePicker,
                      child: const Text('+ जोड़ें', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Submission Status Text
            if (_isSubmitting && _uploadStatus.isNotEmpty) ...[
              Center(
                child: Text(
                  _uploadStatus,
                  style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Submit Button
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        isEditing ? 'समीक्षा अपडेट करें (Update)' : 'रेटिंग व समीक्षा सबमिट करें',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoThumbnail({
    required Widget imageWidget,
    required VoidCallback onDelete,
  }) {
    return Container(
      width: 70,
      height: 70,
      margin: const EdgeInsets.only(right: 10),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: imageWidget,
          ),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.black87,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 12, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getRatingLabel(int rating) {
    switch (rating) {
      case 5:
        return '⭐⭐⭐⭐⭐ उत्कृष्ट सेवा (Excellent)';
      case 4:
        return '⭐⭐⭐⭐ बहुत अच्छी सेवा (Very Good)';
      case 3:
        return '⭐⭐⭐ औसत सेवा (Average)';
      case 2:
        return '⭐⭐ असंतोषजनक सेवा (Below Average)';
      case 1:
      default:
        return '⭐ खराब सेवा (Poor)';
    }
  }
}
