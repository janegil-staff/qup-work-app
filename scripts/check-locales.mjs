// /qup-work-app/scripts/check-locales.mjs
// Checks every language file against en-US.json (the source):
//   - valid JSON, same keys in the same order, no empty values
//   - same {placeholders} as English
//   - every key used in the code exists, and no key is unused
//   - every language in src/i18n/languages.js has a file (and the other way round)
//
//   node scripts/check-locales.mjs
//   node scripts/check-locales.mjs --fix-order    → rewrite files with English key order
//
// Adding new text: put the key in en-US.json first, run this, then translate the missing keys.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const DIR = path.join(ROOT, 'src', 'locales');
const SOURCE = 'en-US.json';
const FIX_ORDER = process.argv.includes('--fix-order');

const placeholders = (s) => (s.match(/\{\w*\}/g) ?? []).sort().join(' ');
const problems = [];
const warn = (file, msg) => problems.push(`${file}: ${msg}`);

const en = JSON.parse(fs.readFileSync(path.join(DIR, SOURCE), 'utf8'));
const enKeys = Object.keys(en);
const files = fs.readdirSync(DIR).filter((f) => f.endsWith('.json')).sort();

for (const file of files) {
  let data;
  try {
    data = JSON.parse(fs.readFileSync(path.join(DIR, file), 'utf8'));
  } catch (err) {
    warn(file, `not valid JSON (${err.message})`);
    continue;
  }
  const keys = Object.keys(data);
  const missing = enKeys.filter((k) => !(k in data));
  const extra = keys.filter((k) => !(k in en));
  if (missing.length) warn(file, `missing ${missing.length} key(s): ${missing.join(', ')}`);
  if (extra.length) warn(file, `unknown key(s): ${extra.join(', ')}`);

  for (const k of enKeys) {
    if (!(k in data)) continue;
    if (typeof data[k] !== 'string' || !data[k].trim()) warn(file, `${k} is empty`);
    else if (placeholders(data[k]) !== placeholders(en[k])) {
      warn(file, `${k} has placeholders "${placeholders(data[k])}", English has "${placeholders(en[k])}"`);
    }
  }

  const inOrder = !missing.length && !extra.length && keys.every((k, i) => k === enKeys[i]);
  if (!inOrder && !missing.length && !extra.length) {
    if (FIX_ORDER) {
      const ordered = Object.fromEntries(enKeys.map((k) => [k, data[k]]));
      fs.writeFileSync(path.join(DIR, file), `${JSON.stringify(ordered, null, '\t')}\n`);
      console.log(`  ↕️  ${file}: key order fixed`);
    } else {
      warn(file, 'keys are not in the same order as en-US.json (run with --fix-order)');
    }
  }
}

// Keys used in the code
const codeFiles = [];
const walk = (dir) => {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory() && e.name !== 'locales') walk(p);
    else if (/\.(js|jsx|ts|tsx)$/.test(e.name)) codeFiles.push(p);
  }
};
walk(path.join(ROOT, 'src'));
const code = codeFiles.map((f) => fs.readFileSync(f, 'utf8')).join('\n');
const used = new Set([...code.matchAll(/'([A-Z][A-Z0-9_]+)'/g)].map((m) => m[1]));
// HTTP methods and company types (ENK, AS) look like keys but aren't
const ignore = new Set(['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'KEY', 'WELCOME', 'ENK', 'AS', 'ANS', 'DA', 'NUF']);
for (const k of used) if (!ignore.has(k) && !(k in en)) warn(SOURCE, `${k} is used in the code but missing`);
for (const k of enKeys) {
  // CAT_* keys are looked up from category slugs at runtime
  if (!k.startsWith('CAT_') && !used.has(k)) warn(SOURCE, `${k} is not used anywhere in the code`);
}

// languages.js ↔ files
const langs = fs.readFileSync(path.join(ROOT, 'src', 'i18n', 'languages.js'), 'utf8');
const listed = [...langs.matchAll(/code: '([a-z]{2}-[A-Z]{2})'/g)].map((m) => `${m[1]}.json`);
for (const f of listed) if (!files.includes(f)) warn('languages.js', `${f} is listed but the file is missing`);
for (const f of files) if (!listed.includes(f)) warn('languages.js', `${f} exists but isn't listed`);

console.log(`\n🌍 ${files.length} language files, ${enKeys.length} keys each\n`);
if (problems.length) {
  for (const p of problems) console.log(`  ❌ ${p}`);
  console.log(`\n${problems.length} problem(s)\n`);
  process.exit(1);
}
console.log('  ✅ all files complete and consistent\n');
