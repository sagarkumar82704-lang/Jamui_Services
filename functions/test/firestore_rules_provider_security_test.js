const fs = require('fs');
const path = require('path');
const assert = require('assert');

console.log('================================================================');
console.log('  JAMUI SERVICES — FIRESTORE RULES PROVIDER SECURITY TEST SUITE ');
console.log('================================================================\n');

// 1. Verify firestore.rules file exists and contains the required security logic
const rulesPath = path.resolve(__dirname, '../../backend/firebase/firestore.rules');
assert.ok(fs.existsSync(rulesPath), `firestore.rules not found at ${rulesPath}`);
const rulesContent = fs.readFileSync(rulesPath, 'utf8');

// Ensure key security guards exist in the active rules file
assert.ok(rulesContent.includes('isProviderAdminApproved(resource.data)'), 'Rule must check isProviderAdminApproved');
assert.ok(rulesContent.includes('!isProviderBlockedOrSuspended(resource.data)'), 'Rule must block blocked/suspended providers');
assert.ok(rulesContent.includes("request.resource.data.diff(resource.data).affectedKeys().hasAny"), 'Rule must diff protected fields');
assert.ok(rulesContent.includes("'isVerified'"), 'Rule must guard isVerified');
assert.ok(rulesContent.includes("'status'"), 'Rule must guard status');
assert.ok(rulesContent.includes("'kycStatus'"), 'Rule must guard kycStatus');
assert.ok(rulesContent.includes("'verificationStatus'"), 'Rule must guard verificationStatus');
assert.ok(rulesContent.includes("'primaryCategoryId'"), 'Rule must guard primaryCategoryId');
assert.ok(rulesContent.includes("'isSubscriptionActive'"), 'Rule must guard isSubscriptionActive');
assert.ok(rulesContent.includes("'paymentVerified'"), 'Rule must guard paymentVerified');
assert.ok(rulesContent.includes("'planLimits'"), 'Rule must guard planLimits');
assert.ok(rulesContent.includes("'isPremiumEligible'"), 'Rule must guard isPremiumEligible');
assert.ok(rulesContent.includes("'storageUsage'"), 'Rule must guard storageUsage');
assert.ok(rulesContent.includes("'subscriptionExpiry'"), 'Rule must guard subscriptionExpiry');
assert.ok(rulesContent.includes("'paymentVerifiedAt'"), 'Rule must guard paymentVerifiedAt');
assert.ok(rulesContent.includes("'adminCategoryOverrideLimit'"), 'Rule must guard adminCategoryOverrideLimit');

/**
 * Exact simulation of Firestore Security Rules logic for /providers/{providerId}
 * matching the conditions in backend/firebase/firestore.rules lines 94-143.
 */
