/* ============================================================
   Flutter bridge — drives the real morphicons_flutter web build
   over postMessage; renders the telemetry it posts back.
   ============================================================ */

(() => {
  const frame = document.getElementById('flutterBridge');
  const loading = document.getElementById('bridgeLoading');
  const pairSel = document.getElementById('fbPair');
  const modeSeg = document.getElementById('fbModeSeg');
  const kSlider = document.getElementById('fbK');
  const cSlider = document.getElementById('fbC');
  const strokeSlider = document.getElementById('fbStroke');
  const kVal = document.getElementById('fbKVal');
  const cVal = document.getElementById('fbCVal');
  const strokeVal = document.getElementById('fbStrokeVal');
  const scrubRow = document.getElementById('fbScrubRow');
  const tSlider = document.getElementById('fbT');
  const tVal = document.getElementById('fbTVal');
  const morphBtn = document.getElementById('fbMorph');
  const resetBtn = document.getElementById('fbReset');
  const ro = {
    x: document.getElementById('fbX'),
    v: document.getElementById('fbV'),
    settled: document.getElementById('fbSettled'),
    theta: document.getElementById('fbTheta'),
    sigma: document.getElementById('fbSigma'),
    res: document.getElementById('fbRes'),
    block: document.getElementById('fbBlock'),
    build: document.getElementById('fbBuild'),
  };

  const PAIRS = [
    { id: 'menu-x', label: 'menu → x', from: 'M4 6L20 6M4 12L20 12M4 18L20 18', to: 'M18 6L6 18M6 6L18 18' },
    { id: 'arrow-right-down', label: 'arrow-right → arrow-down', from: 'M5 12h14m-7-7 7 7-7 7', to: 'M12 5v14m-7-7 7 7 7-7' },
    { id: 'plus-minus', label: 'plus → minus', from: 'M5 12h14M12 5v14', to: 'M5 12h14' },
    { id: 'check-x', label: 'check → x', from: 'M20 6 9 17l-5-5', to: 'M18 6 6 18m0-12 12 12' },
    { id: 'square-circle', label: 'square → circle', from: 'M5 5h14v14H5Z', to: 'M12 2a10 10 0 1 0 0 20 10 10 0 1 0 0-20' },
  ];

  PAIRS.forEach((pair, i) => {
    const opt = document.createElement('option');
    opt.value = String(i);
    opt.textContent = pair.label;
    pairSel.appendChild(opt);
  });

  let ready = false;
  const queue = [];

  function postToFrame(msg) {
    const target = frame && frame.contentWindow;
    if (!target) return false;
    try {
      target.postMessage(msg, '*');
      return true;
    } catch {
      return false;
    }
  }

  function send(cmd) {
    const msg = { source: 'morphicons-site', ...cmd };
    if (!ready || queue.length) {
      queue.push(msg);
      if (ready) flushQueue();
      return;
    }
    if (!postToFrame(msg)) queue.push(msg);
  }

  function sendPair() {
    const index = Number.parseInt(pairSel.value, 10);
    const pair = PAIRS[index] || PAIRS[0];
    send({ cmd: 'pair', label: pair.label, from: pair.from, to: pair.to });
  }

  function sendSpring() {
    send({ cmd: 'spring', k: parseFloat(kSlider.value), c: parseFloat(cSlider.value) });
  }

  function sendStroke() {
    const stroke = Math.min(2.5, Math.max(1, parseFloat(strokeSlider.value) || 2));
    send({ cmd: 'stroke', stroke });
  }

  function setReadout(element, value) {
    element.textContent = value;
  }

  function finiteNumber(value) {
    return typeof value === 'number' && Number.isFinite(value) ? value : null;
  }

  function fixed(value, digits) {
    const number = finiteNumber(value);
    return number === null ? '—' : number.toFixed(digits);
  }

  function scientific(value, digits) {
    const number = finiteNumber(value);
    return number === null ? '—' : number.toExponential(digits);
  }

  function clearTelemetry() {
    setReadout(ro.x, '—');
    setReadout(ro.v, '—');
    setReadout(ro.settled, '—');
  }

  function clearPlanReadouts() {
    setReadout(ro.theta, '—');
    setReadout(ro.sigma, '—');
    setReadout(ro.res, '—');
    setReadout(ro.block, '—');
    setReadout(ro.build, '—');
  }

  function clearReadouts() {
    clearTelemetry();
    clearPlanReadouts();
  }

  function resetScrub() {
    tSlider.value = '0';
    tVal.textContent = '0.00';
  }

  function flushQueue() {
    while (queue.length) {
      const msg = queue[0];
      if (!postToFrame(msg)) return;
      queue.shift();
    }
  }

  window.addEventListener('message', (e) => {
    const d = e.data;
    if (!d || d.source !== 'morphicons-flutter') return;
    if (d.type === 'ready') {
      ready = true;
      loading.style.display = 'none';
      clearReadouts();
      // Replay anything queued while the engine was booting.
      flushQueue();
      // The iframe may have restarted; always restore the current controls.
      sendPair();
      sendSpring();
      sendStroke();
      return;
    }
    if (!ready) return;
    if (d.type === 'telemetry') {
      setReadout(ro.x, fixed(d.x, 3));
      setReadout(ro.v, fixed(d.v, 3));
      setReadout(ro.settled, d.settled === true ? 'yes' : d.settled === false ? 'no' : '—');
      return;
    }
    if (d.type === 'plan') {
      const theta = fixed(d.theta, 4);
      const sigma = fixed(d.sigma, 4);
      const residual = scientific(d.residual, 2);
      const build = fixed(d.buildMs, 2);
      setReadout(ro.theta, theta === '—' ? theta : `${theta} rad`);
      setReadout(ro.sigma, sigma);
      setReadout(ro.res, residual);
      setReadout(ro.block, typeof d.blockHybrid === 'boolean' ? (d.blockHybrid ? 'applied' : 'per-subpath') : '—');
      setReadout(ro.build, build === '—' ? build : `${build} ms`);
    }
  });

  pairSel.addEventListener('change', () => {
    resetScrub();
    clearReadouts();
    sendPair();
  });

  kSlider.addEventListener('input', () => {
    kVal.textContent = kSlider.value;
    sendSpring();
  });
  cSlider.addEventListener('input', () => {
    cVal.textContent = cSlider.value;
    sendSpring();
  });
  strokeSlider.addEventListener('input', () => {
    strokeVal.textContent = Number.parseFloat(strokeSlider.value).toFixed(1);
    sendStroke();
  });

  modeSeg.querySelectorAll('.seg-btn').forEach((b) => {
    b.addEventListener('click', () => {
      modeSeg.querySelectorAll('.seg-btn').forEach((x) => x.classList.remove('is-active'));
      b.classList.add('is-active');
      const mode = b.dataset.mode;
      scrubRow.hidden = mode !== 'controlled';
      morphBtn.disabled = mode === 'controlled';
      resetScrub();
      clearTelemetry();
      send({ cmd: 'mode', mode });
    });
  });

  tSlider.addEventListener('input', () => {
    const t = Math.min(1, Math.max(0, parseFloat(tSlider.value)));
    tVal.textContent = t.toFixed(2);
    send({ cmd: 'scrub', t });
  });

  morphBtn.addEventListener('click', () => {
    clearTelemetry();
    send({ cmd: 'morph' });
  });
  resetBtn.addEventListener('click', () => {
    resetScrub();
    clearTelemetry();
    send({ cmd: 'reset' });
  });
})();
