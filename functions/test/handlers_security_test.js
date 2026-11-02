/**
 * Jamui Services - Direct Exported Handlers Security Test Suite
 * Tests the ACTUAL exported Cloud Functions handlers in `functions/index.js`
 * with safe in-memory mocked Firestore and Razorpay API responses.
 *
 * Verifies:
 * 1. Concurrency safety (Firestore runTransaction / OCC)
 * 2. Pricing immutability (snapshots in order creation, rejection of live price reliance)
 * 3. Captured payment invariants (rejection of 'authorized', 'failed', uncaptured)
 * 4. Fail-closed network and API handling
 * 5. Webhook signature, idempotency, and late failure protection
 * 6. Legacy record fail-closed manual reconciliation requirement
 */

const assert = require('assert');
const crypto = require('crypto');
const EventEmitter = require('events');
const admin = require('firebase-admin');

// 1. In-Memory Mock Database with OCC runTransaction support
class MockFirestore {
  constructor() {
    this.store = {};
    this.docVersions = new Map();
  }

  reset(initialData = {}) {
    this.store = JSON.parse(JSON.stringify(initialData));
    this.docVersions = new Map();
    for (const coll of Object.keys(this.store)) {
      for (const id of Object.keys(this.store[coll])) {
        this.docVersions.set(`${coll}/${id}`, 1);
      }
    }
  }

  getSnapshot() {
    return JSON.parse(JSON.stringify(this.store));
  }

  collection(collName) {
    const self = this;
    function makeQuery(filters = [], limitCount = null) {
      return {
        where(field, op, val) {
          return makeQuery([...filters, { field, op, val }], limitCount);
        },
        limit(n) {
          return makeQuery(filters, n);
        },
        async get() {
          const docsMap = self.store[collName] || {};
          let matches = Object.entries(docsMap).map(([id, data]) => ({ id, data }));
          for (const f of filters) {
            matches = matches.filter(m => {
              if (f.op === '==') return m.data[f.field] === f.val;
              if (f.op === '!=') return m.data[f.field] !== f.val;
              if (f.op === '>') return m.data[f.field] > f.val;
              if (f.op === '<') return m.data[f.field] < f.val;
              if (f.op === '>=') return m.data[f.field] >= f.val;
              if (f.op === '<=') return m.data[f.field] <= f.val;
              return true;
            });
          }
          if (limitCount !== null) {
            matches = matches.slice(0, limitCount);
          }
          const docs = matches.map(m => ({
            id: m.id,
            path: `${collName}/${m.id}`,
            exists: true,
            data: () => JSON.parse(JSON.stringify(m.data)),
          }));
          return {
            empty: docs.length === 0,
            size: docs.length,
            docs,
          };
        },
      };
    }

    const query = makeQuery();
    return {
      doc: (docId) => {
        const id = docId || `auto_${Math.random().toString(36).substring(2, 10)}`;
        const docPath = `${collName}/${id}`;
        return {
          path: docPath,
          collName,
          id,
          get: async () => {
            const data = this.store[collName]?.[id];
            return {
              exists: !!data,
              id,
              data: () => (data ? JSON.parse(JSON.stringify(data)) : undefined),
            };
          },
          set: async (data, options = {}) => {
            if (!this.store[collName]) this.store[collName] = {};
            if (options.merge && this.store[collName][id]) {
              this.store[collName][id] = { ...this.store[collName][id], ...JSON.parse(JSON.stringify(data)) };
            } else {
              this.store[collName][id] = JSON.parse(JSON.stringify(data));
            }
            this.docVersions.set(docPath, (this.docVersions.get(docPath) || 0) + 1);
          },
          update: async (data) => {
            if (!this.store[collName]?.[id]) {
              throw new Error(`Doc ${collName}/${id} not found`);
            }
            this.store[collName][id] = { ...this.store[collName][id], ...JSON.parse(JSON.stringify(data)) };
            this.docVersions.set(docPath, (this.docVersions.get(docPath) || 0) + 1);
          },
        };
      },
      where: query.where,
      limit: query.limit,
      get: query.get,
    };
  }

  batch() {
    const operations = [];
    return {
      set: (docRef, data, options) => operations.push({ type: 'set', docRef, data, options }),
      update: (docRef, data) => operations.push({ type: 'update', docRef, data }),
      commit: async () => {
        for (const op of operations) {
          if (op.type === 'set') await op.docRef.set(op.data, op.options);
          if (op.type === 'update') await op.docRef.update(op.data);
        }
      },
    };
  }

  async runTransaction(updateFunction) {
    let attempts = 0;
    const maxAttempts = 10;

    while (attempts < maxAttempts) {
      attempts++;
      const readVersions = new Map();
      const writes = [];

      const transaction = {
        get: async (docRef) => {
          const snap = await docRef.get();
          readVersions.set(docRef.path, this.docVersions.get(docRef.path) || 0);
          return snap;
        },
        set: (docRef, data, options = {}) => {
          writes.push({ type: 'set', docRef, data, options });
        },
        update: (docRef, data) => {
          writes.push({ type: 'update', docRef, data });
        },
        delete: (docRef) => {
          writes.push({ type: 'delete', docRef });
        },
      };

      const result = await updateFunction(transaction);

      // Concurrency check: verify that no documents read during transaction were modified concurrently
      let conflict = false;
      for (const [path, versionAtRead] of readVersions.entries()) {
        const currentVersion = this.docVersions.get(path) || 0;
        if (currentVersion !== versionAtRead) {
          conflict = true;
          break;
        }
      }

      if (conflict) {
        // Yield momentarily to let concurrent transaction complete, then auto-retry
        await new Promise((r) => setTimeout(r, 10));
        continue;
      }

      // No conflict: commit transaction writes atomically
      for (const op of writes) {
        if (op.type === 'set') {
          await op.docRef.set(op.data, op.options);
        } else if (op.type === 'update') {
          await op.docRef.update(op.data);
        } else if (op.type === 'delete') {
          const parts = op.docRef.path.split('/');
          if (this.store[parts[0]]) delete this.store[parts[0]][parts[1]];
          this.docVersions.set(op.docRef.path, (this.docVersions.get(op.docRef.path) || 0) + 1);
        }
      }

      return result;
    }

    throw new Error('Transaction failed after maximum retries due to contention.');
  }
}

const mockDb = new MockFirestore();

// Intercept admin.firestore() on prototype so index.js receives mockDb
const firestoreFn = () => mockDb;
firestoreFn.FieldValue = {
  serverTimestamp: () => new Date().toISOString(),
};
firestoreFn.Timestamp = {
  fromDate: (date) => ({
    _seconds: Math.floor(date.getTime() / 1000),
    _nanoseconds: 0,
    toDate: () => date,
    toISOString: () => date.toISOString(),
    toJSON: () => date.toISOString(),
  }),
  now: () => {
    const d = new Date();
    return {
      _seconds: Math.floor(d.getTime() / 1000),
      _nanoseconds: 0,
      toDate: () => d,
      toISOString: () => d.toISOString(),
      toJSON: () => d.toISOString(),
    };
  },
};

Object.defineProperty(Object.getPrototypeOf(admin), 'firestore', {
  value: firestoreFn,
  configurable: true,
  writable: true,
});

// Intercept admin.auth() on prototype
const authFn = () => ({
  getUser: async (uid) => ({
    uid,
    phoneNumber: '+919999999999',
    email: `${uid}@jamuiservices.com`,
  }),
});
Object.defineProperty(Object.getPrototypeOf(admin), 'auth', {
  value: authFn,
  configurable: true,
  writable: true,
});

// Configure test environment secrets
const TEST_KEY_ID = 'rzp_test_sec_key_12345';
const TEST_KEY_SECRET = 'sec_alphanumeric_secret_987654';
const TEST_WEBHOOK_SECRET = 'webhook_secret_xyz789';

process.env.RAZORPAY_KEY_ID = TEST_KEY_ID;
process.env.RAZORPAY_KEY_SECRET = TEST_KEY_SECRET;
process.env.RAZORPAY_WEBHOOK_SECRET = TEST_WEBHOOK_SECRET;

// Stub Razorpay class via require.cache so new Razorpay() returns our mock
let mockFetchImplementation = null;
let mockCreateOrderImplementation = null;
let mockFetchPaymentsImplementation = null;
let mockFetchOrderImplementation = null;

class MockRazorpay {
  constructor(options) {
    this.key_id = options.key_id;
    this.key_secret = options.key_secret;
    this.payments = {
      fetch: async (paymentId) => {
        if (mockFetchImplementation) {
          return await mockFetchImplementation(paymentId);
        }
        return {
          id: paymentId,
          order_id: 'order_default_mock',
          status: 'captured',
          amount: 19900,
          currency: 'INR',
        };
      },
    };
    this.orders = {
      create: async (options) => {
        if (mockCreateOrderImplementation) {
          return await mockCreateOrderImplementation(options);
        }
        return {
          id: `order_mock_${Date.now()}`,
          entity: 'order',
          amount: options.amount,
          amount_paid: 0,
          amount_due: options.amount,
          currency: options.currency || 'INR',
          receipt: options.receipt,
          status: 'created',
          notes: options.notes,
        };
      },
      fetch: async (orderId) => {
        if (mockFetchOrderImplementation) {
          return await mockFetchOrderImplementation(orderId);
        }
        return {
          id: orderId,
          entity: 'order',
          amount: 2000,
          currency: 'INR',
          status: 'paid',
          notes: {
            providerId: 'prov_alice',
            planId: 'jP3p8pl3upBi7b8GShhw',
          },
        };
      },
      fetchPayments: async (orderId) => {
        if (mockFetchPaymentsImplementation) {
          return await mockFetchPaymentsImplementation(orderId);
        }
        return {
          entity: 'collection',
          count: 1,
          items: [
            {
              id: 'pay_mock_reconciled_1',
              order_id: orderId,
              status: 'captured',
              captured: true,
              amount: 2000,
              currency: 'INR',
              method: 'upi',
              notes: {
                providerId: 'prov_alice',
                planId: 'jP3p8pl3upBi7b8GShhw',
              },
            },
          ],
        };
      },
    };
  }
}

require.cache[require.resolve('razorpay')] = {
  exports: MockRazorpay,
};

// Mock Response for Express Webhook handler
class MockResponse extends EventEmitter {
  constructor() {
    super();
    this.statusCode = 200;
    this.body = null;
    this.headers = {};
  }
  status(code) {
    this.statusCode = code;
    return this;
  }
  send(body) {
    this.body = body;
    this.emit('finish');
    return this;
  }
  json(obj) {
    this.body = obj;
    this.emit('finish');
    return this;
  }
  setHeader(k, v) {
    this.headers[k] = v;
  }
  getHeader(k) {
    return this.headers[k];
  }
  end() {
    this.emit('finish');
    return this;
  }
}

// Require the ACTUAL exported handlers
const handlers = require('../index.js');

// Helper to seed initial store state
function seedDefaultStore() {
  return {
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
    admin_users: {
      'admin_super': { role: 'super_admin' },
    },
    subscription_plans: {
      'jP3p8pl3upBi7b8GShhw': {
        id: 'jP3p8pl3upBi7b8GShhw',
        name: 'Basic',
        price: 20.0,
        durationDays: 30,
        categoryLimit: 1,
        isActive: true,
        targetAudience: 'new_provider',
      },
      'plan_basic': { id: 'plan_basic', name: 'Basic Starter', price: 199.0, durationDays: 30, categoryLimit: 1, isActive: true },
      'plan_popular': { id: 'plan_popular', name: 'Standard Pro', price: 399.0, durationDays: 30, categoryLimit: 3, isActive: true },
      'plan_annual': { id: 'plan_annual', name: 'Premium Yearly', price: 2999.0, durationDays: 365, categoryLimit: 5, isActive: true },
    },
    payments: {},
    subscriptions: {},
    audit_logs: {},
  };
}

