import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/localization/provider_strings.dart';
import '../../services/professional_receipt_service.dart';

/// Provider App Professional Order Receipt & Packing Slip Modal Sheet.
///
/// Enforces store ownership authorization (`ProfessionalReceiptSecurityGuard`)
/// and provides three working actions:
/// 1. Download PDF (`JamuiServices_<orderNumber>.pdf`)
/// 2. Share PDF (Native Share Sheet on Android / Download fallback on Web)
/// 3. Send to Customer on WhatsApp (Validated E.164 deep link + manual PDF attachment guidance)
class ProfessionalProviderOrderReceiptSheet extends StatefulWidget {
  final ProfessionalReceiptData receipt;
  final String authenticatedShopId;
  final String? authenticatedOwnerUid;
  final ProfessionalReceiptService? receiptService;

  const ProfessionalProviderOrderReceiptSheet({
    super.key,
    required this.receipt,
    required this.authenticatedShopId,
    this.authenticatedOwnerUid,
    this.receiptService,
  });

  static void showFromMap(
    BuildContext context, {
    required Map<String, dynamic> orderMap,
    required String authenticatedShopId,
    String? authenticatedOwnerUid,
    ProfessionalReceiptService? receiptService,
    Map<String, String?>? catalogTitles,
  }) {
    final receipt = ProfessionalReceiptData.fromMap(
      orderMap,
      catalogTitles: catalogTitles,
    );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProfessionalProviderOrderReceiptSheet(
        receipt: receipt,
        authenticatedShopId: authenticatedShopId,
        authenticatedOwnerUid: authenticatedOwnerUid,
        receiptService: receiptService,
      ),
    );
  }

  @override
  State<ProfessionalProviderOrderReceiptSheet> createState() =>
      _ProfessionalProviderOrderReceiptSheetState();
}

