// What-If Simulation Engine
// Builds a procedural 3D world from a JSON "scene spec" and plays a timeline of effects.
// Deterministic: the same spec always renders the same frames (seeded RNG + fixed timestep).
import * as THREE from 'three';

const W = 1080, H = 1920;

// ---------- helpers ----------
function mulberry32(a) {
  return function () {
    a |= 0; a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
function hashStr(s) { let h = 1779033703; for (const c of String(s)) { h = Math.imul(h ^ c.charCodeAt(0), 3432918353); h = (h << 13) | (h >>> 19); } return h >>> 0; }
const clamp = (x, a = 0, b = 1) => Math.max(a, Math.min(b, x));
const lerp = (a, b, t) => a + (b - a) * t;
const smooth = (x) => { x = clamp(x); return x * x * (3 - 2 * x); };
const col = (c) => new THREE.Color(c);

const TAG_ALIASES = {
  rubber: 'tires', tire: 'tires', tyres: 'tires', wheels: 'tires',
  car: 'cars', vehicles: 'cars', vehicle: 'cars', traffic: 'cars',
  person: 'people', humans: 'people', human: 'people', crowd: 'people', pedestrians: 'people',
  building: 'buildings', skyscrapers: 'buildings', houses: 'buildings', house: 'buildings',
  tree: 'trees', plants: 'trees', palms: 'trees', palm_trees: 'trees',
  billboard: 'billboards', screens: 'billboards', ads: 'billboards',
  ocean: 'water', sea: 'water', lake: 'water',
  cloud: 'clouds', boat: 'boats', ships: 'boats',
  windows: 'glass', road: 'roads', asphalt: 'roads', streetlights: 'lamps', lights: 'lamps',
  umbrellas: 'umbrellas', metal: 'metal', everything: 'movable',
};
const normTag = (t) => { t = String(t || '').toLowerCase().trim().replace(/\s+/g, '_'); return TAG_ALIASES[t] || t; };

const TIMES = {
  day: { top: '#2f6fd0', bottom: '#cfe8ff', sun: '#fff1dc', sunI: 3.2, hemiSky: '#d6eaff', hemiGround: '#9a917c', hemiI: 2.3, fog: '#cfe4f7', sunDir: [0.35, 0.8, -0.45], glow: 0.08, stars: 0, exposure: 1.1 },
  sunset: { top: '#27336a', bottom: '#ffa066', sun: '#ffb27a', sunI: 2.4, hemiSky: '#ffc9a0', hemiGround: '#6a5050', hemiI: 1.5, fog: '#f0a988', sunDir: [-0.35, 0.16, -0.92], glow: 0.7, stars: 0, exposure: 1.05 },
  night: { top: '#020511', bottom: '#0d1d44', sun: '#9fb6ff', sunI: 0.35, hemiSky: '#4a62a8', hemiGround: '#1a1a26', hemiI: 0.8, fog: '#0b1736', sunDir: [0.3, 0.8, -0.4], glow: 1.5, stars: 1, exposure: 1.15 },
};

// ---------- canvas textures ----------
function windowTexture(rng, style) {
  const c = document.createElement('canvas'); c.width = 128; c.height = 256;
  const g = c.getContext('2d');
  const wall = style.wall; g.fillStyle = wall; g.fillRect(0, 0, 128, 256);
  const lit = document.createElement('canvas'); lit.width = 128; lit.height = 256;
  const lg = lit.getContext('2d'); lg.fillStyle = '#000'; lg.fillRect(0, 0, 128, 256);
  const cols = 4, rows = 8;
  for (let y = 0; y < rows; y++) for (let x = 0; x < cols; x++) {
    const px = 8 + x * 30, py = 8 + y * 31;
    g.fillStyle = style.glass; g.fillRect(px, py, 20, 22);
    g.fillStyle = 'rgba(255,255,255,0.08)'; g.fillRect(px, py, 20, 6);
    if (rng() < style.litRatio) {
      const warm = rng() < 0.75;
      lg.fillStyle = warm ? `hsl(${38 + rng() * 12},90%,${62 + rng() * 20}%)` : `hsl(200,60%,${70 + rng() * 15}%)`;
      lg.fillRect(px, py, 20, 22);
    }
  }
  const t = new THREE.CanvasTexture(c); t.wrapS = t.wrapT = THREE.RepeatWrapping; t.colorSpace = THREE.SRGBColorSpace;
  const e = new THREE.CanvasTexture(lit); e.wrapS = e.wrapT = THREE.RepeatWrapping; e.colorSpace = THREE.SRGBColorSpace;
  t.anisotropy = 4; e.anisotropy = 4;
  return { map: t, emissive: e };
}

const BB_WORDS = ['LIVE', 'NEWS', 'SALE', 'COLA', 'NEW', 'SHOW', 'MUSIC', 'TECH', 'PHONE', 'FILM', 'OPEN', 'MEGA', 'NOW', 'WOW', 'BURGER', 'SPORT', 'PLAY', 'STAR', '24/7', 'DEALS'];
function billboardTexture(rng) {
  const c = document.createElement('canvas'); c.width = 256; c.height = 256;
  const g = c.getContext('2d');
  const h1 = Math.floor(rng() * 360), h2 = (h1 + 40 + rng() * 120) % 360;
  const gr = g.createLinearGradient(0, 0, 256, 256);
  gr.addColorStop(0, `hsl(${h1},90%,55%)`); gr.addColorStop(1, `hsl(${h2},90%,45%)`);
  g.fillStyle = gr; g.fillRect(0, 0, 256, 256);
  const kind = rng();
  if (kind < 0.4) {
    g.fillStyle = 'rgba(255,255,255,.9)'; g.beginPath(); g.arc(80 + rng() * 100, 90 + rng() * 60, 40 + rng() * 40, 0, 7); g.fill();
  } else if (kind < 0.7) {
    for (let i = 0; i < 5; i++) { g.fillStyle = `hsla(${rng() * 360},90%,70%,.85)`; g.fillRect(rng() * 200, rng() * 200, 40 + rng() * 80, 20 + rng() * 60); }
  }
  g.fillStyle = rng() < 0.5 ? '#fff' : '#111';
  g.font = `900 ${60 + Math.floor(rng() * 30)}px Arial, sans-serif`; g.textAlign = 'center'; g.textBaseline = 'middle';
  g.fillText(BB_WORDS[Math.floor(rng() * BB_WORDS.length)], 128, 190);
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; return t;
}

function moonTexture(rng, base = '#cfcfc8') {
  const c = document.createElement('canvas'); c.width = 512; c.height = 256;
  const g = c.getContext('2d'); g.fillStyle = base; g.fillRect(0, 0, 512, 256);
  for (let i = 0; i < 220; i++) {
    const r = 2 + Math.pow(rng(), 3) * 30, x = rng() * 512, y = rng() * 256;
    g.fillStyle = `rgba(0,0,0,${0.05 + rng() * 0.15})`; g.beginPath(); g.arc(x, y, r, 0, 7); g.fill();
    g.fillStyle = `rgba(255,255,255,${0.04 + rng() * 0.08})`; g.beginPath(); g.arc(x - r * 0.2, y - r * 0.2, r * 0.7, 0, 7); g.fill();
  }
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; return t;
}

function planetTexture(rng, hue) {
  const c = document.createElement('canvas'); c.width = 512; c.height = 256;
  const g = c.getContext('2d');
  for (let y = 0; y < 256; y += 2) {
    const v = Math.sin(y * 0.08 + rng() * 0.6) * 10 + rng() * 6;
    g.fillStyle = `hsl(${hue + v},${45 + v}%,${50 + v}%)`; g.fillRect(0, y, 512, 2);
  }
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; return t;
}

// ---------- particle system ----------
class Particles {
  constructor(sim, { count = 1500, color = '#ffffff', size = 0.15, additive = false, opacity = 1, sizeAttenuation = true } = {}) {
    this.sim = sim; this.count = count;
    this.pos = new Float32Array(count * 3); this.vel = new Float32Array(count * 3); this.life = new Float32Array(count);
    this.geo = new THREE.BufferGeometry(); this.geo.setAttribute('position', new THREE.BufferAttribute(this.pos, 3));
    this.mat = new THREE.PointsMaterial({ color: col(color), size, transparent: true, opacity, depthWrite: false, sizeAttenuation, blending: additive ? THREE.AdditiveBlending : THREE.NormalBlending });
    this.points = new THREE.Points(this.geo, this.mat); this.points.frustumCulled = false;
    for (let i = 0; i < count; i++) { this.life[i] = 0; this.pos[i * 3 + 1] = -9999; }
    sim.scene.add(this.points);
    this.cursor = 0; this.gravity = 0; this.drag = 0; this.floor = -Infinity; this.lifeMax = 3;
  }
  emit(x, y, z, vx, vy, vz, life = this.lifeMax) {
    const i = this.cursor; this.cursor = (this.cursor + 1) % this.count;
    this.pos[i * 3] = x; this.pos[i * 3 + 1] = y; this.pos[i * 3 + 2] = z;
    this.vel[i * 3] = vx; this.vel[i * 3 + 1] = vy; this.vel[i * 3 + 2] = vz; this.life[i] = life;
  }
  update(dt) {
    for (let i = 0; i < this.count; i++) {
      if (this.life[i] <= 0) continue;
      this.life[i] -= dt;
      if (this.life[i] <= 0) { this.pos[i * 3 + 1] = -9999; continue; }
      this.vel[i * 3 + 1] += this.gravity * dt;
      const d = 1 - this.drag * dt;
      this.vel[i * 3] *= d; this.vel[i * 3 + 1] *= d; this.vel[i * 3 + 2] *= d;
      this.pos[i * 3] += this.vel[i * 3] * dt; this.pos[i * 3 + 1] += this.vel[i * 3 + 1] * dt; this.pos[i * 3 + 2] += this.vel[i * 3 + 2] * dt;
      if (this.pos[i * 3 + 1] < this.floor) { this.pos[i * 3 + 1] = this.floor; this.vel[i * 3] *= 0.5; this.vel[i * 3 + 1] = 0; this.vel[i * 3 + 2] *= 0.5; }
    }
    this.geo.attributes.position.needsUpdate = true;
  }
}

// ---------- the simulation ----------
class Sim {
  constructor() {
    this.canvas = document.getElementById('gl');
    this.errors = [];
  }

  async init(spec, opts = {}) {
    this.spec = spec = normalizeSpec(spec);
    this.opts = opts;
    this.fps = opts.fps || 30; this.dt = 1 / this.fps;
    this.t = 0; this.frame = 0; this.simTime = 0;
    this.rng = mulberry32(hashStr(spec.seed ?? spec.title));
    const rng = this.rng;

    this.renderer = new THREE.WebGLRenderer({ canvas: this.canvas, antialias: true, preserveDrawingBuffer: true });
    this.renderer.setPixelRatio(opts.pixelRatio || 1);
    this.renderer.setSize(W, H, false);
    this.renderer.shadowMap.enabled = opts.shadows !== false;
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;

    this.scene = new THREE.Scene();
    this.camera = new THREE.PerspectiveCamera(spec.camera.fov || 68, W / H, 0.1, 4000);

    this.materials = []; this.matCache = new Map();
    this.glowMats = []; this.billboardMats = []; this.lampMats = [];
    this.entities = []; this.tags = new Map();
    this.particles = [];
    this.timeScale = 1;
    this.groundY = 0;
    this.base = { ...TIMES[spec.time] || TIMES.day };
    if (spec.sky) Object.assign(this.base, spec.sky);

    this.setupLights();
    this.setupSky();
    const builder = BUILDERS[spec.setting] || BUILDERS.city;
    builder(this, rng);
    this.setupClouds();

    // weather by default
    if (spec.weather && spec.weather !== 'clear') spec.effects.unshift({ type: 'weather', kind: spec.weather, start: 0, intensity: 0.6, ramp: 0.01 });

    // effects
    this.fx = spec.effects.map((fx, i) => ({ ...fx, _i: i, _state: {} }));
    for (const fx of this.fx) {
      const h = FX[fx.type];
      if (!h) { this.errors.push(`Unknown effect type "${fx.type}"`); continue; }
      try { h.setup && h.setup(this, fx); } catch (e) { this.err(e, fx); }
    }

    this.setupOverlay();
    this.update(0);
    this.render();
    return { ok: true, errors: this.errors, entities: this.entities.length };
  }

  err(e, fx) {
    const msg = `${fx ? `[effect ${fx.type}#${fx._i}] ` : ''}${e && e.message ? e.message : e}`;
    if (!this.errors.includes(msg)) { this.errors.push(msg); console.error(msg); }
  }

  // ----- materials & registry -----
  mat(color, o = {}) {
    const key = color + JSON.stringify(o);
    if (this.matCache.has(key)) return this.matCache.get(key);
    const m = new THREE.MeshStandardMaterial({ color: col(color), roughness: o.roughness ?? 0.8, metalness: o.metalness ?? 0.05, emissive: col(o.emissive || '#000000'), emissiveIntensity: o.emissiveIntensity ?? 1, transparent: !!o.transparent, opacity: o.opacity ?? 1, flatShading: !!o.flat });
    this.reg(m); this.matCache.set(key, m); return m;
  }
  reg(m) { m.userData.base = m.color.clone(); this.materials.push(m); return m; }
  tag(obj, tags) { for (let t of [].concat(tags)) { t = normTag(t); if (!this.tags.has(t)) this.tags.set(t, []); this.tags.get(t).push(obj); } obj.userData.baseScale = obj.scale.clone(); return obj; }
  tagged(t) { return this.tags.get(normTag(t)) || []; }
  addEntity(obj, kind, tags, extra = {}) {
    const e = { obj, kind, tags: new Set([].concat(tags).map(normTag)), vel: new THREE.Vector3(), angVel: new THREE.Vector3(), physics: false, g: -9.8, ...extra };
    obj.userData.ent = e;
    e.home = obj.position.clone();
    this.entities.push(e); this.tag(obj, [...e.tags]); this.scene.add(obj);
    return e;
  }
  ents(tag) { tag = normTag(tag); return this.entities.filter((e) => tag === 'movable' ? e.movable : e.tags.has(tag)); }

  // ----- environment -----
  setupLights() {
    const b = this.base;
    this.hemi = new THREE.HemisphereLight(col(b.hemiSky), col(b.hemiGround), b.hemiI); this.scene.add(this.hemi);
    this.sun = new THREE.DirectionalLight(col(b.sun), b.sunI);
    this.sun.castShadow = true;
    const s = this.sun.shadow; s.mapSize.set(2048, 2048); s.camera.left = -70; s.camera.right = 70; s.camera.top = 70; s.camera.bottom = -70; s.camera.near = 1; s.camera.far = 400; s.bias = -0.0005; s.normalBias = 0.04;
    this.scene.add(this.sun); this.scene.add(this.sun.target);
    this.sunDir = new THREE.Vector3(...b.sunDir).normalize();
    this.scene.fog = new THREE.Fog(col(b.fog), 60, 520);
  }
  setupSky() {
    const b = this.base;
    this.skyU = { top: { value: col(b.top) }, bottom: { value: col(b.bottom) }, sunDir: { value: new THREE.Vector3(...b.sunDir).normalize() }, sunColor: { value: col(b.sun) }, sunSize: { value: 1 }, sunVis: { value: this.spec.time === 'night' ? 0 : 1 } };
    const m = new THREE.ShaderMaterial({
      uniforms: this.skyU, side: THREE.BackSide, depthWrite: false, fog: false,
      vertexShader: 'varying vec3 vP; void main(){ vP = normalize(position); gl_Position = projectionMatrix*modelViewMatrix*vec4(position,1.); }',
      fragmentShader: `uniform vec3 top; uniform vec3 bottom; uniform vec3 sunDir; uniform vec3 sunColor; uniform float sunSize; uniform float sunVis; varying vec3 vP;
        void main(){ float h = clamp(vP.y*1.4+0.08,0.,1.); vec3 c = mix(bottom, top, pow(h,0.7));
          float d = max(dot(normalize(vP), normalize(sunDir)),0.);
          c += sunColor * sunVis * (pow(d, 900./sunSize)*2.5 + pow(d, 60.)*0.25);
          gl_FragColor = vec4(c,1.); }`,
    });
    this.sky = new THREE.Mesh(new THREE.SphereGeometry(2000, 32, 16), m); this.sky.renderOrder = -1; this.scene.add(this.sky);
    // stars
    const n = 1500, p = new Float32Array(n * 3), r = this.rng;
    for (let i = 0; i < n; i++) { const th = r() * Math.PI * 2, ph = Math.acos(r() * 0.95); p[i * 3] = Math.sin(ph) * Math.cos(th) * 1800; p[i * 3 + 1] = Math.cos(ph) * 1800; p[i * 3 + 2] = Math.sin(ph) * Math.sin(th) * 1800; }
    const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.BufferAttribute(p, 3));
    this.stars = new THREE.Points(g, new THREE.PointsMaterial({ color: 0xffffff, size: 2.2, sizeAttenuation: false, transparent: true, opacity: 0, fog: false, depthWrite: false }));
    this.scene.add(this.stars); this.tag(this.stars, 'stars');
  }
  setupClouds() {
    if (this.spec.time === 'night') return;
    const r = this.rng, m = this.mat('#ffffff', { roughness: 1 });
    const geo = new THREE.SphereGeometry(1, 10, 8);
    for (let i = 0; i < 10; i++) {
      const g = new THREE.Group();
      for (let j = 0; j < 5; j++) { const s = new THREE.Mesh(geo, m); s.scale.set(18 + r() * 14, 7 + r() * 5, 14 + r() * 8); s.position.set(j * 14 - 28 + r() * 6, r() * 4, r() * 8); g.add(s); }
      g.position.set(-500 + r() * 1000, 160 + r() * 80, -700 + r() * 600);
      this.addEntity(g, 'cloud', ['clouds'], { drift: 2 + r() * 3 });
    }
  }
  ground(color, size = 1200, y = 0) {
    const g = new THREE.Mesh(new THREE.PlaneGeometry(size, size), this.mat(color, { roughness: 0.95 }));
    g.rotation.x = -Math.PI / 2; g.position.y = y; g.receiveShadow = true; this.scene.add(g); this.tag(g, 'ground'); return g;
  }
  box(w, h, d, color, o = {}) {
    const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), o.material || this.mat(color, o));
    m.castShadow = o.cast !== false; m.receiveShadow = true; return m;
  }
  ocean({ x0 = 10, x1 = 600, z0 = -700, z1 = 200, y = 0, color = '#1f7aa8', segs = 90, amp = 0.35 } = {}) {
    const geo = new THREE.PlaneGeometry(x1 - x0, z1 - z0, segs, segs); geo.rotateX(-Math.PI / 2);
    const m = new THREE.MeshStandardMaterial({ color: col(color), roughness: 0.18, metalness: 0.15, transparent: true, opacity: 0.94, flatShading: false });
    this.reg(m);
    const mesh = new THREE.Mesh(geo, m); mesh.position.set((x0 + x1) / 2, y, (z0 + z1) / 2); mesh.receiveShadow = true;
    this.scene.add(mesh); this.tag(mesh, ['water']);
    this.water = { mesh, geo, base: geo.attributes.position.array.slice(), amp, level: y, baseLevel: y, mat: m, color: col(color) };
    // sea bed so draining the ocean looks right
    const bed = new THREE.Mesh(new THREE.PlaneGeometry(x1 - x0, z1 - z0), this.mat('#b59a6a', { roughness: 1 }));
    bed.rotation.x = -Math.PI / 2; bed.position.set((x0 + x1) / 2, y - 14, (z0 + z1) / 2); this.scene.add(bed);
    const slope = new THREE.Mesh(new THREE.PlaneGeometry(40, z1 - z0), this.mat('#cdb27c', { roughness: 1 }));
    slope.rotation.x = -Math.PI / 2; slope.rotation.y = -Math.atan2(14, 40); slope.position.set(x0 + 18, y - 7.2, (z0 + z1) / 2); this.scene.add(slope);
    return this.water;
  }

  // ----- reusable props -----
  car(x, z, dir, color, speed, opts = {}) {
    const g = new THREE.Group();
    const L = opts.bus ? 11 : 4.4, Wd = opts.bus ? 2.5 : 1.85, wheelR = opts.bus ? 0.55 : 0.36;
    const bodyH = opts.bus ? 2.6 : 0.72;
    const body = this.box(Wd, bodyH, L, color, { roughness: 0.35, metalness: 0.4 }); body.position.y = wheelR + bodyH / 2 + 0.05;
    const bodyGroup = new THREE.Group(); bodyGroup.add(body);
    if (!opts.bus) {
      const cab = this.box(Wd * 0.88, 0.62, L * 0.5, '#1d2b3a', { roughness: 0.15, metalness: 0.6 }); cab.position.set(0, wheelR + bodyH + 0.33, -0.15); bodyGroup.add(cab); this.tag(cab, 'glass');
      if (opts.taxi) { const sign = this.box(0.6, 0.18, 0.25, '#fff7c2', { emissive: '#ffd84a', emissiveIntensity: 0.6 }); sign.position.set(0, wheelR + bodyH + 0.75, -0.1); bodyGroup.add(sign); }
    } else {
      const win = this.box(Wd + 0.02, 0.8, L * 0.86, '#1d2b3a', { roughness: 0.15, metalness: 0.6 }); win.position.set(0, wheelR + bodyH * 0.7, 0); bodyGroup.add(win); this.tag(win, 'glass');
    }
    const hl = this.box(0.35, 0.14, 0.05, '#ffffff', { emissive: '#fff4cc', emissiveIntensity: 1.5, cast: false });
    const hl2 = hl.clone(); hl.position.set(-Wd * 0.33, wheelR + 0.45, -L / 2); hl2.position.set(Wd * 0.33, wheelR + 0.45, -L / 2);
    const tl = this.box(0.35, 0.12, 0.05, '#ff2a2a', { emissive: '#ff1a1a', emissiveIntensity: 1.2, cast: false });
    const tl2 = tl.clone(); tl.position.set(-Wd * 0.33, wheelR + 0.45, L / 2); tl2.position.set(Wd * 0.33, wheelR + 0.45, L / 2);
    bodyGroup.add(hl, hl2, tl, tl2);
    g.add(bodyGroup);
    const wheels = [];
    const wg = this._wheelGeo || (this._wheelGeo = new THREE.CylinderGeometry(1, 1, 1, 14).rotateZ(Math.PI / 2));
    for (const [wx, wz] of [[-1, -1], [1, -1], [-1, 1], [1, 1]]) {
      const w = new THREE.Mesh(wg, this.mat('#161616', { roughness: 0.9 })); w.scale.set(0.28, wheelR, wheelR);
      w.position.set(wx * (Wd / 2 - 0.08), wheelR, wz * (L / 2 - (opts.bus ? 1.6 : 0.8))); w.castShadow = true; g.add(w); wheels.push(w); this.tag(w, ['tires']);
    }
    g.position.set(x, 0, z); g.rotation.y = dir > 0 ? Math.PI : 0;
    this.tag(bodyGroup, ['metal']);
    return this.addEntity(g, 'car', ['cars', 'vehicles', opts.bus ? 'buses' : 'cars'], { dir, speed, baseSpeed: speed, wheels, body: bodyGroup, wheelR, movable: true, lane: x, zMin: opts.zMin ?? -260, zMax: opts.zMax ?? 80, axis: opts.axis || 'z', parked: !!opts.parked });
  }
  person(x, z, rng, opts = {}) {
    const P = this._pgeo || (this._pgeo = { leg: new THREE.BoxGeometry(0.16, 0.82, 0.18).translate(0, -0.41, 0), torso: new THREE.BoxGeometry(0.46, 0.64, 0.27), arm: new THREE.BoxGeometry(0.12, 0.6, 0.14).translate(0, -0.3, 0), head: new THREE.BoxGeometry(0.27, 0.29, 0.27), hair: new THREE.BoxGeometry(0.29, 0.1, 0.29) });
    const shirts = ['#e23b3b', '#2f6fe0', '#f2c230', '#37b24d', '#ffffff', '#222831', '#ff7a1a', '#8e44ad', '#16a3b8', '#ff4f9a', '#c0c7d1'];
    const pants = ['#24324a', '#1d1d1d', '#4a5568', '#6b4f3a', '#2b4a7e', '#c8b38a'];
    const skins = ['#f1c7a5', '#d9a57c', '#a8714b', '#6e4529', '#ffdbc2', '#c68a62'];
    const pick = (a) => a[Math.floor(rng() * a.length)];
    const g = new THREE.Group();
    const pm = this.mat(pick(pants)), sm = this.mat(pick(shirts)), skin = this.mat(pick(skins)), hm = this.mat(pick(['#1b1410', '#3b2414', '#6b4a2a', '#d6b46a', '#111111', '#8a8a8a']));
    const legL = new THREE.Mesh(P.leg, pm), legR = new THREE.Mesh(P.leg, pm); legL.position.set(-0.11, 0.84, 0); legR.position.set(0.11, 0.84, 0);
    const torso = new THREE.Mesh(P.torso, sm); torso.position.y = 1.16;
    const armL = new THREE.Mesh(P.arm, sm), armR = new THREE.Mesh(P.arm, sm); armL.position.set(-0.3, 1.45, 0); armR.position.set(0.3, 1.45, 0);
    const head = new THREE.Mesh(P.head, skin); head.position.y = 1.64;
    const hair = new THREE.Mesh(P.hair, hm); hair.position.y = 1.8;
    for (const m of [legL, legR, torso, armL, armR, head]) m.castShadow = true;
    g.add(legL, legR, torso, armL, armR, head, hair);
    const s = 0.9 + rng() * 0.2; g.scale.setScalar(s);
    g.position.set(x, 0, z);
    const dir = opts.dir ?? (rng() < 0.5 ? 1 : -1);
    g.rotation.y = opts.static ? rng() * Math.PI * 2 : (dir > 0 ? 0 : Math.PI);
    return this.addEntity(g, 'person', ['people'], { legs: [legL, legR], arms: [armL, armR], dir, speed: opts.static ? 0 : 1.1 + rng() * 0.6, baseSpeed: opts.static ? 0 : 1.1 + rng() * 0.6, phase: rng() * 6, movable: true, zMin: opts.zMin ?? -200, zMax: opts.zMax ?? 60, axis: opts.axis || 'z', static: !!opts.static });
  }
  palm(x, z, rng) {
    const g = new THREE.Group();
    const h = 7 + rng() * 4, lean = (rng() - 0.5) * 0.25;
    const trunk = new THREE.Mesh(new THREE.CylinderGeometry(0.18, 0.3, h, 7), this.mat('#8b6a45')); trunk.position.y = h / 2; trunk.castShadow = true;
    const crown = new THREE.Group(); crown.position.y = h;
    const leafGeo = this._leaf || (this._leaf = new THREE.BoxGeometry(0.7, 0.06, 3.6).translate(0, 0, 1.8));
    for (let i = 0; i < 8; i++) { const l = new THREE.Mesh(leafGeo, this.mat('#2f8a3a')); l.rotation.y = (i / 8) * Math.PI * 2; l.rotation.x = 0.45; l.castShadow = true; crown.add(l); }
    const pivot = new THREE.Group(); pivot.add(trunk, crown); pivot.rotation.z = lean; g.add(pivot); g.position.set(x, 0, z);
    return this.addEntity(g, 'tree', ['trees'], { canopy: pivot, lean, movable: true, rooted: true });
  }
  tree(x, z, rng, kind = 'round') {
    const g = new THREE.Group(); const h = 3 + rng() * 3;
    const trunk = new THREE.Mesh(new THREE.CylinderGeometry(0.2, 0.3, h, 6), this.mat('#6b4a2e')); trunk.position.y = h / 2; trunk.castShadow = true;
    const pivot = new THREE.Group(); pivot.add(trunk);
    if (kind === 'pine') {
      for (let i = 0; i < 3; i++) { const c = new THREE.Mesh(new THREE.ConeGeometry(2.2 - i * 0.5, 2.6, 7), this.mat(this.spec.setting === 'snow' ? '#2e5b45' : '#2c6e3f', { flat: true })); c.position.y = h + i * 1.4 - 0.4; c.castShadow = true; pivot.add(c); }
    } else if (kind === 'cactus') {
      trunk.material = this.mat('#4f8a3c'); trunk.scale.set(1.6, 1, 1.6);
      const arm = new THREE.Mesh(new THREE.CylinderGeometry(0.22, 0.22, 1.4, 6), this.mat('#4f8a3c')); arm.position.set(0.6, h * 0.6, 0); arm.castShadow = true; pivot.add(arm);
    } else {
      const c = new THREE.Mesh(new THREE.IcosahedronGeometry(2 + rng(), 0), this.mat(['#3f8f3a', '#4c9a3f', '#2f7a34', '#6aa84f'][Math.floor(rng() * 4)], { flat: true })); c.position.y = h + 1.2; c.castShadow = true; pivot.add(c);
    }
    g.add(pivot); g.position.set(x, 0, z);
    return this.addEntity(g, 'tree', ['trees'], { canopy: pivot, lean: 0, movable: true, rooted: true });
  }
  building(x, z, w, d, h, rng, opts = {}) {
    const styles = opts.styles || [
      { wall: '#3a3f4b', glass: '#5d7896', litRatio: 0.35 }, { wall: '#7b6a5a', glass: '#4b6178', litRatio: 0.3 }, { wall: '#c9c2b5', glass: '#56708c', litRatio: 0.3 },
      { wall: '#2a3140', glass: '#7fa6c9', litRatio: 0.45 }, { wall: '#8a4b3a', glass: '#3f5266', litRatio: 0.3 }, { wall: '#d8d4cc', glass: '#6c8db0', litRatio: 0.25 }];
    const st = styles[Math.floor(rng() * styles.length)];
    const tex = this._winTex && rng() < 0.6 ? this._winTex[Math.floor(rng() * this._winTex.length)] : null;
    const tx = tex || windowTexture(rng, st);
    if (!this._winTex) this._winTex = []; if (!tex) this._winTex.push(tx);
    const map = tx.map.clone(), em = tx.emissive.clone(); map.needsUpdate = true; em.needsUpdate = true;
    map.repeat.set(Math.max(1, Math.round(w / 6)), Math.max(1, Math.round(h / 7))); em.repeat.copy(map.repeat);
    const m = new THREE.MeshStandardMaterial({ map, emissiveMap: em, emissive: col('#ffffff'), emissiveIntensity: 0.1, roughness: 0.7, metalness: 0.1 });
    this.reg(m); this.glowMats.push(m);
    const roof = this.mat('#2b2e33');
    const mesh = new THREE.Mesh(new THREE.BoxGeometry(w, h, d).translate(0, h / 2, 0), [m, m, roof, roof, m, m]);
    mesh.castShadow = true; mesh.receiveShadow = true;
    const g = new THREE.Group(); g.add(mesh); g.position.set(x, 0, z);
    return this.addEntity(g, 'building', ['buildings'], { h, w, d, mesh });
  }
  billboard(x, y, z, w, h, facing, rng) {
    const m = new THREE.MeshBasicMaterial({ map: billboardTexture(rng), toneMapped: false });
    m.userData.base = m.color.clone(); this.billboardMats.push(m); this.materials.push(m);
    const p = new THREE.Mesh(new THREE.PlaneGeometry(w, h), m); p.position.set(x, y, z); p.rotation.y = facing;
    const frame = new THREE.Mesh(new THREE.BoxGeometry(w + 0.4, h + 0.4, 0.3), this.mat('#111111')); frame.position.set(0, 0, -0.2); p.add(frame);
    this.scene.add(p); this.tag(p, ['billboards']); return p;
  }
  lamp(x, z, side) {
    const g = new THREE.Group();
    const pole = new THREE.Mesh(new THREE.CylinderGeometry(0.08, 0.1, 6, 6), this.mat('#3a3d42', { metalness: 0.6, roughness: 0.4 })); pole.position.y = 3; pole.castShadow = true;
    const arm = this.box(1.4, 0.1, 0.1, '#3a3d42'); arm.position.set(-side * 0.7, 6, 0);
    const lm = new THREE.MeshStandardMaterial({ color: col('#fff3d6'), emissive: col('#ffd890'), emissiveIntensity: 0 }); this.reg(lm); this.lampMats.push(lm);
    const head = new THREE.Mesh(new THREE.BoxGeometry(0.6, 0.15, 0.3), lm); head.position.set(-side * 1.3, 5.95, 0);
    g.add(pole, arm, head); g.position.set(x, 0, z); this.scene.add(g); this.tag(g, ['lamps', 'metal']); return g;
  }
  ferrisWheel(x, z, r = 14) {
    const g = new THREE.Group(); const wheel = new THREE.Group();
    const rim = new THREE.Mesh(new THREE.TorusGeometry(r, 0.25, 6, 48), this.mat('#e8e8e8', { metalness: 0.5 })); wheel.add(rim);
    const rim2 = rim.clone(); rim2.position.z = 1.2; wheel.add(rim2);
    const colors = ['#e74c3c', '#f1c40f', '#3498db', '#2ecc71', '#9b59b6', '#e67e22'];
    this.gondolas = [];
    for (let i = 0; i < 16; i++) {
      const a = (i / 16) * Math.PI * 2;
      const sp = this.box(0.12, r, 0.12, '#dcdcdc'); sp.position.set(Math.cos(a) * r / 2, Math.sin(a) * r / 2, 0.6); sp.rotation.z = a - Math.PI / 2; wheel.add(sp);
      const gd = this.box(1.2, 1.2, 1.2, colors[i % colors.length]); gd.position.set(Math.cos(a) * r, Math.sin(a) * r - 0.8, 0.6); wheel.add(gd); this.gondolas.push(gd);
    }
    wheel.position.y = r + 3; g.add(wheel);
    for (const s of [-1, 1]) { const leg = this.box(0.4, r + 4, 0.4, '#cfcfcf'); leg.position.set(s * 4, (r + 3) / 2, 0.6); leg.rotation.z = s * 0.25; g.add(leg); }
    g.position.set(x, 0, z); g.rotation.y = Math.PI / 2;
    this.addEntity(g, 'ferris', ['ferris_wheel', 'metal'], { wheel, spin: 0.08 });
  }
  umbrella(x, z, rng) {
    const g = new THREE.Group();
    const pole = new THREE.Mesh(new THREE.CylinderGeometry(0.04, 0.04, 2.2, 5), this.mat('#eeeeee')); pole.position.y = 1.1;
    const top = new THREE.Mesh(new THREE.ConeGeometry(1.4, 0.6, 8), this.mat(['#e74c3c', '#f1c40f', '#1abc9c', '#3498db', '#ff6fa8'][Math.floor(rng() * 5)])); top.position.y = 2.2; top.castShadow = true;
    g.add(pole, top); g.position.set(x, 0, z);
    return this.addEntity(g, 'prop', ['umbrellas'], { movable: true });
  }
  house(x, z, rng, facing) {
    const g = new THREE.Group(); const w = 8 + rng() * 3, d = 8 + rng() * 2, h = 3 + rng() * 3;
    const walls = this.box(w, h, d, ['#efe6d8', '#d9e2ec', '#f4d9c6', '#e8e1b8', '#cfd8c4'][Math.floor(rng() * 5)]); walls.position.y = h / 2;
    const roof = new THREE.Mesh(new THREE.ConeGeometry(Math.max(w, d) * 0.75, 3, 4), this.mat(['#8a3b2e', '#4a4f57', '#5b3a29'][Math.floor(rng() * 3)], { flat: true })); roof.position.y = h + 1.5; roof.rotation.y = Math.PI / 4; roof.castShadow = true;
    const door = this.box(1.1, 2.1, 0.1, '#5a3d2b'); door.position.set(0, 1.05, d / 2 + 0.05);
    const win = new THREE.MeshStandardMaterial({ color: col('#9cc4e4'), emissive: col('#ffd890'), emissiveIntensity: 0.05 }); this.reg(win); this.glowMats.push(win);
    for (const s of [-1, 1]) { const wdw = new THREE.Mesh(new THREE.BoxGeometry(1.4, 1.2, 0.1), win); wdw.position.set(s * w * 0.28, h * 0.55, d / 2 + 0.06); g.add(wdw); }
    g.add(walls, roof, door); g.position.set(x, 0, z); g.rotation.y = facing;
    return this.addEntity(g, 'building', ['buildings', 'houses'], { h, w, d });
  }

  // ----- overlay -----
  setupOverlay() {
    const s = this.spec;
    document.getElementById('watermark').textContent = s.handle ? '@' + s.handle.replace(/^@/, '') : '';
    document.getElementById('location').textContent = s.location || '';
    const hud = document.getElementById('hud'); hud.innerHTML = ''; hud.className = s.hudSide === 'right' ? 'right' : '';
    this.hudEls = s.hud.map((h) => {
      const d = document.createElement('div'); d.className = 'hud-item' + (h.alert ? ' alert' : '');
      d.innerHTML = `<div class="lbl"></div><div class="val"></div>${h.sub ? '<div class="sub"></div>' : ''}`;
      d.querySelector('.lbl').textContent = h.label || '';
      if (h.sub) d.querySelector('.sub').textContent = h.sub;
      hud.appendChild(d); return d;
    });
    const ec = document.getElementById('endcard');
    if (s.endcard) { ec.querySelector('.ec-q').textContent = s.endcard.text || ''; ec.querySelector('.ec-follow').textContent = s.endcard.cta || 'Follow for part 2'; }
  }
  updateOverlay(t) {
    const s = this.spec;
    const fade = (a, b, tt, f = 0.35) => b == null ? clamp((tt - a) / f) : Math.min(clamp((tt - a) / f), clamp((b - tt) / f));
    document.getElementById('location').style.opacity = s.location ? fade(0.2, s.duration - 0.2, t) * 0.9 : 0;
    s.hud.forEach((h, i) => {
      const el = this.hudEls[i];
      const show0 = h.show?.[0] ?? 0.3, show1 = h.show?.[1] ?? s.duration;
      el.style.opacity = fade(show0, show1, t);
      const p = h.end > h.start ? clamp((t - h.start) / (h.end - h.start)) : (t >= h.start ? 1 : 0);
      const e = h.ease === 'linear' ? p : h.ease === 'in' ? p * p * p : 1 - Math.pow(1 - p, 3);
      const v = lerp(h.from, h.to, e);
      el.querySelector('.val').innerHTML = `${fmtNum(v, h)}${h.unit ? `<small>${escapeHtml(h.unit)}</small>` : ''}`;
      el.classList.toggle('alert', !!h.alert && p > 0 && p < 1 || (h.alertAfter != null && t >= h.alertAfter));
    });
    for (const style of ['title', 'subtitle', 'big']) {
      const el = document.getElementById(style);
      let best = null;
      for (const c of s.captions) if ((c.style || 'subtitle') === style && t >= c.start - 0.35 && t <= (c.end ?? s.duration) + 0.35) best = c;
      if (best) {
        if (el.dataset.txt !== best.text) { el.textContent = best.text; el.dataset.txt = best.text; el.style.color = best.color || ''; }
        const o = fade(best.start, best.end ?? s.duration - 0.05, t);
        el.style.opacity = o; el.style.transform = style === 'big' ? `scale(${0.85 + 0.15 * smooth(clamp((t - best.start) / 0.25))})` : `translateY(${(1 - smooth(clamp((t - best.start) / 0.4))) * 14}px)`;
      } else el.style.opacity = 0;
    }
    const ec = document.getElementById('endcard');
    ec.style.opacity = s.endcard ? clamp((t - s.endcard.start) / 0.4) : 0;
  }

  // ----- camera -----
  updateCamera(t) {
    const c = this.spec.camera, mode = c.mode;
    const T = t * (c.speed ?? 1);
    const o = this.camOrigin || [0, 0, 0];
    if (this.roadCam && (mode === 'street' || mode === 'low' || mode === 'static')) c.offsetX = clamp(c.offsetX ?? 0, -0.3, 0.3);
    let pos, look;
    if (mode === 'aerial') {
      const a = (c.angle ?? 0.6) + T * 0.025, r = c.distance ?? 95;
      pos = new THREE.Vector3(o[0] + Math.sin(a) * r, c.height ?? 55, o[2] + Math.cos(a) * r);
      look = new THREE.Vector3(o[0], 0, o[2] - 10);
    } else if (mode === 'orbit') {
      const a = (c.angle ?? 0.3) + T * 0.06, r = c.distance ?? 38;
      pos = new THREE.Vector3(o[0] + Math.sin(a) * r, c.height ?? 10, o[2] + Math.cos(a) * r);
      look = new THREE.Vector3(o[0], 4, o[2]);
    } else if (mode === 'drone') {
      const p = clamp(T / Math.max(1, this.spec.duration));
      pos = new THREE.Vector3(o[0], lerp(3, c.height ?? 45, smooth(p)), o[2] + 30 - T * 2.2);
      look = new THREE.Vector3(o[0], lerp(4, 0, smooth(p)), pos.z - 70);
    } else if (mode === 'low') {
      pos = new THREE.Vector3(o[0] + (c.offsetX ?? 0), 0.7, o[2] + 26 - T * 0.9);
      look = new THREE.Vector3(o[0] + (c.offsetX ?? 0) * 0.5, 4, pos.z - 60);
    } else if (mode === 'static') {
      pos = new THREE.Vector3(o[0] + (c.offsetX ?? 0), c.height ?? 3, o[2] + 26);
      look = new THREE.Vector3(o[0], (c.height ?? 3) + 2, o[2] - 60);
    } else { // street
      const h = c.height ?? 3.2;
      pos = new THREE.Vector3(o[0] + (c.offsetX ?? 0) + Math.sin(T * 0.3) * 0.25, h + Math.sin(T * 0.7) * 0.05, o[2] + 26 - T * 1.2);
      look = new THREE.Vector3(o[0] + (c.lookX ?? 0), h + 4.5, pos.z - 60);
    }
    if (this.floodLevel != null) { const minY = this.floodLevel + 1.6; if (pos.y < minY) { look.y += minY - pos.y; pos.y = minY; } }
    const sh = this.shake;
    if (sh > 0) { const n = (k) => Math.sin(t * 37 + k) * 0.6 + Math.sin(t * 23 + k * 3) * 0.4; pos.x += n(1) * sh; pos.y += n(2) * sh * 0.6; pos.z += n(3) * sh * 0.4; look.x += n(4) * sh * 0.5; }
    this.camera.position.copy(pos); this.camera.lookAt(look);
    this.camera.fov = c.fov || 68; this.camera.updateProjectionMatrix();
    // keep sun shadow centred around what the camera sees
    const focus = pos.clone().add(look.clone().sub(pos).setY(0).normalize().multiplyScalar(35)); focus.y = 0;
    this.sun.target.position.copy(focus); this.sun.position.copy(focus).addScaledVector(this.sunDir, 150);
    this.sky.position.copy(pos); this.stars.position.copy(pos);
  }

  // ----- main update -----
  update(dt) {
    const t = this.t;
    // reset look accumulators
    const b = this.base;
    this.look = {
      sunI: b.sunI, hemiI: b.hemiI, top: col(b.top), bottom: col(b.bottom), fog: col(b.fog), fogNear: 60, fogFar: 520,
      tint: col('#ffffff'), tintAmt: 0, glow: b.glow, billboard: 1, lamps: this.spec.time === 'night' ? 1 : this.spec.time === 'sunset' ? 0.5 : 0, stars: b.stars, sunColor: col(b.sun), sunSize: 1, sunVis: this.spec.time === 'night' ? 0 : 1,
      exposure: b.exposure, filter: [], gradeColor: null, gradeAmt: 0, flash: 0, waveMul: 1, waterColor: this.water?.color.clone(), waterOffset: 0,
    };
    this.shake = 0; this.floodLevel = null; this.timeScale = 1; this.wind = 0; this.windDir = new THREE.Vector3(1, 0, 0);
    this.gravityScale = 1;
    // effects
    for (const fx of this.fx) {
      const h = FX[fx.type]; if (!h || !h.update) continue;
      const k = fxK(fx, t);
      try { h.update(this, fx, k, t, dt); } catch (e) { this.err(e, fx); }
    }
    if (this.customError) { this.errors.push(this.customError); this.customError = null; }
    const sdt = dt * this.timeScale; this.simTime += sdt;
    this.updateEntities(sdt, dt);
    for (const p of this.particles) p.update(dt);
    this.applyLook();
    this.updateCamera(t);
    this.updateOverlay(t);
  }

  updateEntities(sdt, dt) {
    const wind = this.wind;
    for (const e of this.entities) {
      const o = e.obj;
      if (e.hidden) continue;
      if (e.physics) {
        e.vel.y += e.g * this.gravityScale * dt * (e.floatMul ?? 1);
        if (wind > 0 && !e.rooted) e.vel.addScaledVector(this.windDir, wind * 6 * dt / (e.kind === 'car' ? 4 : 1));
        o.position.addScaledVector(e.vel, dt);
        o.rotation.x += e.angVel.x * dt; o.rotation.y += e.angVel.y * dt; o.rotation.z += e.angVel.z * dt;
        const floor = this.floorAt(o.position) + (e.kind === 'car' && e.tiresGone ? -e.wheelR + 0.05 : 0);
        if (o.position.y <= floor && e.vel.y <= 0) {
          o.position.y = floor;
          if (Math.abs(e.vel.y) > 3) { e.vel.y *= -0.25; e.angVel.multiplyScalar(0.5); this.dust(o.position, 6); }
          else { e.vel.y = 0; e.vel.x *= 0.85; e.vel.z *= 0.85; e.angVel.multiplyScalar(0.8); if (e.landing) { o.rotation.x *= 0.85; o.rotation.z *= 0.85; } }
        }
        continue;
      }
      if (e.kind === 'car') {
        const tiresGone = e.wheels.length && e.wheels[0].scale.y < e.wheelR * 0.5;
        if (tiresGone && !e.tiresGone) { e.tiresGone = true; }
        if (!tiresGone && e.tiresGone) { e.tiresGone = false; }
        const targetY = e.tiresGone ? -e.wheelR + 0.06 : 0;
        o.position.y += (targetY - o.position.y) * Math.min(1, dt * 14);
        if (e.tiresGone) {
          e.speed = Math.max(0, e.speed - 9 * dt);
          if (e.speed > 0.5 && this.sparks) for (let i = 0; i < 8; i++) this.sparks.emit(o.position.x + (this.rng() - 0.5) * 1.6, 0.1, o.position.z + (this.rng() - 0.5) * 4, (this.rng() - 0.5) * 3, 1 + this.rng() * 2, -e.dir * e.speed * 0.6 + (this.rng() - 0.5) * 2, 0.5);
          e.body.rotation.z = Math.sin(this.simTime * 30 + e.home.z) * 0.01 * Math.min(1, e.speed);
        } else if (!e.parked) {
          e.speed += (e.baseSpeed * (e.speedMul ?? 1) - e.speed) * Math.min(1, dt * 0.8);
        }
        if (!e.parked) {
          const ax = e.axis; o.position[ax] += e.dir * e.speed * sdt;
          if (o.position[ax] > e.zMax) o.position[ax] = e.zMin; if (o.position[ax] < e.zMin) o.position[ax] = e.zMax;
          for (const w of e.wheels) w.rotation.x += (e.speed * sdt / e.wheelR) * -e.dir;
        }
        if (wind > 0.4 && !e.tiresGone) { o.position.x += this.windDir.x * (wind - 0.4) * 2.5 * sdt; o.rotation.z = Math.sin(this.simTime * 8 + e.home.z) * 0.04 * wind; }
      } else if (e.kind === 'person') {
        const sp = e.speed * (e.speedMul ?? 1);
        if (!e.static && sp > 0) {
          if (e.runDir) { o.position.x += e.runDir.x * sp * sdt; o.position.z += e.runDir.z * sp * sdt; }
          else { const ax = e.axis; o.position[ax] += e.dir * sp * sdt; if (o.position[ax] > e.zMax) o.position[ax] = e.zMin; if (o.position[ax] < e.zMin) o.position[ax] = e.zMax; }
        }
        const ph = this.simTime * (sp * 5) + e.phase, sw = sp > 0 ? Math.sin(ph) * Math.min(0.7, sp * 0.4) : 0;
        e.legs[0].rotation.x = sw; e.legs[1].rotation.x = -sw; e.arms[0].rotation.x = -sw * 0.8; e.arms[1].rotation.x = sw * 0.8;
        if (e.armsUp) { e.arms[0].rotation.x = e.arms[1].rotation.x = Math.PI + Math.sin(this.simTime * 8 + e.phase) * 0.2; }
        o.position.y = this.floorAt(o.position) + (sp > 0 ? Math.abs(Math.sin(ph)) * 0.04 : 0);
        if (wind > 0.3) o.rotation.z = -this.windDir.x * wind * 0.25;
      } else if (e.kind === 'tree') {
        const sway = Math.sin(this.simTime * 1.3 + e.home.x) * 0.02 + Math.sin(this.simTime * (2 + wind * 6) + e.home.z) * wind * 0.12;
        e.canopy.rotation.z = e.lean - this.windDir.x * wind * 0.45 + sway;
      } else if (e.kind === 'cloud') {
        o.position.x += (e.drift + wind * 40) * sdt;
      } else if (e.kind === 'boat') {
        const lvl = this.water ? this.water.level : 0;
        o.position.y += ((lvl - 0.2 + Math.sin(this.simTime * 1.2 + e.home.x) * 0.3 * this.look.waveMul) - o.position.y) * Math.min(1, dt * 3);
        o.position.y = Math.max(o.position.y, (this.water ? this.water.baseLevel - 13.5 : -100));
        o.rotation.z = Math.sin(this.simTime * 0.9 + e.home.z) * 0.05 * this.look.waveMul; o.position.z += e.speed * sdt;
      } else if (e.kind === 'ferris') {
        e.wheel.rotation.z += e.spin * sdt;
        for (const gd of this.gondolas) gd.rotation.z = -e.wheel.rotation.z;
      }
    }
    // water waves
    if (this.water) {
      const w = this.water, pa = w.geo.attributes.position.array, base = w.base, amp = w.amp * this.look.waveMul, st = this.simTime;
      for (let i = 0; i < pa.length; i += 3) {
        const x = base[i], z = base[i + 2];
        pa[i + 1] = (Math.sin(x * 0.08 + st * 1.4) * 0.6 + Math.sin(z * 0.11 + st * 1.1) * 0.5 + Math.sin((x + z) * 0.23 + st * 2.1) * 0.25) * amp;
      }
      w.geo.attributes.position.needsUpdate = true; w.geo.computeVertexNormals();
      w.mesh.position.y = w.level + this.look.waterOffset;
    }
  }
  floorAt(p) { return this.groundY; }

  applyLook() {
    const L = this.look, r = this.renderer;
    this.sun.intensity = L.sunI; this.sun.color.copy(L.sunColor); this.hemi.intensity = L.hemiI;
    this.skyU.top.value.copy(L.top); this.skyU.bottom.value.copy(L.bottom); this.skyU.sunColor.value.copy(L.sunColor); this.skyU.sunSize.value = L.sunSize; this.skyU.sunVis.value = L.sunVis;
    this.skyU.sunDir.value.copy(this.sunDir);
    this.scene.fog.color.copy(L.fog); this.scene.fog.near = L.fogNear; this.scene.fog.far = L.fogFar;
    this.stars.material.opacity = clamp(L.stars);
    for (const m of this.materials) { if (!m.userData.base) continue; m.color.copy(m.userData.base); if (L.tintAmt > 0) m.color.lerp(L.tint, L.tintAmt); }
    for (const m of this.billboardMats) m.color.multiplyScalar(clamp(L.billboard));
    for (const m of this.glowMats) m.emissiveIntensity = L.glow;
    for (const m of this.lampMats) m.emissiveIntensity = L.lamps * 2.5;
    if (this.water && L.waterColor) this.water.mat.color.copy(L.waterColor).lerp(L.tint, L.tintAmt * 0.8);
    r.toneMappingExposure = L.exposure;
    this.canvas.style.filter = L.filter.join(' ');
    const gd = document.getElementById('grade');
    if (L.gradeColor && L.gradeAmt > 0) { gd.style.background = L.gradeColor; gd.style.opacity = L.gradeAmt; } else gd.style.opacity = 0;
    document.getElementById('flash').style.opacity = clamp(L.flash);
  }

  dust(p, n = 20, color) {
    if (!this.dustPS) { this.dustPS = new Particles(this, { count: 3000, color: '#b9a98f', size: 0.6, opacity: 0.6 }); this.dustPS.gravity = -0.5; this.dustPS.drag = 1.2; this.dustPS.floor = 0; this.particles.push(this.dustPS); }
    for (let i = 0; i < n; i++) this.dustPS.emit(p.x + (this.rng() - 0.5) * 2, p.y + this.rng(), p.z + (this.rng() - 0.5) * 2, (this.rng() - 0.5) * 6, this.rng() * 3, (this.rng() - 0.5) * 6, 1.5 + this.rng() * 1.5);
  }

  render() { this.renderer.render(this.scene, this.camera); }

  step(n = 1, doRender = true) {
    for (let i = 0; i < n; i++) { this.t += this.dt; this.frame++; this.update(this.dt); }
    if (doRender) this.render();
    return this.frame;
  }
  stepTo(t) { const n = Math.max(0, Math.round(t * this.fps) - this.frame); return this.step(n, true); }
}

