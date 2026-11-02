# PAYMENT ERROR HANDLING & RECOVERY WORKFLOWS

## 1. Common Payment Error Scenarios & Resolution

| Scenario | Symptom | System Behavior & Remediation |
|---|---|---|
| **Network Timeout During Checkout** | Money deducted from bank, but Flutter app closed | Webhook receives `payment.captured` from Razorpay and automatically activates subscription on server. |
| **User Cancelled Payment** | Provider closes Razorpay sheet | Flutter app catches `EVENT_PAYMENT_ERROR`, displays informative message, and allows one-click retry. |
| **Invalid Signature** | Cryptographic mismatch | Backend rejects verification with HTTP 400. Logged as security alert without secrets. |
| **Backend Unreachable** | Flutter cannot reach server | App falls back to secure direct Firestore record creation and alerts admin for reconciliation. |
| **Duplicate Payment Callback** | Webhook and Flutter callback arrive simultaneously | Idempotent Firestore batch update checks existing status to avoid duplicate extension. |

## 2. Admin Reconciliation Workflow
- Admin Panel > **Payments** displays all transaction logs from `payments` collection.
- Discrepancies can be reviewed and cross-referenced with Razorpay Payment IDs in real-time.
