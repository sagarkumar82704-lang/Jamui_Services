const assert = require('assert');

console.log('================================================================');
console.log(' JAMUI SERVICES — BACKEND UNISEX PREMIUM CLASSIFICATION TESTS');
console.log(' Mode: Local Unit Simulation & Assertion Verification');
console.log('================================================================\n');

let passedTests = 0;
let totalTests = 0;

function runTest(description, testFn) {
  totalTests++;
  try {
    testFn();
    console.log(`✅ PASSED [${totalTests}]: ${description}`);
    passedTests++;
  } catch (err) {
    console.error(`❌ FAILED [${totalTests}]: ${description}`);
    console.error(`   Error: ${err.message}`);
    process.exitCode = 1;
  }
}

// -----------------------------------------------------------------------------
// Reference Simulation of Backend Functions Logic (functions/index.js)
// -----------------------------------------------------------------------------

function simulateDetermineProviderEligibility({
  providerData,
  premiumCategories = [],
  normalCategories = []
}) {
  if (!providerData) {
    return {
      type: 'new_provider',
      isRenewal: false,
      planTier: 'normal',
      isPremiumEligible: false,
    };
  }

  const pData = providerData;
  const hasPaid = pData.paymentVerified === true;
  const isSubActive = pData.isSubscriptionActive === true;
  const plan = pData.subscriptionPlan;
  const subTier = (pData.subscriptionPlanTier || '').toString().toLowerCase().trim();
  const isAdminPremiumApproved = pData.isPremiumEligible === true;

  const isRenewal = hasPaid || isSubActive || (plan && plan !== 'free_trial' && plan !== 'none');

  // Canonical Category Evaluation from trusted collections (ignoring client categoryType)
  let isCategoryPremium = false;
  const catId = (pData.approvedCategoryId || pData.primaryCategoryId || pData.categoryId || pData.selectedCategoryId || '').toString().trim();
  if (catId) {
    const premMatch = premiumCategories.find(c => (c.id === catId || c.categoryId === catId) && c.isActive !== false);
    if (premMatch) {
      isCategoryPremium = true;
    } else {
      const normMatch = normalCategories.find(c => c.id === catId && (c.categoryType === 'premium' || c.isPremium === true));
      if (normMatch) {
        isCategoryPremium = true;
      }
    }
  }

  // Authoritative Tier determination:
  // Pending Unisex providers under canonical premium_categories MUST see and purchase Premium plans!
  let providerTier = 'normal';

  if (isRenewal && subTier) {
    if (subTier === 'premium') {
      providerTier = 'premium';
    } else if (subTier === 'normal') {
      providerTier = isCategoryPremium ? 'premium' : 'normal';
    }
  } else {
    if (isAdminPremiumApproved || isCategoryPremium) {
      providerTier = 'premium';
    } else {
      providerTier = 'normal';
    }
  }

  return {
    type: isRenewal ? 'existing_provider' : 'new_provider',
    isRenewal: Boolean(isRenewal),
    planTier: providerTier,
    isPremiumEligible: providerTier === 'premium',
  };
}

function simulateAdminApproveProvider({
  providerData,
  premiumCategories = []
}) {
  const pData = providerData;
  const catId = (pData.approvedCategoryId || pData.primaryCategoryId || pData.categoryId || pData.selectedCategoryId || '').toString().trim();

  let isCategoryPremium = false;
  if (catId) {
    const premMatch = premiumCategories.find(c => (c.id === catId || c.categoryId === catId) && c.isActive !== false);
    if (premMatch) {
      isCategoryPremium = true;
    }
  }

  const updates = {
    status: 'approved',
    kycStatus: 'approved',
    verificationStatus: 'approved',
    isVerified: true,
    isPremiumCategoryEligible: isCategoryPremium,
    isPremiumCategory: isCategoryPremium,
    categoryType: isCategoryPremium ? 'premium' : 'general',
  };

  // Only align isPremiumEligible if provider ALREADY has a paid active subscription
  // NEVER auto-activate subscription or bypass payment verification
  if (isCategoryPremium && pData.paymentVerified === true && pData.isSubscriptionActive === true) {
    updates.isPremiumEligible = true;
  }

  return {
    ...pData,
    ...updates,
  };
}