function fmtNum(v, h) {
  const d = h.decimals ?? (Math.abs(h.to - h.from) < 20 && Math.round(h.to) !== h.to ? 1 : 0);
  if (h.format === 'compact') {
    const a = Math.abs(v);
    if (a >= 1e9) return (v / 1e9).toFixed(1) + 'B'; if (a >= 1e6) return (v / 1e6).toFixed(1) + 'M'; if (a >= 1e3) return (v / 1e3).toFixed(1) + 'K';
  }
  if (h.format === 'time') { const s = Math.max(0, v); return `${Math.floor(s / 60)}:${String(Math.floor(s % 60)).padStart(2, '0')}`; }
  return v.toLocaleString('en-US', { minimumFractionDigits: d, maximumFractionDigits: d });
}
function escapeHtml(s) { return String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]); }

function fxK(fx, t) {
  const r = fx.ramp ?? 0.8;
  if (t < fx.start) return 0;
  let k = r <= 0 ? 1 : smooth((t - fx.start) / r);
  if (fx.end != null && fx.revert) k = Math.min(k, r <= 0 ? (t <= fx.end ? 1 : 0) : smooth((fx.end + r - t) / r));
  return k * (fx.intensity ?? 1);
}

// ---------- world builders ----------
const BUILDERS = {
  city(sim, r) {
    sim.roadCam = true;
    sim.ground('#5d5f63');
    const roadW = 15, zMin = -320, zMax = 90;
    const road = new THREE.Mesh(new THREE.PlaneGeometry(roadW, zMax - zMin), sim.mat('#45484e', { roughness: 0.9 })); road.rotation.x = -Math.PI / 2; road.position.set(0, 0.01, (zMin + zMax) / 2); road.receiveShadow = true; sim.scene.add(road); sim.tag(road, 'roads');
    for (const x of [-0.18, 0.18]) { const l = new THREE.Mesh(new THREE.PlaneGeometry(0.18, zMax - zMin), sim.mat('#f2c230', { roughness: 0.6 })); l.rotation.x = -Math.PI / 2; l.position.set(x, 0.02, (zMin + zMax) / 2); sim.scene.add(l); }
    for (let z = zMin; z < zMax; z += 9) for (const x of [-3.8, 3.8]) { const d = new THREE.Mesh(new THREE.PlaneGeometry(0.16, 3.5), sim.mat('#e8e8e8')); d.rotation.x = -Math.PI / 2; d.position.set(x, 0.02, z); sim.scene.add(d); }
    // crosswalks
    for (const cz of [-40, -130, -220]) for (let x = -6.5; x <= 6.5; x += 1.3) { const s = new THREE.Mesh(new THREE.PlaneGeometry(0.7, 4), sim.mat('#efefef')); s.rotation.x = -Math.PI / 2; s.position.set(x, 0.021, cz); sim.scene.add(s); }
    for (const s of [-1, 1]) {
      const sw = sim.box(7, 0.2, zMax - zMin, '#9b9a95', { cast: false }); sw.position.set(s * (roadW / 2 + 3.5), 0.1, (zMin + zMax) / 2); sim.scene.add(sw);
    }
    // buildings
    const dens = sim.spec.density ?? 1;
    for (const s of [-1, 1]) {
      let z = zMax;
      while (z > zMin - 40) {
        const w = 14 + r() * 14, d = 18 + r() * 14, h = (24 + Math.pow(r(), 1.5) * 90) * (0.6 + dens * 0.4);
        const b = sim.building(s * (roadW / 2 + 7 + d / 2), z - w / 2, d, w, h, r);
        if (r() < 0.75) {
          const bw = Math.min(w - 2, 6 + r() * 8), bh = 5 + r() * 10, by = 7 + bh / 2 + r() * Math.max(0, h - bh - 14);
          sim.billboard(s * (roadW / 2 + 6.8), Math.min(by, h - bh / 2 - 1), z - w / 2, bw, bh, s > 0 ? -Math.PI / 2 : Math.PI / 2, r);
          if (r() < 0.5) sim.billboard(s * (roadW / 2 + 6.8), Math.max(5, by - bh - 2), z - w / 2 + (r() - 0.5) * 4, bw * 0.8, bh * 0.6, s > 0 ? -Math.PI / 2 : Math.PI / 2, r);
        }
        z -= w + 1;
      }
    }
    // landmark tower at the end of the street
    const tower = sim.building(0, zMin - 30, 24, 24, 150, r);
    for (let i = 0; i < 4; i++) sim.billboard(0, 20 + i * 14, zMin - 17.7, 20, 11, 0, r);
    // street lamps
    for (let z = zMax; z > zMin; z -= 22) for (const s of [-1, 1]) sim.lamp(s * (roadW / 2 + 0.8), z, s);
    // cars
    const lanes = [[-5.6, 1], [-1.9, 1], [1.9, -1], [5.6, -1]];
    const nCars = Math.round(44 * dens);
    for (let i = 0; i < nCars; i++) {
      const [x, dir] = lanes[i % 4];
      const taxi = r() < 0.45, bus = !taxi && r() < 0.06;
      const color = taxi ? '#f6c514' : ['#c0392b', '#ecf0f1', '#2c3e50', '#7f8c8d', '#2980b9', '#111111', '#8e9aa6', '#16a085'][Math.floor(r() * 8)];
      sim.car(x, zMin + r() * (zMax - zMin), dir, color, 6 + r() * 5, { taxi, bus, zMin, zMax });
    }
    // people on sidewalks
    const nP = Math.round(150 * dens);
    for (let i = 0; i < nP; i++) {
      const s = r() < 0.5 ? -1 : 1;
      sim.person(s * (roadW / 2 + 1 + r() * 5.5), zMin + 40 + r() * (zMax - zMin - 40), r, { zMin, zMax });
    }
    sim.sparks = new Particles(sim, { count: 2500, color: '#ffb347', size: 0.22, additive: true }); sim.sparks.gravity = -9; sim.sparks.floor = 0.02; sim.particles.push(sim.sparks);
    sim.camOrigin = [0, 0, 0];
  },

  beach(sim, r) {
    sim.ground('#e7d3a1');
    sim.ocean({ x0: 22, x1: 700, z0: -800, z1: 200, color: sim.spec.time === 'night' ? '#0f3550' : '#2a8bb5' });
    // wet sand strip
    const wet = new THREE.Mesh(new THREE.PlaneGeometry(10, 1000), sim.mat('#c8b07a')); wet.rotation.x = -Math.PI / 2; wet.position.set(19, 0.005, -300); sim.scene.add(wet);
    // promenade + road + low buildings
    const prom = sim.box(9, 0.3, 1000, '#cfc8bb', { cast: false }); prom.position.set(-12, 0.15, -300); sim.scene.add(prom);
    const road = new THREE.Mesh(new THREE.PlaneGeometry(13, 1000), sim.mat('#34363a')); road.rotation.x = -Math.PI / 2; road.position.set(-24, 0.02, -300); road.receiveShadow = true; sim.scene.add(road); sim.tag(road, 'roads');
    for (let z = -790; z < 190; z += 9) { const d = new THREE.Mesh(new THREE.PlaneGeometry(0.16, 3.5), sim.mat('#f2c230')); d.rotation.x = -Math.PI / 2; d.position.set(-24, 0.03, z); sim.scene.add(d); }
    for (let z = 80; z > -500; z -= 16 + r() * 10) { const w = 12 + r() * 6; sim.building(-44 - r() * 4, z, 14, w, 8 + r() * 22, r); }
    for (let z = 70; z > -400; z -= 13) sim.palm(-16.5, z + r() * 3, r);
    for (let z = 60; z > -400; z -= 30) sim.lamp(-8, z, -1);
    // pier with ferris wheel
    const pz = -120;
    const deck = sim.box(130, 0.6, 10, '#8a6a4a'); deck.position.set(65, 4, pz); sim.scene.add(deck); sim.tag(deck, 'pier');
    for (let x = 6; x < 130; x += 8) for (const s of [-1, 1]) { const pl = sim.box(0.5, 8, 0.5, '#6b5038'); pl.position.set(x, 0, pz + s * 4.5); sim.scene.add(pl); }
    sim.ferrisWheel(95, pz - 9, 16);
    // umbrellas & people on the sand
    for (let i = 0; i < 26; i++) sim.umbrella(-3 + r() * 20, 40 - r() * 260, r);
    for (let i = 0; i < 110; i++) {
      const onProm = r() < 0.45;
      if (onProm) sim.person(-12 + (r() - 0.5) * 7, 40 - r() * 260, r, { zMin: -260, zMax: 60 });
      else sim.person(-4 + r() * 24, 40 - r() * 240, r, { static: r() < 0.6, zMin: -260, zMax: 60 });
    }
    for (let i = 0; i < 18; i++) sim.car(-24 + (i % 2 ? 3 : -3), -500 + r() * 560, i % 2 ? -1 : 1, ['#ecf0f1', '#c0392b', '#2c3e50', '#f39c12', '#2980b9'][Math.floor(r() * 5)], 7 + r() * 4, { zMin: -500, zMax: 80 });
    // boats
    for (let i = 0; i < 6; i++) sim.boat(60 + r() * 200, -100 - r() * 400, r);
    sim.sparks = new Particles(sim, { count: 1500, color: '#ffb347', size: 0.22, additive: true }); sim.sparks.gravity = -9; sim.sparks.floor = 0.02; sim.particles.push(sim.sparks);
    sim.camOrigin = [-6, 0, 0];
    if (!sim.spec.camera.offsetX) sim.spec.camera.offsetX = 0;
    sim.spec.camera.lookX = sim.spec.camera.lookX ?? 26;
  },

  suburb(sim, r) {
    sim.roadCam = true;
    sim.ground('#6aa84f');
    const road = new THREE.Mesh(new THREE.PlaneGeometry(10, 700), sim.mat('#3a3c40')); road.rotation.x = -Math.PI / 2; road.position.set(0, 0.02, -200); road.receiveShadow = true; sim.scene.add(road); sim.tag(road, 'roads');
    for (let z = -540; z < 140; z += 9) { const d = new THREE.Mesh(new THREE.PlaneGeometry(0.16, 3.5), sim.mat('#f2c230')); d.rotation.x = -Math.PI / 2; d.position.set(0, 0.03, z); sim.scene.add(d); }
    for (const s of [-1, 1]) { const sw = sim.box(2.5, 0.15, 700, '#bdbab2', { cast: false }); sw.position.set(s * 6.3, 0.07, -200); sim.scene.add(sw); }
    for (const s of [-1, 1]) for (let z = 60; z > -500; z -= 20) {
      sim.house(s * (17 + r() * 3), z, r, s > 0 ? -Math.PI / 2 : Math.PI / 2);
      if (r() < 0.8) sim.tree(s * (9.5 + r() * 2), z - 8 + r() * 4, r);
      if (r() < 0.4) sim.car(s * 3.3, z + r() * 6, s, ['#ecf0f1', '#c0392b', '#2c3e50', '#7f8c8d', '#2980b9'][Math.floor(r() * 5)], 0, { parked: true });
    }
    for (let i = 0; i < 8; i++) sim.car(i % 2 ? 2.3 : -2.3, -400 + r() * 460, i % 2 ? -1 : 1, ['#ecf0f1', '#c0392b', '#2c3e50', '#f39c12'][Math.floor(r() * 4)], 8 + r() * 3, { zMin: -420, zMax: 80 });
    for (let i = 0; i < 40; i++) sim.person((r() < 0.5 ? -1 : 1) * 6.3, 40 - r() * 260, r, { zMin: -260, zMax: 60 });
    for (let i = 0; i < 14; i++) sim.person((r() < 0.5 ? -1 : 1) * (11 + r() * 6), 40 - r() * 200, r, { static: true });
    sim.sparks = new Particles(sim, { count: 1500, color: '#ffb347', size: 0.22, additive: true }); sim.sparks.gravity = -9; sim.sparks.floor = 0.02; sim.particles.push(sim.sparks);
    sim.camOrigin = [0, 0, 0];
  },

  highway(sim, r) {
    sim.roadCam = true;
    sim.ground('#7a9a5a');
    const road = new THREE.Mesh(new THREE.PlaneGeometry(34, 1200), sim.mat('#2f3135')); road.rotation.x = -Math.PI / 2; road.position.set(0, 0.02, -400); road.receiveShadow = true; sim.scene.add(road); sim.tag(road, 'roads');
    const bar = sim.box(0.6, 1, 1200, '#bfbfbf'); bar.position.set(0, 0.5, -400); sim.scene.add(bar);
    for (let z = -990; z < 190; z += 10) for (const x of [-12.75, -8.5, -4.25, 4.25, 8.5, 12.75]) { const d = new THREE.Mesh(new THREE.PlaneGeometry(0.16, 4), sim.mat('#ededed')); d.rotation.x = -Math.PI / 2; d.position.set(x, 0.03, z); sim.scene.add(d); }
    for (let i = 0; i < 30; i++) { const m = new THREE.Mesh(new THREE.ConeGeometry(80 + r() * 120, 60 + r() * 120, 5), sim.mat(sim.spec.time === 'night' ? '#1d2433' : '#6e7f8f', { flat: true })); m.position.set((r() < 0.5 ? -1 : 1) * (200 + r() * 400), 0, -400 - r() * 900); sim.scene.add(m); }
    for (let i = 0; i < 60; i++) sim.tree((r() < 0.5 ? -1 : 1) * (24 + r() * 60), 100 - r() * 900, r, r() < 0.5 ? 'pine' : 'round');
    const lanes = [-14.9, -10.6, -6.4, -2.1, 2.1, 6.4, 10.6, 14.9];
    for (let i = 0; i < 60; i++) {
      const x = lanes[i % 8], dir = x < 0 ? 1 : -1;
      sim.car(x, -800 + r() * 900, dir, ['#c0392b', '#ecf0f1', '#2c3e50', '#7f8c8d', '#2980b9', '#111111', '#f39c12'][Math.floor(r() * 7)], 22 + r() * 8, { bus: r() < 0.08, zMin: -800, zMax: 100 });
    }
    for (let z = 100; z > -800; z -= 40) for (const s of [-1, 1]) sim.lamp(s * 18, z, s);
    sim.sparks = new Particles(sim, { count: 3000, color: '#ffb347', size: 0.14, additive: true }); sim.sparks.gravity = -9; sim.sparks.floor = 0.02; sim.particles.push(sim.sparks);
    sim.camOrigin = [0, 0, 0];
    sim.spec.camera.height = sim.spec.camera.height ?? 7;
  },

  park(sim, r) {
    sim.ground('#5fa043');
    const pond = new THREE.Mesh(new THREE.CircleGeometry(30, 40), new THREE.MeshStandardMaterial({ color: col('#3c8fb0'), roughness: 0.15, metalness: 0.2 })); sim.reg(pond.material);
    pond.rotation.x = -Math.PI / 2; pond.position.set(25, 0.03, -70); sim.scene.add(pond); sim.tag(pond, 'water');
    const path = new THREE.Mesh(new THREE.PlaneGeometry(5, 600), sim.mat('#cbb994')); path.rotation.x = -Math.PI / 2; path.position.set(0, 0.02, -200); sim.scene.add(path);
    for (let i = 0; i < 120; i++) { const x = (r() - 0.5) * 220, z = 60 - r() * 400; if (Math.abs(x) < 5 || Math.hypot(x - 25, z + 70) < 33) continue; sim.tree(x, z, r); }
    for (let i = 0; i < 70; i++) sim.person((r() - 0.5) * 4, 40 - r() * 300, r, { zMin: -300, zMax: 60 });
    for (let i = 0; i < 40; i++) sim.person((r() - 0.5) * 60, 40 - r() * 200, r, { static: true });
    for (let z = -400; z < 60; z += 30) sim.building(-120 - r() * 30, z, 25, 25, 40 + r() * 80, r);
    sim.camOrigin = [0, 0, 0];
  },

  desert(sim, r) {
    sim.roadCam = true;
    const g = new THREE.PlaneGeometry(1600, 1600, 80, 80); g.rotateX(-Math.PI / 2);
    const p = g.attributes.position.array; for (let i = 0; i < p.length; i += 3) { const x = p[i], z = p[i + 2]; if (Math.abs(x) > 14) p[i + 1] = (Math.sin(x * 0.02) * Math.cos(z * 0.015) * 6 + Math.sin(x * 0.05 + z * 0.03) * 2) * clamp((Math.abs(x) - 14) / 40); }
    g.computeVertexNormals();
    const gr = new THREE.Mesh(g, sim.mat('#d9b57a', { roughness: 1 })); gr.receiveShadow = true; sim.scene.add(gr); sim.tag(gr, 'ground');
    const road = new THREE.Mesh(new THREE.PlaneGeometry(10, 1600), sim.mat('#3b3a38')); road.rotation.x = -Math.PI / 2; road.position.set(0, 0.03, -400); sim.scene.add(road); sim.tag(road, 'roads');
    for (let z = -1100; z < 200; z += 10) { const d = new THREE.Mesh(new THREE.PlaneGeometry(0.16, 4), sim.mat('#f2c230')); d.rotation.x = -Math.PI / 2; d.position.set(0, 0.04, z); sim.scene.add(d); }
    for (let i = 0; i < 70; i++) sim.tree((r() < 0.5 ? -1 : 1) * (10 + r() * 80), 80 - r() * 600, r, 'cactus');
    for (let i = 0; i < 14; i++) { const h = 40 + r() * 80; const m = sim.box(60 + r() * 80, h, 60 + r() * 80, '#b5683f'); m.position.set((r() < 0.5 ? -1 : 1) * (150 + r() * 300), h / 2, -300 - r() * 700); sim.scene.add(m); }
    for (let i = 0; i < 8; i++) sim.car(i % 2 ? 2.4 : -2.4, -600 + r() * 680, i % 2 ? -1 : 1, ['#ecf0f1', '#c0392b', '#2c3e50', '#f39c12'][Math.floor(r() * 4)], 18 + r() * 6, { zMin: -600, zMax: 80 });
    for (let i = 0; i < 6; i++) sim.person(6 + r() * 4, 10 - r() * 40, r, { static: true });
    sim.sparks = new Particles(sim, { count: 1500, color: '#ffb347', size: 0.22, additive: true }); sim.sparks.gravity = -9; sim.sparks.floor = 0.02; sim.particles.push(sim.sparks);
    sim.camOrigin = [0, 0, 0];
    if (!sim.spec.sky) Object.assign(sim.base, { bottom: '#ffe1b0', fog: '#f3d9ad' });
  },

  snow(sim, r) {
    sim.roadCam = true;
    sim.ground('#f4f7fb');
    const road = new THREE.Mesh(new THREE.PlaneGeometry(9, 800), sim.mat('#7d8590')); road.rotation.x = -Math.PI / 2; road.position.set(0, 0.02, -250); sim.scene.add(road); sim.tag(road, 'roads');
    for (let i = 0; i < 160; i++) { const x = (r() < 0.5 ? -1 : 1) * (8 + r() * 120), z = 80 - r() * 500; sim.tree(x, z, r, 'pine'); }
    for (let i = 0; i < 12; i++) sim.house((r() < 0.5 ? -1 : 1) * (16 + r() * 20), 40 - r() * 300, r, r() * 6);
    for (let i = 0; i < 30; i++) sim.person((r() < 0.5 ? -1 : 1) * (5.5 + r() * 2), 40 - r() * 200, r, { zMin: -200, zMax: 60 });
    for (let i = 0; i < 6; i++) sim.car(i % 2 ? 2.2 : -2.2, -300 + r() * 360, i % 2 ? -1 : 1, ['#c0392b', '#2c3e50', '#ecf0f1'][Math.floor(r() * 3)], 7 + r() * 3, { zMin: -320, zMax: 80 });
    for (let i = 0; i < 10; i++) { const m = new THREE.Mesh(new THREE.ConeGeometry(120 + r() * 100, 150 + r() * 150, 6), sim.mat('#e9eef5', { flat: true })); m.position.set((r() - 0.5) * 1400, 0, -700 - r() * 500); sim.scene.add(m); }
    sim.camOrigin = [0, 0, 0];
    if (!sim.spec.effects.some((f) => f.type === 'weather')) sim.spec.effects.unshift({ type: 'weather', kind: 'snow', start: 0, ramp: 0.01, intensity: 0.5 });
  },

  harbor(sim, r) {
    sim.ground('#8d8a83');
    sim.ocean({ x0: -400, x1: 400, z0: -900, z1: -8, color: sim.spec.time === 'night' ? '#0e2f46' : '#2b7ea6' });
    const quay = sim.box(80, 1.2, 30, '#9a978f'); quay.position.set(0, 0.6 - 0.6, 7); sim.scene.add(quay);
    for (let i = 0; i < 40; i++) sim.person((r() - 0.5) * 60, 2 - r() * 14, r, { static: r() < 0.5, axis: 'x', zMin: -40, zMax: 40, dir: r() < 0.5 ? 1 : -1 });
    for (let i = 0; i < 12; i++) sim.boat((r() - 0.5) * 300, -40 - r() * 400, r);
    // skyline across the water
    for (let i = 0; i < 40; i++) sim.building(-350 + i * 18 + r() * 6, -620 - r() * 60, 14 + r() * 8, 14 + r() * 8, 30 + Math.pow(r(), 1.5) * 160, r);
    for (let x = -36; x <= 36; x += 18) sim.lamp(x, -6, 1);
    sim.camOrigin = [0, 0, 0];
    sim.spec.camera.height = sim.spec.camera.height ?? 4;
  },
};

