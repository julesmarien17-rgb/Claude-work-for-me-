// Generates a simple soundtrack with ffmpeg: ambient pad + riser and impact on each big effect.
// (On TikTok you'll usually add a trending sound on top, so this stays subtle.)
import { run } from './render.js';

const CHORDS = {
  tense: [110, 130.81, 164.81, 220],
  wonder: [130.81, 164.81, 196, 261.63],
  dark: [73.42, 110, 146.83, 174.61],
};
const BIG = new Set(['meteor', 'vanish', 'freeze', 'flash', 'darkness', 'gravity_off', 'earthquake', 'flood', 'giant_object', 'time_stop', 'wind', 'rain_objects', 'heat', 'custom']);

export async function buildAudio({ duration, effects = [], mood = 'tense', out }) {
  const D = duration.toFixed(2);
  const notes = CHORDS[mood] || CHORDS.tense;
  const parts = notes.map((f, i) => `0.045*sin(2*PI*${f}*t)*(0.6+0.4*sin(2*PI*${(0.07 + i * 0.03).toFixed(2)}*t+${i}))`);
  parts.push(`0.02*sin(2*PI*${notes[0] / 2}*t)`);
  // events: impacts and risers
  const hits = [];
  for (const fx of effects) {
    if (!BIG.has(fx.type)) continue;
    if (!hits.some((h) => Math.abs(h - fx.start) < 1)) hits.push(fx.start);
    if (fx.revert && fx.end != null && !hits.some((h) => Math.abs(h - fx.end) < 1)) hits.push(fx.end);
  }
  for (const T of hits.slice(0, 6)) {
    const T0 = Math.max(0, T - 2.5).toFixed(2), Ts = T.toFixed(2), len = (T - Math.max(0, T - 2.5)).toFixed(2);
    parts.push(`0.10*(random(0)*2-1)*pow((t-${T0})/${len},3)*between(t,${T0},${Ts})`);
    parts.push(`0.55*sin(2*PI*48*(t-${Ts}))*exp(-2.2*(t-${Ts}))*gte(t,${Ts})`);
    parts.push(`0.18*(random(1)*2-1)*exp(-7*(t-${Ts}))*gte(t,${Ts})`);
  }
  const fade = `min(1,t/1.5)*min(1,(${D}-t)/1.5)`;
  const expr = `(${parts.join('+')})*${fade}`;
  await run('ffmpeg', ['-y', '-loglevel', 'error', '-f', 'lavfi', '-i', `aevalsrc='${expr}|${expr}':s=44100:d=${D}`, '-af', 'lowpass=f=7000,alimiter=limit=0.9', out]);
  return out;
}
