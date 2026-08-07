# Morphicons for Flutter

Similarity-aware icon morphing for Flutter — a faithful Dart port of
[morphicons](https://github.com/guillermolg00/morphicons) (MIT, by Guillermo).

Morphicons is not a shape-tween library. It is a **similarity-transform
solver**: for any two stroke icons it decides automatically whether the
transition is a rotation, a scale, a plain morph, or a mix — then interpolates
in polar/similarity space so rigid shapes stay rigid mid-flight (an arrow
rotates as an arrow; it never shrinks through its own chord).

## Packages

| Package | What it is |
|---|---|
| [`morphicons_core`](packages/morphicons_core) | Pure-Dart solver: SVG `d` parser, cubic normalizer, arc-length resampling (N=64, corner-anchored), correspondence search, 2D closed-form Procrustes, polar interpolation + block transport, plan cache, spring physics. **No Flutter dependency.** |
| [`morphicons_flutter`](packages/morphicons_flutter) | `MorphIcon` widget (uncontrolled / controlled / imperative), shared `Ticker` scheduler, `CustomPainter` paint driver with canonical snap on settle. |
| [`morphicons_lucide`](packages/morphicons_lucide) | 1500+ Lucide icons as plain Dart `const` `d` strings, generated from the npm `lucide` package. |
| [`morphicons_example`](packages/morphicons_example) | Playground: icon grid, spring picker, t-scrubber, θ/σ/residual readout. |

## Quick start

```dart
import 'package:morphicons_flutter/morphicons_flutter.dart';
import 'package:morphicons_lucide/morphicons_lucide.dart';

// Uncontrolled — change `icon`, the morph animates.
MorphIcon(icon: isOpen ? MorphIconsLucide.x : MorphIconsLucide.menu,
          spring: SpringPreset.snappy)

// Controlled — explicit progress, e.g. driven by a drag gesture.
MorphIcon.controlled(from: MorphIconsLucide.menu, to: MorphIconsLucide.x,
                     progress: dragProgress)

// Imperative — sequenced morphs via state.
final key = GlobalKey<MorphIconState>();
MorphIcon(key: key, icon: MorphIconsLucide.menu);
key.currentState?.morphTo(MorphIconsLucide.check); // animates
key.currentState?.set(MorphIconsLucide.x);         // jumps, no animation
```

## The pipeline (mirrors upstream `core → dom → react`)

1. **Normalize** every SVG primitive to cubic Bézier subpaths (`parsePath`, `iconToCubics`, `fitIcon`).
2. **Resample** each subpath to N=64 arc-length-equidistant points (8-point Gauss–Legendre quadrature); corners are anchored as exact sample indices so they stay sharp.
3. **Correspondence**: both traversal directions, all circular start rotations, subpath matching by `dist(centroids) + 0.35·|ΔL|` (exact ≤8 subpaths, greedy above); unequal counts duplicate the nearest subpath.
4. **2D Procrustes** (closed form, no SVD) per subpath + a global hybrid pass so rigid icons rotate as one block.
5. **Polar interpolation**: `translation + rotation(t·θ*) + scale(σ*ᵗ)` on the residual — never raw x/y lerp.
6. **Block transport** so off-center subpaths ride the global rotation instead of sagging along their chord.
7. **Spring physics**: semi-implicit Euler at 1/240 s, presets `smooth (k=170,c=26)`, `snappy (k=420,c=30)`, `bouncy (k=300,c=14)`; mid-flight interruptions re-plan from the current shape with preserved velocity.
8. **Canonical snap**: at settle the painter emits the exact target icon paths — a resting morph is indistinguishable from a static icon.

## Numeric parity with the JS reference

The core is validated against golden fixtures dumped from the actual upstream
implementation (`reference/fixtures.json`):

| Stage | Parity result |
|---|---|
| Procrustes θ/σ/residual | ≤ 4.4e-16 (float64 machine epsilon) |
| Resampled point clouds | ≤ 7.3e-15 |
| Interpolated frames (t = 0…1) | byte-exact vs upstream serializer |
| `buildPlan` | 351 µs for a 2-subpath pair (upstream: 0.01–0.42 ms) |

## Zero runtime dependencies

`morphicons_core` uses only `dart:math`/`dart:typed_data`; `morphicons_flutter`
uses only the Flutter SDK. Icon packs are separate, optional packages.

## Regenerating Lucide data

```sh
cd tool && npm install && node extract_icons.mjs
```

## Credits & license

MIT. Algorithm and design: [Guillermo / morphicons](https://github.com/guillermolg00/morphicons)
— this project is a transcription of that mathematics to Dart, not a
re-derivation. See [LICENSE](LICENSE).
