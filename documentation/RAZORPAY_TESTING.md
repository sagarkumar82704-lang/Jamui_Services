# RAZORPAY TEST MODE & QA VERIFICATION

## 1. Test Cards and UPI VPA
When testing payments in **Test Mode**:
- **UPI ID**: `success@razorpay` (Simulates instant success)
- **UPI ID (Failure)**: `failure@razorpay` (Simulates failed payment)
- **Test Cards**: Any standard Razorpay test card from [Razorpay Docs](https://razorpay.com/docs/payments/payments/test-card-details/) (e.g., `4111 1111 1111 1111`, expiry `12/30`, CVV `123`, OTP `123456`).

## 2. Test Cases Matrix

| Test ID | Test Scenario | Input / Action | Expected Result | Status |
|---|---|---|---|---|
| **TC-01** | Successful Plan Purchase | Select Pro Plan (₹399), Complete Test Payment | Server verifies signature, sets `isSubscriptionActive: true` | **PASS** |
| **TC-02** | Payment Failure | Trigger failure with `failure@razorpay` | Subscription remains inactive, shows clear error message | **PASS** |
| **TC-03** | User Cancelled Payment | Back button during Razorpay modal | Order remains pending, no subscription change | **PASS** |
| **TC-04** | Client-Side Amount Tampering | Modified client sends `amount = 1` | Server ignores client amount and charges plan price | **PASS** |
| **TC-05** | Inactive Plan Purchase | Provider requests inactive `plan_id` | Server returns HTTP 404/400 rejected | **PASS** |
| **TC-06** | Duplicate Verification Attack | Replay verification request twice | Idempotent response, no double duration extension | **PASS** |
| **TC-07** | Invalid HMAC Signature | Fake signature string in verification | Server rejects with HTTP 400 | **PASS** |
