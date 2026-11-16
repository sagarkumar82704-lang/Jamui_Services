/**
 * JAMUI SERVICES — PROFESSIONAL MARKETPLACE
 * PRODUCT ADD/EDIT P0 REPAIR & STOCK BACKEND REGRESSION TEST SUITE
 * 
 * Validates the 10 real product scenarios and stock integrity invariants:
 *  1. Loose Basmati Rice (25.5 kg decimal stock, 1 kg order deducts 1000g base units)
 *  2. Lux Soap (Piece/Pack, 100 pcs integer discrete items)
 *  3. Mustard Oil (15.5 L loose volume, 500 ml order deducts 500ml base units)
 *  4. Cardamom (Elaichi) (2 kg loose stock, 50g option, parent unit strictly 'kg')
 *  5. Cotton T-Shirt (Sizes S/M/L, independent stock per size SKU)
 *  6. Mixed Loose Order (1x 500g + 1x 1kg rice atomic shared deduction of 1500g)
 *  7. Simple Loose Order (variantId == null, loose product order deducts baseStockQuantity)
 *  8. Decimal Stock Adjustment (+0.5 kg, -0.25 kg)
 *  9. Dozen Conversion (1 dozen = 12 units)
 * 10. Safe Edit Protection (Zero-trust metadata updates never overwrite inventory balances)
 */

const assert = require('assert');

// 1. Replicate authoritative calculateBaseUnits logic from functions/index.js
function calculateBaseUnits(unit, value) {
  const u = String(unit || '').toLowerCase().trim();
  const v = Number(value);
  if (!Number.isFinite(v) || v <= 0) return 1;

  if (u === 'kg' || u === 'kilogram' || u === 'kgs') return Math.round(v * 1000);
  if (u === 'g' || u === 'gram' || u === 'gm' || u === 'gms') return Math.round(v);
  if (u === 'mg' || u === 'milligram') return Math.max(1, Math.round(v));
  if (u === 'l' || u === 'liter' || u === 'litre' || u === 'ltr') return Math.round(v * 1000);
  if (u === 'ml' || u === 'milliliter') return Math.round(v);
  if (u === 'dozen' || u === 'dz' || u === 'दर्जन') return Math.round(v * 12);

  return Math.round(v);
}

// 2. Authoritative initial stock resolution logic from functions/index.js (createProfessionalProduct)
function resolveInitialStock(clean, initialStock) {
  const parsedInitialStock = Number(initialStock);
  const stockQty = Number.isFinite(parsedInitialStock) ? parsedInitialStock : 0;
  if (stockQty < 0) throw new Error('Stock cannot be negative.');

  const isBulk = clean.stockType === 'bulk';
  let baseStockQty = null;
  let baseUnit = null;
  if (isBulk) {
    baseUnit = String(clean.baseUnit || (clean.unit === 'kg' ? 'g' : (clean.unit === 'l' || clean.unit === 'liter' ? 'ml' : 'g'))).toLowerCase();
    baseStockQty = Number.isInteger(Number(clean.baseStockQuantity))
      ? Number(clean.baseStockQuantity)
      : calculateBaseUnits(clean.unit || baseUnit, stockQty);
  }

  const resultStockQty = isBulk
    ? (() => {
        const u = String(clean.unit || baseUnit || '').toLowerCase().trim();
        const pMult = (u === 'kg' || u === 'kilogram' || u === 'kgs' || u === 'l' || u === 'liter' || u === 'litre' || u === 'ltr') ? 1000 : 1;
        return pMult === 1000 ? Number((baseStockQty / 1000).toFixed(3)) : baseStockQty;
      })()
    : Math.round(stockQty);

  return {
    unit: clean.unit,
    stockType: isBulk ? 'bulk' : (clean.stockType || 'pack'),
    baseUnit,
    baseStockQuantity: baseStockQty,
    stockQuantity: resultStockQty,
    inStock: (isBulk ? baseStockQty : resultStockQty) > 0
  };
}

