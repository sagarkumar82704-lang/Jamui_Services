const assert = require('assert');
const crypto = require('crypto');

// Setup mock environment variables for test execution
const TEST_KEY_ID = 'rzp_test_mock_12345678';
const TEST_KEY_SECRET = 'mock_secret_key_87654321';
const TEST_WEBHOOK_SECRET = 'mock_webhook_secret_abcdef';

process.env.RAZORPAY_KEY_ID = TEST_KEY_ID;
process.env.RAZORPAY_KEY_SECRET = TEST_KEY_SECRET;
process.env.RAZORPAY_WEBHOOK_SECRET = TEST_WEBHOOK_SECRET;

// In-Memory Mock Database to test Cloud Functions handlers deterministically without touching production data
class MockFirestore {
  constructor() {
    this.store = {
      app_config: {
        payment: { razorpay_key_id: TEST_KEY_ID },
        payment_secrets: { keySecret: TEST_KEY_SECRET, webhookSecret: TEST_WEBHOOK_SECRET },
      },
      providers: {
        'prov_alice': {
          fullName: 'Alice Electrician',
          status: 'approved',
          kycStatus: 'approved',
          isSubscriptionActive: false,
          paymentVerified: false,
        },
        'prov_bob': {
          fullName: 'Bob Plumber',
          status: 'pendingReview',
          kycStatus: 'pendingReview',
          isSubscriptionActive: false,
          paymentVerified: false,
        },
      },
      subscription_plans: {
        'plan_basic': { id: 'plan_basic', name: 'Basic Starter', price: 199.0, durationDays: 30, categoryLimit: 1, isActive: true },
        'plan_popular': { id: 'plan_popular', name: 'Standard Pro', price: 399.0, durationDays: 30, categoryLimit: 3, isActive: true },
      },
      payments: {},
      subscriptions: {},
    };
  }

  collection(name) {
    return {
      doc: (id) => ({
        get: async () => {
          const docData = this.store[name]?.[id];
          return {
            exists: !!docData,
            data: () => (docData ? JSON.parse(JSON.stringify(docData)) : undefined),
          };
        },
        set: async (data, options = {}) => {
          if (!this.store[name]) this.store[name] = {};
          if (options.merge && this.store[name][id]) {
            this.store[name][id] = { ...this.store[name][id], ...data };
          } else {
            this.store[name][id] = JSON.parse(JSON.stringify(data));
          }
        },
        update: async (data) => {
          if (!this.store[name]?.[id]) throw new Error(`Doc ${id} not found`);
          this.store[name][id] = { ...this.store[name][id], ...data };
        },
      }),
    };
  }

  batch() {
    const ops = [];
    return {
      set: (docRef, data, options) => ops.push({ type: 'set', docRef, data, options }),
      update: (docRef, data) => ops.push({ type: 'update', docRef, data }),
      commit: async () => {
        for (const op of ops) {
          if (op.type === 'set') await op.docRef.set(op.data, op.options);
          if (op.type === 'update') await op.docRef.update(op.data);
        }
      },
    };
  }
}