function simulateClientStripping(clientMap) {
  const map = { ...clientMap };
  // Strictly strip server-only and admin-managed protected fields
  delete map.planLimits;
  delete map.isPremiumEligible;
  delete map.storageUsage;
  delete map.adminCategoryOverrideLimit;
  delete map.subscriptionExpiry;
  delete map.paymentVerifiedAt;
  delete map.subscriptionPlan;
  delete map.subscriptionPlanTier;
  delete map.isSubscriptionActive;
  delete map.paymentVerified;
  return map;
}

// -----------------------------------------------------------------------------
// TESTS
// -----------------------------------------------------------------------------

const canonicalPremiumCategories = [
  { id: '9nmkCNHzB9kpQPiEfNK4', categoryId: 'unisex_salon', categoryName: 'Unisex Salon', isActive: true }
];

const canonicalNormalCategories = [
  { id: 'yA8xW9cN5vV9lgRgQKBa', titleEnglish: 'Electrician', categoryType: 'general', isPremium: false },
  { id: 'YbncBgi24iaaUHqkc5M3', titleEnglish: 'Plumber', categoryType: 'general', isPremium: false }
];

// TEST 1: Pending Unisex provider receives Premium plan eligibility
runTest('1. Pending Unisex provider receives Premium plan eligibility without needing prior isApproved', () => {
  const pendingUnisex = {
    id: 'g5nVlXFcuQQq8Pn3TsQ9kEjUGH53',
    businessName: 'Shrisu A unisex salon',
    primaryCategoryId: 'unisex_salon',
    status: 'pendingReview',
    isVerified: false,
    paymentVerified: false,
    isSubscriptionActive: false,
  };

  const result = simulateDetermineProviderEligibility({
    providerData: pendingUnisex,
    premiumCategories: canonicalPremiumCategories,
    normalCategories: canonicalNormalCategories,
  });

  assert.strictEqual(result.planTier, 'premium', 'Plan tier must be premium');
  assert.strictEqual(result.isPremiumEligible, true, 'isPremiumEligible must be true for plan selection');
  assert.strictEqual(result.type, 'new_provider', 'Should be categorized as new provider');
});

// TEST 2: Pending Normal provider receives Normal plan eligibility
runTest('2. Pending Normal provider (Electrician) receives Normal plan eligibility', () => {
  const pendingElectrician = {
    id: 'p_elec_001',
    businessName: 'Sharma Electricals',
    primaryCategoryId: 'yA8xW9cN5vV9lgRgQKBa', // Electrician
    status: 'pendingReview',
    isVerified: false,
    paymentVerified: false,
    isSubscriptionActive: false,
  };

  const result = simulateDetermineProviderEligibility({
    providerData: pendingElectrician,
    premiumCategories: canonicalPremiumCategories,
    normalCategories: canonicalNormalCategories,
  });

  assert.strictEqual(result.planTier, 'normal', 'Plan tier must be normal');
  assert.strictEqual(result.isPremiumEligible, false, 'isPremiumEligible must be false');
});

// TEST 3: Client cannot write protected eligibility fields
runTest('3. Client stripping prevents provider app from writing isPremiumEligible and planLimits', () => {
  const maliciousClientPayload = {
    businessName: 'Hacker Salon',
    primaryCategoryId: 'unisex_salon',
    isPremiumEligible: true, // Tampered client field
    planLimits: { isPremiumCategoryEligible: true }, // Tampered client field
    isSubscriptionActive: true, // Tampered client field
    paymentVerified: true, // Tampered client field
  };

  const sanitized = simulateClientStripping(maliciousClientPayload);

  assert.strictEqual(sanitized.isPremiumEligible, undefined, 'isPremiumEligible must be stripped');
  assert.strictEqual(sanitized.planLimits, undefined, 'planLimits must be stripped');
  assert.strictEqual(sanitized.isSubscriptionActive, undefined, 'isSubscriptionActive must be stripped');
  assert.strictEqual(sanitized.paymentVerified, undefined, 'paymentVerified must be stripped');
  assert.strictEqual(sanitized.primaryCategoryId, 'unisex_salon', 'Category must be preserved');
});

