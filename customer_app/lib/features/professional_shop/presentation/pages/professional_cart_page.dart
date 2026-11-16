import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/app_image_url_resolver.dart';
import '../../../location/presentation/bloc/location_bloc.dart';
import '../../../location/presentation/bloc/location_state.dart';
import '../../data/datasources/professional_shop_remote_data_source.dart';
import '../../data/services/professional_checkout_idempotency_manager.dart';
import '../../domain/entities/professional_order_entity.dart';
import '../../domain/entities/professional_shop_entity.dart';
import '../bloc/professional_cart_bloc.dart';
import '../localization/ecom_locale_controller.dart';
import '../localization/ecom_strings.dart';
import '../theme/ecom_theme.dart';
import 'professional_order_tracking_page.dart';
import '../widgets/professional_order_processing_overlay.dart';
import 'professional_order_success_page.dart';

class ProfessionalCartPage extends StatefulWidget {
  final ProfessionalShopEntity shop;
  final ProfessionalShopRemoteDataSource? dataSource;
  final ProfessionalCheckoutIdempotencyManager? idempotencyManager;

  const ProfessionalCartPage({
    super.key,
    required this.shop,
    this.dataSource,
    this.idempotencyManager,
  });

  @override
  State<ProfessionalCartPage> createState() => _ProfessionalCartPageState();
}

class _ProfessionalCartPageState extends State<ProfessionalCartPage> {
  late final ProfessionalShopRemoteDataSource _dataSource;
  late final ProfessionalCheckoutIdempotencyManager _idempotencyManager;
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  bool _isSubmitting = false;
  String? _validationError;
  double? _customerLat;
  double? _customerLng;
  String _customerArea = '';

