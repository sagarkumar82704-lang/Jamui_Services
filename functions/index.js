const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { setGlobalOptions } = require('firebase-functions/v2');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');
const { FieldValue } = require('firebase-admin/firestore');
const crypto = require('crypto');
const Razorpay = require('razorpay');

// Configure global deployment region (Mumbai, India for lowest latency in Bihar)
setGlobalOptions({ region: 'asia-south1', maxInstances: 10 });

// Initialize Firebase Admin SDK
if (admin.apps.length === 0) {
  admin.initializeApp();
}
const db = admin.firestore();

// Ensure FieldValue is available under all runtimes (including Functions Emulator)
if (!admin.firestore.FieldValue) {
  try {
    admin.firestore.FieldValue = require('firebase-admin/firestore').FieldValue;
  } catch (_) {}
}

// Secret Manager declarations for 2nd Gen Functions
const RAZORPAY_SECRETS = ['RAZORPAY_KEY_ID', 'RAZORPAY_KEY_SECRET', 'RAZORPAY_WEBHOOK_SECRET'];

// Single Source of Truth Rule:
// All subscription plans MUST originate from Firebase Firestore `subscription_plans` collection.
// Hardcoded plans, prices, durations, or fallbacks are strictly prohibited across backend handlers.

/**
 * Validates that a candidate secret is an actual signing secret and not an accidental URL or endpoint.
 */
function isValidWebhookSecret(sec) {
  if (!sec || typeof sec !== 'string') return false;
  const trimmed = sec.trim();
  if (trimmed.length < 8 || trimmed.startsWith('*')) return false;
  const lower = trimmed.toLowerCase();
  if (lower.startsWith('http://') || lower.startsWith('https://')) return false;
  if (trimmed.includes('/') || trimmed.includes('\\') || lower.includes('.cloudfunctions.net') || lower.includes('.run.app')) {
    return false;
  }
  return true;
}

/**
 * Retrieves Razorpay configuration from Cloud Firestore `app_config/payment` or environment variables.
 * Enforces strict validation on webhook signing secrets so URLs are never accepted as cryptographic keys.
 */
async function getRazorpayCredentials() {
  let keyId = process.env.RAZORPAY_KEY_ID || '';
  let keySecret = process.env.RAZORPAY_KEY_SECRET || '';
  let rawEnvWebhookSecret = process.env.RAZORPAY_WEBHOOK_SECRET || '';
  let webhookSecret = '';

  // 1. Validate environment variable RAZORPAY_WEBHOOK_SECRET
  if (rawEnvWebhookSecret) {
    if (isValidWebhookSecret(rawEnvWebhookSecret)) {
      webhookSecret = rawEnvWebhookSecret.trim();
    } else {
      logger.error('CRITICAL CONFIGURATION ERROR: RAZORPAY_WEBHOOK_SECRET in environment/Secret Manager appears to be a URL or invalid string instead of a signing secret key. Ignoring invalid environment variable.');
    }
  }

  // Read public keyId from app_config/payment if not set in environment variables
  if (!keyId) {
    try {
      const configDoc = await db.collection('app_config').doc('payment').get();
      if (configDoc.exists) {
        const data = configDoc.data();
        keyId = data?.razorpay_key_id || data?.keyId || data?.key_id || '';
      }
    } catch (error) {
      logger.warn('Failed to read app_config/payment from Firestore:', error);
    }
  }

  // Also check secure app_config/payment_secrets (restricted from client access via Security Rules)
  if (!keySecret || keySecret.startsWith('*')) {
    try {
      const secretDoc = await db.collection('app_config').doc('payment_secrets').get();
      if (secretDoc.exists) {
        const sData = secretDoc.data();
        const firestoreSecret = (sData?.keySecret || sData?.razorpay_key_secret || sData?.key_secret || '').trim();
        if (firestoreSecret && !firestoreSecret.startsWith('*')) {
          keySecret = firestoreSecret;
        }
      }
    } catch (_) {}
  }

  // Dedicated webhook secret lookup: If env webhook secret was absent or invalid, inspect secure payment_secrets doc
  if (!webhookSecret) {
    try {
      const secretDoc = await db.collection('app_config').doc('payment_secrets').get();
      if (secretDoc.exists) {
        const sData = secretDoc.data();
        const firestoreWebhook = (sData?.webhookSecret || sData?.razorpay_webhook_secret || '').trim();
        if (isValidWebhookSecret(firestoreWebhook)) {
          webhookSecret = firestoreWebhook;
          logger.info('Securely resolved valid Razorpay Webhook Secret from Firestore app_config/payment_secrets fallback.');
        } else if (firestoreWebhook) {
          logger.error('CRITICAL: Firestore app_config/payment_secrets webhookSecret is also invalid or contains a URL.');
        }
      }
    } catch (secErr) {
      logger.warn('Failed to read webhookSecret fallback from payment_secrets:', secErr);
    }
  }

  const cleanKeyId = (keyId || '').trim();
  const cleanKeySecret = (keySecret || '').trim();
  const cleanWebhookSecret = (webhookSecret || '').trim();

  if (cleanKeySecret.startsWith('*')) {
    logger.error('⚠️ [CRITICAL] RAZORPAY_KEY_SECRET contains masked asterisks (***) instead of actual alphanumeric secret key.');
  }

  if (!cleanWebhookSecret) {
    logger.warn('⚠️ [WARNING] No valid Razorpay Webhook Secret resolved. Webhook signature verification will fail-closed (HTTP 401).');
  }

  return {
    keyId: cleanKeyId,
    keySecret: cleanKeySecret,
    webhookSecret: cleanWebhookSecret,
  };
}

/**
 * Authoritatively verifies whether a caller is an active, authorized administrator.
 * Invariant: `admin_users` is the authoritative source of truth.
 * - Non-admin users (missing admin_users record) are strictly rejected with 'permission-denied'.
 * - Inactive or suspended admin accounts are strictly rejected with 'permission-denied'.
 * - Super admin operations require role 'super_admin' or 'superAdmin' in admin_users record.
 * - Safely supports looking up admin_users by UID, and falls back to looking up admin_users
 *   by verified auth email if doc(uid) is not yet bound, preserving existing production admins
 *   without requiring any database mutations, while strictly rejecting any unlisted or suspended accounts.
 */
async function verifyActiveAdmin(request, options = {}) {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const callerUid = request.auth.uid;
  const callerEmail = request.auth.token?.email ? String(request.auth.token.email).trim().toLowerCase() : null;

  let adminDoc = await db.collection('admin_users').doc(callerUid).get();
  if (!adminDoc.exists && callerEmail) {
    try {
      const emailQuery = await db.collection('admin_users')
        .where('email', '==', callerEmail)
        .limit(1)
        .get();
      if (!emailQuery.empty) {
        adminDoc = emailQuery.docs[0];
      }
    } catch (e) {
      logger.warn(`Admin email lookup error for ${callerEmail}:`, e?.message || e);
    }
  }

  if (!adminDoc || !adminDoc.exists) {
    logger.warn(`Unauthorized admin attempt: UID ${callerUid} (email: ${callerEmail}) does not exist in admin_users.`);
    throw new HttpsError('permission-denied', 'Only authorized administrators can perform this operation.');
  }

  const adminData = adminDoc.data() || {};
  const isSuspended = (adminData.status && adminData.status !== 'active') || adminData.isActive === false;
  if (isSuspended) {
    logger.warn(`Inactive/suspended admin ${callerUid} attempted privileged operation.`);
    throw new HttpsError('permission-denied', 'Admin account is inactive or suspended.');
  }

  if (options.requireSuperAdmin) {
    const isSuperAdmin = adminData.role === 'super_admin' || adminData.role === 'superAdmin';
    if (!isSuperAdmin) {
      logger.warn(`Non-super_admin UID ${callerUid} attempted super_admin operation.`);
      throw new HttpsError('permission-denied', 'This operation requires Super Admin privileges.');
    }
  }

  return { uid: callerUid, adminDoc, adminData, email: callerEmail || adminData.email || '' };
}

/**
 * Evaluates provider eligibility server-side based on actual registration age,
 * payment history, approved category, and subscription plan tier.
 * Authoritative: Separates category from plan tier, validates admin approval & entitlement.
 */
async function determineProviderEligibility(providerId) {
  if (!providerId) {
    return {
      type: 'new_provider',
      isRenewal: false,
      isExisting: false,
      hasPaidBefore: false,
      planTier: 'normal',
      isPremiumEligible: false,
      currentPlanTier: 'normal',
    };
  }

  try {
    const provDoc = await db.collection('providers').doc(providerId).get();
    if (!provDoc.exists) {
      return {
        type: 'new_provider',
        isRenewal: false,
        isExisting: false,
        hasPaidBefore: false,
        planTier: 'normal',
        isPremiumEligible: false,
        currentPlanTier: 'normal',
      };
    }

    const pData = provDoc.data() || {};
    const hasPaid = pData.paymentVerified === true;
    const isSubActive = pData.isSubscriptionActive === true;
    const plan = pData.subscriptionPlan;

    // Check historical subscription records
    let subHistoryExists = false;
    let lastSubscriptionTier = null;
    try {
      const subSnap = await db.collection('subscriptions')
        .where('providerId', '==', providerId)
        .limit(1)
        .get();
      if (!subSnap.empty) {
        subHistoryExists = true;
        const subData = subSnap.docs[0].data() || {};
        if (subData.planTier) {
          lastSubscriptionTier = (subData.planTier === 'premium') ? 'premium' : 'normal';
        }
      }
    } catch (_) {}

    const hasPaidBefore = hasPaid || subHistoryExists;

    // Calculate days since registration
    let daysSinceRegistration = 0;
    if (pData.createdAt) {
      const createdDate = pData.createdAt.toDate ? pData.createdAt.toDate() : new Date(pData.createdAt);
      daysSinceRegistration = (Date.now() - createdDate.getTime()) / (1000 * 60 * 60 * 24);
    }

    const isRenewal = hasPaidBefore || isSubActive || daysSinceRegistration > 14 || (plan && plan !== 'free_trial' && plan !== 'none');

    // Authoritative Provider Tier Resolution (Normal vs Premium)
    // 1. Current or historical subscription tier entitlement
    const subTier = (pData.subscriptionPlanTier || lastSubscriptionTier || '').toString().toLowerCase().trim();

    // 2. Explicit Admin Approval on provider profile
    const isAdminPremiumApproved = pData.isPremiumEligible === true;

    // 3. Category Evaluation in Firestore collections
    let isCategoryPremium = false;
    const catId = (pData.approvedCategoryId || pData.primaryCategoryId || pData.categoryId || pData.selectedCategoryId || '').toString().trim();
    if (catId) {
      try {
        // A. Check premium_categories collection
        const premCatDoc = await db.collection('premium_categories').doc(catId).get();
        if (premCatDoc && premCatDoc.exists && premCatDoc.data()?.isActive !== false) {
          isCategoryPremium = true;
        } else {
          const premCatQuery = await db.collection('premium_categories')
            .where('categoryId', '==', catId)
            .limit(1)
            .get();
          if (premCatQuery && !premCatQuery.empty && premCatQuery.docs[0].data()?.isActive !== false) {
            isCategoryPremium = true;
          }
        }

        // B. Check categories collection if not already confirmed
        if (!isCategoryPremium) {
          const catDoc = await db.collection('categories').doc(catId).get();
          if (catDoc && catDoc.exists) {
            const catData = catDoc.data() || {};
            if (catData.categoryType === 'premium' || catData.isPremium === true) {
              isCategoryPremium = true;
            }
          }
        }
      } catch (catErr) {
        logger.warn(`Error resolving category ${catId} premium status for provider ${providerId}:`, catErr);
      }
    }

    // Also check provider profile's categoryType or isPremiumCategory flags
    const profileCategoryType = (pData.categoryType || '').toString().toLowerCase().trim();
    const isProfileCategoryPremium = profileCategoryType === 'premium' || pData.isPremiumCategory === true;

    // Authoritative Tier determination for subscription plan visibility & purchasing:
    // Priority:
    // 1. Current / historical verified subscription tier entitlement
    // 2. Explicit Admin Approval on profile (pData.isPremiumEligible === true)
    // 3. Provider registered under canonical Premium category (e.g. unisex_salon) -> can view & purchase Premium plans even while status is 'pendingReview'!
    // 4. Default: 'normal'
    let providerTier = 'normal';

    if (isRenewal && subTier) {
      // For existing / renewal providers with historical subTier:
      if (subTier === 'premium') {
        providerTier = 'premium';
      } else if (subTier === 'normal') {
        providerTier = isCategoryPremium ? 'premium' : 'normal';
      }
    } else {
      // For new or pending providers:
      // A provider registered under an eligible canonical Premium category such as unisex_salon
      // MUST be able to see and purchase Premium subscription plans even when status is 'pendingReview'.
      // Canonical category metadata from premium_categories determines this.
      if (isAdminPremiumApproved || isCategoryPremium) {
        providerTier = 'premium';
      } else {
        providerTier = 'normal';
      }
    }

    return {
      type: isRenewal ? 'existing_provider' : 'new_provider',
      isRenewal: isRenewal,
      isExisting: isRenewal,
      hasPaidBefore: hasPaidBefore,
      daysSinceRegistration: Math.round(daysSinceRegistration),
      providerName: pData.fullName || pData.businessName || 'Service Provider',
      planTier: providerTier, // Authoritative 'normal' | 'premium'
      isPremiumEligible: providerTier === 'premium',
      currentPlanTier: subTier || providerTier,
    };
  } catch (err) {
    logger.warn(`Error evaluating eligibility for provider ${providerId}:`, err);
    return {
      type: 'new_provider',
      isRenewal: false,
      isExisting: false,
      hasPaidBefore: false,
      planTier: 'normal',
      isPremiumEligible: false,
      currentPlanTier: 'normal',
    };
  }
}

/**
 * 1. GET SUBSCRIPTION PLANS
 * Returns active subscription plans tailored to provider's verified eligibility
 */
exports.getSubscriptionPlans = onCall({ cors: true }, async (request) => {
  const providerId = request.data?.providerId || request.auth?.uid;
  let eligibility = null;

  if (providerId) {
    eligibility = await determineProviderEligibility(providerId);
  }

  try {
    const requestedTier = request.data?.planTier || request.data?.tier;
    const snapshot = await db.collection('subscription_plans').where('isActive', '==', true).get();
    let allPlans = [];
    if (!snapshot.empty) {
      allPlans = snapshot.docs
        .map(doc => {
          const pData = doc.data() || {};
          const rawTier = (pData.planTier || '').toString().toLowerCase().trim();
          return {
            id: doc.id,
            ...pData,
            planTier: (rawTier === 'premium') ? 'premium' : 'normal',
          };
        })
        .filter(p => Number(p.price) > 0 && Number(p.durationDays) > 0);
    }

    // 1. Authoritative Provider-Specific Filtering
    if (eligibility) {
      const eligibleTier = eligibility.planTier || 'normal';
      const target = eligibility.type; // 'new_provider' or 'existing_provider'

      // STRICT RULE 1: Tier filtering (Normal vs Premium - ZERO mixing)
      let matchingPlans = allPlans.filter(p => p.planTier === eligibleTier);

      // STRICT RULE 2: Target Audience filtering (New vs Renewal)
      let audienceFiltered = matchingPlans.filter(p => {
        const audience = p.targetAudience || 'new_provider';
        return audience === target || audience === 'all';
      });

      // If audience filter has matching plans, return them; otherwise keep tier-matching plans
      if (audienceFiltered.length > 0) {
        matchingPlans = audienceFiltered;
      }

      return {
        plans: matchingPlans,
        providerEligibility: eligibility,
      };
    }

    // 2. Generic Query (No providerId provided, e.g. admin or guest inquiry)
    if (requestedTier && (requestedTier === 'normal' || requestedTier === 'premium')) {
      allPlans = allPlans.filter(p => p.planTier === requestedTier);
    }

    return allPlans;
  } catch (error) {
    logger.error('Error reading subscription_plans from Firestore:', error);
    return { plans: [], providerEligibility: eligibility, error: 'Failed to read active plans from database' };
  }
});

/**
 * 2. CREATE RAZORPAY SUBSCRIPTION ORDER
 * Authoritative server-side calculation: Validates eligibility, applies discounts, ignores client price.
 */
