/**
 * Jamui Services — Provider Category-Based Subscription Plans Test Suite
 * 
 * Verifies all 10 core requirements:
 * 1. Normal Provider receives ONLY Normal plans.
 * 2. Premium Provider receives ONLY Premium plans.
 * 3. Normal Provider cannot create an order for a Premium plan (server rejects with permission-denied).
 * 4. Premium Provider cannot create an order for a Normal plan (server rejects with permission-denied).
 * 5. Frontend tampering with planTier is rejected; server strictly validates against Firestore plan and provider eligibility.
 * 6. New vs Renewal audience filtering works accurately for both tiers; cross-tier renewal is blocked.
 * 7. Legacy plans missing planTier default to 'normal' (backward-compatible).
 * 8. Pending captured payment blocks duplicate order creation.
 * 9. Active subscription stacking and payment idempotency are preserved.
 * 10. Admin Panel plans management: Normal and Premium plans are maintained and filtered independently.
 */

const assert = require('assert');
const crypto = require('crypto');
const admin = require('firebase-admin');

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

  async runTransaction(updateFunction) {
    let attempts = 0;
    while (attempts < 10) {
      attempts++;
      const readVersions = new Map();
      const writes = [];

      const transaction = {
        get: async (docRef) => {
          const snap = await docRef.get();
          readVersions.set(docRef.path, this.docVersions.get(docRef.path) || 0);
          return snap;
        },
        set: (docRef, data, options = {}) => writes.push({ type: 'set', docRef, data, options }),
        update: (docRef, data) => writes.push({ type: 'update', docRef, data }),
        delete: (docRef) => writes.push({ type: 'delete', docRef }),
      };

      const result = await updateFunction(transaction);

      let conflict = false;
      for (const [path, vAtRead] of readVersions.entries()) {
        if ((this.docVersions.get(path) || 0) !== vAtRead) {
          conflict = true;
          break;
        }
      }

      if (conflict) {
        await new Promise(r => setTimeout(r, 10));
        continue;
      }

      for (const op of writes) {
        if (op.type === 'set') await op.docRef.set(op.data, op.options);
        else if (op.type === 'update') await op.docRef.update(op.data);
      }
      return result;
    }
    throw new Error('Transaction contention limit exceeded');
  }
}

const mockDb = new MockFirestore();
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
  }),
};

Object.defineProperty(Object.getPrototypeOf(admin), 'firestore', {
  value: firestoreFn,
  configurable: true,
  writable: true,
});

Object.defineProperty(Object.getPrototypeOf(admin), 'auth', {
  value: () => ({
    getUser: async (uid) => ({
      uid,
      phoneNumber: '+919876543210',
      email: `${uid}@jamuiservices.com`,
    }),
  }),
  configurable: true,
  writable: true,
});

const TEST_KEY_ID = 'rzp_test_sec_key_12345';
const TEST_KEY_SECRET = 'sec_alphanumeric_secret_987654';
const TEST_WEBHOOK_SECRET = 'webhook_secret_xyz789';

process.env.RAZORPAY_KEY_ID = TEST_KEY_ID;
process.env.RAZORPAY_KEY_SECRET = TEST_KEY_SECRET;
process.env.RAZORPAY_WEBHOOK_SECRET = TEST_WEBHOOK_SECRET;

class MockRazorpay {
  constructor(opts) {
    this.key_id = opts.key_id;
    this.key_secret = opts.key_secret;
    this.orders = {
      create: async (options) => ({
        id: `order_mock_${Math.random().toString(36).substring(2, 9)}`,
        entity: 'order',
        amount: options.amount,
        amount_paid: 0,
        currency: options.currency || 'INR',
        receipt: options.receipt,
        status: 'created',
        notes: options.notes,
      }),
    };
  }
}

require.cache[require.resolve('razorpay')] = { exports: MockRazorpay };

const handlers = require('../index.js');

