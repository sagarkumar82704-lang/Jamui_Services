import 'package:flutter/material.dart';
import '../../data/datasources/professional_shop_remote_data_source.dart';
import '../../domain/entities/professional_order_entity.dart';

class ProfessionalOrderTrackingPage extends StatelessWidget {
  final String orderId;
  final ProfessionalOrderEntity? initialOrder;

  const ProfessionalOrderTrackingPage({
    super.key,
    required this.orderId,
    this.initialOrder,
  });

  int _getStatusStepIndex(String status) {
    switch (status.toLowerCase()) {
      case 'placed':
        return 0;
      case 'accepted':
      case 'confirmed':
        return 1;
      case 'preparing':
        return 2;
      case 'out_for_delivery':
      case 'ready_for_pickup':
        return 3;
      case 'delivered':
      case 'collected':
      case 'completed':
        return 4;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataSource = ProfessionalShopRemoteDataSource();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Order #$orderId',
          style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
      ),
      body: StreamBuilder<ProfessionalOrderEntity?>(
        stream: dataSource.streamOrder(orderId),
        initialData: initialOrder,
        builder: (context, snapshot) {
          final order = snapshot.data ?? initialOrder;
          if (order == null) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)));
          }

          final currentStep = _getStatusStepIndex(order.status);
          final isDelivery = order.fulfillmentType == 'delivery';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order Status Banner Card (Matching Reference Image)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Order #${order.orderId}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              order.status.toUpperCase(),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Placed on ${order.createdAt.day} ${_getMonthName(order.createdAt.month)}, ${order.createdAt.year} • ${order.createdAt.hour}:${order.createdAt.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const Divider(height: 24),

                      if (order.status.toLowerCase() == 'rejected' || order.status.toLowerCase() == 'cancelled') ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFFCDD2)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.cancel_rounded, color: Color(0xFFC62828), size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      order.status.toLowerCase() == 'rejected' ? 'Order Declined by Shop' : 'Order Cancelled',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFC62828)),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      order.rejectionReason != null && order.rejectionReason!.isNotEmpty
                                          ? 'Reason: ${order.rejectionReason}'
                                          : 'This order was not fulfilled and inventory has been restored.',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFFB71C1C)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        // Stepper Timeline (Matching Reference Image)
                        _buildTimelineStep(
                          step: 0,
                          currentStep: currentStep,
                          title: 'Order Placed',
                          subtitle: 'Your order has been placed',
                        ),
                        _buildTimelineStep(
                          step: 1,
                          currentStep: currentStep,
                          title: 'Confirmed',
                          subtitle: 'Shop has confirmed your order',
                        ),
                        _buildTimelineStep(
                          step: 2,
                          currentStep: currentStep,
                          title: 'Preparing',
                          subtitle: 'Your order is being prepared',
                        ),
                        _buildTimelineStep(
                          step: 3,
                          currentStep: currentStep,
                          title: isDelivery ? 'Out for Delivery' : 'Ready for Pickup',
                          subtitle: isDelivery ? 'Your order is on the way' : 'Order is ready at store counter',
                        ),
                        _buildTimelineStep(
                          step: 4,
                          currentStep: currentStep,
                          title: isDelivery ? 'Delivered' : 'Collected',
                          subtitle: isDelivery ? 'Order delivered successfully' : 'Customer collected successfully',
                          isLast: true,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Order Items Summary Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'From: ${order.shopName}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 10),
                      ...order.items.map((it) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${it.title}  x${it.quantity} (${it.unit})', style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
                              Text('₹${it.total.toInt()}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                            ],
                          ),
                        );
                      }),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Grand Total', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                          Text('₹${order.totalAmount.toInt()}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF2E7D32))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Need Help? Contact Support Link (Matching Reference Image)
                Center(
                  child: TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.help_outline_rounded, color: Color(0xFF1E88E5), size: 18),
                    label: const Text(
                      'Need Help? Contact Support',
                      style: TextStyle(color: Color(0xFF1E88E5), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimelineStep({
    required int step,
    required int currentStep,
    required String title,
    required String subtitle,
    bool isLast = false,
  }) {
    final isDone = currentStep >= step;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isDone ? const Color(0xFF2E7D32) : Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isDone
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                    : Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 38,
                color: currentStep > step ? const Color(0xFF2E7D32) : Colors.grey.shade300,
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: isDone ? const Color(0xFF1E293B) : Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDone ? const Color(0xFF64748B) : Colors.grey.shade400,
                ),
              ),
              if (!isLast) const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }

  String _getMonthName(int m) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[m - 1];
  }
}

