/// Canvas adapters for rendering morph geometry without owning a ticker.
library;

import 'package:flutter/widgets.dart';
import 'core/morphicons_core.dart';

import 'morph_render.dart';
import 'morph_scheduler.dart';

/// A controlled painter for a morphing stroked icon.
///
/// This painter is deliberately ticker-free. The owner supplies [progress],
/// including finite values above one when spring-style overshoot is desired.
class MorphCanvasPainter extends CustomPainter {
  /// Creates a painter for [from] to [to] at [progress].
  MorphCanvasPainter.controlled({
    required String from,
    required String to,
    required double progress,
    Color color = const Color(0xFF000000),
    double strokeWidth = 2,
    double viewBox = 24,
    bool? canonicalSnap,
  }) : this._fromRender(
          from: from,
          to: to,
          progress: progress,
          color: color,
          strokeWidth: strokeWidth,
          viewBox: viewBox,
          canonicalSnap: canonicalSnap ?? progress == 1,
          render: MorphRender.forPair(from, to),
        );

  MorphCanvasPainter._fromRender({
    required this.from,
    required this.to,
    required this.progress,
    this.color = const Color(0xFF000000),
    this.strokeWidth = 2,
    this.viewBox = 24,
    this.canonicalSnap = true,
    required MorphRender render,
  }) : _render = render;

  /// Source icon `d` string.
  final String from;

  /// Target icon `d` string.
  final String to;

  /// Interpolation progress. Values outside 0..1 are extrapolated.
  final double progress;

  /// Stroke color.
  final Color color;

  /// Stroke width in [viewBox] coordinates.
  final double strokeWidth;

  /// Coordinate-space extent of the icon.
  final double viewBox;

  /// Whether to use exact target cubic geometry instead of interpolation.
  final bool canonicalSnap;

  final MorphRender _render;

  @override
  void paint(Canvas canvas, Size size) {
    if (!progress.isFinite || !viewBox.isFinite || viewBox <= 0) return;
    canvas.save();
    canvas.scale(size.width / viewBox, size.height / viewBox);
    try {
      final path = morphPath(
        _render,
        progress,
        canonicalSnap: canonicalSnap,
      );
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = strokeWidth
        ..color = color;
      canvas.drawPath(path, paint);
    } finally {
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant MorphCanvasPainter oldDelegate) {
    return from != oldDelegate.from ||
        to != oldDelegate.to ||
        progress != oldDelegate.progress ||
        color != oldDelegate.color ||
        strokeWidth != oldDelegate.strokeWidth ||
        viewBox != oldDelegate.viewBox ||
        canonicalSnap != oldDelegate.canonicalSnap;
  }
}

/// An icon that animates to a new [icon] using the shared morph scheduler.
class MorphCanvas extends StatefulWidget {
  /// Creates an uncontrolled canvas morph.
  const MorphCanvas({
    super.key,
    required this.icon,
    this.spring = SpringPreset.smooth,
    this.size = 24,
    this.color,
    this.strokeWidth = 2,
    this.viewBox = 24,
    this.semanticLabel,
    this.onPaint,
  })  : from = null,
        progress = null;

  /// Creates a ticker-free controlled canvas morph.
  const MorphCanvas.controlled({
    super.key,
    required this.from,
    required this.icon,
    required this.progress,
    this.size = 24,
    this.color,
    this.strokeWidth = 2,
    this.viewBox = 24,
    this.semanticLabel,
    this.onPaint,
  }) : spring = SpringPreset.smooth;

  /// Target icon `d` string.
  final String icon;

  /// Optional controlled source icon `d` string.
  final String? from;

  /// Optional controlled progress.
  final double? progress;

  /// Spring used in uncontrolled mode.
  final SpringPreset spring;

  /// Square logical size.
  final double size;

  /// Stroke color, defaulting to the ambient text color.
  final Color? color;

  /// Stroke width in [viewBox] coordinates.
  final double strokeWidth;

