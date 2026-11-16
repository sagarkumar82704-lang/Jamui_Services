const crypto = require('crypto');
const https = require('https');

/**
 * Jamui Services - Cloudflare R2 Upload Infrastructure & Security Validator
 *
 * Enforces:
 * 1. Strict caller authentication.
 * 2. Role-based ownership validation (Admin for categories/banners, Provider for profile/biz, Customer for reviews).
 * 3. MIME allowlist (JPEG, PNG, WebP only).
 * 4. Maximum size cap (8MB).
 * 5. Explicit rejection of KYC / Aadhaar / private documents.
 * 6. Server-generated safe object keys (zero path traversal).
 * 7. Short-lived S3/R2 SigV4 Presigned PUT URL generation.
 */

const ALLOWED_MIME_TYPES = Object.freeze([
  'image/jpeg',
  'image/jpg',
  'image/png',
  'image/webp',
  'application/pdf'
]);

const MAX_FILE_SIZE_BYTES = 8 * 1024 * 1024; // 8 MB

const ALLOWED_FOLDERS = Object.freeze([
  'categories',
  'banners',
  'profile',
  'business',
  'workplace',
  'reviews',
  'certificates',
  'kyc',
  'listings',
  'products'
]);

const DEFAULT_FREE_TIER_LIMITS = Object.freeze({
  maxActiveListings: 1,
  maxImagesPerProvider: 3,
  maxImagesPerListing: 2,
  maxSizePerImageBytes: 2 * 1024 * 1024, // 2MB
  maxTotalStorageBytes: 6 * 1024 * 1024, // 6MB
  isPremiumCategoryEligible: false
});

/**
 * Resolves authoritative plan limits for a provider.
 * Checks subscription status, expiry, and retrieves limits from plan snapshot or default free tier.
 */
async function resolveProviderStoragePlanLimits({ db, providerId, providerData = null }) {
  if (!providerId) {
    return { ...DEFAULT_FREE_TIER_LIMITS, planId: 'default_free', isPaidPlan: false };
  }

  let pData = providerData;
  if (!pData && db) {
    try {
      const pSnap = await db.collection('providers').doc(providerId).get();
      pData = (typeof pSnap?.data === 'function' ? pSnap.data() : pSnap?.data) || null;
    } catch (_) {
      pData = null;
    }
  }

  if (!pData) {
    return { ...DEFAULT_FREE_TIER_LIMITS, planId: 'default_free', isPaidPlan: false };
  }

  // If provider has an active subscription, check expiry
  const isSubActive = pData.isSubscriptionActive === true;
  let isExpired = false;
  if (pData.subscriptionExpiry) {
    const expiryDate = pData.subscriptionExpiry.toDate
      ? pData.subscriptionExpiry.toDate()
      : new Date(pData.subscriptionExpiry);
    if (expiryDate.getTime() < Date.now()) {
      isExpired = true;
    }
  }

  const planId = pData.subscriptionPlan;
  if (isSubActive && !isExpired && planId && planId !== 'none' && planId !== 'free_trial') {
    // Check if plan limits are already snapshotted in provider data
    if (pData.planLimits && typeof pData.planLimits === 'object') {
      return {
        maxActiveListings: Number(pData.planLimits.maxActiveListings || 10),
        maxImagesPerProvider: Number(pData.planLimits.maxImagesPerProvider || 20),
        maxImagesPerListing: Number(pData.planLimits.maxImagesPerListing || 5),
        maxSizePerImageBytes: Number(pData.planLimits.maxSizePerImageBytes || (5 * 1024 * 1024)),
        maxTotalStorageBytes: Number(pData.planLimits.maxTotalStorageBytes || (50 * 1024 * 1024)),
        isPremiumCategoryEligible: pData.planLimits.isPremiumCategoryEligible === true,
        planId: planId,
        isPaidPlan: true
      };
    }

    // Fetch plan doc from Firestore if db is available
    if (db) {
      try {
        const planSnap = await db.collection('subscription_plans').doc(planId).get();
        if (planSnap && planSnap.exists) {
          const planData = (typeof planSnap.data === 'function' ? planSnap.data() : planSnap.data) || {};
          return {
            maxActiveListings: Number(planData.maxActiveListings || 10),
            maxImagesPerProvider: Number(planData.maxImagesPerProvider || 20),
            maxImagesPerListing: Number(planData.maxImagesPerListing || 5),
            maxSizePerImageBytes: Number(planData.maxSizePerImageBytes || (5 * 1024 * 1024)),
            maxTotalStorageBytes: Number(planData.maxTotalStorageBytes || (50 * 1024 * 1024)),
            isPremiumCategoryEligible: planData.isPremiumCategoryEligible === true,
            planId: planId,
            isPaidPlan: true
          };
        }
      } catch (_) {}
    }
  }

  return { ...DEFAULT_FREE_TIER_LIMITS, planId: 'free_tier', isPaidPlan: false };
}

const DISALLOWED_FOLDERS = Object.freeze([
  'kyc_documents',
  'aadhaar',
  'pan_card',
  'pan',
  'identity_proofs',
  'identity'
]);

/**
 * Sanitizes arbitrary input string into a safe alphanumeric/hyphen ID.
 */
function sanitizeIdentifier(input, fallback = 'default') {
  if (!input || typeof input !== 'string') return fallback;
  const clean = input.replace(/[^a-zA-Z0-9_\-]/g, '').trim();
  return clean.length > 0 ? clean : fallback;
}

/**
 * Extracts and sanitizes allowed image extension.
 */
function sanitizeExtension(fileName, mimeType) {
  let ext = 'jpg';
  if (fileName && typeof fileName === 'string' && fileName.includes('.')) {
    const rawExt = fileName.split('.').pop().toLowerCase().trim();
    if (['jpg', 'jpeg', 'png', 'webp', 'pdf'].includes(rawExt)) {
      ext = rawExt === 'jpeg' ? 'jpg' : rawExt;
    }
  } else if (mimeType && typeof mimeType === 'string') {
    const m = mimeType.toLowerCase().trim();
    if (m === 'image/png') ext = 'png';
    else if (m === 'image/webp') ext = 'webp';
    else if (m === 'application/pdf') ext = 'pdf';
    else if (m === 'image/jpeg' || m === 'image/jpg') ext = 'jpg';
  }
  return ext;
}

/**
 * Validates the upload request and generates a canonical, server-side object key.
 */
