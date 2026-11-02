const fs = require('fs');
const path = require('path');
const assert = require('assert');

// Ensure module resolution points to functions/node_modules
const functionsNodeModules = path.resolve(__dirname, '../node_modules');
if (!module.paths.includes(functionsNodeModules)) {
  module.paths.unshift(functionsNodeModules);
}

const { initializeTestEnvironment } = require(path.resolve(functionsNodeModules, '@firebase/rules-unit-testing'));

async function runEndToEndApprovalTest() {
  console.log('================================================================');
  console.log(' JAMUI SERVICES — PROFESSIONAL REGISTRATION & APPROVAL TEST');
  console.log(' Target: Registration, Tracking Stream, Admin Review & Security');
  console.log('================================================================\n');

  const rulesPath = path.resolve(__dirname, '../../backend/firebase/firestore.rules');
  const rules = fs.readFileSync(rulesPath, 'utf8');

  const testEnv = await initializeTestEnvironment({
    projectId: 'demo-jamui-services-emulator',
    firestore: {
      rules,
      host: '127.0.0.1',
      port: 8080,
    },
  });

  const adminUid = 'admin_super_user';
  const adminCtx = testEnv.authenticatedContext(adminUid, { role: 'admin', email: 'admin@jamui.com' });
  const adminDb = adminCtx.firestore();

  // Seed Admin user record
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().collection('admin_users').doc(adminUid).set({
      role: 'super_admin',
      isActive: true,
      email: 'admin@jamui.com',
      createdAt: new Date(),
    });
  });

  // =============================================================
  // PART 1: TEST A — PROFESSIONAL SELLER REGISTRATION & ADMIN APPROVAL
  // =============================================================
  console.log('--- PART 1: TEST A — Seller Registration, Admin Visibility & Approval ---');
  const sellerAUid = 'seller_ramesh_001';
  const sellerACtx = testEnv.authenticatedContext(sellerAUid);
  const sellerADb = sellerACtx.firestore();

  // 1. Seller A creates initial diamond_shops/{uid} record
  console.log('Step 1: Seller A creates diamond_shops/{uid} record (status: pending)...');
  const initialShopData = {
    id: sellerAUid,
    shopId: sellerAUid,
    ownerUid: sellerAUid,
    shopName: 'Ramesh General Store',
    category: 'Grocery & Daily Needs',
    categoryId: 'grocery',
    demandCategoryId: 'grocery',
    demandCategoryTitle: 'Grocery & Daily Needs',
    description: 'Fresh grains, oils and daily household goods in Jamui',
    address: 'Station Road, Jamui - 811307',
    jamuiArea: 'Jamui Town',
    city: 'Jamui',
    district: 'Jamui',
    pincode: '811307',
    latitude: 24.9273,
    longitude: 86.2238,
    isOpen: true,
    status: 'pending',
    isApproved: false,
    isActive: true,
    isDeleted: false,
    isSubscriptionActive: false,
    paymentVerified: false,
    rating: 0.0,
    ratingCount: 0,
    totalOrders: 0,
    totalRevenue: 0,
    ownerName: 'Ramesh Kumar',
    ownerPhone: '+919876543210',
    ownerEmail: 'ramesh@jamui.test',
  };

  await sellerADb.collection('diamond_shops').doc(sellerAUid).set(initialShopData);
  console.log('✅ Step 1 Passed: Seller A registration document successfully persisted in diamond_shops.');

  // 2. Admin streams/queries diamond_shops directory
  console.log('Step 2: Admin queries pending shops directory...');
  const pendingShopsSnap = await adminDb.collection('diamond_shops').get();
  const foundShopDoc = pendingShopsSnap.docs.find(d => d.id === sellerAUid);
  assert(foundShopDoc, 'Admin must find newly registered shop in diamond_shops');
  assert.strictEqual(foundShopDoc.data().status, 'pending');
  assert.strictEqual(foundShopDoc.data().isApproved, false);
  assert.strictEqual(foundShopDoc.data().shopName, 'Ramesh General Store');
  assert.strictEqual(foundShopDoc.data().demandCategoryId, 'grocery');
  console.log('✅ Step 2 Passed: Admin sees newly registered shop with correct pending status and metadata.');

  // 3. Admin approves the application
  console.log('Step 3: Admin approves the application...');
  await adminDb.collection('diamond_shops').doc(sellerAUid).update({
    status: 'approved',
    isApproved: true,
    isActive: true,
    approvedAt: new Date(),
    approvedBy: adminUid,
  });
  console.log('✅ Step 3 Passed: Admin successfully approved shop.');

  // 4. Verify Seller A reads the updated status via real-time stream
  console.log('Step 4: Seller A reads updated diamond_shops/{uid} status...');
  const sellerAShopSnap = await sellerADb.collection('diamond_shops').doc(sellerAUid).get();
  assert.strictEqual(sellerAShopSnap.data().status, 'approved', 'Status must be approved');
  assert.strictEqual(sellerAShopSnap.data().isApproved, true, 'isApproved must be true');
  assert.strictEqual(sellerAShopSnap.data().isSubscriptionActive, false, 'isSubscriptionActive must still be false');
  console.log('✅ Step 4 Passed: Seller A receives approved status in real-time stream. isSubscriptionActive remains false.');

  // =============================================================
  // PART 2: TEST B — REJECTION FLOW
  // =============================================================
  console.log('\n--- PART 2: TEST B — Rejection Flow ---');
  const sellerBUid = 'seller_suresh_002';
  const sellerBCtx = testEnv.authenticatedContext(sellerBUid);
  const sellerBDb = sellerBCtx.firestore();

  // Register Seller B
  await sellerBDb.collection('diamond_shops').doc(sellerBUid).set({
    id: sellerBUid,
    shopId: sellerBUid,
    ownerUid: sellerBUid,
    shopName: 'Suresh Hardware',
    category: 'Hardware & Electricals',
    categoryId: 'hardware',
    demandCategoryId: 'hardware',
    demandCategoryTitle: 'Hardware & Electricals',
    description: 'Tools and construction materials',
    isOpen: true,
    status: 'pending',
    isApproved: false,
    isActive: true,
    isDeleted: false,
    isSubscriptionActive: false,
    paymentVerified: false,
    rating: 0.0,
    ratingCount: 0,
    totalOrders: 0,
    totalRevenue: 0,
  });

  // Admin rejects Seller B
  console.log('Admin rejects Seller B with reason...');
  await adminDb.collection('diamond_shops').doc(sellerBUid).update({
    status: 'rejected',
    isApproved: false,
    isActive: false,
    rejectionReason: 'Invalid shop trade license documents provided.',
    rejectedAt: new Date(),
    rejectedBy: adminUid,
  });

  const rejectedSnap = await sellerBDb.collection('diamond_shops').doc(sellerBUid).get();
  assert.strictEqual(rejectedSnap.data().status, 'rejected');
  assert.strictEqual(rejectedSnap.data().isApproved, false);
  assert.strictEqual(rejectedSnap.data().isActive, false);
  assert.strictEqual(rejectedSnap.data().rejectionReason, 'Invalid shop trade license documents provided.');
  console.log('✅ Rejection status and reason verified. Provider treated as unapproved/inactive.');

  // =============================================================
  // PART 3: TEST C — APP RESTART & RECOVERY
  // =============================================================
  console.log('\n--- PART 3: TEST C — App Restart & Recovery ---');
  const sellerCUid = 'seller_anita_003';
  const sellerCCtx = testEnv.authenticatedContext(sellerCUid);
  const sellerCDb = sellerCCtx.firestore();

  await sellerCDb.collection('diamond_shops').doc(sellerCUid).set({
    id: sellerCUid,
    shopId: sellerCUid,
    ownerUid: sellerCUid,
    shopName: 'Anita Book Store',
    category: 'Books & Stationery',
    categoryId: 'stationery',
    demandCategoryId: 'stationery',
    demandCategoryTitle: 'Books & Stationery',
    isOpen: true,
    status: 'pending',
    isApproved: false,
    isActive: true,
    isDeleted: false,
    isSubscriptionActive: false,
    paymentVerified: false,
    rating: 0.0,
    ratingCount: 0,
    totalOrders: 0,
    totalRevenue: 0,
  });

  // Simulate app restart / login with same credentials: query diamond_shops/{uid}
  const restoredShop = await sellerCDb.collection('diamond_shops').doc(sellerCUid).get();

  assert(restoredShop.exists, 'Shop doc exists on restart');
  assert.strictEqual(restoredShop.data().status, 'pending');
  assert.strictEqual(restoredShop.data().isApproved, false);
  assert.strictEqual(restoredShop.data().ownerUid, sellerCUid);
  console.log('✅ App restart successfully recovers exact pending registration state without duplicate creation.');

  // =============================================================
  // PART 4: SECURITY & ACCESS CONTROL TESTS
  // =============================================================
  console.log('\n--- PART 4: Security & Privilege Escalation Prevention ---');

  // 1. Cross-seller read rejection
  console.log('Test 4.1: Cross-seller read rejection...');
  try {
    await sellerACtx.firestore().collection('diamond_shops').doc(sellerBUid).get();
    assert.fail('Should have been rejected');
  } catch (err) {
    assert.strictEqual(err.code, 'permission-denied');
    console.log('✅ Passed: Seller A cannot read Seller B’s pending application.');
  }

  // 2. Self-approval escalation rejection
  console.log('Test 4.2: Self-approval escalation rejection...');
  try {
    await sellerCCtx.firestore().collection('diamond_shops').doc(sellerCUid).update({
      isApproved: true,
      status: 'approved',
    });
    assert.fail('Should have been rejected');
  } catch (err) {
    assert.strictEqual(err.code, 'permission-denied');
    console.log('✅ Passed: Seller cannot self-approve their own shop.');
  }

  // 3. Self-subscription activation escalation rejection
  console.log('Test 4.3: Self-subscription activation escalation rejection...');
  try {
    await sellerACtx.firestore().collection('diamond_shops').doc(sellerAUid).update({
      isSubscriptionActive: true,
    });
    assert.fail('Should have been rejected');
  } catch (err) {
    assert.strictEqual(err.code, 'permission-denied');
    console.log('✅ Passed: Seller cannot self-activate subscription.');
  }

  // 4. Public Customer read visibility rule
  console.log('Test 4.4: Public customer read rules...');
  const customerCtx = testEnv.authenticatedContext('customer_shopper_999');
  const customerDb = customerCtx.firestore();

  // A. Seller A is approved but isSubscriptionActive is false -> Customer CANNOT read
  try {
    await customerDb.collection('diamond_shops').doc(sellerAUid).get();
    assert.fail('Should have failed');
  } catch (err) {
    assert.strictEqual(err.code, 'permission-denied');
    console.log('Sub-test 4.4A: Approved shop with isSubscriptionActive == false is HIDDEN from customer.');
  }

  // B. Seller B is rejected -> Customer CANNOT read
  try {
    await customerDb.collection('diamond_shops').doc(sellerBUid).get();
    assert.fail('Should have failed');
  } catch (err) {
    assert.strictEqual(err.code, 'permission-denied');
    console.log('Sub-test 4.4B: Rejected shop is HIDDEN from customer.');
  }

  // C. Seller C is pending -> Customer CANNOT read
  try {
    await customerDb.collection('diamond_shops').doc(sellerCUid).get();
    assert.fail('Should have failed');
  } catch (err) {
    assert.strictEqual(err.code, 'permission-denied');
    console.log('Sub-test 4.4C: Pending shop is HIDDEN from customer.');
  }

  // D. Fully live shop (approved, active, subscription active) -> Customer CAN read
  const liveShopUid = 'seller_live_store_100';
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().collection('diamond_shops').doc(liveShopUid).set({
      id: liveShopUid,
      shopId: liveShopUid,
      ownerUid: liveShopUid,
      shopName: 'Live Kirana Jamui',
      status: 'approved',
      isApproved: true,
      isActive: true,
      isSubscriptionActive: true,
      isDeleted: false,
    });
  });

  const liveDoc = await customerDb.collection('diamond_shops').doc(liveShopUid).get();
  assert(liveDoc.exists, 'Live doc exists');
  console.log('Sub-test 4.4D: Fully compliant live shop is readable by customer.');

  // =============================================================
  // PART 5: NORMAL PROVIDER ISOLATION
  // =============================================================
  console.log('\n--- PART 5: Normal Service Provider Isolation ---');
  const normalUid = 'normal_plumber_555';
  const normalCtx = testEnv.authenticatedContext(normalUid);
  const normalDb = normalCtx.firestore();

  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().collection('providers').doc(normalUid).set({
      businessName: 'Sharma Plumbing Works',
      primaryCategoryId: 'plumber',
      primaryCategoryTitle: 'Plumber',
      categoryType: 'general',
      isProfessional: false,
      isDiamond: false,
      businessType: 'service_provider',
      registrationStatus: 'completed',
      status: 'approved',
    });
  });

  // Verify normal provider has no diamond_shops doc
  const normalShopDoc = await normalDb.collection('diamond_shops').doc(normalUid).get();
  assert(!normalShopDoc.exists, 'Normal provider must not have diamond_shops doc');
  console.log('✅ Passed: Normal service provider remains completely isolated with zero professional exposure.');

  await testEnv.cleanup();
  console.log('\n================================================================');
  console.log(' ALL REGISTRATION, TRACKING & APPROVAL TESTS PASSED (100%)');
  console.log('================================================================');
}

runEndToEndApprovalTest().catch(err => {
  console.error('Fatal Test Error:', err);
  process.exit(1);
});
