import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/datasources/professional_shop_remote_data_source.dart';
import '../../domain/entities/professional_order_entity.dart';
import '../../services/professional_receipt_service.dart';
import '../localization/ecom_locale_controller.dart';
import '../localization/ecom_strings.dart';
import '../theme/ecom_theme.dart';
import '../widgets/ecom_order_status_timeline.dart';
import '../widgets/professional_order_receipt_sheet.dart';

class ProfessionalOrderTrackingPage extends StatefulWidget {
  final String orderId;
  final ProfessionalOrderEntity? initialOrder;
  final Stream<ProfessionalOrderEntity?>? orderStream;

  const ProfessionalOrderTrackingPage({
    super.key,
    required this.orderId,
    this.initialOrder,
    this.orderStream,
  });

  @override
  State<ProfessionalOrderTrackingPage> createState() => _ProfessionalOrderTrackingPageState();
}

class _ProfessionalOrderTrackingPageState extends State<ProfessionalOrderTrackingPage> {
  final ProfessionalShopRemoteDataSource _dataSource = ProfessionalShopRemoteDataSource();
  final ProfessionalReceiptService _receiptService = ProfessionalReceiptService();
  bool _showDetails = false;
  bool _isDownloadingPdf = false;
  bool _isSharingPdf = false;

  Future<void> _downloadOrderPdf(ProfessionalOrderEntity order) async {
    if (_isDownloadingPdf) return;
    setState(() => _isDownloadingPdf = true);
    final result = await _receiptService.downloadReceiptPdf(order.toReceiptData());
    if (!mounted) return;
    setState(() => _isDownloadingPdf = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? EcomColors.primaryDark : Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _shareOrderPdf(ProfessionalOrderEntity order) async {
    if (_isSharingPdf) return;
    setState(() => _isSharingPdf = true);
    final result = await _receiptService.shareReceiptPdf(order.toReceiptData());
    if (!mounted) return;
    setState(() => _isSharingPdf = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? EcomColors.primaryDark : Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: EcomLocaleController.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: EcomColors.background,
          appBar: AppBar(
            backgroundColor: EcomColors.surface,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: EcomColors.textPrimary, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(EcomStrings.trackOrder,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: EcomColors.textPrimary)),
          ),
          body: StreamBuilder<ProfessionalOrderEntity?>(
            stream: widget.orderStream ?? _dataSource.streamOrder(widget.orderId),
            initialData: widget.initialOrder,
            builder: (context, snapshot) {
              final order = snapshot.data ?? widget.initialOrder;
              if (order == null) {
                return const Center(child: CircularProgressIndicator(color: EcomColors.primary));
              }

              final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Order Header Card (Matching Reference Screen 5)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: EcomColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: EcomColors.cardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${EcomStrings.orderNumber} #${order.orderNumber}',
                                      style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: EcomColors.textPrimary),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (order.sellerOrderNumber != null && order.sellerOrderNumber!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          EcomLocaleController.instance.isHindi
                                              ? 'दुकान ऑर्डर नंबर: ${order.sellerOrderNumber}'
                                              : 'Store Order: ${order.sellerOrderNumber}',
                                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: EcomColors.primaryDark),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: EcomColors.softGreen, borderRadius: BorderRadius.circular(12)),
                                child: Text(
                                  order.fulfillmentType == 'delivery' ? EcomStrings.deliveryOption : EcomStrings.pickupOption,
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: EcomColors.primaryDark),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${EcomStrings.dateLabel}: $formattedDate',
                            style: const TextStyle(fontSize: 12.5, color: EcomColors.textSecondary),
                          ),
                          if (order.deliveryOtp != null && order.deliveryOtp!.trim().isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: EcomColors.softGreen,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: EcomColors.primary.withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.verified_user_rounded, size: 15, color: EcomColors.primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${EcomStrings.deliveryOtpLabel}: ${order.deliveryOtp}',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: EcomColors.primaryDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if ((order.status.toLowerCase() == 'cancelled' || order.status.toLowerCase() == 'rejected') &&
                              order.rejectionReason != null &&
                              order.rejectionReason!.trim().isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                order.rejectionReason!.trim(),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFB91C1C)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Status Timeline (Matching Reference Screen 5)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: EcomColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: EcomColors.cardShadow,
                      ),
                      child: EcomOrderStatusTimeline(
                        orderStatus: order.status,
                        isDelivery: order.fulfillmentType == 'delivery',
                        orderDateFormatted: formattedDate,
                      ),
                    ),

                    const SizedBox(height: 18),

                    // View Order Details Pill Button & Expandable Summary (Matching Reference Screen 5)
                    Center(
                      child: InkWell(
                        onTap: () => setState(() => _showDetails = !_showDetails),
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                          decoration: BoxDecoration(
                            color: EcomColors.softGreen,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: EcomColors.primary.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                EcomStrings.viewOrderDetails,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                  color: EcomColors.primaryDark,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                _showDetails ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                color: EcomColors.primaryDark,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_showDetails) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: EcomColors.surface,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: EcomColors.cardShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...order.items.map((item) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${item.displayTitleWithUnit} x ${item.quantity}',
                                        style: const TextStyle(fontSize: 13, color: EcomColors.textPrimary),
                                      ),
                                    ),
                                    Text(ProfessionalOrderItem.formatCurrency(item.total),
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: EcomColors.textPrimary)),
                                  ],
                                ),
                              );
                            }),
                            const Divider(color: EcomColors.divider),
                            const SizedBox(height: 6),
                            _summaryRow(EcomStrings.itemTotal, ProfessionalOrderItem.formatCurrency(order.subtotal)),
                            const SizedBox(height: 6),
                            _summaryRow(
                              EcomStrings.deliveryFee,
                              order.deliveryCharge == 0 ? EcomStrings.freeDelivery : ProfessionalOrderItem.formatCurrency(order.deliveryCharge),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(EcomStrings.totalPayable,
                                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: EcomColors.textPrimary)),
                                Text(ProfessionalOrderItem.formatCurrency(order.totalAmount),
                                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: EcomColors.primaryDark)),
                              ],
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => ProfessionalOrderReceiptSheet.show(context, order),
                                icon: const Icon(Icons.receipt_long_rounded, size: 18),
                                label: Text(
                                  EcomLocaleController.instance.isHindi ? 'ऑर्डर रसीद' : 'Order Receipt',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: EcomColors.primaryDark,
                                  side: const BorderSide(color: EcomColors.primary),
                                  padding: const EdgeInsets.symmetric(vertical: 11),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    key: const Key('tracking_download_pdf_button'),
                                    onPressed: _isDownloadingPdf ? null : () => _downloadOrderPdf(order),
                                    icon: _isDownloadingPdf
                                        ? const SizedBox(
                                            width: 15,
                                            height: 15,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : const Icon(Icons.download_rounded, size: 17),
                                    label: const Text(
                                      'Download PDF',
                                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: EcomColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 11),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    key: const Key('tracking_share_pdf_button'),
                                    onPressed: _isSharingPdf ? null : () => _shareOrderPdf(order),
                                    icon: _isSharingPdf
                                        ? const SizedBox(
                                            width: 15,
                                            height: 15,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: EcomColors.primary),
                                          )
                                        : const Icon(Icons.share_rounded, size: 17),
                                    label: const Text(
                                      'Share PDF',
                                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: EcomColors.primaryDark,
                                      side: const BorderSide(color: EcomColors.primary),
                                      padding: const EdgeInsets.symmetric(vertical: 11),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: EcomColors.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
