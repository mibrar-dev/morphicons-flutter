# morphicons_heroicons

[Heroicons](https://heroicons.com) icon data for
[Morphicons](https://pub.dev/packages/morphicons_flutter): 1300+ icons as
plain Dart `const` `d` strings — generated from the npm `heroicons` package by
`tool/extract_heroicons.mjs`, zero hand-editing.

```dart
import 'package:morphicons_flutter/morphicons_flutter.dart';
import 'package:morphicons_heroicons/morphicons_heroicons.dart';

// Outline 24×24 — stroke, like Lucide/Tabler (no scaling needed)
MorphIcon(icon: MorphIconsHeroicons.bars3)
MorphIcon(icon: MorphIconsHeroicons.xMark)
MorphIcon(icon: MorphIconsHeroicons.heart)
MorphIcon(icon: heroiconsIcons['arrow-right']!)

// Solid 20×20 fitted to 24×24 — fill, scaled ×1.2 at generation time
MorphIcon(icon: MorphIconsHeroiconsSolid.heart)
MorphIcon(icon: heroiconsSolidIcons['heart']!)

// Solid 24×24 — fill, also 24 grid
MorphIcon(icon: MorphIconsHeroiconsSolid24.heart)
```

Every icon targets the canonical 24×24 grid expected by `morphicons_core`.
Heroicons outline (`24/outline`) and solid 24 (`24/solid`) natively draw on
24×24. Solid 20 (`20/solid`) and solid 16 (`16/solid`) natively draw on
20×20 and 16×16; this pack re-grids them to 24×24 at generation time via a
uniform `xMidYMid meet` scale (×1.2 for 20→24, ×1.5 for 16→24) so they morph
cleanly with outline without an extra `fitIcon` call. To use the raw 20-grid
data, `fitIcon(raw, '0 0 20 20')` or divide by 1.2 also works. Non-path
primitives (none in Heroicons today) would be flattened via `elementToPath`
like Lucide/Tabler. Every element's `d` is anchored with `M0 0` before joining
so relative moves don't bleed across concatenated subpaths.

Four classes are exported:

- `MorphIconsHeroicons` / `heroiconsIcons` — 324 outline 24×24 stroke icons
- `MorphIconsHeroiconsSolid` / `heroiconsSolidIcons` — 324 solid 20×20 fit to 24
- `MorphIconsHeroiconsSolid24` / `heroiconsSolid24Icons` — 324 solid 24×24
- `MorphIconsHeroiconsSolid16` / `heroiconsSolid16Icons` — 316 solid 16×16 fit to 24
- `heroiconsAllIcons` — outline + solid20 combined (solid wins on key collision)

## Regenerating

```sh
cd tool && npm install && node extract_heroicons.mjs
```

Sources:

- `heroicons/24/outline` — 324 icons, `viewBox="0 0 24 24"`, `stroke-width="1.5"`
- `heroicons/20/solid` — 324 icons, `viewBox="0 0 20 20"`, `fill="currentColor"`
- `heroicons/24/solid` — 324 icons, `viewBox="0 0 24 24"`, `fill="currentColor"`
- `heroicons/16/solid` — 316 icons, `viewBox="0 0 16 16"`, `fill="currentColor"`

## License

MIT. Heroicons are MIT-licensed; this package carries only their path data.
Morphicons algorithm credit: [Guillermo / morphicons](https://github.com/guillermolg00/morphicons).
