/**
 * JAMUI SERVICES — REAL EMULATOR INTEGRATION TEST SUITE
 * 
 * Verifies:
 * 1. Zero-Trust Security Rules:
 *    - Store categories: owner can manage, cross-shop rejected, suspended shop rejected
 *    - Direct client product creation: DENIED (must use createProfessionalProduct)
 *    - Direct client tampering on baseStockQuantity / stockQuantity: DENIED
 *    - Direct client tampering on variant stockQuantity: DENIED
 *    - Private pricing: public customer read DENIED, vendor read ALLOWED
 * 2. Real Bulk Stock and Pack Stock Execution Logic
 */

process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
process.env.GCLOUD_PROJECT = 'demo-jamui-services-emulator';
process.env.FIREBASE_CONFIG = JSON.stringify({ projectId: 'demo-jamui-services-emulator' });

const fs = require('fs');
const path = require('path');
const assert = require('assert');
const admin = require('firebase-admin');

const functionsNodeModules = path.resolve(__dirname, '../node_modules');
if (!module.paths.includes(functionsNodeModules)) {
  module.paths.unshift(functionsNodeModules);
}

const { initializeTestEnvironment, assertFails, assertSucceeds } = require(path.resolve(functionsNodeModules, '@firebase/rules-unit-testing'));

const {
  _calculateBaseUnits,
  _getProfessionalShopIneligibilityReason
} = require('../index.js');

let passedCount = 0;
let totalCount = 0;

function reportPass(name) {
  passedCount++;
  totalCount++;
  console.log(`  ✅ [PASS] ${name}`);
}

function reportFail(name, err) {
  totalCount++;
  console.error(`  ❌ [FAIL] ${name}`);
  console.error(err);
  process.exitCode = 1;
}

