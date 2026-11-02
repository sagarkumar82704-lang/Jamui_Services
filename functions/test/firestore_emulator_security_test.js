/**
 * JAMUI SERVICES — FIRESTORE EMULATOR SECURITY RULES TEST SUITE
 * Uses @firebase/rules-unit-testing against actual backend/firebase/firestore.rules
 * 
 * Target Scenarios:
 * 1. Vendor A cannot read Vendor B private data.
 * 2. Vendor A cannot edit Vendor B products.
 * 3. Customer cannot read another customer's order.
 * 4. Vendor cannot self-approve.
 * 5. Unapproved shop cannot be publicly listed.
 * 6. Suspended shop and its products cannot be read publicly.
 * 7. Unauthorized user cannot execute Admin operations.
 * 8. Customer cannot directly create or modify protected orders.
 * 9. Only authorized Admin can approve or suspend shops.
 * 10. Subscription expired shop cannot be public.
 */

const fs = require('fs');
const path = require('path');

// Ensure module resolution points to functions/node_modules
const functionsNodeModules = path.resolve(__dirname, '../node_modules');
if (!module.paths.includes(functionsNodeModules)) {
  module.paths.unshift(functionsNodeModules);
}

let testEnv;

async function setupTestEnvironment() {
  const { initializeTestEnvironment, assertFails, assertSucceeds } = require(path.resolve(functionsNodeModules, '@firebase/rules-unit-testing'));
  
  const rulesPath = path.resolve(__dirname, '../../backend/firebase/firestore.rules');
  const rulesContent = fs.readFileSync(rulesPath, 'utf8');

  testEnv = await initializeTestEnvironment({
    projectId: 'demo-jamui-services-emulator',
    firestore: {
      rules: rulesContent,
      host: '127.0.0.1',
      port: 8080
    }
  });

  return { testEnv, assertFails, assertSucceeds };
}