Sim.prototype.boat = function (x, z, r) {
  const g = new THREE.Group();
  const hull = this.box(4, 1.4, 12, ['#ffffff', '#c0392b', '#2c3e50', '#f1c40f'][Math.floor(r() * 4)], { roughness: 0.5 }); hull.position.y = 0.4;
  const cabin = this.box(3, 1.6, 4, '#ecf0f1'); cabin.position.set(0, 1.9, 1.5);
  const mast = this.box(0.15, 8, 0.15, '#dddddd'); mast.position.set(0, 5, -1);
  g.add(hull, cabin, mast); g.position.set(x, 0, z); g.rotation.y = r() * Math.PI;
  return this.addEntity(g, 'boat', ['boats'], { speed: (r() - 0.5) * 2, movable: true });
};

// ---------- effects ----------
const ICE = col('#e9f3ff');
const FX = {
  freeze: {
    setup(sim, fx) { fx._ps = new Particles(sim, { count: 1500, color: '#ffffff', size: 0.12, opacity: 0.9 }); fx._ps.gravity = -0.6; sim.particles.push(fx._ps); },
    update(sim, fx, k, t, dt) {
      const L = sim.look;
      L.tint.copy(ICE); L.tintAmt = Math.max(L.tintAmt, 0.82 * k);
      L.top.lerp(col('#9fc3e6'), k * 0.7); L.bottom.lerp(col('#f2f8ff'), k * 0.8); L.fog.lerp(col('#e8f1fb'), k);
      L.fogNear = lerp(L.fogNear, 20, k); L.fogFar = lerp(L.fogFar, 300, k);
      L.waveMul *= 1 - k; L.sunColor.lerp(col('#dbe9ff'), k);
      sim.timeScale *= 1 - k * (fx.stopMotion === false ? 0 : 1);
      L.filter.push(`saturate(${1 - 0.5 * k})`, `brightness(${1 + 0.08 * k})`);
      if (k > 0.05) { const c = sim.camera.position; for (let i = 0; i < 6 * k; i++) fx._ps.emit(c.x + (sim.rng() - 0.5) * 40, c.y + 10 + sim.rng() * 8, c.z - 5 - sim.rng() * 40, (sim.rng() - 0.5), -1, 0, 6); }
    },
  },
  heat: {
    setup(sim, fx) { fx._ps = new Particles(sim, { count: 1200, color: '#ffe6c8', size: 0.5, opacity: 0.35 }); fx._ps.gravity = 1.5; sim.particles.push(fx._ps); },
    update(sim, fx, k) {
      const L = sim.look; L.tint.set('#ffb070'); L.tintAmt = Math.max(L.tintAmt, 0.35 * k);
      L.top.lerp(col('#c46a2a'), k * 0.7); L.bottom.lerp(col('#ffcf8a'), k); L.fog.lerp(col('#f5b77a'), k); L.fogFar = lerp(L.fogFar, 260, k);
      L.sunSize = lerp(L.sunSize, 3, k); L.sunI *= 1 + k * 0.4; L.filter.push(`saturate(${1 + 0.3 * k})`, `contrast(${1 + 0.1 * k})`);
      if (sim.water && fx.evaporate !== false) sim.water.level = lerp(sim.water.baseLevel, sim.water.baseLevel - 12, k);
      const c = sim.camera.position; for (let i = 0; i < 5 * k; i++) fx._ps.emit(c.x + (sim.rng() - 0.5) * 50, 0.5, c.z - 10 - sim.rng() * 50, 0, 1, 0, 4);
      L.gradeColor = '#ffb37a'; L.gradeAmt = Math.max(L.gradeAmt, 0.25 * k);
    },
  },
  vanish: {
    setup(sim, fx) { fx._targets = [].concat(fx.target || fx.targets || 'cars').map(normTag); },
    update(sim, fx, k, t) {
      const stagger = fx.stagger ?? 0.5;
      for (const tg of fx._targets) {
        if (tg === 'water') { if (sim.water) sim.water.level = lerp(sim.water.baseLevel, sim.water.baseLevel - 13, k); continue; }
        if (tg === 'sun') { sim.look.sunI *= 1 - k; sim.look.sunVis *= 1 - k; sim.look.hemiI *= 1 - k * 0.7; sim.look.top.lerp(col('#05070f'), k); sim.look.bottom.lerp(col('#0b1020'), k); sim.look.stars = Math.max(sim.look.stars, k); sim.look.glow = Math.max(sim.look.glow, 1.2 * k); sim.look.lamps = Math.max(sim.look.lamps, k); continue; }
        if (tg === 'moon' || tg === 'stars') { sim.look.stars *= 1 - k; continue; }
        const objs = tg === 'movable' ? sim.entities.filter((e) => e.movable).map((e) => e.obj) : sim.tagged(tg);
        objs.forEach((o, i) => {
          const off = ((i * 7919) % 1000) / 1000 * stagger;
          const kk = fx.start + off > t ? 0 : k;
          const local = fx.end != null && fx.revert ? kk : Math.min(kk, smooth((t - fx.start - off) / 0.35));
          const s = 1 - local; const bs = o.userData.baseScale;
          if (local > 0.99) { if (o.visible) { o.visible = false; if (!o.userData.noPuff && o.userData.ent && fx.puff !== false) sim.dust(o.getWorldPosition(new THREE.Vector3()), 4); } }
          else { o.visible = true; o.scale.set(bs.x * Math.max(0.001, s), bs.y * Math.max(0.001, s), bs.z * Math.max(0.001, s)); }
          if (o.userData.ent) o.userData.ent.hidden = local > 0.99;
        });
      }
    },
  },
  gravity_off: {
    update(sim, fx, k, t, dt) {
      const st = fx._state, ents = sim.ents(fx.target || 'movable');
      if (t >= fx.start && !st.on) {
        st.on = true;
        for (const e of ents) { e.physics = true; e.rooted = false; e.vel.set((sim.rng() - 0.5) * 0.6, (0.6 + sim.rng() * 1.6) * (fx.strength ?? 1), (sim.rng() - 0.5) * 0.6); e.angVel.set((sim.rng() - 0.5) * 0.8, (sim.rng() - 0.5) * 0.8, (sim.rng() - 0.5) * 0.8); e.g = fx.reverse ? 4 : 0.15; }
      }
      if (st.on && fx.end != null && t >= fx.end && !st.off) { st.off = true; for (const e of ents) { e.g = -9.8; e.landing = true; } }
      if (st.on && !st.off) sim.timeScale *= 1 - 0.7 * k;
    },
  },
  darkness: {
    update(sim, fx, k) {
      const L = sim.look; L.sunI *= 1 - k; L.sunVis *= 1 - k; L.hemiI *= 1 - 0.8 * k;
      L.top.lerp(col('#010208'), k); L.bottom.lerp(col('#070b18'), k); L.fog.lerp(col('#03050c'), k); L.stars = Math.max(L.stars, k);
      L.glow = lerp(L.glow, fx.powerOut ? 0 : 1.6, k); L.lamps = lerp(L.lamps, fx.powerOut ? 0 : 1, k); L.exposure *= 1 + 0.2 * k;
    },
  },
  power_out: {
    update(sim, fx, k) { const L = sim.look; L.glow *= 1 - k; L.lamps *= 1 - k; L.billboard *= 1 - k; },
  },
  flood: {
    setup(sim, fx) {
      const m = new THREE.MeshStandardMaterial({ color: col(fx.color || '#2d7fa6'), roughness: 0.15, metalness: 0.1, transparent: true, opacity: fx.color === '#ff5a00' || fx.liquid === 'lava' ? 1 : 0.88, emissive: col(fx.liquid === 'lava' ? '#ff3a00' : '#000000'), emissiveIntensity: fx.liquid === 'lava' ? 1.4 : 0 });
      const geo = new THREE.PlaneGeometry(1400, 1400, 60, 60); geo.rotateX(-Math.PI / 2);
      fx._mesh = new THREE.Mesh(geo, m); fx._mesh.position.y = -1; fx._base = geo.attributes.position.array.slice(); sim.scene.add(fx._mesh); sim.tag(fx._mesh, 'flood');
      fx._ps = new Particles(sim, { count: 1200, color: '#ffffff', size: 0.3, opacity: 0.8 }); fx._ps.gravity = -8; sim.particles.push(fx._ps);
    },
    update(sim, fx, k, t, dt) {
      const h = fx.height ?? 6, y = lerp(-1, h, k);
      sim.floodLevel = Math.max(sim.floodLevel ?? -1, y);
      fx._mesh.position.y = y; fx._mesh.position.x = sim.camera.position.x; fx._mesh.position.z = sim.camera.position.z - 300;
      const pa = fx._mesh.geometry.attributes.position.array, b = fx._base;
      for (let i = 0; i < pa.length; i += 3) pa[i + 1] = Math.sin(b[i] * 0.05 + t * 1.6) * 0.3 + Math.sin(b[i + 2] * 0.07 + t * 1.2) * 0.25;
      fx._mesh.geometry.attributes.position.needsUpdate = true;
      for (const e of sim.entities) {
        if (!e.movable || e.rooted || e.kind === 'boat') continue;
        const o = e.obj;
        if (y > 0.8 && (e.kind === 'car' || e.kind === 'person' || e.kind === 'prop')) {
          if (!e.floating) { e.floating = true; e.physics = false; e.speedMul = 0; e.speed = 0; }
          o.position.y += ((y - (e.kind === 'car' ? 0.9 : 1.2)) - o.position.y) * Math.min(1, dt * 2);
          o.position.y = Math.max(0, o.position.y);
          o.position.x += Math.sin(t * 0.4 + e.home.z) * 0.6 * dt; o.position.z += (fx.current ?? 1.2) * dt;
          o.rotation.z = Math.sin(t + e.home.x) * 0.1; if (e.kind === 'person') { e.armsUp = true; }
        }
      }
      if (k > 0 && k < 1 && fx.liquid !== 'lava') { const c = sim.camera.position; for (let i = 0; i < 8; i++) fx._ps.emit(c.x + (sim.rng() - 0.5) * 40, y + 0.2, c.z - 10 - sim.rng() * 40, (sim.rng() - 0.5) * 2, 2 + sim.rng() * 3, (sim.rng() - 0.5) * 2, 1); }
      if (fx.liquid === 'lava') { sim.look.fog.lerp(col('#ff7a3a'), k * 0.5); sim.look.bottom.lerp(col('#ff8a4a'), k * 0.6); }
    },
  },
  giant_object: {
    setup(sim, fx) {
      const shape = fx.shape || 'moon', r = sim.rng;
      let mesh;
      if (shape === 'black_hole') {
        mesh = new THREE.Group();
        mesh.add(new THREE.Mesh(new THREE.SphereGeometry(1, 48, 24), new THREE.MeshBasicMaterial({ color: 0x000000, fog: false })));
        const ring = new THREE.Mesh(new THREE.TorusGeometry(1.9, 0.45, 16, 96), new THREE.MeshBasicMaterial({ color: col('#ffb05a'), fog: false, transparent: true, opacity: 0.95, blending: THREE.AdditiveBlending }));
        ring.rotation.x = 1.25; mesh.add(ring); fx._ring = ring;
        const halo = new THREE.Mesh(new THREE.RingGeometry(1.02, 1.5, 64), new THREE.MeshBasicMaterial({ color: col('#ffd7a0'), fog: false, transparent: true, opacity: 0.8, side: THREE.DoubleSide, blending: THREE.AdditiveBlending })); mesh.add(halo); fx._halo = halo;
      } else if (shape === 'cube') {
        mesh = new THREE.Mesh(new THREE.BoxGeometry(1.4, 1.4, 1.4), new THREE.MeshStandardMaterial({ color: col(fx.color || '#888888'), fog: false, roughness: 0.6 }));
      } else {
        const tex = shape === 'planet' || shape === 'jupiter' ? planetTexture(r, fx.hue ?? 30) : shape === 'sun' ? null : moonTexture(r, fx.color || '#d4d2c8');
        const m = shape === 'sun' ? new THREE.MeshBasicMaterial({ color: col(fx.color || '#fff2c0'), fog: false }) : new THREE.MeshStandardMaterial({ map: tex, color: col(tex ? '#ffffff' : fx.color || '#cccccc'), emissive: col('#ffffff'), emissiveMap: tex, emissiveIntensity: 0.55, fog: false, roughness: 1 });
        mesh = new THREE.Mesh(new THREE.SphereGeometry(1, 64, 32), m);
        if (shape === 'planet' && fx.rings) { const rg = new THREE.Mesh(new THREE.RingGeometry(1.4, 2.3, 64), new THREE.MeshBasicMaterial({ color: col('#e8d3a8'), side: THREE.DoubleSide, transparent: true, opacity: 0.7, fog: false })); rg.rotation.x = 1.3; mesh.add(rg); }
      }
      mesh.renderOrder = 0; sim.scene.add(mesh); fx._mesh = mesh; mesh.visible = false;
      fx._light = new THREE.DirectionalLight(col(fx.shape === 'sun' ? '#fff2c0' : '#c8d4ff'), 0); sim.scene.add(fx._light); sim.scene.add(fx._light.target);
      sim.tag(mesh, [shape, 'giant']);
    },
    update(sim, fx, k, t) {
      const m = fx._mesh; m.visible = k > 0.001;
      const cam = sim.camera.position, fwd = new THREE.Vector3(0, 0, -1);
      const dist = 1600, elev = fx.elevation ?? 0.32, side = fx.side ?? 0.15;
      const dir = new THREE.Vector3(side, elev, -1).normalize();
      // size = radius as a fraction of distance (0.2 ≈ 23° wide). Capped so it never fills the whole sky.
      const sizeEnd = clamp(fx.size ?? 0.15, 0.02, 0.22);
      const grow = fx.approach ? lerp(0.08, 1, k) : smooth(k / Math.max(0.001, fx.intensity ?? 1)) * 0.3 + 0.7;
      m.position.copy(cam).addScaledVector(dir, dist);
      m.scale.setScalar(dist * sizeEnd * grow);
      m.rotation.y = t * 0.02;
      if (fx._ring) { fx._ring.rotation.z = t * 0.5; fx._halo.lookAt(cam); }
      if (fx.shape === 'black_hole') { sim.look.top.lerp(col('#05040a'), k * 0.7); sim.look.bottom.lerp(col('#2a1a3a'), k * 0.5); sim.look.sunI *= 1 - 0.5 * k; sim.wind = Math.max(sim.wind, (fx.pull ?? 0) * k); }
      if (fx.shape === 'moon' || fx.shape === 'planet') { fx._light.intensity = 0.8 * k; fx._light.position.copy(m.position); fx._light.target.position.copy(cam); }
      if (fx.shape === 'sun') { sim.look.sunI *= 1 + k; sim.look.exposure *= 1 + 0.3 * k; sim.look.bottom.lerp(col('#fff0c8'), k * 0.5); }
      if (fx.tides && sim.water) sim.water.level = sim.water.baseLevel + Math.sin(clamp((t - fx.start) / 6) * Math.PI / 2) * fx.tides * k;
      if (fx.shake) sim.shake = Math.max(sim.shake, fx.shake * k);
    },
  },
  meteor: {
    setup(sim, fx) {
      const imp = fx.impact || [ (fx.side ?? 0.25) * 120, -(fx.distance ?? 160) ];
      fx._imp = new THREE.Vector3(imp[0], 0, imp[1]);
      fx._size = fx.size ?? 6;
      fx._rock = new THREE.Mesh(new THREE.IcosahedronGeometry(fx._size, 1), new THREE.MeshStandardMaterial({ color: col('#4a3a30'), emissive: col('#ff6a1a'), emissiveIntensity: 1.6, flatShading: true }));
      fx._rock.visible = false; sim.scene.add(fx._rock);
      fx._trail = new Particles(sim, { count: 2500, color: '#ffae5a', size: fx._size * 0.9, additive: true, opacity: 0.8 }); fx._trail.drag = 1.5; sim.particles.push(fx._trail);
      fx._smoke = new Particles(sim, { count: 3000, color: '#4b4038', size: fx._size * 1.6, opacity: 0.55 }); fx._smoke.gravity = 1.2; fx._smoke.drag = 0.8; sim.particles.push(fx._smoke);
      fx._ball = new THREE.Mesh(new THREE.SphereGeometry(1, 32, 16), new THREE.MeshBasicMaterial({ color: col('#ffb24a'), transparent: true, opacity: 1, fog: false, blending: THREE.AdditiveBlending }));
      fx._ball.visible = false; sim.scene.add(fx._ball);
      fx._ring = new THREE.Mesh(new THREE.TorusGeometry(1, 0.08, 8, 64), new THREE.MeshBasicMaterial({ color: col('#ffe2b0'), transparent: true, opacity: 0.9, fog: false })); fx._ring.rotation.x = Math.PI / 2; fx._ring.visible = false; sim.scene.add(fx._ring);
      fx._crater = new THREE.Mesh(new THREE.CircleGeometry(1, 32), sim.mat('#2a221d')); fx._crater.rotation.x = -Math.PI / 2; fx._crater.position.copy(fx._imp).setY(0.05); fx._crater.visible = false; sim.scene.add(fx._crater);
      fx._fall = fx.fall ?? 2.2;
    },
    update(sim, fx, k, t, dt) {
      const ti = fx.start, from = fx._imp.clone().add(new THREE.Vector3(260, 420, -380));
      const S = fx._size;
      if (t >= ti - fx._fall && t < ti) {
        const p = (t - (ti - fx._fall)) / fx._fall, pos = from.clone().lerp(fx._imp, p * p);
        fx._rock.visible = true; fx._rock.position.copy(pos); fx._rock.rotation.x += dt * 3;
        for (let i = 0; i < 20; i++) fx._trail.emit(pos.x + (sim.rng() - 0.5) * S, pos.y + (sim.rng() - 0.5) * S, pos.z + (sim.rng() - 0.5) * S, (sim.rng() - 0.5) * 4, (sim.rng() - 0.5) * 4, (sim.rng() - 0.5) * 4, 0.6);
        for (let i = 0; i < 4; i++) fx._smoke.emit(pos.x, pos.y, pos.z, 0, 0, 0, 3);
        sim.look.bottom.lerp(col('#ffb070'), p * 0.4); sim.look.exposure *= 1 + p * 0.3; sim.shake = Math.max(sim.shake, p * 0.1);
      } else fx._rock.visible = false;
      if (t >= ti) {
        const a = t - ti;
        if (!fx._state.hit) {
          fx._state.hit = true; fx._crater.visible = true; fx._crater.scale.setScalar(S * 5);
          for (let i = 0; i < 900; i++) { const th = sim.rng() * Math.PI * 2, sp = 10 + sim.rng() * 50; fx._smoke.emit(fx._imp.x, 2 + sim.rng() * 10, fx._imp.z, Math.cos(th) * sp, sim.rng() * 30, Math.sin(th) * sp, 4 + sim.rng() * 4); }
          for (const e of sim.entities) {
            if (!e.movable) continue; const d = e.obj.position.distanceTo(fx._imp), R = S * 30;
            if (d < R) { const f = (1 - d / R); const dirv = e.obj.position.clone().sub(fx._imp).setY(0).normalize(); e.physics = true; e.rooted = false; e.g = -9.8; e.vel.copy(dirv.multiplyScalar(30 * f)).setY(15 * f + 3); e.angVel.set(sim.rng() * 6 * f, sim.rng() * 6 * f, sim.rng() * 6 * f); e.landing = false; }
          }
        }
        sim.look.flash = Math.max(sim.look.flash, clamp(1 - a / 0.6) * (fx.flash ?? 0.9));
        sim.shake = Math.max(sim.shake, clamp(1 - a / 3.5) * (fx.shakeAmount ?? 1.2));
        fx._ball.visible = a < 4; fx._ball.position.copy(fx._imp); fx._ball.scale.setScalar(S * (2 + a * 14)); fx._ball.material.opacity = clamp(1 - a / 4);
        fx._ring.visible = a < 3; fx._ring.position.copy(fx._imp).setY(1); fx._ring.scale.setScalar(S * (2 + a * 70)); fx._ring.material.opacity = clamp(1 - a / 3);
        sim.look.bottom.lerp(col('#ff9a5a'), clamp(1 - a / 6) * 0.6); sim.look.fog.lerp(col('#8a6a55'), clamp(a / 2) * 0.5); sim.look.fogFar = lerp(sim.look.fogFar, 260, clamp(a / 3) * 0.6);
      }
    },
  },
  earthquake: {
    setup(sim, fx) { fx._b = sim.ents('buildings').map((e) => ({ e, ph: sim.rng() * 6, collapse: fx.collapse && sim.rng() < (fx.collapse === true ? 0.3 : fx.collapse) })); },
    update(sim, fx, k, t, dt) {
      const s = fx.strength ?? 1; sim.shake = Math.max(sim.shake, k * 0.35 * s);
      for (const { e, ph, collapse } of fx._b) {
        e.obj.rotation.z = Math.sin(t * 9 + ph) * 0.012 * k * s; e.obj.rotation.x = Math.sin(t * 7 + ph * 2) * 0.008 * k * s;
        if (collapse && k > 0.3) { const p = clamp((t - fx.start - 1) / 3); e.obj.position.y = -e.h * smooth(p) * 0.9; if (p > 0 && p < 1 && sim.rng() < 0.6) sim.dust(e.obj.position.clone().setY(2), 6); }
      }
      for (const e of sim.ents('cars')) { if (!e.physics) e.obj.position.x = e.lane + Math.sin(t * 14 + e.home.z) * 0.08 * k * s; }
      for (const e of sim.ents('people')) e.speedMul = k > 0.2 ? 2.2 : 1;
      if (k > 0.2 && sim.rng() < 0.4) { const c = sim.camera.position; sim.dust(new THREE.Vector3(c.x + (sim.rng() - 0.5) * 30, 0, c.z - 10 - sim.rng() * 40), 5); }
    },
  },
  wind: {
    setup(sim, fx) { fx._ps = new Particles(sim, { count: 3000, color: fx.color || '#d8d2c4', size: 0.18, opacity: 0.7 }); sim.particles.push(fx._ps); },
    update(sim, fx, k, t) {
      const s = (fx.strength ?? 0.7) * k; sim.wind = Math.max(sim.wind, s); sim.windDir.set(fx.direction === 'left' ? -1 : 1, 0, 0);
      sim.shake = Math.max(sim.shake, s * 0.12);
      const L = sim.look; L.top.lerp(col('#4a5560'), s * 0.6); L.bottom.lerp(col('#8a949c'), s * 0.6); L.fog.lerp(col('#8a949c'), s * 0.6); L.sunI *= 1 - s * 0.5; L.fogFar = lerp(L.fogFar, 220, s);
      const c = sim.camera.position, dx = sim.windDir.x;
      for (let i = 0; i < 25 * s; i++) fx._ps.emit(c.x - dx * 30, 0.5 + sim.rng() * 14, c.z - 5 - sim.rng() * 50, dx * (25 + sim.rng() * 30) * s, (sim.rng() - 0.3) * 3, (sim.rng() - 0.5) * 3, 2);
      if (s > 0.6 && !fx._state.lift) {
        fx._state.lift = true;
        for (const e of sim.entities) if ((e.kind === 'prop' || e.kind === 'person' || (e.kind === 'car' && s > 0.85)) && sim.rng() < (fx.liftChance ?? 0.35)) { e.physics = true; e.g = -2; e.vel.set(dx * 3, 2 + sim.rng() * 4, 0); e.angVel.set(sim.rng() * 2, sim.rng() * 2, sim.rng() * 2); }
      }
    },
  },
  weather: {
    setup(sim, fx) {
      const kind = fx.kind || 'rain';
      const cfg = { rain: ['#a8c4e0', 0.08, 0.6], snow: ['#ffffff', 0.18, 0.9], ash: ['#5a5550', 0.2, 0.8], sand: ['#d9b57a', 0.12, 0.7], confetti: ['#ff4fa0', 0.25, 1], embers: ['#ff8a2a', 0.15, 1], fireflies: ['#fff59a', 0.2, 1] }[kind] || ['#ffffff', 0.15, 0.8];
      fx._ps = new Particles(sim, { count: 6000, color: cfg[0], size: cfg[1], opacity: cfg[2], additive: kind === 'embers' || kind === 'fireflies' }); sim.particles.push(fx._ps);
      if (kind === 'confetti') { fx._ps2 = new Particles(sim, { count: 3000, color: '#3ad1ff', size: 0.25 }); fx._ps3 = new Particles(sim, { count: 3000, color: '#ffd84a', size: 0.25 }); sim.particles.push(fx._ps2, fx._ps3); }
      fx._kind = kind;
    },
    update(sim, fx, k) {
      const kind = fx._kind, n = (fx.intensity ?? 0.6) * (kind === 'rain' ? 70 : 35) * (k > 0 ? 1 : 0);
      const c = sim.camera.position, r = sim.rng;
      for (let i = 0; i < n; i++) {
        const x = c.x + (r() - 0.5) * 60, z = c.z - 2 - r() * 60, y = c.y + 15 + r() * 10;
        const ps = kind === 'confetti' ? [fx._ps, fx._ps2, fx._ps3][i % 3] : fx._ps;
        if (kind === 'rain') ps.emit(x, y, z, 0, -28, 0, 1.2);
        else if (kind === 'embers' || kind === 'fireflies') ps.emit(x, r() * 8, z, (r() - 0.5), 0.5 + r(), (r() - 0.5), 3);
        else ps.emit(x, y, z, (r() - 0.5) * 1.5 + (kind === 'sand' ? 8 : 0), kind === 'confetti' ? -2 : -1.6, (r() - 0.5) * 1.5, 12);
      }
      if (kind === 'rain' || kind === 'ash' || kind === 'sand') { const L = sim.look, s = k * (fx.intensity ?? 0.6); L.sunI *= 1 - 0.6 * s; L.top.lerp(col(kind === 'sand' ? '#c79a5a' : '#59626d'), s); L.bottom.lerp(col(kind === 'sand' ? '#e0b77a' : '#9aa3ab'), s); L.fog.lerp(col(kind === 'sand' ? '#d9b57a' : '#9aa3ab'), s); L.fogFar = lerp(L.fogFar, 200, s); }
    },
  },
  speed: { update(sim, fx, k) { sim.timeScale *= lerp(1, fx.value ?? 3, k); } },
  time_stop: {
    update(sim, fx, k) { sim.timeScale *= 1 - k; sim.look.filter.push(`saturate(${1 - 0.75 * k})`, `contrast(${1 + 0.1 * k})`); sim.look.gradeColor = '#9ab8ff'; sim.look.gradeAmt = Math.max(sim.look.gradeAmt, 0.12 * k); },
  },
  grade: {
    update(sim, fx, k) {
      const P = { red: ['hue-rotate(-20deg) saturate(1.3)', '#ff6a5a', 0.35], green: ['hue-rotate(60deg) saturate(1.2)', '#7dff7a', 0.25], blue: ['saturate(1.1)', '#6aa8ff', 0.3], sepia: ['sepia(0.8)', null, 0], noir: ['grayscale(1) contrast(1.25)', null, 0], invert: ['invert(1) hue-rotate(180deg)', null, 0], warm: ['saturate(1.2)', '#ffb36a', 0.25], cold: ['saturate(0.85)', '#9cc8ff', 0.25], toxic: ['hue-rotate(80deg) saturate(1.6)', '#a8ff3a', 0.3], purple: ['hue-rotate(-60deg) saturate(1.3)', '#b06aff', 0.3] }[fx.preset || 'warm'] || ['', null, 0];
      if (k > 0.001 && P[0]) sim.look.filter.push(...P[0].split(' ').map((f) => f.replace(/\(([-\d.]+)(deg)?\)/, (m, v, u) => `(${fx.preset === 'invert' && f.startsWith('invert') ? k : (f.startsWith('hue') ? v * k : f.startsWith('saturate') || f.startsWith('contrast') ? 1 + (v - 1) * k : v * k)}${u || ''})`)));
      if (P[1]) { sim.look.gradeColor = P[1]; sim.look.gradeAmt = Math.max(sim.look.gradeAmt, P[2] * k); }
    },
  },
  sky: {
    update(sim, fx, k) {
      const L = sim.look;
      if (fx.top) L.top.lerp(col(fx.top), k); if (fx.bottom) L.bottom.lerp(col(fx.bottom), k); if (fx.fog) L.fog.lerp(col(fx.fog), k);
      if (fx.sunColor) L.sunColor.lerp(col(fx.sunColor), k); if (fx.sunSize) L.sunSize = lerp(L.sunSize, fx.sunSize, k);
      if (fx.sunIntensity != null) L.sunI = lerp(L.sunI, fx.sunIntensity, k);
      if (fx.stars != null) L.stars = lerp(L.stars, fx.stars, k);
    },
  },
  scale: {
    setup(sim, fx) { fx._t = [].concat(fx.target || 'people').map(normTag); },
    update(sim, fx, k) {
      const f = lerp(1, fx.factor ?? 5, k);
      for (const tg of fx._t) for (const o of sim.tagged(tg)) { const b = o.userData.baseScale; o.scale.set(b.x * f, b.y * f, b.z * f); const e = o.userData.ent; if (e && e.kind === 'person') e.speedMul = Math.sqrt(f) * (e._panic ?? 1); }
    },
  },
  flash: { update(sim, fx, k, t) { if (t >= fx.start) sim.look.flash = Math.max(sim.look.flash, clamp(1 - (t - fx.start) / (fx.length ?? 0.6)) * (fx.amount ?? 1)); } },
  shake: { update(sim, fx, k) { sim.shake = Math.max(sim.shake, k * (fx.amount ?? 0.4)); } },
  panic: {
    update(sim, fx, k, t) {
      if (k <= 0 || fx._state.done) return; fx._state.done = true;
      const from = fx.from ? new THREE.Vector3(fx.from[0], 0, fx.from[1]) : null;
      for (const e of sim.ents('people')) {
        e.static = false; e._panic = 3; e.speedMul = 3; if (!e.speed) e.speed = 1.3;
        const d = from ? e.obj.position.clone().sub(from).setY(0).normalize() : new THREE.Vector3(sim.rng() - 0.5, 0, sim.rng() - 0.5).normalize();
        e.runDir = d; e.obj.rotation.y = Math.atan2(d.x, d.z);
        if (fx.armsUp) e.armsUp = true;
      }
    },
  },
  rain_objects: {
    setup(sim, fx) {
      const kind = fx.object || 'cubes', n = Math.min(400, fx.count ?? 120), r = sim.rng; fx._objs = [];
      for (let i = 0; i < n; i++) {
        let o;
        if (kind === 'cars') { const e = sim.car(0, 0, 1, ['#c0392b', '#ecf0f1', '#2c3e50', '#f6c514', '#2980b9'][i % 5], 0, { parked: true }); o = e; }
        else if (kind === 'people') o = sim.person(0, 0, r, { static: true });
        else {
          const geo = kind === 'balls' ? new THREE.SphereGeometry(0.6 * (fx.size ?? 1), 16, 10) : kind === 'coins' ? new THREE.CylinderGeometry(0.5 * (fx.size ?? 1), 0.5 * (fx.size ?? 1), 0.1, 16) : new THREE.BoxGeometry(fx.size ?? 1, fx.size ?? 1, fx.size ?? 1);
          const m = new THREE.Mesh(geo, sim.mat(fx.color || (kind === 'coins' ? '#f2c230' : ['#e74c3c', '#f1c40f', '#3498db', '#2ecc71', '#9b59b6'][i % 5]), { metalness: kind === 'coins' ? 0.8 : 0.1, roughness: kind === 'coins' ? 0.3 : 0.6 }));
          m.castShadow = true; const g = new THREE.Group(); g.add(m); o = sim.addEntity(g, 'prop', [kind, 'falling'], { movable: true });
        }
        o.obj.visible = false; o.hidden = true; o.spawnT = fx.start + r() * (fx.spread ?? 4); fx._objs.push(o);
      }
    },
    update(sim, fx, k, t) {
      const c = sim.camera.position, r = sim.rng;
      for (const e of fx._objs) {
        if (e.hidden && t >= e.spawnT) {
          e.hidden = false; e.obj.visible = true; e.physics = true; e.g = -9.8; e.landing = false;
          e.obj.position.set(c.x + (r() - 0.5) * 50, 60 + r() * 50, c.z - 15 - r() * 70); e.vel.set(0, -10, 0); e.angVel.set(r() * 3, r() * 3, r() * 3);
        }
      }
    },
  },
  custom: {
    setup(sim, fx) {
      const api = { THREE, sim, scene: sim.scene, rng: sim.rng, fx, Particles, col, lerp, clamp, smooth };
      try {
        fx._setup = fx.setupCode ? new Function('api', `const {THREE, sim, scene, rng, fx, Particles, col, lerp, clamp, smooth} = api;\n${fx.setupCode}`) : null;
        fx._update = fx.code ? new Function('api', 't', 'dt', 'k', `const {THREE, sim, scene, rng, fx, Particles, col, lerp, clamp, smooth} = api;\n${fx.code}`) : null;
        fx._api = api; fx._setup && fx._setup(api);
      } catch (e) { sim.err(e, fx); fx._update = null; }
    },
    update(sim, fx, k, t, dt) { if (fx._update) { try { fx._update(fx._api, t, dt, k); } catch (e) { sim.err(e, fx); fx._update = null; } } },
  },
};