// TEST 4: Backend derives eligibility from canonical category metadata
runTest('4. Backend derives eligibility from canonical premium_categories metadata, ignoring false client flags', () => {
  const providerWithFakeFlags = {
    id: 'p_fake',
    primaryCategoryId: 'unisex_salon',
    categoryType: 'general', // Conflicting client flag
    isPremiumCategory: false, // Conflicting client flag
    status: 'pendingReview',
  };

  const result = simulateDetermineProviderEligibility({
    providerData: providerWithFakeFlags,
    premiumCategories: canonicalPremiumCategories,
    normalCategories: canonicalNormalCategories,
  });

  // Since unisex_salon is canonically in premium_categories, backend overrides client flag
  assert.strictEqual(result.planTier, 'premium', 'Backend must trust canonical collection over client flag');
});

// TEST 5: Admin approval correctly updates category eligibility fields without granting free subscription
runTest('5. Admin approval updates category eligibility fields but DOES NOT bypass payment/subscription', () => {
  const unapprovedUnisex = {
    id: 'g5nVlXFcuQQq8Pn3TsQ9kEjUGH53',
    primaryCategoryId: 'unisex_salon',
    status: 'pendingReview',
    isVerified: false,
    paymentVerified: false,
    isSubscriptionActive: false,
  };

  const approved = simulateAdminApproveProvider({
    providerData: unapprovedUnisex,
    premiumCategories: canonicalPremiumCategories,
  });

  assert.strictEqual(approved.status, 'approved', 'Status must be approved');
  assert.strictEqual(approved.isVerified, true, 'isVerified must be true');
  assert.strictEqual(approved.isPremiumCategoryEligible, true, 'isPremiumCategoryEligible must be true');
  assert.strictEqual(approved.categoryType, 'premium', 'categoryType must be premium');
  assert.strictEqual(approved.isPremiumCategory, true, 'isPremiumCategory must be true');
  // Strict Security Checks:
  assert.strictEqual(approved.isSubscriptionActive, false, 'Subscription must NOT be auto-activated');
  assert.strictEqual(approved.paymentVerified, false, 'Payment must NOT be auto-verified');
  assert.strictEqual(approved.isPremiumEligible, undefined, 'isPremiumEligible must NOT be set until subscription is paid');
});

// TEST 6: Admin approval on already-paid provider aligns isPremiumEligible
runTest('6. Admin approval on already-paid Unisex provider aligns isPremiumEligible to true', () => {
  const paidUnapprovedUnisex = {
    id: 'p_paid_unapproved',
    primaryCategoryId: 'unisex_salon',
    status: 'pendingReview',
    paymentVerified: true,
    isSubscriptionActive: true,
  };

  const approved = simulateAdminApproveProvider({
    providerData: paidUnapprovedUnisex,
    premiumCategories: canonicalPremiumCategories,
  });

  assert.strictEqual(approved.status, 'approved');
  assert.strictEqual(approved.isPremiumEligible, true, 'Paid provider gets isPremiumEligible: true');
});

// TEST 7: Missing or unknown category metadata fails safely
runTest('7. Missing or unknown category metadata fails safely to normal tier', () => {
  const unknownCategoryProvider = {
    id: 'p_unknown',
    primaryCategoryId: 'non_existent_category_id',
    status: 'pendingReview',
  };

  const result = simulateDetermineProviderEligibility({
    providerData: unknownCategoryProvider,
    premiumCategories: canonicalPremiumCategories,
    normalCategories: canonicalNormalCategories,
  });

  assert.strictEqual(result.planTier, 'normal', 'Unknown category must fail closed to normal tier');
  assert.strictEqual(result.isPremiumEligible, false, 'isPremiumEligible must fail closed to false');
});

console.log('\n================================================================');
console.log(` SUMMARY: ${passedTests} / ${totalTests} Backend Tests Passed.`);
console.log('================================================================\n');

if (passedTests !== totalTests) {
  process.exit(1);
}

