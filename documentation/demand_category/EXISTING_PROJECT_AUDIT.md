# JAMUI SERVICES — EXISTING PROJECT AUDIT & SYSTEM ARCHITECTURE
**Document ID:** `EXISTING_PROJECT_AUDIT.md`  
**Version:** 1.0.0 (Phase 0 Pre-Implementation Baseline)  
**Status:** READ-ONLY COMPREHENSIVE REPOSITORY AUDIT  
**Date:** 2026-10-30  

---

## 1. Executive Overview & System Topology

Jamui Services (Apna Jamui) is an active, production-grade hyperlocal on-demand service marketplace operating in Bihar, India. The Customer Application is currently live on the Google Play Store.

The system is architected as a **tri-application ecosystem** sharing a single Firebase project (`jamui-services`) in the Mumbai, India region (`asia-south1`):

```
                        JAMUI SERVICES BACKEND ECOSYSTEM
                     ┌────────────────────────────────────┐
                     │     Firebase Project:              │
                     │     jamui-services (asia-south1)   │
                     └──────────────────┬─────────────────┘
                                        │
           ┌────────────────────────────┼────────────────────────────┐
           │                            │                            │
           ▼                            ▼                            ▼
┌──────────────────────┐     ┌──────────────────────┐     ┌──────────────────────┐
│     CUSTOMER APP     │     │     PROVIDER APP     │     │     ADMIN PANEL      │
│  Flutter Mobile APK  │     │  Flutter Web & App   │     │  Flutter Web Portal  │
│ (Live on Play Store) │     │ (Partner Management) │     │  (Super Admin / Ops) │
└──────────┬───────────┘     └──────────┬───────────┘     └──────────┬───────────┘
           │                            │                            │
           │ Phone OTP Auth             │ Email/Pass + Phone OTP     │ Email/Pass Auth
           │ Discovery & Leads          │ Dashboard & KYC            │ Complete Oversight
           │ Rating & Reviews           │ Subscription & Profile     │ Approvals & Audits
           │ Visiting Charge booking    │ Leads Management           │ Razorpay & Categories
           └────────────────────────────┼────────────────────────────┘
                                        │
                                        ▼
                     ┌────────────────────────────────────┐
                     │ SHARED CLOUD SERVICES:             │
                     │ • Cloud Firestore (NoSQL DB)       │
                     │ • Firebase Cloud Functions (v2)    │
                     │ • Razorpay Gateway (Subscriptions) │
                     │ • Cloudflare R2 (Object Storage)   │
                     │ • Cloud Messaging (FCM Alerts)     │
                     └────────────────────────────────────┘
```

---

## 2. Deep Dive: Three Client Applications

### 2.1 Customer Application (`customer_app`)
- **Primary Tech Stack:** Flutter, Dart, BLoC Pattern (`flutter_bloc`), Firebase Auth, Cloud Firestore, Geocoding.
- **Audience:** End-users in Jamui and surrounding areas.
- **Authentication:** Firebase Phone Number Authentication (`FirebaseAuth.instance.verifyPhoneNumber`) with SMS OTP. Optional guest access allows browsing with restricted actions.
- **Core Features:**
  1. **GPS & Location Engine:** `LocationBloc` retrieves GPS coordinates or user-selected Jamui areas (e.g., Jamui Bazaar, Sono, Jhajha, Sikandra, Chakai).
  2. **Discovery & Smart Search:** `DiscoveryBloc` queries `categories` and `providers`. Features `AISmartSearchBar` with natural language keywords.
  3. **Banner Section:** `SponsorBannerCarousel` displays promotional campaigns managed by admins in `banners` collection.
  4. **Category Grid:** Dynamic 5-column pastel card layout querying `categories` (priority sorted, active only).
  5. **Premium Services Showcase:** Dedicated carousel for high-value services (`premium_categories` such as Unisex Salon, AC Repair, Photography).
  6. **Provider Listing & Ranking:** Displays verified, active providers with visiting charge, experience years, distance calculation, call button, and WhatsApp direct contact.
  7. **Provider Details Page:** Full portfolio, gallery photos, itemized rate cards (`servicesWithPricing`), Google Maps directions, customer reviews, and social handles (Instagram, Facebook, Website).
  8. **Lead Generation:** Tapping "Call" or "WhatsApp" increments Firestore engagement counters (`totalCalls`, `totalWhatsAppClicks`) and logs a `leads` entry.