  @override
  void initState() {
    super.initState();
    _dataSource = widget.dataSource ?? ProfessionalShopRemoteDataSource();
    _idempotencyManager = widget.idempotencyManager ?? ProfessionalCheckoutIdempotencyManager();
    _initUserAndFulfillment();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _initUserAndFulfillment() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.phoneNumber != null && user.phoneNumber!.trim().isNotEmpty) {
      _phoneController.text = user.phoneNumber!.trim();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Enforce supported fulfillment modes based on real shop settings
      final cartBloc = context.read<ProfessionalCartBloc>();
      final currentMode = cartBloc.state.fulfillmentMode;
      if (!widget.shop.isHomeDeliveryActive && widget.shop.isPickupActive && currentMode != 'pickup') {
        cartBloc.add(const SetFulfillmentModeEvent('pickup'));
      } else if (widget.shop.isHomeDeliveryActive && !widget.shop.isPickupActive && currentMode != 'delivery') {
        cartBloc.add(const SetFulfillmentModeEvent('delivery'));
      }

      // Safely prefill from actual customer location ONLY when a real street/formatted address exists
      // Never invent an address from a bare location/city label.
      try {
        final locState = context.read<LocationBloc>().state;
        if (locState is LocationLoaded) {
          final loc = locState.location;
          if (loc.hasValidCoordinates) {
            _customerLat = loc.latitude;
            _customerLng = loc.longitude;
          }
          if (loc.locality.trim().isNotEmpty) {
            _customerArea = loc.locality.trim();
          }
          final fmt = loc.formattedAddress.trim();
          final isBareCityLabel = fmt.toLowerCase() == 'jamui' ||
              fmt.toLowerCase() == 'jamui, bihar' ||
              fmt.toLowerCase() == 'bihar';
          if (fmt.isNotEmpty && !isBareCityLabel && _addressController.text.trim().isEmpty) {
            _addressController.text = fmt;
          }
        }
      } catch (_) {}
    });
  }

  bool _isMinOrderMet(ProfessionalCartState cartState) {
    if (cartState.fulfillmentMode != 'delivery') return true;
    if (widget.shop.minOrderAmount <= 0) return true;
    return cartState.subtotal >= widget.shop.minOrderAmount;
  }

  void _openCheckoutSheet(BuildContext context, ProfessionalCartState cartState) {
    if (!_isMinOrderMet(cartState)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(EcomStrings.minOrderWarning(widget.shop.minOrderAmount.toInt())),
          backgroundColor: const Color(0xFFE53935),
        ),
      );
      return;
    }

    _validationError = null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (bottomSheetContext, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              decoration: const BoxDecoration(
                color: EcomColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          EcomStrings.confirmOrder,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: EcomColors.textPrimary),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: EcomColors.textSecondary),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(color: EcomColors.divider, height: 18),

                    // Delivery Address Input OR Store Pickup Info
                    Text(
                      cartState.fulfillmentMode == 'delivery'
                          ? EcomStrings.deliveryAddress
                          : EcomStrings.pickupInstructions,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: EcomColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    if (cartState.fulfillmentMode == 'delivery')
                      TextField(
                        controller: _addressController,
                        maxLines: 2,
                        onChanged: (_) {
                          if (_validationError != null) {
                            setModalState(() => _validationError = null);
                          }
                        },
                        style: const TextStyle(fontSize: 13.5, color: EcomColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: EcomStrings.enterDeliveryAddress,
                          hintStyle: const TextStyle(fontSize: 12.5, color: EcomColors.textTertiary),
                          prefixIcon: const Icon(Icons.location_on_rounded, color: EcomColors.primary, size: 20),
                          filled: true,
                          fillColor: EcomColors.background,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: EcomColors.cardBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: EcomColors.cardBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: EcomColors.primary, width: 1.5),
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: EcomColors.background,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: EcomColors.cardBorder),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.storefront_rounded, color: EcomColors.primary, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                [
                                  widget.shop.shopName,
                                  if (widget.shop.fullAddress.isNotEmpty)
                                    widget.shop.fullAddress
                                  else if (widget.shop.jamuiArea.isNotEmpty)
                                    widget.shop.jamuiArea,
                                  if (widget.shop.pickupInstructions.isNotEmpty)
                                    widget.shop.pickupInstructions,
                                ].join('\n'),
                                style: const TextStyle(fontSize: 13, color: EcomColors.textPrimary, height: 1.35),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),

                    // Contact Phone Input
                    Text(
                      EcomStrings.contactPhoneLabel,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: EcomColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      onChanged: (_) {
                        if (_validationError != null) {
                          setModalState(() => _validationError = null);
                        }
                      },
                      style: const TextStyle(fontSize: 13.5, color: EcomColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: '10-digit mobile number',
                        hintStyle: const TextStyle(fontSize: 12.5, color: EcomColors.textTertiary),
                        prefixIcon: const Icon(Icons.phone_rounded, color: EcomColors.primary, size: 19),
                        filled: true,
                        fillColor: EcomColors.background,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: EcomColors.cardBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: EcomColors.cardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: EcomColors.primary, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Optional Customer Notes
                    TextField(
                      controller: _notesController,
                      maxLines: 1,
                      style: const TextStyle(fontSize: 13, color: EcomColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: EcomStrings.orderNotesHint,
                        hintStyle: const TextStyle(fontSize: 12, color: EcomColors.textTertiary),
                        prefixIcon: const Icon(Icons.notes_rounded, color: EcomColors.textSecondary, size: 19),
                        filled: true,
                        fillColor: EcomColors.background,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: EcomColors.cardBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: EcomColors.cardBorder),
                        ),
                      ),
                    ),

                    if (_validationError != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _validationError!,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFB91C1C)),
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Payment Method (COD Active, Online UPI Coming Soon)
                    Text(
                      EcomStrings.paymentMethod,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: EcomColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
                            decoration: BoxDecoration(
                              color: EcomColors.softGreen,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: EcomColors.primary, width: 1.5),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.money_rounded, color: EcomColors.primary, size: 19),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    EcomStrings.codCashOnDelivery,
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: EcomColors.primaryDark),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.lock_outline_rounded, color: Colors.grey.shade500, size: 15),
                              const SizedBox(width: 5),
                              Text(
                                EcomStrings.onlineUpiSoon,
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Total & Place Order Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(EcomStrings.totalPayable, style: const TextStyle(fontSize: 12, color: EcomColors.textSecondary)),
                            Text(
                              '₹${cartState.grandTotal.toInt()}',
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: EcomColors.textPrimary),
                            ),
                          ],
                        ),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isSubmitting
                                ? null
                                : () {
                                    // Validate required fields before order placement
                                    final cleanAddress = _addressController.text.trim();
                                    final cleanPhone = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');

                                    if (cartState.fulfillmentMode == 'delivery' && cleanAddress.length < 5) {
                                      setModalState(() => _validationError = EcomStrings.addressRequiredError);
                                      return;
                                    }
                                    if (cleanPhone.length < 10) {
                                      setModalState(() => _validationError = EcomStrings.phoneRequiredError);
                                      return;
                                    }
                                    if (!_isMinOrderMet(cartState)) {
                                      setModalState(
                                        () => _validationError = EcomStrings.minOrderWarning(widget.shop.minOrderAmount.toInt()),
                                      );
                                      return;
                                    }

                                    setModalState(() => _validationError = null);
                                    _submitOrder(ctx, cartState);
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: EcomColors.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 30),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : Text(
                                    EcomStrings.placeOrder,
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitOrder(BuildContext sheetContext, ProfessionalCartState cartState) async {
    if (_isSubmitting) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to place an order.')));
      return;
    }

    setState(() => _isSubmitting = true);

    // Show the full-screen order processing animation overlay
    ProfessionalOrderProcessingOverlay.show(context);

    try {
      final cleanAddress = _addressController.text.trim();
      final cleanPhone = _phoneController.text.trim().isNotEmpty
          ? _phoneController.text.trim()
          : (user.phoneNumber ?? '');
      final cleanNotes = _notesController.text.trim();

      // Build order items using actual ProfessionalOrderItem (from entity)
      final orderItems = cartState.items.map((item) {
        return ProfessionalOrderItem(
          productId: item.product.id,
          variantId: item.variantId ?? '',
          variantTitle: item.variantTitle,
          title: item.product.displayName,
          unit: item.variantTitle ?? item.product.unit,
          thumbnailUrl: item.selectedImageUrl ?? item.product.thumbnailUrl,
          price: item.unitSellingPrice,
          quantity: item.quantity,
          total: item.itemTotal,
        );
      }).toList();

      final deliveryAddress = cartState.fulfillmentMode == 'delivery'
          ? {
              'customerName': (user.displayName != null && user.displayName!.trim().isNotEmpty)
                  ? user.displayName!.trim()
                  : 'Customer',
              'contactPhone': cleanPhone,
              'address': cleanAddress,
              'area': _customerArea.isNotEmpty ? _customerArea : widget.shop.jamuiArea,
              if (_customerLat != null) 'latitude': _customerLat,
              if (_customerLng != null) 'longitude': _customerLng,
            }
          : null;

      final fingerprint = ProfessionalCheckoutIdempotencyManager.computeFingerprint(
        shopId: widget.shop.id,
        deliveryMethod: cartState.fulfillmentMode,
        items: orderItems,
        deliveryAddress: deliveryAddress,
      );

      var attempt = await _idempotencyManager.getOrCreateAttempt(
        customerId: user.uid,
        shopId: widget.shop.id,
        payloadFingerprint: fingerprint,
        orderPayload: {
          'subtotal': cartState.subtotal,
          'deliveryFee': cartState.deliveryFee,
          'totalAmount': cartState.grandTotal,
        },
      );

      if (attempt.hasPayloadMismatch) {
        // Reconcile with Firestore: check if prior attempt with different cart was actually created
        final reconciliation = await _idempotencyManager.reconcileWithFirestore(
          firestore: FirebaseFirestore.instance,
          customerId: user.uid,
          shopId: widget.shop.id,
          idempotencyKey: attempt.idempotencyKey,
        );

        if (reconciliation.isConfirmedPlaced && reconciliation.order != null) {
          // Prior attempt already succeeded on the backend! Show success and clear cart.
          if (mounted) {
            ProfessionalOrderProcessingOverlay.hide(context);
            if (sheetContext.mounted && Navigator.canPop(sheetContext)) {
              Navigator.pop(sheetContext);
            }
            context.read<ProfessionalCartBloc>().add(ClearCartEvent());
            await Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => ProfessionalOrderSuccessPage(order: reconciliation.order!),
              ),
            );
          }
          return;
        }

        if (reconciliation.isNetworkError) {
          // Cannot verify prior attempt due to network; NEVER discard unresolved attempt!
          if (mounted) {
            ProfessionalOrderProcessingOverlay.hide(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'पिछला चेकआउट अभी अनिर्णीत है। कृपया नेटवर्क चेक करें या कुछ क्षण बाद पुनः प्रयास करें।',
                ),
                backgroundColor: Color(0xFFC62828),
              ),
            );
          }
          return;
        }

        // Conclusively verified that prior attempt does not exist on server (definitivelyNotFound)
        // Prompt user confirmation before discarding old attempt
        bool? shouldDiscard = false;
        if (mounted) {
          ProfessionalOrderProcessingOverlay.hide(context);
          shouldDiscard = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (dCtx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('कार्ट में बदलाव मिला', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              content: const Text(
                'आपके पिछले चेकआउट प्रयास के बाद कार्ट में बदलाव हुआ है। '
                'सर्वर पर पुराना ऑर्डर नहीं बना था। क्या आप नए कार्ट के साथ आगे बढ़ना चाहते हैं?',
                style: TextStyle(fontSize: 13.5),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dCtx, false),
                  child: const Text('रद्द करें', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dCtx, true),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E)),
                  child: const Text('हाँ, आगे बढ़ें', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        }

        if (shouldDiscard != true) {
          return;
        }

        // User confirmed: safely clear verified non-existent prior attempt and create new
        await _idempotencyManager.clearAttempt(
          customerId: user.uid,
          shopId: widget.shop.id,
        );
        attempt = await _idempotencyManager.getOrCreateAttempt(
          customerId: user.uid,
          shopId: widget.shop.id,
          payloadFingerprint: fingerprint,
          orderPayload: {
            'subtotal': cartState.subtotal,
            'deliveryFee': cartState.deliveryFee,
            'totalAmount': cartState.grandTotal,
          },
        );
        if (mounted) {
          ProfessionalOrderProcessingOverlay.show(context);
        }
      }

      final order = ProfessionalOrderEntity(
        orderId: 'ord_${DateTime.now().millisecondsSinceEpoch}',
        idempotencyKey: attempt.idempotencyKey,
        customerId: user.uid,
        customerName: (user.displayName != null && user.displayName!.trim().isNotEmpty)
            ? user.displayName!.trim()
            : 'Customer',
        customerPhone: cleanPhone,
        shopId: widget.shop.id,
        shopName: widget.shop.shopName,
        fulfillmentType: cartState.fulfillmentMode,
        deliveryAddress: deliveryAddress,
        customerNotes: cleanNotes,
        items: orderItems,
        subtotal: cartState.subtotal,
        deliveryCharge: cartState.deliveryFee,
        totalAmount: cartState.grandTotal,
        paymentMode: 'cod',
        createdAt: DateTime.now(),
      );

      final placeResult = await _dataSource.placeOrder(order);

      // On authoritative resolution (fresh placement or duplicate recovery), clear unresolved attempt
      await _idempotencyManager.clearAttempt(
        customerId: user.uid,
        shopId: widget.shop.id,
      );

      if (mounted) {
        // Dismiss the processing overlay
        ProfessionalOrderProcessingOverlay.hide(context);

        // Close the checkout bottom sheet if open
        if (sheetContext.mounted && Navigator.canPop(sheetContext)) {
          Navigator.pop(sheetContext);
        }

        // Clear the cart only after confirmed order creation
        context.read<ProfessionalCartBloc>().add(ClearCartEvent());

        // Build a fresh entity with the confirmed internal orderId, public orderNumber, and sellerOrderNumber
        final confirmedOrder = order.copyWith(
          orderId: placeResult.orderId,
          orderNumber: placeResult.orderNumber,
          sellerOrderNumber: placeResult.sellerOrderNumber,
          channelId: placeResult.channelId,
        );

        // Navigate to the animated ProfessionalOrderSuccessPage
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ProfessionalOrderSuccessPage(
              order: confirmedOrder,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Dismiss the processing overlay on failure
        ProfessionalOrderProcessingOverlay.hide(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${EcomStrings.retry}: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _showOrderPlacedSuccessDialog(
    String orderId,
    String orderNumber,
    ProfessionalOrderEntity confirmedOrder,
  ) async {
    final isHindi = EcomLocaleController.instance.isHindi;
    final displayOrderNumber = orderNumber.startsWith('JS-')
        ? orderNumber
        : (orderNumber.startsWith('ORD') ? orderNumber : '#$orderNumber');

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: EcomColors.softGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: EcomColors.primary,
                  size: 52,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isHindi ? 'ऑर्डर सफलतापूर्वक दर्ज हुआ!' : 'Order Placed Successfully!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: EcomColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: EcomColors.background,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isHindi ? 'ऑर्डर नंबर: #$displayOrderNumber' : 'Order ID: #$displayOrderNumber',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: EcomColors.textPrimary,
                  ),
                ),
              ),
              if (confirmedOrder.sellerOrderNumber != null && confirmedOrder.sellerOrderNumber!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: EcomColors.softGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isHindi
                        ? 'दुकान ऑर्डर नंबर: ${confirmedOrder.sellerOrderNumber}'
                        : 'Store Order: ${confirmedOrder.sellerOrderNumber}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: EcomColors.primaryDark,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                isHindi
                    ? 'आपका ऑर्डर कन्फर्म हो गया है और दुकान द्वारा जल्द तैयार किया जाएगा।'
                    : 'Your order has been confirmed and will be processed soon.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: EcomColors.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfessionalOrderTrackingPage(
                          orderId: orderId,
                          initialOrder: confirmedOrder,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EcomColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: Text(
                    EcomStrings.trackOrder,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pop();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: EcomColors.textPrimary,
                    side: const BorderSide(color: EcomColors.cardBorder),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: Text(
                    isHindi ? 'खरीदारी जारी रखें' : 'Continue Shopping',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isHindi = EcomLocaleController.instance.isHindi;
    final supportsDelivery = widget.shop.isHomeDeliveryActive;
    final supportsPickup = widget.shop.isPickupActive;

    return AnimatedBuilder(
      animation: EcomLocaleController.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: EcomColors.background,
          // Dark Forest Green Header matching Reference Screen 4 ("मेरा कार्ट (3 आइटम)")
          appBar: AppBar(
            backgroundColor: EcomColors.primary,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: BlocBuilder<ProfessionalCartBloc, ProfessionalCartState>(
              builder: (context, state) => Text(
                EcomStrings.myCartTitle(state.totalItemsCount),
                style: const TextStyle(fontSize: 17.5, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
          body: BlocBuilder<ProfessionalCartBloc, ProfessionalCartState>(
            builder: (context, state) {
              if (state.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80, height: 80,
                          decoration: const BoxDecoration(color: EcomColors.softGreen, shape: BoxShape.circle),
                          child: const Icon(Icons.shopping_cart_outlined, size: 40, color: EcomColors.primary),
                        ),
                        const SizedBox(height: 16),
                        Text(EcomStrings.cartEmptyTitle,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: EcomColors.textPrimary)),
                        const SizedBox(height: 6),
                        Text(EcomStrings.cartEmptySubtitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13, color: EcomColors.textSecondary)),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: EcomColors.primary, foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(EcomStrings.browseProducts, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final minOrderMet = _isMinOrderMet(state);

              return Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Supported Fulfillment Mode Selector (Delivery / Store Pickup)
                        if (supportsDelivery || supportsPickup) ...[
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: EcomColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: EcomColors.cardShadow,
                            ),
                            child: Row(
                              children: [
                                if (supportsDelivery)
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => context
                                          .read<ProfessionalCartBloc>()
                                          .add(const SetFulfillmentModeEvent('delivery')),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        decoration: BoxDecoration(
                                          color: state.fulfillmentMode == 'delivery'
                                              ? EcomColors.primary
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.delivery_dining_rounded,
                                              size: 17,
                                              color: state.fulfillmentMode == 'delivery'
                                                  ? Colors.white
                                                  : EcomColors.textSecondary,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              EcomStrings.deliveryOption,
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.bold,
                                                color: state.fulfillmentMode == 'delivery'
                                                    ? Colors.white
                                                    : EcomColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                if (supportsDelivery && supportsPickup) const SizedBox(width: 6),
                                if (supportsPickup)
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => context
                                          .read<ProfessionalCartBloc>()
                                          .add(const SetFulfillmentModeEvent('pickup')),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        decoration: BoxDecoration(
                                          color: state.fulfillmentMode == 'pickup'
                                              ? EcomColors.primary
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.storefront_rounded,
                                              size: 16,
                                              color: state.fulfillmentMode == 'pickup'
                                                  ? Colors.white
                                                  : EcomColors.textSecondary,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              EcomStrings.pickupOption,
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.bold,
                                                color: state.fulfillmentMode == 'pickup'
                                                    ? Colors.white
                                                    : EcomColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Minimum Order Warning Banner (when Delivery is selected and subtotal < minOrderAmount)
                        if (!minOrderMet) ...[
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded, color: Color(0xFFB45309), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    EcomStrings.minOrderWarning(widget.shop.minOrderAmount.toInt()),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF92400E),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Cart Items (Matching Reference Screen 4)
                        ...state.items.map((item) {
                          final imgUrl = AppImageUrlResolver.resolve(
                              item.selectedImageUrl ?? item.product.thumbnailUrl);
                          final itemTitle = isHindi && item.product.titleHindi.isNotEmpty
                              ? item.product.titleHindi
                              : item.product.displayName;
                          final itemUnit = (item.variantTitle != null && item.variantTitle!.trim().isNotEmpty)
                              ? item.variantTitle!.trim()
                              : EcomStrings.formatUnit(item.product.unitValue, item.product.unit);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: EcomColors.surface,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: EcomColors.cardShadow,
                            ),
                            child: Row(
                              children: [
                                // Thumbnail
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    width: 64, height: 64,
                                    color: const Color(0xFFFBFDFB),
                                    padding: const EdgeInsets.all(4),
                                    child: imgUrl.isNotEmpty
                                        ? Image.network(imgUrl, fit: BoxFit.contain,
                                            errorBuilder: (_, _, _) => const Icon(Icons.inventory_2_outlined, color: EcomColors.textTertiary))
                                        : const Icon(Icons.inventory_2_outlined, color: EcomColors.textTertiary),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                // Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(itemTitle,
                                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: EcomColors.textPrimary),
                                          maxLines: 1, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 3),
                                      Text(itemUnit,
                                          style: const TextStyle(fontSize: 12, color: EcomColors.textSecondary)),
                                      const SizedBox(height: 4),
                                      Text('₹${item.unitSellingPrice.toInt()}',
                                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: EcomColors.textPrimary)),
                                    ],
                                  ),
                                ),
                                // Delete Icon + Stepper Pill (Matching Reference Screen 3)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 18,
                                        color: EcomColors.textSecondary,
                                      ),
                                      padding: const EdgeInsets.only(bottom: 6),
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        context.read<ProfessionalCartBloc>().add(
                                          UpdateQuantityEvent(
                                            productId: item.product.id,
                                            variantId: item.variantId,
                                            delta: -item.quantity,
                                          ),
                                        );
                                      },
                                    ),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: EcomColors.softGreen,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: EcomColors.primary.withValues(alpha: 0.25)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.remove, size: 16, color: EcomColors.primary),
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                            constraints: const BoxConstraints(),
                                            onPressed: () {
                                              context.read<ProfessionalCartBloc>().add(
                                                UpdateQuantityEvent(productId: item.product.id, variantId: item.variantId, delta: -1),
                                              );
                                            },
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 6),
                                            child: Text('${item.quantity}',
                                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: EcomColors.primaryDark)),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.add, size: 16, color: EcomColors.primary),
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                            constraints: const BoxConstraints(),
                                            onPressed: () {
                                              context.read<ProfessionalCartBloc>().add(
                                                UpdateQuantityEvent(productId: item.product.id, variantId: item.variantId, delta: 1),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),

                        const SizedBox(height: 12),

                        // Bill Summary Card (Matching Reference Screen 4)
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: EcomColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: EcomColors.cardShadow,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildBillRow(EcomStrings.itemTotal, '₹${state.subtotal.toInt()}'),
                              const SizedBox(height: 10),
                              _buildBillRow(
                                EcomStrings.deliveryFee,
                                state.deliveryFee == 0 ? EcomStrings.freeDelivery : '₹${state.deliveryFee.toInt()}',
                                isDelivery: state.deliveryFee == 0,
                              ),
                              const SizedBox(height: 12),
                              const Divider(color: EcomColors.divider),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(EcomStrings.totalPayable,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: EcomColors.textPrimary)),
                                  Text('₹${state.grandTotal.toInt()}',
                                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: EcomColors.textPrimary)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Sticky Pill CTA ("ऑर्डर करें") matching Reference Screen 4
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: EcomColors.surface,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                        boxShadow: EcomColors.floatingBarShadow,
                      ),
                      child: SafeArea(
                        top: false,
                        child: SizedBox(
                          width: double.infinity, height: 52,
                          child: ElevatedButton(
                            onPressed: () => _openCheckoutSheet(context, state),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: minOrderMet ? EcomColors.primary : Colors.grey.shade400,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                            ),
                            child: Text(EcomStrings.placeOrder,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildBillRow(String label, String value, {bool isDelivery = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13.5, color: EcomColors.textSecondary)),
        Text(value,
            style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: isDelivery ? EcomColors.primary : EcomColors.textPrimary)),
      ],
    );
  }
}
