import fs from 'node:fs';
import path from 'node:path';
import lunr from 'lunr';

function findRepoRoot(startDir) {
  let dir = startDir;
  while (true) {
    if (fs.existsSync(path.join(dir, 'Package.swift'))) return dir;
    const parent = path.dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }
  return startDir;
}

const repoRoot = findRepoRoot(process.cwd());
const indexPath = path.join(repoRoot, 'build', 'docs', 'search-index.json');
if (!fs.existsSync(indexPath)) {
  console.error(`Index not found: ${indexPath}`);
  process.exit(1);
}
const payload = JSON.parse(fs.readFileSync(indexPath, 'utf8'));
const idx = lunr.Index.load(payload.index);

const query = process.argv[2] || 'AudioCapRecorder';
const start = process.hrtime.bigint();
const results = idx.search(query);
const end = process.hrtime.bigint();
const ms = Number(end - start) / 1e6;
console.log(`Query: "${query}" → ${results.length} results in ${ms.toFixed(2)} ms`);
if (ms > 200) {
  console.error('Search slower than 200 ms');
  process.exit(2);
}
