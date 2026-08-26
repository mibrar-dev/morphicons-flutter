import {
  flattenNodes,
  sanitizeIdentifier,
  serializeOutputs,
  validateSvgMarkup,
} from './converter-core.mjs';

/* ============================================================
   SVG -> Morphicons converter
   Browser adapter for the pure converter-core helpers.
   ============================================================ */

(() => {
  const M = window.MorphCore;

  const input = document.getElementById('convInput');
  const runBtn = document.getElementById('convRun');
  const sampleBtn = document.getElementById('convSample');
  const dropZone = document.getElementById('convDrop');
  const fileInput = document.getElementById('convFile');
  const status = document.getElementById('convStatus');
  const preview = document.getElementById('convPreview');
  const nameInput = document.getElementById('convName');
  const outCode = document.getElementById('convOut');
  const copyBtn = document.getElementById('convCopy');
  const downloadBtn = document.getElementById('convDownload');
  const tabs = document.querySelectorAll('.conv-tabs .seg-btn');
  const targetSel = document.getElementById('convMorphTarget');
  const morphPlay = document.getElementById('convMorphPlay');
  const cvSubs = document.getElementById('cvSubs');
  const cvPts = document.getElementById('cvPts');
  const cvVerdict = document.getElementById('cvVerdict');

  const SAMPLE = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <circle cx="12" cy="12" r="9"/>
  <polyline points="12 7 12 12 15.5 13.5"/>
</svg>`;

  let currentD = '';
  let currentPoints = [];
  let morphAnim = null;
  let outMode = 'dart';

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
    const viewBox = (svg.getAttribute('viewBox') || '')
      .trim()
      .split(/[\s,]+/)
      .map(Number);
    return { ...result, viewBox: viewBox.length === 4 && viewBox.every(Number.isFinite) ? viewBox : null };
  }

  function drawD(canvas, d, color) {
    const rect = canvas.getBoundingClientRect();
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    canvas.width = Math.max(1, Math.round(rect.width * dpr));
    canvas.height = Math.max(1, Math.round(rect.height * dpr));
    const ctx = canvas.getContext('2d');
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    if (!d) return;

    const pad = 0.08;
    const scale = (Math.min(canvas.width, canvas.height) / 24) * (1 - 2 * pad);
    ctx.save();
    ctx.translate((canvas.width - 24 * scale) / 2, (canvas.height - 24 * scale) / 2);
    ctx.scale(scale, scale);
    ctx.strokeStyle = color;
    ctx.lineWidth = 2;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    try {
      ctx.stroke(new Path2D(d));
    } catch (error) {
      status.textContent = `Could not render the flattened path: ${error.message}`;
    }
    ctx.restore();
  }

  function drawSubsOnPreview(subs, color) {
    const rect = preview.getBoundingClientRect();
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    preview.width = Math.max(1, Math.round(rect.width * dpr));
    preview.height = Math.max(1, Math.round(rect.height * dpr));
    const ctx = preview.getContext('2d');
    ctx.clearRect(0, 0, preview.width, preview.height);
    const scale = (Math.min(preview.width, preview.height) / 24) * 0.84;
    const ox = (preview.width - 24 * scale) / 2;
    const oy = (preview.height - 24 * scale) / 2;
    ctx.strokeStyle = color;
    ctx.lineWidth = 2 * (preview.width / 480);
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    for (const pts of subs) {
      const n = pts.length / 2;
      if (n < 2) continue;
      ctx.beginPath();
      ctx.moveTo(ox + pts[0] * scale, oy + pts[1] * scale);
      for (let i = 1; i < n; i++) ctx.lineTo(ox + pts[2 * i] * scale, oy + pts[2 * i + 1] * scale);
      ctx.stroke();
    }
  }

  function resetAssessment() {
    currentPoints = [];
    cvSubs.textContent = '—';
    cvPts.textContent = '—';
    cvVerdict.textContent = '—';
    cvVerdict.style.color = '';
    morphPlay.disabled = true;
  }

  function assess() {
    resetAssessment();
    if (!currentD) return null;
    try {
      const sampled = M.resampleIcon(currentD);
      currentPoints = sampled.map(({ pts }) => Array.from(pts));
      const pointCount = currentPoints.reduce((total, points) => total + points.length / 2, 0);
      cvSubs.textContent = String(currentPoints.length);
      cvPts.textContent = String(pointCount);
      cvVerdict.textContent = 'morph-ready';
      cvVerdict.style.color = '#346538';
      morphPlay.disabled = !targetSel.value;
      return sampled;
    } catch (error) {
      cvVerdict.textContent = 'parse error';
      cvVerdict.style.color = '#9F2F2D';
      status.textContent = `Could not parse the flattened path: ${error.message}`;
      return null;
    }
  }

  function renderOutput() {
    if (!currentD) return;
    const outputs = serializeOutputs({ id: sanitizeIdentifier(nameInput.value), d: currentD, points: currentPoints });
    outCode.textContent = outputs[outMode];
  }

  function clearConversion(message) {
    currentD = '';
    resetAssessment();
    drawD(preview, '');
    outCode.textContent = '// No stroke geometry found in this SVG.';
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
      cvVerdict.textContent = 'parse error';
      cvVerdict.style.color = '#9F2F2D';
      return;
    }

    const doc = new DOMParser().parseFromString(svgText, 'image/svg+xml');
    const parserError = doc.querySelector('parsererror');
    const svg = doc.documentElement;
    if (parserError || !svg || svg.tagName.toLowerCase() !== 'svg') {
      clearConversion('That is not valid SVG markup.');
      cvVerdict.textContent = 'parse error';
      cvVerdict.style.color = '#9F2F2D';
      return;
    }

    const { d, notes, viewBox, elementCount } = flatten(svg);
    if (!d) {
      clearConversion('No stroke geometry found. ' + (notes.join(' · ') || 'Add path/line/circle/rect elements.'));
      cvVerdict.textContent = 'nothing to morph';
      cvVerdict.style.color = '#9F2F2D';
      return;
    }

    currentD = d;
    let message = `Flattened ${elementCount} element${elementCount === 1 ? '' : 's'}`;
    if (viewBox && (viewBox[2] !== 24 || viewBox[3] !== 24)) {
      message += ` · viewBox is ${viewBox[2]}×${viewBox[3]} — wrap with fitIcon() or rescale`;
    }
    if (notes.length) message += ` · ${notes.join(' · ')}`;
    status.textContent = message;
    drawD(preview, d, '#111111');
    assess();
    renderOutput();
  }

  tabs.forEach((button) => {
    button.addEventListener('click', () => {
      tabs.forEach((item) => item.classList.remove('is-active'));
      button.classList.add('is-active');
      outMode = button.dataset.out;
      renderOutput();
    });
  });

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

  downloadBtn.addEventListener('click', () => {
    if (!currentD) return;
    const outputs = serializeOutputs({ id: sanitizeIdentifier(nameInput.value), d: currentD, points: currentPoints });
    const blob = new Blob([outputs.dart + '\n'], { type: 'text/plain;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement('a');
    anchor.href = url;
    anchor.download = `${sanitizeIdentifier(nameInput.value)}.dart`;
    anchor.click();
    URL.revokeObjectURL(url);
  });

  nameInput.addEventListener('input', renderOutput);
  runBtn.addEventListener('click', () => convert(input.value));
  sampleBtn.addEventListener('click', () => {
    input.value = SAMPLE;
    convert(SAMPLE);
  });
  input.addEventListener('keydown', (event) => {
    if ((event.metaKey || event.ctrlKey) && event.key === 'Enter') convert(input.value);
  });

  function loadFile(file) {
    if (!file) return;
    const reader = new FileReader();
    reader.onload = () => {
      input.value = String(reader.result);
      const base = file.name.replace(/\.svg$/i, '').replace(/[^A-Za-z0-9]+/g, '_');
      nameInput.value = sanitizeIdentifier(base);
      convert(input.value);
    };
    reader.onerror = () => clearConversion('Could not read that local SVG file.');
    reader.readAsText(file);
  }

  fileInput.addEventListener('change', () => loadFile(fileInput.files[0]));
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

  const BUILT_IN = [
    ['menu', 'M4 6L20 6M4 12L20 12M4 18L20 18'],
    ['x', 'M18 6L6 18M6 6L18 18'],
    ['check', 'M20 6L9 17L4 12'],
    ['plus', 'M5 12L19 12M12 5L12 19'],
    ['arrow-right', 'M5 12L19 12M12 5L19 12L12 19'],
    ['square', 'M5 5L19 5L19 19L5 19Z'],
    ['circle', 'M12 2A10 10 0 1 0 12 22A10 10 0 1 0 12 2Z'],
  ];
  BUILT_IN.forEach(([name, d]) => {
    const option = document.createElement('option');
    option.value = d;
    option.textContent = name;
    targetSel.appendChild(option);
  });
  targetSel.addEventListener('change', () => { morphPlay.disabled = !targetSel.value || !currentD; });

  let previewVisible = true;
  if ('IntersectionObserver' in window) {
    const io = new IntersectionObserver((entries) => {
      previewVisible = entries[0].isIntersecting;
    }, { threshold: 0.12 });
    io.observe(preview);
  }
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) previewVisible = false;
    else previewVisible = true;
  });

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
      drawSubsOnPreview(out, '#111111');
      if (!settled) morphAnim = requestAnimationFrame(tick);
      else morphAnim = null;
    };
    tick();
  });

  window.addEventListener('resize', () => { if (currentD) drawD(preview, currentD, '#111111'); });
})();
