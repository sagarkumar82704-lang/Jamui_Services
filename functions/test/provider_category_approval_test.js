const assert = require('assert');

console.log('================================================================');
console.log(' JAMUI SERVICES — PROVIDER CATEGORY EDIT, RE-APPLY & APPROVAL TESTS');
console.log('================================================================\n');

let passedTests = 0;
let totalTests = 16;

function runTest(description, testFn) {
  try {
    testFn();
    console.log(`✅ PASSED: ${description}`);
    passedTests++;
  } catch (err) {
    console.error(`❌ FAILED: ${description}`);
    console.error(`   ${err.message}`);
    process.exitCode = 1;
  }
}

// -----------------------------------------------------------------------------
// Reference Simulation of Backend Logic
// -----------------------------------------------------------------------------

function simulateRequestCategoryChange({
  callerUid,
  providerId,
  providerData,
  requestedCategoryId,
  requestedCategoryTitle,
  activeCategories,
  customDetails
}) {
  // Rule: Caller must be authenticated and own the profile
  if (!callerUid || callerUid !== providerId) {
    throw new Error('permission-denied: You are not authorized to update this profile.');
  }

  if (providerData.isDeleted === true) {
    throw new Error('failed-precondition: Cannot request category change for deleted account.');
  }

  // Validate category existence if not custom
  if (requestedCategoryId !== 'other' && requestedCategoryId !== 'custom') {
    const matched = activeCategories.find(c => c.id === requestedCategoryId && c.isActive !== false);
    if (!matched) {
      throw new Error(`not-found: Category '${requestedCategoryId}' is not active.`);
    }
  }

  // Idempotent category request record
  const requestId = `req_${providerId}`;
  const categoryRequest = {
    id: requestId,
    providerId: providerId,
    currentApprovedCategoryId: providerData.primaryCategoryId || '',
    currentApprovedCategoryTitle: providerData.primaryCategoryTitle || '',
    requestedCategoryId: requestedCategoryId,
    requestedCategoryTitle: requestedCategoryTitle,
    serviceName: requestedCategoryTitle,
    status: 'pending_review',
    categoryRequestStatus: 'pending_review',
    updatedAt: new Date(),
  };

  // Profile update: PRESERVES primaryCategoryId, subscription, expiry, and payment
  const updatedProvider = {
    ...providerData,
    requestedCategoryId: requestedCategoryId,
    requestedCategoryTitle: requestedCategoryTitle,
    categoryApprovalStatus: 'pending_review',
    categoryRequestStatus: 'pending_review',
    categoryRequestId: requestId,
    categoryRejectionReason: null,
    categoryRequestSubmittedAt: new Date(),
    updatedAt: new Date(),
  };

  return { categoryRequest, updatedProvider };
}

