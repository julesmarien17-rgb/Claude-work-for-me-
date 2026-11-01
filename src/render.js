// Renders a scene spec to an MP4 by driving the engine in headless Chromium
// frame by frame and piping screenshots into ffmpeg.
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { chromium } from 'playwright';
import { startEngineServer } from './static.js';
import { buildAudio } from './audio.js';
import { buildVoiceover } from './voice.js';

const QUALITY = {
  draft: { pixelRatio: 0.5, shadows: false, jpeg: 80, crf: 26 },
  medium: { pixelRatio: 0.75, shadows: true, jpeg: 88, crf: 21 },
  high: { pixelRatio: 1, shadows: true, jpeg: 92, crf: 19 },
};

async function launch() {
  const args = ['--ignore-gpu-blocklist', '--enable-unsafe-swiftshader', '--use-angle=' + (process.env.ANGLE_BACKEND || (process.platform === 'darwin' ? 'metal' : 'swiftshader')), '--disable-dev-shm-usage', '--no-sandbox'];
  const opts = { headless: true, args };
  if (process.env.CHROMIUM_PATH) opts.executablePath = process.env.CHROMIUM_PATH;
  try { return await chromium.launch(opts); }
  catch (e) {
    for (const p of ['/opt/pw-browsers/chromium']) if (fs.existsSync(p)) { try { return await chromium.launch({ ...opts, executablePath: fs.statSync(p).isDirectory() ? undefined : p }); } catch {} }
    throw new Error(`Kon Chromium niet starten. Draai eerst: npx playwright install chromium\n${e.message}`);
  }
}

export async function openEngine(spec, { quality = 'medium', fps = 30 } = {}) {
  const q = QUALITY[quality] || QUALITY.medium;
  const { server, url } = await startEngineServer();
  const browser = await launch();
  const page = await browser.newPage({ viewport: { width: 1080, height: 1920 }, deviceScaleFactor: 1 });
  const logs = [];
  page.on('console', (m) => { if (m.type() === 'error' || m.type() === 'warning') logs.push(`${m.type()}: ${m.text()}`); });
  page.on('pageerror', (e) => logs.push(`pageerror: ${e.message}`));
  await page.goto(`${url}/engine/index.html`);
  await page.waitForFunction(() => window.SIM_READY === true, null, { timeout: 30000 });
  await page.evaluate(() => document.fonts && document.fonts.ready);
  const info = await page.evaluate(async ({ spec, o }) => {
    try { return await window.SIM.init(spec, o); } catch (e) { return { ok: false, errors: [String(e && e.stack || e)] }; }
  }, { spec, o: { pixelRatio: q.pixelRatio, shadows: q.shadows, fps } });
  const close = async () => { await browser.close().catch(() => {}); server.close(); };
  return { page, info, logs, q, close };
}

// Render a few still frames (for the self-check step). Returns { files, errors }.
export async function renderStills(spec, times, outDir, opts = {}) {
  fs.mkdirSync(outDir, { recursive: true });
  const eng = await openEngine(spec, { quality: opts.quality || 'draft' });
  const files = [];
  try {
    if (!eng.info.ok) return { files, errors: eng.info.errors || ['init failed'] };
    for (const t of [...times].sort((a, b) => a - b)) {
      await eng.page.evaluate((t) => window.SIM.stepTo(t), t);
      const f = path.join(outDir, `still_${t.toFixed(1)}s.jpg`);
      await eng.page.screenshot({ path: f, type: 'jpeg', quality: 80 });
      files.push(f);
    }
    const errors = await eng.page.evaluate(() => window.SIM.errors);
    return { files, errors: [...(eng.info.errors || []), ...errors, ...eng.logs.filter((l) => l.startsWith('pageerror'))] };
  } finally { await eng.close(); }
}

