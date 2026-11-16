const assert = require('assert');
const {
  validateAndGenerateUploadKey,
  resolveBucketForFolder,
  resolveBucketForObjectKey,
  ALLOWED_FOLDERS,
  ALLOWED_MIME_TYPES,
  MAX_FILE_SIZE_BYTES
} = require('../r2_storage_upload_handler');

console.log('================================================================');
console.log(' JAMUI SERVICES — PROFESSIONAL SELLER PRODUCT R2 UPLOAD TESTS   ');
console.log('================================================================\n');

async function runTests() {
  let passed = 0;
  let total = 0;

  function record(desc, ok) {
    total++;
    if (ok) {
      passed++;
      console.log(`✅ [PASS ${total}] ${desc}`);
    } else {
      console.error(`❌ [FAIL ${total}] ${desc}`);
      process.exit(1);
    }
  }

  const callerSellerUid = 'seller_uid_123';
  const otherSellerUid = 'seller_uid_456';
  const shopId = 'shop_123';
  const nowFuture = new Date(Date.now() + 10 * 24 * 60 * 60 * 1000); // 10 days in future

  // Mock Shop DB
  const mockShopDb = {
    collection: (colName) => {
      if (colName === 'diamond_shops') {
        return {
          doc: (docId) => ({
            get: async () => {
              if (docId === 'shop_123' || docId === callerSellerUid) {
                return {
                  exists: true,
                  id: shopId,
                  data: () => ({
                    ownerUid: callerSellerUid,
                    shopName: 'Jamui Grocery Store',
                    status: 'approved',
                    isApproved: true,
                    isActive: true,
                    isSubscriptionActive: true,
                    subscriptionExpiry: nowFuture
                  })
                };
              }
              if (docId === 'unapproved_shop') {
                return {
                  exists: true,
                  id: 'unapproved_shop',
                  data: () => ({
                    ownerUid: callerSellerUid,
                    shopName: 'Unapproved Shop',
                    status: 'pending',
                    isApproved: false,
                    isActive: true,
                    isSubscriptionActive: true,
                    subscriptionExpiry: nowFuture
                  })
                };
              }
              if (docId === 'suspended_shop') {
                return {
                  exists: true,
                  id: 'suspended_shop',
                  data: () => ({
                    ownerUid: callerSellerUid,
                    shopName: 'Suspended Shop',
                    status: 'suspended',
                    isApproved: true,
                    isActive: true,
                    isSubscriptionActive: true,
                    subscriptionExpiry: nowFuture
                  })
                };
              }
              if (docId === 'deleted_shop') {
                return {
                  exists: true,
                  id: 'deleted_shop',
                  data: () => ({
                    ownerUid: callerSellerUid,
                    shopName: 'Deleted Shop',
                    isDeleted: true,
                    status: 'approved',
                    isApproved: true,
                    isActive: true
                  })
                };
              }
              if (docId === 'expired_sub_shop') {
                return {
                  exists: true,
                  id: 'expired_sub_shop',
                  data: () => ({
                    ownerUid: callerSellerUid,
                    shopName: 'Expired Sub Shop',
                    status: 'approved',
                    isApproved: true,
                    isActive: true,
                    isSubscriptionActive: false,
                    subscriptionExpiry: new Date(Date.now() - 10000)
                  })
                };
              }
              if (docId === 'other_shop') {
                return {
                  exists: true,
                  id: 'other_shop',
                  data: () => ({
                    ownerUid: otherSellerUid,
                    shopName: 'Other Store',
                    status: 'approved',
                    isApproved: true,
                    isActive: true,
                    isSubscriptionActive: true,
                    subscriptionExpiry: nowFuture
                  })
                };
              }
              return { exists: false, data: () => null };
            }
          }),
          where: (field, op, val) => ({
            limit: () => ({
              get: async () => {
                if (field === 'ownerUid' && val === callerSellerUid) {
                  return {
                    empty: false,
                    docs: [{
                      id: shopId,
                      exists: true,
                      data: () => ({
                        ownerUid: callerSellerUid,
                        shopName: 'Jamui Grocery Store',
                        status: 'approved',
                        isApproved: true,
                        isActive: true,
                        isSubscriptionActive: true,
                        subscriptionExpiry: nowFuture
                      })
                    }]
                  };
                }
                return { empty: true, docs: [] };
              }
            })
          })
        };
      }
      return { doc: () => ({ get: async () => ({ exists: false }) }) };
    }
  };

  // TEST 1: Allowed folder includes 'products'
  record("'products' is in ALLOWED_FOLDERS allowlist", ALLOWED_FOLDERS.includes('products'));

  // TEST 2: Valid authenticated professional seller uploads JPEG product image
  const resValidJpeg = await validateAndGenerateUploadKey({
    auth: { uid: callerSellerUid },
    data: {
      folder: 'products',
      targetId: shopId,
      fileName: 'prod_apple.jpg',
      mimeType: 'image/jpeg',
      fileSize: 1024 * 500 // 500 KB
    },
    db: mockShopDb
  });
  record("Valid JPEG product upload succeeds with canonical server key",
    resValidJpeg.objectKey.startsWith(`providers/${callerSellerUid}/products/prod_`) &&
    resValidJpeg.objectKey.endsWith('.jpg') &&
    resValidJpeg.isPrivate === false
  );

  // TEST 3: Valid WebP product upload
  const resValidWebp = await validateAndGenerateUploadKey({
    auth: { uid: callerSellerUid },
    data: {
      folder: 'products',
      targetId: shopId,
      fileName: 'prod_mango.webp',
      mimeType: 'image/webp',
      fileSize: 1024 * 300
    },
    db: mockShopDb
  });
  record("Valid WebP product upload succeeds with canonical .webp extension",
    resValidWebp.objectKey.endsWith('.webp') && resValidWebp.isPrivate === false
  );

  // TEST 4: Valid PNG product upload without targetId (auto-resolves shop from ownerUid)
  const resValidPng = await validateAndGenerateUploadKey({
    auth: { uid: callerSellerUid },
    data: {
      folder: 'products',
      fileName: 'prod_milk.png',
      mimeType: 'image/png',
      fileSize: 1024 * 400
    },
    db: mockShopDb
  });
  record("Valid PNG product upload without explicit targetId auto-resolves owner's shop",
    resValidPng.objectKey.startsWith(`providers/${callerSellerUid}/products/prod_`) &&
    resValidPng.objectKey.endsWith('.png')
  );

  // TEST 5: Unauthenticated request is rejected
  try {
    await validateAndGenerateUploadKey({
      auth: null,
      data: { folder: 'products', fileName: 'test.jpg', mimeType: 'image/jpeg', fileSize: 100 },
      db: mockShopDb
    });
    record("Unauthenticated request fails closed", false);
  } catch (e) {
    record("Unauthenticated request rejected with unauthenticated error", e.code === 'unauthenticated');
  }

  // TEST 6: Unsupported format (PDF) for products is rejected
  try {
    await validateAndGenerateUploadKey({
      auth: { uid: callerSellerUid },
      data: { folder: 'products', targetId: shopId, fileName: 'catalog.pdf', mimeType: 'application/pdf', fileSize: 1024 },
      db: mockShopDb
    });
    record("PDF rejected for product images", false);
  } catch (e) {
    record("PDF rejected for product images with invalid-argument", e.code === 'invalid-argument' && e.message.includes('Unsupported format'));
  }

  // TEST 7: Oversized product image (>8MB) is rejected
  try {
    await validateAndGenerateUploadKey({
      auth: { uid: callerSellerUid },
      data: { folder: 'products', targetId: shopId, fileName: 'giant.jpg', mimeType: 'image/jpeg', fileSize: 9 * 1024 * 1024 },
      db: mockShopDb
    });
    record("Oversized image rejected", false);
  } catch (e) {
    record("Oversized image (>8MB) rejected with invalid-argument", e.code === 'invalid-argument' && e.message.includes('exceeds maximum limit'));
  }

  // TEST 8: Cross-seller upload (seller A targeting seller B's shop) is strictly rejected
  try {
    await validateAndGenerateUploadKey({
      auth: { uid: callerSellerUid },
      data: { folder: 'products', targetId: 'other_shop', fileName: 'hacked.jpg', mimeType: 'image/jpeg', fileSize: 1024 },
      db: mockShopDb
    });
    record("Cross-seller upload rejected", false);
  } catch (e) {
    record("Cross-seller upload rejected with permission-denied", e.code === 'permission-denied' && e.message.includes('Unauthorized'));
  }

  // TEST 9: Unapproved shop is rejected
  try {
    await validateAndGenerateUploadKey({
      auth: { uid: callerSellerUid },
      data: { folder: 'products', targetId: 'unapproved_shop', fileName: 'prod.jpg', mimeType: 'image/jpeg', fileSize: 1024 },
      db: mockShopDb
    });
    record("Unapproved shop rejected", false);
  } catch (e) {
    record("Unapproved shop rejected with failed-precondition", e.code === 'failed-precondition' && e.message.includes('not approved'));
  }

  // TEST 10: Suspended shop is rejected
  try {
    await validateAndGenerateUploadKey({
      auth: { uid: callerSellerUid },
      data: { folder: 'products', targetId: 'suspended_shop', fileName: 'prod.jpg', mimeType: 'image/jpeg', fileSize: 1024 },
      db: mockShopDb
    });
    record("Suspended shop rejected", false);
  } catch (e) {
    record("Suspended shop rejected with permission-denied", e.code === 'permission-denied' && e.message.includes('suspended'));
  }

  // TEST 11: Deleted shop is rejected
  try {
    await validateAndGenerateUploadKey({
      auth: { uid: callerSellerUid },
      data: { folder: 'products', targetId: 'deleted_shop', fileName: 'prod.jpg', mimeType: 'image/jpeg', fileSize: 1024 },
      db: mockShopDb
    });
    record("Deleted shop rejected", false);
  } catch (e) {
    record("Deleted shop rejected with not-found", e.code === 'not-found');
  }

  // TEST 12: Inactive/expired subscription is rejected
  try {
    await validateAndGenerateUploadKey({
      auth: { uid: callerSellerUid },
      data: { folder: 'products', targetId: 'expired_sub_shop', fileName: 'prod.jpg', mimeType: 'image/jpeg', fileSize: 1024 },
      db: mockShopDb
    });
    record("Expired subscription rejected", false);
  } catch (e) {
    record("Expired subscription rejected with failed-precondition", e.code === 'failed-precondition' && e.message.includes('subscription is inactive or expired'));
  }

  // TEST 13: Non-existent shop is rejected
  try {
    await validateAndGenerateUploadKey({
      auth: { uid: 'non_seller_user' },
      data: { folder: 'products', targetId: 'fake_shop', fileName: 'prod.jpg', mimeType: 'image/jpeg', fileSize: 1024 },
      db: mockShopDb
    });
    record("Non-existent shop rejected", false);
  } catch (e) {
    record("Non-existent shop rejected with not-found", e.code === 'not-found');
  }

  // TEST 14: Path traversal attempt is neutralized
  const resPathTraversal = await validateAndGenerateUploadKey({
    auth: { uid: callerSellerUid },
    data: {
      folder: 'products',
      targetId: shopId,
      fileName: '../../../../etc/passwd.jpg',
      mimeType: 'image/jpeg',
      fileSize: 1024
    },
    db: mockShopDb
  });
  record("Path traversal filename neutralized into safe canonical server key",
    !resPathTraversal.objectKey.includes('..') &&
    resPathTraversal.objectKey.startsWith(`providers/${callerSellerUid}/products/prod_`)
  );

  // TEST 15: Dual-bucket isolation routes 'products' to public bucket
  const pubBucket = resolveBucketForFolder('products', 'jamui-services-public', 'jamui-services-private');
  record("Dual-bucket isolation correctly routes 'products' to public R2 bucket",
    pubBucket === 'jamui-services-public'
  );

  // TEST 16: Private documents (certificates, kyc) still route to private bucket
  const privBucketCerts = resolveBucketForFolder('certificates', 'jamui-services-public', 'jamui-services-private');
  const privBucketKyc = resolveBucketForFolder('kyc', 'jamui-services-public', 'jamui-services-private');
  record("Private documents (certificates, kyc) remain strictly isolated in private R2 bucket",
    privBucketCerts === 'jamui-services-private' && privBucketKyc === 'jamui-services-private'
  );

  console.log('\n================================================================');
  console.log(` RESULTS: ${passed}/${total} PROFESSIONAL SELLER R2 TESTS PASSED`);
  console.log('================================================================\n');
}

runTests().catch(err => {
  console.error('Test execution failed:', err);
  process.exit(1);
});

