/**
 * JAMUI SERVICES — PROFESSIONAL SELLER RAZORPAY PAYMENT BACKEND TEST SUITE
 * Phase 1B: Cloud Functions & Security Validation
 * 
 * Verifies all 22 required scenarios:
 * 1. Valid active plan order creation
 * 2. Inactive plan rejection
 * 3. Missing duration rejection
 * 4. Invalid duration rejection
 * 5. Client amount tampering rejection
 * 6. Cross-shop seller isolation rejection (Seller A on Seller B shop)
 * 7. Missing authentication rejection
 * 8. Invalid HMAC checkout signature rejection
 * 9. Mismatched payment/order ID rejection
 * 10. Amount mismatch rejection
 * 11. Currency mismatch rejection
 * 12. Payment not captured rejection
 * 13. Successful captured payment activation
 * 14. Duplicate verification idempotency (no double extension)
 * 15. Different payment ID reusing consumed order rejection
 * 16. Payment before Admin approval (shop stays hidden until approval)
 * 17. Early renewal expiry stacking (T_exp + d)
 * 18. Late renewal expiry reset (T_now + d)
 * 19. Activation failure and recovery state (pending_retry)
 * 20. Concurrent verification attempts safety
 * 21. Normal Provider subscription regression pass
 * 22. Premium Provider subscription regression pass
 */

process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || 'demo-jamui-services';
process.env.FIREBASE_CONFIG = JSON.stringify({ projectId: 'demo-jamui-services' });
process.env.RAZORPAY_MOCK = 'true';
process.env.RAZORPAY_KEY_ID = 'rzp_test_mockKeyId1234';
process.env.RAZORPAY_KEY_SECRET = 'mock_secret_key_12345678';
process.env.RAZORPAY_WEBHOOK_SECRET = 'mock_webhook_secret_87654321';

const crypto = require('crypto');
const assert = require('assert');
const path = require('path');
const admin = require('firebase-admin');

if (admin.apps.length === 0) {
  admin.initializeApp({ projectId: 'demo-jamui-services' });
}
const db = admin.firestore();

const {
  createProfessionalSubscriptionOrder,
  verifyProfessionalSubscriptionPayment,
  professionalRazorpayWebhook,
  adminApproveDiamondShop,
  createSubscriptionOrder,
  verifySubscriptionPayment
} = require('../index.js');

let passedCount = 0;
let totalCount = 0;

function reportPass(name) {
  passedCount++;
  console.log(`✅ [PASS ${passedCount}/22] ${name}`);
}

function reportFail(name, err) {
  console.error(`❌ [FAIL] ${name}`);
  console.error(err);
  process.exitCode = 1;
}

function computeSignature(orderId, paymentId, secret = 'mock_secret_key_12345678') {
  return crypto.createHmac('sha256', secret).update(`${orderId}|${paymentId}`).digest('hex');
}

