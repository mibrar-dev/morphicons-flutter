# Morphicons for Flutter

Morph any icon into any other — `String d` or `IconData` with the same widget, same solver. A Dart port of [morphicons](https://github.com/guillermolg00/morphicons) (MIT).

If a pair is congruent under rotation, it rotates; if not, it morphs. No groups, no keyframes. Zero dependencies.

[![pub.dev](https://img.shields.io/pub/v/morphicons_flutter)](https://pub.dev/packages/morphicons_flutter) [![License: MIT](https://img.shields.io/badge/license-MIT-black.svg)](LICENSE) [![Website](https://img.shields.io/badge/website-morphicons--flutter-blue.svg)](https://mibrar-dev.github.io/morphicons-flutter/)

**Live demo:** https://mibrar-dev.github.io/morphicons-flutter/ — every icon on the page morphs with this exact library.

## Install

```sh
flutter pub add morphicons_flutter
```

Fully standalone — solver included, works with raw SVG path data or **any** `IconData` from any package.

## Use

```dart
import 'package:flutter/material.dart';
import 'package:morphicons_flutter/morphicons_flutter.dart';

// 1. Uncontrolled — change `icon`, it animates.
MorphIcon(icon: isOpen ? Icons.close : Icons.menu)

// Any IconData, any package:
MorphIcon(icon: isHome ? Icons.home : Icons.favorite)

// Raw SVG path data (24×24 stroke grammar):
MorphIcon(icon: isOpen ? 'M18 6L6 18M6 6L18 18' : 'M4 6h16M4 12h16M4 18h16')

// 2. Controlled — explicit progress, e.g. driven by a drag gesture.
MorphIcon.controlled(
  from: Icons.menu,
  icon: Icons.close,
  progress: dragProgress, // 0..1, >1 extrapolates
)

// 3. Imperative — sequenced morphs.
final key = GlobalKey<MorphIconState>();
MorphIcon(key: key, icon: Icons.menu);
key.currentState?.morphTo(Icons.check); // animates
key.currentState?.set(Icons.close);     // jumps, no animation

// Typed factories reject the other kind at compile time.
MorphIcon.svg(icon: 'M18 6L6 18');
MorphIcon.font(icon: Icons.home);
```

Mask a child with the same geometry:

```dart
MorphMask(icon: Icons.favorite, child: DecoratedBox(
  decoration: BoxDecoration(gradient: LinearGradient(
    colors: [Color(0xfff857a6), Color(0xffff5858)])),
  child: const SizedBox(width: 220, height: 150),
))
```

More: `MorphCanvas`, `MorphTween`, `MorphPair` (`menu.morphTo(x)`), `String` helpers.

## Behavior

- Filled (font glyphs) and stroked (SVG paths) share one solver and one ticker.
- First frame paints the exact canonical shape — no async warm-up, no flash.
- Canonical snap on settle: a resting icon is pixel-identical to a static one.
- `MediaQuery.disableAnimations` → instant swap (reduced motion).
- Interruptions re-plan from the current shape with velocity preserved.

Full pipeline, parity numbers and icon-set compatibility: [DOCS.md](DOCS.md).

## License

MIT — algorithm and design credit: [Guillermo / morphicons](https://github.com/guillermolg00/morphicons). See [LICENSE](LICENSE).
