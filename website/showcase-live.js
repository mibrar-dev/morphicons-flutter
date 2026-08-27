/* showcase-live.js — 6 live MorphCore cards, like morphicons.com
   Copy→Check, Eye→EyeOff, Sun→Moon, Play↔Pause + Volume↔VolumeX, Check↔X, Folder↔FolderOpen
   - Real polar interpolation + Procrustes solver via MorphCore (6.5 kB core)
   - Interruptible: mid-flight re-plan from interpolated shape, velocity preserved (λ tie-break)
   - Spring presets + stroke live from left sidebar (showcase:control)
   - Cards are tappable (role=button, keyboard, cursor) — not just the icon
   - Reduced motion → instant canonical snap, no frames
   - Hi-DPI canvas, resize-aware, visibility-aware
*/
(() => {
  const M = window.MorphCore;
  const L = window.LucideCatalog;
  if (!M || !L) {
    console.warn('[showcase-live] MorphCore or LucideCatalog missing');
    return;
  }

  const SPRING_PRESETS = M.SPRING_PRESETS || { smooth:{k:170,c:26}, snappy:{k:420,c:30}, bouncy:{k:300,c:14} };
  let currentPreset = SPRING_PRESETS.smooth;
  let currentPresetKey = 'smooth';
  let currentStroke = 2;
  const liveMorphs = [];
  const rm = window.matchMedia('(prefers-reduced-motion: reduce)');

  function dOf(name, fallback) { return L[name] || fallback || null; }

  // Sidebar controls drive every morph (library/framework are visual adapters — stroke+spring are live)
  window.addEventListener('showcase:control', (e) => {
    const d = e.detail || {};
    if (d.control === 'spring' && SPRING_PRESETS[d.value]) {
      currentPresetKey = d.value;
      currentPreset = SPRING_PRESETS[d.value];
      liveMorphs.forEach(m => m && m.updateSpring && m.updateSpring(currentPreset));
    }
    if (d.control === 'stroke') {
      const v = parseFloat(d.value);
      if (!isNaN(v) && v >= 1 && v <= 2.5) {
        currentStroke = v;
        liveMorphs.forEach(m => m && m.updateStroke && m.updateStroke(v));
        liveMorphs.forEach(m => m && m.rerender && m.rerender());
      }
    }
    // library/framework -> no-op but keep selected state visual; we stay on Lucide geometry
  });

  function fitCanvas(canvas) {
    if (!canvas || !canvas.getBoundingClientRect) return null;
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const r = canvas.getBoundingClientRect();
    if (!r.width || !r.height) return null;
    const w = Math.round(r.width * dpr);
    const h = Math.round(r.height * dpr);
    if (canvas.width !== w || canvas.height !== h) { canvas.width = w; canvas.height = h; }
    const ctx = canvas.getContext('2d');
    if (!ctx) return null;
    ctx.setTransform(1,0,0,1,0,0);
    return { ctx, w, h, dpr };
  }

  function drawSubs(ctx, w, h, subs, color, lineWidthPx, closedFlags) {
    ctx.clearRect(0,0,w,h);
    const s = (Math.min(w,h)/24)*0.92;
    const ox = (w - 24*s)/2, oy = (h - 24*s)/2;
    ctx.strokeStyle = color; ctx.lineWidth = lineWidthPx; ctx.lineCap='round'; ctx.lineJoin='round';
    for (let k=0;k<subs.length;k++) {
      const pts = subs[k];
      if (typeof pts === 'string') continue;
      const n = pts.length/2; if (n<2) continue;
      ctx.beginPath();
      ctx.moveTo(ox + pts[0]*s, oy + pts[1]*s);
      for (let i=1;i<n;i++) ctx.lineTo(ox + pts[2*i]*s, oy + pts[2*i+1]*s);
      if (closedFlags && closedFlags[k]) ctx.closePath();
      ctx.stroke();
    }
  }

  function createMorph(canvas, fromD, toD, opts) {
    opts = opts || {};
    if (!canvas || !fromD || !toD) return null;
    let stroke = opts.stroke != null ? opts.stroke : currentStroke;
    const color = opts.color || '#ededed';
    const presetAtBirth = opts.presetKey ? (SPRING_PRESETS[opts.presetKey] || currentPreset) : currentPreset;

    let targetD = fromD; // currently settled target
    let plan = null, out = null;
    let playing = false, raf = null;
    let lastT = 0, curT = 0;
    const spring = new M.Spring();
    spring.config(presetAtBirth.k, presetAtBirth.c);

    try {
      plan = M.buildPlan(M.resampleIcon(fromD), M.resampleIcon(toD));
      out = M.allocOutputs(plan);
    } catch (err) {
      console.warn('[showcase-live] buildPlan failed', err);
      return null;
    }

    function render(tt) {
      lastT = tt;
      try { M.interpPolar(plan, tt, out); } catch(_e) {}
      const fit = fitCanvas(canvas);
      if (fit) {
        const closed = plan && plan.items ? plan.items.map(it=>!!it.closed) : null;
        drawSubs(fit.ctx, fit.w, fit.h, out, color, stroke*(fit.w/120)*0.9, closed);
      }
    }

    function morphTo(newTargetD) {
      if (!newTargetD || newTargetD === targetD && !playing) return;
      // reduced motion -> instant canonical
      if (rm.matches) {
        try {
          const solo = M.buildPlan(M.resampleIcon(newTargetD), M.resampleIcon(newTargetD));
          const soloOut = M.allocOutputs(solo);
          M.interpPolar(solo, 1, soloOut);
          plan = solo; out = soloOut; targetD = newTargetD; lastT = 1; curT = 1;
          const fit = fitCanvas(canvas);
          if (fit) {
            const closed = solo.items.map(it=>!!it.closed);
            drawSubs(fit.ctx, fit.w, fit.h, soloOut, color, stroke*(fit.w/120)*0.9, closed);
          }
        } catch(_e) {}
        return;
      }

      let newPlan = null, newOut = null;
      if (playing && out && plan) {
        // interrupt: snapshot current interpolated polyline as source (preserves position, velocity via spring)
        try {
          const synthetic = out.map((pts,i) => ({ pts: new Float64Array(pts), closed: !!plan.items[i].closed }));
          const targetResampled = M.resampleIcon(newTargetD);
          newPlan = M.buildPlan(synthetic, targetResampled);
          newOut = M.allocOutputs(newPlan);
        } catch(_e) {
          try {
            newPlan = M.buildPlan(M.resampleIcon(targetD), M.resampleIcon(newTargetD));
            newOut = M.allocOutputs(newPlan);
          } catch(e2) { console.warn('[showcase-live] morphTo fallback failed', e2); return; }
        }
      } else {
        try {
          newPlan = M.buildPlan(M.resampleIcon(targetD), M.resampleIcon(newTargetD));
          newOut = M.allocOutputs(newPlan);
        } catch(e) { console.warn('[showcase-live] morphTo build failed', e); return; }
      }
      plan = newPlan; out = newOut; targetD = newTargetD;
      spring.config(currentPreset.k, currentPreset.c);
      spring.start(); // x=0, v preserved clamp ±14
      curT = 0;
      if (!playing) { playing = true; tick(); }
    }

    function tick() {
      if (!playing) return;
      // throttle when tab hidden or completely offscreen? keep ticking but defer rAF if hidden to save CPU
      if (document.hidden) { raf = requestAnimationFrame(tick); return; }
      const settled = spring.step(1/60);
      curT = Math.min(Math.max(spring.x, 0), 1.2);
      const t = Math.min(curT, 1);
      render(t);
      if (settled) {
        playing = false; curT = 1; lastT = 1; render(1); raf = null;
      } else {
        raf = requestAnimationFrame(tick);
      }
    }

    function updateSpring(preset) { spring.config(preset.k, preset.c); }
    function updateStroke(v) { stroke = v; }
    function rerender() { render(lastT); }
    function destroy() { if (raf) cancelAnimationFrame(raf); playing=false; }

    render(0);

    const api = { canvas, morphTo, render, updateSpring, updateStroke, rerender, destroy, get playing(){return playing;}, get target(){return targetD;}, get plan(){return plan;} };
    liveMorphs.push(api);
    return api;
  }

  function makeCardTappable(card, handler) {
    if (!card || !handler) return;
    card.style.cursor = 'pointer';
    if (!card.hasAttribute('tabindex')) card.setAttribute('tabindex','0');
    if (!card.hasAttribute('role')) card.setAttribute('role','button');
    const onActivate = (e) => {
      // don't double-trigger when interacting with native controls inside
      const t = e.target;
      if (t && t.closest) {
        // if click originated from an input/textarea/select, ignore card tap (user is typing)
        if (t.closest('input, textarea, select')) return;
        // if target is a button and card handler is same as button, avoid double
        if (t.closest('button') && card.contains(t.closest('button'))) {
          // let button handler run; card tap would duplicate. For keyboard we still allow.
          if (e.type === 'click') return;
        }
      }
      handler(e);
    };
    card.addEventListener('click', onActivate);
    card.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); handler(e); }
    });
  }

  // --------------- 1. Copy → Check ---------------
  (() => {
    const canvas = document.getElementById('live-copy');
    const btn = document.getElementById('live-copy-btn');
    const card = canvas ? canvas.closest('.pattern-card') : null;
    if (!canvas) return;
    const copyD = dOf('copy'), checkD = dOf('check');
    if (!copyD || !checkD) return;
    const m = createMorph(canvas, copyD, checkD);
    if (!m) return;
    let copied = false;
    let revertTimer = null;

    function doCopy() {
      if (copied && revertTimer) return; // already showing check, wait for revert
      copied = true;
      m.morphTo(checkD);
      if (btn) { btn.textContent = 'Copied'; btn.setAttribute('aria-pressed','true'); }
      if (card) card.setAttribute('aria-pressed','true');
      // clipboard best-effort
      navigator.clipboard && navigator.clipboard.writeText('npm i morphicons').catch(()=>{});
      clearTimeout(revertTimer);
      revertTimer = setTimeout(() => {
        copied = false;
        m.morphTo(copyD);
        if (btn) { btn.textContent = 'Copy'; btn.setAttribute('aria-pressed','false'); }
        if (card) card.setAttribute('aria-pressed','false');
        revertTimer = null;
      }, 1600);
    }

    if (btn) {
      btn.addEventListener('click', (e) => { e.stopPropagation(); doCopy(); });
      btn.setAttribute('aria-pressed','false');
    }
    canvas.addEventListener('click', (e) => { e.stopPropagation(); doCopy(); });
    canvas.style.cursor = 'pointer';
    canvas.setAttribute('role','img');
    canvas.setAttribute('aria-label','Copy — tap to morph to check');
    if (card) {
      card.setAttribute('aria-label','Copy to clipboard — tap to show confirmation morph');
      makeCardTappable(card, doCopy);
    }
    // expose for tests/debug
    window._liveCopy = { morph: m, doCopy, get copied(){return copied;} };
  })();

  // --------------- 2. Password: Eye ↔ EyeOff ---------------
  (() => {
    const canvas = document.getElementById('live-eye');
    const input = document.getElementById('live-password-input');
    const btn = document.getElementById('live-eye-btn');
    const card = canvas ? canvas.closest('.pattern-card') : null;
    if (!canvas) return;
    const eyeD = dOf('eye'), eyeOffD = dOf('eye-off');
    if (!eyeD || !eyeOffD) return;
    const m = createMorph(canvas, eyeD, eyeOffD);
    if (!m) return;
    let visible = false;

    function toggle() {
      visible = !visible;
      if (input) input.type = visible ? 'text' : 'password';
      m.morphTo(visible ? eyeOffD : eyeD);
      if (btn) {
        btn.setAttribute('aria-pressed', String(visible));
        btn.setAttribute('aria-label', visible ? 'Hide password' : 'Show password');
      }
      if (card) card.setAttribute('aria-pressed', String(visible));
      canvas.setAttribute('aria-label', visible ? 'Eye off — tap to hide' : 'Eye — tap to show');
    }

    if (btn) btn.addEventListener('click', (e) => { e.stopPropagation(); toggle(); });
    canvas.addEventListener('click', (e) => { e.stopPropagation(); toggle(); });
    canvas.style.cursor = 'pointer';
    canvas.setAttribute('role','img');
    canvas.setAttribute('aria-label','Eye — tap to toggle visibility');
    if (input) input.setAttribute('aria-label','Password');
    if (card) {
      card.setAttribute('aria-label','Password visibility — tap to toggle eye morph');
      // card tap toggles, but ignore when focusing input
      makeCardTappable(card, (e) => {
        const ae = document.activeElement;
        if (ae === input) return;
        toggle();
      });
    }
    window._liveEye = { morph: m, toggle, get visible(){return visible;} };
  })();

  // --------------- 3. Theme: Sun ↔ Moon ---------------
  (() => {
    const canvas = document.getElementById('live-theme');
    const card = canvas ? canvas.closest('.pattern-card') : null;
    if (!canvas) return;
    const sunD = dOf('sun'), moonD = dOf('moon');
    if (!sunD || !moonD) return;
    const m = createMorph(canvas, sunD, moonD);
    if (!m) return;
    let dark = false;

    function toggle() {
      dark = !dark;
      m.morphTo(dark ? moonD : sunD);
      document.documentElement.style.colorScheme = dark ? 'dark' : 'light';
      if (card) card.setAttribute('aria-pressed', String(dark));
      canvas.setAttribute('aria-label', dark ? 'Moon — tap for sun' : 'Sun — tap for moon');
      // subtle: add data-theme for CSS hooks if present
      document.documentElement.setAttribute('data-theme', dark ? 'dark' : 'light');
    }

    canvas.addEventListener('click', (e) => { e.stopPropagation(); toggle(); });
    canvas.style.cursor = 'pointer';
    canvas.setAttribute('role','img');
    canvas.setAttribute('tabindex','0');
    canvas.setAttribute('aria-label','Sun — tap to toggle theme');
    canvas.addEventListener('keydown', (e) => { if (e.key==='Enter'||e.key===' ') { e.preventDefault(); toggle(); } });
    if (card) {
      card.setAttribute('aria-label','Theme toggle — tap to morph sun and moon');
      makeCardTappable(card, toggle);
    }
    window._liveTheme = { morph: m, toggle, get dark(){return dark;} };
  })();

  // --------------- 4. Player: Play↔Pause + Volume↔VolumeX ---------------
  (() => {
    const playCanvas = document.getElementById('live-play');
    const muteCanvas = document.getElementById('live-mute');
    const card = playCanvas ? playCanvas.closest('.pattern-card') : null;
    if (!playCanvas || !muteCanvas) return;
    const playD = dOf('play'), pauseD = dOf('pause');
    const volD = dOf('volume-2') || dOf('volume'), volX = dOf('volume-x');
    if (!playD || !pauseD || !volD || !volX) return;
    const mPlay = createMorph(playCanvas, playD, pauseD);
    const mMute = createMorph(muteCanvas, volD, volX);
    if (!mPlay || !mMute) return;
    let playing = false, muted = false;

    function togglePlay(e) {
      if (e) e.stopPropagation();
      playing = !playing;
      mPlay.morphTo(playing ? pauseD : playD);
      playCanvas.setAttribute('aria-label', playing ? 'Pause — tap to play' : 'Play — tap to pause');
      if (card) card.setAttribute('aria-pressed', String(playing));
    }
    function toggleMute(e) {
      if (e) e.stopPropagation();
      muted = !muted;
      mMute.morphTo(muted ? volX : volD);
      muteCanvas.setAttribute('aria-label', muted ? 'Unmute' : 'Mute');
      muteCanvas.setAttribute('aria-pressed', String(muted));
    }

    playCanvas.addEventListener('click', togglePlay);
    muteCanvas.addEventListener('click', toggleMute);
    [playCanvas, muteCanvas].forEach(c => {
      c.style.cursor='pointer';
      c.setAttribute('role','img');
      c.setAttribute('tabindex','0');
      c.addEventListener('keydown', (e) => {
        if (e.key==='Enter' || e.key===' ') { e.preventDefault(); (c===playCanvas?togglePlay:toggleMute)(e); }
      });
    });
    playCanvas.setAttribute('aria-label','Play — tap to pause');
    muteCanvas.setAttribute('aria-label','Volume — tap to mute');
    muteCanvas.setAttribute('aria-pressed','false');

    if (card) {
      card.setAttribute('aria-label','Player controls — tap to toggle play, tap speaker to mute');
      // card tap toggles play; mute is separate via its own canvas
      makeCardTappable(card, (e) => {
        // if mute canvas was the target, ignore card-level play toggle (mute handler already ran with stopPropagation)
        togglePlay(e);
      });
    }
    window._livePlayer = { play: mPlay, mute: mMute, togglePlay, toggleMute, get playing(){return playing;}, get muted(){return muted;} };
  })();

  // --------------- 5. Inline validation: Check ↔ X (EMAIL) ---------------
  (() => {
    const headerCanvas = document.getElementById('live-valid');
    const trailingCanvas = document.getElementById('live-valid-icon');
    const input = document.getElementById('live-email');
    const card = headerCanvas ? headerCanvas.closest('.pattern-card') : null;
    if (!headerCanvas || !input) return;
    const checkD = dOf('check'), xD = dOf('x');
    if (!checkD || !xD) return;

    const mHeader = createMorph(headerCanvas, checkD, xD);
    const mTrailing = trailingCanvas ? createMorph(trailingCanvas, checkD, xD) : null;
    if (!mHeader) return;
    const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    let lastState = null; // 'empty' | 'valid' | 'invalid'

    function update() {
      const v = input.value;
      const hasValue = v.length > 0;
      const valid = EMAIL.test(v);
      const state = !hasValue ? 'empty' : (valid ? 'valid' : 'invalid');

      // header morph mirrors trailing: opacity when empty
      if (!hasValue) {
        headerCanvas.style.opacity = '0.35';
        if (trailingCanvas) { trailingCanvas.style.display='none'; trailingCanvas.style.opacity='0'; }
        lastState = 'empty';
        return;
      }
      headerCanvas.style.opacity = '1';
      if (trailingCanvas) {
        trailingCanvas.style.display = 'block';
        trailingCanvas.style.opacity = '1';
      }
      if (state === lastState) return;
      const target = valid ? checkD : xD;
      mHeader.morphTo(target);
      if (mTrailing) mTrailing.morphTo(target);
      lastState = state;
      if (trailingCanvas) {
        trailingCanvas.setAttribute('aria-label', valid ? 'Valid email' : 'Invalid email');
      }
      headerCanvas.setAttribute('aria-label', valid ? 'Valid — check' : 'Invalid — x');
    }

    // initial
    headerCanvas.style.transition = 'opacity 200ms var(--ease-smooth)';
    headerCanvas.style.opacity = '0.35';
    headerCanvas.setAttribute('role','img');
    headerCanvas.setAttribute('aria-label','Validation — type an email');
    if (trailingCanvas) {
      trailingCanvas.style.display='none';
      trailingCanvas.style.opacity='0';
      trailingCanvas.style.transition='opacity 200ms var(--ease-smooth)';
      trailingCanvas.setAttribute('role','img');
    }

    input.addEventListener('input', update);
    input.addEventListener('change', update);
    // card tap focuses input (and cycles demo values for discoverability)
    let demoIdx = 0;
    const demos = ['', 'you@example.com', 'not-an-email'];
    function cycleDemo() {
      demoIdx = (demoIdx + 1) % demos.length;
      input.value = demos[demoIdx];
      input.dispatchEvent(new Event('input', {bubbles:true}));
      input.focus();
    }
    if (card) {
      card.setAttribute('aria-label','Inline validation — type an email to morph check and x');
      makeCardTappable(card, (e) => {
        if (e.target === input) return;
        cycleDemo();
      });
    }
    // also header tap cycles
    headerCanvas.addEventListener('click', (e) => { e.stopPropagation(); cycleDemo(); });
    headerCanvas.style.cursor='pointer';
    window._liveValid = { header: mHeader, trailing: mTrailing, update, input };
  })();

  // --------------- 6. File tree: Folder ↔ FolderOpen (+ chevron) ---------------
  (() => {
    const canvas = document.getElementById('live-folder');
    const btn = document.getElementById('live-tree-btn');
    const files = document.getElementById('live-tree-files');
    const chevron = document.getElementById('live-chevron');
    const card = canvas ? canvas.closest('.pattern-card') : null;
    if (!canvas) return;
    const folderD = dOf('folder'), folderOpenD = dOf('folder-open');
    if (!folderD || !folderOpenD) return;
    const m = createMorph(canvas, folderD, folderOpenD);
    if (!m) return;
    let open = false;

    function setOpen(next, fromCard) {
      if (typeof next === 'boolean') open = next;
      else open = !open;
      m.morphTo(open ? folderOpenD : folderD);
      if (files) files.hidden = !open;
      if (chevron) chevron.style.transform = open ? 'rotate(90deg)' : '';
      if (btn) {
        btn.textContent = open ? 'Close folder' : 'Toggle folder';
        btn.setAttribute('aria-expanded', String(open));
      }
      if (card) card.setAttribute('aria-expanded', String(open));
      canvas.setAttribute('aria-label', open ? 'Open folder — tap to close' : 'Folder — tap to open');
      canvas.setAttribute('aria-expanded', String(open));
    }
    function toggle(e) { if (e) e.stopPropagation(); setOpen(!open); }

    if (btn) btn.addEventListener('click', toggle);
    canvas.addEventListener('click', toggle);
    canvas.style.cursor='pointer';
    canvas.setAttribute('role','img');
    canvas.setAttribute('tabindex','0');
    canvas.setAttribute('aria-label','Folder — tap to open');
    canvas.setAttribute('aria-expanded','false');
    canvas.addEventListener('keydown', (e) => { if (e.key==='Enter'||e.key===' ') { e.preventDefault(); toggle(); }});
    if (chevron) chevron.setAttribute('aria-hidden','true');
    if (card) {
      card.setAttribute('aria-label','File tree — tap to disclose folder');
      makeCardTappable(card, toggle);
    }
    window._liveTree = { morph: m, toggle, setOpen, get open(){return open;} };
  })();

  // keep canvases crisp on resize / orientation
  let resizeTimer = null;
  window.addEventListener('resize', () => {
    clearTimeout(resizeTimer);
    resizeTimer = setTimeout(() => liveMorphs.forEach(m => m && m.rerender && m.rerender()), 50);
  });
  window.addEventListener('orientationchange', () => setTimeout(() => liveMorphs.forEach(m=>m.rerender()), 150));

  // expose
  window._showcaseLive = { morphs: liveMorphs, presets: SPRING_PRESETS, get stroke(){return currentStroke;}, get preset(){return currentPresetKey;} };
})();
