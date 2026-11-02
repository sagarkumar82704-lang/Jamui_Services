# JAMUI SERVICES — DEMAND CATEGORY BUSINESS ALGORITHMS & LOGIC
**Document ID:** `DEMAND_CATEGORY_BUSINESS_ALGORITHM.md`  
**Version:** 1.0.0 (Phase 0 Pre-Implementation Baseline)  
**Status:** BUSINESS LOGIC & STATE MACHINE SPECIFICATION  
**Date:** 2026-10-30  

---

## 1. Provider Type Detection & Dashboard Routing Algorithm

```
                           PROVIDER APP LOGIN (Email/Pass + OTP)
                                            │
                                            ▼
                          Fetch /providers/{uid} and /shops/{uid}
                                            │
                                            ▼
                           Does /shops/{uid} document exist?
                                    │               │
                                   YES              NO
                                    │               │
                                    ▼               ▼
                       Is shop.isDeleted == true?   Standard Karigar Flow
                                    │               (ProviderWorkspaceScreen)
                                    │
                        ┌───────────┴───────────┐
                       YES                      NO
                        │                       │
                        ▼                       ▼
               AccountBlockedPage        Evaluate Shop Account State:
                                         ┌───────────────────────────────────┐
                                         │ • status == 'draft' ➔ Setup Wizard│
                                         │ • status == 'pending' ➔ Review    │
                                         │ • status == 'approved' ➔ Check Sub│
                                         │   ├── Sub Inactive ➔ Sub Plans    │
                                         │   └── Sub Active ➔ Shop Workspace │
                                         └───────────────────────────────────┘
```

### Pseudo-code Implementation
```dart
Future<Widget> resolveProviderInitialScreen(String uid) async {
  final shopDoc = await FirebaseFirestore.instance.collection('shops').doc(uid).get();
  
  if (shopDoc.exists) {
    final shop = ShopModel.fromFirestore(shopDoc);
    if (shop.isDeleted) {
      return AccountBlockedPage(reason: 'दुकान खाता हटा दिया गया है।');
    }
    if (shop.status == ShopStatus.draft) {
      return ShopOnboardingWizard(initialShop: shop);
    }
    if (shop.status == ShopStatus.pendingApproval) {
      return ShopPendingApprovalScreen(shop: shop);
    }
    if (shop.status == ShopStatus.approved && !shop.isSubscriptionActive) {
      return ShopSubscriptionPage(shop: shop);
    }
    // Fully approved and active merchant
    return ShopWorkspaceScreen(shop: shop);
  }

  // Fallback to existing Karigar / Service Provider Workspace
  final providerDoc = await FirebaseFirestore.instance.collection('providers').doc(uid).get();
  final profile = ProviderProfileModel.fromFirestore(providerDoc);
  return ProviderWorkspaceScreen(profile: profile);
}
```

---

## 2. Fulfillment Availability & Checkout Eligibility Algorithm

When a customer opens a shop's storefront or attempts to place an order, the system evaluates the fulfillment eligibility using this strict algorithm:

```
                      CUSTOMER ATTEMPTS ORDER CHECKOUT
                                     │
                                     ▼
                     Is shop.isOpen == true (Shop Open)?
                                     │
                         ┌───────────┴───────────┐
                        NO                      YES
                         │                       │
                         ▼                       ▼
                 ORDERING BLOCKED         Check Customer Selected Mode:
                 "दुकान अभी बंद है"       [ DELIVERY ]  or  [ PICKUP ]
                                                 │                 │
                                                 ▼                 ▼
                                         Evaluate Delivery   Evaluate Pickup
```

### 2.1 Delivery Eligibility Algorithm
```
Input: Customer GPS (lat1, lon1), Shop GPS (lat2, lon2), Cart Subtotal, Shop Settings
1. Compute Distance: D = HaversineFormula(lat1, lon1, lat2, lon2) in Kilometers.
2. If shop.isHomeDeliveryActive == false:
      REJECT ➔ "यह दुकान होम डिलीवरी नहीं करती है। कृपया स्टोर पिकअप चुनें।"
3. If D > shop.serviceRadiusKm:
      REJECT ➔ "आपका पता डिलीवरी क्षेत्र (${shop.serviceRadiusKm} km) से बाहर है। दूरी: ${D.toStringAsFixed(1)} km"
4. If Cart.subtotal < shop.minOrderAmount:
      REJECT ➔ "न्यूनतम ऑर्डर मूल्य ₹${shop.minOrderAmount} है। वर्तमान: ₹${Cart.subtotal}"
5. Compute Delivery Fee:
      If shop.freeDeliveryThreshold > 0 and Cart.subtotal >= shop.freeDeliveryThreshold:
          deliveryFee = 0.0 (Free Delivery)
      Else:
          deliveryFee = shop.deliveryCharges
6. ALLOW DELIVERY ➔ Proceed with computed deliveryFee.
```

### 2.2 Pickup Eligibility Algorithm
```
Input: Shop Settings
1. If shop.isPickupActive == false:
      REJECT ➔ "इस दुकान पर स्टोर पिकअप उपलब्ध नहीं है।"
2. Set deliveryFee = 0.0.
3. Attach shop.pickupInstructions and shop.fullAddress to order summary.
4. ALLOW PICKUP ➔ Proceed to Order Confirmation.
```

---

## 3. Single-Shop Cart Enforcement Algorithm

