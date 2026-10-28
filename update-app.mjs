// /qup-work-app/update-app.mjs
// Installs the new version of the app code into your Expo project.
// Run it from your project folder. It works wherever the script itself is:
//
//   node update-app.mjs                       → finds the download in ~/Downloads (or a nested folder)
//   node update-app.mjs --from ~/Desktop/qup-work-app   → use this download folder
//   node update-app.mjs --dry-run             → show what would happen, change nothing
//
// If you already copied the new src/ into the project yourself, it just cleans up
// the old files that clash with it (like the old src/app/(app) folder).
//
// What it does:
//   1. Moves your current src/ (and any old root app/, lib/, ... folders) to _backup_<time>/
//   2. Copies the new src/ in
//   3. Sets the @/ alias to src/ (jsconfig.json)
//   4. Checks package.json "main", app.json (scheme, plugins, light mode) and missing packages
// Nothing is deleted: everything that is replaced ends up in the backup folder.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const ROOT = process.cwd();
const DRY = process.argv.includes('--dry-run');
const fromArg = (() => {
  const i = process.argv.indexOf('--from');
  return i > -1 ? process.argv[i + 1] : undefined;
})();

// The new version is recognised by its tab layout
const isNewVersion = (dir) => fs.existsSync(path.join(dir, 'src', 'app', '(tabs)', '_layout.js'));

function findDownload() {
  if (fromArg) {
    const dir = path.resolve(fromArg.replace(/^~(?=$|\/)/, os.homedir()));
    if (!isNewVersion(dir)) {
      console.error(`❌ ${dir} doesn't contain the new app (no src/app/(tabs)). Point --from at the unzipped qup-work-app folder.`);
      process.exit(1);
    }
    return dir;
  }

  // Common places: unzipped inside the project, next to it, or in Downloads/Desktop
  // (macOS names repeated downloads "qup-work-app 2", "qup-work-app 3", ...)
  const candidates = [path.join(ROOT, 'qup-work-app')];
  for (const base of [path.dirname(ROOT), path.join(os.homedir(), 'Downloads'), path.join(os.homedir(), 'Desktop')]) {
    try {
      for (const name of fs.readdirSync(base)) {
        if (name.startsWith('qup-work-app')) candidates.push(path.join(base, name));
      }
    } catch {
      // folder doesn't exist or isn't readable
    }
  }
  const found = candidates
    .filter((dir) => path.resolve(dir) !== path.resolve(ROOT) && isNewVersion(dir))
    .sort((a, b) => fs.statSync(path.join(b, 'src')).mtimeMs - fs.statSync(path.join(a, 'src')).mtimeMs);
  return found[0] ?? null;
}
const OLD_ROOT_FOLDERS = ['app', 'components', 'constants', 'context', 'lib', 'hooks'];
const NEEDED_PACKAGES = [
  'expo-router', 'react-native-safe-area-context', 'react-native-screens', 'expo-linking',
  'expo-constants', 'expo-status-bar', 'expo-secure-store', '@expo/vector-icons',
  'expo-font', '@expo-google-fonts/archivo', 'react-native-svg',
];

const log = { done: [], skipped: [], warnings: [] };
const exists = (p) => fs.existsSync(p);
const readJson = (p) => JSON.parse(fs.readFileSync(p, 'utf8'));
const writeJson = (p, data) => {
  const text = `${JSON.stringify(data, null, 2)}\n`;
  if (exists(p) && fs.readFileSync(p, 'utf8') === text) return false;
  if (!DRY) fs.writeFileSync(p, text);
  return true;
};

// ---------------------------------------------------------------------------
// 0. Checks
// ---------------------------------------------------------------------------
const pkgPath = path.join(ROOT, 'package.json');
if (!exists(pkgPath) || !readJson(pkgPath).dependencies?.expo) {
  console.error('❌ Run this from your Expo project folder (the one with package.json and "expo" in it).');
  process.exit(1);
}
const FROM = findDownload();
const projectHasNewVersion = isNewVersion(ROOT);

if (!FROM && !projectHasNewVersion) {
  console.error('❌ Couldn\'t find the new app code.');
  console.error('   Unzip qup-work-app.zip, then tell the script where it is, for example:');
  console.error('   node update-app.mjs --from ~/Downloads/qup-work-app');
  process.exit(1);
}

const stamp = new Date().toISOString().slice(0, 19).replace(/[-:T]/g, '').replace(/(\d{8})(\d{6})/, '$1-$2');
const backup = path.join(ROOT, `_backup_${stamp}`);
const moveToBackup = (relPath) => {
  if (!DRY) {
    const target = path.join(backup, relPath);
    fs.mkdirSync(path.dirname(target), { recursive: true });
    fs.renameSync(path.join(ROOT, relPath), target);
  }
  log.done.push(`moved old ${relPath}/ to ${path.basename(backup)}/`);
};
const count = (dir) =>
  fs.readdirSync(dir, { withFileTypes: true }).reduce((n, e) => n + (e.isDirectory() ? count(path.join(dir, e.name)) : 1), 0);

