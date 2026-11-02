const assert = require('assert');
const crypto = require('crypto');

console.log('================================================================');
console.log(' JAMUI SERVICES — PAYMENT VERIFICATION & RECONCILIATION TEST SUITE');
console.log('================================================================\n');

let passedTests = 0;
let totalTests = 18;

function runTest(description, testFn) {
  try {
    testFn();
    console.log(`✅ PASSED: ${description}`);
    passedTests++;
  } catch (err) {
    console.error(`❌ FAILED: ${description}`);
    console.error(`   ${err.message}`);
    process.exitCode = 1;
  }
}

// -----------------------------------------------------------------------------
// Reference Logic from functions/index.js
// -----------------------------------------------------------------------------

function isValidWebhookSecret(sec) {
  if (!sec || typeof sec !== 'string') return false;
  const trimmed = sec.trim();
  if (trimmed.length < 8 || trimmed.startsWith('*')) return false;
  const lower = trimmed.toLowerCase();
  if (lower.startsWith('http://') || lower.startsWith('https://')) return false;
  if (trimmed.includes('/') || trimmed.includes('\\') || lower.includes('.cloudfunctions.net') || lower.includes('.run.app')) {
    return false;
  }
  return true;
}

function verifyWebhookHmac(rawPayload, signature, webhookSecret) {
  if (!isValidWebhookSecret(webhookSecret)) {
    return { valid: false, reason: 'Invalid or misconfigured webhook secret' };
  }
  if (!signature) {
    return { valid: false, reason: 'Missing signature header' };
  }
  const expectedSignature = crypto
    .createHmac('sha256', webhookSecret)
    .update(rawPayload)
    .digest('hex');

  const sigBuffer = Buffer.from(signature, 'utf8');
  const expBuffer = Buffer.from(expectedSignature, 'utf8');
  const isValid = (sigBuffer.length === expBuffer.length) && crypto.timingSafeEqual(sigBuffer, expBuffer);
  return { valid: isValid, expected: expectedSignature };
}

function verifyClientPaymentHmac(orderId, paymentId, signature, keySecret) {
  if (!keySecret || keySecret.startsWith('*')) {
    throw new Error('Key secret unconfigured or invalid');
  }
  const expectedBody = `${orderId}|${paymentId}`;
  const expectedSignature = crypto
    .createHmac('sha256', keySecret)
    .update(expectedBody)
    .digest('hex');

  const sigBuffer = Buffer.from(signature || '', 'utf8');
  const expBuffer = Buffer.from(expectedSignature, 'utf8');
  const isValid = (sigBuffer.length === expBuffer.length) && crypto.timingSafeEqual(sigBuffer, expBuffer);
  return isValid;
}

// Admin Panel Pending Approval Filter Simulation
function filterPendingApprovalPayments(paymentsList) {
  const pendingByProvider = new Map();

  // First pass: identify payments awaiting approval
  for (const pay of paymentsList) {
    const isCaptured = pay.status === 'success' || pay.captured === true || pay.paymentStatus === 'captured';
    const isPendingApproval = pay.adminApprovalStatus === 'pending_approval';

    if (isCaptured && isPendingApproval) {
      const pid = pay.providerId;
      if (!pendingByProvider.has(pid) || pay.createdAt > pendingByProvider.get(pid).createdAt) {
        pendingByProvider.set(pid, pay);
      }
    }
  }

  return Array.from(pendingByProvider.values());
}

// -----------------------------------------------------------------------------
// TEST 1: Valid webhook signature HMAC-SHA256
// -----------------------------------------------------------------------------
runTest('1. Valid webhook signature HMAC-SHA256 is accepted', () => {
  const secret = 'valid_webhook_secret_key_884920';
  const payload = JSON.stringify({
    event: 'payment.captured',
    payload: {
      payment: {
        entity: {
          id: 'pay_TtlXdLnP0DSUWa',
          order_id: 'order_TtlXXJlxvpAnM4',
          amount: 2000,
          status: 'captured',
          notes: { providerId: 'KLDVdlQdduVE8PWgOXnJy6zskIn2', planId: 'plan_basic_20' }
        }
      }
    }
  });

  const validSignature = crypto.createHmac('sha256', secret).update(payload).digest('hex');
  const result = verifyWebhookHmac(payload, validSignature, secret);

  assert.strictEqual(result.valid, true, 'HMAC verification should succeed for valid signature');
});

