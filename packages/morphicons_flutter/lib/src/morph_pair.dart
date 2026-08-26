/// A reusable source/target pair for controlled morph widgets.
library;

import 'package:flutter/widgets.dart';

import 'morph_canvas.dart';
import 'morph_icon.dart';
import 'morph_mask.dart';
import 'morph_tween.dart';

/// Describes a morph from [from] to [to] without owning animation state.
final class MorphPair {
  /// Source icon `d` attribute.
  final String from;

  /// Target icon `d` attribute.
  final String to;

  /// Creates a source/target pair.
  const MorphPair(this.from, this.to);

  /// Builds a controlled [MorphIcon] at [progress].
  MorphIcon icon({
    required double progress,
    double size = 24,
    double strokeWidth = 2,
    Color? color,
    String? semanticLabel,
  }) {
    return MorphIcon.controlled(
      from: from,
      icon: to,
      progress: progress,
      size: size,
      strokeWidth: strokeWidth,
      color: color,
      semanticLabel: semanticLabel,
    );
  }

  /// Builds a controlled [MorphCanvas] at [progress].
  MorphCanvas canvas({
    required double progress,
    double size = 24,
    Color? color,
    double strokeWidth = 2,
    double viewBox = 24,
    String? semanticLabel,
  }) {
    return MorphCanvas.controlled(
      from: from,
      icon: to,
      progress: progress,
      size: size,
      color: color,
      strokeWidth: strokeWidth,
      viewBox: viewBox,
      semanticLabel: semanticLabel,
    );
  }

  /// Builds a controlled [MorphMask] at [progress] around [child].
  MorphMask mask({
    required Widget child,
    required double progress,
    Color color = const Color(0xFFFFFFFF),
    double strokeWidth = 2,
    double viewBox = 24,
    String? semanticLabel,
  }) {
    return MorphMask.controlled(
      from: from,
      icon: to,
      progress: progress,
      color: color,
      strokeWidth: strokeWidth,
      viewBox: viewBox,
      semanticLabel: semanticLabel,
      child: child,
    );
  }

  /// Creates the pure, ticker-free interpolator for this pair.
  MorphTween tween() => MorphTween(from: from, to: to);
}