async function validateAndGenerateUploadKey({ auth, data, verifyActiveAdminFn, db }) {
  // 1. Authenticated user validation
  if (!auth || !auth.uid) {
    const err = new Error('User must be authenticated to upload media.');
    err.code = 'unauthenticated';
    throw err;
  }
  const callerUid = auth.uid;

  const folder = (data?.folder || '').toString().toLowerCase().trim();
  const rawFileName = (data?.fileName || '').toString().trim();
  const mimeType = (data?.mimeType || '').toString().toLowerCase().trim();
  const fileSize = Number(data?.fileSize || 0);
  const targetId = data?.targetId ? String(data.targetId).trim() : '';

  // 2. Strict rejection of arbitrary identity documents (Aadhaar, PAN, raw identity proofs)
  if (DISALLOWED_FOLDERS.includes(folder) || folder.includes('aadhaar') || folder.includes('pan')) {
    const err = new Error('Aadhaar, PAN, and unverified identity document uploads to public R2 storage are strictly prohibited.');
    err.code = 'invalid-argument';
    throw err;
  }

  // 3. Folder allowlist validation
  if (!ALLOWED_FOLDERS.includes(folder)) {
    const err = new Error(`Invalid upload folder '${folder}'. Allowed: ${ALLOWED_FOLDERS.join(', ')}.`);
    err.code = 'invalid-argument';
    throw err;
  }

  // 4. MIME type validation (Photos strictly JPEG/PNG/WebP; Certificates/KYC can also be PDF)
  const isDocFolder = folder === 'certificates' || folder === 'kyc';
  const allowedMimes = isDocFolder
    ? ['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'application/pdf']
    : ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];

  if (!allowedMimes.includes(mimeType)) {
    const err = new Error(`Unsupported format '${mimeType}' for folder '${folder}'. Allowed: ${allowedMimes.join(', ')}.`);
    err.code = 'invalid-argument';
    throw err;
  }

  // 5. File size validation
  if (isNaN(fileSize) || fileSize <= 0) {
    const err = new Error('Invalid fileSize: must be a positive number of bytes.');
    err.code = 'invalid-argument';
    throw err;
  }
  if (fileSize > MAX_FILE_SIZE_BYTES) {
    const err = new Error(`File size (${fileSize} bytes) exceeds maximum limit of 8MB.`);
    err.code = 'invalid-argument';
    throw err;
  }

  // 6. Role & Ownership Authorization
  const timestamp = Date.now();
  const randomSuffix = crypto.randomBytes(4).toString('hex');
  const ext = sanitizeExtension(rawFileName, mimeType);
  let objectKey = '';

  if (folder === 'categories') {
    // Must be admin
    if (typeof verifyActiveAdminFn === 'function') {
      await verifyActiveAdminFn({ auth });
    }
    const safeCatId = sanitizeIdentifier(targetId, `cat_${timestamp}`);
    objectKey = `categories/${safeCatId}/cover_${timestamp}_${randomSuffix}.${ext}`;

  } else if (folder === 'banners') {
    // Must be admin
    if (typeof verifyActiveAdminFn === 'function') {
      await verifyActiveAdminFn({ auth });
    }
    const safeBannerId = sanitizeIdentifier(targetId, `banner_${timestamp}`);
    objectKey = `banners/${safeBannerId}/banner_${timestamp}_${randomSuffix}.${ext}`;

  } else if (folder === 'profile') {
    // Caller can only upload for their own UID
    if (targetId && targetId !== callerUid) {
      const err = new Error('Unauthorized: You can only upload profile photos for your own user account.');
      err.code = 'permission-denied';
      throw err;
    }
    objectKey = `providers/${callerUid}/profile/profile_${timestamp}_${randomSuffix}.${ext}`;

  } else if (folder === 'business' || folder === 'workplace' || folder === 'listings') {
    if (folder === 'listings') {
      const safeListingId = sanitizeIdentifier(targetId, `list_${timestamp}`);
      objectKey = `providers/${callerUid}/listings/${safeListingId}/img_${timestamp}_${randomSuffix}.${ext}`;
    } else {
      // Provider uploading for own profile
      if (targetId && targetId !== callerUid) {
        const err = new Error(`Unauthorized: You can only upload ${folder} photos for your own provider account.`);
        err.code = 'permission-denied';
        throw err;
      }
      objectKey = `providers/${callerUid}/${folder}/${folder}_${timestamp}_${randomSuffix}.${ext}`;
    }

  } else if (folder === 'certificates' || folder === 'kyc') {
    // Sensitive verification documents: Only authenticated provider for their own UID
    if (targetId && targetId !== callerUid) {
      const err = new Error(`Unauthorized: You can only upload ${folder} documents for your own provider account.`);
      err.code = 'permission-denied';
      throw err;
    }
    objectKey = `providers/${callerUid}/${folder}/${folder}_${timestamp}_${randomSuffix}.${ext}`;

  } else if (folder === 'reviews') {
    // Customer uploading review photos for a completed booking/lead
    const cleanBookingId = sanitizeIdentifier(targetId, '');
    if (!cleanBookingId) {
      const err = new Error('A valid booking ID (targetId) is required for customer review photo uploads.');
      err.code = 'invalid-argument';
      throw err;
    }

    if (!db) {
      const err = new Error('Database service unavailable for booking validation.');
      err.code = 'failed-precondition';
      throw err;
    }

    let bookingSnap;
    try {
      bookingSnap = await db.collection('leads').doc(cleanBookingId).get();
    } catch (e) {
      const err = new Error(`Database error while verifying booking eligibility: ${e?.message || e}`);
      err.code = 'unavailable';
      throw err;
    }

    if (!bookingSnap || !bookingSnap.exists) {
      const err = new Error(`Booking '${cleanBookingId}' does not exist.`);
      err.code = 'not-found';
      throw err;
    }

    const bookingData = (typeof bookingSnap.data === 'function' ? bookingSnap.data() : bookingSnap.data) || {};
    const bookingCustomerUid = (bookingData.customerId || bookingData.customerUid || '').toString().trim();
    if (!bookingCustomerUid || bookingCustomerUid !== callerUid) {
      const err = new Error('Unauthorized: You can only upload review photos for your own bookings.');
      err.code = 'permission-denied';
      throw err;
    }

    const bookingStatus = (bookingData.status || '').toString().toLowerCase().trim();
    if (bookingStatus !== 'completed') {
      const err = new Error(`Booking is not eligible for review. Current status is '${bookingStatus || 'unknown'}', but reviews are only permitted for 'completed' bookings.`);
      err.code = 'failed-precondition';
      throw err;
    }

    objectKey = `reviews/${callerUid}/${cleanBookingId}/rev_${timestamp}_${randomSuffix}.${ext}`;
  } else if (folder === 'products') {
    // Professional Seller uploading product images for marketplace store
    if (!db) {
      const err = new Error('Database service unavailable for shop validation.');
      err.code = 'failed-precondition';
      throw err;
    }

    let shopSnap = null;
    const cleanTargetShopId = sanitizeIdentifier(targetId, '');

    // 1. Resolve Shop Record by targetId, ownerUid, or direct doc ID
    if (cleanTargetShopId) {
      try {
        shopSnap = await db.collection('diamond_shops').doc(cleanTargetShopId).get();
        if (!shopSnap.exists) {
          const err = new Error(`Professional shop '${cleanTargetShopId}' not found.`);
          err.code = 'not-found';
          throw err;
        }
      } catch (e) {
        if (e.code === 'not-found') throw e;
        const err = new Error(`Database error while retrieving shop: ${e?.message || e}`);
        err.code = 'unavailable';
        throw err;
      }
    } else {
      // Auto-resolve caller's shop when targetId is not explicitly specified
      try {
        const querySnap = await db.collection('diamond_shops').where('ownerUid', '==', callerUid).limit(1).get();
        if (!querySnap.empty) {
          shopSnap = querySnap.docs[0];
        } else {
          shopSnap = await db.collection('diamond_shops').doc(callerUid).get();
        }
      } catch (e) {
        const err = new Error(`Database error while querying seller shop: ${e?.message || e}`);
        err.code = 'unavailable';
        throw err;
      }
    }

    if (!shopSnap || !shopSnap.exists) {
      const err = new Error('Professional shop account not found. Only registered professional sellers can upload product media.');
      err.code = 'not-found';
      throw err;
    }

    const shopData = (typeof shopSnap.data === 'function' ? shopSnap.data() : shopSnap.data) || {};
    const effectiveShopId = shopSnap.id;

    // 2. Ownership Verification
    const shopOwnerUid = (shopData.ownerUid || effectiveShopId || '').toString().trim();
    if (shopOwnerUid !== callerUid && effectiveShopId !== callerUid) {
      let isCallerAdmin = false;
      if (typeof verifyActiveAdminFn === 'function') {
        try {
          await verifyActiveAdminFn({ auth });
          isCallerAdmin = true;
        } catch (_) {
          isCallerAdmin = false;
        }
      }
      if (!isCallerAdmin) {
        const err = new Error('Unauthorized: You can only upload product images for your own professional shop.');
        err.code = 'permission-denied';
        throw err;
      }
    }

    // 3. Shop Status and Approval Verification
    if (shopData.isDeleted === true) {
      const err = new Error('Shop has been deleted.');
      err.code = 'not-found';
      throw err;
    }

    const shopStatus = (shopData.status || '').toString().toLowerCase().trim();
    if (shopStatus === 'suspended' || shopStatus === 'blocked' || shopStatus === 'rejected') {
      const err = new Error(`Shop account is ${shopStatus}. Product image uploads are suspended.`);
      err.code = 'permission-denied';
      throw err;
    }

    if (shopData.isActive === false) {
      const err = new Error('Shop account is inactive. Product image uploads are not permitted.');
      err.code = 'failed-precondition';
      throw err;
    }

    const isApproved = shopData.isApproved === true || shopStatus === 'approved';
    if (!isApproved) {
      const err = new Error('Shop is not approved by administrator. Product image uploads require an approved shop.');
      err.code = 'failed-precondition';
      throw err;
    }

    // 4. Subscription Status Verification
    if (shopData.isSubscriptionActive !== true) {
      const expiry = shopData.subscriptionExpiry;
      let expDate = null;
      if (expiry && typeof expiry.toDate === 'function') expDate = expiry.toDate();
      else if (expiry instanceof Date) expDate = expiry;
      else if (expiry) expDate = new Date(expiry);

      if (!expDate || expDate.getTime() < Date.now()) {
        const err = new Error('Shop subscription is inactive or expired. Please activate your subscription to upload products.');
        err.code = 'failed-precondition';
        throw err;
      }
    }

    // 5. Generate Safe Server-Controlled Object Key (Public Bucket)
    objectKey = `providers/${callerUid}/products/prod_${timestamp}_${randomSuffix}.${ext}`;
  }

  // 7. Server-Side Plan Quota & Limits Enforcement for Provider Media
  let reservationId = null;
  let resolvedLimits = null;
  const isProviderMediaFolder = ['profile', 'business', 'workplace', 'listings'].includes(folder);

  if (isProviderMediaFolder && db) {
    let provDoc;
    try {
      provDoc = await db.collection('providers').doc(callerUid).get();
    } catch (e) {
      const err = new Error(`Database error while checking provider account: ${e?.message || e}`);
      err.code = 'unavailable';
      throw err;
    }

    if (!provDoc || !provDoc.exists) {
      const err = new Error('Provider account does not exist. Only registered providers can upload business media.');
      err.code = 'not-found';
      throw err;
    }

    const provData = (typeof provDoc.data === 'function' ? provDoc.data() : provDoc.data) || {};
    if (provData.status === 'suspended' || provData.status === 'blocked' || provData.isBlocked === true || provData.isDeleted === true) {
      const err = new Error('Provider account is suspended, blocked, or inactive.');
      err.code = 'permission-denied';
      throw err;
    }

    resolvedLimits = await resolveProviderStoragePlanLimits({ db, providerId: callerUid, providerData: provData });

    // Enforce per-image size limit from plan
    if (fileSize > resolvedLimits.maxSizePerImageBytes) {
      const maxMb = (resolvedLimits.maxSizePerImageBytes / (1024 * 1024)).toFixed(1);
      const err = new Error(`File size (${(fileSize / (1024 * 1024)).toFixed(2)} MB) exceeds the plan limit of ${maxMb} MB per image.`);
      err.code = 'invalid-argument';
      throw err;
    }

    // Enforce total storage bytes quota and total image count
    const storageUsage = provData.storageUsage || {};
    const totalBytesUsed = Number(storageUsage.totalBytesUsed || 0);
    const reservedBytes = Number(storageUsage.reservedBytes || 0);
    const totalImagesCount = Number(storageUsage.totalImagesCount || 0);

    if (totalBytesUsed + reservedBytes + fileSize > resolvedLimits.maxTotalStorageBytes) {
      const maxStorageMb = Math.round(resolvedLimits.maxTotalStorageBytes / (1024 * 1024));
      const usedStorageMb = ((totalBytesUsed + reservedBytes) / (1024 * 1024)).toFixed(2);
      const err = new Error(`Storage quota exceeded (${usedStorageMb} MB / ${maxStorageMb} MB used). Please upgrade your subscription plan or delete old images.`);
      err.code = 'resource-exhausted';
      throw err;
    }

    if (totalImagesCount + 1 > resolvedLimits.maxImagesPerProvider) {
      const err = new Error(`Maximum image count reached (${totalImagesCount}/${resolvedLimits.maxImagesPerProvider} images). Please upgrade your subscription plan or delete unused images.`);
      err.code = 'resource-exhausted';
      throw err;
    }

    // Enforce listing images limit if uploading for a specific listing
    if (folder === 'listings' && targetId && targetId !== callerUid) {
      const cleanListingId = sanitizeIdentifier(targetId, '');
      if (cleanListingId) {
        try {
          const listSnap = await db.collection('provider_listings').doc(cleanListingId).get();
          if (listSnap && listSnap.exists) {
            const listData = (typeof listSnap.data === 'function' ? listSnap.data() : listSnap.data) || {};
            if (listData.providerId && listData.providerId !== callerUid) {
              const err = new Error('Unauthorized: You cannot upload images to another provider’s listing.');
              err.code = 'permission-denied';
              throw err;
            }
            const existingImages = Array.isArray(listData.images) ? listData.images : [];
            if (existingImages.length >= resolvedLimits.maxImagesPerListing) {
              const err = new Error(`Maximum images per listing reached (${existingImages.length}/${resolvedLimits.maxImagesPerListing}). Cannot add more images to this listing.`);
              err.code = 'resource-exhausted';
              throw err;
            }
          }
        } catch (e) {
          if (e.code === 'permission-denied' || e.code === 'resource-exhausted') throw e;
        }
      }
    }

    // Concurrency reservation & Idempotency
    reservationId = `res_${timestamp}_${randomSuffix}`;
    try {
      const provRef = db.collection('providers').doc(callerUid);
      if (typeof provRef.collection === 'function') {
        const resRef = provRef.collection('storage_reservations').doc(reservationId);
        if (typeof resRef.set === 'function') {
          await resRef.set({
            reservationId,
            objectKey,
            fileSize,
            folder,
            status: 'reserved',
            createdAt: new Date(),
            expiresAt: new Date(Date.now() + 15 * 60 * 1000)
          });
        }
      }
      if (typeof provRef.update === 'function') {
        await provRef.update({
          'storageUsage.reservedBytes': reservedBytes + fileSize
        });
      }
    } catch (_) {}
  }

  return {
    objectKey,
    mimeType,
    fileSize,
    folder,
    callerUid,
    isPrivate: isDocFolder,
    bucketType: isDocFolder ? 'private' : 'public',
    reservationId,
    resolvedLimits
  };
}

