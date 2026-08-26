const DART_KEYWORDS = new Set([
  'assert', 'break', 'case', 'catch', 'class', 'const', 'continue', 'default',
  'do', 'else', 'enum', 'extends', 'false', 'final', 'finally', 'for', 'if',
  'in', 'is', 'new', 'null', 'rethrow', 'return', 'super', 'switch', 'this',
  'throw', 'true', 'try', 'var', 'void', 'while', 'with',
]);

const SUPPORTED_TAGS = new Set([
  'path', 'line', 'circle', 'ellipse', 'rect', 'polyline', 'polygon',
]);

function attr(attrs, name) {
  if (!attrs) return undefined;
  if (typeof attrs.get === 'function') return attrs.get(name);
  return attrs[name];
}

function number(value, fallback = 0) {
  if (value === undefined || value === null || value === '') return fallback;
  const result = Number(value);
  return Number.isFinite(result) ? result : fallback;
}

function parseNumbers(value) {
  if (!value) return [];
  const matches = String(value).match(/[+-]?(?:\d+\.?\d*|\.\d+)(?:e[+-]?\d+)?/gi) || [];
  return matches.map(Number).filter(Number.isFinite);
}

function circleToPath(attrs) {
  const cx = number(attr(attrs, 'cx'));
  const cy = number(attr(attrs, 'cy'));
  const r = number(attr(attrs, 'r'));
  if (r <= 0) return null;
  return `M${cx - r} ${cy}A${r} ${r} 0 1 0 ${cx + r} ${cy}A${r} ${r} 0 1 0 ${cx - r} ${cy}`;
}

function ellipseToPath(attrs) {
  const cx = number(attr(attrs, 'cx'));
  const cy = number(attr(attrs, 'cy'));
  const rx = number(attr(attrs, 'rx'));
  const ry = number(attr(attrs, 'ry'));
  if (rx <= 0 || ry <= 0) return null;
  return `M${cx - rx} ${cy}A${rx} ${ry} 0 1 0 ${cx + rx} ${cy}A${rx} ${ry} 0 1 0 ${cx - rx} ${cy}`;
}

function lineToPath(attrs) {
  return `M${number(attr(attrs, 'x1'))} ${number(attr(attrs, 'y1'))}L${number(attr(attrs, 'x2'))} ${number(attr(attrs, 'y2'))}`;
}

function pointsToPath(attrs, close) {
  const values = parseNumbers(attr(attrs, 'points'));
  if (values.length < 4) return null;

  let d = `M${values[0]} ${values[1]}`;
  for (let i = 2; i + 1 < values.length; i += 2) {
    d += `L${values[i]} ${values[i + 1]}`;
  }
  if (close) d += 'Z';
  return d;
}

function rectToPath(attrs) {
  const x = number(attr(attrs, 'x'));
  const y = number(attr(attrs, 'y'));
  const width = number(attr(attrs, 'width'));
  const height = number(attr(attrs, 'height'));
  if (width <= 0 || height <= 0) return null;

  let rx = number(attr(attrs, 'rx'), Number.NaN);
  let ry = number(attr(attrs, 'ry'), Number.NaN);
  if (Number.isNaN(rx) && Number.isNaN(ry)) {
    rx = 0;
    ry = 0;
  } else if (Number.isNaN(ry)) {
    ry = rx;
  } else if (Number.isNaN(rx)) {
    rx = ry;
  }
  rx = Math.min(Math.max(0, rx), width / 2);
  ry = Math.min(Math.max(0, ry), height / 2);

  if (rx === 0 || ry === 0) return `M${x} ${y}h${width}v${height}h${-width}Z`;
  return `M${x + rx} ${y}h${width - 2 * rx}` +
    `a${rx} ${ry} 0 0 1 ${rx} ${ry}v${height - 2 * ry}` +
    `a${rx} ${ry} 0 0 1 ${-rx} ${ry}h${-(width - 2 * rx)}` +
    `a${rx} ${ry} 0 0 1 ${-rx} ${-ry}v${-(height - 2 * ry)}` +
    `a${rx} ${ry} 0 0 1 ${rx} ${-ry}Z`;
}

