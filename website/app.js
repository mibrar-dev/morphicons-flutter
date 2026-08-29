/* ============================================================
   Morphicons playground — drives the real solver (MorphCore)
   ============================================================ */

const M = window.MorphCore;
const LUCIDE = window.LucideCatalog || {};
const LIBRARIES = {
  lucide: { label: 'Lucide', data: LUCIDE },
  heroicons: { label: 'Heroicons', data: window.HeroiconsCatalog || {} },
  tabler: { label: 'Tabler', data: window.TablerCatalog || {} },
};

/* ---------- floating navigation ---------- */
(() => {
  const toggle = document.querySelector('.nav-toggle');
  const menu = document.getElementById('mobileMenu');
  if (toggle && menu) {
    function setMenu(open) {
      toggle.setAttribute('aria-expanded', String(open));
      toggle.setAttribute('aria-label', open ? 'Close navigation' : 'Open navigation');
      menu.classList.toggle('is-open', open);
      menu.setAttribute('aria-hidden', String(!open));
      document.body.classList.toggle('menu-open', open);
    }
    toggle.addEventListener('click', () => {
      setMenu(toggle.getAttribute('aria-expanded') !== 'true');
    });
    menu.querySelectorAll('a').forEach((link) => link.addEventListener('click', () => setMenu(false)));
    document.addEventListener('keydown', (event) => {
      if (event.key === 'Escape' && toggle.getAttribute('aria-expanded') === 'true') setMenu(false);
    });
  }
  // Desktop showcase dropdown — click toggles for keyboard/touch, hover still works via CSS.
  const dd = document.querySelector('.nav-dropdown');
  const ddBtn = document.querySelector('.nav-dropdown-trigger');
  if (dd && ddBtn) {
    ddBtn.addEventListener('click', (e) => {
      e.preventDefault();
      const open = ddBtn.getAttribute('aria-expanded') === 'true';
      ddBtn.setAttribute('aria-expanded', String(!open));
      dd.classList.toggle('is-open', !open);
    });
    document.addEventListener('click', (e) => {
      if (!dd.contains(e.target)) {
        ddBtn.setAttribute('aria-expanded', 'false');
        dd.classList.remove('is-open');
      }
    });
  }
})();

/* Library-qualified icon refs: "lucide:menu", "heroicons:x-mark", "tabler:x".
   Bare names resolve against Lucide for backwards compatibility. */
function splitIconRef(ref) {
  const s = String(ref || '');
  const i = s.indexOf(':');
  if (i > 0) {
    const lib = s.slice(0, i);
    const name = s.slice(i + 1);
    return { lib: Object.prototype.hasOwnProperty.call(LIBRARIES, lib) ? lib : '', name };
  }
  return { lib: 'lucide', name: s };
}
function dForRef(ref, fallback) {
  const { lib, name } = splitIconRef(ref);
  const data = lib ? LIBRARIES[lib].data : null;
  const d = (data && name && data[name]) || '';
  return d || fallback || '';
}

/* ---------- morph safety net ----------
   Any ref — known or not, valid d or not — must always produce a usable
   plan. Empirically: resampleIcon('') / 'M12 12' yield 0 subpaths and
   buildPlan then throws "icon has no subpaths"; malformed d throws from the
   parser. A throw inside the auto-morph loop would kill the rAF chain, so
   every stage below degrades to a fallback instead of throwing. */
const FALLBACK_D = 'M0 0M12 2A10 10 0 1 0 12 22A10 10 0 1 0 12 2Z';
const FALLBACK_PTS = (() => {
  const pts = new Float64Array(2 * 64);
  for (let i = 0; i < 64; i++) {
    const a = (i / 64) * Math.PI * 2;
    pts[2 * i] = 12 + 9 * Math.cos(a);
    pts[2 * i + 1] = 12 + 9 * Math.sin(a);
  }
  return [{ pts, closed: true }];
})();

function resolveD(ref) {
  const e = catalogEntry(ref);
  return e ? e.d : FALLBACK_D;
}

function iconLabel(ref) {
  const e = catalogEntry(ref);
  return e ? e.name : String(ref ?? '').replace(/^[a-z]+:/i, '');
}

function catalogEntry(ref) {
  if (typeof ref !== 'string') return null;
  const raw = ref.trim();
  if (!raw) return null;
  const { lib, name } = splitIconRef(raw);
  const libs = lib ? [lib] : Object.keys(LIBRARIES);
  for (const l of libs) {
    const data = LIBRARIES[l] && LIBRARIES[l].data;
    if (data && Object.prototype.hasOwnProperty.call(data, name) && typeof data[name] === 'string' && data[name].trim()) {
      return { ref: `${l}:${name}`, lib: l, name, d: data[name] };
    }
  }
  return null;
}

const RESAMPLE_CACHE_LIMIT = 512;
const resampleCache = new Map();
function safeResample(d) {
  if (typeof d !== 'string' || !d.trim()) return null;
  const hit = resampleCache.get(d);
  if (hit !== undefined) return hit;
  let out = null;
  try {
    const subs = M.resampleIcon(d);
    out = Array.isArray(subs) && subs.length > 0 && subs.every((s) => s && s.pts && s.pts.length >= 4) ? subs : null;
  } catch { out = null; }
  if (resampleCache.size >= RESAMPLE_CACHE_LIMIT) resampleCache.delete(resampleCache.keys().next().value);
  resampleCache.set(d, out);
  return out;
}

function safeBuildPlan(fromD, toD) {
  const a = safeResample(fromD) || FALLBACK_PTS;
  const b = safeResample(toD) || FALLBACK_PTS;
  try {
    return M.buildPlan(a, b);
  } catch {
    // Last resort: identity plan on the fallback icon — a valid plan is
    // always returned so sequences, springs and the UI never break.
    try { return M.buildPlan(FALLBACK_PTS, FALLBACK_PTS); } catch { return null; }
  }
}

function iconData(name, fallback) {
  return dForRef(name, fallback);
}

/* ---------- icon pairs (24x24 stroke data, lucide grammar) ---------- */
const PAIRS = [
  { id: 'menu-x', label: 'menu → x', from: iconData('menu', 'M0 0M4 12h16 M0 0M4 6h16 M0 0M4 18h16'), to: iconData('x', 'M0 0M18 6 6 18 M0 0m6 6 12 12') },
  { id: 'arrow-right-down', label: 'arrow-right → arrow-down', from: iconData('arrow-right', 'M0 0M5 12h14 M0 0m12-7 7 7-7 7'), to: iconData('arrow-down', 'M0 0M12 5v14 M0 0m-7-7 7 7 7-7') },
  { id: 'plus-minus', label: 'plus → minus', from: iconData('plus', 'M0 0M5 12h14 M0 0M12 5v14'), to: iconData('minus', 'M0 0M5 12h14') },
  { id: 'check-x', label: 'check → x', from: iconData('check', 'M0 0M20 6 9 17l-5-5'), to: iconData('x', 'M0 0M18 6 6 18 M0 0m6 6 12 12') },
  { id: 'square-circle', label: 'square → circle', from: iconData('square', 'M0 0M5 5h14v14H5Z'), to: iconData('circle', 'M0 0M12 2a10 10 0 1 0 0 20 10 10 0 1 0 0-20') },
];

const PRESETS = { smooth: { k: 170, c: 26 }, snappy: { k: 420, c: 30 }, bouncy: { k: 300, c: 14 } };

/* ---------- icon-only controls (SVG fallback when MorphCore is absent) ---------- */
const PLAY_ICON = '<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polygon points="6 3 20 12 6 21 6 3"></polygon></svg>';
const PAUSE_ICON = '<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="6" y="4" width="4" height="16" rx="1"></rect><rect x="14" y="4" width="4" height="16" rx="1"></rect></svg>';
function setPlayPauseIcon(btn, isPlaying) {
  if (!btn) return;
  const isPause = !!isPlaying;
  btn.innerHTML = isPause ? PAUSE_ICON : PLAY_ICON;
  btn.setAttribute('aria-label', isPause ? 'Pause' : 'Play');
  btn.setAttribute('aria-pressed', String(isPause));
  btn.title = isPause ? 'Pause' : 'Play';
}

/* ---------- morphing icon buttons (MorphCore) ----------
   The button icon is itself a canvas morph driven by the same solver:
   interpPolar between play and pause shapes, animated with the snappy
   spring (k=420, c=30) instead of a static innerHTML swap. */
const BTN_PLAY_D = 'M6 3L20 12L6 21';
const BTN_PAUSE_D = 'M6 4h4v16h-4zM14 4h4v16h-4z';