/**
 * Generates an AWS Signature Version 4 Presigned PUT URL for Cloudflare R2.
 * Pure Node.js 20 Web Crypto implementation (Zero external dependencies).
 */
function generateR2PresignedPutUrl({
  accountId,
  accessKeyId,
  secretAccessKey,
  bucketName,
  objectKey,
  mimeType,
  fileSize,
  expiresInSeconds = 600 // 10 minutes
}) {
  const acc = typeof accountId === 'string' ? accountId.trim() : '';
  const key = typeof accessKeyId === 'string' ? accessKeyId.trim() : '';
  const sec = typeof secretAccessKey === 'string' ? secretAccessKey.trim() : '';
  const bkt = typeof bucketName === 'string' ? bucketName.trim() : '';

  if (!acc || !key || !sec || !bkt) {
    const err = new Error('R2 configuration secrets are incomplete or empty. Check R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, and R2_BUCKET_NAME.');
    err.code = 'failed-precondition';
    throw err;
  }

  const host = `${acc}.r2.cloudflarestorage.com`;
  const region = 'auto';
  const service = 's3';

  const now = new Date();
  const amzDate = now.toISOString().replace(/[:-]|\.\d{3}/g, ''); // YYYYMMDDTHHMMSSZ
  const dateStamp = amzDate.substring(0, 8); // YYYYMMDD
  const credentialScope = `${dateStamp}/${region}/${service}/aws4_request`;

  // Standard SigV4 canonical headers and query string (Cloudflare R2 S3 API expects /<bucketName>/<objectKey>)
  const cleanKey = objectKey.startsWith('/') ? objectKey.substring(1) : objectKey;
  const canonicalUri = `/${bucketName.trim()}/${cleanKey.split('/').map(encodeURIComponent).join('/')}`;

  // Standard SigV4 signed headers for web browser compatibility.
  // WHATWG fetch strictly forbids manual Content-Length headers in browsers.
  // Upload size (<= 8MB) is strictly validated on the server in validateAndGenerateUploadKey.
  const signedHeaders = 'content-type;host';
  const canonicalHeaders = `content-type:${mimeType.trim()}\nhost:${host}\n`;

  const queryParams = [
    `X-Amz-Algorithm=AWS4-HMAC-SHA256`,
    `X-Amz-Credential=${encodeURIComponent(`${accessKeyId.trim()}/${credentialScope}`)}`,
    `X-Amz-Date=${amzDate}`,
    `X-Amz-Expires=${expiresInSeconds}`,
    `X-Amz-SignedHeaders=${encodeURIComponent(signedHeaders)}`
  ];
  queryParams.sort();
  const canonicalQuery = queryParams.join('&');
  const payloadHash = 'UNSIGNED-PAYLOAD';

  const canonicalRequest = [
    'PUT',
    canonicalUri,
    canonicalQuery,
    canonicalHeaders,
    signedHeaders,
    payloadHash
  ].join('\n');

  const stringToSign = [
    'AWS4-HMAC-SHA256',
    amzDate,
    credentialScope,
    crypto.createHash('sha256').update(canonicalRequest, 'utf8').digest('hex')
  ].join('\n');

  // Derive signing key
  function hmac(key, str) {
    return crypto.createHmac('sha256', key).update(str, 'utf8').digest();
  }

  const kDate = hmac(`AWS4${secretAccessKey.trim()}`, dateStamp);
  const kRegion = hmac(kDate, region);
  const kService = hmac(kRegion, service);
  const kSigning = hmac(kService, 'aws4_request');

  const signature = crypto.createHmac('sha256', kSigning).update(stringToSign, 'utf8').digest('hex');

  const uploadUrl = `https://${host}${canonicalUri}?${canonicalQuery}&X-Amz-Signature=${signature}`;

  return {
    uploadUrl,
    objectKey: cleanKey,
    expiresInSeconds,
    requiredHeaders: {
      'Content-Type': mimeType.trim()
    }
  };
}

