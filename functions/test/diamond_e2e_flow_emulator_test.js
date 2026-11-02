/**
 * JAMUI SERVICES — PROFESSIONAL MARKETPLACE
 * (Legacy physical schema: diamond_shops, diamond_orders, diamond_categories)
 * PRIORITY 10: END-TO-END EMULATOR FLOW VERIFICATION TEST
 * 
 * Verifies all 10 core requirements:
 * 1. Seller Registration
 * 2. Admin Approval
 * 3. Product Add/Edit
 * 4. Product Stock Verification
 * 5. Customer Product Listing
 * 6. Cart & COD Order Placement (placeDiamondOrder)
 * 7. Stock Deduction (5 -> 3)
 * 8. Out of Stock Rejection (Ordering > remaining stock fails)
 * 9. Order Cancellation & Automatic Stock Restoration (1 -> 2)
 * 10. Seller & Admin Order Management Lifecycle
 */

const assert = require('assert');
const path = require('path');
const admin = require(path.join(__dirname, '../node_modules/firebase-admin'));
const FieldValue = admin.firestore.FieldValue;
const Timestamp = admin.firestore.Timestamp;

const PROJECT_ID = 'demo-jamui-services';
const FIRESTORE_PORT = 8080;
const FUNCTIONS_PORT = 5001;
const AUTH_PORT = 9099;

process.env.FIRESTORE_EMULATOR_HOST = `127.0.0.1:${FIRESTORE_PORT}`;
process.env.FIREBASE_AUTH_EMULATOR_HOST = `127.0.0.1:${AUTH_PORT}`;
process.env.GCLOUD_PROJECT = PROJECT_ID;

if (!admin.apps.length) {
  admin.initializeApp({ projectId: PROJECT_ID });
}

const db = admin.firestore();

// Helper to invoke HTTP callable cloud functions on Functions Emulator
async function callCallableFunction(functionName, data, authContext = null) {
  const url = `http://127.0.0.1:${FUNCTIONS_PORT}/${PROJECT_ID}/asia-south1/${functionName}`;
  const headers = { 'Content-Type': 'application/json' };
  if (authContext && authContext.token) {
    headers['Authorization'] = `Bearer ${authContext.token}`;
  }

  const res = await fetch(url, {
    method: 'POST',
    headers,
    body: JSON.stringify({ data }),
  });

  const json = await res.json();
  if (!res.ok || json.error) {
    const err = new Error(json.error?.message || `HTTP ${res.status}`);
    err.code = json.error?.status || json.error?.code || `HTTP_${res.status}`;
    err.details = json.error?.details;
    throw err;
  }
  return json.result;
}

// Mint mock JWT for callable function authentication in emulator
async function getAuthToken(uid, email = null) {
  try {
    const customToken = await admin.auth().createCustomToken(uid, email ? { email } : {});
    // Exchange custom token for ID token via Auth Emulator REST API
    const exchangeUrl = `http://127.0.0.1:${AUTH_PORT}/identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=fake-api-key`;
    const res = await fetch(exchangeUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token: customToken, returnSecureToken: true }),
    });
    const data = await res.json();
    return data.idToken;
  } catch (e) {
    // Fallback direct mock token
    return `mock_token_for_${uid}`;
  }
}

