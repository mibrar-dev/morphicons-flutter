# morphicons_lucide

[Lucide](https://lucide.dev) icon data for
[Morphicons](https://pub.dev/packages/morphicons_flutter): 1500+ icons as
plain Dart `const` `d` strings — generated from the npm `lucide` package by
`tool/extract_icons.mjs`, zero hand-editing.

```dart
import 'package:morphicons_flutter/morphicons_flutter.dart';
import 'package:morphicons_lucide/morphicons_lucide.dart';

MorphIcon(icon: MorphIconsLucide.menu)

// Or by name:
MorphIcon(icon: lucideIcons['arrow-right']!)
```

Every icon targets the canonical 24×24 grid with uniform stroke, exactly what
`morphicons_core` expects. Non-path primitives (`line`, `circle`, `ellipse`,
`rect`, `polyline`, `polygon`) are flattened to path data at generation time.

## Regenerating

```sh
cd tool && npm install && node extract_icons.mjs
```

## License

MIT. Lucide icons are ISC-licensed; this package carries only their path data.
Morphicons algorithm credit: [Guillermo / morphicons](https://github.com/guillermolg00/morphicons).
