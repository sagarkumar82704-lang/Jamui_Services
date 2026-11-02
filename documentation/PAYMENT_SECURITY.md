# PAYMENT & FINANCIAL SECURITY GUIDELINES

## 1. Zero Trust Client Security Model
- **Amount Tampering Defense**: The Flutter client never dictates the payment amount. All amounts are fetched from database plans on the backend.
- **Order ID Verification**: Payments can only be verified against orders created by the server.
- **Cryptographic Signature Validation**: HMAC-SHA256 ensures only genuine Razorpay payments trigger activation.
- **Idempotency**: Duplicate payment callbacks or replayed requests cannot generate duplicate subscriptions.

## 2. Secrets Management
- `RAZORPAY_KEY_SECRET` and `RAZORPAY_WEBHOOK_SECRET` are stored in environment variables / GCP Secret Manager.
- Flutter source code, Git repositories, and compiled client bundles contain **only public identifiers** (`RAZORPAY_KEY_ID`).

## 3. Database Integrity & Firestore Rules
- Providers can only view their own payment receipts and subscriptions.
- Direct client writes to `payments` status or `subscriptions` are strictly restricted by Firestore security rules.
