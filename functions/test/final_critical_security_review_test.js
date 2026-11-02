/**
 * Jamui Services — Final Critical Security Review Test Suite
 * 
 * Local mock tests covering the 6 critical deployment review cases:
 * 1. Razorpay API fetch failure (Webhook with already-approved subscription)
 * 2. Payment not captured ('authorized' or uncaptured gateway status)
 * 3. Duplicate webhook safe acknowledgment & payment record truthfulness
 * 4. Already-approved subscription and expiry protection
 * 5. Suspended admin and missing admin_users document across all privileged handlers
 * 6. Concurrent approval (OCC) and renewal stacking
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
              this.store[collName][id] = Object.assign({}, this.store[collName][id], data);
            } else {
              this.store[collName][id] = JSON.parse(JSON.stringify(data));
            }
            this.docVersions.set(docPath, (this.docVersions.get(docPath) || 0) + 1);
          },
          update: async (data) => {
            if (!this.store[collName]?.[id]) {
              throw new Error(`Document ${docPath} does not exist for update.`);
            }
            this.store[collName][id] = Object.assign({}, this.store[collName][id], data);
            this.docVersions.set(docPath, (this.docVersions.get(docPath) || 0) + 1);
          },
          delete: async () => {
            if (this.store[collName]?.[id]) {
              delete this.store[collName][id];
              this.docVersions.set(docPath, (this.docVersions.get(docPath) || 0) + 1);
            }
          },
        };
      },
      where: query.where,
      limit: query.limit,
      get: query.get,
      add: async (data) => {
        const id = `auto_${Math.random().toString(36).substring(2, 10)}`;
        if (!this.store[collName]) this.store[collName] = {};
        this.store[collName][id] = JSON.parse(JSON.stringify(data));
        this.docVersions.set(`${collName}/${id}`, 1);
        return { id };
      },
    };
  }

  batch() {
    const ops = [];
    return {
      set: (docRef, data, options = {}) => {
        ops.push({ type: 'set', docRef, data, options });
      },
      update: (docRef, data) => {
        ops.push({ type: 'update', docRef, data });
      },
      delete: (docRef) => {
        ops.push({ type: 'delete', docRef });
      },
      commit: async () => {
        for (const op of ops) {
          if (op.type === 'set') {
            await op.docRef.set(op.data, op.options);
          } else if (op.type === 'update') {
            await op.docRef.update(op.data);
          } else if (op.type === 'delete') {
            await op.docRef.delete();
          }
        }
      },
    };
  }

  async runTransaction(updateFunction) {
    const maxRetries = 10;
    for (let attempt = 0; attempt < maxRetries; attempt++) {
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

      let conflict = false;
      for (const [path, versionAtRead] of readVersions.entries()) {
        const currentVersion = this.docVersions.get(path) || 0;
        if (currentVersion !== versionAtRead) {
          conflict = true;
          break;
        }
      }

      if (conflict) {
        await new Promise((r) => setTimeout(r, 10));
        continue;
      }

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

// Intercept admin.firestore()
const firestoreFn = () => mockDb;
firestoreFn.FieldValue = {
  serverTimestamp: () => new Date().toISOString(),
  arrayUnion: (...items) => items,
  delete: () => undefined,
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

// Intercept admin.auth()
const authFn = () => ({
  getUser: async (uid) => ({
    uid,
    phoneNumber: '+919999999999',
    email: `${uid}@jamuiservices.com`,
  }),
  updateUser: async () => ({}),
});
Object.defineProperty(Object.getPrototypeOf(admin), 'auth', {
  value: authFn,
  configurable: true,
  writable: true,
});

// Secrets
const TEST_KEY_ID = 'rzp_test_sec_key_12345';
const TEST_KEY_SECRET = 'sec_alphanumeric_secret_987654';
const TEST_WEBHOOK_SECRET = 'webhook_secret_xyz789';

process.env.RAZORPAY_KEY_ID = TEST_KEY_ID;
process.env.RAZORPAY_KEY_SECRET = TEST_KEY_SECRET;
process.env.RAZORPAY_WEBHOOK_SECRET = TEST_WEBHOOK_SECRET;

// Mock Razorpay
let mockFetchImplementation = null;

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
          amount: 39900,
          currency: 'INR',
        };
      },
    };
  }
}

require.cache[require.resolve('razorpay')] = {
  exports: MockRazorpay,
};

// Mock Response for Express Webhook
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

// Require exported handlers
const handlers = require('../index.js');

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
    },
    admin_users: {
      'admin_super': { role: 'super_admin', status: 'active' },
      'admin_regular': { role: 'admin', status: 'active' },
    },
    subscription_plans: {
      'plan_popular': {
        id: 'plan_popular',
        name: 'Popular Pro',
        price: 399.0,
        durationDays: 30,
        categoryLimit: 3,
        isActive: true,
      },
    },
    payments: {},
    subscriptions: {},
    audit_logs: {},
  };
}

async function runReviewTests() {
  console.log('======================================================================');
  console.log(' JAMUI SERVICES — FINAL CRITICAL SECURITY REVIEW REGRESSION TESTS     ');
  console.log(' (Local In-Memory Mock Testing — NOT Live Production Integration)     ');
  console.log('======================================================================\n');

  let passed = 0;
  let total = 0;

  function record(testName, passedCondition, extraInfo = '') {
    total++;
    if (passedCondition) {
      passed++;
      console.log(`✅ [PASS] Case ${total}: ${testName}${extraInfo ? ' (' + extraInfo + ')' : ''}`);
    } else {
      console.error(`❌ [FAIL] Case ${total}: ${testName}${extraInfo ? ' (' + extraInfo + ')' : ''}`);
    }
  }

  // ---------------------------------------------------------------------------------
  // CASE 1: Razorpay API fetch failure (Webhook with already approved subscription)
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    const orderId = 'order_wh_fetch_fail_test';
    const subId = `sub_${orderId}`;
    const approvedExpiry = new Date(Date.now() + 45 * 24 * 60 * 60 * 1000).toISOString();

    await mockDb.collection('providers').doc('prov_alice').update({
      isSubscriptionActive: true,
      subscriptionApprovalStatus: 'approved',
      subscriptionExpiry: approvedExpiry,
    });

    await mockDb.collection('subscriptions').doc(subId).set({
      id: subId,
      providerId: 'prov_alice',
      planId: 'plan_popular',
      status: 'active',
      approvalStatus: 'approved',
      expiryDate: approvedExpiry,
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

    // Mock fetch failure: ETIMEDOUT network failure
    mockFetchImplementation = async () => {
      throw new Error('ETIMEDOUT: Connection to api.razorpay.com timed out');
    };

    const payloadObj = {
      event: 'payment.captured',
      payload: {
        payment: {
          entity: {
            id: 'pay_fetch_fail_1',
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

    const paymentDoc = (await mockDb.collection('payments').doc(orderId).get()).data();
    const subDoc = (await mockDb.collection('subscriptions').doc(subId).get()).data();
    const provDoc = (await mockDb.collection('providers').doc('prov_alice').get()).data();

    const isFetchFailSafe = res.statusCode === 502 &&
      paymentDoc.status !== 'success' &&
      paymentDoc.captured === false &&
      paymentDoc.liveVerified === false &&
      paymentDoc.gatewayFetchError.includes('ETIMEDOUT') &&
      subDoc.status === 'active' &&
      subDoc.approvalStatus === 'approved' &&
      subDoc.expiryDate === approvedExpiry &&
      provDoc.subscriptionExpiry === approvedExpiry;

    record(
      "Razorpay API fetch failure: Unconfirmed payment is NOT marked captured/success; returns 502; approved sub preserved",
      isFetchFailSafe,
      `Status: ${res.statusCode}, captured: ${paymentDoc.captured}, status: ${paymentDoc.status}`
    );
    mockFetchImplementation = null;
  }

  // ---------------------------------------------------------------------------------
  // CASE 2: Payment not captured (Gateway returns status: 'authorized' or captured: false)
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    const orderId = 'order_wh_uncaptured_test';
    const subId = `sub_${orderId}`;
    const approvedExpiry = new Date(Date.now() + 45 * 24 * 60 * 60 * 1000).toISOString();

    await mockDb.collection('providers').doc('prov_alice').update({
      isSubscriptionActive: true,
      subscriptionApprovalStatus: 'approved',
      subscriptionExpiry: approvedExpiry,
    });

    await mockDb.collection('subscriptions').doc(subId).set({
      id: subId,
      providerId: 'prov_alice',
      planId: 'plan_popular',
      status: 'active',
      approvalStatus: 'approved',
      expiryDate: approvedExpiry,
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

    // Mock returns authorized (uncaptured)
    mockFetchImplementation = async (payId) => ({
      id: payId,
      order_id: orderId,
      status: 'authorized',
      captured: false,
      amount: 39900,
      currency: 'INR',
    });

    const payloadObj = {
      event: 'payment.captured',
      payload: {
        payment: {
          entity: {
            id: 'pay_auth_only_1',
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

    const paymentDoc = (await mockDb.collection('payments').doc(orderId).get()).data();
    const subDoc = (await mockDb.collection('subscriptions').doc(subId).get()).data();
    const provDoc = (await mockDb.collection('providers').doc('prov_alice').get()).data();

    const isUncapturedSafe = res.statusCode === 200 &&
      res.body.message === 'payment_not_captured' &&
      paymentDoc.status === 'pending' &&
      paymentDoc.paymentStatus === 'authorized' &&
      paymentDoc.captured === false &&
      paymentDoc.liveVerified === false &&
      subDoc.status === 'active' &&
      subDoc.approvalStatus === 'approved' &&
      provDoc.subscriptionExpiry === approvedExpiry;

    record(
      "Payment not captured: Gateway status 'authorized' recorded with captured:false, liveVerified:false, status:pending",
      isUncapturedSafe,
      `Response: ${res.body.message}, paymentStatus: ${paymentDoc.paymentStatus}, captured: ${paymentDoc.captured}`
    );
    mockFetchImplementation = null;
  }

  // ---------------------------------------------------------------------------------
  // CASE 3: Duplicate webhook safe acknowledgment & payment record truthfulness
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    const orderId = 'order_wh_duplicate_test';

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

    mockFetchImplementation = async (payId) => ({
      id: payId,
      order_id: orderId,
      status: 'captured',
      captured: true,
      amount: 39900,
      currency: 'INR',
    });

    const payloadObj = {
      event: 'payment.captured',
      payload: {
        payment: {
          entity: {
            id: 'pay_captured_legit_1',
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

    const req1 = {
      method: 'POST',
      headers: { 'x-razorpay-signature': sig },
      rawBody: Buffer.from(rawPayload),
      body: payloadObj,
    };
    const res1 = new MockResponse();
    await handlers.razorpayWebhook(req1, res1);

    const paymentAfter1 = (await mockDb.collection('payments').doc(orderId).get()).data();

    // Delivery 2: Exact duplicate webhook delivery
    let gatewayFetchCalledOnDuplicate = false;
    mockFetchImplementation = async () => {
      gatewayFetchCalledOnDuplicate = true;
      throw new Error('Should not call gateway fetch on duplicate fulfilled webhook!');
    };

    const res2 = new MockResponse();
    await handlers.razorpayWebhook(req1, res2);

    const paymentAfter2 = (await mockDb.collection('payments').doc(orderId).get()).data();

    const isDuplicateSafe = res2.statusCode === 200 &&
      res2.body.message === 'already_fulfilled' &&
      gatewayFetchCalledOnDuplicate === false &&
      paymentAfter2.status === 'success' &&
      paymentAfter2.captured === true &&
      paymentAfter2.paymentId === 'pay_captured_legit_1' &&
      paymentAfter2.webhookProcessed === true;

    record(
      "Duplicate webhook: Safely acknowledged (200 already_fulfilled) without altering truthful payment record",
      isDuplicateSafe,
      `Delivery 1: ${paymentAfter1.status}, Delivery 2: ${res2.body.message}`
    );
    mockFetchImplementation = null;
  }

  // ---------------------------------------------------------------------------------
  // CASE 4: Already-approved subscription protection (Confirmed gateway capture)
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    const orderId = 'order_wh_already_approved_protect_test';
    const subId = `sub_${orderId}`;
    const approvedExpiry = new Date(Date.now() + 60 * 24 * 60 * 60 * 1000).toISOString();

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
      createdAt: '2026-10-15T12:00:00.000Z',
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

    mockFetchImplementation = async (payId) => ({
      id: payId,
      order_id: orderId,
      status: 'captured',
      captured: true,
      amount: 39900,
      currency: 'INR',
    });

    const payloadObj = {
      event: 'payment.captured',
      payload: {
        payment: {
          entity: {
            id: 'pay_captured_approved_branch',
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

    const paymentDoc = (await mockDb.collection('payments').doc(orderId).get()).data();
    const subDoc = (await mockDb.collection('subscriptions').doc(subId).get()).data();
    const provDoc = (await mockDb.collection('providers').doc('prov_alice').get()).data();

    const isAlreadyApprovedProtected = res.statusCode === 200 &&
      res.body.message === 'already_active_payment_captured' &&
      paymentDoc.status === 'success' &&
      paymentDoc.captured === true &&
      paymentDoc.liveVerified === true &&
      paymentDoc.paymentId === 'pay_captured_approved_branch' &&
      subDoc.status === 'active' &&
      subDoc.approvalStatus === 'approved' &&
      subDoc.expiryDate === approvedExpiry &&
      provDoc.isSubscriptionActive === true &&
      provDoc.subscriptionExpiry === approvedExpiry;

    record(
      "Already-approved subscription: Confirmed captured payment commits capture while preserving existing approved subscription & expiry",
      isAlreadyApprovedProtected,
      `Payment status: ${paymentDoc.status}, captured: ${paymentDoc.captured}, subExpiry: preserved`
    );
    mockFetchImplementation = null;
  }

  // ---------------------------------------------------------------------------------
  // CASE 5: Suspended admin और missing admin_users document across ALL privileged handlers
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    await mockDb.collection('admin_users').doc('admin_suspended_user').set({
      role: 'admin',
      status: 'suspended',
      isActive: false,
    });

    const dummyOrderId = 'order_auth_review_test';
    await mockDb.collection('payments').doc(dummyOrderId).set({
      id: dummyOrderId,
      orderId: dummyOrderId,
      providerId: 'prov_alice',
      planId: 'plan_popular',
      amount: 399.0,
      amountInPaise: 39900,
      currency: 'INR',
      status: 'success',
      captured: true,
      liveVerified: true,
      paymentId: 'pay_auth_test_1',
    });

    // Subcase 5A: Missing admin_users document (with super admin email spoofing attempt)
    const missingAdminAuth = {
      uid: 'uid_missing_from_admin_users',
      token: { email: 'sk12@gmail.com', admin: true },
    };

    let missingAdminBlockedInAll = true;
    const privilegedCalls = [
      () => handlers.adminApproveSubscription.run({ data: { providerId: 'prov_alice', orderId: dummyOrderId }, auth: missingAdminAuth }),
      () => handlers.adminRejectSubscription.run({ data: { providerId: 'prov_alice', orderId: dummyOrderId }, auth: missingAdminAuth }),
      () => handlers.adminApproveProvider.run({ data: { providerId: 'prov_alice' }, auth: missingAdminAuth }),
      () => handlers.adminToggleProviderStatus.run({ data: { providerId: 'prov_alice', isActive: true }, auth: missingAdminAuth }),
      () => handlers.adminSoftDeleteProvider.run({ data: { providerId: 'prov_alice' }, auth: missingAdminAuth }),
      () => handlers.adminPermanentDeleteProvider.run({ data: { providerId: 'prov_alice', confirmationText: 'DELETE' }, auth: missingAdminAuth }),
      () => handlers.reviewCustomServiceApplication.run({ data: { applicationId: 'app_1', action: 'approve' }, auth: missingAdminAuth }),
      () => handlers.adminReconcileOrderPayment.run({ data: { orderId: dummyOrderId }, auth: missingAdminAuth }),
      () => handlers.createSubscriptionOrder.run({ data: { planId: 'plan_popular', providerId: 'prov_alice' }, auth: missingAdminAuth }),
    ];

    for (const fn of privilegedCalls) {
      try {
        await fn();
        missingAdminBlockedInAll = false;
      } catch (e) {
        if (e.code !== 'permission-denied') missingAdminBlockedInAll = false;
      }
    }

    // Subcase 5B: Suspended admin account in admin_users
    const suspendedAdminAuth = {
      uid: 'admin_suspended_user',
      token: { email: 'admin@jamuiservice.com', admin: true },
    };

    let suspendedAdminBlockedInAll = true;
    const suspendedCalls = [
      () => handlers.adminApproveSubscription.run({ data: { providerId: 'prov_alice', orderId: dummyOrderId }, auth: suspendedAdminAuth }),
      () => handlers.adminRejectSubscription.run({ data: { providerId: 'prov_alice', orderId: dummyOrderId }, auth: suspendedAdminAuth }),
      () => handlers.adminApproveProvider.run({ data: { providerId: 'prov_alice' }, auth: suspendedAdminAuth }),
      () => handlers.adminToggleProviderStatus.run({ data: { providerId: 'prov_alice', isActive: true }, auth: suspendedAdminAuth }),
      () => handlers.adminSoftDeleteProvider.run({ data: { providerId: 'prov_alice' }, auth: suspendedAdminAuth }),
      () => handlers.adminPermanentDeleteProvider.run({ data: { providerId: 'prov_alice', confirmationText: 'DELETE' }, auth: suspendedAdminAuth }),
      () => handlers.reviewCustomServiceApplication.run({ data: { applicationId: 'app_1', action: 'approve' }, auth: suspendedAdminAuth }),
      () => handlers.adminReconcileOrderPayment.run({ data: { orderId: dummyOrderId }, auth: suspendedAdminAuth }),
      () => handlers.createSubscriptionOrder.run({ data: { planId: 'plan_popular', providerId: 'prov_alice' }, auth: suspendedAdminAuth }),
    ];

    for (const fn of suspendedCalls) {
      try {
        await fn();
        suspendedAdminBlockedInAll = false;
      } catch (e) {
        if (e.code !== 'permission-denied') suspendedAdminBlockedInAll = false;
      }
    }

    // Subcase 5C: Legitimate admin with email unlinked in doc ID (backward-compatible email resolution)
    await mockDb.collection('admin_users').doc('unlinked_auto_doc_id').set({
      email: 'legit_operator@jamuiservices.com',
      role: 'admin',
      status: 'active',
    });

    const legitimateUnlinkedAuth = {
      uid: 'uid_fresh_firebase_auth_login',
      token: { email: 'legit_operator@jamuiservices.com' },
    };

    let legitimateAdminSuccess = false;
    try {
      const res = await handlers._verifyActiveAdmin({ auth: legitimateUnlinkedAuth });
      legitimateAdminSuccess = res.uid === 'uid_fresh_firebase_auth_login' && res.adminData.status === 'active';
    } catch (_) {
      legitimateAdminSuccess = false;
    }

    const isAuthReviewConsistent = missingAdminBlockedInAll && suspendedAdminBlockedInAll && legitimateAdminSuccess;

    record(
      "Admin authorization: Missing admin_users doc & suspended admins blocked across ALL handlers; legitimate admins safely preserved",
      isAuthReviewConsistent,
      `MissingBlocked: ${missingAdminBlockedInAll}, SuspendedBlocked: ${suspendedAdminBlockedInAll}, LegitPreserved: ${legitimateAdminSuccess}`
    );
  }

  // ---------------------------------------------------------------------------------
  // CASE 6: Concurrent approval (OCC) और renewal stacking
  // ---------------------------------------------------------------------------------
  {
    mockDb.reset(seedDefaultStore());
    const orderId = 'order_concurrent_approval_test';

    await mockDb.collection('payments').doc(orderId).set({
      id: orderId,
      orderId: orderId,
      providerId: 'prov_alice',
      planId: 'plan_popular',
      amount: 399.0,
      amountInPaise: 39900,
      currency: 'INR',
      status: 'success',
      captured: true,
      liveVerified: true,
      paymentId: 'pay_concurrent_1',
    });

    const authCtx = {
      uid: 'admin_super',
      token: { email: 'admin@jamuiservice.com' },
    };

    // Subcase 6A: Simultaneous concurrent approvals (Firestore OCC)
    const [call1, call2] = await Promise.allSettled([
      handlers.adminApproveSubscription.run({ data: { providerId: 'prov_alice', orderId }, auth: authCtx }),
      handlers.adminApproveSubscription.run({ data: { providerId: 'prov_alice', orderId }, auth: authCtx }),
    ]);

    const oneSucceeded = (call1.status === 'fulfilled' && call2.status === 'rejected') ||
      (call2.status === 'fulfilled' && call1.status === 'rejected');
    const failedReason = (call1.status === 'rejected' ? call1.reason : call2.reason)?.message;
    const isOccSafe = oneSucceeded && failedReason.includes('already been approved and activated');

    // Subcase 6B: Renewal stacking (Unexpired active subscription)
    const now = new Date();
    const existingExpiry = new Date(now.getTime() + 15 * 24 * 60 * 60 * 1000); // 15 days unexpired

    await mockDb.collection('providers').doc('prov_alice').update({
      isSubscriptionActive: true,
      subscriptionApprovalStatus: 'approved',
      subscriptionExpiry: admin.firestore.Timestamp.fromDate(existingExpiry),
      subscriptionPlan: 'plan_popular',
    });

    const renewalOrderId = 'order_renewal_stacking_test';
    await mockDb.collection('payments').doc(renewalOrderId).set({
      id: renewalOrderId,
      orderId: renewalOrderId,
      providerId: 'prov_alice',
      planId: 'plan_popular',
      amount: 399.0,
      amountInPaise: 39900,
      currency: 'INR',
      status: 'success',
      captured: true,
      liveVerified: true,
      paymentId: 'pay_renew_stack_1',
      isRenewal: true,
    });

    const renewalResult = await handlers.adminApproveSubscription.run({
      data: { providerId: 'prov_alice', orderId: renewalOrderId },
      auth: authCtx,
    });

    const updatedProv = (await mockDb.collection('providers').doc('prov_alice').get()).data();
    const newExpiryDate = updatedProv.subscriptionExpiry.toDate
      ? updatedProv.subscriptionExpiry.toDate()
      : new Date(updatedProv.subscriptionExpiry);

    // Stacking check: Existing expiry (15 days) + 30 days plan = ~45 days from now
    const totalRemainingDays = Math.round((newExpiryDate.getTime() - now.getTime()) / (24 * 60 * 60 * 1000));
    const isStackingAccurate = totalRemainingDays >= 44 && totalRemainingDays <= 46;

    const isConcurrencyAndStackingSafe = isOccSafe && isStackingAccurate;

    record(
      "Concurrent approval (OCC) & renewal stacking: Exactly one approval wins, second rejected; renewal stacked seamlessly from existing expiry",
      isConcurrencyAndStackingSafe,
      `OCC Conflict Handled: ${isOccSafe}, Stacked Days: ${totalRemainingDays} (expected ~45)`
    );
  }

  console.log('\n======================================================================');
  console.log(` RESULTS: ${passed}/${total} CRITICAL SECURITY REVIEW TESTS PASSED`);
  console.log('======================================================================\n');

  if (passed !== total) {
    process.exit(1);
  }
}

runReviewTests().catch((err) => {
  console.error('Fatal Test Runner Error:', err);
  process.exit(1);
});