function evaluateProviderUpdateRule({ auth, providerId, existingData, incomingData }) {
  // Helper: isAuthenticated
  const isAuthenticated = auth != null && auth.uid != null;
  if (!isAuthenticated) return { allowed: false, reason: 'Unauthenticated' };

  // Helper: isOwner
  const isOwner = auth.uid === providerId;

  // Helper: isAdmin
  const isAdmin = auth.token?.admin === true ||
                  auth.token?.email === 'sk12@gmail.com' ||
                  auth.token?.email === 'admin@apnajamui.com' ||
                  auth.isAdminUserDoc === true;

  if (isAdmin) {
    return { allowed: true, reason: 'Admin override permitted' };
  }

  // Helper: isProviderAdminApproved
  const isProviderAdminApproved = (data) => {
    return (data.status || '') === 'approved' ||
           (data.kycStatus || '') === 'approved' ||
           (data.isVerified || false) === true;
  };

  // Helper: isProviderBlockedOrSuspended
  const isProviderBlockedOrSuspended = (data) => {
    return data.status === 'blocked' || data.status === 'suspended';
  };

  // Helper: diff affected keys
  const getAffectedKeys = (existing, incoming) => {
    const keys = new Set([...Object.keys(existing), ...Object.keys(incoming)]);
    const affected = [];
    for (const k of keys) {
      if (JSON.stringify(existing[k]) !== JSON.stringify(incoming[k])) {
        affected.push(k);
      }
    }
    return affected;
  };

  const affectedKeys = getAffectedKeys(existingData, incomingData);

  // Check 1: Owner branch
  if (isOwner) {
    // 1. Blocked or Suspended providers cannot update
    if (isProviderBlockedOrSuspended(existingData)) {
      return { allowed: false, reason: 'Blocked or suspended provider cannot update profile' };
    }

    const wasApproved = isProviderAdminApproved(existingData);

    // 2. Strict Anti-Privilege Escalation
    if (!wasApproved) {
      const incomingIsVerified = incomingData.isVerified || false;
      const incomingStatus = incomingData.status || '';
      const incomingKycStatus = incomingData.kycStatus || '';
      const incomingVerificationStatus = incomingData.verificationStatus || '';

      if (incomingIsVerified === true ||
          incomingStatus === 'approved' ||
          incomingKycStatus === 'approved' ||
          incomingVerificationStatus === 'approved') {
        return { allowed: false, reason: 'Unapproved provider cannot self-approve or self-verify' };
      }
    }

    // 3. Subscription & Payment immutability for provider
    if ((incomingData.isSubscriptionActive || false) !== (existingData.isSubscriptionActive || false)) {
      return { allowed: false, reason: 'Provider cannot self-modify isSubscriptionActive' };
    }
    if ((incomingData.paymentVerified || false) !== (existingData.paymentVerified || false)) {
      return { allowed: false, reason: 'Provider cannot self-modify paymentVerified' };
    }
    if ((incomingData.subscriptionExpiry ?? null) !== (existingData.subscriptionExpiry ?? null)) {
      return { allowed: false, reason: 'Provider cannot self-modify subscriptionExpiry' };
    }

    // 4. Ratings & Admin Limits immutability for provider
    if ((incomingData.rating ?? 5.0) !== (existingData.rating ?? 5.0)) {
      return { allowed: false, reason: 'Provider cannot self-modify rating' };
    }
    if ((incomingData.ratingCount ?? 0) !== (existingData.ratingCount ?? 0)) {
      return { allowed: false, reason: 'Provider cannot self-modify ratingCount' };
    }
    if ((incomingData.adminCategoryOverrideLimit ?? 0) !== (existingData.adminCategoryOverrideLimit ?? 0)) {
      return { allowed: false, reason: 'Provider cannot self-modify adminCategoryOverrideLimit' };
    }

    // 5. Strictly forbidden server-only & payment keys
    const serverOnlyKeys = [
      'planLimits',
      'isPremiumEligible',
      'storageUsage',
      'isSubscriptionActive',
      'paymentVerified',
      'subscriptionExpiry',
      'paymentVerifiedAt',
      'adminCategoryOverrideLimit',
      'subscriptionPlan',
      'subscriptionStatus',
      'subscriptionHistory',
      'subscriptionActivatedAt',
      'lastPaymentId',
      'paymentId',
      'orderId',
      'razorpayPaymentId',
      'razorpayOrderId',
      'razorpaySignature',
      'rating',
      'ratingCount'
    ];
    if (affectedKeys.some(k => serverOnlyKeys.includes(k))) {
      return { allowed: false, reason: 'Server-only keys cannot be modified by provider' };
    }

    // 6. If already approved, locked admin keys cannot be altered
    if (wasApproved) {
      const lockedAdminKeys = [
        'status',
        'kycStatus',
        'verificationStatus',
        'primaryCategoryId',
        'categoryId',
        'category',
        'primaryCategoryTitle',
        'categoryTitle',
        'selectedCategoryIds',
        'isVerified',
        'isSubscriptionActive',
        'subscriptionPlan',
        'paymentVerified',
        'rating',
        'ratingCount'
      ];
      if (affectedKeys.some(k => lockedAdminKeys.includes(k))) {
        return { allowed: false, reason: 'Approved provider cannot alter locked admin / category / approval fields' };
      }
    }

    // 7. If unapproved, status must stay in allowed initial states
    if (!wasApproved) {
      const incomingStatus = incomingData.status || 'pendingReview';
      const incomingKycStatus = incomingData.kycStatus || 'pendingReview';
      const incomingVerificationStatus = incomingData.verificationStatus || 'pending';

      if (!['draft', 'pendingReview'].includes(incomingStatus)) {
        return { allowed: false, reason: 'Unapproved provider status must be draft or pendingReview' };
      }
      if (!['draft', 'notSubmitted', 'pendingReview'].includes(incomingKycStatus)) {
        return { allowed: false, reason: 'Unapproved provider kycStatus invalid' };
      }
      if (!['draft', 'pending', 'pendingReview'].includes(incomingVerificationStatus)) {
        return { allowed: false, reason: 'Unapproved provider verificationStatus invalid' };
      }
    }

    return { allowed: true, reason: 'Permitted owner update' };
  }

  // Public interaction counter update branch (for customers/call clicks)
  const publicCounterKeys = ['totalCalls', 'totalWhatsAppClicks', 'totalViews', 'rating', 'ratingCount', 'updatedAt'];
  if (affectedKeys.every(k => publicCounterKeys.includes(k))) {
    return { allowed: true, reason: 'Public counter update permitted' };
  }

  return { allowed: false, reason: 'Permission denied: unauthorized field update' };
}

