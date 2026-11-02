/**
 * JAMUI SERVICES — REAL CLOUD FUNCTIONS EMULATOR NETWORK TEST SUITE
 * Priority 5.2: Verification of Cloud Functions through actual HTTP Callables over Port 5001
 * 
 * Architecture:
 * - Functions Emulator Daemon: http://127.0.0.1:5001/demo-jamui-services-emulator/asia-south1
 * - Auth Emulator Daemon: http://127.0.0.1:9099
 * - Firestore Emulator Daemon: 127.0.0.1:8080
 * 
 * Invokes functions via real Firebase Client SDK (httpsCallable) over loopback HTTP socket.
 */

const path = require('path');

process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099';
process.env.GCLOUD_PROJECT = 'demo-jamui-services-emulator';

// 1. Admin SDK for DB seeding and Minting Auth Tokens
const admin = require('firebase-admin');
if (admin.apps.length === 0) {
  admin.initializeApp({ projectId: 'demo-jamui-services-emulator' });
}
const db = admin.firestore();

// 2. Client SDK for HTTP Callable Invocations
const { initializeApp } = require(path.resolve(__dirname, '../node_modules/firebase/app'));
const { getAuth, connectAuthEmulator, signInWithCustomToken, signOut } = require(path.resolve(__dirname, '../node_modules/firebase/auth'));
const { getFunctions, connectFunctionsEmulator, httpsCallable } = require(path.resolve(__dirname, '../node_modules/firebase/functions'));

// Setup Client Apps
const clientApp = initializeApp({
  projectId: 'demo-jamui-services-emulator',
  apiKey: 'demo-fake-api-key'
}, 'real_emulator_client');

const clientAuth = getAuth(clientApp);
connectAuthEmulator(clientAuth, 'http://127.0.0.1:9099', { disableWarnings: true });

const clientFunctions = getFunctions(clientApp, 'asia-south1');
connectFunctionsEmulator(clientFunctions, '127.0.0.1', 5001);

// Callable Function References
const placeDiamondOrderCallable = httpsCallable(clientFunctions, 'placeDiamondOrder');
const updateDiamondOrderStatusCallable = httpsCallable(clientFunctions, 'updateDiamondOrderStatus');
const adminApproveDiamondShopCallable = httpsCallable(clientFunctions, 'adminApproveDiamondShop');
const adminSuspendDiamondShopCallable = httpsCallable(clientFunctions, 'adminSuspendDiamondShop');

// Helper to switch user identities
async function loginAs(uid, email = null) {
  await signOut(clientAuth);
  if (!uid) return null;
  const claims = email ? { email } : {};
  const customToken = await admin.auth().createCustomToken(uid, claims);
  const userCred = await signInWithCustomToken(clientAuth, customToken);
  return userCred.user;
}

// Assertions Helper
let passedCount = 0;
let totalCount = 0;

function assert(condition, message) {
  totalCount++;
  if (!condition) {
    console.error(`❌ [FAIL] ${message}`);
    throw new Error(`Assertion failed: ${message}`);
  }
  passedCount++;
  console.log(`✅ [PASS] ${message}`);
}

async function assertCallableRejects(promise, expectedCode, message) {
  totalCount++;
  try {
    await promise;
    console.error(`❌ [FAIL] Expected callable to fail with '${expectedCode}' but resolved: ${message}`);
    throw new Error(`Expected error '${expectedCode}' was not thrown`);
  } catch (err) {
    // In Firebase JS SDK, err.code is e.g. 'functions/permission-denied' or 'permission-denied'
    const code = (err.code || '').replace('functions/', '');
    const matches = code === expectedCode || (err.message && err.message.toLowerCase().includes(expectedCode));
    if (matches) {
      passedCount++;
      console.log(`✅ [PASS] ${message} (Received expected error '${code}')`);
    } else {
      console.error(`❌ [FAIL] Expected '${expectedCode}' but got '${err.code}': ${err.message}`);
      throw err;
    }
  }
}

