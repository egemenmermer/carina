// Builds the webOS app into dist/: bundles src/ for Chrome 53 (webOS 4.x),
// copies the static files (appinfo.json, icons, index.html) and the Inter
// font files from the Flutter app's assets.
import { build } from 'esbuild';
import { cpSync, mkdirSync, rmSync, readFileSync, writeFileSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const dist = join(root, 'dist');
const dev = process.argv.includes('--dev');
const pkg = JSON.parse(readFileSync(join(root, 'package.json'), 'utf8'));

rmSync(dist, { recursive: true, force: true });
mkdirSync(join(dist, 'fonts'), { recursive: true });

await build({
  entryPoints: { app: join(root, 'src/main.ts') },
  outdir: dist,
  bundle: true,
  format: 'iife',
  target: ['chrome53'],
  minify: !dev,
  sourcemap: dev ? 'inline' : false,
  legalComments: 'none',
  define: {
    __DEV__: String(dev),
    __VERSION__: JSON.stringify(pkg.version),
  },
  logLevel: 'warning',
});

// Static files. appinfo.json gets the package version so both stay in sync.
cpSync(join(root, 'static'), dist, { recursive: true });
const appinfoPath = join(dist, 'appinfo.json');
const appinfo = JSON.parse(readFileSync(appinfoPath, 'utf8'));
appinfo.version = pkg.version;
writeFileSync(appinfoPath, JSON.stringify(appinfo, null, 2) + '\n');

// Inter (OFL) from the Flutter app; falls back to the system font if missing.
const fonts = join(root, '..', 'assets', 'fonts', 'inter');
for (const f of ['Inter-Regular.ttf', 'Inter-Medium.ttf', 'Inter-SemiBold.ttf', 'Inter-Bold.ttf', 'OFL.txt']) {
  const src = join(fonts, f);
  if (existsSync(src)) cpSync(src, join(dist, 'fonts', f));
  else console.warn(`warning: font ${f} not found, using the system font`);
}

// Chrome 53 has no regex lookbehind or named groups; fail loudly if any slipped in.
const js = readFileSync(join(dist, 'app.js'), 'utf8');
if (/\(\?<[=!a-zA-Z]/.test(js)) {
  console.error('error: bundle contains regex lookbehind/named groups (unsupported on Chrome 53)');
  process.exit(1);
}
console.log(`built dist/ (v${pkg.version}${dev ? ', dev' : ''}): app.js ${(js.length / 1024).toFixed(1)} KB`);
