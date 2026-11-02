import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions/v1';
import * as crypto from 'crypto';
import Razorpay from 'razorpay';

// Initialize Firebase Admin SDK
admin.initializeApp();
const db = admin.firestore();

// All subscription plans MUST originate from Firebase Firestore `subscription_plans` collection.
// Hardcoded plans, prices, durations, or fallbacks are strictly prohibited across backend handlers.

/**
 * Retrieves Razorpay configuration from Cloud Firestore `app_config/payment` or environment variables
 */
async function getRazorpayCredentials(): Promise<{ keyId: string; keySecret: string }> {
  try {
    const configDoc = await db.collection('app_config').doc('payment').get();
    if (configDoc.exists) {
      const data = configDoc.data();
      const keyId = data?.keyId || process.env.RAZORPAY_KEY_ID || 'rzp_test_apnajamui';
      const keySecret = data?.keySecret || process.env.RAZORPAY_KEY_SECRET || '';
      return { keyId, keySecret };
    }
  } catch (error) {
    functions.logger.warn('Failed to read app_config/payment from Firestore, using environment fallbacks:', error);
  }

  return {
    keyId: process.env.RAZORPAY_KEY_ID || 'rzp_test_apnajamui',
    keySecret: process.env.RAZORPAY_KEY_SECRET || '',
  };
}

/**
 * 1. GET SUBSCRIPTION PLANS
 * Callable & REST: Returns all active subscription plans configured by Admin
 */
export const getSubscriptionPlans = functions.https.onCall(async (data, context) => {
  try {
    const snapshot = await db.collection('subscription_plans').where('isActive', '==', true).get();
    if (!snapshot.empty) {
      return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    }
  } catch (error) {
    functions.logger.error('Error reading subscription_plans from Firestore:', error);
  }
  return [];
});

/**
 * 2. CREATE RAZORPAY SUBSCRIPTION ORDER
 * Authoritative server-side calculation: Client sends only planId and providerId.
 */
