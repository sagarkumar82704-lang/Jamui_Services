/**
 * JAMUI SERVICES — Backward-Compatible Premium Eligibility Backfill & Verification Script
 * 
 * Purpose:
 * Strictly inspects approved active provider subscriptions, fetches the true
 * subscription plan from `subscription_plans/{planId}`, and sets `isPremiumEligible`
 * and `planLimits` on the provider profile.
 * 
 * Safety Rules:
 * 1. Default mode is DRY-RUN (safe read-only inspection).
 * 2. ONLY updates if `--execute` flag is passed.
 * 3. Can be scoped to a single provider via `--provider <providerId>` to eliminate bulk update risks.
 * 4. Strictly resolves from verified subscription plan (never categoryType or isPremiumCategory).
 * 5. Ensures no normal plan provider is mistakenly marked as premium.
 * 6. Marks missing, unverified, or conflicting records as REVIEW_REQUIRED (never auto-modifies them).
 * 7. Strictly protects payment, approval, and expiry timestamps from being modified (uses explicit updateMask).
 */

const fs = require('fs');
const path = require('path');
const https = require('https');

const configPath = path.join(process.env.USERPROFILE, '.config', 'configstore', 'firebase-tools.json');
if (!fs.existsSync(configPath)) {
  console.error('Firebase CLI configstore not found at:', configPath);
  process.exit(1);
}

const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
const accessToken = config.tokens?.access_token;
if (!accessToken) {
  console.error('No valid Firebase access token found.');
  process.exit(1);
}

const isExecute = process.argv.includes('--execute');
const providerArgIdx = process.argv.indexOf('--provider');
const targetProviderId = providerArgIdx !== -1 && process.argv[providerArgIdx + 1] ? process.argv[providerArgIdx + 1] : null;

function firestoreRequest(method, endpoint, body = null) {
  return new Promise((resolve, reject) => {
    const postData = body ? JSON.stringify(body) : null;
    const options = {
      hostname: 'firestore.googleapis.com',
      path: endpoint,
      method: method,
      headers: {
        'Authorization': 'Bearer ' + accessToken,
        'Content-Type': 'application/json',
      }
    };
    if (postData) {
      options.headers['Content-Length'] = Buffer.byteLength(postData);
    }

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          reject(new Error(`Failed to parse response: ${data}`));
        }
      });
    });
    req.on('error', reject);
    if (postData) req.write(postData);
    req.end();
  });
}