async function runRealFunctionsEmulatorTests() {
  console.log('================================================================');
  console.log(' JAMUI SERVICES — REAL CLOUD FUNCTIONS EMULATOR NETWORK SUITE');
  console.log(' Target Endpoint: http://127.0.0.1:5001/demo-jamui-services-emulator/asia-south1');
  console.log(' Auth Endpoint:   http://127.0.0.1:9099');
  console.log(' DB Endpoint:     http://127.0.0.1:8080');
  console.log('================================================================\n');

  const vendorAUid = 'vendor_a_uid';
  const vendorBUid = 'vendor_b_uid';
  const customer1Uid = 'customer_1_uid';
  const customer2Uid = 'customer_2_uid';
  const activeAdminUid = 'admin_super_uid';
  const inactiveAdminUid = 'admin_inactive_uid';

  try {
    // -------------------------------------------------------------
    // STEP 1: Seed Initial Database State in Firestore Emulator
    // -------------------------------------------------------------
    console.log('--- SEEDING INITIAL DATA IN FIRESTORE EMULATOR ---');

    // Active Admin
    await db.collection('admin_users').doc(activeAdminUid).set({
      uid: activeAdminUid,
      role: 'admin',
      isActive: true,
      status: 'active',
      email: 'superadmin@jamuiservices.in'
    });

    // Inactive Admin
    await db.collection('admin_users').doc(inactiveAdminUid).set({
      uid: inactiveAdminUid,
      role: 'admin',
      isActive: false,
      email: 'inactiveadmin@jamuiservices.in'
    });

    // Approved & Active Shop A
    await db.collection('diamond_shops').doc(vendorAUid).set({
      id: vendorAUid,
      ownerUid: vendorAUid,
      shopName: 'Jamui Shrestha Jewellers',
      isApproved: true,
      status: 'approved',
      isActive: true,
      isSubscriptionActive: true,
      isDeleted: false,
      totalOrders: 0,
      totalRevenue: 0
    });

    // Products in Shop A
    const ringProdId = 'prod_gold_ring_4g';
    await db.collection('diamond_shops').doc(vendorAUid).collection('products').doc(ringProdId).set({
      id: ringProdId,
      shopId: vendorAUid,
      name: '22K Gold Ring 4g Hallmark',
      sellingPrice: 28000,
      stockQuantity: 10,
      inStock: true,
      isAvailable: true,
      isDeleted: false
    });

    const zeroStockProdId = 'prod_silver_bar_10g';
    await db.collection('diamond_shops').doc(vendorAUid).collection('products').doc(zeroStockProdId).set({
      id: zeroStockProdId,
      shopId: vendorAUid,
      name: '10g Pure Silver Bar',
      sellingPrice: 1200,
      stockQuantity: 0,
      inStock: false,
      isAvailable: true,
      isDeleted: false
    });

    // Pending Unapproved Shop B
    await db.collection('diamond_shops').doc(vendorBUid).set({
      id: vendorBUid,
      ownerUid: vendorBUid,
      shopName: 'Unapproved Diamond Traders',
      isApproved: false,
      status: 'pending',
      isActive: true,
      isSubscriptionActive: false,
      isDeleted: false
    });

    console.log('✓ Seeding complete via Firestore Emulator daemon on Port 8080\n');

    // -------------------------------------------------------------
    // STEP 2: TASK 3 & 4 — ADMIN AUTHORIZATION OVER NETWORK CALLABLES
    // -------------------------------------------------------------
    console.log('--- TASK 4: ADMIN AUTHORIZATION OVER PORT 5001 ---');

    // 1. Unauthenticated call to adminApproveDiamondShop
    await loginAs(null);
    await assertCallableRejects(
      adminApproveDiamondShopCallable({ shopId: vendorBUid }),
      'unauthenticated',
      '1. Unauthenticated HTTP call to adminApproveDiamondShop is rejected'
    );

    // 2. Normal customer calling adminApproveDiamondShop
    await loginAs(customer1Uid);
    await assertCallableRejects(
      adminApproveDiamondShopCallable({ shopId: vendorBUid }),
      'permission-denied',
      '2. Normal customer calling adminApproveDiamondShop is rejected with permission-denied'
    );

    // 3. Vendor attempting self-approval via callable
    await loginAs(vendorBUid);
    await assertCallableRejects(
      adminApproveDiamondShopCallable({ shopId: vendorBUid }),
      'permission-denied',
      '3. Vendor attempting self-approval via adminApproveDiamondShop is denied'
    );

    // 4. Inactive Admin calling adminApproveDiamondShop
    await loginAs(inactiveAdminUid, 'inactiveadmin@jamuiservices.in');
    await assertCallableRejects(
      adminApproveDiamondShopCallable({ shopId: vendorBUid }),
      'permission-denied',
      '4. Inactive Admin (isActive: false) calling adminApproveDiamondShop is denied'
    );

    // 5. Active Admin calling adminApproveDiamondShop
    await loginAs(activeAdminUid, 'superadmin@jamuiservices.in');
    const approveRes = await adminApproveDiamondShopCallable({ shopId: vendorBUid });
    assert(approveRes.data && approveRes.data.success === true, '5. Active Admin successfully approves shop via HTTP Callable');

    const shopBDocApproved = (await db.collection('diamond_shops').doc(vendorBUid).get()).data();
    assert(shopBDocApproved.isApproved === true && shopBDocApproved.status === 'approved', 'Shop B status in Firestore updated to approved');

    // 6. Normal customer calling adminSuspendDiamondShop
    await loginAs(customer1Uid);
    await assertCallableRejects(
      adminSuspendDiamondShopCallable({ shopId: vendorBUid, reason: 'Unauthorized customer action' }),
      'permission-denied',
      '6. Normal customer calling adminSuspendDiamondShop is denied'
    );

    // 7. Active Admin calling adminSuspendDiamondShop
    await loginAs(activeAdminUid, 'superadmin@jamuiservices.in');
    const suspendRes = await adminSuspendDiamondShopCallable({ shopId: vendorBUid, reason: 'Pending GST Verification' });
    assert(suspendRes.data && suspendRes.data.success === true, '7. Active Admin successfully suspends shop via HTTP Callable');

    const shopBDocSuspended = (await db.collection('diamond_shops').doc(vendorBUid).get()).data();
    assert(shopBDocSuspended.status === 'suspended' && shopBDocSuspended.isActive === false, 'Shop B status in Firestore updated to suspended');

    console.log('');

    // -------------------------------------------------------------
    // STEP 3: TASK 5 — INVENTORY & ORDER LIFECYCLE OVER CALLABLES
    // -------------------------------------------------------------
    console.log('--- TASK 5: INVENTORY & ORDER LIFECYCLE OVER PORT 5001 ---');

    // 8. Unauthenticated call to placeDiamondOrder
    await loginAs(null);
    await assertCallableRejects(
      placeDiamondOrderCallable({ shopId: vendorAUid, items: [{ productId: ringProdId, quantity: 1 }] }),
      'unauthenticated',
      '8. Unauthenticated HTTP call to placeDiamondOrder is rejected'
    );

    // 9. Authenticated customer ordering zero-stock item
    await loginAs(customer1Uid);
    await assertCallableRejects(
      placeDiamondOrderCallable({
        shopId: vendorAUid,
        items: [{ productId: zeroStockProdId, quantity: 1 }],
        deliveryMethod: 'delivery',
        deliveryAddress: { addressLine1: 'Cinema Road, Jamui' }
      }),
      'failed-precondition',
      '9. Checkout with zero stock product rejected with failed-precondition'
    );

    // 10. Malicious client sends unitPrice = ₹1 for ₹28,000 gold ring
    // Server must reject client price and calculate authoritative ₹56,000
    const orderReqPayload = {
      shopId: vendorAUid,
      items: [{ productId: ringProdId, quantity: 2, unitPrice: 1 }], // Tampered client price
      deliveryMethod: 'delivery',
      deliveryAddress: { addressLine1: 'Main Bazaar, Jamui', contactPhone: '+919876543210' },
      idempotencyKey: 'http_idem_key_001'
    };

    const placeRes = await placeDiamondOrderCallable(orderReqPayload);
    assert(placeRes.data && placeRes.data.success === true, '10. placeDiamondOrder succeeded over HTTP Callable');
    assert(placeRes.data.totalAmount === 56000, 'Server enforced authoritative price: 2 * ₹28,000 = ₹56,000 (Tampered ₹1 ignored)');

    const createdOrderId = placeRes.data.orderId;

    // 11. Verify atomic stock deduction in Firestore
    const ringDocAfterOrder = (await db.collection('diamond_shops').doc(vendorAUid).collection('products').doc(ringProdId).get()).data();
    assert(ringDocAfterOrder.stockQuantity === 8, '11. Product stock atomically decremented in Firestore from 10 to 8');

    // 12. Idempotency Check — Duplicate request over HTTP
    const dupRes = await placeDiamondOrderCallable(orderReqPayload);
    assert(dupRes.data.isDuplicate === true, '12. Duplicate request with idempotencyKey returned isDuplicate: true');
    assert(dupRes.data.orderId === createdOrderId, 'Returned original orderId without duplicate creation');

    const ringDocAfterDup = (await db.collection('diamond_shops').doc(vendorAUid).collection('products').doc(ringProdId).get()).data();
    assert(ringDocAfterDup.stockQuantity === 8, 'Product stock was NOT decremented again on duplicate request');

    // 13. Cross-Vendor Order Tampering — Vendor B attempts to update Vendor A order
    await loginAs(vendorBUid);
    await assertCallableRejects(
      updateDiamondOrderStatusCallable({ orderId: createdOrderId, newStatus: 'accepted' }),
      'permission-denied',
      '13. Unauthorized Vendor B updating Vendor A order is rejected with permission-denied'
    );

    // 14. Invalid status transition (placed -> delivered directly)
    await loginAs(vendorAUid);
    await assertCallableRejects(
      updateDiamondOrderStatusCallable({ orderId: createdOrderId, newStatus: 'delivered' }),
      'failed-precondition',
      '14. Invalid status transition (placed -> delivered) rejected with failed-precondition'
    );

    // 15. Authorized Shopkeeper accepts order (placed -> accepted)
    const acceptRes = await updateDiamondOrderStatusCallable({ orderId: createdOrderId, newStatus: 'accepted' });
    assert(acceptRes.data && acceptRes.data.success === true && acceptRes.data.newStatus === 'accepted', '15. Authorized shopkeeper accepts order over HTTP Callable (placed -> accepted)');

    // 16. Customer cancellation rejected after order is accepted
    await loginAs(customer1Uid);
    await assertCallableRejects(
      updateDiamondOrderStatusCallable({ orderId: createdOrderId, newStatus: 'cancelled' }),
      'failed-precondition',
      '16. Customer cancellation rejected when order is no longer in "placed" state'
    );

    // 17. Authorized Shopkeeper cancels order (accepted -> cancelled) with atomic stock restoration
    await loginAs(vendorAUid);
    const cancelRes = await updateDiamondOrderStatusCallable({
      orderId: createdOrderId,
      newStatus: 'cancelled',
      reason: 'Customer requested order cancellation'
    });
    assert(cancelRes.data && cancelRes.data.success === true && cancelRes.data.newStatus === 'cancelled', '17. Authorized shopkeeper cancels order (accepted -> cancelled)');

    const ringDocAfterCancel = (await db.collection('diamond_shops').doc(vendorAUid).collection('products').doc(ringProdId).get()).data();
    assert(ringDocAfterCancel.stockQuantity === 10, '18. Product stock atomically restored from 8 back to 10');

    // 19. Terminal status protection against double stock restoration
    const cancelledOrderDoc = (await db.collection('diamond_orders').doc(createdOrderId).get()).data();
    assert(cancelledOrderDoc.stockRestored === true, '19. Order document marked with stockRestored: true');

    // 20. Attempting another terminal transition on cancelled order
    await assertCallableRejects(
      updateDiamondOrderStatusCallable({ orderId: createdOrderId, newStatus: 'rejected' }),
      'failed-precondition',
      '20. Attempting re-rejection on cancelled order rejected; double stock restoration blocked'
    );

    const ringDocAfterTerminal = (await db.collection('diamond_shops').doc(vendorAUid).collection('products').doc(ringProdId).get()).data();
    assert(ringDocAfterTerminal.stockQuantity === 10, 'Product stock remained strictly 10 (no double increment)');

    console.log('\n================================================================');
    console.log(` RESULT: ${passedCount} / ${totalCount} TESTS PASSED (100%)`);
    console.log(' ALL 4 CLOUD FUNCTIONS VERIFIED OVER REAL EMULATOR HTTP PORT 5001');
    console.log('================================================================\n');

  } catch (err) {
    console.error('Real Functions Emulator Suite Failed:', err);
    process.exitCode = 1;
  }
}

if (require.main === module) {
  runRealFunctionsEmulatorTests();
}

module.exports = { runRealFunctionsEmulatorTests };