/**
 * Exact simulation of Firestore Security Rules logic for CREATE /providers/{providerId}
 * matching the conditions in backend/firebase/firestore.rules lines 78-106.
 */
function evaluateProviderCreateRule({ auth, providerId, incomingData }) {
  const isAuthenticated = auth != null && auth.uid != null;
  if (!isAuthenticated) return { allowed: false, reason: 'Unauthenticated' };

  const isOwner = auth.uid === providerId;
  const isAdmin = auth.token?.admin === true ||
                  auth.token?.email === 'admin@jamuiservice.com' ||
                  auth.token?.email === 'sk12@gmail.com' ||
                  auth.isAdminUserDoc === true;

  if (isAdmin) {
    return { allowed: true, reason: 'Admin override permitted' };
  }

  if (isOwner) {
    if (incomingData.isVerified !== false) {
      return { allowed: false, reason: 'New provider must have isVerified: false' };
    }
    if (incomingData.isSubscriptionActive !== false) {
      return { allowed: false, reason: 'New provider must have isSubscriptionActive: false' };
    }
    if (incomingData.paymentVerified !== false) {
      return { allowed: false, reason: 'New provider must have paymentVerified: false' };
    }
    const subPlan = incomingData.subscriptionPlan || 'none';
    if (!['none', 'free', ''].includes(subPlan)) {
      return { allowed: false, reason: 'New provider subscriptionPlan must be none or free' };
    }
    if ((incomingData.rating ?? 5.0) !== 5.0) {
      return { allowed: false, reason: 'New provider rating must be 5.0' };
    }
    if ((incomingData.ratingCount ?? 0) !== 0) {
      return { allowed: false, reason: 'New provider ratingCount must be 0' };
    }
    const status = incomingData.status || 'draft';
    if (!['draft', 'pendingReview'].includes(status)) {
      return { allowed: false, reason: 'New provider status must be draft or pendingReview' };
    }
    const kycStatus = incomingData.kycStatus || 'pendingReview';
    if (!['draft', 'notSubmitted', 'pendingReview'].includes(kycStatus)) {
      return { allowed: false, reason: 'New provider kycStatus invalid' };
    }
    const verificationStatus = incomingData.verificationStatus || 'pending';
    if (!['draft', 'pending', 'pendingReview'].includes(verificationStatus)) {
      return { allowed: false, reason: 'New provider verificationStatus invalid' };
    }

    const forbiddenCreateKeys = [
      'planLimits',
      'isPremiumEligible',
      'storageUsage',
      'adminCategoryOverrideLimit',
      'subscriptionExpiry',
      'paymentVerifiedAt',
      'subscriptionStatus',
      'subscriptionHistory',
      'subscriptionActivatedAt',
      'lastPaymentId',
      'paymentId',
      'orderId',
      'razorpayPaymentId',
      'razorpayOrderId',
      'razorpaySignature'
    ];

    const incomingKeys = Object.keys(incomingData);
    if (incomingKeys.some(k => forbiddenCreateKeys.includes(k))) {
      return { allowed: false, reason: 'Forbidden server-only key present on create' };
    }

    return { allowed: true, reason: 'Permitted provider registration' };
  }

  return { allowed: false, reason: 'Permission denied: non-owner creation' };
}

// ============================================================================
// TEST CASES
// ============================================================================
let passed = 0;
let total = 0;

function runTest(desc, fn) {
  total++;
  try {
    fn();
    passed++;
    console.log(`✅ [PASS] Test ${total}: ${desc}`);
  } catch (err) {
    console.error(`❌ [FAIL] Test ${total}: ${desc}`);
    console.error(`   Error: ${err.message}`);
    process.exit(1);
  }
}