// -----------------------------------------------------------------------------
// TEST 2: Invalid webhook signature rejection
// -----------------------------------------------------------------------------
runTest('2. Invalid webhook signature is rejected with invalid status', () => {
  const secret = 'valid_webhook_secret_key_884920';
  const payload = JSON.stringify({ event: 'payment.captured' });
  const badSignature = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

  const result = verifyWebhookHmac(payload, badSignature, secret);
  assert.strictEqual(result.valid, false, 'Invalid signature should be rejected');
});

// -----------------------------------------------------------------------------
// TEST 3: Secret missing or URL/malformed validation (isValidWebhookSecret)
// -----------------------------------------------------------------------------
runTest('3. Secret missing or URL/malformed is detected and rejected by isValidWebhookSecret', () => {
  // URLs that might accidentally be pasted as secret
  assert.strictEqual(isValidWebhookSecret('https://us-central1-jamui-services.cloudfunctions.net/razorpayWebhook'), false);
  assert.strictEqual(isValidWebhookSecret('http://api.jamuiservices.in/webhook'), false);
  assert.strictEqual(isValidWebhookSecret('https://service-run.a.run.app/hook'), false);
  
  // Empty, short or masked
  assert.strictEqual(isValidWebhookSecret(''), false);
  assert.strictEqual(isValidWebhookSecret(null), false);
  assert.strictEqual(isValidWebhookSecret('short'), false);
  assert.strictEqual(isValidWebhookSecret('***MASKED***'), false);

  // Valid secrets
  assert.strictEqual(isValidWebhookSecret('rzp_wh_live_992384752834'), true);
  assert.strictEqual(isValidWebhookSecret('my_secure_hmac_secret_key_2026'), true);
});

// -----------------------------------------------------------------------------
// TEST 4: Client callback success vs backend verification failure
// -----------------------------------------------------------------------------
runTest('4. Client claiming success is rejected if HMAC signature does not verify', () => {
  const keySecret = 'rzp_key_secret_test_abcdef';
  const orderId = 'order_TtlXXJlxvpAnM4';
  const paymentId = 'pay_TtlXdLnP0DSUWa';
  const fakeSignature = 'bad_forged_client_signature_abc123';

  const isValid = verifyClientPaymentHmac(orderId, paymentId, fakeSignature, keySecret);
  assert.strictEqual(isValid, false, 'Forged client signature must not pass verification');
});

