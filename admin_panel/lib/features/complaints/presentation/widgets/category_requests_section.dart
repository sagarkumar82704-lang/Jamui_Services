import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/status_badge.dart';

class CategoryRequestsSection extends StatefulWidget {
  const CategoryRequestsSection({super.key});

  @override
  State<CategoryRequestsSection> createState() => _CategoryRequestsSectionState();
}

class _CategoryRequestsSectionState extends State<CategoryRequestsSection> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _adminCategories = [];
  String _statusFilter = 'all'; // 'all', 'pending_review', 'approved', 'rejected'
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchRequests(),
      _fetchAdminCategories(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchRequests() async {
    try {
      // 1. Fetch from category_requests collection
      final snap = await FirebaseFirestore.instance
          .collection('category_requests')
          .limit(200)
          .get();

      final list = snap.docs.map((d) => {'docId': d.id, ...d.data()}).toList();

      // 2. Also check legacy custom_service_applications to merge without duplicates
      try {
        final legacySnap = await FirebaseFirestore.instance
            .collection('custom_service_applications')
            .limit(100)
            .get();
        final existingIds = list.map((e) => e['docId']).toSet();
        for (var doc in legacySnap.docs) {
          if (!existingIds.contains(doc.id)) {
            list.add({'docId': doc.id, ...doc.data()});
          }
        }
      } catch (_) {}

      // Sort by createdAt descending
      list.sort((a, b) {
        final aTime = _extractTimestamp(a['createdAt']);
        final bTime = _extractTimestamp(b['createdAt']);
        return bTime.compareTo(aTime);
      });

      if (mounted) {
        setState(() {
          _requests = list;
        });
      }
    } catch (e) {
      debugPrint('⚠️ [CategoryRequestsSection] Error fetching requests: $e');
    }
  }

  int _extractTimestamp(dynamic val) {
    if (val == null) return 0;
    if (val is Timestamp) return val.millisecondsSinceEpoch;
    if (val is DateTime) return val.millisecondsSinceEpoch;
    if (val is String) {
      final dt = DateTime.tryParse(val);
      return dt?.millisecondsSinceEpoch ?? 0;
    }
    return 0;
  }

  Future<void> _fetchAdminCategories() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('categories').get();
      final list = snap.docs
          .map((d) => {'id': d.id, ...d.data()})
          .where((c) => c['isDeleted'] != true && (c['status'] == 'active' || c['isActive'] == true))
          .toList();
      if (mounted) {
        setState(() {
          _adminCategories = list;
        });
      }
    } catch (e) {
      debugPrint('⚠️ [CategoryRequestsSection] Error fetching categories: $e');
    }
  }

  List<Map<String, dynamic>> get _filteredRequests {
    return _requests.where((r) {
      final status = (r['status']?.toString() ?? 'pending_review').toLowerCase().trim();
      if (_statusFilter != 'all') {
        if (_statusFilter == 'pending_review' &&
            status != 'pending_review' &&
            status != 'pending') {
          return false;
        }
        if (_statusFilter == 'approved' && status != 'approved') return false;
        if (_statusFilter == 'rejected' && status != 'rejected') return false;
      }

      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final name = (r['providerName'] ?? r['fullName'] ?? '').toString().toLowerCase();
        final phone = (r['phoneNumber'] ?? r['phone'] ?? '').toString().toLowerCase();
        final service = (r['serviceName'] ?? r['requestedCategoryName'] ?? '').toString().toLowerCase();
        final area = (r['jamuiArea'] ?? '').toString().toLowerCase();

        final matches = name.contains(q) || phone.contains(q) || service.contains(q) || area.contains(q);
        if (!matches) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final totalCount = _requests.length;
    final pendingCount = _requests.where((r) {
      final s = (r['status']?.toString() ?? '').toLowerCase().trim();
      return s == 'pending_review' || s == 'pending' || s == '';
    }).length;
    final approvedCount = _requests.where((r) => (r['status']?.toString() ?? '').toLowerCase().trim() == 'approved').length;
    final rejectedCount = _requests.where((r) => (r['status']?.toString() ?? '').toLowerCase().trim() == 'rejected').length;

    final displayed = _filteredRequests;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sub-header & Refresh
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Provider New Category Requests', style: AppTextStyles.h2),
                const SizedBox(height: 4),
                Text(
                  'Requests submitted by providers when their specialized skill is not in current active categories.',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: _fetchData,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Refresh Requests'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // KPI Metric Cards
        Row(
          children: [
            _buildKpiCard('Total Category Requests', '$totalCount', Icons.category_outlined, Colors.indigo),
            const SizedBox(width: 12),
            _buildKpiCard('Pending Action (Review)', '$pendingCount', Icons.pending_actions_rounded, Colors.orange),
            const SizedBox(width: 12),
            _buildKpiCard('Approved Categories', '$approvedCount', Icons.check_circle_outline, Colors.green),
            const SizedBox(width: 12),
            _buildKpiCard('Rejected Requests', '$rejectedCount', Icons.cancel_outlined, Colors.red),
          ],
        ),
        const SizedBox(height: 20),

        // Filter & Search Controls
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Text('Status Filter:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(width: 12),
              _buildFilterChip('All Requests', 'all'),
              const SizedBox(width: 8),
              _buildFilterChip('Pending ($pendingCount)', 'pending_review', badgeColor: Colors.orange),
              const SizedBox(width: 8),
              _buildFilterChip('Approved ($approvedCount)', 'approved', badgeColor: Colors.green),
              const SizedBox(width: 8),
              _buildFilterChip('Rejected ($rejectedCount)', 'rejected', badgeColor: Colors.red),
              const Spacer(),

              // Search Bar
              SizedBox(
                width: 280,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by provider, phone, skill…',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Requests Table or Empty State
        if (_isLoading)
          const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator()))
        else if (displayed.isEmpty)
          Container(
            padding: const EdgeInsets.all(48),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text('No Category Requests Found', style: AppTextStyles.h3),
                const SizedBox(height: 4),
                Text('Currently there are no category requests matching the selected filter.', style: AppTextStyles.caption),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayed.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final req = displayed[index];
                return _buildRequestRow(req);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.caption, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(value, style: AppTextStyles.h2.copyWith(color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, {Color? badgeColor}) {
    final isSelected = _statusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _statusFilter = value);
      },
      selectedColor: (badgeColor ?? AppColors.primary).withValues(alpha: 0.15),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? (badgeColor ?? AppColors.primary) : AppColors.textPrimary,
      ),
    );
  }

  Widget _buildRequestRow(Map<String, dynamic> req) {
    final providerId = (req['providerId'] ?? req['docId'] ?? '').toString();
    final providerName = req['providerName']?.toString() ?? req['fullName']?.toString() ?? 'प्राइवेट प्रोवाइडर';
    final phone = req['phoneNumber']?.toString() ?? req['phone']?.toString() ?? 'N/A';
    final serviceName = req['serviceName']?.toString() ?? req['requestedCategoryName']?.toString() ?? 'अनुरोधित सेवा';
    final currentCat = (req['currentApprovedCategoryTitle'] ?? req['currentApprovedCategoryId'] ?? '').toString();
    final description = req['serviceDescription']?.toString() ?? 'विवरण उपलब्ध नहीं';
    final area = req['jamuiArea']?.toString() ?? 'जमुई';
    final exp = req['experienceYears']?.toString() ?? '1';
    final status = (req['status']?.toString() ?? 'pending_review').toLowerCase().trim();

    DateTime? createdAt;
    final rawTs = req['createdAt'];
    if (rawTs is Timestamp) createdAt = rawTs.toDate();
    if (rawTs is String) createdAt = DateTime.tryParse(rawTs);

    final dateStr = createdAt != null ? DateFormat('dd MMM yyyy, hh:mm a').format(createdAt) : 'Recent';

    final isPending = status == 'pending_review' || status == 'pending';
    final isApproved = status == 'approved';

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon badge
          CircleAvatar(
            radius: 20,
            backgroundColor: isPending
                ? Colors.orange.shade100
                : isApproved
                    ? Colors.green.shade100
                    : Colors.red.shade100,
            child: Icon(
              isPending
                  ? Icons.hourglass_top_rounded
                  : isApproved
                      ? Icons.check
                      : Icons.close,
              color: isPending
                  ? Colors.orange.shade800
                  : isApproved
                      ? Colors.green.shade800
                      : Colors.red.shade800,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),

          // Main Information
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      serviceName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                    ),
                    const SizedBox(width: 10),
                    StatusBadge.fromStatus(
                      isPending ? 'pending' : (isApproved ? 'approved' : 'rejected'),
                    ),
                    const Spacer(),
                    Text(dateStr, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 6),

                // Provider info line
                Row(
                  children: [
                    const Icon(Icons.person, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(providerName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(width: 12),
                    const Icon(Icons.phone, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(phone, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    const SizedBox(width: 12),
                    const Icon(Icons.location_on, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(area, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    const SizedBox(width: 12),
                    const Icon(Icons.workspace_premium, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text('$exp yrs exp', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 6),

                // Provider ID & Category Comparison
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        'Provider ID: $providerId',
                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Text(
                        'वर्तमान स्वीकृत: ${currentCat.isNotEmpty ? currentCat : "कोई नहीं (नया)"}',
                        style: TextStyle(fontSize: 11, color: Colors.blue.shade900, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.indigo.shade200),
                      ),
                      child: Text(
                        'अनुरोधित श्रेणी: $serviceName',
                        style: TextStyle(fontSize: 11, color: Colors.indigo.shade900, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Description
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(
                    description,
                    style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.35),
                  ),
                ),

                // If approved / rejected feedback exists
                if (req['adminFeedback'] != null || req['mappedCategoryTitle'] != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        isApproved ? Icons.verified : Icons.feedback_outlined,
                        size: 15,
                        color: isApproved ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isApproved
                            ? 'Mapped to Category: ${req['mappedCategoryTitle'] ?? req['mappedCategoryId']}'
                            : 'Admin Feedback: ${req['adminFeedback']}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isApproved ? Colors.green.shade800 : Colors.red.shade800,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 20),

          // Actions Column
          Column(
            children: [
              if (isPending) ...[
                ElevatedButton.icon(
                  onPressed: () => _showApproveDialog(req),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Approve Category'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _showRejectDialog(req),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Reject Request'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ] else ...[
                OutlinedButton.icon(
                  onPressed: () => _showApproveDialog(req),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Re-evaluate'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showApproveDialog(Map<String, dynamic> req) {
    final docId = req['docId']?.toString() ?? '';
    final providerId = req['providerId']?.toString() ?? docId;
    final serviceName = req['serviceName']?.toString() ?? req['requestedCategoryName']?.toString() ?? '';

    String? selectedCategoryId = _adminCategories.isNotEmpty ? _adminCategories.first['id']?.toString() : null;
    bool createNewCategory = false;
    final newIdCtrl = TextEditingController(text: serviceName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_'));
    final newTitleEnCtrl = TextEditingController(text: serviceName);
    final newTitleHiCtrl = TextEditingController(text: serviceName);
    final feedbackCtrl = TextEditingController(text: 'आपकी श्रेणी का अनुरोध स्वीकृत कर दिया गया है। कृपया रजिस्ट्रेशन जारी रखें।');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.green.shade100, shape: BoxShape.circle),
                child: const Icon(Icons.check_circle, color: Colors.green, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('Approve Category Request', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Requested Service: "$serviceName"',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Select how to map this request into active Jamui Services categories:',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),

                  // Option Selector
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<bool>(
                          value: false,
                          groupValue: createNewCategory,
                          title: const Text('Map to Existing Category', style: TextStyle(fontSize: 13)),
                          contentPadding: EdgeInsets.zero,
                          onChanged: (val) => setDlgState(() => createNewCategory = val ?? false),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<bool>(
                          value: true,
                          groupValue: createNewCategory,
                          title: const Text('Create New Category', style: TextStyle(fontSize: 13)),
                          contentPadding: EdgeInsets.zero,
                          onChanged: (val) => setDlgState(() => createNewCategory = val ?? false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (!createNewCategory) ...[
                    DropdownButtonFormField<String>(
                      value: selectedCategoryId,
                      decoration: InputDecoration(
                        labelText: 'Select Active Category',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: _adminCategories.map((c) {
                        final id = c['id']?.toString() ?? '';
                        final hi = c['titleHindi']?.toString() ?? '';
                        final en = c['titleEnglish']?.toString() ?? '';
                        return DropdownMenuItem(value: id, child: Text('$hi ($en)'));
                      }).toList(),
                      onChanged: (val) => setDlgState(() => selectedCategoryId = val),
                    ),
                  ] else ...[
                    TextField(
                      controller: newIdCtrl,
                      decoration: InputDecoration(
                        labelText: 'New Category ID (lowercase_slug)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: newTitleHiCtrl,
                      decoration: InputDecoration(
                        labelText: 'Category Title (Hindi / हिंदी)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: newTitleEnCtrl,
                      decoration: InputDecoration(
                        labelText: 'Category Title (English)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  TextField(
                    controller: feedbackCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Admin Note / Feedback to Provider',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),

                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.security, color: Colors.blue, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Important Security Rule: Category approval only links this approved category to the provider\'s registration state. It does NOT approve KYC, mark provider verified, or activate paid subscriptions.',
                            style: TextStyle(fontSize: 11.5, color: Colors.blue, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                await _executeApproval(
                  docId: docId,
                  providerId: providerId,
                  createNewCategory: createNewCategory,
                  selectedCategoryId: selectedCategoryId,
                  newCatId: newIdCtrl.text.trim(),
                  newCatTitleHi: newTitleHiCtrl.text.trim(),
                  newCatTitleEn: newTitleEnCtrl.text.trim(),
                  feedback: feedbackCtrl.text.trim(),
                );
              },
              child: const Text('Confirm Approval'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _executeApproval({
    required String docId,
    required String providerId,
    required bool createNewCategory,
    required String? selectedCategoryId,
    required String newCatId,
    required String newCatTitleHi,
    required String newCatTitleEn,
    required String feedback,
  }) async {
    setState(() => _isLoading = true);
    try {
      final now = FieldValue.serverTimestamp();
      final batch = FirebaseFirestore.instance.batch();

      String finalCatId = selectedCategoryId ?? '';
      String finalCatTitle = '';

      if (createNewCategory) {
        final slug = newCatId.isNotEmpty ? newCatId : 'cat_${DateTime.now().millisecondsSinceEpoch}';
        finalCatId = slug;
        finalCatTitle = newCatTitleHi.isNotEmpty ? newCatTitleHi : newCatTitleEn;

        final newCatRef = FirebaseFirestore.instance.collection('categories').doc(slug);
        batch.set(newCatRef, {
          'id': slug,
          'titleHindi': newCatTitleHi,
          'titleEnglish': newCatTitleEn,
          'description': '',
          'icon': 'handyman',
          'imageUrl': '',
          'subServices': [],
          'priorityOrder': 99,
          'isActive': true,
          'status': 'active',
          'isDeleted': false,
          'createdAt': now,
          'updatedAt': now,
        }, SetOptions(merge: true));
      } else {
        final match = _adminCategories.firstWhere(
          (c) => c['id'] == finalCatId,
          orElse: () => {'titleHindi': finalCatId, 'titleEnglish': finalCatId},
        );
        finalCatTitle = match['titleHindi']?.toString().isNotEmpty == true
            ? match['titleHindi']
            : (match['titleEnglish'] ?? finalCatId);
      }

      // Update category_requests document
      final reqRef = FirebaseFirestore.instance.collection('category_requests').doc(docId);
      batch.set(reqRef, {
        'status': 'approved',
        'mappedCategoryId': finalCatId,
        'mappedCategoryTitle': finalCatTitle,
        'adminFeedback': feedback,
        'reviewedAt': now,
        'reviewedBy': FirebaseAuth.instance.currentUser?.email ?? 'Admin',
        'updatedAt': now,
      }, SetOptions(merge: true));

      // Also update legacy collection if it exists
      final legacyRef = FirebaseFirestore.instance.collection('custom_service_applications').doc(docId);
      batch.set(legacyRef, {
        'status': 'approved',
        'mappedCategoryId': finalCatId,
        'mappedCategoryTitle': finalCatTitle,
        'adminFeedback': feedback,
        'reviewedAt': now,
        'reviewedBy': FirebaseAuth.instance.currentUser?.email ?? 'Admin',
        'updatedAt': now,
      }, SetOptions(merge: true));

      // Update Provider Registration State:
      // DO NOT set status: 'approved', kycStatus: 'approved', or isVerified: true!
      final providerRef = FirebaseFirestore.instance.collection('providers').doc(providerId);
      batch.update(providerRef, {
        'primaryCategoryId': finalCatId,
        'primaryCategoryTitle': finalCatTitle,
        'selectedCategoryId': finalCatId,
        'selectedCategoryIds': FieldValue.arrayUnion([finalCatId]),
        'customServiceStatus': 'approved',
        'categoryRequestStatus': 'approved',
        'categoryApprovalStatus': 'approved',
        'requestedCategoryId': FieldValue.delete(),
        'requestedCategoryTitle': FieldValue.delete(),
        'categoryRejectionReason': FieldValue.delete(),
        'registrationStatus': 'category_approved',
        'currentStep': 2, // Moves provider directly to Step 3: Business/Shop Details
        'updatedAt': now,
      });

      // Audit Log
      final auditRef = FirebaseFirestore.instance.collection('audit_logs').doc();
      batch.set(auditRef, {
        'action': 'CATEGORY_REQUEST_APPROVED',
        'requestId': docId,
        'providerId': providerId,
        'mappedCategoryId': finalCatId,
        'mappedCategoryTitle': finalCatTitle,
        'adminEmail': FirebaseAuth.instance.currentUser?.email ?? 'Admin',
        'timestamp': now,
      });

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Category request approved and mapped to "$finalCatTitle"'), backgroundColor: Colors.green),
      );
      await _fetchData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Approval failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showRejectDialog(Map<String, dynamic> req) {
    final docId = req['docId']?.toString() ?? '';
    final providerId = req['providerId']?.toString() ?? docId;
    final serviceName = req['serviceName']?.toString() ?? req['requestedCategoryName']?.toString() ?? '';
    final reasonCtrl = TextEditingController(text: 'वर्तमान में हम इस सेवा श्रेणी का संचालन नहीं कर रहे हैं। कृपया उपलब्ध श्रेणियों में से चुनें।');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.red.shade100, shape: BoxShape.circle),
              child: const Icon(Icons.cancel_outlined, color: Colors.red, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Reject Category Request', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Service: "$serviceName"', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text('Please provide a constructive reason to inform the provider:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Rejection Reason (प्रदाता को दिखेगा)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await _executeRejection(
                docId: docId,
                providerId: providerId,
                reason: reasonCtrl.text.trim(),
              );
            },
            child: const Text('Confirm Rejection'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeRejection({
    required String docId,
    required String providerId,
    required String reason,
  }) async {
    setState(() => _isLoading = true);
    try {
      final now = FieldValue.serverTimestamp();
      final batch = FirebaseFirestore.instance.batch();

      final reqRef = FirebaseFirestore.instance.collection('category_requests').doc(docId);
      batch.set(reqRef, {
        'status': 'rejected',
        'adminFeedback': reason,
        'reviewedAt': now,
        'reviewedBy': FirebaseAuth.instance.currentUser?.email ?? 'Admin',
        'updatedAt': now,
      }, SetOptions(merge: true));

      final legacyRef = FirebaseFirestore.instance.collection('custom_service_applications').doc(docId);
      batch.set(legacyRef, {
        'status': 'rejected',
        'adminFeedback': reason,
        'reviewedAt': now,
        'reviewedBy': FirebaseAuth.instance.currentUser?.email ?? 'Admin',
        'updatedAt': now,
      }, SetOptions(merge: true));

      final providerRef = FirebaseFirestore.instance.collection('providers').doc(providerId);
      batch.update(providerRef, {
        'customServiceStatus': 'rejected',
        'categoryRequestStatus': 'rejected',
        'categoryApprovalStatus': 'rejected',
        'categoryRejectionReason': reason,
        'rejectionReason': reason,
        'updatedAt': now,
      });

      // Audit Log
      final auditRef = FirebaseFirestore.instance.collection('audit_logs').doc();
      batch.set(auditRef, {
        'action': 'CATEGORY_REQUEST_REJECTED',
        'requestId': docId,
        'providerId': providerId,
        'reason': reason,
        'adminEmail': FirebaseAuth.instance.currentUser?.email ?? 'Admin',
        'timestamp': now,
      });

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category request marked as rejected.'), backgroundColor: Colors.orange),
      );
      await _fetchData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rejection failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