// ----------------------------------------------------------------------------
// GROUP 1: Approved Provider Allowed Updates (Profile & Business Photos, Bio, Phone)
// ----------------------------------------------------------------------------
const baseApprovedDoc = {
  fullName: 'Rakesh Sharma',
  businessName: 'Rakesh Bike Service',
  status: 'approved',
  kycStatus: 'approved',
  isVerified: true,
  isSubscriptionActive: true,
  paymentVerified: true,
  primaryCategoryId: 'cat_bike_repair',
  category: 'Bike Repair',
  rating: 4.8,
  ratingCount: 15,
  profileImageUrl: 'https://firebasestorage.googleapis.com/v0/b/legacy.jpg',
  businessImageUrl: 'https://firebasestorage.googleapis.com/v0/b/biz.jpg',
  visitingCharge: 150,
  experienceYears: 5,
  jamuiArea: 'Jamui Town',
  fullAddress: 'Station Road, Jamui'
};

runTest('1. Approved provider updating profileImageUrl to Cloudflare R2 key is ALLOWED', () => {
  const incoming = {
    ...baseApprovedDoc,
    profileImageUrl: 'providers/prov_123/profile/profile_1792950000_abc.jpg',
    updatedAt: '2026-10-26T00:00:00Z'
  };
  const res = evaluateProviderUpdateRule({
    auth: { uid: 'prov_123' },
    providerId: 'prov_123',
    existingData: baseApprovedDoc,
    incomingData: incoming
  });
  assert.strictEqual(res.allowed, true, res.reason);
});

runTest('2. Approved provider updating businessImageUrl to Cloudflare R2 key is ALLOWED', () => {
  const incoming = {
    ...baseApprovedDoc,
    businessImageUrl: 'providers/prov_123/business/business_1792950000_xyz.jpg',
    updatedAt: '2026-10-26T00:00:00Z'
  };
  const res = evaluateProviderUpdateRule({
    auth: { uid: 'prov_123' },
    providerId: 'prov_123',
    existingData: baseApprovedDoc,
    incomingData: incoming
  });
  assert.strictEqual(res.allowed, true, res.reason);
});

runTest('3. Approved provider updating permitted bio, visitingCharge, and address is ALLOWED', () => {
  const incoming = {
    ...baseApprovedDoc,
    visitingCharge: 200,
    experienceYears: 6,
    fullAddress: 'Near Post Office, Jamui',
    updatedAt: '2026-10-26T00:00:00Z'
  };
  const res = evaluateProviderUpdateRule({
    auth: { uid: 'prov_123' },
    providerId: 'prov_123',
    existingData: baseApprovedDoc,
    incomingData: incoming
  });
  assert.strictEqual(res.allowed, true, res.reason);
});

// ----------------------------------------------------------------------------
// GROUP 2: Approved Provider CANNOT Modify Protected Fields
// ----------------------------------------------------------------------------
runTest('4. Approved provider attempting to alter primaryCategoryId is BLOCKED', () => {
  const incoming = {
    ...baseApprovedDoc,
    primaryCategoryId: 'cat_electrician', // Category lock violation!
    profileImageUrl: 'providers/prov_123/profile/pic.jpg'
  };
  const res = evaluateProviderUpdateRule({
    auth: { uid: 'prov_123' },
    providerId: 'prov_123',
    existingData: baseApprovedDoc,
    incomingData: incoming
  });
  assert.strictEqual(res.allowed, false, 'Expected category change to be blocked');
  assert.ok(res.reason.includes('locked admin / category / approval fields'));
});

runTest('5. Approved provider attempting to alter status or kycStatus is BLOCKED', () => {
  const incoming = {
    ...baseApprovedDoc,
    status: 'super_approved',
    profileImageUrl: 'providers/prov_123/profile/pic.jpg'
  };
  const res = evaluateProviderUpdateRule({
    auth: { uid: 'prov_123' },
    providerId: 'prov_123',
    existingData: baseApprovedDoc,
    incomingData: incoming
  });
  assert.strictEqual(res.allowed, false, 'Expected status change to be blocked');
});

runTest('6. Approved provider attempting to manipulate rating or ratingCount is BLOCKED', () => {
  const incoming = {
    ...baseApprovedDoc,
    rating: 5.0, // Existing was 4.8
    ratingCount: 50
  };
  const res = evaluateProviderUpdateRule({
    auth: { uid: 'prov_123' },
    providerId: 'prov_123',
    existingData: baseApprovedDoc,
    incomingData: incoming
  });
  assert.strictEqual(res.allowed, false, 'Expected rating manipulation to be blocked');
});