  /// Coordinate-space extent of the icon.
  final double viewBox;

  /// Accessibility label. Without one, the drawing is excluded from semantics.
  final String? semanticLabel;

  /// Called when an animation frame is painted.
  final VoidCallback? onPaint;

  bool get _controlled => progress != null;

  @override
  State<MorphCanvas> createState() => MorphCanvasState();
}

/// State and scheduler lifecycle for [MorphCanvas].
class MorphCanvasState extends State<MorphCanvas> {
  final Spring _spring = Spring();
  MorphRender? _render;
  String _source = '';
  String _target = '';
  bool _registered = false;
  bool _canonicalSnap = true;

  @override
  void initState() {
    super.initState();
    _spring.applyPreset(widget.spring);
    if (widget._controlled) {
      _setPair();
    } else {
      _source = _target = widget.icon;
      _render = MorphRender.forPair(_source, _target);
    }
  }

  void _setPair() {
    _source = widget.from!;
    _target = widget.icon;
    _render = MorphRender.forPair(_source, _target);
  }

  @override
  void didUpdateWidget(MorphCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget._controlled) {
      if (widget.from != _source || widget.icon != _target) _setPair();
      return;
    }
    if (oldWidget.spring != widget.spring) _spring.applyPreset(widget.spring);
    if (widget.icon == _target) return;
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _set(widget.icon);
    } else {
      _morphTo(widget.icon);
    }
  }

  void _set(String icon) {
    _source = _target = icon;
    _render = MorphRender.forPair(icon, icon);
    _spring.x = 1;
    _spring.v = 0;
    _canonicalSnap = true;
    _unregister();
    setState(() {});
  }

  void _morphTo(String icon) {
    if (_spring.x < 1) _render!.interpolate(_spring.x);
    final source = _spring.x >= 1 ? _target : _render!.serializeOut();
    _source = source;
    _target = icon;
    _render = MorphRender.forPair(source, icon);
    _spring.start();
    _canonicalSnap = false;
    _register();
    setState(() {});
  }

  void _register() {
    if (_registered) return;
    _registered = true;
    MorphScheduler.instance.register(_step);
  }

  void _unregister() {
    if (!_registered) return;
    _registered = false;
    MorphScheduler.instance.unregister(_step);
  }

  void _step(double dt) {
    if (_spring.step(dt)) {
      _spring.x = 1;
      _spring.v = 0;
      _canonicalSnap = true;
      _unregister();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _unregister();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controlled = widget._controlled;
    final progress = controlled ? widget.progress! : _spring.x;
    final painter = MorphCanvasPainter._fromRender(
      from: _source,
      to: _target,
      progress: progress,
      color: widget.color ??
          DefaultTextStyle.of(context).style.color ??
          const Color(0xFF000000),
      strokeWidth: widget.strokeWidth,
      viewBox: widget.viewBox,
      canonicalSnap: controlled ? progress == 1 : _canonicalSnap,
      render: _render!,
    );
    final CustomPainter paintDelegate = widget.onPaint == null
        ? painter
        : _PaintCallbackPainter(painter, widget.onPaint);
    final child = CustomPaint(
      size: Size.square(widget.size),
      painter: paintDelegate,
    );
    return widget.semanticLabel == null
        ? ExcludeSemantics(child: child)
        : Semantics(
            label: widget.semanticLabel,
            image: true,
            child: child,
          );
  }
}

class _PaintCallbackPainter extends CustomPainter {
  const _PaintCallbackPainter(this.delegate, this.onPaint);
  final MorphCanvasPainter delegate;
  final VoidCallback? onPaint;

  @override
  void paint(Canvas canvas, Size size) {
    delegate.paint(canvas, size);
    onPaint?.call();
  }

  @override
  bool shouldRepaint(covariant _PaintCallbackPainter oldDelegate) =>
      delegate.shouldRepaint(oldDelegate.delegate) ||
      onPaint != oldDelegate.onPaint;
}