### 2.2 Provider Application (`provider_app`)
- **Primary Tech Stack:** Flutter (configured for both Android APK and Web hosting target `provider`).
- **Audience:** Local service technicians, karigars, and service businesses.
- **Authentication:** Firebase Email and Password for credentials, combined with Phone OTP verification during registration.
- **Core Features:**
  1. **Multi-Step Onboarding:** 5-step registration wizard collecting personal details, business info, primary category, sub-services, experience, address, GPS location, and visiting charges.
  2. **KYC & Account Status:** States include `draft`, `pendingReview`, `approved`, `rejected`, `suspended`, `blocked`.
  3. **Workspace Dashboard (`ProviderWorkspaceScreen`):**
     - Tab 1: Dashboard overview with active/inactive warnings, profile summary, quick links.
     - Tab 2: Leads Page (`LeadsPage`) showing customer contact requests (locked for unpaid providers).
     - Tab 3: Analytics Page (`AnalyticsPage`) tracking profile views, calls, and WhatsApp clicks.
     - Tab 4: Business Profile (`ProviderBusinessProfileScreen`) for editing rates, gallery, and working hours.
  4. **Subscription Management (`SubscriptionPage`):** Dynamic plan fetching matching the provider's `resolvedPlanTier` ('normal' vs 'premium'). Integrates Razorpay checkout, real-time snapshot sync, and pull-to-refresh.

### 2.3 Admin Panel (`admin_panel`)
- **Primary Tech Stack:** Flutter Web (hosted on Firebase Hosting target `admin`).
- **Audience:** Internal Jamui Services operations and management team.
- **Authentication:** Email & Password strictly validated against Firestore `admin_users` collection. Inactive or suspended admin accounts are blocked at both UI and Cloud Function layers.
- **Core Modules:**
  1. `DashboardPage`: Business KPIs, provider counts, revenue, and pending approvals.
  2. `ProvidersPage`: Full provider directory, KYC review, document verification, status toggling (active/suspend/delete), and **Edit Category** action with atomic audit logging.
  3. `CategoriesPage` & `ServicesPage`: Management of normal service categories and itemized service catalogs.
  4. `SubscriptionsPage` & `PaymentsPage`: Manual payment verification, subscription reconciliation, and transaction audits.
  5. `BannersManagementPage`: Sponsor banner upload, scheduling, and link assignment.
  6. `AuditLogsPage`: Read-only chronological trail of admin actions.

---

## 3. Existing Firestore Schema & Data Structure

```
FIRESTORE ROOT COLLECTIONS
├── categories/                     # Public normal service categories
│   └── {categoryId}/               # e.g., 'electrician', 'plumber'
├── premium_categories/             # High-tier service categories
│   └── {premiumCatId}/             # e.g., 'unisex_salon'
├── services/                       # Sub-services catalog
│   └── {serviceId}/                # e.g., 'switchboard_repair'
├── providers/                      # Service provider profiles
│   └── {providerId}/               # Provider profile document
├── users/ (or customers/)          # Registered customer profiles
│   └── {userId}/                   # Phone auth user profile
├── leads/                          # Inquiries & engagement logs
│   └── {leadId}/                   # Customer-provider lead record
├── banners/                        # Promotional home banners
│   └── {bannerId}/                 # Carousel banner item
├── subscription_plans/             # Canonical plan catalog
│   └── {planId}/                   # Plan pricing, tier, limits
├── subscription_orders/            # Razorpay orders and transactions
│   └── {orderId}/                  # Order verification record
├── admin_users/                    # Authorized administrator accounts
│   └── {adminUid}/                 # Admin role, status, email
├── audit_logs/                     # Immutable admin security logs
│   └── {logId}/                    # Write-only security trail
└── app_config/                     # System configs (payment, versions)
    ├── payment                     # Public Razorpay Key ID
    └── payment_secrets             # Secure backend secrets
```

