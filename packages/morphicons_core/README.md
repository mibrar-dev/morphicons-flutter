# morphicons_core

Pure-Dart core of [Morphicons](https://github.com/infinora/morphicons_flutter):
the similarity-transform solver behind similarity-aware icon morphing. A
faithful port of the [morphicons](https://github.com/guillermolg00/morphicons)
core — Flutter-free by design, unit-testable on the plain Dart VM.

## What's inside

- `parsePath` — full SVG `d` mini-language (relative commands, `H/V/S/T`
  shorthands, packed arc flags, exponent notation).
- `iconToCubics` / `fitIcon` — normalize `line`, `circle`, `ellipse`, `rect`,
  `polyline`, `polygon`, arcs to cubic Bézier chains; re-grid foreign viewBox
  icons onto 24×24.
- `resampleIcon` — N=64 arc-length-equidistant sampling (8-point
  Gauss–Legendre quadrature) with exact corner anchoring.
- `pairSubpaths` — correspondence: direction + circular-offset search,
  subpath matching by `dist(centroids) + 0.35·|ΔL|`.
- `procrustes` / `applyGlobal` — 2D closed-form similarity solve, per-subpath
  + global hybrid with block transport.
- `buildPlan` / `interpPolar` / `serialize` — plan building with an
  `Expando`-based identity cache, polar interpolation, polyline serialization.
- `Spring` — semi-implicit Euler integrator (1/240 s substeps) with the
  `smooth`/`snappy`/`bouncy` presets and interruption-safe re-planning.

## Zero dependencies

`dart:math` and `dart:typed_data` only — nothing else.

## Numeric parity

Validated against golden fixtures dumped from the upstream JS implementation:
Procrustes θ/σ/residual to 4.4e-16, resampled clouds to 7.3e-15, interpolated
frames byte-exact against the upstream serializer. See the repository README
for the full table.

## License

MIT — algorithm and design credit: [Guillermo / morphicons](https://github.com/guillermolg00/morphicons).
