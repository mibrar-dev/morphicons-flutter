# Morphicons for Flutter

Morph any icon into any other — `String d` or `IconData` with the same widget, same solver. A Dart port of [morphicons](https://github.com/guillermolg00/morphicons) (MIT).

If a pair is congruent under rotation, it rotates; if not, it morphs. No groups, no keyframes. Zero dependencies.

[![pub.dev](https://img.shields.io/pub/v/morphicons_flutter)](https://pub.dev/packages/morphicons_flutter) [![License: MIT](https://img.shields.io/badge/license-MIT-black.svg)](LICENSE)

## Install

```sh
flutter pub add morphicons_flutter
# optional packs (1500 Lucide, 4761 Tabler, 1288 Heroicons) or use any IconData directly
flutter pub add morphicons_lucide
```

`dart pub add morphicons_core` for the pure-Dart solver.

## Use

```dart
import 'package:morphicons_flutter/morphicons_flutter.dart';
import 'package:morphicons_lucide/morphicons_lucide.dart';

// String d — stroked SVG
MorphIcon(icon: isOpen ? MorphIconsLucide.x : MorphIconsLucide.menu)

// IconData — filled font glyph, same widget
MorphIcon(icon: isHome ? Icons.home : Icons.favorite)
MorphIcon(icon: Icons.search) // any IconData from any package

// Typed, rejects the other kind
MorphIcon.svg(icon: "M4 6L20 6...")
MorphIcon.font(icon: Icons.home)

// Controlled / imperative (both kinds)
MorphIcon.controlled(from: Icons.home, icon: Icons.settings, progress: t)
final key = GlobalKey<MorphIconState>();
key.currentState?.morphTo(Icons.favorite);
```

Any `IconData` from any `pub.dev` icon package works — the widget resolves it via a curated `Map<int,String>` table (`lib/src/icon_data_resolver.dart`) to the same 24×24 cubic pipeline. Add a new pack by extending the table or use `MorphIcon.svg(String d)`.

Mask / canvas:

```dart
MorphMask(icon: Icons.favorite, child: SizedBox(width: 220, height: 150,
  child: DecoratedBox(decoration: BoxDecoration(
    gradient: LinearGradient(colors: [Color(0xfff857a6), Color(0xffff5858)])))))
```

Live `IconData → IconData` demo (filled `home → favorite`) is on the [site](https://mibrar-dev.github.io/morphicons-flutter/#icondata) and in `example/icon_data_example.dart`. Packs are optional; the adapter makes any installed icon package morphable. See [DOCS.md](DOCS.md) for the full pipeline and parity.

## License

MIT. Algorithm & design: [Guillermo / morphicons](https://github.com/guillermolg00/morphicons). See [LICENSE](LICENSE).