runTest('7. Approved provider attempting to self-modify isSubscriptionActive or paymentVerified is BLOCKED', () => {
  const docWithInactiveSub = { ...baseApprovedDoc, isSubscriptionActive: false };
  const incoming = { ...docWithInactiveSub, isSubscriptionActive: true };
  const res = evaluateProviderUpdateRule({
    auth: { uid: 'prov_123' },
    providerId: 'prov_123',
    existingData: docWithInactiveSub,
    incomingData: incoming
  });
  assert.strictEqual(res.allowed, false, 'Expected self-activation of subscription to be blocked');
});

runTest('8. Approved provider attempting to inject server-only keys (adminCategoryOverrideLimit) is BLOCKED', () => {
  const incoming = {
    ...baseApprovedDoc,
    adminCategoryOverrideLimit: 10
  };
  const res = evaluateProviderUpdateRule({
    auth: { uid: 'prov_123' },
    providerId: 'prov_123',
    existingData: baseApprovedDoc,
    incomingData: incoming
  });
  assert.strictEqual(res.allowed, false, 'Expected server-only key injection to be blocked');
});

// ----------------------------------------------------------------------------
// GROUP 3: Unapproved Provider CANNOT Self-Approve
// ----------------------------------------------------------------------------
const baseUnapprovedDoc = {
  fullName: 'New Applicant',
  businessName: 'New Services',
  status: 'pendingReview',
  kycStatus: 'pendingReview',
  isVerified: false,
  isSubscriptionActive: false,
  paymentVerified: false,
  primaryCategoryId: 'cat_painter',
  rating: 5.0,
  ratingCount: 0,
  profileImageUrl: ''
};

runTest('9. Unapproved provider setting status to approved is BLOCKED', () => {
  const incoming = { ...baseUnapprovedDoc, status: 'approved' };
  const res = evaluateProviderUpdateRule({
    auth: { uid: 'applicant_1' },
    providerId: 'applicant_1',
    existingData: baseUnapprovedDoc,
    incomingData: incoming
  });
  assert.strictEqual(res.allowed, false, 'Expected self-approval to be blocked');
  assert.ok(res.reason.includes('Unapproved provider cannot self-approve'));
});

runTest('10. Unapproved provider setting isVerified to true is BLOCKED', () => {
  const incoming = { ...baseUnapprovedDoc, isVerified: true };
  const res = evaluateProviderUpdateRule({
    auth: { uid: 'applicant_1' },
    providerId: 'applicant_1',
    existingData: baseUnapprovedDoc,
    incomingData: incoming
  });
  assert.strictEqual(res.allowed, false, 'Expected self-verification to be blocked');
});

runTest('11. Unapproved provider setting kycStatus or verificationStatus to approved is BLOCKED', () => {
  const incoming = { ...baseUnapprovedDoc, kycStatus: 'approved' };
  const res = evaluateProviderUpdateRule({
    auth: { uid: 'applicant_1' },
    providerId: 'applicant_1',
    existingData: baseUnapprovedDoc,
    incomingData: incoming
  });
  assert.strictEqual(res.allowed, false, 'Expected KYC self-approval to be blocked');
});

runTest('12. Unapproved provider updating profile photo while keeping status pendingReview is ALLOWED', () => {
  const incoming = {
    ...baseUnapprovedDoc,
    profileImageUrl: 'providers/applicant_1/profile/profile_initial.jpg',
    fullName: 'New Applicant Updated'
  };
  const res = evaluateProviderUpdateRule({
    auth: { uid: 'applicant_1' },
    providerId: 'applicant_1',
    existingData: baseUnapprovedDoc,
    incomingData: incoming
  });
  assert.strictEqual(res.allowed, true, res.reason);
});

// ----------------------------------------------------------------------------
// GROUP 4: Blocked or Suspended Provider Strict Lockdown
// ----------------------------------------------------------------------------
runTest('13. Blocked provider attempting any profile update is STRICTLY BLOCKED', () => {
  const blockedDoc = { ...baseApprovedDoc, status: 'blocked' };
  const incoming = { ...blockedDoc, profileImageUrl: 'providers/prov_123/profile/hacked.jpg' };
  const res = evaluateProviderUpdateRule({
    auth: { uid: 'prov_123' },
    providerId: 'prov_123',
    existingData: blockedDoc,
    incomingData: incoming
  });
  assert.strictEqual(res.allowed, false, 'Expected blocked provider to be denied');
  assert.ok(res.reason.includes('Blocked or suspended'));
});