// Emulate razorpayWebhook core verification logic
async function simulateRazorpayWebhook(req, mockDb) {
  let statusCode = 200;
  let responseData = null;

  const res = {
    status: (code) => {
      statusCode = code;
      return {
        send: (msg) => { responseData = msg; },
        json: (obj) => { responseData = obj; },
      };
    },
  };

  const webhookSecret = TEST_WEBHOOK_SECRET;
  const signature = req.headers['x-razorpay-signature'];

  // 1. Mandatory Dedicated Webhook Secret & Signature Check
  if (!webhookSecret || !signature) {
    res.status(401).send('Missing Signature or Secret');
    return { statusCode, responseData };
  }

  // 2. HMAC Validation with Dedicated Webhook Secret
  const rawPayload = req.rawBody ? req.rawBody.toString('utf8') : JSON.stringify(req.body);
  const expectedSignature = crypto
    .createHmac('sha256', webhookSecret)
    .update(rawPayload)
    .digest('hex');

  const sigBuffer = Buffer.from(signature, 'utf8');
  const expBuffer = Buffer.from(expectedSignature, 'utf8');
  const isValid = (sigBuffer.length === expBuffer.length) && crypto.timingSafeEqual(sigBuffer, expBuffer);

  if (!isValid) {
    res.status(400).send('Invalid Signature');
    return { statusCode, responseData };
  }

  // 3. Process Event
  const event = req.body?.event;
  const payload = req.body?.payload;

  if (event === 'payment.captured' || event === 'order.paid') {
    const paymentEntity = payload?.payment?.entity || payload?.order?.entity;
    const notes = paymentEntity?.notes || {};
    const providerId = notes.providerId;
    const planId = notes.planId;
    const orderId = paymentEntity?.order_id || payload?.order?.entity?.id;
    const paymentId = paymentEntity?.id;

    if (providerId && planId && orderId) {
      const paymentDocRef = mockDb.collection('payments').doc(orderId);
      const existingPayment = await paymentDocRef.get();

      // Idempotency check
      if (existingPayment.exists && existingPayment.data()?.status === 'success') {
        res.status(200).json({ status: 'ok', message: 'already_fulfilled' });
        return { statusCode, responseData };
      }

      // Currency check
      const paymentCurrency = paymentEntity?.currency || 'INR';
      if (paymentCurrency !== 'INR') {
        res.status(400).json({ status: 'error', message: 'Invalid currency' });
        return { statusCode, responseData };
      }

      const existingData = existingPayment.exists ? existingPayment.data() : {};
      const expectedPaise = existingData.amountInPaise !== undefined ? Number(existingData.amountInPaise) : 0;
      const webhookPaidPaise = Number(paymentEntity?.amount || 0);

      // Amount check in minor units
      if (expectedPaise > 0 && webhookPaidPaise > 0 && webhookPaidPaise < expectedPaise) {
        res.status(400).json({ status: 'error', message: 'Underpaid amount' });
        return { statusCode, responseData };
      }

      const paidAmountRupees = webhookPaidPaise > 0 ? (webhookPaidPaise / 100) : 199.0;
      const finalPaise = webhookPaidPaise > 0 ? webhookPaidPaise : Math.round(paidAmountRupees * 100);

      const batch = mockDb.batch();
      batch.set(paymentDocRef, {
        status: 'success',
        orderId,
        paymentId,
        providerId,
        planId,
        amount: paidAmountRupees,
        amountInPaise: finalPaise,
        currency: 'INR',
        webhookProcessed: true,
        adminApprovalStatus: 'pending_approval',
      }, { merge: true });

      const subRef = mockDb.collection('subscriptions').doc(`sub_${orderId}`);
      batch.set(subRef, {
        id: `sub_${orderId}`,
        providerId,
        planId,
        amountPaid: paidAmountRupees,
        amountPaidInPaise: finalPaise,
        currency: 'INR',
        status: 'pending_approval',
      });

      const provRef = mockDb.collection('providers').doc(providerId);
      batch.update(provRef, {
        isSubscriptionActive: false, // Strict
        paymentVerified: true,
        subscriptionPaymentStatus: 'paid',
        subscriptionApprovalStatus: 'pending_approval',
      });

      await batch.commit();
      res.status(200).json({ status: 'ok', message: 'fulfilled' });
      return { statusCode, responseData };
    }
  } else if (event === 'payment.failed') {
    const paymentEntity = payload?.payment?.entity;
    const orderId = paymentEntity?.order_id;
    if (orderId) {
      const existingDoc = await mockDb.collection('payments').doc(orderId).get();
      if (existingDoc.exists && existingDoc.data()?.status === 'success') {
        res.status(200).json({ status: 'ok', message: 'ignored_already_successful' });
        return { statusCode, responseData };
      }

      await mockDb.collection('payments').doc(orderId).set({
        status: 'failed',
        errorCode: paymentEntity?.error_code || 'PAYMENT_FAILED',
      }, { merge: true });
      res.status(200).json({ status: 'ok', message: 'failed_recorded' });
      return { statusCode, responseData };
    }
  }

  res.status(200).json({ status: 'ok' });
  return { statusCode, responseData };
}

