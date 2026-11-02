import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_network_or_base64_image.dart';

class ServicesPage extends StatefulWidget {
  const ServicesPage({super.key});

  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage> {
  String _selectedStatusFilter = 'all'; // 'all', 'pending_review', 'approved', 'rejected', 'paused'
  String _selectedTypeFilter = 'all'; // 'all', 'job', 'product', 'service'
  String _searchQuery = '';

  Future<void> _updateListingStatus(String listingId, String newStatus, {String? reason}) async {
    try {
      final updateData = <String, dynamic>{
        'status': newStatus,
        'moderatedAt': FieldValue.serverTimestamp(),
        'moderatedBy': 'admin@jamuiservice.com',
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (reason != null && reason.isNotEmpty) {
        updateData['rejectionReason'] = reason;
      }
      if (newStatus == 'approved') {
        updateData['isActive'] = true;
      } else if (newStatus == 'paused') {
        updateData['isActive'] = false;
      }

      await FirebaseFirestore.instance
          .collection('provider_listings')
          .doc(listingId)
          .update(updateData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('लिस्टिंग स्थिति सफलतापूर्वक "$newStatus" में बदली गई।'),
            backgroundColor: newStatus == 'approved' ? AppColors.success : AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('स्थिति बदलने में त्रुटि: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _showRejectDialog(String listingId, String title) async {
    final controller = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('लिस्टिंग अस्वीकृत करें: "$title"'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('अस्वीकृति का स्पष्ट कारण दर्ज करें (यह प्रदाता को दिखेगा):'),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'उदा. गलत श्रेणी, अस्पष्ट फोटो या अनुचित मूल्य/विवरण',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('रद्द करें')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('अस्वीकृत करें'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final reason = controller.text.trim().isNotEmpty
          ? controller.text.trim()
          : 'एडमिन द्वारा नियमों के उल्लंघन के कारण अस्वीकृत।';
      await _updateListingStatus(listingId, 'rejected', reason: reason);
    }
  }

  Future<void> _deleteListing(String listingId, String title, List<dynamic> images) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('लिस्टिंग स्थायी रूप से हटाएं?'),
        content: Text('क्या आप वाकई "$title" को हटाना चाहते हैं? इससे संबद्ध R2 स्टोरेज फोटो भी सुरक्षित रूप से हटा दिए जाएंगे।'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('रद्द करें')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('हटाएं'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Call deleteStorageObject for all attached image keys
        final deleteObjectCallable = FirebaseFunctions.instanceFor(region: 'asia-south1').httpsCallable('deleteStorageObject');
        for (final img in images) {
          final imgStr = img.toString();
          if (imgStr.contains('providers/')) {
            final keyPart = imgStr.split('providers/').last;
            final objectKey = 'providers/$keyPart';
            try {
              await deleteObjectCallable.call({'objectKey': objectKey});
            } catch (_) {}
          }
        }

        await FirebaseFirestore.instance.collection('provider_listings').doc(listingId).delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('लिस्टिंग और संबंधित स्टोरेज फोटो सफलतापूर्वक हटाए गए।'), backgroundColor: AppColors.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('हटाने में त्रुटि: $e'), backgroundColor: AppColors.danger),
          );
        }
      }
    }
  }

  void _showListingDetailModal(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (_) => _ListingDetailModal(
        item: item,
        onApprove: () {
          Navigator.pop(context);
          _updateListingStatus(item['id'], 'approved');
        },
        onReject: () {
          Navigator.pop(context);
          _showRejectDialog(item['id'], item['title'] ?? 'Listing');
        },
        onPause: () {
          Navigator.pop(context);
          final current = (item['status'] ?? 'pending_review').toString();
          _updateListingStatus(item['id'], current == 'paused' ? 'approved' : 'paused');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Stats Stream
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('provider_listings').snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              final total = docs.length;
              final pending = docs.where((d) => (d.data()['status'] ?? 'pending_review') == 'pending_review').length;
              final approved = docs.where((d) => d.data()['status'] == 'approved').length;
              final paused = docs.where((d) => d.data()['status'] == 'paused').length;
              final rejected = docs.where((d) => d.data()['status'] == 'rejected').length;

              return Row(
                children: [
                  _buildMetricCard('कुल लिस्टिंग्स', '$total', Icons.list_alt_rounded, Colors.blue),
                  const SizedBox(width: 14),
                  _buildMetricCard('समीक्षाधीन (Pending)', '$pending', Icons.hourglass_top_rounded, Colors.orange),
                  const SizedBox(width: 14),
                  _buildMetricCard('स्वीकृत (Active)', '$approved', Icons.check_circle_rounded, Colors.green),
                  const SizedBox(width: 14),
                  _buildMetricCard('रोकी गई (Paused)', '$paused', Icons.pause_circle_rounded, Colors.grey),
                  const SizedBox(width: 14),
                  _buildMetricCard('अस्वीकृत (Rejected)', '$rejected', Icons.cancel_rounded, Colors.red),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Search and Filters Bar
          Row(
            children: [
              Expanded(
                flex: 4,
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'लिस्टिंग शीर्षक, प्रदाता या श्रेणी से खोजें...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Type filter
              DropdownButton<String>(
                value: _selectedTypeFilter,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('सभी प्रकार (All Types)')),
                  DropdownMenuItem(value: 'service', child: Text('🛠️ सर्विस (Service)')),
                  DropdownMenuItem(value: 'job', child: Text('💼 जॉब (Job)')),
                  DropdownMenuItem(value: 'product', child: Text('📦 प्रोडक्ट (Product)')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _selectedTypeFilter = v);
                },
              ),
              const SizedBox(width: 12),
              // Status segment switcher
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'all', label: Text('सभी')),
                  ButtonSegment(value: 'pending_review', label: Text('समीक्षाधीन')),
                  ButtonSegment(value: 'approved', label: Text('स्वीकृत')),
                  ButtonSegment(value: 'paused', label: Text('रोकी गई')),
                  ButtonSegment(value: 'rejected', label: Text('अस्वीकृत')),
                ],
                selected: {_selectedStatusFilter},
                onSelectionChanged: (val) {
                  if (val.isNotEmpty) setState(() => _selectedStatusFilter = val.first);
                },
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Main Listings Stream Table
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('provider_listings')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  // Fallback without orderBy if createdAt composite index not built
                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance.collection('provider_listings').snapshots(),
                    builder: (ctx, snap2) {
                      if (snap2.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return _buildTableFromDocs(snap2.data?.docs ?? []);
                    },
                  );
                }

                return _buildTableFromDocs(snapshot.data?.docs ?? []);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableFromDocs(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final filtered = docs.where((d) {
      final data = d.data();
      final status = (data['status'] ?? 'pending_review').toString().toLowerCase();
      final type = (data['listingType'] ?? 'service').toString().toLowerCase();
      final title = (data['title'] ?? '').toString().toLowerCase();
      final provName = (data['providerName'] ?? '').toString().toLowerCase();
      final cat = (data['categoryTitle'] ?? data['category'] ?? '').toString().toLowerCase();

      final matchesStatus = _selectedStatusFilter == 'all' || status == _selectedStatusFilter;
      final matchesType = _selectedTypeFilter == 'all' || type == _selectedTypeFilter;
      final matchesSearch = _searchQuery.isEmpty ||
          title.contains(_searchQuery) ||
          provName.contains(_searchQuery) ||
          cat.contains(_searchQuery);

      return matchesStatus && matchesType && matchesSearch;
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 14),
            Text(
              _searchQuery.isNotEmpty ? 'कोई मेल खाती लिस्टिंग नहीं मिली' : 'इस फिल्टर में कोई लिस्टिंग नहीं है',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'प्रदाताओं द्वारा ऐप में नई जॉब, प्रोडक्ट या सर्विस जोड़ने पर वे यहाँ समीक्षा हेतु दिखेंगे।',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        itemCount: filtered.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final doc = filtered[index];
          final data = doc.data();
          final id = doc.id;
          final title = (data['title'] ?? 'शीर्षक रहित').toString();
          final type = (data['listingType'] ?? 'service').toString().toLowerCase();
          final status = (data['status'] ?? 'pending_review').toString().toLowerCase();
          final providerName = (data['providerName'] ?? 'Service Provider').toString();
          final categoryTitle = (data['categoryTitle'] ?? data['category'] ?? 'General').toString();
          final price = data['price'] != null ? '₹${data['price']}' : 'मूल्य उपलब्ध नहीं';
          final images = (data['images'] as List<dynamic>?) ?? [];
          final firstImage = images.isNotEmpty ? images.first.toString() : '';

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              clipBehavior: Clip.antiAlias,
              child: firstImage.isNotEmpty
                  ? AppNetworkOrBase64Image(imageUrl: firstImage, fit: BoxFit.cover)
                  : Icon(_getTypeIcon(type), color: _getTypeColor(type), size: 24),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _buildTypeBadge(type),
                const SizedBox(width: 6),
                _buildStatusBadge(status),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                children: [
                  Icon(Icons.person_outline, size: 13, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(providerName, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700)),
                  const SizedBox(width: 14),
                  Icon(Icons.category_outlined, size: 13, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(categoryTitle, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700)),
                  const SizedBox(width: 14),
                  Icon(Icons.photo_library_outlined, size: 13, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text('${images.length} फोटो', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700)),
                  const SizedBox(width: 14),
                  Text(price, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade900)),
                ],
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (status == 'pending_review' || status == 'rejected')
                  ElevatedButton.icon(
                    onPressed: () => _updateListingStatus(id, 'approved'),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('स्वीकृत करें'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                if (status == 'pending_review') const SizedBox(width: 8),
                if (status == 'pending_review' || status == 'approved')
                  OutlinedButton.icon(
                    onPressed: () => _showRejectDialog(id, title),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('अस्वीकृत'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.visibility_outlined, size: 20),
                  tooltip: 'विवरण व फोटो देखें',
                  onPressed: () => _showListingDetailModal({'id': id, ...data}),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  tooltip: 'लिस्टिंग हटाएं',
                  onPressed: () => _deleteListing(id, title, images),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'job':
        return Icons.work_outline;
      case 'product':
        return Icons.shopping_bag_outlined;
      case 'service':
      default:
        return Icons.build_outlined;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'job':
        return Colors.blue;
      case 'product':
        return Colors.purple;
      case 'service':
      default:
        return Colors.teal;
    }
  }

  Widget _buildTypeBadge(String type) {
    Color bg = Colors.teal.shade50;
    Color fg = Colors.teal.shade900;
    String label = 'सर्विस';
    if (type == 'job') {
      bg = Colors.blue.shade50;
      fg = Colors.blue.shade900;
      label = 'जॉब';
    } else if (type == 'product') {
      bg = Colors.purple.shade50;
      fg = Colors.purple.shade900;
      label = 'प्रोडक्ट';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: fg)),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = Colors.orange.shade50;
    Color fg = Colors.orange.shade900;
    String label = 'समीक्षाधीन (Pending)';
    if (status == 'approved') {
      bg = Colors.green.shade50;
      fg = Colors.green.shade900;
      label = 'स्वीकृत (Approved)';
    } else if (status == 'rejected') {
      bg = Colors.red.shade50;
      fg = Colors.red.shade900;
      label = 'अस्वीकृत (Rejected)';
    } else if (status == 'paused') {
      bg = Colors.grey.shade100;
      fg = Colors.black54;
      label = 'रोकी गई (Paused)';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: fg)),
    );
  }
}

class _ListingDetailModal extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onPause;

  const _ListingDetailModal({
    required this.item,
    required this.onApprove,
    required this.onReject,
    required this.onPause,
  });

  @override
  Widget build(BuildContext context) {
    final title = (item['title'] ?? 'Listing Details').toString();
    final description = (item['description'] ?? 'विवरण उपलब्ध नहीं है।').toString();
    final providerName = (item['providerName'] ?? 'N/A').toString();
    final category = (item['categoryTitle'] ?? item['category'] ?? 'General').toString();
    final price = item['price'] != null ? '₹${item['price']}' : 'N/A';
    final status = (item['status'] ?? 'pending_review').toString();
    final type = (item['listingType'] ?? 'service').toString();
    final images = (item['images'] as List<dynamic>?) ?? [];
    final rejectionReason = item['rejectionReason']?.toString();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: AppTextStyles.h3,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const Divider(height: 16),

              Expanded(
                child: ListView(
                  children: [
                    // Metadata Row
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _buildMetaChip(Icons.person, 'प्रदाता: $providerName'),
                        _buildMetaChip(Icons.category, 'कैटगरी: $category'),
                        _buildMetaChip(Icons.sell, 'मूल्य: $price'),
                        _buildMetaChip(Icons.label, 'प्रकार: $type'),
                        _buildMetaChip(Icons.info_outline, 'स्थिति: $status'),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (rejectionReason != null && rejectionReason.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          'अस्वीकृति का कारण: $rejectionReason',
                          style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Images Gallery
                    const Text('संबद्ध फ़ोटो (R2 Media Gallery):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    if (images.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                        child: const Text('कोई फोटो संलग्न नहीं है।', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      )
                    else
                      SizedBox(
                        height: 120,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: images.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 10),
                          itemBuilder: (ctx, i) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: AppNetworkOrBase64Image(
                                imageUrl: images[i].toString(),
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 16),

                    // Description
                    const Text('विस्तृत विवरण (Description):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(description, style: const TextStyle(fontSize: 12.5, height: 1.4)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 20),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('बंद करें')),
                  const SizedBox(width: 8),
                  if (status != 'paused')
                    OutlinedButton(
                      onPressed: onPause,
                      child: Text(status == 'paused' ? 'अन-पॉज़ करें' : 'पॉज़ करें'),
                    ),
                  const SizedBox(width: 8),
                  if (status != 'rejected')
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
                      onPressed: onReject,
                      child: const Text('अस्वीकृत करें'),
                    ),
                  const SizedBox(width: 8),
                  if (status != 'approved')
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
                      onPressed: onApprove,
                      child: const Text('स्वीकृत करें'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
