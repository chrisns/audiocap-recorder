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

const cwd = process.cwd();
const repoRoot = findRepoRoot(cwd);
const docsRoot = path.join(repoRoot, 'build', 'docs');
const htmlRoot = path.join(docsRoot, 'html');
const outputPath = path.join(docsRoot, 'search-index.json');

function walk(dir) {
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) files.push(...walk(full));
    else files.push(full);
  }
  return files;
}

function readText(filePath) {
  try {
    return fs.readFileSync(filePath, 'utf8');
  } catch {
    return '';
  }
}

function extractTextFromHTML(html) {
  const text = html
    .replace(/<script[\s\S]*?<\/script>/g, ' ')
    .replace(/<style[\s\S]*?<\/style>/g, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  return text;
}

function main() {
  if (!fs.existsSync(htmlRoot)) {
    console.error(`HTML root not found: ${htmlRoot}`);
    process.exit(1);
  }

  const htmlFiles = walk(htmlRoot).filter(f => f.endsWith('.html'));
  const documents = htmlFiles.map((file, i) => {
    const rel = path.relative(htmlRoot, file);
    const content = readText(file);
    const body = extractTextFromHTML(content);
    return { id: String(i), path: rel, body };
  }).filter(d => d.body.length > 0);

  const idx = lunr(function () {
    this.ref('id');
    this.field('body');
    this.field('path');
    for (const doc of documents) this.add(doc);
  });

  const indexPayload = {
    createdAt: new Date().toISOString(),
    numDocs: documents.length,
    index: idx.toJSON(),
    docs: documents.map(({ id, path }) => ({ id, path }))
  };

  fs.mkdirSync(docsRoot, { recursive: true });
  fs.writeFileSync(outputPath, JSON.stringify(indexPayload));
  console.log(`Search index written: ${outputPath} (docs=${documents.length})`);
}

main();
