const assert = require('assert');

console.log('================================================================');
console.log(' JAMUI SERVICES — LIVE STAGING E2E R2 PRODUCT UPLOAD TEST      ');
console.log(' Project: jamui-services-staging                                ');
console.log(' Target Account: sk12@gmail.com (OXBV2Zink6TvWg5VefHPi53QkyV2)  ');
console.log('================================================================\n');

const API_KEY = 'AIzaSyAB35pqPdAuLiVT5XRu_OmEjIT2NqC4zG0';
const GET_UPLOAD_URL_ENDPOINT = 'https://asia-south1-jamui-services-staging.cloudfunctions.net/getStorageUploadUrl';
const VERIFY_OBJECT_ENDPOINT = 'https://asia-south1-jamui-services-staging.cloudfunctions.net/verifyUploadedStorageObject';
const DELETE_OBJECT_ENDPOINT = 'https://asia-south1-jamui-services-staging.cloudfunctions.net/deleteStorageObject';

async function getIdToken(email, password) {
  const resp = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${API_KEY}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password, returnSecureToken: true })
  });
  const data = await resp.json();
  if (!data.idToken) {
    throw new Error(`Auth failed for ${email}: ${JSON.stringify(data)}`);
  }
  return { idToken: data.idToken, localId: data.localId };
}

