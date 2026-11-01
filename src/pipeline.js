// The bot: prompt -> premise check & sources -> scene code -> self-check -> render -> video.
import fs from 'node:fs';
import path from 'node:path';
import { askClaude, extractJson } from './claude.js';
import { planPrompt, fixPrompt, reviewPrompt, ideasPrompt, researchPrompt } from './prompts.js';
import { renderStills, renderVideo, makeThumbnail } from './render.js';
import { OUTPUT_DIR } from './static.js';
import { loadSettings } from './settings.js';

export function slugify(s) {
  return String(s).toLowerCase().normalize('NFKD').replace(/[^\w\s-]/g, '').trim().replace(/\s+/g, '-').slice(0, 50) || 'video';
}

export function listVideos() {
  if (!fs.existsSync(OUTPUT_DIR)) return [];
  return fs.readdirSync(OUTPUT_DIR)
    .filter((d) => fs.existsSync(path.join(OUTPUT_DIR, d, 'meta.json')))
    .map((d) => { try { return JSON.parse(fs.readFileSync(path.join(OUTPUT_DIR, d, 'meta.json'), 'utf8')); } catch { return null; } })
    .filter(Boolean)
    .sort((a, b) => (b.createdAt || '').localeCompare(a.createdAt || ''));
}

function writeMeta(dir, meta) { fs.writeFileSync(path.join(dir, 'meta.json'), JSON.stringify(meta, null, 2)); }

/**
 * Make one video.
 * @param {string} prompt  e.g. "What if all rubber disappeared for 5 seconds?"
 * @param {object} o       { log(step, msg), spec (skip Claude and use this spec), quality, review }
 */
export async function makeVideo(prompt, o = {}) {
  const settings = loadSettings();
  const log = o.log || ((step, msg) => console.log(`[${step}] ${msg}`));
  const quality = o.quality || settings.quality;
  const review = o.review ?? settings.selfReview;
  const id = `${new Date().toISOString().slice(0, 10)}-${slugify(prompt)}-${Math.random().toString(36).slice(2, 6)}`;
  const dir = path.join(OUTPUT_DIR, id); fs.mkdirSync(dir, { recursive: true });
  const meta = { id, prompt, status: 'working', createdAt: new Date().toISOString(), steps: [] };
  const step = (name, msg) => { meta.steps.push({ name, msg, at: new Date().toISOString() }); log(name, msg); writeMeta(dir, meta); };
  writeMeta(dir, meta);

  try {
    let plan;
    if (o.spec) {
      plan = { spec: o.spec, facts: o.facts || [], premise: { verdict: 'ok', note: 'Spec handmatig aangeleverd' }, tiktok: o.tiktok };
      step('premise', 'Eigen spec gebruikt (Claude overgeslagen)');
    } else {
      // 1+2+3: premise check, sources, scene
      step('premise', 'Claude checkt het idee, zoekt bronnen en schrijft de scène…');
      const past = listVideos().filter((v) => v.id !== id && v.title).map((v) => v.title).slice(0, 40);
      plan = extractJson(await askClaude(planPrompt(prompt, past)));
      if (!plan.spec) throw new Error('Claude gaf geen scene spec terug');
      step('premise', `${plan.premise?.verdict === 'twist' ? 'Nieuwe twist: ' : 'Idee OK: '}${plan.premise?.note || ''}`);
      if (plan.facts?.length) step('sources', plan.facts.map((f) => `${f.text} (${f.source})`).join(' | '));
    }
    let spec = plan.spec;
    spec.handle = spec.handle || settings.handle;
    meta.title = spec.title; meta.facts = plan.facts || []; meta.premise = plan.premise;
    meta.tiktok = plan.tiktok || { description: spec.title, hashtags: ['whatif', 'simulation', 'science'] };
    fs.writeFileSync(path.join(dir, 'spec.json'), JSON.stringify(spec, null, 2));

    // 4: it checks its own frames
    const checkDir = path.join(dir, 'check');
    for (let attempt = 0; attempt < 3; attempt++) {
      const times = keyTimes(spec);
      step('check', `Test-frames renderen (${times.map((t) => t.toFixed(1) + 's').join(', ')})…`);
      const { files, errors } = await renderStills(spec, times, checkDir, { quality: 'draft' });
      if (errors.length) {
        if (o.spec || attempt === 2) { step('check', `Waarschuwing: ${errors.join('; ')}`); break; }
        step('fix', `Fout gevonden, Claude repareert: ${errors[0]}`);
        spec = extractJson(await askClaude(fixPrompt(spec, errors)));
        spec.handle = spec.handle || settings.handle;
        continue;
      }
      if (review && !o.spec && attempt === 0) {
        step('review', 'Claude bekijkt de eigen frames…');
        try {
          const rv = extractJson(await askClaude(reviewPrompt(spec), { images: files }));
          if (!rv.ok && rv.spec) { step('fix', `Verbeterd: ${(rv.issues || []).join('; ')}`); spec = rv.spec; spec.handle = spec.handle || settings.handle; continue; }
          step('review', `Goedgekeurd${rv.issues?.length ? ' (' + rv.issues.join('; ') + ')' : ''}`);
        } catch (e) { step('review', 'Review overgeslagen: ' + e.message); }
      }
      break;
    }
    meta.title = spec.title;
    fs.writeFileSync(path.join(dir, 'spec.json'), JSON.stringify(spec, null, 2));

    // 5: render
    step('render', `Video renderen (${quality})…`);
    const out = path.join(dir, 'video.mp4');
    const res = await renderVideo(spec, out, {
      quality, voice: settings.voiceover !== false, onLog: (m) => step('voice', m),
      onProgress: (p) => { meta.progress = p; if (o.onProgress) o.onProgress(p); if (p.frame % 60 === 1) writeMeta(dir, meta); },
    });
    await makeThumbnail(out, path.join(dir, 'thumb.jpg'), Math.min(spec.duration ?? 18, 6.5));
    fs.rmSync(checkDir, { recursive: true, force: true });
    meta.status = 'done'; meta.video = `${id}/video.mp4`; meta.thumb = `${id}/thumb.jpg`; meta.renderSeconds = Math.round(res.seconds); meta.duration = spec.duration;
    delete meta.progress;
    step('done', `Klaar in ${Math.round(res.seconds)}s → ${out}`);
    return meta;
  } catch (e) {
    meta.status = 'error'; meta.error = e.message; step('error', e.message); throw e;
  }
}

function keyTimes(spec) {
  const d = Number(spec.duration) || 18;
  const ts = new Set([1]);
  for (const f of spec.effects || []) { const s = Number(f.start) || 0; ts.add(Math.min(d - 0.5, s + 1.5)); }
  ts.add(Math.max(1, d - 2));
  return [...ts].sort((a, b) => a - b).slice(0, 4);
}

export async function suggestIdeas(n = 8) {
  const past = listVideos().map((v) => v.title).filter(Boolean).slice(0, 60);
  return extractJson(await askClaude(ideasPrompt(n, past))).ideas || [];
}

// Prompt maker: searches YouTube/TikTok/web for what already exists and returns fresh short prompts.
export async function researchPrompts(topic = '', lang = 'en') {
  const past = listVideos().map((v) => v.title).filter(Boolean).slice(0, 60);
  const r = extractJson(await askClaude(researchPrompt(topic.trim(), lang, past), { web: true, timeoutMs: 420000 }));
  return { covered: Array.isArray(r.covered) ? r.covered : [], prompts: Array.isArray(r.prompts) ? r.prompts : [] };
}
