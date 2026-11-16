async function inspectStagingProducts() {
  const API_KEY = 'AIzaSyAB35pqPdAuLiVT5XRu_OmEjIT2NqC4zG0';
  const shopId = 'OXBV2Zink6TvWg5VefHPi53QkyV2';

  console.log('1. Authenticating as seller sk12@gmail.com...');
  const resp = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${API_KEY}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: 'sk12@gmail.com', password: '123456', returnSecureToken: true })
  });
  const authData = await resp.json();
  const idToken = authData.idToken;

  console.log('Seller authenticated! Fetching products subcollection via Firestore REST API...');

  // 1. Direct subcollection list
  const url = `https://firestore.googleapis.com/v1/projects/jamui-services-staging/databases/(default)/documents/diamond_shops/${shopId}/products`;
  const subRes = await fetch(url, {
    headers: { 'Authorization': `Bearer ${idToken}` }
  });
  const subData = await subRes.json();

  console.log('\n--- diamond_shops/${shopId}/products docs ---');
  if (subData.documents && subData.documents.length > 0) {
    console.log(`Found ${subData.documents.length} products:`);
    for (const doc of subData.documents) {
      console.log('Doc name:', doc.name);
      console.log('Fields:', JSON.stringify(doc.fields, null, 2));
    }
  } else {
    console.log('No documents found in diamond_shops/${shopId}/products. Response:', JSON.stringify(subData));
  }

  // 2. Also check top-level diamond_products just in case
  const topUrl = `https://firestore.googleapis.com/v1/projects/jamui-services-staging/databases/(default)/documents/diamond_products`;
  const topRes = await fetch(topUrl, {
    headers: { 'Authorization': `Bearer ${idToken}` }
  });
  const topData = await topRes.json();
  console.log('\n--- top-level diamond_products docs ---');
  if (topData.documents && topData.documents.length > 0) {
    console.log(`Found ${topData.documents.length} products in diamond_products:`);
    for (const doc of topData.documents) {
      console.log('Doc name:', doc.name);
    }
  } else {
    console.log('No documents in top-level diamond_products. Response:', JSON.stringify(topData));
  }

  // 3. Test the exact compound query that fetchProductsPaginated runs!
  console.log('\n--- Testing exact query: isDeleted == false, orderBy createdAt DESC ---');
  const runQueryUrl = `https://firestore.googleapis.com/v1/projects/jamui-services-staging/databases/(default)/documents/diamond_shops/${shopId}:runQuery`;
  const queryBody = {
    structuredQuery: {
      from: [{ collectionId: 'products' }],
      where: {
        fieldFilter: {
          field: { fieldPath: 'isDeleted' },
          op: 'EQUAL',
          value: { booleanValue: false }
        }
      },
      orderBy: [
        {
          field: { fieldPath: 'createdAt' },
          direction: 'DESCENDING'
        }
      ],
      limit: 25
    }
  };

  const qRes = await fetch(runQueryUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${idToken}`
    },
    body: JSON.stringify(queryBody)
  });
  const qData = await qRes.json();
  console.log('Query result:', JSON.stringify(qData, null, 2));
}

inspectStagingProducts().catch(e => console.error(e));

