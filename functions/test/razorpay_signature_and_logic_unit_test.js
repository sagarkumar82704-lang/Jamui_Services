const crypto = require('crypto');
const assert = require('assert');

console.log('--- RUNNING PURE UNIT TESTS FOR RAZORPAY SUBSCRIPTION LOGIC ---');

// 1. Signature generation and timingSafeEqual verification
function verifyCheckoutSignature(orderId, paymentId, signature, secret) {
  const expectedBody = `${orderId}|${paymentId}`;
  const expectedSignature = crypto.createHmac('sha256', secret).update(expectedBody).digest('hex');
  const sigBuffer = Buffer.from(signature, 'utf8');
  const expBuffer = Buffer.from(expectedSignature, 'utf8');
  return (sigBuffer.length === expBuffer.length) && crypto.timingSafeEqual(sigBuffer, expBuffer);
}

const secret = 'rzp_test_secret_abc123';
const orderId = 'order_test_123';
const paymentId = 'pay_test_456';
const validSig = crypto.createHmac('sha256', secret).update(`${orderId}|${paymentId}`).digest('hex');
const tamperedSig = 'a' + validSig.slice(1);

assert.strictEqual(verifyCheckoutSignature(orderId, paymentId, validSig, secret), true, 'Valid signature must pass');
assert.strictEqual(verifyCheckoutSignature(orderId, paymentId, tamperedSig, secret), false, 'Tampered signature must fail');
assert.strictEqual(verifyCheckoutSignature('order_other', paymentId, validSig, secret), false, 'Mismatched order must fail');
assert.strictEqual(verifyCheckoutSignature(orderId, 'pay_other', validSig, secret), false, 'Mismatched payment must fail');
console.log('✅ TEST 1 PASSED: HMAC-SHA256 signature verification & tampering detection');

// 2. Amount in paise conversion
function calculatePaise(price) {
  const p = Number(price);
  if (isNaN(p) || p < 0) throw new Error('Invalid price');
  const paise = Math.round(p * 100);
  if (paise < 100) throw new Error('Minimum ₹1.00');
  return paise;
}

assert.strictEqual(calculatePaise(199), 19900);
assert.strictEqual(calculatePaise(499.50), 49950);
assert.throws(() => calculatePaise(0.50), /Minimum ₹1.00/);
assert.throws(() => calculatePaise(-10), /Invalid price/);
console.log('✅ TEST 2 PASSED: Price to paise server conversion');

// 3. Subscription Expiry Stacking Logic
function calculateNewExpiry(existingExpiryDate, durationDays, now = new Date()) {
  const durationMillis = durationDays * 24 * 60 * 60 * 1000;
  if (existingExpiryDate && existingExpiryDate.getTime() > now.getTime()) {
    return new Date(existingExpiryDate.getTime() + durationMillis);
  } else {
    return new Date(now.getTime() + durationMillis);
  }
}

const now = new Date('2026-11-06T12:00:00Z');
// Case A: New subscription (no existing expiry) -> starts from now
const expiryA = calculateNewExpiry(null, 30, now);
assert.strictEqual(expiryA.getTime(), now.getTime() + 30 * 24 * 60 * 60 * 1000);

// Case B: Expired subscription -> starts from now
const pastExpiry = new Date('2026-10-01T12:00:00Z');
const expiryB = calculateNewExpiry(pastExpiry, 30, now);
assert.strictEqual(expiryB.getTime(), now.getTime() + 30 * 24 * 60 * 60 * 1000);

// Case C: Active subscription (early renewal) -> stacks on top of existing future expiry
const futureExpiry = new Date('2026-11-20T12:00:00Z');
const expiryC = calculateNewExpiry(futureExpiry, 30, now);
assert.strictEqual(expiryC.getTime(), futureExpiry.getTime() + 30 * 24 * 60 * 60 * 1000);
console.log('✅ TEST 3 PASSED: Subscription expiry calculation (new, expired, early renewal)');

// 4. Idempotency logic check
function verifyIdempotency(orderData, incomingPaymentId) {
  if (orderData.status === 'activated') {
    if (orderData.paymentId === incomingPaymentId) {
      return { alreadyVerified: true, success: true };
    } else {
      throw new Error('Order fulfilled with different payment');
    }
  }
  return { alreadyVerified: false };
}

const activatedOrder = { status: 'activated', paymentId: 'pay_test_456' };
const idempRes = verifyIdempotency(activatedOrder, 'pay_test_456');
assert.strictEqual(idempRes.alreadyVerified, true);
assert.throws(() => verifyIdempotency(activatedOrder, 'pay_different'), /Order fulfilled with different payment/);
console.log('✅ TEST 4 PASSED: Payment idempotency and replay protection');

console.log('--- ALL PURE UNIT TESTS PASSED SUCCESSFULLY ---');