if (FROM) {
  // ---------------------------------------------------------------------------
  // 1. Back up the old code   2. Copy the new src/
  // ---------------------------------------------------------------------------
  log.done.push(`using the new code from ${FROM}`);
  for (const name of ['src', ...OLD_ROOT_FOLDERS]) if (exists(path.join(ROOT, name))) moveToBackup(name);

  if (!DRY) fs.cpSync(path.join(FROM, 'src'), path.join(ROOT, 'src'), { recursive: true });
  log.done.push(`copied the new src/ (${count(path.join(FROM, 'src'))} files)`);

  // Helper scripts (e.g. scripts/check-locales.mjs); existing files with other names are kept
  if (exists(path.join(FROM, 'scripts'))) {
    if (!DRY) fs.cpSync(path.join(FROM, 'scripts'), path.join(ROOT, 'scripts'), { recursive: true });
    log.done.push('copied scripts/ (check-locales.mjs)');
  }

  // .env.example is handy to have; .env is never touched
  if (exists(path.join(FROM, '.env.example')) && !DRY) {
    fs.copyFileSync(path.join(FROM, '.env.example'), path.join(ROOT, '.env.example'));
  }
  if (path.dirname(path.resolve(FROM)) === path.resolve(ROOT)) {
    log.warnings.push(`The download is unzipped inside your project (${path.basename(FROM)}/). Delete that folder when you're happy.`);
  }
} else {
  // ---------------------------------------------------------------------------
  // The new src/ is already in the project: only clean up what clashes with it
  // ---------------------------------------------------------------------------
  log.done.push('the new src/ is already in place, cleaning up old files only');
  for (const name of OLD_ROOT_FOLDERS) if (exists(path.join(ROOT, name))) moveToBackup(name);
  // The old logged-in group: its index.js clashes with (tabs)/index.js on "/"
  for (const old of ['src/app/(app)', 'src/components/JobCard.js']) {
    if (exists(path.join(ROOT, old))) moveToBackup(old);
  }
}

// ---------------------------------------------------------------------------
// 3. @/ alias
// ---------------------------------------------------------------------------
const jsconfigPath = path.join(ROOT, 'jsconfig.json');
const jsconfig = exists(jsconfigPath) ? readJson(jsconfigPath) : {};
jsconfig.compilerOptions ??= {};
jsconfig.compilerOptions.baseUrl = '.';
jsconfig.compilerOptions.paths = { ...jsconfig.compilerOptions.paths, '@/*': ['./src/*'] };
if (writeJson(jsconfigPath, jsconfig)) log.done.push('jsconfig.json: @/* → ./src/*');
else log.skipped.push('jsconfig.json already correct');
if (exists(path.join(ROOT, 'tsconfig.json'))) {
  log.warnings.push('tsconfig.json exists and overrides jsconfig.json. Delete it (this is a JavaScript project).');
}

// ---------------------------------------------------------------------------
// 4. Expo Router setup
// ---------------------------------------------------------------------------
const pkg = readJson(pkgPath);
if (pkg.main !== 'expo-router/entry') {
  pkg.main = 'expo-router/entry';
  writeJson(pkgPath, pkg);
  log.done.push('package.json: "main": "expo-router/entry"');
}

const missing = NEEDED_PACKAGES.filter((d) => !pkg.dependencies?.[d]);
if (missing.length) log.warnings.push(`Install missing packages:\n       npx expo install ${missing.join(' ')}`);

const appJsonPath = path.join(ROOT, 'app.json');
if (exists(appJsonPath)) {
  const appJson = readJson(appJsonPath);
  const expo = (appJson.expo ??= {});
  const changes = [];
  if (!expo.scheme) (expo.scheme = 'qupwork'), changes.push('scheme');
  if (expo.userInterfaceStyle !== 'light') (expo.userInterfaceStyle = 'light'), changes.push('light mode');
  expo.plugins ??= [];
  for (const plugin of ['expo-router', 'expo-secure-store']) {
    if (!expo.plugins.some((p) => (Array.isArray(p) ? p[0] : p) === plugin)) {
      expo.plugins.push(plugin);
      changes.push(`plugin ${plugin}`);
    }
  }
  if (changes.length && writeJson(appJsonPath, appJson)) log.done.push(`app.json: ${changes.join(', ')}`);
  else log.skipped.push('app.json already set up');
}

for (const old of ['App.js', 'App.jsx', 'index.js']) {
  if (exists(path.join(ROOT, old))) log.warnings.push(`${old} isn't used with Expo Router, you can delete it.`);
}
if (!exists(path.join(ROOT, '.env'))) log.warnings.push('.env is missing: copy .env.example to .env and set EXPO_PUBLIC_API_URL.');

// ---------------------------------------------------------------------------
console.log(`\n🛠️  Qup Work app update${DRY ? ' (dry run, nothing changed)' : ''}\n`);
for (const m of log.done) console.log(`  ✅ ${DRY ? '(would) ' : ''}${m}`);
for (const m of log.skipped) console.log(`  ⏭️  ${m}`);
for (const m of log.warnings) console.log(`  ⚠️  ${m}`);
console.log(DRY ? '\nRun without --dry-run to apply.\n' : '\n🎉 Done. Start with a clean cache:  npx expo start -c\n');