export const createSubscriptionOrder = functions.https.onCall(async (data, context) => {
  const { planId, providerId, providerPhone, providerEmail } = data;

  if (!planId || !providerId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Both planId and providerId are required to initiate an order.'
    );
  }

  // 1. Fetch Authoritative Plan Price
  let planData: any = null;
  try {
    const planDoc = await db.collection('subscription_plans').doc(planId).get();
    if (planDoc.exists && planDoc.data()?.isActive !== false) {
      planData = { id: planDoc.id, ...planDoc.data() };
    }
  } catch (error) {
    functions.logger.warn(`Error fetching plan ${planId}:`, error);
  }

  if (!planData) {
    throw new functions.https.HttpsError('not-found', `Subscription plan '${planId}' is invalid or inactive.`);
  }

  const priceInRupees = Number(planData.price);
  if (!Number.isFinite(priceInRupees) || priceInRupees <= 0) {
    throw new functions.https.HttpsError('failed-precondition', 'Invalid plan price configured in database.');
  }
  const amountInPaise = Math.round(priceInRupees * 100);
  const planName = String(planData.name || 'Subscription Plan');

  const { keyId, keySecret } = await getRazorpayCredentials();
  let orderId = '';

  // 2. Call Razorpay API if Secret is configured
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
        notes: {
          providerId,
          planId,
          planName,
        },
      };

      const order = await instance.orders.create(options);
      orderId = order.id;
      functions.logger.info(`Successfully generated Razorpay Cloud Order: ${orderId}`);
    } catch (apiError) {
      functions.logger.error('Razorpay API order creation failed, generating local fallback order:', apiError);
    }
  }

  if (!orderId) {
    const hash = crypto.createHash('md5').update(`${providerId}_${planId}_${Date.now()}`).digest('hex').substring(0, 12);
    orderId = `order_${hash}`;
  }

  // 3. Persist Order in Firestore payments collection
  try {
    await db.collection('payments').doc(orderId).set({
      id: orderId,
      orderId: orderId,
      providerId: providerId,
      planId: planId,
      planName: planName,
      amount: priceInRupees,
      amountInPaise: amountInPaise,
      currency: 'INR',
      status: 'created',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (dbError) {
    functions.logger.error('Failed to log payment order in Firestore:', dbError);
  }

  return {
    orderId,
    amount: amountInPaise,
    currency: 'INR',
    keyId,
    planId,
    planName,
  };
});

/**
 * 3. VERIFY RAZORPAY SUBSCRIPTION PAYMENT
 * Validates HMAC-SHA256 signature server-side and atomically activates the provider's subscription.
 */
export const verifySubscriptionPayment = functions.https.onCall(async (data, context) => {
  const { providerId, planId, razorpayOrderId, razorpayPaymentId, razorpaySignature } = data;

  if (!providerId || !planId || !razorpayOrderId || !razorpayPaymentId) {
    throw new functions.https.HttpsError('invalid-argument', 'Incomplete payment verification payload.');
  }

  const { keySecret } = await getRazorpayCredentials();

  // 1. Cryptographic HMAC Signature Verification
  if (!keySecret || keySecret === 'your_razorpay_secret_here') {
    functions.logger.error('CRITICAL: RAZORPAY_KEY_SECRET is not configured in Cloud Functions / Firestore.');
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Payment Gateway Configuration Error: Razorpay Secret is not configured on the server.'
    );
  }

  const body = `${razorpayOrderId}|${razorpayPaymentId}`;
  const expectedSignature = crypto
    .createHmac('sha256', keySecret)
    .update(body)
    .digest('hex');

  if (expectedSignature !== razorpaySignature) {
    functions.logger.warn(`HMAC signature mismatch for order: ${razorpayOrderId}`);
    throw new functions.https.HttpsError(
      'permission-denied',
      'Payment signature verification failed. Transaction cannot be validated.'
    );
  }

  // 2. Fetch Plan Duration to compute new expiry
  let durationDays = 30;
  let categoryLimit = 1;
  try {
    const planDoc = await db.collection('subscription_plans').doc(planId).get();
    if (planDoc.exists && planDoc.data()?.isActive !== false) {
      durationDays = Number(planDoc.data()?.durationDays || 0);
      categoryLimit = Number(planDoc.data()?.categoryLimit || 1);
    }
  } catch (err) {
    functions.logger.warn('Plan lookup failed during payment verification:', err);
  }

  if (!durationDays || durationDays <= 0) {
    throw new functions.https.HttpsError('failed-precondition', 'Invalid plan duration in database.');
  }

  // 3. Calculate New Expiry (Stack onto existing subscription if still active)
  const now = new Date();
  let startDate = now;
  const providerRef = db.collection('providers').doc(providerId);
  const providerDoc = await providerRef.get();

  if (providerDoc.exists) {
    const existingExpiry = providerDoc.data()?.subscriptionExpiry;
    if (existingExpiry) {
      const existingDate = existingExpiry.toDate ? existingExpiry.toDate() : new Date(existingExpiry);
      if (existingDate > now) {
        startDate = existingDate;
      }
    }
  }

  const expiryDate = new Date(startDate.getTime() + durationDays * 24 * 60 * 60 * 1000);

  // 4. Batch Write: Update Payment Record & Provider Profile Atomically
  const batch = db.batch();
  const paymentRef = db.collection('payments').doc(razorpayOrderId);

  batch.set(
    paymentRef,
    {
      status: 'success',
      paymentId: razorpayPaymentId,
      signature: razorpaySignature || '',
      verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      expiryDate: expiryDate,
    },
    { merge: true }
  );

  batch.update(providerRef, {
    isSubscriptionActive: true,
    subscriptionPlan: planId,
    subscriptionExpiry: admin.firestore.Timestamp.fromDate(expiryDate),
    adminCategoryOverrideLimit: categoryLimit,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await batch.commit();

  functions.logger.info(`✅ Subscription activated successfully for Provider: ${providerId} until ${expiryDate.toISOString()}`);

  return {
    success: true,
    message: 'Subscription payment verified and plan activated successfully.',
    expiryDate: expiryDate.toISOString(),
  };
});

/**
 * 4. UPDATE PROVIDER PROFILE (AUTHORITATIVE BACKEND)
 * Validates ownership, checks admin approval status, locks approved category,
 * updates only permitted fields, and preserves existing approved status.
 */
export const updateProviderProfile = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated to update profile.');
  }

  const { providerId, fields } = data || {};
  if (!providerId || !fields || typeof fields !== 'object') {
    throw new functions.https.HttpsError('invalid-argument', 'providerId and fields object are required.');
  }

  // 1. Verify Ownership (or Admin)
  let isCallerAdmin = false;
  try {
    const adminDoc = await db.collection('admin_users').doc(context.auth.uid).get();
    isCallerAdmin = adminDoc.exists;
  } catch (_) {
    isCallerAdmin = false;
  }

  if (context.auth.uid !== providerId && !isCallerAdmin) {
    throw new functions.https.HttpsError('permission-denied', 'You are not authorized to edit this provider profile.');
  }

  const providerRef = db.collection('providers').doc(providerId);
  const providerSnap = await providerRef.get();
  if (!providerSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Provider profile does not exist.');
  }

  const currentData = providerSnap.data() || {};

  // 2. Blocked or Suspended Providers cannot edit
  if (currentData.status === 'blocked' || currentData.status === 'suspended') {
    throw new functions.https.HttpsError('permission-denied', 'This provider account is blocked or suspended.');
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
        throw new functions.https.HttpsError(
          'permission-denied',
          'Admin-approved category is locked and cannot be changed by the provider. Please contact Admin.'
        );
      }
    }
  }

  // 4. Whitelist Permitted Fields
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

  const updatePayload: Record<string, any> = {};
  for (const [key, value] of Object.entries(fields)) {
    if (ALLOWED_FIELDS.has(key)) {
      updatePayload[key] = value;
    }
  }

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
export const razorpayWebhook = functions.https.onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).send('Method Not Allowed');
    return;
  }

  const { keySecret } = await getRazorpayCredentials();
  const signature = req.headers['x-razorpay-signature'] as string;

  if (keySecret && signature) {
    const expectedSignature = crypto
      .createHmac('sha256', keySecret)
      .update(JSON.stringify(req.body))
      .digest('hex');

    if (expectedSignature !== signature) {
      functions.logger.warn('Unauthorized webhook signature attempt');
      res.status(400).send('Invalid Signature');
      return;
    }
  }

  const event = req.body.event;
  const payload = req.body.payload;

  if (event === 'payment.captured' || event === 'order.paid') {
    const paymentEntity = payload.payment?.entity;
    const notes = paymentEntity?.notes || {};
    const providerId = notes.providerId;
    const planId = notes.planId;

    if (providerId && planId) {
      functions.logger.info(`Processing background webhook fulfillment for Provider: ${providerId}`);
      // Fulfillment logic...
    }
  }

  res.status(200).json({ status: 'ok' });
});
