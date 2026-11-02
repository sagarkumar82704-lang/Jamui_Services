# JAMUI SERVICES — DEMAND CATEGORY MINI E-COMMERCE REQUIREMENTS
**Document ID:** `DEMAND_CATEGORY_REQUIREMENTS.md`  
**Version:** 1.0.0 (Phase 0 Pre-Implementation Baseline)  
**Status:** COMPLETE REQUIREMENTS SPECIFICATION  
**Date:** 2026-10-30  

---

## 1. Business Concept & Core Objectives

Jamui Services is expanding from an on-demand service karigar marketplace to a dual-vertical platform by introducing:

> **Demand Category Based Local Mini E-commerce Marketplace**

### 1.1 What is a "Demand Category"?
Unlike traditional service categories (Electrician, Plumber, Salon) where a technician visits a customer's home or provides personal services, **Demand Categories** represent local physical retail stores providing tangible physical goods on demand.

Examples of Demand Categories:
- **Grocery & Kirana Stores** (दुकान / किराना)
- **Sabji & Fresh Vegetables** (सब्जी मंडी)
- **Fresh Fruits** (फल दुकान)
- **Meat, Chicken & Fish Shops** (मांस / मछली)
- **Dairy & Milk Parlors** (डेयरी / दूध)
- **Bakery & Confectionery** (बेकरी)
- **Stationery & Books** (स्टेशनरी)
- **Hardware & Electrical Goods Store** (हार्डवेयर दुकान)
- **Pooja Samagri Stores** (पूजा सामग्री)

### 1.2 Strict Separation of Verticals
| Attribute | Existing Service Marketplace | New Demand Category Marketplace |
| :--- | :--- | :--- |
| **Provider Identity** | Individual Karigar / Technician / Studio | Local Physical Shop / Merchant |
| **Transaction Unit** | Visiting Fee / Service Booking / Direct Call | Product Cart & E-commerce Order |
| **Fulfillment** | Karigar visits home or customer visits salon | Merchant Self-Delivery OR Customer Pickup |
| **Inventory** | Time & Availability | Real-time Product Catalog & Stock |
| **Pricing** | Inspection charge + service estimates | Fixed unit prices (e.g. ₹40/kg, ₹120/pack)|
| **Cross-Eligibility** | Premium subscription grants salon/rich profile | **ZERO CROSSOVER**: Paying premium subscription NEVER grants shop features |

---

## 2. Customer Application Requirements

### 2.1 Homepage Integration
The customer homepage (`customer_home_screen.dart`) will present both verticals smoothly without clutter:

```
┌────────────────────────────────────────────────────────┐
│  JAMUI SERVICES (Location: Jamui Bazaar [GPS])    🔔  │
├────────────────────────────────────────────────────────┤
│  🔍 Search shops, products or karigars...              │
├────────────────────────────────────────────────────────┤
│  [ PROMOTIONAL BANNER CAROUSEL ]                       │
├────────────────────────────────────────────────────────┤
│  DEMAND CATEGORIES (Local Shops & Daily Needs)         │
│  [Grocery]  [Sabji]  [Fruits]  [Meat/Fish]  [Dairy]   │
├────────────────────────────────────────────────────────┤
│  NEARBY LOCAL SHOPS (Open Now, Fast Delivery/Pickup)   │
│  ┌──────────────────┐  ┌──────────────────┐           │
│  │ Gupta Kirana     │  │ Kisan Fresh Veg  │   [See All]│
│  │ ⭐ 4.8 • 1.2 km  │  │ ⭐ 4.9 • 800 m   │           │
│  └──────────────────┘  └──────────────────┘           │
├────────────────────────────────────────────────────────┤
│  HOME SERVICES (Karigars & Technicians)                │
│  [Electrician]  [Plumber]  [Carpenter]  [Painter]     │
├────────────────────────────────────────────────────────┤
│  TOP SERVICE PROVIDERS & KARIGARS                      │
│  ... (Existing Karigar Cards & Area Filters) ...       │
└────────────────────────────────────────────────────────┘
```

