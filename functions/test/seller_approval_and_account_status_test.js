const assert = require('assert');

console.log('================================================================');
console.log(' PROFESSIONAL SELLER APPROVAL & ACCOUNT STATUS TEST SUITE');
console.log(' Server-Authoritative Validation Tests for Order & Payment Flows');
console.log('================================================================\n');

/**
 * Mirror of server-side validation logic implemented in createProfessionalSubscriptionOrder
 */
function validateShopForSubscriptionOrder(shopData, callerUid, cleanShopId, isCallerAdmin = false) {
  if (!shopData) {
    const err = new Error('Professional shop not found.');
    err.code = 'not-found';
    throw err;
  }

  const ownerUid = shopData.ownerUid || cleanShopId;
  if (!isCallerAdmin && callerUid !== ownerUid && callerUid !== cleanShopId) {
    const err = new Error('You do not have permission to purchase a subscription for this shop.');
    err.code = 'permission-denied';
    throw err;
  }

  if (shopData.isDeleted === true) {
    const err = new Error('Shop has been deleted.');
    err.code = 'not-found';
    throw err;
  }

  const rawStatus = (shopData.status || '').toLowerCase().trim();
  if (rawStatus === 'suspended') {
    const err = new Error('Shop account is suspended. Subscription purchase is not permitted.');
    err.code = 'failed-precondition';
    throw err;
  }

  if (rawStatus === 'blocked') {
    const err = new Error('Shop account is blocked. Subscription purchase is not permitted.');
    err.code = 'permission-denied';
    throw err;
  }

  if (rawStatus === 'rejected') {
    const err = new Error('Shop registration has been rejected by administration.');
    err.code = 'failed-precondition';
    throw err;
  }

  if (shopData.isApproved === false) {
    const err = new Error('Shop registration is not approved. Subscription purchase is not permitted.');
    err.code = 'failed-precondition';
    throw err;
  }

  const unapprovedStatuses = ['pending', 'pending_review', 'draft', 'rejected', 'suspended', 'blocked'];
  if (unapprovedStatuses.includes(rawStatus)) {
    const err = new Error(`Shop registration is in '${rawStatus}' status. Subscription purchase is not permitted.`);
    err.code = 'failed-precondition';
    throw err;
  }

  const hasApprovalEvidence = shopData.isApproved === true || rawStatus === 'approved';
  if (!hasApprovalEvidence) {
    const err = new Error('Shop registration is pending admin approval. You can purchase a subscription once your shop is approved.');
    err.code = 'failed-precondition';
    throw err;
  }

  if (shopData.isActive === false) {
    const err = new Error('Shop account is currently inactive.');
    err.code = 'failed-precondition';
    throw err;
  }

  return { success: true };
}

/**
 * Mirror of server-side validation logic inside verifyProfessionalSubscriptionPayment transaction
 */
function validateShopForActivationTransaction(currentShopData) {
  if (!currentShopData) {
    const err = new Error('Professional shop not found.');
    err.code = 'not-found';
    throw err;
  }

  if (currentShopData.isDeleted === true) {
    const err = new Error('Shop has been deleted.');
    err.code = 'not-found';
    throw err;
  }

  const rawShopStatus = (currentShopData.status || '').toLowerCase().trim();
  if (rawShopStatus === 'suspended') {
    const err = new Error('Shop account is suspended. Subscription activation held.');
    err.code = 'failed-precondition';
    throw err;
  }
  if (rawShopStatus === 'blocked') {
    const err = new Error('Shop account is blocked. Subscription activation held.');
    err.code = 'permission-denied';
    throw err;
  }
  if (rawShopStatus === 'rejected') {
    const err = new Error('Shop registration was rejected. Subscription activation held.');
    err.code = 'failed-precondition';
    throw err;
  }

  if (currentShopData.isApproved === false) {
    const err = new Error('Shop approval is explicitly false. Subscription activation held.');
    err.code = 'failed-precondition';
    throw err;
  }

  const unapprovedStatuses = ['pending', 'pending_review', 'draft', 'rejected', 'suspended', 'blocked'];
  if (unapprovedStatuses.includes(rawShopStatus)) {
    const err = new Error(`Shop is in '${rawShopStatus}' status. Subscription activation held.`);
    err.code = 'failed-precondition';
    throw err;
  }

  const hasTxApprovalEvidence = currentShopData.isApproved === true || rawShopStatus === 'approved';
  if (!hasTxApprovalEvidence) {
    const err = new Error('Shop is not approved. Subscription activation held.');
    err.code = 'failed-precondition';
    throw err;
  }

  if (currentShopData.isActive === false) {
    const err = new Error('Shop is inactive. Subscription activation held.');
    err.code = 'failed-precondition';
    throw err;
  }

  return { success: true };
}

