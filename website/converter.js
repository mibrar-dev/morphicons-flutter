import {
  flattenNodes,
  sanitizeIdentifier,
  serializeOutputs,
  validateSvgMarkup,
} from './converter-core.mjs';

/* ============================================================
   SVG -> Morphicons converter
   Browser adapter for the pure converter-core helpers.
   Mounts both the frame-panel converter and the standalone
   page converter (dark minimal, square 6px). Uses same core.
   ============================================================ */

const SAMPLE = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <circle cx="12" cy="12" r="9"/>
  <polyline points="12 7 12 12 15.5 13.5"/>
</svg>`;

const BUILT_IN = [
  ['menu', 'M4 6L20 6M4 12L20 12M4 18L20 18'],
  ['x', 'M18 6L6 18M6 6L18 18'],
  ['check', 'M20 6L9 17L4 12'],
  ['plus', 'M5 12L19 12M12 5L12 19'],
  ['arrow-right', 'M5 12L19 12M12 5L19 12L12 19'],
  ['square', 'M5 5L19 5L19 19L5 19Z'],
  ['circle', 'M12 2A10 10 0 1 0 12 22A10 10 0 1 0 12 2Z'],
];

function attributes(el) {
  const attrs = {};
  for (const item of el.attributes) attrs[item.name] = item.value;
  return attrs;
}

function flatten(svg) {
  const nodes = [{ tag: 'svg', attrs: attributes(svg) }];
  const walk = (parent) => {
    for (const el of parent.children) {
      nodes.push({ tag: el.tagName, attrs: attributes(el) });
      if (['g', 'svg', 'defs', 'symbol'].includes(el.tagName.toLowerCase())) walk(el);
    }
  };
  walk(svg);

  const result = flattenNodes(nodes);
  let viewBox = null;
  const vbAttr = (svg.getAttribute('viewBox') || '').trim();
  if (vbAttr) {
    const parts = vbAttr.split(/[\s,]+/).map(Number);
    if (parts.length === 4 && parts.every(Number.isFinite) && parts[2] > 0 && parts[3] > 0) viewBox = parts;
  }
  if (!viewBox) {
    const wRaw = svg.getAttribute('width');
    const hRaw = svg.getAttribute('height');
    const w = wRaw ? Number.parseFloat(String(wRaw)) : NaN;
    const h = hRaw ? Number.parseFloat(String(hRaw)) : NaN;
    if (Number.isFinite(w) && Number.isFinite(h) && w > 0 && h > 0) viewBox = [0, 0, w, h];
  }
  return { ...result, viewBox };
}

function mountConverter(config) {
  const M = window.MorphCore;
  if (!M) return;

  const {
    input, runBtn, sampleBtn, dropZone, fileInput, status, preview,
    nameInput, outCode, copyBtn, downloadBtn, tabsContainer, targetSel,
    morphPlay, cvSubs, cvPts, cvVerdict, browseBtn,
  } = config;

  // Guard: required elements must exist, otherwise this instance is not on page
  if (!input || !preview || !status || !runBtn) return;

  const tabs = tabsContainer ? tabsContainer.querySelectorAll('.seg-btn') : [];
  let currentD = '';
  let currentPoints = [];
  let currentViewBox = [0, 0, 24, 24];
  let morphAnim = null;
  let outMode = 'dart';
  let previewVisible = true;

  function resolveViewBox(vb) {
    if (Array.isArray(vb) && vb.length === 4 && vb.every((v) => Number.isFinite(v)) && vb[2] > 0 && vb[3] > 0) return vb;
    return [0, 0, 24, 24];
  }

  function drawD(canvas, d, color, viewBox) {
    const rect = canvas.getBoundingClientRect();
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    canvas.width = Math.max(1, Math.round(rect.width * dpr));
    canvas.height = Math.max(1, Math.round(rect.height * dpr));
    const ctx = canvas.getContext('2d');
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    if (!d) return;
    const pad = 0.08;
    const vb = resolveViewBox(viewBox ?? currentViewBox);
    const [vbX, vbY, vbW, vbH] = vb;
    const scale = Math.min(canvas.width / vbW, canvas.height / vbH) * (1 - 2 * pad);
    const ox = (canvas.width - vbW * scale) / 2 - vbX * scale;
    const oy = (canvas.height - vbH * scale) / 2 - vbY * scale;
    ctx.save();
    ctx.translate(ox, oy);
    ctx.scale(scale, scale);
    ctx.strokeStyle = color;
    ctx.lineWidth = 2 * Math.max(vbW, vbH) / 24;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    try {
      ctx.stroke(new Path2D(d));
    } catch (error) {
      status.textContent = `Could not render the flattened path: ${error.message}`;
    }
    ctx.restore();
  }

  function drawSubsOnPreview(subs, color, viewBox, closedFlags) {
    const rect = preview.getBoundingClientRect();
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    preview.width = Math.max(1, Math.round(rect.width * dpr));
    preview.height = Math.max(1, Math.round(rect.height * dpr));
    const ctx = preview.getContext('2d');
    ctx.clearRect(0, 0, preview.width, preview.height);
    if (!subs || subs.length === 0) return;
    const baseVb = resolveViewBox(viewBox ?? currentViewBox);
    const [bx, by, bw, bh] = baseVb;
    const minX = Math.min(bx, 0);
    const minY = Math.min(by, 0);
    const maxX = Math.max(bx + bw, 24);
    const maxY = Math.max(by + bh, 24);
    const vbW = maxX - minX;
    const vbH = maxY - minY;
    const vbX = minX;
    const vbY = minY;
    const pad = 0.08;
    const scale = Math.min(preview.width / vbW, preview.height / vbH) * (1 - 2 * pad);
    const ox = (preview.width - vbW * scale) / 2 - vbX * scale;
    const oy = (preview.height - vbH * scale) / 2 - vbY * scale;
    const maxDim = Math.max(vbW, vbH);
    ctx.strokeStyle = color;
    ctx.lineWidth = 2 * (preview.width / 480) * (maxDim / 24);
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    for (let k = 0; k < subs.length; k++) {
      const pts = subs[k];
      const n = pts.length / 2;
      if (n < 2) continue;
      ctx.beginPath();
      ctx.moveTo(ox + pts[0] * scale, oy + pts[1] * scale);
      for (let i = 1; i < n; i++) ctx.lineTo(ox + pts[2 * i] * scale, oy + pts[2 * i + 1] * scale);
      if (closedFlags && closedFlags[k]) ctx.closePath();
      ctx.stroke();
    }
  }

  function resetAssessment() {
    currentPoints = [];
    if (cvSubs) cvSubs.textContent = '—';
    if (cvPts) cvPts.textContent = '—';
    if (cvVerdict) { cvVerdict.textContent = '—'; cvVerdict.style.color = ''; }
    if (morphPlay) morphPlay.disabled = true;
  }

  function assess() {
    resetAssessment();
    if (!currentD) return null;
    try {
      const sampled = M.resampleIcon(currentD);
      currentPoints = sampled.map(({ pts }) => Array.from(pts));
      const pointCount = currentPoints.reduce((total, points) => total + points.length / 2, 0);
      if (cvSubs) cvSubs.textContent = String(currentPoints.length);
      if (cvPts) cvPts.textContent = String(pointCount);
      if (cvVerdict) { cvVerdict.textContent = 'morph-ready'; cvVerdict.style.color = '#346538'; }
      if (morphPlay) morphPlay.disabled = !targetSel || !targetSel.value;
      return sampled;
    } catch (error) {
      if (cvVerdict) { cvVerdict.textContent = 'parse error'; cvVerdict.style.color = '#9F2F2D'; }
      status.textContent = `Could not parse the flattened path: ${error.message}`;
      return null;
    }
  }

  function renderOutput() {
    if (!currentD) return;
    if (!nameInput || !outCode) return;
    const outputs = serializeOutputs({ id: sanitizeIdentifier(nameInput.value), d: currentD, points: currentPoints });
    outCode.textContent = outputs[outMode] ?? outputs.dart;
  }

  function clearConversion(message) {
    currentD = '';
    currentViewBox = [0, 0, 24, 24];
    resetAssessment();
    drawD(preview, '', '#ededed', currentViewBox);
    if (outCode) outCode.textContent = '// No stroke geometry found in this SVG.';
    status.textContent = message;
  }

  function convert(svgText) {
    if (morphAnim) {
      cancelAnimationFrame(morphAnim);
      morphAnim = null;
    }
    const markupError = validateSvgMarkup(svgText);
    if (markupError) {
      clearConversion(markupError);
      if (cvVerdict) { cvVerdict.textContent = 'parse error'; cvVerdict.style.color = '#9F2F2D'; }
      return;
    }
    const doc = new DOMParser().parseFromString(svgText, 'image/svg+xml');
    const parserError = doc.querySelector('parsererror');
    const svg = doc.documentElement;
    if (parserError || !svg || svg.tagName.toLowerCase() !== 'svg') {
      clearConversion('That is not valid SVG markup.');
      if (cvVerdict) { cvVerdict.textContent = 'parse error'; cvVerdict.style.color = '#9F2F2D'; }
      return;
    }
    const { d, notes, viewBox, elementCount } = flatten(svg);
    if (!d) {
      clearConversion('No stroke geometry found. ' + (notes.join(' · ') || 'Add path/line/circle/rect elements.'));
      if (cvVerdict) { cvVerdict.textContent = 'nothing to morph'; cvVerdict.style.color = '#9F2F2D'; }
      return;
    }
    currentD = d;
    currentViewBox = resolveViewBox(viewBox);
    let message = `Flattened ${elementCount} element${elementCount === 1 ? '' : 's'}`;
    if (viewBox && (viewBox[2] !== 24 || viewBox[3] !== 24)) {
      message += ` · viewBox is ${viewBox[2]}×${viewBox[3]} — wrap with fitIcon() or rescale`;
    }
    if (notes.length) message += ` · ${notes.join(' · ')}`;
    status.textContent = message;
    drawD(preview, d, '#ededed', currentViewBox);
    assess();
    renderOutput();
  }

  if (tabs && tabs.length) {
    tabs.forEach((button) => {
      button.addEventListener('click', () => {
        tabs.forEach((item) => item.classList.remove('is-active'));
        button.classList.add('is-active');
        outMode = button.dataset.out || 'dart';
        renderOutput();
      });
    });
  }

  if (copyBtn && outCode) {
    copyBtn.addEventListener('click', async () => {
      try {
        await navigator.clipboard.writeText(outCode.textContent);
        copyBtn.textContent = 'Copied';
        setTimeout(() => { copyBtn.textContent = 'Copy'; }, 1200);
      } catch {
        copyBtn.textContent = 'Copy failed';
        setTimeout(() => { copyBtn.textContent = 'Copy'; }, 1600);
      }
    });
  }

  if (downloadBtn) {
    downloadBtn.addEventListener('click', () => {
      if (!currentD) return;
      const outputs = serializeOutputs({ id: sanitizeIdentifier(nameInput ? nameInput.value : 'myIcon'), d: currentD, points: currentPoints });
      const blob = new Blob([outputs.dart + '\n'], { type: 'text/plain;charset=utf-8' });
      const url = URL.createObjectURL(blob);
      const anchor = document.createElement('a');
      anchor.href = url;
      anchor.download = `${sanitizeIdentifier(nameInput ? nameInput.value : 'myIcon')}.dart`;
      anchor.click();
      URL.revokeObjectURL(url);
    });
  }

  if (nameInput) nameInput.addEventListener('input', renderOutput);
  if (runBtn) runBtn.addEventListener('click', () => convert(input.value));
  if (sampleBtn) sampleBtn.addEventListener('click', () => {
    input.value = SAMPLE;
    convert(SAMPLE);
  });
  if (input) input.addEventListener('keydown', (event) => {
    if ((event.metaKey || event.ctrlKey) && event.key === 'Enter') convert(input.value);
  });

  function loadFile(file) {
    if (!file) return;
    const reader = new FileReader();
    reader.onload = () => {
      input.value = String(reader.result);
      const base = file.name.replace(/\.svg$/i, '').replace(/[^A-Za-z0-9]+/g, '_');
      if (nameInput) nameInput.value = sanitizeIdentifier(base);
      convert(input.value);
    };
    reader.onerror = () => clearConversion('Could not read that local SVG file.');
    reader.readAsText(file);
  }

  if (fileInput) fileInput.addEventListener('change', () => loadFile(fileInput.files[0]));
  if (dropZone) {
    dropZone.addEventListener('dragover', (event) => {
      event.preventDefault();
      dropZone.style.borderColor = '#111';
    });
    dropZone.addEventListener('dragleave', () => { dropZone.style.borderColor = ''; });
    dropZone.addEventListener('drop', (event) => {
      event.preventDefault();
      dropZone.style.borderColor = '';
      loadFile(event.dataTransfer.files[0]);
    });
    if (browseBtn && fileInput) browseBtn.addEventListener('click', () => fileInput.click());
  }

  // Populate built-in morph targets
  if (targetSel) {
    BUILT_IN.forEach(([name, d]) => {
      const option = document.createElement('option');
      option.value = d;
      option.textContent = name;
      targetSel.appendChild(option);
    });
    targetSel.addEventListener('change', () => { if (morphPlay) morphPlay.disabled = !targetSel.value || !currentD; });
  }

  // IntersectionObserver for preview visibility
  if ('IntersectionObserver' in window && preview) {
    const io = new IntersectionObserver((entries) => {
      previewVisible = entries[0].isIntersecting;
    }, { threshold: 0.12 });
    io.observe(preview);
  }
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) previewVisible = false;
    else previewVisible = true;
  });

  if (morphPlay && targetSel) {
    morphPlay.addEventListener('click', () => {
      if (!currentD || !targetSel.value) return;
      if (morphAnim) { cancelAnimationFrame(morphAnim); morphAnim = null; }
      let plan;
      try {
        plan = M.buildPlan(M.resampleIcon(currentD), M.resampleIcon(targetSel.value));
      } catch (error) {
        status.textContent = `Could not build a plan: ${error.message}`;
        return;
      }
      const out = M.allocOutputs(plan);
      const closedFlags = plan.items.map((it) => !!it.closed);
      const spring = new M.Spring();
      spring.config(170, 26);
      spring.start();
      const tick = () => {
        if (!previewVisible || document.hidden) {
          morphAnim = requestAnimationFrame(tick);
          return;
        }
        const settled = spring.step(1 / 60);
        M.interpPolar(plan, Math.min(spring.x, 1), out);
        drawSubsOnPreview(out, '#ededed', currentViewBox, closedFlags);
        if (!settled) morphAnim = requestAnimationFrame(tick);
        else morphAnim = null;
      };
      tick();
    });
  }

  window.addEventListener('resize', () => { if (currentD) drawD(preview, currentD, '#ededed', currentViewBox); });

  // expose for tests/debug
  return { convert, get currentD() { return currentD; } };
}

(() => {
  // Mount frame converter (existing IDs)
  mountConverter({
    input: document.getElementById('convInput'),
    runBtn: document.getElementById('convRun'),
    sampleBtn: document.getElementById('convSample'),
    dropZone: document.getElementById('convDrop'),
    fileInput: document.getElementById('convFile'),
    status: document.getElementById('convStatus'),
    preview: document.getElementById('convPreview'),
    nameInput: document.getElementById('convName'),
    outCode: document.getElementById('convOut'),
    copyBtn: document.getElementById('convCopy'),
    downloadBtn: document.getElementById('convDownload'),
    tabsContainer: document.getElementById('convTabs'),
    targetSel: document.getElementById('convMorphTarget'),
    morphPlay: document.getElementById('convMorphPlay'),
    cvSubs: document.getElementById('cvSubs'),
    cvPts: document.getElementById('cvPts'),
    cvVerdict: document.getElementById('cvVerdict'),
    browseBtn: document.getElementById('convBrowse'),
  });

  // Mount standalone page converter (new IDs with Page suffix)
  const pageInstance = mountConverter({
    input: document.getElementById('convInputPage'),
    runBtn: document.getElementById('convRunPage'),
    sampleBtn: document.getElementById('convSamplePage'),
    dropZone: document.getElementById('convDropPage'),
    fileInput: document.getElementById('convFilePage'),
    status: document.getElementById('convStatusPage'),
    preview: document.getElementById('convPreviewPage'),
    nameInput: document.getElementById('convNamePage'),
    outCode: document.getElementById('convOutPage'),
    copyBtn: document.getElementById('convCopyPage'),
    downloadBtn: document.getElementById('convDownloadPage'),
    tabsContainer: document.getElementById('convTabsPage'),
    targetSel: document.getElementById('convMorphTargetPage'),
    morphPlay: document.getElementById('convMorphPlayPage'),
    cvSubs: document.getElementById('cvSubsPage'),
    cvPts: document.getElementById('cvPtsPage'),
    cvVerdict: document.getElementById('cvVerdictPage'),
    browseBtn: document.getElementById('convBrowsePage'),
  });

  // Expose for debugging and tests
  window._converterPage = pageInstance;
})();
