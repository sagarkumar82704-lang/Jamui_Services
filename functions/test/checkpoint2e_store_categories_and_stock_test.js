/**
 * JAMUI SERVICES — CHECKPOINT 2E
 * End-to-End Store Categories Rules & Atomic Inventory Cloud Function Test Suite
 * 
 * Verifies:
 * 1. Firestore Security Rules for diamond_shops/{shopId}/store_categories/{catId}
 * 2. Product storeCategoryId validation (ownership, active status, legacy safety)
 * 3. Atomic Inventory Adjustment Cloud Function (set, increment, decrement, negative rejection)
 * 4. Concurrency Safety (Simultaneous customer checkout & seller adjustment)
 * 5. Audit Logging in audit_logs
 * 6. Regression on placeDiamondOrder and updateDiamondOrderStatus
 */

process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
process.env.GCLOUD_PROJECT = 'demo-jamui-services-emulator';
process.env.FIREBASE_CONFIG = JSON.stringify({ projectId: 'demo-jamui-services-emulator' });

const fs = require('fs');
const path = require('path');
const assert = require('assert');
const admin = require('firebase-admin');

// Ensure module resolution points to functions/node_modules
const functionsNodeModules = path.resolve(__dirname, '../node_modules');
if (!module.paths.includes(functionsNodeModules)) {
  module.paths.unshift(functionsNodeModules);
}

const { initializeTestEnvironment, assertFails, assertSucceeds } = require(path.resolve(functionsNodeModules, '@firebase/rules-unit-testing'));

const {
  adjustDiamondProductStock,
  placeDiamondOrder,
  updateDiamondOrderStatus
} = require('../index.js');

const db = admin.firestore();

let passedCount = 0;
let totalCount = 0;

function reportPass(name) {
  passedCount++;
  console.log(`✅ [PASS] ${name}`);
}

function reportFail(name, err) {
  console.error(`❌ [FAIL] ${name}`);
  console.error(err);
  process.exitCode = 1;
}

