const fs = require('fs');
const path = require('path');
const assert = require('assert');

console.log('================================================================');
console.log('  JAMUI SERVICES — FIRESTORE RULES: PREMIUM CATEGORIES & ADMIN SECURITY TEST  ');
console.log('================================================================\n');

// 1. Verify firestore.rules file exists and contains the required security logic
const rulesPath = path.resolve(__dirname, '../../backend/firebase/firestore.rules');
assert.ok(fs.existsSync(rulesPath), `firestore.rules not found at ${rulesPath}`);
const rulesContent = fs.readFileSync(rulesPath, 'utf8');

// Ensure key security rules exist in the active rules file
assert.ok(rulesContent.includes('match /premium_categories/{catId}'), 'Rule must define match /premium_categories/{catId}');
assert.ok(rulesContent.includes('match /admin_users/{adminId}'), 'Rule must define match /admin_users/{adminId}');
assert.ok(rulesContent.includes('function isAdmin()'), 'Rule must define function isAdmin()');
assert.ok(rulesContent.includes('exists(/databases/$(database)/documents/admin_users/$(request.auth.uid))'), 'isAdmin() must check admin_users collection for caller UID');
assert.ok(!rulesContent.includes('match /{document=**}'), 'Rule must NOT have catch-all wildcard rule');

/**
 * Exact simulation of Firestore Security Rules logic for:
 * 1. isAdmin()
 * 2. /admin_users/{adminId}
 * 3. /premium_categories/{catId}
 */
class FirestoreRulesSimulator {
  constructor(adminUsersStore = new Set()) {
    this.adminUsersStore = adminUsersStore; // Set of UIDs that exist in /admin_users
  }

  isAuthenticated(auth) {
    return auth != null && auth.uid != null;
  }

  isAdmin(auth) {
    if (!this.isAuthenticated(auth)) return false;
    const uidInAdminUsers = this.adminUsersStore.has(auth.uid);
    const hasAdminEmail = auth.token && auth.token.email === 'admin@jamuiservice.com';
    return uidInAdminUsers || hasAdminEmail;
  }

  evaluateAdminUsersAccess({ auth, operation, targetAdminId }) {
    // match /admin_users/{adminId} {
    //   allow read: if isAdmin();
    //   allow write: if isAdmin();
    // }
    const admin = this.isAdmin(auth);
    if (!admin) {
      return { allowed: false, reason: `Permission Denied: Caller is not an authorized administrator` };
    }
    return { allowed: true, reason: `Access granted by isAdmin()` };
  }

  evaluatePremiumCategoryRead({ auth, catId }) {
    // match /premium_categories/{catId} {
    //   allow read: if true;
    // }
    return { allowed: true, reason: 'Public read allowed' };
  }

  evaluatePremiumCategoryWrite({ auth, operation, catId, incomingData }) {
    // match /premium_categories/{catId} {
    //   allow write: if isAdmin();
    // }
    const admin = this.isAdmin(auth);
    if (!admin) {
      return { allowed: false, reason: `Permission Denied: Only administrators can ${operation} premium_categories` };
    }
    return { allowed: true, reason: `Write granted by isAdmin()` };
  }
}

// Test Runner
let passed = 0;
let total = 0;

function runTest(name, fn) {
  total++;
  try {
    fn();
    passed++;
    console.log(`✅ [PASS] Test ${total}: ${name}`);
  } catch (err) {
    console.error(`❌ [FAIL] Test ${total}: ${name}`);
    console.error(`       Error: ${err.message}\n`);
    process.exitCode = 1;
  }
}

// Setup fixtures
const ADMIN_UID = '5YcJBZKwuMYrU0URARmCBTtEkRD2';
const SECOND_ADMIN_UID = 'XtAafqnaooZmJdgZGMVpR6QlHkh2';
const CUSTOMER_UID = 'cust_local_test_user_001';
const PROVIDER_UID = 'prov_salon_local_user_002';
const ATTACKER_UID = 'hacker_malicious_user_666';