// Emulate verifySubscriptionPayment core verification logic
async function simulateVerifySubscriptionPayment(request, mockDb, mockRzpClient = null) {
  const { providerId, planId, razorpayOrderId, razorpayPaymentId, razorpaySignature } = request.data || {};

  if (!providerId || !planId || !razorpayOrderId || !razorpayPaymentId || !razorpaySignature) {
    throw new Error('invalid-argument: Incomplete payload');
  }

  if (!request.auth || !request.auth.uid) {
    throw new Error('unauthenticated: Login required');
  }

  if (request.auth.uid !== providerId) {
    throw new Error('permission-denied: UID mismatch');
  }

  const provDoc = await mockDb.collection('providers').doc(providerId).get();
  if (!provDoc.exists) {
    throw new Error('permission-denied: Provider does not exist');
  }

  // 1. Signature Check
  const expectedBody = `${razorpayOrderId}|${razorpayPaymentId}`;
  const expectedSignature = crypto.createHmac('sha256', TEST_KEY_SECRET).update(expectedBody).digest('hex');
  const sigBuffer = Buffer.from(razorpaySignature, 'utf8');
  const expBuffer = Buffer.from(expectedSignature, 'utf8');
  const isSigValid = (sigBuffer.length === expBuffer.length) && crypto.timingSafeEqual(sigBuffer, expBuffer);
  if (!isSigValid) {
    throw new Error('permission-denied: HMAC signature mismatch');
  }

  // 2. Order Doc Check
  const paymentRef = mockDb.collection('payments').doc(razorpayOrderId);
  const paymentSnap = await paymentRef.get();
  if (!paymentSnap.exists) {
    throw new Error('failed-precondition: Order record not found');
  }

  const orderData = paymentSnap.data();

  // Idempotency
  if (orderData.status === 'success') {
    return { success: true, alreadyProcessed: true };
  }

  // Cross-checks
  if (orderData.providerId !== providerId) {
    throw new Error('permission-denied: Order provider mismatch');
  }
  if (orderData.planId !== planId) {
    throw new Error('invalid-argument: Order plan mismatch');
  }
  if (orderData.currency !== 'INR') {
    throw new Error('invalid-argument: Invalid currency');
  }

  const expectedPaise = Number(orderData.amountInPaise || 19900);

  // 3. Razorpay API Cross-Check
  if (mockRzpClient) {
    const rzpPayment = await mockRzpClient.payments.fetch(razorpayPaymentId);
    if (rzpPayment.status !== 'captured' && rzpPayment.status !== 'authorized') {
      throw new Error(`failed-precondition: Payment not captured (${rzpPayment.status})`);
    }
    if (rzpPayment.order_id !== razorpayOrderId) {
      throw new Error('permission-denied: Razorpay order_id mismatch');
    }
    if (rzpPayment.currency !== 'INR') {
      throw new Error('invalid-argument: Razorpay currency not INR');
    }
    if (Number(rzpPayment.amount) < expectedPaise) {
      throw new Error('invalid-argument: Underpaid amount in Razorpay payment');
    }
  }

  const batch = mockDb.batch();
  batch.set(paymentRef, {
    status: 'success',
    amount: expectedPaise / 100,
    amountInPaise: expectedPaise,
    currency: 'INR',
    signature: razorpaySignature,
    adminApprovalStatus: 'pending_approval',
  }, { merge: true });

  const subRef = mockDb.collection('subscriptions').doc(`sub_${razorpayOrderId}`);
  batch.set(subRef, {
    id: `sub_${razorpayOrderId}`,
    providerId,
    planId,
    amountPaid: expectedPaise / 100,
    amountPaidInPaise: expectedPaise,
    status: 'pending_approval',
  });

  const providerRef = mockDb.collection('providers').doc(providerId);
  batch.update(providerRef, {
    isSubscriptionActive: false, // Strict: Pending Admin Manual Approval
    paymentVerified: true,
    subscriptionPaymentStatus: 'paid',
    subscriptionApprovalStatus: 'pending_approval',
  });

  await batch.commit();
  return { success: true, approvalStatus: 'pending_approval' };
}

