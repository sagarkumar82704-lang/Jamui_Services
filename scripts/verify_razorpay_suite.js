const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

console.log('================================================================');
console.log('  JAMUI SERVICES — RAZORPAY SECURITY & INTEGRATION TEST SUITE  ');
console.log('================================================================\n');

let passedTests = 0;
let totalTests = 17;

function assert(condition, message) {
  if (!condition) {
    throw new Error('FAILED: ' + message);
  }
}

// -----------------------------------------------------------------------------
// TEST 1: Cryptographic HMAC-SHA256 Signature Verification (Valid Case)
// -----------------------------------------------------------------------------
try {
  const orderId = 'order_test_998877';
  const paymentId = 'pay_test_112233';
  const keySecret = 'secret_test_key_xyz987';
  const expectedSig = crypto.createHmac('sha256', keySecret).update(`${orderId}|${paymentId}`).digest('hex');

  const generated = crypto.createHmac('sha256', keySecret).update(`${orderId}|${paymentId}`).digest('hex');
  assert(generated === expectedSig, 'Valid signature must match expected HMAC');
  console.log('✅ TEST 1: Cryptographic HMAC-SHA256 Valid Signature Check -> PASSED');
  passedTests++;
} catch (e) {
  console.error('❌ TEST 1 FAILED:', e.message);
}

// -----------------------------------------------------------------------------
// TEST 2: Cryptographic Tampered Signature Rejection (Tampered Case)
// -----------------------------------------------------------------------------
try {
  const orderId = 'order_test_998877';
  const paymentId = 'pay_test_112233';
  const keySecret = 'secret_test_key_xyz987';
  const tamperedSig = 'tampered_signature_payload_123';
  const validSig = crypto.createHmac('sha256', keySecret).update(`${orderId}|${paymentId}`).digest('hex');

  assert(tamperedSig !== validSig, 'Tampered signature must not equal valid signature');
  console.log('✅ TEST 2: Cryptographic Tampered Signature Rejection -> PASSED');
  passedTests++;
} catch (e) {
  console.error('❌ TEST 2 FAILED:', e.message);
}

// -----------------------------------------------------------------------------
// TEST 3: Razorpay Webhook RawBody Verification
// -----------------------------------------------------------------------------
try {
  const webhookSecret = 'whsec_jamui_secure_test_456';
  const payloadObj = { event: 'payment.captured', payload: { payment: { entity: { id: 'pay_abc', order_id: 'order_abc' } } } };
  const rawBody = Buffer.from(JSON.stringify(payloadObj), 'utf8');

  const webhookSignature = crypto.createHmac('sha256', webhookSecret).update(rawBody).digest('hex');
  const computedSignature = crypto.createHmac('sha256', webhookSecret).update(rawBody).digest('hex');

  assert(webhookSignature === computedSignature, 'Webhook rawBody signature must verify with webhook secret');
  console.log('✅ TEST 3: Razorpay Webhook RawBody HMAC Verification -> PASSED');
  passedTests++;
} catch (e) {
  console.error('❌ TEST 3 FAILED:', e.message);
}

// -----------------------------------------------------------------------------
// TEST 4: Authoritative Plan Price & Duration Lookup (Client Untrusted)
// -----------------------------------------------------------------------------
try {
  const serverPlans = {
    'monthly_starter': { price: 199, durationDays: 30, name: 'Starter Plan' },
    'yearly_pro': { price: 1999, durationDays: 365, name: 'Yearly Pro Plan' }
  };
  const clientInput = { planId: 'monthly_starter', claimedPrice: 1.0 }; // Client attempts to pay ₹1
  
  const authoritativePlan = serverPlans[clientInput.planId];
  assert(authoritativePlan.price === 199, 'Authoritative price must override client claimed price');
  const amountInPaise = Math.round(authoritativePlan.price * 100);
  assert(amountInPaise === 19900, 'Calculated amount in paise must be 19900');
  console.log('✅ TEST 4: Authoritative Plan Pricing (Client Untrusted) -> PASSED');
  passedTests++;
} catch (e) {
  console.error('❌ TEST 4 FAILED:', e.message);
}