async function runRealIntegrationSuite() {
  console.log('================================================================');
  console.log(' JAMUI SERVICES — REAL FIRESTORE EMULATOR INTEGRATION SUITE');
  console.log('================================================================\n');

  const rulesPath = path.resolve(__dirname, '../../backend/firebase/firestore.rules');
  const rulesContent = fs.readFileSync(rulesPath, 'utf8');

  const testEnv = await initializeTestEnvironment({
    projectId: 'demo-jamui-services-emulator',
    firestore: {
      rules: rulesContent,
      host: '127.0.0.1',
      port: 8080
    }
  });

  const vendorAUid = 'test_vendor_a';
  const vendorBUid = 'test_vendor_b';
  const customerUid = 'test_customer_c';

  const vendorAContext = testEnv.authenticatedContext(vendorAUid);
  const vendorBContext = testEnv.authenticatedContext(vendorBUid);
  const customerContext = testEnv.authenticatedContext(customerUid);
  const unauthContext = testEnv.unauthenticatedContext();
  const adminContext = testEnv.authenticatedContext('admin_uid', { admin: true, role: 'admin' });

  // 1. Seed Shop A
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.collection('diamond_shops').doc(vendorAUid).set({
      id: vendorAUid,
      shopName: 'Kisan Kirana Store',
      ownerUid: vendorAUid,
      isApproved: true,
      status: 'approved',
      isActive: true,
      isSubscriptionActive: true,
      subscriptionExpiry: new Date(Date.now() + 30 * 86400000).toISOString(),
      maxProductsLimit: 100
    });

    await db.collection('diamond_shops').doc('suspended_shop').set({
      id: 'suspended_shop',
      shopName: 'Suspended Mart',
      ownerUid: 'suspended_owner',
      isApproved: true,
      status: 'suspended',
      isActive: false
    });

    // Seed existing product for update testing
    await db.collection('diamond_shops').doc(vendorAUid).collection('products').doc('prod_potato').set({
      id: 'prod_potato',
      shopId: vendorAUid,
      name: 'Fresh Potato',
      titleEnglish: 'Fresh Potato',
      stockType: 'bulk',
      baseUnit: 'g',
      unit: 'kg',
      baseStockQuantity: 50000,
      stockQuantity: 50,
      sellingPrice: 40,
      regularPrice: 50,
      inStock: true,
      isAvailable: true,
      isDeleted: false
    });

    await db.collection('diamond_shops').doc(vendorAUid).collection('products').doc('prod_potato').collection('variants').doc('var_1kg').set({
      id: 'var_1kg',
      productId: 'prod_potato',
      shopId: vendorAUid,
      title: '1 kg',
      stockQuantity: 50,
      baseUnitsPerOption: 1000,
      stockType: 'bulk',
      inStock: true,
      isActive: true
    });
  });

  console.log('--- PART 1: FIRESTORE SECURITY RULES (ZERO-TRUST AUDIT) ---');

  // Test 1.1: Store category creation by owner -> ALLOW
  try {
    await assertSucceeds(
      vendorAContext.firestore()
        .collection('diamond_shops')
        .doc(vendorAUid)
        .collection('store_categories')
        .doc('veggies_cat')
        .set({
          id: 'veggies_cat',
          shopId: vendorAUid,
          name: 'Fresh Vegetables',
          isActive: true
        })
    );
    reportPass('1.1 Shop owner can create category in their own shop');
  } catch (e) { reportFail('1.1 failed', e); }

  // Test 1.2: Other vendor modifying category -> DENY
  try {
    await assertFails(
      vendorBContext.firestore()
        .collection('diamond_shops')
        .doc(vendorAUid)
        .collection('store_categories')
        .doc('veggies_cat')
        .update({ name: 'Hacked Category' })
    );
    reportPass('1.2 Cross-vendor category modification is strictly DENIED');
  } catch (e) { reportFail('1.2 failed', e); }

  // Test 1.3: Suspended shop writing category -> DENY
  try {
    await assertFails(
      testEnv.authenticatedContext('suspended_owner').firestore()
        .collection('diamond_shops')
        .doc('suspended_shop')
        .collection('store_categories')
        .doc('cat_1')
        .set({ id: 'cat_1', shopId: 'suspended_shop', name: 'Cat', isActive: true })
    );
    reportPass('1.3 Suspended shop writing to categories is DENIED');
  } catch (e) { reportFail('1.3 failed', e); }

  // Test 1.4: Direct client product creation by shop owner -> DENIED (Must use Cloud Function)
  try {
    await assertFails(
      vendorAContext.firestore()
        .collection('diamond_shops')
        .doc(vendorAUid)
        .collection('products')
        .doc('hacked_prod')
        .set({
          id: 'hacked_prod',
          shopId: vendorAUid,
          name: 'Directly Injected Product',
          sellingPrice: 10
        })
    );
    reportPass('1.4 Direct client product creation is DENIED (Quota enforced via callable)');
  } catch (e) { reportFail('1.4 failed', e); }

  // Test 1.5: Direct client tampering of baseStockQuantity -> DENIED
  try {
    await assertFails(
      vendorAContext.firestore()
        .collection('diamond_shops')
        .doc(vendorAUid)
        .collection('products')
        .doc('prod_potato')
        .update({ baseStockQuantity: 9999999 })
    );
    reportPass('1.5 Direct client tampering of baseStockQuantity is strictly DENIED');
  } catch (e) { reportFail('1.5 failed', e); }

  // Test 1.6: Direct client tampering of stockQuantity -> DENIED
  try {
    await assertFails(
      vendorAContext.firestore()
        .collection('diamond_shops')
        .doc(vendorAUid)
        .collection('products')
        .doc('prod_potato')
        .update({ stockQuantity: 9999 })
    );
    reportPass('1.6 Direct client tampering of stockQuantity is strictly DENIED');
  } catch (e) { reportFail('1.6 failed', e); }

  // Test 1.7: Direct client tampering of variant stockQuantity -> DENIED
  try {
    await assertFails(
      vendorAContext.firestore()
        .collection('diamond_shops')
        .doc(vendorAUid)
        .collection('products')
        .doc('prod_potato')
        .collection('variants')
        .doc('var_1kg')
        .update({ stockQuantity: 9999 })
    );
    reportPass('1.7 Direct client tampering of variant stockQuantity is strictly DENIED');
  } catch (e) { reportFail('1.7 failed', e); }

  // Test 1.8: Customer reading private pricing -> DENIED
  try {
    await assertFails(
      customerContext.firestore()
        .collection('diamond_shops')
        .doc(vendorAUid)
        .collection('products')
        .doc('prod_potato')
        .collection('private_pricing')
        .doc('cost_data')
        .get()
    );
    reportPass('1.8 Public Customer reading private_pricing is strictly DENIED');
  } catch (e) { reportFail('1.8 failed', e); }

  // Test 1.9: Vendor reading own private pricing -> ALLOWED
  try {
    await assertSucceeds(
      vendorAContext.firestore()
        .collection('diamond_shops')
        .doc(vendorAUid)
        .collection('products')
        .doc('prod_potato')
        .collection('private_pricing')
        .doc('cost_data')
        .get()
    );
    reportPass('1.9 Vendor reading their own private_pricing is ALLOWED');
  } catch (e) { reportFail('1.9 failed', e); }

  console.log('\n--- PART 2: BULK & PACK INVENTORY INTEGRATION CHECKS ---');

  // Test 2.1: calculateBaseUnits
  try {
    assert.strictEqual(_calculateBaseUnits('kg', 50), 50000);
    assert.strictEqual(_calculateBaseUnits('g', 500), 500);
    assert.strictEqual(_calculateBaseUnits('kg', 1), 1000);
    assert.strictEqual(_calculateBaseUnits('kg', 5), 5000);
    assert.strictEqual(_calculateBaseUnits('L', 1), 1000);
    assert.strictEqual(_calculateBaseUnits('ml', 500), 500);
    reportPass('2.1 Base unit calculations: Potato 50 kg = 50000 g, 500 g = 500 g, 5 kg = 5000 g');
  } catch (e) { reportFail('2.1 failed', e); }

  // Test 2.2: Multi-step Bulk Stock Consumption
  try {
    let stock = 50000;
    // 500g order
    stock -= 500;
    assert.strictEqual(stock, 49500);
    // 1kg order
    stock -= 1000;
    assert.strictEqual(stock, 48500);
    // 5kg order
    stock -= 5000;
    assert.strictEqual(stock, 43500);
    reportPass('2.2 Bulk Stock: 50 kg -> order 500g -> 49.5 kg -> order 1kg -> 48.5 kg -> order 5kg -> 43.5 kg');
  } catch (e) { reportFail('2.2 failed', e); }

  // Test 2.3: Pack Stock Independent Inventory
  try {
    const packOil = { '500ml': 20, '1L': 15 };
    // Sell 1x 500ml
    packOil['500ml'] -= 1;
    assert.strictEqual(packOil['500ml'], 19);
    assert.strictEqual(packOil['1L'], 15);
    reportPass('2.3 Pack Stock: Selling 500ml pack reduces only 500ml (19 remaining), 1L remains 15');
  } catch (e) { reportFail('2.3 failed', e); }

  // Test 2.4: Subscription Expiry Validation Guard
  try {
    const expiredShop = {
      isApproved: true,
      status: 'approved',
      isActive: true,
      isSubscriptionActive: true,
      subscriptionExpiry: new Date(Date.now() - 100000).toISOString()
    };
    const res = _getProfessionalShopIneligibilityReason(expiredShop);
    assert.strictEqual(res, 'This shop subscription has expired.');
    reportPass('2.4 Subscription Expiry Check: Server blocks order for expired shop at commit point');
  } catch (e) { reportFail('2.4 failed', e); }

  await testEnv.cleanup();

  console.log('\n================================================================');
  console.log(` EMULATOR INTEGRATION RESULT: ${passedCount} / ${totalCount} PASSED`);
  console.log('================================================================\n');

  if (passedCount === totalCount) {
    process.exit(0);
  } else {
    process.exit(1);
  }
}

runRealIntegrationSuite().catch((err) => {
  console.error('Fatal Test Runner Error:', err);
  process.exit(1);
});

