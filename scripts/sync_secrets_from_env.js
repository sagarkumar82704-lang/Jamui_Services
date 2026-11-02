const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const envPath = path.resolve('functions/.env');
if (!fs.existsSync(envPath)) {
  console.error('❌ functions/.env file not found!');
  process.exit(1);
}

const content = fs.readFileSync(envPath, 'utf8');
const lines = content.split('\n');
const envVars = {};

for (const line of lines) {
  const trimmed = line.trim();
  if (!trimmed || trimmed.startsWith('#')) continue;
  const idx = trimmed.indexOf('=');
  if (idx !== -1) {
    const key = trimmed.substring(0, idx).trim();
    const val = trimmed.substring(idx + 1).trim();
    envVars[key] = val;
  }
}

console.log('--- SYNCING SECRETS TO FIREBASE SECRET MANAGER ---');

const tmpDir = path.resolve('scratch_tmp_secrets');
if (!fs.existsSync(tmpDir)) fs.mkdirSync(tmpDir);

const keysToSync = ['RAZORPAY_KEY_ID', 'RAZORPAY_KEY_SECRET', 'RAZORPAY_WEBHOOK_SECRET'];

for (const key of keysToSync) {
  const val = envVars[key];
  if (!val || val.includes('यहाँ_अपना') || val.includes('paste_here')) {
    console.log(`⚠️ Skipping ${key}: Placeholder value detected.`);
    continue;
  }

  const tmpFile = path.join(tmpDir, `${key}.txt`);
  fs.writeFileSync(tmpFile, val, 'utf8');

  try {
    console.log(`⏳ Setting ${key}...`);
    execSync(`firebase functions:secrets:set ${key} --data-file "${tmpFile}" --force`, { stdio: 'inherit' });
    console.log(`✅ Successfully set ${key}!`);
  } catch (err) {
    console.error(`❌ Failed to set ${key}:`, err.message);
  } finally {
    if (fs.existsSync(tmpFile)) fs.unlinkSync(tmpFile);
  }
}

if (fs.existsSync(tmpDir)) {
  try { fs.rmdirSync(tmpDir); } catch (_) {}
}

console.log('\n--- SYNC COMPLETE ---');
