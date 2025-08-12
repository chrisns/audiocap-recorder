import fs from 'node:fs';
import path from 'node:path';

function findRepoRoot(startDir) {
  let dir = startDir;
  while (true) {
    if (fs.existsSync(path.join(dir, 'semver.yaml'))) return dir;
    const parent = path.dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }
  return startDir;
}

const repoRoot = findRepoRoot(process.cwd());
const semverPath = path.join(repoRoot, 'semver.yaml');
const content = fs.readFileSync(semverPath, 'utf8');
const match = content.match(/version:\s*"?([0-9]+\.[0-9]+\.[0-9]+)"?/);
if (!match) {
  console.error('version not found in semver.yaml');
  process.exit(1);
}
process.stdout.write(match[1]);