function createMorphButton(btn, fromD, toD) {
  if (!btn) return null;
  const fallbackMorphTo = (d) => setPlayPauseIcon(btn, d === toD);
  if (!M || typeof M.buildPlan !== 'function' || typeof M.Spring !== 'function') {
    return { morphTo: fallbackMorphTo };
  }
  const plan = safeBuildPlan(fromD, toD);
  const out = plan ? M.allocOutputs(plan) : null;
  if (!out) return { morphTo: fallbackMorphTo };

  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  btn.innerHTML = '';
  const canvas = document.createElement('canvas');
  canvas.width = Math.round(16 * dpr);
  canvas.height = Math.round(16 * dpr);
  canvas.setAttribute('aria-hidden', 'true');
  btn.appendChild(canvas);
  const ctx = canvas.getContext('2d');
  const spring = new M.Spring();

  // 0 = from (play) shape, 1 = to (pause) shape. Starts on the play shape so
  // the first morphTo(toD) renders a visible play → pause morph.
  let value = reducedMotion ? 1 : 0;
  let from = value;
  let target = value;
  let rafId = null;

  function draw() {
    const s = canvas.width / 24;
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    ctx.strokeStyle = getComputedStyle(btn).color || '#ededed';
    ctx.lineWidth = 2 * s;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    M.interpPolar(plan, Math.min(1, Math.max(0, value)), out);
    for (let k = 0; k < out.length; k++) {
      const pts = out[k];
      if (typeof pts === 'string') continue;
      const n = pts.length / 2;
      if (n < 2) continue;
      ctx.beginPath();
      ctx.moveTo(pts[0] * s, pts[1] * s);
      for (let i = 1; i < n; i++) ctx.lineTo(pts[2 * i] * s, pts[2 * i + 1] * s);
      // play/pause are open strokes — never close
      ctx.stroke();
    }
  }

  function frame() {
    rafId = null;
    if (spring.step(1 / 60)) {
      value = target;
      draw();
      return;
    }
    value = from + (target - from) * Math.min(spring.x, 1);
    draw();
    rafId = requestAnimationFrame(frame);
  }

  function morphTo(d) {
    const isTo = d === toD;
    btn.setAttribute('aria-label', isTo ? 'Pause' : 'Play');
    btn.setAttribute('aria-pressed', String(isTo));
    btn.title = isTo ? 'Pause' : 'Play';
    const to = isTo ? 1 : 0;
    if (to === target && value === target) return;
    if (reducedMotion) {
      value = to;
      target = to;
      draw();
      return;
    }
    from = value;
    target = to;
    spring.config(420, 30);
    spring.start();
    if (rafId == null) rafId = requestAnimationFrame(frame);
  }

  draw();
  return { morphTo };
}

/* ---------- canvas helpers ---------- */
function fitCanvas(canvas) {
  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  const rect = canvas.getBoundingClientRect();
  if (rect.width === 0) return null;
  const w = Math.round(rect.width * dpr);
  const h = Math.round(rect.height * dpr);
  if (canvas.width !== w || canvas.height !== h) { canvas.width = w; canvas.height = h; }
  const ctx = canvas.getContext('2d');
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  return { ctx, w, h, dpr };
}

function drawSubs(ctx, w, h, subs, color, lineWidthPx, closed) {
  ctx.clearRect(0, 0, w, h);
  const pad = 0.10;
  const s = (Math.min(w, h) / 24) * (1 - 2 * pad);
  const ox = (w - 24 * s) / 2;
  const oy = (h - 24 * s) / 2;
  ctx.strokeStyle = color;
  ctx.lineWidth = lineWidthPx;
  ctx.lineCap = 'round';
  ctx.lineJoin = 'round';
  for (let k = 0; k < subs.length; k++) {
    const pts = subs[k];
    if (typeof pts === 'string') continue;
    const n = pts.length / 2;
    if (n < 2) continue;
    ctx.beginPath();
    ctx.moveTo(ox + pts[0] * s, oy + pts[1] * s);
    for (let i = 1; i < n; i++) ctx.lineTo(ox + pts[2 * i] * s, oy + pts[2 * i + 1] * s);
    // closed subpaths (closed=true in the plan) must connect the last resampled
    // point back to the first — otherwise the final perimeter segment is a gap.
    if (closed && closed[k]) ctx.closePath();
    ctx.stroke();
  }
}

function svgFromD(d, stroke, strokeWidth) {
  const NS = 'http://www.w3.org/2000/svg';
  const svg = document.createElementNS(NS, 'svg');
  svg.setAttribute('viewBox', '0 0 24 24');
  svg.setAttribute('fill', 'none');
  svg.setAttribute('stroke', stroke || 'currentColor');
  svg.setAttribute('stroke-width', String(strokeWidth ?? 2));
  svg.setAttribute('stroke-linecap', 'round');
  svg.setAttribute('stroke-linejoin', 'round');
  const path = document.createElementNS(NS, 'path');
  path.setAttribute('d', d);
  svg.appendChild(path);
  return svg;
}

/* ---------- plan stats ---------- */
function planStats(plan) {
  const it = plan.items[0];
  const sigma = it.sigma !== undefined ? it.sigma : Math.exp(it.lnSigma);
  const blockHybrid = plan.items.every((x) => x.block != null) &&
    plan.items.every((x) => Math.abs(x.theta - it.theta) < 1e-12);
  return { theta: it.theta, sigma, res: it.res, blockHybrid };
}

function settleSeconds(k, c) {
  const s = new M.Spring();
  s.config(k, c);
  s.start();
  let frames = 0;
  while (!s.step(1 / 60) && frames < 3000) frames++;
  return frames / 60;
}

/* ---------- spring curve plot ---------- */
function drawCurve(canvas, k, c, currentT) {
  const fit = fitCanvas(canvas);
  if (!fit) return;
  const { ctx, w, h } = fit;
  ctx.clearRect(0, 0, w, h);

  const total = settleSeconds(k, c) + 0.2;
  const s = new M.Spring();
  s.config(k, c);
  s.start();
  const xs = [];
  let t = 0;
  while (true) {
    xs.push(s.x);
    if (s.step(1 / 60)) break;
    t += 1 / 60;
    if (t > 8) break;
  }
  const maxT = xs.length / 60;

  const px = (tt) => (tt / maxT) * (w - 8) + 4;
  const py = (x) => h - 10 - (x / 1.25) * (h - 24);

  ctx.strokeStyle = '#262626';
  ctx.lineWidth = 1;
  ctx.beginPath(); ctx.moveTo(0, py(1)); ctx.lineTo(w, py(1)); ctx.stroke();

  ctx.strokeStyle = '#ededed';
  ctx.lineWidth = 1.6;
  ctx.beginPath();
  xs.forEach((x, i) => {
    const X = px(i / 60), Y = py(x);
    if (i === 0) ctx.moveTo(X, Y); else ctx.lineTo(X, Y);
  });
  ctx.stroke();

  if (currentT >= 0 && currentT <= 1) {
    const spring2 = new M.Spring();
    spring2.config(k, c);
    spring2.start();
    let tt = 0;
    while (spring2.x < currentT && tt < maxT) { spring2.step(1 / 60); tt += 1 / 60; }
    ctx.fillStyle = '#9F2F2D';
    ctx.beginPath();
    ctx.arc(px(tt), py(spring2.x), 3.4, 0, Math.PI * 2);
    ctx.fill();
  }
}

/* ============================================================
   HERO — auto-cycling showcase (viewport-aware)
   ============================================================ */
const hero = (() => {
  const canvas = document.getElementById('heroCanvas');
  if (!canvas) return {};
  const label = document.getElementById('heroPairLabel');
  const fromCanvas = document.getElementById('heroFromCanvas');
  const toCanvas = document.getElementById('heroToCanvas');
  const slowToggle = document.getElementById('heroSlow');
  const heroSection = canvas.closest('.hero') || canvas.parentElement;
  let idx = 0;
  let plan = null, out = null;
  let planClosed = null;
  const spring = new M.Spring();
  let phase = 'morph'; // morph -> hold -> next
  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  let visible = true;
  let rafId = null;
  let slow = false;
  if (slowToggle) slowToggle.addEventListener('change', () => { slow = slowToggle.checked; });

  function drawStatic(canvasEl, d) {
    if (!canvasEl) return;
    const fit = fitCanvas(canvasEl);
    if (!fit) return;
    try {
      const soloPlan = M.buildPlan(M.resampleIcon(d), M.resampleIcon(d));
      const soloOut = M.allocOutputs(soloPlan);
      M.interpPolar(soloPlan, 1, soloOut);
      drawSubs(fit.ctx, fit.w, fit.h, soloOut, '#7d7d7d', 1.6 * (fit.w / 112) * 0.9, soloPlan.items.map((it) => !!it.closed));
    } catch {}
  }

  function loadPair(i) {
    const p = PAIRS[i];
    const t0 = performance.now();
    plan = M.buildPlan(M.resampleIcon(p.from), M.resampleIcon(p.to));
    out = M.allocOutputs(plan);
    planClosed = plan.items.map((it) => !!it.closed);
    spring.config(slow ? 90 : 170, slow ? 20 : 26);
    spring.start();
    phase = 'morph';
    if (label) label.textContent = p.label;
    drawStatic(fromCanvas, p.from);
    drawStatic(toCanvas, p.to);
    return performance.now() - t0;
  }

  let holdUntil = 0;
  loadPair(0);

  function frame() {
    rafId = null;
    let canDraw = visible && !document.hidden;
    if (heroSection) {
      const r = heroSection.getBoundingClientRect();
      if (r.bottom < 0 || r.top > window.innerHeight) canDraw = false;
    }
    if (!canDraw) {
      rafId = requestAnimationFrame(frame);
      return;
    }
    const fit = fitCanvas(canvas);
    if (fit && plan && out) {
      const { ctx, w, h } = fit;
      if (reducedMotion) {
        M.interpPolar(plan, 1, out);
        drawSubs(ctx, w, h, out, '#ededed', 2 * (w / 240) * 0.9, planClosed);
      } else if (phase === 'morph') {
        const dt = slow ? 1/120 : 1/60; // slow motion halves speed
        const settled = spring.step(dt);
        M.interpPolar(plan, Math.min(spring.x, 1), out);
        drawSubs(ctx, w, h, out, '#ededed', 2 * (w / 240) * 0.9, planClosed);
        if (settled) { phase = 'hold'; holdUntil = performance.now() + (slow ? 2200 : 1400); }
      } else if (phase === 'hold') {
        M.interpPolar(plan, 1, out);
        drawSubs(ctx, w, h, out, '#ededed', 2 * (w / 240) * 0.9, planClosed);
        if (performance.now() > holdUntil) {
          idx = (idx + 1) % PAIRS.length;
          loadPair(idx);
        }
      }
    }
    rafId = requestAnimationFrame(frame);
  }
  // Pause when scrolled out of view — saves CPU and respects user.
  if ('IntersectionObserver' in window && heroSection) {
    const io = new IntersectionObserver((entries) => {
      visible = entries[0].isIntersecting && !document.hidden;
      window._heroVisible = visible;
      if (visible && rafId == null) rafId = requestAnimationFrame(frame);
    }, { threshold: 0.15 });
    io.observe(heroSection);
  }
  window._heroVisible = visible;
  window._heroGetVisible = () => visible;
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) visible = false;
    else if (heroSection) {
      const r = heroSection.getBoundingClientRect();
      visible = r.bottom > 0 && r.top < window.innerHeight;
    } else visible = true;
    window._heroVisible = visible;
    if (visible && rafId == null) rafId = requestAnimationFrame(frame);
  });
  rafId = requestAnimationFrame(frame);
  return {
    get visible() { return visible; },
    pause() { visible = false; window._heroVisible = false; },
    resume() { visible = true; window._heroVisible = true; if (rafId == null) rafId = requestAnimationFrame(frame); }
  };
})();