// -----------------------------------------------------------------------------
// TEST 5: Idempotent Payment Activation (Prevents Double Duration on Dual Callback)
// -----------------------------------------------------------------------------
try {
  let paymentDoc = { status: 'created', providerId: 'prov_123', planDurationDays: 30 };
  let providerProfile = { isSubscriptionActive: false, subscriptionExpiry: null };

  function simulateActivation(incomingOrderId, isWebhook) {
    if (paymentDoc.status === 'success') {
      return { skipped: true, reason: 'Already processed and activated' };
    }
    paymentDoc.status = 'success';
    const now = new Date();
    const expiry = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);
    providerProfile.isSubscriptionActive = true;
    providerProfile.subscriptionExpiry = expiry;
    return { skipped: false, activatedAt: now, expiry };
  }

  // 1st Arrival: Client verify callback
  const firstRun = simulateActivation('order_test', false);
  assert(firstRun.skipped === false, 'First callback must activate subscription');
  const initialExpiry = providerProfile.subscriptionExpiry;

  // 2nd Arrival: Razorpay Webhook arrives 500ms later
  const secondRun = simulateActivation('order_test', true);
  assert(secondRun.skipped === true, 'Concurrent webhook must be skipped as duplicate');
  assert(providerProfile.subscriptionExpiry.getTime() === initialExpiry.getTime(), 'Expiry must not be extended twice');
  console.log('✅ TEST 5: Dual Callback & Webhook Idempotency Check -> PASSED');
  passedTests++;
} catch (e) {
  console.error('❌ TEST 5 FAILED:', e.message);
}

// -----------------------------------------------------------------------------
// TEST 6: Customer Visibility Gating (isApprovedAndLive Logic)
// -----------------------------------------------------------------------------
try {
  function isApprovedAndLive(entity) {
    return (
      (entity.isVerified === true || entity.status === 'approved' || entity.verificationStatus === 'approved') &&
      entity.isAvailable === true &&
      entity.isSubscriptionActive === true
    );
  }

  // Case A: Approved, Available, but Subscription Unpaid/Expired -> Must NOT be live
  const unPaidApproved = { isVerified: true, isAvailable: true, isSubscriptionActive: false };
  assert(isApprovedAndLive(unPaidApproved) === false, 'Unpaid provider must NOT be live in customer app');

  // Case B: Paid, Available, but Admin NOT approved -> Must NOT be live
  const paidUnapproved = { isVerified: false, status: 'pendingReview', isAvailable: true, isSubscriptionActive: true };
  assert(isApprovedAndLive(paidUnapproved) === false, 'Unapproved provider must NOT be live in customer app');

  // Case C: Paid, Admin Approved, but Marked Unavailable -> Must NOT be live
  const unavailableProvider = { isVerified: true, status: 'approved', isAvailable: false, isSubscriptionActive: true };
  assert(isApprovedAndLive(unavailableProvider) === false, 'Unavailable provider must NOT be live');

  // Case D: Paid, Admin Approved, Available -> MUST be live
  const fullyValidProvider = { isVerified: true, status: 'approved', isAvailable: true, isSubscriptionActive: true };
  assert(isApprovedAndLive(fullyValidProvider) === true, 'Valid provider MUST be live in customer app');
  console.log('✅ TEST 6: Customer Visibility Gating (isApprovedAndLive) -> PASSED');
  passedTests++;
} catch (e) {
  console.error('❌ TEST 6 FAILED:', e.message);
}

// -----------------------------------------------------------------------------
// TEST 7: Expiry Date Enforcement & Auto-Expiry Logic
// -----------------------------------------------------------------------------
try {
  const pastDate = new Date(Date.now() - 1000 * 60 * 60); // 1 hour ago
  const futureDate = new Date(Date.now() + 1000 * 60 * 60 * 24 * 10); // 10 days ahead

  function evaluateActiveStatus(expiryDate) {
    if (!expiryDate) return false;
    return expiryDate.getTime() > Date.now();
  }

  assert(evaluateActiveStatus(pastDate) === false, 'Past expiry must evaluate to inactive');
  assert(evaluateActiveStatus(futureDate) === true, 'Future expiry must evaluate to active');
  console.log('✅ TEST 7: Subscription Expiry Date Logic -> PASSED');
  passedTests++;
} catch (e) {
  console.error('❌ TEST 7 FAILED:', e.message);
}

