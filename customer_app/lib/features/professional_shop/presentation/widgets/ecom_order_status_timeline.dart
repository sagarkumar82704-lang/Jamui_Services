import 'package:flutter/material.dart';
import '../localization/ecom_strings.dart';
import '../theme/ecom_theme.dart';

/// Status step metadata
class OrderTimelineStep {
  final String title;
  final String description;
  final String time;
  final bool isCompleted;
  final bool isCurrent;
  final bool isDeliveryRider;

  const OrderTimelineStep({
    required this.title,
    required this.description,
    required this.time,
    required this.isCompleted,
    required this.isCurrent,
    this.isDeliveryRider = false,
  });
}

/// Vertical Order Status Timeline matching Screen 5 of the reference design:
/// - Green checkmarks in circles
/// - Smooth vertical connecting lines
/// - Highlighted delivery scooter badge for Out-for-Delivery step
class EcomOrderStatusTimeline extends StatelessWidget {
  final String orderStatus;
  final bool isDelivery;
  final String orderDateFormatted;
  final String? estimatedTime;

  const EcomOrderStatusTimeline({
    super.key,
    required this.orderStatus,
    required this.isDelivery,
    required this.orderDateFormatted,
    this.estimatedTime,
  });

  bool get _isCancelledOrRejected {
    final s = orderStatus.toLowerCase().trim();
    return s == 'cancelled' || s == 'rejected';
  }

  int get _stepIndex {
    switch (orderStatus.toLowerCase().trim()) {
      case 'placed':
        return 0;
      case 'accepted':
      case 'confirmed':
      case 'preparing':
      case 'packing':
        return 1;
      case 'out_for_delivery':
      case 'ready_for_pickup':
        return 2;
      case 'delivered':
      case 'completed':
      case 'collected':
        return 3;
      default:
        return 0;
    }
  }

  List<OrderTimelineStep> _buildSteps() {
    if (_isCancelledOrRejected) {
      final isRejected = orderStatus.toLowerCase().trim() == 'rejected';
      return [
        OrderTimelineStep(
          title: EcomStrings.statusPlaced,
          description: EcomStrings.statusPlacedDesc,
          time: orderDateFormatted,
          isCompleted: true,
          isCurrent: false,
        ),
        OrderTimelineStep(
          title: isRejected ? EcomStrings.statusRejected : EcomStrings.statusCancelled,
          description: '',
          time: '',
          isCompleted: true,
          isCurrent: true,
        ),
      ];
    }

    final idx = _stepIndex;
    final isDelivered = idx >= 3;

    if (isDelivery) {
      return [
        OrderTimelineStep(
          title: EcomStrings.statusPlaced,
          description: EcomStrings.statusPlacedDesc,
          time: orderDateFormatted,
          isCompleted: idx >= 0,
          isCurrent: idx == 0,
        ),
        OrderTimelineStep(
          title: EcomStrings.statusPacking,
          description: EcomStrings.statusPackingDesc,
          time: '',
          isCompleted: idx >= 1,
          isCurrent: idx == 1,
        ),
        OrderTimelineStep(
          title: EcomStrings.statusOutForDelivery,
          description: EcomStrings.statusOutForDeliveryDesc,
          time: '',
          isCompleted: idx >= 2,
          isCurrent: idx == 2,
          isDeliveryRider: true,
        ),
        OrderTimelineStep(
          title: EcomStrings.statusDelivered,
          description: EcomStrings.statusDeliveredDesc,
          time: (!isDelivered && estimatedTime != null && estimatedTime!.isNotEmpty)
              ? EcomStrings.estimatedDelivery(estimatedTime!)
              : '',
          isCompleted: isDelivered,
          isCurrent: idx == 3,
        ),
      ];
    } else {
      return [
        OrderTimelineStep(
          title: EcomStrings.statusPlaced,
          description: EcomStrings.statusPlacedDesc,
          time: orderDateFormatted,
          isCompleted: idx >= 0,
          isCurrent: idx == 0,
        ),
        OrderTimelineStep(
          title: EcomStrings.statusPacking,
          description: EcomStrings.statusPackingDesc,
          time: '',
          isCompleted: idx >= 1,
          isCurrent: idx == 1,
        ),
        OrderTimelineStep(
          title: EcomStrings.statusReadyForPickup,
          description: EcomStrings.statusReadyForPickupDesc,
          time: '',
          isCompleted: idx >= 2,
          isCurrent: idx == 2,
        ),
        OrderTimelineStep(
          title: EcomStrings.statusPickedUp,
          description: EcomStrings.statusPickedUpDesc,
          time: '',
          isCompleted: isDelivered,
          isCurrent: idx == 3,
        ),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = _buildSteps();

    return Column(
      children: List.generate(steps.length, (index) {
        final step = steps[index];
        final isLast = index == steps.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Circle & Connecting Line
              Column(
                children: [
                  // Circle Icon
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (_isCancelledOrRejected && isLast)
                          ? const Color(0xFFE53935)
                          : (step.isCompleted ? EcomColors.primary : const Color(0xFFE2E8F0)),
                    ),
                    alignment: Alignment.center,
                    child: (_isCancelledOrRejected && isLast)
                        ? const Icon(Icons.close_rounded, color: Colors.white, size: 18)
                        : step.isCompleted
                            ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                            : Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                  ),

                  // Vertical Line
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2.5,
                        color: step.isCompleted ? EcomColors.primary : const Color(0xFFE2E8F0),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),

              // Right Column: Title, Description, and Rider Illustration if applicable
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 22),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Texts
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step.title,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: (_isCancelledOrRejected && isLast)
                                    ? const Color(0xFFE53935)
                                    : (step.isCompleted ? EcomColors.textPrimary : const Color(0xFF64748B)),
                              ),
                            ),
                            if (step.description.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                step.description,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: EcomColors.textSecondary,
                                ),
                              ),
                            ],
                            if (step.time.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                step.time,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: step.isCompleted ? EcomColors.primary : const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Delivery Scooter Illustration if step is Out For Delivery
                      if (step.isDeliveryRider && step.isCompleted)
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: EcomColors.softGreen,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: EcomColors.primary.withValues(alpha: 0.2)),
                          ),
                          child: const Icon(
                            Icons.two_wheeler_rounded,
                            color: EcomColors.primary,
                            size: 26,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