/* ============================================================
   PLAYGROUND
   ============================================================ */
const pg = (() => {
  const canvas = document.getElementById('pgCanvas');
  const cmpCanvas = document.getElementById('pgCompareCanvas');
  const cmpWrap = document.getElementById('pgCompareWrap');
  const title = document.getElementById('pgTitle');
  const playBtn = document.getElementById('pgPlay');
  const replayBtn = document.getElementById('pgReplay');
  const pgPlayMorph = createMorphButton(playBtn, BTN_PLAY_D, BTN_PAUSE_D);
  const tSlider = document.getElementById('pgT');
  const tVal = document.getElementById('pgTVal');
  const kSlider = document.getElementById('pgK');
  const cSlider = document.getElementById('pgC');
  const kVal = document.getElementById('pgKVal');
  const cVal = document.getElementById('pgCVal');
  const seg = document.getElementById('presetSeg');
  const compareBox = document.getElementById('pgCompare');
  const curveCanvas = document.getElementById('curveCanvas');
  const pairSource = document.getElementById('pairSource');
  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const ro = {
    theta: document.getElementById('roTheta'),
    sigma: document.getElementById('roSigma'),
    res: document.getElementById('roRes'),
    block: document.getElementById('roBlock'),
    planMs: document.getElementById('roPlanMs'),
    settle: document.getElementById('roSettle'),
  };

   const state = {
    pair: 0,
    animationSet: [],
    animationIndex: 0,
    k: 170, c: 26,
    stroke: 2,
    preset: 'smooth',
    mode: 'idle',      // idle | playing | scrub
    t: 0,
    plan: null, out: null,
    spring: new M.Spring(),
  };

  /* ----- pair picker ----- */
  const pairGrid = document.getElementById('pairGrid');
  PAIRS.forEach((p, i) => {
     const b = document.createElement('button');
     b.className = 'pair-btn' + (i === 0 ? ' is-active' : '');
     b.setAttribute('role', 'option');
     b.setAttribute('aria-selected', String(i === 0));
     b.setAttribute('aria-label', `Use icon pair ${p.label}`);
     b.title = p.label;
     b.appendChild(svgFromD(p.to, 'currentColor', state.stroke));
    const lbl = document.createElement('span');
    lbl.textContent = p.label;
    b.appendChild(lbl);
    b.addEventListener('click', () => {
      pairGrid.querySelectorAll('.pair-btn').forEach((x) => {
        x.classList.remove('is-active');
        x.setAttribute('aria-selected', 'false');
      });
      b.classList.add('is-active');
      b.setAttribute('aria-selected', 'true');
      state.pair = i;
      if (typeof window.setLucideAnimationSet === 'function') window.setLucideAnimationSet([]);
      rebuildPlan();
      restart();
    });
    pairGrid.appendChild(b);
  });

   function currentPair() {
     if (state.animationSet.length >= 2) {
       const from = state.animationSet[state.animationIndex % state.animationSet.length];
       const to = state.animationSet[(state.animationIndex + 1) % state.animationSet.length];
       return { label: `${iconLabel(from)} → ${iconLabel(to)}`, from: resolveD(from), to: resolveD(to) };
     }
     return PAIRS[state.pair];
   }

    function rebuildPlan(fromD) {
      const p = currentPair();
      if (!p || !p.from || !p.to) return;
     title.textContent = p.label;
     // D string hidden to prevent dynamic flow/layout reflow — keep label only
     pairSource.textContent = p.label;
     pairSource.setAttribute('data-d-from', p.from);
     pairSource.setAttribute('data-d-to', p.to);
    const t0 = performance.now();
    // fromD (optional): d-string snapshot of the shape currently on screen.
    // Used when the sequence is retargeted (icon picked/removed) so the new
    // plan starts from exactly what the eye sees — a continuous morph, no snap.
    const plan = safeBuildPlan(typeof fromD === 'string' && fromD.trim() ? fromD : p.from, p.to);
    if (!plan) return; // keep the previous plan — never break the loop
    state.plan = plan;
    const ms = performance.now() - t0;
    state.out = M.allocOutputs(state.plan);
    const st = planStats(state.plan);
    ro.theta.textContent = st.theta.toFixed(4) + ' rad';
    ro.sigma.textContent = st.sigma.toFixed(4);
    ro.res.textContent = st.res.toExponential(2);
    ro.block.textContent = st.blockHybrid ? 'applied' : 'per-subpath';
    ro.planMs.textContent = ms.toFixed(2) + ' ms';
    ro.settle.textContent = settleSeconds(state.k, state.c).toFixed(2) + ' s';
    drawCurve(curveCanvas, state.k, state.c, state.t);
  }

  function applySpring() {
    state.spring.config(state.k, state.c);
    ro.settle.textContent = settleSeconds(state.k, state.c).toFixed(2) + ' s';
    drawCurve(curveCanvas, state.k, state.c, state.t);
  }

  function restart() {
    state.spring = new M.Spring();
    state.spring.config(state.k, state.c);
    state.spring.start();
    if (reducedMotion) {
      state.spring.x = 1;
      state.mode = 'idle';
      state.t = 1;
      pgPlayMorph?.morphTo(BTN_PLAY_D);
      render(1);
      return;
    }
    state.mode = 'playing';
    state.t = 0;
    pgPlayMorph?.morphTo(BTN_PAUSE_D);
  }

  function render(t) {
    const fit = fitCanvas(canvas);
    if (fit && state.plan) {
      M.interpPolar(state.plan, t, state.out);
       drawSubs(fit.ctx, fit.w, fit.h, state.out, '#ededed', state.stroke * (fit.w / 320) * 0.9, state.plan.items.map((it) => !!it.closed));
    }
    if (!cmpWrap.hidden) {
      const fit2 = fitCanvas(cmpCanvas);
      if (fit2 && state.plan) {
        const outL = M.allocOutputs(state.plan);
        M.interpLinear(state.plan, t, outL);
         drawSubs(fit2.ctx, fit2.w, fit2.h, outL, '#9F2F2D', state.stroke * (fit2.w / 320) * 0.9, state.plan.items.map((it) => !!it.closed));
      }
    }
    tSlider.value = t;
    tVal.textContent = 't = ' + t.toFixed(3);
    drawCurve(curveCanvas, state.k, state.c, t);
  }

  /* ----- animation loop (pauses when section not in view) ----- */
  let pgVisible = true;
  const pgSection = document.getElementById('playground') || document.querySelector('.playground');
  if ('IntersectionObserver' in window && pgSection) {
    const io = new IntersectionObserver((entries) => {
      pgVisible = entries[0].isIntersecting && !document.hidden;
      // expose for debugging / tests
      window._pgVisible = pgVisible;
    }, { threshold: 0.12, rootMargin: '0px 0px -40px 0px' });
    io.observe(pgSection);
  }
  // Also pause while tab hidden (user switched tabs) — saves battery.
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) pgVisible = false;
    else if (pgSection) {
      const rect = pgSection.getBoundingClientRect();
      pgVisible = rect.top < window.innerHeight && rect.bottom > 0;
    } else pgVisible = true;
    window._pgVisible = pgVisible;
  });
  // debugging helper
  window._pgVisible = pgVisible;
  window._pgGetVisible = () => pgVisible;
  window._pgSectionRect = () => {
    if (!pgSection) return null;
    const r = pgSection.getBoundingClientRect();
    return { top: r.top, bottom: r.bottom, vh: window.innerHeight, hidden: document.hidden, flag: pgVisible };
  };
  function tick() {
    // Recompute visibility synchronously each tick as safety net (covers fast scroll before observer fires)
    let canAnimate = pgVisible && !document.hidden;
    if (pgSection) {
      const r = pgSection.getBoundingClientRect();
      const inView = r.bottom > 0 && r.top < window.innerHeight;
      if (!inView) canAnimate = false;
    }
    const isSlow = document.getElementById('pgSlow')?.checked;
    const dt = isSlow ? 1/120 : 1/60;
    window._lastCanAnimate = canAnimate;
    window._lastTickMode = state.mode;
    if (state.mode === 'playing' && canAnimate) {
      const settled = state.spring.step(dt);
      state.t = Math.min(state.spring.x, 1.2);
      render(Math.min(state.t, 1));
        if (settled) {
           state.mode = 'idle';
           state.t = 1;
           render(1);
           pgPlayMorph?.morphTo(BTN_PLAY_D);
           // Auto-morph every icon at start: cycle animationSet if present, otherwise cycle PAIRS slowly
           // Wrapped so no failure during a transition can ever kill the rAF loop.
           if (canAnimate) {
             try {
               if (state.animationSet.length >= 2) {
                 state.animationIndex = (state.animationIndex + 1) % state.animationSet.length;
                 rebuildPlan();
                 restart();
               } else {
                 // no set: auto-advance through built-in pairs to show every icon morphing
                 state.pair = (state.pair + 1) % PAIRS.length;
                 // update pairGrid active state
                 const btns = pairGrid.querySelectorAll('.pair-btn');
                 btns.forEach((x, idx) => {
                   const active = idx === state.pair;
                   x.classList.toggle('is-active', active);
                   x.setAttribute('aria-selected', String(active));
                 });
                 rebuildPlan();
                 // small hold before next morph so slow motion is visible
                 setTimeout(() => { if (pgVisible && !document.hidden) restart(); }, isSlow ? 600 : 300);
               }
             } catch {}
           }
        }
    }
    requestAnimationFrame(tick);
  }

  /* ----- controls ----- */
  playBtn.addEventListener('click', () => {
    if (state.mode === 'playing') {
      state.mode = 'idle';
      pgPlayMorph?.morphTo(BTN_PLAY_D);
      return;
    }
    if (state.t >= 1 || state.t === 0) restart();
    else {
      state.mode = 'playing';
      pgPlayMorph?.morphTo(BTN_PAUSE_D);
    }
  });
  replayBtn.addEventListener('click', restart);

  tSlider.addEventListener('input', () => {
    state.mode = 'scrub';
    pgPlayMorph?.morphTo(BTN_PLAY_D);
    state.t = parseFloat(tSlider.value);
    render(state.t);
  });

   seg.querySelectorAll('.seg-btn').forEach((b) => {
     b.addEventListener('click', () => {
       seg.querySelectorAll('.seg-btn').forEach((x) => {
         x.classList.remove('is-active');
         x.setAttribute('aria-selected', 'false');
       });
       b.classList.add('is-active');
       b.setAttribute('aria-selected', 'true');
      const name = b.dataset.preset;
      state.preset = name;
      if (name !== 'custom') {
        state.k = PRESETS[name].k;
        state.c = PRESETS[name].c;
        kSlider.value = state.k;
        cSlider.value = state.c;
        kVal.textContent = state.k;
        cVal.textContent = state.c;
        applySpring();
        restart();
      }
    });
  });

  function customFromSliders() {
    seg.querySelectorAll('.seg-btn').forEach((x) => {
      x.classList.remove('is-active');
      x.setAttribute('aria-selected', 'false');
    });
    seg.querySelector('[data-preset="custom"]').classList.add('is-active');
    seg.querySelector('[data-preset="custom"]').setAttribute('aria-selected', 'true');
    state.preset = 'custom';
    applySpring();
  }
  kSlider.addEventListener('input', () => {
    state.k = parseFloat(kSlider.value);
    kVal.textContent = state.k;
    customFromSliders();
  });
   cSlider.addEventListener('input', () => {
    state.c = parseFloat(cSlider.value);
    cVal.textContent = state.c;
    customFromSliders();
   });

   const strokeSlider = document.getElementById('pgStroke');
   const strokeVal = document.getElementById('pgStrokeVal');
   strokeSlider.addEventListener('input', () => {
     state.stroke = Math.min(2.5, Math.max(1, parseFloat(strokeSlider.value) || 2));
     strokeVal.textContent = state.stroke.toFixed(1);
     render(Math.min(state.t, 1));
      document.querySelectorAll('#playground svg').forEach((svg) => svg.setAttribute('stroke-width', String(state.stroke)));
   });

   compareBox.addEventListener('change', () => {
     cmpWrap.hidden = !compareBox.checked;
     render(Math.min(state.t, 1));
   });

    // Slow motion + from→to preview (slow by default, toggle to normal)
    const slowToggle = document.getElementById('pgSlow');
    const fromToWrap = document.getElementById('pgFromTo');
    const fromCanvas = document.getElementById('pgFromCanvas');
    const toCanvas = document.getElementById('pgToCanvas');
    let slow = slowToggle ? !!slowToggle.checked : false;
    // initialize slow config if checked on load (every icon auto-morphs slow)
    if (slow) {
      state.k = 90; state.c = 20; state.preset = 'custom';
      if (kSlider) kSlider.value = '90';
      if (cSlider) cSlider.value = '20';
      if (kVal) kVal.textContent = '90';
      if (cVal) cVal.textContent = '20';
      if (seg) {
        seg.querySelectorAll('.seg-btn').forEach((x) => { x.classList.remove('is-active'); x.setAttribute('aria-selected','false'); });
        const cust = seg.querySelector('[data-preset="custom"]');
        if (cust) { cust.classList.add('is-active'); cust.setAttribute('aria-selected','true'); }
      }
    }
    if (fromToWrap) fromToWrap.hidden = !slow;
   function drawStaticPG(canvasEl, d, color) {
     const fit = fitCanvas(canvasEl);
     if (!fit) return;
     try {
       const soloPlan = M.buildPlan(M.resampleIcon(d), M.resampleIcon(d));
       const soloOut = M.allocOutputs(soloPlan);
       M.interpPolar(soloPlan, 1, soloOut);
       drawSubs(fit.ctx, fit.w, fit.h, soloOut, color, 1.6 * (fit.w / 84) * 0.9, soloPlan.items.map((it) => !!it.closed));
     } catch {}
   }

   // Morphing preview: each canvas morphs from its previous icon to the new
   // pair's icon using the solver + snappy spring, instead of an instant swap.
   const fromPreview = createMorphPreview(fromCanvas);
   const toPreview = createMorphPreview(toCanvas);
   function createMorphPreview(canvasEl) {
     if (!canvasEl || !M || typeof M.buildPlan !== 'function') {
       return { setIcon: (d) => drawStaticPG(canvasEl, d, '#6b6b6b') };
     }
     let currentD = null;
     let plan = null, out = null;
     const spring = new M.Spring();
     let rafId = null;
     let value = 1, from = 1, target = 1;
     let fromPts = null;
     const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

     function draw(t) {
       const fit = fitCanvas(canvasEl);
       if (!fit || !plan || !out) return;
       M.interpPolar(plan, Math.min(1, Math.max(0, t)), out);
       drawSubs(fit.ctx, fit.w, fit.h, out, '#6b6b6b', 1.6 * (fit.w / 84) * 0.9, plan.items.map((it) => !!it.closed));
     }
     function frame() {
       rafId = null;
       if (spring.step(1 / 60)) {
         value = target;
         draw(1);
         return;
       }
       value = from + (target - from) * Math.min(spring.x, 1);
       draw(value);
       rafId = requestAnimationFrame(frame);
     }
     function setIcon(nextD) {
       if (!nextD) return;
       if (currentD === null || reducedMotion || currentD === nextD) {
         // first draw or same icon: render statically
         currentD = nextD;
         try {
           plan = M.buildPlan(M.resampleIcon(nextD), M.resampleIcon(nextD));
           out = M.allocOutputs(plan);
           draw(1);
         } catch {}
         return;
       }
       try {
         // snapshot current interpolated shape as the morph source
         M.interpPolar(plan, value, out);
         const closed = plan.items.map((it) => !!it.closed);
         fromPts = M.serialize(out, closed);
         plan = M.buildPlan(M.resampleIcon(fromPts), M.resampleIcon(nextD));
         out = M.allocOutputs(plan);
       } catch {
         try {
           plan = M.buildPlan(M.resampleIcon(currentD), M.resampleIcon(nextD));
           out = M.allocOutputs(plan);
         } catch { return; }
       }
       currentD = nextD;
       from = value;
       target = 1;
       value = 0;
       spring.config(420, 30);
       spring.start();
       if (rafId == null) rafId = requestAnimationFrame(frame);
     }
     return { setIcon };
   }
   function drawFromToPG() {
     if (!slow || (!fromCanvas && !toCanvas)) return;
     const p = currentPair();
     fromPreview?.setIcon(p.from);
     toPreview?.setIcon(p.to);
   }
   if (slowToggle) {
     slowToggle.addEventListener('change', () => {
       slow = slowToggle.checked;
       if (fromToWrap) fromToWrap.hidden = !slow;
       if (slow) {
         drawFromToPG();
         state.k = 90; state.c = 20;
         kSlider.value = '90'; cSlider.value = '20';
         kVal.textContent = '90'; cVal.textContent = '20';
         // mark as custom but keep slow flag
         seg.querySelectorAll('.seg-btn').forEach((x) => { x.classList.remove('is-active'); x.setAttribute('aria-selected','false'); });
         const cust = seg.querySelector('[data-preset="custom"]');
         if (cust) { cust.classList.add('is-active'); cust.setAttribute('aria-selected','true'); }
         state.preset = 'custom';
         applySpring();
         slow = true;
       } else {
         state.k = 170; state.c = 26;
         kSlider.value = '170'; cSlider.value = '26';
         kVal.textContent = '170'; cVal.textContent = '26';
         seg.querySelectorAll('.seg-btn').forEach((x) => { x.classList.remove('is-active'); x.setAttribute('aria-selected','false'); });
         const sm = seg.querySelector('[data-preset="smooth"]');
         if (sm) { sm.classList.add('is-active'); sm.setAttribute('aria-selected','true'); }
         state.preset = 'smooth';
         applySpring();
       }
     });
   }
    const origRebuild = rebuildPlan;
    rebuildPlan = function(...args) {
      origRebuild(...args);
      drawFromToPG();
    };

   window.addEventListener('resize', () => { render(Math.min(state.t, 1)); if (slow) drawFromToPG(); });

    rebuildPlan();
   restart();
   requestAnimationFrame(tick);
   // expose for viewport test
   window._pgSlow = () => slow;
    // Snapshot whatever the stage is showing right now (mid-flight spring
    // interpolation included) as a d-string. Rebuilding a plan from it makes
    // any retarget a continuous morph — the spring restarts from the on-screen
    // shape, so the flight keeps going whether the stage was idle or playing.
    function snapshotDisplayedD() {
      try {
        if (state.plan && state.out) {
          return M.serialize(state.out, state.plan.items.map((it) => !!it.closed));
        }
      } catch {}
      return null;
    }
    state.setAnimationSet = (names, focusIndex) => {
      // Keep any non-empty string ref (deduped). Unknown or broken refs resolve
      // to the fallback icon at draw/plan time, so a set never collapses and
      // the auto-morph sequence never breaks.
      const seen = new Set();
      const next = Array.isArray(names)
        ? names.filter((name) => {
            if (typeof name !== 'string' || !name.trim() || seen.has(name)) return false;
            seen.add(name);
            return true;
          })
        : [];
      const unchanged = next.length === state.animationSet.length
        && next.every((name, i) => name === state.animationSet[i]);
      state.animationSet = next;
      if (unchanged && typeof focusIndex !== 'number') return; // no-op: keep the stage as-is
      const len = state.animationSet.length;
      if (len < 2) {
        // below sequence size — fall back to the built-in pair cycle
        state.animationIndex = 0;
        rebuildPlan();
        restart();
        return;
      }
      // Never reset the sequence to 0 on selection — advance in place.
      if (typeof focusIndex === 'number' && Number.isFinite(focusIndex)) {
        // Icon just picked in the browser: morph the stage directly onto it.
        // The plan that LANDS on set[focusIndex] starts one slot back; once it
        // settles the auto-advance steps to focusIndex and the sequence keeps
        // cycling from the selected icon.
        state.animationIndex = ((focusIndex - 1) % len + len) % len;
      } else {
        // Set content changed (e.g. icon removed): clamp, keep cycling.
        state.animationIndex = ((state.animationIndex % len) + len) % len;
      }
      const snap = snapshotDisplayedD();
      rebuildPlan(snap || undefined);
      restart();
    };
   return state;
})();