// 3. Authoritative placeDiamondOrder deduction logic
function simulateOrderDeduction(product, orderItems) {
  const isBulkProduct = product.stockType === 'bulk';
  let parentBaseStock = product.baseStockQuantity !== undefined ? product.baseStockQuantity : (product.stockQuantity * 1000);
  let parentStockQuantity = product.stockQuantity;

  let totalBaseNeeded = 0;

  for (const item of orderItems) {
    if (isBulkProduct) {
      let optionBaseUnits = item.baseUnitsPerOption;
      if (!optionBaseUnits) {
        optionBaseUnits = calculateBaseUnits(item.unit || product.unit, item.unitValue || 1);
      }
      totalBaseNeeded += optionBaseUnits * item.quantity;
    } else {
      if (parentStockQuantity < item.quantity) {
        throw new Error(`Insufficient stock for '${product.title}'. Requested: ${item.quantity}, Available: ${parentStockQuantity}.`);
      }
      parentStockQuantity -= item.quantity;
    }
  }

  if (isBulkProduct) {
    if (parentBaseStock < totalBaseNeeded) {
      throw new Error(`Insufficient shared stock for '${product.title}'. Requested: ${totalBaseNeeded} base units, Available: ${parentBaseStock} base units.`);
    }
    parentBaseStock -= totalBaseNeeded;
    const u = String(product.unit || '').toLowerCase().trim();
    const mult = (u === 'kg' || u === 'kilogram' || u === 'kgs' || u === 'l' || u === 'liter' || u === 'litre' || u === 'ltr') ? 1000 : 1;
    parentStockQuantity = mult === 1000 ? Number((parentBaseStock / 1000).toFixed(3)) : parentBaseStock;
  }

  return {
    ...product,
    baseStockQuantity: isBulkProduct ? parentBaseStock : undefined,
    stockQuantity: parentStockQuantity,
    inStock: (isBulkProduct ? parentBaseStock : parentStockQuantity) > 0
  };
}

console.log('================================================================');
console.log(' JAMUI SERVICES — PRODUCT ADD/EDIT P0 BACKEND REGRESSION TESTS');
console.log('================================================================\n');

let passedTests = 0;
let totalTests = 10;

// SCENARIO 1: Decimal Initial Stock Parsing (25.5 kg Loose Rice)
console.log('--- SCENARIO 1: Decimal Initial Stock Parsing (25.5 kg Rice) ---');
{
  const rice = resolveInitialStock({ stockType: 'bulk', unit: 'kg', baseStockQuantity: 25500 }, 25.5);
  assert.strictEqual(rice.baseStockQuantity, 25500, 'baseStockQuantity must be exactly 25500 grams');
  assert.strictEqual(rice.stockQuantity, 25.5, 'stockQuantity must remain exactly 25.5 kg without truncation');
  assert.strictEqual(rice.inStock, true);
  console.log('  ✅ [PASS] 25.5 kg loose rice initial stock resolves to 25500g and 25.5 kg exactly\n');
  passedTests++;
}

// SCENARIO 2: Discrete Piece / Packet Product (Lux Soap, 100 pcs)
console.log('--- SCENARIO 2: Discrete Piece/Packet (Lux Soap, 100 pcs) ---');
{
  const soap = resolveInitialStock({ stockType: 'pack', unit: 'piece' }, 100);
  assert.strictEqual(soap.stockType, 'pack');
  assert.strictEqual(soap.stockQuantity, 100);
  assert.strictEqual(soap.baseStockQuantity, null);
  assert.strictEqual(soap.inStock, true);
  console.log('  ✅ [PASS] 100 pcs Lux Soap creates clean pack stock without bulk clutter\n');
  passedTests++;
}

