import fs from 'node:fs';
import path from 'node:path';
import { DATA_DIR, ROOT } from './static.js';

// Minimal .env loader (no dependency).
const envFile = path.join(ROOT, '.env');
if (fs.existsSync(envFile)) {
  for (const line of fs.readFileSync(envFile, 'utf8').split('\n')) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
    if (m && !process.env[m[1]]) process.env[m[1]] = m[2].replace(/^["']|["']$/g, '');
  }
}

const FILE = path.join(DATA_DIR, 'settings.json');
const DEFAULTS = { handle: 'whatif.bot', quality: 'medium', selfReview: true };

export function loadSettings() {
  try { return { ...DEFAULTS, ...JSON.parse(fs.readFileSync(FILE, 'utf8')) }; } catch { return { ...DEFAULTS }; }
}
export function saveSettings(s) {
  fs.mkdirSync(DATA_DIR, { recursive: true });
  const merged = { ...loadSettings(), ...s };
  fs.writeFileSync(FILE, JSON.stringify(merged, null, 2));
  return merged;
}