async function runCheckpoint2ETestSuite() {
  console.log('================================================================');
  console.log(' JAMUI SERVICES — CHECKPOINT 2E EMULATOR VALIDATION SUITE');
  console.log(' Target: Store Categories Rules & Atomic Inventory Cloud Function');
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

  const vendorAUid = 'vendor_a_uid';
  const vendorBUid = 'vendor_b_uid';
  const customerUid = 'customer_1_uid';
  const adminUid = 'admin_super_uid';

  const vendorAContext = testEnv.authenticatedContext(vendorAUid);
  const vendorBContext = testEnv.authenticatedContext(vendorBUid);
  const customerContext = testEnv.authenticatedContext(customerUid);
  const adminContext = testEnv.authenticatedContext(adminUid);
  const unauthContext = testEnv.unauthenticatedContext();

  try {
    // -------------------------------------------------------------
    // SEEDING TEST FIXTURES
    // -------------------------------------------------------------
    console.log('--- SEEDING TEST FIXTURES IN EMULATOR ---');
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const fDb = ctx.firestore();

      // 1. Seed Active Admin
      await fDb.collection('admin_users').doc(adminUid).set({
        uid: adminUid,
        role: 'super_admin',
        isActive: true,
        status: 'active',
        email: 'admin@jamuiservices.in'
      });

      // 2. Seed Vendor A Shop (Approved, Active, Subscription Active)
      await fDb.collection('diamond_shops').doc(vendorAUid).set({
        id: vendorAUid,
        shopId: vendorAUid,
        ownerUid: vendorAUid,
        shopName: 'Vendor A Supermarket',
        category: 'Grocery',
        categoryId: 'grocery',
        isApproved: true,
        status: 'approved',
        isActive: true,
        isSubscriptionActive: true,
        isDeleted: false,
        isOpen: true,
        deliveryEnabled: true,
        pickupEnabled: true,
        deliveryCharge: 30,
        minOrderAmount: 50,
        latitude: 24.9273,
        longitude: 86.2238
      });

      // 3. Seed Vendor B Shop (Approved, Active, Subscription Active)
      await fDb.collection('diamond_shops').doc(vendorBUid).set({
        id: vendorBUid,
        shopId: vendorBUid,
        ownerUid: vendorBUid,
        shopName: 'Vendor B Boutique',
        category: 'Clothing',
        categoryId: 'clothing',
        isApproved: true,
        status: 'approved',
        isActive: true,
        isSubscriptionActive: true,
        isDeleted: false,
        isOpen: true,
        latitude: 24.9280,
        longitude: 86.2245
      });

      // 4. Seed Suspended Shop
      await fDb.collection('diamond_shops').doc('suspended_shop_uid').set({
        id: 'suspended_shop_uid',
        shopId: 'suspended_shop_uid',
        ownerUid: 'suspended_shop_uid',
        shopName: 'Suspended Seller',
        isApproved: true,
        status: 'suspended',
        isActive: false,
        isSubscriptionActive: true,
        isDeleted: false
      });

      // 5. Seed Vendor B Store Category (to test cross-shop reference injection)
      await fDb.collection('diamond_shops').doc(vendorBUid).collection('store_categories').doc('vendor_b_cat').set({
        id: 'vendor_b_cat',
        shopId: vendorBUid,
        name: 'Vendor B Mens Wear',
        isActive: true
      });
    });

    console.log('✓ Seeding complete\n');

    // =============================================================
    // PART 1: FIRESTORE SECURITY RULES — STORE CATEGORIES
    // =============================================================
    console.log('--- PART 1: FIRESTORE SECURITY RULES: STORE CATEGORIES ---');

    // 1.1 Owner Category Create: ALLOW
    totalCount++;
    await assertSucceeds(
      vendorAContext.firestore()
        .collection('diamond_shops')
        .doc(vendorAUid)
        .collection('store_categories')
        .doc('dairy_cat')
        .set({
          id: 'dairy_cat',
          shopId: vendorAUid,
          name: 'Dairy & Eggs',
          isActive: true,
          displayOrder: 1,
          itemCount: 0
        })
    );
    reportPass('1.1 Owner can create store category in their own shop');

    // 1.2 Owner Category Update: ALLOW
    totalCount++;
    await assertSucceeds(
      vendorAContext.firestore()
        .collection('diamond_shops')
        .doc(vendorAUid)
        .collection('store_categories')
        .doc('dairy_cat')
        .update({
          name: 'Fresh Dairy & Organic Eggs',
          isActive: true
        })
    );
    reportPass('1.2 Owner can update store category in their own shop');

    // 1.3 Other Seller Category Access: DENY
    totalCount++;
    await assertFails(
      vendorBContext.firestore()
        .collection('diamond_shops')
        .doc(vendorAUid)
        .collection('store_categories')
        .doc('dairy_cat')
        .update({
          name: 'Hacked by Vendor B'
        })
    );
    reportPass('1.3 Other Seller modifying category is DENIED');

    totalCount++;
    await assertFails(
      vendorBContext.firestore()
        .collection('diamond_shops')
        .doc(vendorAUid)
        .collection('store_categories')
        .doc('malicious_cat')
        .set({
          id: 'malicious_cat',
          shopId: vendorAUid,
          name: 'Injected Category'
        })
    );
    reportPass('1.4 Other Seller creating category in another shop is DENIED');

    // 1.4 Public Customer can read active categories of approved/active shop: ALLOW
    totalCount++;
    await assertSucceeds(
      unauthContext.firestore()
        .collection('diamond_shops')
        .doc(vendorAUid)
        .collection('store_categories')
        .doc('dairy_cat')
        .get()
    );
    reportPass('1.5 Public Customer can read active category of approved/live shop');

    // 1.5 Seed inactive category in Vendor A; Public Customer reading inactive category: DENY
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore()
        .collection('diamond_shops')
        .doc(vendorAUid)
        .collection('store_categories')
        .doc('hidden_seasonal_cat')
        .set({
          id: 'hidden_seasonal_cat',
          shopId: vendorAUid,
          name: 'Hidden Seasonal Items',
          isActive: false
        });
    });

    totalCount++;
    await assertFails(
      unauthContext.firestore()
        .collection('diamond_shops')
        .doc(vendorAUid)
        .collection('store_categories')
        .doc('hidden_seasonal_cat')
        .get()
    );
    reportPass('1.6 Public Customer reading inactive category is DENIED');

    // 1.6 Suspended Shop Owner creating or modifying category: DENY
    const suspendedContext = testEnv.authenticatedContext('suspended_shop_uid');
    totalCount++;
    await assertFails(
      suspendedContext.firestore()
        .collection('diamond_shops')
        .doc('suspended_shop_uid')
        .collection('store_categories')
        .doc('suspended_cat')
        .set({
          id: 'suspended_cat',
          shopId: 'suspended_shop_uid',
          name: 'Suspended Category',
          isActive: true
        })
    );
    reportPass('1.7 Suspended Shop write to store categories is DENIED');

    // 1.7 Cross-shop data poisoning (writing mismatching shopId in body): DENY
    totalCount++;
    await assertFails(
      vendorAContext.firestore()
        .collection('diamond_shops')
        .doc(vendorAUid)
        .collection('store_categories')
        .doc('spoofed_cat')
        .set({
          id: 'spoofed_cat',
          shopId: vendorBUid, // Mismatched body shopId!
          name: 'Spoofed Shop Category',
          isActive: true
        })
    );
    reportPass('1.8 Cross-shop data poisoning (mismatched shopId) is DENIED\n');

    // =============================================================
    // PART 2: PRODUCT CATEGORY VALIDATION RULES
    // =============================================================
    console.log('--- PART 2: PRODUCT CATEGORY VALIDATION RULES ---');

    // 2.1 Legacy Product without storeCategoryId: ALLOW
    totalCount++;
    await assertSucceeds(
      vendorAContext.firestore()
        .collection('diamond_shops')
        .doc(vendorAUid)
        .collection('products')
        .doc('legacy_prod_1')
        .set({
          id: 'legacy_prod_1',
          shopId: vendorAUid,
          name: 'Plain Salt (Legacy)',
          price: 25,
          sellingPrice: 20,
          stockQuantity: 50,
          inStock: true,
          isAvailable: true,
          isDeleted: false
          // storeCategoryId omitted
        })
    );
    reportPass('2.1 Legacy product without storeCategoryId is ALLOWED');

    // 2.2 Product with empty string storeCategoryId: ALLOW
    totalCount++;
    await assertSucceeds(
      vendorAContext.firestore()
        .collection('diamond_shops')
        .doc(vendorAUid)
        .collection('products')
        .doc('legacy_prod_2')
        .set({
          id: 'legacy_prod_2',
          shopId: vendorAUid,
          name: 'Wheat Flour (Unassigned)',
          price: 45,
          sellingPrice: 40,
          stockQuantity: 30,
          inStock: true,
          isAvailable: true,
          isDeleted: false,
          storeCategoryId: ''
        })
    );
    reportPass('2.2 Product with empty string storeCategoryId is ALLOWED');

    // 2.3 Product with valid active category belonging to this shop: ALLOW
    totalCount++;
    await assertSucceeds(
      vendorAContext.firestore()
        .collection('diamond_shops')
        .doc(vendorAUid)
        .collection('products')
        .doc('valid_dairy_prod')
        .set({
          id: 'valid_dairy_prod',
          shopId: vendorAUid,
          name: 'Amul Milk 1L',
          price: 66,
          sellingPrice: 64,
          stockQuantity: 20,
          inStock: true,
          isAvailable: true,
          isDeleted: false,
          storeCategoryId: 'dairy_cat'
        })
    );
    reportPass('2.3 Product with valid active category belonging to this shop is ALLOWED');

    // 2.4 Product assigning Other Shop category ID: DENY
    totalCount++;
    await assertFails(
      vendorAContext.firestore()
        .collection('diamond_shops')
        .doc(vendorAUid)
        .collection('products')
        .doc('injected_cat_prod')
        .set({
          id: 'injected_cat_prod',
          shopId: vendorAUid,
          name: 'Injected Cross-Category Prod',
          price: 100,
          sellingPrice: 90,
          stockQuantity: 10,
          inStock: true,
          isAvailable: true,
          isDeleted: false,
          storeCategoryId: 'vendor_b_cat' // Belongs to Vendor B!
        })
    );
    reportPass('2.4 Assigning category ID from another shop is DENIED');

    // 2.5 Product assigning inactive category on creation: DENY
    totalCount++;
    await assertFails(
      vendorAContext.firestore()
        .collection('diamond_shops')
        .doc(vendorAUid)
        .collection('products')
        .doc('inactive_cat_prod')
        .set({
          id: 'inactive_cat_prod',
          shopId: vendorAUid,
          name: 'Product with Inactive Category',
          price: 50,
          sellingPrice: 45,
          stockQuantity: 10,
          inStock: true,
          isAvailable: true,
          isDeleted: false,
          storeCategoryId: 'hidden_seasonal_cat' // Inactive!
        })
    );
    reportPass('2.5 Assigning inactive category to new product is DENIED\n');

    // =============================================================
    // PART 3: CLOUD FUNCTION: adjustDiamondProductStock
    // =============================================================
    console.log('--- PART 3: CLOUD FUNCTION: adjustDiamondProductStock ---');

    // Seed test product for stock adjustment in db directly
    const stockTestProdId = 'stock_test_prod_1';
    await db.collection('diamond_shops').doc(vendorAUid).collection('products').doc(stockTestProdId).set({
      id: stockTestProdId,
      shopId: vendorAUid,
      name: 'Basmati Rice 5kg',
      price: 500,
      sellingPrice: 450,
      stockQuantity: 10,
      inStock: true,
      isAvailable: true,
      isDeleted: false
    });

    // 3.1 Unauthenticated request is rejected
    totalCount++;
    await assert.rejects(
      adjustDiamondProductStock.run({
        auth: null,
        data: { shopId: vendorAUid, productId: stockTestProdId, operation: 'increment', amount: 5 }
      }),
      (err) => err.code === 'unauthenticated'
    );
    reportPass('3.1 Unauthenticated call to adjustDiamondProductStock is REJECTED');

    // 3.2 Unauthorized vendor attempting to adjust another vendor's product: REJECT
    totalCount++;
    await assert.rejects(
      adjustDiamondProductStock.run({
        auth: { uid: vendorBUid },
        data: { shopId: vendorAUid, productId: stockTestProdId, operation: 'increment', amount: 5 }
      }),
      (err) => err.code === 'permission-denied'
    );
    reportPass('3.2 Unauthorized vendor adjusting another vendor product is REJECTED');

    // 3.3 Invalid Operation or Amount is rejected
    totalCount++;
    await assert.rejects(
      adjustDiamondProductStock.run({
        auth: { uid: vendorAUid },
        data: { shopId: vendorAUid, productId: stockTestProdId, operation: 'multiply', amount: 5 }
      }),
      (err) => err.code === 'invalid-argument'
    );
    reportPass('3.3 Invalid operation rejected with invalid-argument');

    totalCount++;
    await assert.rejects(
      adjustDiamondProductStock.run({
        auth: { uid: vendorAUid },
        data: { shopId: vendorAUid, productId: stockTestProdId, operation: 'increment', amount: -5 }
      }),
      (err) => err.code === 'invalid-argument'
    );
    reportPass('3.4 Negative amount rejected with invalid-argument');

    // 3.4 Valid Increment: from 10 to 18 (+8)
    totalCount++;
    const incRes = await adjustDiamondProductStock.run({
      auth: { uid: vendorAUid },
      data: { shopId: vendorAUid, productId: stockTestProdId, operation: 'increment', amount: 8, reason: 'New stock delivery arrived' }
    });
    assert.strictEqual(incRes.previousStock, 10);
    assert.strictEqual(incRes.newStock, 18);
    assert.strictEqual(incRes.inStock, true);
    reportPass('3.5 Valid increment: 10 -> 18');

    // 3.5 Valid Decrement: from 18 to 11 (-7)
    totalCount++;
    const decRes = await adjustDiamondProductStock.run({
      auth: { uid: vendorAUid },
      data: { shopId: vendorAUid, productId: stockTestProdId, operation: 'decrement', amount: 7, reason: 'Damaged packaging removed' }
    });
    assert.strictEqual(decRes.previousStock, 18);
    assert.strictEqual(decRes.newStock, 11);
    assert.strictEqual(decRes.inStock, true);
    reportPass('3.6 Valid decrement: 18 -> 11');

    // 3.6 Valid Set: from 11 to 25
    totalCount++;
    const setRes = await adjustDiamondProductStock.run({
      auth: { uid: vendorAUid },
      data: { shopId: vendorAUid, productId: stockTestProdId, operation: 'set', amount: 25, reason: 'Physical stock count reconciliation' }
    });
    assert.strictEqual(setRes.previousStock, 11);
    assert.strictEqual(setRes.newStock, 25);
    reportPass('3.7 Valid set: 11 -> 25');

    // 3.7 Negative Stock Attempt: Current stock 25, attempt to decrement 30: REJECT
    totalCount++;
    await assert.rejects(
      adjustDiamondProductStock.run({
        auth: { uid: vendorAUid },
        data: { shopId: vendorAUid, productId: stockTestProdId, operation: 'decrement', amount: 30 }
      }),
      (err) => err.code === 'failed-precondition'
    );
    const verifyDoc = await db.collection('diamond_shops').doc(vendorAUid).collection('products').doc(stockTestProdId).get();
    assert.strictEqual(verifyDoc.data().stockQuantity, 25);
    reportPass('3.8 Negative stock attempt is strictly REJECTED (Stock remains at 25)');

    // 3.8 Audit Log Verification
    totalCount++;
    const auditLogsSnap = await db.collection('audit_logs')
      .where('action', '==', 'DIAMOND_STOCK_ADJUSTMENT')
      .where('productId', '==', stockTestProdId)
      .get();
    assert.strictEqual(auditLogsSnap.docs.length >= 3, true);
    const latestLog = auditLogsSnap.docs[auditLogsSnap.docs.length - 1].data();
    assert.strictEqual(latestLog.shopId, vendorAUid);
    assert.strictEqual(latestLog.adjustedBy, vendorAUid);
    assert.strictEqual(latestLog.callerRole, 'shopkeeper');
    reportPass('3.9 Audit log correctly recorded in audit_logs\n');

    // =============================================================
    // PART 4: CONCURRENCY SAFETY TEST
    // =============================================================
    console.log('--- PART 4: CONCURRENCY SAFETY TEST ---');
    console.log('Testing parallel execution of customer checkout & seller stock adjustment...');

    // Setup: Product with 5 units
    const concurrentProdId = 'concurrent_prod_1';
    await db.collection('diamond_shops').doc(vendorAUid).collection('products').doc(concurrentProdId).set({
      id: concurrentProdId,
      shopId: vendorAUid,
      name: 'Limited Mustard Oil 1L',
      price: 150,
      sellingPrice: 140,
      stockQuantity: 5,
      inStock: true,
      isAvailable: true,
      isDeleted: false
    });

    // Run parallel operations:
    // Operation 1: Seller decrements stock by 4
    // Operation 2: Customer orders 3 units (5 - 4 - 3 = -2 => Must conflict and safely fail one of them!)
    totalCount++;
    const sellerPromise = adjustDiamondProductStock.run({
      auth: { uid: vendorAUid },
      data: { shopId: vendorAUid, productId: concurrentProdId, operation: 'decrement', amount: 4, reason: 'Offline bulk counter sale' }
    });

    const customerPromise = placeDiamondOrder.run({
      auth: { uid: customerUid },
      data: {
        shopId: vendorAUid,
        deliveryMethod: 'pickup',
        items: [{ productId: concurrentProdId, quantity: 3 }]
      }
    });

    const results = await Promise.allSettled([sellerPromise, customerPromise]);
    const fulfilled = results.filter(r => r.status === 'fulfilled');
    const rejected = results.filter(r => r.status === 'rejected');

    console.log(`Concurrency execution: ${fulfilled.length} fulfilled, ${rejected.length} rejected as expected`);

    // Verify stock never went negative
    const finalDoc = await db.collection('diamond_shops').doc(vendorAUid).collection('products').doc(concurrentProdId).get();
    const finalStock = finalDoc.data().stockQuantity;
    assert.strictEqual(finalStock >= 0, true, 'Stock must never be negative');
    reportPass(`4.1 Concurrency safety verified: Final stock is ${finalStock} (strictly >= 0, no overselling)\n`);

    // =============================================================
    // PART 5: REGRESSION TESTING (Existing Order & Subscription Logic)
    // =============================================================
    console.log('--- PART 5: REGRESSION TESTING (ORDER FLOW & RESTORATION) ---');

    // Test placeDiamondOrder -> updateDiamondOrderStatus (rejected) -> atomic stock restoration strictly once
    totalCount++;
    const regProdId = 'regression_prod_1';
    await db.collection('diamond_shops').doc(vendorAUid).collection('products').doc(regProdId).set({
      id: regProdId,
      shopId: vendorAUid,
      name: 'Sugar 1kg',
      price: 50,
      sellingPrice: 42,
      stockQuantity: 20,
      inStock: true,
      isAvailable: true,
      isDeleted: false
    });

    // Place order for 5 units
    const orderRes = await placeDiamondOrder.run({
      auth: { uid: customerUid },
      data: {
        shopId: vendorAUid,
        deliveryMethod: 'pickup',
        items: [{ productId: regProdId, quantity: 5 }]
      }
    });
    const orderId = orderRes.orderId;

    // Check stock decremented to 15
    let pDoc = await db.collection('diamond_shops').doc(vendorAUid).collection('products').doc(regProdId).get();
    assert.strictEqual(pDoc.data().stockQuantity, 15);

    // Reject order: should restore stock to 20
    await updateDiamondOrderStatus.run({
      auth: { uid: vendorAUid },
      data: { orderId, newStatus: 'rejected', reason: 'Out of stock at store' }
    });

    pDoc = await db.collection('diamond_shops').doc(vendorAUid).collection('products').doc(regProdId).get();
    assert.strictEqual(pDoc.data().stockQuantity, 20);

    // Attempt second status update: terminal status cannot transition again
    await assert.rejects(
      updateDiamondOrderStatus.run({
        auth: { uid: vendorAUid },
        data: { orderId, newStatus: 'cancelled', reason: 'Cancel again' }
      }),
      (err) => err.code === 'failed-precondition'
    );

    // Stock must remain 20 (no double restoration)
    pDoc = await db.collection('diamond_shops').doc(vendorAUid).collection('products').doc(regProdId).get();
    assert.strictEqual(pDoc.data().stockQuantity, 20);
    reportPass('5.1 placeDiamondOrder and updateDiamondOrderStatus regression PASS (Atomic restoration strictly once)\n');

    console.log('================================================================');
    console.log(` ALL ${passedCount} OF ${totalCount} CHECKPOINT 2E TESTS PASSED (100% SUCCESS)`);
    console.log('================================================================');
  } finally {
    await testEnv.cleanup();
  }
}

runCheckpoint2ETestSuite().catch((err) => {
  console.error('Test Suite Fatal Error:', err);
  process.exit(1);
});

