const assert = require('assert');
const {
  resolveBucketForFolder,
  resolveBucketForObjectKey,
  handleStorageObjectDelete,
  generateR2PresignedPutUrl,
  generateR2PresignedGetUrl
} = require('../r2_storage_upload_handler');
const handlers = require('../index');

console.log('================================================================');
console.log('  JAMUI SERVICES — R2 PRODUCTION FALLBACK REMOVAL VERIFICATION  ');
console.log('================================================================\n');

let passed = 0;
let total = 0;

function record(name, condition) {
  total++;
  if (condition) {
    passed++;
    console.log(`✅ [PASS] Test ${total}: ${name}`);
  } else {
    console.error(`❌ [FAIL] Test ${total}: ${name}`);
    throw new Error(`Test assertion failed: ${name}`);
  }
}

async function runFallbackRemovalVerification() {
  // Clear any ambient environment variables for clean isolation
  const originalEnv = { ...process.env };
  delete process.env.R2_ACCOUNT_ID;
  delete process.env.R2_ACCESS_KEY_ID;
  delete process.env.R2_SECRET_ACCESS_KEY;
  delete process.env.R2_BUCKET_NAME;
  delete process.env.R2_PRIVATE_BUCKET_NAME;

  // 1. Missing Public Bucket fails closed
  try {
    resolveBucketForFolder('profile');
    record('Missing R2_BUCKET_NAME on resolveBucketForFolder fails closed', false);
  } catch (err) {
    record('Missing R2_BUCKET_NAME on resolveBucketForFolder fails closed',
      err.code === 'failed-precondition' &&
      err.message.includes('Production fallback is strictly disabled') &&
      err.message.includes('R2_BUCKET_NAME')
    );
  }

  // 2. Missing Private Bucket fails closed
  try {
    resolveBucketForFolder('certificates');
    record('Missing R2_PRIVATE_BUCKET_NAME on resolveBucketForFolder fails closed', false);
  } catch (err) {
    record('Missing R2_PRIVATE_BUCKET_NAME on resolveBucketForFolder fails closed',
      err.code === 'failed-precondition' &&
      err.message.includes('Production fallback is strictly disabled') &&
      err.message.includes('R2_PRIVATE_BUCKET_NAME')
    );
  }

  // 3. Whitespace Public Bucket fails closed
  try {
    resolveBucketForFolder('business', '   ', 'valid-private');
    record('Whitespace publicBucket argument fails closed', false);
  } catch (err) {
    record('Whitespace publicBucket argument fails closed',
      err.code === 'failed-precondition' &&
      err.message.includes('Production fallback is strictly disabled')
    );
  }

  // 4. Whitespace Private Bucket fails closed
  try {
    resolveBucketForFolder('kyc', 'valid-public', '   ');
    record('Whitespace privateBucket argument fails closed', false);
  } catch (err) {
    record('Whitespace privateBucket argument fails closed',
      err.code === 'failed-precondition' &&
      err.message.includes('Production fallback is strictly disabled')
    );
  }

  // 5. resolveBucketForObjectKey on public object without bucket fails closed
  try {
    resolveBucketForObjectKey('providers/p101/profile/avatar.png');
    record('Missing public bucket on resolveBucketForObjectKey fails closed', false);
  } catch (err) {
    record('Missing public bucket on resolveBucketForObjectKey fails closed',
      err.code === 'failed-precondition' &&
      err.message.includes('Production fallback is strictly disabled')
    );
  }

  // 6. resolveBucketForObjectKey on private object without bucket fails closed
  try {
    resolveBucketForObjectKey('providers/p101/certificates/diploma.pdf');
    record('Missing private bucket on resolveBucketForObjectKey fails closed', false);
  } catch (err) {
    record('Missing private bucket on resolveBucketForObjectKey fails closed',
      err.code === 'failed-precondition' &&
      err.message.includes('Production fallback is strictly disabled')
    );
  }

  // 7. Production bucket fallback elimination check
  const prodNames = ['jamui-services-public-prod', 'jamui-services-private-prod'];
  let prodLeaked = false;
  const testFolders = ['categories', 'banners', 'profile', 'business', 'workplace', 'reviews', 'certificates', 'kyc', 'listings'];
  for (const f of testFolders) {
    try {
      const res = resolveBucketForFolder(f);
      if (prodNames.includes(res)) prodLeaked = true;
    } catch (_) {
      // Expected to fail closed
    }
  }
  record('Zero production fallback: Default production bucket names are NEVER returned', !prodLeaked);

  // 8. Dual-bucket separation remains enforced when valid buckets are supplied
  const stagingPub = 'jamui-services-public-staging';
  const stagingPriv = 'jamui-services-private-staging';

  const folderPub = resolveBucketForFolder('profile', stagingPub, stagingPriv);
  const folderPriv = resolveBucketForFolder('kyc', stagingPub, stagingPriv);
  const keyPub = resolveBucketForObjectKey('providers/u1/business/shop.jpg', stagingPub, stagingPriv);
  const keyPriv = resolveBucketForObjectKey('providers/u1/certificates/doc.pdf', stagingPub, stagingPriv);

  record('Dual-bucket separation correctly resolves Staging public and private buckets',
    folderPub === stagingPub &&
    folderPriv === stagingPriv &&
    keyPub === stagingPub &&
    keyPriv === stagingPriv
  );

  // 9. Environment variable fallback works ONLY when non-empty, and fails if empty
  process.env.R2_BUCKET_NAME = stagingPub;
  process.env.R2_PRIVATE_BUCKET_NAME = stagingPriv;

  const envFolderPub = resolveBucketForFolder('business');
  const envFolderPriv = resolveBucketForFolder('certificates');
  record('Explicit non-empty environment variables resolved successfully',
    envFolderPub === stagingPub &&
    envFolderPriv === stagingPriv
  );

  // 10. Empty environment variable fails closed
  process.env.R2_BUCKET_NAME = '';
  try {
    resolveBucketForFolder('business');
    record('Empty process.env.R2_BUCKET_NAME fails closed', false);
  } catch (err) {
    record('Empty process.env.R2_BUCKET_NAME fails closed',
      err.code === 'failed-precondition' &&
      err.message.includes('Production fallback is strictly disabled')
    );
  }

  // 11. Presigned PUT URL generator fails closed on missing credentials or bucket
  try {
    generateR2PresignedPutUrl({
      accountId: 'acc1',
      accessKeyId: 'key1',
      secretAccessKey: 'sec1',
      bucketName: '', // empty
      objectKey: 'categories/c1/img.webp',
      mimeType: 'image/webp'
    });
    record('generateR2PresignedPutUrl fails closed on empty bucketName', false);
  } catch (err) {
    record('generateR2PresignedPutUrl fails closed on empty bucketName', err.code === 'failed-precondition');
  }

  // 12. Presigned GET URL generator fails closed on missing credentials or bucket
  try {
    generateR2PresignedGetUrl({
      accountId: 'acc1',
      accessKeyId: 'key1',
      secretAccessKey: 'sec1',
      bucketName: '   ', // whitespace
      objectKey: 'providers/p1/certificates/cert.pdf'
    });
    record('generateR2PresignedGetUrl fails closed on whitespace bucketName', false);
  } catch (err) {
    record('generateR2PresignedGetUrl fails closed on whitespace bucketName', err.code === 'failed-precondition');
  }

  // Restore env
  process.env = originalEnv;

  console.log('\n================================================================');
  console.log(` RESULTS: ${passed}/${total} FALLBACK REMOVAL VERIFICATION TESTS PASSED`);
  console.log('================================================================\n');
}

runFallbackRemovalVerification().catch(err => {
  console.error('Test suite failed:', err);
  process.exit(1);
});

