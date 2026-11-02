# RAZORPAY PRODUCTION MIGRATION CHECKLIST

Before switching from **Test Mode** to **Live Production Mode**, verify each item:

- [ ] **Live KYC Completed**: Complete merchant onboarding and bank account verification on Razorpay Dashboard.
- [ ] **Live API Keys Generated**: Generate Live Key ID (`rzp_live_...`) and Live Key Secret from Razorpay Dashboard (**Live Mode**).
- [ ] **Environment Variables Updated**:
  - `RAZORPAY_MODE=live`
  - `RAZORPAY_KEY_ID=rzp_live_...`
  - `RAZORPAY_KEY_SECRET=<production_secret>`
  - `RAZORPAY_WEBHOOK_SECRET=<production_webhook_secret>`
- [ ] **Production Webhook Registered**: Add Live Webhook URL pointing to production backend with HTTPS (`https://api.apnajamui.com/api/provider/subscription/webhook`).
- [ ] **No Secrets in Source Code**: Ensure `.env` is listed in `.gitignore` and no secrets are bundled in mobile app APKs / web bundles.
- [ ] **HTTPS Enforced**: All backend API endpoints communicate exclusively over TLS 1.3 / HTTPS.
- [ ] **Firestore Security Rules Active**: Verify Firestore security rules prevent unauthorized direct client writes to subscriptions or verified payments.
- [ ] **Audit Logs Verification**: Confirm admin changes to plans and financial records are logged to `audit_logs`.
- [ ] **Small Live Transaction Test**: Perform a live ₹1 or minimum plan transaction using a real UPI ID/card to verify end-to-end settlement.