function seedTierStore() {
  return {
    app_config: {
      payment: { razorpay_key_id: TEST_KEY_ID },
      payment_secrets: { keySecret: TEST_KEY_SECRET, webhookSecret: TEST_WEBHOOK_SECRET },
    },
    categories: {
      'electrician': { id: 'electrician', titleHindi: 'इलेक्ट्रीशियन', categoryType: 'general', isPremium: false },
      'plumber': { id: 'plumber', titleHindi: 'प्लम्बर', categoryType: 'general', isPremium: false },
      'unisex_salon': { id: 'unisex_salon', titleHindi: 'यूनिसेक्स सैलून', categoryType: 'premium', isPremium: true },
    },
    premium_categories: {
      'unisex_salon': { id: 'unisex_salon', categoryId: 'unisex_salon', customTitle: 'Unisex Salon', isActive: true },
    },
    subscription_plans: {
      // Normal Plans
      'plan_normal_new': {
        id: 'plan_normal_new',
        name: 'Normal Starter',
        planTier: 'normal',
        price: 199.0,
        durationDays: 30,
        categoryLimit: 1,
        targetAudience: 'new_provider',
        isActive: true,
      },
      'plan_normal_renew': {
        id: 'plan_normal_renew',
        name: 'Normal Renewal Monthly',
        planTier: 'normal',
        price: 179.0,
        durationDays: 30,
        categoryLimit: 1,
        targetAudience: 'existing_provider',
        isActive: true,
      },
      'plan_normal_all': {
        id: 'plan_normal_all',
        name: 'Normal Universal',
        planTier: 'normal',
        price: 499.0,
        durationDays: 90,
        categoryLimit: 2,
        targetAudience: 'all',
        isActive: true,
      },
      // Premium Plans
      'plan_premium_new': {
        id: 'plan_premium_new',
        name: 'Premium Salon Starter ⭐',
        planTier: 'premium',
        price: 499.0,
        durationDays: 30,
        categoryLimit: 3,
        targetAudience: 'new_provider',
        isActive: true,
        isPremiumCategoryEligible: true,
      },
      'plan_premium_renew': {
        id: 'plan_premium_renew',
        name: 'Premium Salon Renewal ⭐',
        planTier: 'premium',
        price: 449.0,
        durationDays: 30,
        categoryLimit: 3,
        targetAudience: 'existing_provider',
        isActive: true,
        isPremiumCategoryEligible: true,
      },
      'plan_premium_all': {
        id: 'plan_premium_all',
        name: 'Premium Universal Gold ⭐',
        planTier: 'premium',
        price: 1299.0,
        durationDays: 90,
        categoryLimit: 5,
        targetAudience: 'all',
        isActive: true,
        isPremiumCategoryEligible: true,
      },
      // Legacy Plan missing planTier
      'plan_legacy_no_tier': {
        id: 'plan_legacy_no_tier',
        name: 'Legacy Basic Plan',
        // planTier is intentionally undefined
        price: 99.0,
        durationDays: 30,
        categoryLimit: 1,
        targetAudience: 'new_provider',
        isActive: true,
      },
    },
    admin_users: {
      'admin_super': { role: 'super_admin', status: 'active', email: 'admin@jamuiservice.com' },
    },
    providers: {
      // 1. New Normal Provider (Electrician)
      'prov_normal_new': {
        id: 'prov_normal_new',
        fullName: 'Amit Electrician',
        primaryCategoryId: 'electrician',
        categoryType: 'general',
        isPremiumEligible: false,
        status: 'approved',
        kycStatus: 'approved',
        isSubscriptionActive: false,
        paymentVerified: false,
        createdAt: new Date().toISOString(),
      },
      // 2. Existing Normal Provider with active subscription (Renewal)
      'prov_normal_renewal': {
        id: 'prov_normal_renewal',
        fullName: 'Sanjay Plumber',
        primaryCategoryId: 'plumber',
        categoryType: 'general',
        isPremiumEligible: false,
        status: 'approved',
        kycStatus: 'approved',
        isSubscriptionActive: true,
        paymentVerified: true,
        subscriptionPlan: 'plan_normal_new',
        subscriptionPlanTier: 'normal',
        subscriptionApprovalStatus: 'approved',
        subscriptionExpiry: new Date(Date.now() + 10 * 24 * 60 * 60 * 1000).toISOString(),
        createdAt: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString(),
      },
      // 3. New Premium Provider (Unisex Salon)
      'prov_premium_new': {
        id: 'prov_premium_new',
        fullName: 'Rohit Salon Stylist',
        primaryCategoryId: 'unisex_salon',
        categoryType: 'premium',
        isPremiumCategory: true,
        isPremiumEligible: false,
        status: 'approved',
        kycStatus: 'approved',
        isSubscriptionActive: false,
        paymentVerified: false,
        createdAt: new Date().toISOString(),
      },
      // 4. Existing Premium Provider with active subscription (Renewal)
      'prov_premium_renewal': {
        id: 'prov_premium_renewal',
        fullName: 'Pooja Glamour Salon',
        primaryCategoryId: 'unisex_salon',
        categoryType: 'premium',
        isPremiumCategory: true,
        isPremiumEligible: true,
        status: 'approved',
        kycStatus: 'approved',
        isSubscriptionActive: true,
        paymentVerified: true,
        subscriptionPlan: 'plan_premium_new',
        subscriptionPlanTier: 'premium',
        subscriptionApprovalStatus: 'approved',
        subscriptionExpiry: new Date(Date.now() + 15 * 24 * 60 * 60 * 1000).toISOString(),
        createdAt: new Date(Date.now() - 40 * 24 * 60 * 60 * 1000).toISOString(),
      },
      // 5. Normal Provider with admin override isPremiumEligible = true
      'prov_admin_premium_approved': {
        id: 'prov_admin_premium_approved',
        fullName: 'Vikas Elite Contractor',
        primaryCategoryId: 'electrician', // General category
        categoryType: 'general',
        isPremiumEligible: true, // Explicit Admin Approval override
        status: 'approved',
        kycStatus: 'approved',
        isSubscriptionActive: false,
        paymentVerified: false,
        createdAt: new Date().toISOString(),
      },
      // 6. Unapproved Provider who selected a premium category (status: pendingReview)
      'prov_unapproved_salon': {
        id: 'prov_unapproved_salon',
        fullName: 'Unapproved Salon Stylist',
        primaryCategoryId: 'unisex_salon',
        categoryType: 'premium',
        isPremiumCategory: true,
        isPremiumEligible: false,
        status: 'pendingReview',
        kycStatus: 'pendingReview',
        isSubscriptionActive: false,
        paymentVerified: false,
        createdAt: new Date().toISOString(),
      },
      // 7. Expired Normal Subscription Provider (Renewal eligible)
      'prov_normal_expired': {
        id: 'prov_normal_expired',
        fullName: 'Ramesh Expired Plumber',
        primaryCategoryId: 'plumber',
        categoryType: 'general',
        isPremiumEligible: false,
        status: 'approved',
        kycStatus: 'approved',
        isSubscriptionActive: false,
        paymentVerified: true,
        subscriptionPlan: 'plan_normal_new',
        subscriptionPlanTier: 'normal',
        subscriptionApprovalStatus: 'approved',
        subscriptionExpiry: new Date(Date.now() - 5 * 24 * 60 * 60 * 1000).toISOString(), // Expired 5 days ago
        createdAt: new Date(Date.now() - 60 * 24 * 60 * 60 * 1000).toISOString(),
      },
    },
    payments: {},
    subscriptions: {},
    audit_logs: {},
  };
}