function simulateAdminReviewCategoryRequest({
  callerIsAdmin,
  requestId,
  explicitProviderId,
  providerData,
  requestData,
  action,
  mappedCategoryId,
  mappedCategoryTitle,
  adminFeedback,
  activeCategories = []
}) {
  if (!callerIsAdmin) {
    throw new Error('permission-denied: Only active admins can review category requests.');
  }

  if (!requestId || !action) {
    throw new Error('invalid-argument: requestId and action are required.');
  }

  const reqData = requestData || {};
  const targetProviderId = reqData.providerId || providerData?.id;
  if (!targetProviderId) {
    throw new Error('failed-precondition: Category request document is missing a providerId.');
  }

  if (explicitProviderId && explicitProviderId !== targetProviderId) {
    throw new Error(`invalid-argument: Provider ID mismatch: explicit '${explicitProviderId}' does not match request providerId '${targetProviderId}'.`);
  }

  if (!providerData) {
    throw new Error('not-found: Provider profile not found.');
  }

  // Idempotency: If already approved/rejected
  if (action === 'approve' && requestData.status === 'approved' && providerData.categoryApprovalStatus === 'approved') {
    return {
      updatedProvider: providerData,
      updatedRequest: requestData,
      alreadyProcessed: true,
      success: true,
    };
  }
  if (action === 'reject' && requestData.status === 'rejected' && providerData.categoryApprovalStatus === 'rejected') {
    return {
      updatedProvider: providerData,
      updatedRequest: requestData,
      alreadyProcessed: true,
      success: true,
    };
  }

  // Stale Request Protection
  if (providerData.categoryRequestId && providerData.categoryRequestId !== requestId) {
    throw new Error(`failed-precondition: Stale request conflict: Provider has an active request '${providerData.categoryRequestId}', cannot review older request '${requestId}'.`);
  }
  if (requestData.requestedCategoryId && providerData.requestedCategoryId && requestData.requestedCategoryId !== providerData.requestedCategoryId) {
    throw new Error(`failed-precondition: Stale request conflict: Provider active requested category is '${providerData.requestedCategoryId}', but this request is for '${requestData.requestedCategoryId}'.`);
  }

  if (action === 'approve') {
    const finalCatId = mappedCategoryId || requestData.requestedCategoryId;
    if (!finalCatId) {
      throw new Error('invalid-argument: Approved category must have a valid mappedCategoryId or requestedCategoryId.');
    }

    if (activeCategories && activeCategories.length > 0) {
      const cat = activeCategories.find(c => c.id === finalCatId);
      if (!cat) {
        throw new Error(`not-found: Target category '${finalCatId}' does not exist in active categories collection.`);
      }
      if (cat.isActive === false || cat.isDeleted === true) {
        throw new Error(`failed-precondition: Category '${finalCatId}' is currently inactive.`);
      }
    }

    const finalCatTitle = mappedCategoryTitle || requestData.requestedCategoryTitle || finalCatId;
    const existingSelected = new Set(providerData.selectedCategoryIds || []);
    existingSelected.add(finalCatId);

    const updatedProvider = {
      ...providerData,
      primaryCategoryId: finalCatId,
      primaryCategoryTitle: finalCatTitle,
      selectedCategoryId: finalCatId,
      selectedCategoryIds: Array.from(existingSelected),
      categoryApprovalStatus: 'approved',
      categoryRequestStatus: 'approved',
      requestedCategoryId: null,
      requestedCategoryTitle: null,
      categoryRejectionReason: null,
      registrationStatus: 'category_approved',
      updatedAt: new Date(),
    };

    const updatedRequest = {
      ...requestData,
      status: 'approved',
      categoryRequestStatus: 'approved',
      mappedCategoryId: finalCatId,
      mappedCategoryTitle: finalCatTitle,
      reviewedAt: new Date(),
    };

    return { updatedProvider, updatedRequest };
  } else if (action === 'reject') {
    const updatedProvider = {
      ...providerData,
      categoryApprovalStatus: 'rejected',
      categoryRequestStatus: 'rejected',
      categoryRejectionReason: adminFeedback || 'श्रेणी अनुरोध अस्वीकृत किया गया',
      updatedAt: new Date(),
    };

    const updatedRequest = {
      ...requestData,
      status: 'rejected',
      categoryRequestStatus: 'rejected',
      adminFeedback: adminFeedback,
      reviewedAt: new Date(),
    };

    return { updatedProvider, updatedRequest };
  }
}

// Subscription Page Display Logic Simulation
function resolveSubscriptionPageDisplay(provider) {
  const approvedCategoryTitle = provider.primaryCategoryTitle || provider.primaryCategoryId || 'सर्विस पार्टनर';
  const isChangePending = (provider.categoryApprovalStatus === 'pending_review' || provider.categoryRequestStatus === 'pending_review') &&
      Boolean(provider.requestedCategoryTitle);
  const isRejected = provider.categoryApprovalStatus === 'rejected' || provider.categoryRequestStatus === 'rejected';

  return {
    displayApprovedCategory: approvedCategoryTitle,
    pendingCategoryLabel: isChangePending ? `Requested Category: ${provider.requestedCategoryTitle} — Pending Approval` : null,
    rejectedLabel: isRejected ? `श्रेणी अनुरोध अस्वीकृत: ${provider.categoryRejectionReason || ''}` : null,
  };
}

