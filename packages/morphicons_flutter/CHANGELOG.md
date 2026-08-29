## 1.0.1

- Standalone package: the pure-Dart solver is vendored in (`lib/src/core/`) — no `morphicons_core` dependency.
- Recognized MIT license.
- Shorter package description.

## 1.0.0

- Initial release.
- `MorphIcon` widget: uncontrolled, controlled (`MorphIcon.controlled`) and imperative (`MorphIconState.morphTo` / `.set`) modes — accepts `String d` or `IconData`.
- `MorphMask`, `MorphCanvas`, `MorphTween`, `MorphPair`, `String` extensions.
- `MorphPainter` with canonical snap on settle; one shared `Ticker` scheduler.
- IconData resolved via curated table; filled + stroked share the same solver.