### 2.2 Customer Journey & Navigation Flow
```
Home Page 
   └── Tap Demand Category (e.g., Grocery)
         └── Category Shops Directory (Filtered by Jamui area & distance)
               └── Tap Shop Card
                     └── Shop Details Page (Overview, rating, delivery terms)
                           └── Tap "Open Shop / स्टोर खोलें"
                                 └── Mini E-commerce Storefront
                                       ├── Browse Categories & Search Products
                                       ├── Select Fulfillment: [ Delivery | Pickup ]
                                       ├── Add to Cart (Itemized quantities)
                                       ├── View Cart (Single-Shop Cart rule enforced)
                                       ├── Checkout & Address Confirmation
                                       ├── Place Order (COD or Online)
                                       └── Live Order Status Stepper & Tracking
```

### 2.3 Shop Details Page Specifications
When a customer selects a shop, before opening the full product catalog, a rich informative details screen is presented:
- **Visuals:** Shop banner header and square shop logo.
- **Identity:** Shop name, Verified badge, Demand Category pill.
- **Metrics:** Customer rating (stars + review count), distance in km from customer's GPS.
- **Direct Contacts:** Direct Call button, WhatsApp chat button, Google Maps "Directions" launcher.
- **Address:** Complete physical address and landmark.
- **Fulfillment Badges:**
  - `Home Delivery Available` (shows delivery radius, delivery fee, minimum order value).
  - `Store Pickup Available` (shows shop address and pickup instructions).
- **Business Timings:** Opening and closing hours, "Open Now" / "Closed" real-time status indicator.
- **Product Preview Section:** Horizontal scroll of 4-6 featured or best-selling products with prices.
- **Call to Action (Sticky Bottom Button):** **"Open Shop / स्टोर देखें"** (navigates to Storefront).

### 2.4 Mini E-commerce Storefront Specifications
- **Header:** Sticky shop name with live Cart icon showing total items and subtotal badge.
- **Fulfillment Switcher:** High-visibility toggle at the top:
  - `🚚 Home Delivery` (Active only if `shop.isHomeDeliveryActive == true` and customer is within `deliveryRadiusKm`).
  - `🏪 Store Pickup` (Active only if `shop.isPickupActive == true`).
  - If a mode is disabled by the merchant, it is visually grayed out with a helpful tooltip.
- **Search Bar:** Real-time search filter within this shop's product list.
- **Internal Category Tabs:** Horizontal chips of the merchant's custom categories (e.g., "Flour & Grains", "Oils & Ghee", "Snacks & Biscuits", "Spices", "All").
- **Product Listing:**
  - Product Image (optimized WebP via Cloudflare R2 CDN).
  - Product Title in Hindi and English.
  - Unit description (e.g., "1 kg", "500 gm", "1 Litre", "1 Piece", "1 Pack").
  - Pricing: Original MRP / Strike-through Price and Discounted Selling Price.
  - Stock State: "In Stock" with green badge, or "Out of Stock" with grayed card and disabled button.
  - Interactive Quantity Stepper:
    - If quantity is 0: Shows prominent **"+ Add"** button.
    - When added: Transforms into **`[-] [ 1 ] [+]`** interactive stepper.
- **Cart Bottom Bar (Float):** If cart has items, a floating pill appears at the bottom:
  `[ 3 Items | ₹340 ]   [ View Cart > ]`

### 2.5 Single-Shop Cart Enforcement Rule
To prevent complex multi-vendor delivery splits and inventory conflicts in local logistics:
- A customer's cart can only hold items from **ONE shop at a time**.
- If a customer has items from "Gupta Kirana" and attempts to add an item from "Verma Spices":
  - The app displays an alert dialog:
    > *"Your cart already contains items from Gupta Kirana. Do you want to clear your cart and start a fresh order from Verma Spices?"*
  - If customer confirms: Previous cart is cleared and the new item is added.
  - If customer cancels: Existing cart is preserved.

### 2.6 Checkout, Fulfillment & Order Tracking
- **Order Placement:**
  - Customer verifies Delivery Address (or Pickup instructions if Pickup is selected).
  - Order summary displays: Items subtotal, delivery charges (if Delivery), platform fee (if applicable), and final payable amount.
  - Payment options: **Cash on Delivery (COD)** or **Online via Razorpay**.
  - On submit: Payload is validated server-side by a Cloud Function before writing to Firestore.
