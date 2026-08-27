/* showcase-live.js — 6 REAL MorphCore cards like morphicons.com
   Copy→Check inside npm pill, Eye↔EyeOff inside input, Sun↔Moon button,
   Play↔Pause + Volume↔VolumeX in player cluster, Check↔X trailing validation, Folder↔FolderOpen tree
   - Real polar interpolation + Procrustes solver via MorphCore (6.5 kB core)
   - Interruptible: mid-flight re-plan from interpolated shape, velocity preserved (λ tie-break)
   - Spring presets + stroke live from left sidebar (showcase:control)
   - Cards are tappable (role=button, keyboard, cursor) — icons themselves are live canvases
   - Reduced motion → instant canonical snap, no frames
   - Hi-DPI canvas, resize-aware, visibility-aware, keyboard accessible
*/
(() => {
  const M = window.MorphCore;
  const Catalogs = {
    lucide: window.LucideCatalog || {},
    heroicons: window.HeroiconsCatalog || {},
    tabler: window.TablerCatalog || {}
  };
  if (!M || !Catalogs.lucide || !Object.keys(Catalogs.lucide).length) {
    console.warn('[showcase-live] MorphCore or LucideCatalog missing');
    return;
  }

  const SPRING_PRESETS = M.SPRING_PRESETS || { smooth:{k:170,c:26}, snappy:{k:420,c:30}, bouncy:{k:300,c:14} };
  let currentPreset = SPRING_PRESETS.smooth;
  let currentPresetKey = 'smooth';
  let currentStroke = 2;
  let currentLibrary = 'lucide';
  const liveMorphs = [];
  const libraryHandlers = [];
  const rm = window.matchMedia('(prefers-reduced-motion: reduce)');

  // Logical -> physical name per library. Logical keys cover all 6 cards.
  const LIB_ALIASES = {
    lucide: {
      'copy': 'copy',
      'check': 'check',
      'eye': 'eye',
      'eye-off': 'eye-off',
      'sun': 'sun',
      'moon': 'moon',
      'play': 'play',
      'pause': 'pause',
      'volume-2': 'volume-2',
      'volume-x': 'volume-x',
      'x': 'x',
      'folder': 'folder',
      'folder-open': 'folder-open'
    },
    heroicons: {
      'copy': 'clipboard-document',
      'check': 'check',
      'eye': 'eye',
      'eye-off': 'eye-slash',
      'sun': 'sun',
      'moon': 'moon',
      'play': 'play',
      'pause': 'pause',
      'volume-2': 'speaker-wave',
      'volume-x': 'speaker-x-mark',
      'x': 'x-mark',
      'folder': 'folder',
      'folder-open': 'folder-open'
    },
    tabler: {
      'copy': 'copy',
      'check': 'check',
      'eye': 'eye',
      'eye-off': 'eye-off',
      'sun': 'sun',
      'moon': 'moon',
      'play': 'player-play',
      'pause': 'player-pause',
      'volume-2': 'volume-2',
      'volume-x': 'volume-off',
      'x': 'x',
      'folder': 'folder',
      'folder-open': 'folder-open'
    }
  };

  function physicalName(logical) {
    const m = LIB_ALIASES[currentLibrary] || LIB_ALIASES.lucide;
    return (m[logical] || LIB_ALIASES.lucide[logical] || logical);
  }
  function currentCatalog() { return Catalogs[currentLibrary] || Catalogs.lucide; }
  function dOf(logical, fallback) {
    const cat = currentCatalog();
    const phys = physicalName(logical);
    return cat[phys] || cat[logical] || Catalogs.lucide[phys] || Catalogs.lucide[logical] || fallback || null;
  }
  function dOfLibrary(library, logical) {
    const cat = Catalogs[library] || Catalogs.lucide;
    const alias = (LIB_ALIASES[library] || LIB_ALIASES.lucide)[logical] || logical;
    return cat[alias] || cat[logical] || Catalogs.lucide[alias] || Catalogs.lucide[logical] || null;
  }

  function updateLibraryIcons() {
    libraryHandlers.forEach(fn => { try { fn(); } catch(e){ console.warn('[showcase-live] library handler failed', e); } });
  }

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
    if (d.control === 'library' && Catalogs[d.value]) {
      currentLibrary = d.value;
      updateLibraryIcons();
    }
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

    let targetD = fromD;
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
      if (!newTargetD || (newTargetD === targetD && !playing)) return;
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
      spring.start();
      curT = 0;
      if (!playing) { playing = true; tick(); }
    }

    function tick() {
      if (!playing) return;
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
    function snapTo(d) {
      if (!d) return;
      // cancel in-flight
      if (raf) cancelAnimationFrame(raf);
      playing = false; raf = null;
      try {
        const solo = M.buildPlan(M.resampleIcon(d), M.resampleIcon(d));
        const soloOut = M.allocOutputs(solo);
        M.interpPolar(solo, 1, soloOut);
        plan = solo; out = soloOut; targetD = d; lastT = 1; curT = 1;
        const fit = fitCanvas(canvas);
        if (fit) {
          const closed = solo.items.map(it=>!!it.closed);
          drawSubs(fit.ctx, fit.w, fit.h, soloOut, color, stroke*(fit.w/120)*0.9, closed);
        }
      } catch(_e) {}
    }

    render(0);

    const api = { canvas, morphTo, snapTo, render, updateSpring, updateStroke, rerender, destroy, get playing(){return playing;}, get target(){return targetD;}, get plan(){return plan;} };
    liveMorphs.push(api);
    return api;
  }

  function makeCardTappable(card, handler) {
    if (!card || !handler) return;
    card.style.cursor = 'pointer';
    if (!card.hasAttribute('tabindex')) card.setAttribute('tabindex','0');
    if (!card.hasAttribute('role')) card.setAttribute('role','button');
    const onActivate = (e) => {
      const t = e.target;
      if (t && t.closest) {
        if (t.closest('input, textarea, select')) return;
        if (t.closest('button') && card.contains(t.closest('button'))) {
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

  // --------------- 1. Copy → Check — npm pill, icon inside button ---------------
  (() => {
    const canvas = document.getElementById('live-copy');
    const btn = document.getElementById('live-copy-btn');
    const card = canvas ? canvas.closest('.pattern-card') : null;
    const headerCopy = card ? card.querySelector('.demo-card-copy-btn') : null;
    if (!canvas) return;
    let copyD = dOf('copy'), checkD = dOf('check');
    if (!copyD || !checkD) return;
    let m = createMorph(canvas, copyD, checkD);
    if (!m) return;
    let copied = false;
    let revertTimer = null;

    function doCopy() {
      if (copied && revertTimer) return;
      copied = true;
      m.morphTo(checkD);
      if (btn) { btn.setAttribute('aria-pressed','true'); btn.setAttribute('aria-label','Copied'); }
      if (card) card.setAttribute('aria-pressed','true');
      if (headerCopy) { headerCopy.textContent = 'Copied'; }
      navigator.clipboard && navigator.clipboard.writeText('npm i morphicons').catch(()=>{});
      clearTimeout(revertTimer);
      revertTimer = setTimeout(() => {
        copied = false;
        m.morphTo(copyD);
        if (btn) { btn.setAttribute('aria-pressed','false'); btn.setAttribute('aria-label','Copy command'); }
        if (card) card.setAttribute('aria-pressed','false');
        if (headerCopy) headerCopy.textContent = 'Flutter';
        revertTimer = null;
      }, 1600);
    }

    if (btn) {
      btn.addEventListener('click', (e) => { e.stopPropagation(); doCopy(); });
      btn.setAttribute('aria-pressed','false');
    }
    if (headerCopy) {
      headerCopy.addEventListener('click', (e) => { e.stopPropagation(); doCopy(); });
    }
    canvas.addEventListener('click', (e) => { e.stopPropagation(); doCopy(); });
    canvas.style.cursor = 'pointer';
    canvas.setAttribute('role','img');
    canvas.setAttribute('aria-label','Copy — tap to morph to check');
    if (card) {
      card.setAttribute('aria-label','Copy to clipboard — tap to show confirmation morph');
      makeCardTappable(card, doCopy);
    }
    window._liveCopy = { morph: m, doCopy, get copied(){return copied;} };
    libraryHandlers.push(() => {
      copyD = dOf('copy'); checkD = dOf('check');
      if (!copyD || !checkD || !m || !m.snapTo) return;
      m.snapTo(copied ? checkD : copyD);
    });
  })();

  // --------------- 2. Password: Eye ↔ EyeOff — real input with trailing morph button ---------------
  (() => {
    const canvas = document.getElementById('live-eye');
    const input = document.getElementById('live-password-input');
    const btn = document.getElementById('live-eye-btn');
    const card = canvas ? canvas.closest('.pattern-card') : null;
    if (!canvas) return;
    let eyeD = dOf('eye'), eyeOffD = dOf('eye-off');
    if (!eyeD || !eyeOffD) return;
    let m = createMorph(canvas, eyeD, eyeOffD);
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
      // keep focus on input if it had focus
      if (input && document.activeElement === input) {
        // preserve cursor
        const len = input.value.length;
        try { input.setSelectionRange(len,len); } catch(_e) {}
      }
    }

    if (btn) btn.addEventListener('click', (e) => { e.stopPropagation(); toggle(); });
    canvas.addEventListener('click', (e) => { e.stopPropagation(); toggle(); });
    canvas.style.cursor = 'pointer';
    canvas.setAttribute('role','img');
    canvas.setAttribute('aria-label','Eye — tap to toggle visibility');
    if (input) input.setAttribute('aria-label','Password');
    if (card) {
      card.setAttribute('aria-label','Password visibility — tap to toggle eye morph');
      makeCardTappable(card, (e) => {
        const ae = document.activeElement;
        if (ae === input) return;
        toggle();
      });
    }
    window._liveEye = { morph: m, toggle, get visible(){return visible;} };
    libraryHandlers.push(() => {
      eyeD = dOf('eye'); eyeOffD = dOf('eye-off');
      if (!eyeD || !eyeOffD || !m || !m.snapTo) return;
      m.snapTo(visible ? eyeOffD : eyeD);
    });
  })();

  // --------------- 3. Theme: Sun ↔ Moon — single button ---------------
  (() => {
    const canvas = document.getElementById('live-theme');
    const btn = document.getElementById('live-theme-btn');
    const card = canvas ? canvas.closest('.pattern-card') : null;
    if (!canvas) return;
    let sunD = dOf('sun'), moonD = dOf('moon');
    if (!sunD || !moonD) return;
    let m = createMorph(canvas, sunD, moonD);
    if (!m) return;
    let dark = false;

    function toggle() {
      dark = !dark;
      m.morphTo(dark ? moonD : sunD);
      document.documentElement.style.colorScheme = dark ? 'dark' : 'light';
      if (btn) btn.setAttribute('aria-pressed', String(dark));
      if (card) card.setAttribute('aria-pressed', String(dark));
      canvas.setAttribute('aria-label', dark ? 'Moon — tap for sun' : 'Sun — tap for moon');
      if (btn) btn.setAttribute('aria-label', dark ? 'Switch to light' : 'Switch to dark');
      document.documentElement.setAttribute('data-theme', dark ? 'dark' : 'light');
    }

    const trigger = btn || canvas;
    trigger.addEventListener('click', (e) => { e.stopPropagation(); toggle(); });
    canvas.style.cursor = 'pointer';
    if (btn) btn.style.cursor = 'pointer';
    canvas.setAttribute('role','img');
    canvas.setAttribute('aria-label','Sun — tap to toggle theme');
    if (btn) {
      btn.setAttribute('tabindex','0');
      btn.addEventListener('keydown', (e) => { if (e.key==='Enter'||e.key===' ') { e.preventDefault(); toggle(); } });
    } else {
      canvas.setAttribute('tabindex','0');
      canvas.addEventListener('keydown', (e) => { if (e.key==='Enter'||e.key===' ') { e.preventDefault(); toggle(); } });
    }
    if (card) {
      card.setAttribute('aria-label','Theme toggle — tap to morph sun and moon');
      makeCardTappable(card, toggle);
    }
    window._liveTheme = { morph: m, toggle, get dark(){return dark;} };
    libraryHandlers.push(() => {
      sunD = dOf('sun'); moonD = dOf('moon');
      if (!sunD || !moonD || !m || !m.snapTo) return;
      m.snapTo(dark ? moonD : sunD);
    });
  })();

  // --------------- 4. Player: Play↔Pause + Volume↔VolumeX — real player cluster ---------------
  (() => {
    const playCanvas = document.getElementById('live-play');
    const muteCanvas = document.getElementById('live-mute');
    const playBtn = document.getElementById('live-play-btn');
    const muteBtn = document.getElementById('live-mute-btn');
    const card = playCanvas ? playCanvas.closest('.pattern-card') : null;
    if (!playCanvas || !muteCanvas) return;
    let playD = dOf('play'), pauseD = dOf('pause');
    let volD = dOf('volume-2') || dOf('volume'), volX = dOf('volume-x');
    if (!playD || !pauseD || !volD || !volX) return;
    // play on light bg → dark stroke
    let mPlay = createMorph(playCanvas, playD, pauseD, { color: '#0a0a0a' });
    let mMute = createMorph(muteCanvas, volD, volX);
    if (!mPlay || !mMute) return;
    let playing = false, muted = false;

    function togglePlay(e) {
      if (e) e.stopPropagation();
      playing = !playing;
      mPlay.morphTo(playing ? pauseD : playD);
      const label = playing ? 'Pause — tap to play' : 'Play — tap to pause';
      playCanvas.setAttribute('aria-label', label);
      if (playBtn) playBtn.setAttribute('aria-label', label);
      if (card) card.setAttribute('aria-pressed', String(playing));
    }
    function toggleMute(e) {
      if (e) e.stopPropagation();
      muted = !muted;
      mMute.morphTo(muted ? volX : volD);
      const label = muted ? 'Unmute' : 'Mute';
      muteCanvas.setAttribute('aria-label', label);
      if (muteBtn) {
        muteBtn.setAttribute('aria-label', label);
        muteBtn.setAttribute('aria-pressed', String(muted));
      }
    }

    if (playBtn) playBtn.addEventListener('click', togglePlay);
    else playCanvas.addEventListener('click', togglePlay);
    if (muteBtn) muteBtn.addEventListener('click', toggleMute);
    else muteCanvas.addEventListener('click', toggleMute);

    [playCanvas, muteCanvas].forEach(c => {
      c.style.cursor='pointer';
      c.setAttribute('role','img');
    });
    if (playBtn) {
      playBtn.style.cursor='pointer';
      playBtn.setAttribute('tabindex','0');
      playBtn.addEventListener('keydown', (e) => { if (e.key==='Enter'||e.key===' ') { e.preventDefault(); togglePlay(e); }});
    } else {
      playCanvas.setAttribute('tabindex','0');
      playCanvas.addEventListener('keydown', (e) => { if (e.key==='Enter'||e.key===' ') { e.preventDefault(); togglePlay(e); }});
    }
    if (muteBtn) {
      muteBtn.style.cursor='pointer';
      muteBtn.setAttribute('tabindex','0');
      muteBtn.addEventListener('keydown', (e) => { if (e.key==='Enter'||e.key===' ') { e.preventDefault(); toggleMute(e); }});
    } else {
      muteCanvas.setAttribute('tabindex','0');
      muteCanvas.addEventListener('keydown', (e) => { if (e.key==='Enter'||e.key===' ') { e.preventDefault(); toggleMute(e); }});
    }
    playCanvas.setAttribute('aria-label','Play — tap to pause');
    muteCanvas.setAttribute('aria-label','Volume — tap to mute');
    if (muteBtn) muteBtn.setAttribute('aria-pressed','false');

    if (card) {
      card.setAttribute('aria-label','Player controls — tap to toggle play, tap speaker to mute');
      makeCardTappable(card, (e) => {
        // card tap toggles play; mute is separate
        togglePlay(e);
      });
    }
    window._livePlayer = { play: mPlay, mute: mMute, togglePlay, toggleMute, get playing(){return playing;}, get muted(){return muted;} };
    libraryHandlers.push(() => {
      playD = dOf('play'); pauseD = dOf('pause');
      volD = dOf('volume-2') || dOf('volume'); volX = dOf('volume-x');
      if (!playD || !pauseD || !volD || !volX) return;
      if (mPlay && mPlay.snapTo) mPlay.snapTo(playing ? pauseD : playD);
      if (mMute && mMute.snapTo) mMute.snapTo(muted ? volX : volD);
    });
  })();

  // --------------- 5. Inline validation: Check ↔ X trailing — real email input ---------------
  (() => {
    const trailingCanvas = document.getElementById('live-valid-icon');
    const input = document.getElementById('live-email');
    const card = input ? input.closest('.pattern-card') : null;
    if (!trailingCanvas || !input) return;
    let checkD = dOf('check'), xD = dOf('x');
    if (!checkD || !xD) return;

    let mTrailing = createMorph(trailingCanvas, checkD, xD);
    if (!mTrailing) return;
    const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    let lastState = null; // 'empty' | 'valid' | 'invalid'

    function update() {
      const v = input.value.trim();
      const hasValue = v.length > 0;
      const valid = EMAIL.test(v);
      const state = !hasValue ? 'empty' : (valid ? 'valid' : 'invalid');

      if (!hasValue) {
        trailingCanvas.style.display='none';
        trailingCanvas.style.opacity='0';
        lastState = 'empty';
        input.setAttribute('aria-invalid', 'false');
        return;
      }
      trailingCanvas.style.display = 'block';
      // trigger reflow then fade in
      requestAnimationFrame(() => { trailingCanvas.style.opacity='1'; });
      if (state === lastState) return;
      const target = valid ? checkD : xD;
      mTrailing.morphTo(target);
      lastState = state;
      trailingCanvas.setAttribute('aria-label', valid ? 'Valid email' : 'Invalid email');
      input.setAttribute('aria-invalid', valid ? 'false' : 'true');
      // tint border
      input.style.borderColor = valid ? '#262626' : '#404040';
    }

    trailingCanvas.style.opacity='0';
    trailingCanvas.style.transition='opacity 200ms var(--ease-smooth)';
    trailingCanvas.setAttribute('role','img');
    trailingCanvas.setAttribute('aria-hidden','true');

    input.addEventListener('input', update);
    input.addEventListener('change', update);
    input.addEventListener('blur', update);

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
    // also trailing click cycles
    trailingCanvas.addEventListener('click', (e) => { e.stopPropagation(); cycleDemo(); });
    trailingCanvas.style.cursor='pointer';
    trailingCanvas.parentElement && (trailingCanvas.parentElement.style.cursor='pointer');
    window._liveValid = { trailing: mTrailing, update, input, cycleDemo };
    libraryHandlers.push(() => {
      checkD = dOf('check'); xD = dOf('x');
      if (!checkD || !xD || !mTrailing || !mTrailing.snapTo) return;
      // Rebuild trailing based on lastState; if empty hide, else show check/x
      const v = input.value.trim();
      const hasValue = v.length>0;
      if (!hasValue) {
        // keep hidden, but snap to check for next show
        mTrailing.snapTo(checkD);
        return;
      }
      const valid = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v);
      const target = valid ? checkD : xD;
      mTrailing.snapTo(target);
    });
  })();

  // --------------- 6. File tree: Folder ↔ FolderOpen (+ chevron) — real disclosures ---------------
  (() => {
    const canvas = document.getElementById('live-folder');
    const btn = document.getElementById('live-tree-btn');
    const files = document.getElementById('live-tree-files');
    const chevron = document.getElementById('live-chevron');
    const card = canvas ? canvas.closest('.pattern-card') : null;
    if (!canvas) return;
    let folderD = dOf('folder'), folderOpenD = dOf('folder-open');
    if (!folderD || !folderOpenD) return;
    let m = createMorph(canvas, folderD, folderOpenD);
    if (!m) return;
    let open = false;

    function setOpen(next) {
      if (typeof next === 'boolean') open = next;
      else open = !open;
      m.morphTo(open ? folderOpenD : folderD);
      if (files) files.hidden = !open;
      if (chevron) chevron.style.transform = open ? 'rotate(90deg)' : '';
      if (btn) {
        btn.setAttribute('aria-expanded', String(open));
      }
      if (card) card.setAttribute('aria-expanded', String(open));
      canvas.setAttribute('aria-label', open ? 'Open folder — tap to close' : 'Folder — tap to open');
      canvas.setAttribute('aria-expanded', String(open));
      if (btn) btn.setAttribute('aria-label', open ? 'Collapse components' : 'Expand components');
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
    if (btn) {
      btn.setAttribute('tabindex','0');
      btn.addEventListener('keydown', (e) => { if (e.key==='Enter'||e.key===' ') { e.preventDefault(); toggle(); }});
    }
    if (card) {
      card.setAttribute('aria-label','File tree — tap to disclose folder');
      makeCardTappable(card, toggle);
    }
    // also handle header lib row is static — no morph
    window._liveTree = { morph: m, toggle, setOpen, get open(){return open;} };
    libraryHandlers.push(() => {
      folderD = dOf('folder'); folderOpenD = dOf('folder-open');
      if (!folderD || !folderOpenD || !m || !m.snapTo) return;
      m.snapTo(open ? folderOpenD : folderD);
    });
  })();

  // keep canvases crisp on resize / orientation
  let resizeTimer = null;
  window.addEventListener('resize', () => {
    clearTimeout(resizeTimer);
    resizeTimer = setTimeout(() => liveMorphs.forEach(m => m && m.rerender && m.rerender()), 50);
  });
  window.addEventListener('orientationchange', () => setTimeout(() => liveMorphs.forEach(m=>m.rerender()), 150));

  // expose
  window._showcaseLive = { morphs: liveMorphs, presets: SPRING_PRESETS, get stroke(){return currentStroke;}, get preset(){return currentPresetKey;}, get library(){return currentLibrary;}, get catalogs(){return Catalogs;} };
  // also expose for tests: current catalog accessor
  window._showcaseLibrary = { get library(){return currentLibrary;}, setLibrary: (lib)=>{ if(Catalogs[lib]){ currentLibrary=lib; updateLibraryIcons(); } }, catalogs: Catalogs, aliases: LIB_ALIASES };
})();