/**
 * Generates an AWS Signature Version 4 Presigned GET URL for Cloudflare R2.
 * Pure Node.js Web Crypto implementation.
 */
function generateR2PresignedGetUrl({
  accountId,
  accessKeyId,
  secretAccessKey,
  bucketName,
  objectKey,
  expiresInSeconds = 600 // 10 minutes
}) {
  const acc = typeof accountId === 'string' ? accountId.trim() : '';
  const key = typeof accessKeyId === 'string' ? accessKeyId.trim() : '';
  const sec = typeof secretAccessKey === 'string' ? secretAccessKey.trim() : '';
  const bkt = typeof bucketName === 'string' ? bucketName.trim() : '';

  if (!acc || !key || !sec || !bkt) {
    const err = new Error('R2 configuration secrets are incomplete or empty. Check R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, and R2_BUCKET_NAME.');
    err.code = 'failed-precondition';
    throw err;
  }

  const host = `${acc}.r2.cloudflarestorage.com`;
  const region = 'auto';
  const service = 's3';

  const now = new Date();
  const amzDate = now.toISOString().replace(/[:-]|\.\d{3}/g, '');
  const dateStamp = amzDate.substring(0, 8);
  const credentialScope = `${dateStamp}/${region}/${service}/aws4_request`;

  const cleanKey = objectKey.startsWith('/') ? objectKey.substring(1) : objectKey;
  const canonicalUri = `/${bucketName.trim()}/${cleanKey.split('/').map(encodeURIComponent).join('/')}`;

  const signedHeaders = 'host';
  const canonicalHeaders = `host:${host}\n`;

  const queryParams = [
    `X-Amz-Algorithm=AWS4-HMAC-SHA256`,
    `X-Amz-Credential=${encodeURIComponent(`${accessKeyId.trim()}/${credentialScope}`)}`,
    `X-Amz-Date=${amzDate}`,
    `X-Amz-Expires=${expiresInSeconds}`,
    `X-Amz-SignedHeaders=${encodeURIComponent(signedHeaders)}`
  ];
  queryParams.sort();
  const canonicalQuery = queryParams.join('&');
  const payloadHash = 'UNSIGNED-PAYLOAD';

  const canonicalRequest = [
    'GET',
    canonicalUri,
    canonicalQuery,
    canonicalHeaders,
    signedHeaders,
    payloadHash
  ].join('\n');

  const stringToSign = [
    'AWS4-HMAC-SHA256',
    amzDate,
    credentialScope,
    crypto.createHash('sha256').update(canonicalRequest, 'utf8').digest('hex')
  ].join('\n');

  function hmac(key, str) {
    return crypto.createHmac('sha256', key).update(str, 'utf8').digest();
  }

  const kDate = hmac(`AWS4${secretAccessKey.trim()}`, dateStamp);
  const kRegion = hmac(kDate, region);
  const kService = hmac(kRegion, service);
  const kSigning = hmac(kService, 'aws4_request');

  const signature = crypto.createHmac('sha256', kSigning).update(stringToSign, 'utf8').digest('hex');

  const viewUrl = `https://${host}${canonicalUri}?${canonicalQuery}&X-Amz-Signature=${signature}`;

  return {
    viewUrl,
    objectKey: cleanKey,
    expiresInSeconds
  };
}