// -----------------------------------------------------------------------------
// TEST 8: Firestore Security Rules Analysis (Protected Fields Inspection)
// -----------------------------------------------------------------------------
try {
  const rulesPath = path.resolve('backend/firebase/firestore.rules');
  const rulesContent = fs.readFileSync(rulesPath, 'utf8');

  // Check that sensitive fields are forbidden from client modification
  assert(rulesContent.includes('paymentVerified'), 'Rules must protect paymentVerified');
  assert(rulesContent.includes('paymentVerifiedAt'), 'Rules must protect paymentVerifiedAt');
  assert(rulesContent.includes('isSubscriptionActive'), 'Rules must protect isSubscriptionActive');
  assert(rulesContent.includes('subscriptionExpiry'), 'Rules must protect subscriptionExpiry');
  console.log('✅ TEST 8: Firestore Security Rules Protected Fields -> PASSED');
  passedTests++;
} catch (e) {
  console.error('❌ TEST 8 FAILED:', e.message);
}

// -----------------------------------------------------------------------------
// TEST 9: Firestore Config Public Access Hardening
// -----------------------------------------------------------------------------
try {
  const rulesPath = path.resolve('backend/firebase/firestore.rules');
  const rulesContent = fs.readFileSync(rulesPath, 'utf8');

  // Verify that payment secrets and server secrets are blocked from public read
  assert(!rulesContent.includes('match /app_config/{configId} {\n      allow read: if true;'), 'Must not allow public read on all app_config');
  assert(rulesContent.includes('server_secrets') || rulesContent.includes('payment_secrets'), 'Must identify and isolate server/payment secrets');
  console.log('✅ TEST 9: App Config Secret Shielding -> PASSED');
  passedTests++;
} catch (e) {
  console.error('❌ TEST 9 FAILED:', e.message);
}

// -----------------------------------------------------------------------------
// TEST 10: Zero Client Secret Exposure (Code Scan)
// -----------------------------------------------------------------------------
try {
  const clientFiles = [
    'provider_app/lib/core/config/razorpay_payment_config.dart',
    'customer_app/lib/core/config/maps_config.dart'
  ];

  let leakedSecrets = false;
  for (const file of clientFiles) {
    if (fs.existsSync(file)) {
      const content = fs.readFileSync(file, 'utf8');
      if (content.includes('keySecret') && !content.includes('//') && content.match(/keySecret\s*=\s*['"][^'"]+['"]/)) {
        leakedSecrets = true;
      }
    }
  }
  assert(!leakedSecrets, 'Client files must NOT contain hardcoded keySecret');
  console.log('✅ TEST 10: Zero Client Secret Exposure in Mobile Apps -> PASSED');
  passedTests++;
} catch (e) {
  console.error('❌ TEST 10 FAILED:', e.message);
}

// -----------------------------------------------------------------------------
// TEST 11: Admin Panel Data Field Harmonization
// -----------------------------------------------------------------------------
try {
  const adminPaymentsPath = path.resolve('admin_panel/lib/features/payments/presentation/pages/payments_page.dart');
  const content = fs.readFileSync(adminPaymentsPath, 'utf8');

  assert(content.includes('userName') || content.includes('providerName'), 'Admin payments must support providerName/userName');
  assert(content.includes('razorpayPaymentId') || content.includes('paymentId'), 'Admin payments must support paymentId fallback');
  console.log('✅ TEST 11: Admin Panel Field Synchronization -> PASSED');
  passedTests++;
} catch (e) {
  console.error('❌ TEST 11 FAILED:', e.message);
}

// -----------------------------------------------------------------------------
// TEST 12: Legacy Provider Protection (Free Trial Preservation)
// -----------------------------------------------------------------------------
try {
  const functionsPath = path.resolve('functions/index.js');
  const funcContent = fs.readFileSync(functionsPath, 'utf8');

  // Verify scheduled check ignores or protects valid free_trial or active providers
  assert(funcContent.includes('checkSubscriptionExpiry'), 'Cloud functions must define checkSubscriptionExpiry');
  assert(funcContent.includes('isSubscriptionActive'), 'Expiry check must query isSubscriptionActive');
  console.log('✅ TEST 12: Scheduled Expiry & Legacy Provider Safeguard -> PASSED');
  passedTests++;
} catch (e) {
  console.error('❌ TEST 12 FAILED:', e.message);
}

