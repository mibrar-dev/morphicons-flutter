## 1.0.0

- Stable 1.0.0 release, ready for pub.dev.
- Full SVG `d` parser (relative commands, shorthands, packed arc flags).
- Cubic normalizer for `line`, `circle`, `ellipse`, `rect`, `polyline`,
  `polygon` and arcs, plus `fitIcon` re-gridding onto 24×24.
- N=64 arc-length resampling (Gauss–Legendre quadrature) with exact corner
  anchoring.
- Subpath correspondence (direction + circular-offset search, centroid/length
  matching, nearest-subpath duplication).
- 2D closed-form Procrustes per subpath + global hybrid with block transport.
- Polar interpolation, polyline serialization, `buildPlan` with `Expando`
  identity cache.
- Spring integrator (semi-implicit Euler, 1/240 s) with `smooth`, `snappy`,
  `bouncy` presets and interruption-safe re-planning.
- Numeric parity against the upstream morphicons JS implementation:
  Procrustes 4.4e-16, resampling 7.3e-15, frames byte-exact.

## 0.1.0

- Initial prerelease.