/* ============================================================
   ICON LIBRARY BROWSER — search the Lucide, Heroicons and Tabler
   catalogs without mounting every icon into the document at once.
   ============================================================ */
(() => {
  const results = document.getElementById('lucideResults');
  if (!results || !Object.keys(LUCIDE).length) return;

  const search = document.getElementById('lucideSearch');
  const count = document.getElementById('lucideCount');
   const selected = document.getElementById('lucideSelected');
   const animationSet = document.getElementById('animationSet');
   const animationSetCount = document.getElementById('animationSetCount');
   const animationSetHint = document.getElementById('animationSetHint');
  const downloadSelectedIconsBtn = document.getElementById('downloadSelectedIcons');
  const filters = document.querySelectorAll('[data-lucide-filter]');
   const entries = [];
   Object.keys(LIBRARIES).forEach((lib) => {
     const meta = LIBRARIES[lib];
     Object.keys(meta.data).forEach((name) => {
       const d = meta.data[name];
       // never offer an icon that cannot morph (empty/non-string d)
       if (typeof d !== 'string' || !d.trim()) return;
       entries.push({ ref: `${lib}:${name}`, lib, name, d });
     });
   });
  const libOrder = Object.keys(LIBRARIES);
  entries.sort((a, b) => {
    const lo = libOrder.indexOf(a.lib) - libOrder.indexOf(b.lib);
    return lo !== 0 ? lo : a.name.localeCompare(b.name);
  });
  const DART_KEYWORDS = new Set([
    'assert','break','case','catch','class','const','continue','default','do','else','enum','extends','false','final','finally','for','if','in','is','new','null','rethrow','return','super','switch','this','throw','true','try','var','void','while','with'
  ]);
  function toDartIdentifier(kebab) {
    let body = String(kebab);
    let prefix = '';
    const ci = body.indexOf(':');
    if (ci > 0) {
      prefix = body.slice(0, ci);
      body = body.slice(ci + 1);
    }
    const camel = body
      .split('-')
      .filter((p) => p)
      .map((p, i) => (i === 0 && !prefix ? p : p[0].toUpperCase() + p.slice(1)))
      .join('');
    let id = prefix + camel;
    if (!id || /^[0-9]/.test(id)) {
      id = 'icon' + (id ? id[0].toUpperCase() + id.slice(1) : 'Icon');
    }
    if (DART_KEYWORDS.has(id)) id += 'Icon';
    // ensure valid: replace any remaining invalid chars (should not happen for kebab) and handle empty
    id = id.replace(/[^A-Za-z0-9_]/g, '_');
    if (!id) id = 'icon';
    if (/^[0-9]/.test(id)) id = 'icon' + id;
    return id;
  }
  function escapeDartString(value) {
    return String(value).replaceAll('\\', '\\\\').replaceAll('"', '\\"').replaceAll('$', '\\$');
  }
  function buildSelectedIconsDart(names) {
    const safeNames = Array.isArray(names) ? names.filter((n) => typeof n === 'string' && dForRef(n)) : [];
    const used = new Set();
    const lines = safeNames.map((name) => {
      const base = toDartIdentifier(name);
      let id = base;
      let n = 2;
      while (used.has(id)) id = base + n++;
      used.add(id);
      const d = dForRef(name) || '';
      const escaped = escapeDartString(d);
      return `  static const String ${id} = "${escaped}";`;
    });
    return `class SelectedIcons {\n${lines.join('\n')}\n}\n`;
  }
  function downloadSelectedIconsDart() {
    if (!state.animationSet.length || !downloadSelectedIconsBtn || downloadSelectedIconsBtn.disabled) return;
    const content = buildSelectedIconsDart(state.animationSet);
    const blob = new Blob([content], { type: 'text/plain;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'selected_icons.dart';
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  }
   const state = { filter: 'all', query: '', limit: 36, selected: '', animationSet: [] };
   // true once every filtered icon is rendered (nothing left to load)
   let allVisible = false;

   window.setLucideAnimationSet = (names) => {
     // Keep non-empty string refs (deduped); unknown/broken refs fall back to
     // the fallback icon when drawn/planned instead of breaking the sequence.
     const seen = new Set();
     state.animationSet = Array.isArray(names)
       ? names.filter((name) => {
           if (typeof name !== 'string' || !name.trim() || seen.has(name)) return false;
           seen.add(name);
           return true;
         })
       : [];
     render();
   };

   function renderAnimationSet(focusRef) {
     animationSet.replaceChildren();
     state.animationSet.forEach((name, index) => {
       const item = document.createElement('div');
       item.className = 'animation-set-item';
       item.setAttribute('role', 'listitem');
       item.title = `${index + 1}. ${iconLabel(name)}`;
       item.appendChild(svgFromD(resolveD(name), 'currentColor', pg.stroke));
       const remove = document.createElement('button');
       remove.type = 'button';
       remove.className = 'animation-set-remove';
       remove.setAttribute('aria-label', `Remove ${name} from animation set`);
       remove.textContent = '×';
       remove.addEventListener('click', () => {
         state.animationSet = state.animationSet.filter((itemName) => itemName !== name);
         render();
       });
       item.appendChild(remove);
       animationSet.appendChild(item);
     });
     animationSetCount.textContent = `${state.animationSet.length} icon${state.animationSet.length === 1 ? '' : 's'}`;
     animationSetHint.textContent = state.animationSet.length < 2 ? 'Choose two or more icons to make a sequence.' : 'Stage advance cycles current → next through this set.';
     if (downloadSelectedIconsBtn) downloadSelectedIconsBtn.disabled = state.animationSet.length === 0;
     // focusRef: ref just added via the browser — the stage morphs onto it
     const fi = typeof focusRef === 'string' ? state.animationSet.indexOf(focusRef) : -1;
     pg.setAnimationSet(state.animationSet, fi >= 0 ? fi : undefined);
   }

  function filteredEntries() {
    return entries.filter((entry) => {
      if (state.filter !== 'all' && entry.lib !== state.filter) return false;
      if (state.query && !entry.name.includes(state.query) && entry.lib !== state.query) return false;
      return true;
    });
  }

  function buildItemButton(entry) {
    const button = document.createElement('button');
    button.type = 'button';
    button.dataset.ref = entry.ref;
    button.className = `lucide-item${state.animationSet.includes(entry.ref) ? ' is-selected' : ''}`;
    button.setAttribute('role', 'option');
    button.setAttribute('aria-label', `Select ${LIBRARIES[entry.lib].label} icon ${entry.name}`);
    button.setAttribute('aria-selected', String(state.animationSet.includes(entry.ref)));
    button.title = `${LIBRARIES[entry.lib].label}: ${entry.name}`;
    button.appendChild(svgFromD(entry.d, 'currentColor', pg.stroke));
    const label = document.createElement('span');
    label.textContent = entry.name;
    button.appendChild(label);
    const libTag = document.createElement('span');
    libTag.className = 'lucide-item-lib';
    libTag.textContent = LIBRARIES[entry.lib].label;
    button.appendChild(libTag);
    // read selection state at click time (never a stale closure)
    button.addEventListener('click', () => {
      const wasSelected = state.animationSet.includes(entry.ref);
      state.selected = entry.ref;
      state.animationSet = wasSelected
        ? state.animationSet.filter((item) => item !== entry.ref)
        : [...state.animationSet, entry.ref];
      selected.textContent = wasSelected
        ? `Removed ${entry.ref}`
        : `Added ${entry.ref} · ${state.animationSet.length} in set`;
      // update just this button's selection state — no grid rebuild
      const on = !wasSelected;
      button.classList.toggle('is-selected', on);
      button.setAttribute('aria-selected', String(on));
      // adding an icon retargets the stage at it (smooth morph, no reset to
      // index 0); removing just updates the set and keeps cycling in place
      renderAnimationSet(on ? entry.ref : undefined);
    });
    return button;
  }

  // Full rebuild — only on search/filter/selection-affecting changes.
  function render() {
    const matches = filteredEntries();
    const visible = matches.slice(0, state.limit);
    const fragment = document.createDocumentFragment();
    visible.forEach((entry) => fragment.appendChild(buildItemButton(entry)));
    results.replaceChildren(fragment);
    renderAnimationSet();
    count.textContent = `${matches.length} icons`;
    allVisible = visible.length >= matches.length;
  }

  // Append-only — used by infinite scroll. Never touches existing DOM,
  // the animation set, or the left-side solver state.
  function appendNextBatch() {
    const matches = filteredEntries();
    const next = matches.slice(state.limit, state.limit + 36);
    if (!next.length) { allVisible = true; return; }
    state.limit += 36;
    const fragment = document.createDocumentFragment();
    next.forEach((entry) => fragment.appendChild(buildItemButton(entry)));
    results.appendChild(fragment);
    allVisible = state.limit >= matches.length;
  }

  search.addEventListener('input', () => {
    state.query = search.value.trim().toLowerCase();
    state.limit = 36;
    render();
  });
  filters.forEach((button) => {
    button.addEventListener('click', () => {
      state.filter = button.dataset.lucideFilter;
      state.limit = 36;
      filters.forEach((item) => {
        const active = item === button;
        item.classList.toggle('is-active', active);
        item.setAttribute('aria-pressed', String(active));
      });
      render();
    });
  });

  // --- infinite scroll: auto-load when user scrolls near bottom ---
  let scrollRaf = null;
  let lucideIO = null;
  let lucideSentinel = null;

  function ensureSentinel() {
    if (lucideSentinel && lucideIO) {
      try { lucideIO.unobserve(lucideSentinel); } catch {}
    }
    if (allVisible) {
      if (lucideSentinel) { lucideSentinel.remove(); lucideSentinel = null; }
      return;
    }
    // create sentinel at end of results for IntersectionObserver
    lucideSentinel = document.createElement('div');
    lucideSentinel.className = 'lucide-sentinel';
    lucideSentinel.setAttribute('aria-hidden', 'true');
    lucideSentinel.style.cssText = 'height:1px;width:100%;pointer-events:none;';
    results.appendChild(lucideSentinel);
    if (!lucideIO && 'IntersectionObserver' in window) {
      lucideIO = new IntersectionObserver((entries) => {
        if (!entries[0].isIntersecting) return;
        if (allVisible) return;
        // throttle via rAF to avoid double-fire with scroll handler
        if (scrollRaf) return;
        scrollRaf = requestAnimationFrame(() => {
          scrollRaf = null;
          if (allVisible) return;
          if (lucideSentinel) lucideSentinel.remove();
          appendNextBatch();
          ensureSentinel();
        });
      }, { root: results, rootMargin: '120px', threshold: 0 });
    }
    if (lucideIO && lucideSentinel) lucideIO.observe(lucideSentinel);
  }

  // Scroll fallback (for browsers without IO or for fast scroll)
  results.addEventListener('scroll', () => {
    if (scrollRaf) return;
    scrollRaf = requestAnimationFrame(() => {
      scrollRaf = null;
      if (allVisible) return;
      const threshold = 96;
      const nearBottom = results.scrollTop + results.clientHeight >= results.scrollHeight - threshold;
      if (nearBottom) {
        if (lucideSentinel) lucideSentinel.remove();
        appendNextBatch();
        ensureSentinel();
      }
    });
  }, { passive: true });

  // patch render to re-attach sentinel after each full render (search/filter only)
  const _origRender = render;
  render = function() {
    // unobserve previous sentinel before clearing results
    if (lucideSentinel && lucideIO) {
      try { lucideIO.unobserve(lucideSentinel); } catch {}
      lucideSentinel = null;
    }
    _origRender();
    ensureSentinel();
  };

  if (downloadSelectedIconsBtn) {
    downloadSelectedIconsBtn.addEventListener('click', downloadSelectedIconsDart);
    // ensure initial disabled state
    downloadSelectedIconsBtn.disabled = state.animationSet.length === 0;
  }
  render();
  // expose for tests
  window._lucideInfinite = {
    get limit() { return state.limit; },
    get resultsEl() { return results; },
    loadMore() { state.limit += 36; render(); }
  };
  window._lucideDownload = {
    get button() { return downloadSelectedIconsBtn; },
    toDartIdentifier,
    escapeDartString,
    buildSelectedIconsDart,
    downloadSelectedIconsDart,
    get selected() { return [...state.animationSet]; }
  };
})();

/* ============================================================
   DART CODE TABS — examples use the public Flutter and core APIs.
   ============================================================ */
(() => {
  const code = document.getElementById('dartCode');
  const copy = document.getElementById('copyCode');
  const tabs = document.querySelectorAll('[data-code-tab]');
  if (!code || !copy || !tabs.length) return;

  const snippets = {
    uncontrolled: `import 'package:flutter/material.dart';
import 'package:morphicons_flutter/morphicons_flutter.dart';
import 'package:morphicons_lucide/morphicons_lucide.dart';

MorphIcon(
  icon: isOpen ? MorphIconsLucide.x : MorphIconsLucide.menu,
  spring: SpringPreset.snappy,
)`,
    controlled: `MorphIcon.controlled(
  from: MorphIconsLucide.menu,
  icon: MorphIconsLucide.x,
  progress: dragProgress,
  size: 28,
)`,
    imperative: `final iconKey = GlobalKey<MorphIconState>();

MorphIcon(
  key: iconKey,
  icon: MorphIconsLucide.menu,
)

iconKey.currentState?.morphTo(MorphIconsLucide.check);
iconKey.currentState?.set(MorphIconsLucide.menu);`,
    core: `import 'package:morphicons_core/morphicons_core.dart';

final plan = planBetween(menuD, xD);
final output = allocOutputs(plan);
interpPolar(plan, 0.5, output);
final d = serialize(output, plan.items.map((item) => item.closed).toList());`,
  };

  function selectTab(name) {
    tabs.forEach((tab) => {
      const active = tab.dataset.codeTab === name;
      tab.classList.toggle('is-active', active);
      tab.setAttribute('aria-selected', String(active));
    });
    code.textContent = snippets[name];
  }

  async function copyCode() {
    try {
      if (navigator.clipboard) await navigator.clipboard.writeText(code.textContent);
      else throw new Error('clipboard unavailable');
      copy.textContent = 'Copied';
    } catch {
      const field = document.createElement('textarea');
      field.value = code.textContent;
      field.setAttribute('readonly', '');
      field.style.position = 'fixed';
      field.style.opacity = '0';
      document.body.appendChild(field);
      field.select();
      document.execCommand('copy');
      field.remove();
      copy.textContent = 'Copied';
    }
    window.setTimeout(() => { copy.textContent = 'Copy'; }, 1200);
  }

  tabs.forEach((tab) => tab.addEventListener('click', () => selectTab(tab.dataset.codeTab)));
  copy.addEventListener('click', copyCode);
  selectTab('uncontrolled');
})();

/* ============================================================
   COMPATIBILITY STRIP — static render of varied d strings
   ============================================================ */
(() => {
  const strip = document.getElementById('compatStrip');
  if (!strip) return;
  const icons = [
    'M12 2A10 10 0 1 0 12 22A10 10 0 1 0 12 2Z',                       // circle
    'M5 5L19 5L19 19L5 19Z',                                           // square
    'M12 3L21 20L3 20Z',                                               // triangle
    'M12 2L15 9L22 9L16.5 14L18.5 21L12 17L5.5 21L7.5 14L2 9L9 9Z',    // star
    'M12 21C7 16 3 12.5 3 8.5A4.5 4.5 0 0 1 12 5.5A4.5 4.5 0 0 1 21 8.5C21 12.5 17 16 12 21Z', // heart
    'M13 2L4 14L11 14L10 22L20 9L13 9Z',                               // bolt
    'M3 12A9 9 0 1 0 12 3M12 7L12 12L15 15',                           // clock-ish
    'M7 5L19 12L7 19Z',                                                // play
    'M5 12L19 12M12 5L12 19',                                          // plus
    'M4 6L20 6M4 12L20 12M4 18L20 18',                                 // menu
    'M18 6L6 18M6 6L18 18',                                            // x
    'M20 6L9 17L4 12',                                                 // check
  ];
  icons.forEach((d) => {
    const cell = document.createElement('div');
    cell.className = 'strip-cell';
    cell.appendChild(svgFromD(d));
    strip.appendChild(cell);
  });
})();

/* ============================================================
   SCROLL REVEALS — IntersectionObserver only
   ============================================================ */
(() => {
  const els = document.querySelectorAll('.reveal');
  const io = new IntersectionObserver((entries) => {
    for (const e of entries) {
      if (e.isIntersecting) {
        e.target.classList.add('is-visible');
        io.unobserve(e.target);
      }
    }
  }, { threshold: 0.12, rootMargin: '0px 0px -40px 0px' });
  els.forEach((el, i) => {
    el.style.setProperty('--index', String(i % 6));
    io.observe(el);
  });
})();

/* ============================================================
   FRAME TABS — single sub-website interface (no scroll labels)
   ============================================================ */
(() => {
  const tabs = document.querySelectorAll('.frame-tab');
  const panels = document.querySelectorAll('.frame-panel');
  if (!tabs.length || !panels.length) return;
  function activate(name) {
    tabs.forEach((t) => {
      const on = t.dataset.frameTab === name;
      t.classList.toggle('is-active', on);
      t.setAttribute('aria-selected', String(on));
    });
    panels.forEach((p) => {
      const on = p.dataset.panel === name;
      p.classList.toggle('is-active', on);
      p.hidden = !on;
    });
    // keep URL in sync without scrolling
    try { history.replaceState(null, '', '#'+name); } catch {}
  }
  tabs.forEach((btn) => btn.addEventListener('click', () => activate(btn.dataset.frameTab)));
  // nav links that point to frame tabs (e.g. Converter in header)
  document.querySelectorAll('[data-frame-tab-link]').forEach((link) => {
    link.addEventListener('click', (e) => {
      e.preventDefault();
      const name = link.dataset.frameTabLink;
      document.getElementById('playground')?.scrollIntoView({ behavior: 'smooth', block: 'start' });
      activate(name);
    });
  });
  // converter browse button → file input
  const convBrowse = document.getElementById('convBrowse');
  const convFile = document.getElementById('convFile');
  if (convBrowse && convFile) convBrowse.addEventListener('click', () => convFile.click());
  // allow deep link #converter etc
  const hash = (location.hash || '').replace('#','');
  if (hash && document.querySelector(`.frame-tab[data-frame-tab="${hash}"]`)) activate(hash);
  // also support #converter hash via nav
  if (location.hash === '#converter') activate('converter');
  // expose for nav testing
  window._frameActivate = activate;
})();

/* ============================================================
   ICONDATA — Flutter IconData live (filled · same solver)
   ============================================================ */
(() => {
  const canvas = document.getElementById('iconDataCanvas');
  if (!canvas || !window.MorphCore) return;

  const M = window.MorphCore;
  const fromCanvas = document.getElementById('iconDataFromCanvas');
  const toCanvas = document.getElementById('iconDataToCanvas');
  const title = document.getElementById('iconDataTitle');
  const meta = document.getElementById('iconDataMeta');
  const playBtn = document.getElementById('iconDataPlay');
  const replayBtn = document.getElementById('iconDataReplay');
  const iconDataPlayMorph = createMorphButton(playBtn, BTN_PLAY_D, BTN_PAUSE_D);
  const slowBox = document.getElementById('iconDataSlow');
  const curveCanvas = document.getElementById('iconDataCurve');

  // Curated Material d — 24×24, same strings as lib/src/icon_data_resolver.dart
  const MATERIAL = {
    home: 'M12 5.69l5 4.5V18h-2v-6H9v6H7v-7.81l5-4.5M12 3L2 12h3v8h6v-6h2v6h6v-8h3L12 3z',
    favorite: 'M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z',
    star: 'M12 17.27L18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z',
    search: 'M15.5 14h-.79l-.28-.27C15.41 12.59 16 11.11 16 9.5 16 5.91 13.09 3 9.5 3S3 5.91 3 9.5 5.91 16 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z',
    settings: 'M19.14 12.94c.04-.3.06-.61.06-.94 0-.32-.02-.64-.07-.94l2.03-1.58c.18-.14.23-.41.12-.61l-1.92-3.32c-.12-.22-.37-.29-.59-.22l-2.39.96c-.5-.38-1.03-.7-1.62-.94L14.4 2.81c-.04-.24-.24-.41-.48-.41h-3.84c-.24 0-.43.17-.47.41L9.25 5.35C8.66 5.59 8.12 5.92 7.63 6.29L5.24 5.33c-.22-.08-.47 0-.59.22L2.74 8.87C2.62 9.08 2.66 9.34 2.86 9.48l2.03 1.58C4.84 11.36 4.8 11.69 4.8 12s0.02.64.07.94l-2.03 1.58c-.18.14-.23.41-.12.61l1.92 3.32c.12.22.37.29.59.22l2.39-.96c.5.38 1.03.7 1.62.94l0.36 2.54c.05.24.24.41.48.41h3.84c.24 0 .44-.17.47-.41l0.36-2.54c.59-.24 1.13-.56 1.62-.94l2.39.96c.22.08.47 0 .59-.22l1.92-3.32c.12-.22.07-.47-.12-.61L19.14 12.94zM12 15.6c-1.98 0-3.6-1.62-3.6-3.6s1.62-3.6 3.6-3.6 3.6 1.62 3.6 3.6-1.98 3.6-3.6 3.6z',
    menu: 'M3 18h18v-2H3v2zm0-5h18v-2H3v2zm0-7v2h18V6H3z',
    close: 'M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z',
    lucideX: 'M18 6L6 18M6 6L18 18',
  };

  const PAIRS = [
    { id: 'home-favorite', label: 'home → favorite', title: 'home → favorite · filled', from: MATERIAL.home, to: MATERIAL.favorite, filled: true },
    { id: 'star-home', label: 'star → home', title: 'star → home · filled', from: MATERIAL.star, to: MATERIAL.home, filled: true },
    { id: 'search-star', label: 'search → star', title: 'search → star · filled', from: MATERIAL.search, to: MATERIAL.star, filled: true },
    { id: 'menu-close', label: 'menu → close', title: 'menu → close · filled', from: MATERIAL.menu, to: MATERIAL.close, filled: true },
    { id: 'settings-home', label: 'settings → home', title: 'settings → home · filled', from: MATERIAL.settings, to: MATERIAL.home, filled: true },
    { id: 'home-lucide-x', label: 'home ↔ lucide x (mixed)', title: 'home (IconData) ↔ lucide x (String) · mixed', from: MATERIAL.home, to: MATERIAL.lucideX, filled: false },
  ];

  // Helpers: fitCanvas/draw already defined earlier via closure? Reuse outer scope functions
  // but define local filled-aware draw to avoid polluting global.
  function localFit(canvasEl) {
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const rect = canvasEl.getBoundingClientRect();
    if (rect.width === 0) return null;
    const w = Math.round(rect.width * dpr);
    const h = Math.round(rect.height * dpr);
    if (canvasEl.width !== w || canvasEl.height !== h) { canvasEl.width = w; canvasEl.height = h; }
    const ctx = canvasEl.getContext('2d');
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    return { ctx, w, h, dpr };
  }
  function drawFilled(ctx, w, h, subs, color) {
    ctx.clearRect(0, 0, w, h);
    const pad = 0.10;
    const s = (Math.min(w, h) / 24) * (1 - 2 * pad);
    const ox = (w - 24 * s) / 2;
    const oy = (h - 24 * s) / 2;
    ctx.fillStyle = color;
    for (const pts of subs) {
      if (typeof pts === 'string') continue;
      const n = pts.length / 2;
      if (n < 2) continue;
      ctx.beginPath();
      ctx.moveTo(ox + pts[0] * s, oy + pts[1] * s);
      for (let i = 1; i < n; i++) ctx.lineTo(ox + pts[2 * i] * s, oy + pts[2 * i + 1] * s);
      ctx.closePath();
      ctx.fill();
    }
  }
  function drawStroked(ctx, w, h, subs, color, lineW) {
    ctx.clearRect(0, 0, w, h);
    const pad = 0.10;
    const s = (Math.min(w, h) / 24) * (1 - 2 * pad);
    const ox = (w - 24 * s) / 2;
    const oy = (h - 24 * s) / 2;
    ctx.strokeStyle = color;
    ctx.lineWidth = lineW;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    for (const pts of subs) {
      if (typeof pts === 'string') continue;
      const n = pts.length / 2;
      if (n < 2) continue;
      ctx.beginPath();
      ctx.moveTo(ox + pts[0] * s, oy + pts[1] * s);
      for (let i = 1; i < n; i++) ctx.lineTo(ox + pts[2 * i] * s, oy + pts[2 * i + 1] * s);
      ctx.stroke();
    }
  }
  function drawStatic(canvasEl, d, filled) {
    const fit = localFit(canvasEl);
    if (!fit) return;
    try {
      const plan = M.buildPlan(M.resampleIcon(d), M.resampleIcon(d));
      const out = M.allocOutputs(plan);
      M.interpPolar(plan, 1, out);
      if (filled) drawFilled(fit.ctx, fit.w, fit.h, out, '#7d7d7d');
      else drawStroked(fit.ctx, fit.w, fit.h, out, '#7d7d7d', 1.6 * (fit.w / 84) * 0.9);
    } catch {}
  }

  let pairIdx = 0;
  let plan = null, out = null;
  const spring = new M.Spring();
  let slow = false;
  let playing = true;
  let t = 0;
  let rafId = null;
  let visible = true;

  function currentPair() { return PAIRS[pairIdx]; }

  function rebuild(pair) {
    const t0 = performance.now();
    plan = M.buildPlan(M.resampleIcon(pair.from), M.resampleIcon(pair.to));
    out = M.allocOutputs(plan);
    const st = (() => {
      const it = plan.items[0];
      const sigma = it.sigma !== undefined ? it.sigma : Math.exp(it.lnSigma);
      const blockHybrid = plan.items.every((x) => x.block != null) && plan.items.every((x) => Math.abs(x.theta - it.theta) < 1e-12);
      return { theta: it.theta, sigma, res: it.res, blockHybrid };
    })();
    const ms = performance.now() - t0;
    if (title) title.textContent = pair.title;
    if (meta) meta.textContent = `${st.theta.toFixed(3)} rad · σ ${st.sigma.toFixed(3)} · ${ms.toFixed(1)} ms${st.blockHybrid ? ' · block' : ''}`;
    drawStatic(fromCanvas, pair.from, pair.filled);
    drawStatic(toCanvas, pair.to, pair.filled);
    // curve
    const cc = document.getElementById('iconDataCurve');
    if (cc) {
      const k = slow ? 90 : 170, c = slow ? 20 : 26;
      const fit = localFit(cc);
      if (fit) {
        const { ctx, w, h } = fit;
        ctx.clearRect(0, 0, w, h);
        const s2 = new M.Spring(); s2.config(k, c); s2.start();
        const xs = [];
        while (!s2.step(1/60) && xs.length < 600) xs.push(s2.x);
        xs.push(1);
        const maxT = xs.length / 60;
        const px = (tt) => (tt / maxT) * (w - 8) + 4;
        const py = (x) => h - 10 - (x / 1.25) * (h - 24);
        ctx.strokeStyle = '#262626'; ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(0, py(1)); ctx.lineTo(w, py(1)); ctx.stroke();
        ctx.strokeStyle = '#ededed'; ctx.lineWidth = 1.6; ctx.beginPath();
        xs.forEach((x, i) => {
          const X = px(i/60), Y = py(x);
          if (i===0) ctx.moveTo(X,Y); else ctx.lineTo(X,Y);
        });
        ctx.stroke();
      }
    }
    spring.config(slow ? 90 : 170, slow ? 20 : 26);
    spring.start();
    playing = true;
    iconDataPlayMorph?.morphTo(BTN_PAUSE_D);
    t = 0;
    if (rafId == null) rafId = requestAnimationFrame(tick);
  }

  function render(tt) {
    const fit = localFit(canvas);
    if (!fit || !plan || !out) return;
    const pair = currentPair();
    M.interpPolar(plan, tt, out);
    if (pair.filled) drawFilled(fit.ctx, fit.w, fit.h, out, '#ededed');
    else drawStroked(fit.ctx, fit.w, fit.h, out, '#ededed', 2 * (fit.w / 320) * 0.9);
  }

  function tick() {
    rafId = null;
    const section = document.getElementById('icondata');
    let canAnimate = visible && !document.hidden && playing;
    if (section) {
      const r = section.getBoundingClientRect();
      if (r.bottom < 0 || r.top > window.innerHeight) canAnimate = false;
    }
    if (canAnimate) {
      const dt = slow ? 1/120 : 1/60;
      const settled = spring.step(dt);
      t = Math.min(spring.x, 1);
      render(Math.min(t, 1));
      if (settled) {
        playing = false;
        render(1);
        iconDataPlayMorph?.morphTo(BTN_PLAY_D);
        // auto-advance after hold when visible
        setTimeout(() => {
          if (visible && !document.hidden && !playing) {
            pairIdx = (pairIdx + 1) % PAIRS.length;
            syncPills();
            rebuild(currentPair());
          }
        }, slow ? 900 : 600);
      }
    }
    rafId = requestAnimationFrame(tick);
  }

  function syncPills() {
    document.querySelectorAll('[data-icondata-pair]').forEach((b) => {
      const on = b.dataset.icondataPair === currentPair().id;
      b.classList.toggle('is-active', on);
      b.setAttribute('aria-pressed', String(on));
    });
  }

  document.querySelectorAll('[data-icondata-pair]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const id = btn.dataset.icondataPair;
      const idx = PAIRS.findIndex((p) => p.id === id);
      if (idx >= 0) {
        pairIdx = idx;
        syncPills();
        rebuild(currentPair());
      }
    });
  });

  if (playBtn) playBtn.addEventListener('click', () => {
    playing = !playing;
    iconDataPlayMorph?.morphTo(playing ? BTN_PAUSE_D : BTN_PLAY_D);
    if (playing) {
      // if at end, restart
      if (t >= 1) { rebuild(currentPair()); }
      if (rafId == null) rafId = requestAnimationFrame(tick);
    }
  });
  if (replayBtn) replayBtn.addEventListener('click', () => rebuild(currentPair()));
  if (slowBox) slowBox.addEventListener('change', () => {
    slow = slowBox.checked;
    rebuild(currentPair());
  });

  const copyBtn = document.getElementById('copyIconDataCode');
  if (copyBtn) {
    copyBtn.addEventListener('click', async () => {
      const target = document.getElementById('iconDataCode');
      if (!target) return;
      const text = target.textContent;
      try {
        if (navigator.clipboard) await navigator.clipboard.writeText(text);
        const orig = copyBtn.textContent; copyBtn.textContent = 'Copied'; copyBtn.classList.add('is-copied');
        setTimeout(() => { copyBtn.textContent = orig; copyBtn.classList.remove('is-copied'); }, 1400);
      } catch {}
    });
  }

  // Visibility observer
  const sec = document.getElementById('icondata');
  if ('IntersectionObserver' in window && sec) {
    const io = new IntersectionObserver((entries) => {
      visible = entries[0].isIntersecting && !document.hidden;
      if (visible && rafId == null) rafId = requestAnimationFrame(tick);
    }, { threshold: 0.12 });
    io.observe(sec);
  }
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) visible = false;
    else if (sec) {
      const r = sec.getBoundingClientRect();
      visible = r.bottom > 0 && r.top < window.innerHeight;
    }
    if (visible && rafId == null) rafId = requestAnimationFrame(tick);
  });
  window.addEventListener('resize', () => render(Math.min(t,1)));

  // Initial
  rebuild(currentPair());
  rafId = requestAnimationFrame(tick);
  // expose for tests
  window._iconDataDemo = {
    get pair() { return currentPair().id; },
    setPair(id) {
      const idx = PAIRS.findIndex((p) => p.id === id);
      if (idx >= 0) { pairIdx = idx; syncPills(); rebuild(currentPair()); }
    },
    get playing() { return playing; },
    get visible() { return visible; },
  };
})();