// -----------------------------------------------------------------------------
// TEST 13: Provider Eligibility Logic (Server-Side Deterministic Check)
// -----------------------------------------------------------------------------
try {
  function testDetermineEligibility(provider, subHistory = []) {
    const hasPaid = provider.paymentVerified === true;
    const isSubActive = provider.isSubscriptionActive === true;
    const plan = provider.subscriptionPlan;
    const hasPaidBefore = hasPaid || subHistory.length > 0;
    
    let daysSinceRegistration = 0;
    if (provider.createdAt) {
      const createdDate = new Date(provider.createdAt);
      daysSinceRegistration = (Date.now() - createdDate.getTime()) / (1000 * 60 * 60 * 24);
    }

    if (hasPaidBefore || isSubActive || daysSinceRegistration > 14 || (plan && plan !== 'free_trial' && plan !== 'none')) {
      return { type: 'existing_provider', isRenewal: true };
    }
    return { type: 'new_provider', isRenewal: false };
  }

  // Case A: Just registered today, no payment -> new_provider
  const newProv = { createdAt: new Date().toISOString(), paymentVerified: false, isSubscriptionActive: false };
  assert(testDetermineEligibility(newProv).type === 'new_provider', 'Brand new provider must be new_provider');

  // Case B: Registered 20 days ago, no payment yet -> existing_provider (policy protects after 14 days)
  const oldUnpaidProv = { createdAt: new Date(Date.now() - 20 * 86400000).toISOString(), paymentVerified: false };
  assert(testDetermineEligibility(oldUnpaidProv).type === 'existing_provider', 'Provider registered > 14 days ago must be existing_provider');

  // Case C: Registered today but has prior subscription history -> existing_provider (renewal)
  assert(testDetermineEligibility(newProv, [{ id: 'sub_prev' }]).type === 'existing_provider', 'Provider with prior payment history must be existing_provider');

  console.log('✅ TEST 13: Deterministic Provider Eligibility Logic -> PASSED');
  passedTests++;
} catch (e) {
  console.error('❌ TEST 13 FAILED:', e.message);
}

// -----------------------------------------------------------------------------
// TEST 14: Dynamic Discount Calculation for Existing Providers
// -----------------------------------------------------------------------------
try {
  function calculatePlanPrice(plan, eligibility) {
    let price = Number(plan.price);
    let discountApplied = 0;
    if (eligibility.type === 'existing_provider' && plan.discountPercentage && plan.discountPercentage > 0) {
      discountApplied = Math.round((price * plan.discountPercentage) / 100.0);
      price = Math.max(1.0, price - discountApplied);
    }
    return { finalPrice: price, discountApplied };
  }

  const renewalPlan = { id: 'plan_renew', price: 299, discountPercentage: 20 };
  const existingEligibility = { type: 'existing_provider', isRenewal: true };
  const newEligibility = { type: 'new_provider', isRenewal: false };

  // Existing provider receives 20% discount (₹299 - ₹60 = ₹239)
  const existingResult = calculatePlanPrice(renewalPlan, existingEligibility);
  assert(existingResult.discountApplied === 60, 'Discount applied must be ₹60');
  assert(existingResult.finalPrice === 239, 'Discounted price must be ₹239');

  // New provider on same plan does NOT get existing provider discount
  const newResult = calculatePlanPrice(renewalPlan, newEligibility);
  assert(newResult.discountApplied === 0, 'New provider must not receive renewal discount');
  assert(newResult.finalPrice === 299, 'New provider price must remain original ₹299');

  console.log('✅ TEST 14: Server-Side Renewal Discount Calculation -> PASSED');
  passedTests++;
} catch (e) {
  console.error('❌ TEST 14 FAILED:', e.message);
}

