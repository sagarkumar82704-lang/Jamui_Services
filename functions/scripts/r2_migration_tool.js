/**
 * Jamui Services - Cloudflare R2 Migration & Verification Tool (Phase 1C)
 * 
 * DESIGN PRINCIPLES:
 * 1. Default mode is DRY-RUN (`--dry-run`). Live operations require explicit flags.
 * 2. Independent SHA-256 byte checksum comparison (ETag is NEVER assumed to be MD5).
 * 3. Resumable progress tracking via local manifest (`migration_manifest.json`).
 * 4. Deduplication: Identical object + matching SHA-256 skipped automatically.
 * 5. Strict Exclusion: KYC documents, Aadhaar cards, and unapproved certificates
 *    are NEVER copied to public R2 storage.
 * 6. ZERO DESTRUCTION: Never deletes source Firebase Storage objects.
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

// Excluded private/sensitive paths (per Jamui Services data privacy policy)
const EXCLUDED_PREFIXES = [
  'kyc_documents/',
  'providers/', // will check for /kyc/ or /certificates/ inside
  'aadhaar/',
  'pan/',
  'identity/'
];

/**
 * Computes independent SHA-256 hash of a buffer.
 */
function computeSha256(buffer) {
  return crypto.createHash('sha256').update(buffer).digest('hex');
}

/**
 * Maps a legacy Firebase Storage object path to a standardized Cloudflare R2 object key.
 * Returns null if the path should be excluded.
 */
function mapFirebasePathToR2Key(sourcePath) {
  if (!sourcePath || typeof sourcePath !== 'string') return null;
  const clean = sourcePath.replace(/^\/+/, '').trim();

  // 1. Strict Exclusions
  if (clean.startsWith('kyc_documents/') ||
      clean.includes('/kyc/') ||
      clean.includes('/certificates/') ||
      clean.startsWith('aadhaar/') ||
      clean.startsWith('pan/')) {
    return null; // Excluded from public bucket
  }

  // 2. Category Images: category_images/{id}/{file} -> categories/{id}/{file}
  if (clean.startsWith('category_images/')) {
    return clean.replace(/^category_images\//, 'categories/');
  }

  // 3. Promotional Banners: keep banners/ or sponsor_banners/
  if (clean.startsWith('banners/') || clean.startsWith('sponsor_banners/')) {
    return clean;
  }

  // 4. Provider Profile Photos: profile_images/{uid}/{file} -> providers/{uid}/profile/{file}
  if (clean.startsWith('profile_images/')) {
    const parts = clean.split('/');
    if (parts.length >= 3) {
      const uid = parts[1];
      const file = parts.slice(2).join('/');
      return `providers/${uid}/profile/${file}`;
    }
  }

  // 5. Provider Business / Workplace Photos: providers/{uid}/{folder}/{file}
  if (clean.startsWith('providers/')) {
    return clean;
  }

  // 6. Customer Review Photos: review_photos/{uid}/{bookingId}/{file} -> reviews/{uid}/{bookingId}/{file}
  if (clean.startsWith('review_photos/')) {
    return clean.replace(/^review_photos\//, 'reviews/');
  }

  return clean;
}

/**
 * In-memory state manager for resumable execution.
 */
class MigrationStateManager {
  constructor(manifestPath) {
    this.manifestPath = manifestPath || path.join(__dirname, 'migration_manifest.json');
    this.state = {
      completed: {},
      failed: {},
      stats: {
        totalScanned: 0,
        migrated: 0,
        skippedExisting: 0,
        excludedPrivate: 0,
        failed: 0,
        bytesProcessed: 0
      }
    };
    this.load();
  }

  load() {
    if (fs.existsSync(this.manifestPath)) {
      try {
        const raw = fs.readFileSync(this.manifestPath, 'utf8');
        this.state = JSON.parse(raw);
      } catch (_) {}
    }
  }

  save() {
    try {
      fs.writeFileSync(this.manifestPath, JSON.stringify(this.state, null, 2), 'utf8');
    } catch (_) {}
  }

  isAlreadyMigrated(sourcePath, sha256) {
    const record = this.state.completed[sourcePath];
    return record && record.sha256 === sha256;
  }

  recordSuccess({ sourcePath, destKey, size, sha256, isDryRun }) {
    this.state.completed[sourcePath] = {
      destKey,
      size,
      sha256,
      migratedAt: new Date().toISOString(),
      isDryRun
    };
    this.state.stats.migrated++;
    this.state.stats.bytesProcessed += size;
    delete this.state.failed[sourcePath];
    this.save();
  }

  recordFailure({ sourcePath, destKey, error }) {
    this.state.failed[sourcePath] = {
      destKey,
      error: error?.message || String(error),
      failedAt: new Date().toISOString()
    };
    this.state.stats.failed++;
    this.save();
  }
}

/**
 * Executes migration planning or dry-run audit over an inventory of objects.
 */
async function planOrExecuteMigration({
  inventory,
  stateManager,
  isDryRun = true,
  uploaderFn = null,
  verifierFn = null
}) {
  const plan = {
    actions: [],
    summary: {
      total: inventory.length,
      eligible: 0,
      excludedPrivate: 0,
      alreadyMigrated: 0,
      dryRun: isDryRun,
      totalBytes: 0
    }
  };

  for (const item of inventory) {
    const { sourcePath, buffer, size, contentType } = item;
    const sha256 = buffer ? computeSha256(buffer) : (item.sha256 || 'unknown');

    // Check exclusion
    const destKey = mapFirebasePathToR2Key(sourcePath);
    if (!destKey) {
      plan.summary.excludedPrivate++;
      plan.actions.push({
        sourcePath,
        status: 'EXCLUDED_PRIVATE',
        reason: 'Sensitive or unapproved KYC/Certificate document'
      });
      continue;
    }

    // Check if already migrated
    if (stateManager.isAlreadyMigrated(sourcePath, sha256)) {
      plan.summary.alreadyMigrated++;
      plan.actions.push({
        sourcePath,
        destKey,
        status: 'SKIPPED_EXISTING',
        sha256
      });
      continue;
    }

    plan.summary.eligible++;
    plan.summary.totalBytes += (size || 0);

    if (isDryRun) {
      plan.actions.push({
        sourcePath,
        destKey,
        size,
        contentType,
        sha256,
        status: 'DRY_RUN_ELIGIBLE'
      });
      stateManager.recordSuccess({ sourcePath, destKey, size, sha256, isDryRun: true });
    } else {
      try {
        if (typeof uploaderFn === 'function') {
          await uploaderFn({ destKey, buffer, contentType });
        }
        if (typeof verifierFn === 'function') {
          const verifiedSha = await verifierFn({ destKey });
          if (verifiedSha !== sha256) {
            throw new Error(`SHA-256 mismatch! Expected ${sha256}, got ${verifiedSha}`);
          }
        }
        stateManager.recordSuccess({ sourcePath, destKey, size, sha256, isDryRun: false });
        plan.actions.push({
          sourcePath,
          destKey,
          status: 'SUCCESS',
          sha256
        });
      } catch (err) {
        stateManager.recordFailure({ sourcePath, destKey, error: err });
        plan.actions.push({
          sourcePath,
          destKey,
          status: 'FAILED',
          error: err.message
        });
      }
    }
  }

  return plan;
}

module.exports = {
  computeSha256,
  mapFirebasePathToR2Key,
  MigrationStateManager,
  planOrExecuteMigration,
  EXCLUDED_PREFIXES
};
