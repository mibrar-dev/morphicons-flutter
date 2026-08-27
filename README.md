# Morphicons for Flutter

Morph any SVG icon into any other. Similarity-aware morphing for Flutter — a Dart port of [morphicons](https://github.com/guillermolg00/morphicons) (MIT, by Guillermo).

If a pair is congruent under rotation, it rotates; if not, it morphs in the aligned frame. No keyframes. No hand-declared correspondence. Zero dependencies.

[![pub.dev](https://img.shields.io/pub/v/morphicons_flutter)](https://pub.dev/packages/morphicons_flutter)
[![License: MIT](https://img.shields.io/badge/license-MIT-black.svg)](LICENSE)

## Install

```sh
flutter pub add morphicons_flutter
flutter pub add morphicons_lucide # optional, 1500+ icons
```

Or `dart pub add morphicons_core` for the pure-Dart solver (no Flutter).

## Use

```dart
import 'package:morphicons_flutter/morphicons_flutter.dart';
import 'package:morphicons_lucide/morphicons_lucide.dart';

// Uncontrolled — swap `icon`, it animates.
MorphIcon(icon: isOpen ? MorphIconsLucide.x : MorphIconsLucide.menu)

// Controlled — drive `progress` yourself (drag, scrub, etc.)
MorphIcon.controlled(
  from: MorphIconsLucide.menu,
  icon: MorphIconsLucide.x,
  progress: t, // 0..1
)

// Imperative
final key = GlobalKey<MorphIconState>();
MorphIcon(key: key, icon: MorphIconsLucide.menu);
key.currentState?.morphTo(MorphIconsLucide.check);
```

Mask a child with the same geometry:

```dart
MorphMask(icon: MorphIconsLucide.heart, child: DecoratedBox(
  decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xfff857a6), Color(0xffff5858)])),
  child: SizedBox(width: 220, height: 150),
))
```

More: `MorphCanvas`, `MorphTween`, `MorphPair` (`menu.morphTo(x)`), and `String` helpers. See [DOCS.md](DOCS.md) and the [live site](https://mibrar-dev.github.io/morphicons-flutter/).

## How it works

Optimal similarity via 2D Procrustes in closed form, polar interpolation, spring physics. Validated against the upstream JS at float64 parity (θ/σ ≤4.4e-16). Details and the full pipeline in [DOCS.md](DOCS.md).

## License

MIT. Algorithm & design credit: [Guillermo / morphicons](https://github.com/guillermolg00/morphicons). See [LICENSE](LICENSE).
