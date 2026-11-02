/**
 * JAMUI SERVICES — DIAMOND MARKETPLACE
 * SEED SCRIPT FOR LOCAL FIREBASE EMULATOR ONLY
 * 
 * STRICT SAFETY RULES:
 * 1. ONLY runs against local emulator (demo-jamui-services).
 * 2. Pre-checks emulator environment variables.
 * 3. Never touches live production Firebase.
 */

const path = require('path');
const admin = require(path.join(__dirname, '../functions/node_modules/firebase-admin'));
const FieldValue = admin.firestore.FieldValue;
const Timestamp = admin.firestore.Timestamp;

// STRICT SAFETY GUARD: Verify Emulator environment
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';

process.env.FIRESTORE_EMULATOR_HOST = firestoreHost;
process.env.FIREBASE_AUTH_EMULATOR_HOST = authHost;

const PROJECT_ID = process.env.GCLOUD_PROJECT || 'demo-jamui-services';

if (!PROJECT_ID.startsWith('demo-')) {
  console.error(`❌ FATAL SAFETY ERROR: Project ID is "${PROJECT_ID}". Seed script is STRICTLY restricted to demo-* emulator projects!`);
  process.exit(1);
}

if (!admin.apps.length) {
  admin.initializeApp({
    projectId: PROJECT_ID,
  });
}

const db = admin.firestore();
const auth = admin.auth();

