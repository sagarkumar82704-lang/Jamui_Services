const fs = require('fs');
const path = require('path');

function searchCollection(dir, collName) {
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (!['node_modules', '.git', 'build', '.dart_tool', '.idea'].includes(entry.name)) {
        searchCollection(fullPath, collName);
      }
    } else if (entry.isFile() && (entry.name.endsWith('.dart') || entry.name.endsWith('.js'))) {
      const c = fs.readFileSync(fullPath, 'utf8');
      if (c.includes(`'${collName}'`) || c.includes(`"${collName}"`)) {
        console.log(`${collName} found in: ${fullPath}`);
      }
    }
  }
}

console.log('--- Services collection references ---');
searchCollection('.', 'services');
console.log('--- Categories collection references ---');
searchCollection('.', 'categories');
console.log('--- Providers collection references ---');
searchCollection('.', 'providers');