/* Copy buttons for code panels (shadcn style — square 6px, dark theme) */
(() => {
  document.querySelectorAll('[data-copy-target]').forEach((button) => {
    button.addEventListener('click', async () => {
      const target = document.getElementById(button.dataset.copyTarget);
      if (!target) return;
      const text = target.textContent;
      const onSuccess = () => {
        const orig = button.textContent;
        button.textContent = 'Copied';
        button.classList.add('is-copied');
        setTimeout(() => {
          button.textContent = orig;
          button.classList.remove('is-copied');
        }, 1400);
      };
      const onFail = () => {
        const orig = button.textContent;
        button.textContent = 'Copy failed';
        setTimeout(() => { button.textContent = orig; }, 1400);
      };
      try {
        if (navigator.clipboard && navigator.clipboard.writeText) {
          await navigator.clipboard.writeText(text);
          onSuccess();
          return;
        }
        throw new Error('clipboard unavailable');
      } catch {
        try {
          const ta = document.createElement('textarea');
          ta.value = text;
          ta.setAttribute('readonly', '');
          ta.style.position = 'fixed';
          ta.style.opacity = '0';
          document.body.appendChild(ta);
          ta.select();
          const ok = document.execCommand('copy');
          ta.remove();
          if (ok) onSuccess(); else onFail();
        } catch {
          onFail();
        }
      }
    });
  });
  // Minimal install chip — mirrors reference InstallCommand.
  const copyInstall = document.getElementById('copyInstall');
  if (copyInstall) {
    copyInstall.addEventListener('click', async () => {
      const text = 'flutter pub add morphicons_flutter';
      const orig = copyInstall.textContent;
      try {
        if (navigator.clipboard && navigator.clipboard.writeText) await navigator.clipboard.writeText(text);
        else throw new Error('no clipboard');
        copyInstall.textContent = 'Copied';
        copyInstall.classList.add('is-copied');
        setTimeout(() => { copyInstall.textContent = orig; copyInstall.classList.remove('is-copied'); }, 1400);
      } catch {
        copyInstall.textContent = 'Copy failed';
        setTimeout(() => { copyInstall.textContent = orig; }, 1400);
      }
    });
  }
})();