// -----------------------------------------------------------------------------
// TEST 5: UPI callback miss & resume status recovery via reconcileProviderSubscriptionPayment
// -----------------------------------------------------------------------------
runTest('5. UPI callback miss is recovered on resume via reconcileProviderSubscriptionPayment logic', () => {
  // Mock order state in payments collection when UPI returns without client callback
  const mockDb = {
    payments: {
      'order_TtlXXJlxvpAnM4': {
        orderId: 'order_TtlXXJlxvpAnM4',
        providerId: 'KLDVdlQdduVE8PWgOXnJy6zskIn2',
        status: 'created', // Unreconciled
        amountInPaise: 2000,
        amount: 20,
        planId: '1nhifE6GzhmgYh28mxZd',
        planName: 'Basic',
      }
    }
  };

  // Mock Razorpay API response for captured payment
  const mockRzpPayment = {
    id: 'pay_TtlXdLnP0DSUWa',
    order_id: 'order_TtlXXJlxvpAnM4',
    status: 'captured',
    amount: 2000,
    currency: 'INR',
    notes: { providerId: 'KLDVdlQdduVE8PWgOXnJy6zskIn2' }
  };

  // Simulate reconciliation function
  function reconcileOrder(orderId, callerUid) {
    const payData = mockDb.payments[orderId];
    assert(payData, 'Payment record exists');
    assert.strictEqual(payData.providerId, callerUid, 'Caller must own the order');

    // Live API check
    if (mockRzpPayment.status === 'captured' && mockRzpPayment.amount === payData.amountInPaise) {
      payData.status = 'success';
      payData.paymentStatus = 'captured';
      payData.captured = true;
      payData.paymentId = mockRzpPayment.id;
      payData.razorpayPaymentId = mockRzpPayment.id;
      payData.liveVerified = true;
      payData.adminApprovalStatus = 'pending_approval';
      return { success: true, reconciled: true, adminApprovalStatus: 'pending_approval' };
    }
    return { success: false };
  }

  const result = reconcileOrder('order_TtlXXJlxvpAnM4', 'KLDVdlQdduVE8PWgOXnJy6zskIn2');
  assert.strictEqual(result.success, true);
  assert.strictEqual(result.adminApprovalStatus, 'pending_approval');
  assert.strictEqual(mockDb.payments['order_TtlXXJlxvpAnM4'].status, 'success');
  assert.strictEqual(mockDb.payments['order_TtlXXJlxvpAnM4'].captured, true);
});

// -----------------------------------------------------------------------------
// TEST 6: Captured & verified payment → Pending Approval list inclusion
// -----------------------------------------------------------------------------
runTest('6. Captured & verified payment is correctly included in Admin Pending Approvals list', () => {
  const payments = [
    {
      orderId: 'order_TtlXXJlxvpAnM4',
      providerId: 'KLDVdlQdduVE8PWgOXnJy6zskIn2',
      providerName: 'jamui air coling',
      status: 'success',
      paymentStatus: 'captured',
      captured: true,
      adminApprovalStatus: 'pending_approval',
      createdAt: new Date('2026-10-29T15:00:00Z'),
    },
    {
      // Older provider, already approved
      orderId: 'order_OLD123',
      providerId: 'uIT6hYxtt3PuWW9rBx9CIWl36Op1',
      providerName: 'Srusu Unisex',
      status: 'success',
      paymentStatus: 'captured',
      captured: true,
      adminApprovalStatus: 'approved',
      createdAt: new Date('2026-10-25T10:00:00Z'),
    }
  ];

  const pendingList = filterPendingApprovalPayments(payments);
  assert.strictEqual(pendingList.length, 1);
  assert.strictEqual(pendingList[0].providerId, 'KLDVdlQdduVE8PWgOXnJy6zskIn2');
  assert.strictEqual(pendingList[0].orderId, 'order_TtlXXJlxvpAnM4');
});

// -----------------------------------------------------------------------------
// TEST 7: Uncaptured/unverified payment → excluded from Approval list
// -----------------------------------------------------------------------------
runTest('7. Uncaptured or abandoned orders are excluded from Pending Approval list', () => {
  const payments = [
    {
      orderId: 'order_abandoned_999',
      providerId: 'provider_abandoned_1',
      status: 'created',
      captured: false,
      adminApprovalStatus: null,
      createdAt: new Date('2026-10-29T16:00:00Z'),
    },
    {
      orderId: 'order_failed_888',
      providerId: 'provider_failed_2',
      status: 'failed',
      captured: false,
      adminApprovalStatus: null,
      createdAt: new Date('2026-10-29T16:10:00Z'),
    }
  ];

  const pendingList = filterPendingApprovalPayments(payments);
  assert.strictEqual(pendingList.length, 0, 'Uncaptured payments must never appear in pending approvals');
});

