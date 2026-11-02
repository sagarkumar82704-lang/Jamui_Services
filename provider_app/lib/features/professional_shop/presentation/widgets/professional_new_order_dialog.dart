import 'package:flutter/material.dart';
import '../../data/datasources/professional_provider_remote_data_source.dart';

class ProfessionalNewOrderDialog extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onDismiss;

  const ProfessionalNewOrderDialog({
    super.key,
    required this.order,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final ds = ProfessionalProviderRemoteDataSource();
    final orderId = (order['orderId'] as String?) ?? order['id'] ?? 'ORD';
    final customerName = (order['customerName'] as String?) ?? 'Customer';
    final totalAmount = (order['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final addressMap = order['deliveryAddress'] as Map<String, dynamic>?;
    final address = addressMap != null ? (addressMap['address'] ?? 'Jamui') : 'Laxmi Chowk, Jamui';
    final items = (order['items'] as List<dynamic>?) ?? [];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Bell Icon & Title (Matching Reference Image)
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF3E0),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.notifications_active_rounded, color: Color(0xFFE65100), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'New Order Received!',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      Text(
                        '#$orderId',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Customer Name & Total Bill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  customerName,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                Text(
                  '₹${totalAmount.toInt()} • ${items.length} Items',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Delivery Address
            Row(
              children: [
                const Icon(Icons.location_on_outlined, color: Colors.grey, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Deliver to: $address',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Item Breakdown List (Matching Reference Image)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: items.map((it) {
                  final map = it as Map<String, dynamic>;
                  final title = map['title'] ?? 'Item';
                  final qty = map['quantity'] ?? 1;
                  final unit = map['unit'] ?? '';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('• $title', style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155))),
                        Text('$qty $unit', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons: Accept Order (Green) & Reject Order (Red)
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () async {
                  await ds.updateOrderStatus(order['id'] ?? orderId, 'accepted');
                  onDismiss();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E), // Deep Teal from Reference
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Accept Order', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: () async {
                  await ds.updateOrderStatus(order['id'] ?? orderId, 'rejected', rejectionReason: 'Shop busy / Item unavailable');
                  onDismiss();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFE53935),
                  side: const BorderSide(color: Color(0xFFE53935)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Reject Order', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

