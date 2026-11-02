# JAMUI SERVICES — PAYMENT ARCHITECTURE DOCUMENTATION

## 1. Overview
This document describes the end-to-end payment architecture for provider subscriptions and services in APNA_JAMUI / Jamui Services.

```mermaid
sequenceDiagram
    autonumber
    actor Provider as Provider App (Flutter)
    participant Server as FastAPI / Cloud Backend
    participant DB as Firestore (subscription_plans, payments, subscriptions)
    participant RZP as Razorpay Gateway (API & Webhook)

    Provider->>Server: POST /api/provider/subscription/create-order { planId, providerId }
    Server->>DB: Fetch authoritative plan price & status (subscription_plans)
    Server->>RZP: POST /v1/orders { amount: priceInPaise, currency: "INR" }
    RZP-->>Server: { orderId: "order_xyz" }
    Server->>DB: Save pending payment doc { orderId, status: "created", amount }
    Server-->>Provider: { orderId: "order_xyz", amount: priceInPaise, keyId: "rzp_test_..." }
    Note over Provider: Provider opens Razorpay Checkout SDK
    Provider->>RZP: Payment processing (UPI / Cards / NetBanking)
    RZP-->>Provider: PaymentSuccessResponse { orderId, paymentId, signature }
    Provider->>Server: POST /api/provider/subscription/verify-payment { orderId, paymentId, signature }
    Server->>Server: Verify HMAC-SHA256 signature
    Server->>DB: Atomically update payment (status: "success") & provider (isSubscriptionActive: true)
    Server-->>Provider: { success: true, expiryDate: "..." }
```

## 2. Core Architectural Principles
1. **Never Trust the Client for Financial Data:** The Flutter application sends only `planId` and `providerId`. Amount calculation is 100% authoritative and executed exclusively on the server.
2. **Server-Side Order Creation:** Orders are generated via Razorpay API by the backend. The client cannot forge order IDs or modify prices.
3. **Cryptographic Verification:** Every completed transaction is verified using HMAC-SHA256 server-side before subscription benefits are granted.
4. **Zero Client-Side Secrets:** Only the public Razorpay Key ID (`RAZORPAY_KEY_ID`) is shared with clients. The `RAZORPAY_KEY_SECRET` and `RAZORPAY_WEBHOOK_SECRET` are never bundled in Flutter APKs or web builds.
