# JAMUI SERVICES — IMPLEMENTATION PHASE PLAN
**Document ID:** `IMPLEMENTATION_PHASE_PLAN.md`  
**Version:** 1.0.0 (Phase 0 Pre-Implementation Baseline)  
**Status:** STEP-BY-STEP TECHNICAL ROADMAP  
**Date:** 2026-10-30  

---

## 1. Overview & Phased Roadmap Strategy

To guarantee that the live Customer App, active karigars, and ongoing subscription billing are never disrupted, the Demand Category Mini E-commerce functionality will be built in **7 isolated, sequential phases**:

```
┌─────────────────────────────────────────────────────────────┐
│ PHASE 1: Data Architecture, Security Rules & Backend Core  │
└──────────────────────────────┬──────────────────────────────┘
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ PHASE 2: Admin Panel Demand Categories & Shop Management    │
└──────────────────────────────┬──────────────────────────────┘
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ PHASE 3: Provider App Merchant Onboarding & Catalog Engine  │
└──────────────────────────────┬──────────────────────────────┘
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ PHASE 4: Customer App Discovery, Storefront & Cart Engine   │
└──────────────────────────────┬──────────────────────────────┘
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ PHASE 5: Checkout, Server Order Validation & Order Tracking │
└──────────────────────────────┬──────────────────────────────┘
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ PHASE 6: Automated Testing, Edge Cases & Security Audits    │
└──────────────────────────────┬──────────────────────────────┘
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ PHASE 7: Controlled Staging Deployment & Play Store Rollout │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Phase-by-Phase Execution Details

### Phase 1: Backend Data Model, Security Rules & Cloud Functions Core
- **Goal:** Establish backend foundations, collections, and security guards before any client UI is built.
- **Tasks:**
  1. Add Firestore collections: `/demand_categories`, `/shops`, `/shops/{shopId}/products`, `/shops/{shopId}/categories`, `/shop_orders`.
  2. Update `backend/firebase/firestore.rules` with strict merchant-only and customer-only boundaries.
  3. Update `functions/r2_storage_upload_handler.js` to support `folder: 'products'` with 4MB image caps and WebP validation.
  4. Build automated unit test suite `functions/test/demand_category_rules_test.js`.
- **Files Modified / Added:**
  - `backend/firebase/firestore.rules` (append rules only)
  - `functions/r2_storage_upload_handler.js` (add `'products'` to `ALLOWED_FOLDERS`)
  - `functions/test/demand_category_backend_test.js` (new test suite)

### Phase 2: Admin Panel Demand Category & Merchant Management
- **Goal:** Enable internal Jamui Services administrators to create and manage demand categories and review physical shops.
- **Tasks:**
  1. Create Demand Categories feature in `admin_panel` (`features/demand_categories/`).
  2. Implement Demand Categories Table: Add, Edit, Toggle Active, Reorder, Upload Icon/Banner via Cloudflare R2.
  3. Add "Shop Providers" tab under `ProvidersPage` for approving retail merchant accounts.
  4. Add Shop Subscription configuration to `SubscriptionsPage`.
- **Files Modified / Added:**
  - `admin_panel/lib/features/demand_categories/` (new feature module)
  - `admin_panel/lib/features/layout/presentation/widgets/admin_sidebar.dart`
  - `admin_panel/lib/features/layout/presentation/pages/main_layout_page.dart`
  - `admin_panel/lib/features/providers/presentation/pages/providers_page.dart` (add Shops tab)

### Phase 3: Provider App Merchant Onboarding & Catalog Engine
- **Goal:** Allow local physical store owners to register their shop, configure fulfillment (Delivery/Pickup), and manage products.
- **Tasks:**
  1. Implement Provider Type router in `provider_app/lib/main.dart` (Karigar vs Shop).
  2. Build `ShopWorkspaceScreen` (Shop Dashboard, Today's Sales, Open/Closed Toggle).
  3. Build Product Catalog Manager:
     - Internal Category Manager (Add department e.g. "Spices", "Oils").
     - Add/Edit Product Modal with Cloudflare R2 image upload.
     - In-stock / Out-of-stock toggle and numeric inventory.
  4. Build Shop Fulfillment Settings:
     - Home Delivery ON/OFF, Delivery charges, Delivery radius, Min order amount.
     - Store Pickup ON/OFF, Pickup instructions.
- **Files Modified / Added:**
  - `provider_app/lib/features/shop/` (new dedicated shop module)
  - `provider_app/lib/main.dart` (branch routing based on `shops` collection check)

### Phase 4: Customer App Discovery, Storefront & Cart Engine
- **Goal:** Allow customers to discover nearby shops, explore storefronts, and build single-vendor carts.
- **Tasks:**
  1. Add Demand Categories horizontal scroll section to `customer_home_screen.dart`.
  2. Add "Nearby Local Shops" card carousel below Demand Categories.
  3. Build `CategoryShopsPage` (shows shops matching the selected category, filtered by customer GPS distance).
  4. Build `ShopDetailsPage` (Shop banner, verified badge, rating, contacts, delivery badges, "Open Shop" button).
  5. Build `ShopStorefrontPage`:
     - In-shop product search.
     - Category filter tabs.
     - Product cards with price, discount, WebP images, and interactive `[-] [qty] [+]` steppers.
  6. Implement Single-Shop Cart Manager (`CartBloc` / `CartController`).
- **Files Modified / Added:**
  - `customer_app/lib/features/home/presentation/pages/customer_home_screen.dart`
  - `customer_app/lib/features/shop_discovery/` (new module)
  - `customer_app/lib/features/cart/` (new single-shop cart module)

### Phase 5: Checkout, Server Order Validation & Real-time Tracking
- **Goal:** Enable end-to-end order placement, server-side price verification, and merchant fulfillment tracking.
- **Tasks:**
  1. Create Cloud Function `placeShopOrder`:
     - Authoritative price and stock recalculation.
     - Delivery radius validation.
     - Atomic batch write to `/shop_orders`.
     - FCM push notification to merchant with audible alert.
  2. Build Customer Checkout Sheet:
     - Address selector / Pickup summary.
     - Fulfillment breakdown (subtotal, delivery fee, grand total).
     - Payment selector (Cash on Delivery / Razorpay).
  3. Build Customer Order Tracking Screen (`CustomerOrderTrackingPage`):
     - Real-time Firestore snapshot listener on `/shop_orders/{orderId}`.
     - Visual stepper: Placed ➔ Accepted ➔ Preparing ➔ Out for Delivery / Ready for Pickup ➔ Completed.
     - 4-digit Delivery OTP display.
  4. Build Provider App Order Processing:
     - Real-time orders tab with sound alert.
     - One-tap "Accept", "Start Preparing", "Dispatched", "Delivered".
- **Files Modified / Added:**
  - `functions/index.js` (add `placeShopOrder`, `updateShopOrderStatus`)
  - `customer_app/lib/features/orders/` (customer order tracking)
  - `provider_app/lib/features/shop/presentation/pages/shop_orders_page.dart`

### Phase 6: Automated Testing, Edge Cases & Verification
- **Goal:** Rigorously test all edge cases, concurrency, security, and performance.
- **Test Scenarios:**
  - Multi-shop cart conflict resolution.
  - Delivery radius violation (customer ordering from 15 km away when shop delivers up to 5 km).
  - Out-of-stock and price tampering rejection.
  - Concurrency stock depletion test.
  - Zero regression on existing Karigar directory, Unisex Salon tests, and existing subscription tests.
- **Test Suites:**
  - `functions/test/shop_order_placement_test.js`
  - `functions/test/shop_inventory_concurrency_test.js`
  - `customer_app/test/cart_single_vendor_test.dart`

### Phase 7: Deployment & Controlled Rollout
- **Goal:** Production release without service interruption.
- **Execution:**
  1. Deploy Firestore Security Rules: `firebase deploy --only firestore:rules`.
  2. Deploy new Cloud Functions: `firebase deploy --only functions:placeShopOrder,functions:updateShopOrderStatus`.
  3. Build and deploy Admin Panel Web: `firebase deploy --only hosting:admin`.
  4. Release Provider App update (Web and APK).
  5. Release Customer App update to Google Play Store internal/open testing track.

---

## 3. Rollback & Fail-Safe Strategy
- All new features operate in isolated collections (`demand_categories`, `shops`, `shop_orders`).
- If an unforeseen issue arises in the shop vertical, toggling `isActive: false` on Demand Categories in Admin Panel instantly hides the entire e-commerce section from the Customer App homepage without requiring an app store update or affecting any karigar services.

