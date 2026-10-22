// Bundles test/*.test.ts into .test-out/*.test.mjs for `node --test`.
import { build } from 'esbuild';
import { readdirSync, rmSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const out = join(root, '.test-out');
rmSync(out, { recursive: true, force: true });
const entries = readdirSync(join(root, 'test')).filter((f) => f.endsWith('.test.ts'));
await build({
  entryPoints: entries.map((f) => join(root, 'test', f)),
  outdir: out,
  outExtension: { '.js': '.mjs' },
  bundle: true,
  platform: 'node',
  format: 'esm',
  target: 'node22',
  define: { __DEV__: 'true', __VERSION__: '"test"', __M3U_WORKER_SRC__: '""' },
  logLevel: 'warning',
});
