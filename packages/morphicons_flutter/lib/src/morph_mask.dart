/// Morphing alpha masks for arbitrary Flutter children.
library;

import 'dart:math' as math;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:morphicons_core/morphicons_core.dart';

import 'morph_render.dart';
import 'morph_scheduler.dart';

/// Clips a child with the alpha of a morphing stroked icon.
///
/// A mask uses an offscreen compositing layer for every painted frame. This
/// preserves the child's layout, hit testing, and semantics, but makes
/// [MorphMask] best suited to small interactive surfaces rather than large
/// grids of animated children.
class MorphMask extends StatefulWidget {
  /// Creates an uncontrolled mask that animates when [icon] changes.
  const MorphMask({
    super.key,
    required this.icon,
    required this.child,
    this.spring = SpringPreset.smooth,
    this.color = const Color(0xFFFFFFFF),
    this.strokeWidth = 2,
    this.viewBox = 24,
    this.semanticLabel,
  })  : from = null,
        progress = null;

  /// Creates a ticker-free controlled mask.
  const MorphMask.controlled({
    super.key,
    required this.from,
    required this.icon,
    required this.progress,
    required this.child,
    this.color = const Color(0xFFFFFFFF),
    this.strokeWidth = 2,
    this.viewBox = 24,
    this.semanticLabel,
  }) : spring = SpringPreset.smooth;

  /// Target icon `d` string.
  final String icon;

  /// Optional controlled source icon `d` string.
  final String? from;

  /// Optional controlled progress.
  final double? progress;

  /// Child whose alpha is masked. Its layout and semantics are unchanged.
  final Widget child;

  /// Spring used in uncontrolled mode.
  final SpringPreset spring;

  /// Color of the mask geometry. Alpha is the meaningful component.
  final Color color;

  /// Stroke width in [viewBox] coordinates.
  final double strokeWidth;

  /// Coordinate-space extent of the icon.
  final double viewBox;

  /// Optional label added around the preserved child semantics.
  final String? semanticLabel;

  bool get _controlled => progress != null;

  @override
  State<MorphMask> createState() => MorphMaskState();
}

/// State and scheduler lifecycle for [MorphMask].
class MorphMaskState extends State<MorphMask> {
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
  void didUpdateWidget(MorphMask oldWidget) {
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
    final progress = widget._controlled ? widget.progress! : _spring.x;
    final mask = _MorphMaskRenderWidget(
      render: _render!,
      progress: progress,
      color: widget.color,
      strokeWidth: widget.strokeWidth,
      viewBox: widget.viewBox,
      canonicalSnap: widget._controlled ? progress == 1 : _canonicalSnap,
      child: widget.child,
    );
    return widget.semanticLabel == null
        ? mask
        : Semantics(label: widget.semanticLabel, child: mask);
  }
}

class _MorphMaskRenderWidget extends SingleChildRenderObjectWidget {
  const _MorphMaskRenderWidget({
    required this.render,
    required this.progress,
    required this.color,
    required this.strokeWidth,
    required this.viewBox,
    required this.canonicalSnap,
    required super.child,
  });

  final MorphRender render;
  final double progress;
  final Color color;
  final double strokeWidth;
  final double viewBox;
  final bool canonicalSnap;

  @override
  _MorphMaskRender createRenderObject(BuildContext context) => _MorphMaskRender(
        render: render,
        progress: progress,
        color: color,
        strokeWidth: strokeWidth,
        viewBox: viewBox,
        canonicalSnap: canonicalSnap,
      );

  @override
  void updateRenderObject(BuildContext context, _MorphMaskRender object) {
    object
      ..render = render
      ..progress = progress
      ..color = color
      ..strokeWidth = strokeWidth
      ..viewBox = viewBox
      ..canonicalSnap = canonicalSnap;
  }
}

class _MorphMaskRender extends RenderProxyBox {
  _MorphMaskRender({
    required MorphRender render,
    required double progress,
    required Color color,
    required double strokeWidth,
    required double viewBox,
    required bool canonicalSnap,
  })  : _render = render,
        _progress = progress,
        _color = color,
        _strokeWidth = strokeWidth,
        _viewBox = viewBox,
        _canonicalSnap = canonicalSnap;

  MorphRender _render;
  double _progress;
  Color _color;
  double _strokeWidth;
  double _viewBox;
  bool _canonicalSnap;

  set render(MorphRender value) {
    if (_render == value) return;
    _render = value;
    markNeedsPaint();
  }

  set progress(double value) {
    if (_progress == value) return;
    _progress = value;
    markNeedsPaint();
  }

  set color(Color value) {
    if (_color == value) return;
    _color = value;
    markNeedsPaint();
  }

  set strokeWidth(double value) {
    if (_strokeWidth == value) return;
    _strokeWidth = value;
    markNeedsPaint();
  }

  set viewBox(double value) {
    if (_viewBox == value) return;
    _viewBox = value;
    markNeedsPaint();
  }

  set canonicalSnap(bool value) {
    if (_canonicalSnap == value) return;
    _canonicalSnap = value;
    markNeedsPaint();
  }

  Path _buildStrokedClip(double s, double dx, double dy) {
    // Build a filled path that is the stroked outline of the morphed icon.
    final outs = _render.interpolate(_progress);
    final closeds = _render.closed;
    final hw = _strokeWidth * s / 2;
    final path = Path();

    for (var k = 0; k < outs.length; k++) {
      final pts = outs[k];
      final n = pts.length ~/ 2;
      if (n < 2) continue;
      final closed = closeds[k];
      final sx = List<double>.filled(n, 0);
      final sy = List<double>.filled(n, 0);
      for (var i = 0; i < n; i++) {
        sx[i] = dx + pts[2 * i] * s;
        sy[i] = dy + pts[2 * i + 1] * s;
      }
      final segCount = closed ? n : n - 1;
      for (var i = 0; i < segCount; i++) {
        final x0 = sx[i];
        final y0 = sy[i];
        final x1 = sx[(i + 1) % n];
        final y1 = sy[(i + 1) % n];
        final ddx = x1 - x0;
        final ddy = y1 - y0;
        final len = math.sqrt(ddx * ddx + ddy * ddy);
        if (len < 1e-9) continue;
        final nx = -ddy / len * hw;
        final ny = ddx / len * hw;
        path.moveTo(x0 + nx, y0 + ny);
        path.lineTo(x0 - nx, y0 - ny);
        path.lineTo(x1 - nx, y1 - ny);
        path.lineTo(x1 + nx, y1 + ny);
        path.close();
      }
      for (var i = 0; i < n; i++) {
        path.addOval(Rect.fromCircle(center: Offset(sx[i], sy[i]), radius: hw));
      }
    }
    return path;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null ||
        !_progress.isFinite ||
        !_viewBox.isFinite ||
        _viewBox <= 0) {
      return;
    }
    final s = size.shortestSide / _viewBox;
    final dx = offset.dx + (size.width - _viewBox * s) / 2;
    final dy = offset.dy + (size.height - _viewBox * s) / 2;
    final clip = _buildStrokedClip(s, dx, dy);
    if (clip.getBounds().isEmpty) {
      context.paintChild(child, offset);
      return;
    }
    final canvas = context.canvas;
    canvas.save();
    canvas.clipPath(clip);
    context.paintChild(child, offset);
    canvas.restore();
  }
}
