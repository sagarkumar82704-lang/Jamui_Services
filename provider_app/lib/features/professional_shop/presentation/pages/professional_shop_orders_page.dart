import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../data/datasources/professional_provider_remote_data_source.dart';
import '../../services/professional_receipt_service.dart';
import '../../../../core/localization/provider_strings.dart';
import '../../../../core/localization/language_selection_modal.dart';
import '../widgets/professional_provider_order_receipt_sheet.dart';

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
  final Set<String> _pendingProductResolutions = {};

  @override
  void initState() {
    super.initState();
    _dataSource = widget.dataSource ?? ProfessionalProviderRemoteDataSource();
    _ordersStream = _dataSource.streamShopOrders(widget.shopId);
  }

  void _resolveCatalogTitlesIfNeeded(List<Map<String, dynamic>> orders) {
    bool hasNewToResolve = false;
    for (final order in orders) {
      final orderShopId = ((order['shopId'] as String?) ?? widget.shopId).trim();
      // Strict security invariant: isolate queries to the current authenticated shop
      if (orderShopId != widget.shopId) continue;
      final items = (order['items'] as List<dynamic>?) ?? [];
      for (final it in items) {
        if (it is Map) {
          final rawName = (it['name'] ?? it['title']) as String?;
          final productId = (it['productId'] as String?)?.trim() ?? '';
          if (ProfessionalProviderRemoteDataSource.isGenericFallbackItemName(rawName) && productId.isNotEmpty) {
            final key = '${widget.shopId}_$productId';
            if (!_pendingProductResolutions.contains(key) &&
                _dataSource.getCachedCatalogProductTitle(shopId: widget.shopId, productId: productId) == null) {
              _pendingProductResolutions.add(key);
              hasNewToResolve = true;
            }
          }
        }
      }
    }

    if (hasNewToResolve) {
      _dataSource.resolveOrdersCatalogTitles(orders, widget.shopId).then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  ({String displayName, bool isRecovered, bool isNotFound}) _resolveItemDisplayTitle(Map<String, dynamic> item) {
    final rawName = ((item['name'] ?? item['title']) as String?)?.trim() ?? '';
    final productId = (item['productId'] as String?)?.trim() ?? '';

    if (ProfessionalProviderRemoteDataSource.isGenericFallbackItemName(rawName)) {
      if (productId.isNotEmpty) {
        final cachedTitle = _dataSource.getCachedCatalogProductTitle(
          shopId: widget.shopId,
          productId: productId,
        );
        if (cachedTitle != null && cachedTitle.isNotEmpty) {
          return (
            displayName: cachedTitle,
            isRecovered: true,
            isNotFound: false,
          );
        }
      }
      return (
        displayName: 'उत्पाद का नाम उपलब्ध नहीं',
        isRecovered: true,
        isNotFound: true,
      );
    }

    return (
      displayName: rawName.isNotEmpty ? rawName : 'उत्पाद',
      isRecovered: false,
      isNotFound: false,
    );
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
    final docId = o['id'] ?? o['orderId'] ?? '';
    final platformOrderNum = o['orderNumber'] ?? o['orderId'] ?? docId;
    final sellerOrderNum = (o['sellerOrderNumber'] as String?)?.trim();
    final custName = o['customerName'] ?? 'ग्राहक';
    final custPhone = o['customerPhone'] ?? '';
    final subtotal = (o['subtotal'] as num?)?.toDouble() ?? 0.0;
    final deliveryFee = (o['deliveryFee'] as num?)?.toDouble() ?? (o['deliveryCharge'] as num?)?.toDouble() ?? 0.0;
    final total = (o['totalAmount'] as num?)?.toDouble() ?? (subtotal + deliveryFee);
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
                        if (sellerOrderNum != null && sellerOrderNum.isNotEmpty) ...[
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF0F766E).withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  '${ProviderStrings.sellerOrderNo}: $sellerOrderNum',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF0F766E)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('${ProviderStrings.platformOrderNo}: #$platformOrderNum', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                            ],
                          ),
                          const SizedBox(height: 4),
                        ] else ...[
                          Text('${ProviderStrings.orderDetails} #$platformOrderNum', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                          const SizedBox(height: 2),
                        ],
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
                            isDelivery ? ProviderStrings.homeDelivery : ProviderStrings.storePickup,
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
                      final res = _resolveItemDisplayTitle(it);
                      final name = res.displayName;
                      final variantTitle = (it['variantTitle'] as String?)?.trim();
                      final hasVariant = variantTitle != null && variantTitle.isNotEmpty;

                      // Safe quantity parsing
                      final rawQty = it['quantity'];
                      final int qty = (rawQty is num)
                          ? rawQty.toInt()
                          : (int.tryParse(rawQty?.toString() ?? '') ?? 1);
                      final safeQty = qty > 0 ? qty : 1;

                      final unit = ((it['unit'] as String?) ?? '').trim();
                      final price = (it['price'] as num?)?.toDouble() ??
                          (it['pricePerUnit'] as num?)?.toDouble() ??
                          (it['sellingPrice'] as num?)?.toDouble() ??
                          0.0;
                      final itemTotal = (it['itemTotal'] as num?)?.toDouble() ??
                          (it['total'] as num?)?.toDouble() ??
                          (price * safeQty);

                      // Avoid duplicate unit display like "500g (g)"
                      String unitSuffix = '';
                      if (hasVariant) {
                        if (unit.isNotEmpty && !variantTitle.toLowerCase().contains(unit.toLowerCase())) {
                          unitSuffix = ' • $unit';
                        }
                      } else if (unit.isNotEmpty) {
                        unitSuffix = ' ($unit)';
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          name,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.bold,
                                            color: res.isNotFound ? const Color(0xFFC62828) : const Color(0xFF1E293B),
                                            fontStyle: res.isNotFound ? FontStyle.italic : FontStyle.normal,
                                          ),
                                        ),
                                      ),
                                      if (res.isRecovered && !res.isNotFound) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE0F2F1),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: const Color(0xFF0F766E), width: 0.6),
                                          ),
                                          child: const Text(
                                            'कैटलॉग से प्राप्त',
                                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (res.isRecovered)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        res.isNotFound
                                            ? 'मूल ऑर्डर में नाम दर्ज नहीं था और यह उत्पाद अब कैटलॉग में नहीं है।'
                                            : 'मूल ऑर्डर रिकॉर्ड में नाम अनुपलब्ध था - दुकान कैटलॉग से प्रदर्शित किया गया है।',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: res.isNotFound ? const Color(0xFFC62828) : const Color(0xFF0F766E),
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  if (hasVariant)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: const Color(0xFFCBD5E1), width: 0.6),
                                        ),
                                        child: Text(
                                          'वेरिएंट (Variant): $variantTitle$unitSuffix',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${ProfessionalReceiptService.formatCurrency(price)} x $safeQty${!hasVariant ? unitSuffix : ""}',
                                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              ProfessionalReceiptService.formatCurrency(itemTotal),
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
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
                          Text(ProviderStrings.subtotal, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                          Text(ProfessionalReceiptService.formatCurrency(subtotal), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(ProviderStrings.deliveryFee, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                          Text(deliveryFee > 0 ? ProfessionalReceiptService.formatCurrency(deliveryFee) : ProviderStrings.freeWithZero, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(ProviderStrings.total, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                          Text(ProfessionalReceiptService.formatCurrency(total), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F766E))),
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
                      '${ProviderStrings.rejectedOrders}: "$rejectionReason"',
                      style: const TextStyle(fontSize: 12, color: Color(0xFFC62828), fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // Digital Packing Slip Button
                OutlinedButton.icon(
                  onPressed: () => _showPackingSlip(o),
                  icon: const Icon(Icons.receipt_long_rounded, size: 18),
                  label: Text(ProviderStrings.packingSlip),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F766E),
                    side: const BorderSide(color: Color(0xFF0F766E)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 14),

                // Action Area inside modal sheet
                _buildActionForStatus(docId, st, isDelivery, onFinished: () => Navigator.pop(ctx)),
                const SizedBox(height: 20),
              ],
            );
          },
        );
      },
    );
  }

  void _showPackingSlip(Map<String, dynamic> o) {
    final catalogTitles = <String, String?>{};
    final items = (o['items'] as List<dynamic>?) ?? [];
    for (final it in items) {
      if (it is Map) {
        final pId = (it['productId'] as String?)?.trim() ?? '';
        if (pId.isNotEmpty) {
          catalogTitles[pId] = _dataSource.getCachedCatalogProductTitle(
            shopId: widget.shopId,
            productId: pId,
          );
        }
      }
    }

    final safeOrderMap = <String, dynamic>{
      'shopId': widget.shopId,
      ...o,
    };
    ProfessionalProviderOrderReceiptSheet.showFromMap(
      context,
      orderMap: safeOrderMap,
      authenticatedShopId: widget.shopId,
      catalogTitles: catalogTitles,
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
        title: Text(
          ProviderStrings.ordersManagement,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        actions: [
          IconButton(
            tooltip: ProviderStrings.selectLanguage,
            icon: const Icon(Icons.language_rounded, color: Color(0xFF0F766E)),
            onPressed: () => LanguageSelectionModal.show(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _ordersStream,
        builder: (context, snapshot) {
          final allOrders = snapshot.data ?? [];
          if (allOrders.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _resolveCatalogTitlesIfNeeded(allOrders);
            });
          }
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
                width: double.infinity,
                color: Colors.white,
                child: ResponsiveContentContainer(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildTabChip('${ProviderStrings.allOrders} (${allOrders.length})', 'All'),
                        const SizedBox(width: 8),
                        _buildTabChip(ProviderStrings.newOrders, 'New'),
                        const SizedBox(width: 8),
                        _buildTabChip(ProviderStrings.preparingOrders, 'Preparing'),
                        const SizedBox(width: 8),
                        _buildTabChip(ProviderStrings.outOrders, 'Out'),
                        const SizedBox(width: 8),
                        _buildTabChip(ProviderStrings.completedOrders, 'Completed'),
                        const SizedBox(width: 8),
                        _buildTabChip(ProviderStrings.rejectedOrders, 'Rejected'),
                      ],
                    ),
                  ),
                ),
              ),

              // Orders List
              Expanded(
                child: filtered.isEmpty
                    ? _buildEmptyOrders()
                    : SingleChildScrollView(
                        padding: EdgeInsets.zero,
                        child: ResponsiveContentContainer(
                          padding: ResponsiveLayout.pagePadding(context),
                          child: ResponsiveCardGrid(
                            tabletColumns: 2,
                            desktopColumns: 2,
                            largeDesktopColumns: 2,
                            children: filtered.map(_buildOrderCard).toList(),
                          ),
                        ),
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
    final docId = o['id'] ?? o['orderId'] ?? '';
    final platformOrderNum = o['orderNumber'] ?? o['orderId'] ?? docId;
    final sellerOrderNum = (o['sellerOrderNumber'] as String?)?.trim();
    final custName = o['customerName'] ?? 'ग्राहक';
    final custPhone = o['customerPhone'] ?? '';
    final subtotal = (o['subtotal'] as num?)?.toDouble() ?? 0.0;
    final deliveryFee = (o['deliveryFee'] as num?)?.toDouble() ?? (o['deliveryCharge'] as num?)?.toDouble() ?? 0.0;
    final total = (o['totalAmount'] as num?)?.toDouble() ?? (subtotal + deliveryFee);
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
                Expanded(
                  child: Row(
                    children: [
                      if (sellerOrderNum != null && sellerOrderNum.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF0F766E).withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            sellerOrderNum,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F766E),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          '#$platformOrderNum',
                          style: TextStyle(
                            fontSize: sellerOrderNum != null ? 13 : 15,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF64748B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusBadge(st),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.person_rounded, size: 15, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    custPhone.isNotEmpty ? '$custName • $custPhone' : custName,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
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
              final res = _resolveItemDisplayTitle(map);
              final name = res.displayName;
              final variantTitle = (map['variantTitle'] as String?)?.trim();
              final hasVariant = variantTitle != null && variantTitle.isNotEmpty;
              final rawQty = map['quantity'];
              final int quantity = (rawQty is num)
                  ? rawQty.toInt()
                  : (int.tryParse(rawQty?.toString() ?? '') ?? 1);
              final safeQty = quantity > 0 ? quantity : 1;
              final unit = ((map['unit'] as String?) ?? '').trim();
              final price = (map['price'] as num?)?.toDouble() ??
                  (map['pricePerUnit'] as num?)?.toDouble() ??
                  (map['sellingPrice'] as num?)?.toDouble() ??
                  0.0;
              final itemTotal = (map['itemTotal'] as num?)?.toDouble() ??
                  (map['total'] as num?)?.toDouble() ??
                  (price * safeQty);

              // Construct display label avoiding duplicate units like "500g (g)"
              String label = name;
              if (res.isRecovered && !res.isNotFound) {
                label = '$name [कैटलॉग]';
              }
              if (hasVariant) {
                if (unit.isNotEmpty && !variantTitle.toLowerCase().contains(unit.toLowerCase())) {
                  label = '$label ($variantTitle, $unit)';
                } else {
                  label = '$label ($variantTitle)';
                }
              } else if (unit.isNotEmpty) {
                label = '$label ($unit)';
              }

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '$label  x$safeQty',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: res.isNotFound ? const Color(0xFFC62828) : const Color(0xFF475569),
                          fontStyle: res.isNotFound ? FontStyle.italic : FontStyle.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      ProfessionalReceiptService.formatCurrency(itemTotal),
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
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
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'कुल राशि: ${ProfessionalReceiptService.formatCurrency(total)}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F766E)),
                    ),
                    if (deliveryFee > 0)
                      Text(
                        '(वस्तु: ${ProfessionalReceiptService.formatCurrency(subtotal)} + डिलीवरी: ${ProfessionalReceiptService.formatCurrency(deliveryFee)})',
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                      ),
                  ],
                ),
                _buildActionForStatus(docId, st, isDelivery),
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
    final label = ProviderStrings.orderStatusLabel(st);

    if (st == 'placed') {
      bg = const Color(0xFFEFF6FF);
      fg = const Color(0xFF1D4ED8);
    } else if (st == 'accepted') {
      bg = const Color(0xFFE0F2F1);
      fg = const Color(0xFF0F766E);
    } else if (st == 'preparing') {
      bg = const Color(0xFFFFF3E0);
      fg = const Color(0xFFE65100);
    } else if (st == 'out_for_delivery') {
      bg = const Color(0xFFE3F2FD);
      fg = const Color(0xFF1565C0);
    } else if (st == 'ready_for_pickup') {
      bg = const Color(0xFFF3E8FF);
      fg = const Color(0xFF7E22CE);
    } else if (st == 'delivered' || st == 'collected') {
      bg = const Color(0xFFE8F5E9);
      fg = const Color(0xFF2E7D32);
    } else if (st == 'rejected' || st == 'cancelled') {
      bg = const Color(0xFFFFEBEE);
      fg = const Color(0xFFC62828);
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