function isPrivateFolder(folder) {
  return folder === 'certificates' || folder === 'kyc';
}

function resolveBucketForFolder(folder, publicBucket, privateBucket) {
  const isPrivate = isPrivateFolder(folder);
  const effectivePub = typeof publicBucket === 'string' ? publicBucket.trim() : (process.env.R2_BUCKET_NAME || '').trim();
  const effectivePriv = typeof privateBucket === 'string' ? privateBucket.trim() : (process.env.R2_PRIVATE_BUCKET_NAME || '').trim();
  const target = isPrivate ? effectivePriv : effectivePub;

  if (!target) {
    const bucketType = isPrivate ? 'R2_PRIVATE_BUCKET_NAME' : 'R2_BUCKET_NAME';
    const err = new Error(`R2 configuration error: Missing or empty ${bucketType} for folder '${folder}'. Production fallback is strictly disabled.`);
    err.code = 'failed-precondition';
    throw err;
  }
  return target;
}

function resolveBucketForObjectKey(objectKey, publicBucket, privateBucket) {
  const effectivePub = typeof publicBucket === 'string' ? publicBucket.trim() : (process.env.R2_BUCKET_NAME || '').trim();
  const effectivePriv = typeof privateBucket === 'string' ? privateBucket.trim() : (process.env.R2_PRIVATE_BUCKET_NAME || '').trim();

  if (!objectKey || typeof objectKey !== 'string') {
    if (!effectivePub) {
      const err = new Error('R2 configuration error: Missing or empty R2_BUCKET_NAME. Production fallback is strictly disabled.');
      err.code = 'failed-precondition';
      throw err;
    }
    return effectivePub;
  }
  const cleanKey = objectKey.startsWith('/') ? objectKey.substring(1) : objectKey;
  const isPrivate = cleanKey.includes('/certificates/') || cleanKey.includes('/kyc/');
  const target = isPrivate ? effectivePriv : effectivePub;

  if (!target) {
    const bucketType = isPrivate ? 'R2_PRIVATE_BUCKET_NAME' : 'R2_BUCKET_NAME';
    const err = new Error(`R2 configuration error: Missing or empty ${bucketType} for key '${objectKey}'. Production fallback is strictly disabled.`);
    err.code = 'failed-precondition';
    throw err;
  }
  return target;
}

/**
 * Performs an authenticated AWS SigV4 request (HEAD or DELETE) against Cloudflare R2 S3 API.
 */
function makeSigV4Request({ method, accountId, accessKeyId, secretAccessKey, bucketName, objectKey, httpRequestFn = null }) {
  return new Promise((resolve, reject) => {
    const acc = typeof accountId === 'string' ? accountId.trim() : '';
    const key = typeof accessKeyId === 'string' ? accessKeyId.trim() : '';
    const sec = typeof secretAccessKey === 'string' ? secretAccessKey.trim() : '';
    const bkt = typeof bucketName === 'string' ? bucketName.trim() : '';

    if (!acc || !key || !sec || !bkt) {
      const err = new Error('R2 configuration secrets are incomplete or empty. Production fallback is strictly disabled.');
      err.code = 'failed-precondition';
      return reject(err);
    }

    const host = `${acc}.r2.cloudflarestorage.com`;
    const region = 'auto';
    const service = 's3';

    const now = new Date();
    const amzDate = now.toISOString().replace(/[:-]|\.\d{3}/g, '');
    const dateStamp = amzDate.substring(0, 8);
    const credentialScope = `${dateStamp}/${region}/${service}/aws4_request`;

    const cleanKey = objectKey.startsWith('/') ? objectKey.substring(1) : objectKey;
    const canonicalUri = `/${bucketName.trim()}/${cleanKey.split('/').map(encodeURIComponent).join('/')}`;

    const payloadHash = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'; // SHA-256 of empty string
    const signedHeaders = 'host;x-amz-content-sha256;x-amz-date';
    const canonicalHeaders = `host:${host}\nx-amz-content-sha256:${payloadHash}\nx-amz-date:${amzDate}\n`;
    const canonicalQuery = '';

    const canonicalRequest = [
      method,
      canonicalUri,
      canonicalQuery,
      canonicalHeaders,
      signedHeaders,
      payloadHash
    ].join('\n');

    const stringToSign = [
      'AWS4-HMAC-SHA256',
      amzDate,
      credentialScope,
      crypto.createHash('sha256').update(canonicalRequest, 'utf8').digest('hex')
    ].join('\n');

    function hmac(key, str) {
      return crypto.createHmac('sha256', key).update(str, 'utf8').digest();
    }

    const kDate = hmac(`AWS4${secretAccessKey.trim()}`, dateStamp);
    const kRegion = hmac(kDate, region);
    const kService = hmac(kRegion, service);
    const kSigning = hmac(kService, 'aws4_request');

    const signature = crypto.createHmac('sha256', kSigning).update(stringToSign, 'utf8').digest('hex');
    const authHeader = `AWS4-HMAC-SHA256 Credential=${accessKeyId.trim()}/${credentialScope}, SignedHeaders=${signedHeaders}, Signature=${signature}`;

    const headers = {
      'Host': host,
      'x-amz-date': amzDate,
      'x-amz-content-sha256': payloadHash,
      'Authorization': authHeader
    };

    if (typeof httpRequestFn === 'function') {
      return httpRequestFn({ method, host, path: canonicalUri, headers }, resolve, reject);
    }

    const req = https.request({
      method,
      hostname: host,
      port: 443,
      path: canonicalUri,
      headers
    }, (res) => {
      resolve({ statusCode: res.statusCode, headers: res.headers });
    });

    req.on('error', (err) => reject(err));
    req.end();
  });
}

