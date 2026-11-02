const http = require('http');

function makeRequest(method, path, body = null, headers = {}) {
  return new Promise((resolve, reject) => {
    const postData = body ? (typeof body === 'string' ? body : JSON.stringify(body)) : null;
    const reqHeaders = { ...headers };
    if (postData) {
      reqHeaders['Content-Type'] = 'application/json';
      reqHeaders['Content-Length'] = Buffer.byteLength(postData);
    }

    const options = {
      hostname: '127.0.0.1',
      port: 8080,
      path: path,
      method: method,
      headers: reqHeaders
    };

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => resolve({ statusCode: res.statusCode, data }));
    });
    req.on('error', reject);
    if (postData) req.write(postData);
    req.end();
  });
}

function runStructuredQuery(collectionId, filters) {
  const postData = {
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
  };
  return makeRequest('POST', '/v1/projects/demo-jamui-services/databases/(default)/documents:runQuery', postData);
}

async function runCheckpoint4SecurityVerification() {
  console.log('================================================================');
  console.log('   JAMUI SERVICES — PHASE 3 CHECKPOINT 4 SECURITY AUDIT REPORT  ');
  console.log('   Firebase Emulator Security & Integrity Gate Verification      ');
  console.log('================================================================\n');

  let totalTests = 0;
  let passedTests = 0;

  function evaluate(testNum, testName, condition, details) {
    totalTests++;
    if (condition) passedTests++;
    const icon = condition ? '✅ PASS' : '❌ FAIL';
    console.log(`[${icon}] Test ${testNum}: ${testName}`);
    console.log(`       Details: ${details}\n`);
  }

  // 1. Direct Document Read: Approved Shop
  const resApproved = await makeRequest('GET', '/v1/projects/demo-jamui-services/databases/(default)/documents/diamond_shops/mock_seller_uid_01');
  evaluate(
    '1.1',
    'Approved Shop Public Read',
    resApproved.statusCode === 200,
    `HTTP ${resApproved.statusCode} (Expected: 200 OK)`
  );

  // 2. Direct Document Read: Pending Shop
  const resPending = await makeRequest('GET', '/v1/projects/demo-jamui-services/databases/(default)/documents/diamond_shops/mock_seller_uid_02');
  evaluate(
    '1.2',
    'Pending Shop Blocked from Public Access',
    resPending.statusCode === 403,
    `HTTP ${resPending.statusCode} (Expected: 403 Forbidden)`
  );

  // 3. Mandatory 5-Filter Compliant Query
  const fStatus = { fieldFilter: { field: { fieldPath: 'status' }, op: 'EQUAL', value: { stringValue: 'approved' } } };
  const fApproved = { fieldFilter: { field: { fieldPath: 'isApproved' }, op: 'EQUAL', value: { booleanValue: true } } };
  const fActive = { fieldFilter: { field: { fieldPath: 'isActive' }, op: 'EQUAL', value: { booleanValue: true } } };
  const fSub = { fieldFilter: { field: { fieldPath: 'isSubscriptionActive' }, op: 'EQUAL', value: { booleanValue: true } } };
  const fDeleted = { fieldFilter: { field: { fieldPath: 'isDeleted' }, op: 'EQUAL', value: { booleanValue: false } } };

  const resAll5 = await runStructuredQuery('diamond_shops', [fStatus, fApproved, fActive, fSub, fDeleted]);
  evaluate(
    '1.3',
    'Mandatory 5-Filter Compliant Query Allowed',
    resAll5.statusCode === 200,
    `HTTP ${resAll5.statusCode} (Expected: 200 OK)`
  );

  // 4. Missing isActive Filter Blocked
  const resNoActive = await runStructuredQuery('diamond_shops', [fStatus, fApproved, fSub, fDeleted]);
  evaluate(
    '1.4',
    'Query Missing isActive Filter Blocked',
    resNoActive.statusCode === 403,
    `HTTP ${resNoActive.statusCode} (Expected: 403 Forbidden)`
  );

  // 5. Missing isSubscriptionActive Filter Blocked
  const resNoSub = await runStructuredQuery('diamond_shops', [fStatus, fApproved, fActive, fDeleted]);
  evaluate(
    '1.5',
    'Query Missing isSubscriptionActive Filter Blocked',
    resNoSub.statusCode === 403,
    `HTTP ${resNoSub.statusCode} (Expected: 403 Forbidden)`
  );

  // 6. Missing isApproved Filter Blocked
  const resNoApp = await runStructuredQuery('diamond_shops', [fStatus, fActive, fSub, fDeleted]);
  evaluate(
    '1.6',
    'Query Missing isApproved Filter Blocked',
    resNoApp.statusCode === 403,
    `HTTP ${resNoApp.statusCode} (Expected: 403 Forbidden)`
  );

  // 7. Missing status Filter Blocked
  const resNoStatus = await runStructuredQuery('diamond_shops', [fApproved, fActive, fSub, fDeleted]);
  evaluate(
    '1.7',
    'Query Missing status Filter Blocked',
    resNoStatus.statusCode === 403,
    `HTTP ${resNoStatus.statusCode} (Expected: 403 Forbidden)`
  );

  // 8. Legacy Collection 'shops' Query Bypass Attempt
  const resLegacyBypass = await runStructuredQuery('shops', [fStatus]);
  evaluate(
    '1.8',
    'Legacy Collection Query Bypass Attempt Blocked',
    resLegacyBypass.statusCode === 403,
    `HTTP ${resLegacyBypass.statusCode} (Expected: 403 Forbidden)`
  );

  // 9. Unauthorized Client Direct Write on diamond_shops
  const resUnauthWrite = await makeRequest(
    'POST',
    '/v1/projects/demo-jamui-services/databases/(default)/documents/diamond_shops',
    { fields: { shopName: { stringValue: 'Malicious Injected Shop' } } }
  );
  evaluate(
    '1.9',
    'Unauthorized Client Create on diamond_shops Blocked',
    resUnauthWrite.statusCode === 403,
    `HTTP ${resUnauthWrite.statusCode} (Expected: 403 Forbidden)`
  );

  // 10. Unauthorized Client Update on diamond_shops
  const resUnauthUpdate = await makeRequest(
    'PATCH',
    '/v1/projects/demo-jamui-services/databases/(default)/documents/diamond_shops/mock_seller_uid_01',
    { fields: { isApproved: { booleanValue: true } } }
  );
  evaluate(
    '1.10',
    'Unauthorized Client Update on diamond_shops Blocked',
    resUnauthUpdate.statusCode === 403,
    `HTTP ${resUnauthUpdate.statusCode} (Expected: 403 Forbidden)`
  );

  // 11. Unauthorized Client Delete on diamond_shops
  const resUnauthDelete = await makeRequest(
    'DELETE',
    '/v1/projects/demo-jamui-services/databases/(default)/documents/diamond_shops/mock_seller_uid_01'
  );
  evaluate(
    '1.11',
    'Unauthorized Client Delete on diamond_shops Blocked',
    resUnauthDelete.statusCode === 403,
    `HTTP ${resUnauthDelete.statusCode} (Expected: 403 Forbidden)`
  );

  // 12. Direct Client Order Creation on diamond_orders (Must go through Cloud Function)
  const resDirectOrder = await makeRequest(
    'POST',
    '/v1/projects/demo-jamui-services/databases/(default)/documents/diamond_orders',
    { fields: { orderAmount: { integerValue: '500' } } }
  );
  evaluate(
    '1.12',
    'Direct Client Order Creation Blocked (Zero-Trust Enforcement)',
    resDirectOrder.statusCode === 403,
    `HTTP ${resDirectOrder.statusCode} (Expected: 403 Forbidden)`
  );

  // 13. Public / Unauthenticated Read on diamond_orders Blocked
  const resOrderRead = await makeRequest('GET', '/v1/projects/demo-jamui-services/databases/(default)/documents/diamond_orders/order_001');
  evaluate(
    '1.13',
    'Unauthenticated Read on diamond_orders Blocked',
    resOrderRead.statusCode === 403,
    `HTTP ${resOrderRead.statusCode} (Expected: 403 Forbidden)`
  );

  // 14. Cross-Account Private Data Isolation: Subscriptions Collection
  const resSubRead = await makeRequest('GET', '/v1/projects/demo-jamui-services/databases/(default)/documents/subscriptions/sub_001');
  evaluate(
    '1.14',
    'Cross-Account Subscriptions Private Data Isolation Blocked',
    resSubRead.statusCode === 403,
    `HTTP ${resSubRead.statusCode} (Expected: 403 Forbidden)`
  );

  // 15. Cross-Account Private Data Isolation: Payments Collection
  const resPayRead = await makeRequest('GET', '/v1/projects/demo-jamui-services/databases/(default)/documents/payments/pay_001');
  evaluate(
    '1.15',
    'Cross-Account Payments Private Data Isolation Blocked',
    resPayRead.statusCode === 403,
    `HTTP ${resPayRead.statusCode} (Expected: 403 Forbidden)`
  );

  console.log('----------------------------------------------------------------');
  console.log(`TOTAL SECURITY VERIFICATION TESTS: ${totalTests}`);
  console.log(`PASSED: ${passedTests}`);
  console.log(`FAILED: ${totalTests - passedTests}`);
  console.log(`SUCCESS RATE: ${Math.round((passedTests / totalTests) * 100)}%`);
  console.log('================================================================\n');

  if (passedTests !== totalTests) {
    process.exit(1);
  }
}

runCheckpoint4SecurityVerification().catch(err => {
  console.error('Fatal execution error:', err);
  process.exit(1);
});