async function runHandlerSecurityTests() {
  console.log('======================================================================');
  console.log(' JAMUI SERVICES — COMPREHENSIVE SECURITY & CONCURRENCY TEST SUITE   ');
  console.log(' Testing ACTUAL functions/index.js handlers (Firestore OCC & Security) ');
  console.log('======================================================================\n');

  let passed = 0;
  let total = 0;

  function record(testName, success, details = '') {
    total++;
    if (success) {
      passed++;
      console.log(`✅ [PASS] Test ${total}: ${testName}`);
    } else {
      console.error(`❌ [FAIL] Test ${total}: ${testName} - ${details}`);
    }
  }

  // ---------------------------------------------------------------------------------
  // TEST 1: verifySubscriptionPayment - 'authorized' payment REJECTED (Fail-Closed)
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    const orderId = 'order_auth_only_1';
    await mockDb.collection('payments').doc(orderId).set({
      id: orderId,
      orderId: orderId,
      providerId: 'prov_alice',
      planId: 'plan_basic',
      amount: 199.0,
      amountInPaise: 19900,
      currency: 'INR',
      status: 'created',
    });

    const paymentId = 'pay_authorized_123';
    const sig = crypto.createHmac('sha256', TEST_KEY_SECRET).update(`${orderId}|${paymentId}`).digest('hex');

    mockFetchImplementation = async (id) => ({
      id,
      order_id: orderId,
      status: 'authorized', // NOT captured!
      amount: 19900,
      currency: 'INR',
    });

    let threw = false;
    let errorMessage = '';
    try {
      await handlers.verifySubscriptionPayment.run({
        data: {
          providerId: 'prov_alice',
          planId: 'plan_basic',
          razorpayOrderId: orderId,
          razorpayPaymentId: paymentId,
          razorpaySignature: sig,
        },
        auth: { uid: 'prov_alice' },
      });
    } catch (e) {
      threw = true;
      errorMessage = e.message || '';
    }

    const paymentDoc = await mockDb.collection('payments').doc(orderId).get();
    const isProtected = threw &&
      (errorMessage.includes('Captured') || errorMessage.includes('captured')) &&
      paymentDoc.data().status === 'created' &&
      !paymentDoc.data().captured;

    record("verifySubscriptionPayment: 'authorized' uncaptured payment rejected with failed-precondition", isProtected);
  }

  // ---------------------------------------------------------------------------------
  // TEST 2: verifySubscriptionPayment - Razorpay API Error / Network Timeout Fail-Closed
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    const orderId = 'order_timeout_1';
    await mockDb.collection('payments').doc(orderId).set({
      id: orderId,
      orderId: orderId,
      providerId: 'prov_alice',
      planId: 'plan_basic',
      amount: 199.0,
      amountInPaise: 19900,
      currency: 'INR',
      status: 'created',
    });

    const paymentId = 'pay_timeout_123';
    const sig = crypto.createHmac('sha256', TEST_KEY_SECRET).update(`${orderId}|${paymentId}`).digest('hex');

    mockFetchImplementation = async () => {
      throw new Error('ETIMEDOUT: Connection to api.razorpay.com timed out.');
    };

    let threw = false;
    let errorMessage = '';
    try {
      await handlers.verifySubscriptionPayment.run({
        data: {
          providerId: 'prov_alice',
          planId: 'plan_basic',
          razorpayOrderId: orderId,
          razorpayPaymentId: paymentId,
          razorpaySignature: sig,
        },
        auth: { uid: 'prov_alice' },
      });
    } catch (e) {
      threw = true;
      errorMessage = e.message || '';
    }

    const paymentDoc = await mockDb.collection('payments').doc(orderId).get();
    const isFailClosed = threw &&
      (errorMessage.includes('संपर्क नहीं हो सका') || errorMessage.includes('failed')) &&
      paymentDoc.data().status === 'created';

    record("verifySubscriptionPayment: Razorpay API timeout/error fails-closed with internal error", isFailClosed);
  }

  // ---------------------------------------------------------------------------------
  // TEST 3: verifySubscriptionPayment - Genuine 'captured' payment succeeds
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    const orderId = 'order_valid_captured_1';
    await mockDb.collection('payments').doc(orderId).set({
      id: orderId,
      orderId: orderId,
      providerId: 'prov_alice',
      planId: 'plan_basic',
      amount: 199.0,
      amountInPaise: 19900,
      currency: 'INR',
      status: 'created',
    });

    const paymentId = 'pay_captured_456';
    const sig = crypto.createHmac('sha256', TEST_KEY_SECRET).update(`${orderId}|${paymentId}`).digest('hex');

    mockFetchImplementation = async (id) => ({
      id,
      order_id: orderId,
      status: 'captured',
      amount: 19900,
      currency: 'INR',
    });

    let res = null;
    try {
      res = await handlers.verifySubscriptionPayment.run({
        data: {
          providerId: 'prov_alice',
          planId: 'plan_basic',
          razorpayOrderId: orderId,
          razorpayPaymentId: paymentId,
          razorpaySignature: sig,
        },
        auth: { uid: 'prov_alice' },
      });
    } catch (e) {
      console.error('Test 3 error:', e);
    }

    const paymentDoc = await mockDb.collection('payments').doc(orderId).get();
    const isSuccess = res && res.success &&
      paymentDoc.data().status === 'success' &&
      paymentDoc.data().captured === true &&
      paymentDoc.data().liveVerified === true &&
      paymentDoc.data().adminApprovalStatus === 'pending_approval';

    record("verifySubscriptionPayment: Valid 'captured' payment verified with captured: true", isSuccess);
  }

  // ---------------------------------------------------------------------------------
  // TEST 4: verifySubscriptionPayment - Unequal amount (19901 vs 19900) rejected
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    const orderId = 'order_amt_mismatch';
    await mockDb.collection('payments').doc(orderId).set({
      id: orderId,
      orderId: orderId,
      providerId: 'prov_alice',
      planId: 'plan_basic',
      amount: 199.0,
      amountInPaise: 19900,
      currency: 'INR',
      status: 'created',
    });

    const paymentId = 'pay_amt_1';
    const sig = crypto.createHmac('sha256', TEST_KEY_SECRET).update(`${orderId}|${paymentId}`).digest('hex');

    mockFetchImplementation = async (id) => ({
      id,
      order_id: orderId,
      status: 'captured',
      amount: 19901,
      currency: 'INR',
    });

    let threw = false;
    try {
      await handlers.verifySubscriptionPayment.run({
        data: {
          providerId: 'prov_alice',
          planId: 'plan_basic',
          razorpayOrderId: orderId,
          razorpayPaymentId: paymentId,
          razorpaySignature: sig,
        },
        auth: { uid: 'prov_alice' },
      });
    } catch (e) {
      threw = e.message.includes('Paid amount') || e.message.includes('अंतर');
    }

    record("verifySubscriptionPayment: Unequal amount (19901 vs 19900) rejected with invalid-argument", threw);
  }

  // ---------------------------------------------------------------------------------
  // TEST 5: verifySubscriptionPayment - Order ID mismatch in Razorpay API
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    const orderId = 'order_legit_5';
    await mockDb.collection('payments').doc(orderId).set({
      id: orderId,
      orderId: orderId,
      providerId: 'prov_alice',
      planId: 'plan_basic',
      amount: 199.0,
      amountInPaise: 19900,
      currency: 'INR',
      status: 'created',
    });

    const paymentId = 'pay_wrong_order_5';
    const sig = crypto.createHmac('sha256', TEST_KEY_SECRET).update(`${orderId}|${paymentId}`).digest('hex');

    mockFetchImplementation = async (id) => ({
      id,
      order_id: 'order_different_999',
      status: 'captured',
      amount: 19900,
      currency: 'INR',
    });

    let threw = false;
    try {
      await handlers.verifySubscriptionPayment.run({
        data: {
          providerId: 'prov_alice',
          planId: 'plan_basic',
          razorpayOrderId: orderId,
          razorpayPaymentId: paymentId,
          razorpaySignature: sig,
        },
        auth: { uid: 'prov_alice' },
      });
    } catch (e) {
      threw = e.message.includes('Razorpay payment does not match the specified order');
    }

    record("verifySubscriptionPayment: Razorpay order_id mismatch rejected with permission-denied", threw);
  }

  // ---------------------------------------------------------------------------------
  // TEST 6: adminApproveSubscription - Two simultaneous concurrent admin approvals (OCC Safety)
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    const orderId = 'order_concurrent_approval';
    await mockDb.collection('payments').doc(orderId).set({
      id: orderId,
      orderId: orderId,
      paymentId: 'pay_concurrent_123',
      providerId: 'prov_alice',
      planId: 'plan_basic',
      amount: 199.0,
      amountInPaise: 19900,
      currency: 'INR',
      status: 'success',
      captured: true,
      liveVerified: true,
      adminApprovalStatus: 'pending_approval',
    });

    const reqData = { providerId: 'prov_alice', orderId: orderId };
    const authCtx = { uid: 'admin_super', token: { email: 'admin@jamuiservice.com' } };

    // Fire two concurrent approval calls simultaneously
    const [resA, resB] = await Promise.allSettled([
      handlers.adminApproveSubscription.run({ data: reqData, auth: authCtx }),
      handlers.adminApproveSubscription.run({ data: reqData, auth: authCtx }),
    ]);

    const successes = [resA, resB].filter((r) => r.status === 'fulfilled' && r.value?.success);
    const rejections = [resA, resB].filter((r) => r.status === 'rejected');

    const provDoc = await mockDb.collection('providers').doc('prov_alice').get();
    const payDoc = await mockDb.collection('payments').doc(orderId).get();
    const auditLogs = mockDb.store['audit_logs'] || {};
    const auditCount = Object.keys(auditLogs).length;

    // Concurrency guarantee: EXACTLY ONE succeeds, EXACTLY ONE rejected with duplicate error,
    // exactly ONE audit log created, subscription active.
    const isRaceSafe = successes.length === 1 &&
      rejections.length === 1 &&
      rejections[0].reason.message.includes('already been approved and activated') &&
      provDoc.data().isSubscriptionActive === true &&
      payDoc.data().adminApprovalStatus === 'approved' &&
      auditCount === 1;

    record("adminApproveSubscription: Two simultaneous concurrent admin approval requests (OCC Concurrency Safe)", isRaceSafe);
  }

  // ---------------------------------------------------------------------------------
  // TEST 7: adminApproveSubscription - Repeated / duplicate approval rejected
  // ---------------------------------------------------------------------------------
  {
    const orderId = 'order_concurrent_approval';
    let threw = false;
    try {
      await handlers.adminApproveSubscription.run({
        data: { providerId: 'prov_alice', orderId },
        auth: { uid: 'admin_super', token: { email: 'admin@jamuiservice.com' } },
      });
    } catch (e) {
      threw = e.message.includes('already been approved and activated');
    }

    record("adminApproveSubscription: Repeated / duplicate request to approve same order rejected with failed-precondition", threw);
  }

  // ---------------------------------------------------------------------------------
  // TEST 8: adminApproveSubscription - Reject if payment is NOT captured
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    const orderId = 'order_uncaptured_admin_test';
    await mockDb.collection('payments').doc(orderId).set({
      id: orderId,
      orderId: orderId,
      paymentId: 'pay_un_cap_1',
      providerId: 'prov_alice',
      planId: 'plan_basic',
      amount: 199.0,
      amountInPaise: 19900,
      currency: 'INR',
      status: 'success',
      captured: false, // NOT CAPTURED!
      liveVerified: false,
    });

    let threw = false;
    let errorMsg = '';
    try {
      await handlers.adminApproveSubscription.run({
        data: { providerId: 'prov_alice', orderId },
        auth: { uid: 'admin_super', token: { email: 'admin@jamuiservice.com' } },
      });
    } catch (e) {
      threw = true;
      errorMsg = e.message || '';
    }

    const provDoc = await mockDb.collection('providers').doc('prov_alice').get();
    const isBlocked = threw &&
      errorMsg.includes('captured') &&
      provDoc.data().isSubscriptionActive === false;

    record("adminApproveSubscription: Uncaptured payment rejected from activation", isBlocked);
  }

  // ---------------------------------------------------------------------------------
  // TEST 9: adminApproveSubscription - Plan price changed in Firestore after order creation
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    const orderId = 'order_price_increased_1';
    // Order was created and paid when plan was ₹199 (19900 paise)
    await mockDb.collection('payments').doc(orderId).set({
      id: orderId,
      orderId: orderId,
      paymentId: 'pay_old_price_123',
      providerId: 'prov_alice',
      planId: 'plan_basic',
      amount: 199.0,
      amountInPaise: 19900,
      currency: 'INR',
      status: 'success',
      captured: true,
      liveVerified: true,
      adminApprovalStatus: 'pending_approval',
      pricingSnapshot: {
        planId: 'plan_basic',
        amount: 199.0,
        amountInPaise: 19900,
        basePriceInRupees: 199.0,
        basePriceInPaise: 19900,
        currency: 'INR',
        durationDays: 30,
        categoryLimit: 1,
      },
    });

    // An administrator now increases the live plan price in Firestore to ₹249 (24900 paise)!
    await mockDb.collection('subscription_plans').doc('plan_basic').update({
      price: 249.0,
    });

    let success = false;
    try {
      const res = await handlers.adminApproveSubscription.run({
        data: { providerId: 'prov_alice', orderId },
        auth: { uid: 'admin_super', token: { email: 'admin@jamuiservice.com' } },
      });
      success = res && res.success;
    } catch (e) {
      console.error('Test 9 unexpected error:', e);
    }

    const provDoc = await mockDb.collection('providers').doc('prov_alice').get();
    const isApprovedWithOldSnapshot = success && provDoc.data().isSubscriptionActive === true;

    record("adminApproveSubscription: Plan price changed after order creation (Old valid order approved via immutable snapshot)", isApprovedWithOldSnapshot);
  }

  // ---------------------------------------------------------------------------------
  // TEST 10: adminApproveSubscription - Discounted order exact captured amount verified
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    const orderId = 'order_discounted_1';
    // Order was created with a ₹20 discount: ₹199 - ₹20 = ₹179 (17900 paise)
    await mockDb.collection('payments').doc(orderId).set({
      id: orderId,
      orderId: orderId,
      paymentId: 'pay_discounted_cap_789',
      providerId: 'prov_alice',
      planId: 'plan_basic',
      amount: 179.0,
      amountInPaise: 17900,
      discountApplied: 20.0,
      currency: 'INR',
      status: 'success',
      captured: true,
      liveVerified: true,
      adminApprovalStatus: 'pending_approval',
      pricingSnapshot: {
        planId: 'plan_basic',
        amount: 179.0,
        amountInPaise: 17900,
        basePriceInRupees: 199.0,
        basePriceInPaise: 19900,
        discountApplied: 20.0,
        currency: 'INR',
        durationDays: 30,
        categoryLimit: 1,
      },
    });

    let success = false;
    try {
      const res = await handlers.adminApproveSubscription.run({
        data: { providerId: 'prov_alice', orderId },
        auth: { uid: 'admin_super', token: { email: 'admin@jamuiservice.com' } },
      });
      success = res && res.success;
    } catch (e) {
      console.error('Test 10 error:', e);
    }

    const provDoc = await mockDb.collection('providers').doc('prov_alice').get();
    const isDiscountApproved = success &&
      provDoc.data().isSubscriptionActive === true &&
      provDoc.data().paymentAmountInPaise === 17900;

    record("adminApproveSubscription: Discounted order exact captured amount verified and approved", isDiscountApproved);
  }

  // ---------------------------------------------------------------------------------
  // TEST 11: adminApproveSubscription - Captured amount mismatch or tampering rejected
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    const orderId = 'order_tampered_paise';
    // Tampered: amount says 199.0 but amountInPaise was changed to 15000 paise (or tampered snapshot)
    await mockDb.collection('payments').doc(orderId).set({
      id: orderId,
      orderId: orderId,
      paymentId: 'pay_tampered_1',
      providerId: 'prov_alice',
      planId: 'plan_basic',
      amount: 199.0,
      amountInPaise: 15000, // Inconsistent with amount 199.0 (19900 paise)!
      currency: 'INR',
      status: 'success',
      captured: true,
      liveVerified: true,
      adminApprovalStatus: 'pending_approval',
    });

    let threw = false;
    let errorMsg = '';
    try {
      await handlers.adminApproveSubscription.run({
        data: { providerId: 'prov_alice', orderId },
        auth: { uid: 'admin_super', token: { email: 'admin@jamuiservice.com' } },
      });
    } catch (e) {
      threw = true;
      errorMsg = e.message || '';
    }

    const provDoc = await mockDb.collection('providers').doc('prov_alice').get();
    const isBlocked = threw &&
      (errorMsg.includes('Inconsistent') || errorMsg.includes('mismatch')) &&
      provDoc.data().isSubscriptionActive === false;

    record("adminApproveSubscription: Captured amount mismatch or tampering rejected", isBlocked);
  }

  // ---------------------------------------------------------------------------------
  // TEST 12: adminApproveSubscription - Legacy payment record missing immutable pricing snapshot fails closed
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    const orderId = 'order_legacy_no_paise';
    // Legacy record from old schema without amountInPaise
    await mockDb.collection('payments').doc(orderId).set({
      id: orderId,
      orderId: orderId,
      paymentId: 'pay_legacy_old_1',
      providerId: 'prov_alice',
      planId: 'plan_basic',
      amount: 199.0,
      // amountInPaise is UNDEFINED!
      currency: 'INR',
      status: 'success',
      captured: true,
      liveVerified: true,
      adminApprovalStatus: 'pending_approval',
    });

    let threw = false;
    let errorMsg = '';
    try {
      await handlers.adminApproveSubscription.run({
        data: { providerId: 'prov_alice', orderId },
        auth: { uid: 'admin_super', token: { email: 'admin@jamuiservice.com' } },
      });
    } catch (e) {
      threw = true;
      errorMsg = e.message || '';
    }

    const provDoc = await mockDb.collection('providers').doc('prov_alice').get();
    const isLegacyProtected = threw &&
      errorMsg.includes('Legacy payment record missing immutable pricing snapshot') &&
      provDoc.data().isSubscriptionActive === false;

    record("adminApproveSubscription: Legacy payment record missing immutable pricing snapshot fails closed (Manual reconciliation required)", isLegacyProtected);
  }

  // ---------------------------------------------------------------------------------
  // TEST 13: adminApproveSubscription - Active subscription date stacking preserved without double-extension
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    const futureExpiry = new Date(Date.now() + 15 * 24 * 60 * 60 * 1000); // 15 days in future
    await mockDb.collection('providers').doc('prov_alice').update({
      isSubscriptionActive: true,
      subscriptionApprovalStatus: 'approved',
      subscriptionExpiry: admin.firestore.Timestamp.fromDate(futureExpiry),
    });

    const orderId = 'order_stacking_1';
    await mockDb.collection('payments').doc(orderId).set({
      id: orderId,
      orderId: orderId,
      paymentId: 'pay_stack_1',
      providerId: 'prov_alice',
      planId: 'plan_basic',
      amount: 199.0,
      amountInPaise: 19900,
      currency: 'INR',
      status: 'success',
      captured: true,
      liveVerified: true,
      durationDays: 30,
      adminApprovalStatus: 'pending_approval',
    });

    const res = await handlers.adminApproveSubscription.run({
      data: { providerId: 'prov_alice', orderId },
      auth: { uid: 'admin_super', token: { email: 'admin@jamuiservice.com' } },
    });

    const provDoc = await mockDb.collection('providers').doc('prov_alice').get();
    const rawExpiry = provDoc.data().subscriptionExpiry;
    const computedExpiry = rawExpiry?.toDate ? rawExpiry.toDate() : new Date(rawExpiry);

    // Expiry should be exactly futureExpiry + 30 days
    const expectedExpiryTime = futureExpiry.getTime() + 30 * 24 * 60 * 60 * 1000;
    const diffMs = Math.abs(computedExpiry.getTime() - expectedExpiryTime);

    // Now try duplicate call on same order - must be rejected and expiry must not change
    let threwDuplicate = false;
    try {
      await handlers.adminApproveSubscription.run({
        data: { providerId: 'prov_alice', orderId },
        auth: { uid: 'admin_super', token: { email: 'admin@jamuiservice.com' } },
      });
    } catch (e) {
      threwDuplicate = e.message.includes('already been approved and activated');
    }

    const provDocAfter = await mockDb.collection('providers').doc('prov_alice').get();
    const rawExpiryAfter = provDocAfter.data().subscriptionExpiry;
    const computedExpiryAfter = rawExpiryAfter?.toDate ? rawExpiryAfter.toDate() : new Date(rawExpiryAfter);
    const expiryUnchanged = computedExpiryAfter.getTime() === computedExpiry.getTime();

    const isStackingCorrect = res.success &&
      diffMs < 5000 &&
      threwDuplicate &&
      expiryUnchanged;

    record("adminApproveSubscription: Active subscription duplicate approval effect & date stacking preserved without double-extension", isStackingCorrect);
  }

  // ---------------------------------------------------------------------------------
  // TEST 14: razorpayWebhook - Idempotency & Late Failure Protection
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    const orderId = 'order_webhook_test_1';
    await mockDb.collection('payments').doc(orderId).set({
      id: orderId,
      orderId: orderId,
      providerId: 'prov_bob',
      planId: 'plan_popular',
      amount: 399.0,
      amountInPaise: 39900,
      currency: 'INR',
      status: 'created',
    });

    const payloadObj = {
      event: 'payment.captured',
      payload: {
        payment: {
          entity: {
            id: 'pay_wh_1',
            order_id: orderId,
            amount: 39900,
            currency: 'INR',
            notes: { providerId: 'prov_bob', planId: 'plan_popular' },
          },
        },
      },
    };
    const rawPayload = JSON.stringify(payloadObj);
    const validSig = crypto.createHmac('sha256', TEST_WEBHOOK_SECRET).update(rawPayload).digest('hex');

    const req1 = {
      method: 'POST',
      headers: { 'x-razorpay-signature': validSig },
      rawBody: Buffer.from(rawPayload),
      body: payloadObj,
    };
    const res1 = new MockResponse();

    // First delivery
    await handlers.razorpayWebhook(req1, res1);

    // Second delivery (duplicate)
    const res2 = new MockResponse();
    await handlers.razorpayWebhook(req1, res2);

    // Out-of-order payment.failed
    const failPayloadObj = {
      event: 'payment.failed',
      payload: {
        payment: {
          entity: {
            id: 'pay_wh_late_fail',
            order_id: orderId,
            error_code: 'BAD_REQUEST',
          },
        },
      },
    };
    const failRaw = JSON.stringify(failPayloadObj);
    const failSig = crypto.createHmac('sha256', TEST_WEBHOOK_SECRET).update(failRaw).digest('hex');
    const req3 = {
      method: 'POST',
      headers: { 'x-razorpay-signature': failSig },
      rawBody: Buffer.from(failRaw),
      body: failPayloadObj,
    };
    const res3 = new MockResponse();
    await handlers.razorpayWebhook(req3, res3);

    const paymentDoc = await mockDb.collection('payments').doc(orderId).get();
    const isWebhookSafe = res2.statusCode === 200 &&
      res2.body.message === 'already_fulfilled' &&
      res3.body.message === 'ignored_already_successful' &&
      paymentDoc.data().status === 'success' &&
      paymentDoc.data().captured === true;

    record("razorpayWebhook: Duplicate delivery idempotent and late payment.failed safely ignored", isWebhookSafe);
  }

  // ---------------------------------------------------------------------------------
  // TEST 15: razorpayWebhook - Dedicated webhook secret absent fails closed with 401
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    const savedEnvWebhook = process.env.RAZORPAY_WEBHOOK_SECRET;
    delete process.env.RAZORPAY_WEBHOOK_SECRET;
    await mockDb.collection('app_config').doc('payment_secrets').set({
      keySecret: TEST_KEY_SECRET,
      webhookSecret: '', // No dedicated webhook secret!
    });

    const payloadObj = { event: 'payment.captured', payload: { payment: { entity: { id: 'pay_wh_test', amount: 39900 } } } };
    const rawPayload = JSON.stringify(payloadObj);
    const someSig = crypto.createHmac('sha256', 'any_secret').update(rawPayload).digest('hex');

    const req = {
      method: 'POST',
      headers: { 'x-razorpay-signature': someSig },
      rawBody: Buffer.from(rawPayload),
      body: payloadObj,
    };
    const res = new MockResponse();
    await handlers.razorpayWebhook(req, res);

    process.env.RAZORPAY_WEBHOOK_SECRET = savedEnvWebhook;

    const isFailClosed = res.statusCode === 401 && res.body.includes('Missing Signature or Secret');
    record("razorpayWebhook: Dedicated webhook secret absent fails closed with 401", isFailClosed);
  }

  // ---------------------------------------------------------------------------------
  // TEST 16: razorpayWebhook - API key secret alone does NOT bypass webhook verification
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    const savedEnvWebhook = process.env.RAZORPAY_WEBHOOK_SECRET;
    delete process.env.RAZORPAY_WEBHOOK_SECRET;
    await mockDb.collection('app_config').doc('payment_secrets').set({
      keySecret: TEST_KEY_SECRET,
      webhookSecret: '', // No webhook secret configured
    });

    // Attempt to forge signature using API keySecret
    const payloadObj = { event: 'payment.captured', payload: { payment: { entity: { id: 'pay_wh_bypass', amount: 39900 } } } };
    const rawPayload = JSON.stringify(payloadObj);
    const keySecretSig = crypto.createHmac('sha256', TEST_KEY_SECRET).update(rawPayload).digest('hex');

    const req = {
      method: 'POST',
      headers: { 'x-razorpay-signature': keySecretSig },
      rawBody: Buffer.from(rawPayload),
      body: payloadObj,
    };
    const res = new MockResponse();
    await handlers.razorpayWebhook(req, res);

    process.env.RAZORPAY_WEBHOOK_SECRET = savedEnvWebhook;

    // Must strictly be rejected with 401 (keySecret is NOT accepted as fallback!)
    const isBypassBlocked = res.statusCode === 401 && res.body.includes('Missing Signature or Secret');
    record("razorpayWebhook: API key secret alone does NOT bypass webhook verification (401 Rejection)", isBypassBlocked);
  }

  // ---------------------------------------------------------------------------------
  // TEST 17: razorpayWebhook - Tampered signature rejected with 400 and zero mutations
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    const orderId = 'order_tamper_webhook_1';
    await mockDb.collection('payments').doc(orderId).set({
      id: orderId,
      orderId: orderId,
      status: 'created',
      amountInPaise: 39900,
    });
    const preSnapshot = mockDb.getSnapshot();

    const payloadObj = { event: 'payment.captured', payload: { payment: { entity: { id: 'pay_wh_tamper', order_id: orderId, amount: 39900 } } } };
    const rawPayload = JSON.stringify(payloadObj);
    const tamperedSig = crypto.createHmac('sha256', 'wrong_fake_secret').update(rawPayload).digest('hex');

    const req = {
      method: 'POST',
      headers: { 'x-razorpay-signature': tamperedSig },
      rawBody: Buffer.from(rawPayload),
      body: payloadObj,
    };
    const res = new MockResponse();
    await handlers.razorpayWebhook(req, res);

    const postSnapshot = mockDb.getSnapshot();
    const isTamperRejected = res.statusCode === 400 &&
      res.body.includes('Invalid Signature') &&
      JSON.stringify(preSnapshot) === JSON.stringify(postSnapshot);

    record("razorpayWebhook: Tampered signature rejected with 400 and zero state mutations", isTamperRejected);
  }

  // ---------------------------------------------------------------------------------
  // TEST 18: createSubscriptionOrder - Generates Authoritative Pricing Snapshot & payment_capture = 1
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    let capturedOptions = null;
    mockCreateOrderImplementation = async (options) => {
      capturedOptions = options;
      return {
        id: 'order_sdk_auto_capture_123',
        entity: 'order',
        amount: options.amount,
        amount_paid: 0,
        currency: 'INR',
        receipt: options.receipt,
        status: 'created',
      };
    };

    const res = await handlers.createSubscriptionOrder.run({
      data: {
        planId: 'plan_basic',
        providerId: 'prov_alice',
      },
      auth: { uid: 'prov_alice' },
    });

    const paymentDoc = await mockDb.collection('payments').doc('order_sdk_auto_capture_123').get();
    const payData = paymentDoc.data() || {};

    const isOrderCreationSafe = res && res.orderId === 'order_sdk_auto_capture_123' &&
      capturedOptions && capturedOptions.payment_capture === 1 &&
      payData.amountInPaise === 19900 &&
      payData.pricingSnapshot &&
      payData.pricingSnapshot.amountInPaise === 19900 &&
      payData.pricingSnapshot.durationDays === 30 &&
      payData.pricingSnapshot.categoryLimit === 1;

    record("createSubscriptionOrder: Server-side immutable pricing snapshot generated with payment_capture = 1", isOrderCreationSafe);
    mockCreateOrderImplementation = null;
  }

  // ---------------------------------------------------------------------------------
  // TEST 19: Zero Firestore Mutation on Rejected Requests
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    const preSnapshot = mockDb.getSnapshot();

    // Call verifySubscriptionPayment with invalid caller UID
    try {
      await handlers.verifySubscriptionPayment.run({
        data: {
          providerId: 'prov_alice',
          planId: 'plan_basic',
          razorpayOrderId: 'order_nonexistent',
          razorpayPaymentId: 'pay_fake',
          razorpaySignature: 'fake_sig',
        },
        auth: { uid: 'attacker_charlie' },
      });
    } catch (_) {}

    const postSnapshot = mockDb.getSnapshot();
    const isUnmutated = JSON.stringify(preSnapshot) === JSON.stringify(postSnapshot);

    record("Security Guard: Zero Firestore mutations on rejected requests", isUnmutated);
  }

  // ---------------------------------------------------------------------------------
  // TEST 20: 30-Day Plan First Approval Flow (verifySubscriptionPayment -> adminApproveSubscription)
  // Ensures duration is applied EXACTLY ONCE (30 days, NEVER 60 days)
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    const orderId = 'order_two_step_30d';
    const paymentId = 'pay_two_step_30d';

    await mockDb.collection('payments').doc(orderId).set({
      id: orderId,
      orderId: orderId,
      providerId: 'prov_alice',
      planId: 'plan_basic',
      amount: 199.0,
      amountInPaise: 19900,
      durationDays: 30,
      currency: 'INR',
      status: 'created',
      pricingSnapshot: {
        planId: 'plan_basic',
        amountInPaise: 19900,
        durationDays: 30,
        categoryLimit: 1,
      },
    });

    const sig = crypto.createHmac('sha256', TEST_KEY_SECRET).update(`${orderId}|${paymentId}`).digest('hex');
    mockFetchImplementation = async (id) => ({
      id,
      order_id: orderId,
      status: 'captured',
      amount: 19900,
      currency: 'INR',
    });

    // Step 1: verifySubscriptionPayment
    const verifyRes = await handlers.verifySubscriptionPayment.run({
      data: {
        providerId: 'prov_alice',
        planId: 'plan_basic',
        razorpayOrderId: orderId,
        razorpayPaymentId: paymentId,
        razorpaySignature: sig,
      },
      auth: { uid: 'prov_alice' },
    });

    const provAfterVerify = (await mockDb.collection('providers').doc('prov_alice').get()).data();
    const verifyDoesNotPrematurelyExtend = provAfterVerify.isSubscriptionActive === false &&
      !provAfterVerify.subscriptionExpiry &&
      verifyRes.approvalStatus === 'pending_approval';

    // Step 2: adminApproveSubscription
    const approveRes = await handlers.adminApproveSubscription.run({
      data: { providerId: 'prov_alice', orderId },
      auth: { uid: 'admin_super', token: { email: 'admin@jamuiservice.com' } },
    });

    const provAfterApprove = (await mockDb.collection('providers').doc('prov_alice').get()).data();
    const rawStart = provAfterApprove.subscriptionStartDate;
    const rawExpiry = provAfterApprove.subscriptionExpiry;
    const startDate = rawStart?.toDate ? rawStart.toDate() : new Date(rawStart);
    const expiryDate = rawExpiry?.toDate ? rawExpiry.toDate() : new Date(rawExpiry);

    const diffDays = Math.round((expiryDate.getTime() - startDate.getTime()) / (24 * 60 * 60 * 1000));
    const isExact30Days = diffDays === 30;
    const isNotDoubled = diffDays !== 60;

    const testPassed = verifyDoesNotPrematurelyExtend &&
      approveRes.success &&
      provAfterApprove.isSubscriptionActive === true &&
      isExact30Days &&
      isNotDoubled;

    record("30-Day Plan: Two-step flow applies duration exactly ONCE (30 days, not 60 days)", testPassed, `diffDays: ${diffDays}`);
  }

  // ---------------------------------------------------------------------------------
  // TEST 21: 365-Day Annual Plan First Approval Flow (verifySubscriptionPayment -> adminApproveSubscription)
  // Ensures annual plan is applied EXACTLY ONCE (365 days, NEVER 730 days)
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    const orderId = 'order_two_step_365d';
    const paymentId = 'pay_two_step_365d';

    await mockDb.collection('payments').doc(orderId).set({
      id: orderId,
      orderId: orderId,
      providerId: 'prov_alice',
      planId: 'plan_annual',
      amount: 2999.0,
      amountInPaise: 299900,
      durationDays: 365,
      currency: 'INR',
      status: 'created',
      pricingSnapshot: {
        planId: 'plan_annual',
        amountInPaise: 299900,
        durationDays: 365,
        categoryLimit: 5,
      },
    });

    const sig = crypto.createHmac('sha256', TEST_KEY_SECRET).update(`${orderId}|${paymentId}`).digest('hex');
    mockFetchImplementation = async (id) => ({
      id,
      order_id: orderId,
      status: 'captured',
      amount: 299900,
      currency: 'INR',
    });

    await handlers.verifySubscriptionPayment.run({
      data: {
        providerId: 'prov_alice',
        planId: 'plan_annual',
        razorpayOrderId: orderId,
        razorpayPaymentId: paymentId,
        razorpaySignature: sig,
      },
      auth: { uid: 'prov_alice' },
    });

    const approveRes = await handlers.adminApproveSubscription.run({
      data: { providerId: 'prov_alice', orderId },
      auth: { uid: 'admin_super', token: { email: 'admin@jamuiservice.com' } },
    });

    const provDoc = (await mockDb.collection('providers').doc('prov_alice').get()).data();
    const startDate = provDoc.subscriptionStartDate?.toDate ? provDoc.subscriptionStartDate.toDate() : new Date(provDoc.subscriptionStartDate);
    const expiryDate = provDoc.subscriptionExpiry?.toDate ? provDoc.subscriptionExpiry.toDate() : new Date(provDoc.subscriptionExpiry);

    const diffDays = Math.round((expiryDate.getTime() - startDate.getTime()) / (24 * 60 * 60 * 1000));
    const isExact365Days = diffDays === 365;
    const isNotDoubled = diffDays !== 730;

    const testPassed = approveRes.success &&
      provDoc.isSubscriptionActive === true &&
      isExact365Days &&
      isNotDoubled;

    record("365-Day Plan: Two-step flow applies duration exactly ONCE (365 days, not 730 days)", testPassed, `diffDays: ${diffDays}`);
  }

  // ---------------------------------------------------------------------------------
  // TEST 22: Duplicate Approval Prevention (Replay Guard)
  // Ensures second call on same order throws error and does not extend duration
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    const orderId = 'order_dup_guard_1';
    await mockDb.collection('payments').doc(orderId).set({
      id: orderId,
      orderId: orderId,
      paymentId: 'pay_dup_guard_1',
      providerId: 'prov_alice',
      planId: 'plan_basic',
      amount: 199.0,
      amountInPaise: 19900,
      durationDays: 30,
      currency: 'INR',
      status: 'success',
      captured: true,
      liveVerified: true,
      adminApprovalStatus: 'pending_approval',
    });

    // First Approval
    const firstRes = await handlers.adminApproveSubscription.run({
      data: { providerId: 'prov_alice', orderId },
      auth: { uid: 'admin_super', token: { email: 'admin@jamuiservice.com' } },
    });

    const provAfterFirst = (await mockDb.collection('providers').doc('prov_alice').get()).data();
    const expiryFirst = provAfterFirst.subscriptionExpiry?.toDate ? provAfterFirst.subscriptionExpiry.toDate() : new Date(provAfterFirst.subscriptionExpiry);

    // Second Approval Attempt (Duplicate)
    let threwDup = false;
    let dupErrMsg = '';
    try {
      await handlers.adminApproveSubscription.run({
        data: { providerId: 'prov_alice', orderId },
        auth: { uid: 'admin_super', token: { email: 'admin@jamuiservice.com' } },
      });
    } catch (e) {
      threwDup = true;
      dupErrMsg = e.message || '';
    }

    const provAfterSecond = (await mockDb.collection('providers').doc('prov_alice').get()).data();
    const expirySecond = provAfterSecond.subscriptionExpiry?.toDate ? provAfterSecond.subscriptionExpiry.toDate() : new Date(provAfterSecond.subscriptionExpiry);

    const isDupProtected = firstRes.success &&
      threwDup &&
      dupErrMsg.includes('already been approved and activated') &&
      expiryFirst.getTime() === expirySecond.getTime();

    record("Duplicate Approval: Second approval attempt safely rejected with failed-precondition, expiry untouched", isDupProtected);
  }

  // ---------------------------------------------------------------------------------
  // TEST 23: Webhook Duplicate Retry Followed By Admin Approval
  // Ensures duplicate webhook retries are idempotent and admin approval applies duration once
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    const orderId = 'order_wh_retry_1';
    await mockDb.collection('payments').doc(orderId).set({
      id: orderId,
      orderId: orderId,
      providerId: 'prov_bob',
      planId: 'plan_basic',
      amount: 199.0,
      amountInPaise: 19900,
      durationDays: 30,
      currency: 'INR',
      status: 'created',
    });

    const payloadObj = {
      event: 'payment.captured',
      payload: {
        payment: {
          entity: {
            id: 'pay_wh_retry_1',
            order_id: orderId,
            amount: 19900,
            currency: 'INR',
            notes: { providerId: 'prov_bob', planId: 'plan_basic' },
          },
        },
      },
    };
    const rawPayload = JSON.stringify(payloadObj);
    const validSignature = crypto.createHmac('sha256', TEST_WEBHOOK_SECRET).update(rawPayload).digest('hex');

    // Webhook Delivery 1
    const req1 = {
      method: 'POST',
      headers: { 'x-razorpay-signature': validSignature },
      rawBody: Buffer.from(rawPayload),
      body: payloadObj,
    };
    const res1 = new MockResponse();
    await handlers.razorpayWebhook(req1, res1);

    // Webhook Delivery 2 (Duplicate Retry)
    const req2 = {
      method: 'POST',
      headers: { 'x-razorpay-signature': validSignature },
      rawBody: Buffer.from(rawPayload),
      body: payloadObj,
    };
    const res2 = new MockResponse();
    await handlers.razorpayWebhook(req2, res2);

    const provAfterWebhook = (await mockDb.collection('providers').doc('prov_bob').get()).data();
    const isWebhookPending = provAfterWebhook.isSubscriptionActive === false &&
      provAfterWebhook.subscriptionApprovalStatus === 'pending_approval' &&
      !provAfterWebhook.subscriptionExpiry;

    // Admin Approval
    await handlers.adminApproveSubscription.run({
      data: { providerId: 'prov_bob', orderId },
      auth: { uid: 'admin_super', token: { email: 'admin@jamuiservice.com' } },
    });

    const provAfterApprove = (await mockDb.collection('providers').doc('prov_bob').get()).data();
    const startDate = provAfterApprove.subscriptionStartDate?.toDate ? provAfterApprove.subscriptionStartDate.toDate() : new Date(provAfterApprove.subscriptionStartDate);
    const expiryDate = provAfterApprove.subscriptionExpiry?.toDate ? provAfterApprove.subscriptionExpiry.toDate() : new Date(provAfterApprove.subscriptionExpiry);
    const diffDays = Math.round((expiryDate.getTime() - startDate.getTime()) / (24 * 60 * 60 * 1000));

    const isWebhookRetryCorrect = res1.statusCode === 200 &&
      res2.statusCode === 200 &&
      isWebhookPending &&
      provAfterApprove.isSubscriptionActive === true &&
      diffDays === 30;

    record("Webhook Retry: Duplicate deliveries idempotent, single authoritative duration (30 days) applied on approval", isWebhookRetryCorrect);
  }

  // ---------------------------------------------------------------------------------
  // TEST 24: Existing Active Subscription Renewal (Stacking Preservation)
  // Existing unexpired days preserved; new duration stacked from current expiry
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    const now = Date.now();
    const remainingDays = 12;
    const futureExpiry = new Date(now + remainingDays * 24 * 60 * 60 * 1000);

    // Provider has active approved subscription with 12 days left
    await mockDb.collection('providers').doc('prov_alice').update({
      isSubscriptionActive: true,
      subscriptionApprovalStatus: 'approved',
      subscriptionExpiry: admin.firestore.Timestamp.fromDate(futureExpiry),
    });

    const orderId = 'order_active_renewal_1';
    const paymentId = 'pay_active_renewal_1';
    await mockDb.collection('payments').doc(orderId).set({
      id: orderId,
      orderId: orderId,
      paymentId: paymentId,
      providerId: 'prov_alice',
      planId: 'plan_basic',
      amount: 199.0,
      amountInPaise: 19900,
      durationDays: 30,
      currency: 'INR',
      status: 'created',
      isRenewal: true,
      pricingSnapshot: {
        planId: 'plan_basic',
        amountInPaise: 19900,
        durationDays: 30,
        categoryLimit: 1,
      },
    });

    const sig = crypto.createHmac('sha256', TEST_KEY_SECRET).update(`${orderId}|${paymentId}`).digest('hex');
    mockFetchImplementation = async (id) => ({
      id,
      order_id: orderId,
      status: 'captured',
      amount: 19900,
      currency: 'INR',
    });

    // Step 1: verifySubscriptionPayment
    await handlers.verifySubscriptionPayment.run({
      data: {
        providerId: 'prov_alice',
        planId: 'plan_basic',
        razorpayOrderId: orderId,
        razorpayPaymentId: paymentId,
        razorpaySignature: sig,
      },
      auth: { uid: 'prov_alice' },
    });

    const provAfterVerify = (await mockDb.collection('providers').doc('prov_alice').get()).data();
    const expiryAfterVerify = provAfterVerify.subscriptionExpiry?.toDate ? provAfterVerify.subscriptionExpiry.toDate() : new Date(provAfterVerify.subscriptionExpiry);
    
    // Crucial: Provider MUST remain active and unexpired expiry MUST NOT be altered yet
    const unexpiredPreservedDuringVerify = provAfterVerify.isSubscriptionActive === true &&
      Math.abs(expiryAfterVerify.getTime() - futureExpiry.getTime()) < 1000;

    // Step 2: adminApproveSubscription
    await handlers.adminApproveSubscription.run({
      data: { providerId: 'prov_alice', orderId },
      auth: { uid: 'admin_super', token: { email: 'admin@jamuiservice.com' } },
    });

    const provAfterApprove = (await mockDb.collection('providers').doc('prov_alice').get()).data();
    const finalStartDate = provAfterApprove.subscriptionStartDate?.toDate ? provAfterApprove.subscriptionStartDate.toDate() : new Date(provAfterApprove.subscriptionStartDate);
    const finalExpiry = provAfterApprove.subscriptionExpiry?.toDate ? provAfterApprove.subscriptionExpiry.toDate() : new Date(provAfterApprove.subscriptionExpiry);

    // Expected final expiry: futureExpiry + 30 days = now + 42 days total
    const expectedFinalExpiryMs = futureExpiry.getTime() + 30 * 24 * 60 * 60 * 1000;
    const diffFromExpectedMs = Math.abs(finalExpiry.getTime() - expectedFinalExpiryMs);

    const isRenewalStackingPreserved = unexpiredPreservedDuringVerify &&
      provAfterApprove.isSubscriptionActive === true &&
      Math.abs(finalStartDate.getTime() - futureExpiry.getTime()) < 1000 &&
      diffFromExpectedMs < 2000;

    record("Existing Active Subscription Renewal: Preserves remaining days, stacks duration cleanly onto existing expiry", isRenewalStackingPreserved);
  }

  // ---------------------------------------------------------------------------------
  // TEST 25: Self-Healing Guard on Legacy Pending Provisional Expiry
  // If provider document had dirty provisional expiry from old code but isSubscriptionActive: false,
  // approval treats it as inactive and applies 30 days from now (NEVER adds to provisional expiry)
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    const dirtyProvisionalExpiry = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);

    // Simulate old buggy state: provisional expiry was written, but subscription is inactive
    await mockDb.collection('providers').doc('prov_alice').update({
      isSubscriptionActive: false,
      subscriptionApprovalStatus: 'pending_approval',
      subscriptionExpiry: admin.firestore.Timestamp.fromDate(dirtyProvisionalExpiry),
    });

    const orderId = 'order_dirty_provisional_1';
    await mockDb.collection('payments').doc(orderId).set({
      id: orderId,
      orderId: orderId,
      paymentId: 'pay_dirty_prov_1',
      providerId: 'prov_alice',
      planId: 'plan_basic',
      amount: 199.0,
      amountInPaise: 19900,
      durationDays: 30,
      currency: 'INR',
      status: 'success',
      captured: true,
      liveVerified: true,
      adminApprovalStatus: 'pending_approval',
    });

    await handlers.adminApproveSubscription.run({
      data: { providerId: 'prov_alice', orderId },
      auth: { uid: 'admin_super', token: { email: 'admin@jamuiservice.com' } },
    });

    const provDoc = (await mockDb.collection('providers').doc('prov_alice').get()).data();
    const startDate = provDoc.subscriptionStartDate?.toDate ? provDoc.subscriptionStartDate.toDate() : new Date(provDoc.subscriptionStartDate);
    const expiryDate = provDoc.subscriptionExpiry?.toDate ? provDoc.subscriptionExpiry.toDate() : new Date(provDoc.subscriptionExpiry);

    const diffDays = Math.round((expiryDate.getTime() - startDate.getTime()) / (24 * 60 * 60 * 1000));
    const isSelfHealedTo30Days = diffDays === 30;
    const isNotDoubledTo60Days = diffDays !== 60;

    record("Self-Healing Guard: Old pending provisional date ignored; approval applies exact 30 days (not 60 days)", isSelfHealedTo30Days && isNotDoubledTo60Days);
  }

  // ---------------------------------------------------------------------------------
  // TEST 26: Expired Subscription Renewal (Starts from NOW, NOT from past expiry)
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    const pastExpiredDate = new Date(Date.now() - 5 * 24 * 60 * 60 * 1000); // Expired 5 days ago

    // Provider had an expired subscription
    await mockDb.collection('providers').doc('prov_alice').update({
      isSubscriptionActive: false,
      subscriptionApprovalStatus: 'approved',
      subscriptionExpiry: admin.firestore.Timestamp.fromDate(pastExpiredDate),
    });

    const orderId = 'order_expired_renewal_1';
    await mockDb.collection('payments').doc(orderId).set({
      id: orderId,
      orderId: orderId,
      paymentId: 'pay_expired_renew_1',
      providerId: 'prov_alice',
      planId: 'plan_basic',
      amount: 199.0,
      amountInPaise: 19900,
      durationDays: 30,
      currency: 'INR',
      status: 'success',
      captured: true,
      liveVerified: true,
      adminApprovalStatus: 'pending_approval',
    });

    const beforeApproveMs = Date.now();
    await handlers.adminApproveSubscription.run({
      data: { providerId: 'prov_alice', orderId },
      auth: { uid: 'admin_super', token: { email: 'admin@jamuiservice.com' } },
    });
    const afterApproveMs = Date.now();

    const provDoc = (await mockDb.collection('providers').doc('prov_alice').get()).data();
    const startDate = provDoc.subscriptionStartDate?.toDate ? provDoc.subscriptionStartDate.toDate() : new Date(provDoc.subscriptionStartDate);
    const expiryDate = provDoc.subscriptionExpiry?.toDate ? provDoc.subscriptionExpiry.toDate() : new Date(provDoc.subscriptionExpiry);

    const isStartFromNow = startDate.getTime() >= beforeApproveMs - 1000 && startDate.getTime() <= afterApproveMs + 1000;
    const isExpiry30DaysFromNow = Math.abs(expiryDate.getTime() - (startDate.getTime() + 30 * 24 * 60 * 60 * 1000)) < 1000;

    record("Expired Subscription Renewal: Starts from approval time (now), NOT past expired date; exactly 30 days applied", isStartFromNow && isExpiry30DaysFromNow && provDoc.isSubscriptionActive === true);
  }

  // ---------------------------------------------------------------------------------
  // TEST 27: adminRejectSubscription on New Provider & Re-approval Protection
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    const orderId = 'order_new_reject_1';

    await mockDb.collection('payments').doc(orderId).set({
      id: orderId,
      orderId: orderId,
      paymentId: 'pay_reject_1',
      providerId: 'prov_bob',
      planId: 'plan_basic',
      amount: 199.0,
      amountInPaise: 19900,
      durationDays: 30,
      currency: 'INR',
      status: 'success',
      captured: true,
      liveVerified: true,
      adminApprovalStatus: 'pending_approval',
    });

    // 1. Admin rejects payment request
    await handlers.adminRejectSubscription.run({
      data: { providerId: 'prov_bob', orderId, reason: 'दस्तावेज़ अस्पष्ट होने के कारण अस्वीकृत' },
      auth: { uid: 'admin_super', token: { email: 'admin@jamuiservice.com' } },
    });

    const payAfterReject = (await mockDb.collection('payments').doc(orderId).get()).data();
    const provAfterReject = (await mockDb.collection('providers').doc('prov_bob').get()).data();

    const isRejectRecorded = payAfterReject.adminApprovalStatus === 'rejected' &&
      payAfterReject.rejectionReason === 'दस्तावेज़ अस्पष्ट होने के कारण अस्वीकृत' &&
      provAfterReject.isSubscriptionActive === false &&
      provAfterReject.subscriptionApprovalStatus === 'rejected';

    // 2. Calling adminApproveSubscription on rejected order without override MUST fail
    let threwOnRejectedApprove = false;
    try {
      await handlers.adminApproveSubscription.run({
        data: { providerId: 'prov_bob', orderId },
        auth: { uid: 'admin_super', token: { email: 'admin@jamuiservice.com' } },
      });
    } catch (err) {
      threwOnRejectedApprove = err.code === 'failed-precondition';
    }

    record("adminRejectSubscription: Rejection sets isSubscriptionActive: false, blocks accidental re-approval", isRejectRecorded && threwOnRejectedApprove);
  }

  // ---------------------------------------------------------------------------------
  // TEST 28: adminRejectSubscription on Active Provider Renewal (Preserves Ongoing Subscription)
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    const futureExpiry = new Date(Date.now() + 20 * 24 * 60 * 60 * 1000); // 20 days remaining

    // Alice has an ongoing active subscription
    await mockDb.collection('providers').doc('prov_alice').update({
      isSubscriptionActive: true,
      subscriptionApprovalStatus: 'approved',
      subscriptionExpiry: admin.firestore.Timestamp.fromDate(futureExpiry),
    });

    const renewalOrderId = 'order_renewal_rejected_1';
    await mockDb.collection('payments').doc(renewalOrderId).set({
      id: renewalOrderId,
      orderId: renewalOrderId,
      paymentId: 'pay_renew_rej_1',
      providerId: 'prov_alice',
      planId: 'plan_basic',
      amount: 199.0,
      amountInPaise: 19900,
      durationDays: 30,
      currency: 'INR',
      status: 'success',
      captured: true,
      liveVerified: true,
      adminApprovalStatus: 'pending_approval',
    });

    // Admin rejects the renewal order
    await handlers.adminRejectSubscription.run({
      data: { providerId: 'prov_alice', orderId: renewalOrderId, reason: 'Duplicate accidental renewal payment' },
      auth: { uid: 'admin_super', token: { email: 'admin@jamuiservice.com' } },
    });

    const payDoc = (await mockDb.collection('payments').doc(renewalOrderId).get()).data();
    const provDoc = (await mockDb.collection('providers').doc('prov_alice').get()).data();
    const currentExpiry = provDoc.subscriptionExpiry?.toDate ? provDoc.subscriptionExpiry.toDate() : new Date(provDoc.subscriptionExpiry);

    // Existing active subscription must NOT be killed! Expiry must be preserved!
    const isOngoingSubscriptionPreserved = provDoc.isSubscriptionActive === true &&
      Math.abs(currentExpiry.getTime() - futureExpiry.getTime()) < 1000 &&
      provDoc.renewalStatus === 'rejected' &&
      payDoc.adminApprovalStatus === 'rejected';

    record("adminRejectSubscription on Active Renewal: Ongoing unexpired subscription remains active and untouched", isOngoingSubscriptionPreserved);
  }

  // ---------------------------------------------------------------------------------
  // TEST 29: Explicit Authorized Re-approval of Previously Rejected Request
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    const orderId = 'order_reapprove_test_1';

    await mockDb.collection('payments').doc(orderId).set({
      id: orderId,
      orderId: orderId,
      paymentId: 'pay_reapprove_1',
      providerId: 'prov_bob',
      planId: 'plan_basic',
      amount: 199.0,
      amountInPaise: 19900,
      durationDays: 30,
      currency: 'INR',
      status: 'success',
      captured: true,
      liveVerified: true,
      adminApprovalStatus: 'rejected',
    });

    // Passing allowReapprove: true allows administrator to override
    const res = await handlers.adminApproveSubscription.run({
      data: { providerId: 'prov_bob', orderId, allowReapprove: true },
      auth: { uid: 'admin_super', token: { email: 'admin@jamuiservice.com' } },
    });

    const provDoc = (await mockDb.collection('providers').doc('prov_bob').get()).data();
    const payDoc = (await mockDb.collection('payments').doc(orderId).get()).data();

    const isReapproved = res.success === true &&
      provDoc.isSubscriptionActive === true &&
      provDoc.subscriptionApprovalStatus === 'approved' &&
      payDoc.adminApprovalStatus === 'approved';

    record("Explicit Re-approval: Authorized administrator with allowReapprove: true can safely reactivate", isReapproved);
  }

  // ---------------------------------------------------------------------------------
  // TEST 30: Provider App & Customer App Invariants
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());

    // Case A: Provider profile verified in Admin Panel (KYC approved) WITHOUT payment
    await mockDb.collection('providers').doc('prov_alice').update({
      status: 'approved',
      verificationStatus: 'approved',
      kycStatus: 'approved',
      isSubscriptionActive: false,
      paymentVerified: false,
    });

    const aliceDoc = (await mockDb.collection('providers').doc('prov_alice').get()).data();
    // Invariant: KYC approval ALONE must NEVER activate paid subscription
    const kycAloneDoesNotActivate = aliceDoc.isSubscriptionActive === false && aliceDoc.paymentVerified === false;

    // Case B: Customer App Visibility Filter check
    // Business rule: Provider is only visible in search/category listings if:
    // status == 'approved' && isActive !== false && isSubscriptionActive == true && expiry > now
    const now = new Date();
    const isCustomerVisibleAlice = aliceDoc.status === 'approved' &&
      aliceDoc.isActive !== false &&
      aliceDoc.isSubscriptionActive === true &&
      (aliceDoc.subscriptionExpiry ? (aliceDoc.subscriptionExpiry.toDate ? aliceDoc.subscriptionExpiry.toDate() : new Date(aliceDoc.subscriptionExpiry)) > now : false);

    // Case C: Bob completes payment and Admin approves
    const orderId = 'order_app_invariants_1';
    await mockDb.collection('payments').doc(orderId).set({
      id: orderId,
      orderId: orderId,
      paymentId: 'pay_app_inv_1',
      providerId: 'prov_bob',
      planId: 'plan_basic',
      amount: 199.0,
      amountInPaise: 19900,
      durationDays: 30,
      currency: 'INR',
      status: 'success',
      captured: true,
      liveVerified: true,
      adminApprovalStatus: 'pending_approval',
    });

    await handlers.adminApproveSubscription.run({
      data: { providerId: 'prov_bob', orderId },
      auth: { uid: 'admin_super', token: { email: 'admin@jamuiservice.com' } },
    });

    // Make Bob also profile-approved
    await mockDb.collection('providers').doc('prov_bob').update({
      status: 'approved',
      verificationStatus: 'approved',
      kycStatus: 'approved',
      isActive: true,
    });

    const bobDoc = (await mockDb.collection('providers').doc('prov_bob').get()).data();
    const bobExpiry = bobDoc.subscriptionExpiry.toDate ? bobDoc.subscriptionExpiry.toDate() : new Date(bobDoc.subscriptionExpiry);
    const isCustomerVisibleBob = bobDoc.status === 'approved' &&
      bobDoc.isActive !== false &&
      bobDoc.isSubscriptionActive === true &&
      bobExpiry > now;

    const areAppInvariantsMaintained = kycAloneDoesNotActivate &&
      !isCustomerVisibleAlice &&
      isCustomerVisibleBob;

    record("App Visibility Invariants: KYC alone does not activate subscription; only paid + approved providers are active", areAppInvariantsMaintained);
  }

  // ---------------------------------------------------------------------------------
  // TEST 31: getSubscriptionPlans - Only returns active plans from Firestore
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    // Add an inactive plan to Firestore
    await mockDb.collection('subscription_plans').doc('plan_inactive').set({
      id: 'plan_inactive',
      name: 'Inactive Old Plan',
      price: 50.0,
      durationDays: 15,
      isActive: false,
    });

    const res = await handlers.getSubscriptionPlans.run({
      data: { providerId: 'prov_alice' },
      auth: { uid: 'prov_alice' },
    });

    const returnedPlans = res.plans || res;
    const inactiveFound = returnedPlans.some(p => p.id === 'plan_inactive');
    const basicFound = returnedPlans.some(p => p.id === 'jP3p8pl3upBi7b8GShhw' || p.id === 'plan_basic');

    record("Firestore Single Source: getSubscriptionPlans returns only active Firestore plans and ignores inactive ones", !inactiveFound && basicFound);
  }

  // ---------------------------------------------------------------------------------
  // TEST 32: createSubscriptionOrder - Non-existent plan ID rejected with not-found
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    let threwNotFound = false;
    try {
      await handlers.createSubscriptionOrder.run({
        data: { providerId: 'prov_alice', planId: 'plan_non_existent_999' },
        auth: { uid: 'prov_alice' },
      });
    } catch (e) {
      if (e.code === 'not-found') threwNotFound = true;
    }

    record("Strict Plan Validation: createSubscriptionOrder fails with not-found for non-existent plan", threwNotFound);
  }

  // ---------------------------------------------------------------------------------
  // TEST 33: createSubscriptionOrder - Inactive plan rejected with not-found
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    await mockDb.collection('subscription_plans').doc('plan_disabled').set({
      id: 'plan_disabled',
      name: 'Disabled Promo Plan',
      price: 49.0,
      durationDays: 30,
      isActive: false,
    });

    let threwInactive = false;
    try {
      await handlers.createSubscriptionOrder.run({
        data: { providerId: 'prov_alice', planId: 'plan_disabled' },
        auth: { uid: 'prov_alice' },
      });
    } catch (e) {
      if (e.code === 'not-found') threwInactive = true;
    }

    record("Strict Plan Validation: createSubscriptionOrder fails with not-found for inactive plan", threwInactive);
  }

  // ---------------------------------------------------------------------------------
  // TEST 34: createSubscriptionOrder - Malformed plan price (<= 0) rejected
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    await mockDb.collection('subscription_plans').doc('plan_zero_price').set({
      id: 'plan_zero_price',
      name: 'Zero Price Bug Plan',
      price: 0,
      durationDays: 30,
      isActive: true,
    });

    let threwMalformedPrice = false;
    try {
      await handlers.createSubscriptionOrder.run({
        data: { providerId: 'prov_alice', planId: 'plan_zero_price' },
        auth: { uid: 'prov_alice' },
      });
    } catch (e) {
      if (e.code === 'failed-precondition') threwMalformedPrice = true;
    }

    record("Strict Price Validation: createSubscriptionOrder rejects plan with price <= 0", threwMalformedPrice);
  }

  // ---------------------------------------------------------------------------------
  // TEST 35: createSubscriptionOrder - Malformed durationDays (<= 0) rejected
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    await mockDb.collection('subscription_plans').doc('plan_zero_duration').set({
      id: 'plan_zero_duration',
      name: 'Zero Duration Bug Plan',
      price: 100,
      durationDays: 0,
      isActive: true,
    });

    let threwMalformedDuration = false;
    try {
      await handlers.createSubscriptionOrder.run({
        data: { providerId: 'prov_alice', planId: 'plan_zero_duration' },
        auth: { uid: 'prov_alice' },
      });
    } catch (e) {
      if (e.code === 'failed-precondition') threwMalformedDuration = true;
    }

    record("Strict Duration Validation: createSubscriptionOrder rejects plan with durationDays <= 0", threwMalformedDuration);
  }

  // ---------------------------------------------------------------------------------
  // TEST 36: createSubscriptionOrder - Live Production Basic Plan (₹20 = 2000 paise)
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    const res = await handlers.createSubscriptionOrder.run({
      data: { providerId: 'prov_alice', planId: 'jP3p8pl3upBi7b8GShhw' },
      auth: { uid: 'prov_alice' },
    });

    const paymentDoc = (await mockDb.collection('payments').doc(res.orderId).get()).data();
    const isLivePlanAccurate = res.amount === 2000 &&
      paymentDoc.amount === 20 &&
      paymentDoc.amountInPaise === 2000 &&
      paymentDoc.durationDays === 30 &&
      paymentDoc.pricingSnapshot != null &&
      paymentDoc.pricingSnapshot.amount === 20 &&
      paymentDoc.pricingSnapshot.amountInPaise === 2000 &&
      paymentDoc.pricingSnapshot.durationDays === 30;

    record("Live Plan Contract: Basic plan generates exact ₹20 (2000 paise) order with immutable pricingSnapshot", isLivePlanAccurate);
  }

  // ---------------------------------------------------------------------------------
  // TEST 37: Changed Plan After Order Creation - Snapshot Preserves Original Terms
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    // Alice creates order for ₹20 plan
    const orderRes = await handlers.createSubscriptionOrder.run({
      data: { providerId: 'prov_alice', planId: 'jP3p8pl3upBi7b8GShhw' },
      auth: { uid: 'prov_alice' },
    });
    const orderId = orderRes.orderId;

    // Admin now mutates live Firestore plan price from ₹20 to ₹500 and duration from 30 to 90 days!
    await mockDb.collection('subscription_plans').doc('jP3p8pl3upBi7b8GShhw').update({
      price: 500,
      durationDays: 90,
    });

    // Alice pays original ₹20
    const paymentId = 'pay_snapshot_immutability_1';
    const sig = crypto.createHmac('sha256', TEST_KEY_SECRET).update(`${orderId}|${paymentId}`).digest('hex');
    mockFetchImplementation = async (id) => ({
      id,
      order_id: orderId,
      status: 'captured',
      amount: 2000, // Original ₹20 in paise
      currency: 'INR',
    });

    const verifyRes = await handlers.verifySubscriptionPayment.run({
      data: {
        providerId: 'prov_alice',
        planId: 'jP3p8pl3upBi7b8GShhw',
        razorpayOrderId: orderId,
        razorpayPaymentId: paymentId,
        razorpaySignature: sig,
      },
      auth: { uid: 'prov_alice' },
    });

    // Admin approves
    await handlers.adminApproveSubscription.run({
      data: { providerId: 'prov_alice', orderId },
      auth: { uid: 'admin_super', token: { email: 'admin@jamuiservice.com' } },
    });

    const aliceDoc = (await mockDb.collection('providers').doc('prov_alice').get()).data();
    const approvedAt = aliceDoc.subscriptionApprovedAt.toDate ? aliceDoc.subscriptionApprovedAt.toDate() : new Date(aliceDoc.subscriptionApprovedAt);
    const expiry = aliceDoc.subscriptionExpiry.toDate ? aliceDoc.subscriptionExpiry.toDate() : new Date(aliceDoc.subscriptionExpiry);
    const diffDays = Math.round((expiry.getTime() - approvedAt.getTime()) / (1000 * 60 * 60 * 24));

    // Must be original 30 days from snapshot, NOT 90 days from updated plan!
    const isImmutable = verifyRes.amountPaid === 20 &&
      diffDays === 30 &&
      aliceDoc.subscriptionDurationDays === 30;

    record("Pricing Immutability: Plan modification after order does NOT alter paid snapshot terms", isImmutable);
  }

  // ---------------------------------------------------------------------------------
  // TEST 38: Fail-Closed Protection - Missing Snapshot and missing legacy duration fails safely
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    const corruptOrderId = 'order_corrupted_no_snapshot';
    await mockDb.collection('payments').doc(corruptOrderId).set({
      id: corruptOrderId,
      orderId: corruptOrderId,
      paymentId: 'pay_corrupted_1',
      providerId: 'prov_bob',
      planId: 'plan_deleted_from_db',
      amount: 199.0,
      amountInPaise: 19900,
      currency: 'INR',
      status: 'success',
      captured: true,
      liveVerified: true,
      adminApprovalStatus: 'pending_approval',
      // Neither pricingSnapshot nor durationDays provided!
    });

    let approveThrew = false;
    try {
      await handlers.adminApproveSubscription.run({
        data: { providerId: 'prov_bob', orderId: corruptOrderId },
        auth: { uid: 'admin_super', token: { email: 'admin@jamuiservice.com' } },
      });
    } catch (e) {
      approveThrew = true;
    }

    const bobDoc = (await mockDb.collection('providers').doc('prov_bob').get()).data();
    const failClosedSafe = approveThrew && bobDoc.isSubscriptionActive !== true;

    record("Fail-Closed Safe: Unverifiable order without snapshot/duration fails safely without guessing 30 days", failClosedSafe);
  }

  // ---------------------------------------------------------------------------------
  // TEST 39: Email Auth Support: Provider with Email Auth (phoneNumber is null) successfully creates order without Phone OTP
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    mockDb.store.providers['prov_email_only'] = {
      fullName: 'Email Auth Provider',
      email: 'email_only_provider@jamuiservices.com',
      status: 'pendingReview',
      kycStatus: 'pendingReview',
      isSubscriptionActive: false,
      paymentVerified: false,
    };

    const originalAuth = Object.getOwnPropertyDescriptor(Object.getPrototypeOf(admin), 'auth');
    Object.defineProperty(Object.getPrototypeOf(admin), 'auth', {
      value: () => ({
        getUser: async (uid) => ({
          uid,
          phoneNumber: null, // Email & Password login has no Phone Auth
          email: `${uid}@jamuiservices.com`,
        }),
      }),
      configurable: true,
      writable: true,
    });

    let emailOrderThrew = false;
    let orderRes = null;
    try {
      orderRes = await handlers.createSubscriptionOrder.run({
        data: {
          planId: 'plan_basic',
          providerId: 'prov_email_only',
          providerEmail: 'email_only_provider@jamuiservices.com',
          providerPhone: '9876543210',
        },
        auth: { uid: 'prov_email_only', token: { email: 'email_only_provider@jamuiservices.com' } },
      });
    } catch (e) {
      emailOrderThrew = true;
      console.error('Email order creation threw:', e);
    }

    if (originalAuth) {
      Object.defineProperty(Object.getPrototypeOf(admin), 'auth', originalAuth);
    }

    const profileUntainted = !mockDb.store.providers['prov_email_only'].phoneNumber;

    const emailOrderSuccess = !emailOrderThrew &&
      orderRes &&
      orderRes.orderId &&
      orderRes.orderId.startsWith('order_mock_') &&
      orderRes.amount === 19900 &&
      orderRes.verifiedEmail === 'prov_email_only@jamuiservices.com' &&
      profileUntainted;

    record("Email Auth Support: Provider with Email/Password (null auth phone) generates subscription order without Phone OTP requirement and leaves profile phone untainted", emailOrderSuccess);
  }

  // ---------------------------------------------------------------------------------
  // TEST 40: Client request.data spoofing rejected: Cannot bypass identity check using client data
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    mockDb.store.providers['prov_no_id'] = {
      fullName: 'No Identity Provider',
      status: 'pendingReview',
      kycStatus: 'pendingReview',
      isSubscriptionActive: false,
      paymentVerified: false,
    };

    const originalAuth = Object.getOwnPropertyDescriptor(Object.getPrototypeOf(admin), 'auth');
    Object.defineProperty(Object.getPrototypeOf(admin), 'auth', {
      value: () => ({
        getUser: async (uid) => ({
          uid,
          phoneNumber: null,
          email: null,
        }),
      }),
      configurable: true,
      writable: true,
    });

    let spoofThrew = false;
    let spoofErrorCode = null;
    try {
      await handlers.createSubscriptionOrder.run({
        data: {
          planId: 'plan_basic',
          providerId: 'prov_no_id',
          providerEmail: 'fake_spoofed_email@attacker.com',
          providerPhone: '9999999999',
        },
        auth: { uid: 'prov_no_id' },
      });
    } catch (e) {
      spoofThrew = true;
      spoofErrorCode = e.code;
    }

    if (originalAuth) {
      Object.defineProperty(Object.getPrototypeOf(admin), 'auth', originalAuth);
    }

    const spoofRejected = spoofThrew && spoofErrorCode === 'failed-precondition';
    record("Zero Trust Client Data: request.data email/phone ignored; provider without Auth/Firestore identity strictly rejected", spoofRejected);
  }

  // ---------------------------------------------------------------------------------
  // TEST 41: Caller Authorization Gate: Caller UID must match providerId
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    let mismatchThrew = false;
    let mismatchErrorCode = null;
    try {
      await handlers.createSubscriptionOrder.run({
        data: {
          planId: 'plan_basic',
          providerId: 'prov_alice',
        },
        auth: { uid: 'attacker_unauthorized_user' },
      });
    } catch (e) {
      mismatchThrew = true;
      mismatchErrorCode = e.code;
    }

    const mismatchRejected = mismatchThrew && mismatchErrorCode === 'permission-denied';
    record("Caller Authorization Gate: Caller UID mismatch rejected with permission-denied", mismatchRejected);
  }

  // ---------------------------------------------------------------------------------
  // TEST 42: Live ₹20 Basic Plan: Email Auth Provider with emailVerified: false creates order without Phone OTP
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    mockDb.store.providers['prov_email_basic20'] = {
      fullName: 'Basic 20 Provider',
      email: 'basic20@jamuiservices.com',
      status: 'pendingReview',
      kycStatus: 'pendingReview',
      isSubscriptionActive: false,
      paymentVerified: false,
    };

    const originalAuth = Object.getOwnPropertyDescriptor(Object.getPrototypeOf(admin), 'auth');
    Object.defineProperty(Object.getPrototypeOf(admin), 'auth', {
      value: () => ({
        getUser: async (uid) => ({
          uid,
          phoneNumber: null,
          email: 'basic20@jamuiservices.com',
          emailVerified: false, // Provider registered with email & password, has not verified link yet
        }),
      }),
      configurable: true,
      writable: true,
    });

    let basic20Threw = false;
    let basic20Res = null;
    try {
      basic20Res = await handlers.createSubscriptionOrder.run({
        data: {
          planId: 'jP3p8pl3upBi7b8GShhw', // Live Basic ₹20 Plan in Firestore
          providerId: 'prov_email_basic20',
        },
        auth: { uid: 'prov_email_basic20', token: { email: 'basic20@jamuiservices.com' } },
      });
    } catch (e) {
      basic20Threw = true;
      console.error('basic20 order creation error:', e);
    }

    if (originalAuth) {
      Object.defineProperty(Object.getPrototypeOf(admin), 'auth', originalAuth);
    }

    const basic20Success = !basic20Threw &&
      basic20Res &&
      basic20Res.orderId &&
      basic20Res.orderId.startsWith('order_mock_') &&
      basic20Res.amount === 2000 &&
      basic20Res.verifiedEmail === 'basic20@jamuiservices.com';

    record("Live Contract: Email Auth provider with emailVerified: false creates ₹20 (2000 paise) order without Phone OTP", basic20Success);
  }

  // ---------------------------------------------------------------------------------
  // TEST 43: providerData.email Alone Rejection: Loose Firestore email without Firebase Auth is rejected
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    mockDb.store.providers['prov_loose_email'] = {
      fullName: 'Loose Email Provider',
      email: 'unauthenticated_loose_email@jamuiservices.com', // Only in Firestore, NOT in Auth
      status: 'pendingReview',
      kycStatus: 'pendingReview',
      isSubscriptionActive: false,
      paymentVerified: false,
    };

    const originalAuth = Object.getOwnPropertyDescriptor(Object.getPrototypeOf(admin), 'auth');
    Object.defineProperty(Object.getPrototypeOf(admin), 'auth', {
      value: () => ({
        getUser: async (uid) => ({
          uid,
          phoneNumber: null,
          email: null, // No email on Auth record!
        }),
      }),
      configurable: true,
      writable: true,
    });

    let looseThrew = false;
    let looseErrorCode = null;
    try {
      await handlers.createSubscriptionOrder.run({
        data: {
          planId: 'plan_basic',
          providerId: 'prov_loose_email',
        },
        auth: { uid: 'prov_loose_email' }, // No token email
      });
    } catch (e) {
      looseThrew = true;
      looseErrorCode = e.code;
    }

    if (originalAuth) {
      Object.defineProperty(Object.getPrototypeOf(admin), 'auth', originalAuth);
    }

    const looseRejected = looseThrew && looseErrorCode === 'failed-precondition';
    record("Anti-Spoofing: Firestore providerData.email alone without Auth record is strictly rejected", looseRejected);
  }

  // ---------------------------------------------------------------------------------
  // TEST 44: Admin Delegation: Active authorized admin can create order on behalf of provider
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    mockDb.store.admin_users['admin_active_1'] = { role: 'admin', status: 'active' };

    let adminOrderThrew = false;
    let adminOrderRes = null;
    try {
      adminOrderRes = await handlers.createSubscriptionOrder.run({
        data: {
          planId: 'plan_basic',
          providerId: 'prov_alice',
        },
        auth: { uid: 'admin_active_1', token: { email: 'admin@jamuiservices.com' } },
      });
    } catch (e) {
      adminOrderThrew = true;
      console.error('admin order error:', e);
    }

    const adminOrderSuccess = !adminOrderThrew &&
      adminOrderRes &&
      adminOrderRes.orderId &&
      adminOrderRes.amount === 19900;

    record("Admin Authorization: Active administrator in admin_users can create order for provider", adminOrderSuccess);
  }

  // ---------------------------------------------------------------------------------
  // TEST 45: Suspended Admin Rejection: Suspended admin attempting order creation is rejected
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    mockDb.store.admin_users['admin_suspended_1'] = { role: 'admin', status: 'suspended' };

    let suspendedThrew = false;
    let suspendedErrorCode = null;
    try {
      await handlers.createSubscriptionOrder.run({
        data: {
          planId: 'plan_basic',
          providerId: 'prov_alice',
        },
        auth: { uid: 'admin_suspended_1', token: { email: 'suspended_admin@jamuiservices.com' } },
      });
    } catch (e) {
      suspendedThrew = true;
      suspendedErrorCode = e.code;
    }

    const suspendedRejected = suspendedThrew && suspendedErrorCode === 'permission-denied';
    record("Admin Authorization: Suspended admin in admin_users is strictly rejected with permission-denied", suspendedRejected);
  }

  // ---------------------------------------------------------------------------------
  // TEST 46: Webhook Secret Validation - URLs, short strings, asterisks rejected
  // ---------------------------------------------------------------------------------
  {
    const isValid = handlers._isValidWebhookSecret;
    const testCases = [
      { input: 'https://asia-south1-jamui-services.cloudfunctions.net/razorpayWebhook', expected: false },
      { input: 'http://example.com/hook', expected: false },
      { input: 'https://razorpaywebhook-n52u45u6ba-el.a.run.app', expected: false },
      { input: 'some/path/secret', expected: false },
      { input: '***masked_secret***', expected: false },
      { input: 'short', expected: false },
      { input: '', expected: false },
      { input: null, expected: false },
      { input: 'valid_secure_secret_24chars', expected: true },
      { input: 'MyWebhookSecretPassphrase123!', expected: true },
    ];

    const allPassed = testCases.every((tc) => isValid(tc.input) === tc.expected);
    record("Webhook Secret Validation: URLs, slashes, asterisks and short strings strictly rejected", allPassed);
  }

  // ---------------------------------------------------------------------------------
  // TEST 47: URL in RAZORPAY_WEBHOOK_SECRET - Ignored and falls back safely to Firestore
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    const savedEnvWebhook = process.env.RAZORPAY_WEBHOOK_SECRET;
    
    // Simulate faulty production state: Secret Manager contains Cloud Function URL!
    process.env.RAZORPAY_WEBHOOK_SECRET = 'https://asia-south1-jamui-services.cloudfunctions.net/razorpayWebhook';

    // Firestore has the valid secret
    const validFallbackSecret = 'valid_firestore_secret_abc123';
    await mockDb.collection('app_config').doc('payment_secrets').set({
      keySecret: TEST_KEY_SECRET,
      webhookSecret: validFallbackSecret,
    });

    const orderId = 'order_hook_url_fallback_1';
    await mockDb.collection('payments').doc(orderId).set({
      id: orderId,
      orderId: orderId,
      providerId: 'prov_bob',
      planId: 'plan_popular',
      amount: 399.0,
      amountInPaise: 39900,
      currency: 'INR',
      status: 'created',
    });

    const payloadObj = {
      event: 'payment.captured',
      payload: {
        payment: {
          entity: {
            id: 'pay_wh_url_fallback',
            order_id: orderId,
            amount: 39900,
            currency: 'INR',
            notes: { providerId: 'prov_bob', planId: 'plan_popular' },
          },
        },
      },
    };
    const rawPayload = JSON.stringify(payloadObj);
    // Signature created using the valid Firestore fallback secret
    const sig = crypto.createHmac('sha256', validFallbackSecret).update(rawPayload).digest('hex');

    const req = {
      method: 'POST',
      headers: { 'x-razorpay-signature': sig },
      rawBody: Buffer.from(rawPayload),
      body: payloadObj,
    };
    const res = new MockResponse();
    await handlers.razorpayWebhook(req, res);

    process.env.RAZORPAY_WEBHOOK_SECRET = savedEnvWebhook;

    const paymentDoc = await mockDb.collection('payments').doc(orderId).get();
    const isFallbackSuccessful = res.statusCode === 200 &&
      paymentDoc.data().status === 'success' &&
      paymentDoc.data().captured === true &&
      paymentDoc.data().paymentId === 'pay_wh_url_fallback';

    record("Webhook Secret Fallback: URL in env rejected; valid Firestore secret accepted cleanly", isFallbackSuccessful);
  }

  // ---------------------------------------------------------------------------------
  // TEST 48: Missed Payment Reconciliation Engine (UPI Captured, Frontend Callback Missing)
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    const orderId = 'order_reconcile_test_1';
    await mockDb.collection('payments').doc(orderId).set({
      id: orderId,
      orderId: orderId,
      providerId: 'prov_alice',
      planId: 'jP3p8pl3upBi7b8GShhw',
      planName: 'Basic',
      amount: 20,
      amountInPaise: 2000,
      currency: 'INR',
      durationDays: 30,
      categoryLimit: 1,
      status: 'created',
      createdAt: admin.firestore.Timestamp.now(),
    });

    // Mock Razorpay API returning captured payment
    mockFetchPaymentsImplementation = async (oid) => ({
      entity: 'collection',
      count: 1,
      items: [
        {
          id: 'pay_reconcile_captured_1',
          order_id: oid,
          status: 'captured',
          captured: true,
          amount: 2000,
          currency: 'INR',
          method: 'upi',
          notes: { providerId: 'prov_alice' },
        },
      ],
    });

    const reconcileRes = await handlers._reconcileSingleOrderInternal(orderId);

    const payDoc = (await mockDb.collection('payments').doc(orderId).get()).data();
    const subDoc = (await mockDb.collection('subscriptions').doc(`sub_${orderId}`).get()).data();
    const provDoc = (await mockDb.collection('providers').doc('prov_alice').get()).data();

    const isReconciliationSuccess = reconcileRes.status === 'success' &&
      payDoc.status === 'success' &&
      payDoc.captured === true &&
      payDoc.liveVerified === true &&
      payDoc.paymentId === 'pay_reconcile_captured_1' &&
      payDoc.adminApprovalStatus === 'pending_approval' &&
      subDoc.id === `sub_${orderId}` &&
      subDoc.status === 'pending_approval' &&
      provDoc.paymentVerified === true &&
      provDoc.subscriptionPaymentStatus === 'paid' &&
      provDoc.subscriptionApprovalStatus === 'pending_approval' &&
      provDoc.isSubscriptionActive === false; // Provider strictly INACTIVE pending admin activation

    record("Missed Payment Recovery: Captured UPI payment with missing frontend callback successfully reconciled", isReconciliationSuccess);
    mockFetchPaymentsImplementation = null;
  }

  // ---------------------------------------------------------------------------------
  // TEST 49: Admin Approval Invariant After Reconciliation
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    const orderId = 'order_reconcile_approval_1';
    await mockDb.collection('payments').doc(orderId).set({
      id: orderId,
      orderId: orderId,
      providerId: 'prov_alice',
      planId: 'jP3p8pl3upBi7b8GShhw',
      planName: 'Basic',
      amount: 20,
      amountInPaise: 2000,
      currency: 'INR',
      durationDays: 30,
      categoryLimit: 1,
      status: 'created',
      createdAt: admin.firestore.Timestamp.now(),
    });

    mockFetchPaymentsImplementation = async (oid) => ({
      entity: 'collection',
      count: 1,
      items: [
        {
          id: 'pay_reconcile_appr_1',
          order_id: oid,
          status: 'captured',
          captured: true,
          amount: 2000,
          currency: 'INR',
          method: 'upi',
          notes: {
            providerId: 'prov_alice',
            planId: 'jP3p8pl3upBi7b8GShhw',
          },
        },
      ],
    });

    await handlers._reconcileSingleOrderInternal(orderId);

    // Verify provider is NOT active before admin approves
    const preApprovalProv = (await mockDb.collection('providers').doc('prov_alice').get()).data();
    const preApprovalInactive = preApprovalProv.isSubscriptionActive === false &&
      preApprovalProv.subscriptionApprovalStatus === 'pending_approval';

    // Admin approves via adminApproveSubscription
    await handlers.adminApproveSubscription.run({
      data: { providerId: 'prov_alice', orderId },
      auth: { uid: 'admin_super', token: { email: 'admin@jamuiservice.com' } },
    });

    const postApprovalProv = (await mockDb.collection('providers').doc('prov_alice').get()).data();
    const postApprovalActive = postApprovalProv.isSubscriptionActive === true &&
      postApprovalProv.subscriptionApprovalStatus === 'approved' &&
      postApprovalProv.subscriptionExpiry != null;

    record("Admin Gate Invariant: Reconciled provider remains inactive until Admin manually approves", preApprovalInactive && postApprovalActive);
    mockFetchPaymentsImplementation = null;
  }

  // ---------------------------------------------------------------------------------
  // TEST 50: Duplicate Reconciliation & Webhook Concurrency Idempotency
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    const orderId = 'order_reconcile_idempotent_1';
    await mockDb.collection('payments').doc(orderId).set({
      id: orderId,
      orderId: orderId,
      providerId: 'prov_alice',
      planId: 'jP3p8pl3upBi7b8GShhw',
      amount: 20,
      amountInPaise: 2000,
      currency: 'INR',
      durationDays: 30,
      status: 'created',
      createdAt: admin.firestore.Timestamp.now(),
    });

    mockFetchPaymentsImplementation = async (oid) => ({
      entity: 'collection',
      count: 1,
      items: [
        {
          id: 'pay_reconcile_idem_1',
          order_id: oid,
          status: 'captured',
          captured: true,
          amount: 2000,
          currency: 'INR',
          notes: {
            providerId: 'prov_alice',
            planId: 'jP3p8pl3upBi7b8GShhw',
          },
        },
      ],
    });

    // Run first reconciliation
    const firstRes = await handlers._reconcileSingleOrderInternal(orderId);

    // Run second reconciliation (duplicate)
    const secondRes = await handlers._reconcileSingleOrderInternal(orderId);

    const isIdempotent = firstRes.status === 'success' &&
      secondRes.status === 'already_fulfilled';

    record("Reconciliation Idempotency: Second reconciliation execution safely skips already fulfilled order", isIdempotent);
    mockFetchPaymentsImplementation = null;
  }

  // ---------------------------------------------------------------------------------
  // TEST 51: Reconciliation Rejection - Uncaptured, Created, or Failed Payments
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    const orderId = 'order_reconcile_uncaptured_1';
    await mockDb.collection('payments').doc(orderId).set({
      id: orderId,
      orderId: orderId,
      providerId: 'prov_alice',
      planId: 'jP3p8pl3upBi7b8GShhw',
      amount: 20,
      amountInPaise: 2000,
      currency: 'INR',
      status: 'created',
      createdAt: admin.firestore.Timestamp.now(),
    });

    // Mock payments where status is created or failed (not captured)
    mockFetchPaymentsImplementation = async () => ({
      entity: 'collection',
      count: 1,
      items: [
        {
          id: 'pay_pending_upi',
          order_id: orderId,
          status: 'created',
          captured: false,
          amount: 2000,
          currency: 'INR',
          notes: {
            providerId: 'prov_alice',
          },
        },
      ],
    });

    const res = await handlers._reconcileSingleOrderInternal(orderId);
    const payDoc = (await mockDb.collection('payments').doc(orderId).get()).data();

    // Order must remain created and unverified
    const isUncapturedSafe = res.status === 'uncaptured' &&
      payDoc.status === 'created' &&
      payDoc.captured !== true;

    record("Reconciliation Rejection: Uncaptured / pending / failed payments safely ignored with zero mutation", isUncapturedSafe);
    mockFetchPaymentsImplementation = null;
  }

  // ---------------------------------------------------------------------------------
  // TEST 52: Reconciliation Invariants - Amount, Currency, or Provider Mismatch Rejected
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    const orderId = 'order_reconcile_tamper_1';
    await mockDb.collection('payments').doc(orderId).set({
      id: orderId,
      orderId: orderId,
      providerId: 'prov_alice',
      planId: 'jP3p8pl3upBi7b8GShhw',
      amount: 20,
      amountInPaise: 2000,
      currency: 'INR',
      status: 'created',
      createdAt: admin.firestore.Timestamp.now(),
    });

    // 1. Amount mismatch (Gateway: 1000 paise vs Expected: 2000 paise)
    mockFetchPaymentsImplementation = async () => ({
      entity: 'collection',
      count: 1,
      items: [
        { id: 'pay_underpaid', order_id: orderId, status: 'captured', captured: true, amount: 1000, currency: 'INR', notes: { providerId: 'prov_alice' } },
      ],
    });
    const amountMismatchRes = await handlers._reconcileSingleOrderInternal(orderId);

    // 2. Currency mismatch (Gateway: USD vs Expected: INR)
    mockFetchPaymentsImplementation = async () => ({
      entity: 'collection',
      count: 1,
      items: [
        { id: 'pay_usd', order_id: orderId, status: 'captured', captured: true, amount: 2000, currency: 'USD', notes: { providerId: 'prov_alice' } },
      ],
    });
    const currencyMismatchRes = await handlers._reconcileSingleOrderInternal(orderId);

    // 3. Provider notes mismatch (Gateway: attacker_uid vs Expected: prov_alice)
    mockFetchPaymentsImplementation = async () => ({
      entity: 'collection',
      count: 1,
      items: [
        { id: 'pay_alien', order_id: orderId, status: 'captured', captured: true, amount: 2000, currency: 'INR', notes: { providerId: 'attacker_uid' } },
      ],
    });
    const providerMismatchRes = await handlers._reconcileSingleOrderInternal(orderId);

    const payDoc = (await mockDb.collection('payments').doc(orderId).get()).data();
    const isInvariantsProtected = amountMismatchRes.status === 'amount_mismatch' &&
      currencyMismatchRes.status === 'currency_mismatch' &&
      providerMismatchRes.status === 'provider_mismatch' &&
      payDoc.status === 'created' &&
      payDoc.captured !== true;

    record("Reconciliation Invariants: Amount mismatch, USD currency, and Provider UID mismatch strictly rejected", isInvariantsProtected);
    mockFetchPaymentsImplementation = null;
  }

  // ---------------------------------------------------------------------------------
  // TEST 53: Missing Payment Notes ProviderId Rejection
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    const orderId = 'order_reconcile_missing_pay_notes';
    await mockDb.collection('payments').doc(orderId).set({
      id: orderId,
      orderId: orderId,
      providerId: 'prov_alice',
      planId: 'jP3p8pl3upBi7b8GShhw',
      amount: 20,
      amountInPaise: 2000,
      currency: 'INR',
      status: 'created',
      createdAt: admin.firestore.Timestamp.now(),
    });

    // Payment without notes.providerId
    mockFetchPaymentsImplementation = async () => ({
      entity: 'collection',
      count: 1,
      items: [
        { id: 'pay_no_notes', order_id: orderId, status: 'captured', captured: true, amount: 2000, currency: 'INR', notes: {} },
      ],
    });

    const res = await handlers._reconcileSingleOrderInternal(orderId);
    const payDoc = (await mockDb.collection('payments').doc(orderId).get()).data();

    const isRejected = res.status === 'missing_payment_provider_notes' &&
      payDoc.status === 'created' &&
      payDoc.captured !== true;

    record("Reconciliation Invariants: Missing capturedPayment.notes.providerId is strictly rejected", isRejected);
    mockFetchPaymentsImplementation = null;
  }

  // ---------------------------------------------------------------------------------
  // TEST 54: Server-Side Razorpay Order Metadata Verification
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    const orderId = 'order_reconcile_order_meta_test';
    await mockDb.collection('payments').doc(orderId).set({
      id: orderId,
      orderId: orderId,
      providerId: 'prov_alice',
      planId: 'jP3p8pl3upBi7b8GShhw',
      amount: 20,
      amountInPaise: 2000,
      currency: 'INR',
      status: 'created',
      createdAt: admin.firestore.Timestamp.now(),
    });

    // 1. Order on gateway missing providerId in notes
    mockFetchOrderImplementation = async () => ({
      id: orderId,
      amount: 2000,
      currency: 'INR',
      notes: {}, // missing providerId!
    });
    mockFetchPaymentsImplementation = async () => ({
      entity: 'collection',
      count: 1,
      items: [
        { id: 'pay_valid_1', order_id: orderId, status: 'captured', captured: true, amount: 2000, currency: 'INR', notes: { providerId: 'prov_alice' } },
      ],
    });

    const missingMetaRes = await handlers._reconcileSingleOrderInternal(orderId);

    // 2. Order on gateway has different providerId
    mockFetchOrderImplementation = async () => ({
      id: orderId,
      amount: 2000,
      currency: 'INR',
      notes: { providerId: 'prov_malicious' },
    });

    const mismatchMetaRes = await handlers._reconcileSingleOrderInternal(orderId);

    const isMetadataProtected = missingMetaRes.status === 'missing_order_provider_metadata' &&
      mismatchMetaRes.status === 'order_provider_mismatch';

    record("Reconciliation Invariants: Missing or mismatched server-side Razorpay order metadata strictly rejected", isMetadataProtected);
    mockFetchOrderImplementation = null;
    mockFetchPaymentsImplementation = null;
  }

  // ---------------------------------------------------------------------------------
  // TEST 55: Payment Order ID Mismatch Check
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    const orderId = 'order_reconcile_order_id_check';
    await mockDb.collection('payments').doc(orderId).set({
      id: orderId,
      orderId: orderId,
      providerId: 'prov_alice',
      planId: 'jP3p8pl3upBi7b8GShhw',
      amount: 20,
      amountInPaise: 2000,
      currency: 'INR',
      status: 'created',
      createdAt: admin.firestore.Timestamp.now(),
    });

    // Payment has different order_id
    mockFetchPaymentsImplementation = async () => ({
      entity: 'collection',
      count: 1,
      items: [
        { id: 'pay_diff_order', order_id: 'order_completely_different', status: 'captured', captured: true, amount: 2000, currency: 'INR', notes: { providerId: 'prov_alice' } },
      ],
    });

    const res = await handlers._reconcileSingleOrderInternal(orderId);
    const isMismatchCaught = res.status === 'order_id_mismatch';

    record("Reconciliation Invariants: capturedPayment.order_id must match target orderId", isMismatchCaught);
    mockFetchPaymentsImplementation = null;
  }

  // ---------------------------------------------------------------------------------
  // TEST 56: Server-Side Dynamic Admin Authorization in adminReconcileOrderPayment
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    // Seed admin users
    await mockDb.collection('admin_users').doc('admin_active_1').set({ role: 'admin', status: 'active' });
    await mockDb.collection('admin_users').doc('admin_suspended_1').set({ role: 'admin', status: 'suspended' });

    const orderId = 'order_admin_auth_test_1';
    await mockDb.collection('payments').doc(orderId).set({
      id: orderId,
      orderId: orderId,
      providerId: 'prov_alice',
      planId: 'jP3p8pl3upBi7b8GShhw',
      amount: 20,
      amountInPaise: 2000,
      currency: 'INR',
      status: 'created',
      createdAt: admin.firestore.Timestamp.now(),
    });

    // 1. Authorized active admin: must succeed
    let activeAdminSuccess = false;
    try {
      const res = await handlers.adminReconcileOrderPayment.run({
        data: { orderId },
        auth: { uid: 'admin_active_1', token: { email: 'active_admin@customdomain.in' } },
      });
      activeAdminSuccess = res.status === 'success';
    } catch (e) {
      activeAdminSuccess = false;
    }

    // Reset order back to created for next check
    await mockDb.collection('payments').doc(orderId).update({ status: 'created', captured: false });

    // 2. Suspended admin: must be rejected with permission-denied
    let suspendedAdminDenied = false;
    try {
      await handlers.adminReconcileOrderPayment.run({
        data: { orderId },
        auth: { uid: 'admin_suspended_1', token: { email: 'suspended@customdomain.in' } },
      });
    } catch (e) {
      suspendedAdminDenied = e.code === 'permission-denied';
    }

    // 3. Regular non-admin user: must be rejected with permission-denied
    let nonAdminDenied = false;
    try {
      await handlers.adminReconcileOrderPayment.run({
        data: { orderId },
        auth: { uid: 'prov_alice', token: { email: 'prov_alice@gmail.com' } },
      });
    } catch (e) {
      nonAdminDenied = e.code === 'permission-denied';
    }

    // 4. Revoked admin whose doc was deleted from admin_users (even if their JWT still has admin: true claim)
    let revokedAdminDenied = false;
    try {
      await handlers.adminReconcileOrderPayment.run({
        data: { orderId },
        auth: { uid: 'admin_deleted_1', token: { admin: true, email: 'revoked@customdomain.in' } },
      });
    } catch (e) {
      revokedAdminDenied = e.code === 'permission-denied';
    }

    const isDynamicAuthCorrect = activeAdminSuccess && suspendedAdminDenied && nonAdminDenied && revokedAdminDenied;
    record("Admin Authorization: Dynamic admin_users authorization correctly permits active admin, blocks suspended/non-admin, and immediately revokes deleted admin regardless of claims", isDynamicAuthCorrect);
  }

  // ---------------------------------------------------------------------------------
  // TEST 57: Distinct Subscription Lifecycle: New Subscription vs Early Renewal
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    const now = new Date();
    const futureExpiry = new Date(now.getTime() + 15 * 24 * 60 * 60 * 1000); // 15 days remaining

    // Part A: New Provider (Inactive, no expiry)
    const newOrderId = 'order_new_provider_sub';
    await mockDb.collection('payments').doc(newOrderId).set({
      id: newOrderId,
      orderId: newOrderId,
      providerId: 'prov_bob',
      planId: 'jP3p8pl3upBi7b8GShhw',
      amount: 20,
      amountInPaise: 2000,
      currency: 'INR',
      status: 'created',
      createdAt: admin.firestore.Timestamp.now(),
    });
    mockFetchOrderImplementation = async (oid) => ({
      id: oid,
      amount: 2000,
      currency: 'INR',
      notes: { providerId: 'prov_bob' },
    });
    mockFetchPaymentsImplementation = async (oid) => ({
      entity: 'collection',
      count: 1,
      items: [
        { id: 'pay_bob_1', order_id: oid, status: 'captured', captured: true, amount: 2000, currency: 'INR', notes: { providerId: 'prov_bob' } },
      ],
    });

    await handlers._reconcileSingleOrderInternal(newOrderId);
    const bobDoc = (await mockDb.collection('providers').doc('prov_bob').get()).data();
    const isNewProviderCorrect = bobDoc.isSubscriptionActive === false &&
      bobDoc.subscriptionApprovalStatus === 'pending_approval' &&
      !bobDoc.subscriptionExpiry;

    // Part B: Early Renewal for active unexpired provider
    await mockDb.collection('providers').doc('prov_alice').update({
      isSubscriptionActive: true,
      subscriptionApprovalStatus: 'approved',
      subscriptionExpiry: admin.firestore.Timestamp.fromDate(futureExpiry),
    });

    const renewalOrderId = 'order_renewal_sub';
    await mockDb.collection('payments').doc(renewalOrderId).set({
      id: renewalOrderId,
      orderId: renewalOrderId,
      providerId: 'prov_alice',
      planId: 'jP3p8pl3upBi7b8GShhw',
      amount: 20,
      amountInPaise: 2000,
      currency: 'INR',
      isRenewal: true,
      status: 'created',
      createdAt: admin.firestore.Timestamp.now(),
    });
    mockFetchOrderImplementation = async (oid) => ({
      id: oid,
      amount: 2000,
      currency: 'INR',
      notes: { providerId: 'prov_alice' },
    });
    mockFetchPaymentsImplementation = async (oid) => ({
      entity: 'collection',
      count: 1,
      items: [
        { id: 'pay_alice_renew', order_id: oid, status: 'captured', captured: true, amount: 2000, currency: 'INR', notes: { providerId: 'prov_alice' } },
      ],
    });

    await handlers._reconcileSingleOrderInternal(renewalOrderId);
    const aliceDoc = (await mockDb.collection('providers').doc('prov_alice').get()).data();
    const isRenewalCorrect = aliceDoc.isSubscriptionActive === true &&
      aliceDoc.subscriptionApprovalStatus === 'approved' &&
      aliceDoc.renewalPendingOrderId === renewalOrderId &&
      aliceDoc.subscriptionExpiry !== undefined;

    const isLifecycleAccurate = isNewProviderCorrect && isRenewalCorrect;
    record("Subscription Lifecycle: New subscriptions remain inactive/pending while ongoing renewals preserve active status", isLifecycleAccurate);
    mockFetchOrderImplementation = null;
    mockFetchPaymentsImplementation = null;
  }

  // ---------------------------------------------------------------------------------
  // TEST 58: Concurrency & Transaction Invariant Guards & History Preservation
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    const orderId = 'order_tx_guard_test';

    // 1. Payment status changed to cancelled / refunded -> Aborts
    await mockDb.collection('payments').doc(orderId).set({
      id: orderId,
      orderId: orderId,
      providerId: 'prov_alice',
      planId: 'jP3p8pl3upBi7b8GShhw',
      amount: 20,
      amountInPaise: 2000,
      currency: 'INR',
      status: 'refunded',
      createdAt: admin.firestore.Timestamp.now(),
    });

    const statusAbortRes = await handlers._reconcileSingleOrderInternal(orderId);

    // 2. Provider doc missing -> Aborts
    const ghostOrderId = 'order_ghost_provider';
    await mockDb.collection('payments').doc(ghostOrderId).set({
      id: ghostOrderId,
      orderId: ghostOrderId,
      providerId: 'prov_nonexistent',
      planId: 'jP3p8pl3upBi7b8GShhw',
      amount: 20,
      amountInPaise: 2000,
      currency: 'INR',
      status: 'created',
      createdAt: admin.firestore.Timestamp.now(),
    });
    mockFetchOrderImplementation = async (oid) => ({
      id: oid,
      amount: 2000,
      currency: 'INR',
      notes: { providerId: 'prov_nonexistent' },
    });
    mockFetchPaymentsImplementation = async (oid) => ({
      entity: 'collection',
      count: 1,
      items: [
        { id: 'pay_ghost', order_id: oid, status: 'captured', captured: true, amount: 2000, currency: 'INR', notes: { providerId: 'prov_nonexistent' } },
      ],
    });

    const missingProvRes = await handlers._reconcileSingleOrderInternal(ghostOrderId);

    // 3. subscriptions/sub_<orderId> already active -> Overwrite protection triggers
    const activeSubOrderId = 'order_active_sub_protect';
    await mockDb.collection('payments').doc(activeSubOrderId).set({
      id: activeSubOrderId,
      orderId: activeSubOrderId,
      providerId: 'prov_alice',
      planId: 'jP3p8pl3upBi7b8GShhw',
      amount: 20,
      amountInPaise: 2000,
      currency: 'INR',
      status: 'created',
      createdAt: admin.firestore.Timestamp.now(),
    });
    await mockDb.collection('subscriptions').doc(`sub_${activeSubOrderId}`).set({
      id: `sub_${activeSubOrderId}`,
      status: 'active',
      approvalStatus: 'approved',
      providerId: 'prov_alice',
    });
    mockFetchOrderImplementation = async (oid) => ({
      id: oid,
      amount: 2000,
      currency: 'INR',
      notes: { providerId: 'prov_alice' },
    });
    mockFetchPaymentsImplementation = async (oid) => ({
      entity: 'collection',
      count: 1,
      items: [
        { id: 'pay_protect', order_id: oid, status: 'captured', captured: true, amount: 2000, currency: 'INR', notes: { providerId: 'prov_alice' } },
      ],
    });

    const overwriteProtectRes = await handlers._reconcileSingleOrderInternal(activeSubOrderId);
    const preservedSub = (await mockDb.collection('subscriptions').doc(`sub_${activeSubOrderId}`).get()).data();

    // 4. Original createdAt timestamp preservation in subscription record
    const preserveTimestampOrderId = 'order_preserve_created_at';
    const originalCreatedTime = '2026-10-20T10:00:00.000Z';
    await mockDb.collection('payments').doc(preserveTimestampOrderId).set({
      id: preserveTimestampOrderId,
      orderId: preserveTimestampOrderId,
      providerId: 'prov_alice',
      planId: 'jP3p8pl3upBi7b8GShhw',
      amount: 20,
      amountInPaise: 2000,
      currency: 'INR',
      status: 'created',
      createdAt: originalCreatedTime,
    });
    await mockDb.collection('subscriptions').doc(`sub_${preserveTimestampOrderId}`).set({
      id: `sub_${preserveTimestampOrderId}`,
      status: 'pending_approval',
      providerId: 'prov_alice',
      createdAt: originalCreatedTime,
    });
    mockFetchOrderImplementation = async (oid) => ({
      id: oid,
      amount: 2000,
      currency: 'INR',
      notes: { providerId: 'prov_alice' },
    });
    mockFetchPaymentsImplementation = async (oid) => ({
      entity: 'collection',
      count: 1,
      items: [
        { id: 'pay_ts_test', order_id: oid, status: 'captured', captured: true, amount: 2000, currency: 'INR', notes: { providerId: 'prov_alice' } },
      ],
    });

    await handlers._reconcileSingleOrderInternal(preserveTimestampOrderId);
    const reconciledSub = (await mockDb.collection('subscriptions').doc(`sub_${preserveTimestampOrderId}`).get()).data();
    const isCreatedAtPreserved = reconciledSub.createdAt === originalCreatedTime;

    const isGuarded = statusAbortRes.status === 'invalid_status' &&
      missingProvRes.status === 'provider_not_found' &&
      overwriteProtectRes.status === 'subscription_already_active' &&
      preservedSub.status === 'active' &&
      preservedSub.approvalStatus === 'approved' &&
      isCreatedAtPreserved;

    record("OCC Transaction Guards: Non-created status aborts, active history protected, and original createdAt timestamp preserved", isGuarded);
    mockFetchOrderImplementation = null;
    mockFetchPaymentsImplementation = null;
  }

  // ---------------------------------------------------------------------------------
  // TEST 59: razorpayWebhook - Webhook when subscription already active/approved commits payment capture safely without overwriting approved subscription or its expiry
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    const orderId = 'order_hook_already_active_sub';
    const subId = `sub_${orderId}`;
    const approvedExpiry = new Date(Date.now() + 45 * 24 * 60 * 60 * 1000).toISOString();
    const approvedCreatedAt = '2026-10-15T12:00:00.000Z';

    // 1. Initial State: Provider has approved subscription, but payment doc is still 'created'
    await mockDb.collection('providers').doc('prov_alice').update({
      isSubscriptionActive: true,
      subscriptionApprovalStatus: 'approved',
      subscriptionExpiry: approvedExpiry,
      subscriptionPlan: 'plan_popular',
    });

    await mockDb.collection('subscriptions').doc(subId).set({
      id: subId,
      providerId: 'prov_alice',
      planId: 'plan_popular',
      status: 'active',
      approvalStatus: 'approved',
      expiryDate: approvedExpiry,
      createdAt: approvedCreatedAt,
    });

    await mockDb.collection('payments').doc(orderId).set({
      id: orderId,
      orderId: orderId,
      providerId: 'prov_alice',
      planId: 'plan_popular',
      amount: 399.0,
      amountInPaise: 39900,
      currency: 'INR',
      status: 'created',
      captured: false,
    });

    const payloadObj = {
      event: 'payment.captured',
      payload: {
        payment: {
          entity: {
            id: 'pay_wh_already_approved_1',
            order_id: orderId,
            amount: 39900,
            currency: 'INR',
            notes: { providerId: 'prov_alice', planId: 'plan_popular' },
          },
        },
      },
    };
    const rawPayload = JSON.stringify(payloadObj);
    const sig = crypto.createHmac('sha256', TEST_WEBHOOK_SECRET).update(rawPayload).digest('hex');

    const req = {
      method: 'POST',
      headers: { 'x-razorpay-signature': sig },
      rawBody: Buffer.from(rawPayload),
      body: payloadObj,
    };
    const res = new MockResponse();
    await handlers.razorpayWebhook(req, res);

    const updatedPayment = (await mockDb.collection('payments').doc(orderId).get()).data();
    const updatedSub = (await mockDb.collection('subscriptions').doc(subId).get()).data();
    const updatedProv = (await mockDb.collection('providers').doc('prov_alice').get()).data();

    const isWebhookSafe = res.statusCode === 200 &&
      updatedPayment.status === 'success' &&
      updatedPayment.captured === true &&
      updatedPayment.webhookProcessed === true &&
      updatedPayment.paymentId === 'pay_wh_already_approved_1' &&
      updatedSub.status === 'active' &&
      updatedSub.approvalStatus === 'approved' &&
      updatedSub.expiryDate === approvedExpiry &&
      updatedProv.isSubscriptionActive === true &&
      updatedProv.subscriptionExpiry === approvedExpiry;

    record("razorpayWebhook Early Return Fix: Existing active/approved subscription safely commits payment capture without dropping writes or overwriting approved subscription/expiry", isWebhookSafe);
  }

  // ---------------------------------------------------------------------------------
  // TEST 60: adminApproveSubscription - Inactive or suspended admin is strictly rejected with permission-denied
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    await mockDb.collection('admin_users').doc('admin_suspended_approval').set({ role: 'admin', status: 'suspended' });
    const orderId = 'order_suspended_admin_approval_test';
    await mockDb.collection('payments').doc(orderId).set({
      id: orderId,
      orderId: orderId,
      providerId: 'prov_alice',
      planId: 'jP3p8pl3upBi7b8GShhw',
      amount: 20,
      amountInPaise: 2000,
      currency: 'INR',
      status: 'success',
      captured: true,
      liveVerified: true,
      paymentId: 'pay_valid_for_suspension_test',
    });

    let suspendedApprovalDenied = false;
    try {
      await handlers.adminApproveSubscription.run({
        data: { providerId: 'prov_alice', orderId },
        auth: { uid: 'admin_suspended_approval', token: { email: 'suspended@customadmin.in' } },
      });
    } catch (e) {
      suspendedApprovalDenied = e.code === 'permission-denied';
    }

    record("Admin Authorization: Suspended admin in admin_users is strictly rejected from approving subscriptions with permission-denied", suspendedApprovalDenied);
  }

  console.log('\n======================================================================');
  console.log(` RESULTS: ${passed}/${total} DIRECT HANDLER SECURITY TESTS PASSED`);
  console.log('======================================================================\n');

  if (passed !== total) {
    process.exit(1);
  }
}

runHandlerSecurityTests().catch((err) => {
  console.error('Fatal Test Runner Error:', err);
  process.exit(1);
});