/**
 * Checks metadata of an object on R2 via SigV4 HEAD request.
 */
async function fetchR2ObjectMetadata(params) {
  const result = await makeSigV4Request({ ...params, method: 'HEAD' });
  if (result.statusCode === 200) {
    const rawLen = result.headers['content-length'];
    const contentLength = rawLen ? parseInt(rawLen, 10) : 0;
    const contentType = (result.headers['content-type'] || 'application/octet-stream').split(';')[0].trim().toLowerCase();
    const etag = result.headers['etag'] || null;
    return { exists: true, contentLength, contentType, etag };
  } else if (result.statusCode === 404) {
    return { exists: false, contentLength: 0, contentType: null, etag: null };
  } else {
    const err = new Error(`R2 HEAD request returned status ${result.statusCode}`);
    err.code = result.statusCode === 403 ? 'permission-denied' : 'unavailable';
    throw err;
  }
}

/**
 * Permanently deletes an object from R2 via SigV4 DELETE request.
 */
async function deleteR2Object(params) {
  const result = await makeSigV4Request({ ...params, method: 'DELETE' });
  return {
    success: result.statusCode === 204 || result.statusCode === 200,
    statusCode: result.statusCode
  };
}

/**
 * Authoritatively verifies that the uploaded object exists on R2, does not exceed 8MB,
 * and matches the allowed MIME types. If oversized or invalid, the object is immediately
 * deleted/quarantined from R2 storage.
 */
async function verifyAndEnforceObjectLimits({
  accountId,
  accessKeyId,
  secretAccessKey,
  bucketName,
  objectKey,
  maxSizeBytes = MAX_FILE_SIZE_BYTES,
  httpRequestFn = null
}) {
  const meta = await fetchR2ObjectMetadata({
    accountId,
    accessKeyId,
    secretAccessKey,
    bucketName,
    objectKey,
    httpRequestFn
  });

  if (!meta.exists) {
    const err = new Error(`Object '${objectKey}' does not exist on R2 storage.`);
    err.code = 'not-found';
    throw err;
  }

  // Determine folder from objectKey: e.g. "providers/uid/profile/..." -> "profile"
  const parts = objectKey.split('/');
  const folder = parts.length > 2 && parts[0] === 'providers' ? parts[2] : parts[0];
  const isDoc = folder === 'certificates' || folder === 'kyc';
  const allowedMimes = isDoc
    ? ['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'application/pdf']
    : ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];

  // 1. Enforce actual byte size
  if (meta.contentLength > maxSizeBytes) {
    try {
      await deleteR2Object({ accountId, accessKeyId, secretAccessKey, bucketName, objectKey, httpRequestFn });
    } catch (_) {}
    const err = new Error(`Uploaded file exceeds the maximum allowed size of 8MB (actual: ${meta.contentLength} bytes). The object has been purged from storage.`);
    err.code = 'invalid-argument';
    throw err;
  }

  if (meta.contentLength <= 0) {
    try {
      await deleteR2Object({ accountId, accessKeyId, secretAccessKey, bucketName, objectKey, httpRequestFn });
    } catch (_) {}
    const err = new Error('Empty file (0 bytes) is not permitted. The object has been purged from storage.');
    err.code = 'invalid-argument';
    throw err;
  }

  // 2. Enforce MIME type
  const cleanMime = (meta.contentType || '').split(';')[0].toLowerCase().trim();
  if (!allowedMimes.includes(cleanMime)) {
    try {
      await deleteR2Object({ accountId, accessKeyId, secretAccessKey, bucketName, objectKey, httpRequestFn });
    } catch (_) {}
    const err = new Error(`Uploaded file type '${meta.contentType}' is not permitted for '${folder}'. The object has been purged from storage.`);
    err.code = 'invalid-argument';
    throw err;
  }

  return {
    verified: true,
    objectKey,
    actualSizeBytes: meta.contentLength,
    mimeType: cleanMime,
    bucket: bucketName
  };
}

/**
 * Handles secure deletion of an R2 storage object with ownership verification
 * and atomic storage quota decrement in Firestore.
 */
