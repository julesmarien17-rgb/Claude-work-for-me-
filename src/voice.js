// Voice-over: turns narration lines into speech and places them on the timeline.
// Engines (picked automatically, override with TTS_ENGINE in .env):
//   edge       – free Microsoft neural voices (internet needed, no key)          [default]
//   elevenlabs – ElevenLabs (ELEVENLABS_API_KEY, optional ELEVENLABS_VOICE_ID)
//   openai     – OpenAI TTS (OPENAI_API_KEY, optional OPENAI_TTS_VOICE)
//   say        – macOS built-in voices (offline)
//   espeak     – espeak-ng (offline, robotic)
import fs from 'node:fs';
import path from 'node:path';
import { spawn } from 'node:child_process';

// Good native voices per language, so it never sounds like a foreign accent.
export const EDGE_VOICES = {
  en: { male: 'en-US-AndrewNeural', female: 'en-US-AvaNeural' },
  nl: { male: 'nl-NL-MaartenNeural', female: 'nl-NL-FennaNeural' },
  be: { male: 'nl-BE-ArnaudNeural', female: 'nl-BE-DenaNeural' },
  de: { male: 'de-DE-ConradNeural', female: 'de-DE-KatjaNeural' },
  fr: { male: 'fr-FR-HenriNeural', female: 'fr-FR-DeniseNeural' },
  es: { male: 'es-ES-AlvaroNeural', female: 'es-ES-ElviraNeural' },
};
const SAY_VOICES = { en: 'Daniel', nl: 'Xander', be: 'Ellen', de: 'Anna', fr: 'Thomas', es: 'Jorge' };

export function detectLang(text) {
  const t = ` ${String(text).toLowerCase()} `;
  if (/ wat als | het | een | niet | zijn | worden | de zon | seconden /.test(t)) return 'nl';
  if (/ was wäre | wenn | nicht | sekunden /.test(t)) return 'de';
  if (/ et si | pendant | secondes /.test(t)) return 'fr';
  if (/ qué pasaría | segundos /.test(t)) return 'es';
  return 'en';
}

function engine() {
  if (process.env.TTS_ENGINE) return process.env.TTS_ENGINE;
  if (process.env.ELEVENLABS_API_KEY) return 'elevenlabs';
  return 'edge';
}

function run(cmd, args) {
  return new Promise((res, rej) => {
    const p = spawn(cmd, args, { stdio: ['ignore', 'pipe', 'pipe'] }); let out = '', err = '';
    p.stdout.on('data', (d) => (out += d)); p.stderr.on('data', (d) => (err += d)); p.on('error', rej);
    p.on('close', (c) => (c === 0 ? res(out) : rej(new Error(`${cmd} failed (${c}): ${err.slice(-300)}`))));
  });
}

export async function audioDuration(file) {
  const out = await run('ffprobe', ['-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', file]);
  return parseFloat(out) || 0;
}

async function speakEdge(text, out, { lang, gender, rate }) {
  const { MsEdgeTTS, OUTPUT_FORMAT } = await import('msedge-tts');
  const voice = process.env.TTS_VOICE || (EDGE_VOICES[lang] || EDGE_VOICES.en)[gender] || EDGE_VOICES.en.male;
  const tts = new MsEdgeTTS();
  await tts.setMetadata(voice, OUTPUT_FORMAT.AUDIO_24KHZ_96KBITRATE_MONO_MP3);
  const dir = path.dirname(out);
  const { audioFilePath } = await tts.toFile(dir, text, { rate });
  fs.renameSync(audioFilePath, out);
  try { tts.close(); } catch {}
}

async function speakElevenLabs(text, out) {
  const voice = process.env.ELEVENLABS_VOICE_ID || 'pNInz6obpgDQGcFmaJgB';
  const r = await fetch(`https://api.elevenlabs.io/v1/text-to-speech/${voice}`, {
    method: 'POST', headers: { 'xi-api-key': process.env.ELEVENLABS_API_KEY, 'content-type': 'application/json', accept: 'audio/mpeg' },
    body: JSON.stringify({ text, model_id: process.env.ELEVENLABS_MODEL || 'eleven_multilingual_v2' }),
  });
  if (!r.ok) throw new Error(`ElevenLabs ${r.status}: ${(await r.text()).slice(0, 200)}`);
  fs.writeFileSync(out, Buffer.from(await r.arrayBuffer()));
}