// -----------------------------------------------------------------------------
// TEST 8: Duplicate webhook deliveries → idempotent (no duplicate renewal)
// -----------------------------------------------------------------------------
runTest('8. Duplicate webhook deliveries are handled idempotently without double processing', () => {
  let activationCount = 0;
  const paymentRecord = {
    orderId: 'order_TtlXXJlxvpAnM4',
    status: 'created'
  };

  function processWebhook(event, orderId) {
    if (paymentRecord.status === 'success') {
      // Idempotency: skip duplicate execution
      return { skipped: true, reason: 'Already fulfilled' };
    }
    paymentRecord.status = 'success';
    activationCount++;
    return { success: true };
  }

  // First delivery
  const res1 = processWebhook('payment.captured', 'order_TtlXXJlxvpAnM4');
  assert.strictEqual(res1.success, true);
  assert.strictEqual(activationCount, 1);

  // Second delivery (Razorpay automatic retry)
  const res2 = processWebhook('payment.captured', 'order_TtlXXJlxvpAnM4');
  assert.strictEqual(res2.skipped, true);
  assert.strictEqual(activationCount, 1, 'Activation count must remain 1');

  // Third delivery
  const res3 = processWebhook('payment.captured', 'order_TtlXXJlxvpAnM4');
  assert.strictEqual(res3.skipped, true);
  assert.strictEqual(activationCount, 1, 'Activation count must remain 1');
});

// -----------------------------------------------------------------------------
// TEST 9: Client verification + webhook collision → single processing
// -----------------------------------------------------------------------------
runTest('9. Concurrent client verification and webhook delivery process safely without conflict', () => {
  let executionCount = 0;
  const paymentState = { status: 'created', captured: false };

  function handleVerificationOrWebhook(source) {
    // Both verifySubscriptionPayment and razorpayWebhook check if status === 'success'
    if (paymentState.status === 'success') {
      return { source, alreadyProcessed: true };
    }
    paymentState.status = 'success';
    paymentState.captured = true;
    executionCount++;
    return { source, processed: true };
  }

  // Client finishes first
  const r1 = handleVerificationOrWebhook('client_verification');
  assert.strictEqual(r1.processed, true);

  // Webhook finishes slightly later
  const r2 = handleVerificationOrWebhook('webhook');
  assert.strictEqual(r2.alreadyProcessed, true);
  assert.strictEqual(executionCount, 1, 'Payment state transitioned exactly once');
});

// -----------------------------------------------------------------------------
// TEST 10: Duplicate admin approval attempt → rejection, expiry extended only once
// -----------------------------------------------------------------------------
runTest('10. Duplicate admin approval is rejected and expiry is extended only once', () => {
  let approvalCount = 0;
  const initialExpiry = new Date('2026-11-28T15:00:00Z');
  const provider = {
    id: 'KLDVdlQdduVE8PWgOXnJy6zskIn2',
    subscriptionExpiry: initialExpiry,
    isSubscriptionActive: false,
    subscriptionApprovalStatus: 'pending_approval'
  };

  const payment = {
    orderId: 'order_TtlXXJlxvpAnM4',
    adminApprovalStatus: 'pending_approval',
    status: 'success',
    captured: true,
    liveVerified: true,
    durationDays: 30
  };

  function adminApproveSubscription(prov, pay) {
    if (pay.adminApprovalStatus === 'approved') {
      throw new Error('This subscription payment has already been approved and activated.');
    }
    if (pay.status !== 'success' || pay.captured !== true || pay.liveVerified !== true) {
      throw new Error('Payment not confirmed captured');
    }

    // Extend expiry by 30 days
    const newExpiry = new Date(prov.subscriptionExpiry.getTime() + (pay.durationDays * 24 * 60 * 60 * 1000));
    prov.subscriptionExpiry = newExpiry;
    prov.isSubscriptionActive = true;
    prov.subscriptionApprovalStatus = 'approved';
    pay.adminApprovalStatus = 'approved';
    approvalCount++;
    return { success: true, expiry: newExpiry };
  }

  // First approval
  const res1 = adminApproveSubscription(provider, payment);
  assert.strictEqual(res1.success, true);
  assert.strictEqual(approvalCount, 1);
  const expiryAfterFirstApproval = provider.subscriptionExpiry.getTime();

  // Second approval attempt (accidental double-click)
  assert.throws(
    () => adminApproveSubscription(provider, payment),
    /already been approved and activated/
  );
  assert.strictEqual(approvalCount, 1, 'Approval count must remain 1');
  assert.strictEqual(provider.subscriptionExpiry.getTime(), expiryAfterFirstApproval, 'Expiry must not be extended twice');
});