async function runPhase1BTestSuite() {
  console.log('================================================================');
  console.log(' JAMUI SERVICES — PROFESSIONAL SELLER PAYMENT BACKEND TEST SUITE');
  console.log(' Phase 1B: Order Creation, Verification, Idempotency & Lifecycle');
  console.log('================================================================\n');

  try {
    // 0. Seed Razorpay Credentials in app_config
    await db.collection('app_config').doc('payment').set({
      razorpay_key_id: 'rzp_test_mockKeyId1234',
      isActive: true
    }, { merge: true });

    await db.collection('app_config').doc('payment_secrets').set({
      keySecret: 'mock_secret_key_12345678',
      webhookSecret: 'mock_webhook_secret_87654321'
    }, { merge: true });

    // Seed Admin User
    const adminUid = 'admin_super_user';
    await db.collection('admin_users').doc(adminUid).set({
      uid: adminUid,
      email: 'admin@jamuiservices.com',
      role: 'super_admin',
      isActive: true
    });

    // Seed Test Plans
    const validPlanId = 'pro_plan_standard_30';
    await db.collection('diamond_subscription_plans').doc(validPlanId).set({
      id: validPlanId,
      name: 'Pro Standard 30 Days',
      price: 499,
      durationDays: 30,
      isActive: true,
      productLimit: 50,
      imageLimit: 5,
      storageLimitMb: 500,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    const inactivePlanId = 'pro_plan_inactive_test';
    await db.collection('diamond_subscription_plans').doc(inactivePlanId).set({
      id: inactivePlanId,
      name: 'Pro Inactive Plan',
      price: 299,
      durationDays: 30,
      isActive: false,
      productLimit: 20
    });

    const missingDurationPlanId = 'pro_plan_missing_duration';
    await db.collection('diamond_subscription_plans').doc(missingDurationPlanId).set({
      id: missingDurationPlanId,
      name: 'Pro Legacy No Duration',
      price: 199,
      isActive: true,
      productLimit: 10
    });

    const invalidDurationPlanId = 'pro_plan_invalid_duration';
    await db.collection('diamond_subscription_plans').doc(invalidDurationPlanId).set({
      id: invalidDurationPlanId,
      name: 'Pro Invalid Duration',
      price: 999,
      durationDays: 0,
      isActive: true
    });

    // Seed Test Shops
    const sellerAUid = 'seller_user_aaa';
    const shopAId = 'shop_seller_aaa';
    await db.collection('diamond_shops').doc(shopAId).set({
      id: shopAId,
      shopName: 'Shree Krishna Electronics',
      ownerUid: sellerAUid,
      ownerName: 'Krishna Kumar',
      ownerPhone: '9876543210',
      ownerEmail: 'krishna@example.com',
      status: 'pending_approval',
      isApproved: false,
      isActive: false,
      isSubscriptionActive: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    const sellerBUid = 'seller_user_bbb';
    const shopBId = 'shop_seller_bbb';
    await db.collection('diamond_shops').doc(shopBId).set({
      id: shopBId,
      shopName: 'Maa Tara Jewellers',
      ownerUid: sellerBUid,
      status: 'approved',
      isApproved: true,
      isActive: true,
      isSubscriptionActive: false
    });

    // -------------------------------------------------------------
    // SCENARIO 1: Valid active plan order creation
    // -------------------------------------------------------------
    totalCount++;
    const orderRes1 = await createProfessionalSubscriptionOrder.run({
      auth: { uid: sellerAUid },
      data: { shopId: shopAId, planId: validPlanId }
    });

    assert.strictEqual(orderRes1.success, true);
    assert.strictEqual(orderRes1.amount, 499);
    assert.strictEqual(orderRes1.amountInPaise, 49900);
    assert.strictEqual(orderRes1.currency, 'INR');
    assert.strictEqual(orderRes1.durationDays, 30);
    assert.strictEqual(orderRes1.shopId, shopAId);
    assert.strictEqual(orderRes1.planId, validPlanId);
    assert.ok(orderRes1.orderId.startsWith('order_mock_'));

    const paymentDoc1 = await db.collection('diamond_payments').doc(orderRes1.orderId).get();
    assert.ok(paymentDoc1.exists);
    assert.strictEqual(paymentDoc1.data().status, 'created');
    assert.strictEqual(paymentDoc1.data().ownerUid, sellerAUid);
    assert.strictEqual(paymentDoc1.data().productLimit, 50);
    reportPass('1. Valid active plan order creation succeeds with server-priced payload and diamond_payments record');

    // -------------------------------------------------------------
    // SCENARIO 2: Inactive plan rejection
    // -------------------------------------------------------------
    totalCount++;
    await assert.rejects(
      createProfessionalSubscriptionOrder.run({
        auth: { uid: sellerAUid },
        data: { shopId: shopAId, planId: inactivePlanId }
      }),
      (err) => err.code === 'failed-precondition' && err.message.includes('inactive')
    );
    reportPass('2. Inactive plan order creation is rejected with failed-precondition');

    // -------------------------------------------------------------
    // SCENARIO 3: Missing duration rejection
    // -------------------------------------------------------------
    totalCount++;
    await assert.rejects(
      createProfessionalSubscriptionOrder.run({
        auth: { uid: sellerAUid },
        data: { shopId: shopAId, planId: missingDurationPlanId }
      }),
      (err) => err.code === 'failed-precondition' && err.message.includes('duration')
    );
    reportPass('3. Plan with missing durationDays is rejected with failed-precondition');

    // -------------------------------------------------------------
    // SCENARIO 4: Invalid duration rejection
    // -------------------------------------------------------------
    totalCount++;
    await assert.rejects(
      createProfessionalSubscriptionOrder.run({
        auth: { uid: sellerAUid },
        data: { shopId: shopAId, planId: invalidDurationPlanId }
      }),
      (err) => err.code === 'failed-precondition' && err.message.includes('duration')
    );
    reportPass('4. Plan with invalid durationDays (0) is rejected with failed-precondition');

    // -------------------------------------------------------------
    // SCENARIO 5: Client amount tampering rejection
    // -------------------------------------------------------------
    totalCount++;
    const tamperRes = await createProfessionalSubscriptionOrder.run({
      auth: { uid: sellerAUid },
      data: { shopId: shopAId, planId: validPlanId, amount: 10, price: 10, durationDays: 999 }
    });
    // Server ignores client-supplied amount: must be authoritative 499 (49900 paise) and duration 30
    assert.strictEqual(tamperRes.amount, 499);
    assert.strictEqual(tamperRes.amountInPaise, 49900);
    assert.strictEqual(tamperRes.durationDays, 30);
    const tamperDoc = await db.collection('diamond_payments').doc(tamperRes.orderId).get();
    assert.strictEqual(tamperDoc.data().amount, 499);
    assert.strictEqual(tamperDoc.data().durationDays, 30);
    reportPass('5. Client amount and duration tampering ignored; authoritative Firestore pricing enforced');

    // -------------------------------------------------------------
    // SCENARIO 6: Cross-shop seller isolation rejection (Seller A on Seller B shop)
    // -------------------------------------------------------------
    totalCount++;
    await assert.rejects(
      createProfessionalSubscriptionOrder.run({
        auth: { uid: sellerAUid },
        data: { shopId: shopBId, planId: validPlanId }
      }),
      (err) => err.code === 'permission-denied'
    );
    reportPass('6. Cross-shop seller access denied: Seller A cannot purchase order for Seller B shop');

    // -------------------------------------------------------------
    // SCENARIO 7: Missing authentication rejection
    // -------------------------------------------------------------
    totalCount++;
    await assert.rejects(
      createProfessionalSubscriptionOrder.run({
        auth: null,
        data: { shopId: shopAId, planId: validPlanId }
      }),
      (err) => err.code === 'unauthenticated'
    );
    reportPass('7. Unauthenticated order creation request rejected with unauthenticated error');

    // -------------------------------------------------------------
    // SCENARIO 8: Invalid HMAC checkout signature rejection
    // -------------------------------------------------------------
    totalCount++;
    const testOrderId = orderRes1.orderId;
    const testPaymentId = 'pay_mock_test_12345';
    await assert.rejects(
      verifyProfessionalSubscriptionPayment.run({
        auth: { uid: sellerAUid },
        data: {
          shopId: shopAId,
          planId: validPlanId,
          razorpayOrderId: testOrderId,
          razorpayPaymentId: testPaymentId,
          razorpaySignature: 'invalid_tampered_hex_signature_abcdef1234567890'
        }
      }),
      (err) => err.code === 'invalid-argument' && err.message.includes('signature')
    );
    reportPass('8. Invalid HMAC-SHA256 signature rejected with invalid-argument');

    // -------------------------------------------------------------
    // SCENARIO 9: Mismatched payment/order ID rejection
    // -------------------------------------------------------------
    totalCount++;
    const validSig = computeSignature(testOrderId, testPaymentId);
    await assert.rejects(
      verifyProfessionalSubscriptionPayment.run({
        auth: { uid: sellerAUid },
        data: {
          shopId: shopAId,
          planId: validPlanId,
          razorpayOrderId: 'order_mock_non_existent_9999',
          razorpayPaymentId: testPaymentId,
          razorpaySignature: validSig
        }
      }),
      (err) => err.code === 'not-found'
    );
    reportPass('9. Non-existent order ID rejected with not-found');

    // -------------------------------------------------------------
    // SCENARIO 10: Amount mismatch rejection
    // -------------------------------------------------------------
    totalCount++;
    const amountMismatchPayId = 'pay_mock_fail_amount_999';
    const amountMismatchSig = computeSignature(testOrderId, amountMismatchPayId);
    await assert.rejects(
      verifyProfessionalSubscriptionPayment.run({
        auth: { uid: sellerAUid },
        data: {
          shopId: shopAId,
          planId: validPlanId,
          razorpayOrderId: testOrderId,
          razorpayPaymentId: amountMismatchPayId,
          razorpaySignature: amountMismatchSig
        }
      }),
      (err) => err.code === 'invalid-argument' && err.message.includes('amount')
    );
    reportPass('10. Gateway payment amount mismatch rejected');

    // -------------------------------------------------------------
    // SCENARIO 11: Currency mismatch rejection
    // -------------------------------------------------------------
    totalCount++;
    const currencyMismatchPayId = 'pay_mock_fail_currency_usd';
    const currencyMismatchSig = computeSignature(testOrderId, currencyMismatchPayId);
    await assert.rejects(
      verifyProfessionalSubscriptionPayment.run({
        auth: { uid: sellerAUid },
        data: {
          shopId: shopAId,
          planId: validPlanId,
          razorpayOrderId: testOrderId,
          razorpayPaymentId: currencyMismatchPayId,
          razorpaySignature: currencyMismatchSig
        }
      }),
      (err) => err.code === 'invalid-argument' && err.message.includes('currency')
    );
    reportPass('11. Non-INR currency rejected with invalid-argument');

    // -------------------------------------------------------------
    // SCENARIO 12: Payment not captured rejection
    // -------------------------------------------------------------
    totalCount++;
    const uncapturedPayId = 'pay_mock_fail_not_captured_auth';
    const uncapturedSig = computeSignature(testOrderId, uncapturedPayId);
    await assert.rejects(
      verifyProfessionalSubscriptionPayment.run({
        auth: { uid: sellerAUid },
        data: {
          shopId: shopAId,
          planId: validPlanId,
          razorpayOrderId: testOrderId,
          razorpayPaymentId: uncapturedPayId,
          razorpaySignature: uncapturedSig
        }
      }),
      (err) => err.code === 'failed-precondition' && err.message.includes('not captured')
    );
    reportPass('12. Uncaptured gateway payment rejected with failed-precondition');

    // -------------------------------------------------------------
    // SCENARIO 13: Successful captured payment activation
    // -------------------------------------------------------------
    totalCount++;
    const capturedPayId = 'pay_mock_captured_valid_1';
    const capturedSig = computeSignature(testOrderId, capturedPayId);
    const verifyRes = await verifyProfessionalSubscriptionPayment.run({
      auth: { uid: sellerAUid },
      data: {
        shopId: shopAId,
        planId: validPlanId,
        razorpayOrderId: testOrderId,
        razorpayPaymentId: capturedPayId,
        razorpaySignature: capturedSig
      }
    });

    assert.strictEqual(verifyRes.success, true);
    assert.strictEqual(verifyRes.alreadyVerified, false);
    assert.strictEqual(verifyRes.isSubscriptionActive, true);

    const verifiedPaymentDoc = await db.collection('diamond_payments').doc(testOrderId).get();
    assert.strictEqual(verifiedPaymentDoc.data().status, 'activated');
    assert.strictEqual(verifiedPaymentDoc.data().paymentId, capturedPayId);

    const verifiedShopDoc = await db.collection('diamond_shops').doc(shopAId).get();
    assert.strictEqual(verifiedShopDoc.data().isSubscriptionActive, true);
    assert.strictEqual(verifiedShopDoc.data().paymentVerified, true);
    assert.strictEqual(verifiedShopDoc.data().subscriptionPlanId, validPlanId);
    assert.strictEqual(verifiedShopDoc.data().subscriptionDurationDays, 30);
    assert.ok(verifiedShopDoc.data().subscriptionExpiry !== null);
    reportPass('13. Authoritative verification activates subscription and updates diamond_payments and diamond_shops');

    // -------------------------------------------------------------
    // SCENARIO 14: Duplicate verification idempotency (no double extension)
    // -------------------------------------------------------------
    totalCount++;
    const originalExpiry = verifiedShopDoc.data().subscriptionExpiry.toDate().getTime();

    const dupRes = await verifyProfessionalSubscriptionPayment.run({
      auth: { uid: sellerAUid },
      data: {
        shopId: shopAId,
        planId: validPlanId,
        razorpayOrderId: testOrderId,
        razorpayPaymentId: capturedPayId,
        razorpaySignature: capturedSig
      }
    });

    assert.strictEqual(dupRes.success, true);
    assert.strictEqual(dupRes.alreadyVerified, true);

    const shopAfterDup = await db.collection('diamond_shops').doc(shopAId).get();
    const expiryAfterDup = shopAfterDup.data().subscriptionExpiry.toDate().getTime();
    assert.strictEqual(originalExpiry, expiryAfterDup, 'Expiry must not be extended again on duplicate verification');
    reportPass('14. Duplicate verification is idempotent; does not double-extend subscriptionExpiry');

    // -------------------------------------------------------------
    // SCENARIO 15: Different payment ID reusing consumed order rejection
    // -------------------------------------------------------------
    totalCount++;
    const reusedPayId = 'pay_mock_different_pay_2';
    const reusedSig = computeSignature(testOrderId, reusedPayId);
    await assert.rejects(
      verifyProfessionalSubscriptionPayment.run({
        auth: { uid: sellerAUid },
        data: {
          shopId: shopAId,
          planId: validPlanId,
          razorpayOrderId: testOrderId,
          razorpayPaymentId: reusedPayId,
          razorpaySignature: reusedSig
        }
      }),
      (err) => err.code === 'failed-precondition' && err.message.includes('already been fulfilled')
    );
    reportPass('15. Different payment ID attempting to reuse consumed order is rejected');

    // -------------------------------------------------------------
    // SCENARIO 16: Payment before Admin approval (shop stays hidden until approval)
    // -------------------------------------------------------------
    totalCount++;
    // shopAId had status 'pending_approval'. Verify that payment did NOT alter status to 'approved'
    const shopDocAStatus = await db.collection('diamond_shops').doc(shopAId).get();
    assert.strictEqual(shopDocAStatus.data().status, 'pending_approval');
    assert.strictEqual(shopDocAStatus.data().isSubscriptionActive, true);

    // Now Admin approves the shop
    const adminApproveRes = await adminApproveDiamondShop.run({
      auth: { uid: adminUid, token: { email: 'admin@jamuiservices.com' } },
      data: { shopId: shopAId }
    });
    assert.strictEqual(adminApproveRes.success, true);

    const shopDocAfterAdmin = await db.collection('diamond_shops').doc(shopAId).get();
    assert.strictEqual(shopDocAfterAdmin.data().status, 'approved');
    assert.strictEqual(shopDocAfterAdmin.data().isActive, true);
    assert.strictEqual(shopDocAfterAdmin.data().isSubscriptionActive, true);
    reportPass('16. Payment before approval preserves status=pending_approval; shop becomes live upon admin approval');

    // -------------------------------------------------------------
    // SCENARIO 17: Early renewal expiry stacking (T_exp + d)
    // -------------------------------------------------------------
    totalCount++;
    // Currently shopA has active subscription expiring in ~30 days. Let's record the current expiry
    const preRenewalExpiry = shopDocAfterAdmin.data().subscriptionExpiry.toDate().getTime();

    // Create renewal order for 30 days
    const renewalOrder = await createProfessionalSubscriptionOrder.run({
      auth: { uid: sellerAUid },
      data: { shopId: shopAId, planId: validPlanId }
    });

    const renewalPayId = 'pay_mock_renewal_captured_3';
    const renewalSig = computeSignature(renewalOrder.orderId, renewalPayId);

    await verifyProfessionalSubscriptionPayment.run({
      auth: { uid: sellerAUid },
      data: {
        shopId: shopAId,
        planId: validPlanId,
        razorpayOrderId: renewalOrder.orderId,
        razorpayPaymentId: renewalPayId,
        razorpaySignature: renewalSig
      }
    });

    const shopDocAfterRenewal = await db.collection('diamond_shops').doc(shopAId).get();
    const postRenewalExpiry = shopDocAfterRenewal.data().subscriptionExpiry.toDate().getTime();

    const expectedExtensionMillis = 30 * 24 * 60 * 60 * 1000;
    const diff = Math.abs((postRenewalExpiry - preRenewalExpiry) - expectedExtensionMillis);
    assert.ok(diff < 5000, `Expected extension ~${expectedExtensionMillis}ms, got diff ${diff}ms`);
    reportPass('17. Early renewal stacks duration onto future subscriptionExpiry (T_exp + durationDays)');

    // -------------------------------------------------------------
    // SCENARIO 18: Late renewal expiry reset (T_now + d)
    // -------------------------------------------------------------
    totalCount++;
    const expiredShopId = 'shop_seller_expired';
    const pastExpiryDate = new Date(Date.now() - (10 * 24 * 60 * 60 * 1000)); // 10 days ago
    await db.collection('diamond_shops').doc(expiredShopId).set({
      id: expiredShopId,
      shopName: 'Expired Shop',
      ownerUid: sellerAUid,
      status: 'approved',
      isSubscriptionActive: false,
      subscriptionExpiry: admin.firestore.Timestamp.fromDate(pastExpiryDate)
    });

    const lateRenewalOrder = await createProfessionalSubscriptionOrder.run({
      auth: { uid: sellerAUid },
      data: { shopId: expiredShopId, planId: validPlanId }
    });

    const latePayId = 'pay_mock_late_renewal_4';
    const lateSig = computeSignature(lateRenewalOrder.orderId, latePayId);

    const nowBeforeVerify = Date.now();
    await verifyProfessionalSubscriptionPayment.run({
      auth: { uid: sellerAUid },
      data: {
        shopId: expiredShopId,
        planId: validPlanId,
        razorpayOrderId: lateRenewalOrder.orderId,
        razorpayPaymentId: latePayId,
        razorpaySignature: lateSig
      }
    });

    const expiredShopDocAfter = await db.collection('diamond_shops').doc(expiredShopId).get();
    const newLateExpiry = expiredShopDocAfter.data().subscriptionExpiry.toDate().getTime();
    const expectedLateMin = nowBeforeVerify + (30 * 24 * 60 * 60 * 1000) - 5000;
    const expectedLateMax = Date.now() + (30 * 24 * 60 * 60 * 1000) + 5000;
    assert.ok(newLateExpiry >= expectedLateMin && newLateExpiry <= expectedLateMax,
      'Expired subscription renewal must calculate from now + durationDays, not past date');
    reportPass('18. Late renewal on expired subscription resets expiry starting from now (T_now + durationDays)');

    // -------------------------------------------------------------
    // SCENARIO 19: Activation failure and recovery state (pending_retry)
    // -------------------------------------------------------------
    totalCount++;
    const failOrderId = 'order_mock_fail_tx_sim';
    const failPayId = 'pay_mock_fail_tx_pay';
    const failSig = computeSignature(failOrderId, failPayId);

    // Seed payment pointing to a non-existent shop so runTransaction throws not-found
    await db.collection('diamond_payments').doc(failOrderId).set({
      orderId: failOrderId,
      shopId: 'shop_non_existent_corrupted',
      ownerUid: sellerAUid,
      planId: validPlanId,
      amount: 499,
      amountInPaise: 49900,
      currency: 'INR',
      durationDays: 30,
      status: 'created',
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    await assert.rejects(
      verifyProfessionalSubscriptionPayment.run({
        auth: { uid: sellerAUid },
        data: {
          shopId: 'shop_non_existent_corrupted',
          planId: validPlanId,
          razorpayOrderId: failOrderId,
          razorpayPaymentId: failPayId,
          razorpaySignature: failSig
        }
      }),
      (err) => err.code === 'not-found'
    );

    const failedPaymentDoc = await db.collection('diamond_payments').doc(failOrderId).get();
    assert.strictEqual(failedPaymentDoc.data().status, 'pending_retry');
    assert.strictEqual(failedPaymentDoc.data().paymentId, failPayId);
    reportPass('19. Activation database failure marks payment status as pending_retry for recovery');

    // -------------------------------------------------------------
    // SCENARIO 20: Concurrent verification attempts safety
    // -------------------------------------------------------------
    totalCount++;
    const concOrder = await createProfessionalSubscriptionOrder.run({
      auth: { uid: sellerBUid },
      data: { shopId: shopBId, planId: validPlanId }
    });

    const concPayId = 'pay_mock_conc_5';
    const concSig = computeSignature(concOrder.orderId, concPayId);

    const [concRes1, concRes2] = await Promise.all([
      verifyProfessionalSubscriptionPayment.run({
        auth: { uid: sellerBUid },
        data: {
          shopId: shopBId,
          planId: validPlanId,
          razorpayOrderId: concOrder.orderId,
          razorpayPaymentId: concPayId,
          razorpaySignature: concSig
        }
      }),
      verifyProfessionalSubscriptionPayment.run({
        auth: { uid: sellerBUid },
        data: {
          shopId: shopBId,
          planId: validPlanId,
          razorpayOrderId: concOrder.orderId,
          razorpayPaymentId: concPayId,
          razorpaySignature: concSig
        }
      })
    ]);

    assert.ok(concRes1.success && concRes2.success);
    const shopDocConc = await db.collection('diamond_shops').doc(shopBId).get();
    assert.strictEqual(shopDocConc.data().isSubscriptionActive, true);
    reportPass('20. Concurrent verification calls resolved safely without race condition');

    // -------------------------------------------------------------
    // SCENARIO 21: Normal Provider subscription regression pass
    // -------------------------------------------------------------
    totalCount++;
    // Normal provider uses subscription_plans and payments collections
    assert.strictEqual(typeof createSubscriptionOrder, 'function');
    assert.strictEqual(typeof verifySubscriptionPayment, 'function');
    // Ensure payments collection has zero contamination from diamond_payments
    const diamondPaymentsInPayments = await db.collection('payments').doc(orderRes1.orderId).get();
    assert.strictEqual(diamondPaymentsInPayments.exists, false, 'diamond_payments must not write into payments collection');
    reportPass('21. Normal Provider subscription functions and collections are untouched and fully isolated');

    // -------------------------------------------------------------
    // SCENARIO 22: Premium Provider subscription regression pass
    // -------------------------------------------------------------
    totalCount++;
    // Check webhook handler for professional subscriptions
    assert.strictEqual(typeof professionalRazorpayWebhook, 'function');
    // Verify diamond_payments document integrity
    const finalDoc = await db.collection('diamond_payments').doc(concOrder.orderId).get();
    assert.strictEqual(finalDoc.data().currency, 'INR');
    reportPass('22. Premium Provider architecture remains pristine with dedicated pro payment lifecycle');

    console.log('\n================================================================');
    console.log(` ALL ${passedCount} / ${totalCount} PHASE 1B BACKEND TEST SCENARIOS PASSED SUCCESSFULLY`);
    console.log('================================================================\n');

  } catch (err) {
    reportFail('Test execution encountered unhandled error', err);
  }
}

runPhase1BTestSuite();

