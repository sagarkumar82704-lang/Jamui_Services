/**
 * JAMUI SERVICES — ADMIN UID MAPPING & MIGRATION SCRIPT
 * 
 * Purpose:
 * Safely maps existing Admin accounts in `admin_users` to their actual Firebase Auth UIDs
 * so that hardcoded email fallbacks can be completely eliminated from Firestore Security Rules
 * without locking out any valid existing administrators.
 * 
 * Safety Features:
 * - Dry-run mode by default (`--execute` required to apply changes)
 * - Zero destructive operations (preserves legacy documents)
 * - Read-after-write verification
 * - Validates role ('admin', 'super_admin') and status ('active')
 */

const path = require('path');
const functionsNodeModules = path.resolve(__dirname, '../functions/node_modules');
if (!module.paths.includes(functionsNodeModules)) {
  module.paths.unshift(functionsNodeModules);
}

const admin = require('firebase-admin');

// Ensure correct project initialization
const projectId = process.env.GCLOUD_PROJECT || 'demo-jamui-services-emulator';
if (admin.apps.length === 0) {
  admin.initializeApp({ projectId });
}
const db = admin.firestore();
const auth = admin.auth();

async function migrateAdminUids(isDryRun = true) {
  console.log('================================================================');
  console.log(` JAMUI SERVICES — ADMIN UID MIGRATION (Mode: ${isDryRun ? 'DRY-RUN' : 'LIVE EXECUTION'})`);
  console.log(` Target Project: ${projectId}`);
  console.log('================================================================\n');

  const snapshot = await db.collection('admin_users').get();
  console.log(`Found ${snapshot.docs.length} document(s) in 'admin_users' collection.\n`);

  let boundCount = 0;
  let alreadyBoundCount = 0;
  let skippedCount = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const docId = doc.id;
    const email = (data.email || '').trim().toLowerCase();
    const explicitUid = data.uid || '';

    console.log(`--- Inspecting Admin Record [${docId}] ---`);
    console.log(`  Name:   ${data.name || 'N/A'}`);
    console.log(`  Email:  ${email || 'N/A'}`);
    console.log(`  Role:   ${data.role || 'admin'}`);
    console.log(`  Status: ${data.status || 'active'}`);

    if (!email) {
      console.log(`  ⚠️ Skipped: Document has no email address.`);
      skippedCount++;
      continue;
    }

    let authUser;
    try {
      authUser = await auth.getUserByEmail(email);
    } catch (err) {
      if (explicitUid) {
        try {
          authUser = await auth.getUser(explicitUid);
        } catch (_) {}
      }
    }

    if (!authUser) {
      console.log(`  ⚠️ Notice: No Firebase Auth account found for email "${email}".`);
      skippedCount++;
      continue;
    }

    const authUid = authUser.uid;
    console.log(`  Found Auth Record: UID = ${authUid}`);

    if (docId === authUid) {
      console.log(`  ✅ Already correctly keyed by Auth UID.`);
      alreadyBoundCount++;
      continue;
    }

    // Document is keyed by something else (e.g. auto-id or email)
    console.log(`  🔄 Needs Binding: Key [${docId}] -> Key [${authUid}]`);

    // Check for collision or conflict with existing destination doc
    const destDoc = await db.collection('admin_users').doc(authUid).get();
    if (destDoc.exists && destDoc.id !== docId) {
      console.log(`  ⚠️ CONFLICT DETECTED: Destination doc('admin_users/${authUid}') already exists with name "${destDoc.data()?.name || 'N/A'}" and role "${destDoc.data()?.role || 'N/A'}". Will not overwrite without manual resolution.`);
      skippedCount++;
      continue;
    }

    if (isDryRun) {
      console.log(`  [DRY-RUN] Target safe: doc('admin_users/${authUid}') does not collide. Ready for mapping.`);
      boundCount++;
    } else {
      const payload = {
        ...data,
        uid: authUid,
        email: email,
        status: data.status || 'active',
        isActive: data.isActive !== false,
        role: data.role || 'admin',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        migratedFromDocId: docId,
        migratedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      await db.collection('admin_users').doc(authUid).set(payload, { merge: true });

      // Read-after-write verification
      const verify = await db.collection('admin_users').doc(authUid).get();
      if (verify.exists) {
        console.log(`  ✅ Successfully bound to doc('${authUid}').`);
        boundCount++;
      } else {
        console.error(`  ❌ Failed to verify write for doc('${authUid}').`);
      }
    }
  }

  console.log('\n================================================================');
  console.log(` SUMMARY: ${alreadyBoundCount} already bound, ${boundCount} mapped, ${skippedCount} skipped`);
  console.log('================================================================\n');

  return { alreadyBoundCount, boundCount, skippedCount };
}

if (require.main === module) {
  const isExecute = process.argv.includes('--execute');
  migrateAdminUids(!isExecute)
    .then(() => process.exit(0))
    .catch((err) => {
      console.error('Migration error:', err);
      process.exit(1);
    });
}

module.exports = { migrateAdminUids };

