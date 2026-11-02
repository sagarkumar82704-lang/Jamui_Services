import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../data/datasources/professional_provider_remote_data_source.dart';

/// Professional Seller Orders Management Page
/// Strictly adheres to backend state machine transitions in updateDiamondOrderStatus.
/// Enforces distinct Delivery vs Pickup workflows, mandatory rejection reason,
/// and rich order details inspection modal.
class ProfessionalShopOrdersPage extends StatefulWidget {
  final String shopId;
  final ProfessionalProviderRemoteDataSource? dataSource;

  const ProfessionalShopOrdersPage({
    super.key,
    required this.shopId,
    this.dataSource,
  });

  @override
  State<ProfessionalShopOrdersPage> createState() => _ProfessionalShopOrdersPageState();
}

class _ProfessionalShopOrdersPageState extends State<ProfessionalShopOrdersPage> {
  late final ProfessionalProviderRemoteDataSource _dataSource;
  String _activeTab = 'All'; // 'All', 'New', 'Preparing', 'Out', 'Completed', 'Rejected'
  late final Stream<List<Map<String, dynamic>>> _ordersStream;

  @override
  void initState() {
    super.initState();
    _dataSource = widget.dataSource ?? ProfessionalProviderRemoteDataSource();
    _ordersStream = _dataSource.streamShopOrders(widget.shopId);
  }

