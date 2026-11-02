import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/datasources/professional_shop_remote_data_source.dart';
import '../../domain/entities/professional_order_entity.dart';
import '../../domain/entities/professional_shop_entity.dart';
import '../bloc/professional_cart_bloc.dart';
import 'professional_order_tracking_page.dart';

class ProfessionalCartPage extends StatefulWidget {
  final ProfessionalShopEntity shop;

  const ProfessionalCartPage({super.key, required this.shop});

  @override
  State<ProfessionalCartPage> createState() => _ProfessionalCartPageState();
}

class _ProfessionalCartPageState extends State<ProfessionalCartPage> {
  final ProfessionalShopRemoteDataSource _dataSource = ProfessionalShopRemoteDataSource();
  bool _isSubmitting = false;
  String _customerAddress = 'Laxmi Chowk, Jamui, Bihar';
  String _customerPhone = '';
  String _customerNotes = '';

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _customerPhone = user.phoneNumber ?? '';
    }
  }

  void _openCheckoutSheet(BuildContext context, ProfessionalCartState cartState) {
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
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Confirm & Place Order',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 16),

                  // Delivery or Pickup Summary
                  Text(
                    cartState.fulfillmentMode == 'delivery' ? 'Delivery Address' : 'Pickup Instructions',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          cartState.fulfillmentMode == 'delivery' ? Icons.location_on_rounded : Icons.storefront_rounded,
                          color: const Color(0xFF2E7D32),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            cartState.fulfillmentMode == 'delivery'
                                ? _customerAddress
                                : '${widget.shop.shopName}\n${widget.shop.fullAddress}',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Payment Method Selection (Matching Reference Image)
                  const Text(
                    'Payment Method',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF2E7D32), width: 1.5),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.money_rounded, color: Color(0xFF2E7D32), size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Cash on Delivery (COD)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.lock_outline_rounded, color: Colors.grey.shade500, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Online UPI (Soon)',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Pay safely via Cash on Delivery when you receive your order at your doorstep.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 18),

                  // Order Total & Place Order Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Amount', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text(
                            '₹${cartState.grandTotal.toInt()}',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: 46,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : () => _submitOrder(ctx, cartState),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Place Order', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitOrder(BuildContext modalCtx, ProfessionalCartState cartState) async {
    setState(() => _isSubmitting = true);
    final user = FirebaseAuth.instance.currentUser;
    final orderItems = cartState.items.map((i) {
      return ProfessionalOrderItem(
        productId: i.product.id,
        title: i.product.displayName,
        unit: i.product.unitLabel,
        thumbnailUrl: i.product.thumbnailUrl,
        price: i.product.sellingPrice,
        quantity: i.quantity,
        total: i.itemTotal,
      );
    }).toList();

    final order = ProfessionalOrderEntity(
      orderId: 'ORD${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
      customerId: user?.uid ?? 'guest_customer',
      customerName: user?.displayName ?? 'Jamui Customer',
      customerPhone: _customerPhone.isNotEmpty ? _customerPhone : (user?.phoneNumber ?? ''),
      shopId: widget.shop.id,
      shopName: widget.shop.shopName,
      shopPhone: widget.shop.contactPhone.isNotEmpty ? widget.shop.contactPhone : widget.shop.ownerPhone,
      fulfillmentType: cartState.fulfillmentMode,
      deliveryAddress: cartState.fulfillmentMode == 'delivery'
          ? {'address': _customerAddress, 'area': widget.shop.jamuiArea}
          : null,
      customerNotes: _customerNotes,
      items: orderItems,
      subtotal: cartState.subtotal,
      deliveryCharge: cartState.deliveryFee,
      discountAmount: cartState.totalSavings,
      totalAmount: cartState.grandTotal,
      paymentMode: 'cod',
      paymentStatus: 'pending',
      status: 'placed',
      createdAt: DateTime.now(),
    );

    try {
      final orderId = await _dataSource.placeOrder(order);
      if (mounted) {
        context.read<ProfessionalCartBloc>().add(ClearCartEvent());
        Navigator.pop(modalCtx); // Close modal
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ProfessionalOrderTrackingPage(orderId: orderId, initialOrder: order),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to place order: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E293B), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Cart (${widget.shop.shopName})',
          style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
      ),
      body: BlocBuilder<ProfessionalCartBloc, ProfessionalCartState>(
        builder: (context, state) {
          if (state.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shopping_bag_outlined, size: 72, color: Colors.grey.shade400),
                  const SizedBox(height: 14),
                  const Text(
                    'आपकी कार्ट खाली है',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 6),
                  const Text('दुकान से अपनी पसंद के उत्पाद जोड़ें।', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Go to Store', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
          }

          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 14, bottom: 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Delivery Address Card (Matching Reference Image)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.home_rounded, color: Color(0xFF2E7D32), size: 26),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Delivery to Home',
                                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _customerAddress,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () {},
                            child: const Text('Change', style: TextStyle(fontSize: 13, color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Cart Items Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: state.items.length,
                        separatorBuilder: (_, __) => const Divider(height: 20),
                        itemBuilder: (ctx, idx) {
                          final item = state.items[idx];
                          return Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  color: Colors.grey.shade100,
                                  child: item.product.thumbnailUrl.isNotEmpty
                                      ? Image.network(item.product.thumbnailUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.shopping_bag_outlined, size: 20))
                                      : const Icon(Icons.shopping_bag_outlined, size: 20),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.product.displayName,
                                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.product.unitLabel,
                                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                              // Stepper
                              Container(
                                height: 30,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 26),
                                      icon: const Icon(Icons.remove_rounded, size: 14),
                                      onPressed: () {
                                        context.read<ProfessionalCartBloc>().add(UpdateQuantityEvent(productId: item.product.id, delta: -1));
                                      },
                                    ),
                                    Text('${item.quantity}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 26),
                                      icon: const Icon(Icons.add_rounded, size: 14),
                                      onPressed: () {
                                        context.read<ProfessionalCartBloc>().add(UpdateQuantityEvent(productId: item.product.id, delta: 1));
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Text(
                                '₹${item.itemTotal.toInt()}',
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Bill Details Breakdown Card (Matching Reference Image)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Bill Details',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Subtotal', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                              Text('₹${state.subtotal.toInt()}', style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Delivery Fee', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                              Text(
                                state.deliveryFee == 0 ? 'FREE' : '₹${state.deliveryFee.toInt()}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: state.deliveryFee == 0 ? const Color(0xFF2E7D32) : const Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                          if (state.totalSavings > 0) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Savings', style: TextStyle(fontSize: 13, color: Color(0xFF2E7D32))),
                                Text('-₹${state.totalSavings.toInt()}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                              ],
                            ),
                          ],
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Amount', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                              Text('₹${state.grandTotal.toInt()}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Sticky Bottom "Proceed to Checkout" Button
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, -2)),
                    ],
                  ),
                  child: SafeArea(
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => _openCheckoutSheet(context, state),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'Proceed to Checkout • ₹${state.grandTotal.toInt()}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
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
  }
}

