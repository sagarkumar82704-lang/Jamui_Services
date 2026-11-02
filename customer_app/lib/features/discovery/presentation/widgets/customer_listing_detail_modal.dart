import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_network_or_base64_image.dart';
import '../../domain/entities/service_provider_entity.dart';

class CustomerListingDetailModal extends StatefulWidget {
  final Map<String, dynamic> listing;
  final ServiceProviderEntity provider;

  const CustomerListingDetailModal({
    super.key,
    required this.listing,
    required this.provider,
  });

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> listing,
    required ServiceProviderEntity provider,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CustomerListingDetailModal(
        listing: listing,
        provider: provider,
      ),
    );
  }

  @override
  State<CustomerListingDetailModal> createState() => _CustomerListingDetailModalState();
}

class _CustomerListingDetailModalState extends State<CustomerListingDetailModal> {
  int _activeImageIdx = 0;

  Future<void> _makeCall() async {
    final cleanPhone = widget.provider.phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: cleanPhone);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {}
  }

  Future<void> _openWhatsApp() async {
    final cleanPhone = widget.provider.phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanPhone.isEmpty) return;
    final fullNumber = cleanPhone.startsWith('91') ? cleanPhone : '91$cleanPhone';
    final title = widget.listing['title']?.toString() ?? 'लिस्टिंग';
    final message = Uri.encodeComponent(
      'नमस्ते ${widget.provider.fullName} जी, मैंने JAMUI SERVICE ऐप पर आपकी लिस्टिंग "$title" देखी है। मुझे इसके बारे में और जानकारी चाहिए।',
    );
    final uri = Uri.parse('https://wa.me/$fullNumber?text=$message');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.listing['title']?.toString() ?? '';
    final description = widget.listing['description']?.toString() ?? '';
    final price = (widget.listing['price'] as num?)?.toDouble() ?? 0.0;
    final type = (widget.listing['listingType']?.toString().toLowerCase() ?? 'service');
    final categoryName = widget.listing['categoryName']?.toString() ?? '';

    final rawImages = widget.listing['images'];
    final List<String> images = rawImages is List
        ? rawImages.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
        : [];

    String typeLabel;
    Color typeBg;
    Color typeFg;
    switch (type) {
      case 'product':
        typeLabel = 'उत्पाद (Product)';
        typeBg = Colors.purple.shade50;
        typeFg = Colors.purple.shade800;
        break;
      case 'job':
        typeLabel = 'नौकरी (Job Offer)';
        typeBg = Colors.blue.shade50;
        typeFg = Colors.blue.shade800;
        break;
      case 'service':
      default:
        typeLabel = 'सर्विस (Service)';
        typeBg = Colors.green.shade50;
        typeFg = Colors.green.shade800;
        break;
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: typeBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    typeLabel,
                    style: TextStyle(color: typeFg, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Images Gallery
                  if (images.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        height: 220,
                        width: double.infinity,
                        child: PageView.builder(
                          itemCount: images.length,
                          onPageChanged: (idx) => setState(() => _activeImageIdx = idx),
                          itemBuilder: (context, idx) {
                            return AppNetworkOrBase64Image(
                              imageUrl: images[idx],
                              fit: BoxFit.cover,
                            );
                          },
                        ),
                      ),
                    ),
                    if (images.length > 1) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(images.length, (idx) {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: _activeImageIdx == idx ? 16 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _activeImageIdx == idx ? AppColors.primary : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],

                  // Title and Price
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        type == 'job' ? '₹${price.toInt()} / माह' : '₹${price.toInt()}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: AppColors.accent),
                      ),
                      if (categoryName.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            categoryName,
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Description
                  if (description.isNotEmpty) ...[
                    const Text('विवरण (Details)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.45),
                    ),
                    const Divider(height: 24),
                  ],

                  // Provider Info Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          child: const Icon(Icons.person, color: AppColors.primary),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.provider.businessName.isNotEmpty
                                    ? widget.provider.businessName
                                    : widget.provider.fullName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Text(
                                '${widget.provider.categoryTitle} • ${widget.provider.jamuiArea}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: AppColors.gold, size: 16),
                            const SizedBox(width: 2),
                            Text(
                              widget.provider.rating.toStringAsFixed(1),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Action Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF25D366)),
                    label: const Text('व्हाट्सएप पूछताछ', style: TextStyle(color: Color(0xFF25D366), fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF25D366)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _openWhatsApp,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.phone_in_talk_rounded, color: Colors.white),
                    label: const Text('कॉल करें', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _makeCall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