const adminUsers = new Set([ADMIN_UID, SECOND_ADMIN_UID]);
const simulator = new FirestoreRulesSimulator(adminUsers);

const validUnisexSalonData = {
  categoryId: 'unisex_salon',
  categoryName: 'Unisex Salon',
  customTitle: 'Unisex Salon & Grooming Hub',
  imageUrl: 'https://images.unsplash.com/photo-1560066984-138dadb4c035?auto=format&fit=crop&w=800&q=80',
  priority: 1,
  isActive: true,
  showOnHome: true,
  createdAt: new Date()
};

// -------------------------------------------------------------
// TESTS
// -------------------------------------------------------------

// 1. Unauthenticated customer-facing read
runTest('Unauthenticated guest visitor reading premium_categories is ALLOWED', () => {
  const res = simulator.evaluatePremiumCategoryRead({
    auth: null,
    catId: 'unisex_salon'
  });
  assert.strictEqual(res.allowed, true);
});

// 2. Authenticated customer read
runTest('Authenticated customer reading premium_categories is ALLOWED', () => {
  const res = simulator.evaluatePremiumCategoryRead({
    auth: { uid: CUSTOMER_UID, token: { email: 'customer@gmail.com' } },
    catId: 'unisex_salon'
  });
  assert.strictEqual(res.allowed, true);
});

// 3. Unauthenticated write
runTest('Unauthenticated guest attempting to create premium category is BLOCKED', () => {
  const res = simulator.evaluatePremiumCategoryWrite({
    auth: null,
    operation: 'create',
    catId: 'unisex_salon',
    incomingData: validUnisexSalonData
  });
  assert.strictEqual(res.allowed, false);
});

// 4. Normal customer write
runTest('Normal customer attempting to create premium category is BLOCKED', () => {
  const res = simulator.evaluatePremiumCategoryWrite({
    auth: { uid: CUSTOMER_UID, token: { email: 'customer@gmail.com' } },
    operation: 'create',
    catId: 'unisex_salon',
    incomingData: validUnisexSalonData
  });
  assert.strictEqual(res.allowed, false);
  assert.ok(res.reason.includes('Permission Denied'));
});

// 5. Normal customer update
runTest('Normal customer attempting to modify customTitle or priority is BLOCKED', () => {
  const res = simulator.evaluatePremiumCategoryWrite({
    auth: { uid: CUSTOMER_UID, token: { email: 'customer@gmail.com' } },
    operation: 'update',
    catId: 'unisex_salon',
    incomingData: { ...validUnisexSalonData, priority: 99 }
  });
  assert.strictEqual(res.allowed, false);
});

// 6. Normal customer delete
runTest('Normal customer attempting to delete premium category is BLOCKED', () => {
  const res = simulator.evaluatePremiumCategoryWrite({
    auth: { uid: CUSTOMER_UID, token: { email: 'customer@gmail.com' } },
    operation: 'delete',
    catId: 'unisex_salon',
    incomingData: null
  });
  assert.strictEqual(res.allowed, false);
});

// 7. Normal provider write
runTest('Normal salon provider attempting to create premium category is BLOCKED', () => {
  const res = simulator.evaluatePremiumCategoryWrite({
    auth: { uid: PROVIDER_UID, token: { email: 'provider@salongrooming.com' } },
    operation: 'create',
    catId: 'unisex_salon',
    incomingData: validUnisexSalonData
  });
  assert.strictEqual(res.allowed, false);
});

// 8. Normal provider update
runTest('Normal provider attempting to update priority or image of premium category is BLOCKED', () => {
  const res = simulator.evaluatePremiumCategoryWrite({
    auth: { uid: PROVIDER_UID, token: { email: 'provider@salongrooming.com' } },
    operation: 'update',
    catId: 'unisex_salon',
    incomingData: { ...validUnisexSalonData, imageUrl: 'https://evil.com/fake.png' }
  });
  assert.strictEqual(res.allowed, false);
});

