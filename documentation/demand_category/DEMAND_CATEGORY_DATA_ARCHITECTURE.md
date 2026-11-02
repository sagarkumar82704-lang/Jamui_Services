# JAMUI SERVICES — DEMAND CATEGORY DATA ARCHITECTURE
**Document ID:** `DEMAND_CATEGORY_DATA_ARCHITECTURE.md`  
**Version:** 1.0.0 (Phase 0 Pre-Implementation Baseline)  
**Status:** FIRESTORE SCHEMA & DATA RELATIONSHIP DESIGN  
**Date:** 2026-10-30  

---

## 1. Architectural Strategy & Isolation Principles

To ensure zero risk of data corruption, regression, or accidental schema overlap with the live Play Store Customer App and Karigar Service Marketplace, the Demand Category Mini E-commerce system employs **Isolated Domain Architecture**:

```
           EXISTING VERTICAL                         NEW E-COMMERCE VERTICAL
┌───────────────────────────────────────┐   ┌───────────────────────────────────────┐
│ • categories/ (Normal Services)       │   │ • demand_categories/ (Retail Sectors) │
│ • premium_categories/ (Salon etc.)    │   │ • shops/ (Merchant Profiles)          │
│ • services/ (Service Items)           │   │ • shops/{id}/products/ (Catalog)      │
│ • providers/ (Karigars / Technicians) │   │ • shops/{id}/categories/ (Shop Depts) │
│ • leads/ (Inspection Requests)        │   │ • shop_orders/ (Fulfillment Orders)   │
│ • subscription_plans/ (Karigar Plans) │   │ • shop_subscriptions/ (Shop Plans)    │
└───────────────────────────────────────┘   └───────────────────────────────────────┘
                     ▲                                     ▲
                     └──────────────────┬──────────────────┘
                                        │
                         SHARED CROSS-CUTTING ENTITIES
                     ┌──────────────────────────────────────┐
                     │ • users/ (Customer Profiles)         │
                     │ • admin_users/ (Authorized Staff)    │
                     │ • audit_logs/ (Security Audit Trail) │
                     │ • app_config/ (Public Configuration) │
                     └──────────────────────────────────────┘
```

---

## 2. Firestore Collection Specifications

### 2.1 Collection: `demand_categories`
- **Purpose:** Stores admin-managed retail store categories (Grocery, Sabji, Meat, etc.).
- **Path:** `/demand_categories/{categoryId}`
- **Document ID:** URL-safe slug (e.g. `grocery_kirana`, `fresh_vegetables`, `fruit_shop`, `meat_fish`, `dairy_sweets`).

```typescript
interface DemandCategoryDocument {
  id: string;                     // Matches document ID e.g. 'grocery_kirana'
  titleHindi: string;             // e.g. 'किराना एवं दैनिक सामान'
  titleEnglish: string;           // e.g. 'Grocery & Daily Needs'
  slug: string;                   // 'grocery_kirana'
  iconUrl: string;                // R2 CDN URL for square icon
  bannerUrl: string;              // R2 CDN URL for promo header banner
  priorityOrder: number;          // Sort index (1, 2, 3...)
  isActive: boolean;              // Global visibility toggle
  totalShopsCount: number;        // Cached aggregate of active shops
  createdAt: Timestamp;           // Server timestamp
  updatedAt: Timestamp;           // Server timestamp
  createdBy: string;              // Admin UID
}
```

### 2.2 Collection: `shops` (Shop Merchant Profile)
- **Purpose:** Primary profile for physical retail shop merchants.
- **Path:** `/shops/{shopId}`
- **Document ID:** Matches the merchant's Firebase Auth `ownerUid` (guarantees strict 1:1 owner mapping and prevents duplicate stores per account).

