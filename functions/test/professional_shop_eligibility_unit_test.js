/**
 * UNIT TEST (pure logic, NO Firestore, NO emulator).
 * Covers the server-authoritative Professional shop sellability check used by
 * placeDiamondOrder (pre-check + in-transaction re-check) and createProfessionalProduct.
 * This is a UNIT test only — it is NOT a Firestore Emulator integration test.
 */
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || 'demo-unit-test';
const assert = require('assert');
const fns = require('../index');
const check = fns._getProfessionalShopIneligibilityReason;

const NOW = Date.now();
const ts = (ms) => ({ toMillis: () => ms });
const live = { isApproved: true, status: 'approved', isActive: true, isSubscriptionActive: true, isDeleted: false };

const cases = [
  ['active seller, future expiry => eligible', { ...live, subscriptionExpiry: ts(NOW + 86400000) }, null],
  ['legacy seller, no expiry field => eligible (flag only)', { ...live }, null],
  ['EXPIRED (flag still true) => rejected', { ...live, subscriptionExpiry: ts(NOW - 1000) }, 'expired'],
  ['expiry exactly now => rejected', { ...live, subscriptionExpiry: ts(NOW) }, 'expired'],
  ['subscription flag false => rejected', { ...live, isSubscriptionActive: false }, 'active subscription'],
  ['not approved => rejected', { ...live, isApproved: false }, 'pending approval'],
  ['status pending => rejected', { ...live, status: 'pending' }, 'pending approval'],
  ['suspended => rejected', { ...live, status: 'suspended', isApproved: true }, 'pending approval'],
  ['isActive false => rejected', { ...live, isActive: false }, 'suspended or inactive'],
  ['deleted => rejected', { ...live, isDeleted: true }, 'no longer available'],
  ['null shop => rejected', null, 'pending approval'],
];

let pass = 0;
let fail = 0;
for (const [name, shop, expected] of cases) {
  try {
    const r = check(shop, NOW);
    if (expected === null) assert.strictEqual(r, null);
    else assert.ok(r && r.toLowerCase().includes(expected), `got: ${r}`);
    console.log(`PASS  ${name}`);
    pass++;
  } catch (e) {
    console.log(`FAIL  ${name} -> ${e.message}`);
    fail++;
  }
}
console.log(`\nRESULT: ${pass} passed, ${fail} failed (unit-level, no emulator)`);
process.exit(fail === 0 ? 0 : 1);

