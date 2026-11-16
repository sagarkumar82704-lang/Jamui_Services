const assert = require('assert');
const {
  validateAndGenerateUploadKey,
  generateR2PresignedPutUrl,
  verifyAndEnforceObjectLimits,
  handleStorageObjectDelete,
  reconcileProviderStorageUsage,
  resolveProviderStoragePlanLimits,
  DEFAULT_FREE_TIER_LIMITS
} = require('../r2_storage_upload_handler');

process.env.R2_BUCKET_NAME = 'test-public-bucket';
process.env.R2_PRIVATE_BUCKET_NAME = 'test-private-bucket';

console.log('================================================================');
console.log('  JAMUI SERVICES — R2 STORAGE QUOTA & SECURITY TEST SUITE       ');
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

  // --- MOCK DATABASE FACTORY ---
  function createMockDb({ providers = {}, plans = {}, listings = {}, storageObjects = {} }) {
    return {
      collection: (colName) => {
        return {
          doc: (docId) => {
            return {
              get: async () => {
                let data = null;
                if (colName === 'providers') data = providers[docId] || null;
                else if (colName === 'subscription_plans') data = plans[docId] || null;
                else if (colName === 'provider_listings') data = listings[docId] || null;

                return {
                  exists: !!data,
                  data: () => data
                };
              },
              update: async (fields) => {
                if (colName === 'providers') {
                  providers[docId] = { ...(providers[docId] || {}), ...fields };
                } else if (colName === 'provider_listings') {
                  listings[docId] = { ...(listings[docId] || {}), ...fields };
                }
                return true;
              },
              collection: (subColName) => {
                return {
                  doc: (subDocId) => ({
                    set: async (val) => {
                      if (!storageObjects[docId]) storageObjects[docId] = {};
                      storageObjects[docId][subDocId] = val;
                      return true;
                    },
                    delete: async () => {
                      if (storageObjects[docId]) delete storageObjects[docId][subDocId];
                      return true;
                    }
                  }),
                  where: (field, op, val) => ({
                    get: async () => {
                      const objs = storageObjects[docId] || {};
                      const matched = Object.values(objs).filter(item => item[field] === val);
                      return {
                        docs: matched.map(m => ({ data: () => m }))
                      };
                    }
                  })
                };
              }
            };
          }
        };
      }
    };
  }

  const mockAdminVerifier = async ({ auth }) => {
    if (auth.uid !== 'super_admin_1') {
      const err = new Error('Permission denied: not admin');
      err.code = 'permission-denied';
      throw err;
    }
    return { uid: auth.uid, role: 'super_admin' };
  };

  // -------------------------------------------------------------
  // GROUP 1: PLAN LIMIT RESOLUTION
  // -------------------------------------------------------------

  // Test 1: Unregistered or empty provider gets default free tier limits
  const freeLimits = await resolveProviderStoragePlanLimits({ db: null, providerId: null });
  record('Provider without profile receives default free tier limits',
    freeLimits.maxActiveListings === DEFAULT_FREE_TIER_LIMITS.maxActiveListings &&
    freeLimits.isPaidPlan === false
  );

  // Test 2: Expired subscription resolves to free tier limits
  const expiredMockDb = createMockDb({
    providers: {
      'prov_expired': {
        isSubscriptionActive: true,
        subscriptionPlan: 'plan_pro',
        subscriptionExpiry: new Date(Date.now() - 100000) // in the past
      }
    }
  });
  const expiredLimits = await resolveProviderStoragePlanLimits({ db: expiredMockDb, providerId: 'prov_expired' });
  record('Expired subscription correctly falls back to free tier limits',
    expiredLimits.isPaidPlan === false &&
    expiredLimits.maxTotalStorageBytes === DEFAULT_FREE_TIER_LIMITS.maxTotalStorageBytes
  );

  // Test 3: Active unexpired subscription resolves plan limits from DB
  const paidMockDb = createMockDb({
    providers: {
      'prov_active': {
        isSubscriptionActive: true,
        subscriptionPlan: 'plan_gold',
        subscriptionExpiry: new Date(Date.now() + 86400000 * 30) // 30 days future
      }
    },
    plans: {
      'plan_gold': {
        name: 'Gold Plan',
        maxActiveListings: 25,
        maxImagesPerProvider: 50,
        maxImagesPerListing: 8,
        maxSizePerImageBytes: 5 * 1024 * 1024,
        maxTotalStorageBytes: 100 * 1024 * 1024,
        isPremiumCategoryEligible: true
      }
    }
  });
  const goldLimits = await resolveProviderStoragePlanLimits({ db: paidMockDb, providerId: 'prov_active' });
  record('Active subscription correctly loads authoritative limits from plan',
    goldLimits.isPaidPlan === true &&
    goldLimits.maxTotalStorageBytes === 100 * 1024 * 1024 &&
    goldLimits.maxImagesPerProvider === 50 &&
    goldLimits.isPremiumCategoryEligible === true
  );

  // -------------------------------------------------------------
  // GROUP 2: UPLOAD KEY & QUOTA ENFORCEMENT
  // -------------------------------------------------------------

  // Test 4: Provider uploading when suspended is rejected
  const suspendedDb = createMockDb({
    providers: {
      'prov_suspended': {
        status: 'suspended'
      }
    }
  });
  try {
    await validateAndGenerateUploadKey({
      auth: { uid: 'prov_suspended' },
      data: { folder: 'business', fileName: 'shop.jpg', mimeType: 'image/jpeg', fileSize: 1024 },
      db: suspendedDb
    });
    record('Suspended provider upload rejected with permission-denied', false);
  } catch (e) {
    record('Suspended provider upload rejected with permission-denied', e.code === 'permission-denied');
  }

  // Test 5: Per-image file size exceeding plan limit is rejected
  const standardDb = createMockDb({
    providers: {
      'prov_free': {
        status: 'approved',
        isSubscriptionActive: false,
        storageUsage: { totalBytesUsed: 1000, totalImagesCount: 1 }
      }
    }
  });
  // Default free limit is 2MB (2 * 1024 * 1024)
  try {
    await validateAndGenerateUploadKey({
      auth: { uid: 'prov_free' },
      data: { folder: 'business', fileName: 'heavy.jpg', mimeType: 'image/jpeg', fileSize: 3 * 1024 * 1024 },
      db: standardDb
    });
    record('File size exceeding plan limit rejected with invalid-argument', false);
  } catch (e) {
    record('File size exceeding plan limit rejected with invalid-argument', e.code === 'invalid-argument');
  }

  // Test 6: Total storage byte quota exceeded is rejected
  const quotaFullDb = createMockDb({
    providers: {
      'prov_full': {
        status: 'approved',
        isSubscriptionActive: false,
        storageUsage: { totalBytesUsed: 5.5 * 1024 * 1024, totalImagesCount: 2 } // 5.5MB used out of 6MB
      }
    }
  });
  try {
    await validateAndGenerateUploadKey({
      auth: { uid: 'prov_full' },
      data: { folder: 'business', fileName: 'pic.jpg', mimeType: 'image/jpeg', fileSize: 1 * 1024 * 1024 }, // 1MB would exceed 6MB
      db: quotaFullDb
    });
    record('Storage byte quota exceeded rejected with resource-exhausted', false);
  } catch (e) {
    record('Storage byte quota exceeded rejected with resource-exhausted', e.code === 'resource-exhausted');
  }

  // Test 7: Total images count limit reached is rejected
  const countFullDb = createMockDb({
    providers: {
      'prov_images_max': {
        status: 'approved',
        isSubscriptionActive: false,
        storageUsage: { totalBytesUsed: 1024, totalImagesCount: 3 } // 3 images used (free limit is 3)
      }
    }
  });
  try {
    await validateAndGenerateUploadKey({
      auth: { uid: 'prov_images_max' },
      data: { folder: 'workplace', fileName: 'another.jpg', mimeType: 'image/jpeg', fileSize: 1024 },
      db: countFullDb
    });
    record('Image count limit exceeded rejected with resource-exhausted', false);
  } catch (e) {
    record('Image count limit exceeded rejected with resource-exhausted', e.code === 'resource-exhausted');
  }

  // Test 8: Valid listings upload generates canonical listing key
  const listingDb = createMockDb({
    providers: {
      'prov_seller': {
        status: 'approved',
        isSubscriptionActive: true,
        planLimits: {
          maxActiveListings: 10,
          maxImagesPerProvider: 20,
          maxImagesPerListing: 3,
          maxSizePerImageBytes: 4 * 1024 * 1024,
          maxTotalStorageBytes: 40 * 1024 * 1024
        },
        storageUsage: { totalBytesUsed: 1024, totalImagesCount: 1 }
      }
    },
    listings: {
      'list_item_123': {
        providerId: 'prov_seller',
        title: 'AC Repair Service',
        images: ['https://r2/img1.jpg']
      }
    }
  });

  const listingUpload = await validateAndGenerateUploadKey({
    auth: { uid: 'prov_seller' },
    data: {
      folder: 'listings',
      targetId: 'list_item_123',
      fileName: 'ac_unit.webp',
      mimeType: 'image/webp',
      fileSize: 500 * 1024
    },
    db: listingDb
  });
  record('Listings upload generates canonical key and reservation ID',
    listingUpload.objectKey.startsWith('providers/prov_seller/listings/list_item_123/img_') &&
    listingUpload.objectKey.endsWith('.webp') &&
    typeof listingUpload.reservationId === 'string'
  );

  // Test 9: Provider cannot upload image to another provider's listing
  const crossListingDb = createMockDb({
    providers: {
      'prov_intruder': {
        status: 'approved',
        storageUsage: { totalBytesUsed: 0, totalImagesCount: 0 }
      }
    },
    listings: {
      'list_victim_456': {
        providerId: 'prov_victim',
        images: []
      }
    }
  });
  try {
    await validateAndGenerateUploadKey({
      auth: { uid: 'prov_intruder' },
      data: {
        folder: 'listings',
        targetId: 'list_victim_456',
        fileName: 'hack.jpg',
        mimeType: 'image/jpeg',
        fileSize: 1024
      },
      db: crossListingDb
    });
    record('Cross-provider listing image upload rejected with permission-denied', false);
  } catch (e) {
    record('Cross-provider listing image upload rejected with permission-denied', e.code === 'permission-denied');
  }

  // Test 10: Listing exceeding maxImagesPerListing is rejected
  const listingFullDb = createMockDb({
    providers: {
      'prov_seller': {
        status: 'approved',
        isSubscriptionActive: true,
        planLimits: {
          maxImagesPerListing: 2,
          maxImagesPerProvider: 20,
          maxSizePerImageBytes: 4 * 1024 * 1024,
          maxTotalStorageBytes: 40 * 1024 * 1024
        },
        storageUsage: { totalBytesUsed: 1024, totalImagesCount: 2 }
      }
    },
    listings: {
      'list_item_full': {
        providerId: 'prov_seller',
        images: ['img1.jpg', 'img2.jpg'] // already 2
      }
    }
  });
  try {
    await validateAndGenerateUploadKey({
      auth: { uid: 'prov_seller' },
      data: {
        folder: 'listings',
        targetId: 'list_item_full',
        fileName: 'overflow.jpg',
        mimeType: 'image/jpeg',
        fileSize: 1024
      },
      db: listingFullDb
    });
    record('Listing exceeding maxImagesPerListing rejected with resource-exhausted', false);
  } catch (e) {
    record('Listing exceeding maxImagesPerListing rejected with resource-exhausted', e.code === 'resource-exhausted');
  }

  // -------------------------------------------------------------
  // GROUP 3: STORAGE DELETION & QUOTA RESTORATION
  // -------------------------------------------------------------

  // Test 11: Unauthenticated delete request rejected
  try {
    await handleStorageObjectDelete({
      auth: null,
      objectKey: 'providers/p1/business/shop.jpg'
    });
    record('Unauthenticated delete request rejected with unauthenticated', false);
  } catch (e) {
    record('Unauthenticated delete request rejected with unauthenticated', e.code === 'unauthenticated');
  }

  // Test 12: Provider deleting another provider's object rejected
  try {
    await handleStorageObjectDelete({
      auth: { uid: 'provider_attacker' },
      objectKey: 'providers/provider_victim/business/shop.jpg',
      verifyActiveAdminFn: mockAdminVerifier
    });
    record('Cross-provider deletion rejected with permission-denied', false);
  } catch (e) {
    record('Cross-provider deletion rejected with permission-denied', e.code === 'permission-denied');
  }

  // Test 13: Provider deleting own object succeeds and decrements Firestore usage
  const deleteDb = createMockDb({
    providers: {
      'prov_cleaner': {
        storageUsage: {
          totalBytesUsed: 2000000,
          totalImagesCount: 4
        }
      }
    }
  });

  const mockHttpSuccess = ({ method }, resolve) => {
    if (method === 'HEAD') {
      resolve({ statusCode: 200, headers: { 'content-length': '500000', 'content-type': 'image/jpeg' } });
    } else if (method === 'DELETE') {
      resolve({ statusCode: 204, headers: {} });
    }
  };

  const deleteRes = await handleStorageObjectDelete({
    auth: { uid: 'prov_cleaner' },
    objectKey: 'providers/prov_cleaner/business/old_pic.jpg',
    db: deleteDb,
    accountId: 'mock_acc',
    accessKeyId: 'mock_key',
    secretAccessKey: 'mock_sec',
    httpRequestFn: mockHttpSuccess
  });

  record('Provider deleting own object decrements byte quota and image count',
    deleteRes.success === true &&
    deleteRes.bytesFreed === 500000 &&
    deleteRes.storageUsage.totalBytesUsed === 1500000 &&
    deleteRes.storageUsage.totalImagesCount === 3
  );

  // Test 14: Admin can delete any provider's object and quota updates correctly
  const adminDeleteRes = await handleStorageObjectDelete({
    auth: { uid: 'super_admin_1' },
    objectKey: 'providers/prov_cleaner/business/admin_removed.jpg',
    verifyActiveAdminFn: mockAdminVerifier,
    db: deleteDb,
    accountId: 'mock_acc',
    accessKeyId: 'mock_key',
    secretAccessKey: 'mock_sec',
    httpRequestFn: mockHttpSuccess
  });
  record('Administrator can delete provider object with verified admin auth',
    adminDeleteRes.success === true
  );

  // Test 15: Deleting an object belonging to a listing removes it from listing images array
  const listingDeleteDb = createMockDb({
    providers: {
      'prov_seller': {
        storageUsage: { totalBytesUsed: 1000000, totalImagesCount: 2 }
      }
    },
    listings: {
      'list_cleaning_job': {
        providerId: 'prov_seller',
        images: ['providers/prov_seller/listings/list_cleaning_job/img_keep.jpg', 'providers/prov_seller/listings/list_cleaning_job/img_delete.jpg']
      }
    }
  });

  await handleStorageObjectDelete({
    auth: { uid: 'prov_seller' },
    objectKey: 'providers/prov_seller/listings/list_cleaning_job/img_delete.jpg',
    db: listingDeleteDb,
    accountId: 'mock_acc',
    accessKeyId: 'mock_key',
    secretAccessKey: 'mock_sec',
    httpRequestFn: mockHttpSuccess
  });

  // Verify listing doc now only has 1 image
  const updatedListingSnap = await listingDeleteDb.collection('provider_listings').doc('list_cleaning_job').get();
  const updatedListingData = updatedListingSnap.data();
  record('Deleting listing image automatically purges reference from listing images array',
    updatedListingData.images.length === 1 &&
    !updatedListingData.images[0].includes('img_delete')
  );

  // -------------------------------------------------------------
  // GROUP 4: STORAGE RECONCILIATION
  // -------------------------------------------------------------

  // Test 16: Reconciliation computes exact bytes and active objects count
  const reconcileDb = createMockDb({
    providers: {
      'prov_reconcile': {
        storageUsage: { totalBytesUsed: 999999, totalImagesCount: 99 } // corrupted/desynced
      }
    },
    storageObjects: {
      'prov_reconcile': {
        'obj1': { sizeBytes: 250000, status: 'active' },
        'obj2': { sizeBytes: 350000, status: 'active' },
        'obj3': { sizeBytes: 100000, status: 'deleted' } // should be ignored
      }
    }
  });

  const reconciledUsage = await reconcileProviderStorageUsage({ db: reconcileDb, providerId: 'prov_reconcile' });
  record('Reconciliation restores true total bytes (600,000) and image count (2)',
    reconciledUsage.totalBytesUsed === 600000 &&
    reconciledUsage.totalImagesCount === 2 &&
    reconciledUsage.reservedBytes === 0
  );

  console.log('\n================================================================');
  console.log(` RESULTS: ${passed}/${total} STORAGE QUOTA & SECURITY TESTS PASSED`);
  console.log('================================================================\n');
}

runTests().catch(err => {
  console.error('Test execution error:', err);
  process.exit(1);
});
