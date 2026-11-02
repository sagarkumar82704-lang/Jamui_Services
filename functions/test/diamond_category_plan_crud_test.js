/**
 * JAMUI SERVICES — PROFESSIONAL MARKETPLACE CATEGORY & SUBSCRIPTION PLAN CRUD TEST
 * (Legacy physical schema: diamond_categories, diamond_subscription_plans)
 * Priority 8: Verification of end-to-end Category & Plan lifecycle against Firestore Emulator
 */

const path = require('path');
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.GCLOUD_PROJECT = 'demo-jamui-services-emulator';

const admin = require('firebase-admin');
if (admin.apps.length === 0) {
  admin.initializeApp({ projectId: 'demo-jamui-services-emulator' });
}
const db = admin.firestore();

let passed = 0;
let total = 0;

function assert(condition, message) {
  total++;
  if (condition) {
    passed++;
    console.log(`  ✅ [PASS] ${message}`);
  } else {
    console.error(`  ❌ [FAIL] ${message}`);
    process.exitCode = 1;
  }
}

async function runCategoryAndPlanLifecycleTest() {
  console.log('================================================================');
  console.log(' JAMUI SERVICES — CATEGORY & PLAN END-TO-END CRUD TEST');
  console.log('================================================================\n');

  try {
    // -------------------------------------------------------------
    // PART 1: DIAMOND CATEGORIES LIFECYCLE
    // -------------------------------------------------------------
    console.log('--- Testing Diamond Categories CRUD Lifecycle ---');

    const catSlug = 'test_bakery_sweets';
    const catRef = db.collection('diamond_categories').doc(catSlug);

    // 1. Create Category
    await catRef.set({
      titleEnglish: 'Bakery & Sweets',
      titleHindi: 'बेकरी और मिठाई',
      slug: catSlug,
      iconUrl: 'bakery_icon',
      priorityOrder: 5,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const createdSnap = await catRef.get();
    assert(createdSnap.exists, 'Category document was persisted in diamond_categories');
    const createdData = createdSnap.data();
    assert(createdData.titleEnglish === 'Bakery & Sweets', 'Category titleEnglish matches');
    assert(createdData.titleHindi === 'बेकरी और मिठाई', 'Category titleHindi matches');
    assert(createdData.slug === catSlug, 'Category slug matches document ID');
    assert(createdData.priorityOrder === 5, 'Category priorityOrder matches');
    assert(createdData.isActive === true, 'Category isActive is true');

    // 2. Query as Customer (.where('isActive', '==', true))
    const customerQuerySnap = await db.collection('diamond_categories')
      .where('isActive', '==', true)
      .orderBy('priorityOrder')
      .get();
    const foundInQuery = customerQuerySnap.docs.some(d => d.id === catSlug);
    assert(foundInQuery, 'Customer active categories query successfully retrieves active category');

    // 3. Update Category
    await catRef.update({
      titleEnglish: 'Bakery, Sweets & Snacks',
      priorityOrder: 2,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    const updatedSnap = await catRef.get();
    assert(updatedSnap.data().titleEnglish === 'Bakery, Sweets & Snacks', 'Category title updated');
    assert(updatedSnap.data().priorityOrder === 2, 'Category priorityOrder updated');

    // 4. Toggle Category Inactive
    await catRef.update({
      isActive: false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    const inactiveQuerySnap = await db.collection('diamond_categories')
      .where('isActive', '==', true)
      .orderBy('priorityOrder')
      .get();
    const foundWhenInactive = inactiveQuerySnap.docs.some(d => d.id === catSlug);
    assert(!foundWhenInactive, 'Customer active categories query excludes deactivated category');

    // -------------------------------------------------------------
    // PART 2: DIAMOND SUBSCRIPTION PLANS LIFECYCLE
    // -------------------------------------------------------------
    console.log('\n--- Testing Diamond Subscription Plans CRUD Lifecycle ---');

    // 1. Create Subscription Plan
    const planDocRef = await db.collection('diamond_subscription_plans').add({
      name: 'Platinum Growth Plan',
      price: 499.0,
      durationDays: 30,
      maxProducts: 250,
      maxImagesPerMonth: 500,
      storageMb: 1024,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    const planId = planDocRef.id;

    const planCreatedSnap = await planDocRef.get();
    assert(planCreatedSnap.exists, 'Plan document was persisted with auto-generated ID');
    const planData = planCreatedSnap.data();
    assert(planData.name === 'Platinum Growth Plan', 'Plan name matches');
    assert(planData.price === 499.0, 'Plan price matches ₹499.0');
    assert(planData.durationDays === 30, 'Plan durationDays is 30');
    assert(planData.maxProducts === 250, 'Plan maxProducts is 250');
    assert(planData.maxImagesPerMonth === 500, 'Plan maxImagesPerMonth is 500');
    assert(planData.storageMb === 1024, 'Plan storageMb is 1024 MB');
    assert(planData.isActive === true, 'Plan isActive is true');

    // 2. Query as Provider (.where('isActive', '==', true).orderBy('price'))
    const providerPlansSnap = await db.collection('diamond_subscription_plans')
      .where('isActive', '==', true)
      .orderBy('price')
      .get();
    const foundPlanInQuery = providerPlansSnap.docs.some(d => d.id === planId);
    assert(foundPlanInQuery, 'Provider active plans query successfully retrieves published plan');

    // 3. Update Subscription Plan
    await planDocRef.update({
      name: 'Platinum Pro Elite',
      price: 599.0,
      durationDays: 90,
      maxProducts: 350,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    const updatedPlanSnap = await planDocRef.get();
    assert(updatedPlanSnap.data().name === 'Platinum Pro Elite', 'Plan name updated to Platinum Pro Elite');
    assert(updatedPlanSnap.data().price === 599.0, 'Plan price updated to ₹599.0');
    assert(updatedPlanSnap.data().durationDays === 90, 'Plan durationDays updated to 90');
    assert(updatedPlanSnap.data().maxProducts === 350, 'Plan maxProducts updated to 350');

    // 4. Test Legacy Plan Compatibility (without durationDays)
    const legacyPlanRef = await db.collection('diamond_subscription_plans').add({
      name: 'Legacy Pro Plan',
      price: 199.0,
      maxProducts: 50,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    const legacySnap = await legacyPlanRef.get();
    assert(legacySnap.exists, 'Legacy plan document exists');
    assert(legacySnap.data().durationDays === undefined, 'Legacy plan handles missing durationDays gracefully without crash');

    // 4. Toggle Plan Inactive
    await planDocRef.update({
      isActive: false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    const inactivePlansSnap = await db.collection('diamond_subscription_plans')
      .where('isActive', '==', true)
      .orderBy('price')
      .get();
    const foundPlanWhenInactive = inactivePlansSnap.docs.some(d => d.id === planId);
    assert(!foundPlanWhenInactive, 'Provider active plans query excludes deactivated plan');

    console.log('\n================================================================');
    console.log(` RESULTS: ${passed}/${total} CRUD & LIFECYCLE ASSERTIONS PASSED`);
    console.log('================================================================\n');

  } catch (err) {
    console.error('Test execution error:', err);
    process.exitCode = 1;
  }
}

if (require.main === module) {
  runCategoryAndPlanLifecycleTest();
}

module.exports = { runCategoryAndPlanLifecycleTest };

