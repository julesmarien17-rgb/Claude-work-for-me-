// Tiny static file helpers shared by the web app and the renderer.
import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

export const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
export const ENGINE_DIR = path.join(ROOT, 'engine');
export const OUTPUT_DIR = path.join(ROOT, 'output');
export const DATA_DIR = path.join(ROOT, 'data');

const require = createRequire(import.meta.url);
export const THREE_DIR = path.dirname(require.resolve('three'));

const TYPES = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8', '.json': 'application/json', '.mp4': 'video/mp4', '.jpg': 'image/jpeg', '.png': 'image/png', '.svg': 'image/svg+xml', '.wav': 'audio/wav', '.m4a': 'audio/mp4' };

export function sendFile(req, res, file) {
  fs.stat(file, (err, st) => {
    if (err || !st.isFile()) { res.writeHead(404); res.end('Not found'); return; }
    const type = TYPES[path.extname(file).toLowerCase()] || 'application/octet-stream';
    const range = req.headers.range;
    if (range && /^bytes=/.test(range)) {
      const [s, e] = range.replace('bytes=', '').split('-');
      const start = parseInt(s, 10) || 0, end = e ? parseInt(e, 10) : st.size - 1;
      res.writeHead(206, { 'Content-Type': type, 'Content-Range': `bytes ${start}-${end}/${st.size}`, 'Accept-Ranges': 'bytes', 'Content-Length': end - start + 1 });
      fs.createReadStream(file, { start, end }).pipe(res);
    } else {
      res.writeHead(200, { 'Content-Type': type, 'Content-Length': st.size, 'Accept-Ranges': 'bytes', 'Cache-Control': 'no-cache' });
      fs.createReadStream(file).pipe(res);
    }
  });
}

// Resolve a URL path safely inside a base directory.
export function safeJoin(base, p) {
  const full = path.resolve(base, '.' + path.posix.normalize('/' + decodeURIComponent(p)));
  return full.startsWith(base) ? full : null;
}

// Serves /engine/* and /vendor/three/* — used by the renderer and the web app.
export function serveEngine(req, res, urlPath) {
  if (urlPath.startsWith('/vendor/three/')) { const f = safeJoin(THREE_DIR, urlPath.slice('/vendor/three'.length)); return f ? (sendFile(req, res, f), true) : false; }
  if (urlPath.startsWith('/engine/')) { const f = safeJoin(ENGINE_DIR, urlPath.slice('/engine'.length)); return f ? (sendFile(req, res, f), true) : false; }
  return false;
}

export function startEngineServer() {
  return new Promise((resolve) => {
    const srv = http.createServer((req, res) => {
      const u = new URL(req.url, 'http://x');
      if (!serveEngine(req, res, u.pathname)) { res.writeHead(404); res.end(); }
    });
    srv.listen(0, '127.0.0.1', () => resolve({ server: srv, url: `http://127.0.0.1:${srv.address().port}` }));
  });
}
