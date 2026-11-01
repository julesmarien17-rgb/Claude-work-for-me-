// Prompt templates that teach Claude the scene-spec format.

export const SPEC_DOC = `
You write JSON "scene specs" for a 3D "What if...?" simulation engine (Three.js). The engine builds
a stylised low-poly world and plays a timeline of effects. Output is a vertical 9:16 TikTok video.

SPEC FORMAT (all times in seconds):
{
  "title": "What if ...?",              // the hook question, short, max ~60 chars
  "setting": "city|beach|suburb|highway|park|desert|snow|harbor",
  "time": "day|sunset|night",
  "weather": "clear|rain|snow|ash|sand|confetti|embers|fireflies",   // optional ambient weather
  "duration": 24-32,                     // MINIMUM 23 seconds; 25-28 is ideal (build-up, effect, consequences, twist)
  "location": "TIMES SQUARE · NEW YORK", // small caps label, real-sounding place that fits the setting
  "camera": { "mode": "street|aerial|orbit|drone|low|static", "height": 3, "speed": 1 },
  "mood": "tense|wonder|dark",           // soundtrack
  "density": 0.6-1.4,                    // optional crowd/traffic/building density (city)
  "hud": [ // 1-2 animated counters, top-left. Numbers count from 'from' to 'to' between start and end.
    { "label": "Temperature", "sub": "optional small line", "from": 72, "to": -459.67, "start": 4, "end": 5,
      "unit": "°F", "decimals": 0, "ease": "linear|in|out", "format": "number|compact|time",
      "show": [0.3, 18], "alert": true, "alertAfter": 4 }
  ],
  "effects": [ /* see EFFECTS; 1-4 effects, the main one usually starts at 3.5-5s right after the title */ ],
  "captions": [ // serif text. style "title" = big hook at top (first ~4s), "subtitle" = lower third, "big" = huge bold word
    { "text": "What if ...?", "start": 0.2, "end": 4.2, "style": "title" },
    { "text": "Short punchy fact.", "start": 5, "end": 8.5, "style": "subtitle" }
  ],
  "endcard": { "start": 17, "text": "Part 2?", "cta": "Follow for part 2" },  // optional
  "language": "en|nl|be|de|fr|es",       // language of captions + voice-over (same as the user's prompt)
  "voice": { "gender": "male|female" },
  "voiceover": [ // spoken narration, like a documentary narrator. One line per beat, timed to the captions.
    { "start": 0.3, "text": "What if all rubber on Earth disappeared for five seconds?" },
    { "start": 4.6, "text": "Instantly, every tire is gone." }
  ]
}
VOICE-OVER RULES: speech runs ~2.7 words per second, so each line must finish before the next line's start
(a 3 s gap fits ~8 words). Write numbers as words when they are hard to read aloud ("minus four hundred fifty-nine degrees").
The narration may say a bit more than the caption, but never contradict it. Last line = the twist / cliffhanger.

EFFECTS (common fields: type, start, end (optional), ramp (fade seconds, default 0.8), revert (bool; default true when end < duration), intensity 0-1):
- freeze: everything frosts over, motion stops, ocean freezes. {}
- heat: scorching, hazy orange, water evaporates. { "evaporate": true }
- vanish: objects disappear. { "target": "tires|cars|people|buildings|trees|billboards|clouds|water|sun|glass|lamps|umbrellas|boats|roads|movable", "stagger": 0.5 }
    (tires vanishing makes cars drop & grind with sparks; water drains the ocean; sun = instant night)
- gravity_off: things float up; with end they fall back down. { "target": "movable|cars|people", "strength": 1, "reverse": false }
- darkness: sun goes out, city lights on, stars. { "powerOut": false }
- power_out: all windows, billboards and street lights go dark.
- flood: water rises, cars & people float. { "height": 6, "color": "#2d7fa6", "liquid": "water|lava", "current": 1.2 }
- giant_object: big body in the sky. { "shape": "moon|planet|sun|black_hole|cube", "size": 0.02-0.22 (radius/distance; 0.05 = 6x today's Moon, 0.2 = fills a third of the sky), "elevation": 0.32, "side": 0.15,
    "approach": false, "tides": 0, "shake": 0, "pull": 0, "rings": false, "hue": 30, "color": "#d4d2c8" }
- meteor: asteroid streaks down and impacts (start = impact time; it falls during the 2.2 s before). { "size": 6, "distance": 160, "side": 0.25 }
- earthquake: shaking, buildings sway. { "strength": 1, "collapse": 0.3 }
- wind: hurricane winds, debris, things blow away. { "strength": 0.8, "direction": "right|left" }
- weather: particles. { "kind": "rain|snow|ash|sand|confetti|embers|fireflies", "intensity": 0.6 }
- speed: change time speed. { "value": 0.2 }  (0.2 = slow motion, 4 = fast)
- time_stop: everything freezes in place and desaturates.
- grade: colour grade. { "preset": "red|green|blue|sepia|noir|invert|warm|cold|toxic|purple" }
- sky: recolour sky. { "top": "#hex", "bottom": "#hex", "fog": "#hex", "sunColor": "#hex", "sunSize": 3, "sunIntensity": 2, "stars": 1 }
- scale: resize things. { "target": "people|cars|trees|buildings", "factor": 6 }
- flash: white flash. { "amount": 1, "length": 0.6 }
- shake: camera shake. { "amount": 0.4 }
- panic: people run. { "armsUp": true, "from": [x, z] }
- rain_objects: things fall from the sky. { "object": "cars|people|balls|cubes|coins", "count": 120, "spread": 4, "size": 1, "color": "#hex" }
- custom: your own Three.js code when nothing above fits. { "setupCode": "...", "code": "..." }
    setupCode runs once, code runs every frame. Available: THREE, sim, scene, rng (seeded random), fx (this effect object,
    store state on it), Particles, col, lerp, clamp, smooth; in code also t, dt, k (0..1 effect strength).
    sim.camera, sim.entities (each {obj, kind:'car|person|tree|building|prop|boat|cloud', vel, physics, g}), sim.look (per-frame
    lighting: sunI, hemiI, top, bottom, fog (THREE.Color), stars, glow, flash, filter[] css filters), sim.shake, sim.timeScale.
    Never use Math.random (use rng), never touch the DOM, keep it under 60 lines.

RULES
- Be scientifically grounded: numbers in hud/captions must be realistic and defensible.
- Captions: short (max ~8 words), punchy, escalating. The last caption is a twist or a cliffhanger.
- Length: at least 23 seconds. Use the time: hook (0-4s), the event (4-8s), 2-3 escalating consequences with their own
  caption + voice line, then the twist. Use 5-7 captions and 5-7 voice-over lines spread over the whole video.
- Pick the setting and camera that show the effect best (e.g. tires -> city street, ocean draining -> beach, meteor -> aerial or drone).
- Captions are in the SAME LANGUAGE as the user's prompt.
`;

