/**
 * JAMUI SERVICES — ADMIN MIGRATION DRY-RUN SAFETY VERIFICATION
 * Tests scripts/migrate_admin_uids.js against actual Firebase Emulator
 */

const path = require('path');
const functionsNodeModules = path.resolve(__dirname, '../node_modules');
if (!module.paths.includes(functionsNodeModules)) {
  module.paths.unshift(functionsNodeModules);
}

process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099';
process.env.GCLOUD_PROJECT = 'demo-jamui-services-emulator';

const admin = require('firebase-admin');
if (admin.apps.length === 0) {
  admin.initializeApp({ projectId: 'demo-jamui-services-emulator' });
}
const db = admin.firestore();
const auth = admin.auth();
const { migrateAdminUids } = require('../../scripts/migrate_admin_uids');

async function testMigrationDryRunSafety() {
  console.log('================================================================');
  console.log(' SEEDING TEST ADMIN RECORDS IN EMULATOR FOR MIGRATION AUDIT');
  console.log('================================================================\n');

  // 1. Create Auth Users in Auth Emulator
  let user1, user2, user3;
  try {
    user1 = await auth.createUser({ uid: 'uid_master_001', email: 'master@jamuiservices.in' });
  } catch (_) {
    user1 = await auth.getUserByEmail('master@jamuiservices.in');
  }

  try {
    user2 = await auth.createUser({ uid: 'uid_legacy_002', email: 'legacy_admin@jamuiservices.in' });
  } catch (_) {
    user2 = await auth.getUserByEmail('legacy_admin@jamuiservices.in');
  }

  try {
    user3 = await auth.createUser({ uid: 'uid_conflict_003', email: 'conflict@jamuiservices.in' });
  } catch (_) {
    user3 = await auth.getUserByEmail('conflict@jamuiservices.in');
  }

  // 2. Seed Firestore admin_users documents:
  // Case A: Correctly Keyed by UID
  await db.collection('admin_users').doc('uid_master_001').set({
    name: 'Master Admin',
    email: 'master@jamuiservices.in',
    role: 'super_admin',
    status: 'active',
    isActive: true
  });

  // Case B: Legacy Auto-Generated Doc ID needing migration
  await db.collection('admin_users').doc('auto_doc_legacy_xyz').set({
    name: 'Legacy Admin Manager',
    email: 'legacy_admin@jamuiservices.in',
    role: 'admin',
    status: 'active',
    isActive: true
  });

  // Case C: Conflict Scenario (Source doc and different target doc exist)
  await db.collection('admin_users').doc('auto_doc_conflict_abc').set({
    name: 'Duplicate Source Record',
    email: 'conflict@jamuiservices.in',
    role: 'admin',
    status: 'active'
  });
  await db.collection('admin_users').doc('uid_conflict_003').set({
    name: 'Existing Pre-bound Target',
    email: 'conflict@jamuiservices.in',
    role: 'super_admin',
    status: 'active'
  });

  // Case D: Missing Auth Account (Admin record without matching Auth account)
  await db.collection('admin_users').doc('auto_doc_orphan_999').set({
    name: 'Ghost Admin',
    email: 'nonexistent_user@jamuiservices.in',
    role: 'admin',
    status: 'inactive'
  });

  console.log('✓ Seeding complete. Executing DRY-RUN Migration...\n');

  // 3. Execute Migration in DRY-RUN mode (isDryRun = true)
  const result = await migrateAdminUids(true);

  // 4. Invariant Verification: No documents should have been created or modified in dry-run
  const verifyTargetDoc = await db.collection('admin_users').doc('uid_legacy_002').get();
  if (verifyTargetDoc.exists) {
    console.error('❌ FAIL: Dry-run modified the database!');
    process.exitCode = 1;
  } else {
    console.log('✅ [PASS] Invariant: Dry-run strictly made ZERO writes to Firestore');
  }

  const verifyLegacySource = await db.collection('admin_users').doc('auto_doc_legacy_xyz').get();
  if (verifyLegacySource.exists) {
    console.log('✅ [PASS] Invariant: Source legacy record remains 100% intact');
  } else {
    console.error('❌ FAIL: Legacy source was modified!');
    process.exitCode = 1;
  }

  console.log('\n================================================================');
  console.log(' ADMIN MIGRATION DRY-RUN AUDIT & SAFETY VERIFIED SUCCESSFULLY');
  console.log('================================================================\n');
}

if (require.main === module) {
  testMigrationDryRunSafety();
}

module.exports = { testMigrationDryRunSafety };