async function runEmulatorTestSuite() {
  console.log('================================================================');
  console.log(' JAMUI SERVICES — REAL FIRESTORE EMULATOR SECURITY RULES SUITE');
  console.log(' Executing against backend/firebase/firestore.rules');
  console.log('================================================================\n');

  try {
    const { testEnv, assertFails, assertSucceeds } = await setupTestEnvironment();

    // 1. Seed Initial Documents via Admin Context (bypasses rules)
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();

      // Seed Vendor A (Approved & Active)
      await db.collection('diamond_shops').doc('vendor_a_uid').set({
        id: 'vendor_a_uid',
        ownerUid: 'vendor_a_uid',
        shopName: 'Jewellery A',
        isApproved: true,
        status: 'approved',
        isActive: true,
        isSubscriptionActive: true,
        isDeleted: false,
        totalRevenue: 50000,
        ownerPhone: '+919876543210'
      });

      // Seed Vendor B (Pending / Unapproved)
      await db.collection('diamond_shops').doc('vendor_b_uid').set({
        id: 'vendor_b_uid',
        ownerUid: 'vendor_b_uid',
        shopName: 'Diamonds B',
        isApproved: false,
        status: 'pending',
        isActive: true,
        isSubscriptionActive: false,
        isDeleted: false,
        totalRevenue: 0,
        ownerPhone: '+919123456789'
      });

      // Seed Vendor B Product
      await db.collection('diamond_shops').doc('vendor_b_uid').collection('products').doc('prod_b_1').set({
        id: 'prod_b_1',
        shopId: 'vendor_b_uid',
        name: 'Diamond Ring',
        sellingPrice: 25000,
        isAvailable: true,
        isDeleted: false
      });

      // Seed Vendor C (Suspended)
      await db.collection('diamond_shops').doc('vendor_c_uid').set({
        id: 'vendor_c_uid',
        ownerUid: 'vendor_c_uid',
        shopName: 'Suspended Jewels',
        isApproved: true,
        status: 'suspended',
        isActive: false,
        isSubscriptionActive: true,
        isDeleted: false
      });

      await db.collection('diamond_shops').doc('vendor_c_uid').collection('products').doc('prod_c_1').set({
        id: 'prod_c_1',
        shopId: 'vendor_c_uid',
        name: 'Suspended Gold Necklace',
        isAvailable: true,
        isDeleted: false
      });

      // Seed Customer B Order
      await db.collection('diamond_orders').doc('order_b_1').set({
        id: 'order_b_1',
        customerId: 'customer_b_uid',
        shopId: 'vendor_a_uid',
        totalAmount: 5000,
        status: 'placed'
      });

      // Seed Admin User
      await db.collection('admin_users').doc('admin_master_uid').set({
        uid: 'admin_master_uid',
        role: 'admin',
        isActive: true,
        status: 'active'
      });

      // Seed Super Admin User
      await db.collection('admin_users').doc('admin_super_uid').set({
        uid: 'admin_super_uid',
        role: 'super_admin',
        isActive: true,
        status: 'active'
      });

      // Seed Inactive Admin User (deactivated)
      await db.collection('admin_users').doc('admin_inactive_uid').set({
        uid: 'admin_inactive_uid',
        role: 'admin',
        isActive: false,
        status: 'inactive'
      });

      // Seed Blocked Admin User
      await db.collection('admin_users').doc('admin_blocked_uid').set({
        uid: 'admin_blocked_uid',
        role: 'admin',
        isActive: true,
        status: 'blocked'
      });

      // Seed Invalid Role Admin User
      await db.collection('admin_users').doc('admin_viewer_uid').set({
        uid: 'admin_viewer_uid',
        role: 'viewer',
        isActive: true,
        status: 'active'
      });
    });

    // Client Contexts
    const vendorAContext = testEnv.authenticatedContext('vendor_a_uid');
    const vendorBContext = testEnv.authenticatedContext('vendor_b_uid');
    const customerAContext = testEnv.authenticatedContext('customer_a_uid');
    const customerBContext = testEnv.authenticatedContext('customer_b_uid');
    const unauthContext = testEnv.unauthenticatedContext();
    const adminContext = testEnv.authenticatedContext('admin_master_uid');
    const superAdminContext = testEnv.authenticatedContext('admin_super_uid');
    const inactiveAdminContext = testEnv.authenticatedContext('admin_inactive_uid');
    const blockedAdminContext = testEnv.authenticatedContext('admin_blocked_uid');
    const viewerAdminContext = testEnv.authenticatedContext('admin_viewer_uid');
    // Attacker presenting admin email in auth token but unlisted UID
    const emailSpoofAttackerContext = testEnv.authenticatedContext('attacker_uid', { email: 'admin@jamuiservice.com' });

    // Scenario 1: Vendor A cannot read Vendor B private data
    await assertFails(vendorAContext.firestore().collection('diamond_shops').doc('vendor_b_uid').get());
    console.log('✅ [Scenario 1 PASS] Vendor A reading Vendor B private unapproved shop is DENIED');

    // Scenario 2: Vendor A cannot edit Vendor B products
    await assertFails(vendorAContext.firestore().collection('diamond_shops').doc('vendor_b_uid').collection('products').doc('prod_b_1').update({
      sellingPrice: 1
    }));
    console.log('✅ [Scenario 2 PASS] Vendor A modifying Vendor B products is DENIED');

    // Scenario 3: Customer cannot read another customer\'s order
    await assertFails(customerAContext.firestore().collection('diamond_orders').doc('order_b_1').get());
    await assertSucceeds(customerBContext.firestore().collection('diamond_orders').doc('order_b_1').get());
    console.log('✅ [Scenario 3 PASS] Customer A reading Customer B order is DENIED; Customer B succeeds');

    // Scenario 4: Vendor cannot self-approve
    await assertFails(vendorBContext.firestore().collection('diamond_shops').doc('vendor_b_uid').update({
      isApproved: true,
      status: 'approved'
    }));
    console.log('✅ [Scenario 4 PASS] Vendor B attempting self-approval is STRICTLY DENIED');

    // Scenario 5: Unapproved shop cannot be publicly listed
    await assertFails(unauthContext.firestore().collection('diamond_shops').doc('vendor_b_uid').get());
    console.log('✅ [Scenario 5 PASS] Unapproved shop read by public is DENIED');

    // Scenario 6: Suspended shop and its products cannot be read publicly
    await assertFails(unauthContext.firestore().collection('diamond_shops').doc('vendor_c_uid').get());
    await assertFails(unauthContext.firestore().collection('diamond_shops').doc('vendor_c_uid').collection('products').doc('prod_c_1').get());
    console.log('✅ [Scenario 6 PASS] Suspended shop and its products read by public is DENIED');

    // Scenario 7: Unauthorized user cannot execute Admin operations
    await assertFails(customerAContext.firestore().collection('admin_users').doc('customer_a_uid').set({ role: 'admin' }));
    console.log('✅ [Scenario 7 PASS] Regular customer escalating to admin_users is DENIED');

    // Scenario 8: Customer cannot directly create or modify protected orders
    await assertFails(customerAContext.firestore().collection('diamond_orders').doc('new_order_direct').set({
      customerId: 'customer_a_uid',
      shopId: 'vendor_a_uid',
      totalAmount: 100,
      status: 'placed'
    }));
    console.log('✅ [Scenario 8 PASS] Direct client write to diamond_orders is DENIED (Zero-Trust CF required)');

    // Scenario 9: Only authorized Admin can approve or suspend shops
    await assertSucceeds(adminContext.firestore().collection('diamond_shops').doc('vendor_b_uid').update({
      isApproved: true,
      status: 'approved'
    }));
    console.log('✅ [Scenario 9 PASS] Authorized Admin approving vendor_b_uid SUCCEEDS');

    // Scenario 10: Subscription expired shop cannot be public
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection('diamond_shops').doc('vendor_a_uid').update({
        isSubscriptionActive: false
      });
    });
    await assertFails(unauthContext.firestore().collection('diamond_shops').doc('vendor_a_uid').get());
    console.log('✅ [Scenario 10 PASS] Unauthenticated read of expired subscription shop is DENIED');

    // Scenario 11: Active Admin can create and update Diamond Categories; regular user cannot
    await assertSucceeds(adminContext.firestore().collection('diamond_categories').doc('bakery_shop').set({
      titleEnglish: 'Bakery & Sweets',
      titleHindi: 'बेकरी और मिठाई',
      slug: 'bakery_shop',
      iconUrl: 'bakery',
      priorityOrder: 1,
      isActive: true
    }));
    await assertFails(customerAContext.firestore().collection('diamond_categories').doc('hack_cat').set({
      titleEnglish: 'Unauthorized Category'
    }));
    console.log('✅ [Scenario 11 PASS] Admin can create Diamond Category; Customer write is DENIED');

    // Scenario 12: Public/Customer can read active category, but NOT inactive category
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection('diamond_categories').doc('hidden_cat').set({
        titleEnglish: 'Hidden Category',
        isActive: false,
        priorityOrder: 99
      });
    });
    await assertSucceeds(unauthContext.firestore().collection('diamond_categories').doc('bakery_shop').get());
    await assertFails(unauthContext.firestore().collection('diamond_categories').doc('hidden_cat').get());
    console.log('✅ [Scenario 12 PASS] Public can read active Diamond Category; reading inactive category is DENIED');

    // Scenario 13: Inactive Admin CANNOT write to diamond_categories or diamond_subscription_plans
    await assertFails(inactiveAdminContext.firestore().collection('diamond_categories').doc('inactive_admin_attempt').set({
      titleEnglish: 'Unauthorized by Inactive Admin'
    }));
    await assertFails(inactiveAdminContext.firestore().collection('diamond_subscription_plans').doc('inactive_admin_plan').set({
      name: 'Hack Plan',
      price: 0
    }));
    console.log('✅ [Scenario 13 PASS] Inactive Admin writing Category or Plan is STRICTLY DENIED (Hardened isAdmin)');

    // Scenario 14: Active Admin can publish Subscription Plans; regular customer cannot
    await assertSucceeds(adminContext.firestore().collection('diamond_subscription_plans').doc('plan_pro_tier').set({
      name: 'Growth Plan',
      price: 499,
      maxProducts: 200,
      maxImagesPerMonth: 500,
      storageMb: 1000,
      isActive: true
    }));
    await assertFails(customerAContext.firestore().collection('diamond_subscription_plans').doc('plan_fake').set({
      name: 'Free Plan',
      price: 0
    }));
    await assertSucceeds(unauthContext.firestore().collection('diamond_subscription_plans').doc('plan_pro_tier').get());
    console.log('✅ [Scenario 14 PASS] Admin can publish Subscription Plan; Customer write is DENIED; Public read SUCCEEDS');

    // Scenario 15: Attacker with admin email in token but unlisted UID is STRICTLY DENIED (Email fallback removed)
    await assertFails(emailSpoofAttackerContext.firestore().collection('diamond_categories').doc('spoofed_cat').set({
      titleEnglish: 'Spoofed Category'
    }));
    await assertFails(emailSpoofAttackerContext.firestore().collection('diamond_shops').doc('vendor_b_uid').update({
      isApproved: true,
      status: 'approved'
    }));
    console.log('✅ [Scenario 15 PASS] Attacker presenting admin email but unlisted UID is STRICTLY DENIED (No Email Fallback)');

    // Scenario 16: Blocked Admin is STRICTLY DENIED all privileged operations
    await assertFails(blockedAdminContext.firestore().collection('diamond_categories').doc('blocked_admin_cat').set({
      titleEnglish: 'Blocked Admin Category'
    }));
    console.log('✅ [Scenario 16 PASS] Blocked Admin (status: "blocked") is STRICTLY DENIED');

    // Scenario 17: Admin with invalid/viewer role is STRICTLY DENIED privileged operations
    await assertFails(viewerAdminContext.firestore().collection('diamond_categories').doc('viewer_admin_cat').set({
      titleEnglish: 'Viewer Admin Category'
    }));
    console.log('✅ [Scenario 17 PASS] Admin with unauthorized role (viewer) is STRICTLY DENIED');

    // Scenario 18: Regular Customer or Vendor CANNOT create or elevate record in admin_users
    await assertFails(customerAContext.firestore().collection('admin_users').doc('customer_a_uid').set({
      uid: 'customer_a_uid',
      role: 'super_admin',
      status: 'active',
      isActive: true
    }));
    await assertFails(vendorAContext.firestore().collection('admin_users').doc('vendor_a_uid').set({
      uid: 'vendor_a_uid',
      role: 'admin',
      status: 'active',
      isActive: true
    }));
    console.log('✅ [Scenario 18 PASS] Regular Customer/Vendor cannot self-elevate to admin_users (Anti-Privilege Escalation)');

    // Scenario 19: Super Admin with valid UID and status: "active" SUCCEEDS
    await assertSucceeds(superAdminContext.firestore().collection('diamond_categories').doc('super_admin_cat').set({
      titleEnglish: 'Super Admin Category',
      titleHindi: 'सुपर एडमिन श्रेणी',
      slug: 'super_admin_cat',
      iconUrl: 'icon',
      priorityOrder: 1,
      isActive: true
    }));
    console.log('✅ [Scenario 19 PASS] Valid Super Admin (role: "super_admin", active) SUCCEEDS');

    // Scenario 20: Reading admin_users by public/customer is DENIED; Valid Admin read SUCCEEDS
    await assertFails(unauthContext.firestore().collection('admin_users').doc('admin_master_uid').get());
    await assertFails(customerAContext.firestore().collection('admin_users').doc('admin_master_uid').get());
    await assertSucceeds(adminContext.firestore().collection('admin_users').doc('admin_master_uid').get());
    console.log('✅ [Scenario 20 PASS] admin_users read protected from unauthenticated & customer; Admin read SUCCEEDS');

    // Scenario 21: Unauthorized update or delete on admin_users is DENIED
    await assertFails(customerAContext.firestore().collection('admin_users').doc('admin_master_uid').update({
      role: 'viewer'
    }));
    await assertFails(customerAContext.firestore().collection('admin_users').doc('admin_master_uid').delete());
    console.log('✅ [Scenario 21 PASS] Unauthorized update or delete of admin_users is STRICTLY DENIED');

    // Scenario 22: Valid Admin can manage admin_users records
    await assertSucceeds(superAdminContext.firestore().collection('admin_users').doc('admin_master_uid').update({
      name: 'Senior Master Admin'
    }));
    console.log('✅ [Scenario 22 PASS] Super Admin managing admin_users record SUCCEEDS');

    // Scenario 23: Vendor A cannot tamper with immutable security fields (ownerUid, isApproved)
    await assertFails(vendorAContext.firestore().collection('diamond_shops').doc('vendor_a_uid').update({
      ownerUid: 'vendor_b_uid'
    }));
    await assertFails(vendorAContext.firestore().collection('diamond_shops').doc('vendor_a_uid').update({
      totalRevenue: 9999999
    }));
    console.log('✅ [Scenario 23 PASS] Vendor A tampering with ownerUid or totalRevenue is STRICTLY DENIED');

    // Scenario 24: Vendor A attempting to delete Vendor B shop or product is DENIED
    await assertFails(vendorAContext.firestore().collection('diamond_shops').doc('vendor_b_uid').delete());
    await assertFails(vendorAContext.firestore().collection('diamond_shops').doc('vendor_b_uid').collection('products').doc('prod_b_1').delete());
    console.log('✅ [Scenario 24 PASS] Cross-vendor shop/product deletion is STRICTLY DENIED');

    console.log('\n================================================================');
    console.log(' ALL 24 FIRESTORE EMULATOR RULES SCENARIOS VERIFIED SUCCESSFULLY');
    console.log('================================================================\n');

  } catch (err) {
    console.error('Emulator Test Error:', err.message);
    process.exitCode = 1;
  } finally {
    if (testEnv) {
      await testEnv.cleanup();
    }
  }
}

if (require.main === module) {
  runEmulatorTestSuite();
}

module.exports = { runEmulatorTestSuite };