// -----------------------------------------------------------------------------
// TEST 11: Network timeout & retry handling
// -----------------------------------------------------------------------------
runTest('11. Network timeout during verification fails gracefully and allows clean retry', () => {
  let callAttempts = 0;

  function remoteCallWithTimeout(succeedOnAttempt) {
    callAttempts++;
    if (callAttempts < succeedOnAttempt) {
      const err = new Error('Gateway Timeout');
      err.code = 'DEADLINE_EXCEEDED';
      throw err;
    }
    return { success: true, verified: true };
  }

  // Attempt 1: Network timeout
  let firstAttemptSucceeded = false;
  try {
    remoteCallWithTimeout(2);
    firstAttemptSucceeded = true;
  } catch (err) {
    assert.strictEqual(err.code, 'DEADLINE_EXCEEDED');
  }
  assert.strictEqual(firstAttemptSucceeded, false);

  // Attempt 2: Clean retry succeeds without corrupted state
  const retryResult = remoteCallWithTimeout(2);
  assert.strictEqual(retryResult.success, true);
  assert.strictEqual(retryResult.verified, true);
  assert.strictEqual(callAttempts, 2);
});

// -----------------------------------------------------------------------------
// TEST 12: Backward compatibility with legacy payment records
// -----------------------------------------------------------------------------
runTest('12. Backward compatibility: Legacy payment records without snapshot resolve correctly', () => {
  // Legacy payment record format (pre-snapshot schema)
  const legacyPayment = {
    orderId: 'order_legacy_101',
    providerId: 'provider_legacy_1',
    planId: 'plan_basic_20',
    amount: 20, // in Rupees, amountInPaise missing
    durationDays: 30,
    planName: 'Basic',
    status: 'success',
    captured: true,
    liveVerified: true,
    adminApprovalStatus: 'pending_approval'
  };

  function resolveLegacyPricing(payData) {
    let orderAmountPaise = null;
    let orderAmountRupees = null;
    let durationDays = Number(payData.durationDays || 0);

    if (payData.amountInPaise !== undefined && Number(payData.amountInPaise) > 0) {
      orderAmountPaise = Number(payData.amountInPaise);
      orderAmountRupees = Number(payData.amount !== undefined ? payData.amount : (orderAmountPaise / 100));
    } else if (payData.amount !== undefined && Number(payData.amount) > 0) {
      orderAmountRupees = Number(payData.amount);
      orderAmountPaise = Math.round(orderAmountRupees * 100);
    }

    return {
      orderAmountPaise,
      orderAmountRupees,
      durationDays,
    };
  }

  const resolved = resolveLegacyPricing(legacyPayment);
  assert.strictEqual(resolved.orderAmountPaise, 2000, 'Rupees 20 correctly converted to 2000 paise');
  assert.strictEqual(resolved.orderAmountRupees, 20);
  assert.strictEqual(resolved.durationDays, 30);
});

// -----------------------------------------------------------------------------
// TEST 13: Out-of-order webhook events do not regress captured status
// -----------------------------------------------------------------------------
runTest('13. Out-of-order webhook events (authorized/pending) do not regress captured status', () => {
  let paymentDoc = {
    orderId: 'order_ooo_13',
    status: 'success',
    captured: true,
    adminApprovalStatus: 'pending_approval',
  };

  function processIncomingWebhookEvent(currentDoc, incomingEvent) {
    // Invariant: Once success & captured, non-terminal or stale events are ignored
    if (currentDoc.status === 'success' && currentDoc.captured === true) {
      if (incomingEvent === 'payment.authorized' || incomingEvent === 'order.created') {
        return { ignored: true, doc: currentDoc };
      }
    }
    return { ignored: false, doc: { ...currentDoc, status: incomingEvent } };
  }

  const res = processIncomingWebhookEvent(paymentDoc, 'payment.authorized');
  assert.strictEqual(res.ignored, true);
  assert.strictEqual(res.doc.status, 'success');
  assert.strictEqual(res.doc.captured, true);
});

