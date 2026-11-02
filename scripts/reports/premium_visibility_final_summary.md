# JAMUI SERVICES — PROVIDER DIRECTORY AUDIT & PREMIUM VISIBILITY REPORT
**Generated at:** 2026-10-29T14:31:19.784Z
**Project ID:** jamui-services
**Total Audited Providers:** 75

---

## 1. Executive Summary Table
| Metric | Count | Description |
| :--- | :--- | :--- |
| **Total Audited Providers** | **75** | All providers fetched via full pagination |
| **Visible in Premium Category** | **1** | Approved, paid, active, unexpired, and explicitly premium-eligible |
| **Hidden from Premium Category** | **64** | Normal plans, inactive subscriptions, unapproved, or expired |
| **Review Required** | **10** | Missing/conflicting metadata or missing isPremiumEligible on doc |
| **Data Access Failures** | **0** | All pages and collections fetched successfully |

---

## 2. Special Audit: Srusu Unisex (Provider ID: uIT6hYxtt3PuWW9rBx9CIWl36Op1)
- **Business Name:** srusu unisex
- **Plan Name:** Basic Premium (`1nhifE6GzhmgYh28mxZd`)
- **Plan Tier:** premium (`isPremiumCategoryEligible: true`)
- **Live Subscription Status:** Active (Expires: `2026-10-30T06:51:29.325Z`)
- **Payment Verification:** Verified (`paymentVerified: true`)
- **Current Document State in Firestore:**
  - `isPremiumEligible`: **MISSING (undefined)**
  - `planLimits`: **MISSING (undefined)**
- **Customer App Evaluation:** Fails closed to `false` -> **HIDDEN**
- **Classification:** **REVIEW_REQUIRED**
- **Exact Remediation:** Run dry-run verified backfill (`node scripts/backfill_premium_eligibility.js --execute`) or re-approve from Admin Panel to populate `isPremiumEligible: true`.

---

## 3. Review Required Providers (10)
1. **massager** (`7Nnt26TaIuZTMdRUdbCvXONiaA82`): MISSING_PLAN: Linked plan 'free_trial' does not exist in subscription_plans collection.
2. **electric** (`BqkRk7wYJLhN9MvgZXq8cnQ8PNc2`): MISSING_PLAN: Linked plan 'free_trial' does not exist in subscription_plans collection.
3. **rohan bike** (`DTLQWLAUmxgvqX2eoR3z11mMTxB2`): MISSING_PLAN: Linked plan 'free_trial' does not exist in subscription_plans collection.
4. **SAGAR ELECTRIC AND ENTERPRISE** (`ISKJOUbHkyZP33gVmSrVkTQOgwf1`): MISSING_PLAN: Linked plan 'free_trial' does not exist in subscription_plans collection.
5. **sagar electric** (`acekQmXbUwcJfYCKAUgwLR3Wfry1`): MISSING_PLAN: Linked plan 'free_trial' does not exist in subscription_plans collection.
6. **gh5tuyfd6h** (`djMa8aGhKhRIiDnppHKRZOEHUEf1`): MISSING_PLAN: Linked plan 'free_trial' does not exist in subscription_plans collection.
7. **RAHUL PLUMBERING** (`gkEAGSXKBPOVJiRi6RrZWkdllRj1`): MISSING_PLAN: Linked plan 'free_trial' does not exist in subscription_plans collection.
8. **MAHESHWARI & CO.(GST INCOME TAX| E -TENDER SERVICE)** (`u4lFBZlRW8R5fXyxd3ZPYFkm7193`): MISSING_PLAN: Linked plan 'free_trial' does not exist in subscription_plans collection.
9. **Sagar Kumar Singh** (`v8gT3ByQnfaPb9MzNtXfZz8wZmA3`): MISSING_PLAN: Linked plan 'free_trial' does not exist in subscription_plans collection.
10. **anshu** (`z0sRXTWdwmbcTH5d0nkAoTpMcOA2`): MISSING_PLAN: Linked plan 'free_trial' does not exist in subscription_plans collection.

---

## 4. Generated Artifacts
- Visible Providers: `D:\jamui_service\scripts\reports\premium_providers_visible.csv` (1 rows)
- Hidden Providers: `D:\jamui_service\scripts\reports\premium_providers_hidden.csv` (64 rows)
- Review Required Providers: `D:\jamui_service\scripts\reports\premium_providers_review_required.csv` (10 rows)
- Full Audit Report: `D:\jamui_service\scripts\providers_report.csv` (75 rows)
