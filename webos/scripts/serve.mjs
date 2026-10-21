// Local test server for desktop browsers (no dependencies).
//
// Serves dist/ and reverse-proxies every other path (player_api.php,
// get.php, xmltv.php, /live, /movie, /series, images...) to an IPTV backend,
// by default the Flutter repo's mock server on :8787. The app then talks to
// its own origin, so the browser needs no CORS headers from the backend.
//
//   PORT=8080 TARGET=http://127.0.0.1:8787 node scripts/serve.mjs
//   -> add an Xtream playlist with server http://localhost:8080
import { createServer, request } from 'node:http';
import { createReadStream, statSync } from 'node:fs';
import { dirname, extname, join, normalize } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', 'dist');
const port = Number(process.env.PORT || 8080);
const target = new URL(process.env.TARGET || 'http://127.0.0.1:8787');
const types = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.css': 'text/css',
  '.json': 'application/json', '.png': 'image/png', '.ttf': 'font/ttf', '.txt': 'text/plain',
};

function staticFile(pathname) {
  const rel = normalize(pathname === '/' ? '/index.html' : decodeURIComponent(pathname));
  if (rel.includes('..')) return null;
  const file = join(root, rel);
  try {
    return statSync(file).isFile() ? file : null;
  } catch {
    return null;
  }
}

createServer((req, res) => {
  const url = new URL(req.url, 'http://local');
  const file = staticFile(url.pathname);
  if (file) {
    res.writeHead(200, { 'content-type': types[extname(file)] || 'application/octet-stream', 'cache-control': 'no-store' });
    createReadStream(file).pipe(res);
    return;
  }
  const headers = { ...req.headers, host: target.host };
  const up = request(
    { protocol: target.protocol, hostname: target.hostname, port: target.port, method: req.method, path: req.url, headers },
    (upRes) => {
      res.writeHead(upRes.statusCode || 502, upRes.headers);
      upRes.pipe(res);
    },
  );
  up.on('error', (e) => {
    res.writeHead(502, { 'content-type': 'text/plain' });
    res.end(`proxy error: ${e.message}`);
  });
  req.pipe(up);
}).listen(port, () => {
  console.log(`Carina webOS on http://localhost:${port}  (proxy -> ${target.origin})`);
});