async function handleStorageObjectDelete({
  auth,
  objectKey,
  verifyActiveAdminFn,
  db,
  accountId,
  accessKeyId,
  secretAccessKey,
  publicBucket,
  privateBucket,
  httpRequestFn = null
}) {
  if (!auth || !auth.uid) {
    const err = new Error('User must be authenticated to delete media.');
    err.code = 'unauthenticated';
    throw err;
  }

  const callerUid = auth.uid;
  const cleanKey = (objectKey || '').toString().trim();
  if (!cleanKey || cleanKey.includes('..')) {
    const err = new Error('A valid object key is required.');
    err.code = 'invalid-argument';
    throw err;
  }

  const effectivePub = typeof publicBucket === 'string' ? publicBucket.trim() : (process.env.R2_BUCKET_NAME || '').trim();
  const effectivePriv = typeof privateBucket === 'string' ? privateBucket.trim() : (process.env.R2_PRIVATE_BUCKET_NAME || '').trim();
  if (!effectivePub || !effectivePriv) {
    const missing = [];
    if (!effectivePub) missing.push('R2_BUCKET_NAME');
    if (!effectivePriv) missing.push('R2_PRIVATE_BUCKET_NAME');
    const err = new Error(`R2 configuration error: Missing or empty configuration parameter(s): ${missing.join(', ')}. Production fallback is strictly disabled.`);
    err.code = 'failed-precondition';
    throw err;
  }

  // Ownership verification
  let providerOwnerId = null;

  if (cleanKey.startsWith('providers/')) {
    const parts = cleanKey.split('/');
    providerOwnerId = parts[1];
    if (providerOwnerId !== callerUid) {
      if (typeof verifyActiveAdminFn === 'function') {
        await verifyActiveAdminFn({ auth });
      } else {
        const err = new Error('Unauthorized to delete this provider object.');
        err.code = 'permission-denied';
        throw err;
      }
    }
  } else if (cleanKey.startsWith('reviews/')) {
    const parts = cleanKey.split('/');
    const reviewOwner = parts[1];
    if (reviewOwner !== callerUid) {
      if (typeof verifyActiveAdminFn === 'function') {
        await verifyActiveAdminFn({ auth });
      } else {
        const err = new Error('Unauthorized to delete this review photo.');
        err.code = 'permission-denied';
        throw err;
      }
    }
  } else if (cleanKey.startsWith('diamond_shops/')) {
    const parts = cleanKey.split('/');
    const shopId = parts[1];
    let isOwner = false;
    if (db) {
      try {
        const shopSnap = await db.collection('diamond_shops').doc(shopId).get();
        if (shopSnap.exists && (shopSnap.data().ownerUid === callerUid || shopId === callerUid)) {
          isOwner = true;
        }
      } catch (_) {}
    }
    if (!isOwner) {
      if (typeof verifyActiveAdminFn === 'function') {
        await verifyActiveAdminFn({ auth });
      } else {
        const err = new Error('Unauthorized to delete this shop object.');
        err.code = 'permission-denied';
        throw err;
      }
    }
  } else {
    // Categories, banners, etc. strictly require admin
    if (typeof verifyActiveAdminFn === 'function') {
      await verifyActiveAdminFn({ auth });
    } else {
      const err = new Error('Unauthorized to delete admin storage object.');
      err.code = 'permission-denied';
      throw err;
    }
  }

  // Resolve bucket
  const bucketName = resolveBucketForObjectKey(cleanKey, publicBucket, privateBucket);

  // Check object metadata to know size before deleting
  let objectSizeBytes = 0;
  try {
    const meta = await fetchR2ObjectMetadata({
      accountId,
      accessKeyId,
      secretAccessKey,
      bucketName,
      objectKey: cleanKey,
      httpRequestFn
    });
    if (meta.exists) {
      objectSizeBytes = meta.contentLength;
    }
  } catch (_) {}

  // Perform actual R2 deletion
  const delRes = await deleteR2Object({
    accountId,
    accessKeyId,
    secretAccessKey,
    bucketName,
    objectKey: cleanKey,
    httpRequestFn
  });

  if (!delRes.success && delRes.statusCode !== 404) {
    const err = new Error(`Failed to delete object from storage (status ${delRes.statusCode}).`);
    err.code = 'internal';
    throw err;
  }

  // Atomically decrement provider storage usage in Firestore if provider owned
  let updatedUsage = null;
  if (providerOwnerId && db) {
    try {
      const provRef = db.collection('providers').doc(providerOwnerId);
      const provSnap = await provRef.get();
      if (provSnap && provSnap.exists) {
        const currentData = (typeof provSnap.data === 'function' ? provSnap.data() : provSnap.data) || {};
        const usage = currentData.storageUsage || {};
        const oldBytes = Number(usage.totalBytesUsed || 0);
        const oldCount = Number(usage.totalImagesCount || 0);

        const newBytes = Math.max(0, oldBytes - objectSizeBytes);
        const newCount = Math.max(0, oldCount - 1);

        const newUsage = {
          ...usage,
          totalBytesUsed: newBytes,
          totalImagesCount: newCount,
          lastUpdated: new Date()
        };

        if (typeof provRef.update === 'function') {
          await provRef.update({ storageUsage: newUsage });
        }
        updatedUsage = newUsage;

        // Also remove from media tracking record if exists
        const keyHash = crypto.createHash('sha256').update(cleanKey).digest('hex').substring(0, 32);
        try {
          if (typeof provRef.collection === 'function') {
            await provRef.collection('storage_objects').doc(keyHash).delete();
          }
        } catch (_) {}

        // If it belonged to a listing, remove reference from listing document
        if (cleanKey.includes('/listings/')) {
          const keyParts = cleanKey.split('/');
          const listingIndex = keyParts.indexOf('listings');
          if (listingIndex !== -1 && keyParts.length > listingIndex + 1) {
            const listId = keyParts[listingIndex + 1];
            try {
              const listRef = db.collection('provider_listings').doc(listId);
              const listSnap = await listRef.get();
              if (listSnap && listSnap.exists) {
                const listData = (typeof listSnap.data === 'function' ? listSnap.data() : listSnap.data) || {};
                const currentImages = Array.isArray(listData.images) ? listData.images : [];
                const filteredImages = currentImages.filter(img => !img.includes(cleanKey));
                if (typeof listRef.update === 'function') {
                  await listRef.update({ images: filteredImages, updatedAt: new Date() });
                }
              }
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }

  return {
    success: true,
    deletedKey: cleanKey,
    bytesFreed: objectSizeBytes,
    storageUsage: updatedUsage
  };
}

/**
 * Reconciles a provider's storage usage with actual active objects.
 */
async function reconcileProviderStorageUsage({ db, providerId }) {
  if (!db || !providerId) return null;

  const provRef = db.collection('providers').doc(providerId);
  const provSnap = await provRef.get();
  if (!provSnap || !provSnap.exists) return null;

  let totalBytes = 0;
  let totalImages = 0;

  try {
    if (typeof provRef.collection === 'function') {
      const objectsSnap = await provRef.collection('storage_objects').where('status', '==', 'active').get();
      const docs = objectsSnap.docs || [];
      for (const doc of docs) {
        const d = (typeof doc.data === 'function' ? doc.data() : doc.data) || {};
        totalBytes += Number(d.sizeBytes || 0);
        totalImages++;
      }
    }
  } catch (_) {}

  const newUsage = {
    totalBytesUsed: totalBytes,
    totalImagesCount: totalImages,
    reservedBytes: 0,
    lastReconciledAt: new Date()
  };

  if (typeof provRef.update === 'function') {
    await provRef.update({ storageUsage: newUsage });
  }

  return newUsage;
}

/**
 * Uploads raw binary buffer to Cloudflare R2 using AWS SigV4 PUT.
 * Used for server-side uploads from Web clients avoiding browser CORS.
 */
function putR2ObjectBytes({ accountId, accessKeyId, secretAccessKey, bucketName, objectKey, mimeType, buffer }) {
  return new Promise((resolve, reject) => {
    const acc = typeof accountId === 'string' ? accountId.trim() : '';
    const key = typeof accessKeyId === 'string' ? accessKeyId.trim() : '';
    const sec = typeof secretAccessKey === 'string' ? secretAccessKey.trim() : '';
    const bkt = typeof bucketName === 'string' ? bucketName.trim() : '';

    if (!acc || !key || !sec || !bkt) {
      const err = new Error('R2 configuration secrets are incomplete.');
      err.code = 'failed-precondition';
      return reject(err);
    }

    const host = `${acc}.r2.cloudflarestorage.com`;
    const region = 'auto';
    const service = 's3';

    const cleanKey = objectKey.startsWith('/') ? objectKey.substring(1) : objectKey;
    const canonicalUri = `/${bkt}/${cleanKey.split('/').map(encodeURIComponent).join('/')}`;

    const now = new Date();
    const amzDate = now.toISOString().replace(/[:-]|\.\d{3}/g, '');
    const dateStamp = amzDate.substring(0, 8);
    const credentialScope = `${dateStamp}/${region}/${service}/aws4_request`;

    const payloadHash = crypto.createHash('sha256').update(buffer).digest('hex');
    const signedHeaders = 'content-length;content-type;host;x-amz-content-sha256;x-amz-date';
    const canonicalHeaders = `content-length:${buffer.length}\ncontent-type:${mimeType.trim()}\nhost:${host}\nx-amz-content-sha256:${payloadHash}\nx-amz-date:${amzDate}\n`;
    const canonicalQuery = '';

    const canonicalRequest = [
      'PUT',
      canonicalUri,
      canonicalQuery,
      canonicalHeaders,
      signedHeaders,
      payloadHash
    ].join('\n');

    const stringToSign = [
      'AWS4-HMAC-SHA256',
      amzDate,
      credentialScope,
      crypto.createHash('sha256').update(canonicalRequest, 'utf8').digest('hex')
    ].join('\n');

    function hmac(k, str) {
      return crypto.createHmac('sha256', k).update(str, 'utf8').digest();
    }

    const kDate = hmac(`AWS4${sec}`, dateStamp);
    const kRegion = hmac(kDate, region);
    const kService = hmac(kRegion, service);
    const kSigning = hmac(kService, 'aws4_request');

    const signature = crypto.createHmac('sha256', kSigning).update(stringToSign, 'utf8').digest('hex');
    const authHeader = `AWS4-HMAC-SHA256 Credential=${key}/${credentialScope}, SignedHeaders=${signedHeaders}, Signature=${signature}`;

    const headers = {
      'Host': host,
      'Content-Type': mimeType.trim(),
      'Content-Length': buffer.length.toString(),
      'x-amz-date': amzDate,
      'x-amz-content-sha256': payloadHash,
      'Authorization': authHeader
    };

    const req = https.request({
      method: 'PUT',
      hostname: host,
      port: 443,
      path: canonicalUri,
      headers
    }, (res) => {
      let body = '';
      res.on('data', chunk => { body += chunk; });
      res.on('end', () => {
        if (res.statusCode === 200 || res.statusCode === 204) {
          resolve({ success: true, statusCode: res.statusCode, objectKey });
        } else {
          const err = new Error(`R2 upload rejected with status ${res.statusCode}: ${body}`);
          err.statusCode = res.statusCode;
          reject(err);
        }
      });
    });

    req.on('error', err => reject(err));
    req.write(buffer);
    req.end();
  });
}

/**
 * Configures S3 CORS on Cloudflare R2 bucket via SigV4 PUT /<bucket>?cors
 */
function setR2BucketCors({ accountId, accessKeyId, secretAccessKey, bucketName, allowedOrigins = ['*'] }) {
  return new Promise((resolve, reject) => {
    const acc = typeof accountId === 'string' ? accountId.trim() : '';
    const key = typeof accessKeyId === 'string' ? accessKeyId.trim() : '';
    const sec = typeof secretAccessKey === 'string' ? secretAccessKey.trim() : '';
    const bkt = typeof bucketName === 'string' ? bucketName.trim() : '';

    if (!acc || !key || !sec || !bkt) {
      const err = new Error('R2 configuration secrets are incomplete.');
      err.code = 'failed-precondition';
      return reject(err);
    }

    const host = `${acc}.r2.cloudflarestorage.com`;
    const region = 'auto';
    const service = 's3';

    const originsXml = allowedOrigins.map(o => `    <AllowedOrigin>${o}</AllowedOrigin>`).join('\n');
    const corsXml = [
      '<CORSConfiguration xmlns="http://s3.amazonaws.com/doc/2006-03-01/">',
      '  <CORSRule>',
      originsXml,
      '    <AllowedMethod>GET</AllowedMethod>',
      '    <AllowedMethod>PUT</AllowedMethod>',
      '    <AllowedMethod>POST</AllowedMethod>',
      '    <AllowedMethod>HEAD</AllowedMethod>',
      '    <AllowedMethod>DELETE</AllowedMethod>',
      '    <AllowedHeader>*</AllowedHeader>',
      '    <ExposeHeader>ETag</ExposeHeader>',
      '    <MaxAgeSeconds>3600</MaxAgeSeconds>',
      '  </CORSRule>',
      '</CORSConfiguration>'
    ].join('\n');

    const now = new Date();
    const amzDate = now.toISOString().replace(/[:-]|\.\d{3}/g, '');
    const dateStamp = amzDate.substring(0, 8);
    const credentialScope = `${dateStamp}/${region}/${service}/aws4_request`;

    const canonicalUri = `/${bkt}`;
    const canonicalQuery = 'cors=';

    const payloadHash = crypto.createHash('sha256').update(corsXml, 'utf8').digest('hex');
    const signedHeaders = 'content-type;host;x-amz-content-sha256;x-amz-date';
    const canonicalHeaders = `content-type:application/xml\nhost:${host}\nx-amz-content-sha256:${payloadHash}\nx-amz-date:${amzDate}\n`;

    const canonicalRequest = [
      'PUT',
      canonicalUri,
      canonicalQuery,
      canonicalHeaders,
      signedHeaders,
      payloadHash
    ].join('\n');

    const stringToSign = [
      'AWS4-HMAC-SHA256',
      amzDate,
      credentialScope,
      crypto.createHash('sha256').update(canonicalRequest, 'utf8').digest('hex')
    ].join('\n');

    function hmac(k, str) {
      return crypto.createHmac('sha256', k).update(str, 'utf8').digest();
    }

    const kDate = hmac(`AWS4${sec}`, dateStamp);
    const kRegion = hmac(kDate, region);
    const kService = hmac(kRegion, service);
    const kSigning = hmac(kService, 'aws4_request');

    const signature = crypto.createHmac('sha256', kSigning).update(stringToSign, 'utf8').digest('hex');
    const authHeader = `AWS4-HMAC-SHA256 Credential=${key}/${credentialScope}, SignedHeaders=${signedHeaders}, Signature=${signature}`;

    const headers = {
      'Host': host,
      'Content-Type': 'application/xml',
      'Content-Length': Buffer.byteLength(corsXml, 'utf8').toString(),
      'x-amz-date': amzDate,
      'x-amz-content-sha256': payloadHash,
      'Authorization': authHeader
    };

    const req = https.request({
      method: 'PUT',
      hostname: host,
      port: 443,
      path: `${canonicalUri}?cors`,
      headers
    }, (res) => {
      let body = '';
      res.on('data', chunk => { body += chunk; });
      res.on('end', () => {
        resolve({ statusCode: res.statusCode, headers: res.headers, body });
      });
    });

    req.on('error', err => reject(err));
    req.write(corsXml);
    req.end();
  });
}

module.exports = {
  validateAndGenerateUploadKey,
  generateR2PresignedPutUrl,
  generateR2PresignedGetUrl,
  fetchR2ObjectMetadata,
  deleteR2Object,
  putR2ObjectBytes,
  setR2BucketCors,
  verifyAndEnforceObjectLimits,
  handleStorageObjectDelete,
  reconcileProviderStorageUsage,
  resolveProviderStoragePlanLimits,
  isPrivateFolder,
  resolveBucketForFolder,
  resolveBucketForObjectKey,
  ALLOWED_FOLDERS,
  ALLOWED_MIME_TYPES,
  MAX_FILE_SIZE_BYTES,
  DEFAULT_FREE_TIER_LIMITS
};