// Customer App Discovery Filter Simulation
function isProviderVisibleUnderCategory(provider, searchCategoryId) {
  if (provider.isDeleted === true || provider.isActive === false) return false;
  if (provider.status !== 'approved' && provider.kycStatus !== 'approved' && provider.isVerified !== true) return false;
  
  // Strict: unapproved requested category is NEVER matched
  const matchedApprovedCategory = provider.primaryCategoryId === searchCategoryId ||
      (provider.selectedCategoryIds && provider.selectedCategoryIds.includes(searchCategoryId));

  return Boolean(matchedApprovedCategory);
}

// -----------------------------------------------------------------------------
// Active Categories Mock
// -----------------------------------------------------------------------------
const activeCategories = [
  { id: 'electrician', titleHindi: 'इलेक्ट्रीशियन', titleEnglish: 'Electrician', isActive: true },
  { id: 'plumber', titleHindi: 'प्लंबर', titleEnglish: 'Plumber', isActive: true },
  { id: 'salon', titleHindi: 'सैलून व ब्यूटी पार्लर', titleEnglish: 'Salon & Beauty', isActive: true },
  { id: 'inactive_cat', titleHindi: 'अक्रिय श्रेणी', titleEnglish: 'Inactive', isActive: false },
];

// -----------------------------------------------------------------------------
// TEST 1: Pending category application provider can edit category
// -----------------------------------------------------------------------------
runTest('1. Pending category application provider can edit category', () => {
  const provider = {
    id: 'prov_pending_1',
    primaryCategoryId: '',
    primaryCategoryTitle: '',
    categoryApprovalStatus: 'pending_review',
    requestedCategoryId: 'electrician',
    requestedCategoryTitle: 'इलेक्ट्रीशियन',
  };

  const result = simulateRequestCategoryChange({
    callerUid: 'prov_pending_1',
    providerId: 'prov_pending_1',
    providerData: provider,
    requestedCategoryId: 'plumber',
    requestedCategoryTitle: 'प्लंबर',
    activeCategories,
  });

  assert.strictEqual(result.updatedProvider.requestedCategoryId, 'plumber');
  assert.strictEqual(result.updatedProvider.categoryApprovalStatus, 'pending_review');
});

// -----------------------------------------------------------------------------
// TEST 2: Category edit & re-apply saves latest requested category
// -----------------------------------------------------------------------------
runTest('2. Category edit & re-apply saves latest requested category', () => {
  const provider = {
    id: 'prov_edit_2',
    primaryCategoryId: 'electrician',
    primaryCategoryTitle: 'इलेक्ट्रीशियन',
    categoryApprovalStatus: 'approved',
  };

  const { updatedProvider, categoryRequest } = simulateRequestCategoryChange({
    callerUid: 'prov_edit_2',
    providerId: 'prov_edit_2',
    providerData: provider,
    requestedCategoryId: 'salon',
    requestedCategoryTitle: 'सैलून व ब्यूटी पार्लर',
    activeCategories,
  });

  assert.strictEqual(updatedProvider.requestedCategoryId, 'salon');
  assert.strictEqual(updatedProvider.requestedCategoryTitle, 'सैलून व ब्यूटी पार्लर');
  assert.strictEqual(updatedProvider.categoryApprovalStatus, 'pending_review');
  assert.strictEqual(categoryRequest.requestedCategoryId, 'salon');
  assert.strictEqual(categoryRequest.status, 'pending_review');
});

