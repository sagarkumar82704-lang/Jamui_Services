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

async function runCheckpoint1EmulatorSecurity() {
  console.log('================================================================');
  console.log('   JAMUI SERVICES — CHECKPOINT 1 FIREBASE EMULATOR AUDIT        ');
  console.log('   Shop Ownership, Role Isolation & Cross-Vendor Protection    ');
  console.log('================================================================\n');

  let passed = 0;
  let total = 0;

  function evaluate(testNum, testName, condition, details) {
    total++;
    if (condition) passed++;
    const icon = condition ? '✅ PASS' : '❌ FAIL';
    console.log(`[${icon}] Test ${testNum}: ${testName}`);
    console.log(`       Details: ${details}\n`);
  }

  // 1. Approved Shop Read
  const resApproved = await makeRequest('GET', '/v1/projects/demo-jamui-services/databases/(default)/documents/diamond_shops/mock_seller_uid_01');
  evaluate(
    '1.1',
    'Approved Shop Public Access Allowed (Status: Approved, Active, Sub Active)',
    resApproved.statusCode === 200,
    `HTTP ${resApproved.statusCode} (Expected: 200 OK)`
  );

  // 2. Pending Shop Isolation
  const resPending = await makeRequest('GET', '/v1/projects/demo-jamui-services/databases/(default)/documents/diamond_shops/mock_seller_uid_02');
  evaluate(
    '1.2',
    'Pending Shop Blocked from Public Access (Status: Pending Review)',
    resPending.statusCode === 403,
    `HTTP ${resPending.statusCode} (Expected: 403 Forbidden)`
  );

  // 3. Unauthorized Cross-Shop Modification Blocked
  const resTamper = await makeRequest(
    'PATCH',
    '/v1/projects/demo-jamui-services/databases/(default)/documents/diamond_shops/mock_seller_uid_01?updateMask.fieldPaths=status',
    { fields: { status: { stringValue: 'approved' } } }
  );
  evaluate(
    '1.3',
    'Unauthenticated / Client Direct Status Escalation Blocked',
    resTamper.statusCode === 403,
    `HTTP ${resTamper.statusCode} (Expected: 403 Forbidden)`
  );

  // 4. Direct Client Write on diamond_orders Blocked
  const resOrderDirect = await makeRequest(
    'POST',
    '/v1/projects/demo-jamui-services/databases/(default)/documents/diamond_orders',
    { fields: { shopId: { stringValue: 'mock_seller_uid_01' } } }
  );
  evaluate(
    '1.4',
    'Direct Client Write on diamond_orders Blocked (Zero-Trust Callable Required)',
    resOrderDirect.statusCode === 403,
    `HTTP ${resOrderDirect.statusCode} (Expected: 403 Forbidden)`
  );

  // 5. Cross-Vendor Orders Private Data Isolation
  const resOrdersPublic = await makeRequest('GET', '/v1/projects/demo-jamui-services/databases/(default)/documents/diamond_orders/order_demo_01');
  evaluate(
    '1.5',
    'Unauthenticated / Cross-Account Access on Orders Blocked',
    resOrdersPublic.statusCode === 403,
    `HTTP ${resOrdersPublic.statusCode} (Expected: 403 Forbidden)`
  );

  console.log('----------------------------------------------------------------');
  console.log(`TOTAL AUDIT CHECKS: ${total}`);
  console.log(`PASSED: ${passed}`);
  console.log(`FAILED: ${total - passed}`);
  console.log(`SUCCESS RATE: ${Math.round((passed / total) * 100)}%`);
  console.log('================================================================');
}

runCheckpoint1EmulatorSecurity().catch(err => {
  console.error('Fatal execution error:', err);
  process.exit(1);
});