```dart
class CartController {
  String? currentShopId;
  String? currentShopName;
  final List<CartItem> _items = [];

  void addItem({required ShopEntity shop, required ProductEntity product}) {
    // Case 1: Cart is completely empty
    if (currentShopId == null || _items.isEmpty) {
      currentShopId = shop.id;
      currentShopName = shop.shopName;
      _items.add(CartItem(product: product, quantity: 1));
      notifyListeners();
      return;
    }

    // Case 2: Item belongs to the same shop
    if (currentShopId == shop.id) {
      final existingIndex = _items.indexWhere((i) => i.product.id == product.id);
      if (existingIndex >= 0) {
        _items[existingIndex].quantity += 1;
      } else {
        _items.add(CartItem(product: product, quantity: 1));
      }
      notifyListeners();
      return;
    }

    // Case 3: Item belongs to a DIFFERENT shop
    // Prompt confirmation dialog before resetting cart
    showConflictDialog(
      existingShop: currentShopName!,
      newShop: shop.shopName,
      onConfirm: () {
        _items.clear();
        currentShopId = shop.id;
        currentShopName = shop.shopName;
        _items.add(CartItem(product: product, quantity: 1));
        notifyListeners();
      },
    );
  }
}
```

---

## 4. Server-Side Checkout & Order Placement Cloud Function

To prevent client-side price tampering or inventory exploits, order placement is processed **exclusively** by a 2nd Gen Firebase Cloud Function:

```
Callable Function: placeShopOrder(request)
```

### Step-by-Step Backend Verification Pipeline:
1. **Authentication Check:** Validates `request.auth.uid`. Unauthenticated users rejected with `unauthenticated`.
2. **Payload Parsing:** Reads `shopId`, `fulfillmentType`, `deliveryAddress`, `items: [{productId, quantity}]`.
3. **Shop Validation:**
   - Reads `/shops/{shopId}` from Firestore.
   - Verifies `shop.status === 'approved'`, `shop.isActive === true`, `shop.isOpen === true`.
   - Verifies `shop.isSubscriptionActive === true` and `subscriptionExpiry > now`.
4. **Fulfillment Validation:**
   - If `delivery`: Validates distance using customer address coordinates against `shop.serviceRadiusKm`.
   - Validates minimum order amount.
5. **Authoritative Price & Stock Recalculation:**
   - Queries each product document `/shops/{shopId}/products/{productId}` in a transaction or parallel get.
   - Checks `product.isActive === true` and `product.inStock === true`.
   - If `product.trackInventory === true`, checks `product.stockQuantity >= item.quantity`.
   - Re-fetches the real `sellingPrice` from database. **Never trusts client item prices.**
   - Calculates `itemTotal = sellingPrice * quantity`.
   - Calculates `computedSubtotal = sum(itemTotal)`.
6. **Delivery Fee Calculation:**
   - Calculates delivery fee from authoritative `shop.deliveryCharges` and `shop.freeDeliveryThreshold`.
   - Calculates `finalTotal = computedSubtotal + computedDeliveryFee`.
7. **Atomic Firestore Batch / Transaction:**
   - Generates unique order ID (e.g. `ORD_JAMUI_${Date.now()}_${random}`).
   - Writes new `/shop_orders/{orderId}` document with status `'placed'`.
   - Decrements `product.stockQuantity` if tracked.
   - Increments customer's `totalOrders` and shop's pending order counter.
8. **FCM Push Notification Trigger:**
   - Sends high-priority push notification to shop merchant's device with order sound:
     > *"नया ऑर्डर प्राप्त हुआ! ₹${finalTotal} का ऑर्डर आया है।"*
9. **Return to Customer:** Returns `{ success: true, orderId: orderId, totalAmount: finalTotal }`.

---

## 5. Order Lifecycle State Machine

```
                              [ CUSTOMER PLACES ORDER ]
                                          │
                                          ▼
                                   Status: 'placed'
                                          │
                   ┌──────────────────────┴──────────────────────┐
                   │                                             │
      Merchant Accepts Order                        Merchant Rejects Order
                   │                                             │
                   ▼                                             ▼
          Status: 'accepted'                            Status: 'rejected'
                   │                                     (Requires Reason)
                   ▼                                             │
          Status: 'preparing'                                    ▼
                   │                                     [ Order Terminated ]
       ┌───────────┴───────────┐
       │                       │
If Fulfillment == 'delivery'   If Fulfillment == 'pickup'
       │                       │
       ▼                       ▼
Status: 'out_for_delivery'     Status: 'ready_for_pickup'
       │                       │
       ▼                       ▼
Status: 'delivered'            Status: 'collected'
       │                       │
       └───────────┬───────────┘
                   │
                   ▼
         [ ORDER COMPLETED ]
                   │
                   ▼
     (Customer Review Prompted)
```

---

## 6. Shop Subscription Lifecycle & Renewal Algorithm

1. **New Shop Trial:** Admin can configure an optional 15-day or 30-day trial for new verified shops.
2. **Standard Shop Plan:** Flat monthly or quarterly subscription fee via Razorpay.
3. **Daily Expiry Cron (`checkSubscriptionExpiry` in `functions/index.js`):**
   - Evaluates all `/shops` where `subscriptionExpiry <= now`.
   - Sets `isSubscriptionActive: false`.
   - Sets `isOpen: false` (automatically pauses storefront).
   - Sends FCM reminder to merchant to renew subscription.
   - **Zero Data Loss:** Existing products, categories, and past order history remain completely preserved in the database. When the merchant renews, the storefront instantly reactivates!