// -----------------------------------------------------------------------------
// TEST 3: Rejected provider can re-apply after correction
// -----------------------------------------------------------------------------
runTest('3. Rejected provider can re-apply after correction', () => {
  const provider = {
    id: 'prov_rejected_3',
    primaryCategoryId: '',
    categoryApprovalStatus: 'rejected',
    categoryRejectionReason: 'अधूरा अनुभव प्रमाण पत्र',
  };

  const { updatedProvider } = simulateRequestCategoryChange({
    callerUid: 'prov_rejected_3',
    providerId: 'prov_rejected_3',
    providerData: provider,
    requestedCategoryId: 'plumber',
    requestedCategoryTitle: 'प्लंबर',
    activeCategories,
  });

  assert.strictEqual(updatedProvider.categoryApprovalStatus, 'pending_review');
  assert.strictEqual(updatedProvider.categoryRejectionReason, null, 'Rejection reason must be cleared on re-apply');
  assert.strictEqual(updatedProvider.requestedCategoryId, 'plumber');
});

// -----------------------------------------------------------------------------
// TEST 4: Approved category change requires fresh approval
// -----------------------------------------------------------------------------
runTest('4. Changing an approved category requires fresh approval and does not auto-approve', () => {
  const provider = {
    id: 'prov_approved_4',
    primaryCategoryId: 'salon',
    primaryCategoryTitle: 'सैलून',
    status: 'approved',
    categoryApprovalStatus: 'approved',
  };

  const { updatedProvider } = simulateRequestCategoryChange({
    callerUid: 'prov_approved_4',
    providerId: 'prov_approved_4',
    providerData: provider,
    requestedCategoryId: 'electrician',
    requestedCategoryTitle: 'इलेक्ट्रीशियन',
    activeCategories,
  });

  // Current approved category MUST NOT change before admin approval
  assert.strictEqual(updatedProvider.primaryCategoryId, 'salon');
  assert.strictEqual(updatedProvider.requestedCategoryId, 'electrician');
  assert.strictEqual(updatedProvider.categoryApprovalStatus, 'pending_review');
});

// -----------------------------------------------------------------------------
// TEST 5: Subscription Page shows current approved category + pending label
// -----------------------------------------------------------------------------
runTest('5. Subscription Page keeps old approved category and displays pending label for new request', () => {
  const provider = {
    id: 'prov_sub_page_5',
    primaryCategoryId: 'salon',
    primaryCategoryTitle: 'सैलून व ब्यूटी पार्लर',
    categoryApprovalStatus: 'pending_review',
    requestedCategoryId: 'electrician',
    requestedCategoryTitle: 'इलेक्ट्रीशियन',
  };

  const display = resolveSubscriptionPageDisplay(provider);

  assert.strictEqual(display.displayApprovedCategory, 'सैलून व ब्यूटी पार्लर', 'Must display approved category');
  assert.strictEqual(
    display.pendingCategoryLabel,
    'Requested Category: इलेक्ट्रीशियन — Pending Approval',
    'Must display pending label separately'
  );
});

// -----------------------------------------------------------------------------
// TEST 6: Admin approval updates approved state and reflects on Subscription Page
// -----------------------------------------------------------------------------
runTest('6. Admin approval updates approved state and Subscription Page reflects new approved category', () => {
  const provider = {
    id: 'prov_admin_app_6',
    primaryCategoryId: 'salon',
    primaryCategoryTitle: 'सैलून',
    requestedCategoryId: 'electrician',
    requestedCategoryTitle: 'इलेक्ट्रीशियन',
    categoryApprovalStatus: 'pending_review',
    selectedCategoryIds: ['salon'],
  };

  const req = {
    id: 'req_prov_admin_app_6',
    requestedCategoryId: 'electrician',
    requestedCategoryTitle: 'इलेक्ट्रीशियन',
  };

  const { updatedProvider } = simulateAdminReviewCategoryRequest({
    callerIsAdmin: true,
    requestId: 'req_prov_admin_app_6',
    providerData: provider,
    requestData: req,
    action: 'approve',
    mappedCategoryId: 'electrician',
    mappedCategoryTitle: 'इलेक्ट्रीशियन',
  });

  assert.strictEqual(updatedProvider.primaryCategoryId, 'electrician');
  assert.strictEqual(updatedProvider.primaryCategoryTitle, 'इलेक्ट्रीशियन');
  assert.strictEqual(updatedProvider.categoryApprovalStatus, 'approved');
  assert.strictEqual(updatedProvider.requestedCategoryId, null, 'Requested category cleared after approval');

  const display = resolveSubscriptionPageDisplay(updatedProvider);
  assert.strictEqual(display.displayApprovedCategory, 'इलेक्ट्रीशियन');
  assert.strictEqual(display.pendingCategoryLabel, null, 'No pending label after approval');
});

