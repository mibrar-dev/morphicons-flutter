import test from 'node:test';
import assert from 'node:assert/strict';

import {
  flattenNodes,
  escapeDart,
  sanitizeIdentifier,
  serializeOutputs,
  validateSvgMarkup,
} from '../converter-core.mjs';

const fixtures = {
  line: '<svg><line x1="2" y1="3" x2="20" y2="21"/></svg>',
  circle: '<svg><circle cx="12" cy="12" r="9"/></svg>',
  roundedRect: '<svg><rect x="3" y="3" width="18" height="18" rx="2"/></svg>',
  polygon: '<svg><polygon points="12,2 22,22 2,22"/></svg>',
  malformed: '<svg><path></svg>',
  unsupported: '<svg><text>Hello</text></svg>',
};

test('flattens line, circle, rounded rect, and polygon nodes', () => {
  const result = flattenNodes([
    ['line', { x1: '2', y1: '3', x2: '20', y2: '21' }],
    { tag: 'circle', attrs: { cx: '12', cy: '12', r: '9' } },
    { tag: 'rect', attrs: { x: '3', y: '3', width: '18', height: '18', rx: '2' } },
    { tag: 'polygon', attrs: { points: '12,2 22,22 2,22' } },
  ]);

  assert.equal(result.elementCount, 4);
  assert.match(result.d, /M0 0M2 3L20 21/);
  assert.match(result.d, /A9 9 0 1 0 21 12/);
  assert.match(result.d, /a2 2 0 0 1 2 2/);
  assert.match(result.d, /M0 0M12 2L22 22L2 22Z/);
  assert.deepEqual(result.notes, []);
});

test('flattens paths, polylines, ellipses, and records unsupported nodes', () => {
  const result = flattenNodes([
    { tag: 'path', attrs: { d: 'm1 2 3 4' } },
    { tag: 'polyline', attrs: { points: '1 2 3,4 5 6' } },
    { tag: 'ellipse', attrs: { cx: '8', cy: '9', rx: '4', ry: '2' } },
    { tag: 'text', attrs: {} },
    { tag: 'unknown', attrs: {} },
  ]);

  assert.equal(result.elementCount, 3);
  assert.match(result.d, /M0 0m1 2 3 4/);
  assert.match(result.d, /M0 0M1 2L3 4L5 6/);
  assert.match(result.d, /M0 0M4 9A4 2 0 1 0 12 9/);
  assert.ok(result.notes.some((note) => note.includes('<text>')));
  assert.ok(result.notes.some((note) => note.includes('<unknown>')));
});

test('flags transforms and fills without dropping supported geometry', () => {
  const result = flattenNodes([
    {
      tag: 'line',
      attrs: { x1: '0', y1: '0', x2: '1', y2: '1', transform: 'rotate(45)', fill: 'red' },
    },
  ]);

  assert.equal(result.elementCount, 1);
  assert.ok(result.notes.some((note) => note.includes('transform')));
  assert.ok(result.notes.some((note) => note.includes('fill="red"')));
});

test('sanitizes identifiers and escapes Dart string content', () => {
  assert.equal(sanitizeIdentifier('2 weather-icon'), 'icon2_weather_icon');
  assert.equal(sanitizeIdentifier('class'), 'classIcon');
  assert.equal(sanitizeIdentifier(''), 'myIcon');
  assert.equal(escapeDart('M1 2\\"quoted"'), 'M1 2\\\\\\"quoted\\"');
});

test('serializes Dart, map, raw, and sampled points outputs', () => {
  const outputs = serializeOutputs({
    id: 'weatherIcon',
    d: 'M1 2L3 4',
    points: [[[1, 2, 3, 4]]],
  });

  assert.equal(outputs.dart, 'static const String weatherIcon = "M1 2L3 4";');
  assert.equal(outputs.map, '  "weatherIcon": MorphIconsCustom.weatherIcon,');
  assert.equal(outputs.raw, 'M1 2L3 4');
  assert.equal(outputs.points, '[\n  [\n    [\n      1,\n      2,\n      3,\n      4\n    ]\n  ]\n]');
});

test('reports malformed SVG markup clearly', () => {
  assert.match(validateSvgMarkup(fixtures.malformed), /closing tag|unclosed/i);
  assert.equal(validateSvgMarkup(fixtures.line), null);
  assert.equal(validateSvgMarkup('<?xml version="1.0"?><svg></svg>'), null);
});

test('classifies unsupported-only input as nothing to morph', () => {
  const result = flattenNodes([{ tag: 'text', attrs: { text: 'Hello' } }]);

  assert.equal(result.d, '');
  assert.equal(result.elementCount, 0);
  assert.ok(result.notes.some((note) => note.includes('<text>')));
});