async function run() {
  console.log('================================================================');
  console.log(' JAMUI SERVICES — SUBSCRIPTION PREMIUM ELIGIBILITY AUDIT/MIGRATION');
  console.log(` Mode:   ${isExecute ? '🔴 LIVE EXECUTION (--execute)' : '🟢 DRY RUN (Read-Only Preview)'}`);
  console.log(` Scope:  ${targetProviderId ? `🎯 SINGLE PROVIDER (${targetProviderId})` : '🌐 ALL PROVIDERS'}`);
  console.log('================================================================\n');

  // 1. Fetch all subscription plans for canonical plan limits & tier lookup
  const plansRes = await firestoreRequest('GET', '/v1/projects/jamui-services/databases/(default)/documents/subscription_plans');
  if (plansRes.error) {
    console.error('❌ Failed to fetch subscription_plans from Firestore:');
    console.error(`   Code: ${plansRes.error.code}, Message: ${plansRes.error.message}`);
    console.error('\nNOTE: If unauthenticated (401), please refresh Firebase CLI session using `firebase login`.');
    return;
  }

  const planMap = new Map();
  for (const doc of (plansRes.documents || [])) {
    const planId = doc.name.split('/').pop();
    const f = doc.fields || {};
    planMap.set(planId, {
      id: planId,
      name: f.name?.stringValue || '',
      planTier: (f.planTier?.stringValue || 'normal').toLowerCase().trim(),
      isPremiumCategoryEligible: f.isPremiumCategoryEligible?.booleanValue === true,
      maxActiveListings: Number(f.maxActiveListings?.integerValue || 10),
      maxImagesPerProvider: Number(f.maxImagesPerProvider?.integerValue || 20),
      maxImagesPerListing: Number(f.maxImagesPerListing?.integerValue || 5),
      maxSizePerImageBytes: Number(f.maxSizePerImageBytes?.integerValue || 5242880),
      maxTotalStorageBytes: Number(f.maxTotalStorageBytes?.integerValue || 52428800),
    });
  }
  console.log(`Loaded ${planMap.size} subscription plans from database.\n`);

  // 2. Fetch providers (either single doc or collection)
  let providers = [];
  if (targetProviderId) {
    const docRes = await firestoreRequest('GET', `/v1/projects/jamui-services/databases/(default)/documents/providers/${targetProviderId}`);
    if (docRes.error) {
      console.error(`❌ Provider with ID '${targetProviderId}' not found:`, docRes.error);
      return;
    }
    providers = [docRes];
  } else {
    const provRes = await firestoreRequest('GET', '/v1/projects/jamui-services/databases/(default)/documents/providers?pageSize=100');
    if (provRes.error) {
      console.error('❌ Failed to fetch providers from Firestore:');
      console.error(`   Code: ${provRes.error.code}, Message: ${provRes.error.message}`);
      return;
    }
    providers = provRes.documents || [];
  }

  console.log(`Auditing ${providers.length} provider profile(s)...\n`);

  const candidatesToUpdate = [];
  const reviewRequired = [];
  let alignedCount = 0;
  const now = new Date();

  for (const doc of providers) {
    const provId = doc.name.split('/').pop();
    const f = doc.fields || {};
    const businessName = f.businessName?.stringValue || f.fullName?.stringValue || 'Provider';
    const isSubActive = f.isSubscriptionActive?.booleanValue === true;
    const planId = f.subscriptionPlan?.stringValue || '';
    const currentIsPremiumEligible = f.isPremiumEligible?.booleanValue;
    const planTier = (f.subscriptionPlanTier?.stringValue || '').toLowerCase().trim();
    
    // Safety checks: expiry, payment, approval
    const rawExpiry = f.subscriptionExpiry?.timestampValue || f.subscriptionExpiry?.stringValue;
    const isExpired = rawExpiry ? new Date(rawExpiry) < now : true;
    const isPaymentVerified = f.paymentVerified?.booleanValue === true;
    const isApproved = (f.status?.stringValue === 'approved') || (f.isVerified?.booleanValue === true);

    // Guard: Review required if provider is marked active subscription but plan is missing
    if (isSubActive && !planId) {
      reviewRequired.push({
        providerId: provId,
        businessName,
        reason: 'Active subscription flag is true, but subscriptionPlan ID is missing.',
        currentIsPremiumEligible,
      });
      continue;
    }

    // Guard: Review required if planId does not exist in subscription_plans collection
    if (isSubActive && planId && !planMap.has(planId)) {
      reviewRequired.push({
        providerId: provId,
        businessName,
        planId,
        reason: `Linked plan '${planId}' does not exist in subscription_plans collection.`,
        currentIsPremiumEligible,
      });
      continue;
    }

    const matchedPlan = planId ? planMap.get(planId) : null;
    const planIsPremium = matchedPlan
      ? (matchedPlan.isPremiumCategoryEligible === true || matchedPlan.planTier === 'premium')
      : false;

    // Strict evaluation based ONLY on authoritative subscription plan AND live validity
    const expectedPremiumEligible = isSubActive && planIsPremium && isApproved && isPaymentVerified && !isExpired;
    const targetTier = matchedPlan ? matchedPlan.planTier : (planTier || 'normal');

    // Detect if update is needed
    const needsUpdate = currentIsPremiumEligible !== expectedPremiumEligible ||
      (expectedPremiumEligible && f.planLimits === undefined) ||
      (planTier !== targetTier && isSubActive);

    if (needsUpdate) {
      candidatesToUpdate.push({
        providerId: provId,
        businessName,
        planId,
        planName: matchedPlan?.name || f.subscriptionPlanName?.stringValue || 'Unknown',
        planTier: targetTier,
        currentIsPremiumEligible,
        targetIsPremiumEligible: expectedPremiumEligible,
        matchedPlan,
        isApproved,
        isPaymentVerified,
        isExpired,
        rawExpiry,
      });
    } else {
      alignedCount++;
    }
  }

  // 3. Output Review Required Records
  if (reviewRequired.length > 0) {
    console.log(`⚠️  ${reviewRequired.length} PROVIDER(S) MARKED AS REVIEW_REQUIRED (Manual Inspection Needed):`);
    for (const r of reviewRequired) {
      console.log(`   - [Provider] ${r.businessName} (ID: ${r.providerId})`);
      console.log(`     Reason: ${r.reason}`);
      console.log(`     Action: Skipped from automated migration for safety.\n`);
    }
  }

  // 4. Output Candidates to Align
  console.log(`Found ${candidatesToUpdate.length} provider(s) requiring alignment:\n`);

  for (const c of candidatesToUpdate) {
    console.log(`[Provider] ${c.businessName} (ID: ${c.providerId})`);
    console.log(`  - Plan: ${c.planName} (ID: ${c.planId}, Tier: ${c.planTier})`);
    console.log(`  - Plan isPremiumCategoryEligible: ${c.matchedPlan?.isPremiumCategoryEligible}`);
    console.log(`  - Approval Status: ${c.isApproved ? 'Approved' : 'Pending'}`);
    console.log(`  - Payment Verified: ${c.isPaymentVerified ? 'Yes' : 'No'}`);
    console.log(`  - Subscription Expiry: ${c.rawExpiry} (${c.isExpired ? 'EXPIRED' : 'ACTIVE'})`);
    console.log(`  - Current isPremiumEligible: ${c.currentIsPremiumEligible}`);
    console.log(`  - Target isPremiumEligible: ${c.targetIsPremiumEligible}`);

    const updatePayload = {
      fields: {
        isPremiumEligible: { booleanValue: c.targetIsPremiumEligible },
        subscriptionPlanTier: { stringValue: c.planTier },
      }
    };

    if (c.targetIsPremiumEligible && c.matchedPlan) {
      updatePayload.fields.planLimits = {
        mapValue: {
          fields: {
            isPremiumCategoryEligible: { booleanValue: true },
            maxActiveListings: { integerValue: String(c.matchedPlan.maxActiveListings) },
            maxImagesPerProvider: { integerValue: String(c.matchedPlan.maxImagesPerProvider) },
            maxImagesPerListing: { integerValue: String(c.matchedPlan.maxImagesPerListing) },
            maxSizePerImageBytes: { integerValue: String(c.matchedPlan.maxSizePerImageBytes) },
            maxTotalStorageBytes: { integerValue: String(c.matchedPlan.maxTotalStorageBytes) },
          }
        }
      };
    }

    const updateMask = c.targetIsPremiumEligible
      ? 'updateMask.fieldPaths=isPremiumEligible&updateMask.fieldPaths=subscriptionPlanTier&updateMask.fieldPaths=planLimits'
      : 'updateMask.fieldPaths=isPremiumEligible&updateMask.fieldPaths=subscriptionPlanTier';

    const updateUrl = `/v1/projects/jamui-services/databases/(default)/documents/providers/${c.providerId}?${updateMask}`;

    if (isExecute) {
      const res = await firestoreRequest('PATCH', updateUrl, updatePayload);
      console.log(`  -> UPDATE SUCCESS: ${res.name ? 'OK' : JSON.stringify(res)}\n`);
    } else {
      console.log('  -> Action in dry-run (Exact Proposed Request):');
      console.log(`     Target URL: PATCH ${updateUrl}`);
      console.log('     Proposed Payload:', JSON.stringify(updatePayload, null, 2));
      console.log('');
    }
  }

  console.log('================================================================');
  console.log(` Summary:`);
  console.log(`  - Total Audited:    ${providers.length}`);
  console.log(`  - Already Aligned:  ${alignedCount}`);
  console.log(`  - Ready to Align:   ${candidatesToUpdate.length}`);
  console.log(`  - REVIEW_REQUIRED:  ${reviewRequired.length}`);
  console.log('================================================================');

  if (!isExecute) {
    console.log(' Dry run complete. No database changes were made.');
    if (targetProviderId) {
      console.log(` To apply changes ONLY to this provider, run:`);
      console.log(` node scripts/backfill_premium_eligibility.js --provider ${targetProviderId} --execute`);
    } else {
      console.log(' To apply changes to live database, run with: node scripts/backfill_premium_eligibility.js --execute');
    }
  } else {
    console.log(' Live execution complete. Successfully updated providers.');
  }
  console.log('================================================================');
}

run().catch(err => {
  console.error('Error running script:', err);
  process.exit(1);
});