// -------------------------------------------------------------
// EXECUTE AUTOMATED SECURITY TEST SUITE
// -------------------------------------------------------------
async function runTests() {
  console.log('===============================================================');
  console.log('   RAZORPAY & SUBSCRIPTION SECURITY SUITE: AUTOMATED TESTS     ');
  console.log('===============================================================\n');

  let passed = 0;
  let total = 0;

  function record(testName, isSuccess, details = '') {
    total++;
    if (isSuccess) {
      passed++;
      console.log(`✅ [PASS] Test ${total}: ${testName}`);
    } else {
      console.error(`❌ [FAIL] Test ${total}: ${testName} - ${details}`);
    }
  }

  const mockDb = new MockFirestore();

  // Seed an existing order in Firestore
  const testOrderId = 'order_test_9999';
  await mockDb.collection('payments').doc(testOrderId).set({
    id: testOrderId,
    orderId: testOrderId,
    providerId: 'prov_alice',
    planId: 'plan_basic',
    amount: 199.0,
    amountInPaise: 19900,
    currency: 'INR',
    status: 'created',
  });

  // TEST 1: Webhook - Missing Signature Header -> Immediate 401 Reject
  {
    const req = {
      headers: {}, // No signature
      rawBody: Buffer.from(JSON.stringify({ event: 'payment.captured' })),
      body: { event: 'payment.captured' },
    };
    const res = await simulateRazorpayWebhook(req, mockDb);
    record('razorpayWebhook: Missing signature header rejected with 401', res.statusCode === 401);
  }

  // TEST 2: Webhook - Invalid Signature Header -> Immediate 400 Reject
  {
    const req = {
      headers: { 'x-razorpay-signature': 'invalid_tampered_signature_hex' },
      rawBody: Buffer.from(JSON.stringify({ event: 'payment.captured' })),
      body: { event: 'payment.captured' },
    };
    const res = await simulateRazorpayWebhook(req, mockDb);
    record('razorpayWebhook: Tampered signature rejected with 400', res.statusCode === 400);
  }

  // TEST 3: Webhook - Underpaid Amount (e.g. Attacker paid 1 Rupee for 199 Rupee order)
  {
    const bodyObj = {
      event: 'payment.captured',
      payload: {
        payment: {
          entity: {
            id: 'pay_underpaid_1',
            order_id: testOrderId,
            amount: 100, // 100 paise = ₹1 (expected ₹199 = 19900 paise)
            currency: 'INR',
            notes: { providerId: 'prov_alice', planId: 'plan_basic' },
          },
        },
      },
    };
    const rawBody = Buffer.from(JSON.stringify(bodyObj));
    const validSig = crypto.createHmac('sha256', TEST_WEBHOOK_SECRET).update(rawBody).digest('hex');

    const req = {
      headers: { 'x-razorpay-signature': validSig },
      rawBody: rawBody,
      body: bodyObj,
    };
    const res = await simulateRazorpayWebhook(req, mockDb);
    record('razorpayWebhook: Underpaid amount (कम राशि) rejected with 400', res.statusCode === 400 && res.responseData?.message === 'Underpaid amount');
  }

  // TEST 4: Webhook - Invalid Currency (e.g. USD instead of INR)
  {
    const bodyObj = {
      event: 'payment.captured',
      payload: {
        payment: {
          entity: {
            id: 'pay_usd_1',
            order_id: testOrderId,
            amount: 19900,
            currency: 'USD', // Invalid currency
            notes: { providerId: 'prov_alice', planId: 'plan_basic' },
          },
        },
      },
    };
    const rawBody = Buffer.from(JSON.stringify(bodyObj));
    const validSig = crypto.createHmac('sha256', TEST_WEBHOOK_SECRET).update(rawBody).digest('hex');

    const req = {
      headers: { 'x-razorpay-signature': validSig },
      rawBody: rawBody,
      body: bodyObj,
    };
    const res = await simulateRazorpayWebhook(req, mockDb);
    record('razorpayWebhook: Invalid currency (USD) rejected with 400', res.statusCode === 400 && res.responseData?.message === 'Invalid currency');
  }

  // TEST 5: Webhook - Valid Captured Payment -> Fulfilled & Pending Admin Approval
  {
    const bodyObj = {
      event: 'payment.captured',
      payload: {
        payment: {
          entity: {
            id: 'pay_valid_123',
            order_id: testOrderId,
            amount: 19900,
            currency: 'INR',
            notes: { providerId: 'prov_alice', planId: 'plan_basic' },
          },
        },
      },
    };
    const rawBody = Buffer.from(JSON.stringify(bodyObj));
    const validSig = crypto.createHmac('sha256', TEST_WEBHOOK_SECRET).update(rawBody).digest('hex');

    const req = {
      headers: { 'x-razorpay-signature': validSig },
      rawBody: rawBody,
      body: bodyObj,
    };
    const res = await simulateRazorpayWebhook(req, mockDb);

    const updatedPayment = await mockDb.collection('payments').doc(testOrderId).get();
    const subDoc = await mockDb.collection('subscriptions').doc(`sub_${testOrderId}`).get();
    const providerDoc = await mockDb.collection('providers').doc('prov_alice').get();

    const isSuccess = res.statusCode === 200 &&
      updatedPayment.data().status === 'success' &&
      subDoc.exists &&
      subDoc.data().amountPaidInPaise === 19900 &&
      providerDoc.data().paymentVerified === true &&
      providerDoc.data().isSubscriptionActive === false; // Strict safeguard

    record('razorpayWebhook: Valid captured payment fulfilled with pending admin activation', isSuccess);
  }

  // TEST 6: Webhook - Duplicate Event Idempotency Check
  {
    const bodyObj = {
      event: 'order.paid',
      payload: {
        order: {
          entity: {
            id: testOrderId,
            amount: 19900,
            currency: 'INR',
            notes: { providerId: 'prov_alice', planId: 'plan_basic' },
          },
        },
      },
    };
    const rawBody = Buffer.from(JSON.stringify(bodyObj));
    const validSig = crypto.createHmac('sha256', TEST_WEBHOOK_SECRET).update(rawBody).digest('hex');

    const req = {
      headers: { 'x-razorpay-signature': validSig },
      rawBody: rawBody,
      body: bodyObj,
    };
    const res = await simulateRazorpayWebhook(req, mockDb);
    record('razorpayWebhook: Duplicate webhook event idempotently returns already_fulfilled', res.statusCode === 200 && res.responseData?.message === 'already_fulfilled');
  }

  // TEST 7: Webhook - Out-of-Order payment.failed arriving AFTER payment.captured -> Protected!
  {
    const bodyObj = {
      event: 'payment.failed',
      payload: {
        payment: {
          entity: {
            id: 'pay_failed_late',
            order_id: testOrderId,
            error_code: 'BAD_REQUEST_ERROR',
          },
        },
      },
    };
    const rawBody = Buffer.from(JSON.stringify(bodyObj));
    const validSig = crypto.createHmac('sha256', TEST_WEBHOOK_SECRET).update(rawBody).digest('hex');

    const req = {
      headers: { 'x-razorpay-signature': validSig },
      rawBody: rawBody,
      body: bodyObj,
    };
    const res = await simulateRazorpayWebhook(req, mockDb);
    const paymentDoc = await mockDb.collection('payments').doc(testOrderId).get();

    const isProtected = res.statusCode === 200 &&
      res.responseData?.message === 'ignored_already_successful' &&
      paymentDoc.data().status === 'success'; // Not overwritten!

    record('razorpayWebhook: Out-of-order payment.failed does not overwrite captured payment', isProtected);
  }

  // TEST 8: verifySubscriptionPayment - Missing Authentication -> Throws unauthenticated
  {
    let threw = false;
    try {
      await simulateVerifySubscriptionPayment({
        data: {
          providerId: 'prov_bob',
          planId: 'plan_popular',
          razorpayOrderId: 'order_bob_1',
          razorpayPaymentId: 'pay_bob_1',
          razorpaySignature: 'sig',
        },
        auth: null, // No auth
      }, mockDb);
    } catch (e) {
      threw = e.message.includes('unauthenticated');
    }
    record('verifySubscriptionPayment: Unauthenticated call throws unauthenticated', threw);
  }

  // TEST 9: verifySubscriptionPayment - Caller UID Mismatch -> Throws permission-denied
  {
    let threw = false;
    try {
      await simulateVerifySubscriptionPayment({
        data: {
          providerId: 'prov_bob',
          planId: 'plan_popular',
          razorpayOrderId: 'order_bob_1',
          razorpayPaymentId: 'pay_bob_1',
          razorpaySignature: 'sig',
        },
        auth: { uid: 'different_user_charlie' },
      }, mockDb);
    } catch (e) {
      threw = e.message.includes('permission-denied: UID mismatch');
    }
    record('verifySubscriptionPayment: Caller UID mismatch throws permission-denied', threw);
  }

  // TEST 10: verifySubscriptionPayment - Non-existent Order in DB -> Throws failed-precondition
  {
    let threw = false;
    const paymentId = 'pay_bob_dummy';
    const orderId = 'order_nonexistent_99';
    const sig = crypto.createHmac('sha256', TEST_KEY_SECRET).update(`${orderId}|${paymentId}`).digest('hex');
    try {
      await simulateVerifySubscriptionPayment({
        data: {
          providerId: 'prov_bob',
          planId: 'plan_popular',
          razorpayOrderId: orderId,
          razorpayPaymentId: paymentId,
          razorpaySignature: sig,
        },
        auth: { uid: 'prov_bob' },
      }, mockDb);
    } catch (e) {
      threw = e.message.includes('failed-precondition: Order record not found');
    }
    record('verifySubscriptionPayment: Non-existent order in Firestore throws failed-precondition', threw);
  }

  // TEST 11: verifySubscriptionPayment - Provider UID Mismatch in Order -> Throws permission-denied
  {
    const bobOrderId = 'order_bob_2';
    // Order belongs to prov_alice, but bob tries to claim it
    await mockDb.collection('payments').doc(bobOrderId).set({
      id: bobOrderId,
      orderId: bobOrderId,
      providerId: 'prov_alice', // belongs to Alice
      planId: 'plan_popular',
      amount: 399.0,
      amountInPaise: 39900,
      currency: 'INR',
      status: 'created',
    });

    let threw = false;
    const paymentId = 'pay_bob_fake';
    const sig = crypto.createHmac('sha256', TEST_KEY_SECRET).update(`${bobOrderId}|${paymentId}`).digest('hex');
    try {
      await simulateVerifySubscriptionPayment({
        data: {
          providerId: 'prov_bob',
          planId: 'plan_popular',
          razorpayOrderId: bobOrderId,
          razorpayPaymentId: paymentId,
          razorpaySignature: sig,
        },
        auth: { uid: 'prov_bob' },
      }, mockDb);
    } catch (e) {
      threw = e.message.includes('permission-denied: Order provider mismatch');
    }
    record('verifySubscriptionPayment: Claiming another provider order throws permission-denied', threw);
  }

  // TEST 12: verifySubscriptionPayment - Plan ID Mismatch in Order -> Throws invalid-argument
  {
    const planMismatchOrderId = 'order_plan_mismatch';
    await mockDb.collection('payments').doc(planMismatchOrderId).set({
      id: planMismatchOrderId,
      orderId: planMismatchOrderId,
      providerId: 'prov_bob',
      planId: 'plan_basic', // Order was for plan_basic
      amount: 199.0,
      amountInPaise: 19900,
      currency: 'INR',
      status: 'created',
    });

    let threw = false;
    const paymentId = 'pay_bob_p1';
    const sig = crypto.createHmac('sha256', TEST_KEY_SECRET).update(`${planMismatchOrderId}|${paymentId}`).digest('hex');
    try {
      await simulateVerifySubscriptionPayment({
        data: {
          providerId: 'prov_bob',
          planId: 'plan_popular', // Caller tries to claim plan_popular!
          razorpayOrderId: planMismatchOrderId,
          razorpayPaymentId: paymentId,
          razorpaySignature: sig,
        },
        auth: { uid: 'prov_bob' },
      }, mockDb);
    } catch (e) {
      threw = e.message.includes('invalid-argument: Order plan mismatch');
    }
    record('verifySubscriptionPayment: Plan ID mismatch throws invalid-argument', threw);
  }

  // TEST 13: verifySubscriptionPayment - Razorpay Live API Underpaid Payment Detection
  {
    const underpaidOrderId = 'order_bob_underpaid';
    await mockDb.collection('payments').doc(underpaidOrderId).set({
      id: underpaidOrderId,
      orderId: underpaidOrderId,
      providerId: 'prov_bob',
      planId: 'plan_popular',
      amount: 399.0,
      amountInPaise: 39900,
      currency: 'INR',
      status: 'created',
    });

    const paymentId = 'pay_bob_cheap';
    const sig = crypto.createHmac('sha256', TEST_KEY_SECRET).update(`${underpaidOrderId}|${paymentId}`).digest('hex');

    const mockRzpClient = {
      payments: {
        fetch: async (id) => ({
          id,
          order_id: underpaidOrderId,
          status: 'captured',
          amount: 500, // Attacker paid ₹5 instead of ₹399 (39900 paise)
          currency: 'INR',
        }),
      },
    };

    let threw = false;
    try {
      await simulateVerifySubscriptionPayment({
        data: {
          providerId: 'prov_bob',
          planId: 'plan_popular',
          razorpayOrderId: underpaidOrderId,
          razorpayPaymentId: paymentId,
          razorpaySignature: sig,
        },
        auth: { uid: 'prov_bob' },
      }, mockDb, mockRzpClient);
    } catch (e) {
      threw = e.message.includes('Underpaid amount in Razorpay payment');
    }
    record('verifySubscriptionPayment: Underpaid amount in Razorpay API throws invalid-argument', threw);
  }

  // TEST 14: verifySubscriptionPayment - Full Successful Verified Flow
  {
    const legitOrderId = 'order_bob_legit_1';
    await mockDb.collection('payments').doc(legitOrderId).set({
      id: legitOrderId,
      orderId: legitOrderId,
      providerId: 'prov_bob',
      planId: 'plan_popular',
      amount: 399.0,
      amountInPaise: 39900,
      currency: 'INR',
      status: 'created',
    });

    const paymentId = 'pay_bob_legit_100';
    const sig = crypto.createHmac('sha256', TEST_KEY_SECRET).update(`${legitOrderId}|${paymentId}`).digest('hex');

    const mockRzpClient = {
      payments: {
        fetch: async (id) => ({
          id,
          order_id: legitOrderId,
          status: 'captured',
          amount: 39900,
          currency: 'INR',
        }),
      },
    };

    const result = await simulateVerifySubscriptionPayment({
      data: {
        providerId: 'prov_bob',
        planId: 'plan_popular',
        razorpayOrderId: legitOrderId,
        razorpayPaymentId: paymentId,
        razorpaySignature: sig,
      },
      auth: { uid: 'prov_bob' },
    }, mockDb, mockRzpClient);

    const paymentDoc = await mockDb.collection('payments').doc(legitOrderId).get();
    const subDoc = await mockDb.collection('subscriptions').doc(`sub_${legitOrderId}`).get();
    const provDoc = await mockDb.collection('providers').doc('prov_bob').get();

    const isSuccess = result.success === true &&
      paymentDoc.data().status === 'success' &&
      subDoc.exists &&
      subDoc.data().amountPaidInPaise === 39900 &&
      provDoc.data().paymentVerified === true &&
      provDoc.data().isSubscriptionActive === false; // Strict safeguard

    record('verifySubscriptionPayment: Valid payment successfully verified & pending admin approval', isSuccess);
  }

  console.log('\n===============================================================');
  console.log(`  ALL ${total} SECURITY AUDIT TESTS COMPLETED: ${passed}/${total} PASSED`);
  console.log('===============================================================\n');

  if (passed !== total) {
    process.exit(1);
  }
}

runTests().catch(err => {
  console.error('Fatal test error:', err);
  process.exit(1);
});
