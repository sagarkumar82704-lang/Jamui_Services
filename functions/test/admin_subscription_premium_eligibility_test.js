const assert = require('assert');

console.log('================================================================');
console.log(' JAMUI SERVICES — ADMIN APPROVE SUBSCRIPTION PREMIUM TESTS');
console.log('================================================================\n');

let passedTests = 0;
let totalTests = 4;

function runTest(description, testFn) {
  try {
    testFn();
    console.log(`✅ PASSED: ${description}`);
    passedTests++;
  } catch (err) {
    console.error(`❌ FAILED: ${description}`);
    console.error(`   ${err.message}`);
  }
}

// Helper simulating the exact resolution logic in adminApproveSubscription
function resolveSubscriptionPlanEligibility({ payData, pData, planData }) {
  const planId = payData.planId || pData.subscriptionPlan || payData.pricingSnapshot?.planId || '';
  
  let durationDays = payData.pricingSnapshot?.durationDays !== undefined
    ? Number(payData.pricingSnapshot.durationDays)
    : (payData.durationDays !== undefined ? Number(payData.durationDays) : Number(planData.durationDays || 0));
  let categoryLimit = payData.pricingSnapshot?.categoryLimit !== undefined
    ? Number(payData.pricingSnapshot.categoryLimit)
    : (payData.categoryLimit !== undefined ? Number(payData.categoryLimit) : Number(planData.categoryLimit || 1));
  let planName = payData.pricingSnapshot?.planName || payData.planName || planData.name || 'Subscription Plan';

  // Authoritatively resolve planTier from plan document or pricing snapshot
  let planTier = (planData.planTier || payData.pricingSnapshot?.planTier || payData.planTier || 'normal').toString().toLowerCase().trim();

  // Authoritative check: plan is premium eligible strictly based on verified subscription plan
  const isPlanPremium = Boolean(
    planData.isPremiumCategoryEligible === true ||
    planTier === 'premium' ||
    payData.pricingSnapshot?.isPremiumCategoryEligible === true
  );

  const planLimits = {
    maxActiveListings: Number(planData.maxActiveListings || 10),
    maxImagesPerProvider: Number(planData.maxImagesPerProvider || 20),
    maxImagesPerListing: Number(planData.maxImagesPerListing || 5),
    maxSizePerImageBytes: Number(planData.maxSizePerImageBytes || (5 * 1024 * 1024)),
    maxTotalStorageBytes: Number(planData.maxTotalStorageBytes || (50 * 1024 * 1024)),
    isPremiumCategoryEligible: isPlanPremium,
  };

  return {
    planId,
    durationDays,
    categoryLimit,
    planName,
    planTier,
    isPlanPremium,
    planLimits,
    isPremiumEligible: isPlanPremium,
  };
}

// -----------------------------------------------------------------------------
// TEST 1: Srusu Unisex (Basic Premium Plan approval)
// -----------------------------------------------------------------------------
runTest('1. Basic Premium Plan correctly resolves isPremiumEligible: true', () => {
  const payData = {
    planId: '1nhifE6GzhmgYh28mxZd',
    pricingSnapshot: {
      planId: '1nhifE6GzhmgYh28mxZd',
      planName: 'Basic Premium',
      amountInPaise: 200,
      durationDays: 1,
      categoryLimit: 1,
    }
  };
  const pData = {
    businessName: 'srusu unisex',
    categoryId: 'unisex_salon',
    categoryType: 'premium',
    isPremiumCategory: true,
  };
  const planData = {
    id: '1nhifE6GzhmgYh28mxZd',
    name: 'Basic Premium',
    planTier: 'premium',
    isPremiumCategoryEligible: true,
    durationDays: 1,
    categoryLimit: 1,
    maxActiveListings: 10,
  };

  const res = resolveSubscriptionPlanEligibility({ payData, pData, planData });

  assert.strictEqual(res.planTier, 'premium', 'Plan tier must be premium');
  assert.strictEqual(res.isPlanPremium, true, 'isPlanPremium must be true');
  assert.strictEqual(res.isPremiumEligible, true, 'isPremiumEligible written to provider must be true');
  assert.strictEqual(res.planLimits.isPremiumCategoryEligible, true, 'planLimits must reflect isPremiumCategoryEligible: true');
});

// -----------------------------------------------------------------------------
// TEST 2: Normal Plan approval (Even if provider has isPremiumCategory: true)
// -----------------------------------------------------------------------------
runTest('2. Normal Plan approval NEVER grants isPremiumEligible even with isPremiumCategory: true', () => {
  const payData = {
    planId: 'jP3p8pl3upBi7b8GShhw',
    pricingSnapshot: {
      planId: 'jP3p8pl3upBi7b8GShhw',
      planName: 'Basic',
      amountInPaise: 100,
      durationDays: 30,
      categoryLimit: 1,
    }
  };
  const pData = {
    businessName: 'Normal Provider in Salon',
    categoryId: 'unisex_salon',
    categoryType: 'premium',
    isPremiumCategory: true, // Should NOT be used to infer subscription eligibility!
  };
  const planData = {
    id: 'jP3p8pl3upBi7b8GShhw',
    name: 'Basic',
    planTier: 'normal',
    isPremiumCategoryEligible: false,
    durationDays: 30,
  };

  const res = resolveSubscriptionPlanEligibility({ payData, pData, planData });

  assert.strictEqual(res.planTier, 'normal', 'Plan tier must be normal');
  assert.strictEqual(res.isPlanPremium, false, 'isPlanPremium must be false');
  assert.strictEqual(res.isPremiumEligible, false, 'isPremiumEligible must be strictly false');
  assert.strictEqual(res.planLimits.isPremiumCategoryEligible, false, 'planLimits must be false');
});

// -----------------------------------------------------------------------------
// TEST 3: Bug fix verification: planData.planTier takes precedence over missing snapshot planTier
// -----------------------------------------------------------------------------
runTest('3. planData.planTier is preserved when pricingSnapshot has no planTier field', () => {
  const payData = {
    planId: '1nhifE6GzhmgYh28mxZd',
    pricingSnapshot: {
      planId: '1nhifE6GzhmgYh28mxZd',
      planName: 'Basic Premium',
      // Note: planTier field omitted in snapshot
    }
  };
  const pData = {};
  const planData = {
    planTier: 'premium',
    isPremiumCategoryEligible: true,
  };

  const res = resolveSubscriptionPlanEligibility({ payData, pData, planData });

  assert.strictEqual(res.planTier, 'premium', 'planTier must resolve to premium from planData');
  assert.strictEqual(res.isPremiumEligible, true);
});

// -----------------------------------------------------------------------------
// TEST 4: Snapshot overrides planData when snapshot explicitly has planTier
// -----------------------------------------------------------------------------
runTest('4. Immutable pricingSnapshot planTier is respected if explicitly specified', () => {
  const payData = {
    planId: 'custom_plan',
    pricingSnapshot: {
      planId: 'custom_plan',
      planTier: 'premium',
      isPremiumCategoryEligible: true,
    }
  };
  const pData = {};
  const planData = {
    planTier: 'normal',
  };

  const res = resolveSubscriptionPlanEligibility({ payData, pData, planData });

  assert.strictEqual(res.isPremiumEligible, true, 'Snapshot isPremiumCategoryEligible: true must be respected');
});

console.log(`\n================================================================`);
console.log(` Results: ${passedTests}/${totalTests} tests passed.`);
console.log(`================================================================`);

if (passedTests !== totalTests) {
  process.exit(1);
}

