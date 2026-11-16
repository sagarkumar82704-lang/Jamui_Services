import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/r2_upload_service.dart';
import '../../../../core/localization/provider_strings.dart';
import '../../../../core/utils/app_image_url_resolver.dart';
import '../../data/datasources/professional_provider_remote_data_source.dart';
import '../../domain/entities/professional_shop_profile_entity.dart';
import '../widgets/professional_storefront_promo_banner.dart';

class ProfessionalStoreBannerManagementPage extends StatefulWidget {
  final ProfessionalShopProfileEntity shop;
  final ProfessionalProviderRemoteDataSource? dataSource;

  const ProfessionalStoreBannerManagementPage({
    super.key,
    required this.shop,
    this.dataSource,
  });

  @override
  State<ProfessionalStoreBannerManagementPage> createState() =>
      _ProfessionalStoreBannerManagementPageState();
}

class _ProfessionalStoreBannerManagementPageState
    extends State<ProfessionalStoreBannerManagementPage> {
  static const Color _primaryGreen = Color(0xFF15803D);
  static const Color _darkGreenHeader = Color(0xFF0B4F26);

  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  late final ProfessionalProviderRemoteDataSource _ds;

  late final TextEditingController _titleController;
  late final TextEditingController _subtitleController;
  late final TextEditingController _offerTextController;

  String _bannerImageUrl = '';
  bool _isActive = true;
  DateTime? _startDate;
  DateTime? _endDate;

  bool _isUploadingImage = false;
  bool _isSaving = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _ds = widget.dataSource ?? ProfessionalProviderRemoteDataSource();
    final existing = widget.shop.promoBanner;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _subtitleController = TextEditingController(text: existing?.subtitle ?? '');
    _offerTextController =
        TextEditingController(text: existing?.offerText ?? '');
    _bannerImageUrl = existing?.imageUrl ?? '';
    _isActive = existing?.isActive ?? true;
    _startDate = existing?.startDate;
    _endDate = existing?.endDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _offerTextController.dispose();
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

  Future<void> _pickAndUploadBannerImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1400,
        maxHeight: 900,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() => _isUploadingImage = true);

      final bytes = await picked.readAsBytes();
      final ext = picked.name.contains('.')
          ? picked.name.split('.').last.toLowerCase()
          : 'jpg';
      final contentType = ext == 'png'
          ? 'image/png'
          : (ext == 'webp' ? 'image/webp' : 'image/jpeg');

      final uploaded = await R2UploadService().uploadBytes(
        bytes: bytes,
        folder: 'workplace',
        targetId: _effectiveOwnerUid,
        mimeType: contentType,
        fileName: picked.name,
      );

      if (!mounted) return;
      setState(() {
        _bannerImageUrl = uploaded.objectKey;
        _isUploadingImage = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ProviderStrings.bannerUploadSuccess),
          backgroundColor: _primaryGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingImage = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${ProviderStrings.bannerUploadFailed}$e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initial = isStart
        ? (_startDate ?? now)
        : (_endDate ?? (_startDate ?? now).add(const Duration(days: 7)));

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (picked == null) return;

    setState(() {
      if (isStart) {
        _startDate = DateTime(picked.year, picked.month, picked.day);
        if (_endDate != null && _endDate!.isBefore(_startDate!)) {
          _endDate = _startDate!.add(const Duration(days: 7));
        }
      } else {
        _endDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      }
    });
  }

  ShopPromoBannerEntity _buildCurrentDraftBanner() {
    return ShopPromoBannerEntity(
      imageUrl: _bannerImageUrl.trim(),
      title: _titleController.text.trim(),
      subtitle: _subtitleController.text.trim(),
      offerText: _offerTextController.text.trim(),
      startDate: _startDate,
      endDate: _endDate,
      isActive: _isActive,
    );
  }

  Future<void> _savePromoBanner() async {
    if (!_formKey.currentState!.validate()) return;

    final draft = _buildCurrentDraftBanner();
    if (!draft.hasContent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ProviderStrings.bannerContentRequired),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_startDate != null &&
        _endDate != null &&
        _endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ProviderStrings.endDateBeforeStartDate),
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

      await _ds.savePromoBanner(
        widget.shop.id,
        draft,
        currentUid: currentUid,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ProviderStrings.bannerSavedSuccess),
          backgroundColor: _primaryGreen,
        ),
      );
      Navigator.of(context).pop(draft);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save banner: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _confirmAndDeleteBanner() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ProviderStrings.deleteBannerTitle),
        content: Text(ProviderStrings.deleteBannerConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ProviderStrings.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ProviderStrings.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    try {
      String? currentUid;
      try {
        currentUid = FirebaseAuth.instance.currentUser?.uid;
      } catch (_) {}

      await _ds.deletePromoBanner(
        widget.shop.id,
        currentUid: currentUid,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ProviderStrings.bannerDeletedSuccess),
          backgroundColor: _primaryGreen,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete banner: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = _buildCurrentDraftBanner();
    final hasExistingBanner = widget.shop.promoBanner?.hasContent == true;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F9F5),
      appBar: AppBar(
        backgroundColor: _darkGreenHeader,
        foregroundColor: Colors.white,
        title: Text(
          ProviderStrings.promotionalBanner,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          if (hasExistingBanner)
            IconButton(
              key: const Key('btn_delete_promo_banner'),
              tooltip: ProviderStrings.deleteBannerTitle,
              onPressed: _isDeleting ? null : _confirmAndDeleteBanner,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLiveBannerPreviewSection(draft),
              const SizedBox(height: 18),
              _buildBannerFormCard(),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  key: const Key('btn_save_promo_banner'),
                  onPressed:
                      (_isSaving || _isUploadingImage) ? null : _savePromoBanner,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(
                    _isSaving ? ProviderStrings.savingBanner : ProviderStrings.savePromotionalBanner,
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

  Widget _buildLiveBannerPreviewSection(ShopPromoBannerEntity draft) {
    final isLiveNow = draft.isCurrentlyLive();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              ProviderStrings.storefrontBannerPreview,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isLiveNow
                    ? const Color(0xFFDCFCE7)
                    : const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isLiveNow ? ProviderStrings.liveOnStorefront : ProviderStrings.hiddenInactive,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: isLiveNow
                      ? const Color(0xFF15803D)
                      : const Color(0xFFB91C1C),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (!draft.hasContent)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD1E7D6)),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.campaign_outlined,
                  size: 36,
                  color: Color(0xFF9CA3AF),
                ),
                SizedBox(height: 8),
                Text(
                  'No active promotional banner configured',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF374151),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'When no banner is active, the banner section is cleanly hidden on your customer storefront.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          )
        else
          ProfessionalStorefrontPromoBanner(
            banner: draft,
            freeDeliveryThreshold: widget.shop.freeDeliveryThreshold,
            bannerKey: const Key('card_promo_banner_preview'),
            margin: EdgeInsets.zero,
          ),
      ],
    );
  }

  Widget _buildBannerFormCard() {
    final df = DateFormat('dd MMM yyyy');
    final resolvedImg = AppImageUrlResolver.resolve(_bannerImageUrl);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            key: const Key('switch_promo_banner_active'),
            contentPadding: EdgeInsets.zero,
            activeThumbColor: _primaryGreen,
            title: Text(
              ProviderStrings.bannerActiveStatus,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
            ),
            subtitle: Text(
              _isActive
                  ? ProviderStrings.bannerActiveSubtitle
                  : ProviderStrings.hiddenInactive,
              style: const TextStyle(fontSize: 12),
            ),
            value: _isActive,
            onChanged: (v) => setState(() => _isActive = v),
          ),
          const Divider(),
          const SizedBox(height: 8),
          Text(
            ProviderStrings.bannerImageStorage,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 88,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFD1D5DB)),
                ),
                child: resolvedImg.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Image.network(
                          resolvedImg,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.image_not_supported_outlined),
                        ),
                      )
                    : const Icon(
                        Icons.add_photo_alternate_outlined,
                        color: Color(0xFF6B7280),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('btn_upload_banner_image'),
                      onPressed: _isUploadingImage
                          ? null
                          : _pickAndUploadBannerImage,
                      icon: _isUploadingImage
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_upload_outlined, size: 18),
                      label: Text(
                        _isUploadingImage
                            ? 'Uploading...'
                            : (_bannerImageUrl.isNotEmpty
                                ? ProviderStrings.changeBannerImage
                                : ProviderStrings.changeBannerImage),
                      ),
                    ),
                    if (_bannerImageUrl.isNotEmpty)
                      TextButton(
                        onPressed: () => setState(() => _bannerImageUrl = ''),
                        child: Text(
                          ProviderStrings.removeImage,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextFormField(
            key: const Key('field_banner_title'),
            controller: _titleController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: ProviderStrings.bannerTitle,
              hintText: 'e.g. Festive Season Offer',
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('field_banner_subtitle'),
            controller: _subtitleController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: ProviderStrings.bannerSubtitle,
              hintText: 'e.g. On Daily Essentials & Groceries',
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('field_banner_offer_text'),
            controller: _offerTextController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: ProviderStrings.optionalOfferBadgeText,
              hintText: 'e.g. Free Delivery Above ₹499',
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            ProviderStrings.scheduleValidityOptional,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(isStart: true),
                  icon: const Icon(Icons.calendar_today_outlined, size: 16),
                  label: Text(
                    _startDate != null
                        ? 'From: ${df.format(_startDate!)}'
                        : ProviderStrings.startDate,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(isStart: false),
                  icon: const Icon(Icons.event_outlined, size: 16),
                  label: Text(
                    _endDate != null
                        ? 'Until: ${df.format(_endDate!)}'
                        : ProviderStrings.endDate,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
          if (_startDate != null || _endDate != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() {
                  _startDate = null;
                  _endDate = null;
                }),
                child: const Text(
                  'Clear Schedule Dates',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    ),
  );
  }
}