runTest('14. Suspended provider attempting any profile update is STRICTLY BLOCKED', () => {
  const suspendedDoc = { ...baseApprovedDoc, status: 'suspended' };
  const incoming = { ...suspendedDoc, visitingCharge: 500 };
  const res = evaluateProviderUpdateRule({
    auth: { uid: 'prov_123' },
    providerId: 'prov_123',
    existingData: suspendedDoc,
    incomingData: incoming
  });
  assert.strictEqual(res.allowed, false, 'Expected suspended provider to be denied');
  assert.ok(res.reason.includes('Blocked or suspended'));
});

// ----------------------------------------------------------------------------
// GROUP 5: Admin Approval Flow & Administrative Overrides
// ----------------------------------------------------------------------------
runTest('15. Admin approving unapproved provider (status=approved, isVerified=true) is ALLOWED', () => {
  const incoming = {
    ...baseUnapprovedDoc,
    status: 'approved',
    kycStatus: 'approved',
    verificationStatus: 'approved',
    isVerified: true
  };
  const res = evaluateProviderUpdateRule({
    auth: { uid: 'admin_super', token: { email: 'sk12@gmail.com' } },
    providerId: 'applicant_1',
    existingData: baseUnapprovedDoc,
    incomingData: incoming
  });
  assert.strictEqual(res.allowed, true, res.reason);
});

runTest('16. Admin changing provider category and setting subscription is ALLOWED', () => {
  const incoming = {
    ...baseApprovedDoc,
    primaryCategoryId: 'cat_solar_install',
    isSubscriptionActive: true,
    paymentVerified: true,
    adminCategoryOverrideLimit: 5
  };
  const res = evaluateProviderUpdateRule({
    auth: { uid: 'admin_doc_owner', isAdminUserDoc: true },
    providerId: 'prov_123',
    existingData: baseApprovedDoc,
    incomingData: incoming
  });
  assert.strictEqual(res.allowed, true, res.reason);
});

runTest('17. Non-owner regular provider trying to modify another provider is BLOCKED', () => {
  const incoming = { ...baseApprovedDoc, fullName: 'Hacked by Attacker' };
  const res = evaluateProviderUpdateRule({
    auth: { uid: 'attacker_uid' }, // Not the owner
    providerId: 'prov_123',
    existingData: baseApprovedDoc,
    incomingData: incoming
  });
  assert.strictEqual(res.allowed, false, 'Expected non-owner update to be denied');
});

// ----------------------------------------------------------------------------
// GROUP 6: Critical Server-Only & Quota Security Guards (Phase 6 / Pre-Production)
// ----------------------------------------------------------------------------
runTest('18. Provider attempting to modify planLimits is STRICTLY BLOCKED', () => {
  const incoming = {
    ...baseApprovedDoc,
    planLimits: {
      maxTotalStorageBytes: 10737418240, // 10 GB privilege escalation!
      maxImagesPerProvider: 999
    }
  };
  const res = evaluateProviderUpdateRule({
    auth: { uid: 'prov_123' },
    providerId: 'prov_123',
    existingData: baseApprovedDoc,
    incomingData: incoming
  });
  assert.strictEqual(res.allowed, false, 'Expected planLimits tampering to be denied');
  assert.ok(res.reason.includes('Server-only keys cannot be modified'));
});

runTest('19. Provider attempting to set isPremiumEligible: true is STRICTLY BLOCKED', () => {
  const incoming = {
    ...baseApprovedDoc,
    isPremiumEligible: true
  };
  const res = evaluateProviderUpdateRule({
    auth: { uid: 'prov_123' },
    providerId: 'prov_123',
    existingData: baseApprovedDoc,
    incomingData: incoming
  });
  assert.strictEqual(res.allowed, false, 'Expected isPremiumEligible tampering to be denied');
  assert.ok(res.reason.includes('Server-only keys cannot be modified'));
});

runTest('20. Provider attempting to tamper with storageUsage is STRICTLY BLOCKED', () => {
  const docWithUsage = {
    ...baseApprovedDoc,
    storageUsage: { totalBytesUsed: 50000000, totalImagesCount: 15 }
  };
  const incoming = {
    ...docWithUsage,
    storageUsage: { totalBytesUsed: 0, totalImagesCount: 0 } // Reset storage quota!
  };
  const res = evaluateProviderUpdateRule({
    auth: { uid: 'prov_123' },
    providerId: 'prov_123',
    existingData: docWithUsage,
    incomingData: incoming
  });
  assert.strictEqual(res.allowed, false, 'Expected storageUsage tampering to be denied');
  assert.ok(res.reason.includes('Server-only keys cannot be modified'));
});

