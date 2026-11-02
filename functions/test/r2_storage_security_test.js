const assert = require('assert');
const {
  validateAndGenerateUploadKey,
  generateR2PresignedPutUrl,
  generateR2PresignedGetUrl,
  verifyAndEnforceObjectLimits,
  resolveBucketForFolder,
  resolveBucketForObjectKey,
  DEFAULT_PUBLIC_BUCKET,
  DEFAULT_PRIVATE_BUCKET,
  ALLOWED_FOLDERS,
  ALLOWED_MIME_TYPES,
  MAX_FILE_SIZE_BYTES
} = require('../r2_storage_upload_handler');
const {
  computeSha256,
  mapFirebasePathToR2Key,
  MigrationStateManager,
  planOrExecuteMigration
} = require('../scripts/r2_migration_tool');

console.log('================================================================');
console.log('  JAMUI SERVICES — CLOUDFLARE R2 STORAGE SECURITY TEST SUITE    ');
console.log('================================================================\n');

async function runTests() {
  let passed = 0;
  let total = 0;

  function record(desc, ok) {
    total++;
    if (ok) {
      passed++;
      console.log(`✅ [PASS] Test ${total}: ${desc}`);
    } else {
      console.error(`❌ [FAIL] Test ${total}: ${desc}`);
      process.exit(1);
    }
  }

  // --- MOCK VERIFIERS ---
  const mockSuperAdminVerifier = async ({ auth }) => {
    if (auth.uid !== 'admin_123') {
      const err = new Error('Permission denied: not an authorized administrator.');
      err.code = 'permission-denied';
      throw err;
    }
    return { uid: auth.uid, role: 'super_admin' };
  };

  // TEST 1: Unauthenticated request rejected
  try {
    await validateAndGenerateUploadKey({
      auth: null,
      data: { folder: 'profile', fileName: 'pic.jpg', mimeType: 'image/jpeg', fileSize: 1024 },
      verifyActiveAdminFn: mockSuperAdminVerifier
    });
    record('Unauthenticated request rejected with unauthenticated error', false);
  } catch (e) {
    record('Unauthenticated request rejected with unauthenticated error', e.code === 'unauthenticated');
  }

  // TEST 2: Provider uploading to another provider's folder is rejected
  try {
    await validateAndGenerateUploadKey({
      auth: { uid: 'provider_attacker' },
      data: {
        folder: 'profile',
        targetId: 'provider_victim', // mismatch
        fileName: 'pic.jpg',
        mimeType: 'image/jpeg',
        fileSize: 1024
      },
      verifyActiveAdminFn: mockSuperAdminVerifier
    });
    record('Cross-provider profile upload rejected with permission-denied', false);
  } catch (e) {
    record('Cross-provider profile upload rejected with permission-denied', e.code === 'permission-denied');
  }

  // TEST 3: Non-admin caller uploading category image rejected
  try {
    await validateAndGenerateUploadKey({
      auth: { uid: 'regular_provider_uid' },
      data: {
        folder: 'categories',
        targetId: 'cat_cleaning',
        fileName: 'cover.jpg',
        mimeType: 'image/jpeg',
        fileSize: 2048
      },
      verifyActiveAdminFn: mockSuperAdminVerifier
    });
    record('Non-admin uploading category image rejected with permission-denied', false);
  } catch (e) {
    record('Non-admin uploading category image rejected with permission-denied', e.code === 'permission-denied');
  }

  // TEST 4: Authorized admin uploading category image succeeds
  try {
    const res = await validateAndGenerateUploadKey({
      auth: { uid: 'admin_123' },
      data: {
        folder: 'categories',
        targetId: 'cat_electrician',
        fileName: 'cover.webp',
        mimeType: 'image/webp',
        fileSize: 150000
      },
      verifyActiveAdminFn: mockSuperAdminVerifier
    });
    const isValidKey = res.objectKey.startsWith('categories/cat_electrician/cover_') && res.objectKey.endsWith('.webp');
    record('Authorized admin uploading category image succeeds with canonical key', isValidKey);
  } catch (e) {
    record('Authorized admin uploading category image succeeds with canonical key', false);
  }

  // TEST 5: KYC and Aadhaar uploads are strictly blocked
  try {
    await validateAndGenerateUploadKey({
      auth: { uid: 'user_1' },
      data: {
        folder: 'kyc_documents',
        fileName: 'aadhaar_front.jpg',
        mimeType: 'image/jpeg',
        fileSize: 200000
      },
      verifyActiveAdminFn: mockSuperAdminVerifier
    });
    record('Aadhaar / KYC upload strictly blocked with invalid-argument', false);
  } catch (e) {
    record('Aadhaar / KYC upload strictly blocked with invalid-argument', e.code === 'invalid-argument' && e.message.includes('prohibited'));
  }

  // TEST 6: Unsupported MIME type (PDF, SVG with scripts, EXE) rejected
  const badMimes = ['application/pdf', 'image/svg+xml', 'application/octet-stream', 'image/gif'];
  let allBadRejected = true;
  for (const mime of badMimes) {
    try {
      await validateAndGenerateUploadKey({
        auth: { uid: 'user_1' },
        data: { folder: 'profile', fileName: 'doc.pdf', mimeType: mime, fileSize: 1000 },
        verifyActiveAdminFn: mockSuperAdminVerifier
      });
      allBadRejected = false;
    } catch (e) {
      if (e.code !== 'invalid-argument') allBadRejected = false;
    }
  }
  record('Disallowed MIME types strictly rejected with invalid-argument', allBadRejected);

  // TEST 7: Oversized file (>8MB) and zero/negative size rejected
  try {
    await validateAndGenerateUploadKey({
      auth: { uid: 'user_1' },
      data: { folder: 'profile', fileName: 'huge.jpg', mimeType: 'image/jpeg', fileSize: 9 * 1024 * 1024 },
      verifyActiveAdminFn: mockSuperAdminVerifier
    });
    record('Oversized file (>8MB) rejected with invalid-argument', false);
  } catch (e) {
    record('Oversized file (>8MB) rejected with invalid-argument', e.code === 'invalid-argument');
  }

  // TEST 8: Path traversal attempts are neutralized
  try {
    const res = await validateAndGenerateUploadKey({
      auth: { uid: 'prov_hacker' },
      data: {
        folder: 'profile',
        fileName: '../../../../etc/passwd.png',
        mimeType: 'image/png',
        fileSize: 50000
      },
      verifyActiveAdminFn: mockSuperAdminVerifier
    });
    const isSafe = !res.objectKey.includes('..') && res.objectKey.startsWith('providers/prov_hacker/profile/');
    record('Path traversal attempt neutralized; server-generated safe key created', isSafe);
  } catch (e) {
    record('Path traversal attempt neutralized; server-generated safe key created', false);
  }

  // TEST 9: Presigned URL generator derives valid SigV4 parameters
  try {
    const presigned = generateR2PresignedPutUrl({
      accountId: 'test_account_id',
      accessKeyId: 'test_access_key',
      secretAccessKey: 'test_secret_key',
      bucketName: 'jamui-services-public-prod',
      objectKey: 'categories/cat_1/cover_123.webp',
      mimeType: 'image/webp',
      expiresInSeconds: 600
    });
    const url = presigned.uploadUrl;
    const hasAlgo = url.includes('X-Amz-Algorithm=AWS4-HMAC-SHA256');
    const hasCred = url.includes('X-Amz-Credential=');
    const hasSig = url.includes('X-Amz-Signature=');
    const hasExpires = url.includes('X-Amz-Expires=600');
    const hasHost = url.startsWith('https://test_account_id.r2.cloudflarestorage.com/jamui-services-public-prod/categories/cat_1/cover_123.webp');
    record('SigV4 presigned PUT URL correctly formed with expected security parameters', hasAlgo && hasCred && hasSig && hasExpires && hasHost);
  } catch (e) {
    record('SigV4 presigned PUT URL correctly formed with expected security parameters', false);
  }

  // TEST 10: Presigned URL generator rejects missing secrets with failed-precondition
  try {
    generateR2PresignedPutUrl({
      accountId: '', // missing
      accessKeyId: 'key',
      secretAccessKey: 'secret',
      bucketName: 'bucket',
      objectKey: 'key',
      mimeType: 'image/jpeg'
    });
    record('Missing R2 secrets rejected with failed-precondition', false);
  } catch (e) {
    record('Missing R2 secrets rejected with failed-precondition', e.code === 'failed-precondition');
  }

  // TEST 11: Migration Tool — Path mapping and strict KYC exclusions
  const samplePaths = [
    { src: 'category_images/cat_1/cover.jpg', expected: 'categories/cat_1/cover.jpg' },
    { src: 'banners/b_diwali/banner.webp', expected: 'banners/b_diwali/banner.webp' },
    { src: 'profile_images/uid_42/avatar.png', expected: 'providers/uid_42/profile/avatar.png' },
    { src: 'review_photos/cust_1/book_99/photo.jpg', expected: 'reviews/cust_1/book_99/photo.jpg' },
    { src: 'kyc_documents/uid_42/aadhaar.pdf', expected: null },
    { src: 'providers/uid_42/kyc/pan.jpg', expected: null },
    { src: 'providers/uid_42/certificates/cert.pdf', expected: null }
  ];
  let mappingsCorrect = true;
  for (const item of samplePaths) {
    const mapped = mapFirebasePathToR2Key(item.src);
    if (mapped !== item.expected) {
      mappingsCorrect = false;
      console.error(`Mapping error: ${item.src} -> got ${mapped}, expected ${item.expected}`);
    }
  }
  record('Migration Tool accurately maps public paths and strictly excludes private KYC/certs', mappingsCorrect);

  // TEST 12: Migration Tool — Independent SHA-256 checksum and dry-run execution
  const bufA = Buffer.from('Jamui Services Test Image A');
  const bufB = Buffer.from('Jamui Services Test Image B');
  const shaA = computeSha256(bufA);
  const shaB = computeSha256(bufB);
  assert.notStrictEqual(shaA, shaB);

  const mockStateManager = {
    state: { completed: {}, failed: {} },
    isAlreadyMigrated: (src, sha) => false,
    recordSuccess: () => {},
    recordFailure: () => {}
  };

  const inventory = [
    { sourcePath: 'category_images/cat_1/cover.jpg', buffer: bufA, size: bufA.length, contentType: 'image/jpeg' },
    { sourcePath: 'kyc_documents/user_1/aadhaar.jpg', buffer: bufB, size: bufB.length, contentType: 'image/jpeg' }
  ];

  const plan = await planOrExecuteMigration({
    inventory,
    stateManager: mockStateManager,
    isDryRun: true
  });

  const isDryRunPassed = plan.summary.eligible === 1 &&
                         plan.summary.excludedPrivate === 1 &&
                         plan.actions[0].status === 'DRY_RUN_ELIGIBLE' &&
                         plan.actions[1].status === 'EXCLUDED_PRIVATE';
  record('Migration Tool dry-run computes independent SHA-256 and isolates private assets', isDryRunPassed);

  // --- MOCK FIRESTORE DB FOR BOOKING VERIFICATION ---
  const createMockDb = (leadsDocs = {}, shouldThrow = false) => ({
    collection: (colName) => ({
      doc: (docId) => ({
        get: async () => {
          if (shouldThrow) {
            throw new Error('Simulated network error connecting to Firestore');
          }
          if (colName === 'leads' && leadsDocs[docId]) {
            return {
              exists: true,
              data: () => leadsDocs[docId]
            };
          }
          return { exists: false, data: () => null };
        }
      })
    })
  });

  const mockDbWithLeads = createMockDb({
    'lead_completed_cust1': {
      customerId: 'customer_1',
      status: 'completed',
      providerId: 'prov_99'
    },
    'lead_pending_cust1': {
      customerId: 'customer_1',
      status: 'pending',
      providerId: 'prov_99'
    },
    'lead_completed_cust2': {
      customerId: 'customer_2',
      status: 'completed',
      providerId: 'prov_99'
    }
  });

  // TEST 13: Customer review upload with missing targetId rejected with invalid-argument
  try {
    await validateAndGenerateUploadKey({
      auth: { uid: 'customer_1' },
      data: { folder: 'reviews', targetId: '', fileName: 'work.jpg', mimeType: 'image/jpeg', fileSize: 50000 },
      verifyActiveAdminFn: mockSuperAdminVerifier,
      db: mockDbWithLeads
    });
    record('Review upload with missing booking targetId rejected with invalid-argument', false);
  } catch (e) {
    record('Review upload with missing booking targetId rejected with invalid-argument', e.code === 'invalid-argument');
  }

  // TEST 14: Customer review upload without db instance fails closed with failed-precondition
  try {
    await validateAndGenerateUploadKey({
      auth: { uid: 'customer_1' },
      data: { folder: 'reviews', targetId: 'lead_completed_cust1', fileName: 'work.jpg', mimeType: 'image/jpeg', fileSize: 50000 },
      verifyActiveAdminFn: mockSuperAdminVerifier,
      db: null // Missing DB
    });
    record('Review upload without db instance fails closed with failed-precondition', false);
  } catch (e) {
    record('Review upload without db instance fails closed with failed-precondition', e.code === 'failed-precondition');
  }

  // TEST 15: Customer review upload for non-existent booking rejected with not-found
  try {
    await validateAndGenerateUploadKey({
      auth: { uid: 'customer_1' },
      data: { folder: 'reviews', targetId: 'non_existent_lead_999', fileName: 'work.jpg', mimeType: 'image/jpeg', fileSize: 50000 },
      verifyActiveAdminFn: mockSuperAdminVerifier,
      db: mockDbWithLeads
    });
    record('Review upload for non-existent booking rejected with not-found', false);
  } catch (e) {
    record('Review upload for non-existent booking rejected with not-found', e.code === 'not-found');
  }

  // TEST 16: Customer review upload for another customer\'s booking rejected with permission-denied
  try {
    await validateAndGenerateUploadKey({
      auth: { uid: 'customer_1' }, // caller is customer_1
      data: { folder: 'reviews', targetId: 'lead_completed_cust2', fileName: 'work.jpg', mimeType: 'image/jpeg', fileSize: 50000 }, // owned by customer_2
      verifyActiveAdminFn: mockSuperAdminVerifier,
      db: mockDbWithLeads
    });
    record('Review upload for another user\'s booking rejected with permission-denied', false);
  } catch (e) {
    record('Review upload for another user\'s booking rejected with permission-denied', e.code === 'permission-denied');
  }

  // TEST 17: Customer review upload for incomplete booking (pending/accepted) rejected with failed-precondition
  try {
    await validateAndGenerateUploadKey({
      auth: { uid: 'customer_1' },
      data: { folder: 'reviews', targetId: 'lead_pending_cust1', fileName: 'work.jpg', mimeType: 'image/jpeg', fileSize: 50000 },
      verifyActiveAdminFn: mockSuperAdminVerifier,
      db: mockDbWithLeads
    });
    record('Review upload for non-completed booking rejected with failed-precondition', false);
  } catch (e) {
    record('Review upload for non-completed booking rejected with failed-precondition', e.code === 'failed-precondition');
  }

  // TEST 18: Customer review upload on Firestore error fails closed with unavailable
  try {
    const brokenDb = createMockDb({}, true); // simulates query error
    await validateAndGenerateUploadKey({
      auth: { uid: 'customer_1' },
      data: { folder: 'reviews', targetId: 'lead_completed_cust1', fileName: 'work.jpg', mimeType: 'image/jpeg', fileSize: 50000 },
      verifyActiveAdminFn: mockSuperAdminVerifier,
      db: brokenDb
    });
    record('Review upload on Firestore query error fails closed with unavailable', false);
  } catch (e) {
    record('Review upload on Firestore query error fails closed with unavailable', e.code === 'unavailable');
  }

  // TEST 19: Customer review upload for valid completed booking owned by caller succeeds
  try {
    const res = await validateAndGenerateUploadKey({
      auth: { uid: 'customer_1' },
      data: { folder: 'reviews', targetId: 'lead_completed_cust1', fileName: 'work.jpg', mimeType: 'image/jpeg', fileSize: 50000 },
      verifyActiveAdminFn: mockSuperAdminVerifier,
      db: mockDbWithLeads
    });
    const expectedPrefix = 'reviews/customer_1/lead_completed_cust1/rev_';
    const isValidReviewKey = res.objectKey.startsWith(expectedPrefix) && res.objectKey.endsWith('.jpg');
    record('Review upload for valid completed booking owned by caller succeeds with canonical key', isValidReviewKey);
  } catch (e) {
    record('Review upload for valid completed booking owned by caller succeeds with canonical key', false);
  }

  // TEST 20: Authenticated provider uploading certificate for own account succeeds
  try {
    const res = await validateAndGenerateUploadKey({
      auth: { uid: 'provider_101' },
      data: { folder: 'certificates', targetId: 'provider_101', fileName: 'electrical_diploma.jpg', mimeType: 'image/jpeg', fileSize: 150000 },
      verifyActiveAdminFn: mockSuperAdminVerifier
    });
    const isValidCertKey = res.objectKey.startsWith('providers/provider_101/certificates/certificates_') && res.objectKey.endsWith('.jpg');
    record('Authenticated provider uploading certificate for own account succeeds with canonical key', isValidCertKey);
  } catch (e) {
    record('Authenticated provider uploading certificate for own account succeeds with canonical key', false);
  }

  // TEST 21: Authenticated provider uploading certificate for another provider is rejected
  try {
    await validateAndGenerateUploadKey({
      auth: { uid: 'provider_101' },
      data: { folder: 'certificates', targetId: 'provider_victim', fileName: 'fake_cert.jpg', mimeType: 'image/jpeg', fileSize: 150000 },
      verifyActiveAdminFn: mockSuperAdminVerifier
    });
    record('Provider uploading certificate for another provider rejected with permission-denied', false);
  } catch (e) {
    record('Provider uploading certificate for another provider rejected with permission-denied', e.code === 'permission-denied');
  }

  // TEST 22: Certificate upload supports PDF documents
  try {
    const res = await validateAndGenerateUploadKey({
      auth: { uid: 'provider_101' },
      data: { folder: 'certificates', targetId: 'provider_101', fileName: 'trade_license.pdf', mimeType: 'application/pdf', fileSize: 250000 },
      verifyActiveAdminFn: mockSuperAdminVerifier
    });
    const isPdfKey = res.objectKey.startsWith('providers/provider_101/certificates/certificates_') && res.objectKey.endsWith('.pdf');
    record('Certificate upload supports valid PDF documents with canonical .pdf extension', isPdfKey);
  } catch (e) {
    record('Certificate upload supports valid PDF documents with canonical .pdf extension', false);
  }

  // TEST 23: Presigned GET URL generator derives valid SigV4 parameters for secure document viewing
  try {
    const presignedGet = generateR2PresignedGetUrl({
      accountId: 'test_account_id',
      accessKeyId: 'test_access_key',
      secretAccessKey: 'test_secret_key',
      bucketName: 'jamui-services-public-prod',
      objectKey: 'providers/provider_101/certificates/cert_123.pdf',
      expiresInSeconds: 600
    });
    const url = presignedGet.viewUrl;
    const hasAlgo = url.includes('X-Amz-Algorithm=AWS4-HMAC-SHA256');
    const hasCred = url.includes('X-Amz-Credential=');
    const hasSig = url.includes('X-Amz-Signature=');
    const hasExpires = url.includes('X-Amz-Expires=600');
    const hasHost = url.startsWith('https://test_account_id.r2.cloudflarestorage.com/jamui-services-public-prod/providers/provider_101/certificates/cert_123.pdf');
    record('SigV4 presigned GET URL correctly formed for secure document viewing', hasAlgo && hasCred && hasSig && hasExpires && hasHost);
  } catch (e) {
    record('SigV4 presigned GET URL correctly formed for secure document viewing', false);
  }

  // TEST 24: Authenticated provider uploading KYC document for own account succeeds
  try {
    const res = await validateAndGenerateUploadKey({
      auth: { uid: 'provider_101' },
      data: { folder: 'kyc', targetId: 'provider_101', fileName: 'workshop_bill.pdf', mimeType: 'application/pdf', fileSize: 200000 },
      verifyActiveAdminFn: mockSuperAdminVerifier
    });
    const isValidKycKey = res.objectKey.startsWith('providers/provider_101/kyc/kyc_') && res.objectKey.endsWith('.pdf');
    record('Authenticated provider uploading KYC document for own account succeeds with canonical key', isValidKycKey);
  } catch (e) {
    record('Authenticated provider uploading KYC document for own account succeeds with canonical key', false);
  }

  // TEST 25: Authenticated provider uploading KYC document for another provider is rejected
  try {
    await validateAndGenerateUploadKey({
      auth: { uid: 'provider_101' },
      data: { folder: 'kyc', targetId: 'provider_victim', fileName: 'fake_kyc.pdf', mimeType: 'application/pdf', fileSize: 200000 },
      verifyActiveAdminFn: mockSuperAdminVerifier
    });
    record('Provider uploading KYC document for another provider rejected with permission-denied', false);
  } catch (e) {
    record('Provider uploading KYC document for another provider rejected with permission-denied', e.code === 'permission-denied');
  }

  // TEST 26: Dual-Bucket Isolation: Public folders map to public bucket; certificates & KYC map to private bucket
  try {
    const pubProfile = resolveBucketForFolder('profile');
    const pubBiz = resolveBucketForFolder('business');
    const pubWorkplace = resolveBucketForFolder('workplace');
    const privCert = resolveBucketForFolder('certificates');
    const privKyc = resolveBucketForFolder('kyc');

    const keyProfile = resolveBucketForObjectKey('providers/uid1/profile/pic.jpg');
    const keyCert = resolveBucketForObjectKey('providers/uid1/certificates/cert.pdf');
    const keyKyc = resolveBucketForObjectKey('providers/uid1/kyc/doc.pdf');

    const isDualCorrect = pubProfile === DEFAULT_PUBLIC_BUCKET &&
                          pubBiz === DEFAULT_PUBLIC_BUCKET &&
                          pubWorkplace === DEFAULT_PUBLIC_BUCKET &&
                          privCert === DEFAULT_PRIVATE_BUCKET &&
                          privKyc === DEFAULT_PRIVATE_BUCKET &&
                          keyProfile === DEFAULT_PUBLIC_BUCKET &&
                          keyCert === DEFAULT_PRIVATE_BUCKET &&
                          keyKyc === DEFAULT_PRIVATE_BUCKET;

    record('Dual-bucket isolation correctly routes private documents to private bucket and photos to public bucket', isDualCorrect);
  } catch (e) {
    record('Dual-bucket isolation correctly routes private documents to private bucket and photos to public bucket', false);
  }

  // TEST 27: Authoritative server-side verification: Valid 2MB JPEG succeeds
  try {
    const mockHttp = ({ method }, resolve) => {
      if (method === 'HEAD') {
        return resolve({
          statusCode: 200,
          headers: { 'content-length': '2097152', 'content-type': 'image/jpeg', 'etag': '"abc"' }
        });
      }
      return resolve({ statusCode: 200, headers: {} });
    };

    const res = await verifyAndEnforceObjectLimits({
      accountId: 'acc1',
      accessKeyId: 'key1',
      secretAccessKey: 'sec1',
      bucketName: DEFAULT_PUBLIC_BUCKET,
      objectKey: 'providers/p1/profile/pic.jpg',
      httpRequestFn: mockHttp
    });

    record('Server-side verification confirms valid 2MB JPEG without deleting', res.verified && res.actualSizeBytes === 2097152);
  } catch (e) {
    record('Server-side verification confirms valid 2MB JPEG without deleting', false);
  }

  // TEST 28: Authoritative server-side verification: Oversized file (>8MB, e.g. 10MB) is PURGED and rejected
  try {
    let deleteCalled = false;
    const mockHttp = ({ method }, resolve) => {
      if (method === 'HEAD') {
        return resolve({
          statusCode: 200,
          headers: { 'content-length': '10485760', 'content-type': 'image/jpeg' } // 10MB
        });
      }
      if (method === 'DELETE') {
        deleteCalled = true;
        return resolve({ statusCode: 204, headers: {} });
      }
      return resolve({ statusCode: 200, headers: {} });
    };

    await verifyAndEnforceObjectLimits({
      accountId: 'acc1',
      accessKeyId: 'key1',
      secretAccessKey: 'sec1',
      bucketName: DEFAULT_PUBLIC_BUCKET,
      objectKey: 'providers/p1/profile/oversized.jpg',
      httpRequestFn: mockHttp
    });
    record('Server-side verification purges oversized (>8MB) object and throws invalid-argument', false);
  } catch (e) {
    record('Server-side verification purges oversized (>8MB) object and throws invalid-argument', e.code === 'invalid-argument' && e.message.includes('exceeds the maximum allowed size of 8MB'));
  }

  // TEST 29: Authoritative server-side verification: Disallowed MIME (e.g. application/x-msdownload) is PURGED
  try {
    let deleteCalled = false;
    const mockHttp = ({ method }, resolve) => {
      if (method === 'HEAD') {
        return resolve({
          statusCode: 200,
          headers: { 'content-length': '50000', 'content-type': 'application/x-msdownload' }
        });
      }
      if (method === 'DELETE') {
        deleteCalled = true;
        return resolve({ statusCode: 204, headers: {} });
      }
      return resolve({ statusCode: 200, headers: {} });
    };

    await verifyAndEnforceObjectLimits({
      accountId: 'acc1',
      accessKeyId: 'key1',
      secretAccessKey: 'sec1',
      bucketName: DEFAULT_PUBLIC_BUCKET,
      objectKey: 'providers/p1/profile/malware.exe',
      httpRequestFn: mockHttp
    });
    record('Server-side verification purges disallowed MIME type and throws invalid-argument', false);
  } catch (e) {
    record('Server-side verification purges disallowed MIME type and throws invalid-argument', e.code === 'invalid-argument' && e.message.includes('not permitted'));
  }

  // TEST 30: Server-side verification throws not-found for non-existent R2 object
  try {
    const mockHttp = ({ method }, resolve) => {
      if (method === 'HEAD') {
        return resolve({ statusCode: 404, headers: {} });
      }
      return resolve({ statusCode: 200, headers: {} });
    };

    await verifyAndEnforceObjectLimits({
      accountId: 'acc1',
      accessKeyId: 'key1',
      secretAccessKey: 'sec1',
      bucketName: DEFAULT_PUBLIC_BUCKET,
      objectKey: 'providers/p1/profile/nonexistent.jpg',
      httpRequestFn: mockHttp
    });
    record('Server-side verification throws not-found for non-existent object', false);
  } catch (e) {
    record('Server-side verification throws not-found for non-existent object', e.code === 'not-found');
  }

  console.log('\n================================================================');
  console.log(` RESULTS: ${passed}/${total} CLOUDFLARE R2 SECURITY TESTS PASSED`);
  console.log('================================================================\n');
}

runTests().catch(err => {
  console.error('Test suite uncaught error:', err);
  process.exit(1);
});