export function planPrompt(userPrompt, pastTitles = []) {
  return `You are the creative director + scientist of a viral TikTok account that posts "What if...?" simulations.
The user wants a video about: """${userPrompt}"""

Step 1 – PREMISE CHECK: Is this a strong, clear "what if" premise? Has our account already done it? Our past videos:
${pastTitles.length ? pastTitles.map((t) => '- ' + t).join('\n') : '(none yet)'}
If it duplicates a past video, add a fresh twist.
Step 2 – SOURCES: list 2-4 real facts (with a source name) that back the numbers you'll show.
Step 3 – SCENE: write the scene spec.

${SPEC_DOC}

Reply with ONLY one JSON object, no prose:
{
  "premise": { "verdict": "ok|twist", "note": "one sentence" },
  "facts": [ { "text": "...", "source": "..." } ],
  "spec": { ...scene spec... },
  "tiktok": { "description": "post caption with a hook question", "hashtags": ["whatif", "..."] }
}`;
}

export function fixPrompt(spec, errors) {
  return `This "What if" scene spec produced errors when rendering in the engine:
${errors.map((e) => '- ' + e).join('\n')}

Spec:
${JSON.stringify(spec, null, 2)}

${SPEC_DOC}

Fix the spec so it renders without errors (keep the idea). Reply with ONLY the corrected spec JSON object.`;
}

export function reviewPrompt(spec) {
  return `You are reviewing frames rendered from this "What if" TikTok scene spec. Check them like an editor:
is the effect clearly visible, is text readable, is anything broken (black frames, objects missing, camera inside a wall)?

Spec:
${JSON.stringify(spec, null, 2)}

${SPEC_DOC}

Reply with ONLY JSON: { "ok": true|false, "issues": ["..."], "spec": { ...improved spec, only if ok is false... } }`;
}

export function ideasPrompt(n, pastTitles) {
  return `Give ${n} fresh, highly viral "What if...?" ideas for a TikTok simulation account (physics, nature, space, everyday life).
They must be visualisable in a 3D street/beach/city/highway/park/desert/snow/harbor scene. Avoid these past ones:
${pastTitles.map((t) => '- ' + t).join('\n') || '(none)'}
Reply with ONLY JSON: { "ideas": ["What if ...?", ...] }`;
}

export function researchPrompt(topic, lang, pastTitles) {
  return `You are the researcher for a TikTok account that posts 3D "What if...?" simulation videos.
${topic ? `Topic to explore: """${topic}"""` : 'No topic given: find what is trending right now in "what if" / science / "how things work" videos.'}

1. SEARCH the web (use your web search tool several times) for existing videos on YouTube, YouTube Shorts and TikTok
   (e.g. queries like "what if ${topic || 'science'} youtube", "what if ${topic || ''} tiktok", "how does ${topic || 'it'} work video"),
   and for "how things work" explainers on the topic. Note which what-if questions have already been done a lot.
2. Find ANGLES THAT ARE NOT DONE YET (or barely): surprising, visual, scientifically grounded, and showable in a 3D
   street / beach / city / highway / park / desert / snow / harbor scene.
3. Turn each angle into ONE short prompt for the video bot (max ~12 words, starts with "What if" ${lang === 'nl' ? 'but written in Dutch ("Wat als ...?")' : 'in English'}).
Avoid these, our account already did them:
${pastTitles.map((t) => '- ' + t).join('\n') || '(none)'}

Reply with ONLY JSON:
{
  "covered": [ { "title": "existing video / question", "platform": "YouTube|TikTok|Web", "url": "https://..." } ],
  "prompts": [ { "prompt": "What if ...?", "why": "one short line: why it's fresh / what it shows", "fresh": true } ]
}
Give 6-10 prompts (fresh ones first) and up to 8 covered items with real URLs from your searches.`;
}