exports.createSubscriptionOrder = onCall({ cors: true, secrets: RAZORPAY_SECRETS }, async (request) => {
  const { planId, providerId } = request.data || {};

  if (!planId || !providerId || typeof providerId !== 'string' || typeof planId !== 'string') {
    throw new HttpsError('invalid-argument', 'Both planId and providerId are required valid strings.');
  }

  // 1. Enforce Authentication & Identity Verification (Strict Security)
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError('unauthenticated', 'सब्सक्रिप्शन आर्डर बनाने के लिए ऑथेंटिकेशन (Authentication) अनिवार्य है।');
  }

  // Strictly verify caller matches providerId, or caller is an authorized active admin in 'admin_users'
  const callerUid = request.auth.uid;
  if (callerUid !== providerId) {
    await verifyActiveAdmin(request);
  }

  // 2. Strictly enforce that providerId exists in 'providers' collection (Customer accounts cannot initiate provider subscriptions)
  const providerRef = db.collection('providers').doc(providerId);
  const providerDoc = await providerRef.get();
  if (!providerDoc.exists) {
    throw new HttpsError('permission-denied', 'Only registered providers can purchase subscriptions. Customer accounts are not authorized.');
  }

  const providerData = providerDoc.data() || {};

  // 3. Strict Double Payment & Pending Activation Concurrency Guard
  // Guard A: Provider Profile check - if an order is verified and awaiting admin approval
  if (providerData.subscriptionApprovalStatus === 'pending_approval' && providerData.paymentVerified === true) {
    const existingRef = providerData.paymentOrderId || 'लंबित आर्डर';
    logger.warn(`Rejected duplicate subscription order creation for provider ${providerId}: active payment (${existingRef}) is currently awaiting Admin Approval.`);
    throw new HttpsError(
      'failed-precondition',
      `आपका पिछला भुगतान (Order ID: ${existingRef}) पहले से प्राप्त हो चुका है और Admin Approval के लिए लंबित है। कृपया सक्रिय होने की प्रतीक्षा करें।`
    );
  }

  // Guard B: Active unexpired renewal check - if early renewal is already pending approval
  if (providerData.renewalPendingOrderId) {
    logger.warn(`Rejected duplicate renewal order creation for provider ${providerId}: renewal order (${providerData.renewalPendingOrderId}) is already awaiting Admin Approval.`);
    throw new HttpsError(
      'failed-precondition',
      `आपका रिन्यूअल भुगतान (Order ID: ${providerData.renewalPendingOrderId}) पहले से प्राप्त हो चुका है और Admin Approval के लिए लंबित है। कृपया सक्रिय होने की प्रतीक्षा करें।`
    );
  }

  // Guard C: Authoritative Collections check - verify no captured payments are in 'pending_approval'
  try {
    const pendingSnap = await db.collection('payments')
      .where('providerId', '==', providerId)
      .where('status', '==', 'success')
      .where('captured', '==', true)
      .where('adminApprovalStatus', '==', 'pending_approval')
      .limit(1)
      .get();

    if (!pendingSnap.empty) {
      const pDocData = pendingSnap.docs[0].data() || {};
      const pendingOrderId = pDocData.orderId || pendingSnap.docs[0].id;
      logger.warn(`Rejected duplicate order for provider ${providerId}: Captured payment document ${pendingOrderId} is awaiting Admin Approval.`);
      throw new HttpsError(
        'failed-precondition',
        `आपका पिछला भुगतान (Order ID: ${pendingOrderId}) पहले से प्राप्त हो चुका है और Admin Approval के लिए लंबित है। कृपया दोबारा भुगतान न करें।`
      );
    }
  } catch (queryErr) {
    if (queryErr instanceof HttpsError) throw queryErr;
    logger.warn('Warning during pending payment collection lookup in createSubscriptionOrder:', queryErr?.message || queryErr);
  }

  // 4. Authoritative server-side resolution of provider identity
  // Trusted sources ONLY: Firebase Auth record / decoded Auth token.
  // CRITICAL SECURITY RULE: Firestore providerData.email alone is NEVER accepted as proof of authenticated email!
  // NEVER trust unverified client request.data for identity!
  let authPhone = null;
  let authEmail = null;
  try {
    const authUser = await admin.auth().getUser(providerId);
    authPhone = authUser.phoneNumber || null;
    authEmail = authUser.email || null;
  } catch (err) {
    logger.warn(`Could not fetch Auth record for provider ${providerId}:`, err);
  }

  // Strictly resolve identity from verified server-side sources only
  const callerIsSelf = callerUid === providerId;
  const callerTokenEmail = callerIsSelf ? (request.auth.token?.email || null) : null;
  const callerTokenPhone = callerIsSelf ? (request.auth.token?.phone_number || null) : null;

  // Trusted email must strictly originate from Firebase Auth (authUser or verified auth token)
  const trustedEmail = authEmail || callerTokenEmail || '';
  const trustedPhone = authPhone || callerTokenPhone || providerData.phoneNumber || providerData.phone || '';

  // Require that the provider has at least one authoritative verified identity (Email or Phone)
  if (!trustedEmail && !trustedPhone) {
    throw new HttpsError(
      'failed-precondition',
      'प्रदाता के खाते में कोई अधिकृत ईमेल या सत्यापित मोबाइल नंबर नहीं मिला। कृपया अपनी प्रोफाइल विवरण की जांच करें।'
    );
  }

  // Sync verified Firebase Auth phone to Firestore profile ONLY if cryptographically verified by Firebase Auth
  // Unverified client strings are NEVER written to the provider's trusted profile.
  if (authPhone && !providerData.phoneNumber) {
    try {
      await providerRef.update({
        phoneNumber: authPhone,
        phone: authPhone,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // 4. Fetch Authoritative Plan Data strictly from Firestore (No hardcoded fallback allowed)
  let planDoc = null;
  try {
    planDoc = await db.collection('subscription_plans').doc(planId).get();
  } catch (error) {
    logger.error(`Database error fetching plan ${planId}:`, error);
    throw new HttpsError('internal', 'डेटाबेस से प्लान लोड करने में विफलता।');
  }

  if (!planDoc || !planDoc.exists || planDoc.data()?.isActive !== true) {
    logger.warn(`Rejected order creation: Plan '${planId}' does not exist or is inactive.`);
    throw new HttpsError('not-found', `सब्सक्रिप्शन प्लान '${planId}' अमान्य या निष्क्रिय है।`);
  }

  const planData = { id: planDoc.id, ...planDoc.data() };

  // Strict Validation: Price and durationDays MUST be valid positive numbers
  const rawPrice = Number(planData.price);
  if (!Number.isFinite(rawPrice) || rawPrice <= 0) {
    logger.error(`Rejected order creation: Plan '${planId}' has invalid price (${planData.price}).`);
    throw new HttpsError('failed-precondition', 'प्लान कंफिगरेशन अमान्य है: मूल्य ₹0 से अधिक होना चाहिए।');
  }

  const rawDuration = Number(planData.durationDays);
  if (!Number.isSafeInteger(rawDuration) || rawDuration <= 0) {
    logger.error(`Rejected order creation: Plan '${planId}' has invalid durationDays (${planData.durationDays}).`);
    throw new HttpsError('failed-precondition', 'प्लान कंफिगरेशन अमान्य है: सदस्यता अवधि (durationDays) 0 से अधिक होनी चाहिए।');
  }

  // 5. Authoritative Server-Side Eligibility & Pricing Calculation
  const eligibility = await determineProviderEligibility(providerId);
  const eligibleTier = eligibility.planTier || 'normal';
  const rawPlanTier = (planData.planTier || '').toString().toLowerCase().trim();
  const planTier = (rawPlanTier === 'premium') ? 'premium' : 'normal';
  const targetAudience = planData.targetAudience || 'new_provider';

  // STRICT TIER VALIDATION (Normal Provider can ONLY buy Normal plan; Premium Provider can ONLY buy Premium plan)
  if (planTier !== eligibleTier) {
    logger.warn(`createSubscriptionOrder rejected: Provider ${providerId} is in tier '${eligibleTier}', but tried to purchase plan '${planId}' in tier '${planTier}'.`);
    throw new HttpsError(
      'permission-denied',
      eligibleTier === 'normal'
        ? 'आप केवल Normal सब्सक्रिप्शन प्लान खरीदने के लिए पात्र हैं। Premium प्लान खरीदने की अनुमति नहीं है।'
        : 'आप केवल Premium सब्सक्रिप्शन प्लान खरीदने के लिए पात्र हैं। Normal प्लान खरीदने की अनुमति नहीं है।'
    );
  }

  // STRICT TARGET AUDIENCE VALIDATION (New vs Existing / Renewal)
  if (targetAudience !== 'all' && targetAudience !== eligibility.type) {
    logger.warn(`createSubscriptionOrder rejected: Target audience mismatch for plan '${planId}' (plan expects '${targetAudience}', provider is '${eligibility.type}').`);
    throw new HttpsError(
      'failed-precondition',
      eligibility.type === 'existing_provider'
        ? 'यह प्लान केवल नए प्रोवाइडर्स के लिए मान्य है। कृपया रिन्यूअल प्लान चुनें।'
        : 'यह प्लान केवल मौजूदा प्रोवाइडर्स / रिन्यूअल के लिए मान्य है।'
    );
  }

  // STRICT RENEWAL CROSS-TIER SWITCH GUARD
  // If provider has an active unexpired subscription, prevent cross-tier renewal hijack
  if (eligibility.isRenewal && eligibility.currentPlanTier && eligibility.currentPlanTier !== planTier) {
    logger.warn(`createSubscriptionOrder rejected: Provider ${providerId} attempted cross-tier renewal from '${eligibility.currentPlanTier}' to '${planTier}'.`);
    throw new HttpsError(
      'permission-denied',
      'सक्रिय सदस्यता के नवीनीकरण (Renewal) के दौरान सब्सक्रिप्शन टियर बदलना प्रतिबंधित है।'
    );
  }

  let priceInRupees = rawPrice;

  // Apply discount if existing provider plan has valid discount percentage
  let discountApplied = 0.0;
  if (eligibility.type === 'existing_provider' && planData.discountPercentage && Number(planData.discountPercentage) > 0) {
    discountApplied = Math.round((priceInRupees * Number(planData.discountPercentage)) / 100.0);
    priceInRupees = Math.max(1.0, priceInRupees - discountApplied);
  }

  const amountInPaise = Math.round(priceInRupees * 100);
  if (!Number.isSafeInteger(amountInPaise) || amountInPaise < 100) {
    throw new HttpsError('failed-precondition', 'आर्डर राशि अमान्य है (न्यूनतम ₹1.00 / 100 पैसे आवश्यक है)।');
  }
  const planName = String(planData.name || 'Subscription Plan');

  const { keyId, keySecret } = await getRazorpayCredentials();
  let orderId = '';

  // 6. Generate Razorpay Cloud Order with authoritative verified phone & email
  if (keySecret && keySecret !== 'your_razorpay_secret_here') {
    try {
      const instance = new Razorpay({
        key_id: keyId,
        key_secret: keySecret,
      });

      const options = {
        amount: amountInPaise,
        currency: 'INR',
        receipt: `rcpt_${providerId.substring(0, 10)}_${Date.now()}`,
        payment_capture: 1, // Authoritative SDK instruction for auto-capture
        notes: {
          providerId,
          planId,
          planName,
          planTier,
          targetAudience,
          providerPhone: trustedPhone,
          providerEmail: trustedEmail,
          providerType: eligibility.type,
          isRenewal: eligibility.isRenewal ? 'true' : 'false',
        },
      };

      const order = await instance.orders.create(options);
      orderId = order.id;
      logger.info(`Successfully generated Razorpay Cloud Order: ${orderId} (Amount: ₹${priceInRupees}, Phone: ${trustedPhone}, Type: ${eligibility.type})`);
    } catch (apiError) {
      logger.error('Razorpay API order creation failed:', apiError);
      throw new HttpsError(
        'internal',
        'पेमेंट गेटवे आर्डर बनाने में विफलता। कृपया कुछ समय बाद पुनः प्रयास करें या सहायता टीम से संपर्क करें।'
      );
    }
  } else {
    logger.warn('RAZORPAY_KEY_SECRET is not configured in backend.');
    throw new HttpsError(
      'failed-precondition',
      'पेमेंट गेटवे सर्वर त्रुटि। कृपया सहायता टीम से संपर्क करें।'
    );
  }

  const providerName = eligibility.providerName || 'Service Provider';
  const basePriceInRupees = rawPrice;
  const basePriceInPaise = Math.round(basePriceInRupees * 100);
  const durationDays = rawDuration;
  const categoryLimit = Number(planData.categoryLimit || 1);

  // 7. Persist Order in Firestore payments collection with Authoritative Immutable Pricing Snapshot
  try {
    const pricingSnapshot = {
      planId: planId,
      planName: planName,
      planTier: planTier,
      basePriceInRupees: basePriceInRupees,
      basePriceInPaise: basePriceInPaise,
      discountApplied: discountApplied,
      amount: priceInRupees,
      amountInPaise: amountInPaise,
      currency: 'INR',
      durationDays: durationDays,
      categoryLimit: categoryLimit,
      targetAudience: targetAudience,
      providerType: eligibility.type,
      isRenewal: eligibility.isRenewal,
      snapshotAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await db.collection('payments').doc(orderId).set({
      id: orderId,
      orderId: orderId,
      providerId: providerId,
      providerName: providerName,
      userName: providerName,
      phoneNumber: trustedPhone,
      email: trustedEmail,
      planId: planId,
      planName: planName,
      planTier: planTier,
      targetAudience: targetAudience,
      providerType: eligibility.type,
      isRenewal: eligibility.isRenewal,
      discountApplied: discountApplied,
      amount: priceInRupees,
      amountInPaise: amountInPaise,
      basePriceInRupees: basePriceInRupees,
      basePriceInPaise: basePriceInPaise,
      durationDays: durationDays,
      categoryLimit: categoryLimit,
      pricingSnapshot: pricingSnapshot,
      currency: 'INR',
      status: 'created',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (dbError) {
    logger.error('Failed to log payment order in Firestore:', dbError);
  }

  return {
    orderId,
    amount: amountInPaise,
    currency: 'INR',
    keyId,
    planId,
    planName,
    planTier,
    targetAudience,
    providerType: eligibility.type,
    discountApplied,
    verifiedPhone: trustedPhone,
    verifiedEmail: trustedEmail,
  };
});

/**
 * 3. VERIFY RAZORPAY SUBSCRIPTION PAYMENT
 * Validates HMAC-SHA256 signature server-side and atomically activates the provider's subscription.
 */
exports.verifySubscriptionPayment = onCall({ cors: true, secrets: RAZORPAY_SECRETS }, async (request) => {
  const { providerId, planId, razorpayOrderId, razorpayPaymentId, razorpaySignature } = request.data || {};

  if (!providerId || !planId || !razorpayOrderId || !razorpayPaymentId || !razorpaySignature) {
    throw new HttpsError('invalid-argument', 'Incomplete payment verification payload.');
  }

  // 1. Verify caller identity with mandatory authentication
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError('unauthenticated', 'भुगतान सत्यापन के लिए ऑथेंटिकेशन (Authentication) अनिवार्य है।');
  }

  let isCallerAdmin = false;
  if (request.auth.uid !== providerId) {
    try {
      await verifyActiveAdmin(request);
      isCallerAdmin = true;
    } catch (_) {
      isCallerAdmin = false;
    }
    if (!isCallerAdmin) {
      throw new HttpsError('permission-denied', 'You are not authorized to verify payments for this provider.');
    }
  }

  // Strictly enforce that provider exists in 'providers' collection
  const providerRef = db.collection('providers').doc(providerId);
  const providerDoc = await providerRef.get();
  if (!providerDoc.exists) {
    throw new HttpsError('permission-denied', 'Invalid provider account. Cannot verify subscription payment.');
  }

  const { keyId, keySecret } = await getRazorpayCredentials();

  // 2. Cryptographic HMAC-SHA256 Signature Verification with timing-safe comparison
  if (!keySecret || keySecret === 'your_razorpay_secret_here' || keySecret.startsWith('*')) {
    logger.error('CRITICAL: RAZORPAY_KEY_SECRET is not configured or invalid in Cloud Functions.');
    throw new HttpsError(
      'failed-precondition',
      'पेमेंट गेटवे सर्वर त्रुटि। कृपया सहायता टीम से संपर्क करें।'
    );
  }

  const expectedBody = `${razorpayOrderId}|${razorpayPaymentId}`;
  const expectedSignature = crypto
    .createHmac('sha256', keySecret)
    .update(expectedBody)
    .digest('hex');

  const sigBuffer = Buffer.from(razorpaySignature, 'utf8');
  const expBuffer = Buffer.from(expectedSignature, 'utf8');
  const isSignatureValid = (sigBuffer.length === expBuffer.length) && crypto.timingSafeEqual(sigBuffer, expBuffer);

  if (!isSignatureValid) {
    logger.warn(`HMAC signature mismatch for order: ${razorpayOrderId}`);
    throw new HttpsError(
      'permission-denied',
      'Payment signature verification failed. Transaction cannot be validated.'
    );
  }

  // 3. Order Record Verification & Cross-Check in Firestore
  const paymentRef = db.collection('payments').doc(razorpayOrderId);
  const paymentSnap = await paymentRef.get();

  if (!paymentSnap.exists) {
    logger.warn(`Verification rejected: Order ${razorpayOrderId} does not exist in payments collection.`);
    throw new HttpsError(
      'failed-precondition',
      'Order record not found in system. Cannot verify payment without valid order.'
    );
  }

  const orderData = paymentSnap.data() || {};

  // Idempotency Check: Prevent duplicate processing if already verified
  if (orderData.status === 'success') {
    logger.info(`Idempotent verification request received for order: ${razorpayOrderId}`);
    const existingExpiry = orderData.expiryDate;
    const expiryIso = existingExpiry
      ? (existingExpiry.toDate ? existingExpiry.toDate().toISOString() : new Date(existingExpiry).toISOString())
      : new Date().toISOString();

    return {
      success: true,
      alreadyProcessed: true,
      message: 'Subscription payment already verified and active.',
      expiryDate: expiryIso,
    };
  }

  // Cross-check Order Provider UID
  if (orderData.providerId && orderData.providerId !== providerId) {
    logger.warn(`Provider mismatch: Order ${razorpayOrderId} belongs to ${orderData.providerId}, caller is ${providerId}`);
    throw new HttpsError('permission-denied', 'Order provider UID mismatch. Transaction rejected.');
  }

  // Cross-check Order Plan ID
  if (orderData.planId && orderData.planId !== planId) {
    logger.warn(`Plan mismatch: Order ${razorpayOrderId} plan is ${orderData.planId}, caller sent ${planId}`);
    throw new HttpsError('invalid-argument', 'Order plan ID mismatch. Transaction rejected.');
  }

  // Cross-check Order Currency
  if (orderData.currency && orderData.currency !== 'INR') {
    logger.warn(`Invalid currency in order ${razorpayOrderId}: ${orderData.currency}`);
    throw new HttpsError('invalid-argument', 'Invalid currency in transaction. Only INR is supported.');
  }

  // 4. Authoritative Snapshot Resolution (Immutable Order Record)
  let durationDays = null;
  let categoryLimit = 1;
  let planName = 'Subscription Plan';
  let planTier = orderData.pricingSnapshot?.planTier || orderData.planTier || 'normal';
  let orderAmountPaise = null;
  let orderAmountRupees = null;

  if (orderData.pricingSnapshot && typeof orderData.pricingSnapshot === 'object') {
    const snap = orderData.pricingSnapshot;
    durationDays = Number(snap.durationDays);
    categoryLimit = Number(snap.categoryLimit || 1);
    planName = snap.planName || orderData.planName || planName;
    planTier = snap.planTier || orderData.planTier || planTier;
    orderAmountPaise = Number(snap.amountInPaise);
    orderAmountRupees = Number(snap.amount !== undefined ? snap.amount : (orderAmountPaise / 100));

    // Cross-verify order record with snapshot
    if (orderData.amountInPaise !== undefined && Number(orderData.amountInPaise) !== orderAmountPaise) {
      logger.warn(`Order amount mismatch with snapshot: ${orderData.amountInPaise} !== ${orderAmountPaise}`);
      throw new HttpsError('invalid-argument', 'Order amount tampered or inconsistent with order snapshot.');
    }
  } else {
    // Legacy order handling: rely on authoritative fields stored directly on the payment record
    if (orderData.amountInPaise !== undefined && Number(orderData.amountInPaise) > 0) {
      orderAmountPaise = Number(orderData.amountInPaise);
      orderAmountRupees = Number(orderData.amount !== undefined ? orderData.amount : (orderAmountPaise / 100));
    } else if (orderData.amount !== undefined && Number(orderData.amount) > 0) {
      orderAmountRupees = Number(orderData.amount);
      orderAmountPaise = Math.round(orderAmountRupees * 100);
    }

    if (orderData.durationDays !== undefined && Number(orderData.durationDays) > 0) {
      durationDays = Number(orderData.durationDays);
    }
    if (orderData.categoryLimit !== undefined) {
      categoryLimit = Number(orderData.categoryLimit);
    }
    if (orderData.planName) {
      planName = String(orderData.planName);
    }

    // If durationDays or amount still missing, try live plan as fallback for legacy records
    if (!durationDays || !orderAmountPaise) {
      try {
        const planDoc = await db.collection('subscription_plans').doc(planId).get();
        if (planDoc.exists && planDoc.data()?.isActive !== false) {
          const pData = planDoc.data() || {};
          if (!durationDays && pData.durationDays > 0) {
            durationDays = Number(pData.durationDays);
          }
          if (!categoryLimit && pData.categoryLimit > 0) {
            categoryLimit = Number(pData.categoryLimit);
          }
          planName = pData.name || planName;
          if (!orderAmountPaise && pData.price > 0) {
            orderAmountRupees = Number(pData.price);
            orderAmountPaise = Math.round(orderAmountRupees * 100);
          }
        }
      } catch (err) {
        logger.warn('Plan lookup failed during legacy payment verification:', err);
      }
    }

    // Fail closed if amount or duration cannot be verified reliably
    if (!orderAmountPaise || orderAmountPaise <= 0 || !durationDays || durationDays <= 0) {
      logger.error(`Order ${razorpayOrderId} lacks verifiable amount or duration. Fails closed.`);
      throw new HttpsError(
        'failed-precondition',
        'आर्डर का आधिकारिक मूल्य या अवधि सत्यापित नहीं की जा सकी। कृपया सहायता टीम से संपर्क करें।'
      );
    }
  }

  if (orderAmountPaise < 100) {
    throw new HttpsError('invalid-argument', 'Invalid order amount (minimum ₹1.00 / 100 paise).');
  }

  // 5. Authoritative Live Razorpay API Payment Verification
  let livePaymentValidated = false;
  if (keyId && keySecret && !keySecret.startsWith('*')) {
    try {
      const instance = new Razorpay({ key_id: keyId, key_secret: keySecret });
      const rzpPayment = await instance.payments.fetch(razorpayPaymentId);

      if (rzpPayment) {
        // A. Payment Status check: Strictly enforce 'captured' (Reject 'authorized', 'failed', or uncaptured states)
        if (rzpPayment.status !== 'captured') {
          logger.warn(`Razorpay payment ${razorpayPaymentId} status is '${rzpPayment.status}'. Expected 'captured'.`);
          throw new HttpsError(
            'failed-precondition',
            `भुगतान अभी पूर्ण रूप से प्राप्त (Captured) नहीं हुआ है (वर्तमान स्थिति: '${rzpPayment.status}')। केवल पूर्ण रूप से प्राप्त भुगतान ही सत्यापित किए जा सकते हैं।`
          );
        }

        // B. Payment Order ID check
        if (rzpPayment.order_id && rzpPayment.order_id !== razorpayOrderId) {
          logger.warn(`Payment order_id mismatch: ${rzpPayment.order_id} !== ${razorpayOrderId}`);
          throw new HttpsError('permission-denied', 'Razorpay payment does not match the specified order.');
        }

        // C. Payment Currency check
        if (rzpPayment.currency && rzpPayment.currency !== 'INR') {
          logger.warn(`Razorpay payment currency mismatch: ${rzpPayment.currency}`);
          throw new HttpsError('invalid-argument', 'Payment currency mismatch. Only INR is supported.');
        }

        // D. Payment Amount in Minor Units (Paise) exact match
        const rzpAmountInPaise = Number(rzpPayment.amount);
        if (rzpAmountInPaise !== orderAmountPaise) {
          logger.warn(`Payment amount mismatch! Razorpay amount: ${rzpAmountInPaise} paise, Expected: ${orderAmountPaise} paise`);
          throw new HttpsError(
            'invalid-argument',
            `भुगतान राशि (₹${rzpAmountInPaise / 100}) और प्लान शुल्क (₹${orderAmountPaise / 100}) में अंतर है।`
          );
        }

        // E. Payment Notes Provider UID check (if present)
        if (rzpPayment.notes?.providerId && rzpPayment.notes.providerId !== providerId) {
          logger.warn(`Razorpay payment note providerId mismatch: ${rzpPayment.notes.providerId} !== ${providerId}`);
          throw new HttpsError('permission-denied', 'Payment notes provider ID mismatch.');
        }

        livePaymentValidated = true;
      } else {
        throw new HttpsError('internal', 'Razorpay API returned empty payment record.');
      }
    } catch (rzpErr) {
      if (rzpErr instanceof HttpsError) {
        throw rzpErr;
      }
      logger.error(`Razorpay API verification error for payment ${razorpayPaymentId}:`, rzpErr?.message || rzpErr);
      throw new HttpsError(
        'internal',
        'पेमेंट गेटवे सर्वर से संपर्क नहीं हो सका या भुगतान की पुष्टि नहीं हो पाई। कृपया कुछ समय बाद पुनः प्रयास करें।'
      );
    }
  }

  // Fail-Closed Guard: Never proceed without authoritative live verification
  if (!livePaymentValidated) {
    logger.error(`Payment verification fail-closed for payment ${razorpayPaymentId}: livePaymentValidated is false.`);
    throw new HttpsError('failed-precondition', 'Payment verification failed: Razorpay payment could not be validated.');
  }

  // 6. Provider Metadata & Existing Subscription State
  const now = new Date();
  let providerName = 'Service Provider';
  let currentStatus = 'pendingReview';
  let currentKycStatus = 'pendingReview';

  const pData = providerDoc.data() || {};
  providerName = pData.fullName || pData.businessName || pData.ownerName || orderData.providerName || 'Service Provider';
  currentStatus = pData.status || 'pendingReview';
  currentKycStatus = pData.kycStatus || 'pendingReview';

  // Check if provider ALREADY has a genuinely active and approved unexpired subscription (Renewal scenario)
  const isCurrentlyActiveApproved = pData.isSubscriptionActive === true &&
    pData.subscriptionApprovalStatus === 'approved' &&
    pData.subscriptionExpiry;

  let existingActiveExpiry = null;
  if (isCurrentlyActiveApproved) {
    const existingDate = pData.subscriptionExpiry.toDate ? pData.subscriptionExpiry.toDate() : new Date(pData.subscriptionExpiry);
    if (existingDate > now) {
      existingActiveExpiry = existingDate;
    }
  }

  const targetAudience = orderData.targetAudience || 'all';
  const isRenewal = orderData.isRenewal !== undefined ? Boolean(orderData.isRenewal) : false;
  const discountApplied = Number(orderData.discountApplied || 0);

  // 7. Atomic Batch Write: Update Payment, Subscription History, and Provider Profile
  const batch = db.batch();

  // A. Update Payment Document with verified capture evidence
  batch.set(
    paymentRef,
    {
      status: 'success',
      paymentStatus: 'captured',
      captured: true,
      paymentId: razorpayPaymentId,
      razorpayPaymentId: razorpayPaymentId,
      providerId: providerId,
      providerName: providerName,
      userName: providerName,
      targetAudience: targetAudience,
      planId: planId,
      planName: planName,
      planTier: planTier,
      amount: orderAmountRupees,
      amountInPaise: orderAmountPaise,
      currency: 'INR',
      durationDays: durationDays,
      categoryLimit: categoryLimit,
      isRenewal: isRenewal,
      discountApplied: discountApplied,
      signature: razorpaySignature || '',
      verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      adminApprovalStatus: 'pending_approval',
      liveVerified: true,
    },
    { merge: true }
  );

  // B. Write Authoritative Subscription History Record in `subscriptions`
  const subRef = db.collection('subscriptions').doc(`sub_${razorpayOrderId}`);
  batch.set(subRef, {
    id: `sub_${razorpayOrderId}`,
    providerId: providerId,
    providerName: providerName,
    planId: planId,
    planName: planName,
    planTier: planTier,
    amountPaid: orderAmountRupees,
    amountPaidInPaise: orderAmountPaise,
    currency: 'INR',
    orderId: razorpayOrderId,
    paymentId: razorpayPaymentId,
    targetAudience: targetAudience,
    isRenewal: isRenewal,
    discountApplied: discountApplied,
    durationDays: durationDays,
    categoryLimit: categoryLimit,
    status: 'pending_approval',
    approvalStatus: 'pending_approval',
    source: 'client_verification',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // C. Update Provider Profile: Payment verified, subscription strictly pending Admin manual activation
  // Single Authoritative Point Rule: Do NOT advance subscriptionExpiry into the future here.
  // If provider already has an active approved subscription (early renewal), preserve their existing active state and expiry.
  const providerProfileUpdate = {
    subscriptionPlan: planId,
    subscriptionPlanName: planName,
    subscriptionPlanTier: planTier,
    subscriptionDurationDays: durationDays,
    adminCategoryOverrideLimit: categoryLimit,
    paymentVerified: true,
    paymentVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    paymentId: razorpayPaymentId,
    paymentAmount: orderAmountRupees,
    paymentAmountInPaise: orderAmountPaise,
    subscriptionPaymentStatus: 'paid',
    providerType: 'existing_provider',
    isRenewalEligible: true,
    status: currentStatus === 'approved' ? 'approved' : 'pendingReview',
    kycStatus: currentKycStatus === 'approved' ? 'approved' : 'pendingReview',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  // Safe Multi-Order Tracking: If provider already has an active pending_approval order,
  // do NOT overwrite paymentOrderId. Record additionalPendingOrderId to preserve order trail.
  if (pData.subscriptionApprovalStatus === 'pending_approval' && pData.paymentOrderId && pData.paymentOrderId !== razorpayOrderId) {
    providerProfileUpdate.additionalPendingOrderId = razorpayOrderId;
  } else {
    providerProfileUpdate.paymentOrderId = razorpayOrderId;
  }

  if (existingActiveExpiry) {
    // Preserve active status, approved status, and current unexpired expiry for ongoing renewals
    providerProfileUpdate.isSubscriptionActive = true;
    providerProfileUpdate.subscriptionExpiry = pData.subscriptionExpiry;
    providerProfileUpdate.subscriptionApprovalStatus = 'approved';
    providerProfileUpdate.renewalPendingOrderId = razorpayOrderId;
  } else {
    // New or inactive provider: Not active until Admin approves; do NOT advance expiry into the future
    providerProfileUpdate.isSubscriptionActive = false;
    providerProfileUpdate.subscriptionApprovalStatus = 'pending_approval';
  }

  batch.update(providerRef, providerProfileUpdate);

  await batch.commit();

  logger.info(`✅ Payment verified for Provider: ${providerId} (Order: ${razorpayOrderId}, Paid: ₹${orderAmountRupees}). Subscription set to 'pending_approval'.`);

  return {
    success: true,
    message: 'Subscription payment verified. Pending administrator manual activation.',
    approvalStatus: 'pending_approval',
    expiryDate: existingActiveExpiry ? existingActiveExpiry.toISOString() : null,
    amountPaid: orderAmountRupees,
    isRenewal: isRenewal,
  };
});

/**
 * 4. UPDATE PROVIDER PROFILE (AUTHORITATIVE BACKEND)
 * Validates ownership, checks admin approval status, locks approved category,
 * updates only permitted fields, and preserves existing approved status.
 */
exports.updateProviderProfile = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated to update profile.');
  }

  const { providerId, fields } = request.data || {};
  if (!providerId || !fields || typeof fields !== 'object') {
    throw new HttpsError('invalid-argument', 'providerId and fields object are required.');
  }

  // 1. Verify Ownership (or Admin)
  let isCallerAdmin = false;
  if (request.auth.uid !== providerId) {
    try {
      await verifyActiveAdmin(request);
      isCallerAdmin = true;
    } catch (_) {
      isCallerAdmin = false;
    }
    if (!isCallerAdmin) {
      throw new HttpsError('permission-denied', 'You are not authorized to edit this provider profile.');
    }
  }

  const providerRef = db.collection('providers').doc(providerId);
  const providerSnap = await providerRef.get();
  if (!providerSnap.exists) {
    throw new HttpsError('not-found', 'Provider profile does not exist.');
  }

  const currentData = providerSnap.data() || {};

  // 2. Blocked or Suspended Providers cannot edit
  if (currentData.status === 'blocked' || currentData.status === 'suspended') {
    throw new HttpsError('permission-denied', 'This provider account is blocked or suspended.');
  }

  const isApproved = currentData.status === 'approved' ||
                     currentData.kycStatus === 'approved' ||
                     currentData.isVerified === true;

  // 3. Category Lock for Approved Providers
  if (isApproved && !isCallerAdmin) {
    const categoryKeys = [
      'primaryCategoryId',
      'categoryId',
      'category',
      'primaryCategoryTitle',
      'categoryTitle',
      'selectedCategoryIds',
    ];
    for (const key of categoryKeys) {
      if (key in fields && fields[key] !== currentData[key]) {
        throw new HttpsError(
          'permission-denied',
          'Admin-approved category is locked and cannot be changed by the provider. Please contact Admin.'
        );
      }
    }
  }

  // 4. Whitelist Permitted Fields (Protection of Admin-controlled status, limits, and ratings)
  const ALLOWED_FIELDS = new Set([
    'businessName',
    'fullName',
    'ownerName',
    'businessDescription',
    'businessType',
    'visitingCharge',
    'experienceYears',
    'workingHours',
    'jamuiArea',
    'area',
    'fullAddress',
    'latitude',
    'longitude',
    'serviceRadiusKm',
    'profileImageUrl',
    'businessImageUrl',
    'email',
    'isAvailable',
    'isOnline',
  ]);

  const updatePayload = {};
  for (const [key, value] of Object.entries(fields)) {
    if (ALLOWED_FIELDS.has(key)) {
      updatePayload[key] = value;
    }
  }

  // Preserve existing approved status if provider is already approved
  updatePayload.updatedAt = admin.firestore.FieldValue.serverTimestamp();

  await providerRef.update(updatePayload);

  return {
    success: true,
    message: 'Profile updated successfully with status preserved.',
  };
});

/**
 * 5. RAZORPAY WEBHOOK HANDLER
 * HTTPS Endpoint for server-to-server asynchronous notifications from Razorpay
 */
exports.razorpayWebhook = onRequest({ cors: true, secrets: RAZORPAY_SECRETS }, async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).send('Method Not Allowed');
    return;
  }

  const { keyId, keySecret, webhookSecret } = await getRazorpayCredentials();
  const signature = req.headers['x-razorpay-signature'];

  // 1. Mandatory Dedicated Webhook Secret & Signature Check (Strict: No keySecret fallback)
  if (!webhookSecret || !signature) {
    logger.warn('Unauthorized webhook attempt: Missing x-razorpay-signature or dedicated RAZORPAY_WEBHOOK_SECRET not configured');
    res.status(401).send('Missing Signature or Secret');
    return;
  }

  // 2. Cryptographic HMAC-SHA256 Signature Verification with Raw Payload & Timing-Safe Equality
  try {
    const rawPayload = Buffer.isBuffer(req.rawBody)
      ? req.rawBody
      : (typeof req.rawBody === 'string'
          ? req.rawBody
          : (typeof req.body === 'string' ? req.body : JSON.stringify(req.body)));
    const expectedSignature = crypto
      .createHmac('sha256', webhookSecret)
      .update(rawPayload)
      .digest('hex');

    const sigBuffer = Buffer.from(signature, 'utf8');
    const expBuffer = Buffer.from(expectedSignature, 'utf8');
    const isValid = (sigBuffer.length === expBuffer.length) && crypto.timingSafeEqual(sigBuffer, expBuffer);

    if (!isValid) {
      logger.warn('Unauthorized webhook signature attempt: HMAC signature mismatch');
      res.status(400).send('Invalid Signature');
      return;
    }
  } catch (sigErr) {
    logger.error('Webhook signature computation error:', sigErr);
    res.status(400).send('Signature Verification Error');
    return;
  }

  const event = req.body?.event;
  const payload = req.body?.payload;

  if (event === 'payment.captured' || event === 'order.paid') {
    const paymentEntity = payload?.payment?.entity;
    const orderEntity = payload?.order?.entity;
    const orderId = paymentEntity?.order_id || orderEntity?.id;
    const paymentId = paymentEntity?.id || payload?.payment?.entity?.id;

    if (!orderId) {
      logger.warn(`Webhook ignored: event ${event} lacks order_id.`);
      res.status(200).json({ status: 'ignored', message: 'Missing order_id' });
      return;
    }

    try {
      // Look up authoritative order in Firestore payments collection
      const existingPayment = await db.collection('payments').doc(orderId).get();
      if (!existingPayment.exists) {
        logger.warn(`Webhook: Order ${orderId} does not exist in payments collection yet.`);
        res.status(200).json({ status: 'order_not_found', orderId });
        return;
      }

      const existingPaymentData = existingPayment.data() || {};
      const orderData = existingPaymentData;

      // Robust Identity Resolution: Resolve providerId and planId from payment notes, order notes, or Firestore order record
      const notes = (paymentEntity?.notes && Object.keys(paymentEntity.notes).length > 0)
        ? paymentEntity.notes
        : (orderEntity?.notes || {});

      const providerId = notes.providerId || orderEntity?.notes?.providerId || existingPaymentData.providerId;
      const planId = notes.planId || orderEntity?.notes?.planId || existingPaymentData.planId;

      if (!providerId || !planId) {
        logger.error(`Webhook error: Could not resolve providerId or planId for order ${orderId}.`);
        res.status(400).json({ status: 'error', message: 'Unresolved provider or plan' });
        return;
      }

      // Idempotency: Avoid double activation if already processed
      if (existingPayment.data()?.status === 'success') {
        logger.info(`Webhook event already fulfilled for Order: ${orderId}`);
        await db.collection('payments').doc(orderId).set({ webhookProcessed: true }, { merge: true });
        res.status(200).json({ status: 'ok', message: 'already_fulfilled' });
        return;
      }

      // Amount & Currency Validation in Minor Units (Paise)
      const paymentCurrency = paymentEntity?.currency || 'INR';
      if (paymentCurrency !== 'INR') {
        logger.warn(`Webhook rejected: currency is ${paymentCurrency}, expected INR.`);
        res.status(400).json({ status: 'error', message: 'Invalid currency' });
        return;
      }

      const expectedPaise = existingPaymentData.amountInPaise !== undefined
        ? Number(existingPaymentData.amountInPaise)
        : (existingPaymentData.amount ? Math.round(Number(existingPaymentData.amount) * 100) : 0);

        const webhookPaidPaise = Number(paymentEntity?.amount || 0);

        // If order record has an expected amount, assert paid amount exactly matches expected amount
        if (expectedPaise > 0 && webhookPaidPaise > 0 && webhookPaidPaise !== expectedPaise) {
          logger.warn(`Webhook rejected: Amount mismatch in webhook. Paid: ${webhookPaidPaise} paise, Expected: ${expectedPaise} paise`);
          res.status(400).json({ status: 'error', message: 'Amount mismatch' });
          return;
        }

        logger.info(`Processing background webhook fulfillment for Provider: ${providerId}, Order: ${orderId}`);
        
        let durationDays = null;
        let categoryLimit = 1;
        let planName = 'Subscription Plan';
        let priceInRupees = null;

        if (orderData.pricingSnapshot && typeof orderData.pricingSnapshot === 'object') {
          const snap = orderData.pricingSnapshot;
          durationDays = Number(snap.durationDays);
          categoryLimit = Number(snap.categoryLimit || 1);
          planName = snap.planName || orderData.planName || planName;
          priceInRupees = Number(snap.amount !== undefined ? snap.amount : (Number(snap.amountInPaise) / 100));
        } else {
          if (orderData.durationDays !== undefined && Number(orderData.durationDays) > 0) {
            durationDays = Number(orderData.durationDays);
          }
          if (orderData.categoryLimit !== undefined) {
            categoryLimit = Number(orderData.categoryLimit);
          }
          if (orderData.planName) {
            planName = String(orderData.planName);
          }
          if (orderData.amount !== undefined && Number(orderData.amount) > 0) {
            priceInRupees = Number(orderData.amount);
          } else if (orderData.amountInPaise !== undefined && Number(orderData.amountInPaise) > 0) {
            priceInRupees = Number(orderData.amountInPaise) / 100;
          }

          // Fallback to live plan for legacy doc
          if (!durationDays || !priceInRupees) {
            try {
              const planDoc = await db.collection('subscription_plans').doc(planId).get();
              if (planDoc.exists && planDoc.data()?.isActive !== false) {
                const pData = planDoc.data() || {};
                durationDays = durationDays || Number(pData.durationDays);
                categoryLimit = categoryLimit || Number(pData.categoryLimit || 1);
                planName = pData.name || planName;
                priceInRupees = priceInRupees || Number(pData.price);
              }
            } catch (pErr) {
              logger.warn('Plan lookup failed in webhook:', pErr);
            }
          }
        }

        if (!durationDays || durationDays <= 0) {
          logger.error(`Webhook order ${orderId} has no verifiable durationDays. Refusing to guess duration.`);
          res.status(422).json({ status: 'error', message: 'Missing verifiable plan duration' });
          return;
        }

        const now = new Date();
        const providerRef = db.collection('providers').doc(providerId);
        const providerDoc = await providerRef.get();
        let providerName = 'Service Provider';
        let currentStatus = 'pendingReview';
        let currentKycStatus = 'pendingReview';
        let isCurrentlyActiveApproved = false;
        let existingActiveExpiry = null;

        if (providerDoc.exists) {
          const pData = providerDoc.data() || {};
          providerName = pData.fullName || pData.businessName || pData.ownerName || 'Service Provider';
          currentStatus = pData.status || 'pendingReview';
          currentKycStatus = pData.kycStatus || 'pendingReview';

          isCurrentlyActiveApproved = pData.isSubscriptionActive === true &&
            pData.subscriptionApprovalStatus === 'approved' &&
            pData.subscriptionExpiry;

          if (isCurrentlyActiveApproved) {
            const existingDate = pData.subscriptionExpiry.toDate ? pData.subscriptionExpiry.toDate() : new Date(pData.subscriptionExpiry);
            if (existingDate > now) {
              existingActiveExpiry = existingDate;
            }
          }
        }

        const paymentData = existingPayment.exists ? (existingPayment.data() || {}) : {};
        const paidAmount = webhookPaidPaise > 0
          ? (webhookPaidPaise / 100)
          : (paymentData.amount !== undefined ? Number(paymentData.amount) : priceInRupees);
        const finalPaise = webhookPaidPaise > 0 ? webhookPaidPaise : Math.round(paidAmount * 100);
        const targetAudience = paymentData.targetAudience || notes.targetAudience || 'all';
        const isRenewal = paymentData.isRenewal !== undefined ? Boolean(paymentData.isRenewal) : (notes.isRenewal === 'true');
        const discountApplied = Number(paymentData.discountApplied || 0);

        // Server-Side Live Gateway Verification:
        // Rule: liveVerified: true is set ONLY when payment is authoritatively confirmed as captured
        // via server-side Razorpay API fetch, NOT merely on webhook payload or client input.
        let isLiveGatewayCaptured = false;
        let gatewayFetchError = null;
        let rzpPaymentEntity = null;
        if (keyId && keySecret && !keySecret.startsWith('*')) {
          try {
            const instance = new Razorpay({ key_id: keyId, key_secret: keySecret });
            const rzpPayment = await instance.payments.fetch(paymentId);
            rzpPaymentEntity = rzpPayment;
            if (
              rzpPayment &&
              (rzpPayment.status === 'captured' || rzpPayment.captured === true)
            ) {
              isLiveGatewayCaptured = true;
            } else {
              logger.warn(`Razorpay API verification for webhook payment ${paymentId} returned non-captured status: ${rzpPayment?.status}`);
            }
          } catch (fetchErr) {
            gatewayFetchError = fetchErr;
            logger.warn(`Server-side Razorpay API fetch failed for payment ${paymentId} in webhook:`, fetchErr?.message || fetchErr);
          }
        }

        // Check existing subscription state before staging batch writes
        const subRef = db.collection('subscriptions').doc(`sub_${orderId}`);
        const existingSub = await subRef.get();
        const isSubAlreadyActiveOrApproved = existingSub.exists && (
          existingSub.data()?.status === 'active' ||
          existingSub.data()?.status === 'approved' ||
          existingSub.data()?.approvalStatus === 'approved'
        );

        if (isSubAlreadyActiveOrApproved) {
          // Invariant: Do not mark payment captured or success without gateway confirmation
          if (!isLiveGatewayCaptured) {
            if (gatewayFetchError) {
              logger.warn(`Gateway fetch failed for order ${orderId} in already-approved subscription branch:`, gatewayFetchError?.message || gatewayFetchError);
              await db.collection('payments').doc(orderId).set({
                captured: false,
                liveVerified: false,
                gatewayFetchError: gatewayFetchError?.message || 'Gateway fetch failed',
                paymentId: paymentId || '',
                razorpayPaymentId: paymentId || '',
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              }, { merge: true });
              res.status(502).json({ status: 'error', message: 'Gateway fetch failure' });
              return;
            } else {
              logger.warn(`Gateway payment ${paymentId} for order ${orderId} is not captured (status: ${rzpPaymentEntity?.status}). Refusing to mark success.`);
              await db.collection('payments').doc(orderId).set({
                status: 'pending',
                paymentStatus: rzpPaymentEntity?.status || 'uncaptured',
                captured: false,
                liveVerified: false,
                webhookProcessed: true,
                paymentId: paymentId || '',
                razorpayPaymentId: paymentId || '',
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              }, { merge: true });
              res.status(200).json({ status: 'ok', message: 'payment_not_captured' });
              return;
            }
          }

          logger.info(`Webhook event for sub_${orderId}: subscription already active/approved. Committing payment capture without modifying approved subscription.`);
          await db.collection('payments').doc(orderId).set({
            status: 'success',
            paymentStatus: 'captured',
            captured: true,
            liveVerified: true,
            webhookProcessed: true,
            paymentId: paymentId || '',
            razorpayPaymentId: paymentId || '',
            verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true });
          res.status(200).json({ status: 'ok', message: 'already_active_payment_captured' });
          return;
        }

        // Main Webhook Fulfillment Branch: Gate against uncaptured or gateway fetch failures
        if (!isLiveGatewayCaptured) {
          if (gatewayFetchError) {
            logger.warn(`Gateway fetch failed for order ${orderId} in webhook:`, gatewayFetchError?.message || gatewayFetchError);
            await db.collection('payments').doc(orderId).set({
              captured: false,
              liveVerified: false,
              gatewayFetchError: gatewayFetchError?.message || 'Gateway fetch failed',
              paymentId: paymentId || '',
              razorpayPaymentId: paymentId || '',
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
            res.status(502).json({ status: 'error', message: 'Gateway fetch failure' });
            return;
          } else {
            logger.warn(`Gateway payment ${paymentId} for order ${orderId} is not captured (status: ${rzpPaymentEntity?.status}). Refusing to mark success.`);
            await db.collection('payments').doc(orderId).set({
              status: 'pending',
              paymentStatus: rzpPaymentEntity?.status || 'uncaptured',
              captured: false,
              liveVerified: false,
              webhookProcessed: true,
              paymentId: paymentId || '',
              razorpayPaymentId: paymentId || '',
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
            res.status(200).json({ status: 'ok', message: 'payment_not_captured' });
            return;
          }
        }

        const originalSubCreatedAt = (existingSub.exists && existingSub.data()?.createdAt)
          ? existingSub.data().createdAt
          : admin.firestore.FieldValue.serverTimestamp();

        const finalAdminApprovalStatus = existingPaymentData.adminApprovalStatus === 'approved'
          ? 'approved'
          : 'pending_approval';

        const batch = db.batch();
        batch.set(
          db.collection('payments').doc(orderId),
          {
            status: 'success',
            paymentStatus: 'captured',
            captured: true,
            liveVerified: true,
            paymentId: paymentId || '',
            razorpayPaymentId: paymentId || '',
            providerId: providerId,
            providerName: providerName,
            userName: providerName,
            targetAudience: targetAudience,
            planId: planId,
            planName: planName,
            amount: paidAmount,
            amountInPaise: finalPaise,
            currency: 'INR',
            durationDays: durationDays,
            categoryLimit: categoryLimit,
            isRenewal: isRenewal,
            discountApplied: discountApplied,
            webhookProcessed: true,
            verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
            adminApprovalStatus: finalAdminApprovalStatus,
          },
          { merge: true }
        );

        batch.set(subRef, {
          id: `sub_${orderId}`,
          providerId: providerId,
          providerName: providerName,
          planId: planId,
          planName: planName,
          amountPaid: paidAmount,
          amountPaidInPaise: finalPaise,
          currency: 'INR',
          orderId: orderId,
          paymentId: paymentId || '',
          targetAudience: targetAudience,
          isRenewal: isRenewal,
          discountApplied: discountApplied,
          durationDays: durationDays,
          categoryLimit: categoryLimit,
          status: 'pending_approval',
          approvalStatus: 'pending_approval',
          source: 'webhook_fulfillment',
          createdAt: originalSubCreatedAt,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });

        // Single Authoritative Point Rule: Do NOT advance subscriptionExpiry into the future here.
        // If provider already has an active approved subscription (early renewal), preserve their existing active state and expiry.
        const webhookProviderUpdate = {
          subscriptionPlan: planId,
          subscriptionPlanName: planName,
          subscriptionDurationDays: durationDays,
          adminCategoryOverrideLimit: categoryLimit,
          paymentVerified: true,
          paymentVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
          paymentOrderId: orderId,
          paymentId: paymentId || '',
          paymentAmount: paidAmount,
          paymentAmountInPaise: finalPaise,
          subscriptionPaymentStatus: 'paid',
          providerType: 'existing_provider',
          isRenewalEligible: true,
          status: currentStatus === 'approved' ? 'approved' : 'pendingReview',
          kycStatus: currentKycStatus === 'approved' ? 'approved' : 'pendingReview',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        if (existingActiveExpiry && providerDoc.exists) {
          webhookProviderUpdate.isSubscriptionActive = true;
          webhookProviderUpdate.subscriptionExpiry = providerDoc.data()?.subscriptionExpiry;
          webhookProviderUpdate.subscriptionApprovalStatus = 'approved';
          webhookProviderUpdate.renewalPendingOrderId = orderId;
        } else {
          webhookProviderUpdate.isSubscriptionActive = false;
          webhookProviderUpdate.subscriptionApprovalStatus = 'pending_approval';
        }

        batch.update(providerRef, webhookProviderUpdate);

        await batch.commit();
        logger.info(`✅ Webhook fulfillment committed for Provider: ${providerId} (Order: ${orderId}, Paid: ₹${paidAmount}). Pending Admin Approval.`);
      } catch (webhookErr) {
        logger.error('Error fulfilling webhook event:', webhookErr);
      }
  } else if (event === 'payment.failed') {
    const paymentEntity = payload?.payment?.entity;
    const orderId = paymentEntity?.order_id;
    if (orderId) {
      try {
        // Event-ordering Guard: If order was already successfully verified or captured, do NOT mark failed!
        const existingDoc = await db.collection('payments').doc(orderId).get();
        if (existingDoc.exists && existingDoc.data()?.status === 'success') {
          logger.info(`Ignoring payment.failed for Order ${orderId} because order is already in 'success' state.`);
          res.status(200).json({ status: 'ok', message: 'ignored_already_successful' });
          return;
        }

        await db.collection('payments').doc(orderId).set({
          status: 'failed',
          errorCode: paymentEntity?.error_code || 'PAYMENT_FAILED',
          errorDescription: paymentEntity?.error_description || 'Payment was declined or failed.',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        logger.info(`Recorded payment.failed for Order ${orderId}: ${paymentEntity?.error_code}`);
      } catch (err) {
        logger.error('Error logging failed payment webhook:', err);
      }
    }
  }

  res.status(200).json({ status: 'ok' });
});

/**
 * 6. SCHEDULED SUBSCRIPTION EXPIRY MONITOR
 * Runs every day at 00:00 (Midnight IST) to deactivate expired provider subscriptions
 */
exports.checkSubscriptionExpiry = onSchedule({
  schedule: 'every day 00:00',
  timeZone: 'Asia/Kolkata',
  region: 'asia-south1',
}, async (event) => {
  const now = admin.firestore.Timestamp.now();
  logger.info('Starting daily automated subscription expiry check...');

  try {
    // 1. Query all active providers whose expiry date has passed
    let expiredDocs = [];
    try {
      const snap = await db.collection('providers')
        .where('isSubscriptionActive', '==', true)
        .where('subscriptionExpiry', '<=', now)
        .get();
      expiredDocs = snap.docs;
    } catch (indexErr) {
      logger.warn('Composite index query for providers failed, falling back to memory filtering:', indexErr.message);
      const snap = await db.collection('providers')
        .where('isSubscriptionActive', '==', true)
        .get();
      const nowDate = now.toDate ? now.toDate() : new Date();
      expiredDocs = snap.docs.filter((doc) => {
        const d = doc.data();
        const exp = d.subscriptionExpiry;
        if (!exp) {
          // Unverified records with null expiry should be deactivated
          return d.paymentVerified !== true;
        }
        const expDate = exp.toDate ? exp.toDate() : new Date(exp);
        return expDate <= nowDate;
      });
    }

    if (expiredDocs.length > 0) {
      const batch = db.batch();
      expiredDocs.forEach((doc) => {
        batch.update(doc.ref, {
          isSubscriptionActive: false,
          isPremiumEligible: false,
          updatedAt: now,
        });
      });
      await batch.commit();
      logger.info(`Deactivated ${expiredDocs.length} expired provider subscriptions.`);
    } else {
      logger.info('No expired provider subscriptions found.');
    }

    // 2. Mark active subscription history records as expired
    let expiredSubDocs = [];
    try {
      const subSnap = await db.collection('subscriptions')
        .where('status', '==', 'active')
        .where('expiryDate', '<=', now)
        .get();
      expiredSubDocs = subSnap.docs;
    } catch (subIndexErr) {
      logger.warn('Composite index query for subscriptions failed, falling back to memory filtering:', subIndexErr.message);
      const subSnap = await db.collection('subscriptions')
        .where('status', '==', 'active')
        .get();
      const nowDate = now.toDate ? now.toDate() : new Date();
      expiredSubDocs = subSnap.docs.filter((doc) => {
        const exp = doc.data().expiryDate;
        if (!exp) return false;
        const expDate = exp.toDate ? exp.toDate() : new Date(exp);
        return expDate <= nowDate;
      });
    }

    if (expiredSubDocs.length > 0) {
      const subBatch = db.batch();
      expiredSubDocs.forEach((doc) => {
        subBatch.update(doc.ref, {
          status: 'expired',
          updatedAt: now,
        });
      });
      await subBatch.commit();
      logger.info(`Marked ${expiredSubDocs.length} subscription records as expired.`);
    }

    // 3. Scan & Deactivate Expired Professional / Diamond Shops
    try {
      const diamondSnap = await db.collection('diamond_shops')
        .where('isSubscriptionActive', '==', true)
        .get();

      const nowDate = now.toDate ? now.toDate() : new Date();
      const expiredDiamondDocs = [];

      diamondSnap.docs.forEach((doc) => {
        const d = doc.data();
        const exp = d.subscriptionExpiry;
        if (!exp) {
          logger.warn(`[checkSubscriptionExpiry] diamond_shops/${doc.id} (${d.shopName || 'N/A'}) has isSubscriptionActive: true but missing subscriptionExpiry. Skipping auto-deactivation.`);
          return;
        }

        let expDate = null;
        if (typeof exp.toDate === 'function') {
          expDate = exp.toDate();
        } else if (exp instanceof Date) {
          expDate = exp;
        } else if (typeof exp === 'string' || typeof exp === 'number') {
          expDate = new Date(exp);
        }

        if (!expDate || isNaN(expDate.getTime())) {
          logger.warn(`[checkSubscriptionExpiry] diamond_shops/${doc.id} has invalid subscriptionExpiry format (${exp}). Skipping auto-deactivation.`);
          return;
        }

        // Only deactivate if expiry timestamp has strictly passed
        if (expDate <= nowDate) {
          expiredDiamondDocs.push(doc);
        }
      });

      if (expiredDiamondDocs.length > 0) {
        // Chunk batch operations to strictly respect Firestore 500 limit
        const chunkSize = 400;
        for (let i = 0; i < expiredDiamondDocs.length; i += chunkSize) {
          const chunk = expiredDiamondDocs.slice(i, i + chunkSize);
          const batch = db.batch();
          chunk.forEach((doc) => {
            batch.update(doc.ref, {
              isSubscriptionActive: false,
              updatedAt: now,
            });
          });
          await batch.commit();
        }
        logger.info(`Deactivated ${expiredDiamondDocs.length} expired professional shop subscriptions.`);
      } else {
        logger.info('No expired professional shop subscriptions found.');
      }
    } catch (diamondErr) {
      logger.error('Error checking professional shops subscription expiry:', diamondErr);
    }
  } catch (err) {
    logger.error('Error during scheduled subscription expiry check:', err);
  }

});

/**
 * Core Authoritative Payment Reconciliation Engine
 * Queries Razorpay API for orderId, validates captured status and strict invariants,
 * and atomically updates Firestore so the record appears in Admin Panel Pending Approvals.
 * 
 * Safety Guarantees:
 * 1. Idempotency & Concurrency: Firestore runTransaction guarantees zero duplicate activations or race-condition overwrites.
 * 2. Invariants: Strict verification that payment is captured, currency is INR, exact amount matches, order_id matches, and notes match.
 * 3. Provider Ownership: Authoritative verification against Razorpay server-side order metadata (rzpOrder.notes.providerId), payment notes, and Firestore record.
 * 4. Fail-Closed: Uncaptured, pending, or mismatched payments are safely ignored without mutation.
 * 5. Admin Gate: isSubscriptionActive is ALWAYS false (or preserves unexpired active state for renewal).
 */
async function reconcileSingleOrderInternal(orderId, callerAdminUid = null) {
  if (!orderId || typeof orderId !== 'string') {
    throw new Error('Valid orderId is required for reconciliation.');
  }

  const paymentRef = db.collection('payments').doc(orderId);
  const paymentSnap = await paymentRef.get();
  if (!paymentSnap.exists) {
    logger.warn(`Reconciliation aborted: Order ${orderId} does not exist in payments collection.`);
    return { status: 'not_found', message: 'Order record does not exist.' };
  }

  const orderData = paymentSnap.data() || {};
  if (orderData.status === 'success') {
    logger.info(`Reconciliation skipped: Order ${orderId} is already marked success.`);
    return { status: 'already_fulfilled', message: 'Order already fulfilled.' };
  }

  if (orderData.status !== 'created') {
    logger.warn(`Reconciliation aborted: Order ${orderId} is in status '${orderData.status}', not 'created'.`);
    return { status: 'invalid_status', message: `Order status is '${orderData.status}', expected 'created'.` };
  }

  const providerId = orderData.providerId;
  const isRenewal = Boolean(orderData.isRenewal);
  const orderAmountPaise = Number(orderData.amountInPaise || (orderData.amount ? Math.round(Number(orderData.amount) * 100) : 0));
  if (!providerId || !orderAmountPaise) {
    logger.warn(`Reconciliation aborted: Order ${orderId} lacks providerId or amount.`);
    return { status: 'invalid_order', message: 'Order lacks providerId or amount.' };
  }

  const { keyId, keySecret } = await getRazorpayCredentials();
  if (!keyId || !keySecret || keySecret.startsWith('*')) {
    logger.error('Reconciliation failed: Razorpay API credentials not configured.');
    throw new Error('Razorpay credentials not configured.');
  }

  const instance = new Razorpay({ key_id: keyId, key_secret: keySecret });

  // 1. Fetch Razorpay Order and verify authoritative server-side order metadata
  let rzpOrder = null;
  try {
    rzpOrder = await instance.orders.fetch(orderId);
  } catch (err) {
    logger.error(`Failed to fetch order ${orderId} from Razorpay:`, err?.message || err);
    return { status: 'order_fetch_failed', message: 'Could not fetch order metadata from gateway.' };
  }

  if (!rzpOrder) {
    logger.warn(`Razorpay order ${orderId} not found on gateway.`);
    return { status: 'gateway_order_not_found', message: 'Order not found on gateway.' };
  }

  // Enforce server-side order metadata has providerId
  if (!rzpOrder.notes || !rzpOrder.notes.providerId) {
    logger.warn(`Razorpay order ${orderId} missing providerId in notes metadata.`);
    return { status: 'missing_order_provider_metadata', message: 'Order metadata lacks required providerId.' };
  }

  // Cross-verify Razorpay order notes providerId matches order record providerId
  if (rzpOrder.notes.providerId !== providerId) {
    logger.warn(`Provider ownership mismatch on Razorpay order ${orderId}: Order notes provider (${rzpOrder.notes.providerId}) !== record provider (${providerId}).`);
    return { status: 'order_provider_mismatch', message: 'Razorpay order metadata providerId mismatch.' };
  }

  // 2. Fetch payments for this order
  const paymentsResponse = await instance.orders.fetchPayments(orderId);
  const items = paymentsResponse?.items || [];
  if (items.length === 0) {
    logger.info(`No payment attempts recorded on Razorpay for order ${orderId}.`);
    return { status: 'no_payments', message: 'No payments found on gateway.' };
  }

  // Find captured payment for this order
  const capturedPayment = items.find((p) => p.status === 'captured' && p.captured === true);
  if (!capturedPayment) {
    logger.info(`Order ${orderId} has no captured payments on Razorpay (pending or failed).`);
    return { status: 'uncaptured', message: 'Payment is not captured on gateway.' };
  }

  // 3. Strict Invariant Verification on captured payment
  // A. Strict Order ID Match
  if (!capturedPayment.order_id || capturedPayment.order_id !== orderId) {
    logger.warn(`Reconciliation rejected: Payment order_id mismatch (${capturedPayment.order_id} !== ${orderId}).`);
    return { status: 'order_id_mismatch', message: 'Payment order_id does not match order record.' };
  }

  // B. Payment notes providerId cross-verification (if present on payment entity)
  // Note: Standard Razorpay checkout SDK passes notes on order, but payment.notes may be empty unless passed in checkout options.
  // Order notes (rzpOrder.notes.providerId) was ALREADY verified above.
  if (capturedPayment.notes && capturedPayment.notes.providerId) {
    if (capturedPayment.notes.providerId !== providerId) {
      logger.warn(`Reconciliation rejected: Notes providerId mismatch for order ${orderId} (${capturedPayment.notes.providerId} !== ${providerId}).`);
      return { status: 'provider_mismatch', message: 'Gateway notes provider ID mismatch.' };
    }
  }

  // C. Strict Amount Match in minor units (Paise)
  const rzpAmountInPaise = Number(capturedPayment.amount);
  if (rzpAmountInPaise !== orderAmountPaise) {
    logger.warn(`Reconciliation rejected: Amount mismatch for order ${orderId}. Gateway: ${rzpAmountInPaise}, Order: ${orderAmountPaise}`);
    return { status: 'amount_mismatch', message: 'Paid amount does not match order amount.' };
  }

  // D. Strict Currency Match
  if (capturedPayment.currency !== 'INR') {
    logger.warn(`Reconciliation rejected: Currency mismatch (${capturedPayment.currency}) for order ${orderId}.`);
    return { status: 'currency_mismatch', message: 'Only INR currency is supported.' };
  }

  // 4. Concurrency & Idempotency OCC Transaction with Strict Invariant Guards
  const providerRef = db.collection('providers').doc(providerId);
  const subRef = db.collection('subscriptions').doc(`sub_${orderId}`);

  let transactionOutcome = null;

  await db.runTransaction(async (transaction) => {
    // Guard 1: Verify payment document exists and is strictly 'created'
    const curPaymentDoc = await transaction.get(paymentRef);
    if (!curPaymentDoc.exists) {
      transactionOutcome = { status: 'not_found', message: 'Payment document disappeared.' };
      return;
    }
    const curPay = curPaymentDoc.data() || {};
    if (curPay.status === 'success') {
      transactionOutcome = { status: 'already_fulfilled', message: 'Order already fulfilled.' };
      return; // Already fulfilled idempotently
    }
    if (curPay.status !== 'created') {
      transactionOutcome = { status: 'invalid_status', message: `Payment status changed to '${curPay.status}'.` };
      return;
    }

    // Guard 2: Verify provider document exists and is not deleted
    const provDoc = await transaction.get(providerRef);
    if (!provDoc.exists) {
      transactionOutcome = { status: 'provider_not_found', message: 'Provider document does not exist.' };
      return;
    }
    const currentProv = provDoc.data() || {};
    if (currentProv.isDeleted === true) {
      transactionOutcome = { status: 'provider_deleted', message: 'Provider account is deleted.' };
      return;
    }

    // Guard 3: Overwrite Protection for subscriptions/sub_<orderId>
    const subDoc = await transaction.get(subRef);
    let originalSubCreatedAt = admin.firestore.FieldValue.serverTimestamp();
    if (subDoc.exists) {
      const existingSubData = subDoc.data() || {};
      if (existingSubData.status === 'active' || existingSubData.approvalStatus === 'approved') {
        logger.warn(`Existing subscription sub_${orderId} is already active/approved. Aborting reconciliation to protect valid record.`);
        transactionOutcome = { status: 'subscription_already_active', message: 'Subscription record already active/approved.' };
        return;
      }
      if (existingSubData.createdAt) {
        originalSubCreatedAt = existingSubData.createdAt; // Preserve original creation timestamp
      }
    }

    const planId = orderData.planId || 'Basic';
    const planName = orderData.planName || 'Basic';
    const durationDays = Number(orderData.durationDays || 30);
    const categoryLimit = Number(orderData.categoryLimit || 1);
    const orderAmountRupees = Number(orderData.amount !== undefined ? orderData.amount : (orderAmountPaise / 100));
    const targetAudience = orderData.targetAudience || 'new_provider';
    const discountApplied = Number(orderData.discountApplied || 0);

    // 1. Update Payment Record
    transaction.set(paymentRef, {
      status: 'success',
      paymentStatus: 'captured',
      captured: true,
      liveVerified: true,
      paymentId: capturedPayment.id,
      razorpayPaymentId: capturedPayment.id,
      paymentMethod: capturedPayment.method || 'upi',
      verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      adminApprovalStatus: 'pending_approval',
      reconciledFromGateway: true,
      reconciledAt: admin.firestore.FieldValue.serverTimestamp(),
      reconciledBy: callerAdminUid || 'scheduled_cron',
    }, { merge: true });

    // 2. Set Subscription History safely with preserved createdAt
    transaction.set(subRef, {
      id: `sub_${orderId}`,
      providerId: providerId,
      providerName: currentProv.fullName || currentProv.businessName || orderData.providerName || 'Service Provider',
      planId: planId,
      planName: planName,
      amountPaid: orderAmountRupees,
      amountPaidInPaise: orderAmountPaise,
      currency: 'INR',
      orderId: orderId,
      paymentId: capturedPayment.id,
      targetAudience: targetAudience,
      isRenewal: isRenewal,
      discountApplied: discountApplied,
      durationDays: durationDays,
      categoryLimit: categoryLimit,
      status: 'pending_approval',
      approvalStatus: 'pending_approval',
      source: callerAdminUid ? 'admin_reconciliation' : 'scheduled_reconciliation',
      createdAt: originalSubCreatedAt,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    // 3. Update Provider Profile: Distinct New Subscription vs. Early Renewal Handling
    // Single Authoritative Point Rule: Do NOT advance subscriptionExpiry into the future here.
    const now = new Date();
    const isCurrentlyActiveApproved = currentProv.isSubscriptionActive === true &&
      currentProv.subscriptionApprovalStatus === 'approved' &&
      currentProv.subscriptionExpiry;

    let existingActiveExpiry = null;
    if (isCurrentlyActiveApproved) {
      const expDate = currentProv.subscriptionExpiry?.toDate
        ? currentProv.subscriptionExpiry.toDate()
        : new Date(currentProv.subscriptionExpiry);
      if (expDate > now) {
        existingActiveExpiry = expDate;
      }
    }

    const providerUpdate = {
      subscriptionPlan: planId,
      subscriptionPlanName: planName,
      subscriptionPlanTier: planTier,
      subscriptionDurationDays: durationDays,
      adminCategoryOverrideLimit: categoryLimit,
      paymentVerified: true,
      paymentVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      paymentOrderId: orderId,
      paymentId: capturedPayment.id,
      paymentAmount: orderAmountRupees,
      paymentAmountInPaise: orderAmountPaise,
      subscriptionPaymentStatus: 'paid',
      providerType: 'existing_provider',
      isRenewalEligible: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (existingActiveExpiry) {
      // Early Renewal: Preserve ongoing unexpired active subscription!
      providerUpdate.isSubscriptionActive = true;
      providerUpdate.subscriptionExpiry = currentProv.subscriptionExpiry;
      providerUpdate.subscriptionApprovalStatus = 'approved';
      providerUpdate.renewalPendingOrderId = orderId;
    } else {
      // New subscription OR expired subscription: Strictly pending Admin Approval (inactive)
      providerUpdate.isSubscriptionActive = false;
      providerUpdate.subscriptionApprovalStatus = 'pending_approval';
    }

    transaction.update(providerRef, providerUpdate);
    transactionOutcome = {
      status: 'reconciled',
      success: true,
      captured: true,
      orderId,
      paymentId: capturedPayment.id,
      amount: orderAmountPaise / 100,
      providerId,
      approvalStatus: 'pending_approval',
      adminApprovalStatus: 'pending_approval',
      isRenewal,
      preservedActive: !!existingActiveExpiry,
    };
  });

  if (transactionOutcome && (transactionOutcome.status === 'reconciled' || transactionOutcome.status === 'success')) {
    logger.info(`✅ Successfully reconciled captured payment for order ${orderId} (Payment ID: ${capturedPayment.id}, Provider: ${providerId}). Pending Admin Approval.`);
  }

  return transactionOutcome;
}

/**
 * 7. SCHEDULED MISSED PAYMENT RECONCILIATION
 * Runs every 15 minutes to inspect 'created' payments within the last 24 hours.
 * Single-field query prevents composite index failures on Firestore.
 * Fetches authoritative payment status directly from the official Razorpay API.
 * Safely transitions captured payments to 'success' and 'pending_approval' (requiring Admin Approval).
 */
exports.reconcileRecentPayments = onSchedule({
  schedule: 'every 15 minutes',
  timeZone: 'Asia/Kolkata',
  region: 'asia-south1',
  secrets: RAZORPAY_SECRETS,
}, async (event) => {
  logger.info('Starting scheduled missed payment reconciliation check...');

  const { keyId, keySecret } = await getRazorpayCredentials();
  if (!keyId || !keySecret || keySecret.startsWith('*')) {
    logger.warn('Reconciliation skipped: Razorpay API credentials not configured.');
    return;
  }

  const nowMs = Date.now();
  const twentyFourHoursAgoMs = nowMs - 24 * 60 * 60 * 1000;

  let pendingOrders = [];
  try {
    // Pure single-field equality query (never fails due to missing composite index)
    const snap = await db.collection('payments')
      .where('status', '==', 'created')
      .limit(50)
      .get();

    // Filter in-memory for recent orders created within the last 24 hours
    pendingOrders = snap.docs.filter((doc) => {
      const data = doc.data() || {};
      const createdAt = data.createdAt?.toDate ? data.createdAt.toDate() : (data.createdAt ? new Date(data.createdAt) : null);
      if (!createdAt) return true; // Include legacy records lacking createdAt
      return createdAt.getTime() >= twentyFourHoursAgoMs;
    });
  } catch (err) {
    logger.error('Scheduled payment reconciliation query failed:', err?.message || err);
    return;
  }

  if (pendingOrders.length === 0) {
    logger.info('No pending unverified orders in the last 24 hours.');
    return;
  }

  logger.info(`Found ${pendingOrders.length} pending unverified orders in the last 24 hours. Checking with Razorpay...`);
  for (const doc of pendingOrders) {
    try {
      const orderId = doc.id;
      const res = await reconcileSingleOrderInternal(orderId, null);
      if (res && (res.status === 'reconciled' || res.status === 'success' || res.captured === true)) {
        logger.info(`[RECONCILE_RECOVERED] Order ${orderId} was successfully recovered from gateway!`);
      }
    } catch (orderErr) {
      logger.error(`Error reconciling order ${doc.id}:`, orderErr?.message || orderErr);
    }
  }
});

/**
 * 8. ADMIN ON-DEMAND PAYMENT RECONCILIATION
 * Callable Function: Allows authorized Admins to immediately reconcile an order with Razorpay API.
 * Authoritative Server-Side Check on `admin_users` collection for immediate revocation support.
 */
exports.adminReconcileOrderPayment = onCall({ cors: true, secrets: RAZORPAY_SECRETS }, async (request) => {
  const { uid: adminUid } = await verifyActiveAdmin(request);

  const { orderId } = request.data || {};
  if (!orderId) {
    throw new HttpsError('invalid-argument', 'orderId is required.');
  }

  try {
    const result = await reconcileSingleOrderInternal(orderId, adminUid);
    return result;
  } catch (err) {
    logger.error(`Admin reconciliation error for order ${orderId}:`, err);
    throw new HttpsError('internal', err.message || 'Payment reconciliation failed.');
  }
});

/**
 * 8B. PROVIDER SELF-SERVICE PAYMENT RECONCILIATION
 * Callable Function: Allows an authenticated provider to verify and reconcile their own order
 * if client-side callback was missed (e.g. UPI Intent app switch / backgrounding).
 * Security Rules:
 * - Caller MUST be authenticated.
 * - Caller can ONLY reconcile orders where orderData.providerId === request.auth.uid.
 * - Idempotent: If already fulfilled, returns status immediately without re-processing.
 * - Reuses reconcileSingleOrderInternal which checks Razorpay API directly and performs OCC transaction.
 */
exports.reconcileProviderSubscriptionPayment = onCall({ cors: true, secrets: RAZORPAY_SECRETS }, async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError('unauthenticated', 'प्रदाता प्रमाणीकरण आवश्यक है।');
  }
  const callerUid = request.auth.uid;
  const { orderId } = request.data || {};
  if (!orderId || typeof orderId !== 'string' || !orderId.startsWith('order_')) {
    throw new HttpsError('invalid-argument', 'मान्य Order ID आवश्यक है।');
  }

  const paymentDoc = await db.collection('payments').doc(orderId).get();
  if (!paymentDoc.exists) {
    throw new HttpsError('not-found', 'आर्डर रिकॉर्ड नहीं मिला।');
  }
  const payData = paymentDoc.data() || {};
  if (payData.providerId !== callerUid) {
    throw new HttpsError('permission-denied', 'आप केवल अपने आर्डर का सत्यापन कर सकते हैं।');
  }

  if (payData.status === 'success' && payData.captured === true) {
    return {
      status: 'already_fulfilled',
      success: true,
      captured: true,
      adminApprovalStatus: payData.adminApprovalStatus || 'pending_approval',
      message: 'आर्डर पहले से सत्यापित है।'
    };
  }

  try {
    const result = await reconcileSingleOrderInternal(orderId, null);
    return {
      ...result,
      success: result.status === 'reconciled' || result.status === 'already_fulfilled',
      adminApprovalStatus: 'pending_approval'
    };
  } catch (err) {
    logger.error(`Provider reconciliation error for order ${orderId}:`, err);
    throw new HttpsError('internal', err.message || 'Payment reconciliation failed.');
  }
});

// Expose internal reconciliation helper for unit testing
exports._reconcileSingleOrderInternal = reconcileSingleOrderInternal;
exports._isValidWebhookSecret = isValidWebhookSecret;
exports._verifyActiveAdmin = verifyActiveAdmin;

/**
 * 7. REVIEW CUSTOM SERVICE APPLICATION
 * Callable Function: Authoritative Admin approval, category mapping, rejection, or info request.
 * Enforces that:
 * - Only verified Admins can review.
 * - Providers cannot approve their own services.
 * - Approved service maps to an authoritative existing category OR explicitly creates a new category record in `categories`.
 * - Provider status, application status, review timestamp, and Admin feedback are updated atomically via batch commit.
 */
exports.reviewCustomServiceApplication = onCall({ cors: true }, async (request) => {
  const { uid: adminUid, email: callerEmail } = await verifyActiveAdmin(request);

  const {
    applicationId,
    action, // 'approve' | 'reject' | 'more_info_required'
    mappedCategoryId,
    mappedCategoryTitle,
    newCategoryData, // { id, titleHindi, titleEnglish, description, icon, subServices }
    adminFeedback,
  } = request.data || {};

  if (!applicationId || !action) {
    throw new HttpsError('invalid-argument', 'applicationId and action are required.');
  }

  const appRef = db.collection('custom_service_applications').doc(applicationId);
  const appDoc = await appRef.get();
  if (!appDoc.exists) {
    throw new HttpsError('not-found', 'Custom service application not found.');
  }

  const appData = appDoc.data();
  const providerId = appData.providerId || applicationId;
  const providerRef = db.collection('providers').doc(providerId);

  const batch = db.batch();
  const now = admin.firestore.FieldValue.serverTimestamp();

  if (action === 'approve') {
    let finalCategoryId = mappedCategoryId;
    let finalCategoryTitle = mappedCategoryTitle;

    // If Admin explicitly decided to create a new category in Firestore categories collection
    if (newCategoryData && newCategoryData.id) {
      const newCatRef = db.collection('categories').doc(newCategoryData.id);
      batch.set(newCatRef, {
        id: newCategoryData.id,
        titleHindi: newCategoryData.titleHindi || newCategoryData.id,
        titleEnglish: newCategoryData.titleEnglish || newCategoryData.id,
        description: newCategoryData.description || '',
        icon: newCategoryData.icon || 'handyman',
        imageUrl: newCategoryData.imageUrl || '',
        subServices: newCategoryData.subServices || [],
        priorityOrder: newCategoryData.priorityOrder || 99,
        isActive: true,
        status: 'active',
        isDeleted: false,
        createdAt: now,
        updatedAt: now,
      }, { merge: true });

      finalCategoryId = newCategoryData.id;
      finalCategoryTitle = newCategoryData.titleHindi || newCategoryData.titleEnglish || newCategoryData.id;
    }

    if (!finalCategoryId) {
      throw new HttpsError('invalid-argument', 'Approved service must be mapped to an authoritative category ID.');
    }

    batch.update(appRef, {
      status: 'approved',
      mappedCategoryId: finalCategoryId,
      mappedCategoryTitle: finalCategoryTitle || '',
      adminFeedback: adminFeedback || 'विशेष सेवा आवेदन स्वीकृत किया गया है।',
      reviewedAt: now,
      reviewedBy: callerEmail || request.auth.uid,
      updatedAt: now,
    });

    batch.update(providerRef, {
      primaryCategoryId: finalCategoryId,
      primaryCategoryTitle: finalCategoryTitle || '',
      selectedCategoryIds: admin.firestore.FieldValue.arrayUnion(finalCategoryId),
      selectedCategoryId: finalCategoryId,
      customServiceStatus: 'approved',
      categoryRequestStatus: 'approved',
      registrationStatus: 'category_approved',
      currentStep: 2,
      updatedAt: now,
    });
  } else if (action === 'reject') {
    batch.update(appRef, {
      status: 'rejected',
      adminFeedback: adminFeedback || 'आवेदन अस्वीकृत किया गया।',
      reviewedAt: now,
      reviewedBy: callerEmail || request.auth.uid,
      updatedAt: now,
    });

    batch.update(providerRef, {
      customServiceStatus: 'rejected',
      categoryRequestStatus: 'rejected',
      categoryRejectionReason: adminFeedback || 'कस्टम सेवा आवेदन अस्वीकृत किया गया',
      rejectionReason: adminFeedback || 'कस्टम सेवा आवेदन अस्वीकृत किया गया',
      updatedAt: now,
    });
  } else if (action === 'more_info_required') {
    batch.update(appRef, {
      status: 'more_info_required',
      adminFeedback: adminFeedback || 'कृपया अतिरिक्त जानकारी प्रदान करें।',
      reviewedAt: now,
      reviewedBy: callerEmail || request.auth.uid,
      updatedAt: now,
    });

    batch.update(providerRef, {
      customServiceStatus: 'more_info_required',
      rejectionReason: adminFeedback || 'कृपया अतिरिक्त जानकारी प्रदान करें',
      updatedAt: now,
    });
  } else {
    throw new HttpsError('invalid-argument', `Unknown action: ${action}`);
  }

  await batch.commit();

  return { success: true, action, applicationId, providerId };
});

/**
 * 7A. REQUEST PROVIDER CATEGORY CHANGE
 * Callable Cloud Function: Allows authenticated providers to change/re-apply for a category.
 * Enforces that:
 * - Caller is authenticated and is the owner of the provider account.
 * - The provider exists and is not soft-deleted.
 * - If selecting an existing category, validates that it exists and isActive !== false in 'categories'.
 * - Preserves existing approved category until Admin approves.
 * - Saves request in 'category_requests' idempotently (one active request per provider).
 * - Updates 'providers/{providerId}' with requestedCategoryId, requestedCategoryTitle, and categoryApprovalStatus = 'pending_review'.
 * - Strictly NEVER alters subscription, payments, or payment verification records.
 */
exports.requestProviderCategoryChange = onCall({ cors: true }, async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError('unauthenticated', 'ऑथेंटिकेशन आवश्यक है (Authentication required).');
  }

  const {
    providerId,
    requestedCategoryId,
    requestedCategoryTitle,
    customServiceDetails,
  } = request.data || {};

  if (!providerId || request.auth.uid !== providerId) {
    throw new HttpsError('permission-denied', 'आप केवल अपनी प्रोफाइल के लिए श्रेणी परिवर्तन का अनुरोध कर सकते हैं।');
  }

  if (!requestedCategoryId || !requestedCategoryTitle) {
    throw new HttpsError('invalid-argument', 'requestedCategoryId and requestedCategoryTitle are required.');
  }

  const providerRef = db.collection('providers').doc(providerId);
  const providerDoc = await providerRef.get();
  if (!providerDoc.exists) {
    throw new HttpsError('not-found', 'Provider profile not found.');
  }

  const pData = providerDoc.data() || {};
  if (pData.isDeleted === true) {
    throw new HttpsError('failed-precondition', 'Cannot request category change for a deleted account.');
  }

  let finalCatId = requestedCategoryId.trim();
  let finalCatTitle = requestedCategoryTitle.trim();

  // Validate category if targeting an existing category ID
  if (finalCatId !== 'other' && finalCatId !== 'custom') {
    const catDoc = await db.collection('categories').doc(finalCatId).get();
    if (!catDoc.exists) {
      // Also check if matches doc by query
      const catQuery = await db.collection('categories').where('id', '==', finalCatId).limit(1).get();
      if (catQuery.empty) {
        throw new HttpsError('not-found', `Category '${finalCatId}' is not an active category.`);
      }
      const cData = catQuery.docs[0].data() || {};
      if (cData.isActive === false || cData.isDeleted === true) {
        throw new HttpsError('failed-precondition', 'Selected category is currently inactive.');
      }
      finalCatTitle = cData.titleHindi || cData.titleEnglish || finalCatTitle;
    } else {
      const cData = catDoc.data() || {};
      if (cData.isActive === false || cData.isDeleted === true) {
        throw new HttpsError('failed-precondition', 'Selected category is currently inactive.');
      }
      finalCatTitle = cData.titleHindi || cData.titleEnglish || finalCatTitle;
    }
  }

  const batch = db.batch();
  const now = admin.firestore.FieldValue.serverTimestamp();
  const requestId = `req_${providerId}`;
  const reqRef = db.collection('category_requests').doc(requestId);

  const reqPayload = {
    id: requestId,
    requestId: requestId,
    providerId: providerId,
    providerName: pData.businessName || pData.fullName || 'Service Provider',
    phoneNumber: pData.phoneNumber || pData.phone || '',
    email: pData.email || '',
    currentApprovedCategoryId: pData.primaryCategoryId || '',
    currentApprovedCategoryTitle: pData.primaryCategoryTitle || '',
    requestedCategoryId: finalCatId,
    requestedCategoryTitle: finalCatTitle,
    serviceName: finalCatTitle,
    status: 'pending_review',
    categoryRequestStatus: 'pending_review',
    requestType: 'category_change_request',
    updatedAt: now,
  };

  if (customServiceDetails && typeof customServiceDetails === 'object') {
    if (customServiceDetails.serviceDescription) reqPayload.serviceDescription = String(customServiceDetails.serviceDescription);
    if (customServiceDetails.offeredServices) reqPayload.offeredServices = String(customServiceDetails.offeredServices);
    if (customServiceDetails.experienceYears) reqPayload.experienceYears = Number(customServiceDetails.experienceYears);
    if (customServiceDetails.visitingCharge) reqPayload.visitingCharge = Number(customServiceDetails.visitingCharge);
    if (customServiceDetails.jamuiArea) reqPayload.jamuiArea = String(customServiceDetails.jamuiArea);
    if (customServiceDetails.fullAddress) reqPayload.fullAddress = String(customServiceDetails.fullAddress);
  }

  // Idempotently create/update the active category request
  const existingReq = await reqRef.get();
  if (!existingReq.exists) {
    reqPayload.createdAt = now;
  }

  batch.set(reqRef, reqPayload, { merge: true });

  // Update provider profile with requested category while strictly preserving subscriptions
  batch.update(providerRef, {
    requestedCategoryId: finalCatId,
    requestedCategoryTitle: finalCatTitle,
    categoryApprovalStatus: 'pending_review',
    categoryRequestStatus: 'pending_review',
    categoryRequestId: requestId,
    categoryRejectionReason: admin.firestore.FieldValue.delete(),
    categoryRequestSubmittedAt: now,
    updatedAt: now,
  });

  await batch.commit();

  logger.info(`✅ Provider (${providerId}) requested category change to: ${finalCatTitle} (${finalCatId})`);

  return {
    success: true,
    providerId,
    requestId,
    requestedCategoryId: finalCatId,
    requestedCategoryTitle: finalCatTitle,
    status: 'pending_review',
  };
});

/**
 * 7B. REVIEW CATEGORY CHANGE REQUEST
 * Callable Cloud Function: Authoritative Admin review for category changes & applications.
 * Enforces that:
 * - Only verified Admins can review.
 * - On approval, updates provider's primaryCategoryId & primaryCategoryTitle to the approved category.
 * - Clears requested category fields and updates categoryApprovalStatus to 'approved'.
 * - On rejection, sets categoryApprovalStatus to 'rejected' and records categoryRejectionReason.
 * - Strictly preserves provider's subscription, payments, and payment records.
 * - Idempotent against duplicate clicks or retries.
 */
exports.reviewCategoryChangeRequest = onCall({ cors: true }, async (request) => {
  const { uid: adminUid, email: callerEmail } = await verifyActiveAdmin(request);

  const {
    requestId,
    providerId: explicitProviderId,
    action, // 'approve' | 'reject'
    mappedCategoryId,
    mappedCategoryTitle,
    adminFeedback,
    rejectionReason,
  } = request.data || {};

  if (!requestId || !action) {
    throw new HttpsError('invalid-argument', 'requestId and action are required.');
  }

  if (action !== 'approve' && action !== 'reject') {
    throw new HttpsError('invalid-argument', `Unknown action: ${action}`);
  }

  const reqRef = db.collection('category_requests').doc(requestId);
  const reqDoc = await reqRef.get();

  if (!reqDoc.exists) {
    throw new HttpsError('not-found', `Category request '${requestId}' not found.`);
  }

  const reqData = reqDoc.data() || {};
  const targetProviderId = reqData.providerId;

  if (!targetProviderId) {
    throw new HttpsError('failed-precondition', 'Category request document is missing a providerId.');
  }

  if (explicitProviderId && explicitProviderId !== targetProviderId) {
    throw new HttpsError('invalid-argument', `Provider ID mismatch: explicit '${explicitProviderId}' does not match request providerId '${targetProviderId}'.`);
  }

  const providerRef = db.collection('providers').doc(targetProviderId);
  const providerDoc = await providerRef.get();
  if (!providerDoc.exists) {
    throw new HttpsError('not-found', 'Provider profile not found.');
  }

  const pData = providerDoc.data() || {};

  // Idempotency: If already in target status, return success gracefully
  if (action === 'approve' && reqData.status === 'approved' && pData.categoryApprovalStatus === 'approved') {
    return {
      success: true,
      alreadyProcessed: true,
      providerId: targetProviderId,
      status: 'approved',
      primaryCategoryId: pData.primaryCategoryId,
      message: 'Category request is already approved.',
    };
  }
  if (action === 'reject' && reqData.status === 'rejected' && pData.categoryApprovalStatus === 'rejected') {
    return {
      success: true,
      alreadyProcessed: true,
      providerId: targetProviderId,
      status: 'rejected',
      message: 'Category request is already rejected.',
    };
  }

  // Stale Request Protection: Verify that provider has not submitted a newer or different category request
  if (pData.categoryRequestId && pData.categoryRequestId !== requestId) {
    throw new HttpsError('failed-precondition', `Stale request conflict: Provider has an active request '${pData.categoryRequestId}', cannot review older request '${requestId}'.`);
  }
  if (reqData.requestedCategoryId && pData.requestedCategoryId && reqData.requestedCategoryId !== pData.requestedCategoryId) {
    throw new HttpsError('failed-precondition', `Stale request conflict: Provider active requested category is '${pData.requestedCategoryId}', but this request is for '${reqData.requestedCategoryId}'.`);
  }

  const now = admin.firestore.FieldValue.serverTimestamp();
  const batch = db.batch();

  if (action === 'approve') {
    const finalCatId = (mappedCategoryId || reqData.requestedCategoryId || '').trim();
    if (!finalCatId) {
      throw new HttpsError('invalid-argument', 'Approved category must have a valid mappedCategoryId or requestedCategoryId.');
    }

    // Verify category exists and is active in 'categories' collection
    let finalCatTitle = (mappedCategoryTitle || reqData.requestedCategoryTitle || finalCatId).trim();
    const catDoc = await db.collection('categories').doc(finalCatId).get();
    if (catDoc.exists) {
      const cData = catDoc.data() || {};
      if (cData.isActive === false || cData.isDeleted === true) {
        throw new HttpsError('failed-precondition', `Category '${finalCatId}' is currently inactive.`);
      }
      finalCatTitle = cData.titleHindi || cData.titleEnglish || finalCatTitle;
    } else {
      const catQuery = await db.collection('categories').where('id', '==', finalCatId).limit(1).get();
      if (!catQuery.empty) {
        const cData = catQuery.docs[0].data() || {};
        if (cData.isActive === false || cData.isDeleted === true) {
          throw new HttpsError('failed-precondition', `Category '${finalCatId}' is currently inactive.`);
        }
        finalCatTitle = cData.titleHindi || cData.titleEnglish || finalCatTitle;
      } else {
        throw new HttpsError('not-found', `Target category '${finalCatId}' does not exist in active categories collection.`);
      }
    }

    batch.update(reqRef, {
      status: 'approved',
      categoryRequestStatus: 'approved',
      mappedCategoryId: finalCatId,
      mappedCategoryTitle: finalCatTitle,
      adminFeedback: adminFeedback || 'श्रेणी परिवर्तन आवेदन स्वीकृत किया गया।',
      reviewedAt: now,
      reviewedBy: callerEmail || adminUid,
      updatedAt: now,
    });

    batch.update(providerRef, {
      primaryCategoryId: finalCatId,
      primaryCategoryTitle: finalCatTitle,
      selectedCategoryId: finalCatId,
      selectedCategoryIds: admin.firestore.FieldValue.arrayUnion(finalCatId),
      categoryApprovalStatus: 'approved',
      categoryRequestStatus: 'approved',
      requestedCategoryId: admin.firestore.FieldValue.delete(),
      requestedCategoryTitle: admin.firestore.FieldValue.delete(),
      categoryRejectionReason: admin.firestore.FieldValue.delete(),
      registrationStatus: 'category_approved',
      updatedAt: now,
    });

    // Audit log
    const auditRef = db.collection('audit_logs').doc();
    batch.set(auditRef, {
      action: 'CATEGORY_REQUEST_APPROVED',
      requestId: requestId,
      providerId: targetProviderId,
      mappedCategoryId: finalCatId,
      mappedCategoryTitle: finalCatTitle,
      adminEmail: callerEmail || adminUid,
      timestamp: now,
    });
  } else if (action === 'reject') {
    const feedbackText = rejectionReason || adminFeedback || 'श्रेणी परिवर्तन आवेदन अस्वीकृत किया गया।';

    batch.update(reqRef, {
      status: 'rejected',
      categoryRequestStatus: 'rejected',
      adminFeedback: feedbackText,
      rejectionReason: feedbackText,
      reviewedAt: now,
      reviewedBy: callerEmail || adminUid,
      updatedAt: now,
    });

    batch.update(providerRef, {
      categoryApprovalStatus: 'rejected',
      categoryRequestStatus: 'rejected',
      categoryRejectionReason: feedbackText,
      updatedAt: now,
    });

    // Audit log
    const auditRef = db.collection('audit_logs').doc();
    batch.set(auditRef, {
      action: 'CATEGORY_REQUEST_REJECTED',
      requestId: requestId,
      providerId: targetProviderId,
      rejectionReason: feedbackText,
      adminEmail: callerEmail || adminUid,
      timestamp: now,
    });
  }

  await batch.commit();

  logger.info(`✅ Admin (${adminUid}) reviewed category request ${requestId} with action: ${action}`);

  return { success: true, action, requestId, providerId: targetProviderId };
});

/**
 * 7C. ADMIN DIRECT CATEGORY CHANGE FOR PROVIDERS
 * Callable Cloud Function: Authoritative Admin category update for pending/unpaid providers.
 * Enforces strict Zero-Trust security:
 * - Admin Authentication verified via verifyActiveAdmin(request).
 * - Provider ID and newCategoryId are validated.
 * - Change reason is mandatory.
 * - Provider must exist and must not be soft-deleted.
 * - ACTIVE/PAID PROVIDER LOCK: If provider has paymentVerified === true OR isSubscriptionActive === true,
 *   rejects immediately with 'failed-precondition' (no bypass / no force override).
 * - Target Category is validated against canonical Firestore 'categories' and 'premium_categories' collections.
 *   Throws 'not-found' if invalid, 'failed-precondition' if inactive or deleted.
 * - Dynamic Category Type Determination: Backend determines whether new category is 'premium' or 'general'
 *   directly from Firestore records (client claims are ignored).
 * - Atomic batch update on providers/{providerId} and audit_logs:
 *   - primaryCategoryId, primaryCategoryTitle, selectedCategoryId, selectedCategoryIds
 *   - categoryType ('premium' | 'general')
 *   - isPremiumCategory (true | false)
 *   - isPremiumCategoryEligible (true | false)
 *   - categoryApprovalStatus: 'approved'
 *   - categoryRequestStatus: 'approved'
 *   - registrationStatus: 'category_approved'
 *   - Clears pending request fields (requestedCategoryId, requestedCategoryTitle, categoryRejectionReason)
 *   - NEVER activates subscription, NEVER alters payment verification, NEVER changes subscriptionExpiry
 *   - Provider KYC/account approval remains distinct (does NOT set status/kycStatus to approved)
 *   - Never grants isPremiumEligible: true (entitlement requires verified paid subscription)
 */
exports.adminChangeProviderCategory = onCall({ cors: true }, async (request) => {
  const { uid: adminUid, email: callerEmail } = await verifyActiveAdmin(request);

  const {
    providerId,
    newCategoryId,
    changeReason,
  } = request.data || {};

  if (!providerId || typeof providerId !== 'string' || !providerId.trim()) {
    throw new HttpsError('invalid-argument', 'providerId is required.');
  }

  if (!newCategoryId || typeof newCategoryId !== 'string' || !newCategoryId.trim()) {
    throw new HttpsError('invalid-argument', 'newCategoryId is required.');
  }

  const reasonText = (changeReason || '').toString().trim();
  if (!reasonText) {
    throw new HttpsError('invalid-argument', 'श्रेणी बदलने का कारण (changeReason) अनिवार्य है।');
  }

  const providerRef = db.collection('providers').doc(providerId.trim());
  const providerDoc = await providerRef.get();
  if (!providerDoc.exists) {
    throw new HttpsError('not-found', 'Provider profile not found.');
  }

  const pData = providerDoc.data() || {};
  if (pData.isDeleted === true) {
    throw new HttpsError('failed-precondition', 'हटाए गए (deleted) प्रोवाइडर खाते की श्रेणी नहीं बदली जा सकती।');
  }

  // STRICT RULE C: Active / Paid Provider Block
  // Category change is strictly blocked for any provider with active subscription or verified payment
  if (pData.paymentVerified === true || pData.isSubscriptionActive === true) {
    throw new HttpsError(
      'failed-precondition',
      'सक्रिय सब्सक्रिप्शन या सत्यापित भुगतान वाले प्रोवाइडर की श्रेणी नहीं बदली जा सकती। (Cannot change category for a provider with an active subscription or verified payment).'
    );
  }

  const finalCatId = newCategoryId.trim();

  // Validate Target Category from Canonical Firestore collections
  let isCategoryPremium = false;
  let finalCatTitle = finalCatId;
  let categoryFound = false;

  // 1. Check premium_categories collection
  try {
    const premDoc = await db.collection('premium_categories').doc(finalCatId).get();
    if (premDoc.exists) {
      const premData = premDoc.data() || {};
      if (premData.isActive === false || premData.isDeleted === true) {
        throw new HttpsError('failed-precondition', `चयनित प्रीमियम श्रेणी '${finalCatId}' वर्तमान में निष्क्रिय (inactive) है।`);
      }
      isCategoryPremium = true;
      categoryFound = true;
      finalCatTitle = premData.customTitle || premData.categoryName || premData.titleHindi || premData.titleEnglish || finalCatId;
    } else {
      const premQuery = await db.collection('premium_categories')
        .where('categoryId', '==', finalCatId)
        .limit(1)
        .get();
      if (!premQuery.empty) {
        const premData = premQuery.docs[0].data() || {};
        if (premData.isActive === false || premData.isDeleted === true) {
          throw new HttpsError('failed-precondition', `चयनित प्रीमियम श्रेणी '${finalCatId}' वर्तमान में निष्क्रिय (inactive) है।`);
        }
        isCategoryPremium = true;
        categoryFound = true;
        finalCatTitle = premData.customTitle || premData.categoryName || premData.titleHindi || premData.titleEnglish || finalCatId;
      }
    }
  } catch (err) {
    if (err instanceof HttpsError) throw err;
    logger.warn(`Error querying premium_categories for ${finalCatId}:`, err);
  }

  // 2. Check canonical categories collection
  try {
    const catDoc = await db.collection('categories').doc(finalCatId).get();
    if (catDoc.exists) {
      const catData = catDoc.data() || {};
      if (catData.isActive === false || catData.isDeleted === true) {
        throw new HttpsError('failed-precondition', `चयनित श्रेणी '${finalCatId}' वर्तमान में निष्क्रिय (inactive) है।`);
      }
      categoryFound = true;
      if (catData.categoryType === 'premium' || catData.isPremium === true) {
        isCategoryPremium = true;
      }
      finalCatTitle = catData.titleHindi || catData.titleEnglish || catData.name || catData.title || finalCatTitle;
    } else {
      const catQuery = await db.collection('categories')
        .where('id', '==', finalCatId)
        .limit(1)
        .get();
      if (!catQuery.empty) {
        const catData = catQuery.docs[0].data() || {};
        if (catData.isActive === false || catData.isDeleted === true) {
          throw new HttpsError('failed-precondition', `चयनित श्रेणी '${finalCatId}' वर्तमान में निष्क्रिय (inactive) है।`);
        }
        categoryFound = true;
        if (catData.categoryType === 'premium' || catData.isPremium === true) {
          isCategoryPremium = true;
        }
        finalCatTitle = catData.titleHindi || catData.titleEnglish || catData.name || catData.title || finalCatTitle;
      }
    }
  } catch (err) {
    if (err instanceof HttpsError) throw err;
    logger.warn(`Error querying categories for ${finalCatId}:`, err);
  }

  // Unisex Salon canonical fallback classification
  if (finalCatId.toLowerCase() === 'unisex_salon' || finalCatId.toLowerCase() === 'salon') {
    isCategoryPremium = true;
    categoryFound = true;
    if (finalCatTitle === finalCatId) finalCatTitle = 'Unisex Salon';
  }

  if (!categoryFound) {
    throw new HttpsError('not-found', `श्रेणी '${finalCatId}' डेटाबेस में नहीं मिली (Category not found in active categories collection).`);
  }

  const now = admin.firestore.FieldValue.serverTimestamp();
  const batch = db.batch();

  // Existing category info for audit log
  const oldCategoryType = (pData.categoryType || (pData.isPremiumCategory ? 'premium' : 'general')).toString();
  const oldCatId = (pData.primaryCategoryId || pData.categoryId || pData.selectedCategoryId || '').toString();
  const oldCatTitle = (pData.primaryCategoryTitle || pData.categoryTitle || pData.category || oldCatId).toString();

  const updatePayload = {
    primaryCategoryId: finalCatId,
    primaryCategoryTitle: finalCatTitle,
    selectedCategoryId: finalCatId,
    selectedCategoryIds: [finalCatId],
    categoryType: isCategoryPremium ? 'premium' : 'general',
    isPremiumCategory: isCategoryPremium,
    isPremiumCategoryEligible: isCategoryPremium,
    categoryApprovalStatus: 'approved',
    categoryRequestStatus: 'approved',
    requestedCategoryId: admin.firestore.FieldValue.delete(),
    requestedCategoryTitle: admin.firestore.FieldValue.delete(),
    categoryRejectionReason: admin.firestore.FieldValue.delete(),
    registrationStatus: 'category_approved',
    categoryChangedBy: adminUid,
    categoryChangedAt: now,
    updatedAt: now,
  };

  // If changed to normal category, ensure any residual isPremiumEligible is reset to false
  if (!isCategoryPremium) {
    updatePayload.isPremiumEligible = false;
  }
  // If changed to premium category, note: do NOT set isPremiumEligible: true until verified payment!

  batch.update(providerRef, updatePayload);

  // 4. Immutable Audit Log
  const auditRef = db.collection('audit_logs').doc();
  batch.set(auditRef, {
    action: 'ADMIN_CHANGE_PROVIDER_CATEGORY',
    providerId: providerId.trim(),
    providerName: pData.fullName || pData.businessName || 'Service Provider',
    oldCategoryId: oldCatId,
    oldCategoryTitle: oldCatTitle,
    oldCategoryType: oldCategoryType,
    newCategoryId: finalCatId,
    newCategoryTitle: finalCatTitle,
    newCategoryType: isCategoryPremium ? 'premium' : 'general',
    adminUid: adminUid,
    adminEmail: callerEmail || adminUid,
    changeReason: reasonText,
    timestamp: now,
  });

  await batch.commit();

  logger.info(`✅ Admin (${adminUid}) changed Provider (${providerId}) category from '${oldCatId}' (${oldCategoryType}) to '${finalCatId}' (${isCategoryPremium ? 'premium' : 'general'}). Reason: ${reasonText}`);

  return {
    success: true,
    providerId: providerId.trim(),
    oldCategoryId: oldCatId,
    newCategoryId: finalCatId,
    newCategoryTitle: finalCatTitle,
    categoryType: isCategoryPremium ? 'premium' : 'general',
    isPremiumCategory: isCategoryPremium,
    message: 'प्रोवाइडर श्रेणी सफलतापूर्वक अपडेट की गई।',
  };
});

/**
 * 7. ADMIN APPROVE & ACTIVATE SUBSCRIPTION
 * Callable Cloud Function: Verifies admin identity, validates payment is verified success,
 * securely activates subscription, computes dates from plan, prevents duplicates, and logs in audit_logs.
 */
exports.adminApproveSubscription = onCall({ cors: true }, async (request) => {
  const { uid: adminUid, email: callerEmail } = await verifyActiveAdmin(request);

  const { providerId, orderId } = request.data || {};
  if (!providerId || !orderId) {
    throw new HttpsError('invalid-argument', 'providerId and orderId are required.');
  }

  const providerRef = db.collection('providers').doc(providerId);
  const paymentRef = db.collection('payments').doc(orderId);
  const subRef = db.collection('subscriptions').doc(`sub_${orderId}`);
  const auditRef = db.collection('audit_logs').doc();

  // Concurrency-Safe Approval via Firestore runTransaction (OCC)
  const result = await db.runTransaction(async (transaction) => {
    // 1. Transactional Reads
    const [providerDoc, paymentDoc] = await Promise.all([
      transaction.get(providerRef),
      transaction.get(paymentRef),
    ]);

    if (!providerDoc.exists) {
      throw new HttpsError('not-found', 'Provider profile not found.');
    }
    const pData = providerDoc.data() || {};

    // Check if provider was soft-deleted
    if (pData.isDeleted === true) {
      throw new HttpsError('failed-precondition', 'Cannot activate subscription for a deleted provider.');
    }

    if (!paymentDoc.exists) {
      throw new HttpsError('not-found', `Payment record for order ${orderId} not found.`);
    }
    const payData = paymentDoc.data() || {};

    // 2. Strict Duplicate / Replay Activation Guard
    if (payData.adminApprovalStatus === 'approved') {
      throw new HttpsError(
        'failed-precondition',
        'This subscription payment has already been approved and activated.'
      );
    }

    if (payData.adminApprovalStatus === 'rejected' && request.data?.allowReapprove !== true) {
      throw new HttpsError(
        'failed-precondition',
        'Cannot activate subscription: This payment request was previously rejected. Explicit re-approval authorization is required.'
      );
    }

    // 3. Strict Verification: Payment must be success AND confirmed as captured AND liveVerified
    if (payData.status !== 'success' || payData.captured !== true || payData.liveVerified !== true) {
      throw new HttpsError(
        'failed-precondition',
        `Cannot activate subscription: Payment is not verified as captured (status: '${payData.status}', captured: ${payData.captured}, liveVerified: ${payData.liveVerified}). Only confirmed captured payments can be activated.`
      );
    }

    // 4. Ensure valid Razorpay Payment ID and Order ID formats
    const paymentId = payData.paymentId || payData.razorpayPaymentId;
    if (!paymentId || typeof paymentId !== 'string' || !paymentId.startsWith('pay_')) {
      throw new HttpsError('failed-precondition', 'Invalid or missing Razorpay Payment ID in payment record.');
    }
    if (!payData.orderId || typeof payData.orderId !== 'string' || !payData.orderId.startsWith('order_')) {
      throw new HttpsError('failed-precondition', 'Invalid or missing Razorpay Order ID in payment record.');
    }

    // 5. Currency Check
    if (payData.currency && payData.currency !== 'INR') {
      throw new HttpsError('failed-precondition', 'Payment currency must be INR.');
    }

    // 6. Ensure payment belongs to this provider
    if (payData.providerId && payData.providerId !== providerId) {
      throw new HttpsError('permission-denied', 'Payment order does not belong to the specified provider.');
    }

    // 7. Authoritative Immutable Pricing & Snapshot Validation (Fail-Closed)
    // Legacy records missing amountInPaise must NOT be guessed; require manual reconciliation.
    if (payData.amountInPaise === undefined || payData.amountInPaise === null) {
      throw new HttpsError(
        'failed-precondition',
        'Legacy payment record missing immutable pricing snapshot (amountInPaise). Automated approval blocked for safety; manual reconciliation required by administrator.'
      );
    }

    const recordedPaise = Number(payData.amountInPaise);
    if (!Number.isInteger(recordedPaise) || recordedPaise < 100) {
      throw new HttpsError(
        'failed-precondition',
        `Cannot activate subscription: Invalid recorded payment amount (${recordedPaise} paise). Minimum required is 100 paise (₹1.00).`
      );
    }

    // If pricingSnapshot object exists, verify exact integer equality with snapshot amountInPaise
    if (payData.pricingSnapshot && payData.pricingSnapshot.amountInPaise !== undefined) {
      const snapshotPaise = Number(payData.pricingSnapshot.amountInPaise);
      if (recordedPaise !== snapshotPaise) {
        throw new HttpsError(
          'failed-precondition',
          `Cannot activate subscription: Recorded payment amount (${recordedPaise} paise) does not match immutable order pricing snapshot (${snapshotPaise} paise).`
        );
      }
    }

    // If payData.amount (in rupees) is also present, ensure arithmetic consistency
    if (payData.amount !== undefined) {
      const amountPaise = Math.round(Number(payData.amount) * 100);
      if (amountPaise !== recordedPaise) {
        throw new HttpsError(
          'failed-precondition',
          `Cannot activate subscription: Inconsistent amount (₹${payData.amount}) and amountInPaise (${recordedPaise} paise) in payment record.`
        );
      }
    }

    // 8. Resolve Plan Metadata (Duration & Category Limit) strictly from Snapshot or Trusted Order Record
    const planId = payData.planId || pData.subscriptionPlan || payData.pricingSnapshot?.planId || '';

    let planData = {};
    if (planId) {
      try {
        const planRef = db.collection('subscription_plans').doc(planId);
        const planDoc = await transaction.get(planRef);
        if (planDoc.exists) {
          planData = planDoc.data() || {};
        }
      } catch (planErr) {
        logger.warn('Plan lookup note in adminApproveSubscription:', planErr);
      }
    }

    let durationDays = payData.pricingSnapshot?.durationDays !== undefined
      ? Number(payData.pricingSnapshot.durationDays)
      : (payData.durationDays !== undefined ? Number(payData.durationDays) : Number(planData.durationDays || 0));
    let categoryLimit = payData.pricingSnapshot?.categoryLimit !== undefined
      ? Number(payData.pricingSnapshot.categoryLimit)
      : (payData.categoryLimit !== undefined ? Number(payData.categoryLimit) : Number(planData.categoryLimit || 1));
    let planName = payData.pricingSnapshot?.planName || payData.planName || planData.name || 'Subscription Plan';

    // Authoritatively resolve planTier from plan document or pricing snapshot
    let planTier = (planData.planTier || payData.pricingSnapshot?.planTier || payData.planTier || 'normal').toString().toLowerCase().trim();

    // Authoritative check: plan is premium eligible strictly based on verified subscription plan
    const isPlanPremium = Boolean(
      planData.isPremiumCategoryEligible === true ||
      planTier === 'premium' ||
      payData.pricingSnapshot?.isPremiumCategoryEligible === true
    );

    if (!durationDays || durationDays <= 0) {
      durationDays = Number(planData.durationDays || 0);
    }

    if (!durationDays || durationDays <= 0) {
      logger.error(`Admin approval failed: No verifiable durationDays found for Order ${orderId}, Plan ${planId}.`);
      throw new HttpsError(
        'failed-precondition',
        'सब्सक्रिप्शन अवधि (durationDays) सत्यापित नहीं की जा सकी। मैन्युअल समीक्षा आवश्यक है।'
      );
    }
    categoryLimit = categoryLimit || 1;

    const planLimits = {
      maxActiveListings: Number(planData.maxActiveListings || 10),
      maxImagesPerProvider: Number(planData.maxImagesPerProvider || 20),
      maxImagesPerListing: Number(planData.maxImagesPerListing || 5),
      maxSizePerImageBytes: Number(planData.maxSizePerImageBytes || (5 * 1024 * 1024)),
      maxTotalStorageBytes: Number(planData.maxTotalStorageBytes || (50 * 1024 * 1024)),
      isPremiumCategoryEligible: isPlanPremium,
    };

    // 9. Single Authoritative Activation Point: Apply durationDays exactly ONCE per payment
    const now = new Date();
    let startDate = now;

    // Check if provider has a genuinely active, already-approved subscription to stack upon (Renewal)
    const isCurrentlyActiveApproved = pData.isSubscriptionActive === true &&
      pData.subscriptionApprovalStatus === 'approved' &&
      pData.subscriptionExpiry;

    if (isCurrentlyActiveApproved) {
      const existingDate = pData.subscriptionExpiry.toDate
        ? pData.subscriptionExpiry.toDate()
        : new Date(pData.subscriptionExpiry);
      if (existingDate > now) {
        startDate = existingDate; // Preserve unexpired time and stack renewal from current expiry
      }
    }

    const expiryDate = new Date(startDate.getTime() + durationDays * 24 * 60 * 60 * 1000);

    const paidRupees = payData.amount !== undefined ? Number(payData.amount) : (recordedPaise / 100);

    // 10. Atomic Transactional Writes
    // A. Update Provider Profile: Activate subscription & Auto-Approve Provider Profile & KYC & snapshot limits
    transaction.update(providerRef, {
      status: 'approved',
      kycStatus: 'approved',
      verificationStatus: 'approved',
      isVerified: true,
      isSubscriptionActive: true,
      subscriptionPlan: planId,
      subscriptionPlanName: planName,
      subscriptionPlanTier: planTier,
      subscriptionDurationDays: durationDays,
      subscriptionStartDate: admin.firestore.Timestamp.fromDate(startDate),
      subscriptionExpiry: admin.firestore.Timestamp.fromDate(expiryDate),
      subscriptionApprovalStatus: 'approved',
      subscriptionApprovedAt: admin.firestore.FieldValue.serverTimestamp(),
      subscriptionApprovedBy: adminUid,
      adminCategoryOverrideLimit: categoryLimit,
      planLimits: planLimits,
      isPremiumEligible: Boolean(planLimits.isPremiumCategoryEligible),
      storageUsage: pData.storageUsage || {
        totalBytesUsed: 0,
        totalImagesCount: 0,
        reservedBytes: 0,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp()
      },
      paymentVerified: true,
      paymentOrderId: orderId,
      paymentId: paymentId,
      paymentAmount: paidRupees,
      paymentAmountInPaise: recordedPaise,
      isActive: pData.isActive !== false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // B. Update Subscription History
    transaction.set(
      subRef,
      {
        status: 'active',
        approvalStatus: 'approved',
        approvedAt: admin.firestore.FieldValue.serverTimestamp(),
        approvedBy: adminUid,
        startDate: admin.firestore.Timestamp.fromDate(startDate),
        expiryDate: admin.firestore.Timestamp.fromDate(expiryDate),
        durationDays: durationDays,
        categoryLimit: categoryLimit,
        planTier: planTier,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    // C. Update Payment Document (Atomic OCC marker: adminApprovalStatus -> 'approved')
    transaction.set(
      paymentRef,
      {
        adminApprovalStatus: 'approved',
        approvedAt: admin.firestore.FieldValue.serverTimestamp(),
        approvedBy: adminUid,
        startDate: admin.firestore.Timestamp.fromDate(startDate),
        expiryDate: admin.firestore.Timestamp.fromDate(expiryDate),
        durationDays: durationDays,
        categoryLimit: categoryLimit,
        planTier: planTier,
      },
      { merge: true }
    );

    // D. Record Immutable Audit Log
    transaction.set(auditRef, {
      action: 'SUBSCRIPTION_APPROVED_AND_ACTIVATED',
      providerId: providerId,
      providerName: pData.fullName || pData.businessName || payData.providerName || '',
      orderId: orderId,
      paymentId: paymentId,
      amount: paidRupees,
      amountInPaise: recordedPaise,
      planId: planId,
      planTier: planTier,
      durationDays: durationDays,
      startDate: admin.firestore.Timestamp.fromDate(startDate),
      expiryDate: admin.firestore.Timestamp.fromDate(expiryDate),
      adminId: adminUid,
      adminEmail: callerEmail || '',
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      startDate,
      expiryDate,
      durationDays,
    };
  });

  logger.info(`✅ Admin (${adminUid}) approved & activated subscription for Provider: ${providerId} (Order: ${orderId}) until ${result.expiryDate.toISOString()}`);

  return {
    success: true,
    message: 'Subscription successfully approved and activated.',
    startDate: result.startDate.toISOString(),
    expiryDate: result.expiryDate.toISOString(),
    durationDays: result.durationDays,
  };
});

/**
 * 7b. ADMIN REJECT SUBSCRIPTION PAYMENT REQUEST
 * Callable Cloud Function: Verifies admin identity, safely marks payment and subscription as rejected,
 * ensures subscription is NOT active, preserves any ongoing unexpired subscription for renewals,
 * records reason and timestamp, and writes immutable audit log.
 */
exports.adminRejectSubscription = onCall({ cors: true }, async (request) => {
  const { uid: adminUid, email: callerEmail } = await verifyActiveAdmin(request);

  const { providerId, orderId, reason } = request.data || {};
  if (!providerId || !orderId) {
    throw new HttpsError('invalid-argument', 'providerId and orderId are required.');
  }

  const rejectionReason = (typeof reason === 'string' && reason.trim().length > 0)
    ? reason.trim()
    : 'सब्सक्रिप्शन भुगतान एडमिन द्वारा अस्वीकृत किया गया (Rejected by Administrator).';

  const providerRef = db.collection('providers').doc(providerId);
  const paymentRef = db.collection('payments').doc(orderId);
  const subRef = db.collection('subscriptions').doc(`sub_${orderId}`);
  const auditRef = db.collection('audit_logs').doc();

  await db.runTransaction(async (transaction) => {
    const [providerDoc, paymentDoc] = await Promise.all([
      transaction.get(providerRef),
      transaction.get(paymentRef),
    ]);

    if (!providerDoc.exists) {
      throw new HttpsError('not-found', 'Provider profile not found.');
    }
    const pData = providerDoc.data() || {};

    if (!paymentDoc.exists) {
      throw new HttpsError('not-found', `Payment record for order ${orderId} not found.`);
    }
    const payData = paymentDoc.data() || {};

    // Ensure payment belongs to provider
    if (payData.providerId && payData.providerId !== providerId) {
      throw new HttpsError('permission-denied', 'Payment order does not belong to the specified provider.');
    }

    // Guard: Cannot reject an already active approved subscription
    if (payData.adminApprovalStatus === 'approved') {
      throw new HttpsError('failed-precondition', 'Cannot reject an already approved and activated subscription payment.');
    }

    // Idempotency: If already rejected, do nothing
    if (payData.adminApprovalStatus === 'rejected') {
      return;
    }

    // 1. Update Payment Record
    transaction.set(
      paymentRef,
      {
        adminApprovalStatus: 'rejected',
        rejectedAt: admin.firestore.FieldValue.serverTimestamp(),
        rejectedBy: adminUid,
        rejectionReason: rejectionReason,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    // 2. Update Subscription History Record
    transaction.set(
      subRef,
      {
        status: 'rejected',
        approvalStatus: 'rejected',
        rejectedAt: admin.firestore.FieldValue.serverTimestamp(),
        rejectedBy: adminUid,
        rejectionReason: rejectionReason,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    // 3. Update Provider Profile: Ensure subscription is NOT active unless they have an ongoing valid unexpired approved subscription (renewal rejected)
    const providerUpdate = {
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    const isCurrentlyActiveApproved = pData.isSubscriptionActive === true &&
      pData.subscriptionApprovalStatus === 'approved' &&
      pData.subscriptionExpiry;

    let hasUnexpired = false;
    if (isCurrentlyActiveApproved) {
      const expDate = pData.subscriptionExpiry.toDate
        ? pData.subscriptionExpiry.toDate()
        : new Date(pData.subscriptionExpiry);
      hasUnexpired = expDate > new Date();
    }

    if (hasUnexpired) {
      // Preserve current active subscription; record that renewal attempt was rejected
      providerUpdate.renewalStatus = 'rejected';
      providerUpdate.renewalRejectedOrderId = orderId;
      providerUpdate.renewalRejectedReason = rejectionReason;
    } else {
      // New subscription or already-inactive provider: strictly inactive
      providerUpdate.isSubscriptionActive = false;
      providerUpdate.subscriptionApprovalStatus = 'rejected';
      providerUpdate.subscriptionRejectionReason = rejectionReason;
    }

    transaction.update(providerRef, providerUpdate);

    // 4. Record Immutable Audit Log
    transaction.set(auditRef, {
      action: 'SUBSCRIPTION_REJECTED',
      providerId: providerId,
      providerName: pData.fullName || pData.businessName || payData.providerName || '',
      orderId: orderId,
      paymentId: payData.paymentId || payData.razorpayPaymentId || '',
      amount: payData.amount !== undefined ? Number(payData.amount) : 0,
      adminId: adminUid,
      adminEmail: callerEmail || '',
      reason: rejectionReason,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  logger.info(`🚫 Admin (${adminUid}) rejected subscription payment for Provider: ${providerId} (Order: ${orderId}). Reason: ${rejectionReason}`);

  return {
    success: true,
    message: 'Subscription payment request successfully rejected.',
    orderId,
    providerId,
  };
});

/**
 * 7B. ADMIN APPROVE PROVIDER PROFILE (Server-side Authorized)
 * Callable Cloud Function: Authoritatively approves provider KYC & profile.
 */
exports.adminApproveProvider = onCall({ cors: true }, async (request) => {
  const { uid: adminUid, email: callerEmail } = await verifyActiveAdmin(request);

  const { providerId } = request.data || {};
  if (!providerId) {
    throw new HttpsError('invalid-argument', 'providerId is required.');
  }

  const providerRef = db.collection('providers').doc(providerId);
  const providerDoc = await providerRef.get();
  if (!providerDoc.exists) {
    throw new HttpsError('not-found', 'Provider profile not found.');
  }

  const pData = providerDoc.data() || {};
  const catId = (pData.approvedCategoryId || pData.primaryCategoryId || pData.categoryId || pData.selectedCategoryId || '').toString().trim();

  let isCategoryPremium = false;
  if (catId) {
    try {
      const premCatDoc = await db.collection('premium_categories').doc(catId).get();
      if (premCatDoc && premCatDoc.exists && premCatDoc.data()?.isActive !== false) {
        isCategoryPremium = true;
      } else {
        const premCatQuery = await db.collection('premium_categories')
          .where('categoryId', '==', catId)
          .limit(1)
          .get();
        if (premCatQuery && !premCatQuery.empty && premCatQuery.docs[0].data()?.isActive !== false) {
          isCategoryPremium = true;
        }
      }
    } catch (catErr) {
      logger.warn(`Error resolving category ${catId} in adminApproveProvider:`, catErr);
    }
  }

  const updatePayload = {
    status: 'approved',
    kycStatus: 'approved',
    verificationStatus: 'approved',
    isVerified: true,
    isPremiumCategoryEligible: isCategoryPremium,
    isPremiumCategory: isCategoryPremium,
    categoryType: isCategoryPremium ? 'premium' : 'general',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  // If provider already has an active, paid subscription under a premium plan, align isPremiumEligible
  // NOTE: Do NOT automatically activate subscription or bypass payment verification.
  if (isCategoryPremium && pData.paymentVerified === true && pData.isSubscriptionActive === true) {
    updatePayload.isPremiumEligible = true;
  }

  await providerRef.update(updatePayload);

  // Audit log
  try {
    await db.collection('audit_logs').add({
      action: 'ADMIN_APPROVE_PROVIDER_PROFILE',
      adminUid: adminUid,
      adminEmail: callerEmail || 'admin',
      targetProviderId: providerId,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (_) {}

  logger.info(`✅ Admin (${adminUid}) approved Provider Profile: ${providerId}`);

  return { success: true, providerId, status: 'approved' };
});

/**
 * 8. ADMIN TOGGLE PROVIDER ACTIVE / INACTIVE STATUS
 * Callable Cloud Function: Enables or disables provider account.
 * Deactivated providers are hidden from customer app listings and leads.
 */
exports.adminToggleProviderStatus = onCall({ cors: true }, async (request) => {
  const { uid: adminUid, email: callerEmail } = await verifyActiveAdmin(request);

  const { providerId, isActive, reason } = request.data || {};
  if (!providerId || typeof isActive !== 'boolean') {
    throw new HttpsError('invalid-argument', 'providerId and boolean isActive are required.');
  }

  const providerRef = db.collection('providers').doc(providerId);
  const providerDoc = await providerRef.get();
  if (!providerDoc.exists) {
    throw new HttpsError('not-found', 'Provider profile not found.');
  }

  const batch = db.batch();
  const updateData = {
    isActive: isActive,
    statusUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    statusUpdatedBy: adminUid,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  if (!isActive) {
    updateData.deactivationReason = reason || 'खाता एडमिन द्वारा निष्क्रिय किया गया है (Deactivated by Administrator).';
    updateData.isAvailable = false; // Force offline when deactivated
  } else {
    updateData.deactivationReason = admin.firestore.FieldValue.delete();
  }

  batch.update(providerRef, updateData);

  const auditRef = db.collection('audit_logs').doc();
  batch.set(auditRef, {
    action: isActive ? 'PROVIDER_ACTIVATED' : 'PROVIDER_DEACTIVATED',
    providerId: providerId,
    providerName: providerDoc.data()?.fullName || providerDoc.data()?.businessName || '',
    reason: reason || '',
    adminId: adminUid,
    adminEmail: callerEmail || '',
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });

  await batch.commit();

  logger.info(`✅ Admin (${adminUid}) set isActive=${isActive} for Provider: ${providerId} (Reason: ${reason || 'N/A'})`);

  return {
    success: true,
    isActive: isActive,
    message: isActive ? 'Provider account activated successfully.' : 'Provider account deactivated successfully.',
  };
});

/**
 * 9. ADMIN SOFT-DELETE PROVIDER
 * Callable Cloud Function: Safely deactivates provider, sets isDeleted=true,
 * revokes authentication access, while strictly preserving payment and subscription history.
 */
exports.adminSoftDeleteProvider = onCall({ cors: true }, async (request) => {
  const { uid: adminUid, email: callerEmail } = await verifyActiveAdmin(request);

  const { providerId, reason } = request.data || {};
  if (!providerId) {
    throw new HttpsError('invalid-argument', 'providerId is required.');
  }

  const providerRef = db.collection('providers').doc(providerId);
  const providerDoc = await providerRef.get();
  if (!providerDoc.exists) {
    throw new HttpsError('not-found', 'Provider profile not found.');
  }

  const batch = db.batch();
  batch.update(providerRef, {
    isDeleted: true,
    isActive: false,
    isAvailable: false,
    isSubscriptionActive: false,
    deletedAt: admin.firestore.FieldValue.serverTimestamp(),
    deletedBy: adminUid,
    deletionReason: reason || 'खाता एडमिन द्वारा हटाया गया (Deleted by Administrator).',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  const auditRef = db.collection('audit_logs').doc();
  batch.set(auditRef, {
    action: 'PROVIDER_SOFT_DELETED',
    providerId: providerId,
    providerName: providerDoc.data()?.fullName || providerDoc.data()?.businessName || '',
    phoneNumber: providerDoc.data()?.phoneNumber || providerDoc.data()?.phone || '',
    reason: reason || '',
    adminId: adminUid,
    adminEmail: callerEmail || '',
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });

  await batch.commit();

  // Revoke / disable Firebase Auth user account
  try {
    await admin.auth().updateUser(providerId, { disabled: true });
    logger.info(`🔒 Firebase Auth disabled for deleted Provider: ${providerId}`);
  } catch (authErr) {
    logger.warn(`Could not disable Firebase Auth for provider ${providerId}:`, authErr);
  }

  logger.info(`🗑️ Provider (${providerId}) soft-deleted by Admin (${adminUid}). Historical payments preserved.`);

  return {
    success: true,
    message: 'Provider safely soft-deleted. Access revoked while preserving transaction history.',
  };
});

/**
 * Callable Cloud Function: adminPermanentDeleteProvider
 * Region: asia-south1 | Authentication: Strict Super Admin Only
 *
 * Implements resilient, idempotent, multi-stage permanent deletion of a provider:
 * 1. Server-side role verification via `admin_users` collection
 * 2. Durable task tracking in `/admin_deletion_tasks/{providerId}` for resume/recovery
 * 3. Storage files enumeration & deletion (providers/, kyc_documents/, profile_images/)
 * 4. Provider-owned operational data deletion (custom service apps, category requests, stats, complaints, notifs, favourites)
 * 5. Shared customer records integrity preservation (bookings & reviews anonymized, not deleted)
 * 6. Financial records retention & data minimization (Razorpay order/payment audit data preserved, PII redacted)
 * 7. Core Firestore provider document recursive deletion
 * 8. Firebase Auth account permanent deletion (enables fresh registration with same phone/email)
 * 9. Immutable audit log generation in `/audit_logs`
 */
exports.adminPermanentDeleteProvider = onCall({ cors: true }, async (request) => {
  // 1. Strict Server-Side Role Verification via `admin_users` collection (Super Admin required)
  const { uid: callerUid, email: callerEmail } = await verifyActiveAdmin(request, { requireSuperAdmin: true });

  const { providerId, confirmationText, reason } = request.data || {};
  if (!providerId || typeof providerId !== 'string') {
    throw new HttpsError('invalid-argument', 'Valid providerId is required.');
  }

  if (confirmationText !== 'DELETE') {
    throw new HttpsError('invalid-argument', 'Invalid confirmation text. Must type DELETE exactly.');
  }

  const providerRef = db.collection('providers').doc(providerId);
  const providerDoc = await providerRef.get();

  // Check existing durable task for idempotency
  const taskRef = db.collection('admin_deletion_tasks').doc(providerId);
  const taskDoc = await taskRef.get();

  if (!providerDoc.exists) {
    if (taskDoc.exists && taskDoc.data()?.status === 'completed') {
      return {
        success: true,
        message: 'Provider was already permanently deleted.',
        isIdempotent: true,
        executionStatus: taskDoc.data()?.stepProgress
      };
    }
    throw new HttpsError('not-found', 'Provider profile not found in system.');
  }

  const pData = providerDoc.data() || {};
  let task = taskDoc.exists ? taskDoc.data() : {
    providerId,
    providerName: pData.fullName || pData.businessName || '',
    phone: pData.phoneNumber || pData.phone || '',
    email: pData.email || '',
    adminUid: callerUid,
    adminEmail: callerEmail,
    reason: reason || 'Administrative permanent removal requested.',
    status: 'in_progress',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    stepProgress: {
      storage_cleaned: false,
      operational_cleaned: false,
      shared_records_anonymized: false,
      financial_audit_retained: false,
      provider_doc_deleted: false,
      auth_account_deleted: false,
      audit_logged: false
    },
    attempts: 0
  };

  task.attempts = (task.attempts || 0) + 1;
  task.updatedAt = admin.firestore.FieldValue.serverTimestamp();
  task.status = 'in_progress';
  await taskRef.set(task, { merge: true });

  // STEP A: Storage Enumeration and Cleanup
  if (!task.stepProgress.storage_cleaned) {
    try {
      if (admin.storage && typeof admin.storage === 'function') {
        let bucket = null;
        try {
          bucket = admin.storage().bucket();
        } catch (bErr) {
          const fallbackName = process.env.FIREBASE_STORAGE_BUCKET || 'jamui-services.appspot.com';
          try {
            bucket = admin.storage().bucket(fallbackName);
          } catch (bErr2) {
            logger.warn('Storage bucket lookup fallback note:', bErr2.message);
          }
        }
        if (bucket && typeof bucket.deleteFiles === 'function') {
          const prefixes = [
            `providers/${providerId}/`,
            `kyc_documents/${providerId}/`,
            `profile_images/${providerId}/`
          ];
          for (const prefix of prefixes) {
            try {
              await bucket.deleteFiles({ prefix, force: true });
            } catch (storageErr) {
              logger.warn(`Storage prefix cleanup note [${prefix}]:`, storageErr.message);
            }
          }
        }
      }
      task.stepProgress.storage_cleaned = true;
      await taskRef.set({ stepProgress: task.stepProgress, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
    } catch (err) {
      task.status = 'partial_failure';
      task.lastError = `Storage cleanup failed: ${err.message}`;
      await taskRef.set(task, { merge: true });
      throw new HttpsError('internal', `Storage cleanup failed: ${err.message}`);
    }
  }

  // STEP B: Operational Data Cleanup (Provider-owned records only)
  if (!task.stepProgress.operational_cleaned) {
    try {
      const operationalCols = [
        'custom_service_applications',
        'category_requests',
        'complaints',
        'notifications',
        'favourites'
      ];
      for (const col of operationalCols) {
        const field = col === 'notifications' ? 'userId' : 'providerId';
        const snap = await db.collection(col).where(field, '==', providerId).get();
        if (!snap.empty) {
          const batch = db.batch();
          snap.docs.forEach(d => batch.delete(d.ref));
          await batch.commit();
        }
      }
      try {
        await db.collection('provider_stats').doc(providerId).delete();
      } catch (_) {}

      task.stepProgress.operational_cleaned = true;
      await taskRef.set({ stepProgress: task.stepProgress, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
    } catch (err) {
      task.status = 'partial_failure';
      task.lastError = `Operational data cleanup failed: ${err.message}`;
      await taskRef.set(task, { merge: true });
      throw new HttpsError('internal', `Operational cleanup failed: ${err.message}`);
    }
  }

  // STEP C: Shared Customer Records Anonymization (Customer History Protected!)
  if (!task.stepProgress.shared_records_anonymized) {
    try {
      const bookingsSnap = await db.collection('bookings').where('providerId', '==', providerId).get();
      if (!bookingsSnap.empty) {
        const batch = db.batch();
        bookingsSnap.docs.forEach(d => {
          batch.update(d.ref, {
            providerDeleted: true,
            providerName: '[Deleted Provider]',
            providerPhone: null,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          });
        });
        await batch.commit();
      }

      const reviewsSnap = await db.collection('reviews').where('providerId', '==', providerId).get();
      if (!reviewsSnap.empty) {
        const batch = db.batch();
        reviewsSnap.docs.forEach(d => {
          batch.update(d.ref, {
            providerDeleted: true,
            isProviderActive: false,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          });
        });
        await batch.commit();
      }

      task.stepProgress.shared_records_anonymized = true;
      await taskRef.set({ stepProgress: task.stepProgress, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
    } catch (err) {
      task.status = 'partial_failure';
      task.lastError = `Shared records anonymization failed: ${err.message}`;
      await taskRef.set(task, { merge: true });
      throw new HttpsError('internal', `Shared records anonymization failed: ${err.message}`);
    }
  }

  // STEP D: Financial Records Retention & PII Data Minimization
  if (!task.stepProgress.financial_audit_retained) {
    try {
      const paymentsSnap = await db.collection('payments').where('providerId', '==', providerId).get();
      if (!paymentsSnap.empty) {
        const batch = db.batch();
        paymentsSnap.docs.forEach(d => {
          batch.update(d.ref, {
            providerAccountDeleted: true,
            providerName: '[DELETED_ACCOUNT]',
            userName: '[DELETED_ACCOUNT]',
            phoneNumber: null,
            phone: null,
            email: null,
            dataMinimizationAppliedAt: admin.firestore.FieldValue.serverTimestamp()
          });
        });
        await batch.commit();
      }

      const subsSnap = await db.collection('subscriptions').where('providerId', '==', providerId).get();
      if (!subsSnap.empty) {
        const batch = db.batch();
        subsSnap.docs.forEach(d => {
          batch.update(d.ref, {
            providerAccountDeleted: true,
            isActive: false,
            isSubscriptionActive: false,
            providerName: '[DELETED_ACCOUNT]',
            dataMinimizationAppliedAt: admin.firestore.FieldValue.serverTimestamp()
          });
        });
        await batch.commit();
      }

      task.stepProgress.financial_audit_retained = true;
      await taskRef.set({ stepProgress: task.stepProgress, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
    } catch (err) {
      task.status = 'partial_failure';
      task.lastError = `Financial audit preservation failed: ${err.message}`;
      await taskRef.set(task, { merge: true });
      throw new HttpsError('internal', `Financial audit preservation failed: ${err.message}`);
    }
  }

  // STEP E: Provider Firestore Document & Subcollections Deletion
  if (!task.stepProgress.provider_doc_deleted) {
    try {
      if (typeof db.recursiveDelete === 'function') {
        await db.recursiveDelete(providerRef);
      } else {
        await providerRef.delete();
      }
      task.stepProgress.provider_doc_deleted = true;
      await taskRef.set({ stepProgress: task.stepProgress, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
    } catch (err) {
      task.status = 'partial_failure';
      task.lastError = `Provider document deletion failed: ${err.message}`;
      await taskRef.set(task, { merge: true });
      throw new HttpsError('internal', `Provider document deletion failed: ${err.message}`);
    }
  }

  // STEP F: Firebase Auth Account Deletion (Frees Phone & Email for Fresh Registration)
  if (!task.stepProgress.auth_account_deleted) {
    try {
      await admin.auth().deleteUser(providerId);
      task.stepProgress.auth_account_deleted = true;
      await taskRef.set({ stepProgress: task.stepProgress, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
    } catch (authErr) {
      if (authErr.code === 'auth/user-not-found') {
        task.stepProgress.auth_account_deleted = true;
        await taskRef.set({ stepProgress: task.stepProgress, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
      } else {
        task.status = 'partial_failure';
        task.lastError = `Auth account deletion failed: ${authErr.message}`;
        await taskRef.set(task, { merge: true });
        throw new HttpsError('internal', `Auth account deletion failed: ${authErr.message}`);
      }
    }
  }

  // STEP G: Immutable Audit Trail
  if (!task.stepProgress.audit_logged) {
    try {
      await db.collection('audit_logs').add({
        action: 'PROVIDER_PERMANENTLY_DELETED',
        providerId,
        providerName: task.providerName,
        phone: task.phone,
        email: task.email,
        reason: task.reason,
        deletedByAdminId: callerUid,
        deletedByAdminEmail: callerEmail,
        durableJobId: providerId,
        stepProgress: task.stepProgress,
        timestamp: admin.firestore.FieldValue.serverTimestamp()
      });
      task.stepProgress.audit_logged = true;
      task.status = 'completed';
      await taskRef.set({ status: 'completed', stepProgress: task.stepProgress, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
    } catch (auditErr) {
      logger.warn(`Audit log write note for deleted provider ${providerId}:`, auditErr.message);
    }
  }

  logger.info(`🗑️ Provider (${providerId}) permanently deleted by Super Admin (${callerUid}).`);
  return {
    success: true,
    message: 'Provider permanently deleted. Storage, Auth, and Operational records cleaned.',
    executionStatus: task.stepProgress
  };
});

/**
 * 15. LINK PROVIDER EMAIL & PASSWORD
 * Authoritative Server-Side Linking: Securely links email/password credentials to an authenticated
 * phone-verified provider account using Firebase Admin SDK.
 * Bypasses client-side Email Enumeration Protection restrictions (operation-not-allowed)
 * while preserving single UID, verified mobile number, and existing provider profile.
 */
exports.linkProviderEmailPassword = onCall({ cors: true }, async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError('unauthenticated', 'प्रदाता क्रेडेंशियल लिंक करने के लिए ऑथेंटिकेशन (Authentication) अनिवार्य है।');
  }

  const uid = request.auth.uid;
  const { email, password } = request.data || {};

  if (!email || typeof email !== 'string' || !email.includes('@')) {
    throw new HttpsError('invalid-argument', 'कृपया एक वैध ईमेल पता (Valid Email Address) प्रदान करें।');
  }

  if (!password || typeof password !== 'string' || password.length < 6) {
    throw new HttpsError('invalid-argument', 'पासवर्ड कम से कम 6 अक्षरों का होना चाहिए।');
  }

  const cleanEmail = email.trim().toLowerCase();

  try {
    // 1. Verify caller has a phone number registered or exists in providers collection
    const authUser = await admin.auth().getUser(uid);
    const hasPhone = Boolean(authUser.phoneNumber || (authUser.providerUserInfo && authUser.providerUserInfo.some(p => p.providerId === 'phone')));
    
    if (!hasPhone) {
      throw new HttpsError('failed-precondition', 'ईमेल और पासवर्ड लिंक करने से पहले मोबाइल नंबर का सत्यापन (OTP) अनिवार्य है।');
    }

    // 2. Prevent colliding with a different user's existing email
    try {
      const existingUser = await admin.auth().getUserByEmail(cleanEmail);
      if (existingUser && existingUser.uid !== uid) {
        throw new HttpsError('already-exists', 'यह ईमेल पहले से किसी अन्य खाते में पंजीकृत है। कृपया दूसरा ईमेल चुनें।');
      }
    } catch (lookupErr) {
      if (lookupErr.code !== 'auth/user-not-found') {
        throw lookupErr;
      }
    }

    // 3. Update Auth record with email and password via Admin SDK
    await admin.auth().updateUser(uid, {
      email: cleanEmail,
      password: password,
      emailVerified: false,
    });

    // 4. Update Firestore provider profile email if doc exists
    try {
      const provRef = db.collection('providers').doc(uid);
      const provDoc = await provRef.get();
      if (provDoc.exists) {
        await provRef.set({
          email: cleanEmail,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
      }
    } catch (fsErr) {
      logger.warn(`Could not sync email to Firestore providers/${uid}:`, fsErr);
    }

    logger.info(`✅ Successfully linked email/password for Provider: ${uid} (${cleanEmail})`);

    return {
      success: true,
      uid: uid,
      email: cleanEmail,
      message: 'ईमेल और पासवर्ड सफलतापूर्वक लिंक हो गया।',
    };
  } catch (err) {
    if (err instanceof HttpsError) {
      throw err;
    }
    logger.error(`Error linking email/password for provider ${uid}:`, err);
    throw new HttpsError('internal', err.message || 'क्रेडेंशियल लिंक करने में विफलता।');
  }
});

// ============================================================================
// CLOUDFLARE R2 SECURE PRESIGNED UPLOAD INFRASTRUCTURE (PHASE 1B)
// ============================================================================

const { 
  validateAndGenerateUploadKey, 
  generateR2PresignedPutUrl, 
  generateR2PresignedGetUrl,
  verifyAndEnforceObjectLimits,
  handleStorageObjectDelete,
  reconcileProviderStorageUsage,
  resolveProviderStoragePlanLimits,
  resolveBucketForFolder,
  resolveBucketForObjectKey,
  DEFAULT_PUBLIC_BUCKET,
  DEFAULT_PRIVATE_BUCKET
} = require('./r2_storage_upload_handler');
const R2_SECRETS = ['R2_ACCOUNT_ID', 'R2_ACCESS_KEY_ID', 'R2_SECRET_ACCESS_KEY', 'R2_BUCKET_NAME', 'R2_PRIVATE_BUCKET_NAME'];

const R2_ALLOWED_ORIGINS = [
  'https://jamui-admin.web.app',
  'https://jamui-admin.firebaseapp.com',
  'https://jamui-provider.web.app',
  'https://jamui-provider.firebaseapp.com',
  'https://jamui-services.web.app',
  'https://jamui-services.firebaseapp.com'
];

/**
 * Cloud Function: getStorageUploadUrl
 * Generates an authenticated, short-lived presigned PUT URL for Cloudflare R2.
 * Validates caller identity, role ownership, MIME types, and file size server-side.
 * Automatically routes private documents to private R2 bucket and public images to public bucket.
 */
exports.getStorageUploadUrl = onCall({ cors: true, secrets: R2_SECRETS }, async (request) => {
  try {
    const validated = await validateAndGenerateUploadKey({
      auth: request.auth,
      data: request.data,
      verifyActiveAdminFn: verifyActiveAdmin,
      db: db
    });

    const accountId = process.env.R2_ACCOUNT_ID;
    const accessKeyId = process.env.R2_ACCESS_KEY_ID;
    const secretAccessKey = process.env.R2_SECRET_ACCESS_KEY;
    const publicBucket = process.env.R2_BUCKET_NAME || DEFAULT_PUBLIC_BUCKET;
    const privateBucket = process.env.R2_PRIVATE_BUCKET_NAME || DEFAULT_PRIVATE_BUCKET;
    const bucketName = validated.isPrivate ? privateBucket : publicBucket;

    const presigned = generateR2PresignedPutUrl({
      accountId,
      accessKeyId,
      secretAccessKey,
      bucketName,
      objectKey: validated.objectKey,
      mimeType: validated.mimeType,
      fileSize: validated.fileSize,
      expiresInSeconds: 600
    });

    return {
      success: true,
      uploadUrl: presigned.uploadUrl,
      objectKey: presigned.objectKey,
      expiresInSeconds: presigned.expiresInSeconds,
      requiredHeaders: presigned.requiredHeaders,
      bucket: bucketName,
      isPrivate: validated.isPrivate,
      reservationId: validated.reservationId || null,
      resolvedLimits: validated.resolvedLimits || null
    };
  } catch (err) {
    if (err.code && ['unauthenticated', 'permission-denied', 'invalid-argument', 'failed-precondition', 'not-found', 'unavailable', 'resource-exhausted'].includes(err.code)) {
      throw new HttpsError(err.code === 'resource-exhausted' ? 'resource-exhausted' : err.code, err.message);
    }
    logger.error('Error generating R2 upload URL:', err);
    throw new HttpsError('internal', err.message || 'Failed to generate upload URL.');
  }
});

/**
 * Cloud Function: getSecureDocumentViewUrl
 * Generates an authenticated, short-lived presigned GET URL for viewing private documents (e.g. certificates, KYC).
 * Validates caller authorization (provider can view own documents, admin can view any).
 * Targets the private R2 bucket with strict 10-minute expiry.
 */
exports.getSecureDocumentViewUrl = onCall({ cors: true, secrets: R2_SECRETS }, async (request) => {
  try {
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError('unauthenticated', 'User must be authenticated to view secure documents.');
    }

    const callerUid = request.auth.uid;
    const rawKey = (request.data?.objectKey || '').toString().trim();
    if (!rawKey || rawKey.includes('..')) {
      throw new HttpsError('invalid-argument', 'A valid object key is required.');
    }

    // Authorization check:
    // If document belongs to a provider ('providers/{providerId}/...'), verify ownership or admin role
    if (rawKey.startsWith('providers/')) {
      const parts = rawKey.split('/');
      const docOwnerUid = parts[1];
      if (docOwnerUid !== callerUid) {
        // Must be an active administrator
        await verifyActiveAdmin({ auth: request.auth });
      }
    } else {
      // Any other non-provider private document strictly requires administrator role
      await verifyActiveAdmin({ auth: request.auth });
    }

    const accountId = process.env.R2_ACCOUNT_ID;
    const accessKeyId = process.env.R2_ACCESS_KEY_ID;
    const secretAccessKey = process.env.R2_SECRET_ACCESS_KEY;
    const publicBucket = process.env.R2_BUCKET_NAME || DEFAULT_PUBLIC_BUCKET;
    const privateBucket = process.env.R2_PRIVATE_BUCKET_NAME || DEFAULT_PRIVATE_BUCKET;
    const bucketName = resolveBucketForObjectKey(rawKey, publicBucket, privateBucket);

    const presigned = generateR2PresignedGetUrl({
      accountId,
      accessKeyId,
      secretAccessKey,
      bucketName,
      objectKey: rawKey,
      expiresInSeconds: 600
    });

    return {
      success: true,
      viewUrl: presigned.viewUrl,
      objectKey: presigned.objectKey,
      expiresInSeconds: presigned.expiresInSeconds,
      bucket: bucketName
    };
  } catch (err) {
    if (err.code && ['unauthenticated', 'permission-denied', 'invalid-argument', 'failed-precondition', 'not-found', 'unavailable'].includes(err.code)) {
      throw new HttpsError(err.code, err.message);
    }
    logger.error('Error generating secure view URL:', err);
    throw new HttpsError('internal', err.message || 'Failed to generate secure document URL.');
  }
});

/**
 * Cloud Function: verifyUploadedStorageObject
 * Authoritative server-side verification:
 * Checks actual object existence, verifies file size <= 8MB on R2, and checks MIME type.
 * If file is oversized or invalid, permanently deletes it from R2 before it can be referenced.
 * Atomically updates provider's storage quota and records verified media in Firestore.
 */
exports.verifyUploadedStorageObject = onCall({ cors: true, secrets: R2_SECRETS }, async (request) => {
  try {
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError('unauthenticated', 'User must be authenticated to verify storage objects.');
    }

    const callerUid = request.auth.uid;
    const rawKey = (request.data?.objectKey || '').toString().trim();
    if (!rawKey || rawKey.includes('..')) {
      throw new HttpsError('invalid-argument', 'A valid object key is required.');
    }

    // Ownership check: Caller must own the object or be an active admin
    let providerOwnerId = null;
    if (rawKey.startsWith('providers/')) {
      const parts = rawKey.split('/');
      providerOwnerId = parts[1];
      if (providerOwnerId !== callerUid) {
        await verifyActiveAdmin({ auth: request.auth });
      }
    } else if (rawKey.startsWith('reviews/')) {
      const parts = rawKey.split('/');
      const reviewOwnerUid = parts[1];
      if (reviewOwnerUid !== callerUid) {
        await verifyActiveAdmin({ auth: request.auth });
      }
    } else {
      await verifyActiveAdmin({ auth: request.auth });
    }

    const accountId = process.env.R2_ACCOUNT_ID;
    const accessKeyId = process.env.R2_ACCESS_KEY_ID;
    const secretAccessKey = process.env.R2_SECRET_ACCESS_KEY;
    const publicBucket = process.env.R2_BUCKET_NAME || DEFAULT_PUBLIC_BUCKET;
    const privateBucket = process.env.R2_PRIVATE_BUCKET_NAME || DEFAULT_PRIVATE_BUCKET;
    const bucketName = resolveBucketForObjectKey(rawKey, publicBucket, privateBucket);

    const verified = await verifyAndEnforceObjectLimits({
      accountId,
      accessKeyId,
      secretAccessKey,
      bucketName,
      objectKey: rawKey
    });

    // If this object belongs to a provider, atomically record media and commit storageUsage
    let updatedStorageUsage = null;
    if (providerOwnerId) {
      const parts = rawKey.split('/');
      const folder = parts[2] || 'general';
      const keyHash = crypto.createHash('sha256').update(rawKey).digest('hex').substring(0, 32);

      const provRef = db.collection('providers').doc(providerOwnerId);
      const mediaRef = provRef.collection('storage_objects').doc(keyHash);

      await db.runTransaction(async (transaction) => {
        const provSnap = await transaction.get(provRef);
        if (!provSnap.exists) return;

        const pData = provSnap.data() || {};
        const usage = pData.storageUsage || {};
        const oldBytes = Number(usage.totalBytesUsed || 0);
        const oldCount = Number(usage.totalImagesCount || 0);
        const oldReserved = Number(usage.reservedBytes || 0);

        // Check if already verified to prevent duplicate quota increment
        const mediaSnap = await transaction.get(mediaRef);
        const alreadyCounted = mediaSnap.exists && mediaSnap.data()?.status === 'active';

        if (!alreadyCounted) {
          const newBytes = oldBytes + verified.actualSizeBytes;
          const newCount = oldCount + 1;
          const newReserved = Math.max(0, oldReserved - verified.actualSizeBytes);

          updatedStorageUsage = {
            ...usage,
            totalBytesUsed: newBytes,
            totalImagesCount: newCount,
            reservedBytes: newReserved,
            lastUpdated: admin.firestore.FieldValue.serverTimestamp()
          };

          transaction.update(provRef, { storageUsage: updatedStorageUsage });

          transaction.set(mediaRef, {
            objectKey: verified.objectKey,
            sizeBytes: verified.actualSizeBytes,
            mimeType: verified.mimeType,
            bucket: verified.bucket,
            folder: folder,
            status: 'active',
            uploadedAt: admin.firestore.FieldValue.serverTimestamp()
          });
        } else {
          updatedStorageUsage = usage;
        }
      });
    }

    return {
      success: true,
      verified: true,
      objectKey: verified.objectKey,
      actualSizeBytes: verified.actualSizeBytes,
      mimeType: verified.mimeType,
      bucket: verified.bucket,
      storageUsage: updatedStorageUsage
    };
  } catch (err) {
    if (err.code && ['unauthenticated', 'permission-denied', 'invalid-argument', 'failed-precondition', 'not-found', 'unavailable'].includes(err.code)) {
      throw new HttpsError(err.code, err.message);
    }
    logger.error('Error verifying storage object:', err);
    throw new HttpsError('internal', err.message || 'Failed to verify uploaded object.');
  }
});

/**
 * Cloud Function: deleteStorageObject
 * Authoritative server-side deletion of an R2 storage object.
 * Strictly verifies ownership (or active admin), permanently deletes from R2,
 * and atomically decrements provider storage usage upon verified deletion.
 */
exports.deleteStorageObject = onCall({ cors: true, secrets: R2_SECRETS }, async (request) => {
  try {
    const accountId = process.env.R2_ACCOUNT_ID;
    const accessKeyId = process.env.R2_ACCESS_KEY_ID;
    const secretAccessKey = process.env.R2_SECRET_ACCESS_KEY;
    const publicBucket = process.env.R2_BUCKET_NAME || DEFAULT_PUBLIC_BUCKET;
    const privateBucket = process.env.R2_PRIVATE_BUCKET_NAME || DEFAULT_PRIVATE_BUCKET;

    const result = await handleStorageObjectDelete({
      auth: request.auth,
      objectKey: request.data?.objectKey,
      verifyActiveAdminFn: verifyActiveAdmin,
      db: db,
      accountId,
      accessKeyId,
      secretAccessKey,
      publicBucket,
      privateBucket
    });

    return result;
  } catch (err) {
    if (err.code && ['unauthenticated', 'permission-denied', 'invalid-argument', 'failed-precondition', 'not-found', 'unavailable'].includes(err.code)) {
      throw new HttpsError(err.code, err.message);
    }
    logger.error('Error deleting storage object:', err);
    throw new HttpsError('internal', err.message || 'Failed to delete storage object.');
  }
});

/**
 * Cloud Function: reconcileProviderStorage
 * Reconciles provider's actual R2 storage usage against active media tracking documents.
 * Can be called by the provider themselves or an authorized administrator.
 */
exports.reconcileProviderStorage = onCall({ cors: true, secrets: R2_SECRETS }, async (request) => {
  try {
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError('unauthenticated', 'Authentication required.');
    }

    const callerUid = request.auth.uid;
    const targetProviderId = (request.data?.providerId || callerUid).toString().trim();

    if (targetProviderId !== callerUid) {
      await verifyActiveAdmin(request);
    }

    const reconciled = await reconcileProviderStorageUsage({ db, providerId: targetProviderId });
    return {
      success: true,
      providerId: targetProviderId,
      storageUsage: reconciled
    };
  } catch (err) {
    if (err.code && ['unauthenticated', 'permission-denied', 'invalid-argument', 'failed-precondition', 'not-found', 'unavailable'].includes(err.code)) {
      throw new HttpsError(err.code, err.message);
    }
    logger.error('Error reconciling provider storage:', err);
    throw new HttpsError('internal', err.message || 'Failed to reconcile storage usage.');
  }
});

// ============================================================================
// DIAMOND CATEGORY (MINI E-COMMERCE) SECURE 2ND GEN CLOUD FUNCTIONS
// ============================================================================

/**
 * Calculates geographic distance in kilometers between two coordinates using Haversine formula.
 */
function calculateHaversineKm(lat1, lon1, lat2, lon2) {
  const R = 6371; // Earth radius in km
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
            Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
            Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

/**
 * Cloud Function: placeDiamondOrder
 * Secure, zero-trust order placement for Diamond Category mini e-commerce.
 * - Authenticates caller.
 * - Idempotency guard prevents duplicate order submissions.
 * - Validates shop existence, active status, approval, and opening hours.
 * - Server-side delivery radius calculation (never trusts client location eligibility).
 * - Authoritatively reads product prices and availability from Firestore (ignores client prices).
 * - Atomically deducts product stock inside a Firestore transaction.
 * - Creates order with initial 'placed' state.
 * - Dispatches FCM notification to shopkeeper without failing transaction if messaging fails.
 */
exports.placeDiamondOrder = onCall({ cors: true }, async (request) => {
  try {
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError('unauthenticated', 'You must be logged in to place an order.');
    }

    const callerUid = request.auth.uid;
    const {
      shopId,
      items,
      deliveryMethod = 'delivery',
      deliveryAddress,
      customerNotes = '',
      idempotencyKey = null
    } = request.data || {};

    if (!shopId || typeof shopId !== 'string') {
      throw new HttpsError('invalid-argument', 'Valid shop ID is required.');
    }

    if (!Array.isArray(items) || items.length === 0) {
      throw new HttpsError('invalid-argument', 'Order must contain at least one product.');
    }

    const validMethods = ['delivery', 'pickup'];
    if (!validMethods.includes(deliveryMethod)) {
      throw new HttpsError('invalid-argument', `Invalid delivery method: ${deliveryMethod}`);
    }

    // 1. Idempotency Check
    if (idempotencyKey && typeof idempotencyKey === 'string' && idempotencyKey.trim().length > 0) {
      const existingQuery = await db.collection('diamond_orders')
        .where('customerId', '==', callerUid)
        .where('idempotencyKey', '==', idempotencyKey.trim())
        .limit(1)
        .get();

      if (!existingQuery.empty) {
        const existingDoc = existingQuery.docs[0];
        const existingData = existingDoc.data();
        logger.info(`[placeDiamondOrder] Idempotent hit: Returning existing order ${existingDoc.id}`);
        return {
          success: true,
          orderId: existingDoc.id,
          orderNumber: existingData.orderNumber,
          totalAmount: existingData.totalAmount,
          isDuplicate: true,
          message: 'Order already placed.'
        };
      }
    }

    // 2. Fetch Shop Details & Validate Operational Status
    const shopRef = db.collection('diamond_shops').doc(shopId.trim());
    const shopDoc = await shopRef.get();

    if (!shopDoc.exists) {
      throw new HttpsError('not-found', 'Shop does not exist.');
    }

    const shopData = shopDoc.data() || {};

    if (shopData.isApproved !== true || shopData.status !== 'approved') {
      throw new HttpsError('failed-precondition', 'This shop is pending approval or not active.');
    }

    if (shopData.isActive === false || shopData.status === 'suspended' || shopData.status === 'blocked') {
      throw new HttpsError('failed-precondition', 'This shop is currently suspended or inactive.');
    }

    if (shopData.isSubscriptionActive !== true) {
      throw new HttpsError('failed-precondition', 'This shop does not have an active subscription.');
    }

    if (shopData.status === 'closed' || shopData.isOpen === false) {
      throw new HttpsError('failed-precondition', 'This shop is currently closed.');
    }

    // 3. Delivery Method Validation & Server-Side Radius Check
    if (deliveryMethod === 'delivery') {
      if (shopData.deliveryEnabled === false) {
        throw new HttpsError('failed-precondition', 'Home delivery is currently disabled for this shop.');
      }

      if (!deliveryAddress || typeof deliveryAddress !== 'object') {
        throw new HttpsError('invalid-argument', 'Delivery address is required for home delivery.');
      }

      const custLat = Number(deliveryAddress.latitude);
      const custLon = Number(deliveryAddress.longitude);
      const shopLat = Number(shopData.latitude);
      const shopLon = Number(shopData.longitude);

      if (!isNaN(custLat) && !isNaN(custLon) && !isNaN(shopLat) && !isNaN(shopLon) && custLat !== 0 && shopLat !== 0) {
        const distanceKm = calculateHaversineKm(custLat, custLon, shopLat, shopLon);
        const maxRadius = Number(shopData.deliveryRadiusKm || 10);
        if (distanceKm > maxRadius) {
          throw new HttpsError('failed-precondition', `Delivery address is ${distanceKm.toFixed(1)} km away, exceeding maximum delivery radius of ${maxRadius} km.`);
        }
      }
    } else if (deliveryMethod === 'pickup') {
      if (shopData.pickupEnabled === false) {
        throw new HttpsError('failed-precondition', 'Store pickup is not offered by this shop.');
      }
    }

    // 4. Sanitize and Validate Items Array Structure
    const sanitizedItems = [];
    for (const item of items) {
      if (!item || !item.productId || typeof item.productId !== 'string') {
        throw new HttpsError('invalid-argument', 'Invalid product entry.');
      }
      const qty = parseInt(item.quantity, 10);
      if (isNaN(qty) || qty <= 0) {
        throw new HttpsError('invalid-argument', `Invalid quantity for product ${item.productId}.`);
      }
      sanitizedItems.push({
        productId: item.productId.trim(),
        quantity: qty
      });
    }

    // 5. Atomic Transaction: Authoritative Price Verification, Stock Check & Deduction, Order Creation
    const orderRef = db.collection('diamond_orders').doc();
    const orderNumber = 'ORD' + Date.now().toString().slice(-6) + Math.floor(100 + Math.random() * 900);

    const result = await db.runTransaction(async (transaction) => {
      // Re-read shop inside transaction
      const tShopDoc = await transaction.get(shopRef);
      const currentShop = tShopDoc.exists ? tShopDoc.data() : null;
      if (!tShopDoc.exists || 
          currentShop?.isApproved !== true || 
          currentShop?.status !== 'approved' || 
          currentShop?.isActive === false || 
          currentShop?.isSubscriptionActive !== true) {
        throw new HttpsError('failed-precondition', 'Shop became unavailable, suspended, or unapproved during checkout.');
      }

      // Read all products atomically
      const productDocs = [];
      for (const sItem of sanitizedItems) {
        const prodRef = shopRef.collection('products').doc(sItem.productId);
        const pDoc = await transaction.get(prodRef);
        productDocs.push({ pDoc, sItem, prodRef });
      }

      let subtotal = 0;
      const verifiedOrderItems = [];
      const stockUpdates = [];

      for (const { pDoc, sItem, prodRef } of productDocs) {
        if (!pDoc.exists) {
          throw new HttpsError('not-found', `Product with ID ${sItem.productId} was not found in this shop.`);
        }

        const pData = pDoc.data();

        if (pData.isAvailable === false) {
          throw new HttpsError('failed-precondition', `Product '${pData.name || sItem.productId}' is currently unavailable.`);
        }

        if (pData.inStock === false) {
          throw new HttpsError('failed-precondition', `Product '${pData.name || sItem.productId}' is out of stock.`);
        }

        // Stock deduction check if tracking inventory
        if (pData.stockQuantity !== undefined && pData.stockQuantity !== null) {
          const currentStock = Number(pData.stockQuantity);
          if (currentStock < sItem.quantity) {
            throw new HttpsError(
              'failed-precondition',
              `Insufficient stock for '${pData.name || sItem.productId}'. Requested: ${sItem.quantity}, Available: ${currentStock}.`
            );
          }
          stockUpdates.push({
            prodRef,
            newStock: currentStock - sItem.quantity
          });
        }

        // Authoritative server-side price calculation (client price completely ignored)
        const unitPrice = Number(pData.sellingPrice !== undefined ? pData.sellingPrice : (pData.price || 0));
        const itemTotal = unitPrice * sItem.quantity;
        subtotal += itemTotal;

        verifiedOrderItems.push({
          productId: sItem.productId,
          name: String(pData.name || 'Product'),
          imageUrl: String(pData.imageUrl || ''),
          unit: String(pData.unit || ''),
          price: unitPrice,
          mrp: Number(pData.mrp || unitPrice),
          quantity: sItem.quantity,
          itemTotal: itemTotal
        });
      }

      // Authoritative Delivery Fee calculation
      let deliveryFee = 0;
      if (deliveryMethod === 'delivery') {
        const minOrder = Number(currentShop.minOrderAmount || 0);
        if (minOrder > 0 && subtotal < minOrder) {
          throw new HttpsError('failed-precondition', `Minimum order amount for this shop is ₹${minOrder}. Your subtotal is ₹${subtotal}.`);
        }
        deliveryFee = Number(currentShop.deliveryCharge || 0);
      }

      const totalAmount = subtotal + deliveryFee;

      // Apply atomic stock deductions
      for (const update of stockUpdates) {
        transaction.update(update.prodRef, {
          stockQuantity: update.newStock,
          inStock: update.newStock > 0,
          updatedAt: FieldValue.serverTimestamp()
        });
      }

      // Record Order
      const newOrderData = {
        id: orderRef.id,
        orderNumber: orderNumber,
        customerId: callerUid,
        customerName: deliveryAddress?.customerName || request.auth.token?.name || 'Customer',
        customerPhone: deliveryAddress?.contactPhone || request.auth.token?.phone_number || '',
        shopId: shopId.trim(),
        shopName: String(currentShop.shopName || currentShop.businessName || 'Professional Seller'),
        shopPhone: String(currentShop.phone || currentShop.contactPhone || ''),
        items: verifiedOrderItems,
        subtotal: subtotal,
        deliveryFee: deliveryFee,
        totalAmount: totalAmount,
        deliveryMethod: deliveryMethod,
        deliveryAddress: deliveryMethod === 'delivery' ? deliveryAddress : null,
        customerNotes: String(customerNotes).trim().slice(0, 500),
        status: 'placed',
        statusHistory: [
          {
            status: 'placed',
            timestamp: new Date().toISOString(),
            updatedBy: callerUid,
            note: 'Order placed by customer'
          }
        ],
        stockRestored: false,
        idempotencyKey: idempotencyKey ? String(idempotencyKey).trim() : null,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp()
      };

      transaction.set(orderRef, newOrderData);

      // Increment shop orders counter
      transaction.update(shopRef, {
        totalOrders: FieldValue.increment(1),
        updatedAt: FieldValue.serverTimestamp()
      });

      return {
        orderId: orderRef.id,
        orderNumber: orderNumber,
        totalAmount: totalAmount,
        subtotal: subtotal,
        deliveryFee: deliveryFee
      };
    });

    // 6. Non-blocking Shopkeeper Notification (FCM failure must never cancel the order)
    try {
      const providerDoc = await db.collection('providers').doc(shopId.trim()).get();
      const fcmToken = providerDoc.data()?.fcmToken || providerDoc.data()?.deviceToken;

      if (fcmToken) {
        await admin.messaging().send({
          token: fcmToken,
          notification: {
            title: '🛍️ New Order Received!',
            body: `Order #${result.orderNumber} for ₹${result.totalAmount} has been placed.`
          },
          data: {
            type: 'new_diamond_order',
            orderId: result.orderId,
            orderNumber: result.orderNumber
          },
          android: {
            priority: 'high',
            notification: {
              channelId: 'diamond_orders',
              sound: 'default'
            }
          }
        });
        logger.info(`[placeDiamondOrder] FCM push notification delivered to shopkeeper ${shopId}`);
      }
    } catch (fcmErr) {
      logger.warn(`[placeDiamondOrder] FCM push notification to shopkeeper ${shopId} failed (non-fatal):`, fcmErr.message);
    }

    return {
      success: true,
      orderId: result.orderId,
      orderNumber: result.orderNumber,
      totalAmount: result.totalAmount,
      subtotal: result.subtotal,
      deliveryFee: result.deliveryFee,
      message: 'Order placed successfully.'
    };
  } catch (err) {
    if (err.code && ['unauthenticated', 'permission-denied', 'invalid-argument', 'failed-precondition', 'not-found', 'already-exists'].includes(err.code)) {
      throw new HttpsError(err.code, err.message);
    }
    logger.error('[placeDiamondOrder] Unexpected error:', err);
    throw new HttpsError('internal', err.message || 'Failed to place order.');
  }
});

/**
 * Cloud Function: updateDiamondOrderStatus
 * Secure order state machine transitions & customer notifications.
 * - Authenticates caller (must be shopkeeper of this order or admin).
 * - Enforces legal state machine transitions.
 * - Performs atomic stock restoration on rejection or cancellation (strictly once).
 * - Non-blocking customer FCM notification.
 */
exports.updateDiamondOrderStatus = onCall({ cors: true }, async (request) => {
  try {
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError('unauthenticated', 'Authentication required.');
    }

    const callerUid = request.auth.uid;
    const { orderId, newStatus, reason = '' } = request.data || {};

    if (!orderId || typeof orderId !== 'string') {
      throw new HttpsError('invalid-argument', 'Valid order ID is required.');
    }

    const validStatuses = ['accepted', 'rejected', 'preparing', 'out_for_delivery', 'ready_for_pickup', 'delivered', 'cancelled'];
    if (!validStatuses.includes(newStatus)) {
      throw new HttpsError('invalid-argument', `Invalid status '${newStatus}'. Allowed: ${validStatuses.join(', ')}`);
    }

    const orderRef = db.collection('diamond_orders').doc(orderId.trim());
    const orderDoc = await orderRef.get();

    if (!orderDoc.exists) {
      throw new HttpsError('not-found', 'Order not found.');
    }

    const order = orderDoc.data();

    // Authorization: Must be shop owner of this order OR active Admin OR owning customer (for cancellation only)
    let isAuthorized = false;
    let callerRole = 'shopkeeper';

    if (order.shopId === callerUid) {
      isAuthorized = true;
      callerRole = 'shopkeeper';
    } else if (order.customerId === callerUid && newStatus === 'cancelled') {
      // Customer may only request cancellation while still 'placed'
      if (order.status !== 'placed') {
        throw new HttpsError('failed-precondition', 'Customers can only cancel orders while status is "placed".');
      }
      isAuthorized = true;
      callerRole = 'customer';
    } else {
      // Check admin privileges
      try {
        await verifyActiveAdmin(request);
        isAuthorized = true;
        callerRole = 'admin';
      } catch (_) {
        throw new HttpsError('permission-denied', 'You do not have permission to update this order.');
      }
    }

    // State Machine Transition Rules
    const currentStatus = order.status;
    const allowedTransitions = {
      'placed': ['accepted', 'rejected', 'cancelled'],
      'accepted': ['preparing', 'cancelled'],
      'preparing': ['out_for_delivery', 'ready_for_pickup', 'cancelled'],
      'out_for_delivery': ['delivered', 'cancelled'],
      'ready_for_pickup': ['delivered', 'cancelled'],
      'delivered': [], // Terminal
      'rejected': [],  // Terminal
      'cancelled': []  // Terminal
    };

    if (currentStatus === newStatus) {
      return { success: true, orderId, status: newStatus, message: 'Status already up to date.' };
    }

    const allowedNext = allowedTransitions[currentStatus] || [];
    if (!allowedNext.includes(newStatus)) {
      throw new HttpsError('failed-precondition', `Invalid status transition from '${currentStatus}' to '${newStatus}'.`);
    }

    // Atomic Stock Restoration if rejected or cancelled (strictly guarded to execute once)
    const needsStockRestoration = (newStatus === 'rejected' || newStatus === 'cancelled') && order.stockRestored !== true;

    await db.runTransaction(async (transaction) => {
      const tOrderDoc = await transaction.get(orderRef);
      if (!tOrderDoc.exists) throw new HttpsError('not-found', 'Order disappeared during transaction.');
      const tOrder = tOrderDoc.data();

      if (needsStockRestoration && tOrder.stockRestored !== true) {
        const shopRef = db.collection('diamond_shops').doc(order.shopId);
        if (Array.isArray(tOrder.items)) {
          for (const item of tOrder.items) {
            if (item.productId && item.quantity > 0) {
              const prodRef = shopRef.collection('products').doc(item.productId);
              transaction.update(prodRef, {
                stockQuantity: FieldValue.increment(item.quantity),
                inStock: true,
                updatedAt: FieldValue.serverTimestamp()
              });
            }
          }
        }
      }

      const statusHistory = Array.isArray(tOrder.statusHistory) ? [...tOrder.statusHistory] : [];
      statusHistory.push({
        status: newStatus,
        timestamp: new Date().toISOString(),
        updatedBy: callerUid,
        role: callerRole,
        note: String(reason).trim()
      });

      const updatePayload = {
        status: newStatus,
        statusHistory: statusHistory,
        updatedAt: FieldValue.serverTimestamp()
      };

      if (needsStockRestoration) {
        updatePayload.stockRestored = true;
      }

      // If delivered, credit total revenue to the shop
      if (newStatus === 'delivered' && currentStatus !== 'delivered') {
        const shopRef = db.collection('diamond_shops').doc(order.shopId);
        transaction.update(shopRef, {
          totalRevenue: FieldValue.increment(tOrder.totalAmount || 0),
          updatedAt: FieldValue.serverTimestamp()
        });
      }

      transaction.update(orderRef, updatePayload);
    });

    // Non-blocking Customer Notification
    try {
      const customerDoc = await db.collection('users').doc(order.customerId).get();
      const fcmToken = customerDoc.data()?.fcmToken || customerDoc.data()?.deviceToken;

      if (fcmToken) {
        const statusDisplayNames = {
          accepted: 'Accepted',
          rejected: 'Declined',
          preparing: 'Being Prepared',
          out_for_delivery: 'Out for Delivery',
          ready_for_pickup: 'Ready for Pickup',
          delivered: 'Delivered',
          cancelled: 'Cancelled'
        };

        await admin.messaging().send({
          token: fcmToken,
          notification: {
            title: `Order Update: #${order.orderNumber}`,
            body: `Your order is now ${statusDisplayNames[newStatus] || newStatus}.`
          },
          data: {
            type: 'diamond_order_status_update',
            orderId: orderId,
            orderNumber: String(order.orderNumber || ''),
            newStatus: newStatus
          }
        });
        logger.info(`[updateDiamondOrderStatus] FCM status push delivered to customer ${order.customerId}`);
      }
    } catch (fcmErr) {
      logger.warn(`[updateDiamondOrderStatus] Customer FCM notification failed (non-fatal):`, fcmErr.message);
    }

    return {
      success: true,
      orderId: orderId,
      oldStatus: currentStatus,
      newStatus: newStatus,
      stockRestored: needsStockRestoration,
      message: `Order status updated to ${newStatus}.`
    };
  } catch (err) {
    if (err.code && ['unauthenticated', 'permission-denied', 'invalid-argument', 'failed-precondition', 'not-found'].includes(err.code)) {
      throw new HttpsError(err.code, err.message);
    }
    logger.error('[updateDiamondOrderStatus] Unexpected error:', err);
    throw new HttpsError('internal', err.message || 'Failed to update order status.');
  }
});

/**
 * Cloud Function: adminApproveDiamondShop
 * Authoritative admin action to approve and activate a Diamond shop.
 * Strictly verifies caller is an active admin.
 */
exports.adminApproveDiamondShop = onCall({ cors: true }, async (request) => {
  try {
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError('unauthenticated', 'Authentication required.');
    }

    await verifyActiveAdmin(request);

    const { shopId } = request.data || {};
    if (!shopId || typeof shopId !== 'string') {
      throw new HttpsError('invalid-argument', 'Valid shop ID is required.');
    }

    const shopRef = db.collection('diamond_shops').doc(shopId.trim());
    const shopDoc = await shopRef.get();
    if (!shopDoc.exists) {
      throw new HttpsError('not-found', 'Professional seller shop not found.');
    }

    await shopRef.update({
      isApproved: true,
      status: 'approved',
      isActive: true,
      approvedAt: FieldValue.serverTimestamp(),
      approvedBy: request.auth.uid,
      updatedAt: FieldValue.serverTimestamp()
    });

    logger.info(`[adminApproveDiamondShop] Shop ${shopId} approved by admin ${request.auth.uid}`);
    return { success: true, shopId, message: 'Shop successfully approved and activated.' };
  } catch (err) {
    if (err.code && ['unauthenticated', 'permission-denied', 'invalid-argument', 'not-found'].includes(err.code)) {
      throw new HttpsError(err.code, err.message);
    }
    logger.error('[adminApproveDiamondShop] Unexpected error:', err);
    throw new HttpsError('internal', err.message || 'Failed to approve shop.');
  }
});

/**
 * Cloud Function: adminSuspendDiamondShop
 * Authoritative admin action to suspend a Diamond shop.
 * Strictly verifies caller is an active admin.
 */
exports.adminSuspendDiamondShop = onCall({ cors: true }, async (request) => {
  try {
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError('unauthenticated', 'Authentication required.');
    }

    await verifyActiveAdmin(request);

    const { shopId, reason = '' } = request.data || {};
    if (!shopId || typeof shopId !== 'string') {
      throw new HttpsError('invalid-argument', 'Valid shop ID is required.');
    }

    const shopRef = db.collection('diamond_shops').doc(shopId.trim());
    const shopDoc = await shopRef.get();
    if (!shopDoc.exists) {
      throw new HttpsError('not-found', 'Professional seller shop not found.');
    }

    await shopRef.update({
      status: 'suspended',
      isActive: false,
      suspendedAt: FieldValue.serverTimestamp(),
      suspendedBy: request.auth.uid,
      suspensionReason: String(reason).trim(),
      updatedAt: FieldValue.serverTimestamp()
    });

    logger.info(`[adminSuspendDiamondShop] Shop ${shopId} suspended by admin ${request.auth.uid}`);
    return { success: true, shopId, message: 'Shop successfully suspended.' };
  } catch (err) {
    if (err.code && ['unauthenticated', 'permission-denied', 'invalid-argument', 'not-found'].includes(err.code)) {
      throw new HttpsError(err.code, err.message);
    }
    logger.error('[adminSuspendDiamondShop] Unexpected error:', err);
    throw new HttpsError('internal', err.message || 'Failed to suspend shop.');
  }
});

/**
 * Cloud Function: adjustDiamondProductStock
 * Server-authoritative atomic stock adjustment for Professional Sellers & Admins.
 * 
 * Operations:
 * - 'set': sets stockQuantity to absolute non-negative integer amount.
 * - 'increment': increases stockQuantity by positive integer amount.
 * - 'decrement': decreases stockQuantity by positive integer amount, strictly preventing negative stock.
 * 
 * Security:
 * - Requires Firebase Authentication.
 * - Authoritative ownership verification: caller must be shop owner (or active Admin).
 * - Product must exist inside diamond_shops/{shopId}/products/{productId}.
 * - Shop must exist and must not be suspended or blocked.
 * - Negative stock is strictly rejected with 'failed-precondition'.
 * - Atomic Firestore Transaction used to prevent concurrency race with customer orders.
 * - Immutable Audit Log recorded in audit_logs collection.
 */
exports.adjustDiamondProductStock = onCall({ cors: true }, async (request) => {
  try {
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError('unauthenticated', 'Authentication required.');
    }

    const callerUid = request.auth.uid;
    const { shopId, productId, operation, amount, reason = '' } = request.data || {};

    // 1. Parameter Validation
    if (!shopId || typeof shopId !== 'string') {
      throw new HttpsError('invalid-argument', 'Valid shop ID is required.');
    }
    if (!productId || typeof productId !== 'string') {
      throw new HttpsError('invalid-argument', 'Valid product ID is required.');
    }

    const allowedOperations = ['set', 'increment', 'decrement'];
    if (!operation || !allowedOperations.includes(operation)) {
      throw new HttpsError('invalid-argument', `Invalid operation '${operation}'. Allowed operations: ${allowedOperations.join(', ')}.`);
    }

    const parsedAmount = parseInt(amount, 10);
    if (isNaN(parsedAmount) || parsedAmount < 0 || (operation !== 'set' && parsedAmount <= 0)) {
      throw new HttpsError('invalid-argument', 'Amount must be a valid positive integer (or non-negative for set).');
    }

    // 2. Authoritative Caller Role & Ownership Verification
    const cleanShopId = shopId.trim();
    const cleanProductId = productId.trim();
    const shopRef = db.collection('diamond_shops').doc(cleanShopId);
    const shopDoc = await shopRef.get();

    if (!shopDoc.exists) {
      throw new HttpsError('not-found', 'Professional seller shop not found.');
    }

    const shopData = shopDoc.data() || {};
    let isCallerAdmin = false;
    try {
      await verifyActiveAdmin(request);
      isCallerAdmin = true;
    } catch (_) {
      isCallerAdmin = false;
    }

    const isShopOwner = (shopData.ownerUid === callerUid || cleanShopId === callerUid);

    if (!isCallerAdmin && !isShopOwner) {
      logger.warn(`Unauthorized stock adjustment attempt on shop ${cleanShopId} by UID ${callerUid}`);
      throw new HttpsError('permission-denied', 'You do not have permission to adjust inventory for this shop.');
    }

    // Check if shop is suspended or blocked
    if (!isCallerAdmin && (shopData.status === 'suspended' || shopData.status === 'blocked')) {
      throw new HttpsError('failed-precondition', 'Cannot adjust inventory: this shop is currently suspended or blocked.');
    }

    // 3. Atomic Transaction for Stock Adjustment & Audit Logging
    const prodRef = shopRef.collection('products').doc(cleanProductId);

    const result = await db.runTransaction(async (transaction) => {
      const prodDoc = await transaction.get(prodRef);
      if (!prodDoc.exists) {
        throw new HttpsError('not-found', `Product with ID ${cleanProductId} not found in this shop.`);
      }

      const prodData = prodDoc.data() || {};
      const currentStock = Number(prodData.stockQuantity || 0);
      let newStock = 0;

      if (operation === 'set') {
        newStock = parsedAmount;
      } else if (operation === 'increment') {
        newStock = currentStock + parsedAmount;
      } else if (operation === 'decrement') {
        if (currentStock < parsedAmount) {
          throw new HttpsError(
            'failed-precondition',
            `Cannot decrement stock by ${parsedAmount}. Current stock is only ${currentStock}. Negative stock is not allowed.`
          );
        }
        newStock = currentStock - parsedAmount;
      }

      if (newStock < 0) {
        throw new HttpsError('failed-precondition', 'Resulting stock cannot be negative.');
      }

      // Update product stock and availability flag
      transaction.update(prodRef, {
        stockQuantity: newStock,
        inStock: newStock > 0,
        updatedAt: FieldValue.serverTimestamp()
      });

      // Write immutable audit log
      const auditRef = db.collection('audit_logs').doc();
      transaction.set(auditRef, {
        action: 'DIAMOND_STOCK_ADJUSTMENT',
        shopId: cleanShopId,
        productId: cleanProductId,
        productName: prodData.name || '',
        operation: operation,
        amount: parsedAmount,
        previousStock: currentStock,
        newStock: newStock,
        adjustedBy: callerUid,
        callerRole: isCallerAdmin ? 'admin' : 'shopkeeper',
        reason: typeof reason === 'string' ? reason.trim().slice(0, 500) : '',
        createdAt: FieldValue.serverTimestamp()
      });

      return {
        previousStock: currentStock,
        newStock,
        inStock: newStock > 0
      };
    });

    logger.info(`[adjustDiamondProductStock] Stock for ${cleanProductId} adjusted (${operation} ${parsedAmount}) by ${callerUid}. New stock: ${result.newStock}`);

    return {
      success: true,
      shopId: cleanShopId,
      productId: cleanProductId,
      operation: operation,
      amount: parsedAmount,
      previousStock: result.previousStock,
      newStock: result.newStock,
      inStock: result.inStock,
      message: `Stock successfully adjusted to ${result.newStock}.`
    };
  } catch (err) {
    if (err.code && ['unauthenticated', 'permission-denied', 'invalid-argument', 'failed-precondition', 'not-found'].includes(err.code)) {
      throw new HttpsError(err.code, err.message);
    }
    logger.error('[adjustDiamondProductStock] Unexpected error:', err);
    throw new HttpsError('internal', err.message || 'Failed to adjust stock.');
  }
});

// =============================================================================
// PROFESSIONAL SELLER SUBSCRIPTION & RAZORPAY PAYMENT FUNCTIONS
// =============================================================================

/**
 * Cloud Function: createProfessionalSubscriptionOrder
 * Server-authoritative order creation for Professional Seller subscriptions.
 * - Enforces authentication and shop ownership.
 * - Pricing & duration originate exclusively from diamond_subscription_plans.
 * - Stores pending payment record in diamond_payments/{orderId}.
 */
exports.createProfessionalSubscriptionOrder = onCall({ cors: true, secrets: RAZORPAY_SECRETS }, async (request) => {
  try {
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError('unauthenticated', 'Authentication required.');
    }
    const callerUid = request.auth.uid;

    const { shopId, planId } = request.data || {};
    if (!shopId || typeof shopId !== 'string' || !shopId.trim()) {
      throw new HttpsError('invalid-argument', 'Valid shop ID is required.');
    }
    if (!planId || typeof planId !== 'string' || !planId.trim()) {
      throw new HttpsError('invalid-argument', 'Valid plan ID is required.');
    }

    const cleanShopId = shopId.trim();
    const cleanPlanId = planId.trim();

    // 1. Verify Shop Existence and Caller Ownership
    const shopRef = db.collection('diamond_shops').doc(cleanShopId);
    const shopDoc = await shopRef.get();
    if (!shopDoc.exists) {
      throw new HttpsError('not-found', 'Professional shop not found.');
    }
    const shopData = shopDoc.data() || {};
    const ownerUid = shopData.ownerUid || cleanShopId;

    let isCallerAdmin = false;
    try {
      await verifyActiveAdmin(request);
      isCallerAdmin = true;
    } catch (_) {
      isCallerAdmin = false;
    }

    if (!isCallerAdmin && callerUid !== ownerUid && callerUid !== cleanShopId) {
      logger.warn(`[createProfessionalSubscriptionOrder] Forbidden: UID ${callerUid} does not own shop ${cleanShopId}`);
      throw new HttpsError('permission-denied', 'You do not have permission to purchase a subscription for this shop.');
    }

    // 2. Verify Subscription Plan Server-Authoritatively
    const planRef = db.collection('diamond_subscription_plans').doc(cleanPlanId);
    const planDoc = await planRef.get();
    if (!planDoc.exists) {
      throw new HttpsError('not-found', 'Professional subscription plan not found.');
    }
    const planData = planDoc.data() || {};

    if (planData.isActive !== true) {
      logger.warn(`[createProfessionalSubscriptionOrder] Plan ${cleanPlanId} is inactive.`);
      throw new HttpsError('failed-precondition', 'Subscription plan is inactive.');
    }

    const durationDays = Number(planData.durationDays);
    if (!Number.isInteger(durationDays) || durationDays < 1 || durationDays > 3650) {
      logger.warn(`[createProfessionalSubscriptionOrder] Invalid durationDays in plan ${cleanPlanId}: ${planData.durationDays}`);
      throw new HttpsError('failed-precondition', 'Subscription plan duration is invalid or not configured.');
    }

    const price = Number(planData.price);
    if (isNaN(price) || price < 0) {
      throw new HttpsError('failed-precondition', 'Subscription plan price is invalid.');
    }
    const amountInPaise = Math.round(price * 100);
    if (amountInPaise < 100) {
      throw new HttpsError('failed-precondition', 'Subscription plan amount must be at least ₹1.00 (100 paise).');
    }

    // 3. Resolve Razorpay Credentials
    const { keyId, keySecret } = await getRazorpayCredentials();
    if (!keySecret || keySecret.startsWith('*')) {
      logger.error('CRITICAL: RAZORPAY_KEY_SECRET is not configured or invalid in Cloud Functions.');
      throw new HttpsError('failed-precondition', 'Payment gateway configuration error.');
    }

    // 4. Create Razorpay Cloud Order
    let rzpOrder;
    if (process.env.RAZORPAY_MOCK === 'true' || keySecret === 'mock_secret_key_12345678') {
      rzpOrder = {
        id: `order_mock_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
        amount: amountInPaise,
        currency: 'INR',
        receipt: `pro_rcpt_${cleanShopId.slice(0, 8)}_${Date.now()}`.slice(0, 40),
      };
    } else {
      const instance = new Razorpay({ key_id: keyId, key_secret: keySecret });
      const options = {
        amount: amountInPaise,
        currency: 'INR',
        receipt: `pro_rcpt_${cleanShopId.slice(0, 8)}_${Date.now()}`.slice(0, 40),
        payment_capture: 1,
        notes: {
          shopId: cleanShopId,
          ownerUid: callerUid,
          planId: cleanPlanId,
          planName: planData.name || '',
          durationDays: String(durationDays),
          type: 'professional_subscription'
        }
      };
      rzpOrder = await instance.orders.create(options);
    }

    // 5. Store pending payment record in diamond_payments/{orderId}
    const paymentRecord = {
      orderId: rzpOrder.id,
      shopId: cleanShopId,
      ownerUid: callerUid,
      planId: cleanPlanId,
      planName: planData.name || '',
      durationDays: durationDays,
      amount: price,
      amountInPaise: amountInPaise,
      currency: 'INR',
      status: 'created',
      receipt: rzpOrder.receipt || '',
      productLimit: Number(planData.productLimit) || 0,
      imageLimit: Number(planData.imageLimit) || 0,
      storageLimitMb: Number(planData.storageLimitMb) || 0,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp()
    };

    await db.collection('diamond_payments').doc(rzpOrder.id).set(paymentRecord);
    logger.info(`[createProfessionalSubscriptionOrder] Order ${rzpOrder.id} created for shop ${cleanShopId} (Plan: ${cleanPlanId}, ₹${price})`);

    return {
      success: true,
      orderId: rzpOrder.id,
      amount: price,
      amountInPaise: amountInPaise,
      currency: 'INR',
      keyId: keyId,
      shopId: cleanShopId,
      planId: cleanPlanId,
      planName: planData.name || '',
      durationDays: durationDays
    };
  } catch (err) {
    if (err.code && ['unauthenticated', 'permission-denied', 'invalid-argument', 'failed-precondition', 'not-found'].includes(err.code)) {
      throw new HttpsError(err.code, err.message);
    }
    logger.error('[createProfessionalSubscriptionOrder] Unexpected error:', err);
    throw new HttpsError('internal', err.message || 'Failed to create subscription order.');
  }
});

/**
 * Cloud Function: verifyProfessionalSubscriptionPayment
 * Server-authoritative payment verification & atomic subscription activation for Professional Sellers.
 * - Strictly verifies HMAC signature, order ownership, live capture on gateway, and currency/amount.
 * - Handles renewal stacking (adds to current expiry if active, or starts from now if expired/new).
 * - Implements strict idempotency.
 * - Sets pending_retry on diamond_payments if database activation fails after live capture.
 */
exports.verifyProfessionalSubscriptionPayment = onCall({ cors: true, secrets: RAZORPAY_SECRETS }, async (request) => {
  try {
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError('unauthenticated', 'Authentication required.');
    }
    const callerUid = request.auth.uid;

    const { shopId, planId, razorpayOrderId, razorpayPaymentId, razorpaySignature } = request.data || {};
    if (!shopId || typeof shopId !== 'string' || !shopId.trim() ||
        !planId || typeof planId !== 'string' || !planId.trim() ||
        !razorpayOrderId || typeof razorpayOrderId !== 'string' || !razorpayOrderId.trim() ||
        !razorpayPaymentId || typeof razorpayPaymentId !== 'string' || !razorpayPaymentId.trim() ||
        !razorpaySignature || typeof razorpaySignature !== 'string' || !razorpaySignature.trim()) {
      throw new HttpsError('invalid-argument', 'All payment verification fields are required (shopId, planId, razorpayOrderId, razorpayPaymentId, razorpaySignature).');
    }

    const cleanShopId = shopId.trim();
    const cleanPlanId = planId.trim();
    const cleanOrderId = razorpayOrderId.trim();
    const cleanPaymentId = razorpayPaymentId.trim();
    const cleanSignature = razorpaySignature.trim();

    // 1. Fetch Order Record from diamond_payments
    const paymentRef = db.collection('diamond_payments').doc(cleanOrderId);
    const paymentDoc = await paymentRef.get();
    if (!paymentDoc.exists) {
      throw new HttpsError('not-found', 'Order payment record not found.');
    }
    const orderData = paymentDoc.data() || {};

    // 2. Verify Caller Ownership
    let isCallerAdmin = false;
    try {
      await verifyActiveAdmin(request);
      isCallerAdmin = true;
    } catch (_) {
      isCallerAdmin = false;
    }

    if (!isCallerAdmin && callerUid !== orderData.ownerUid && callerUid !== orderData.shopId) {
      logger.warn(`[verifyProfessionalSubscriptionPayment] Forbidden: UID ${callerUid} does not own order ${cleanOrderId}`);
      throw new HttpsError('permission-denied', 'You do not have permission to verify payment for this shop.');
    }

    if (orderData.shopId !== cleanShopId) {
      throw new HttpsError('invalid-argument', 'Shop ID mismatch.');
    }
    if (orderData.planId !== cleanPlanId) {
      throw new HttpsError('invalid-argument', 'Plan ID mismatch.');
    }

    // 3. Idempotency Check
    if (orderData.status === 'activated') {
      if (orderData.paymentId === cleanPaymentId) {
        logger.info(`[verifyProfessionalSubscriptionPayment] Idempotent verification for order ${cleanOrderId}`);
        return {
          success: true,
          alreadyVerified: true,
          orderId: cleanOrderId,
          paymentId: cleanPaymentId,
          shopId: cleanShopId,
          message: 'Payment has already been successfully verified and subscription is active.'
        };
      } else {
        logger.warn(`[verifyProfessionalSubscriptionPayment] Order ${cleanOrderId} already fulfilled with different payment: ${orderData.paymentId}`);
        throw new HttpsError('failed-precondition', 'Order has already been fulfilled with a different payment.');
      }
    }

    // 4. Cryptographic HMAC-SHA256 Signature Verification
    const { keyId, keySecret } = await getRazorpayCredentials();
    if (!keySecret || keySecret.startsWith('*')) {
      logger.error('CRITICAL: RAZORPAY_KEY_SECRET is not configured or invalid in Cloud Functions.');
      throw new HttpsError('failed-precondition', 'Payment gateway configuration error.');
    }

    const expectedBody = `${cleanOrderId}|${cleanPaymentId}`;
    const expectedSignature = crypto
      .createHmac('sha256', keySecret)
      .update(expectedBody)
      .digest('hex');

    const sigBuffer = Buffer.from(cleanSignature, 'utf8');
    const expBuffer = Buffer.from(expectedSignature, 'utf8');
    const isSignatureValid = (sigBuffer.length === expBuffer.length) && crypto.timingSafeEqual(sigBuffer, expBuffer);

    if (!isSignatureValid) {
      logger.warn(`[verifyProfessionalSubscriptionPayment] HMAC signature mismatch for order ${cleanOrderId}`);
      throw new HttpsError('invalid-argument', 'Invalid payment signature.');
    }

    // 5. Authoritative Live Razorpay API Payment Verification
    if (process.env.RAZORPAY_MOCK === 'true' || keySecret === 'mock_secret_key_12345678') {
      if (orderData._mockFailCapture || cleanPaymentId.includes('_fail_not_captured')) {
        throw new HttpsError('failed-precondition', 'Payment is not captured on gateway.');
      }
      if (orderData._mockMismatchedAmount || cleanPaymentId.includes('_fail_amount')) {
        throw new HttpsError('invalid-argument', 'Payment amount mismatch between gateway and order.');
      }
      if (orderData._mockMismatchedCurrency || cleanPaymentId.includes('_fail_currency')) {
        throw new HttpsError('invalid-argument', 'Payment currency mismatch. Only INR is supported.');
      }
      if (orderData._mockMismatchedOrder || cleanPaymentId.includes('_fail_order_mismatch')) {
        throw new HttpsError('invalid-argument', 'Payment does not belong to specified order.');
      }
    } else {
      const instance = new Razorpay({ key_id: keyId, key_secret: keySecret });
      let rzpPayment;
      try {
        rzpPayment = await instance.payments.fetch(cleanPaymentId);
      } catch (fetchErr) {
        logger.error(`[verifyProfessionalSubscriptionPayment] Failed to fetch payment ${cleanPaymentId}:`, fetchErr);
        throw new HttpsError('failed-precondition', 'Failed to verify payment with payment gateway.');
      }

      if (!rzpPayment || rzpPayment.status !== 'captured') {
        logger.warn(`[verifyProfessionalSubscriptionPayment] Payment ${cleanPaymentId} status is '${rzpPayment?.status}'. Expected 'captured'.`);
        throw new HttpsError('failed-precondition', `Payment is not captured on gateway (status: '${rzpPayment?.status || 'unknown'}').`);
      }

      if (rzpPayment.currency !== 'INR') {
        logger.warn(`[verifyProfessionalSubscriptionPayment] Currency mismatch: ${rzpPayment.currency}`);
        throw new HttpsError('invalid-argument', 'Payment currency mismatch. Only INR is supported.');
      }

      if (Number(rzpPayment.amount) !== Number(orderData.amountInPaise)) {
        logger.warn(`[verifyProfessionalSubscriptionPayment] Amount mismatch: rzp=${rzpPayment.amount}, expected=${orderData.amountInPaise}`);
        throw new HttpsError('invalid-argument', 'Payment amount mismatch between gateway and order.');
      }

      if (rzpPayment.order_id && rzpPayment.order_id !== cleanOrderId) {
        logger.warn(`[verifyProfessionalSubscriptionPayment] Order mismatch: rzpOrder=${rzpPayment.order_id}, expected=${cleanOrderId}`);
        throw new HttpsError('invalid-argument', 'Payment does not belong to specified order.');
      }
    }

    // 6. Atomic Firestore Activation Transaction
    const shopRef = db.collection('diamond_shops').doc(cleanShopId);
    let activationResult;

    try {
      activationResult = await db.runTransaction(async (transaction) => {
        const txPaymentDoc = await transaction.get(paymentRef);
        if (!txPaymentDoc.exists) {
          throw new HttpsError('not-found', 'Order payment record not found.');
        }
        const currentPaymentData = txPaymentDoc.data() || {};
        if (currentPaymentData.status === 'activated') {
          if (currentPaymentData.paymentId === cleanPaymentId) {
            return { alreadyActivated: true };
          }
          throw new HttpsError('failed-precondition', 'Order has already been fulfilled with a different payment.');
        }

        const txShopDoc = await transaction.get(shopRef);
        if (!txShopDoc.exists) {
          throw new HttpsError('not-found', 'Professional shop not found.');
        }
        const currentShopData = txShopDoc.data() || {};

        const durationDays = Number(orderData.durationDays) || 30;
        const now = new Date();
        const existingExpiryTimestamp = currentShopData.subscriptionExpiry;
        let existingExpiryDate = null;
        if (existingExpiryTimestamp && typeof existingExpiryTimestamp.toDate === 'function') {
          existingExpiryDate = existingExpiryTimestamp.toDate();
        } else if (existingExpiryTimestamp instanceof Date) {
          existingExpiryDate = existingExpiryTimestamp;
        }

        let newExpiryDate;
        const durationMillis = durationDays * 24 * 60 * 60 * 1000;
        if (existingExpiryDate && existingExpiryDate.getTime() > now.getTime()) {
          // Early renewal: stack duration onto existing future expiry
          newExpiryDate = new Date(existingExpiryDate.getTime() + durationMillis);
        } else {
          // Late renewal or initial subscription: start from now
          newExpiryDate = new Date(now.getTime() + durationMillis);
        }

        transaction.update(paymentRef, {
          status: 'activated',
          paymentId: cleanPaymentId,
          signature: cleanSignature,
          verifiedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
          fulfillmentSource: 'client_verification'
        });

        transaction.update(shopRef, {
          isSubscriptionActive: true,
          subscriptionPlanId: cleanPlanId,
          subscriptionPlanName: orderData.planName || '',
          subscriptionDurationDays: durationDays,
          subscriptionExpiry: admin.firestore.Timestamp.fromDate(newExpiryDate),
          subscriptionActivatedAt: FieldValue.serverTimestamp(),
          paymentVerified: true,
          paymentOrderId: cleanOrderId,
          paymentId: cleanPaymentId,
          paymentAmount: orderData.amount,
          paymentAmountInPaise: orderData.amountInPaise,
          productLimit: orderData.productLimit || 0,
          imageLimit: orderData.imageLimit || 0,
          storageLimitMb: orderData.storageLimitMb || 0,
          updatedAt: FieldValue.serverTimestamp()
        });

        return {
          alreadyActivated: false,
          newExpiryDate
        };
      });
    } catch (txErr) {
      logger.error(`[verifyProfessionalSubscriptionPayment] Activation transaction failed for order ${cleanOrderId}:`, txErr);
      // Recovery handler: Set pending_retry state on diamond_payments because live payment was captured
      try {
        await paymentRef.set({
          status: 'pending_retry',
          paymentId: cleanPaymentId,
          signature: cleanSignature,
          lastError: txErr.message || 'Transaction failed',
          updatedAt: FieldValue.serverTimestamp()
        }, { merge: true });
      } catch (recErr) {
        logger.error('[verifyProfessionalSubscriptionPayment] Failed to set pending_retry status on payment:', recErr);
      }
      throw txErr;
    }

    logger.info(`[verifyProfessionalSubscriptionPayment] Successfully activated subscription for shop ${cleanShopId} (Order: ${cleanOrderId}, Payment: ${cleanPaymentId})`);

    return {
      success: true,
      alreadyVerified: activationResult.alreadyActivated,
      orderId: cleanOrderId,
      paymentId: cleanPaymentId,
      shopId: cleanShopId,
      planId: cleanPlanId,
      durationDays: orderData.durationDays,
      isSubscriptionActive: true,
      message: 'Subscription successfully activated.'
    };
  } catch (err) {
    if (err.code && ['unauthenticated', 'permission-denied', 'invalid-argument', 'failed-precondition', 'not-found'].includes(err.code)) {
      throw new HttpsError(err.code, err.message);
    }
    logger.error('[verifyProfessionalSubscriptionPayment] Unexpected error:', err);
    throw new HttpsError('internal', err.message || 'Failed to verify subscription payment.');
  }
});

/**
 * HTTP Function: professionalRazorpayWebhook
 * Dedicated isolated webhook fulfillment for Professional Seller subscriptions.
 * - Handles payment.captured and order.paid for professional subscriptions.
 * - Cryptographically verifies webhook HMAC signature.
 * - Idempotently activates the shop subscription if not already activated.
 */
exports.professionalRazorpayWebhook = onRequest({ cors: true, secrets: RAZORPAY_SECRETS }, async (req, res) => {
  const { webhookSecret } = await getRazorpayCredentials();
  const signature = req.headers['x-razorpay-signature'];

  if (!webhookSecret || !signature) {
    logger.warn('[professionalRazorpayWebhook] Missing x-razorpay-signature or webhook secret not configured');
    res.status(401).send('Missing Signature or Secret');
    return;
  }

  try {
    const rawPayload = Buffer.isBuffer(req.rawBody)
      ? req.rawBody
      : (typeof req.rawBody === 'string'
          ? req.rawBody
          : (typeof req.body === 'string' ? req.body : JSON.stringify(req.body)));
    const expectedSignature = crypto
      .createHmac('sha256', webhookSecret)
      .update(rawPayload)
      .digest('hex');

    const sigBuffer = Buffer.from(signature, 'utf8');
    const expBuffer = Buffer.from(expectedSignature, 'utf8');
    const isValid = (sigBuffer.length === expBuffer.length) && crypto.timingSafeEqual(sigBuffer, expBuffer);

    if (!isValid) {
      logger.warn('[professionalRazorpayWebhook] Unauthorized webhook signature mismatch');
      res.status(400).send('Invalid Signature');
      return;
    }
  } catch (sigErr) {
    logger.error('[professionalRazorpayWebhook] Signature verification error:', sigErr);
    res.status(400).send('Signature Verification Error');
    return;
  }

  const event = req.body?.event;
  const payload = req.body?.payload;

  if (event === 'payment.captured' || event === 'order.paid') {
    const paymentEntity = payload?.payment?.entity;
    const orderEntity = payload?.order?.entity;
    const orderId = paymentEntity?.order_id || orderEntity?.id;
    const paymentId = paymentEntity?.id;

    if (!orderId) {
      logger.warn('[professionalRazorpayWebhook] Webhook event lacks order_id');
      res.status(200).json({ status: 'ignored', message: 'Missing order_id' });
      return;
    }

    try {
      const paymentRef = db.collection('diamond_payments').doc(orderId);
      const paymentDoc = await paymentRef.get();
      if (!paymentDoc.exists) {
        logger.warn(`[professionalRazorpayWebhook] Order ${orderId} not found in diamond_payments.`);
        res.status(200).json({ status: 'order_not_found', orderId });
        return;
      }

      const orderData = paymentDoc.data() || {};
      if (orderData.status === 'activated') {
        logger.info(`[professionalRazorpayWebhook] Order ${orderId} is already activated. Idempotent return.`);
        res.status(200).json({ status: 'already_activated', orderId });
        return;
      }

      const shopRef = db.collection('diamond_shops').doc(orderData.shopId);
      await db.runTransaction(async (transaction) => {
        const txPaymentDoc = await transaction.get(paymentRef);
        if (!txPaymentDoc.exists || txPaymentDoc.data()?.status === 'activated') {
          return;
        }

        const txShopDoc = await transaction.get(shopRef);
        if (!txShopDoc.exists) return;
        const currentShopData = txShopDoc.data() || {};

        const durationDays = Number(orderData.durationDays) || 30;
        const now = new Date();
        const existingExpiryTimestamp = currentShopData.subscriptionExpiry;
        let existingExpiryDate = null;
        if (existingExpiryTimestamp && typeof existingExpiryTimestamp.toDate === 'function') {
          existingExpiryDate = existingExpiryTimestamp.toDate();
        }
        let newExpiryDate;
        const durationMillis = durationDays * 24 * 60 * 60 * 1000;
        if (existingExpiryDate && existingExpiryDate.getTime() > now.getTime()) {
          newExpiryDate = new Date(existingExpiryDate.getTime() + durationMillis);
        } else {
          newExpiryDate = new Date(now.getTime() + durationMillis);
        }

        transaction.update(paymentRef, {
          status: 'activated',
          paymentId: paymentId || orderData.paymentId || '',
          verifiedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
          fulfillmentSource: 'webhook'
        });

        transaction.update(shopRef, {
          isSubscriptionActive: true,
          subscriptionPlanId: orderData.planId,
          subscriptionPlanName: orderData.planName || '',
          subscriptionDurationDays: durationDays,
          subscriptionExpiry: admin.firestore.Timestamp.fromDate(newExpiryDate),
          subscriptionActivatedAt: FieldValue.serverTimestamp(),
          paymentVerified: true,
          paymentOrderId: orderId,
          paymentId: paymentId || orderData.paymentId || '',
          paymentAmount: orderData.amount,
          paymentAmountInPaise: orderData.amountInPaise,
          productLimit: orderData.productLimit || 0,
          imageLimit: orderData.imageLimit || 0,
          storageLimitMb: orderData.storageLimitMb || 0,
          updatedAt: FieldValue.serverTimestamp()
        });
      });

      logger.info(`[professionalRazorpayWebhook] Successfully activated subscription for shop ${orderData.shopId} via webhook.`);
      res.status(200).json({ status: 'success', orderId });
      return;
    } catch (fulfillErr) {
      logger.error('[professionalRazorpayWebhook] Fulfillment error:', fulfillErr);
      res.status(500).json({ status: 'error', message: fulfillErr.message });
      return;
    }
  }

  res.status(200).json({ status: 'ignored', event });
});