```typescript
interface ShopDocument {
  id: string;                          // Matches ownerUid
  ownerUid: string;                    // Firebase Auth UID
  ownerPhone: string;                  // Primary verified phone
  ownerEmail: string;                  // Primary auth email
  shopName: string;                    // e.g. 'Gupta General Store'
  demandCategoryId: string;            // Reference to demand_categories/{id}
  demandCategoryTitle: string;         // Denormalized for zero-join reads
  logoUrl: string;                     // Shop logo / storefront picture
  bannerUrl: string;                   // Shop showcase cover photo
  description: string;                 // About the store & specialties
  
  // Physical Location & Service Coverage
  fullAddress: string;                 // Street, landmark, Jamui area
  jamuiArea: string;                   // e.g. 'Jamui Bazaar', 'Jhajha'
  latitude: number;                    // GPS coordinates
  longitude: number;                   // GPS coordinates
  serviceRadiusKm: number;             // Delivery coverage radius (default: 5.0 km)
  
  // Contact & Social
  contactPhone: string;                // Customer-facing shop hotline
  whatsAppNumber: string;              // Order inquiries number
  
  // Fulfillment Configuration
  isHomeDeliveryActive: boolean;       // Master toggle for home delivery
  isPickupActive: boolean;             // Master toggle for store pickup
  minOrderAmount: number;              // Minimum cart value for delivery (e.g. ₹150)
  deliveryCharges: number;             // Base delivery fee (e.g. ₹20, or 0 for free)
  freeDeliveryThreshold: number;       // Free delivery on orders above (e.g. ₹500)
  estimatedDeliveryTimeMinutes: number;// e.g. 35 mins
  pickupInstructions: string;          // e.g. 'Collect at Counter #2'
  
  // Store Operational State
  isOpen: boolean;                     // Real-time merchant toggle (Open / Closed)
  openingTime: string;                 // e.g. '08:00 AM'
  closingTime: string;                 // e.g. '09:30 PM'
  
  // Admin Approval & Platform Lifecycle
  status: 'pending_approval' | 'approved' | 'rejected' | 'suspended';
  isVerified: boolean;                 // Explicit admin verification badge
  isActive: boolean;                   // Admin soft-enable toggle
  isDeleted: boolean;                  // Soft-delete guard
  rejectionReason?: string;            // Feedback if rejected
  
  // Subscription & Commercial Tier
  subscriptionPlanId: string;          // e.g. 'shop_standard_monthly'
  isSubscriptionActive: boolean;       // Whether shop subscription is valid
  subscriptionExpiry: Timestamp;       // Expiration date
  paymentVerified: boolean;            // Payment status
  
  // Metrics & Aggregates
  rating: number;                      // Average customer rating (1.0 - 5.0)
  ratingCount: number;                 // Total verified reviews
  totalOrders: number;                 // Total lifetime orders completed
  totalProductsCount: number;          // Total active products in catalog
  
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
```

### 2.3 Subcollection: `shops/{shopId}/categories` (Shop Product Categories)
- **Purpose:** In-store product departments created by the merchant (e.g., "Dairy", "Spices", "Grains").
- **Path:** `/shops/{shopId}/categories/{categoryId}`

```typescript
interface ShopInternalCategory {
  id: string;                     // Auto-generated ID or slug
  nameHindi: string;              // e.g. 'दाल एवं अनाज'
  nameEnglish: string;            // e.g. 'Pulses & Grains'
  priorityOrder: number;          // Merchant display order
  isActive: boolean;              // Toggle category visibility
  productCount: number;           // Count of products in category
}
```

### 2.4 Subcollection: `shops/{shopId}/products` (Product Catalog)
- **Purpose:** Physical items sold by the merchant.
- **Path:** `/shops/{shopId}/products/{productId}`
- **Subcollection Advantage:** Provides complete tenant isolation, simple security rules (`isOwner(shopId)`), and automatic horizontal scaling.

```typescript
interface ProductDocument {
  id: string;                     // Auto-generated product ID
  shopId: string;                 // Parent shop document ID
  internalCategoryId: string;     // Reference to shops/{shopId}/categories/{id}
  categoryName: string;           // Denormalized name for quick display
  
  titleHindi: string;             // e.g. 'आशीर्वाद शुद्ध चक्की आटा'
  titleEnglish: string;           // e.g. 'Aashirvaad Shudh Chakki Atta'
  description: string;            // Product description / ingredients
  
  // Unit & Packaging
  unit: 'kg' | 'gm' | 'liter' | 'ml' | 'piece' | 'packet' | 'dozen';
  unitValue: number;              // e.g. 5 (for 5 kg) or 500 (for 500 gm)
  
  // Pricing
  regularPrice: number;           // MRP (e.g. ₹260)
  sellingPrice: number;           // Discounted customer price (e.g. ₹235)
  discountPercentage: number;     // Computed (e.g. 10%)
  
  // Images (Cloudflare R2 CDN)
  images: string[];               // Array of R2 CDN URLs (up to 3)
  thumbnailUrl: string;           // Optimized 250x250 WebP preview
  
  // Stock & Inventory
  inStock: boolean;               // Merchant live availability toggle
  trackInventory: boolean;        // Whether quantity tracking is enabled
  stockQuantity: number;          // Current stock count (if tracked)
  
  // Badges & Promotion
  isBestSeller: boolean;          // Featured badge
  isFeatured: boolean;            // Highlighted at store top
  
  isActive: boolean;              // Product active status
  isDeleted: boolean;             // Soft-delete
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
```

