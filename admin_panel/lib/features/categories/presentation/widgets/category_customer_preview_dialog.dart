import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_network_or_base64_image.dart';
import '../../domain/entities/category_entity.dart';

class CategoryCustomerPreviewDialog extends StatelessWidget {
  final CategoryEntity category;
  final Uint8List? localImageBytes;

  const CategoryCustomerPreviewDialog({
    super.key,
    required this.category,
    this.localImageBytes,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 440,
        height: 720,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Preview Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.smartphone, color: Colors.white70, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Customer App Live Preview',
                    style: AppTextStyles.bodyBold.copyWith(color: Colors.white),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 18),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Phone Screen Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Image Banner
                    Container(
                      width: double.infinity,
                      height: 180,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _buildBannerImage(),
                    ),
                    const SizedBox(height: 14),

                    // Title & Badges
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                category.name.isNotEmpty ? category.name : 'Category Name',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              if (category.titleHindi.isNotEmpty && category.titleHindi != category.name)
                                Text(
                                  category.titleHindi,
                                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                                ),
                            ],
                          ),
                        ),
                        if (category.isFeatured)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.amber.shade400),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star, color: Colors.amber, size: 14),
                                SizedBox(width: 4),
                                Text('Featured', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber)),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Short Description
                    if (category.shortDescription.isNotEmpty)
                      Text(
                        category.shortDescription,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
                      ),
                    const SizedBox(height: 16),

                    // Price & Duration Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              const Text('Starting Price', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              const SizedBox(height: 4),
                              Text(
                                category.startingPrice != null && category.startingPrice! > 0
                                    ? '₹${category.startingPrice!.toStringAsFixed(0)} ${category.priceUnit}'
                                    : (category.pricingType == 'inspection' ? 'On Inspection' : 'Contact Provider'),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0D6E57)),
                              ),
                            ],
                          ),
                          Container(width: 1, height: 30, color: Colors.grey.shade300),
                          Column(
                            children: [
                              const Text('Est. Duration', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              const SizedBox(height: 4),
                              Text(
                                category.estimatedDuration.isNotEmpty ? category.estimatedDuration : 'Depends on Work',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Services List
                    if (category.subServices.isNotEmpty) ...[
                      const Text('Available Services', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: category.subServices.map((s) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle, size: 14, color: AppColors.primary),
                                const SizedBox(width: 6),
                                Text(s, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // About / Full Description
                    if (category.fullDescription.isNotEmpty || category.aboutCategory.isNotEmpty) ...[
                      const Text('About Service', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(
                        category.fullDescription.isNotEmpty ? category.fullDescription : category.aboutCategory,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade800, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Benefits
                    if (category.benefits.isNotEmpty) ...[
                      const Text('Benefits', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      ...category.benefits.map((b) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.star_rounded, size: 14, color: Colors.green),
                                const SizedBox(width: 6),
                                Expanded(child: Text(b, style: const TextStyle(fontSize: 12))),
                              ],
                            ),
                          )),
                      const SizedBox(height: 16),
                    ],

                    // Common Problems
                    if (category.commonProblems.isNotEmpty) ...[
                      const Text('Common Problems Resolved', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      ...category.commonProblems.map((p) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.build_circle_outlined, size: 14, color: Colors.blueGrey),
                                const SizedBox(width: 6),
                                Expanded(child: Text(p, style: const TextStyle(fontSize: 12))),
                              ],
                            ),
                          )),
                      const SizedBox(height: 16),
                    ],

                    // FAQs
                    if (category.faqs.isNotEmpty) ...[
                      const Text('Frequently Asked Questions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...category.faqs.map((faq) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Q: ${faq.question}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(faq.answer, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                              ],
                            ),
                          )),
                      const SizedBox(height: 16),
                    ],

                    // Safety & Notes
                    if (category.safetyInstructions.isNotEmpty || category.importantNotes.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange.shade800),
                                const SizedBox(width: 6),
                                Text('Safety & Important Instructions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange.shade900)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (category.safetyInstructions.isNotEmpty)
                              Text(category.safetyInstructions, style: TextStyle(fontSize: 11, color: Colors.orange.shade900)),
                            if (category.importantNotes.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(category.importantNotes, style: TextStyle(fontSize: 11, color: Colors.orange.shade900)),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerImage() {
    if (localImageBytes != null && localImageBytes!.isNotEmpty) {
      return Image.memory(
        localImageBytes!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }
    if (category.imageUrl.isNotEmpty) {
      return AppNetworkOrBase64Image(
        imageUrl: category.imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => _buildPlaceholder(),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey.shade100,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text('No Image Uploaded', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}
