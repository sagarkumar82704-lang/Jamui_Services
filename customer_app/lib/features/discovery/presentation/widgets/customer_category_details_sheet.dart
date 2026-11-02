import 'package:flutter/material.dart';
import '../../../../core/widgets/app_network_or_base64_image.dart';
import '../../domain/entities/service_category_entity.dart';

class CustomerCategoryDetailsSheet extends StatelessWidget {
  final ServiceCategoryEntity category;
  final VoidCallback onSelectCategory;

  const CustomerCategoryDetailsSheet({
    super.key,
    required this.category,
    required this.onSelectCategory,
  });

  static void show(BuildContext context, {
    required ServiceCategoryEntity category,
    required VoidCallback onSelectCategory,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CustomerCategoryDetailsSheet(
        category: category,
        onSelectCategory: onSelectCategory,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image Banner
                  Container(
                    width: double.infinity,
                    height: 190,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: category.imageUrl.isNotEmpty
                        ? AppNetworkOrBase64Image(
                            imageUrl: category.imageUrl,
                            height: 190,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _buildPlaceholder(),
                          )
                        : _buildPlaceholder(),
                  ),
                  const SizedBox(height: 16),

                  // Category Title & Badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category.titleHindi.isNotEmpty ? category.titleHindi : category.titleEnglish,
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            if (category.titleEnglish.isNotEmpty && category.titleEnglish != category.titleHindi)
                              Text(
                                category.titleEnglish,
                                style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                              ),
                          ],
                        ),
                      ),
                      if (category.isFeatured)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(8),
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
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.4),
                    ),
                  const SizedBox(height: 16),

                  // Pricing & Duration Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text('शुरुआती शुल्क (Starting Price)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text(
                              category.startingPrice != null && category.startingPrice! > 0
                                  ? '₹${category.startingPrice!.toStringAsFixed(0)} ${category.priceUnit}'
                                  : (category.pricingType == 'inspection' ? 'जांच पर (On Inspection)' : 'संपर्क करें'),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0D6E57)),
                            ),
                          ],
                        ),
                        Container(width: 1, height: 35, color: Colors.grey.shade300),
                        Column(
                          children: [
                            const Text('अनुमानित समय (Est. Duration)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text(
                              category.estimatedDuration.isNotEmpty ? category.estimatedDuration : 'काम के आधार पर',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Available Sub-Services
                  if (category.subServices.isNotEmpty) ...[
                    const Text('उपलब्ध सेवाएँ (Available Services)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: category.subServices.map((s) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D6E57).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF0D6E57).withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle, size: 14, color: Color(0xFF0D6E57)),
                              const SizedBox(width: 6),
                              Text(s, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0D6E57))),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // About Service
                  if (category.fullDescription.isNotEmpty || category.aboutCategory.isNotEmpty) ...[
                    const Text('सेवा के बारे में (About Service)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(
                      category.fullDescription.isNotEmpty ? category.fullDescription : category.aboutCategory,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade800, height: 1.4),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Benefits
                  if (category.benefits.isNotEmpty) ...[
                    const Text('सुविधाएँ एवं लाभ (Benefits)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...category.benefits.map((b) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.verified, size: 16, color: Color(0xFF0D6E57)),
                              const SizedBox(width: 8),
                              Expanded(child: Text(b, style: const TextStyle(fontSize: 13, height: 1.3))),
                            ],
                          ),
                        )),
                    const SizedBox(height: 20),
                  ],

                  // Common Problems
                  if (category.commonProblems.isNotEmpty) ...[
                    const Text('सामान्य समस्याएँ जिनका समाधान उपलब्ध है', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...category.commonProblems.map((p) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.build_rounded, size: 15, color: Colors.blueGrey),
                              const SizedBox(width: 8),
                              Expanded(child: Text(p, style: const TextStyle(fontSize: 13, height: 1.3))),
                            ],
                          ),
                        )),
                    const SizedBox(height: 20),
                  ],

                  // Customer Requirements
                  if (category.customerRequirements.isNotEmpty || category.customerPhotoRequired) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, size: 16, color: Colors.blue.shade800),
                              const SizedBox(width: 6),
                              Text('ग्राहक आवश्यकता (Customer Requirements)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (category.customerRequirements.isNotEmpty)
                            Text(category.customerRequirements, style: TextStyle(fontSize: 12, color: Colors.blue.shade900)),
                          if (category.customerPhotoRequired) ...[
                            const SizedBox(height: 4),
                            const Row(
                              children: [
                                Icon(Icons.camera_alt, size: 14, color: Colors.blue),
                                SizedBox(width: 6),
                                Text('इस सेवा के लिए समस्या की फोटो आवश्यक है।', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blue)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // FAQs
                  if (category.faqs.isNotEmpty) ...[
                    const Text('अक्सर पूछे जाने वाले सवाल (FAQs)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...category.faqs.map((faq) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(faq.question, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              const SizedBox(height: 4),
                              Text(faq.answer, style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.3)),
                            ],
                          ),
                        )),
                    const SizedBox(height: 20),
                  ],

                  // Safety & Instructions
                  if (category.safetyInstructions.isNotEmpty || category.importantNotes.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.security, size: 16, color: Colors.orange.shade900),
                              const SizedBox(width: 6),
                              Text('सुरक्षा एवं महत्वपूर्ण निर्देश', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.orange.shade900)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (category.safetyInstructions.isNotEmpty)
                            Text(category.safetyInstructions, style: TextStyle(fontSize: 12, color: Colors.orange.shade900, height: 1.3)),
                          if (category.importantNotes.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(category.importantNotes, style: TextStyle(fontSize: 12, color: Colors.orange.shade900, height: 1.3)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ),

          // Bottom Action Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  onSelectCategory();
                },
                icon: const Icon(Icons.search, size: 18),
                label: Text('${category.titleHindi} के नजदीकी कारीगर देखें'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D6E57),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFF0D6E57).withValues(alpha: 0.1),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.handyman_rounded, size: 48, color: Color(0xFF0D6E57)),
            SizedBox(height: 6),
            Text('अपना जमुई सेवा', style: TextStyle(fontSize: 12, color: Color(0xFF0D6E57), fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
