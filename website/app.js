/* ============================================================
   Morphicons playground — drives the real solver (MorphCore)
   ============================================================ */

const M = window.MorphCore;
const LUCIDE = window.LucideCatalog || {};

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

function iconData(name, fallback) {
  return LUCIDE[name] || fallback;
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

function drawSubs(ctx, w, h, subs, color, lineWidthPx) {
  ctx.clearRect(0, 0, w, h);
  const pad = 0.10;
  const s = (Math.min(w, h) / 24) * (1 - 2 * pad);
  const ox = (w - 24 * s) / 2;
  const oy = (h - 24 * s) / 2;
  ctx.strokeStyle = color;
  ctx.lineWidth = lineWidthPx;
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

function svgFromD(d, stroke, strokeWidth) {
  const NS = 'http://www.w3.org/2000/svg';
  const svg = document.createElementNS(NS, 'svg');
  svg.setAttribute('viewBox', '0 0 24 24');
  svg.setAttribute('fill', 'none');
  svg.setAttribute('stroke', stroke || '#ededed');
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
      drawSubs(fit.ctx, fit.w, fit.h, soloOut, '#7d7d7d', 1.6 * (fit.w / 112) * 0.9);
    } catch {}
  }

  function loadPair(i) {
    const p = PAIRS[i];
    const t0 = performance.now();
    plan = M.buildPlan(M.resampleIcon(p.from), M.resampleIcon(p.to));
    out = M.allocOutputs(plan);
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
        drawSubs(ctx, w, h, out, '#ededed', 2 * (w / 240) * 0.9);
      } else if (phase === 'morph') {
        const dt = slow ? 1/120 : 1/60; // slow motion halves speed
        const settled = spring.step(dt);
        M.interpPolar(plan, Math.min(spring.x, 1), out);
        drawSubs(ctx, w, h, out, '#ededed', 2 * (w / 240) * 0.9);
        if (settled) { phase = 'hold'; holdUntil = performance.now() + (slow ? 2200 : 1400); }
      } else if (phase === 'hold') {
        M.interpPolar(plan, 1, out);
        drawSubs(ctx, w, h, out, '#ededed', 2 * (w / 240) * 0.9);
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
     b.appendChild(svgFromD(p.to, '#ededed', state.stroke));
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
       return { label: `${from} → ${to}`, from: iconData(from, ''), to: iconData(to, '') };
     }
     return PAIRS[state.pair];
   }

   function rebuildPlan() {
     const p = currentPair();
     if (!p.from || !p.to) return;
    title.textContent = p.label;
    pairSource.textContent = `from ${p.from}  →  to ${p.to}`;
    const t0 = performance.now();
    state.plan = M.buildPlan(M.resampleIcon(p.from), M.resampleIcon(p.to));
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
      playBtn.textContent = 'Play';
      playBtn.setAttribute('aria-pressed', 'false');
      render(1);
      return;
    }
    state.mode = 'playing';
    state.t = 0;
    playBtn.textContent = 'Pause';
    playBtn.setAttribute('aria-pressed', 'true');
  }

  function render(t) {
    const fit = fitCanvas(canvas);
    if (fit && state.plan) {
      M.interpPolar(state.plan, t, state.out);
       drawSubs(fit.ctx, fit.w, fit.h, state.out, '#ededed', state.stroke * (fit.w / 320) * 0.9);
    }
    if (!cmpWrap.hidden) {
      const fit2 = fitCanvas(cmpCanvas);
      if (fit2 && state.plan) {
        const outL = M.allocOutputs(state.plan);
        M.interpLinear(state.plan, t, outL);
         drawSubs(fit2.ctx, fit2.w, fit2.h, outL, '#9F2F2D', state.stroke * (fit2.w / 320) * 0.9);
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
          playBtn.textContent = 'Play';
          playBtn.setAttribute('aria-pressed', 'false');
          // Only auto-advance the staged set while visible — otherwise pause.
          if (state.animationSet.length >= 2 && canAnimate) {
            state.animationIndex = (state.animationIndex + 1) % state.animationSet.length;
            rebuildPlan();
            restart();
          }
       }
    }
    requestAnimationFrame(tick);
  }

  /* ----- controls ----- */
  playBtn.addEventListener('click', () => {
    if (state.mode === 'playing') {
      state.mode = 'idle';
      playBtn.textContent = 'Play';
      playBtn.setAttribute('aria-pressed', 'false');
      return;
    }
    if (state.t >= 1 || state.t === 0) restart();
    else {
      state.mode = 'playing';
      playBtn.textContent = 'Pause';
      playBtn.setAttribute('aria-pressed', 'true');
    }
  });
  replayBtn.addEventListener('click', restart);

  tSlider.addEventListener('input', () => {
    state.mode = 'scrub';
    playBtn.textContent = 'Play';
    playBtn.setAttribute('aria-pressed', 'false');
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

   // Slow motion + from→to preview (minimal, matches hero)
   const slowToggle = document.getElementById('pgSlow');
   const fromToWrap = document.getElementById('pgFromTo');
   const fromCanvas = document.getElementById('pgFromCanvas');
   const toCanvas = document.getElementById('pgToCanvas');
   let slow = false;
   function drawStaticPG(canvasEl, d, color) {
     const fit = fitCanvas(canvasEl);
     if (!fit) return;
     try {
       const soloPlan = M.buildPlan(M.resampleIcon(d), M.resampleIcon(d));
       const soloOut = M.allocOutputs(soloPlan);
       M.interpPolar(soloPlan, 1, soloOut);
       drawSubs(fit.ctx, fit.w, fit.h, soloOut, color, 1.6 * (fit.w / 84) * 0.9);
     } catch {}
   }
   function drawFromToPG() {
     if (!slow || !fromCanvas || !toCanvas) return;
     const p = currentPair();
     drawStaticPG(fromCanvas, p.from, '#6b6b6b');
     drawStaticPG(toCanvas, p.to, '#6b6b6b');
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
   rebuildPlan = function() {
     origRebuild();
     drawFromToPG();
   };

   window.addEventListener('resize', () => { render(Math.min(state.t, 1)); if (slow) drawFromToPG(); });

    rebuildPlan();
   restart();
   requestAnimationFrame(tick);
   // expose for viewport test
   window._pgSlow = () => slow;
   state.setAnimationSet = (names) => {
     state.animationSet = Array.isArray(names) ? names.filter((name) => typeof name === 'string' && LUCIDE[name]) : [];
     state.animationIndex = 0;
     rebuildPlan();
     restart();
   };
   return state;
})();

/* ============================================================
   LUCIDE BROWSER — search the generated catalog without mounting
   every icon into the document at once.
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
  const more = document.getElementById('lucideMore');
  const filters = document.querySelectorAll('[data-lucide-filter]');
  const names = Object.keys(LUCIDE).sort((a, b) => a.localeCompare(b));
  const shapePattern = /circle|square|triangle|diamond|hexagon|octagon|pentagon|star|heart|badge|box|disc|dot|shapes?/;
   const state = { filter: 'all', query: '', limit: 36, selected: '', animationSet: [] };

   window.setLucideAnimationSet = (names) => {
     state.animationSet = Array.isArray(names) ? names.filter((name) => LUCIDE[name]) : [];
     render();
   };

   function renderAnimationSet() {
     animationSet.replaceChildren();
     state.animationSet.forEach((name, index) => {
       const item = document.createElement('div');
       item.className = 'animation-set-item';
       item.setAttribute('role', 'listitem');
       item.title = `${index + 1}. ${name}`;
       item.appendChild(svgFromD(LUCIDE[name], '#ededed', pg.stroke));
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
     pg.setAnimationSet(state.animationSet);
   }

  function filteredNames() {
    return names.filter((name) => {
      if (state.query && !name.includes(state.query)) return false;
      if (state.filter === 'arrow' && !name.includes('arrow')) return false;
      if (state.filter === 'shape' && !shapePattern.test(name)) return false;
      return true;
    });
  }

  function render() {
    const matches = filteredNames();
    const visible = matches.slice(0, state.limit);
    const fragment = document.createDocumentFragment();
    results.replaceChildren();
    visible.forEach((name) => {
      const button = document.createElement('button');
       const isSelected = state.animationSet.includes(name);
      button.type = 'button';
      button.className = `lucide-item${isSelected ? ' is-selected' : ''}`;
      button.setAttribute('role', 'option');
      button.setAttribute('aria-label', `Select Lucide icon ${name}`);
       button.setAttribute('aria-selected', String(isSelected));
      button.title = `Lucide: ${name}`;
       button.appendChild(svgFromD(LUCIDE[name], '#ededed', pg.stroke));
      const label = document.createElement('span');
      label.textContent = name;
      button.appendChild(label);
      button.addEventListener('click', () => {
         state.selected = name;
         state.animationSet = isSelected ? state.animationSet.filter((item) => item !== name) : [...state.animationSet, name];
         selected.textContent = `${name} · ${LUCIDE[name]}`;
         render();
      });
      fragment.appendChild(button);
    });
    results.appendChild(fragment);
     renderAnimationSet();
    count.textContent = `${matches.length} icons`;
    more.hidden = visible.length >= matches.length;
    more.disabled = !matches.length;
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
  more.addEventListener('click', () => {
    state.limit += 36;
    render();
  });
  render();
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