export async function renderVideo(spec, outFile, { quality = 'medium', fps = 30, onProgress = () => {}, audio = true, voice = true, onLog = () => {} } = {}) {
  const eng = await openEngine(spec, { quality, fps });
  const tmpVideo = outFile.replace(/\.mp4$/, '.silent.mp4');
  try {
    if (!eng.info.ok) throw new Error('Engine init mislukt: ' + (eng.info.errors || []).join('; '));
    const duration = await eng.page.evaluate(() => window.SIM.spec.duration);
    const total = Math.round(duration * fps);
    const ff = spawn('ffmpeg', ['-y', '-loglevel', 'error', '-f', 'image2pipe', '-framerate', String(fps), '-c:v', 'mjpeg', '-i', '-', '-c:v', 'libx264', '-preset', 'medium', '-crf', String(eng.q.crf), '-pix_fmt', 'yuv420p', '-movflags', '+faststart', tmpVideo], { stdio: ['pipe', 'inherit', 'inherit'] });
    const ffDone = new Promise((res, rej) => { ff.on('close', (c) => (c === 0 ? res() : rej(new Error('ffmpeg exit ' + c)))); ff.on('error', rej); });
    const started = Date.now();
    for (let i = 0; i < total; i++) {
      if (i > 0) await eng.page.evaluate(() => window.SIM.step(1, true));
      const buf = await eng.page.screenshot({ type: 'jpeg', quality: eng.q.jpeg });
      if (!ff.stdin.write(buf)) await new Promise((r) => ff.stdin.once('drain', r));
      if (i % 10 === 0 || i === total - 1) {
        const el = (Date.now() - started) / 1000;
        onProgress({ frame: i + 1, total, elapsed: el, eta: ((total - i - 1) * el) / (i + 1) });
      }
    }
    ff.stdin.end(); await ffDone;
    const errors = await eng.page.evaluate(() => window.SIM.errors);
    const fxList = await eng.page.evaluate(() => window.SIM.spec.effects.map((f) => ({ type: f.type, start: f.start, end: f.end ?? null, revert: !!f.revert })));
    await eng.close();
    if (audio) {
      const wav = outFile.replace(/\.mp4$/, '.wav');
      await buildAudio({ duration, effects: fxList, mood: spec.mood, out: wav });
      let vo = null;
      if (voice && spec.voiceover !== false) {
        try { vo = await buildVoiceover(spec, path.join(path.dirname(outFile), 'vo'), duration); if (vo) onLog(`Voice-over ingesproken (${vo.engine})`); }
        catch (e) { onLog(`Voice-over mislukt, video zonder stem: ${e.message}`); }
      }
      if (vo) {
        // Music ducks automatically under the voice.
        const fc = '[1:a]volume=0.55[m];[2:a]volume=1.6,asplit[v1][v2];[m][v1]sidechaincompress=threshold=0.02:ratio=10:attack=15:release=450[md];[md][v2]amix=inputs=2:normalize=0,alimiter=limit=0.95[a]';
        await run('ffmpeg', ['-y', '-loglevel', 'error', '-i', tmpVideo, '-i', wav, '-i', vo.file, '-filter_complex', fc, '-map', '0:v', '-map', '[a]', '-c:v', 'copy', '-c:a', 'aac', '-b:a', '192k', '-shortest', '-movflags', '+faststart', outFile]);
        fs.rmSync(path.dirname(vo.file), { recursive: true, force: true });
      } else {
        await run('ffmpeg', ['-y', '-loglevel', 'error', '-i', tmpVideo, '-i', wav, '-c:v', 'copy', '-c:a', 'aac', '-b:a', '160k', '-shortest', '-movflags', '+faststart', outFile]);
      }
      fs.rmSync(wav, { force: true }); fs.rmSync(tmpVideo, { force: true });
    } else fs.renameSync(tmpVideo, outFile);
    return { outFile, errors, frames: total, seconds: (Date.now() - started) / 1000 };
  } catch (e) { await eng.close(); throw e; }
}

export async function makeThumbnail(video, out, t = 1.5) {
  await run('ffmpeg', ['-y', '-loglevel', 'error', '-ss', String(t), '-i', video, '-frames:v', '1', '-vf', 'scale=360:-1', '-q:v', '4', out]);
}

export function run(cmd, args) {
  return new Promise((res, rej) => {
    const p = spawn(cmd, args, { stdio: ['ignore', 'inherit', 'pipe'] }); let err = '';
    p.stderr.on('data', (d) => (err += d)); p.on('error', rej);
    p.on('close', (c) => (c === 0 ? res() : rej(new Error(`${cmd} failed (${c}): ${err.slice(-500)}`))));
  });
}