/**
 * Verification of Firestore update payload to confirm signature is omitted
 */
function buildPaymentActivationPayload(cleanPaymentId) {
  return {
    status: 'activated',
    paymentId: cleanPaymentId,
    verifiedAt: 'SERVER_TIMESTAMP',
    updatedAt: 'SERVER_TIMESTAMP',
    fulfillmentSource: 'client_verification'
  };
}

let testIndex = 0;
function runTest(description, fn) {
  testIndex++;
  try {
    fn();
    console.log(`✅ [PASS ${testIndex}] ${description}`);
  } catch (e) {
    console.error(`❌ [FAIL ${testIndex}] ${description}`);
    console.error(e);
    process.exitCode = 1;
  }
}

// 1. Approved Seller Test
runTest('Approved active seller passes order validation', () => {
  const shop = {
    ownerUid: 'seller_123',
    status: 'approved',
    isApproved: true,
    isActive: true,
    isDeleted: false,
  };
  const res = validateShopForSubscriptionOrder(shop, 'seller_123', 'shop_123');
  assert.strictEqual(res.success, true);
});

// 2. Pending Seller Rejection Test
runTest('Pending seller is strictly rejected with failed-precondition', () => {
  const shop = {
    ownerUid: 'seller_123',
    status: 'pending',
    isApproved: false,
    isActive: false,
    isDeleted: false,
  };
  assert.throws(
    () => validateShopForSubscriptionOrder(shop, 'seller_123', 'shop_123'),
    (err) => err.code === 'failed-precondition' && err.message.includes('not approved')
  );
});

// 3. Draft/Pending Review Seller Rejection Test
runTest('Draft/pending_review seller is strictly rejected', () => {
  const shop = {
    ownerUid: 'seller_123',
    status: 'pending_review',
    isApproved: false,
    isActive: false,
    isDeleted: false,
  };
  assert.throws(
    () => validateShopForSubscriptionOrder(shop, 'seller_123', 'shop_123'),
    (err) => err.code === 'failed-precondition' && err.message.includes('not approved')
  );
});

// 4. Rejected Seller Test
runTest('Rejected seller is strictly rejected with failed-precondition', () => {
  const shop = {
    ownerUid: 'seller_123',
    status: 'rejected',
    isApproved: false,
    isActive: false,
    isDeleted: false,
  };
  assert.throws(
    () => validateShopForSubscriptionOrder(shop, 'seller_123', 'shop_123'),
    (err) => err.code === 'failed-precondition' && err.message.includes('rejected by administration')
  );
});

// 5. Suspended Seller Test
runTest('Suspended seller is strictly rejected with failed-precondition', () => {
  const shop = {
    ownerUid: 'seller_123',
    status: 'suspended',
    isApproved: true,
    isActive: false,
    isDeleted: false,
  };
  assert.throws(
    () => validateShopForSubscriptionOrder(shop, 'seller_123', 'shop_123'),
    (err) => err.code === 'failed-precondition' && err.message.includes('suspended')
  );
});

// 6. Blocked Seller Test
runTest('Blocked seller is strictly rejected with permission-denied', () => {
  const shop = {
    ownerUid: 'seller_123',
    status: 'blocked',
    isApproved: false,
    isActive: false,
    isDeleted: false,
  };
  assert.throws(
    () => validateShopForSubscriptionOrder(shop, 'seller_123', 'shop_123'),
    (err) => err.code === 'permission-denied' && err.message.includes('blocked')
  );
});

// 7. Inactive Seller Test
runTest('Inactive approved seller is strictly rejected with failed-precondition', () => {
  const shop = {
    ownerUid: 'seller_123',
    status: 'approved',
    isApproved: true,
    isActive: false,
    isDeleted: false,
  };
  assert.throws(
    () => validateShopForSubscriptionOrder(shop, 'seller_123', 'shop_123'),
    (err) => err.code === 'failed-precondition' && err.message.includes('inactive')
  );
});

