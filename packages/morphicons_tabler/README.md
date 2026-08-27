# morphicons_tabler

[Tabler](https://tabler.io/icons) icon data for
[Morphicons](https://pub.dev/packages/morphicons_flutter): 4700+ icons as
plain Dart `const` `d` strings — generated from the npm `@tabler/icons`
package by `tool/extract_tabler.mjs`, zero hand-editing.

```dart
import 'package:morphicons_flutter/morphicons_flutter.dart';
import 'package:morphicons_tabler/morphicons_tabler.dart';

MorphIcon(icon: MorphIconsTabler.heart)

 // Or by name:
MorphIcon(icon: tablerIcons['arrow-right']!)
```

Every icon targets the canonical 24×24 grid with uniform stroke, exactly what
`morphicons_core` expects — no `fitIcon` scaling needed because Tabler and
`morphicons_core` share the same 24 grid (like Lucide). Non-path primitives
(`circle`, `rect`) are flattened to path data at generation time; the single
`<rect>` in `binoculars` and the ~23 filled dot `<circle>`s (r=0.5) become
equivalent arc paths.

## Regenerating

```sh
cd tool && npm install && node extract_tabler.mjs
```

## License

MIT. Tabler icons are MIT-licensed; this package carries only their path data.
Morphicons algorithm credit: [Guillermo / morphicons](https://github.com/guillermolg00/morphicons).
