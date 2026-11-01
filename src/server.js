// Web app: type a prompt, the bot makes the video, watch & download it.
// Start with:  npm start   → open http://localhost:3000
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { makeVideo, listVideos, suggestIdeas } from './pipeline.js';
import { loadSettings, saveSettings } from './settings.js';
import { ROOT, OUTPUT_DIR, sendFile, safeJoin, serveEngine } from './static.js';
import { backend } from './claude.js';

const PORT = Number(process.env.PORT || 3000);
const queue = []; // { jobId, prompt, status, log[], progress, videoId, error }
let running = false;

async function pump() {
  if (running) return;
  const job = queue.find((j) => j.status === 'queued');
  if (!job) return;
  running = true; job.status = 'working';
  try {
    const meta = await makeVideo(job.prompt, {
      spec: job.spec,
      log: (step, msg) => { job.log.push({ step, msg }); job.step = step; console.log(`[${job.jobId}] [${step}] ${msg}`); },
      onProgress: (p) => { job.progress = p; },
    });
    job.status = 'done'; job.videoId = meta.id;
  } catch (e) { job.status = 'error'; job.error = e.message; }
  running = false;
  setImmediate(pump);
}

function addJob(prompt, spec) {
  const job = { jobId: Math.random().toString(36).slice(2, 8), prompt, spec, status: 'queued', log: [], createdAt: Date.now() };
  queue.push(job); pump(); return job;
}

const json = (res, code, obj) => { res.writeHead(code, { 'Content-Type': 'application/json' }); res.end(JSON.stringify(obj)); };
const body = (req) => new Promise((resolve) => { let b = ''; req.on('data', (d) => (b += d)); req.on('end', () => { try { resolve(JSON.parse(b || '{}')); } catch { resolve({}); } }); });

const server = http.createServer(async (req, res) => {
  const u = new URL(req.url, 'http://x'); const p = u.pathname;
  try {
    if (p === '/' || p === '/index.html') return sendFile(req, res, path.join(ROOT, 'ui', 'index.html'));
    if (p.startsWith('/ui/')) { const f = safeJoin(path.join(ROOT, 'ui'), p.slice(3)); return f ? sendFile(req, res, f) : json(res, 404, {}); }
    if (serveEngine(req, res, p)) return;
    if (p.startsWith('/media/')) { const f = safeJoin(OUTPUT_DIR, p.slice(6)); return f ? sendFile(req, res, f) : json(res, 404, {}); }
    if (p.startsWith('/download/')) {
      const id = decodeURIComponent(p.slice(10)); const f = safeJoin(OUTPUT_DIR, `/${id}/video.mp4`);
      if (!f || !fs.existsSync(f)) return json(res, 404, {});
      res.setHeader('Content-Disposition', `attachment; filename="${id}.mp4"`); return sendFile(req, res, f);
    }

    if (p === '/api/status') return json(res, 200, { backend: backend(), settings: loadSettings() });
    if (p === '/api/videos') return json(res, 200, listVideos());
    if (p === '/api/queue') return json(res, 200, queue.slice(-30).map(({ spec, ...j }) => j));
    if (p === '/api/generate' && req.method === 'POST') {
      const b = await body(req);
      const prompts = [].concat(b.prompts || b.prompt || []).map((s) => String(s).trim()).filter(Boolean);
      if (!prompts.length && !b.spec) return json(res, 400, { error: 'Vul een prompt in' });
      const jobs = b.spec ? [addJob(b.spec.title || 'Eigen spec', b.spec)] : prompts.map((pr) => addJob(pr));
      return json(res, 200, jobs.map(({ spec, ...j }) => j));
    }
    if (p === '/api/ideas' && req.method === 'POST') { const b = await body(req); return json(res, 200, { ideas: await suggestIdeas(b.n || 8) }); }
    if (p === '/api/settings') {
      if (req.method === 'POST') return json(res, 200, saveSettings(await body(req)));
      return json(res, 200, loadSettings());
    }
    const sm = p.match(/^\/api\/spec\/([\w.-]+)$/);
    if (sm) { const f = path.join(OUTPUT_DIR, sm[1], 'spec.json'); return fs.existsSync(f) ? sendFile(req, res, f) : json(res, 404, {}); }
    const dm = p.match(/^\/api\/videos\/([\w.-]+)$/);
    if (dm && req.method === 'DELETE') { const d = safeJoin(OUTPUT_DIR, '/' + dm[1]); if (d && d !== OUTPUT_DIR) fs.rmSync(d, { recursive: true, force: true }); return json(res, 200, { ok: true }); }
    json(res, 404, { error: 'not found' });
  } catch (e) { console.error(e); json(res, 500, { error: e.message }); }
});

// Listen on all network interfaces so phones/tablets on the same Wi-Fi can open it too.
server.listen(PORT, '0.0.0.0', () => {
  const lan = Object.values(os.networkInterfaces()).flat().filter((i) => i && i.family === 'IPv4' && !i.internal).map((i) => `http://${i.address}:${PORT}`);
  console.log(`\n  What-If TikTok bot draait!\n  Op deze computer:      http://localhost:${PORT}`);
  for (const u of lan) console.log(`  Op je telefoon/tablet: ${u}   (zelfde wifi)`);
  console.log(`  Claude via: ${backend() === 'api' ? 'Anthropic API (ANTHROPIC_API_KEY)' : 'Claude Code CLI (jouw Claude-abonnement)'}\n`);
});