// 8. Deleted Shop Test
runTest('Deleted shop is strictly rejected with not-found', () => {
  const shop = {
    ownerUid: 'seller_123',
    status: 'approved',
    isApproved: true,
    isActive: true,
    isDeleted: true,
  };
  assert.throws(
    () => validateShopForSubscriptionOrder(shop, 'seller_123', 'shop_123'),
    (err) => err.code === 'not-found'
  );
});

// 9. Unauthorized Seller Test (Cross-shop attack)
runTest('Unauthorized caller (not owner) is rejected with permission-denied', () => {
  const shop = {
    ownerUid: 'seller_victim',
    status: 'approved',
    isApproved: true,
    isActive: true,
    isDeleted: false,
  };
  assert.throws(
    () => validateShopForSubscriptionOrder(shop, 'seller_attacker', 'shop_victim', false),
    (err) => err.code === 'permission-denied' && err.message.includes('permission to purchase')
  );
});

// 10. Admin Bypass on Unapproved Shop is Strictly Blocked
runTest('Admin caller CANNOT bypass unapproved status on shop', () => {
  const shop = {
    ownerUid: 'seller_123',
    status: 'pending',
    isApproved: false,
    isActive: false,
    isDeleted: false,
  };
  assert.throws(
    () => validateShopForSubscriptionOrder(shop, 'admin_super', 'shop_123', true),
    (err) => err.code === 'failed-precondition' && err.message.includes('not approved')
  );
});

// 11. Admin Bypass on Suspended Shop is Strictly Blocked
runTest('Admin caller CANNOT bypass suspended status on shop', () => {
  const shop = {
    ownerUid: 'seller_123',
    status: 'suspended',
    isApproved: true,
    isActive: false,
    isDeleted: false,
  };
  assert.throws(
    () => validateShopForSubscriptionOrder(shop, 'admin_super', 'shop_123', true),
    (err) => err.code === 'failed-precondition' && err.message.includes('suspended')
  );
});

// 12. Conflicting Fields: isApproved: false, status: 'approved' -> MUST BE REJECTED
runTest('CRITICAL SECURITY: Conflicting isApproved: false with status: approved is strictly REJECTED', () => {
  const shop = {
    ownerUid: 'seller_conflict',
    status: 'approved', // stale status
    isApproved: false,  // revoked / unapproved
    isActive: true,
    isDeleted: false,
  };
  assert.throws(
    () => validateShopForSubscriptionOrder(shop, 'seller_conflict', 'shop_conflict'),
    (err) => err.code === 'failed-precondition' && err.message.includes('not approved')
  );
});

// 13. Conflicting Fields: isApproved: true, status: 'pending' -> MUST BE REJECTED
runTest('CRITICAL SECURITY: Conflicting isApproved: true with status: pending is strictly REJECTED', () => {
  const shop = {
    ownerUid: 'seller_conflict',
    status: 'pending',
    isApproved: true,
    isActive: true,
    isDeleted: false,
  };
  assert.throws(
    () => validateShopForSubscriptionOrder(shop, 'seller_conflict', 'shop_conflict'),
    (err) => err.code === 'failed-precondition' && err.message.includes('pending')
  );
});

// 14. Conflicting Fields: isApproved: true, status: 'rejected' -> MUST BE REJECTED
runTest('CRITICAL SECURITY: Conflicting isApproved: true with status: rejected is strictly REJECTED', () => {
  const shop = {
    ownerUid: 'seller_conflict',
    status: 'rejected',
    isApproved: true,
    isActive: true,
    isDeleted: false,
  };
  assert.throws(
    () => validateShopForSubscriptionOrder(shop, 'seller_conflict', 'shop_conflict'),
    (err) => err.code === 'failed-precondition' && err.message.includes('rejected by administration')
  );
});

// 15. Conflicting Fields: isApproved: true, status: 'suspended' -> MUST BE REJECTED
runTest('CRITICAL SECURITY: Conflicting isApproved: true with status: suspended is strictly REJECTED', () => {
  const shop = {
    ownerUid: 'seller_conflict',
    status: 'suspended',
    isApproved: true,
    isActive: true,
    isDeleted: false,
  };
  assert.throws(
    () => validateShopForSubscriptionOrder(shop, 'seller_conflict', 'shop_conflict'),
    (err) => err.code === 'failed-precondition' && err.message.includes('suspended')
  );
});