class _ProfessionalProviderOrderReceiptSheetState
    extends State<ProfessionalProviderOrderReceiptSheet> {
  late final ProfessionalReceiptService _service;
  bool _isDownloading = false;
  bool _isSharing = false;
  bool _isOpeningWhatsApp = false;
  String? _feedbackMessage;
  bool _feedbackIsError = false;

  @override
  void initState() {
    super.initState();
    _service = widget.receiptService ?? ProfessionalReceiptService();
  }

  bool get _isAuthorized => ProfessionalReceiptSecurityGuard.canProviderAccessReceipt(
        receipt: widget.receipt,
        authenticatedShopId: widget.authenticatedShopId,
        authenticatedOwnerUid: widget.authenticatedOwnerUid,
      );

  Future<void> _handleDownloadPdf() async {
    if (_isDownloading) return;
    setState(() {
      _isDownloading = true;
      _feedbackMessage = null;
    });

    final result = await _service.downloadReceiptPdf(
      widget.receipt,
      enforceProviderAuth: true,
      authenticatedShopId: widget.authenticatedShopId,
      authenticatedOwnerUid: widget.authenticatedOwnerUid,
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
        backgroundColor: result.success ? const Color(0xFF0F766E) : Colors.red.shade700,
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

    final result = await _service.shareReceiptPdf(
      widget.receipt,
      enforceProviderAuth: true,
      authenticatedShopId: widget.authenticatedShopId,
      authenticatedOwnerUid: widget.authenticatedOwnerUid,
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
        backgroundColor: result.success ? const Color(0xFF0F766E) : Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleSendToCustomerWhatsApp() async {
    if (_isOpeningWhatsApp) return;
    setState(() {
      _isOpeningWhatsApp = true;
      _feedbackMessage = null;
    });

    final result = await _service.sendToCustomerOnWhatsApp(
      widget.receipt,
      enforceProviderAuth: true,
      authenticatedShopId: widget.authenticatedShopId,
      authenticatedOwnerUid: widget.authenticatedOwnerUid,
    );

    if (!mounted) return;
    setState(() {
      _isOpeningWhatsApp = false;
      _feedbackMessage = result.message;
      _feedbackIsError = !result.success;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? const Color(0xFF0F766E) : Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthorized) {
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline_rounded, color: Colors.red, size: 42),
            const SizedBox(height: 12),
            const Text(
              'Unauthorized Receipt Access',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 6),
            const Text(
              'You are only authorized to view and share receipts for orders belonging to your own store.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }

    final r = widget.receipt;
    final isDelivery = r.fulfillmentType.toLowerCase() == 'delivery';
    final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(r.createdAt);
    final phoneValidation = ProfessionalReceiptPhoneValidator.validateAndNormalize(
      r.customerPhone,
      countryCode: r.customerCountryCode,
    );

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.channelId.replaceAll('_', ' '),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F766E),
                            letterSpacing: 0.8,
                          ),
                        ),
                        if (r.shopName.isNotEmpty)
                          Text(
                            r.shopName,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF334155),
                            ),
                          ),
                        Text(
                          ProviderStrings.packingSlipTitle,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  if (r.sellerOrderNumber != null && r.sellerOrderNumber!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF0F766E)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            ProviderStrings.sellerOrderNo,
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F766E),
                            ),
                          ),
                          Text(
                            r.sellerOrderNumber!,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F766E),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              // Meta
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${ProviderStrings.platformOrderNo}: #${r.orderNumber}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF475569),
                    ),
                  ),
                  Text(
                    formattedDate,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${ProviderStrings.deliveryType}: ${isDelivery ? ProviderStrings.homeDeliveryType : ProviderStrings.pickupDeliveryType}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDelivery ? const Color(0xFF1D4ED8) : const Color(0xFF7E22CE),
                ),
              ),
              if (r.customerName.isNotEmpty || r.customerPhone.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'ग्राहक: ${r.customerName}${r.customerPhone.isNotEmpty ? " (${r.customerPhone})" : ""}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                ),
              ],
              if (isDelivery && r.deliveryAddressText.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'पता: ${r.deliveryAddressText}',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                ),
              ],
              const SizedBox(height: 12),
              const Divider(),
              // Items
              const Text(
                'सामान सूची (Items List):',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 8),
              ...r.items.map((it) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${it.displayTitleWithUnit} x ${it.quantity}',
                              style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155)),
                            ),
                            if (it.isRecovered)
                              const Padding(
                                padding: EdgeInsets.only(top: 1),
                                child: Text(
                                  '(कैटलॉग से प्रदर्शित)',
                                  style: TextStyle(fontSize: 10, color: Color(0xFF0F766E), fontStyle: FontStyle.italic),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        ProfessionalReceiptService.formatCurrency(it.totalPrice),
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                );
              }),
              const Divider(height: 20),
              // Totals
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'उप-योग (Subtotal)',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  Text(
                    ProfessionalReceiptService.formatCurrency(r.subtotal),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'डिलीवरी शुल्क (Delivery Fee)',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  Text(
                    ProfessionalReceiptService.formatCurrency(r.deliveryCharge),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              if (r.discountAmount > 0) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'छूट (Discount)',
                      style: TextStyle(fontSize: 12, color: Colors.green),
                    ),
                    Text(
                      '-${ProfessionalReceiptService.formatCurrency(r.discountAmount)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'कुल राशि (Total)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  Text(
                    ProfessionalReceiptService.formatCurrency(r.totalAmount),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F766E),
                    ),
                  ),
                ],
              ),
              if (r.paymentMode.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'भुगतान माध्यम (Payment Mode)',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                    Text(
                      r.paymentMode.toUpperCase(),
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  children: [
                    Text(
                      'Digital Order Receipt / Packing Slip — Not a Tax Invoice.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'सूचना: यह केवल ऑर्डर पैकिंग एवं दुकान संदर्भ हेतु डिजिटल स्लिप है। यह वैध कानूनी टैक्स इनवॉइस (GST Invoice) नहीं है।',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),

              if (_feedbackMessage != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _feedbackIsError ? const Color(0xFFFEE2E2) : const Color(0xFFCCFBF1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _feedbackMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: _feedbackIsError ? const Color(0xFFB91C1C) : const Color(0xFF0F766E),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // Row 1: Download PDF & Share PDF
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      key: const Key('provider_receipt_download_pdf_button'),
                      onPressed: _isDownloading ? null : _handleDownloadPdf,
                      icon: _isDownloading
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.download_rounded, size: 17),
                      label: Text(
                        ProviderStrings.downloadPdf,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('provider_receipt_share_pdf_button'),
                      onPressed: _isSharing ? null : _handleSharePdf,
                      icon: _isSharing
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF0F766E),
                              ),
                            )
                          : const Icon(Icons.share_rounded, size: 17),
                      label: Text(
                        ProviderStrings.sharePdf,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F766E),
                        side: const BorderSide(color: Color(0xFF0F766E)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Row 2: Send to Customer on WhatsApp
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  key: const Key('provider_receipt_whatsapp_button'),
                  onPressed: (!phoneValidation.isValid || _isOpeningWhatsApp)
                      ? null
                      : _handleSendToCustomerWhatsApp,
                  icon: const Icon(Icons.chat_rounded, size: 18),
                  label: Text(
                    ProviderStrings.whatsappCustomer,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF15803D),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFE2E8F0),
                    disabledForegroundColor: const Color(0xFF94A3B8),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),

              const SizedBox(height: 6),
              if (!phoneValidation.isValid)
                Text(
                  phoneValidation.errorReason ??
                      'Valid customer WhatsApp number is not available for this order.',
                  key: const Key('provider_receipt_invalid_phone_notice'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFB91C1C),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: const Text(
                    'Note: WhatsApp chat opens with a pre-filled message. To send the PDF file in WhatsApp, tap "Share PDF" above and select WhatsApp, or download the PDF and attach it manually using 📎.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10.5, color: Color(0xFF166534), height: 1.3),
                  ),
                ),

              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF475569),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('बंद करें (Close)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

