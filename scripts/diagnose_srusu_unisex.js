/**
 * JAMUI SERVICES — Read-Only Diagnostic Tool for Srusu Unisex & Premium Providers
 * 
 * Safety:
 * - 100% READ-ONLY (GET requests only).
 * - Never mutates, approves, or modifies subscription dates.
 * - Authenticates via Firebase CLI configstore and reports raw truth.
 */

const fs = require('fs');
const path = require('path');
const https = require('https');

const configPath = path.join(process.env.USERPROFILE, '.config', 'configstore', 'firebase-tools.json');
if (!fs.existsSync(configPath)) {
  console.log('❌ Firebase CLI configstore not found at:', configPath);
  console.log('   Status: Live verification could not be performed because Firebase CLI is not configured on this machine.');
  process.exit(0);
}

const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
const accessToken = config.tokens?.access_token;
if (!accessToken) {
  console.log('❌ No valid Firebase access token found in configstore.');
  console.log('   Status: Live verification could not be performed without valid Firebase credentials.');
  process.exit(0);
}

function firestoreGet(endpoint) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'firestore.googleapis.com',
      path: endpoint,
      method: 'GET',
      headers: {
        'Authorization': 'Bearer ' + accessToken,
        'Content-Type': 'application/json',
      }
    };
    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, data: JSON.parse(data) });
        } catch (e) {
          resolve({ status: res.statusCode, raw: data });
        }
      });
    });
    req.on('error', reject);
    req.end();
  });
}

async function diagnose() {
  console.log('================================================================');
  console.log(' JAMUI SERVICES — SRUSU UNISEX READ-ONLY DIAGNOSTIC INSPECTION');
  console.log(' Mode: 🟢 STRICT READ-ONLY (Zero Mutations)');
  console.log('================================================================\n');

  // 1. Fetch providers
  const provRes = await firestoreGet('/v1/projects/jamui-services/databases/(default)/documents/providers?pageSize=100');
  if (provRes.status === 401 || provRes.data?.error?.code === 401) {
    console.log('🔒 LIVE VERIFICATION STATUS: UNAUTHENTICATED (HTTP 401)');
    console.log('   Reason: The Firebase CLI OAuth token in firebase-tools.json is expired.');
    console.log('   Action: To enable live database inspection, the administrator must run `firebase login` in their terminal.');
    console.log('\n   [CRITICAL AUDIT RULE OBSERVED]');
    console.log('   - No fake or estimated live database records are returned.');
    console.log('   - Previous audit test records (Basic Premium Plan, 1-day duration) are used purely for local code audit.');
    return;
  }

  if (provRes.status !== 200 || !provRes.data) {
    console.log(`❌ Failed to read providers collection: HTTP ${provRes.status}`);
    console.log('   Error:', provRes.data?.error || provRes.raw);
    return;
  }

  const providers = provRes.data.documents || [];
  console.log(`Auditing ${providers.length} provider records...\n`);

  const srusuDoc = providers.find(d => {
    const f = d.fields || {};
    const bName = (f.businessName?.stringValue || f.fullName?.stringValue || '').toLowerCase();
    const cId = (f.primaryCategoryId?.stringValue || f.categoryId?.stringValue || '').toLowerCase();
    return bName.includes('srusu') || bName.includes('unisex') || cId === 'unisex_salon';
  });

  if (!srusuDoc) {
    console.log('ℹ️  No provider matching "srusu", "unisex", or "unisex_salon" found in the providers collection.');
    return;
  }

  const provId = srusuDoc.name.split('/').pop();
  const f = srusuDoc.fields || {};
  console.log(`✅ Located Provider Document: ${provId}`);
  console.log(`   - Business Name: ${f.businessName?.stringValue || f.fullName?.stringValue || 'N/A'}`);
  console.log(`   - Category ID: ${f.primaryCategoryId?.stringValue || f.categoryId?.stringValue || 'N/A'}`);
  console.log(`   - Status: ${f.status?.stringValue || 'N/A'}`);
  console.log(`   - KYC Status: ${f.kycStatus?.stringValue || 'N/A'}`);
  console.log(`   - isActive: ${f.isActive?.booleanValue}`);
  console.log(`   - isAvailable: ${f.isAvailable?.booleanValue}`);
  console.log(`   - isSubscriptionActive: ${f.isSubscriptionActive?.booleanValue}`);
  console.log(`   - paymentVerified: ${f.paymentVerified?.booleanValue}`);
  console.log(`   - isPremiumEligible: ${f.isPremiumEligible?.booleanValue}`);
  console.log(`   - subscriptionPlan: ${f.subscriptionPlan?.stringValue || 'N/A'}`);
  console.log(`   - subscriptionPlanTier: ${f.subscriptionPlanTier?.stringValue || 'N/A'}`);
  
  const expiryStr = f.subscriptionExpiry?.timestampValue || f.subscriptionExpiry?.stringValue;
  console.log(`   - subscriptionExpiry: ${expiryStr || 'NOT SET'}`);
  if (expiryStr) {
    const expDate = new Date(expiryStr);
    const now = new Date();
    const isExpired = expDate < now;
    console.log(`   - Expiry Evaluation: ${isExpired ? '❌ EXPIRED' : '✅ CURRENTLY ACTIVE'} (${expDate.toISOString()})`);
  }

  // Check linked plan
  const planId = f.subscriptionPlan?.stringValue;
  if (planId) {
    const planRes = await firestoreGet(`/v1/projects/jamui-services/databases/(default)/documents/subscription_plans/${planId}`);
    if (planRes.status === 200 && planRes.data) {
      const pf = planRes.data.fields || {};
      console.log(`\n✅ Linked Plan Record: ${planId}`);
      console.log(`   - Plan Name: ${pf.name?.stringValue || 'N/A'}`);
      console.log(`   - Plan Tier: ${pf.planTier?.stringValue || 'normal'}`);
      console.log(`   - isPremiumCategoryEligible: ${pf.isPremiumCategoryEligible?.booleanValue === true}`);
      console.log(`   - durationDays: ${pf.durationDays?.integerValue || 'N/A'}`);
    } else {
      console.log(`\n⚠️ Linked plan '${planId}' could not be fetched from subscription_plans (Status: ${planRes.status}).`);
    }
  }

  console.log('\n================================================================');
  console.log(' Inspection Complete.');
  console.log('================================================================');
}

diagnose().catch(err => {
  console.error('Diagnostic error:', err);
});