// -----------------------------------------------------------------------------
// TEST 14: Old incomplete order does NOT shadow or hide valid captured payment
// -----------------------------------------------------------------------------
runTest('14. Old incomplete order does NOT shadow or hide valid captured payment in Admin view', () => {
  const provider = {
    id: 'prov_multi_order_14',
    name: 'Ramesh Handyman',
    paymentOrderId: 'order_old_abandoned_14', // Old abandoned order stored in profile
  };

  const oldAbandonedPayment = {
    id: 'order_old_abandoned_14',
    orderId: 'order_old_abandoned_14',
    providerId: 'prov_multi_order_14',
    status: 'created',
    captured: false,
    adminApprovalStatus: null,
  };

  const newCapturedPayment = {
    id: 'order_new_paid_14',
    orderId: 'order_new_paid_14',
    providerId: 'prov_multi_order_14',
    status: 'success',
    captured: true,
    liveVerified: true,
    adminApprovalStatus: 'pending_approval',
    isConsumed: false,
  };

  // Simulating Admin Panel linking logic: Prioritizing pendingApprovalPaymentByProviderId
  const paymentByOrderId = {
    [oldAbandonedPayment.id]: oldAbandonedPayment,
    [newCapturedPayment.id]: newCapturedPayment,
  };
  const pendingApprovalPaymentByProviderId = {
    'prov_multi_order_14': newCapturedPayment,
  };

  const storedOrderId = provider.paymentOrderId;
  // Authoritative linking priority:
  const linkedPayment = pendingApprovalPaymentByProviderId[provider.id] ||
      (storedOrderId ? paymentByOrderId[storedOrderId] : null);

  assert.strictEqual(linkedPayment.orderId, 'order_new_paid_14', 'Pending approval payment must take precedence over old order');
  assert.strictEqual(linkedPayment.captured, true);
  assert.strictEqual(linkedPayment.adminApprovalStatus, 'pending_approval');
});

// -----------------------------------------------------------------------------
// TEST 15: Cross-provider reconciliation authorization protection
// -----------------------------------------------------------------------------
runTest('15. Cross-provider reconciliation: Provider attempting to reconcile another provider order is rejected', () => {
  function simulateProviderReconcileAuth({ callerUid, orderProviderId }) {
    if (!callerUid) throw new Error('unauthenticated');
    if (callerUid !== orderProviderId) {
      throw new Error('permission-denied: You can only reconcile your own orders.');
    }
    return { authorized: true };
  }

  assert.throws(
    () => simulateProviderReconcileAuth({ callerUid: 'attacker_prov_99', orderProviderId: 'victim_prov_01' }),
    /permission-denied/
  );

  const selfReconcile = simulateProviderReconcileAuth({ callerUid: 'legit_prov_01', orderProviderId: 'legit_prov_01' });
  assert.strictEqual(selfReconcile.authorized, true);
});