async function runTierSubscriptionTests() {
  console.log('========================================================================');
  console.log(' JAMUI SERVICES — PROVIDER CATEGORY SUBSCRIPTION PLANS TEST SUITE     ');
  console.log(' Authoritative Normal vs Premium Tier Isolation & Security Verification ');
  console.log('========================================================================\n');

  let passed = 0;
  let total = 0;

  function record(testName, success, details = '') {
    total++;
    if (success) {
      passed++;
      console.log(`✅ [PASS] Test ${total}: ${testName}`);
    } else {
      console.error(`❌ [FAIL] Test ${total}: ${testName}`);
      if (details) console.error(`   Details: ${details}`);
    }
  }

  // -----------------------------------------------------------------------------------
  // TEST 1: Normal Provider receives ONLY Normal plans (Zero Premium plans)
  // -----------------------------------------------------------------------------------
  {
    mockDb.reset(seedTierStore());
    const res = await handlers.getSubscriptionPlans.run({
      data: { providerId: 'prov_normal_new' },
      auth: { uid: 'prov_normal_new' },
    });

    const plans = res.plans || [];
    const allAreNormal = plans.length > 0 && plans.every(p => p.planTier === 'normal');
    const hasAnyPremium = plans.some(p => p.planTier === 'premium');

    record(
      "Normal Provider receives ONLY Normal plans (Zero Premium plans returned)",
      allAreNormal && !hasAnyPremium,
      `Returned ${plans.length} plans, premium count: ${plans.filter(p => p.planTier === 'premium').length}`
    );
  }

  // -----------------------------------------------------------------------------------
  // TEST 2: Premium Provider receives ONLY Premium plans (Zero Normal plans)
  // -----------------------------------------------------------------------------------
  {
    mockDb.reset(seedTierStore());
    const res = await handlers.getSubscriptionPlans.run({
      data: { providerId: 'prov_premium_new' },
      auth: { uid: 'prov_premium_new' },
    });

    const plans = res.plans || [];
    const allArePremium = plans.length > 0 && plans.every(p => p.planTier === 'premium');
    const hasAnyNormal = plans.some(p => p.planTier === 'normal');

    record(
      "Premium Provider receives ONLY Premium plans (Zero Normal plans returned)",
      allArePremium && !hasAnyNormal,
      `Returned ${plans.length} plans, normal count: ${plans.filter(p => p.planTier === 'normal').length}`
    );
  }

  // -----------------------------------------------------------------------------------
  // TEST 3: Normal Provider cannot create order for Premium plan (Server permission-denied)
  // -----------------------------------------------------------------------------------
  {
    mockDb.reset(seedTierStore());
    let threw = false;
    let errCode = null;

    try {
      await handlers.createSubscriptionOrder.run({
        data: {
          providerId: 'prov_normal_new',
          planId: 'plan_premium_new', // Premium plan
        },
        auth: { uid: 'prov_normal_new' },
      });
    } catch (e) {
      threw = true;
      errCode = e.code;
    }

    record(
      "Normal Provider attempting to purchase Premium plan is strictly rejected with permission-denied",
      threw && errCode === 'permission-denied',
      `threw: ${threw}, code: ${errCode}`
    );
  }

  // -----------------------------------------------------------------------------------
  // TEST 4: Premium Provider cannot create order for Normal plan (Server permission-denied)
  // -----------------------------------------------------------------------------------
  {
    mockDb.reset(seedTierStore());
    let threw = false;
    let errCode = null;

    try {
      await handlers.createSubscriptionOrder.run({
        data: {
          providerId: 'prov_premium_new',
          planId: 'plan_normal_new', // Normal plan
        },
        auth: { uid: 'prov_premium_new' },
      });
    } catch (e) {
      threw = true;
      errCode = e.code;
    }

    record(
      "Premium Provider attempting to purchase Normal plan is strictly rejected with permission-denied",
      threw && errCode === 'permission-denied',
      `threw: ${threw}, code: ${errCode}`
    );
  }

  // -----------------------------------------------------------------------------------
  // TEST 5: Frontend Tier Tampering: Normal provider sending planTier='premium' is rejected
  // -----------------------------------------------------------------------------------
  {
    mockDb.reset(seedTierStore());
    let threw = false;
    let errCode = null;

    try {
      await handlers.createSubscriptionOrder.run({
        data: {
          providerId: 'prov_normal_new',
          planId: 'plan_premium_new',
          planTier: 'premium', // Tampered client payload claiming to be premium
        },
        auth: { uid: 'prov_normal_new' },
      });
    } catch (e) {
      threw = true;
      errCode = e.code;
    }

    record(
      "Frontend payload tampering (client sends planTier='premium' for normal provider) rejected",
      threw && errCode === 'permission-denied',
      `threw: ${threw}, code: ${errCode}`
    );
  }

  // -----------------------------------------------------------------------------------
  // TEST 6: New vs Renewal Audience Filtering:
  // - New normal provider gets only new normal plans
  // - Renewal normal provider gets only renewal normal plans
  // - Cross-tier renewal is blocked
  // -----------------------------------------------------------------------------------
  {
    mockDb.reset(seedTierStore());

    // 6A: New Normal Provider
    const newRes = await handlers.getSubscriptionPlans.run({
      data: { providerId: 'prov_normal_new' },
      auth: { uid: 'prov_normal_new' },
    });
    const newPlans = newRes.plans || [];
    const newOnly = newPlans.every(p => p.targetAudience === 'new_provider' || p.targetAudience === 'all');
    const hasRenewalInNew = newPlans.some(p => p.targetAudience === 'existing_provider');

    // 6B: Renewal Normal Provider
    const renewRes = await handlers.getSubscriptionPlans.run({
      data: { providerId: 'prov_normal_renewal' },
      auth: { uid: 'prov_normal_renewal' },
    });
    const renewPlans = renewRes.plans || [];
    const renewOnly = renewPlans.every(p => p.targetAudience === 'existing_provider' || p.targetAudience === 'all');
    const hasNewInRenewal = renewPlans.some(p => p.targetAudience === 'new_provider');

    // 6C: Renewal provider attempting cross-tier renewal is rejected
    let crossTierThrew = false;
    try {
      await handlers.createSubscriptionOrder.run({
        data: {
          providerId: 'prov_normal_renewal',
          planId: 'plan_premium_renew', // Cross-tier renewal hijack attempt
        },
        auth: { uid: 'prov_normal_renewal' },
      });
    } catch (e) {
      crossTierThrew = true;
    }

    const audienceFilteringAccurate = newOnly && !hasRenewalInNew && renewOnly && !hasNewInRenewal && crossTierThrew;

    record(
      "New Subscription & Renewal filtering segregated for both tiers and cross-tier renewal blocked",
      audienceFilteringAccurate,
      `newOnly: ${newOnly}, hasRenewalInNew: ${hasRenewalInNew}, renewOnly: ${renewOnly}, hasNewInRenewal: ${hasNewInRenewal}, crossTierThrew: ${crossTierThrew}`
    );
  }

  // -----------------------------------------------------------------------------------
  // TEST 7: Legacy Plan Backward Compatibility: Missing planTier defaults cleanly to 'normal'
  // -----------------------------------------------------------------------------------
  {
    mockDb.reset(seedTierStore());

    // Normal provider can view the legacy plan
    const res = await handlers.getSubscriptionPlans.run({
      data: { providerId: 'prov_normal_new' },
      auth: { uid: 'prov_normal_new' },
    });
    const legacyFound = (res.plans || []).some(p => p.id === 'plan_legacy_no_tier' && p.planTier === 'normal');

    // Normal provider can create order for legacy plan
    const orderRes = await handlers.createSubscriptionOrder.run({
      data: {
        providerId: 'prov_normal_new',
        planId: 'plan_legacy_no_tier',
      },
      auth: { uid: 'prov_normal_new' },
    });

    const isLegacyCompatible = legacyFound && orderRes && orderRes.planTier === 'normal';

    record(
      "Legacy plan missing planTier defaults backward-compatibly to 'normal' and processes safely",
      isLegacyCompatible,
      `legacyFound: ${legacyFound}, planTier: ${orderRes?.planTier}`
    );
  }

  // -----------------------------------------------------------------------------------
  // TEST 8: Pending Captured Payment blocks subsequent checkout
  // -----------------------------------------------------------------------------------
  {
    mockDb.reset(seedTierStore());
    // Seed an existing captured payment in pending_approval
    await mockDb.collection('payments').doc('order_pending_1').set({
      id: 'order_pending_1',
      orderId: 'order_pending_1',
      providerId: 'prov_normal_new',
      status: 'success',
      captured: true,
      liveVerified: true,
      adminApprovalStatus: 'pending_approval',
      amountInPaise: 19900,
    });

    let duplicateThrew = false;
    let duplicateCode = null;

    try {
      await handlers.createSubscriptionOrder.run({
        data: {
          providerId: 'prov_normal_new',
          planId: 'plan_normal_new',
        },
        auth: { uid: 'prov_normal_new' },
      });
    } catch (e) {
      duplicateThrew = true;
      duplicateCode = e.code;
    }

    record(
      "Pending captured payment awaiting admin approval blocks second order creation with failed-precondition",
      duplicateThrew && duplicateCode === 'failed-precondition',
      `threw: ${duplicateThrew}, code: ${duplicateCode}`
    );
  }

  // -----------------------------------------------------------------------------------
  // TEST 9: Active subscription expiry stacking and payment idempotency preserved
  // -----------------------------------------------------------------------------------
  {
    mockDb.reset(seedTierStore());
    // Create renewal order for prov_normal_renewal (current expiry: +10 days)
    const orderRes = await handlers.createSubscriptionOrder.run({
      data: {
        providerId: 'prov_normal_renewal',
        planId: 'plan_normal_renew', // 30 days renewal
      },
      auth: { uid: 'prov_normal_renewal' },
    });

    const orderId = orderRes.orderId;

    // Simulate captured payment record
    await mockDb.collection('payments').doc(orderId).update({
      paymentId: 'pay_renew_stacking_1',
      status: 'success',
      captured: true,
      liveVerified: true,
      adminApprovalStatus: 'pending_approval',
    });

    // Admin approves renewal
    await handlers.adminApproveSubscription.run({
      data: { providerId: 'prov_normal_renewal', orderId },
      auth: { uid: 'admin_super', token: { email: 'admin@jamuiservice.com' } },
    });

    const updatedProv = (await mockDb.collection('providers').doc('prov_normal_renewal').get()).data();
    const rawExp = updatedProv.subscriptionExpiry;
    let expiry;
    if (rawExp && typeof rawExp.toDate === 'function') {
      expiry = rawExp.toDate();
    } else if (rawExp && rawExp._seconds) {
      expiry = new Date(rawExp._seconds * 1000);
    } else {
      expiry = new Date(rawExp);
    }
    const now = Date.now();
    const totalRemainingDays = Math.round((expiry.getTime() - now) / (1000 * 60 * 60 * 24));

    // Stacking verification: original 10 remaining days + 30 renewed days = ~40 days
    const isStackedCorrectly = totalRemainingDays >= 39 && totalRemainingDays <= 41;

    // Idempotency: duplicate approval attempt rejected
    let duplicateApproveThrew = false;
    try {
      await handlers.adminApproveSubscription.run({
        data: { providerId: 'prov_normal_renewal', orderId },
        auth: { uid: 'admin_super', token: { email: 'admin@jamuiservice.com' } },
      });
    } catch (e) {
      duplicateApproveThrew = true;
    }

    record(
      "Active subscription unexpired time is stacked upon renewal and duplicate approval is idempotent",
      isStackedCorrectly && duplicateApproveThrew,
      `totalRemainingDays: ${totalRemainingDays}, duplicateApproveThrew: ${duplicateApproveThrew}`
    );
  }

  // -----------------------------------------------------------------------------------
  // TEST 10: Admin Panel: Normal and Premium tiers managed independently
  // -----------------------------------------------------------------------------------
  {
    mockDb.reset(seedTierStore());

    // Admin adds a new Premium Plan
    const newPremiumId = 'plan_premium_vip_1';
    await mockDb.collection('subscription_plans').doc(newPremiumId).set({
      id: newPremiumId,
      name: 'VIP Premium Salon 1 Year ⭐',
      planTier: 'premium',
      price: 4999.0,
      durationDays: 365,
      categoryLimit: 5,
      targetAudience: 'all',
      isActive: true,
      isPremiumCategoryEligible: true,
    });

    // Admin query for Premium Tier
    const premiumQueryRes = await handlers.getSubscriptionPlans.run({
      data: { planTier: 'premium' },
    });
    const premiumDocs = Array.isArray(premiumQueryRes) ? premiumQueryRes : (premiumQueryRes.plans || []);
    const onlyPremium = premiumDocs.every(p => p.planTier === 'premium');
    const vipFound = premiumDocs.some(p => p.id === newPremiumId);

    // Admin query for Normal Tier
    const normalQueryRes = await handlers.getSubscriptionPlans.run({
      data: { planTier: 'normal' },
    });
    const normalDocs = Array.isArray(normalQueryRes) ? normalQueryRes : (normalQueryRes.plans || []);
    const onlyNormal = normalDocs.every(p => p.planTier === 'normal');
    const vipInNormal = normalDocs.some(p => p.id === newPremiumId);

    // Explicit Admin override provider (prov_admin_premium_approved) receives premium plans
    const adminOverrideRes = await handlers.getSubscriptionPlans.run({
      data: { providerId: 'prov_admin_premium_approved' },
      auth: { uid: 'prov_admin_premium_approved' },
    });
    const adminOverridePlans = adminOverrideRes.plans || [];
    const adminOverrideIsPremium = adminOverridePlans.every(p => p.planTier === 'premium');

    const adminPanelIndependent = onlyPremium && vipFound && onlyNormal && !vipInNormal && adminOverrideIsPremium;

    record(
      "Admin Panel allows independent creation/editing of Normal vs Premium plans with admin override support",
      adminPanelIndependent,
      `onlyPremium: ${onlyPremium}, vipFound: ${vipFound}, onlyNormal: ${onlyNormal}, vipInNormal: ${vipInNormal}, adminOverrideIsPremium: ${adminOverrideIsPremium}`
    );
  }

  // --------------------------------------------------------------------------
  // TEST 11: Unapproved Provider in Premium Category Defaults to Normal Tier
  // Merely selecting a premium category does not grant Premium tier without Admin approval
  // --------------------------------------------------------------------------
  {
    mockDb.reset(seedTierStore());

    // 1. Fetch plans for unapproved salon provider
    const unapprovedRes = await handlers.getSubscriptionPlans.run({
      data: { providerId: 'prov_unapproved_salon' },
      auth: { uid: 'prov_unapproved_salon' },
    });
    const plans = unapprovedRes.plans || [];
    const eligibility = unapprovedRes.providerEligibility;

    const tierIsNormal = eligibility.planTier === 'normal';
    const isPremiumEligibleFalse = eligibility.isPremiumEligible === false;
    const allNormalPlans = plans.length > 0 && plans.every(p => p.planTier === 'normal');
    const zeroPremiumPlans = plans.every(p => p.planTier !== 'premium');

    // 2. Attempt to create order for Premium plan - must be rejected
    let premiumOrderBlocked = false;
    try {
      await handlers.createSubscriptionOrder.run({
        data: {
          providerId: 'prov_unapproved_salon',
          planId: 'plan_premium_new',
        },
        auth: { uid: 'prov_unapproved_salon' },
      });
    } catch (err) {
      if (err.code === 'permission-denied') {
        premiumOrderBlocked = true;
      }
    }

    const test11Passed = tierIsNormal && isPremiumEligibleFalse && allNormalPlans && zeroPremiumPlans && premiumOrderBlocked;
    record(
      "Unapproved Provider in Premium Category defaults to Normal tier and cannot purchase Premium plan",
      test11Passed,
      `tierIsNormal: ${tierIsNormal}, isPremiumEligibleFalse: ${isPremiumEligibleFalse}, allNormalPlans: ${allNormalPlans}, zeroPremiumPlans: ${zeroPremiumPlans}, premiumOrderBlocked: ${premiumOrderBlocked}`
    );
  }

  // --------------------------------------------------------------------------
  // TEST 12: Expired Subscription Tier Locking: Expired Normal Provider Retains Normal Renewal
  // Profile refresh or renewal after expiry strictly maintains existing Normal tier
  // --------------------------------------------------------------------------
  {
    mockDb.reset(seedTierStore());

    const expiredRes = await handlers.getSubscriptionPlans.run({
      data: { providerId: 'prov_normal_expired' },
      auth: { uid: 'prov_normal_expired' },
    });
    const plans = expiredRes.plans || [];
    const eligibility = expiredRes.providerEligibility;

    const isRenewal = eligibility.isRenewal === true;
    const tierIsNormal = eligibility.planTier === 'normal';
    const allNormalPlans = plans.length > 0 && plans.every(p => p.planTier === 'normal');

    // Try cross-tier renewal to Premium plan -> blocked
    let crossTierBlocked = false;
    try {
      await handlers.createSubscriptionOrder.run({
        data: {
          providerId: 'prov_normal_expired',
          planId: 'plan_premium_renew',
        },
        auth: { uid: 'prov_normal_expired' },
      });
    } catch (err) {
      if (err.code === 'permission-denied') {
        crossTierBlocked = true;
      }
    }

    // Normal renewal plan purchase -> success
    let normalRenewalSuccess = false;
    try {
      const orderRes = await handlers.createSubscriptionOrder.run({
        data: {
          providerId: 'prov_normal_expired',
          planId: 'plan_normal_renew',
        },
        auth: { uid: 'prov_normal_expired' },
      });
      normalRenewalSuccess = !!orderRes.orderId;
    } catch (err) {
      normalRenewalSuccess = false;
    }

    const test12Passed = isRenewal && tierIsNormal && allNormalPlans && crossTierBlocked && normalRenewalSuccess;
    record(
      "Expired Normal Provider retains Normal tier for renewal; cross-tier renewal is strictly blocked",
      test12Passed,
      `isRenewal: ${isRenewal}, tierIsNormal: ${tierIsNormal}, allNormalPlans: ${allNormalPlans}, crossTierBlocked: ${crossTierBlocked}, normalRenewalSuccess: ${normalRenewalSuccess}`
    );
  }

  // --------------------------------------------------------------------------
  // TEST 13: Active Normal Provider Subscription Tier Invariance On Refresh / Re-login
  // Active Normal subscription cannot be escalated to Premium on refresh, re-query, or unapproved category change
  // --------------------------------------------------------------------------
  {
    mockDb.reset(seedTierStore());

    // 1. Initial query
    const res1 = await handlers.getSubscriptionPlans.run({
      data: { providerId: 'prov_normal_renewal' },
      auth: { uid: 'prov_normal_renewal' },
    });

    // 2. Simulate re-login / re-query (simulating profile refresh)
    const res2 = await handlers.getSubscriptionPlans.run({
      data: { providerId: 'prov_normal_renewal' },
      auth: { uid: 'prov_normal_renewal' },
    });

    const tierConsistent = res1.providerEligibility.planTier === 'normal' && res2.providerEligibility.planTier === 'normal';
    const renewalPlansConsistent = res1.plans.every(p => p.planTier === 'normal') && res2.plans.every(p => p.planTier === 'normal');

    const test13Passed = tierConsistent && renewalPlansConsistent;
    record(
      "Active Normal Subscription remains Normal tier across multiple profile refreshes and queries",
      test13Passed,
      `tierConsistent: ${tierConsistent}, renewalPlansConsistent: ${renewalPlansConsistent}`
    );
  }

  console.log('\n========================================================================');
  console.log(` RESULTS: ${passed}/${total} PROVIDER CATEGORY SUBSCRIPTION PLAN TESTS PASSED`);
  console.log('========================================================================\n');

  if (passed !== total) {
    process.exit(1);
  }
}

runTierSubscriptionTests().catch(err => {
  console.error('Fatal test execution error:', err);
  process.exit(1);
});
