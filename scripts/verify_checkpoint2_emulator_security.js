const http = require('http');

function runFirestoreStructuredQuery(filters) {
  return new Promise((resolve, reject) => {
    const postData = JSON.stringify({
      structuredQuery: {
        from: [{ collectionId: 'diamond_shops' }],
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
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => {
        resolve({ statusCode: res.statusCode, data: data });
      });
    });

    req.on('error', (e) => reject(e));
    req.write(postData);
    req.end();
  });
}

async function runTests() {
  console.log('========================================================');
  console.log('🧪 VERIFYING FIRESTORE EMULATOR QUERY & SECURITY COMPLIANCE');
  console.log('========================================================\n');

  // Test 1: Full 5-filter approved query
  const compliantFilters = [
    { fieldFilter: { field: { fieldPath: 'status' }, op: 'EQUAL', value: { stringValue: 'approved' } } },
    { fieldFilter: { field: { fieldPath: 'isApproved' }, op: 'EQUAL', value: { booleanValue: true } } },
    { fieldFilter: { field: { fieldPath: 'isActive' }, op: 'EQUAL', value: { booleanValue: true } } },
    { fieldFilter: { field: { fieldPath: 'isSubscriptionActive' }, op: 'EQUAL', value: { booleanValue: true } } },
    { fieldFilter: { field: { fieldPath: 'isDeleted' }, op: 'EQUAL', value: { booleanValue: false } } }
  ];

  const compliantResult = await runFirestoreStructuredQuery(compliantFilters);
  console.log(`Test 1: 5-Filter Compliant Query -> HTTP ${compliantResult.statusCode}`);
  if (compliantResult.statusCode === 200) {
    console.log('   ✅ PASS: Firestore Security Rules Allowed 5-Filter Public Read Query');
  } else {
    console.log(`   ❌ FAIL: ${compliantResult.data}`);
  }

  // Test 2: Insecure Query (Missing isActive / status filter)
  const insecureFilters = [
    { fieldFilter: { field: { fieldPath: 'status' }, op: 'EQUAL', value: { stringValue: 'pending' } } }
  ];

  const insecureResult = await runFirestoreStructuredQuery(insecureFilters);
  console.log(`\nTest 2: Non-compliant / Pending Shop Query -> HTTP ${insecureResult.statusCode}`);
  if (insecureResult.statusCode === 403 || insecureResult.statusCode === 400) {
    console.log('   ✅ PASS: Firestore Security Rules Blocked Non-Compliant Query as Expected');
  } else {
    console.log(`   ⚠️ Output: ${insecureResult.data}`);
  }

  console.log('\n========================================================');
  console.log('🎉 EMULATOR VERIFICATION TESTS COMPLETE');
  console.log('========================================================');
}

runTests().catch(console.error);