### 2.5 Collection: `shop_orders` (Orders & Transactions)
- **Purpose:** Immutable customer orders placed with local shops.
- **Path:** `/shop_orders/{orderId}`
- **Document ID:** Formatted human-readable ID (e.g. `ORD_JAMUI_202610_89234`).

```typescript
interface ShopOrderItem {
  productId: string;
  titleHindi: string;
  titleEnglish: string;
  unit: string;
  unitValue: number;
  thumbnailUrl: string;
  pricePerUnit: number;           // Server-verified price at time of order
  quantity: number;               // Quantity ordered
  itemTotal: number;              // pricePerUnit * quantity
}

interface ShopOrderDocument {
  orderId: string;                // e.g. 'ORD_JAMUI_202610_89234'
  
  // Customer References
  customerId: string;             // Firebase Auth UID of customer
  customerName: string;           // Customer profile name
  customerPhone: string;          // Customer verified phone number
  
  // Merchant References
  shopId: string;                 // Reference to /shops/{shopId}
  shopName: string;               // Gupta Kirana
  shopPhone: string;              // Merchant contact
  demandCategoryId: string;       // 'grocery_kirana'
  
  // Order Content & Calculation
  items: ShopOrderItem[];         // Array of ordered products
  totalItemsCount: number;        // Sum of quantities
  subtotal: number;               // Sum of item totals (₹)
  deliveryCharge: number;         // Delivery fee applied (0 if pickup or free)
  packagingCharge: number;        // Optional packaging fee
  discountAmount: number;         // Platform or coupon discount
  totalAmount: number;            // Final payable amount: subtotal + delivery + packaging - discount
  
  // Fulfillment Details
  fulfillmentType: 'delivery' | 'pickup';
  deliveryAddress?: {             // Required if fulfillmentType === 'delivery'
    recipientName: string;
    recipientPhone: string;
    fullAddress: string;
    landmark?: string;
    jamuiArea: string;
    latitude: number;
    longitude: number;
  };
  pickupInstructions?: string;    // If fulfillmentType === 'pickup'
  customerNotes?: string;         // e.g. 'Leave with neighbor if door closed'
  
  // Payment Details
  paymentMode: 'cod' | 'razorpay';
  paymentStatus: 'pending' | 'completed' | 'refunded' | 'failed';
  razorpayOrderId?: string;
  razorpayPaymentId?: string;
  
  // Order Lifecycle State Machine
  status: 'placed' 
        | 'accepted' 
        | 'preparing' 
        | 'out_for_delivery' 
        | 'ready_for_pickup' 
        | 'delivered' 
        | 'collected' 
        | 'cancelled' 
        | 'rejected';
        
  statusTimestamps: {
    placedAt: Timestamp;
    acceptedAt?: Timestamp;
    preparingAt?: Timestamp;
    dispatchedAt?: Timestamp;
    completedAt?: Timestamp;
    cancelledAt?: Timestamp;
  };
  
  rejectionReason?: string;       // If shop rejected the order
  cancellationReason?: string;    // If customer/merchant cancelled
  deliveryOtp?: string;           // 4-digit completion verification code
  
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
```

### 2.6 Collection: `shop_reviews`
- **Purpose:** Verified customer reviews for completed shop orders.
- **Path:** `/shops/{shopId}/reviews/{reviewId}`
- **Constraint:** Customer can only review after an order is marked `delivered` or `collected`.

```typescript
interface ShopReviewDocument {
  id: string;
  orderId: string;                // Must link to verified shop_orders record
  customerId: string;
  customerName: string;
  rating: number;                 // 1 to 5 stars
  reviewText: string;
  merchantReply?: string;         // Shop owner response
  createdAt: Timestamp;
}
```

