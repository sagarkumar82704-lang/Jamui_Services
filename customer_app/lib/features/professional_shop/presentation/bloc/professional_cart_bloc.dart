import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/professional_product_entity.dart';
import '../../domain/entities/professional_shop_entity.dart';

// --- Cart Item Model ---
class CartItemModel extends Equatable {
  final ProfessionalProductEntity product;
  final int quantity;

  const CartItemModel({
    required this.product,
    required this.quantity,
  });

  double get itemTotal => product.sellingPrice * quantity;
  double get itemSavings => (product.regularPrice > product.sellingPrice)
      ? (product.regularPrice - product.sellingPrice) * quantity
      : 0.0;

  CartItemModel copyWith({int? quantity}) {
    return CartItemModel(
      product: product,
      quantity: quantity ?? this.quantity,
    );
  }

  @override
  List<Object?> get props => [product.id, quantity];
}

// --- Cart Events ---
abstract class ProfessionalCartEvent extends Equatable {
  const ProfessionalCartEvent();
  @override
  List<Object?> get props => [];
}

class AddToCartEvent extends ProfessionalCartEvent {
  final ProfessionalShopEntity shop;
  final ProfessionalProductEntity product;

  const AddToCartEvent({required this.shop, required this.product});

  @override
  List<Object?> get props => [shop.id, product.id];
}

class UpdateQuantityEvent extends ProfessionalCartEvent {
  final String productId;
  final int delta; // +1 or -1

  const UpdateQuantityEvent({required this.productId, required this.delta});

  @override
  List<Object?> get props => [productId, delta];
}

class SetFulfillmentModeEvent extends ProfessionalCartEvent {
  final String mode; // 'delivery' | 'pickup'

  const SetFulfillmentModeEvent(this.mode);

  @override
  List<Object?> get props => [mode];
}

class ConfirmClearAndSwitchShopEvent extends ProfessionalCartEvent {
  final ProfessionalShopEntity newShop;
  final ProfessionalProductEntity newProduct;

  const ConfirmClearAndSwitchShopEvent({required this.newShop, required this.newProduct});

  @override
  List<Object?> get props => [newShop.id, newProduct.id];
}

class ClearCartEvent extends ProfessionalCartEvent {}

// --- Cart State ---
class ProfessionalCartState extends Equatable {
  final ProfessionalShopEntity? currentShop;
  final List<CartItemModel> items;
  final String fulfillmentMode; // 'delivery' or 'pickup'
  final bool hasShopConflict;
  final ProfessionalShopEntity? conflictingShop;
  final ProfessionalProductEntity? conflictingProduct;

  const ProfessionalCartState({
    this.currentShop,
    this.items = const [],
    this.fulfillmentMode = 'delivery',
    this.hasShopConflict = false,
    this.conflictingShop,
    this.conflictingProduct,
  });

  bool get isEmpty => items.isEmpty;
  String get shopId => currentShop?.id ?? '';
  int get totalItemsCount => items.fold(0, (sum, i) => sum + i.quantity);
  
  double get subtotal => items.fold(0.0, (sum, i) => sum + i.itemTotal);
  double get totalSavings => items.fold(0.0, (sum, i) => sum + i.itemSavings);

  double get deliveryFee {
    if (fulfillmentMode == 'pickup' || currentShop == null) return 0.0;
    if (currentShop!.freeDeliveryThreshold > 0 && subtotal >= currentShop!.freeDeliveryThreshold) {
      return 0.0;
    }
    return currentShop!.deliveryCharges;
  }

  double get grandTotal => subtotal + deliveryFee;

  int getProductQuantity(String productId) {
    for (final item in items) {
      if (item.product.id == productId) return item.quantity;
    }
    return 0;
  }

  ProfessionalCartState copyWith({
    ProfessionalShopEntity? currentShop,
    List<CartItemModel>? items,
    String? fulfillmentMode,
    bool? hasShopConflict,
    ProfessionalShopEntity? conflictingShop,
    ProfessionalProductEntity? conflictingProduct,
    bool clearShop = false,
  }) {
    return ProfessionalCartState(
      currentShop: clearShop ? null : (currentShop ?? this.currentShop),
      items: items ?? this.items,
      fulfillmentMode: fulfillmentMode ?? this.fulfillmentMode,
      hasShopConflict: hasShopConflict ?? false,
      conflictingShop: conflictingShop,
      conflictingProduct: conflictingProduct,
    );
  }

  @override
  List<Object?> get props => [
        currentShop?.id,
        items,
        fulfillmentMode,
        hasShopConflict,
        conflictingShop?.id,
      ];
}

// --- Cart Bloc ---
class ProfessionalCartBloc extends Bloc<ProfessionalCartEvent, ProfessionalCartState> {
  ProfessionalCartBloc() : super(const ProfessionalCartState()) {
    on<AddToCartEvent>(_onAddToCart);
    on<UpdateQuantityEvent>(_onUpdateQuantity);
    on<SetFulfillmentModeEvent>(_onSetFulfillmentMode);
    on<ConfirmClearAndSwitchShopEvent>(_onConfirmClearAndSwitch);
    on<ClearCartEvent>(_onClearCart);
  }

  void _onAddToCart(AddToCartEvent event, Emitter<ProfessionalCartState> emit) {
    if (state.currentShop != null &&
        state.items.isNotEmpty &&
        state.currentShop!.id != event.shop.id) {
      emit(state.copyWith(
        hasShopConflict: true,
        conflictingShop: event.shop,
        conflictingProduct: event.product,
      ));
      return;
    }

    final currentItems = List<CartItemModel>.from(state.items);
    final index = currentItems.indexWhere((i) => i.product.id == event.product.id);

    if (index >= 0) {
      currentItems[index] = currentItems[index].copyWith(
        quantity: currentItems[index].quantity + 1,
      );
    } else {
      currentItems.add(CartItemModel(product: event.product, quantity: 1));
    }

    emit(state.copyWith(
      currentShop: event.shop,
      items: currentItems,
      hasShopConflict: false,
    ));
  }

  void _onUpdateQuantity(UpdateQuantityEvent event, Emitter<ProfessionalCartState> emit) {
    final currentItems = List<CartItemModel>.from(state.items);
    final index = currentItems.indexWhere((i) => i.product.id == event.productId);

    if (index >= 0) {
      final newQty = currentItems[index].quantity + event.delta;
      if (newQty <= 0) {
        currentItems.removeAt(index);
      } else {
        currentItems[index] = currentItems[index].copyWith(quantity: newQty);
      }
    }

    if (currentItems.isEmpty) {
      emit(const ProfessionalCartState());
    } else {
      emit(state.copyWith(items: currentItems));
    }
  }

  void _onSetFulfillmentMode(SetFulfillmentModeEvent event, Emitter<ProfessionalCartState> emit) {
    emit(state.copyWith(fulfillmentMode: event.mode));
  }

  void _onConfirmClearAndSwitch(ConfirmClearAndSwitchShopEvent event, Emitter<ProfessionalCartState> emit) {
    emit(ProfessionalCartState(
      currentShop: event.newShop,
      items: [CartItemModel(product: event.newProduct, quantity: 1)],
      fulfillmentMode: state.fulfillmentMode,
      hasShopConflict: false,
    ));
  }

  void _onClearCart(ClearCartEvent event, Emitter<ProfessionalCartState> emit) {
    emit(const ProfessionalCartState());
  }
}

