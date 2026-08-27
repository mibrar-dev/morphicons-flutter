## 1.0.0

- Stable 1.0.0 release, ready for pub.dev.
- 1288 Heroicons as plain Dart `const` `d` strings across four variants:
  - 324 outline 24×24 stroke (`MorphIconsHeroicons`)
  - 324 solid 20×20 fit to 24×24 (`MorphIconsHeroiconsSolid`, ×1.2)
  - 324 solid 24×24 (`MorphIconsHeroiconsSolid24`)
  - 316 solid 16×16 fit to 24×24 (`MorphIconsHeroiconsSolid16`, ×1.5)
- Generated from the npm `heroicons` package via `tool/extract_heroicons.mjs`.
- ViewBox handling: solid 20 and 16 re-gridded to 24 via uniform scale at generation
  time (xMidYMid meet) so outline↔solid morphs don't need runtime `fitIcon`.
- `M0 0` anchoring per element; `elementToPath` flattening for non-path primitives.
- Four name maps + `heroiconsAllIcons` combined.

## 0.1.0

- Initial prerelease.
