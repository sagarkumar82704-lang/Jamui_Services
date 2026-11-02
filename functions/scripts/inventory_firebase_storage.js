const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'jamui-services',
    storageBucket: 'jamui-services.firebasestorage.app'
  });
}

async function listAllStorageFiles() {
  try {
    const bucket = admin.storage().bucket();
    console.log('Querying Firebase Storage bucket:', bucket.name);
    const [files] = await bucket.getFiles({ maxResults: 1000 });
    console.log(`\nFound ${files.length} total files in Firebase Storage:\n`);
    
    const categorized = {
      profile: [],
      business: [],
      certificates: [],
      kyc: [],
      categories: [],
      banners: [],
      reviews: [],
      others: []
    };

    let totalBytes = 0;

    files.forEach(file => {
      const size = Number(file.metadata.size || 0);
      totalBytes += size;
      const name = file.name;
      if (name.includes('/profile/') || name.startsWith('profile_images/')) {
        categorized.profile.push({ name, size });
      } else if (name.includes('/business/') || name.includes('/workplace/')) {
        categorized.business.push({ name, size });
      } else if (name.includes('/certificates/')) {
        categorized.certificates.push({ name, size });
      } else if (name.includes('/kyc/') || name.includes('kyc_documents/') || name.includes('aadhaar')) {
        categorized.kyc.push({ name, size });
      } else if (name.startsWith('categories/') || name.startsWith('category_images/')) {
        categorized.categories.push({ name, size });
      } else if (name.startsWith('banners/') || name.startsWith('sponsor_banners/')) {
        categorized.banners.push({ name, size });
      } else if (name.includes('review')) {
        categorized.reviews.push({ name, size });
      } else {
        categorized.others.push({ name, size });
      }
    });

    console.log(`SUMMARY OF FIREBASE STORAGE ASSETS:`);
    console.log(`- Profile Photos: ${categorized.profile.length} files`);
    console.log(`- Business Photos: ${categorized.business.length} files`);
    console.log(`- Certificates: ${categorized.certificates.length} files`);
    console.log(`- KYC Documents: ${categorized.kyc.length} files`);
    console.log(`- Categories: ${categorized.categories.length} files`);
    console.log(`- Banners: ${categorized.banners.length} files`);
    console.log(`- Reviews: ${categorized.reviews.length} files`);
    console.log(`- Others: ${categorized.others.length} files`);
    console.log(`Total Size: ${(totalBytes / 1024 / 1024).toFixed(2)} MB (${totalBytes} bytes)`);

    console.log('\n--- CERTIFICATES & KYC INVENTORY ---');
    [...categorized.certificates, ...categorized.kyc].forEach(f => {
      console.log(`  ${f.name} (${f.size} bytes)`);
    });

  } catch (err) {
    console.error('Error listing storage files:', err);
  }
}

listAllStorageFiles();