async function runLiveStagingTests() {
  let passCount = 0;
  let failCount = 0;

  function report(name, pass, detail = '') {
    if (pass) {
      passCount++;
      console.log(`✅ [PASS] ${name}${detail ? ' -> ' + detail : ''}`);
    } else {
      failCount++;
      console.error(`❌ [FAIL] ${name}${detail ? ' -> ' + detail : ''}`);
    }
  }

  // 1. Authenticate Seller
  console.log('Step 1: Authenticating seller sk12@gmail.com...');
  const sellerAuth = await getIdToken('sk12@gmail.com', '123456');
  report('Seller Authentication', !!sellerAuth.idToken, `UID: ${sellerAuth.localId}`);

  // 2. Request Presigned Upload URL for 'products'
  console.log('\nStep 2: Calling live getStorageUploadUrl for folder="products"...');
  let uploadData = null;
  try {
    const res = await fetch(GET_UPLOAD_URL_ENDPOINT, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${sellerAuth.idToken}`
      },
      body: JSON.stringify({
        data: {
          folder: 'products',
          fileName: 'tata_salt_staging_test.jpg',
          mimeType: 'image/jpeg',
          fileSize: 2048,
          targetId: sellerAuth.localId
        }
      })
    });
    const json = await res.json();
    if (json.result && json.result.uploadUrl) {
      uploadData = json.result;
      report('getStorageUploadUrl for products', true, `ObjectKey: ${uploadData.objectKey}`);
    } else {
      report('getStorageUploadUrl for products', false, JSON.stringify(json));
    }
  } catch (e) {
    report('getStorageUploadUrl for products', false, e.message);
  }

  // 3. Upload real JPEG bytes to Cloudflare R2 Presigned PUT URL
  if (uploadData && uploadData.uploadUrl) {
    console.log('\nStep 3: Uploading binary JPEG data directly to Cloudflare R2...');
    try {
      // 2048 bytes of dummy JPEG-like data
      const dummyJpeg = Buffer.alloc(2048, 0xFF);
      dummyJpeg[0] = 0xFF;
      dummyJpeg[1] = 0xD8; // JPEG SOI
      dummyJpeg[2046] = 0xFF;
      dummyJpeg[2047] = 0xD9; // JPEG EOI

      const r2Res = await fetch(uploadData.uploadUrl, {
        method: 'PUT',
        headers: {
          'Content-Type': 'image/jpeg'
        },
        body: dummyJpeg
      });

      report('Cloudflare R2 Presigned PUT Upload', r2Res.status === 200, `HTTP ${r2Res.status} ${r2Res.statusText}`);

      // 4. Verify Uploaded Object via verifyUploadedStorageObject
      console.log('\nStep 4: Calling live verifyUploadedStorageObject...');
      const verifyRes = await fetch(VERIFY_OBJECT_ENDPOINT, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${sellerAuth.idToken}`
        },
        body: JSON.stringify({
          data: {
            objectKey: uploadData.objectKey
          }
        })
      });
      const verifyJson = await verifyRes.json();
      const verified = verifyJson.result && (verifyJson.result.verified === true || verifyJson.result.success === true);
      report('verifyUploadedStorageObject on R2', verified, JSON.stringify(verifyJson.result || verifyJson));

      // 5. Clean up test object using deleteStorageObject
      console.log('\nStep 5: Cleaning up test object via deleteStorageObject...');
      const delRes = await fetch(DELETE_OBJECT_ENDPOINT, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${sellerAuth.idToken}`
        },
        body: JSON.stringify({
          data: {
            objectKey: uploadData.objectKey
          }
        })
      });
      const delJson = await delRes.json();
      const deleted = delJson.result && (delJson.result.success === true || delJson.result.deleted === true);
      report('deleteStorageObject for seller product', deleted, JSON.stringify(delJson.result || delJson));
    } catch (e) {
      report('Cloudflare R2 Upload & Verification Flow', false, e.message);
    }
  }

  // 6. Test Security: Cross-seller upload rejection
  console.log('\nStep 6: Testing cross-seller unauthorized upload rejection...');
  try {
    const crossRes = await fetch(GET_UPLOAD_URL_ENDPOINT, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${sellerAuth.idToken}`
      },
      body: JSON.stringify({
        data: {
          folder: 'products',
          fileName: 'malicious.jpg',
          mimeType: 'image/jpeg',
          fileSize: 1024,
          targetId: 'VICTIM_SELLER_SHOP_ID_99999'
        }
      })
    });
    const crossJson = await crossRes.json();
    const isDenied = crossJson.error && (crossJson.error.status === 'NOT_FOUND' || crossJson.error.status === 'PERMISSION_DENIED');
    report('Cross-seller product upload rejected', isDenied, `Status: ${crossJson.error ? crossJson.error.status : 'Unexpected success'}`);
  } catch (e) {
    report('Cross-seller product upload rejected', false, e.message);
  }

  // 7. Test Disallowed MIME type (PDF rejected for products)
  console.log('\nStep 7: Testing disallowed MIME type rejection (PDF for products)...');
  try {
    const mimeRes = await fetch(GET_UPLOAD_URL_ENDPOINT, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${sellerAuth.idToken}`
      },
      body: JSON.stringify({
        data: {
          folder: 'products',
          fileName: 'test.pdf',
          mimeType: 'application/pdf',
          fileSize: 1024,
          targetId: sellerAuth.localId
        }
      })
    });
    const mimeJson = await mimeRes.json();
    const isMimeRejected = mimeJson.error && mimeJson.error.status === 'INVALID_ARGUMENT';
    report('Disallowed MIME type for products rejected', isMimeRejected, `Status: ${mimeJson.error ? mimeJson.error.status : 'Unexpected success'}`);
  } catch (e) {
    report('Disallowed MIME type for products rejected', false, e.message);
  }

  // 8. Test Compatibility: Normal Provider 'profile' upload remains functional
  console.log('\nStep 8: Testing existing Normal Provider folder="profile" compatibility...');
  try {
    const profRes = await fetch(GET_UPLOAD_URL_ENDPOINT, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${sellerAuth.idToken}`
      },
      body: JSON.stringify({
        data: {
          folder: 'profile',
          fileName: 'profile_test.jpg',
          mimeType: 'image/jpeg',
          fileSize: 1024,
          targetId: sellerAuth.localId
        }
      })
    });
    const profJson = await profRes.json();
    const isProfAllowed = profJson.result && profJson.result.uploadUrl;
    report('Existing folder="profile" backward compatibility', isProfAllowed, `ObjectKey: ${profJson.result ? profJson.result.objectKey : JSON.stringify(profJson)}`);
  } catch (e) {
    report('Existing folder="profile" backward compatibility', false, e.message);
  }

  console.log('\n================================================================');
  console.log(` FINAL RESULTS: ${passCount}/${passCount + failCount} LIVE STAGING TESTS PASSED`);
  console.log('================================================================\n');

  if (failCount > 0) {
    process.exit(1);
  }
}

runLiveStagingTests().catch(err => {
  console.error('Fatal test error:', err);
  process.exit(1);
});