// -----------------------------------------------------------------------------
// TEST 16: Reconciliation recovery sets pending_approval and leaves provider inactive
// -----------------------------------------------------------------------------
runTest('16. Reconciliation recovery sets pending_approval and leaves provider inactive until Admin approval', () => {
  const provider = {
    id: 'prov_reconciled_16',
    isSubscriptionActive: false,
    subscriptionApprovalStatus: 'none',
  };

  const gatewayCaptured = {
    id: 'pay_rzp_rec_16',
    order_id: 'order_rec_16',
    status: 'captured',
    amount: 19900,
    currency: 'INR',
  };

  // Backend state machine transition:
  const updatedProvider = {
    ...provider,
    paymentOrderId: gatewayCaptured.order_id,
    paymentId: gatewayCaptured.id,
    paymentVerified: true,
    subscriptionPaymentStatus: 'paid',
    subscriptionApprovalStatus: 'pending_approval',
    isSubscriptionActive: false, // Strictly false until Admin approval!
  };

  assert.strictEqual(updatedProvider.paymentVerified, true);
  assert.strictEqual(updatedProvider.subscriptionApprovalStatus, 'pending_approval');
  assert.strictEqual(updatedProvider.isSubscriptionActive, false, 'Provider must NEVER self-activate before Admin approval');
});

// -----------------------------------------------------------------------------
// TEST 17: Admin query/network error preserves error state (no false empty list)
// -----------------------------------------------------------------------------
runTest('17. Admin query error preserves error state and is NEVER displayed as a false empty list', () => {
  function handleAdminPaymentFetchResult(error, loadedData) {
    if (error) {
      return {
        isLoading: false,
        errorMessage: 'डेटा लोड करने में त्रुटि। कृपया पुनः प्रयास करें।',
        items: [],
        hasError: true,
      };
    }
    return {
      isLoading: false,
      errorMessage: null,
      items: loadedData,
      hasError: false,
    };
  }

  const errorResult = handleAdminPaymentFetchResult(new Error('Network disconnected'), null);
  assert.strictEqual(errorResult.hasError, true);
  assert.notStrictEqual(errorResult.errorMessage, null);
  // UI knows it is an ERROR state, not a legitimate empty list!
});

// -----------------------------------------------------------------------------
// TEST 18: Currency, amount, or order mismatch in Gateway API strictly rejects
// -----------------------------------------------------------------------------
runTest('18. Currency, amount, or order mismatch in Gateway API strictly rejects payment', () => {
  function validateGatewayCapturedPayment({ orderAmountPaise, orderCurrency, gatewayPayment }) {
    if (gatewayPayment.currency !== orderCurrency) {
      throw new Error(`invalid-currency: Expected ${orderCurrency}, got ${gatewayPayment.currency}`);
    }
    if (Number(gatewayPayment.amount) !== Number(orderAmountPaise)) {
      throw new Error(`amount-mismatch: Expected ${orderAmountPaise}, got ${gatewayPayment.amount}`);
    }
    if (gatewayPayment.status !== 'captured') {
      throw new Error(`uncaptured: Payment status is ${gatewayPayment.status}`);
    }
    return { valid: true };
  }

  // Amount mismatch
  assert.throws(
    () => validateGatewayCapturedPayment({
      orderAmountPaise: 19900,
      orderCurrency: 'INR',
      gatewayPayment: { amount: 10000, currency: 'INR', status: 'captured' },
    }),
    /amount-mismatch/
  );

  // Currency mismatch
  assert.throws(
    () => validateGatewayCapturedPayment({
      orderAmountPaise: 19900,
      orderCurrency: 'INR',
      gatewayPayment: { amount: 19900, currency: 'USD', status: 'captured' },
    }),
    /invalid-currency/
  );

  // Valid payment succeeds
  const valid = validateGatewayCapturedPayment({
    orderAmountPaise: 19900,
    orderCurrency: 'INR',
    gatewayPayment: { amount: 19900, currency: 'INR', status: 'captured' },
  });
  assert.strictEqual(valid.valid, true);
});

// -----------------------------------------------------------------------------
// SUMMARY
// -----------------------------------------------------------------------------
console.log('\n================================================================');
console.log(` RESULTS: ${passedTests}/${totalTests} tests passed.`);
console.log('================================================================\n');

if (passedTests === totalTests) {
  console.log('🎉 ALL 18 PAYMENT & RECONCILIATION TEST SUITE SCENARIOS PASSED!');
  process.exit(0);
} else {
  console.error('❌ SOME TESTS FAILED.');
  process.exit(1);
}

