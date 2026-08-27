/* Live morphs for the 6 showcase cards — web-native, no Flutter */
(() => {
  const M = window.MorphCore;
  const L = window.LucideCatalog;
  if (!M || !L) return;

  function dOf(name) { return L[name] || null; }
  function fitCanvas(c) {
    const dpr = Math.min(window.devicePixelRatio||1, 2);
    const r = c.getBoundingClientRect();
    if (!r.width) return null;
    const w = Math.round(r.width*dpr), h = Math.round(r.height*dpr);
    if (c.width!==w || c.height!==h) { c.width=w; c.height=h; }
    const ctx = c.getContext('2d'); ctx.setTransform(1,0,0,1,0,0);
    return {ctx,w,h,dpr};
  }
  function drawSubs(ctx,w,h,subs,color,lineWidthPx){
    ctx.clearRect(0,0,w,h);
    const s = (Math.min(w,h)/24)*0.92;
    const ox = (w-24*s)/2, oy=(h-24*s)/2;
    ctx.strokeStyle=color; ctx.lineWidth=lineWidthPx; ctx.lineCap='round'; ctx.lineJoin='round';
    for(const pts of subs){
      if(typeof pts==='string') continue;
      const n=pts.length/2; if(n<2) continue;
      ctx.beginPath(); ctx.moveTo(ox+pts[0]*s, oy+pts[1]*s);
      for(let i=1;i<n;i++) ctx.lineTo(ox+pts[2*i]*s, oy+pts[2*i+1]*s);
      ctx.stroke();
    }
  }

  // Generic morph controller for a canvas
  function makeMorph(canvas, fromD, toD, opts={}) {
    const stroke = opts.stroke||2;
    const color = opts.color||'#ededed';
    let plan = M.buildPlan(M.resampleIcon(fromD), M.resampleIcon(toD));
    let out = M.allocOutputs(plan);
    let t = 0, playing=false, raf=null;
    const spring = new M.Spring();
    spring.config(opts.k||170, opts.c||26);
    let curFrom = fromD, curTo = toD, curT = 0;
    function render(tt){
      M.interpPolar(plan, tt, out);
      const fit = fitCanvas(canvas);
      if(fit) drawSubs(fit.ctx,fit.w,fit.h,out,color,stroke*(fit.w/120)*0.9);
    }
    function morphTo(newFrom, newTo){
      curFrom=newFrom; curTo=newTo;
      plan = M.buildPlan(M.resampleIcon(newFrom), M.resampleIcon(newTo));
      out = M.allocOutputs(plan);
      spring.config(opts.k||170, opts.c||26); spring.start(); playing=true; tick();
    }
    function tick(){
      if(!playing) return;
      const settled = spring.step(1/60);
      curT = Math.min(spring.x,1);
      render(curT);
      if(settled){ playing=false; curT=1; render(1); }
      else raf=requestAnimationFrame(tick);
    }
    render(0);
    return { morphTo, render, getT:()=>curT, canvas };
  }

  // 1. Copy / check
  const copyCanvas = document.getElementById('live-copy');
  if(copyCanvas){
    const copyD = dOf('copy'), checkD = dOf('check');
    const m = makeMorph(copyCanvas, copyD, checkD, {k:420,c:30});
    let copied=false;
    const btn = document.getElementById('live-copy-btn');
    if(btn) btn.addEventListener('click', async ()=>{
      copied=!copied;
      m.morphTo(copied?checkD:copyD, copied?copyD:checkD);
      // Actually morphTo toggles, but makeMorph expects from,to swap
      // For simplicity, just morph the canvas
      try{ await navigator.clipboard.writeText('npm i morphicons'); }catch{}
      btn.textContent = copied?'Copied':'Copy';
      setTimeout(()=>{ btn.textContent='Copy'; },1500);
    });
    // Also make the canvas itself tappable
    copyCanvas.addEventListener('click', ()=>{ if(btn) btn.click(); });
    copyCanvas.style.cursor='pointer';
  }

  // 2. Password visibility - eye / eye-off inside input
  const eyeCanvas = document.getElementById('live-eye');
  if(eyeCanvas){
    const eyeD = dOf('eye'), eyeOffD = dOf('eye-off');
    const m = makeMorph(eyeCanvas, eyeD, eyeOffD, {k:420,c:30});
    let visible=false;
    const input = document.getElementById('live-password-input');
    const btn = document.getElementById('live-eye-btn');
    function update(){
      visible=!visible;
      if(input) input.type = visible?'text':'password';
      m.morphTo(visible?eyeOffD:eyeD, visible?eyeD:eyeOffD);
      // Swap for next
      const tmp = m;
    }
    if(btn) btn.addEventListener('click', update);
    eyeCanvas.addEventListener('click', update);
    eyeCanvas.style.cursor='pointer';
    // Initial render eye
    m.render(0);
  }

  // 3. Theme toggle sun/moon
  const themeCanvas = document.getElementById('live-theme');
  if(themeCanvas){
    const sunD = dOf('sun'), moonD = dOf('moon');
    const m = makeMorph(themeCanvas, sunD, moonD, {k:300,c:14});
    let dark=false;
    themeCanvas.addEventListener('click', ()=>{
      dark=!dark;
      m.morphTo(dark?moonD:sunD, dark?sunD:moonD);
      document.documentElement.style.colorScheme = dark?'dark':'light';
    });
    themeCanvas.style.cursor='pointer';
  }

  // 4. Player controls play/pause
  const playCanvas = document.getElementById('live-play');
  if(playCanvas){
    const playD = dOf('play'), pauseD = dOf('pause');
    const m = makeMorph(playCanvas, playD, pauseD, {k:420,c:30});
    let playing=false;
    playCanvas.addEventListener('click', ()=>{
      playing=!playing;
      m.morphTo(playing?pauseD:playD, playing?playD:pauseD);
    });
    playCanvas.style.cursor='pointer';
  }
  // Also mute button for player
  const muteCanvas = document.getElementById('live-mute');
  if(muteCanvas){
    const volD = dOf('volume-2')||dOf('volume'), volOffD = dOf('volume-x');
    if(volD&&volOffD){
      const m2 = makeMorph(muteCanvas, volD, volOffD, {k:420,c:30});
      let muted=false;
      muteCanvas.addEventListener('click', ()=>{
        muted=!muted;
        m2.morphTo(muted?volOffD:volD, muted?volD:volOffD);
      });
      muteCanvas.style.cursor='pointer';
    }
  }

  // 5. Inline validation check/x
  const validCanvas = document.getElementById('live-valid');
  if(validCanvas){
    const checkD = dOf('check'), xD = dOf('x');
    const m = makeMorph(validCanvas, checkD, xD, {k:420,c:30});
    const input = document.getElementById('live-email');
    if(input){
      input.addEventListener('input', ()=>{
        const valid = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(input.value);
        const hasValue = input.value.length>0;
        if(!hasValue){ validCanvas.style.opacity='0'; return; }
        validCanvas.style.opacity='1';
        // Morph to appropriate icon
        const target = valid?checkD:xD;
        const from = valid?xD:checkD;
        m.morphTo(target, from);
      });
    }
  }

  // 6. File tree folder morph
  const folderCanvas = document.getElementById('live-folder');
  if(folderCanvas){
    const folderD = dOf('folder'), folderOpenD = dOf('folder-open');
    if(folderD&&folderOpenD){
      const m = makeMorph(folderCanvas, folderD, folderOpenD, {k:300,c:26});
      let open=false;
      const btn = document.getElementById('live-tree-btn');
      const files = document.getElementById('live-tree-files');
      function toggle(){
        open=!open;
        m.morphTo(open?folderOpenD:folderD, open?folderD:folderOpenD);
        if(files) files.hidden = !open;
        // Rotate chevron via CSS
        const chevron = document.getElementById('live-chevron');
        if(chevron) chevron.style.transform = open?'rotate(90deg)':'';
      }
      if(btn) btn.addEventListener('click', toggle);
      folderCanvas.addEventListener('click', toggle);
      folderCanvas.style.cursor='pointer';
    }
  }
})();