async function speakOpenAI(text, out) {
  const r = await fetch('https://api.openai.com/v1/audio/speech', {
    method: 'POST', headers: { authorization: `Bearer ${process.env.OPENAI_API_KEY}`, 'content-type': 'application/json' },
    body: JSON.stringify({ model: process.env.OPENAI_TTS_MODEL || 'tts-1-hd', voice: process.env.OPENAI_TTS_VOICE || 'onyx', input: text, format: 'mp3' }),
  });
  if (!r.ok) throw new Error(`OpenAI TTS ${r.status}`);
  fs.writeFileSync(out, Buffer.from(await r.arrayBuffer()));
}

async function speakSay(text, out, { lang }) {
  const aiff = out.replace(/\.\w+$/, '.aiff');
  await run('say', ['-v', process.env.TTS_VOICE || SAY_VOICES[lang] || 'Daniel', '-o', aiff, text]);
  await run('ffmpeg', ['-y', '-loglevel', 'error', '-i', aiff, out]); fs.rmSync(aiff, { force: true });
}

async function speakEspeak(text, out, { lang }) {
  const wav = out.replace(/\.\w+$/, '.wav');
  await run('espeak-ng', ['-v', lang === 'be' ? 'nl' : lang, '-s', '165', '-w', wav, text]);
  await run('ffmpeg', ['-y', '-loglevel', 'error', '-i', wav, out]); fs.rmSync(wav, { force: true });
}

export async function speak(text, out, opts = {}) {
  const o = { lang: opts.lang || 'en', gender: opts.gender || 'male', rate: opts.rate || '+8%' };
  const order = [engine(), ...(process.platform === 'darwin' ? ['say'] : []), 'espeak'];
  let lastErr;
  for (const e of [...new Set(order)]) {
    try {
      if (e === 'edge') await speakEdge(text, out, o);
      else if (e === 'elevenlabs') await speakElevenLabs(text, out);
      else if (e === 'openai') await speakOpenAI(text, out);
      else if (e === 'say') await speakSay(text, out, o);
      else if (e === 'espeak') await speakEspeak(text, out, o);
      else continue;
      return e;
    } catch (err) { lastErr = err; }
  }
  throw lastErr || new Error('Geen stem-engine beschikbaar');
}

// Narration lines: spec.voiceover [{start, text}] or, if missing, the title + subtitle captions.
export function narrationLines(spec) {
  if (spec.voiceover === false) return [];
  let lines = Array.isArray(spec.voiceover) && spec.voiceover.length
    ? spec.voiceover.map((v) => ({ start: Number(v.start ?? v.t) || 0, text: String(v.text || '').trim() }))
    : (spec.captions || []).filter((c) => (c.style || 'subtitle') !== 'big').map((c) => ({ start: Number(c.start ?? c.t) || 0, text: String(c.text || '').trim() }));
  return lines.filter((l) => l.text).sort((a, b) => a.start - b.start);
}

/**
 * Builds the voice-over track: speaks each line and places it at its start time.
 * Lines never overlap: if one runs long, the next waits. Returns { file, engine, end } or null.
 */
export async function buildVoiceover(spec, workDir, duration) {
  const lines = narrationLines(spec);
  if (!lines.length) return null;
  fs.mkdirSync(workDir, { recursive: true });
  const lang = spec.voice?.lang || spec.language || detectLang(lines.map((l) => l.text).join(' '));
  const opts = { lang, gender: spec.voice?.gender || 'male', rate: spec.voice?.rate || '+8%' };
  const placed = []; let cursor = 0, used;
  for (let i = 0; i < lines.length; i++) {
    const f = path.join(workDir, `vo_${i}.mp3`);
    used = await speak(lines[i].text, f, opts);
    const d = await audioDuration(f);
    const start = Math.max(lines[i].start, cursor);
    if (start >= duration - 0.3) break;
    placed.push({ file: f, start }); cursor = start + d + 0.12;
  }
  if (!placed.length) return null;
  const out = path.join(workDir, 'voiceover.wav');
  const inputs = placed.flatMap((p) => ['-i', p.file]);
  const chains = placed.map((p, i) => `[${i}:a]aresample=44100,aformat=channel_layouts=stereo,adelay=${Math.round(p.start * 1000)}|${Math.round(p.start * 1000)}[v${i}]`);
  const mix = `${placed.map((_, i) => `[v${i}]`).join('')}amix=inputs=${placed.length}:normalize=0,apad=whole_dur=${duration},atrim=0:${duration}[out]`;
  await run('ffmpeg', ['-y', '-loglevel', 'error', ...inputs, '-filter_complex', [...chains, mix].join(';'), '-map', '[out]', out]);
  return { file: out, engine: used, end: cursor };
}
