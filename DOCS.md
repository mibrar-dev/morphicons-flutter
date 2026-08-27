# Morphicons for Flutter — Detailed Documentation

> **This is the comprehensive guide.** For the quick start, see [README.md](README.md).

A faithful Dart port of [morphicons](https://github.com/guillermolg00/morphicons) (MIT, by Guillermo) — a similarity-transform solver, not a shape-tween library. For any two stroke icons it decides whether the transition is a rotation, a scale, a plain morph, or a mix, then interpolates in polar/similarity space so rigid shapes stay rigid mid-flight.

---

## Packages

| Package | What it is |
|---|---|
| [`morphicons_core`](packages/morphicons_core) | Pure-Dart solver: SVG `d` parser, cubic normalizer, arc-length resampling (N=64, corner-anchored), correspondence search, 2D closed-form Procrustes, polar interpolation + block transport, plan cache, spring physics. **No Flutter dependency.** |
| [`morphicons_flutter`](packages/morphicons_flutter) | `MorphIcon` widget (uncontrolled / controlled / imperative), `MorphMask`, `MorphCanvas`, `MorphTween`, `MorphPair`, `String` extensions, shared `Ticker` scheduler, `CustomPainter` with canonical snap. |
| [`morphicons_lucide`](packages/morphicons_lucide) | 1500+ Lucide icons as plain Dart `const` `d` strings, generated from the npm `lucide` package. |
| [`morphicons_example`](packages/morphicons_example) | Playground: icon grid, spring picker, t-scrubber, θ/σ/residual readout. |
| [`morphicons_site_demo`](packages/morphicons_site_demo) | Flutter Web demo embedded in the static site (`website/flutter`). |

---

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

---

## More widgets & helpers

`morphicons_flutter` exports `MorphCanvas`, `MorphMask`, `MorphTween`, `MorphPair`, and `String` helpers in addition to `MorphIcon`.

### MorphCanvas / MorphCanvasPainter

```dart
// Animated — owns its own ticker.
MorphCanvas(
  icon: isOpen ? MorphIconsLucide.x : MorphIconsLucide.menu,
  spring: SpringPreset.snappy,
  size: 48,
)

// Controlled — no ticker, progress supplied from outside.
MorphCanvas.controlled(
  from: MorphIconsLucide.menu,
  icon: MorphIconsLucide.x,
  progress: dragProgress,
)

// Or paint directly inside your own CustomPaint widget.
CustomPaint(
  size: const Size.square(48),
  painter: MorphCanvasPainter.controlled(
    from: MorphIconsLucide.menu,
    to: MorphIconsLucide.x,
    progress: 0.5,
  ),
)
```

### MorphMask

```dart
// Mask a child with a morphing stroke icon.
MorphMask(
  icon: MorphIconsLucide.x,
  child: Image.asset('photo.jpg', fit: BoxFit.cover),
)

// Controlled mask.
MorphMask.controlled(
  from: MorphIconsLucide.menu,
  icon: MorphIconsLucide.x,
  progress: dragProgress,
  child: child,
)
```

`MorphMask` composites through a clipped path derived from the stroked outline (union of thick rects + round caps) and is best suited to small interactive surfaces rather than large grids.

### MorphTween

```dart
final tween = MorphTween(from: MorphIconsLucide.menu, to: MorphIconsLucide.x);
final mid = tween.transform(0.5); // polar-interpolated d string
final end = tween.transform(1);   // exact canonical target
```

### MorphPair and readable helpers

```dart
final pair = MorphIconsLucide.menu.morphTo(MorphIconsLucide.x);
// or the short alias:
final pair = MorphIconsLucide.menu.morph(MorphIconsLucide.x);

// Build controlled widgets from the pair:
pair.icon(progress: 0.5);
pair.canvas(progress: 0.5);
pair.mask(progress: 0.5, child: child);

// Ticker-free d-string interpolator:
final tween = pair.tween();
```

### Explicit `String` helpers

```dart
MorphIconsLucide.menu.morphCanvasTo(MorphIconsLucide.x, progress: 0.5);
MorphIconsLucide.menu.morphMaskTo(
  MorphIconsLucide.x,
  progress: 0.5,
  child: child,
);
```

All `controlled` constructors and helpers are state-management-neutral: they receive `progress` directly and do not start a ticker, so they work with `setState`, `AnimatedBuilder`, or any external controller.

---

## The pipeline (mirrors upstream `core → dom → react`)

1. **Normalize** every SVG primitive to cubic Bézier subpaths (`parsePath`, `iconToCubics`, `fitIcon`).
2. **Resample** each subpath to N=64 arc-length-equidistant points (8-point Gauss–Legendre quadrature); corners are anchored as exact sample indices so they stay sharp.
3. **Correspondence**: both traversal directions, all circular start rotations, subpath matching by `dist(centroids) + 0.35·|ΔL|` (exact ≤8 subpaths, greedy above); unequal counts duplicate the nearest subpath.
4. **2D Procrustes** (closed form, no SVD) per subpath + a global hybrid pass so rigid icons rotate as one block.
5. **Polar interpolation**: `translation + rotation(t·θ*) + scale(σ*ᵗ)` on the residual — never raw x/y lerp.
6. **Block transport** so off-center subpaths ride the global rotation instead of sagging along their chord.
7. **Spring physics**: semi-implicit Euler at 1/240 s, presets `smooth (k=170,c=26)`, `snappy (k=420,c=30)`, `bouncy (k=300,c=14)`; mid-flight interruptions re-plan from the current shape with preserved velocity.
8. **Canonical snap**: at settle the painter emits the exact target icon paths — a resting morph is indistinguishable from a static icon.

---

## Numeric parity with the JS reference

Validated against golden fixtures dumped from the upstream implementation (`reference/fixtures.json`):

| Stage | Parity result |
|---|---|
| Procrustes θ/σ/residual | ≤ 4.4e-16 (float64 machine epsilon) |
| Resampled point clouds | ≤ 7.3e-15 |
| Interpolated frames (t = 0…1) | byte-exact vs upstream serializer |
| `buildPlan` | 351 µs for a 2-subpath pair (upstream: 0.01–0.42 ms) |

---

## Zero runtime dependencies

`morphicons_core` uses only `dart:math`/`dart:typed_data`; `morphicons_flutter` uses only the Flutter SDK. Icon packs are separate, optional packages.

---

## Regenerating Lucide data

```sh
cd tool && npm install && node extract_icons.mjs
```

---

## Website

From the repository root, build the Flutter iframe from its package directory, then serve the static site:

```sh
cd packages/morphicons_site_demo
flutter build web --release --base-href /flutter/ -o ../../website/flutter
cd ../..
python3 -m http.server 8765 --directory website
```

Open <http://127.0.0.1:8765/> in a browser. The browser-local SVG converter keeps processing on-device and provides four outputs: a Dart `const`, a ready-to-paste map entry, the raw SVG `d` string, and the sampled points used for morphing.

For GitHub Pages (`https://mibrar-dev.github.io/morphicons-flutter/`), the same build runs with `--base-href /morphicons-flutter/flutter/` in CI (`.github/workflows/pages.yml` deploys `website/` to `gh-pages`).

---

## Credits & license

MIT. Algorithm and design: [Guillermo / morphicons](https://github.com/guillermolg00/morphicons) — this project is a transcription of that mathematics to Dart, not a re-derivation. See [LICENSE](LICENSE).