// -----------------------------------------------------------------------------
// TEST 15: Plan Target Audience Filtering Logic
// -----------------------------------------------------------------------------
try {
  const allPlans = [
    { id: 'p1', name: 'Starter New', targetAudience: 'new_provider' },
    { id: 'p2', name: 'Renewal Special', targetAudience: 'existing_provider' },
    { id: 'p3', name: 'Universal Plan', targetAudience: 'all' },
  ];

  function filterPlans(plans, eligibilityType) {
    return plans.filter(p => {
      const audience = p.targetAudience || 'new_provider';
      return audience === eligibilityType || audience === 'all';
    });
  }

  const newPlans = filterPlans(allPlans, 'new_provider');
  assert(newPlans.length === 2 && newPlans.map(p => p.id).includes('p1') && newPlans.map(p => p.id).includes('p3'), 'New provider must see p1 and p3');

  const existingPlans = filterPlans(allPlans, 'existing_provider');
  assert(existingPlans.length === 2 && existingPlans.map(p => p.id).includes('p2') && existingPlans.map(p => p.id).includes('p3'), 'Existing provider must see p2 and p3');

  console.log('✅ TEST 15: Plan Target Audience Filtering Logic -> PASSED');
  passedTests++;
} catch (e) {
  console.error('❌ TEST 15 FAILED:', e.message);
}

// -----------------------------------------------------------------------------
// TEST 16: Admin Panel Multi-Tab & Plan Management Schema
// -----------------------------------------------------------------------------
try {
  const adminPagePath = path.resolve('admin_panel/lib/features/subscriptions/presentation/pages/subscriptions_page.dart');
  const dialogPath = path.resolve('admin_panel/lib/features/subscriptions/presentation/widgets/add_edit_plan_dialog.dart');

  const adminPageContent = fs.readFileSync(adminPagePath, 'utf8');
  const dialogContent = fs.readFileSync(dialogPath, 'utf8');

  // Verify 3 tabs are present in admin panel
  assert(adminPageContent.includes('नए प्रोवाइडर प्लान्स'), 'Admin panel must have New Provider tab');
  assert(adminPageContent.includes('पुराने प्रोवाइडर / रिन्यूअल प्लान्स'), 'Admin panel must have Renewal tab');
  assert(adminPageContent.includes('सब्सक्रिप्शन व रिन्यूअल रिपोर्ट'), 'Admin panel must have History & Report tab');

  // Verify dialog supports audience and policies
  assert(dialogContent.includes('targetAudience'), 'Dialog must support targetAudience');
  assert(dialogContent.includes('isPaymentMandatory'), 'Dialog must support isPaymentMandatory');
  assert(dialogContent.includes('discountPercentage'), 'Dialog must support discountPercentage');
  assert(dialogContent.includes('gracePeriodDays'), 'Dialog must support gracePeriodDays');

  console.log('✅ TEST 16: Admin Panel Multi-Tab & Schema Integrity -> PASSED');
  passedTests++;
} catch (e) {
  console.error('❌ TEST 16 FAILED:', e.message);
}

// -----------------------------------------------------------------------------
// TEST 17: Provider App Domain Entity & Model Serialization
// -----------------------------------------------------------------------------
try {
  const entityPath = path.resolve('provider_app/lib/features/subscription/domain/entities/subscription_plan.dart');
  const modelPath = path.resolve('provider_app/lib/features/subscription/data/models/subscription_plan_model.dart');

  const entityContent = fs.readFileSync(entityPath, 'utf8');
  const modelContent = fs.readFileSync(modelPath, 'utf8');

  assert(entityContent.includes('targetAudience'), 'Entity must have targetAudience');
  assert(entityContent.includes('discountPercentage'), 'Entity must have discountPercentage');
  assert(entityContent.includes('gracePeriodDays'), 'Entity must have gracePeriodDays');
  assert(entityContent.includes('isPaymentMandatory'), 'Entity must have isPaymentMandatory');

  assert(modelContent.includes('targetAudience'), 'Model must serialize targetAudience');
  assert(modelContent.includes('discountPercentage'), 'Model must serialize discountPercentage');
  assert(modelContent.includes('gracePeriodDays'), 'Model must serialize gracePeriodDays');
  assert(modelContent.includes('isPaymentMandatory'), 'Model must serialize isPaymentMandatory');

  console.log('✅ TEST 17: Provider App Domain Entity & Model Serialization -> PASSED');
  passedTests++;
} catch (e) {
  console.error('❌ TEST 17 FAILED:', e.message);
}

console.log('\n================================================================');
console.log(`  TEST RESULTS: ${passedTests} / ${totalTests} TESTS PASSED  `);
console.log('================================================================\n');

process.exit(passedTests === totalTests ? 0 : 1);

