# morphicons_flutter

`MorphIcon` for Flutter: similarity-aware icon morphing powered by
[`morphicons_core`](https://pub.dev/packages/morphicons_core). A faithful
Flutter binding of the [morphicons](https://github.com/guillermolg00/morphicons)
React component.

## Three modes, matching upstream

```dart
// 1. Uncontrolled — change `icon`, morphicons animates.
MorphIcon(icon: isOpen ? MorphIconsLucide.x : MorphIconsLucide.menu,
          spring: SpringPreset.snappy)

// 2. Controlled — explicit progress, e.g. driven by a drag gesture.
MorphIcon.controlled(from: MorphIconsLucide.menu, to: MorphIconsLucide.x,
                     progress: dragProgress)

// 3. Imperative — sequenced morphs.
final key = GlobalKey<MorphIconState>();
MorphIcon(key: key, icon: MorphIconsLucide.menu);
key.currentState?.morphTo(MorphIconsLucide.check); // animates
key.currentState?.set(MorphIconsLucide.x);         // jumps, no animation
```

## Behavior parity checklist

- `size`, `strokeWidth`, `color`, `semanticLabel` (`Semantics`; hidden when
  unlabeled, mirroring the `aria-hidden` default).
- `MediaQuery.disableAnimations` → instant `set()` (reduced motion).
- First frame paints the exact canonical shape — no async warm-up, no flash.
- Canonical snap on settle: a resting icon is pixel-identical to a static one.
- One shared `Ticker`-driven `MorphScheduler` steps every active spring —
  cheap at icon-grid scale.

Icon data lives in companion packages, e.g.
[`morphicons_lucide`](https://pub.dev/packages/morphicons_lucide).

## License

MIT — algorithm and design credit: [Guillermo / morphicons](https://github.com/guillermolg00/morphicons).