async function runDiamondE2EFlowTests() {
  console.log('\n======================================================');
  console.log('🧪 RUNNING PRIORITY 10: DIAMOND MARKETPLACE E2E TESTS');
  console.log(`📡 Project: ${PROJECT_ID} | Host: 127.0.0.1:${FIRESTORE_PORT}`);
  console.log('======================================================\n');

  let passed = 0;
  let failed = 0;

  async function test(name, fn) {
    try {
      await fn();
      console.log(`✅ PASS: ${name}`);
      passed++;
    } catch (e) {
      console.error(`❌ FAIL: ${name}`);
      console.error(`   Error: ${e.message}`);
      if (e.stack) console.error(e.stack.split('\n').slice(1, 4).join('\n'));
      failed++;
    }
  }

  const adminUid = 'mock_admin_uid_01';
  const seller1Uid = 'mock_seller_uid_01';
  const seller2Uid = 'mock_seller_uid_02';
  const custUid = 'mock_cust_uid_01';

  let adminToken, seller1Token, seller2Token, custToken;

  await test('Step 0: Mint Auth Tokens for Mock Users', async () => {
    adminToken = await getAuthToken(adminUid, 'admin@jamuiservice.test');
    seller1Token = await getAuthToken(seller1Uid, 'seller1@jamuiservice.test');
    seller2Token = await getAuthToken(seller2Uid, 'seller2@jamuiservice.test');
    custToken = await getAuthToken(custUid, 'customer@jamuiservice.test');
    assert(adminToken, 'Admin token minted');
    assert(seller1Token, 'Seller 1 token minted');
    assert(custToken, 'Cust token minted');
  });

  // TEST 1: Seller Registration
  await test('Step 1: Seller Registration (Seller 2 applies)', async () => {
    await db.collection('diamond_shops').doc(seller2Uid).set({
      shopId: seller2Uid,
      ownerUid: seller2Uid,
      shopName: 'Maa Durga Gold & Diamond Hub',
      status: 'pending',
      isApproved: false,
      isActive: false,
      isSubscriptionActive: false,
      isDeleted: false,
      paymentVerified: false,
      address: 'Station Road, Jamui, Bihar 811307',
      phone: '+919876543211',
      gstin: '10VWXYZ9876A1B2',
      hallmarkLicense: 'HM-JAMUI-2026-999',
      rating: 0.0,
      ratingCount: 0,
      totalOrders: 0,
      totalRevenue: 0,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    const shopDoc = await db.collection('diamond_shops').doc(seller2Uid).get();
    assert.strictEqual(shopDoc.data().status, 'pending');
    assert.strictEqual(shopDoc.data().isApproved, false);
    assert.strictEqual(shopDoc.data().isSubscriptionActive, false);
  });

  // TEST 2: Admin Approval of Seller 2
  await test('Step 2: Admin Approval of Seller 2 (adminApproveDiamondShop)', async () => {
    const res = await callCallableFunction('adminApproveDiamondShop', { shopId: seller2Uid }, { token: adminToken });
    assert(res.success, 'adminApproveDiamondShop succeeded');

    const shopDoc = await db.collection('diamond_shops').doc(seller2Uid).get();
    assert.strictEqual(shopDoc.data().status, 'approved');
    assert.strictEqual(shopDoc.data().isApproved, true);
    assert.strictEqual(shopDoc.data().isActive, true);
  });

  // TEST 3: Product Add and Edit
  const newProdId = 'prod_diamond_pendant_04';
  await test('Step 3: Product Add and Edit (Seller adds 10 pendants, edits price)', async () => {
    // Add product
    await db.collection('diamond_shops').doc(seller1Uid).collection('products').doc(newProdId).set({
      productId: newProdId,
      name: '14K Diamond Heart Pendant',
      category: 'Pendants',
      categoryId: 'cat_diamond_pendants',
      price: 30000,
      sellingPrice: 30000,
      stock: 10,
      stockQuantity: 10,
      inStock: true,
      purity: '14K',
      diamondWeight: '0.35 Carat',
      isAvailable: true,
      isDeleted: false,
      shopId: seller1Uid,
      shopName: 'Jamui Royal Diamond Jewellers',
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    let prodDoc = await db.collection('diamond_shops').doc(seller1Uid).collection('products').doc(newProdId).get();
    assert.strictEqual(prodDoc.data().stockQuantity, 10);
    assert.strictEqual(prodDoc.data().price, 30000);

    // Edit price to 28000
    await db.collection('diamond_shops').doc(seller1Uid).collection('products').doc(newProdId).update({
      price: 28000,
      updatedAt: FieldValue.serverTimestamp(),
    });

    prodDoc = await db.collection('diamond_shops').doc(seller1Uid).collection('products').doc(newProdId).get();
    assert.strictEqual(prodDoc.data().price, 28000);
  });

  // TEST 4: Customer Product Listing Visibility
  await test('Step 4: Customer Product Listing Visibility Check', async () => {
    const snap = await db.collection('diamond_shops').doc(seller1Uid).collection('products')
      .where('isAvailable', '==', true)
      .where('isDeleted', '==', false)
      .get();

    assert(snap.size >= 3, `Customer sees active products (found ${snap.size})`);
    snap.docs.forEach(d => {
      assert.strictEqual(d.data().isAvailable, true);
      assert.strictEqual(d.data().isDeleted, false);
    });
  });

  // TEST 5 & 6: Cart & COD Order Placement + Stock Deduction
  let testOrderId = null;
  const targetProdId = 'prod_solitaire_ring_01'; // initial stock = 5

  await test('Step 5 & 6: COD Order Placement & Atomic Stock Deduction (5 -> 3)', async () => {
    const prodBefore = await db.collection('diamond_shops').doc(seller1Uid).collection('products').doc(targetProdId).get();
    const initialStock = prodBefore.data().stockQuantity;
    assert.strictEqual(initialStock, 5, 'Initial stock must be 5');

    const orderPayload = {
      shopId: seller1Uid,
      items: [
        {
          productId: targetProdId,
          quantity: 2,
        },
      ],
      deliveryMethod: 'delivery',
      deliveryAddress: {
        customerName: 'Ramesh Kumar',
        contactPhone: '+919988776655',
        address: 'Ward No. 4, Jamui Town',
        area: 'Jamui',
        latitude: 24.92,
        longitude: 86.22,
      },
      paymentMethod: 'cod',
      idempotencyKey: `order_test_${Date.now()}`,
    };

    const res = await callCallableFunction('placeDiamondOrder', orderPayload, { token: custToken });
    assert(res.orderId, 'Order placed with valid orderId');
    testOrderId = res.orderId;

    // Verify order document
    const orderDoc = await db.collection('diamond_orders').doc(testOrderId).get();
    assert(orderDoc.exists, 'Order exists in diamond_orders');
    assert.strictEqual(orderDoc.data().status, 'placed');
    assert.strictEqual(orderDoc.data().totalAmount, 90000);

    // Verify stock deduction from 5 to 3
    const prodAfter = await db.collection('diamond_shops').doc(seller1Uid).collection('products').doc(targetProdId).get();
    assert.strictEqual(prodAfter.data().stockQuantity, 3, 'Stock was atomically decremented from 5 to 3');
  });

  // TEST 7: Out of Stock Rejection
  await test('Step 7: Out of Stock Rejection (Customer requests 4 when only 3 remain)', async () => {
    const invalidPayload = {
      shopId: seller1Uid,
      items: [
        {
          productId: targetProdId,
          quantity: 4, // Available is only 3!
        },
      ],
      deliveryMethod: 'delivery',
      deliveryAddress: {
        customerName: 'Ramesh Kumar',
        contactPhone: '+919988776655',
        address: 'Ward No. 4, Jamui Town',
        area: 'Jamui',
        latitude: 24.92,
        longitude: 86.22,
      },
      paymentMethod: 'cod',
      idempotencyKey: `order_fail_${Date.now()}`,
    };

    let threw = false;
    try {
      await callCallableFunction('placeDiamondOrder', invalidPayload, { token: custToken });
    } catch (e) {
      threw = true;
      assert(e.message.toLowerCase().includes('stock') || e.message.toLowerCase().includes('available') || e.message.toLowerCase().includes('insufficient'),
        `Error mentions stock: ${e.message}`);
    }
    assert(threw, 'Call must throw error on out-of-stock request');

    // Verify stock remains untouched at 3
    const prodCheck = await db.collection('diamond_shops').doc(seller1Uid).collection('products').doc(targetProdId).get();
    assert.strictEqual(prodCheck.data().stockQuantity, 3, 'Stock remains unchanged at 3');
  });

  // TEST 8: Seller Order Management (Status transitions: placed -> accepted -> preparing -> out_for_delivery -> delivered)
  await test('Step 8: Seller Order Processing (placed -> accepted -> preparing -> out_for_delivery -> delivered)', async () => {
    assert(testOrderId, 'testOrderId must exist');

    // 1. Accept order
    await callCallableFunction('updateDiamondOrderStatus', {
      orderId: testOrderId,
      newStatus: 'accepted',
    }, { token: seller1Token });

    let orderDoc = await db.collection('diamond_orders').doc(testOrderId).get();
    assert.strictEqual(orderDoc.data().status, 'accepted');

    // 2. Preparing order
    await callCallableFunction('updateDiamondOrderStatus', {
      orderId: testOrderId,
      newStatus: 'preparing',
    }, { token: seller1Token });

    orderDoc = await db.collection('diamond_orders').doc(testOrderId).get();
    assert.strictEqual(orderDoc.data().status, 'preparing');

    // 3. Out for delivery
    await callCallableFunction('updateDiamondOrderStatus', {
      orderId: testOrderId,
      newStatus: 'out_for_delivery',
    }, { token: seller1Token });

    orderDoc = await db.collection('diamond_orders').doc(testOrderId).get();
    assert.strictEqual(orderDoc.data().status, 'out_for_delivery');

    // 4. Delivered
    await callCallableFunction('updateDiamondOrderStatus', {
      orderId: testOrderId,
      newStatus: 'delivered',
    }, { token: seller1Token });

    orderDoc = await db.collection('diamond_orders').doc(testOrderId).get();
    assert.strictEqual(orderDoc.data().status, 'delivered');
  });

  // TEST 9: Admin Order Management (Admin can view and monitor all diamond orders)
  await test('Step 9: Admin Order Management & Monitoring', async () => {
    const ordersSnap = await db.collection('diamond_orders').orderBy('createdAt', 'desc').limit(10).get();
    assert(ordersSnap.size >= 1, 'Admin can query diamond_orders');
    const order = ordersSnap.docs.find(d => d.id === testOrderId);
    assert(order, 'Target order found in Admin listing');
    assert.strictEqual(order.data().status, 'delivered');
  });

  // TEST 10: Order Cancellation & Automatic Stock Restoration
  await test('Step 10: Order Cancellation & Automatic Stock Restoration (1 -> 2)', async () => {
    const bangleProdId = 'prod_diamond_bangles_03';
    const beforeDoc = await db.collection('diamond_shops').doc(seller1Uid).collection('products').doc(bangleProdId).get();
    const initialBangleStock = beforeDoc.data().stockQuantity;
    assert.strictEqual(initialBangleStock, 2, 'Initial bangles stock must be 2');

    // Place order for 1 pair
    const bangleOrderPayload = {
      shopId: seller1Uid,
      items: [
        {
          productId: bangleProdId,
          quantity: 1,
        },
      ],
      deliveryMethod: 'delivery',
      deliveryAddress: {
        customerName: 'Ramesh Kumar',
        contactPhone: '+919988776655',
        address: 'Ward No. 4, Jamui Town',
        area: 'Jamui',
        latitude: 24.92,
        longitude: 86.22,
      },
      paymentMethod: 'cod',
      idempotencyKey: `bangle_order_${Date.now()}`,
    };

    const res = await callCallableFunction('placeDiamondOrder', bangleOrderPayload, { token: custToken });
    const bangleOrderId = res.orderId;

    // Verify stock decremented from 2 to 1
    const orderedDoc = await db.collection('diamond_shops').doc(seller1Uid).collection('products').doc(bangleProdId).get();
    assert.strictEqual(orderedDoc.data().stockQuantity, 1, 'Bangles stock decremented from 2 to 1');

    // Cancel order
    await callCallableFunction('updateDiamondOrderStatus', {
      orderId: bangleOrderId,
      newStatus: 'cancelled',
      reason: 'Customer requested cancellation due to address correction',
    }, { token: seller1Token });

    // Verify status is cancelled
    const cancelledOrderDoc = await db.collection('diamond_orders').doc(bangleOrderId).get();
    assert.strictEqual(cancelledOrderDoc.data().status, 'cancelled');

    // Verify stock is atomically RESTORED back to 2!
    const restoredDoc = await db.collection('diamond_shops').doc(seller1Uid).collection('products').doc(bangleProdId).get();
    assert.strictEqual(restoredDoc.data().stockQuantity, 2, 'Bangles stock was atomically restored back to 2!');
  });

  // TEST 11: Terminal State Protection (Cannot modify a cancelled order)
  await test('Step 11: Terminal State Protection (Modifying cancelled order fails)', async () => {
    const ordersSnap = await db.collection('diamond_orders').where('status', '==', 'cancelled').limit(1).get();
    assert(ordersSnap.size > 0, 'Cancelled order exists');
    const cancelledOrderId = ordersSnap.docs[0].id;

    let threw = false;
    try {
      await callCallableFunction('updateDiamondOrderStatus', {
        orderId: cancelledOrderId,
        newStatus: 'delivered',
      }, { token: seller1Token });
    } catch (e) {
      threw = true;
      assert(e.message.toLowerCase().includes('terminal') || e.message.toLowerCase().includes('cannot') || e.message.toLowerCase().includes('cancelled'),
        `Error mentions terminal state: ${e.message}`);
    }
    assert(threw, 'Must throw error when trying to update cancelled order');
  });

  console.log('\n======================================================');
  console.log(`📊 SUMMARY: ${passed} PASSED | ${failed} FAILED`);
  console.log('======================================================\n');

  if (failed > 0) {
    process.exit(1);
  }
}

runDiamondE2EFlowTests()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Fatal Test Runner Error:', err);
    process.exit(1);
  });
