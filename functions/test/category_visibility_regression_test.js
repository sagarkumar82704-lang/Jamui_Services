const { initializeTestEnvironment } = require('@firebase/rules-unit-testing');
const fs = require('fs');
const path = require('path');
const assert = require('assert');

async function runCategoryVisibilityRegressionTest() {
  console.log('================================================================');
  console.log(' JAMUI SERVICES — CATEGORY VISIBILITY & REGISTRATION TEST');
  console.log(' Target: Provider App Category Selection & Shop Registration');
  console.log('================================================================\n');

  const rules = fs.readFileSync(path.resolve(__dirname, '../../backend/firebase/firestore.rules'), 'utf8');
  const testEnv = await initializeTestEnvironment({
    projectId: 'demo-jamui-category-vis',
    firestore: {
      rules,
      host: '127.0.0.1',
      port: 8080,
    },
  });

  const providerUid = 'test_provider_123';
  const providerCtx = testEnv.authenticatedContext(providerUid);
  const providerDb = providerCtx.firestore();

  // Seed Categories collection (Normal Provider categories)
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const adminDb = context.firestore();
    // 1. Normal categories
    await adminDb.collection('categories').doc('electrician').set({
      name: 'Electrician',
      titleEnglish: 'Electrician',
      titleHindi: 'इलेक्ट्रीशियन',
      slug: 'electrician',
      priorityOrder: 1,
      isActive: true,
      isDeleted: false,
      status: 'active',
      categoryType: 'general',
      createdAt: new Date().toISOString(),
    });
    await adminDb.collection('categories').doc('plumber').set({
      name: 'Plumber',
      titleEnglish: 'Plumber',
      titleHindi: 'प्लम्बर',
      slug: 'plumber',
      priorityOrder: 2,
      isActive: true,
      isDeleted: false,
      status: 'active',
      categoryType: 'general',
      createdAt: new Date().toISOString(),
    });

    // 2. Admin creates diamond_categories (Professional Marketplace categories)
    await adminDb.collection('diamond_categories').doc('grocery').set({
      titleEnglish: 'Grocery & Daily Needs',
      titleHindi: 'किराना एवं दैनिक वस्तुएं',
      slug: 'grocery',
      priorityOrder: 1,
      isActive: true,
      createdAt: new Date(),
    });

    await adminDb.collection('diamond_categories').doc('stationery').set({
      titleEnglish: 'Books & Stationery',
      titleHindi: 'किताबें और स्टेशनरी',
      slug: 'stationery',
      priorityOrder: 2,
      isActive: true,
      createdAt: new Date(),
    });

    // 3. Admin creates an INACTIVE diamond category
    await adminDb.collection('diamond_categories').doc('seasonal_fireworks').set({
      titleEnglish: 'Seasonal Fireworks',
      titleHindi: 'पटाखे और आतिशबाजी',
      slug: 'seasonal_fireworks',
      priorityOrder: 99,
      isActive: false,
      createdAt: new Date(),
    });
  });

  // -------------------------------------------------------------
  // TEST 1: Unconstrained query fails with permission-denied
  // -------------------------------------------------------------
  console.log('TEST 1: Verifying that unconstrained query to diamond_categories fails for provider...');
  try {
    await providerDb.collection('diamond_categories').get();
    assert.fail('Unconstrained query should have been rejected by Security Rules');
  } catch (err) {
    assert.strictEqual(err.code, 'permission-denied', 'Must fail with permission-denied');
    console.log('✅ TEST 1 PASSED: Unconstrained query correctly denied by Firestore rules.\n');
  }

  // -------------------------------------------------------------
  // TEST 2: Active-constrained query succeeds and returns active categories
  // -------------------------------------------------------------
  console.log('TEST 2: Verifying query with where(isActive == true) succeeds and returns active categories...');
  const activeSnap = await providerDb.collection('diamond_categories')
    .where('isActive', '==', true)
    .get();

  const activeCategoryIds = activeSnap.docs.map(d => d.id);
  console.log('Retrieved category IDs:', activeCategoryIds);
  assert(activeCategoryIds.includes('grocery'), 'Must contain active grocery category');
  assert(activeCategoryIds.includes('stationery'), 'Must contain active stationery category');
  assert(!activeCategoryIds.includes('seasonal_fireworks'), 'Must NOT contain inactive category');
  console.log('✅ TEST 2 PASSED: Active categories retrieved, inactive categories excluded.\n');

  // -------------------------------------------------------------
  // TEST 3: Admin dynamic activation & deactivation lifecycle
  // -------------------------------------------------------------
  console.log('TEST 3: Admin dynamic activation/deactivation lifecycle...');
  // A. Deactivate grocery
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().collection('diamond_categories').doc('grocery').update({
      isActive: false,
    });
  });

  let snapAfterDeactivate = await providerDb.collection('diamond_categories')
    .where('isActive', '==', true)
    .get();
  let idsAfterDeactivate = snapAfterDeactivate.docs.map(d => d.id);
  assert(!idsAfterDeactivate.includes('grocery'), 'Deactivated grocery category must not appear');
  console.log('Sub-test 3A: Deactivated category immediately hidden.');

  // B. Activate seasonal_fireworks
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().collection('diamond_categories').doc('seasonal_fireworks').update({
      isActive: true,
    });
  });

  let snapAfterActivate = await providerDb.collection('diamond_categories')
    .where('isActive', '==', true)
    .get();
  let idsAfterActivate = snapAfterActivate.docs.map(d => d.id);
  assert(idsAfterActivate.includes('seasonal_fireworks'), 'Activated seasonal fireworks must appear');
  console.log('Sub-test 3B: Activated category immediately appears.');

  // C. Re-activate grocery
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().collection('diamond_categories').doc('grocery').update({
      isActive: true,
    });
  });
  console.log('✅ TEST 3 PASSED: Dynamic Admin activation and deactivation works cleanly.\n');

  // -------------------------------------------------------------
  // TEST 4: Normal categories query continues working untouched
  // -------------------------------------------------------------
  console.log('TEST 4: Normal categories query from categories collection...');
  const normalSnap = await providerDb.collection('categories').get();
  const normalIds = normalSnap.docs.map(d => d.id);
  assert(normalIds.includes('electrician'), 'Normal electrician category must be accessible');
  assert(normalIds.includes('plumber'), 'Normal plumber category must be accessible');
  console.log('✅ TEST 4 PASSED: Normal categories collection untouched and functional.\n');

  // -------------------------------------------------------------
  // TEST 5: Provider selects Professional Category and saves draft
  // -------------------------------------------------------------
  console.log('TEST 5: Provider selects Professional category and saves draft...');
  const proCategory = activeSnap.docs.find(d => d.id === 'grocery').data();
  const proTitle = proCategory.titleEnglish;

  await providerDb.collection('providers').doc(providerUid).set({
    primaryCategoryId: 'grocery',
    primaryCategoryTitle: proTitle,
    selectedCategoryId: 'grocery',
    selectedCategoryIds: ['grocery'],
    categoryType: 'professional',
    isProfessional: true,
    isDiamond: true,
    businessType: 'professional_seller',
    registrationStatus: 'draft',
    currentStep: 2,
    completedSteps: [0, 1],
  });

  const providerDoc = await providerDb.collection('providers').doc(providerUid).get();
  assert.strictEqual(providerDoc.data().categoryType, 'professional');
  assert.strictEqual(providerDoc.data().isProfessional, true);
  assert.strictEqual(providerDoc.data().isDiamond, true);
  assert.strictEqual(providerDoc.data().businessType, 'professional_seller');
  console.log('✅ TEST 5 PASSED: Professional category selection draft saved with correct role flags.\n');

  // -------------------------------------------------------------
  // TEST 6: Provider completes setup -> creates diamond_shops document
  // -------------------------------------------------------------
  console.log('TEST 6: Provider completes setup and creates diamond_shops document...');
  await providerDb.collection('diamond_shops').doc(providerUid).set({
    id: providerUid,
    shopId: providerUid,
    ownerUid: providerUid,
    shopName: 'Maa Tara Kirana Store',
    category: proTitle,
    categoryId: 'grocery',
    demandCategoryId: 'grocery',
    demandCategoryTitle: proTitle,
    description: 'Fresh groceries in Jamui',
    address: 'Station Road, Jamui - 811307',
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

  const shopDoc = await providerDb.collection('diamond_shops').doc(providerUid).get();
  assert(shopDoc.exists, 'diamond_shops document must exist');
  assert.strictEqual(shopDoc.data().ownerUid, providerUid);
  assert.strictEqual(shopDoc.data().demandCategoryId, 'grocery');
  assert.strictEqual(shopDoc.data().status, 'pending');
  console.log('✅ TEST 6 PASSED: Professional Shop registration document created successfully.\n');

  // -------------------------------------------------------------
  // TEST 7: Normal Provider does NOT create diamond_shops document
  // -------------------------------------------------------------
  console.log('TEST 7: Normal Provider selects Standard category and does NOT create shop document...');
  const normalUid = 'test_normal_provider_456';
  const normalCtx = testEnv.authenticatedContext(normalUid);
  const normalDb = normalCtx.firestore();

  await normalDb.collection('providers').doc(normalUid).set({
    businessName: 'Sharma Electricals',
    primaryCategoryId: 'electrician',
    primaryCategoryTitle: 'Electrician',
    categoryType: 'general',
    isProfessional: false,
    isDiamond: false,
    businessType: 'service_provider',
    registrationStatus: 'completed',
    status: 'pendingReview',
  });

  const normalProviderDoc = await normalDb.collection('providers').doc(normalUid).get();
  assert.strictEqual(normalProviderDoc.data().categoryType, 'general');
  assert.strictEqual(normalProviderDoc.data().isProfessional, false);
  assert.strictEqual(normalProviderDoc.data().businessType, 'service_provider');

  // Verify diamond_shops document does NOT exist for normal provider
  const normalShopDoc = await normalDb.collection('diamond_shops').doc(normalUid).get();
  assert(!normalShopDoc.exists, 'diamond_shops document MUST NOT exist for normal provider');
  console.log('✅ TEST 7 PASSED: Normal provider registration leaves diamond_shops completely untouched.\n');

  await testEnv.cleanup();
  console.log('================================================================');
  console.log(' ALL 7 REGRESSION & VISIBILITY TESTS PASSED SUCCESSFULLY! (100%)');
  console.log('================================================================');
}

runCategoryVisibilityRegressionTest().catch(err => {
  console.error('Fatal Test Error:', err);
  process.exit(1);
});

