/// Material IconData → SVG `d` resolver (codegen-lite).
///
/// This is the build-time style table described in
/// `docs/UNIFIED_MORPHICON_REPORT.md` §5: instead of parsing TTF at runtime,
/// we ship a curated const map for the demo icons. Any `IconData` not in the
/// table throws with a helpful message so callers know to extend the map or
/// provide a raw `String d` via `MorphIcon.svg`.
///
/// The `d` strings are taken verbatim from
/// https://github.com/google/material-design-icons (MIT) and are already on
/// the canonical 24×24 viewBox, so no `fitIcon` transform is needed. All
/// entries are single-path closed silhouettes (filled) except `menu`/`close`
/// which are multi-rect / X outlines — intentional to show both topologies
/// morphing through the same solver.
///
/// Adapted from morphnext's codegen approach — MIT.
library;

import 'package:flutter/widgets.dart';

// ---------------------------------------------------------------------------
// Raw `d` strings — 24×24 viewBox, as exported by Material Icons SVG.
// ---------------------------------------------------------------------------

/// `Icons.home`  (0xe318) — outlined variant simplified to the canonical
/// house silhouette (single closed path). Source: material-design-icons
/// `src/action/home/materialiconsoutlined/24px.svg` → second `<path>`.
const _kHomeD =
    'M12 5.69l5 4.5V18h-2v-6H9v6H7v-7.81l5-4.5M12 3L2 12h3v8h6v-6h2v6h6v-8h3L12 3z';

/// `Icons.favorite` (0xe25b) — heart.
const _kFavoriteD =
    'M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z';

/// `Icons.star` (0xe5f9) — 5-point star.
const _kStarD =
    'M12 17.27L18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z';

/// `Icons.search` (0xe567) — magnifier (filled, with handle).
const _kSearchD =
    'M15.5 14h-.79l-.28-.27C15.41 12.59 16 11.11 16 9.5 16 5.91 13.09 3 9.5 3S3 5.91 3 9.5 5.91 16 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z';

/// `Icons.settings` (0xe57f) — gear (filled).
const _kSettingsD =
    'M19.14 12.94c.04-.3.06-.61.06-.94 0-.32-.02-.64-.07-.94l2.03-1.58c.18-.14.23-.41.12-.61l-1.92-3.32c-.12-.22-.37-.29-.59-.22l-2.39.96c-.5-.38-1.03-.7-1.62-.94L14.4 2.81c-.04-.24-.24-.41-.48-.41h-3.84c-.24 0-.43.17-.47.41L9.25 5.35C8.66 5.59 8.12 5.92 7.63 6.29L5.24 5.33c-.22-.08-.47 0-.59.22L2.74 8.87C2.62 9.08 2.66 9.34 2.86 9.48l2.03 1.58C4.84 11.36 4.8 11.69 4.8 12s0.02.64.07.94l-2.03 1.58c-.18.14-.23.41-.12.61l1.92 3.32c.12.22.37.29.59.22l2.39-.96c.5.38 1.03.7 1.62.94l0.36 2.54c.05.24.24.41.48.41h3.84c.24 0 .44-.17.47-.41l0.36-2.54c.59-.24 1.13-.56 1.62-.94l2.39.96c.22.08.47 0 .59-.22l1.92-3.32c.12-.22.07-.47-.12-.61L19.14 12.94zM12 15.6c-1.98 0-3.6-1.62-3.6-3.6s1.62-3.6 3.6-3.6 3.6 1.62 3.6 3.6-1.98 3.6-3.6 3.6z';

/// `Icons.menu` (0xe3dc) — hamburger (three bars, multi-rect).
const _kMenuD = 'M3 18h18v-2H3v2zm0-5h18v-2H3v2zm0-7v2h18V6H3z';

/// `Icons.close` (0xe16a) — X (filled).
const _kCloseD =
    'M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z';

/// `Icons.check` (0xe156)
const _kCheckD = 'M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z';

// ---------------------------------------------------------------------------
// Public map — keyed by codePoint + fontFamily check
// ---------------------------------------------------------------------------

const Map<int, String> _kMaterialCodePointToD = <int, String>{
  0xe318: _kHomeD,
  0xe25b: _kFavoriteD,
  0xe5f9: _kStarD,
  0xe567: _kSearchD,
  0xe57f: _kSettingsD,
  0xe3dc: _kMenuD,
  0xe16a: _kCloseD,
  0xe156: _kCheckD,
};

/// Also expose named constants for direct use in examples / tests.
class MaterialIconPaths {
  static const String home = _kHomeD;
  static const String favorite = _kFavoriteD;
  static const String star = _kStarD;
  static const String search = _kSearchD;
  static const String settings = _kSettingsD;
  static const String menu = _kMenuD;
  static const String close = _kCloseD;
  static const String check = _kCheckD;
}

/// Resolves an [IconData] to its SVG `d` if present in the curated table.
///
/// Returns `null` when the codePoint is not registered. Callers that need a
/// strict failure can throw via `iconDataToPathOrThrow`.
String? iconDataToPath(IconData data) {
  // Only MaterialIcons font is in the demo table; other fonts intentionally miss.
  if (data.fontFamily != 'MaterialIcons') return null;
  return _kMaterialCodePointToD[data.codePoint];
}

/// Like [iconDataToPath] but throws with a actionable message.
String iconDataToPathOrThrow(IconData data) {
  final d = iconDataToPath(data);
  if (d != null) return d;
  throw ArgumentError.value(
    data,
    'icon',
    'No SVG path registered for IconData(codePoint: 0x${data.codePoint.toRadixString(16)}, '
        'fontFamily: ${data.fontFamily}). '
        'Add an entry to lib/src/icon_data_resolver.dart or use MorphIcon.svg(String d). '
        'See docs/UNIFIED_MORPHICON_REPORT.md §5 for codegen instructions.',
  );
}

/// `true` if the IconData can be resolved without error.
bool canResolveIconData(IconData data) => iconDataToPath(data) != null;
