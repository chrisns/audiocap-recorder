import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

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
const siteRoot = path.join(repoRoot, 'docs-site');
const readVersion = spawnSync('node', ['scripts/read-version.mjs'], { cwd: siteRoot, encoding: 'utf8' });
const version = readVersion.stdout.trim();

const buildDir = path.join(siteRoot, 'build');
const versionsPath = path.join(buildDir, 'versions.json');

fs.mkdirSync(buildDir, { recursive: true });
let existing = [];
if (fs.existsSync(versionsPath)) {
  try { existing = JSON.parse(fs.readFileSync(versionsPath, 'utf8')); } catch {}
}

const latest = version;

function toRelativeUrl(u) {
  if (!u || typeof u !== "string") return "./";
  // Normalize to a path relative to the site baseUrl
  if (u.startsWith("http://") || u.startsWith("https://")) return u; // leave external URLs
  if (u.startsWith("/")) {
    // Strip any leading path and keep only the tail after '/docs/' if present
    const idx = u.indexOf("/docs/");
    if (idx >= 0) return "." + u.slice(idx + "/docs".length);
    return "." + u; // make relative
  }
  return u; // already relative
}

const entries = [
  { version, url: `./v${version}/`, latest: true },
  ...existing
    .filter((v) => v.version !== version)
    .map((v) => ({
      ...v,
      url: toRelativeUrl(v.url),
      latest: v.version === latest,
    })),
];

fs.writeFileSync(versionsPath, JSON.stringify(entries, null, 2));
console.log(`versions.json updated at ${versionsPath}`);