export function elementToPath(tag, attrs = {}) {
  switch (String(tag).toLowerCase()) {
    case 'path': return String(attr(attrs, 'd') || '').trim() || null;
    case 'line': return lineToPath(attrs);
    case 'circle': return circleToPath(attrs);
    case 'ellipse': return ellipseToPath(attrs);
    case 'rect': return rectToPath(attrs);
    case 'polyline': return pointsToPath(attrs, false);
    case 'polygon': return pointsToPath(attrs, true);
    default: return null;
  }
}

function noteForUnsupported(tag) {
  const label = `<${tag}>`;
  if (tag === 'text' || tag === 'image' || tag === 'use' || tag === 'mask' || tag === 'clippath') {
    return `${label} is not supported — Morphicons morphs stroke paths only`;
  }
  return `${label} is not supported — only SVG path geometry is converted`;
}

export function flattenNodes(nodes = []) {
  const ds = [];
  const notes = [];

  for (const node of nodes) {
    const tag = String(Array.isArray(node) ? node[0] : node?.tag || '').toLowerCase();
    const attrs = (Array.isArray(node) ? node[1] : node?.attrs) || {};
    const transform = attr(attrs, 'transform');
    if (transform) notes.push(`<${tag}> has a transform — flatten it first (bake transforms into coordinates)`);

    const container = tag === 'svg' || tag === 'g' || tag === 'defs' || tag === 'symbol';
    if (!SUPPORTED_TAGS.has(tag) && !container) notes.push(noteForUnsupported(tag || 'unknown'));

    const fill = attr(attrs, 'fill');
    if (fill && String(fill).toLowerCase() !== 'none') {
      notes.push(`<${tag}> has fill="${fill}" — fills are ignored, only stroke geometry is kept`);
    }

    if (container) continue;

    const d = elementToPath(tag, attrs);
    if (d) ds.push(`M0 0${d}`);
  }

  return { d: ds.join(' '), notes, elementCount: ds.length };
}

export function sanitizeIdentifier(value) {
  const raw = String(value ?? '').trim() || 'myIcon';
  let id = raw.replace(/[^A-Za-z0-9_]/g, '_').replace(/^_+|_+$/g, '');
  if (!id) id = 'myIcon';
  if (/^[0-9]/.test(id)) id = `icon${id}`;
  if (DART_KEYWORDS.has(id)) id += 'Icon';
  return id;
}

export function escapeDart(value) {
  return String(value).replaceAll('\\', '\\\\').replaceAll('"', '\\"');
}

function jsonReady(value) {
  if (ArrayBuffer.isView(value)) return Array.from(value, jsonReady);
  if (Array.isArray(value)) return value.map(jsonReady);
  return value;
}

export function serializeOutputs({ id, d, points = [] }) {
  const safeId = sanitizeIdentifier(id);
  return {
    dart: `static const String ${safeId} = "${escapeDart(d)}";`,
    map: `  "${safeId}": MorphIconsCustom.${safeId},`,
    raw: d,
    points: JSON.stringify(jsonReady(points), null, 2),
  };
}

export function validateSvgMarkup(markup) {
  const source = String(markup ?? '').trim();
  if (!source) return 'SVG input is empty.';
  const firstElement = source.match(/<([A-Za-z][\w:.-]*)(?:\s|\/?>)/);
  if (!firstElement || firstElement[1].toLowerCase() !== 'svg') {
    return 'SVG input must start with an <svg> element.';
  }

  const stack = [];
  const tokens = source.match(/<!--[\s\S]*?-->|<\?.*?\?>|<![^>]*>|<\/?[A-Za-z][^<>]*>/g) || [];
  for (const token of tokens) {
    if (token.startsWith('<!--') || token.startsWith('<?') || token.startsWith('<!')) continue;
    const closing = /^<\//.test(token);
    const match = token.match(/^<\/?([A-Za-z][\w:.-]*)/);
    if (!match) continue;
    const tag = match[1].toLowerCase();
    const selfClosing = /\/\s*>$/.test(token);
    if (closing) {
      if (stack[stack.length - 1] !== tag) {
        return `Malformed SVG: expected a closing tag for <${stack[stack.length - 1] || tag}> before </${tag}>.`;
      }
      stack.pop();
    } else if (!selfClosing) {
      stack.push(tag);
    }
  }
  if (stack.length) return `Malformed SVG: unclosed <${stack[stack.length - 1]}> element.`;
  return null;
}