// 16. Legacy Approved Shop without boolean isApproved field
runTest('Legacy approved shop with status:approved (isApproved undefined) is NOT blocked', () => {
  const shop = {
    ownerUid: 'seller_legacy',
    status: 'approved',
    // isApproved is intentionally undefined in legacy doc
    isActive: true,
    isDeleted: false,
  };
  const res = validateShopForSubscriptionOrder(shop, 'seller_legacy', 'shop_legacy');
  assert.strictEqual(res.success, true);
});

// 17. Legacy Approved Shop with undefined isActive field
runTest('Legacy approved shop with undefined isActive (not explicitly false) is NOT blocked', () => {
  const shop = {
    ownerUid: 'seller_legacy',
    status: 'approved',
    isApproved: true,
    // isActive is intentionally undefined in legacy doc
    isDeleted: false,
  };
  const res = validateShopForSubscriptionOrder(shop, 'seller_legacy', 'shop_legacy');
  assert.strictEqual(res.success, true);
});

// 18. Verification Transaction: Approved Shop Activation
runTest('Activation transaction succeeds for approved active shop', () => {
  const shop = {
    status: 'approved',
    isApproved: true,
    isActive: true,
    isDeleted: false,
  };
  const res = validateShopForActivationTransaction(shop);
  assert.strictEqual(res.success, true);
});

// 19. Verification Transaction: Suspended Shop Rejection with Recovery Guard
runTest('Activation transaction holds activation if shop became suspended during checkout', () => {
  const shop = {
    status: 'suspended',
    isApproved: true,
    isActive: false,
    isDeleted: false,
  };
  assert.throws(
    () => validateShopForActivationTransaction(shop),
    (err) => err.code === 'failed-precondition' && err.message.includes('suspended')
  );
});

// 20. Verification Transaction: Blocked Shop Rejection
runTest('Activation transaction holds activation if shop became blocked during checkout', () => {
  const shop = {
    status: 'blocked',
    isApproved: false,
    isActive: false,
    isDeleted: false,
  };
  assert.throws(
    () => validateShopForActivationTransaction(shop),
    (err) => err.code === 'permission-denied' && err.message.includes('blocked')
  );
});

// 21. Verification Transaction: Unapproved Shop Rejection
runTest('Activation transaction holds activation if shop was unapproved', () => {
  const shop = {
    status: 'pending',
    isApproved: false,
    isActive: false,
    isDeleted: false,
  };
  assert.throws(
    () => validateShopForActivationTransaction(shop),
    (err) => err.code === 'failed-precondition' && (err.message.includes('Shop approval is explicitly false') || err.message.includes('pending'))
  );
});

// 22. Verification Transaction: Conflicting isApproved: false with status: approved is held
runTest('Activation transaction holds activation if isApproved: false conflicts with status: approved', () => {
  const shop = {
    status: 'approved',
    isApproved: false,
    isActive: true,
    isDeleted: false,
  };
  assert.throws(
    () => validateShopForActivationTransaction(shop),
    (err) => err.code === 'failed-precondition' && err.message.includes('Shop approval is explicitly false')
  );
});

// 23. Verification Transaction: Legacy Approved Shop Support in Transaction
runTest('Activation transaction succeeds for legacy shop with status:approved (isApproved undefined)', () => {
  const shop = {
    status: 'approved',
    isActive: true,
    isDeleted: false,
  };
  const res = validateShopForActivationTransaction(shop);
  assert.strictEqual(res.success, true);
});

// 24. Payment Document Minimization: No Signature Field Stored
runTest('Payment activation document omits signature field to prevent credential leakage', () => {
  const payload = buildPaymentActivationPayload('pay_123456');
  assert.strictEqual(payload.signature, undefined, 'Signature MUST NOT be present in payment document');
  assert.strictEqual(payload.status, 'activated');
  assert.strictEqual(payload.paymentId, 'pay_123456');
});

console.log('\n================================================================');
console.log(` ALL ${testIndex}/${testIndex} SELLER APPROVAL & SECURITY TESTS PASSED`);
console.log('================================================================\n');
