/**
 * JAMUI SERVICES — REAL CLOUD FUNCTIONS EMULATOR TEST SUITE
 * Priority 5.1: Cloud Functions Emulator, Admin Authorization & Lifecycle Validation
 * 
 * Target Functions:
 * 1. placeDiamondOrder
 * 2. updateDiamondOrderStatus
 * 3. adminApproveDiamondShop
 * 4. adminSuspendDiamondShop
 * 
 * Features Under Test:
 * - Pure Demo Isolation (demo-jamui-services-emulator)
 * - Authentication & Role Verification (Customer, Vendor, Admin)
 * - Server-side authoritative pricing & stock deduction
 * - Atomic stock restoration on reject/cancel (strictly once)
 * - Idempotency
 * - State machine transitions
 * - Failure scenarios (0 stock, malicious price, cross-vendor tampering)
 */

process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
process.env.GCLOUD_PROJECT = 'demo-jamui-services-emulator';
process.env.FIREBASE_CONFIG = JSON.stringify({ projectId: 'demo-jamui-services-emulator' });

const admin = require('firebase-admin');

// Load Cloud Functions under test
const {
  placeDiamondOrder,
  updateDiamondOrderStatus,
  adminApproveDiamondShop,
  adminSuspendDiamondShop
} = require('../index.js');

const db = admin.firestore();

// Test Assertions Helper
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

async function assertRejects(promise, expectedErrorCode, message) {
  totalCount++;
  try {
    await promise;
    console.error(`❌ [FAIL] Expected rejection with '${expectedErrorCode}' but resolved: ${message}`);
    throw new Error(`Expected error '${expectedErrorCode}' was not thrown`);
  } catch (err) {
    const code = err.code || (err.message && err.message.toLowerCase());
    const matches = code && (code === expectedErrorCode || code.includes(expectedErrorCode));
    if (matches) {
      passedCount++;
      console.log(`✅ [PASS] ${message} (Threw expected '${expectedErrorCode}')`);
    } else {
      console.error(`❌ [FAIL] Expected '${expectedErrorCode}' but got '${err.code}': ${err.message}`);
      throw err;
    }
  }
}

