import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/entities/professional_order_entity.dart';
import '../localization/ecom_strings.dart';
import '../theme/ecom_theme.dart';
import '../widgets/professional_order_success_animation.dart';
import 'professional_order_tracking_page.dart';

/// Modern, minimal, and premium "Thank You / Order Placed Successfully" screen.
///
/// Displayed ONLY after backend authoritative confirmation from `placeDiamondOrder`.
/// Shows real platform order number, seller order number, delivery summary,
/// self-drawing animated checkmark with confetti, and navigation options.
class ProfessionalOrderSuccessPage extends StatelessWidget {
  final ProfessionalOrderEntity order;
  final VoidCallback? onContinueShopping;
  final void Function(BuildContext context)? onTrackOrder;

  const ProfessionalOrderSuccessPage({
    super.key,
    required this.order,
    this.onContinueShopping,
    this.onTrackOrder,
  });

  String get _displayOrderNumber {
    final num = order.orderNumber;
    if (num.startsWith('JS-') || num.startsWith('ORD')) {
      return num;
    }
    return '#$num';
  }

  void _handleContinueShopping(BuildContext context) {
    if (onContinueShopping != null) {
      onContinueShopping!();
      return;
    }
    // Safely pop back to shop or home
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _handleTrackOrder(BuildContext context) {
    if (onTrackOrder != null) {
      onTrackOrder!(context);
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ProfessionalOrderTrackingPage(
          orderId: order.orderId,
          initialOrder: order,
        ),
      ),
    );
  }

  void _copyOrderNumber(BuildContext context) {
    Clipboard.setData(ClipboardData(text: order.orderNumber));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ऑर्डर नंबर कॉपी किया गया: $_displayOrderNumber'),
        duration: const Duration(seconds: 2),
        backgroundColor: EcomColors.primaryDark,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDelivery = order.fulfillmentType == 'delivery';
    final formattedTotal = ProfessionalOrderItem.formatCurrency(order.totalAmount);
    final itemsCount = order.items.fold<int>(0, (sum, it) => sum + it.quantity);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleContinueShopping(context);
      },
      child: Scaffold(
        backgroundColor: EcomColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.close_rounded, color: EcomColors.textSecondary),
              tooltip: EcomStrings.continueShopping,
              onPressed: () => _handleContinueShopping(context),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                  child: Column(
                    children: [
                      // Self-Drawing Checkmark with Celebratory Confetti
                      const ProfessionalOrderSuccessAnimation(size: 130),
                      const SizedBox(height: 12),

                      // Primary Title
                      Text(
                        EcomStrings.orderSuccessTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: EcomColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Secondary Title
                      Text(
                        EcomStrings.orderSuccessSubtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: EcomColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Platform Order Number & Seller Tag Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: EcomColors.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: EcomColors.cardBorder),
                          boxShadow: EcomColors.cardShadow,
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'प्लेटफ़ॉर्म ऑर्डर नंबर',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: EcomColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _displayOrderNumber,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                        color: EcomColors.primary,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _copyOrderNumber(context),
                                  icon: const Icon(Icons.copy_rounded, size: 14, color: EcomColors.primary),
                                  label: const Text(
                                    'कॉपी करें',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: EcomColors.primary),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    side: const BorderSide(color: EcomColors.primary, width: 1.2),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ],
                            ),
                            if (order.sellerOrderNumber != null && order.sellerOrderNumber!.isNotEmpty) ...[
                              const Divider(color: EcomColors.divider, height: 18),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: EcomColors.softGreen,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'दुकान ऑर्डर नंबर',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: EcomColors.primaryDark,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    order.sellerOrderNumber!,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: EcomColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Order Summary Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: EcomColors.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: EcomColors.cardBorder),
                          boxShadow: EcomColors.cardShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Store name & Fulfillment Pill
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      const Icon(Icons.storefront_rounded, size: 18, color: EcomColors.primary),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          order.shopName.isNotEmpty ? order.shopName : 'Professional Store',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: EcomColors.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDelivery ? const Color(0xFFEFF6FF) : const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isDelivery ? Icons.local_shipping_rounded : Icons.store_rounded,
                                        size: 12,
                                        color: isDelivery ? const Color(0xFF1D4ED8) : const Color(0xFFB45309),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isDelivery ? 'होम डिलीवरी' : 'दुकान से पिकअप',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isDelivery ? const Color(0xFF1D4ED8) : const Color(0xFFB45309),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(color: EcomColors.divider, height: 20),

                            // Items count & Total
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '$itemsCount सामान • ${order.paymentMode.toUpperCase() == 'COD' ? 'कैश ऑन डिलीवरी' : 'ऑनलाइन'}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: EcomColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  formattedTotal,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: EcomColors.primary,
                                  ),
                                ),
                              ],
                            ),

                            // Address or Pickup instructions
                            if (isDelivery && order.deliveryAddress != null) ...[
                              const SizedBox(height: 10),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.location_on_outlined, size: 16, color: EcomColors.textSecondary),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      [
                                        if (order.deliveryAddress!['address'] != null)
                                          order.deliveryAddress!['address'].toString(),
                                        if (order.deliveryAddress!['area'] != null &&
                                            order.deliveryAddress!['area'].toString().isNotEmpty)
                                          order.deliveryAddress!['area'].toString(),
                                      ].join(', '),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: EcomColors.textSecondary,
                                        height: 1.3,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Reassurance Note
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: EcomColors.softGreen,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle_outline_rounded, size: 18, color: EcomColors.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'दुकानदार को आपका ऑर्डर भेज दिया गया है और वह जल्द इसे तैयार करेंगे।',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: EcomColors.primaryDark,
                                  height: 1.35,
                                ),
                              ),
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
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: BoxDecoration(
                  color: EcomColors.surface,
                  boxShadow: EcomColors.floatingBarShadow,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Primary Action: Track Order
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () => _handleTrackOrder(context),
                        icon: const Icon(Icons.location_searching_rounded, size: 19),
                        label: Text(
                          EcomStrings.trackOrder,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: EcomColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Secondary Action: Continue Shopping
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () => _handleContinueShopping(context),
                        icon: const Icon(Icons.shopping_bag_outlined, size: 18, color: EcomColors.textPrimary),
                        label: Text(
                          EcomStrings.continueShopping,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: EcomColors.textPrimary,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: EcomColors.cardBorder, width: 1.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
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
}