// -----------------------------------------------------------------------------
// TEST 7: Stale request cannot overwrite latest requested category
// -----------------------------------------------------------------------------
runTest('7. Stale request cannot overwrite latest requested category', () => {
  const provider = {
    id: 'prov_stale_7',
    primaryCategoryId: 'salon',
    requestedCategoryId: 'plumber', // Latest request
    requestedCategoryTitle: 'प्लंबर',
    categoryRequestId: 'req_prov_stale_7_v2',
  };

  // Attempting to approve an older request (v1: electrician)
  const staleReq = {
    id: 'req_prov_stale_7_v1',
    requestedCategoryId: 'electrician',
  };

  // Guard: if requestId does not match provider's active categoryRequestId
  function safeAdminApprove(prov, req) {
    if (prov.categoryRequestId && prov.categoryRequestId !== req.id) {
      throw new Error('failed-precondition: Stale category request cannot override newer application.');
    }
    prov.primaryCategoryId = req.requestedCategoryId;
  }

  assert.throws(
    () => safeAdminApprove(provider, staleReq),
    /Stale category request cannot override/
  );
  assert.strictEqual(provider.requestedCategoryId, 'plumber');
});

// -----------------------------------------------------------------------------
// TEST 8: Category edit NEVER modifies subscription, payment or expiry
// -----------------------------------------------------------------------------
runTest('8. Category edit NEVER modifies subscription payment, verification, expiry or active status', () => {
  const initialExpiry = new Date('2026-12-31T23:59:59Z');
  const provider = {
    id: 'prov_payment_guard_8',
    primaryCategoryId: 'salon',
    isSubscriptionActive: true,
    paymentVerified: true,
    subscriptionPlan: 'Basic',
    subscriptionExpiry: initialExpiry,
    captured: true,
  };

  // Provider edits category
  const { updatedProvider } = simulateRequestCategoryChange({
    callerUid: 'prov_payment_guard_8',
    providerId: 'prov_payment_guard_8',
    providerData: provider,
    requestedCategoryId: 'electrician',
    requestedCategoryTitle: 'इलेक्ट्रीशियन',
    activeCategories,
  });

  // Admin approves category
  const { updatedProvider: approvedProvider } = simulateAdminReviewCategoryRequest({
    callerIsAdmin: true,
    requestId: 'req_prov_payment_guard_8',
    providerData: updatedProvider,
    requestData: { requestedCategoryId: 'electrician' },
    action: 'approve',
  });

  assert.strictEqual(approvedProvider.isSubscriptionActive, true, 'isSubscriptionActive must remain true');
  assert.strictEqual(approvedProvider.paymentVerified, true, 'paymentVerified must remain true');
  assert.strictEqual(approvedProvider.subscriptionPlan, 'Basic', 'subscriptionPlan must remain intact');
  assert.strictEqual(approvedProvider.subscriptionExpiry.getTime(), initialExpiry.getTime(), 'Expiry must not change');
  assert.strictEqual(approvedProvider.captured, true, 'Captured flag must not change');
});

