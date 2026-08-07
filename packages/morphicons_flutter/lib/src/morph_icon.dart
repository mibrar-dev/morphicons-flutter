/// MorphIcon: the Flutter widget on top of the pure-Dart core.
///
/// Two modes, mirroring upstream:
///   * Uncontrolled — pass [icon]; changing it animates from the current
///     (possibly mid-flight) shape to the new target. Interruptions
///     re-sample the interpolated polyline as the new plan source and
///     preserve spring velocity, so rapid re-triggering never jumps.
///   * Controlled — [MorphIcon.controlled]: explicit `from`/`to`/`progress`,
///     no spring (for scrubbers and drag gestures).
///
/// First frame is always the exact canonical shape (plan() is synchronous);
/// settling snaps to the canonical target paths for pixel-perfect rest.
library;

import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:morphicons_core/morphicons_core.dart';

import 'morph_painter.dart';
import 'morph_scheduler.dart';

/// An icon that morphs to a new shape when [icon] changes.
class MorphIcon extends StatefulWidget {
  /// Target icon `d` attribute. Changing it triggers an animated morph.
  final String icon;

  /// Spring tuning for the progress x: 0 → 1.
  final SpringPreset spring;

  /// Rendered square size (logical pixels).
  final double size;

  /// Stroke width in the 24×24 icon coordinate space.
  final double strokeWidth;

  /// Stroke color; defaults to the ambient [DefaultTextStyle] color.
  final Color? color;

  /// Accessibility label; the icon is hidden from semantics when null.
  final String? semanticLabel;

  /// Uncontrolled mode: animate to [icon] whenever it changes.
  const MorphIcon({
    super.key,
    required this.icon,
    this.spring = SpringPreset.smooth,
    this.size = 24,
    this.strokeWidth = 2,
    this.color,
    this.semanticLabel,
  })  : from = null,
        progress = null;

  /// Controlled mode: render the [from] → [to] morph at [progress] (0..1),
  /// no spring. Values above 1 extrapolate (spring overshoot).
  const MorphIcon.controlled({
    super.key,
    required String this.from,
    required this.icon,
    required double this.progress,
    this.size = 24,
    this.strokeWidth = 2,
    this.color,
    this.semanticLabel,
  }) : spring = SpringPreset.smooth;

  /// Controlled-mode source icon; null in uncontrolled mode.
  final String? from;

  /// Controlled-mode progress; null in uncontrolled mode.
  final double? progress;

  bool get _isControlled => progress != null;

  @override
  State<MorphIcon> createState() => MorphIconState();
}

/// State of [MorphIcon]; exposed for the imperative mode:
/// `GlobalKey<MorphIconState>().currentState?.morphTo(...)` / `.set(...)`.
class MorphIconState extends State<MorphIcon> {
  final Spring _spring = Spring();
  MorphPlan? _plan;
  List<Float64List>? _out;
  List<CubicPath>? _canonical;
  String _source = '';
  String _target = '';
  bool _registered = false;

  bool get _settledAtTarget => _spring.x >= 1;

  @override
  void initState() {
    super.initState();
    _spring.applyPreset(widget.spring);
    if (widget._isControlled) {
      _setControlledPlan();
    } else {
      _source = widget.icon;
      _target = widget.icon;
      _rebuildPlan(_source, _target);
      _spring.x = 1;
    }
  }

  void _setControlledPlan() {
    _source = widget.from!;
    _target = widget.icon;
    _rebuildPlan(_source, _target);
  }

  void _rebuildPlan(String from, String to) {
    _plan = planBetween(from, to);
    _out = allocOutputs(_plan!);
    _canonical = iconToCubics(to);
  }

  @override
  void didUpdateWidget(MorphIcon oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget._isControlled) {
      if (widget.from != _source || widget.icon != _target) {
        _setControlledPlan();
      }
      return;
    }

    if (oldWidget.spring != widget.spring) {
      _spring.applyPreset(widget.spring);
    }
    if (widget.icon == _target) return;

    // Reduced motion: swap instantly instead of animating.
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      set(widget.icon);
      return;
    }

    _morphFromCurrentShapeTo(widget.icon);
  }

  /// Imperative mode: animate to [icon] from the current (possibly
  /// mid-flight) shape. Interruptions preserve spring velocity.
  void morphTo(String icon) {
    if (icon == _target) return;
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      set(icon);
      return;
    }
    _morphFromCurrentShapeTo(icon);
  }

  /// Imperative mode: jump to [icon] with no animation.
  void set(String icon) {
    _source = icon;
    _target = icon;
    _rebuildPlan(icon, icon);
    _spring.x = 1;
    _spring.v = 0;
    _unregister();
    setState(() {});
  }

  void _morphFromCurrentShapeTo(String icon) {
    // Interruption: re-sample the current intermediate shape as the new
    // morph source so the re-plan starts exactly where we are.
    final closed = _plan!.items.map((it) => it.closed).toList();
    final newSource =
        _settledAtTarget ? _target : serialize(_out!, closed);
    _target = icon;
    _rebuildPlan(newSource, icon);
    _spring.start();
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
    final settled = _spring.step(dt);
    if (settled) {
      _spring.x = 1;
      _spring.v = 0;
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
    final t = widget._isControlled ? widget.progress! : _spring.x;
    final color = widget.color ?? DefaultTextStyle.of(context).style.color;
    final child = CustomPaint(
      size: Size.square(widget.size),
      painter: MorphPainter(
        plan: _plan,
        out: _out,
        t: t,
        canonicalPaths: _canonical,
        strokeWidth: widget.strokeWidth,
        color: color ?? const Color(0xFF000000),
      ),
    );
    final label = widget.semanticLabel;
    return label == null
        ? ExcludeSemantics(child: child)
        : Semantics(label: label, image: true, child: child);
  }
}
