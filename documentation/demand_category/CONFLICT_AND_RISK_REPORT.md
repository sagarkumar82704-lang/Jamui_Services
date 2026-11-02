# JAMUI SERVICES — CONFLICT, RISK & MITIGATION REPORT
**Document ID:** `CONFLICT_AND_RISK_REPORT.md`  
**Version:** 1.0.0 (Phase 0 Pre-Implementation Baseline)  
**Status:** COMPREHENSIVE RISK & CONFLICT AUDIT  
**Date:** 2026-10-30  

---

## 1. Executive Risk Summary

Because Jamui Services already has an active, revenue-generating customer base and the Customer Application is live on the Google Play Store, introducing a Demand Category Mini E-commerce system carries potential technical, architectural, and operational risks if not cleanly isolated.

This document details every identified risk, existing code conflicts, performance bottlenecks, and the mandatory mitigations required before writing a single line of production code.

---

## 2. Codebase & Data Model Conflict Analysis

### 2.1 Risk 1: Collision Between Service Categories & Demand Categories
- **The Danger:** Reusing the existing `/categories` or `/premium_categories` collections for physical shops (e.g., adding `grocery` directly to `categories`).
- **Impact if Violated:**
  1. The Customer App's 5-column service grid (`_buildRealCategoriesGrid`) would display "Grocery" alongside "Plumber", causing customer confusion.
  2. Clicking "Grocery" would invoke `CategoryProvidersPage` which expects karigar profiles with `visitingCharge` and `experienceYears`.
  3. Backend test suites (e.g. `unisex_premium_classification_test.js`) enforce specific classification rules on `categories` that would fail or require messy exceptions.
- **Mandatory Mitigation:**
  - **Zero Overlap:** Demand Categories are stored exclusively in `/demand_categories`.
  - The Customer App UI renders Demand Categories in a completely separate section above the existing Service Categories.

### 2.2 Risk 2: Schema Bloat & Regression in `/providers` Collection
- **The Danger:** Adding e-commerce fields (`isHomeDeliveryActive`, `deliveryRadiusKm`, `productsList`, `minOrderAmount`) directly into existing karigar documents in `/providers/{uid}`.
- **Impact if Violated:**
  1. Breaks existing Dart entity deserializers (`ServiceProviderModel.fromMap` in `customer_app` and `provider_app`).
  2. Modifies document size and triggers unnecessary cache invalidations across the entire karigar directory.
  3. Violates Single Responsibility Principle.
- **Mandatory Mitigation:**
  - Create a dedicated root collection `/shops/{shopId}`.
  - A merchant account uses the same Auth UID, but its storefront data lives in `/shops/{uid}`.

### 2.3 Risk 3: Subcollection vs Root Collection for Products
- **Option A (Subcollection):** `/shops/{shopId}/products/{productId}`
- **Option B (Root Collection):** `/shop_products/{productId}` with field `shopId`
- **Conflict Assessment:**
  - Option A provides natural multi-tenancy, zero possibility of one merchant viewing/editing another's catalog, clean Firestore rules (`match /shops/{shopId}/products/{productId} allow write: if request.auth.uid == shopId`), and automatic isolation.
  - Option B requires composite indexes on every query and complex security rule assertions.
- **Chosen Architecture:** **Option A (Subcollection `/shops/{shopId}/products`)** with a Firestore collection group index (`collectionGroup('products')`) ONLY if cross-shop global product search is introduced in the future.

---

## 3. Authentication & Security Risk Audit

### 3.1 Risk 4: Cross-Role Privilege Escalation
- **The Danger:** A registered customer using their Firebase Auth Phone token to invoke merchant-only endpoints (e.g., adding products or changing order statuses).
- **Mitigation:**
  - In `firestore.rules`, all mutations to `/shops/{shopId}` and `/shops/{shopId}/products/{productId}` require `request.auth.uid == shopId`.
  - In Cloud Functions, all shop management callables strictly verify that `request.auth.uid` matches the shop owner and that the shop document exists and is not suspended.

### 3.2 Risk 5: Client-Side Price & Quantity Tampering
- **The Danger:** A malicious customer modifying the Flutter HTTP payload during checkout to send `sellingPrice: 1` or negative quantities.
- **Mitigation:**
  - **Strict Server-Side Validation:** The client NEVER sends prices. The client sends only `{ productId, quantity }`.
  - The Cloud Function `placeShopOrder` re-fetches authoritative prices directly from `/shops/{shopId}/products/{productId}` in Firestore and computes the math on the server.

---

## 4. Performance & Firestore Read Amplification Risks

### 4.1 Risk 6: Uncontrolled Catalog Reads on Customer Home Screen
- **The Danger:** Querying all products for every shop directly on the homepage.
- **Impact:** If 50 local shops have 100 products each, a single homepage visit could trigger 5,000 document reads, exhausting the Firebase daily quota in minutes!
- **Mitigation:**
  1. The Customer Homepage queries **ONLY** `/demand_categories` (5 to 10 reads) and top nearby `/shops` (limit: 6 reads).
  2. Product documents are **NEVER** queried until the customer explicitly taps into a specific shop's Storefront.
  3. Storefront products are loaded using paginated queries (`limit: 20`) filtered by internal category.

---

## 5. Logistics & Operational Risks

### 5.1 Risk 7: Delivery Disagreements & Fraud
- **The Danger:** Customer claims delivery was never made; merchant claims it was delivered.
- **Mitigation:**
  - A secure **4-digit Delivery OTP** is generated upon order dispatch and visible only in the Customer App.
  - The merchant/delivery boy must ask the customer for this OTP to complete the order in `provider_app`.

### 5.2 Risk 8: Inventory Concurrency / Stock Overselling
- **The Danger:** Two customers placing simultaneous orders for the last available packet of rice.
- **Mitigation:**
  - For items with `trackInventory: true`, the Cloud Function uses a Firestore `transaction()` to decrement `stockQuantity`. If the stock drops below zero, the transaction rolls back cleanly with a friendly error: *"आइटम स्टॉक में उपलब्ध नहीं है।"*

---

## 6. Open Questions for Stakeholder Alignment

The following architectural questions should be aligned before Phase 1 implementation begins:

1. **Delivery OTP Verification:**
   - Should a 4-digit OTP be mandatory for all Home Delivery orders, or optional based on merchant choice?
   - *Recommendation:* Mandatory for orders above ₹500 to prevent fraud.

2. **Merchant Onboarding Flow:**
   - Can an existing Karigar (e.g. an Electrician who also owns a hardware shop) switch roles within one app, or should they register a separate shop account with a separate phone/email?
   - *Recommendation:* Keep separate accounts or allow a single account with an explicit role switcher in `provider_app`.

3. **Customer Online Payments:**
   - In Phase 1, should we launch with **Cash on Delivery (COD)** first to ensure rapid local merchant adoption, followed by Razorpay online payment in Phase 2?
   - *Recommendation:* Support COD from Day 1 as 90%+ of rural/semi-urban Bihar retail transactions are cash-based.