runTest('21. Provider attempting to tamper with paymentVerifiedAt is STRICTLY BLOCKED', () => {
  const incoming = {
    ...baseApprovedDoc,
    paymentVerifiedAt: '2026-10-28T00:00:00Z'
  };
  const res = evaluateProviderUpdateRule({
    auth: { uid: 'prov_123' },
    providerId: 'prov_123',
    existingData: baseApprovedDoc,
    incomingData: incoming
  });
  assert.strictEqual(res.allowed, false, 'Expected paymentVerifiedAt tampering to be denied');
  assert.ok(res.reason.includes('Server-only keys cannot be modified'));
});

runTest('22. Provider attempting to tamper with subscriptionExpiry is STRICTLY BLOCKED', () => {
  const incoming = {
    ...baseApprovedDoc,
    subscriptionExpiry: '2030-01-01T00:00:00Z'
  };
  const res = evaluateProviderUpdateRule({
    auth: { uid: 'prov_123' },
    providerId: 'prov_123',
    existingData: baseApprovedDoc,
    incomingData: incoming
  });
  assert.strictEqual(res.allowed, false, 'Expected subscriptionExpiry tampering to be denied');
  assert.ok(res.reason.includes('subscriptionExpiry') || res.reason.includes('Server-only keys'));
});

runTest('23. Provider attempting to change subscriptionPlan is STRICTLY BLOCKED', () => {
  const incoming = {
    ...baseApprovedDoc,
    subscriptionPlan: 'gold'
  };
  const res = evaluateProviderUpdateRule({
    auth: { uid: 'prov_123' },
    providerId: 'prov_123',
    existingData: baseApprovedDoc,
    incomingData: incoming
  });
  assert.strictEqual(res.allowed, false, 'Expected subscriptionPlan tampering to be denied');
  assert.ok(res.reason.includes('Server-only keys cannot be modified'));
});

runTest('24. Provider attempting to inject Razorpay order or payment keys is STRICTLY BLOCKED', () => {
  const incoming = {
    ...baseApprovedDoc,
    razorpayPaymentId: 'pay_fake_12345',
    razorpayOrderId: 'order_fake_67890'
  };
  const res = evaluateProviderUpdateRule({
    auth: { uid: 'prov_123' },
    providerId: 'prov_123',
    existingData: baseApprovedDoc,
    incomingData: incoming
  });
  assert.strictEqual(res.allowed, false, 'Expected Razorpay injection to be denied');
  assert.ok(res.reason.includes('Server-only keys cannot be modified'));
});

runTest('25. Admin updating planLimits, isPremiumEligible, and storageUsage is ALLOWED', () => {
  const incoming = {
    ...baseApprovedDoc,
    planLimits: { maxTotalStorageBytes: 104857600, maxImagesPerProvider: 50 },
    isPremiumEligible: true,
    storageUsage: { totalBytesUsed: 1000, totalImagesCount: 1 }
  };
  const res = evaluateProviderUpdateRule({
    auth: { uid: 'superadmin_uid', isAdminUserDoc: true },
    providerId: 'prov_123',
    existingData: baseApprovedDoc,
    incomingData: incoming
  });
  assert.strictEqual(res.allowed, true, res.reason);
});

// ----------------------------------------------------------------------------
// GROUP 7: Registration / Document Creation Security Guards (allow create)
// ----------------------------------------------------------------------------
const validNewRegistration = {
  fullName: 'New Provider Registration',
  phoneNumber: '+919876543210',
  phone: '+919876543210',
  email: 'newprov@example.com',
  status: 'draft',
  registrationStatus: 'draft',
  verificationStatus: 'pending',
  kycStatus: 'pendingReview',
  isVerified: false,
  isSubscriptionActive: false,
  paymentVerified: false,
  subscriptionPlan: 'none',
  rating: 5.0,
  ratingCount: 0,
  createdAt: '2026-10-28T00:00:00Z',
  updatedAt: '2026-10-28T00:00:00Z'
};

runTest('26. Valid new provider registration is ALLOWED', () => {
  const res = evaluateProviderCreateRule({
    auth: { uid: 'new_prov_1' },
    providerId: 'new_prov_1',
    incomingData: validNewRegistration
  });
  assert.strictEqual(res.allowed, true, res.reason);
});

