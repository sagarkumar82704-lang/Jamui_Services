const http = require('http');

function httpGet(path) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: '127.0.0.1',
      port: 8080,
      path: path,
      method: 'GET'
    };
    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => resolve({ statusCode: res.statusCode, data }));
    });
    req.on('error', reject);
    req.end();
  });
}

function runStructuredQuery(collectionId, filters) {
  return new Promise((resolve, reject) => {
    const postData = JSON.stringify({
      structuredQuery: {
        from: [{ collectionId: collectionId }],
        where: {
          compositeFilter: {
            op: 'AND',
            filters: filters
          }
        },
        limit: 100
      }
    });

    const options = {
      hostname: '127.0.0.1',
      port: 8080,
      path: '/v1/projects/demo-jamui-services/databases/(default)/documents:runQuery',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(postData)
      }
    };

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => resolve({ statusCode: res.statusCode, data }));
    });
    req.on('error', reject);
    req.write(postData);
    req.end();
  });
}

async function verifySecurity() {
  console.log('=== POINT 1: FIRESTORE SECURITY RULES VERIFICATION ===\n');

  // 1. Direct document read: Approved shop
  const resApproved = await httpGet('/v1/projects/demo-jamui-services/databases/(default)/documents/diamond_shops/mock_seller_uid_01');
  console.log(`1.1 Direct Read Approved Shop (mock_seller_uid_01): HTTP ${resApproved.statusCode}`);
  const passApproved = (resApproved.statusCode === 200);
  console.log(`    Status: ${passApproved ? '✅ PASSED' : '❌ FAILED'}`);

  // 1.2 Direct document read: Pending shop
  const resPending = await httpGet('/v1/projects/demo-jamui-services/databases/(default)/documents/diamond_shops/mock_seller_uid_02');
  console.log(`1.2 Direct Read Pending Shop (mock_seller_uid_02): HTTP ${resPending.statusCode}`);
  const passPending = (resPending.statusCode === 403);
  console.log(`    Status: ${passPending ? '✅ PASSED (Blocked 403 Forbidden)' : '❌ FAILED'}`);

  // 1.3 Query security matrix: All 5 filters
  const fStatus = { fieldFilter: { field: { fieldPath: 'status' }, op: 'EQUAL', value: { stringValue: 'approved' } } };
  const fApproved = { fieldFilter: { field: { fieldPath: 'isApproved' }, op: 'EQUAL', value: { booleanValue: true } } };
  const fActive = { fieldFilter: { field: { fieldPath: 'isActive' }, op: 'EQUAL', value: { booleanValue: true } } };
  const fSub = { fieldFilter: { field: { fieldPath: 'isSubscriptionActive' }, op: 'EQUAL', value: { booleanValue: true } } };
  const fDeleted = { fieldFilter: { field: { fieldPath: 'isDeleted' }, op: 'EQUAL', value: { booleanValue: false } } };

  // Full 5 filters
  const resAll5 = await runStructuredQuery('diamond_shops', [fStatus, fApproved, fActive, fSub, fDeleted]);
  console.log(`1.3 Full 5-Filter Query: HTTP ${resAll5.statusCode}`);
  console.log(`    Status: ${resAll5.statusCode === 200 ? '✅ PASSED' : '❌ FAILED'}`);

  // Bypass attempt A: Missing isActive
  const resNoActive = await runStructuredQuery('diamond_shops', [fStatus, fApproved, fSub, fDeleted]);
  console.log(`1.4 Bypass Attempt (Missing isActive): HTTP ${resNoActive.statusCode}`);
  console.log(`    Status: ${resNoActive.statusCode === 403 ? '✅ PASSED (Blocked 403)' : '❌ FAILED'}`);

  // Bypass attempt B: Missing isSubscriptionActive
  const resNoSub = await runStructuredQuery('diamond_shops', [fStatus, fApproved, fActive, fDeleted]);
  console.log(`1.5 Bypass Attempt (Missing isSubscriptionActive): HTTP ${resNoSub.statusCode}`);
  console.log(`    Status: ${resNoSub.statusCode === 403 ? '✅ PASSED (Blocked 403)' : '❌ FAILED'}`);

  // Bypass attempt C: Missing isApproved
  const resNoApp = await runStructuredQuery('diamond_shops', [fStatus, fActive, fSub, fDeleted]);
  console.log(`1.6 Bypass Attempt (Missing isApproved): HTTP ${resNoApp.statusCode}`);
  console.log(`    Status: ${resNoApp.statusCode === 403 ? '✅ PASSED (Blocked 403)' : '❌ FAILED'}`);

  // Bypass attempt D: Alternate query on legacy collection without 5 filters
  const resLegacyBypass = await runStructuredQuery('shops', [fStatus]);
  console.log(`1.7 Alternate Legacy Collection Bypass: HTTP ${resLegacyBypass.statusCode}`);
  console.log(`    Status: ${resLegacyBypass.statusCode === 403 ? '✅ PASSED (Blocked 403)' : '❌ FAILED'}`);
}

verifySecurity().catch(console.error);