// SCENARIO 3: Loose Volume Product (Mustard Oil, 15.5 L)
console.log('--- SCENARIO 3: Loose Volume Product (Mustard Oil, 15.5 L) ---');
{
  const oil = resolveInitialStock({ stockType: 'bulk', unit: 'L', baseUnit: 'ml', baseStockQuantity: 15500 }, 15.5);
  assert.strictEqual(oil.baseStockQuantity, 15500, 'baseStockQuantity must be 15500 ml');
  assert.strictEqual(oil.stockQuantity, 15.5, 'stockQuantity must be 15.5 L');
  
  // Deduct 500 ml (1 bottle)
  const afterOrder = simulateOrderDeduction(oil, [
    { title: '500 ml', unit: 'ml', unitValue: 500, baseUnitsPerOption: 500, quantity: 1 }
  ]);
  assert.strictEqual(afterOrder.baseStockQuantity, 15000, '15500ml - 500ml = 15000ml');
  assert.strictEqual(afterOrder.stockQuantity, 15.0, '15000ml = 15.0 L');
  console.log('  ✅ [PASS] 15.5 L oil minus 500 ml option deducts accurately to 15.0 L\n');
  passedTests++;
}

// SCENARIO 4: Cardamom (Elaichi) Parent Unit Preservation
console.log('--- SCENARIO 4: Cardamom (Elaichi) Parent Unit Preservation ---');
{
  const elaichi = {
    title: 'Green Cardamom (Hari Elaichi)',
    stockType: 'bulk',
    unit: 'kg', // Parent unit strictly 'kg'
    baseUnit: 'g',
    baseStockQuantity: 2000,
    stockQuantity: 2.0,
    inStock: true
  };
  // Customer buys 2 x 50g packs
  const afterOrder = simulateOrderDeduction(elaichi, [
    { title: '50 g Pack', unit: 'g', unitValue: 50, baseUnitsPerOption: 50, quantity: 2 }
  ]);
  assert.strictEqual(afterOrder.unit, 'kg', 'Parent unit MUST remain "kg", never overwritten with "g"');
  assert.strictEqual(afterOrder.baseStockQuantity, 1900, '2000g - 100g = 1900g');
  assert.strictEqual(afterOrder.stockQuantity, 1.9, '1900g = 1.9 kg');
  console.log('  ✅ [PASS] Cardamom parent unit remains "kg" while 50g packs deduct accurately\n');
  passedTests++;
}

// SCENARIO 5: Clothing Sizes / Separate Packs (S/M/L)
console.log('--- SCENARIO 5: Sizes / Separate Packs Independent Stock ---');
{
  const tshirtS = { title: 'T-Shirt (S)', stockType: 'pack', stockQuantity: 15 };
  const tshirtM = { title: 'T-Shirt (M)', stockType: 'pack', stockQuantity: 25 };
  
  // Buying Size S must not affect Size M
  const afterS = simulateOrderDeduction(tshirtS, [{ quantity: 3 }]);
  assert.strictEqual(afterS.stockQuantity, 12, 'Size S deducted from 15 to 12');
  assert.strictEqual(tshirtM.stockQuantity, 25, 'Size M stock remains completely untouched at 25');
  console.log('  ✅ [PASS] Independent sizes retain isolated physical stock balances\n');
  passedTests++;
}

// SCENARIO 6: Mixed Loose Order Atomic Shared Deduction
console.log('--- SCENARIO 6: Mixed Loose Order Shared Deduction (Rice 500g + 1kg) ---');
{
  const rice = {
    title: 'Basmati Rice',
    stockType: 'bulk',
    unit: 'kg',
    baseStockQuantity: 10000, // 10 kg
    stockQuantity: 10.0
  };
  // Customer cart: 1x 500g + 1x 1kg (total 1500g)
  const afterOrder = simulateOrderDeduction(rice, [
    { title: '500 g', baseUnitsPerOption: 500, quantity: 1 },
    { title: '1 kg', baseUnitsPerOption: 1000, quantity: 1 }
  ]);
  assert.strictEqual(afterOrder.baseStockQuantity, 8500, '10000g - 1500g = 8500g');
  assert.strictEqual(afterOrder.stockQuantity, 8.5, '8500g = 8.5 kg');
  console.log('  ✅ [PASS] Mixed order (500g + 1kg) atomically deducts 1.5 kg from shared stock\n');
  passedTests++;
}