- **Live Order Tracking Stepper:**
  - `Order Placed` ➔ `Accepted by Shop` ➔ `Preparing Order` ➔ `Out for Delivery / Ready for Pickup` ➔ `Delivered / Completed`.
  - Customer can call merchant directly from tracking screen.

---

## 3. Provider Application Requirements

### 3.1 Business Type Detection & Dashboard Isolation
When a provider logs into `provider_app`:
- The app inspects `providerType` from Firestore:
  - If `providerType === 'service'` (Karigar / Normal / Premium): Loads standard `ProviderWorkspaceScreen` (Leads, visiting charges, service pricing).
  - If `providerType === 'shop'` (Demand Category Merchant): Loads **`ShopWorkspaceScreen`**.
  - No mixed or confusing dashboard tabs. Service karigars never see product inventory; shop owners never see visiting fees.

### 3.2 Shop Dashboard Features
1. **Sales & Orders Overview:**
   - Today's Total Sales (₹).
   - Active Orders count (New, Preparing, Out).
   - Total Orders Completed.
   - Quick Shop Open / Closed (Vacation Mode) toggle.
2. **Real-time Order Alerts:**
   - Visual banner and audible chime when a new customer order arrives.
   - Quick "Accept" or "Reject" (with mandatory rejection reason).
