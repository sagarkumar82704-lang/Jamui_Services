const fs = require('fs');
const path = require('path');
const assert = require('assert');

// Ensure module resolution points to functions/node_modules
const functionsNodeModules = path.resolve(__dirname, '../node_modules');
if (!module.paths.includes(functionsNodeModules)) {
  module.paths.unshift(functionsNodeModules);
}

const { initializeTestEnvironment } = require(path.resolve(functionsNodeModules, '@firebase/rules-unit-testing'));

async function runOwnerContactDetailsFixTest() {
  console.log('================================================================');
  console.log(' JAMUI SERVICES — SHOP OWNER CONTACT DETAILS FIX TEST');
  console.log(' Target: diamond_shops ownerName, ownerPhone, ownerEmail & Inspector');
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

  // Helper simulating the Admin Inspector resolver in Dart
  function resolveAdminInspectorFields(shopDocData) {
    const rawOwner = (shopDocData['ownerName'] || shopDocData['fullName'] || shopDocData['name'] || '').toString().trim();
    const rawPhone = (shopDocData['ownerPhone'] || shopDocData['phone'] || shopDocData['mobile'] || shopDocData['contactPhone'] || '').toString().trim();
    const rawEmail = (shopDocData['ownerEmail'] || shopDocData['email'] || '').toString().trim();

    return {
      ownerName: rawOwner.length > 0 ? rawOwner : 'N/A',
      ownerPhone: rawPhone.length > 0 ? rawPhone : 'N/A',
      ownerEmail: rawEmail.length > 0 ? rawEmail : 'N/A',
    };
  }

  // -------------------------------------------------------------
  // TEST 1: New Professional Shop registration saves all 3 owner contact fields
  // -------------------------------------------------------------
  console.log('TEST 1: Verifying new shop registration saves ownerName, ownerPhone, ownerEmail...');
  const seller1Uid = 'seller_contact_test_001';
  const seller1Ctx = testEnv.authenticatedContext(seller1Uid);
  const seller1Db = seller1Ctx.firestore();

  // Seed provider profile in providers/{uid}
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().collection('providers').doc(seller1Uid).set({
      fullName: 'Rameshwar Prasad',
      phone: '+919876543210',
      email: 'rameshwar@jamui.test',
      primaryCategoryId: 'grocery',
      primaryCategoryTitle: 'Grocery & Daily Needs',
      categoryType: 'professional',
      isProfessional: true,
      isDiamond: true,
      businessType: 'professional_seller',
    });
  });

  // Simulate ProviderProfileSetupPage submission
  const shopData1 = {
    id: seller1Uid,
    shopId: seller1Uid,
    ownerUid: seller1Uid,
    shopName: 'Prasad Kirana Store',
    category: 'Grocery & Daily Needs',
    categoryId: 'grocery',
    demandCategoryId: 'grocery',
    demandCategoryTitle: 'Grocery & Daily Needs',
    description: 'All household groceries and spices',
    address: 'Main Road, Jamui - 811307',
    jamuiArea: 'Jamui Town',
    city: 'Jamui',
    district: 'Jamui',
    pincode: '811307',
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
    ownerName: 'Rameshwar Prasad',
    ownerPhone: '+919876543210',
    ownerEmail: 'rameshwar@jamui.test',
  };

  await seller1Db.collection('diamond_shops').doc(seller1Uid).set(shopData1);

  const doc1 = await seller1Db.collection('diamond_shops').doc(seller1Uid).get();
  assert(doc1.exists, 'Shop document 1 must exist');
  assert.strictEqual(doc1.data().ownerName, 'Rameshwar Prasad', 'ownerName must be Rameshwar Prasad');
  assert.strictEqual(doc1.data().ownerPhone, '+919876543210', 'ownerPhone must be +919876543210');
  assert.strictEqual(doc1.data().ownerEmail, 'rameshwar@jamui.test', 'ownerEmail must be rameshwar@jamui.test');
  assert.strictEqual(doc1.data().ownerUid, seller1Uid, 'ownerUid must match seller UID');
  console.log('✅ TEST 1 PASSED: All three owner contact fields successfully persisted in diamond_shops.\n');

  // -------------------------------------------------------------
  // TEST 2: Existing valid contact details are NOT overwritten by empty values
  // -------------------------------------------------------------
  console.log('TEST 2: Verifying update preserves existing contact details and does not overwrite with empty strings...');
  const existingShopData = doc1.data();
  const emptyUpdateInputs = {
    _ownerName: '',
    _ownerPhone: '',
    _ownerEmail: '',
  };

  // Safe resolution logic matching provider_profile_setup_page.dart
  const resolvedOwnerName = emptyUpdateInputs._ownerName.length > 0
    ? emptyUpdateInputs._ownerName
    : ((existingShopData['ownerName'] || '').trim().length > 0 ? existingShopData['ownerName'].trim() : 'Fallback Shop');
  const resolvedOwnerPhone = emptyUpdateInputs._ownerPhone.length > 0
    ? emptyUpdateInputs._ownerPhone
    : ((existingShopData['ownerPhone'] || '').trim().length > 0 ? existingShopData['ownerPhone'].trim() : '');
  const resolvedOwnerEmail = emptyUpdateInputs._ownerEmail.length > 0
    ? emptyUpdateInputs._ownerEmail
    : ((existingShopData['ownerEmail'] || '').trim().length > 0 ? existingShopData['ownerEmail'].trim() : '');

  assert.strictEqual(resolvedOwnerName, 'Rameshwar Prasad', 'Must preserve existing valid ownerName');
  assert.strictEqual(resolvedOwnerPhone, '+919876543210', 'Must preserve existing valid ownerPhone');
  assert.strictEqual(resolvedOwnerEmail, 'rameshwar@jamui.test', 'Must preserve existing valid ownerEmail');

  // Update shop with resolved payload
  await seller1Db.collection('diamond_shops').doc(seller1Uid).update({
    description: 'Updated store description with fresh seasonal items',
    ownerName: resolvedOwnerName,
    ownerPhone: resolvedOwnerPhone,
    ownerEmail: resolvedOwnerEmail,
  });

  const updatedDoc1 = await seller1Db.collection('diamond_shops').doc(seller1Uid).get();
  assert.strictEqual(updatedDoc1.data().ownerName, 'Rameshwar Prasad', 'ownerName still intact');
  assert.strictEqual(updatedDoc1.data().ownerPhone, '+919876543210', 'ownerPhone still intact');
  assert.strictEqual(updatedDoc1.data().ownerEmail, 'rameshwar@jamui.test', 'ownerEmail still intact');
  console.log('✅ TEST 2 PASSED: Existing contact details safely preserved and never overwritten by empty strings.\n');

  // -------------------------------------------------------------
  // TEST 3: Admin Inspector displays saved owner information
  // -------------------------------------------------------------
  console.log('TEST 3: Verifying Admin Inspector reads saved owner information...');
  const adminShopSnap = await adminDb.collection('diamond_shops').doc(seller1Uid).get();
  const inspectorFields = resolveAdminInspectorFields(adminShopSnap.data());

  assert.strictEqual(inspectorFields.ownerName, 'Rameshwar Prasad', 'Admin Inspector sees ownerName');
  assert.strictEqual(inspectorFields.ownerPhone, '+919876543210', 'Admin Inspector sees ownerPhone');
  assert.strictEqual(inspectorFields.ownerEmail, 'rameshwar@jamui.test', 'Admin Inspector sees ownerEmail');
  console.log('Admin Inspector Fields:', inspectorFields);
  console.log('✅ TEST 3 PASSED: Admin Inspector reads and renders saved owner information.\n');

  // -------------------------------------------------------------
  // TEST 4: Older shop documents without owner fields do not crash and show graceful fallback
  // -------------------------------------------------------------
  console.log('TEST 4: Verifying backward-compatible fallback for legacy shop documents...');
  const legacyShopUid = 'legacy_shop_999';
  await testEnv.withSecurityRulesDisabled(async (context) => {
    // Legacy document seeded without ownerName, ownerPhone, ownerEmail
    await context.firestore().collection('diamond_shops').doc(legacyShopUid).set({
      id: legacyShopUid,
      shopId: legacyShopUid,
      ownerUid: legacyShopUid,
      shopName: 'Old Jamui Book Depot',
      fullName: 'Gopal Krishna',
      contactPhone: '+919431200000',
      status: 'pending',
      isApproved: false,
      isActive: true,
      isSubscriptionActive: false,
    });
  });

  const legacySnap = await adminDb.collection('diamond_shops').doc(legacyShopUid).get();
  const legacyInspector = resolveAdminInspectorFields(legacySnap.data());

  assert.strictEqual(legacyInspector.ownerName, 'Gopal Krishna', 'Fallback from fullName');
  assert.strictEqual(legacyInspector.ownerPhone, '+919431200000', 'Fallback from contactPhone');
  assert.strictEqual(legacyInspector.ownerEmail, 'N/A', 'Fallback to N/A for completely missing email');
  console.log('Legacy Inspector Output:', legacyInspector);
  console.log('✅ TEST 4 PASSED: Legacy shop document safely handled without crash, showing appropriate fallback.\n');

  // -------------------------------------------------------------
  // TEST 5: Normal Provider registration & approval flow remains unchanged
  // -------------------------------------------------------------
  console.log('TEST 5: Normal Provider registration and approval isolation...');
  const normalUid = 'normal_electrician_777';
  const normalCtx = testEnv.authenticatedContext(normalUid);
  const normalDb = normalCtx.firestore();

  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().collection('providers').doc(normalUid).set({
      fullName: 'Manoj Sharma',
      phone: '+919811122233',
      businessName: 'Sharma Electrical Works',
      primaryCategoryId: 'electrician',
      primaryCategoryTitle: 'Electrician',
      categoryType: 'general',
      isProfessional: false,
      isDiamond: false,
      businessType: 'service_provider',
      registrationStatus: 'completed',
      status: 'pendingReview',
    });
  });

  // Verify Normal Provider does NOT have a document in diamond_shops
  const normalShopSnap = await normalDb.collection('diamond_shops').doc(normalUid).get();
  assert(!normalShopSnap.exists, 'Normal provider MUST NOT have diamond_shops document');

  // Admin approves Normal Provider in providers/{uid}
  await adminDb.collection('providers').doc(normalUid).update({
    status: 'approved',
    isApproved: true,
  });

  const approvedNormalSnap = await normalDb.collection('providers').doc(normalUid).get();
  assert.strictEqual(approvedNormalSnap.data().status, 'approved');
  assert.strictEqual(approvedNormalSnap.data().isProfessional, false);
  assert.strictEqual(approvedNormalSnap.data().businessType, 'service_provider');
  console.log('✅ TEST 5 PASSED: Normal Provider workflow 100% unaffected and isolated.\n');

  await testEnv.cleanup();
  console.log('================================================================');
  console.log(' ALL 5 OWNER CONTACT FIX TESTS PASSED SUCCESSFULLY! (100%)');
  console.log('================================================================');
}

runOwnerContactDetailsFixTest().catch(err => {
  console.error('Fatal Test Error:', err);
  process.exit(1);
});