  Future<void> _showRejectionDialog(String orderId) async {
    final reasonController = TextEditingController();
    String? errorText;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final isValid = reasonController.text.trim().isNotEmpty;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.cancel_outlined, color: Color(0xFFC62828), size: 24),
                  SizedBox(width: 8),
                  Text('ऑर्डर अस्वीकार करें', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'अस्वीकृति का कारण लिखना अनिवार्य है (Mandatory Rejection Reason):',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    onChanged: (v) {
                      setDialogState(() {
                        errorText = v.trim().isEmpty ? 'कृपया कारण दर्ज करें' : null;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'उदा. स्टॉक अनुपलब्ध, दुकान समय समाप्त...',
                      hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      errorText: errorText,
                      contentPadding: const EdgeInsets.all(10),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('रद्द करें', style: TextStyle(color: Color(0xFF64748B))),
                ),
                ElevatedButton(
                  onPressed: isValid
                      ? () async {
                          final reason = reasonController.text.trim();
                          Navigator.pop(ctx);
                          await _performStatusUpdate(orderId, 'rejected', reason: reason);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC62828),
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                  child: const Text('अस्वीकार करें', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _performStatusUpdate(String orderId, String newStatus, {String? reason}) async {
    try {
      await _dataSource.updateOrderStatus(orderId, newStatus, rejectionReason: reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ऑर्डर स्थिति सफलतापूर्वक "$newStatus" में बदली गई'),
            backgroundColor: const Color(0xFF0F766E),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('स्थिति अपडेट विफल: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showOrderDetailsSheet(Map<String, dynamic> o) {
    final orderId = o['orderId'] ?? o['id'] ?? 'ORD';
    final custName = o['customerName'] ?? 'ग्राहक';
    final custPhone = o['customerPhone'] ?? '';
    final subtotal = (o['subtotal'] as num?)?.toInt() ?? 0;
    final deliveryFee = (o['deliveryFee'] as num?)?.toInt() ?? 0;
    final total = (o['totalAmount'] as num?)?.toInt() ?? (subtotal + deliveryFee);
    final st = (o['status'] as String?)?.toLowerCase().trim() ?? 'placed';
    final deliveryMethod = (o['deliveryMethod'] as String?) ?? (o['fulfillmentType'] as String?) ?? 'delivery';
    final isDelivery = deliveryMethod == 'delivery';
    final items = (o['items'] as List<dynamic>?) ?? [];
    final deliveryAddress = o['deliveryAddress'] as Map<String, dynamic>?;
    final customerNotes = (o['customerNotes'] as String?) ?? '';
    final rejectionReason = (o['rejectionReason'] as String?) ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (_, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ऑर्डर विवरण #$orderId', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                        const SizedBox(height: 2),
                        Text(_formatOrderTime(o['createdAt']), style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                    _buildStatusBadge(st),
                  ],
                ),
                const Divider(height: 24),

                // Fulfillment Mode & Customer Info
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDelivery ? const Color(0xFFEFF6FF) : const Color(0xFFF3E8FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDelivery ? const Color(0xFFBFDBFE) : const Color(0xFFE9D5FF)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isDelivery ? Icons.local_shipping_rounded : Icons.store_rounded,
                            size: 20,
                            color: isDelivery ? const Color(0xFF1D4ED8) : const Color(0xFF7E22CE),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isDelivery ? 'होम डिलीवरी (Home Delivery)' : 'दुकान से पिकअप (Store Pickup)',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: isDelivery ? const Color(0xFF1D4ED8) : const Color(0xFF7E22CE),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('ग्राहक: $custName', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                      if (custPhone.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text('फ़ोन: $custPhone', style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569))),
                      ],
                      if (isDelivery && deliveryAddress != null) ...[
                        const SizedBox(height: 6),
                        const Divider(height: 12),
                        const Text('डिलीवरी पता (Delivery Address):', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                        const SizedBox(height: 2),
                        Text(
                          '${deliveryAddress['fullAddress'] ?? deliveryAddress['address'] ?? ''}'
                          '${deliveryAddress['landmark'] != null ? ", समीप: ${deliveryAddress['landmark']}" : ""}'
                          '${deliveryAddress['pincode'] != null ? " - ${deliveryAddress['pincode']}" : ""}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                        ),
                      ],
                      if (!isDelivery) ...[
                        const SizedBox(height: 6),
                        const Text('ग्राहक स्वयं दुकान पर आकर सामान कलेक्ट करेंगे।', style: TextStyle(fontSize: 11.5, color: Color(0xFF7E22CE), fontWeight: FontWeight.w500)),
                      ],
                      if (customerNotes.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('नोट: "$customerNotes"', style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: Color(0xFF475569))),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Itemized Breakdown
                const Text('सामान की सूची (Ordered Items)', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => Divider(height: 1, color: Colors.grey.shade100),
                    itemBuilder: (context, idx) {
                      final it = items[idx] as Map<String, dynamic>;
                      final name = it['name'] ?? it['title'] ?? 'उत्पाद';
                      final qty = it['quantity'] ?? 1;
                      final unit = it['unit'] ?? '';
                      final price = (it['price'] as num?)?.toInt() ?? 0;
                      final itemTotal = (it['itemTotal'] as num?)?.toInt() ?? (price * (qty as int));

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                                  Text('₹$price x $qty ${unit.isNotEmpty ? "($unit)" : ""}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                                ],
                              ),
                            ),
                            Text('₹$itemTotal', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Bill Breakdown
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('वस्तुओं का मूल्य (Subtotal)', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                          Text('₹$subtotal', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('डिलीवरी शुल्क (Delivery Fee)', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                          Text(deliveryFee > 0 ? '₹$deliveryFee' : 'मुफ़्त (₹0)', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('कुल देय राशि (Total Amount)', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                          Text('₹$total', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F766E))),
                        ],
                      ),
                    ],
                  ),
                ),

                if (rejectionReason.isNotEmpty && (st == 'rejected' || st == 'cancelled')) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFEF9A9A)),
                    ),
                    child: Text(
                      'अस्वीकृति का कारण: "$rejectionReason"',
                      style: const TextStyle(fontSize: 12, color: Color(0xFFC62828), fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // Action Area inside modal sheet
                _buildActionForStatus(o['id'] ?? orderId, st, isDelivery, onFinished: () => Navigator.pop(ctx)),
                const SizedBox(height: 20),
              ],
            );
          },
        );
      },
    );
  }

  String _formatOrderTime(dynamic raw) {
    if (raw == null) return 'समय अज्ञात';
    DateTime? dt;
    if (raw is Timestamp) {
      dt = raw.toDate();
    } else if (raw is String) {
      dt = DateTime.tryParse(raw);
    } else if (raw is int) {
      dt = DateTime.fromMillisecondsSinceEpoch(raw);
    }
    if (dt == null) return 'समय अज्ञात';
    // Format to IST
    final ist = dt.toUtc().add(const Duration(hours: 5, minutes: 30));
    return '${ist.day}/${ist.month}/${ist.year} • ${ist.hour.toString().padLeft(2, '0')}:${ist.minute.toString().padLeft(2, '0')} IST';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'ऑर्डर प्रबंधन (Orders)',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _ordersStream,
        builder: (context, snapshot) {
          final allOrders = snapshot.data ?? [];
          final filtered = allOrders.where((o) {
            final st = (o['status'] as String?)?.toLowerCase().trim() ?? 'placed';
            if (_activeTab == 'New' && st != 'placed') return false;
            if (_activeTab == 'Preparing' && st != 'preparing' && st != 'accepted') return false;
            if (_activeTab == 'Out' && st != 'out_for_delivery' && st != 'ready_for_pickup') return false;
            if (_activeTab == 'Completed' && st != 'delivered' && st != 'collected') return false;
            if (_activeTab == 'Rejected' && st != 'rejected' && st != 'cancelled') return false;
            return true;
          }).toList();

          return Column(
            children: [
              // Order Filter Tabs
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTabChip('सभी (${allOrders.length})', 'All'),
                      const SizedBox(width: 8),
                      _buildTabChip('नए (New)', 'New'),
                      const SizedBox(width: 8),
                      _buildTabChip('प्रक्रियाधीन (Preparing)', 'Preparing'),
                      const SizedBox(width: 8),
                      _buildTabChip('डिस्पैच / तैयार', 'Out'),
                      const SizedBox(width: 8),
                      _buildTabChip('पूर्ण (Completed)', 'Completed'),
                      const SizedBox(width: 8),
                      _buildTabChip('अस्वीकृत (Rejected)', 'Rejected'),
                    ],
                  ),
                ),
              ),

              // Orders List
              Expanded(
                child: filtered.isEmpty
                    ? _buildEmptyOrders()
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (ctx, i) => _buildOrderCard(filtered[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTabChip(String label, String key) {
    final isSel = _activeTab == key;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSel ? const Color(0xFF0F766E) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSel ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> o) {
    final orderId = o['orderId'] ?? o['id'] ?? 'ORD';
    final custName = o['customerName'] ?? 'ग्राहक';
    final custPhone = o['customerPhone'] ?? '';
    final subtotal = (o['subtotal'] as num?)?.toInt() ?? 0;
    final deliveryFee = (o['deliveryFee'] as num?)?.toInt() ?? 0;
    final total = (o['totalAmount'] as num?)?.toInt() ?? (subtotal + deliveryFee);
    final st = (o['status'] as String?)?.toLowerCase().trim() ?? 'placed';
    final deliveryMethod = (o['deliveryMethod'] as String?) ?? (o['fulfillmentType'] as String?) ?? 'delivery';
    final isDelivery = deliveryMethod == 'delivery';
    final items = (o['items'] as List<dynamic>?) ?? [];
    final rejectionReason = (o['rejectionReason'] as String?) ?? '';

    return InkWell(
      onTap: () => _showOrderDetailsSheet(o),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('#$orderId', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                _buildStatusBadge(st),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.person_rounded, size: 15, color: Colors.grey),
                const SizedBox(width: 4),
                Text(custName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                if (custPhone.isNotEmpty) ...[
                  const Text(' • ', style: TextStyle(color: Colors.grey)),
                  Text(custPhone, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDelivery ? const Color(0xFFEFF6FF) : const Color(0xFFF3E8FF),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isDelivery ? 'होम डिलीवरी' : 'दुकान से पिकअप',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isDelivery ? const Color(0xFF1D4ED8) : const Color(0xFF7E22CE),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 18),

            // Items summary
            ...items.take(3).map((it) {
              final map = it as Map<String, dynamic>;
              final name = map['name'] ?? map['title'] ?? 'उत्पाद';
              final quantity = map['quantity'] ?? 1;
              final unit = map['unit'] ?? '';
              final itemTotal = (map['itemTotal'] as num?)?.toInt() ?? (map['total'] as num?)?.toInt() ?? 0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$name  x$quantity ${unit.isNotEmpty ? "($unit)" : ""}',
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
                    ),
                    Text('₹$itemTotal', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            }),
            if (items.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('+ ${items.length - 3} अन्य वस्तुएं...', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontStyle: FontStyle.italic)),
              ),
            const Divider(height: 18),

            // Bill Total & Delivery Breakdown
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('कुल राशि: ₹$total', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F766E))),
                    if (deliveryFee > 0)
                      Text('(वस्तु: ₹$subtotal + डिलीवरी: ₹$deliveryFee)', style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                  ],
                ),
                _buildActionForStatus(o['id'] ?? orderId, st, isDelivery),
              ],
            ),

            if (rejectionReason.isNotEmpty && (st == 'rejected' || st == 'cancelled')) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'अस्वीकृति कारण: $rejectionReason',
                  style: const TextStyle(fontSize: 11, color: Color(0xFFC62828), fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String st) {
    Color bg = const Color(0xFFE0F2F1);
    Color fg = const Color(0xFF0F766E);
    String label = st.toUpperCase();

    if (st == 'placed') {
      bg = const Color(0xFFEFF6FF);
      fg = const Color(0xFF1D4ED8);
      label = 'नया (PLACED)';
    } else if (st == 'accepted') {
      bg = const Color(0xFFE0F2F1);
      fg = const Color(0xFF0F766E);
      label = 'स्वीकृत (ACCEPTED)';
    } else if (st == 'preparing') {
      bg = const Color(0xFFFFF3E0);
      fg = const Color(0xFFE65100);
      label = 'तैयारी जारी (PREPARING)';
    } else if (st == 'out_for_delivery') {
      bg = const Color(0xFFE3F2FD);
      fg = const Color(0xFF1565C0);
      label = 'डिलीवरी हेतु रवाना (OUT)';
    } else if (st == 'ready_for_pickup') {
      bg = const Color(0xFFF3E8FF);
      fg = const Color(0xFF7E22CE);
      label = 'पिकअप हेतु तैयार (READY)';
    } else if (st == 'delivered' || st == 'collected') {
      bg = const Color(0xFFE8F5E9);
      fg = const Color(0xFF2E7D32);
      label = 'वितरित (DELIVERED)';
    } else if (st == 'rejected' || st == 'cancelled') {
      bg = const Color(0xFFFFEBEE);
      fg = const Color(0xFFC62828);
      label = 'रद्द / अस्वीकृत';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg)),
    );
  }

  Widget _buildActionForStatus(String docId, String st, bool isDelivery, {VoidCallback? onFinished}) {
    if (st == 'placed') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton(
            onPressed: () {
              onFinished?.call();
              _showRejectionDialog(docId);
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFC62828)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            child: const Text('अस्वीकार', style: TextStyle(fontSize: 11.5, color: Color(0xFFC62828), fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () async {
              onFinished?.call();
              await _performStatusUpdate(docId, 'accepted');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            child: const Text('स्वीकार करें', style: TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      );
    } else if (st == 'accepted') {
      return ElevatedButton(
        onPressed: () async {
          onFinished?.call();
          await _performStatusUpdate(docId, 'preparing');
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE65100),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
        child: const Text('तैयारी शुरू करें', style: TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.bold)),
      );
    } else if (st == 'preparing') {
      final nextStatus = isDelivery ? 'out_for_delivery' : 'ready_for_pickup';
      final label = isDelivery ? 'डिस्पैच करें' : 'पिकअप हेतु तैयार';
      return ElevatedButton(
        onPressed: () async {
          onFinished?.call();
          await _performStatusUpdate(docId, nextStatus);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1565C0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
        child: Text(label, style: const TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.bold)),
      );
    } else if (st == 'out_for_delivery' || st == 'ready_for_pickup') {
      final label = isDelivery ? 'डिलीवर हो गया' : 'ग्राहक को सौंपा गया';
      return ElevatedButton(
        onPressed: () async {
          onFinished?.call();
          await _performStatusUpdate(docId, 'delivered');
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2E7D32),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
        child: Text(label, style: const TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.bold)),
      );
    } else if (st == 'delivered' || st == 'collected') {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 18),
          SizedBox(width: 4),
          Text('पूर्ण', style: TextStyle(fontSize: 12, color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
        ],
      );
    }
    // Terminal states (rejected, cancelled): display no active buttons
    return const SizedBox.shrink();
  }

  Widget _buildEmptyOrders() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined, size: 54, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text('कोई ऑर्डर नहीं मिला', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
        ],
      ),
    );
  }
}