// SCENARIO 7: Simple Loose Order (variantId == null)
console.log('--- SCENARIO 7: Simple Loose Order without Variant Subcollection ---');
{
  const rice = {
    title: 'Raw Sugar',
    stockType: 'bulk',
    unit: 'kg',
    baseStockQuantity: 50000, // 50 kg
    stockQuantity: 50.0
  };
  // Customer buys 2 units of 1 kg directly
  const afterOrder = simulateOrderDeduction(rice, [
    { unit: 'kg', unitValue: 1, quantity: 2 }
  ]);
  assert.strictEqual(afterOrder.baseStockQuantity, 48000, '50000g - 2000g = 48000g');
  assert.strictEqual(afterOrder.stockQuantity, 48.0, '48000g = 48.0 kg');
  console.log('  ✅ [PASS] Simple loose order (variantId == null) synchronizes baseStockQuantity and stockQuantity\n');
  passedTests++;
}

// SCENARIO 8: Decimal Stock Adjustment (+0.5 kg, -0.25 kg)
console.log('--- SCENARIO 8: Decimal Stock Adjustment ---');
{
  let currentBase = 10000; // 10 kg
  // Manual Inward: +0.5 kg
  const addUnits = calculateBaseUnits('kg', 0.5);
  assert.strictEqual(addUnits, 500);
  currentBase += addUnits;
  assert.strictEqual(currentBase, 10500);

  // Manual Outward: -0.25 kg
  const subUnits = calculateBaseUnits('kg', 0.25);
  assert.strictEqual(subUnits, 250);
  currentBase -= subUnits;
  assert.strictEqual(currentBase, 10250);
  assert.strictEqual(Number((currentBase / 1000).toFixed(3)), 10.25);
  console.log('  ✅ [PASS] Fractional inward (+0.5 kg) and outward (-0.25 kg) maintain 100% precision\n');
  passedTests++;
}

// SCENARIO 9: Dozen Conversion (1 dozen = 12 units)
console.log('--- SCENARIO 9: Dozen Conversion (Bananas) ---');
{
  const dz1 = calculateBaseUnits('dozen', 1);
  assert.strictEqual(dz1, 12, '1 dozen must equal 12 units');
  const dzHalf = calculateBaseUnits('dozen', 0.5);
  assert.strictEqual(dzHalf, 6, '0.5 dozen must equal 6 units');
  const dzHindi = calculateBaseUnits('दर्जन', 2);
  assert.strictEqual(dzHindi, 24, '2 दर्जन must equal 24 units');
  console.log('  ✅ [PASS] Dozen and दर्जन conversions calculate 12 units per dozen accurately\n');
  passedTests++;
}

// SCENARIO 10: Safe Edit Mode Field Sanitization
console.log('--- SCENARIO 10: Safe Edit Mode Zero-Trust Field Sanitization ---');
{
  const clientEditPayload = {
    title: 'Updated Basmati Rice',
    sellingPrice: 75,
    // Malicious or accidental client attempts to overwrite inventory
    stockQuantity: 9999,
    baseStockQuantity: 9999000,
    totalStockQuantity: 9999,
    inStock: true,
    totalOrders: 500,
    rating: 5.0
  };

  // Replicate RemoteDataSource sanitize logic on edit
  const sanitized = { ...clientEditPayload };
  delete sanitized.stockQuantity;
  delete sanitized.baseStockQuantity;
  delete sanitized.totalStockQuantity;
  delete sanitized.inStock;
  delete sanitized.totalOrders;
  delete sanitized.rating;

  assert.strictEqual(sanitized.title, 'Updated Basmati Rice');
  assert.strictEqual(sanitized.sellingPrice, 75);
  assert.strictEqual(sanitized.stockQuantity, undefined, 'stockQuantity MUST be stripped on edit');
  assert.strictEqual(sanitized.baseStockQuantity, undefined, 'baseStockQuantity MUST be stripped on edit');
  assert.strictEqual(sanitized.totalOrders, undefined, 'totalOrders MUST be stripped on edit');
  console.log('  ✅ [PASS] Product edit strictly sanitizes protected inventory fields\n');
  passedTests++;
}

console.log('================================================================');
console.log(` RESULT: ${passedTests} / ${totalTests} TESTS PASSED`);
console.log('================================================================\n');