async function seedEmulator() {
  console.log(`\n======================================================`);
  console.log(`🌱 SEEDING LOCAL FIREBASE EMULATOR (${PROJECT_ID})`);
  console.log(`📡 Firestore: ${firestoreHost} | Auth: ${authHost}`);
  console.log(`======================================================\n`);

  // --- 1. MOCK SUPER ADMIN ---
  const adminUid = 'mock_admin_uid_01';
  const adminEmail = 'admin@jamuiservice.test';
  try {
    await auth.createUser({
      uid: adminUid,
      email: adminEmail,
      password: 'Password123!',
      displayName: 'Super Admin (Local Mock)',
    });
    console.log(`✅ Created Auth User: ${adminEmail} (UID: ${adminUid})`);
  } catch (e) {
    if (e.code === 'auth/uid-already-exists') {
      console.log(`ℹ️ Auth User ${adminEmail} already exists.`);
    } else {
      console.warn(`⚠️ Auth note for ${adminEmail}: ${e.message}`);
    }
  }

  await db.collection('admin_users').doc(adminUid).set({
    email: adminEmail,
    role: 'super_admin',
    isActive: true,
    status: 'active',
    permissions: ['all'],
    name: 'Super Admin (Local Mock)',
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  console.log(`✅ Seeded admin_users/${adminUid}`);

  // --- 2. MOCK SELLER 1 (APPROVED & ACTIVE NORMAL GROCERY PROVIDER) ---
  const seller1Uid = 'mock_seller_uid_01';
  const seller1Email = 'seller1@jamuiservice.test';
  try {
    await auth.createUser({
      uid: seller1Uid,
      email: seller1Email,
      password: 'Password123!',
      displayName: 'Jamui Fresh Grocery Store',
    });
    console.log(`✅ Created Auth User: ${seller1Email} (UID: ${seller1Uid})`);
  } catch (e) {
    if (e.code !== 'auth/uid-already-exists') console.warn(`⚠️ Auth note: ${e.message}`);
  }

  const futureExpiry = new Date();
  futureExpiry.setDate(futureExpiry.getDate() + 90);

  // Dedicated Diamond Shop record for Diamond E-commerce section
  await db.collection('diamond_shops').doc(seller1Uid).set({
    shopId: seller1Uid,
    ownerUid: seller1Uid,
    ownerEmail: seller1Email,
    ownerPhone: '+919876543210',
    shopName: 'Jamui Royal Diamond Jewellers',
    status: 'approved',
    isApproved: true,
    isActive: true,
    isSubscriptionActive: true,
    isDeleted: false,
    paymentVerified: true,
    planId: 'plan_gold_90',
    planName: 'Gold Jeweller Plan',
    subscriptionExpiry: Timestamp.fromDate(futureExpiry),
    address: 'Main Bazaar, Jamui, Bihar 811307',
    phone: '+919876543210',
    gstin: '10ABCDE1234F1Z5',
    hallmarkLicense: 'HM-JAMUI-2026-001',
    rating: 4.9,
    ratingCount: 12,
    totalOrders: 15,
    totalRevenue: 450000,
    isOpen: true,
    deliveryEnabled: true,
    pickupEnabled: true,
    deliveryRadiusKm: 15,
    latitude: 24.92,
    longitude: 86.22,
    deliveryCharge: 0,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  console.log(`✅ Seeded diamond_shops/${seller1Uid} (Approved & Active in Diamond E-commerce)`);

  // Normal Provider Profile (Grocery Category & Service)
  await db.collection('providers').doc(seller1Uid).set({
    id: seller1Uid,
    email: seller1Email,
    phoneNumber: '+919876543210',
    isMobileVerified: true,
    isEmailVerified: true,
    fullName: 'Jamui Fresh Grocery Store',
    businessName: 'Jamui Fresh Grocery Store',
    businessDescription: 'Fresh Groceries, Staples, and Daily Essentials in Jamui',
    businessType: 'Small Business',
    primaryCategoryId: 'grocery',
    primaryCategoryTitle: 'Grocery',
    selectedCategoryId: 'grocery',
    selectedCategoryIds: ['grocery'],
    subServices: ['Grocery Shop'],
    selectedService: 'Grocery Shop',
    serviceRadiusKm: 15,
    jamuiArea: 'Main Bazaar',
    fullAddress: 'Main Bazaar, Jamui, Bihar 811307',
    latitude: 24.92,
    longitude: 86.22,
    kycStatus: 'approved',
    status: 'approved',
    isApproved: true,
    isActive: true,
    isSubscriptionActive: true,
    subscriptionPlan: 'Standard Business Plan',
    paymentVerified: true,
    isActive: true,
    isDeleted: false,
    registrationStatus: 'completed',
    completedSteps: [1, 2, 3, 4, 5],
    currentStep: 5,
    rating: 4.9,
    ratingCount: 12,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  console.log(`✅ Seeded providers/${seller1Uid} (Approved Provider Profile)`);

  // Seed Products for Seller 1
  const products = [
    {
      id: 'prod_solitaire_ring_01',
      data: {
        productId: 'prod_solitaire_ring_01',
        name: '22K Solitaire Diamond Ring',
        category: 'Diamond Rings',
        categoryId: 'cat_diamond_rings',
        price: 45000,
        sellingPrice: 45000,
        stock: 5,
        stockQuantity: 5,
        inStock: true,
        purity: '22K',
        diamondWeight: '0.50 Carat',
        isAvailable: true,
        isDeleted: false,
        shopId: seller1Uid,
        shopName: 'Jamui Royal Diamond Jewellers',
        images: ['https://images.unsplash.com/photo-1605100804763-247f67b3557e?w=400'],
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
    },
    {
      id: 'prod_gold_necklace_02',
      data: {
        productId: 'prod_gold_necklace_02',
        name: '18K Diamond Emerald Pendant Necklace',
        category: 'Diamond Necklaces',
        categoryId: 'cat_diamond_necklaces',
        price: 85000,
        sellingPrice: 85000,
        stock: 3,
        stockQuantity: 3,
        inStock: true,
        purity: '18K',
        diamondWeight: '1.20 Carat',
        isAvailable: true,
        isDeleted: false,
        shopId: seller1Uid,
        shopName: 'Jamui Royal Diamond Jewellers',
        images: ['https://images.unsplash.com/photo-1599643478518-a784e5dc4c8f?w=400'],
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
    },
    {
      id: 'prod_diamond_bangles_03',
      data: {
        productId: 'prod_diamond_bangles_03',
        name: 'Traditional Diamond Bangles (Pair)',
        category: 'Diamond Bangles',
        categoryId: 'cat_diamond_bangles',
        price: 120000,
        sellingPrice: 120000,
        stock: 2,
        stockQuantity: 2,
        inStock: true,
        purity: '22K',
        diamondWeight: '2.00 Carat',
        isAvailable: true,
        isDeleted: false,
        shopId: seller1Uid,
        shopName: 'Jamui Royal Diamond Jewellers',
        images: ['https://images.unsplash.com/photo-1611591475152-473549079f22?w=400'],
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
    },
  ];

  for (const p of products) {
    await db.collection('diamond_shops').doc(seller1Uid).collection('products').doc(p.id).set(p.data);
    console.log(`   💎 Seeded Product: ${p.data.name} (Stock: ${p.data.stock})`);
  }

  // --- 3. MOCK SELLER 2 (PENDING APPROVAL NORMAL VEGETABLE PROVIDER) ---
  const seller2Uid = 'mock_seller_uid_02';
  const seller2Email = 'seller2@jamuiservice.test';
  try {
    await auth.createUser({
      uid: seller2Uid,
      email: seller2Email,
      password: 'Password123!',
      displayName: 'Kisan Fresh Vegetable Shop',
    });
    console.log(`✅ Created Auth User: ${seller2Email} (UID: ${seller2Uid})`);
  } catch (e) {
    if (e.code !== 'auth/uid-already-exists') console.warn(`⚠️ Auth note: ${e.message}`);
  }

  // Dedicated Diamond Shop record for Diamond E-commerce section (pending)
  await db.collection('diamond_shops').doc(seller2Uid).set({
    shopId: seller2Uid,
    ownerUid: seller2Uid,
    ownerEmail: seller2Email,
    ownerPhone: '+919876543211',
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
    isOpen: false,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  console.log(`✅ Seeded diamond_shops/${seller2Uid} (Pending Approval in Diamond E-commerce)`);

  // Normal Provider Profile (Vegetable Shop Category & Service - Pending Review)
  await db.collection('providers').doc(seller2Uid).set({
    id: seller2Uid,
    email: seller2Email,
    phoneNumber: '+919876543211',
    isMobileVerified: true,
    isEmailVerified: true,
    fullName: 'Kisan Fresh Vegetable Shop',
    businessName: 'Kisan Fresh Vegetable Shop',
    businessDescription: 'Farm Fresh Organic Vegetables and Produce in Jamui',
    businessType: 'Small Business',
    primaryCategoryId: 'vegetable_shop',
    primaryCategoryTitle: 'Vegetable Shop',
    selectedCategoryId: 'vegetable_shop',
    selectedCategoryIds: ['vegetable_shop'],
    subServices: ['Vegetable Shop'],
    selectedService: 'Vegetable Shop',
    serviceRadiusKm: 10,
    jamuiArea: 'Station Road',
    fullAddress: 'Station Road, Jamui, Bihar 811307',
    latitude: 24.91,
    longitude: 86.21,
    kycStatus: 'pendingReview',
    status: 'pendingReview',
    isApproved: false,
    isSubscriptionActive: false,
    paymentVerified: false,
    isActive: true,
    isDeleted: false,
    registrationStatus: 'completed',
    completedSteps: [1, 2, 3, 4, 5],
    currentStep: 5,
    rating: 0.0,
    ratingCount: 0,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  console.log(`✅ Seeded providers/${seller2Uid} (Pending Review Provider Profile)`);

  // --- 4. MOCK CUSTOMER ---
  const custUid = 'mock_cust_uid_01';
  const custEmail = 'customer@jamuiservice.test';
  try {
    await auth.createUser({
      uid: custUid,
      email: custEmail,
      password: 'Password123!',
      displayName: 'Ramesh Kumar (Test Customer)',
    });
    console.log(`✅ Created Auth User: ${custEmail} (UID: ${custUid})`);
  } catch (e) {
    if (e.code !== 'auth/uid-already-exists') console.warn(`⚠️ Auth note: ${e.message}`);
  }

  const custData = {
    uid: custUid,
    name: 'Ramesh Kumar',
    email: custEmail,
    phone: '+919988776655',
    address: 'Ward No. 4, Near Circuit House, Jamui, Bihar',
    city: 'Jamui',
    pincode: '811307',
    role: 'customer',
    createdAt: FieldValue.serverTimestamp(),
  };
  await db.collection('customers').doc(custUid).set(custData);
  await db.collection('users').doc(custUid).set(custData);
  console.log(`✅ Seeded customers/${custUid} and users/${custUid}`);

  // --- 5. DIAMOND CATEGORIES (SEPARATE E-COMMERCE SECTION ONLY) ---
  const diamondCategories = [
    { id: 'cat_grocery', name: 'Grocery Shop', description: 'Grocery and daily store products', isActive: true, displayOrder: 1 },
    { id: 'cat_vegetable', name: 'Vegetable Shop', description: 'Fresh vegetables and farm produce', isActive: true, displayOrder: 2 },
    { id: 'cat_fruits', name: 'Fruits Shop', description: 'Fresh seasonal fruits', isActive: true, displayOrder: 3 },
    { id: 'cat_diamond_rings', name: 'Diamond Rings', description: 'Diamond rings and fine jewellery', isActive: true, displayOrder: 4 },
    { id: 'cat_diamond_necklaces', name: 'Diamond Necklaces', description: 'Diamond necklaces and pendants', isActive: true, displayOrder: 5 },
    { id: 'cat_diamond_bangles', name: 'Diamond Bangles', description: 'Diamond bangles and bracelets', isActive: true, displayOrder: 6 },
  ];
  for (const c of diamondCategories) {
    await db.collection('diamond_categories').doc(c.id).set({
      ...c,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    console.log(`✅ Seeded diamond_categories/${c.id} (${c.name})`);
  }

  // --- 6. DIAMOND SUBSCRIPTION PLANS ---
  const plans = [
    {
      id: 'plan_silver_30',
      name: 'Silver Jeweller Plan',
      price: 999,
      durationDays: 30,
      maxListings: 20,
      commissionPercent: 2.0,
      isActive: true,
      description: 'Ideal for local jewellery stores starting in diamond trade.',
      features: ['Up to 20 jewellery listings', 'Standard customer search', 'Basic WhatsApp support'],
    },
    {
      id: 'plan_gold_90',
      name: 'Gold Jeweller Plan',
      price: 2499,
      durationDays: 90,
      maxListings: 100,
      commissionPercent: 1.5,
      isActive: true,
      description: 'Recommended for established jewellers with hallmark inventory.',
      features: ['Up to 100 jewellery listings', 'Featured on homepage', 'Priority order notifications', 'Verified Diamond Badge'],
    },
  ];
  for (const pl of plans) {
    await db.collection('diamond_subscription_plans').doc(pl.id).set({
      ...pl,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    console.log(`✅ Seeded diamond_subscription_plans/${pl.id}`);
  }

  // Seed emulator health check ping doc
  await db.collection('_emulator_health').doc('ping').set({
    status: 'ok',
    timestamp: FieldValue.serverTimestamp(),
  });
  console.log(`✅ Seeded _emulator_health/ping (Health Check Doc)`);

  console.log(`\n🎉 SEEDING COMPLETED SUCCESSFULLY ON LOCAL EMULATOR!\n`);
}

seedEmulator()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('❌ SEEDING FAILED:', err);
    process.exit(1);
  });
