import fs from 'node:fs';
import path from 'node:path';

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

function copyDir(src, dest) {
  if (!fs.existsSync(src)) return false;
  fs.mkdirSync(dest, { recursive: true });
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    const s = path.join(src, entry.name);
    const d = path.join(dest, entry.name);
    if (entry.isDirectory()) copyDir(s, d);
    else fs.copyFileSync(s, d);
  }
  return true;
}

const repoRoot = findRepoRoot(process.cwd());
const doccHtml = path.join(repoRoot, 'build', 'docs', 'html');
const siteStatic = path.join(repoRoot, 'docs-site', 'static', 'docc');

const ok = copyDir(doccHtml, siteStatic);
console.log(ok ? `Imported DocC HTML -> ${siteStatic}` : 'No DocC HTML found; skipping import');
