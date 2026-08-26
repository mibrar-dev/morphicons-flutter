/// MorphTween: a pure-Dart, ticker-free `d`-string interpolator.
///
/// Builds the morph plan for a [from] → [to] icon pair once on construction,
/// then provides [transform] (and the [lerp] alias) to evaluate the morph at
/// any finite progress value:
///
/// * `progress == 0` → exact canonical source string.
/// * `progress == 1` → exact canonical target string.
/// * `0 < progress < 1` → polar-interpolated polyline.
/// * `progress` outside [0, 1] → extrapolated polyline (spring overshoot /
///   rewind before 0).
/// * Non-finite `progress` → [ArgumentError].
///
/// [MorphTween] is `Animatable<String>`-compatible (matches the shape of
/// Flutter's `Animatable.transform`) without importing `dart:animation`, so
/// it works in pure-Dart contexts.
library;

import 'package:morphicons_core/morphicons_core.dart';

import 'morph_render.dart';

/// A ticker-free, plan-backed `d`-string interpolator.
///
/// Construct once per pair and call [transform] on every frame (or just once
/// for a static query). The pair's plan is cached by [planBetween] when both
/// endpoints are stable string objects — sub-millisecond construction.
///
/// ```dart
/// final tween = MorphTween(from: MorphIconsLucide.menu, to: MorphIconsLucide.x);
/// final mid = tween.transform(0.5);   // polyline d string at t=0.5
/// final end = tween.transform(1);     // exact canonical target d string
/// ```
final class MorphTween {
  /// The source icon `d` attribute.
  final String from;

  /// The target icon `d` attribute.
  final String to;

  final MorphRender _render;

  /// Constructs a tween for the [from] → [to] pair.
  ///
  /// [planBetween] is called synchronously; it is sub-millisecond and
  /// cached for stable string objects.
  MorphTween({required this.from, required this.to})
      : _render = MorphRender.forPair(from, to);

  /// Evaluates the morph at [progress] and returns a `d` string.
  ///
  /// * `0` → exact source (canonical cubics serialized).
  /// * `1` → exact target (canonical cubics serialized).
  /// * Any other finite value → polar-interpolated polyline.
  ///
  /// Throws [ArgumentError] if [progress] is NaN or infinite.
  String transform(double progress) {
    if (!progress.isFinite) {
      throw ArgumentError.value(
        progress,
        'progress',
        'MorphTween.transform requires a finite progress value',
      );
    }

    // Exact endpoints: return canonical `d` strings, not polylines.
    if (progress == 0.0) return from;
    if (progress == 1.0) return to;

    // General case: interpolate (also handles overshoot / extrapolation).
    _render.interpolate(progress);
    final result = _render.serializeOut();

    // Guard: if the serializer somehow produced an empty string, that is
    // a core bug, but we must not silently return empty from a public API.
    assert(result.isNotEmpty, 'MorphTween: serialized d string is empty');
    return result;
  }

  /// Alias for [transform]. Matches the shape of Flutter's `Tween.lerp`.
  String lerp(double t) => transform(t);
}