// ---------- spec normalization ----------
function num(v, d) { const n = Number(v); return Number.isFinite(n) ? n : d; }
function normalizeSpec(s) {
  s = JSON.parse(JSON.stringify(s || {}));
  s.title = s.title || 'What if...?';
  s.duration = clamp(num(s.duration, 20), 5, 90);
  s.setting = BUILDERS[s.setting] ? s.setting : 'city';
  s.time = TIMES[s.time] ? s.time : 'day';
  s.camera = typeof s.camera === 'string' ? { mode: s.camera } : (s.camera || {});
  s.camera.mode = s.camera.mode || 'street';
  s.effects = Array.isArray(s.effects) ? s.effects.filter((f) => f && f.type) : [];
  for (const f of s.effects) { f.start = num(f.start, 0); if (f.end != null) f.end = num(f.end, null); if (f.revert == null) f.revert = f.end != null && f.end < s.duration; }
  s.hud = (Array.isArray(s.hud) ? s.hud : []).slice(0, 3).map((h) => ({ ...h, from: num(h.from, 0), to: num(h.to, num(h.from, 0)), start: num(h.start, 0), end: num(h.end, num(h.start, 0)) }));
  s.captions = (Array.isArray(s.captions) ? s.captions : []).filter((c) => c && c.text).map((c) => ({ ...c, start: num(c.start ?? c.t, 0), end: c.end != null ? num(c.end, null) : null }));
  if (!s.captions.some((c) => c.style === 'title')) s.captions.unshift({ text: s.title, start: 0.2, end: Math.min(s.duration, 5.5), style: 'title' });
  return s;
}