---

## 3. Separation of States: Approval vs Payment vs Storefront

A critical design requirement is preventing state entanglement:
```
┌─────────────────────────┐
│ 1. Registration Draft   │ (Merchant fills shop profile & uploads documents)
└───────────┬─────────────┘
            │ Submits for verification
            ▼
┌─────────────────────────┐
│ 2. Admin Review Pending │ (Admin verifies physical presence in Jamui)
└───────────┬─────────────┘
            │ Admin approves
            ▼
┌─────────────────────────┐
│ 3. Shop Approved        │ (Account verified; storefront still hidden from public)
└───────────┬─────────────┘
            │ Merchant subscribes via Razorpay
            ▼
┌─────────────────────────┐
│ 4. Subscription Active  │ (Commercial status verified by Cloud Functions)
└───────────┬─────────────┘
            │ Merchant sets isOpen: true and adds at least 1 in-stock product
            ▼
┌─────────────────────────┐
│ 5. LIVE STOREFRONT      │ (Visible on Customer App homepage & search)
└─────────────────────────┘
```

- **Approval without Payment:** Merchant can configure products and settings in `provider_app`, but shop is **not visible to customers**.
- **Payment without Approval:** Impossible — subscription screen is locked until Admin approves shop KYC.
- **Vacation Mode:** Approved & paid merchant can toggle `isOpen: false` anytime to pause orders without losing ranking or data.

---

## 4. Firestore Security Rules Specifications

The following rules will be introduced into `backend/firebase/firestore.rules` for the new collections:

```javascript
// Demand Categories: Public read, Admin-only write
match /demand_categories/{catId} {
  allow read: if true;
  allow write: if isAdmin();
}

// Shops Directory:
// 1. Public can read approved, active, subscribed shops.
// 2. Owner can read and update their own shop settings (except admin approval & subscription fields).
// 3. Admin can read and write all.
match /shops/{shopId} {
  allow read: if true;
  allow create: if isAuthenticated() && request.auth.uid == shopId;
  allow update: if isAdmin() || (
    isAuthenticated() && 
    request.auth.uid == shopId &&
    // Merchant cannot self-approve or activate subscriptions
    !request.resource.data.diff(resource.data).affectedKeys().hasAny([
      'status', 'isVerified', 'isSubscriptionActive', 'subscriptionExpiry', 
      'paymentVerified', 'rating', 'ratingCount', 'totalOrders'
    ])
  );
  allow delete: if isAdmin();

  // Products Subcollection:
  // Public read active products; Shop owner write
  match /products/{productId} {
    allow read: if true;
    allow write: if isAdmin() || (isAuthenticated() && request.auth.uid == shopId);
  }

  // Categories Subcollection:
  match /categories/{catId} {
    allow read: if true;
    allow write: if isAdmin() || (isAuthenticated() && request.auth.uid == shopId);
  }
}

// Shop Orders:
// Customer can read own orders. Shop owner can read orders for their shopId.
// Order creation is strictly delegated to Cloud Function to prevent price tampering!
match /shop_orders/{orderId} {
  allow read: if isAuthenticated() && (
    resource.data.customerId == request.auth.uid ||
    resource.data.shopId == request.auth.uid ||
    isAdmin()
  );
  // Updates strictly restricted to status progression
  allow update: if isAdmin() || (
    isAuthenticated() && 
    resource.data.shopId == request.auth.uid &&
    request.resource.data.diff(resource.data).affectedKeys().hasOnly([
      'status', 'statusTimestamps', 'rejectionReason', 'updatedAt'
    ])
  );
  allow create, delete: if false; // Cloud Functions exclusively handle creation & cancel
}
```

---

## 5. Required Firestore Composite Indexes

To ensure high-performance querying without client-side memory overhead:
1. `shops`: `(demandCategoryId ASC, isActive ASC, isSubscriptionActive ASC, rating DESC)`
2. `shops`: `(jamuiArea ASC, demandCategoryId ASC, isOpen ASC)`
3. `shop_orders`: `(customerId ASC, createdAt DESC)`
4. `shop_orders`: `(shopId ASC, status ASC, createdAt DESC)`
5. `shops/{shopId}/products`: `(internalCategoryId ASC, isActive ASC, inStock ASC)`

