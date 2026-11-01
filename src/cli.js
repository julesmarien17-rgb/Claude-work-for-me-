#!/usr/bin/env node
// Command line:   npm run make -- "What if the Moon was twice as close?"
//                 npm run make -- --spec examples/rubber.json
import fs from 'node:fs';
import { makeVideo } from './pipeline.js';

const args = process.argv.slice(2);
let spec = null, quality;
const rest = [];
for (let i = 0; i < args.length; i++) {
  if (args[i] === '--spec') spec = JSON.parse(fs.readFileSync(args[++i], 'utf8'));
  else if (args[i] === '--quality') quality = args[++i];
  else rest.push(args[i]);
}
const prompt = rest.join(' ') || spec?.title;
if (!prompt) { console.log('Gebruik: npm run make -- "What if ...?"   of   npm run make -- --spec examples/rubber.json'); process.exit(1); }

let last = 0;
makeVideo(prompt, {
  spec, quality,
  onProgress: (p) => { const pct = Math.floor((p.frame / p.total) * 100); if (pct >= last + 10 || p.frame === p.total) { last = pct; console.log(`[render] ${pct}% (${p.frame}/${p.total}) nog ~${Math.round(p.eta)}s`); } },
}).then((m) => { console.log(`\nKlaar: output/${m.video}`); console.log(`Beschrijving: ${m.tiktok?.description}\n${(m.tiktok?.hashtags || []).map((h) => '#' + h).join(' ')}`); })
  .catch((e) => { console.error('Mislukt:', e.message); process.exit(1); });
