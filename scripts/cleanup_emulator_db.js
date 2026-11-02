/**
 * JAMUI SERVICES — EMULATOR DATABASE CLEANUP
 * Removes any accidental Diamond entries from Normal Provider collections (categories, premium_categories, providers)
 * while strictly preserving Diamond E-Commerce dedicated collections (diamond_shops, diamond_products, diamond_categories, diamond_subscription_plans).
 */

const path = require('path');
const admin = require(path.join(__dirname, '../functions/node_modules/firebase-admin'));

process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';

const PROJECT_ID = process.env.GCLOUD_PROJECT || 'demo-jamui-services';

if (!PROJECT_ID.startsWith('demo-')) {
  console.error(`❌ FATAL: Restricted to demo-* projects only! Current: ${PROJECT_ID}`);
  process.exit(1);
}

if (!admin.apps.length) {
  admin.initializeApp({ projectId: PROJECT_ID });
}

const db = admin.firestore();

async function cleanup() {
  console.log(`\n🧹 Running Safe Emulator Database Cleanup on ${PROJECT_ID}...`);

  // 1. Clean 'categories' collection: delete any accidental diamond categories
  const catSnap = await db.collection('categories').get();
  for (const doc of catSnap.docs) {
    const data = doc.data();
    const id = doc.id.toLowerCase();
    const titleEng = (data.titleEnglish || '').toLowerCase();
    const titleHin = (data.titleHindi || '').toLowerCase();
    if (id.includes('diamond') || titleEng.includes('diamond') || titleHin.includes('diamond') || data.categoryType === 'diamond' || ['grocery', 'vegetable_shop', 'fruits_shop'].includes(id)) {
      console.log(`🗑️ Removing non-normal / accidental category from Normal 'categories': ${doc.id}`);
      await db.collection('categories').doc(doc.id).delete();
    }
  }

  // 2. Clean 'premium_categories' collection: delete any accidental diamond categories
  const premSnap = await db.collection('premium_categories').get();
  for (const doc of premSnap.docs) {
    const data = doc.data();
    const id = doc.id.toLowerCase();
    const catId = (data.categoryId || '').toLowerCase();
    const title = (data.title || data.customTitle || '').toLowerCase();
    if (id.includes('diamond') || catId.includes('diamond') || title.includes('diamond')) {
      console.log(`🗑️ Removing accidental Diamond category from 'premium_categories': ${doc.id}`);
      await db.collection('premium_categories').doc(doc.id).delete();
    }
  }

  // 3. Update normal provider records in 'providers' collection to ensure they use valid normal categories (e.g. grocery, vegetable_shop)
  const provSnap = await db.collection('providers').get();
  for (const doc of provSnap.docs) {
    const data = doc.data();
    if (data.primaryCategoryId === 'diamond_jewellers' || (data.primaryCategoryId || '').toLowerCase().includes('diamond')) {
      console.log(`🔄 Updating provider ${doc.id} (${data.fullName || data.businessName}) to Normal Category 'grocery'...`);
      await db.collection('providers').doc(doc.id).update({
        primaryCategoryId: 'grocery',
        primaryCategoryTitle: 'Grocery',
        businessType: 'Small Business',
        businessDescription: 'Grocery and Daily Essentials Store in Jamui',
        subServices: ['Grocery Shop'],
        selectedService: 'Grocery Shop',
      });
    }
  }

  console.log(`✅ Safe cleanup complete! Diamond E-Commerce collections remain untouched.\n`);
}

cleanup()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('❌ Cleanup failed:', err);
    process.exit(1);
  });