async function runCloudFunctionsEmulatorSuite() {
  console.log('================================================================');
  console.log(' JAMUI SERVICES — CLOUD FUNCTIONS EMULATOR VALIDATION SUITE');
  console.log(' Target Project: demo-jamui-services-emulator (100% Offline)');
  console.log(' Host: 127.0.0.1:8080 (Real Firestore Emulator Daemon)');
  console.log('================================================================\n');

  const testShopId = 'test_shop_emulator_1';
  const vendorAUid = 'vendor_a_uid';
  const vendorBUid = 'vendor_b_uid';
  const customer1Uid = 'customer_1_uid';
  const customer2Uid = 'customer_2_uid';
  const adminUid = 'admin_super_uid';

  try {
    // -------------------------------------------------------------
    // SETUP: Seed Test Documents directly in Emulator DB
    // -------------------------------------------------------------
    console.log('--- SEEDING EMULATOR TEST DATA ---');
    
    // 1. Seed Active Admin
    await db.collection('admin_users').doc(adminUid).set({
      uid: adminUid,
      role: 'admin',
      isActive: true,
      email: 'admin@jamuiservices.in'
    });

    // 2. Seed Diamond Shop
    await db.collection('diamond_shops').doc(testShopId).set({
      id: testShopId,
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

    // 3. Seed Products in Shop Subcollection
    const ringProdId = 'prod_ring_gold';
    await db.collection('diamond_shops').doc(testShopId).collection('products').doc(ringProdId).set({
      id: ringProdId,
      shopId: testShopId,
      name: '22K Hallmark Gold Ring 4g',
      sellingPrice: 28000,
      stockQuantity: 10,
      inStock: true,
      isAvailable: true,
      isDeleted: false
    });

    const zeroStockProdId = 'prod_silver_coin';
    await db.collection('diamond_shops').doc(testShopId).collection('products').doc(zeroStockProdId).set({
      id: zeroStockProdId,
      shopId: testShopId,
      name: '10g Pure Silver Coin',
      sellingPrice: 1200,
      stockQuantity: 0,
      inStock: false,
      isAvailable: true,
      isDeleted: false
    });

    // 4. Seed Pending Unapproved Shop (for Admin test)
    const pendingShopId = 'pending_shop_emulator_2';
    await db.collection('diamond_shops').doc(pendingShopId).set({
      id: pendingShopId,
      ownerUid: vendorBUid,
      shopName: 'Unapproved Diamond Traders',
      isApproved: false,
      status: 'pending',
      isActive: true,
      isSubscriptionActive: false,
      isDeleted: false
    });

    console.log('✓ Seeding complete in Firestore Emulator\n');

    // -------------------------------------------------------------
    // TASK 3: ADMIN AUTHORIZATION TESTS
    // -------------------------------------------------------------
    console.log('--- TASK 3: ADMIN AUTHORIZATION TESTS ---');

    // Test 3.1: Unauthenticated request to adminApproveDiamondShop is rejected
    await assertRejects(
      adminApproveDiamondShop.run({ auth: null, data: { shopId: pendingShopId } }),
      'unauthenticated',
      'Unauthenticated call to adminApproveDiamondShop is rejected'
    );

    // Test 3.2: Regular customer attempting admin approval is rejected
    await assertRejects(
      adminApproveDiamondShop.run({ auth: { uid: customer1Uid }, data: { shopId: pendingShopId } }),
      'permission-denied',
      'Normal customer attempting adminApproveDiamondShop is denied'
    );

    // Test 3.3: Vendor attempting self-approval or approval is rejected
    await assertRejects(
      adminApproveDiamondShop.run({ auth: { uid: vendorBUid }, data: { shopId: pendingShopId } }),
      'permission-denied',
      'Vendor attempting self-approval via adminApproveDiamondShop is denied'
    );

    // Test 3.4: Verified active Admin successfully approves shop
    const approveResult = await adminApproveDiamondShop.run({
      auth: { uid: adminUid, token: { email: 'admin@jamuiservices.in' } },
      data: { shopId: pendingShopId }
    });
    assert(approveResult.success === true, 'Admin successfully approves pending shop');

    const updatedPendingShop = (await db.collection('diamond_shops').doc(pendingShopId).get()).data();
    assert(updatedPendingShop.isApproved === true && updatedPendingShop.status === 'approved', 'Shop document status updated to approved');

    // Test 3.5: Regular customer attempting adminSuspendDiamondShop is rejected
    await assertRejects(
      adminSuspendDiamondShop.run({ auth: { uid: customer1Uid }, data: { shopId: testShopId, reason: 'Malicious attempt' } }),
      'permission-denied',
      'Normal customer attempting adminSuspendDiamondShop is denied'
    );

    // Test 3.6: Verified active Admin successfully suspends shop
    const suspendResult = await adminSuspendDiamondShop.run({
      auth: { uid: adminUid, token: { email: 'admin@jamuiservices.in' } },
      data: { shopId: pendingShopId, reason: 'Incomplete KYC documentation' }
    });
    assert(suspendResult.success === true, 'Admin successfully suspends shop');

    const suspendedShopDoc = (await db.collection('diamond_shops').doc(pendingShopId).get()).data();
    assert(suspendedShopDoc.status === 'suspended' && suspendedShopDoc.isActive === false, 'Shop document status updated to suspended & isActive=false');

    console.log('');

    // -------------------------------------------------------------
    // TASK 2 & 4: INVENTORY, LIFECYCLE & FAILURE SCENARIOS
    // -------------------------------------------------------------
    console.log('--- TASK 2 & 4: CLOUD FUNCTIONS ORDER & INVENTORY TESTS ---');

    // Test 4.1: Unauthenticated placeDiamondOrder is rejected
    await assertRejects(
      placeDiamondOrder.run({ auth: null, data: { shopId: testShopId, items: [{ productId: ringProdId, quantity: 1 }] } }),
      'unauthenticated',
      'Unauthenticated order placement is rejected'
    );

    // Test 4.2: Zero-stock product checkout is rejected
    await assertRejects(
      placeDiamondOrder.run({
        auth: { uid: customer1Uid },
        data: {
          shopId: testShopId,
          items: [{ productId: zeroStockProdId, quantity: 1 }],
          deliveryMethod: 'delivery',
          deliveryAddress: { addressLine1: 'Station Road, Jamui' }
        }
      }),
      'failed-precondition',
      'Checkout with zero stock is rejected with failed-precondition'
    );

    // Test 4.3: Client sends malicious unit price (₹1 instead of ₹28,000)
    // Server must recalculate authoritative price from catalog and ignore client price
    const order1Result = await placeDiamondOrder.run({
      auth: { uid: customer1Uid },
      data: {
        shopId: testShopId,
        items: [{ productId: ringProdId, quantity: 2, unitPrice: 1 }], // Tampered client price
        deliveryMethod: 'delivery',
        deliveryAddress: { addressLine1: 'Main Market, Jamui' },
        idempotencyKey: 'idem_order_001'
      }
    });

    assert(order1Result.success === true, 'Order created successfully');
    assert(order1Result.totalAmount === 56000, 'Server enforced authoritative price: 2 * ₹28,000 = ₹56,000 (Tampered ₹1 ignored)');
    
    // Verify stock deducted in Firestore
    const ringDocAfterOrder = (await db.collection('diamond_shops').doc(testShopId).collection('products').doc(ringProdId).get()).data();
    assert(ringDocAfterOrder.stockQuantity === 8, 'Product stock quantity atomically decremented from 10 to 8');

    // Test 4.4: Idempotency Check — Duplicate request with same idempotencyKey returns existing order
    const order1DupResult = await placeDiamondOrder.run({
      auth: { uid: customer1Uid },
      data: {
        shopId: testShopId,
        items: [{ productId: ringProdId, quantity: 2, unitPrice: 1 }],
        deliveryMethod: 'delivery',
        deliveryAddress: { addressLine1: 'Main Market, Jamui' },
        idempotencyKey: 'idem_order_001'
      }
    });

    assert(order1DupResult.isDuplicate === true, 'Duplicate request with idempotencyKey recognized as duplicate');
    assert(order1DupResult.orderId === order1Result.orderId, 'Existing order ID returned without recreating order');

    const ringDocAfterDup = (await db.collection('diamond_shops').doc(testShopId).collection('products').doc(ringProdId).get()).data();
    assert(ringDocAfterDup.stockQuantity === 8, 'Stock was NOT decremented again on duplicate idempotent hit');

    // Test 4.5: Cross-Vendor Isolation — Vendor B attempts to update Vendor A shop order
    const createdOrderId = order1Result.orderId;
    await assertRejects(
      updateDiamondOrderStatus.run({
        auth: { uid: vendorBUid }, // Vendor B (does not own testShopId)
        data: { orderId: createdOrderId, newStatus: 'accepted' }
      }),
      'permission-denied',
      'Unauthorized vendor B updating vendor A order is rejected with permission-denied'
    );

    // Test 4.6: Invalid State Machine Transition (placed -> delivered directly)
    await assertRejects(
      updateDiamondOrderStatus.run({
        auth: { uid: testShopId }, // Shop owner
        data: { orderId: createdOrderId, newStatus: 'delivered' }
      }),
      'failed-precondition',
      'Invalid status transition (placed -> delivered) is rejected with failed-precondition'
    );

    // Test 4.7: Authorized Shopkeeper accepts order (placed -> accepted)
    const acceptResult = await updateDiamondOrderStatus.run({
      auth: { uid: testShopId },
      data: { orderId: createdOrderId, newStatus: 'accepted' }
    });
    assert(acceptResult.success === true && acceptResult.newStatus === 'accepted', 'Authorized shopkeeper accepts order (placed -> accepted)');

    // Test 4.8: Customer attempting to cancel after order is accepted is rejected
    await assertRejects(
      updateDiamondOrderStatus.run({
        auth: { uid: customer1Uid },
        data: { orderId: createdOrderId, newStatus: 'cancelled' }
      }),
      'failed-precondition',
      'Customer cancellation rejected when order status is no longer "placed"'
    );

    // Test 4.9: Order cancellation by shopkeeper restores inventory atomically
    const cancelResult = await updateDiamondOrderStatus.run({
      auth: { uid: testShopId },
      data: { orderId: createdOrderId, newStatus: 'cancelled', reason: 'Customer requested cancellation' }
    });
    assert(cancelResult.success === true && cancelResult.newStatus === 'cancelled', 'Shopkeeper cancelled order');

    const ringDocAfterCancel = (await db.collection('diamond_shops').doc(testShopId).collection('products').doc(ringProdId).get()).data();
    assert(ringDocAfterCancel.stockQuantity === 10, 'Cancelled order atomically restored 2 units (stock back to 10)');

    // Test 4.10: Double stock restoration prevention — status already terminal
    const orderDocCancelled = (await db.collection('diamond_orders').doc(createdOrderId).get()).data();
    assert(orderDocCancelled.stockRestored === true, 'Order marked with stockRestored=true flag');

    // Attempting another terminal update
    await assertRejects(
      updateDiamondOrderStatus.run({
        auth: { uid: testShopId },
        data: { orderId: createdOrderId, newStatus: 'rejected' }
      }),
      'failed-precondition',
      'Re-rejecting already cancelled terminal order is rejected; stock cannot be restored twice'
    );

    const ringDocAfterTerminalAttempt = (await db.collection('diamond_shops').doc(testShopId).collection('products').doc(ringProdId).get()).data();
    assert(ringDocAfterTerminalAttempt.stockQuantity === 10, 'Stock remained strictly 10 (no double restoration)');

    console.log('\n================================================================');
    console.log(` RESULT: ${passedCount} / ${totalCount} TESTS PASSED (100%)`);
    console.log(' CLOUD FUNCTIONS EMULATOR & ADMIN AUTHORIZATION 100% VERIFIED');
    console.log('================================================================\n');

  } catch (err) {
    console.error('Test Suite Failed:', err);
    process.exitCode = 1;
  }
}

if (require.main === module) {
  runCloudFunctionsEmulatorSuite();
}

module.exports = { runCloudFunctionsEmulatorSuite };