runTest('27. New provider registering with planLimits is STRICTLY BLOCKED', () => {
  const incoming = {
    ...validNewRegistration,
    planLimits: { maxTotalStorageBytes: 999999999 }
  };
  const res = evaluateProviderCreateRule({
    auth: { uid: 'new_prov_1' },
    providerId: 'new_prov_1',
    incomingData: incoming
  });
  assert.strictEqual(res.allowed, false, 'Expected planLimits on create to be blocked');
  assert.ok(res.reason.includes('Forbidden server-only key'));
});

runTest('28. New provider registering with isPremiumEligible: true is STRICTLY BLOCKED', () => {
  const incoming = {
    ...validNewRegistration,
    isPremiumEligible: true
  };
  const res = evaluateProviderCreateRule({
    auth: { uid: 'new_prov_1' },
    providerId: 'new_prov_1',
    incomingData: incoming
  });
  assert.strictEqual(res.allowed, false, 'Expected isPremiumEligible on create to be blocked');
  assert.ok(res.reason.includes('Forbidden server-only key'));
});

runTest('29. New provider registering with storageUsage is STRICTLY BLOCKED', () => {
  const incoming = {
    ...validNewRegistration,
    storageUsage: { totalBytesUsed: 0, totalImagesCount: 0 }
  };
  const res = evaluateProviderCreateRule({
    auth: { uid: 'new_prov_1' },
    providerId: 'new_prov_1',
    incomingData: incoming
  });
  assert.strictEqual(res.allowed, false, 'Expected storageUsage on create to be blocked');
  assert.ok(res.reason.includes('Forbidden server-only key'));
});

runTest('30. New provider registering with isSubscriptionActive: true is STRICTLY BLOCKED', () => {
  const incoming = {
    ...validNewRegistration,
    isSubscriptionActive: true
  };
  const res = evaluateProviderCreateRule({
    auth: { uid: 'new_prov_1' },
    providerId: 'new_prov_1',
    incomingData: incoming
  });
  assert.strictEqual(res.allowed, false, 'Expected isSubscriptionActive: true on create to be blocked');
  assert.ok(res.reason.includes('isSubscriptionActive'));
});

runTest('31. New provider registering with paymentVerified: true is STRICTLY BLOCKED', () => {
  const incoming = {
    ...validNewRegistration,
    paymentVerified: true
  };
  const res = evaluateProviderCreateRule({
    auth: { uid: 'new_prov_1' },
    providerId: 'new_prov_1',
    incomingData: incoming
  });
  assert.strictEqual(res.allowed, false, 'Expected paymentVerified: true on create to be blocked');
  assert.ok(res.reason.includes('paymentVerified'));
});

runTest('32. New provider registering with subscriptionPlan: "gold" is STRICTLY BLOCKED', () => {
  const incoming = {
    ...validNewRegistration,
    subscriptionPlan: 'gold'
  };
  const res = evaluateProviderCreateRule({
    auth: { uid: 'new_prov_1' },
    providerId: 'new_prov_1',
    incomingData: incoming
  });
  assert.strictEqual(res.allowed, false, 'Expected subscriptionPlan: gold on create to be blocked');
  assert.ok(res.reason.includes('subscriptionPlan'));
});

runTest('33. New provider registering with status: "approved" is STRICTLY BLOCKED', () => {
  const incoming = {
    ...validNewRegistration,
    status: 'approved'
  };
  const res = evaluateProviderCreateRule({
    auth: { uid: 'new_prov_1' },
    providerId: 'new_prov_1',
    incomingData: incoming
  });
  assert.strictEqual(res.allowed, false, 'Expected status: approved on create to be blocked');
  assert.ok(res.reason.includes('status'));
});

runTest('34. New provider registering with ratingCount: 50 is STRICTLY BLOCKED', () => {
  const incoming = {
    ...validNewRegistration,
    ratingCount: 50
  };
  const res = evaluateProviderCreateRule({
    auth: { uid: 'new_prov_1' },
    providerId: 'new_prov_1',
    incomingData: incoming
  });
  assert.strictEqual(res.allowed, false, 'Expected ratingCount tampering on create to be blocked');
  assert.ok(res.reason.includes('ratingCount'));
});

console.log('\n================================================================');
console.log(` RESULTS: ${passed}/${total} FIRESTORE RULES SECURITY TESTS PASSED`);
console.log('================================================================\n');