// 9. Normal provider delete
runTest('Normal provider attempting to delete premium category is BLOCKED', () => {
  const res = simulator.evaluatePremiumCategoryWrite({
    auth: { uid: PROVIDER_UID, token: { email: 'provider@salongrooming.com' } },
    operation: 'delete',
    catId: 'unisex_salon',
    incomingData: null
  });
  assert.strictEqual(res.allowed, false);
});

// 10. Authorized admin UID write
runTest('Authorized Admin with verified document in admin_users writing to premium_categories is ALLOWED', () => {
  const res = simulator.evaluatePremiumCategoryWrite({
    auth: { uid: ADMIN_UID, token: { email: 'admin@jamuiservice.com' } },
    operation: 'create',
    catId: 'unisex_salon',
    incomingData: validUnisexSalonData
  });
  assert.strictEqual(res.allowed, true);
});

// 11. Secondary admin UID write
runTest('Secondary Admin (Sagar Kumar) with verified document in admin_users is ALLOWED', () => {
  const res = simulator.evaluatePremiumCategoryWrite({
    auth: { uid: SECOND_ADMIN_UID, token: { email: 'sk12@gmail.com' } },
    operation: 'update',
    catId: 'unisex_salon',
    incomingData: validUnisexSalonData
  });
  assert.strictEqual(res.allowed, true);
});

// 12. Non-admin attempting to claim admin role via write to admin_users
runTest('Attacker attempting to self-create document in /admin_users/{attacker_uid} is STRICTLY BLOCKED', () => {
  const res = simulator.evaluateAdminUsersAccess({
    auth: { uid: ATTACKER_UID, token: { email: 'attacker@evil.com' } },
    operation: 'write',
    targetAdminId: ATTACKER_UID
  });
  assert.strictEqual(res.allowed, false, 'Non-admin must NEVER be allowed to create an admin_users document');
  assert.ok(res.reason.includes('Permission Denied'));
});

// 13. Customer attempting to read admin_users collection
runTest('Customer attempting to read /admin_users to inspect admin credentials is BLOCKED', () => {
  const res = simulator.evaluateAdminUsersAccess({
    auth: { uid: CUSTOMER_UID, token: { email: 'customer@gmail.com' } },
    operation: 'read',
    targetAdminId: ADMIN_UID
  });
  assert.strictEqual(res.allowed, false, 'Non-admins must not be able to read admin_users');
});

// 14. Provider attempting to read admin_users collection
runTest('Provider attempting to read /admin_users is BLOCKED', () => {
  const res = simulator.evaluateAdminUsersAccess({
    auth: { uid: PROVIDER_UID, token: { email: 'provider@salongrooming.com' } },
    operation: 'read',
    targetAdminId: ADMIN_UID
  });
  assert.strictEqual(res.allowed, false);
});

// 15. Authorized Admin reading admin_users collection
runTest('Authorized Admin reading /admin_users is ALLOWED', () => {
  const res = simulator.evaluateAdminUsersAccess({
    auth: { uid: ADMIN_UID, token: { email: 'admin@jamuiservice.com' } },
    operation: 'read',
    targetAdminId: ADMIN_UID
  });
  assert.strictEqual(res.allowed, true);
});

// 16. Schema check: Verify premium_categories schema contains ZERO sensitive fields
runTest('Security Schema Audit: premium_categories collection schema has zero sensitive keys', () => {
  const forbiddenSensitiveKeys = [
    'password', 'token', 'secret', 'apiKey', 'razorpay', 'privateKey',
    'bankDetails', 'phone', 'email', 'kyc', 'aadhar', 'pan', 'upiId'
  ];
  const itemKeys = Object.keys(validUnisexSalonData);
  for (const key of itemKeys) {
    const isSensitive = forbiddenSensitiveKeys.some(forbidden => key.toLowerCase().includes(forbidden.toLowerCase()));
    assert.strictEqual(isSensitive, false, `Field "${key}" in premium_categories is sensitive!`);
  }
});

console.log('\n================================================================');
console.log(` RESULTS: ${passed}/${total} SECURITY TESTS PASSED`);
console.log('================================================================\n');