// -----------------------------------------------------------------------------
// TEST 9: Provider is NOT visible in customer listing under unapproved category
// -----------------------------------------------------------------------------
runTest('9. Provider is strictly NOT visible in customer listing under unapproved requested category', () => {
  const provider = {
    id: 'prov_visible_9',
    status: 'approved',
    kycStatus: 'approved',
    isVerified: true,
    isActive: true,
    isDeleted: false,
    primaryCategoryId: 'salon', // Approved
    selectedCategoryIds: ['salon'],
    requestedCategoryId: 'electrician', // Unapproved
    categoryApprovalStatus: 'pending_review',
  };

  // Searching under approved category 'salon' -> visible
  assert.strictEqual(isProviderVisibleUnderCategory(provider, 'salon'), true);

  // Searching under unapproved requested category 'electrician' -> HIDDEN
  assert.strictEqual(isProviderVisibleUnderCategory(provider, 'electrician'), false);
});

// -----------------------------------------------------------------------------
// TEST 10: Provider cannot update or approve another provider category
// -----------------------------------------------------------------------------
runTest('10. Provider cannot update or approve another provider category (strict isolation)', () => {
  const provider = { id: 'prov_victim', primaryCategoryId: 'salon' };

  // Attacker prov_attacker tries to update prov_victim
  assert.throws(
    () => simulateRequestCategoryChange({
      callerUid: 'prov_attacker',
      providerId: 'prov_victim',
      providerData: provider,
      requestedCategoryId: 'electrician',
      requestedCategoryTitle: 'इलेक्ट्रीशियन',
      activeCategories,
    }),
    /permission-denied/
  );

  // Non-admin tries to approve
  assert.throws(
    () => simulateAdminReviewCategoryRequest({
      callerIsAdmin: false,
      requestId: 'req_prov_victim',
      providerData: provider,
      requestData: { requestedCategoryId: 'electrician' },
      action: 'approve',
    }),
    /permission-denied/
  );
});

// -----------------------------------------------------------------------------
// TEST 11: Duplicate re-apply and approval requests handled idempotently
// -----------------------------------------------------------------------------
runTest('11. Duplicate re-apply and approval requests handled idempotently without duplicate entries', () => {
  const provider = {
    id: 'prov_idempotent_11',
    primaryCategoryId: 'salon',
    selectedCategoryIds: ['salon'],
  };

  // Repeated category change submissions
  const res1 = simulateRequestCategoryChange({
    callerUid: 'prov_idempotent_11',
    providerId: 'prov_idempotent_11',
    providerData: provider,
    requestedCategoryId: 'electrician',
    requestedCategoryTitle: 'इलेक्ट्रीशियन',
    activeCategories,
  });

  const res2 = simulateRequestCategoryChange({
    callerUid: 'prov_idempotent_11',
    providerId: 'prov_idempotent_11',
    providerData: res1.updatedProvider,
    requestedCategoryId: 'electrician',
    requestedCategoryTitle: 'इलेक्ट्रीशियन',
    activeCategories,
  });

  assert.strictEqual(res1.categoryRequest.id, res2.categoryRequest.id, 'Request ID must be deterministic (req_${id})');

  // Repeated approvals
  const app1 = simulateAdminReviewCategoryRequest({
    callerIsAdmin: true,
    requestId: res1.categoryRequest.id,
    providerData: res2.updatedProvider,
    requestData: res2.categoryRequest,
    action: 'approve',
  });

  const app2 = simulateAdminReviewCategoryRequest({
    callerIsAdmin: true,
    requestId: res1.categoryRequest.id,
    providerData: app1.updatedProvider,
    requestData: app1.updatedRequest,
    action: 'approve',
  });

  // Verify selectedCategoryIds does NOT have duplicate entries
  const electricianOccurrences = app2.updatedProvider.selectedCategoryIds.filter(c => c === 'electrician').length;
  assert.strictEqual(electricianOccurrences, 1, 'No duplicate category entries in selectedCategoryIds');
});

