// Dumps alignment/interpolation fixtures from the morphicons core for the
// Flutter port's golden tests. Run from reference/: bun dump_fixtures.mjs
import { writeFileSync } from "node:fs";
import { resampleIcon } from "./morphicons/src/core/resample.ts";
import { buildPlan, centroid, procrustes } from "./morphicons/src/core/plan.ts";
import { allocOutputs, interpPolar } from "./morphicons/src/core/interpolate.ts";
import { serialize } from "./morphicons/src/core/serialize.ts";

const N = 64;
const TS = [0, 0.25, 0.5, 0.75, 1];

// lucide-style d strings (24x24)
const ICONS = {
  menu: "M4 6H20M4 12H20M4 18H20",
  x: "M18 6L6 18M6 6l12 12",
  "arrow-right": "M5 12h14M12 5l7 7-7 7",
  "arrow-down": "M12 5v14M19 12l-7 7-7-7",
  check: "M20 6L9 17l-5-5",
  plus: "M12 5v14M5 12h14",
  minus: "M5 12h14",
};

const PAIRS = [
  ["menu", "x"],
  ["arrow-right", "arrow-down"],
  ["check", "x"],
  ["plus", "minus"],
];

const arr = (f) => Array.from(f, (v) => Math.round(v * 1e6) / 1e6);

const fixtures = {};
for (const [from, to] of PAIRS) {
  const src = resampleIcon(ICONS[from], N);
  const dst = resampleIcon(ICONS[to], N);
  const plan = buildPlan(src, dst);
  const outs = allocOutputs(plan);

  const global = { from: [], to: [] };
  for (const it of plan.items) {
    global.from.push(it.a);
    global.to.push(it.bO);
  }
  const gFrom = new Float64Array(2 * N * plan.items.length);
  const gTo = new Float64Array(2 * N * plan.items.length);
  global.from.forEach((p, k) => gFrom.set(p, 2 * N * k));
  global.to.forEach((p, k) => gTo.set(p, 2 * N * k));
  const g = procrustes(gFrom, gTo, centroid(gFrom), centroid(gTo));

  const frames = {};
  for (const t of TS) {
    interpPolar(plan, t, outs);
    frames[String(t)] = outs.map((o, k) => serialize([o], [plan.items[k].closed]));
  }

  fixtures[`${from}<->${to}`] = {
    from,
    to,
    d: { from: ICONS[from], to: ICONS[to] },
    n: plan.n,
    global: {
      theta: g.theta,
      sigma: g.sigma,
      residual: g.res,
      blockHybridApplied: g.res < 5e-3 && plan.items.length > 1,
    },
    subpaths: plan.items.map((it, idx) => ({
      index: idx,
      closed: it.closed,
      from: arr(it.a),
      to: arr(it.bO),
      theta: it.theta,
      sigma: Math.exp(it.lnSigma),
      residual: it.res,
      ca: arr(it.ca),
      cb: arr(it.cb),
      block: it.block
        ? { off: arr(it.block.off), drift: arr(it.block.drift) }
        : null,
    })),
    frames,
  };
}

const out = {
  generatedBy: "reference/dump_fixtures.mjs",
  n: N,
  ts: TS,
  pairs: fixtures,
};
writeFileSync(new URL("./fixtures.json", import.meta.url), JSON.stringify(out, null, 2));
console.log("wrote fixtures.json:", Object.keys(fixtures).join(", "));
