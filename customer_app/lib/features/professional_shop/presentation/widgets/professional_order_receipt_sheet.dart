import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/professional_order_entity.dart';
import '../../services/professional_receipt_service.dart';
import '../theme/ecom_theme.dart';

/// Compact, print-friendly Professional Order Receipt and Packing Slip.
///
/// Strictly displays ONLY genuine, verified order data.
/// Never hardcodes names, addresses, phone numbers, taxes or prices.
/// Clearly identified as a digital order receipt/packing slip, NOT a tax invoice.
/// Supports Download PDF and Share PDF actions.
class ProfessionalOrderReceiptSheet extends StatefulWidget {
  final ProfessionalOrderEntity order;
  final ProfessionalReceiptService? receiptService;
  final String? authenticatedCustomerUid;

  const ProfessionalOrderReceiptSheet({
    super.key,
    required this.order,
    this.receiptService,
    this.authenticatedCustomerUid,
  });

  static void show(
    BuildContext context,
    ProfessionalOrderEntity order, {
    ProfessionalReceiptService? receiptService,
    String? authenticatedCustomerUid,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProfessionalOrderReceiptSheet(
        order: order,
        receiptService: receiptService,
        authenticatedCustomerUid: authenticatedCustomerUid,
      ),
    );
  }

  @override
  State<ProfessionalOrderReceiptSheet> createState() => _ProfessionalOrderReceiptSheetState();
}

class _ProfessionalOrderReceiptSheetState extends State<ProfessionalOrderReceiptSheet> {
  late final ProfessionalReceiptService _service;
  bool _isDownloading = false;
  bool _isSharing = false;
  String? _feedbackMessage;
  bool _feedbackIsError = false;

  @override
  void initState() {
    super.initState();
    _service = widget.receiptService ?? ProfessionalReceiptService();
  }

  Future<void> _handleDownloadPdf() async {
    if (_isDownloading) return;
    setState(() {
      _isDownloading = true;
      _feedbackMessage = null;
    });

    final receiptData = widget.order.toReceiptData();
    final result = await _service.downloadReceiptPdf(
      receiptData,
      enforceCustomerAuth: widget.authenticatedCustomerUid != null,
      authenticatedCustomerUid: widget.authenticatedCustomerUid,
    );

    if (!mounted) return;
    setState(() {
      _isDownloading = false;
      _feedbackMessage = result.message;
      _feedbackIsError = !result.success;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? EcomColors.primaryDark : Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleSharePdf() async {
    if (_isSharing) return;
    setState(() {
      _isSharing = true;
      _feedbackMessage = null;
    });

    final receiptData = widget.order.toReceiptData();
    final result = await _service.shareReceiptPdf(
      receiptData,
      enforceCustomerAuth: widget.authenticatedCustomerUid != null,
      authenticatedCustomerUid: widget.authenticatedCustomerUid,
    );

    if (!mounted) return;
    setState(() {
      _isSharing = false;
      _feedbackMessage = result.message;
      _feedbackIsError = !result.success;
    });

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
    final order = widget.order;
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final formattedDate = dateFormat.format(order.createdAt);
    final isDelivery = order.fulfillmentType.toLowerCase() == 'delivery';

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header: Platform Branding
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: EcomColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        order.channelId.replaceAll('_', ' '),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'PROFESSIONAL ORDER RECEIPT & PACKING SLIP',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const Divider(color: Color(0xFFE2E8F0), thickness: 1),
              const SizedBox(height: 10),

              // Store and Numbers Block
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.shopName.isNotEmpty ? order.shopName : 'Store',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (order.shopPhone.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Ph: ${order.shopPhone}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Prominent Store Order No (if assigned)
                  if (order.sellerOrderNumber != null && order.sellerOrderNumber!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'STORE ORDER NO',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            order.sellerOrderNumber!,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // Platform Order ID and Timestamp
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Online Order ID',
                          style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                        ),
                        Text(
                          '#${order.orderNumber}',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: EcomColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Date & Time',
                          style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                        ),
                        Text(
                          formattedDate,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Fulfillment Type',
                          style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                        ),
                        Text(
                          isDelivery ? 'Store Delivery' : 'Store Pickup',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Customer & Address Details (Hidden if empty)
              if (order.customerName.isNotEmpty ||
                  order.customerPhone.isNotEmpty ||
                  (isDelivery && order.deliveryAddress != null)) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (order.customerName.isNotEmpty || order.customerPhone.isNotEmpty) ...[
                        Text(
                          'Customer: ${order.customerName}${order.customerPhone.isNotEmpty ? ' (${order.customerPhone})' : ''}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                      if (isDelivery &&
                          order.deliveryAddress != null &&
                          ((order.deliveryAddress!['fullAddress'] ?? order.deliveryAddress!['address'])
                                  ?.toString()
                                  .isNotEmpty ??
                              false)) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Address: ${(order.deliveryAddress!['fullAddress'] ?? order.deliveryAddress!['address'])}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),
              const Text(
                'ITEMS ORDERED',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),

              // Items Table
              ...order.items.map((item) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${item.displayTitleWithUnit} x ${item.quantity}',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
                        ),
                      ),
                      Text(
                        ProfessionalOrderItem.formatCurrency(item.total),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 12),
              const Divider(color: Color(0xFFE2E8F0)),

              // Bill Summary
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Item Subtotal', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                  Text(ProfessionalOrderItem.formatCurrency(order.subtotal), style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B))),
                ],
              ),
              if (order.deliveryCharge > 0) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Delivery Fee', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                    Text(
                      ProfessionalOrderItem.formatCurrency(order.deliveryCharge),
                      style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
                    ),
                  ],
                ),
              ],
              if (order.discountAmount > 0) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Discount', style: TextStyle(fontSize: 13, color: Colors.green)),
                    Text(
                      '-${ProfessionalOrderItem.formatCurrency(order.discountAmount)}',
                      style: const TextStyle(fontSize: 13, color: Colors.green),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TOTAL PAYABLE',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  Text(
                    ProfessionalOrderItem.formatCurrency(order.totalAmount),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: EcomColors.primary,
                    ),
                  ),
                ],
              ),
              if (order.paymentMode.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Payment Mode', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    Text(
                      order.paymentMode.toUpperCase(),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 18),

              // Non-Tax Disclaimer
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Column(
                  children: [
                    Text(
                      'Digital Order Receipt / Packing Slip — Not a Tax Invoice.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF92400E),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'ℹ️ Notice: This is a digital order receipt and packing slip. For official tax invoices, please request an invoice directly from the registered seller.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF92400E),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),

              if (_feedbackMessage != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _feedbackIsError ? const Color(0xFFFEE2E2) : EcomColors.softGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _feedbackMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: _feedbackIsError ? const Color(0xFFB91C1C) : EcomColors.primaryDark,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // Download PDF & Share PDF Action Row (Customer App — No "Send to Customer" button)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      key: const Key('receipt_download_pdf_button'),
                      onPressed: _isDownloading ? null : _handleDownloadPdf,
                      icon: _isDownloading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.download_rounded, size: 18),
                      label: const Text(
                        'Download PDF',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EcomColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('receipt_share_pdf_button'),
                      onPressed: _isSharing ? null : _handleSharePdf,
                      icon: _isSharing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: EcomColors.primary),
                            )
                          : const Icon(Icons.share_rounded, size: 18),
                      label: const Text(
                        'Share PDF',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: EcomColors.primaryDark,
                        side: const BorderSide(color: EcomColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF475569),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Close Receipt'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