3. **Product Catalog Management:**
   - **Product List:** Searchable, categorized list showing image, name, price, stock status.
   - **Add / Edit Product Screen:**
     - Product Title (Hindi & English).
     - Product Category (selected from merchant's categories).
     - Unit Type (`kg`, `gm`, `liter`, `ml`, `piece`, `packet`, `dozen`).
     - Unit Quantity (e.g., 1, 500, 250).
     - MRP (Regular Price) and Discount Selling Price.
     - Product Images (up to 3 images per product, uploaded to Cloudflare R2 via presigned URLs).
     - Stock Management: Toggle "In Stock" / "Out of Stock" or enter numeric inventory count.
     - "Best Seller" / "Special Offer" badges.
4. **Order Lifecycle Execution:**
   - **New Orders:** View customer name, address/pickup mode, itemized list with quantities, customer notes.
   - Action buttons: "Accept Order", "Reject Order".
   - Status updates: Tap "Start Preparing", then "Out for Delivery" (or "Ready for Pickup"), then "Mark Delivered" (with optional delivery OTP verification).
5. **Shop Settings & Fulfillment Controls:**
   - **Home Delivery Settings:**
     - Toggle: Home Delivery `ON / OFF`.
     - Minimum Order Amount for Free Delivery (or standard min order).
     - Delivery Fee (Flat ₹ or free above ₹X).
     - Delivery Radius (e.g. 1 km, 3 km, 5 km, up to 10 km max).
     - Estimated Delivery Time (e.g. 30-45 minutes).
   - **Store Pickup Settings:**
     - Toggle: Store Pickup `ON / OFF`.
     - Pickup Timing & Specific Instructions for customers.
   - **Shop Profile:**
     - Shop Name, Owner Contact, WhatsApp number.
     - Banner photo and Shop front photo.
     - Physical location GPS pin on map.

---

## 4. Admin Panel Requirements

### 4.1 Demand Categories Management
- Dedicated sidebar menu item: **`Demand Categories`** (distinct from Service Categories).
- Actions:
  - Add new Demand Category (Title Hindi, Title English, Icon upload, Banner upload, Priority order, Slug).
  - Toggle Category Active / Inactive.
  - Reorder categories for customer app display.
  - Delete / Archive demand category (blocks deletion if shops are attached).

### 4.2 Shop Merchant Onboarding & Moderation
- Dedicated tab in Providers management: **`Shop Providers`**.
- Review shop registration: Shop name, Trade license/GST (if applicable), Shop photos, Address, GPS coordinates, Assigned Demand Category.
- Admin Actions:
  - **Approve Shop:** Grants active storefront status.
  - **Suspend Shop:** Temporarily hides shop from customer listings.
  - **Deactivate / Soft-Delete:** Removes from platform.
  - **Change Demand Category:** Controlled admin action with atomic audit logging.

### 4.3 Catalog Moderation & Product Auditing
- Admin can inspect the full product catalog of any shop.
- Ability to disable or remove non-compliant, illegal, or misleading products.

### 4.4 Order Monitoring & City-wide Logistics Audit
- Centralized real-time feed of all local e-commerce orders across Jamui.
- Filter by: Today's Orders, Delayed Orders, Cancelled Orders, High-value Orders.
- Customer grievance resolution tools.

### 4.5 Shop Subscription & Commercial Plans
- Specialized subscription plans tailored for shops (e.g., Monthly Storefront Access, Higher Product Catalog Limits, Featured Shop Spotlight).

---

## 5. Storage, Cloudflare R2 & Cost Analysis

### 5.1 Storage Architecture Principles
- **No Product Images in Firestore:** Firestore stores only metadata and image CDN URLs.
- **Object Storage via Cloudflare R2:** Utilizing the existing S3 SigV4 presigned upload framework in `functions/r2_storage_upload_handler.js`.
- **Zero Egress Bandwidth Fees:** Unlike Firebase Storage / Google Cloud Storage which charges $0.12 per GB for public egress, Cloudflare R2 has **$0.00 / GB egress cost**, making it the only financially viable solution for high-traffic e-commerce product photos.

### 5.2 Storage Capacity Projections
- **Assumptions:**
  - Maximum 200 products per shop merchant.
  - Average 2 images per product (1 main + 1 detail/side view) = 400 images per shop.
  - Modern WebP compression target: 200 KB to 250 KB per compressed image.
  - Average storage footprint per shop: **~80 MB to 100 MB**.

| Metric | 100 Shops | 500 Shops | 1,000 Shops | 5,000 Shops |
| :--- | :---: | :---: | :---: | :---: |
| **Total Products** | 20,000 | 100,000 | 200,000 | 1,000,000 |
| **Total Images Stored** | 40,000 | 200,000 | 400,000 | 2,000,000 |
| **Total Storage Volume** | **~10 GB** | **~50 GB** | **~100 GB** | **~500 GB** |

### 5.3 Financial Cost Breakdown (Cloudflare R2 + Firebase)
*Based on official Cloudflare R2 pricing ($0.015/GB-month, 10 GB free tier; Class A PUT: $4.50/M; Class B GET: $0.36/M, 10M free; $0.00 egress):*

| Component | 100 Shops / mo | 500 Shops / mo | 1,000 Shops / mo | 5,000 Shops / mo |
| :--- | :---: | :---: | :---: | :---: |
| **R2 Storage Cost** | **$0.00** (Free tier) | **$0.60** (₹50) | **$1.35** (₹112) | **$7.35** (₹610) |
| **R2 Upload Operations (Class A)**| $0.18 | $0.90 | $1.80 | $9.00 |
| **R2 Read Operations (Class B)**  | $0.00 (within 10M) | $0.00 (within 10M) | $0.72 | $3.60 |
| **Data Egress Bandwidth**        | **$0.00 (FREE)** | **$0.00 (FREE)** | **$0.00 (FREE)** | **$0.00 (FREE)** |
| **Firestore Database (NoSQL)**   | Free tier / ₹100 | ₹400 - ₹800 | ₹1,200 - ₹2,000 | ₹6,000 - ₹10,000 |
| **Firebase Cloud Functions**     | Free tier | ₹150 - ₹300 | ₹400 - ₹800 | ₹2,000 - ₹3,500 |
| **ESTIMATED TOTAL MONTHLY COST** | **< ₹200 / mo** | **~₹800 - ₹1,400**| **~₹2,000 - ₹3,500** | **~₹9,000 - ₹15,000** |

> **Cost Optimization Key:** Cloudflare R2 caching combined with image client-side compression (Flutter `flutter_image_compress` before presigned PUT) guarantees that media infrastructure costs remain virtually negligible (< 5% of gross platform revenue).