// ---------- boot ----------
const sim = new Sim();
window.SIM = sim;
window.SIM_READY = true;
window.addEventListener('error', (e) => sim.errors.push(String(e.message)));

const params = new URLSearchParams(location.search);
if (params.has('preview')) {
  document.body.classList.add('preview');
  const fit = () => { const s = Math.min(innerWidth / W, innerHeight / H); const st = document.getElementById('stage'); st.style.transform = `scale(${s})`; document.body.style.height = H * s + 'px'; document.body.style.width = W * s + 'px'; };
  addEventListener('resize', fit); fit();
  (async () => {
    const id = params.get('preview');
    const spec = await (await fetch(`/api/spec/${encodeURIComponent(id)}`)).json();
    await sim.init(spec, { pixelRatio: 0.5, shadows: true });
    let last = performance.now(), acc = 0;
    const loop = (now) => {
      acc += Math.min(0.1, (now - last) / 1000); last = now;
      while (acc >= sim.dt) { sim.t += sim.dt; sim.frame++; sim.update(sim.dt); acc -= sim.dt; }
      if (sim.t > sim.spec.duration) { sim.renderer.dispose(); location.reload(); return; }
      sim.render(); requestAnimationFrame(loop);
    };
    requestAnimationFrame(loop);
  })();
}
