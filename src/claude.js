// Talks to Claude. Two ways, picked automatically:
//  1. The `claude` CLI (Claude Code) — runs on your Claude plan, no extra cost.
//  2. The Anthropic API — set ANTHROPIC_API_KEY in .env.
import { spawn } from 'node:child_process';

const API_MODEL = process.env.CLAUDE_MODEL || 'claude-sonnet-5-5';

export function backend() {
  if (process.env.CLAUDE_BACKEND) return process.env.CLAUDE_BACKEND;
  if (process.env.ANTHROPIC_API_KEY) return 'api';
  return 'cli';
}

export async function askClaude(prompt, { images = [], timeoutMs = 240000 } = {}) {
  return backend() === 'api' ? askApi(prompt, images) : askCli(prompt, images, timeoutMs);
}

function askCli(prompt, images, timeoutMs) {
  return new Promise((resolve, reject) => {
    const args = ['-p', '--output-format', 'text'];
    if (process.env.CLAUDE_MODEL) args.push('--model', process.env.CLAUDE_MODEL);
    let full = prompt;
    if (images.length) {
      args.push('--allowedTools', 'Read');
      full += `\n\nUse the Read tool to look at these rendered frames before answering:\n${images.map((f) => '- ' + f).join('\n')}`;
    }
    const p = spawn(process.env.CLAUDE_CLI || 'claude', args, { stdio: ['pipe', 'pipe', 'pipe'] });
    let out = '', err = '';
    const timer = setTimeout(() => { p.kill('SIGKILL'); reject(new Error('Claude CLI timeout')); }, timeoutMs);
    p.stdout.on('data', (d) => (out += d)); p.stderr.on('data', (d) => (err += d));
    p.on('error', (e) => { clearTimeout(timer); reject(new Error(`Kon 'claude' niet starten. Installeer Claude Code (npm i -g @anthropic-ai/claude-code) en log in, of zet ANTHROPIC_API_KEY in .env.\n${e.message}`)); });
    p.on('close', (code) => { clearTimeout(timer); code === 0 ? resolve(out.trim()) : reject(new Error(`claude CLI exit ${code}: ${err.slice(-400)}`)); });
    p.stdin.end(full);
  });
}

async function askApi(prompt, images) {
  const fs = await import('node:fs');
  const content = [];
  for (const f of images) content.push({ type: 'image', source: { type: 'base64', media_type: 'image/jpeg', data: fs.readFileSync(f).toString('base64') } });
  content.push({ type: 'text', text: prompt });
  const r = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'x-api-key': process.env.ANTHROPIC_API_KEY, 'anthropic-version': '2023-06-01' },
    body: JSON.stringify({ model: API_MODEL, max_tokens: 8000, messages: [{ role: 'user', content }] }),
  });
  const j = await r.json();
  if (!r.ok) throw new Error(`Anthropic API: ${j.error?.message || r.status}`);
  return j.content.filter((c) => c.type === 'text').map((c) => c.text).join('').trim();
}

// Pull the first JSON object out of a reply.
export function extractJson(text) {
  const fence = text.match(/```(?:json)?\s*([\s\S]*?)```/);
  const src = fence ? fence[1] : text;
  const start = src.indexOf('{');
  if (start < 0) throw new Error('Geen JSON in antwoord van Claude');
  let depth = 0, inStr = false, esc = false;
  for (let i = start; i < src.length; i++) {
    const c = src[i];
    if (inStr) { if (esc) esc = false; else if (c === '\\') esc = true; else if (c === '"') inStr = false; continue; }
    if (c === '"') inStr = true; else if (c === '{') depth++; else if (c === '}' && --depth === 0) return JSON.parse(src.slice(start, i + 1));
  }
  throw new Error('Onvolledige JSON in antwoord van Claude');
}