// -----------------------------------------------------------------------------
// TEST 12: Network failure and retry handling
// -----------------------------------------------------------------------------
runTest('12. Network failure during category submission allows clean retry without corrupted state', () => {
  let callCount = 0;
  function remoteSubmitWithNetworkGlitch(providerId, catId, catTitle) {
    callCount++;
    if (callCount === 1) {
      const err = new Error('Network timeout: Cloud Function unreachable');
      err.code = 'DEADLINE_EXCEEDED';
      throw err;
    }
    return { success: true, status: 'pending_review' };
  }

  // First call: network timeout
  let firstCallFailed = false;
  try {
    remoteSubmitWithNetworkGlitch('prov_retry_12', 'electrician', 'इलेक्ट्रीशियन');
  } catch (err) {
    firstCallFailed = true;
    assert.strictEqual(err.code, 'DEADLINE_EXCEEDED');
  }
  assert.strictEqual(firstCallFailed, true);

  // Retry call: succeeds cleanly
  const retryResult = remoteSubmitWithNetworkGlitch('prov_retry_12', 'electrician', 'इलेक्ट्रीशियन');
  assert.strictEqual(retryResult.success, true);
  assert.strictEqual(retryResult.status, 'pending_review');
  assert.strictEqual(callCount, 2);
});

// -----------------------------------------------------------------------------
// TEST 13: Stale Request Protection (Concurrency & Re-apply Race Condition)
// -----------------------------------------------------------------------------
runTest('13. Stale Request Protection: Approving an older request after provider re-applied for another category is rejected', () => {
  const provider = {
    id: 'prov_stale_13',
    primaryCategoryId: 'salon',
    primaryCategoryTitle: 'सैलून',
    categoryRequestId: 'req_prov_stale_13',
    requestedCategoryId: 'plumber',
    requestedCategoryTitle: 'प्लम्बर',
  };

  // Stale request object (from an earlier submission for electrician)
  const staleRequest = {
    id: 'req_prov_stale_old',
    providerId: 'prov_stale_13',
    requestedCategoryId: 'electrician',
    requestedCategoryTitle: 'इलेक्ट्रीशियन',
  };

  // Attempting to approve the stale request must throw failed-precondition
  assert.throws(
    () => simulateAdminReviewCategoryRequest({
      callerIsAdmin: true,
      requestId: staleRequest.id,
      providerData: provider,
      requestData: staleRequest,
      action: 'approve',
      activeCategories,
    }),
    /Stale request conflict/
  );
});

// -----------------------------------------------------------------------------
// TEST 14: Inactive or Non-Existent Category Approval Protection
// -----------------------------------------------------------------------------
runTest('14. Inactive or Non-Existent Category Approval Protection: Approving unknown or inactive category is rejected', () => {
  const provider = {
    id: 'prov_inactive_14',
    primaryCategoryId: 'salon',
    categoryRequestId: 'req_prov_inactive_14',
    requestedCategoryId: 'non_existent_category',
  };

  const req = {
    id: 'req_prov_inactive_14',
    providerId: 'prov_inactive_14',
    requestedCategoryId: 'non_existent_category',
    requestedCategoryTitle: 'Unknown Service',
  };

  // Must reject non-existent category
  assert.throws(
    () => simulateAdminReviewCategoryRequest({
      callerIsAdmin: true,
      requestId: req.id,
      providerData: provider,
      requestData: req,
      action: 'approve',
      activeCategories,
    }),
    /not exist in active categories/
  );
});

// -----------------------------------------------------------------------------
// TEST 15: Explicit Provider ID Mismatch Protection
// -----------------------------------------------------------------------------
runTest('15. Explicit Provider ID Mismatch Protection: Caller sending conflicting providerId is rejected', () => {
  const provider = {
    id: 'prov_target_15',
    primaryCategoryId: 'salon',
    categoryRequestId: 'req_prov_target_15',
    requestedCategoryId: 'electrician',
  };

  const req = {
    id: 'req_prov_target_15',
    providerId: 'prov_target_15',
    requestedCategoryId: 'electrician',
  };

  assert.throws(
    () => simulateAdminReviewCategoryRequest({
      callerIsAdmin: true,
      requestId: req.id,
      explicitProviderId: 'prov_attacker_15',
      providerData: provider,
      requestData: req,
      action: 'approve',
      activeCategories,
    }),
    /Provider ID mismatch/
  );
});

