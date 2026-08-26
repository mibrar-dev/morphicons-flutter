/// Readable String helpers for constructing morph pairs and controlled widgets.
library;

import 'package:flutter/widgets.dart';

import 'morph_canvas.dart';
import 'morph_mask.dart';
import 'morph_pair.dart';

/// Readable helpers for icon `d` strings.
extension MorphStringExtensions on String {
  /// Creates a pair from this source icon to [target].
  MorphPair morphTo(String target) => MorphPair(this, target);

  /// Short alias for [morphTo].
  MorphPair morph(String target) => morphTo(target);

  /// Builds a controlled [MorphCanvas] with this string as [from] and
  /// [target] as the destination icon.
  MorphCanvas morphCanvasTo(
    String target, {
    required double progress,
    double size = 24,
    Color? color,
    double strokeWidth = 2,
    double viewBox = 24,
    String? semanticLabel,
  }) =>
      MorphCanvas.controlled(
        from: this,
        icon: target,
        progress: progress,
        size: size,
        color: color,
        strokeWidth: strokeWidth,
        viewBox: viewBox,
        semanticLabel: semanticLabel,
      );

  /// Builds a controlled [MorphMask] with this string as [from] and
  /// [target] as the destination mask geometry.
  MorphMask morphMaskTo(
    String target, {
    required Widget child,
    required double progress,
    Color color = const Color(0xFFFFFFFF),
    double strokeWidth = 2,
    double viewBox = 24,
    String? semanticLabel,
  }) =>
      MorphMask.controlled(
        from: this,
        icon: target,
        progress: progress,
        color: color,
        strokeWidth: strokeWidth,
        viewBox: viewBox,
        semanticLabel: semanticLabel,
        child: child,
      );
}
