import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/status_badge.dart';
import '../widgets/category_requests_section.dart';

class ComplaintsPage extends StatefulWidget {
  const ComplaintsPage({super.key});

  @override
  State<ComplaintsPage> createState() => _ComplaintsPageState();
}

class _ComplaintsPageState extends State<ComplaintsPage> {
  int _selectedMainTab = 0; // 0: Tickets, 1: Category Requests
  bool _isLoading = true;
  List<Map<String, dynamic>> _allTickets = [];
  String _searchQuery = '';
  String _sourceFilter = 'all'; // 'all', 'customer', 'provider'
  String _statusFilter = 'all'; // 'all', 'open', 'in progress', 'waiting for response', 'resolved', 'closed'

  @override
  void initState() {
    super.initState();
    _fetchTickets();
  }

  Future<void> _fetchTickets() async {
    setState(() => _isLoading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('complaints')
          .limit(200)
          .get();

      final list = snap.docs.map((d) {
        final data = d.data();
        return {
          'docId': d.id,
          'id': d.id,
          ...data,
        };
      }).toList();

      // Sort by createdAt descending
      list.sort((a, b) {
        final aTs = a['createdAt'] as Timestamp?;
        final bTs = b['createdAt'] as Timestamp?;
        if (aTs == null) return 1;
        if (bTs == null) return -1;
        return bTs.compareTo(aTs);
      });

      setState(() {
        _allTickets = list;
      });
    } catch (e) {
      debugPrint('⚠️ [ComplaintsPage] Error fetching tickets: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Determines true authenticated role/source based on database fields
  String _getTicketSource(Map<String, dynamic> ticket) {
    final ownerRole = ticket['ownerRole']?.toString().toLowerCase();
    if (ownerRole == 'customer') return 'customer';
    if (ownerRole == 'provider') return 'provider';

    // Fallback checks on existing DB records
    if (ticket.containsKey('providerId') && ticket['providerId']?.toString().isNotEmpty == true) {
      return 'provider';
    }
    if (ticket.containsKey('customerId') && ticket['customerId']?.toString().isNotEmpty == true) {
      return 'customer';
    }
    return 'customer'; // Default safe assumption
  }

  List<Map<String, dynamic>> get _filteredTickets {
    return _allTickets.where((t) {
      final source = _getTicketSource(t);
      if (_sourceFilter == 'customer' && source != 'customer') return false;
      if (_sourceFilter == 'provider' && source != 'provider') return false;

      final status = (t['status']?.toString() ?? 'open').toLowerCase().trim();
      if (_statusFilter != 'all' && status != _statusFilter.toLowerCase()) return false;

      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final id = (t['ticketId'] ?? t['docId'] ?? '').toString().toLowerCase();
        final name = (t['senderName'] ?? t['providerName'] ?? t['customerName'] ?? '').toString().toLowerCase();
        final phone = (t['senderPhone'] ?? t['providerPhone'] ?? t['customerPhone'] ?? '').toString().toLowerCase();
        final subject = (t['subject'] ?? t['category'] ?? '').toString().toLowerCase();

        final matches = id.contains(q) || name.contains(q) || phone.contains(q) || subject.contains(q);
        if (!matches) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final totalCount = _allTickets.length;
    final customerCount = _allTickets.where((t) => _getTicketSource(t) == 'customer').length;
    final providerCount = _allTickets.where((t) => _getTicketSource(t) == 'provider').length;
    final openCount = _allTickets.where((t) => (t['status']?.toString().toLowerCase() ?? 'open') == 'open').length;
    final inProgressCount = _allTickets.where((t) => (t['status']?.toString().toLowerCase() ?? '') == 'in progress').length;
    final resolvedCount = _allTickets.where((t) => (t['status']?.toString().toLowerCase() ?? '') == 'resolved').length;
    final closedCount = _allTickets.where((t) => (t['status']?.toString().toLowerCase() ?? '') == 'closed').length;

    final displayed = _filteredTickets;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Tab Selector (Support Tickets vs Provider Category Requests)
        Container(
          margin: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              _buildTopNavTab(
                title: 'Customer & Provider Support Tickets',
                subtitle: 'Dispute resolution, complaints & 2-way conversations',
                icon: Icons.confirmation_number_outlined,
                isSelected: _selectedMainTab == 0,
                badgeCount: openCount,
                onTap: () => setState(() => _selectedMainTab = 0),
              ),
              const SizedBox(width: 8),
              _buildTopNavTab(
                title: 'Provider Category Requests (नई श्रेणी अनुरोध)',
                subtitle: 'Review & approve unlisted category requests from providers',
                icon: Icons.category_rounded,
                isSelected: _selectedMainTab == 1,
                onTap: () => setState(() => _selectedMainTab = 1),
              ),
            ],
          ),
        ),
        Expanded(
          child: _selectedMainTab == 1
              ? const CategoryRequestsSection()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Customer & Provider Support Tickets', style: AppTextStyles.h2),
                  const SizedBox(height: 4),
                  Text('Comprehensive dispute resolution, audit trail & 2-way conversation system', style: AppTextStyles.caption),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _fetchTickets,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh Tickets'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Overview KPI Cards
          Row(
            children: [
              _buildKpiCard('Total Tickets', '$totalCount', Icons.confirmation_number_outlined, Colors.indigo),
              const SizedBox(width: 12),
              _buildKpiCard('Customer Complaints', '$customerCount', Icons.person_outline, Colors.blue),
              const SizedBox(width: 12),
              _buildKpiCard('Provider Complaints', '$providerCount', Icons.handyman_outlined, Colors.purple),
              const SizedBox(width: 12),
              _buildKpiCard('Open (Action Req.)', '$openCount', Icons.warning_amber_rounded, Colors.orange),
              const SizedBox(width: 12),
              _buildKpiCard('In Progress', '$inProgressCount', Icons.timelapse_rounded, Colors.teal),
              const SizedBox(width: 12),
              _buildKpiCard('Resolved / Closed', '${resolvedCount + closedCount}', Icons.check_circle_outline, Colors.green),
            ],
          ),
          const SizedBox(height: 24),

          // Controls Card (Source Filters + Status Dropdown + Search)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                // Source Tabs
                const Text('Source:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(width: 10),
                _buildSourceFilterChip('All Tickets', 'all', totalCount),
                const SizedBox(width: 8),
                _buildSourceFilterChip('Customer Complaints', 'customer', customerCount),
                const SizedBox(width: 8),
                _buildSourceFilterChip('Provider Complaints', 'provider', providerCount),

                const Spacer(),

                // Status Filter
                const Text('Status:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _statusFilter,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                    DropdownMenuItem(value: 'open', child: Text('Open')),
                    DropdownMenuItem(value: 'in progress', child: Text('In Progress')),
                    DropdownMenuItem(value: 'waiting for response', child: Text('Waiting for Response')),
                    DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                    DropdownMenuItem(value: 'closed', child: Text('Closed')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _statusFilter = v);
                  },
                ),
                const SizedBox(width: 16),

                // Search Bar
                SizedBox(
                  width: 260,
                  height: 38,
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Search by ID, name, mobile...',
                      hintStyle: AppTextStyles.caption,
                      prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textMuted),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Main Tickets Table
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(48.0),
                    child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  )
                : displayed.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(48.0),
                        child: Center(
                          child: Text('No complaints match the selected filters.', style: TextStyle(color: AppColors.textMuted)),
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(AppColors.surfaceSubtle),
                          headingTextStyle: AppTextStyles.bodyBold.copyWith(fontSize: 12, color: AppColors.textSecondary),
                          dataTextStyle: AppTextStyles.body.copyWith(fontSize: 12.5),
                          horizontalMargin: 16,
                          columnSpacing: 20,
                          columns: const [
                            DataColumn(label: Text('TICKET ID')),
                            DataColumn(label: Text('SOURCE')),
                            DataColumn(label: Text('SENDER DETAILS')),
                            DataColumn(label: Text('SUBJECT / CATEGORY')),
                            DataColumn(label: Text('STATUS')),
                            DataColumn(label: Text('DATE & TIME')),
                            DataColumn(label: Text('ACTION')),
                          ],
                          rows: displayed.map((t) {
                            final ticketId = t['ticketId']?.toString() ?? 'TKT-${t['docId'].toString().substring(0, 8)}';
                            final source = _getTicketSource(t);
                            final isCustomer = source == 'customer';

                            final senderName = t['senderName']?.toString() ??
                                (isCustomer ? (t['customerName'] ?? 'Customer') : (t['providerName'] ?? 'Provider Partner'));
                            final senderPhone = t['senderPhone']?.toString() ??
                                (isCustomer ? t['customerPhone'] : t['providerPhone']) ??
                                'Not provided';

                            final subject = t['subject']?.toString() ?? t['description']?.toString() ?? 'Support Request';
                            final category = t['category']?.toString() ?? 'General';
                            final status = t['status']?.toString() ?? 'Open';

                            DateTime? createdAt;
                            final ts = t['createdAt'];
                            if (ts is Timestamp) createdAt = ts.toDate();

                            return DataRow(
                              cells: [
                                // Ticket ID
                                DataCell(
                                  Row(
                                    children: [
                                      Text(ticketId, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                                      IconButton(
                                        icon: const Icon(Icons.copy_rounded, size: 14, color: AppColors.textMuted),
                                        tooltip: 'Copy Ticket ID',
                                        onPressed: () {
                                          Clipboard.setData(ClipboardData(text: ticketId));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Ticket ID copied!'), duration: Duration(seconds: 1)),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                // Source Badge
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isCustomer ? Colors.blue.withValues(alpha: 0.1) : Colors.purple.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: isCustomer ? Colors.blue : Colors.purple, width: 0.8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(isCustomer ? Icons.person_rounded : Icons.handyman_rounded,
                                            size: 12, color: isCustomer ? Colors.blue.shade800 : Colors.purple.shade800),
                                        const SizedBox(width: 4),
                                        Text(
                                          isCustomer ? 'Customer App' : 'Provider App',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isCustomer ? Colors.blue.shade900 : Colors.purple.shade900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Sender Details
                                DataCell(
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(senderName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      Text('📞 $senderPhone', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                    ],
                                  ),
                                ),
                                // Subject / Category
                                DataCell(
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 220),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          subject,
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          category,
                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Status
                                DataCell(StatusBadge.fromStatus(status)),
                                // Date & Time
                                DataCell(
                                  Text(
                                    createdAt != null ? DateFormat('dd/MM/yyyy\nhh:mm a').format(createdAt) : 'N/A',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                  ),
                                ),
                                // Action Button
                                DataCell(
                                  ElevatedButton.icon(
                                    onPressed: () => _openTicketDetailsDialog(t),
                                    icon: const Icon(Icons.forum_outlined, size: 14),
                                    label: const Text('View & Reply', style: TextStyle(fontSize: 11.5)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
          ),
        ],
      ),
    ),
  ),
],
);
}

  Widget _buildTopNavTab({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    int? badgeCount,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              color: isSelected ? AppColors.primary : AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (badgeCount != null && badgeCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$badgeCount',
                              style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected ? AppColors.primary.withValues(alpha: 0.85) : AppColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard(String label, String value, IconData icon, Color color) {
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
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: AppTextStyles.h3),
                Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceFilterChip(String label, String value, int count) {
    final isSelected = _sourceFilter == value;
    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: isSelected ? Colors.white : AppColors.textPrimary,
      ),
      onSelected: (_) => setState(() => _sourceFilter = value),
    );
  }

  /// Interactive Ticket Details, Status Transitions, and 2-way Conversation Dialog
  void _openTicketDetailsDialog(Map<String, dynamic> initialTicket) {
    final docId = initialTicket['docId'];
    final replyController = TextEditingController();
    bool isReplying = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('complaints').doc(docId).snapshots(),
              builder: (context, snapshot) {
                final ticket = (snapshot.data?.data() as Map<String, dynamic>?) ?? initialTicket;

                final ticketId = ticket['ticketId']?.toString() ?? 'TKT-${docId.substring(0, 8)}';
                final source = _getTicketSource(ticket);
                final isCustomer = source == 'customer';
                final status = ticket['status']?.toString() ?? 'Open';
                final subject = ticket['subject']?.toString() ?? ticket['description']?.toString() ?? 'Support Request';
                final category = ticket['category']?.toString() ?? 'General';
                final description = ticket['description']?.toString() ?? ticket['message']?.toString() ?? '';

                final senderName = ticket['senderName']?.toString() ??
                    (isCustomer ? ticket['customerName'] : ticket['providerName']) ??
                    (isCustomer ? 'Customer' : 'Provider Partner');
                final senderPhone = ticket['senderPhone']?.toString() ??
                    (isCustomer ? ticket['customerPhone'] : ticket['providerPhone']) ??
                    'Not provided';
                final senderEmail = ticket['senderEmail']?.toString() ?? 'Not provided';
                final ownerUid = ticket['ownerUid'] ?? (isCustomer ? ticket['customerId'] : ticket['providerId']) ?? 'Not provided';

                final messages = (ticket['messages'] as List<dynamic>?) ?? [];
                final statusHistory = (ticket['statusHistory'] as List<dynamic>?) ?? [];

                return Dialog(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                  child: Container(
                    width: 900,
                    height: 650,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Dialog Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(ticketId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary)),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isCustomer ? Colors.blue.withValues(alpha: 0.1) : Colors.purple.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isCustomer ? 'Customer App' : 'Provider App',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isCustomer ? Colors.blue.shade900 : Colors.purple.shade900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                StatusBadge.fromStatus(status),
                                if (statusHistory.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Tooltip(
                                    message: '${statusHistory.length} status change audit entries recorded',
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.grey.shade300),
                                      ),
                                      child: Text(
                                        '${statusHistory.length} audit logs',
                                        style: TextStyle(fontSize: 10, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(dialogCtx),
                            ),
                          ],
                        ),
                        const Divider(height: 24),

                        // Body (2-Column: Left Meta & Actions, Right Conversation Thread)
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Left Column: Sender Details, Description & Status Actions
                              Expanded(
                                flex: 4,
                                child: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Sender Card
                                      Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceSubtle,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: AppColors.border),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('SENDER DETAILS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                                            const SizedBox(height: 8),
                                            _buildDetailRow('Name', senderName),
                                            _buildDetailRow('Phone', senderPhone),
                                            _buildDetailRow('Email', senderEmail),
                                            _buildDetailRow('Role', isCustomer ? 'Customer' : 'Provider Partner'),
                                            _buildDetailRow('User UID', ownerUid.toString()),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 14),

                                      // Subject & Initial Message
                                      Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: AppColors.border),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Category: $category', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                            const SizedBox(height: 4),
                                            Text(subject, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                            const SizedBox(height: 6),
                                            Text(description, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 16),

                                      // Status Transition Actions
                                      const Text('CHANGE TICKET STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _buildStatusActionButton(docId, 'In Progress', Colors.blue, status),
                                          _buildStatusActionButton(docId, 'Waiting for Response', Colors.orange, status),
                                          _buildStatusActionButton(docId, 'Resolved', Colors.green, status),
                                          _buildStatusActionButton(docId, 'Closed', Colors.grey.shade700, status),
                                          if (status.toLowerCase() == 'closed' || status.toLowerCase() == 'resolved')
                                            _buildStatusActionButton(docId, 'Open', Colors.amber.shade900, status, label: 'Reopen Ticket'),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 20),

                              // Right Column: Full Conversation Thread + Admin Reply Box
                              Expanded(
                                flex: 6,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: const BoxDecoration(
                                          border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('Conversation History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                            Text('${messages.length} messages', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                          ],
                                        ),
                                      ),

                                      // Messages list
                                      Expanded(
                                        child: messages.isEmpty
                                            ? const Center(child: Text('No replies yet.', style: TextStyle(color: AppColors.textMuted)))
                                            : ListView.builder(
                                                padding: const EdgeInsets.all(14),
                                                itemCount: messages.length,
                                                itemBuilder: (context, i) {
                                                  final m = messages[i] as Map<String, dynamic>;
                                                  final role = m['senderRole']?.toString().toLowerCase() ?? 'customer';
                                                  final isAdmin = role == 'admin';
                                                  final text = m['message']?.toString() ?? '';
                                                  final senderLabel = m['senderName']?.toString() ?? (isAdmin ? 'Admin' : senderName);

                                                  DateTime? msgTime;
                                                  final ts = m['timestamp'];
                                                  if (ts is Timestamp) msgTime = ts.toDate();

                                                  return Align(
                                                    alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
                                                    child: Container(
                                                      margin: const EdgeInsets.only(bottom: 10),
                                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                                      constraints: const BoxConstraints(maxWidth: 380),
                                                      decoration: BoxDecoration(
                                                        color: isAdmin ? AppColors.primary : Colors.white,
                                                        borderRadius: BorderRadius.only(
                                                          topLeft: const Radius.circular(12),
                                                          topRight: const Radius.circular(12),
                                                          bottomLeft: Radius.circular(isAdmin ? 12 : 2),
                                                          bottomRight: Radius.circular(isAdmin ? 2 : 12),
                                                        ),
                                                        border: isAdmin ? null : Border.all(color: const Color(0xFFE2E8F0)),
                                                        boxShadow: [
                                                          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4),
                                                        ],
                                                      ),
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            isAdmin ? '🛡️ Admin Support' : '👤 $senderLabel',
                                                            style: TextStyle(
                                                              fontSize: 10.5,
                                                              fontWeight: FontWeight.bold,
                                                              color: isAdmin ? Colors.white70 : AppColors.primary,
                                                            ),
                                                          ),
                                                          const SizedBox(height: 3),
                                                          Text(
                                                            text,
                                                            style: TextStyle(
                                                              fontSize: 12.5,
                                                              color: isAdmin ? Colors.white : AppColors.textPrimary,
                                                              height: 1.3,
                                                            ),
                                                          ),
                                                          if (msgTime != null) ...[
                                                            const SizedBox(height: 4),
                                                            Align(
                                                              alignment: Alignment.bottomRight,
                                                              child: Text(
                                                                DateFormat('dd MMM, hh:mm a').format(msgTime),
                                                                style: TextStyle(
                                                                  fontSize: 9.5,
                                                                  color: isAdmin ? Colors.white60 : AppColors.textMuted,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                      ),

                                      // Admin Reply Box
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                                          borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                                        ),
                                        child: Column(
                                          children: [
                                            // Canned Quick Response Chips
                                            Row(
                                              children: [
                                                const Text('Quick:', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                                const SizedBox(width: 6),
                                                _buildQuickChip('जांच की जा रही है।', replyController),
                                                const SizedBox(width: 6),
                                                _buildQuickChip('आपकी समस्या का समाधान कर दिया गया है।', replyController),
                                                const SizedBox(width: 6),
                                                _buildQuickChip('कृपया अधिक विवरण प्रदान करें।', replyController),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: TextField(
                                                    controller: replyController,
                                                    maxLines: 2,
                                                    decoration: InputDecoration(
                                                      hintText: 'Type admin reply to ${isCustomer ? 'customer' : 'partner'}...',
                                                      hintStyle: const TextStyle(fontSize: 12),
                                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                ElevatedButton.icon(
                                                  onPressed: isReplying
                                                      ? null
                                                      : () async {
                                                          final text = replyController.text.trim();
                                                          if (text.isEmpty) return;

                                                          setDialogState(() => isReplying = true);
                                                          try {
                                                            final adminUser = FirebaseAuth.instance.currentUser;
                                                            final newMsg = {
                                                              'senderId': adminUser?.uid ?? 'admin',
                                                              'senderRole': 'admin',
                                                              'senderName': adminUser?.email ?? 'Jamui Support Admin',
                                                              'message': text,
                                                              'timestamp': Timestamp.now(),
                                                            };

                                                            await FirebaseFirestore.instance.collection('complaints').doc(docId).update({
                                                              'messages': FieldValue.arrayUnion([newMsg]),
                                                              'lastMessageAt': FieldValue.serverTimestamp(),
                                                              'lastMessageBy': 'admin',
                                                              'updatedAt': FieldValue.serverTimestamp(),
                                                              if (status == 'Open') 'status': 'In Progress',
                                                            });

                                                            replyController.clear();
                                                            _fetchTickets(); // background table refresh
                                                          } catch (e) {
                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                              SnackBar(content: Text('Failed to send reply: $e')),
                                                            );
                                                          } finally {
                                                            setDialogState(() => isReplying = false);
                                                          }
                                                        },
                                                  icon: isReplying
                                                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                                      : const Icon(Icons.send_rounded, size: 16),
                                                  label: const Text('Send Reply'),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: AppColors.primary,
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                                  ),
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
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildQuickChip(String text, TextEditingController controller) {
    return InkWell(
      onTap: () => controller.text = text,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(text, style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusActionButton(String docId, String targetStatus, Color color, String currentStatus, {String? label}) {
    final isCurrent = currentStatus.toLowerCase() == targetStatus.toLowerCase();
    return OutlinedButton(
      onPressed: isCurrent
          ? null
          : () async {
              try {
                final adminUser = FirebaseAuth.instance.currentUser;
                final auditEntry = {
                  'status': targetStatus,
                  'changedBy': adminUser?.email ?? 'admin',
                  'timestamp': Timestamp.now(),
                  'note': 'Status updated to $targetStatus by admin',
                };

                await FirebaseFirestore.instance.collection('complaints').doc(docId).update({
                  'status': targetStatus,
                  'statusHistory': FieldValue.arrayUnion([auditEntry]),
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Status changed to $targetStatus'), backgroundColor: color),
                );
                _fetchTickets();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to update status: $e'), backgroundColor: Colors.red),
                );
              }
            },
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: isCurrent ? Colors.grey.shade300 : color),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(
        label ?? targetStatus,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isCurrent ? Colors.grey : color,
        ),
      ),
    );
  }
}