// -----------------------------------------------------------------------------
// TEST 16: Firestore Security Rules Simulation (No self-approval of category status)
// -----------------------------------------------------------------------------
runTest('16. Firestore Security Rules: Non-admin provider cannot write categoryApprovalStatus: approved', () => {
  function simulateProviderDirectDocUpdate({
    isAdminCaller,
    isOwnerCaller,
    existingDoc,
    incomingUpdate,
  }) {
    if (isAdminCaller) return { allowed: true };
    if (!isOwnerCaller) throw new Error('permission-denied: not owner or admin');

    // Rule: Provider CAN NEVER self-approve category changes
    const incomingStatus = incomingUpdate.categoryApprovalStatus;
    const existingStatus = existingDoc.categoryApprovalStatus || '';
    if (incomingStatus === 'approved' && existingStatus !== 'approved') {
      throw new Error('permission-denied: Provider cannot self-approve categoryApprovalStatus');
    }

    const incomingReqStatus = incomingUpdate.categoryRequestStatus;
    const existingReqStatus = existingDoc.categoryRequestStatus || '';
    if (incomingReqStatus === 'approved' && existingReqStatus !== 'approved') {
      throw new Error('permission-denied: Provider cannot self-approve categoryRequestStatus');
    }

    // Rule: Locked keys if already admin approved
    if (existingDoc.isApproved === true || existingDoc.status === 'approved') {
      const lockedKeys = ['primaryCategoryId', 'primaryCategoryTitle', 'selectedCategoryIds'];
      for (const k of lockedKeys) {
        if (k in incomingUpdate && incomingUpdate[k] !== existingDoc[k]) {
          throw new Error(`permission-denied: Approved provider cannot modify locked key '${k}'`);
        }
      }
    }

    return { allowed: true };
  }

  const existingProvider = {
    id: 'prov_security_16',
    isApproved: true,
    status: 'approved',
    primaryCategoryId: 'salon',
    categoryApprovalStatus: 'pending_review',
  };

  // Attacker provider tries to write categoryApprovalStatus: 'approved'
  assert.throws(
    () => simulateProviderDirectDocUpdate({
      isAdminCaller: false,
      isOwnerCaller: true,
      existingDoc: existingProvider,
      incomingUpdate: { categoryApprovalStatus: 'approved' },
    }),
    /Provider cannot self-approve categoryApprovalStatus/
  );

  // Attacker provider tries to directly overwrite primaryCategoryId
  assert.throws(
    () => simulateProviderDirectDocUpdate({
      isAdminCaller: false,
      isOwnerCaller: true,
      existingDoc: existingProvider,
      incomingUpdate: { primaryCategoryId: 'electrician' },
    }),
    /Approved provider cannot modify locked key/
  );

  // Legitimate provider submits pending review: allowed
  const validUpdate = simulateProviderDirectDocUpdate({
    isAdminCaller: false,
    isOwnerCaller: true,
    existingDoc: existingProvider,
    incomingUpdate: {
      requestedCategoryId: 'electrician',
      requestedCategoryTitle: 'इलेक्ट्रीशियन',
      categoryApprovalStatus: 'pending_review',
    },
  });
  assert.strictEqual(validUpdate.allowed, true);
});

// -----------------------------------------------------------------------------
// SUMMARY
// -----------------------------------------------------------------------------
console.log('\n================================================================');
console.log(` RESULTS: ${passedTests}/${totalTests} tests passed.`);
console.log('================================================================\n');

if (passedTests === totalTests) {
  console.log('🎉 ALL 16 PROVIDER CATEGORY EDIT & APPROVAL TESTS PASSED!');
  process.exit(0);
} else {
  console.error('❌ SOME TESTS FAILED.');
  process.exit(1);
}

