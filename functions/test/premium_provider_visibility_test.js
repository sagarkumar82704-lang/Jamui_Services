const assert = require('assert');

console.log('================================================================');
console.log(' JAMUI SERVICES — COMPREHENSIVE 12-POINT PREMIUM VISIBILITY TESTS');
console.log('================================================================\n');

let passedTests = 0;
let totalTests = 0;

function runTest(description, testFn) {
  totalTests++;
  try {
    testFn();
    console.log(`✅ PASSED [Test ${totalTests}]: ${description}`);
    passedTests++;
  } catch (err) {
    console.error(`❌ FAILED [Test ${totalTests}]: ${description}`);
    console.error(`   Error: ${err.message}`);
  }
}

// -----------------------------------------------------------------------------
// 1. BACKEND: Simulates adminApproveSubscription resolution logic
// -----------------------------------------------------------------------------
function resolveSubscriptionPlanEligibility({ payData = {}, pData = {}, planData = {} }) {
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
  // NEVER infer from categoryType, isPremiumCategory, category membership, or plan name string
  const isPlanPremium = Boolean(
    planData.isPremiumCategoryEligible === true ||
    planTier === 'premium' ||
    payData.pricingSnapshot?.isPremiumCategoryEligible === true
  );

  if (!durationDays || durationDays <= 0) {
    durationDays = Number(planData.durationDays || 0);
  }

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
// 2. BACKEND: Simulates approval activation and duplicate approval guard
// -----------------------------------------------------------------------------
function simulateApprovalActivation({ paymentDoc, providerDoc, planDoc, now = new Date() }) {
  // Guard 1: Duplicate approval check
  if (paymentDoc.adminApprovalStatus === 'approved') {
    throw new Error('failed-precondition: This subscription payment has already been approved and activated.');
  }

  // Guard 2: Captured check
  if (paymentDoc.status !== 'success' || paymentDoc.captured !== true || paymentDoc.liveVerified !== true) {
    throw new Error('failed-precondition: Payment is not verified as captured.');
  }

  const durationDays = Number(paymentDoc.durationDays || planDoc.durationDays || 30);
  let startDate = now;

  // Stacking for ongoing renewal
  if (providerDoc.isSubscriptionActive === true && providerDoc.subscriptionApprovalStatus === 'approved' && providerDoc.subscriptionExpiry) {
    const existingDate = new Date(providerDoc.subscriptionExpiry);
    if (existingDate > now) {
      startDate = existingDate;
    }
  }

  const expiryDate = new Date(startDate.getTime() + durationDays * 24 * 60 * 60 * 1000);

  // Return simulated mutations
  return {
    providerUpdate: {
      status: 'approved',
      kycStatus: 'approved',
      isVerified: true,
      isSubscriptionActive: true,
      subscriptionApprovalStatus: 'approved',
      subscriptionStartDate: startDate.toISOString(),
      subscriptionExpiry: expiryDate.toISOString(),
      isPremiumEligible: planDoc.isPremiumCategoryEligible === true || planDoc.planTier === 'premium',
    },
    paymentUpdate: {
      adminApprovalStatus: 'approved',
      approvedAt: now.toISOString(),
      expiryDate: expiryDate.toISOString(),
    }
  };
}

// -----------------------------------------------------------------------------
// 3. CLIENT-SIDE: Exact ServiceProviderModel.fromMap & ServiceProviderEntity getters
// -----------------------------------------------------------------------------
function parseServiceProviderModel(map, id = 'test_provider_id') {
  const kycStatusStr = map.kycStatus || map.verificationStatus || 'notSubmitted';
  const statusStr = map.status || map.verificationStatus || 'pendingReview';

  const isBlockedOrRejected = ['rejected', 'suspended', 'blocked'].includes(statusStr.toLowerCase()) ||
    kycStatusStr.toLowerCase() === 'rejected';

  const isExplicitApprovedStatus = ['approved', 'active'].includes(statusStr.toLowerCase()) ||
    kycStatusStr.toLowerCase() === 'approved';

  const isVerified = isExplicitApprovedStatus && !isBlockedOrRejected;
  const isAvailable = map.isAvailable !== undefined ? Boolean(map.isAvailable) : (map.isOnline !== undefined ? Boolean(map.isOnline) : true);

  // Missing isActive defaults to true, explicit false is preserved
  const isActive = map.isActive !== undefined ? Boolean(map.isActive) : true;
  const isDeleted = map.isDeleted !== undefined ? Boolean(map.isDeleted) : false;

  const rawPaymentVerified = Boolean(map.paymentVerified);
  const rawIsSubActive = Boolean(map.isSubscriptionActive);

  let subscriptionExpiry = null;
  if (map.subscriptionExpiry) {
    subscriptionExpiry = new Date(map.subscriptionExpiry);
  }

  // Exact Dart model resolution:
  // (map['isPremiumEligible'] as bool?) ??
  //     ((map['planLimits'] as Map?)?['isPremiumCategoryEligible'] as bool? ?? false)
  let isPremiumEligible = false;
  if (map.isPremiumEligible !== undefined && map.isPremiumEligible !== null) {
    isPremiumEligible = Boolean(map.isPremiumEligible);
  } else if (map.planLimits && map.planLimits.isPremiumCategoryEligible !== undefined && map.planLimits.isPremiumCategoryEligible !== null) {
    isPremiumEligible = Boolean(map.planLimits.isPremiumCategoryEligible);
  } else {
    isPremiumEligible = false; // Strictly fails closed
  }

  const categoryId = map.primaryCategoryId || map.categoryId || '';
  const categoryTitle = map.primaryCategoryTitle || map.categoryTitle || '';
  const selectedCategoryIds = Array.isArray(map.selectedCategoryIds) ? map.selectedCategoryIds : [categoryId];

  return {
    id,
    status: statusStr,
    kycStatus: kycStatusStr,
    isVerified,
    isAvailable,
    isActive,
    isDeleted,
    paymentVerified: rawPaymentVerified,
    isSubscriptionActive: rawIsSubActive,
    subscriptionExpiry,
    isPremiumEligible,
    categoryId,
    categoryTitle,
    selectedCategoryIds,
    // ServiceProviderEntity getters:
    get isApprovedAndLive() {
      if (this.isDeleted) return false;
      if (!this.isActive) return false;

      const s = this.status.toLowerCase().trim();
      const k = this.kycStatus.toLowerCase().trim();
      const isApproved = this.isVerified || s === 'approved' || s === 'active' || k === 'approved';
      const isBlocked = ['rejected', 'suspended', 'blocked'].includes(s) || k === 'rejected';

      if (!isApproved || isBlocked) return false;
      if (!this.isAvailable) return false;
      if (!this.paymentVerified) return false;
      if (!this.isSubscriptionActive) return false;
      if (!this.subscriptionExpiry || this.subscriptionExpiry.getTime() <= Date.now()) return false;

      return true;
    },
    get isPremiumApprovedAndLive() {
      return this.isApprovedAndLive && this.isPremiumEligible;
    },
    get isUnisexSalon() {
      const cId = this.categoryId.toLowerCase().trim();
      const cTitle = this.categoryTitle.toLowerCase().trim();
      return cId === 'unisex_salon' || cId === 'salon' || cTitle.includes('unisex') || cTitle.includes('यूनिसेक्स');
    }
  };
}

// =============================================================================
// TEST SUITE: 12 COMPREHENSIVE REQUIREMENTS
// =============================================================================

// CASE 1: Valid Premium provider is visible
runTest('1. Valid Premium provider is visible in Premium Category', () => {
  const futureExpiry = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();
  const rawDoc = {
    businessName: 'Luxe Unisex Salon',
    primaryCategoryId: 'unisex_salon',
    status: 'approved',
    kycStatus: 'approved',
    isAvailable: true,
    paymentVerified: true,
    isSubscriptionActive: true,
    subscriptionExpiry: futureExpiry,
    isPremiumEligible: true,
  };

  const parsed = parseServiceProviderModel(rawDoc);
  assert.strictEqual(parsed.isApprovedAndLive, true);
  assert.strictEqual(parsed.isPremiumEligible, true);
  assert.strictEqual(parsed.isPremiumApprovedAndLive, true);
});

// CASE 2: Normal plan provider is NOT visible in Premium Category (even if in Unisex Salon)
runTest('2. Normal plan provider in Unisex Salon is NEVER visible in Premium Category', () => {
  const futureExpiry = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();
  const rawDoc = {
    businessName: 'Standard Salon in Unisex',
    primaryCategoryId: 'unisex_salon',
    categoryType: 'premium',   // Should be ignored
    isPremiumCategory: true,   // Should be ignored
    status: 'approved',
    kycStatus: 'approved',
    isAvailable: true,
    paymentVerified: true,
    isSubscriptionActive: true,
    subscriptionExpiry: futureExpiry,
    isPremiumEligible: false,   // Strictly false for normal plan
  };

  const parsed = parseServiceProviderModel(rawDoc);
  assert.strictEqual(parsed.isApprovedAndLive, true, 'Live in general category');
  assert.strictEqual(parsed.isPremiumEligible, false);
  assert.strictEqual(parsed.isPremiumApprovedAndLive, false, 'Must NEVER be visible in Premium Category');
});

// CASE 3: Unpaid or uncaptured payment provider is hidden
runTest('3. Unpaid or uncaptured payment provider is hidden', () => {
  const futureExpiry = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();
  const rawDoc = {
    businessName: 'Unpaid Salon',
    primaryCategoryId: 'unisex_salon',
    status: 'approved',
    kycStatus: 'approved',
    isAvailable: true,
    paymentVerified: false, // NOT paid
    isSubscriptionActive: false,
    subscriptionExpiry: futureExpiry,
    isPremiumEligible: true,
  };

  const parsed = parseServiceProviderModel(rawDoc);
  assert.strictEqual(parsed.isApprovedAndLive, false);
  assert.strictEqual(parsed.isPremiumApprovedAndLive, false);
});

// CASE 4: Pending approval provider is hidden
runTest('4. Pending approval provider is hidden until approved', () => {
  const rawDoc = {
    businessName: 'Pending Activation Salon',
    primaryCategoryId: 'unisex_salon',
    status: 'pendingReview',
    adminApprovalStatus: 'pending_approval',
    paymentVerified: true,
    isSubscriptionActive: false, // Inactive until Admin Approves
    isPremiumEligible: false,
  };

  const parsed = parseServiceProviderModel(rawDoc);
  assert.strictEqual(parsed.isApprovedAndLive, false);
  assert.strictEqual(parsed.isPremiumApprovedAndLive, false);
});

// CASE 5: Expired subscription provider is hidden
runTest('5. Expired subscription provider is hidden', () => {
  const pastExpiry = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString(); // 1 day ago
  const rawDoc = {
    businessName: 'Srusu Unisex (Expired Plan)',
    primaryCategoryId: 'unisex_salon',
    status: 'approved',
    kycStatus: 'approved',
    isAvailable: true,
    paymentVerified: true,
    isSubscriptionActive: true,
    subscriptionExpiry: pastExpiry, // Expired
    isPremiumEligible: true,
  };

  const parsed = parseServiceProviderModel(rawDoc);
  assert.strictEqual(parsed.isApprovedAndLive, false, 'Expired subscription must fail');
  assert.strictEqual(parsed.isPremiumApprovedAndLive, false);
});

// CASE 6: Soft-deleted provider is hidden
runTest('6. Soft-deleted provider (isDeleted: true) is hidden', () => {
  const futureExpiry = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();
  const rawDoc = {
    businessName: 'Deleted Salon',
    primaryCategoryId: 'unisex_salon',
    isDeleted: true,
    status: 'approved',
    paymentVerified: true,
    isSubscriptionActive: true,
    subscriptionExpiry: futureExpiry,
    isPremiumEligible: true,
  };

  const parsed = parseServiceProviderModel(rawDoc);
  assert.strictEqual(parsed.isApprovedAndLive, false);
  assert.strictEqual(parsed.isPremiumApprovedAndLive, false);
});

// CASE 7: Missing isActive in legacy record is safely handled
runTest('7. Missing isActive in legacy valid record defaults to true and passes', () => {
  const futureExpiry = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();
  const rawDoc = {
    businessName: 'Legacy Srusu Unisex (No isActive field)',
    primaryCategoryId: 'unisex_salon',
    // isActive field is omitted / undefined
    status: 'approved',
    kycStatus: 'approved',
    isAvailable: true,
    paymentVerified: true,
    isSubscriptionActive: true,
    subscriptionExpiry: futureExpiry,
    isPremiumEligible: true,
  };

  const parsed = parseServiceProviderModel(rawDoc);
  assert.strictEqual(parsed.isActive, true, 'Missing isActive must default to true');
  assert.strictEqual(parsed.isApprovedAndLive, true);
  assert.strictEqual(parsed.isPremiumApprovedAndLive, true);
});

// CASE 8: Explicit isActive: false is strictly hidden
runTest('8. Explicit isActive: false provider is strictly hidden', () => {
  const futureExpiry = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();
  const rawDoc = {
    businessName: 'Deactivated Salon',
    primaryCategoryId: 'unisex_salon',
    isActive: false, // Explicitly disabled
    status: 'approved',
    kycStatus: 'approved',
    isAvailable: true,
    paymentVerified: true,
    isSubscriptionActive: true,
    subscriptionExpiry: futureExpiry,
    isPremiumEligible: true,
  };

  const parsed = parseServiceProviderModel(rawDoc);
  assert.strictEqual(parsed.isActive, false);
  assert.strictEqual(parsed.isApprovedAndLive, false, 'isActive: false must block visibility');
  assert.strictEqual(parsed.isPremiumApprovedAndLive, false);
});

// CASE 9: Missing or conflicting plan metadata fails closed (false)
runTest('9. Missing or conflicting plan metadata strictly fails closed', () => {
  // Case A: Missing plan data completely
  const resEmpty = resolveSubscriptionPlanEligibility({
    payData: {},
    pData: {},
    planData: {}
  });
  assert.strictEqual(resEmpty.isPlanPremium, false, 'Missing plan must fail closed');
  assert.strictEqual(resEmpty.isPremiumEligible, false);

  // Case B: Conflicting plan: plan document says normal, provider doc says premium
  const resConflict = resolveSubscriptionPlanEligibility({
    payData: { planId: 'normal_plan' },
    pData: { categoryType: 'premium', isPremiumCategory: true },
    planData: { planTier: 'normal', isPremiumCategoryEligible: false }
  });
  assert.strictEqual(resConflict.isPlanPremium, false);
  assert.strictEqual(resConflict.isPremiumEligible, false);
});

// CASE 10: Category Discovery suffers zero regression
runTest('10. General Category Discovery suffers zero regression', () => {
  const futureExpiry = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();

  const normalElectrician = parseServiceProviderModel({
    id: 'elec_1',
    businessName: 'Rajesh Electrician',
    primaryCategoryId: 'electrician',
    status: 'approved',
    kycStatus: 'approved',
    isAvailable: true,
    paymentVerified: true,
    isSubscriptionActive: true,
    subscriptionExpiry: futureExpiry,
    isPremiumEligible: false,
  });

  const premiumSalon = parseServiceProviderModel({
    id: 'salon_1',
    businessName: 'Grand Unisex Salon',
    primaryCategoryId: 'unisex_salon',
    status: 'approved',
    kycStatus: 'approved',
    isAvailable: true,
    paymentVerified: true,
    isSubscriptionActive: true,
    subscriptionExpiry: futureExpiry,
    isPremiumEligible: true,
  });

  // Both must be live in general category listings
  assert.strictEqual(normalElectrician.isApprovedAndLive, true, 'Electrician must be live');
  assert.strictEqual(premiumSalon.isApprovedAndLive, true, 'Salon must be live');

  // Premium filtering: only salon is premium
  assert.strictEqual(normalElectrician.isPremiumApprovedAndLive, false);
  assert.strictEqual(premiumSalon.isPremiumApprovedAndLive, true);
});

// CASE 11: Missing isPremiumEligible flag falls back to authoritative planLimits.isPremiumCategoryEligible
runTest('11. Missing isPremiumEligible resolves to true if authoritative planLimits.isPremiumCategoryEligible is true', () => {
  const futureExpiry = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();
  const rawDoc = {
    businessName: 'Verified Premium Provider (Legacy without top-level flag)',
    primaryCategoryId: 'unisex_salon',
    // isPremiumEligible is omitted / undefined
    planLimits: {
      isPremiumCategoryEligible: true, // Authoritative planLimits saved by Cloud Function
    },
    status: 'approved',
    kycStatus: 'approved',
    isAvailable: true,
    paymentVerified: true,
    isSubscriptionActive: true,
    subscriptionExpiry: futureExpiry,
  };

  const parsed = parseServiceProviderModel(rawDoc);
  assert.strictEqual(parsed.isPremiumEligible, true, 'Must resolve to true via authoritative planLimits');
  assert.strictEqual(parsed.isPremiumApprovedAndLive, true);
});

// CASE 12: Duplicate approval guard prevents extending expiry twice
runTest('12. Duplicate approval guard strictly blocks replay and prevents extending expiry twice', () => {
  const fixedNow = new Date('2026-10-29T10:00:00Z');
  const paymentDoc = {
    id: 'order_123',
    status: 'success',
    captured: true,
    liveVerified: true,
    adminApprovalStatus: 'pending_approval',
    durationDays: 30,
  };
  const providerDoc = {
    id: 'prov_123',
    isSubscriptionActive: false,
  };
  const planDoc = {
    id: 'plan_premium',
    planTier: 'premium',
    isPremiumCategoryEligible: true,
    durationDays: 30,
  };

  // First approval: Succeeds
  const firstActivation = simulateApprovalActivation({ paymentDoc, providerDoc, planDoc, now: fixedNow });
  assert.strictEqual(firstActivation.paymentUpdate.adminApprovalStatus, 'approved');
  assert.strictEqual(firstActivation.providerUpdate.subscriptionExpiry, '2026-11-28T10:00:00.000Z');

  // Mark payment doc as approved
  paymentDoc.adminApprovalStatus = 'approved';

  // Duplicate / second approval attempt: Must throw error and fail closed
  assert.throws(() => {
    simulateApprovalActivation({ paymentDoc, providerDoc, planDoc, now: fixedNow });
  }, /failed-precondition: This subscription payment has already been approved/, 'Duplicate approval must throw failed-precondition');
});

console.log('\n================================================================');
console.log(` Results: ${passedTests}/${totalTests} tests passed.`);
console.log('================================================================');

if (passedTests !== totalTests) {
  process.exit(1);
}