### 3.1 Key Entity: `providers/{providerId}` Fields
```typescript
interface ProviderProfile {
  id: string;                          // Firebase Auth UID
  fullName: string;                    // Karigar / Owner name
  businessName: string;                // Shop / Agency / Display name
  phoneNumber: string;                 // Verified contact number
  email: string;                       // Auth email
  primaryCategoryId: string;           // Canonical category ID (e.g. 'electrician')
  primaryCategoryTitle: string;        // Localized title (e.g. 'इलेक्ट्रीशियन')
  selectedCategoryId: string;          // Selected ID
  selectedCategoryIds: string[];       // Array of category IDs
  categoryType: 'general' | 'premium'; // Authoritative tier
  isPremiumCategory: boolean;          // Flag for premium classification
  isPremiumCategoryEligible: boolean;  // Plan tier resolver flag
  isPremiumEligible: boolean;          // Set ONLY after verified paid subscription
  visitingCharge: number;              // Inspection/visiting fee in INR
  experienceYears: number;             // Years in profession
  jamuiArea: string;                   // Local town / block name
  fullAddress: string;                 // Detailed address
  latitude: number;                    // GPS latitude
  longitude: number;                   // GPS longitude
  serviceRadiusKm: number;             // Service coverage radius
  profileImageUrl: string;             // Owner photo (R2 or storage URL)
  businessImageUrl: string;            // Workplace / shop photo
  galleryImages: string[];             // Showcase photos
  servicesWithPricing: Array<{         // Itemized services
    name: string;
    price: number;
    description?: string;
  }>;
  status: 'draft' | 'pendingReview' | 'approved' | 'rejected' | 'suspended' | 'blocked';
  kycStatus: 'notSubmitted' | 'pendingReview' | 'approved' | 'rejected';
  isVerified: boolean;                 // Admin verified flag
  isActive: boolean;                   // Admin soft-toggle
  isDeleted: boolean;                  // Soft delete flag
  isAvailable: boolean;                // Provider online/offline toggle
  paymentVerified: boolean;            // Subscription payment status
  isSubscriptionActive: boolean;       // Active subscription validity
  subscriptionPlan: string;            // Current plan ID
  subscriptionExpiry: Timestamp;       // Expiry timestamp
  totalViews: number;                  // Profile view counter
  totalCalls: number;                  // Phone call counter
  totalWhatsAppClicks: number;         // WhatsApp click counter
  rating: number;                      // Average rating (1.0 to 5.0)
  ratingCount: number;                 // Number of ratings
}
```

---

## 4. Current Business Rules & Invariants

### 4.1 Customer App Provider Visibility Rule (`isApprovedAndLive`)
A provider is displayed in the Customer App search and directory **IF AND ONLY IF** all 7 conditions are met:
1. `isDeleted !== true` (Record is not soft-deleted).
2. `isActive !== false` (Provider is not deactivated by Admin).
3. `status === 'approved'` OR `isVerified === true` OR `kycStatus === 'approved'` (Explicit admin approval).
4. `status` is not in `['rejected', 'suspended', 'blocked']`.
5. `isAvailable === true` (Provider has toggled status to Online).
6. `paymentVerified === true` AND `isSubscriptionActive === true` (Subscription payment verified by server).
7. `subscriptionExpiry` is in the future (`> DateTime.now()`).

### 4.2 Normal vs Premium Category Separation
- **Normal Categories:** Standard home service categories (Carpenter, Electrician, Plumber, Painter, Mason). Listed in standard 5-column grid. Standard subscription plans apply.
- **Premium Categories:** Specialized business categories (e.g., Unisex Salon, Bridal Studio, AC Technician). Prominently showcased in dedicated carousel. Require premium subscription plan tier to activate visibility.
- **Authoritative Resolution:** Client cannot set `isPremiumEligible: true`. The server resolves eligibility strictly from canonical `premium_categories` collection and verified payment orders.

### 4.3 Payment & Subscription Invariants
- Subscriptions are never auto-activated by profile edits or admin category changes.
- Old transactions or payments cannot be transferred to a new plan tier.
- Double-payment concurrency locks exist in `functions/index.js` to prevent duplicate active orders.

### 4.4 Cloudflare R2 Object Storage Infrastructure
- Image storage is handled via Cloudflare R2 (`functions/r2_storage_upload_handler.js`) using AWS S3-compatible SigV4 presigned PUT URLs.
- Two production buckets are configured:
  - `jamui-services-public-prod`: For category icons, banners, provider profiles, and showcase galleries.
  - `jamui-services-private-prod`: For sensitive internal documents.
- Strict upload caps: Max 8MB per file, allowed MIME types: JPEG, PNG, WebP, PDF.
- Storage usage is tracked server-side in `storageUsage` map on provider records.

---

## 5. Summary of Dependencies Across All Three Apps

| Component | Customer App | Provider App | Admin Panel | Cloud Functions |
| :--- | :---: | :---: | :---: | :---: |
| **Firebase Auth** | Phone OTP | Email/Pass + OTP | Email/Pass | Token verification |
| **Firestore `categories`** | Read (cached) | Read (select) | CRUD | Canonical check |
| **Firestore `providers`** | Read (live only)| Read/Write (own) | Read/Write (all)| Atomic updates |
| **Firestore `leads`** | Create | Read (own) | Read (all) | Counter updates |
| **Firestore `banners`** | Read (active) | None | CRUD | None |
| **Razorpay SDK** | None | Client Checkout | None | Webhook & Verify |
| **Cloudflare R2** | Read (CDN URLs)| Presigned PUT | Presigned PUT | URL Signer |

**Audit Conclusion:** The existing service marketplace is robust, tightly coupled around verified payment subscriptions, and guarded by comprehensive server-side checks. Any new e-commerce vertical must be completely isolated to avoid destabilizing this foundation.

