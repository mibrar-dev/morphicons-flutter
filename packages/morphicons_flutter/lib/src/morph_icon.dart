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
///
/// Phase 0 unified contract: `icon`/`from` are `Object` (`String` d |
/// `IconData` | `IconNode`) — widened from `String` so a single widget
/// handles both stroked SVG and filled font glyphs. Typed factories
/// `MorphIcon.svg`/`.font` and `controlledSvg`/`.controlledFont` recover
/// static safety; `isSvg`/`isFont` introspect the current [icon].
// ignore_for_file: prefer_initializing_formals
library;

import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:morphicons_core/morphicons_core.dart';

import 'icon_data_resolver.dart';
import 'morph_painter.dart';
import 'morph_scheduler.dart';

/// Documentation-only union: `String` (SVG d) | `IconData` | `IconNode`.
typedef MorphSource = Object;

/// An icon that morphs to a new shape when [icon] changes.
///
/// Unified `Object` icon — accepts `String` SVG path data, `IconData` font
/// glyphs, or `IconNode` (Lucide-style). See [isSvg]/[isFont].
class MorphIcon extends StatefulWidget {
  /// Target icon. Changing it triggers an animated morph.
  ///
  /// Accepted types: `String` (SVG `d`), `IconData` (font glyph), `IconNode`.
  final Object icon;

  /// Spring tuning for the progress x: 0 → 1.
  final SpringPreset spring;

  /// Rendered square size (logical pixels).
  final double size;

  /// Stroke width in the 24×24 icon coordinate space.
  ///
  /// Honored for stroked (SVG) icons, ignored for filled (font) icons.
  final double strokeWidth;

  /// Stroke / fill color; defaults to the ambient [DefaultTextStyle] color.
  final Color? color;

  /// Accessibility label; the icon is hidden from semantics when null.
  final String? semanticLabel;

  /// Uncontrolled mode: animate to [icon] whenever it changes.
  ///
  /// Accepts `String` or `IconData` via `Object` — `String <: Object` so
  /// existing `MorphIcon(icon: "M…")` callers keep working.
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

  /// Typed factory for SVG `d` strings — static rejection of `IconData`.
  const MorphIcon.svg({
    super.key,
    required String icon,
    this.spring = SpringPreset.smooth,
    this.size = 24,
    this.strokeWidth = 2,
    this.color,
    this.semanticLabel,
  })  : icon = icon,
        from = null,
        progress = null;

  /// Typed factory for font glyphs — static rejection of `String`.
  const MorphIcon.font({
    super.key,
    required IconData icon,
    this.spring = SpringPreset.smooth,
    this.size = 24,
    this.strokeWidth = 2,
    this.color,
    this.semanticLabel,
  })  : icon = icon,
        from = null,
        progress = null;

  /// Controlled mode: render the [from] → [icon] morph at [progress] (0..1),
  /// no spring. Values above 1 extrapolate (spring overshoot).
  ///
  /// Both [from] and [icon] are `Object` — mixed `IconData ↔ String` is
  /// allowed (common UX: Material `Icons.menu` → Lucide `X`).
  const MorphIcon.controlled({
    super.key,
    required this.from,
    required this.icon,
    required this.progress,
    this.size = 24,
    this.strokeWidth = 2,
    this.color,
    this.semanticLabel,
  }) : spring = SpringPreset.smooth;

  /// Typed controlled for stroked → stroked (same-kind enforced).
  const MorphIcon.controlledSvg({
    super.key,
    required String from,
    required String icon,
    required double progress,
    this.size = 24,
    this.strokeWidth = 2,
    this.color,
    this.semanticLabel,
  })  : from = from,
        icon = icon,
        progress = progress,
        spring = SpringPreset.smooth;

  /// Typed controlled for filled → filled (same-kind enforced).
  const MorphIcon.controlledFont({
    super.key,
    required IconData from,
    required IconData icon,
    required double progress,
    this.size = 24,
    this.strokeWidth = 2,
    this.color,
    this.semanticLabel,
  })  : from = from,
        icon = icon,
        progress = progress,
        spring = SpringPreset.smooth;

  /// Controlled-mode source icon; null in uncontrolled mode.
  final Object? from;

  /// Controlled-mode progress; null in uncontrolled mode.
  final double? progress;

  /// Whether the target [icon] is an SVG stroked source (`String` or `IconNode`).
  bool get isSvg => icon is String || icon is IconNode;

  /// Whether the target [icon] is a filled font glyph (`IconData`).
  bool get isFont => icon is IconData;

  bool get _isControlled => progress != null;

  /// Back-compat shim for callers that read `widget.icon` as `String`.
  @Deprecated('Use `icon` as Object and cast if needed: `icon as String`.')
  String get iconAsString => icon as String;

  /// Back-compat shim for `widget.from` as `String`.
  @Deprecated('Use `from` as Object and cast if needed: `from as String`.')
  String? get fromAsString => from as String?;

  @override
  State<MorphIcon> createState() => MorphIconState();
}

/// Converts any [MorphSource] to an [IconInput] (`String`|`IconNode`) the
/// core solver can handle. `IconData` is resolved via the curated
/// `icon_data_resolver.dart` table (codegen-lite) so the same plan/solver
/// drives both stroke and filled icons.
IconInput _toInput(Object value) {
  if (value is String) return value;
  if (value is IconNode) return value;
  if (value is IconData) return iconDataToPathOrThrow(value);
  // IconNode is `List<(String, Map)>` — at runtime it's a List<Record>.
  // The `is IconNode` check covers the usual case, but for non-const
  // construction it may appear as plain List. Accept it.
  if (value is List) {
    // Heuristic: list of records with String tag + Map attrs.
    // We delegate to core's iconToCubics which will handle IconNode lists;
    // if not an IconNode, the core will throw a useful error later.
    try {
      return value as IconNode;
    } catch (_) {
      // Fall through to error below.
    }
  }
  throw ArgumentError.value(
    value,
    'icon',
    'Unsupported MorphSource type ${value.runtimeType}. Expected String, IconData, or IconNode.',
  );
}

bool _shouldFill(Object value) => value is IconData;

/// State of [MorphIcon]; exposed for the imperative mode:
/// `GlobalKey<MorphIconState>().currentState?.morphTo(...)` / `.set(...)`.
class MorphIconState extends State<MorphIcon> {
  final Spring _spring = Spring();
  MorphPlan? _plan;
  List<Float64List>? _out;
  List<CubicPath>? _canonical;
  Object _source = '';
  Object _target = '';
  bool _registered = false;
  bool _springSettled = true;

  bool get _settledAtTarget => _spring.x >= 1;

  /// Current interpolation progress (spring x in uncontrolled mode,
  /// the [MorphIcon.progress] value in controlled mode). Exposed for
  /// telemetry and debugging UIs.
  double get progress => widget._isControlled ? widget.progress! : _spring.x;

  /// Current spring velocity (uncontrolled mode only; 0 when controlled).
  double get velocity => widget._isControlled ? 0 : _spring.v;

  /// Whether the icon is resting on its target shape.
  bool get settled =>
      widget._isControlled ? widget.progress! >= 1 : _spring.x >= 1;

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

  bool _filled = false;

  void _rebuildPlan(Object from, Object to) {
    // Resolve IconData → String d via the curated table so the same
    // Procrustes/polar solver animates filled and stroked icons alike.
    // Mixed IconData ↔ String is also allowed (common UX: Material menu →
    // Lucide X) — both are normalized to the 24×24 grid already.
    try {
      final fromInput = _toInput(from);
      final toInput = _toInput(to);
      _plan = planBetween(fromInput, toInput);
      _out = allocOutputs(_plan!);
      _canonical = iconToCubics(toInput);
      _filled = _shouldFill(to);
    } catch (_) {
      // Graceful fallback (unknown IconData not in table etc.) — keep
      // previous plan and render target canonically if possible.
      // For stroked unknown we try raw core handling.
      try {
        final toInput = _toInput(to);
        _canonical = iconToCubics(toInput);
      } catch (_) {
        _canonical = null;
      }
      _plan = null;
      _out = null;
      _filled = _shouldFill(to);
    }
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
  ///
  /// Primary unified entry — accepts `String` or `IconData`.
  void morphTo(Object icon) {
    if (icon == _target) return;
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      set(icon);
      return;
    }
    _morphFromCurrentShapeTo(icon);
  }

  /// Typed alias: animate to SVG `d` string.
  void morphToSvg(String d) => morphTo(d);

  /// Typed alias: animate to font glyph.
  void morphToFont(IconData data) => morphTo(data);

  /// Imperative mode: jump to [icon] with no animation.
  void set(Object icon) {
    _source = icon;
    _target = icon;
    _rebuildPlan(icon, icon);
    _spring.x = 1;
    _spring.v = 0;
    _springSettled = true;
    _unregister();
    setState(() {});
  }

  /// Typed alias: snap to SVG `d`.
  void setSvg(String d) => set(d);

  /// Typed alias: snap to font glyph.
  void setFont(IconData data) => set(data);

  void _morphFromCurrentShapeTo(Object icon) {
    // Interruption: re-sample the current intermediate shape as the new
    // morph source so the re-plan starts exactly where we are.
    // For any IconData the intermediate is serialized as a polyline String
    // (quantized to 2 decimals — Phase 6 will use MorphSnapshot to avoid
    // drift for filled icons).
    if (_plan == null || _out == null) {
      _target = icon;
      _rebuildPlan(_source, icon);
      _spring.start();
      _springSettled = false;
      _register();
      setState(() {});
      return;
    }
    final closed = _plan!.items.map((it) => it.closed).toList();
    final newSource = _settledAtTarget ? _target : serialize(_out!, closed);
    // `newSource` is String polyline when interrupted, IconData when settled;
    // _rebuildPlan resolves IconData via the table.
    final Object sourceInput = newSource;
    _target = icon;
    _source = sourceInput;
    _rebuildPlan(sourceInput, icon);
    _spring.start();
    _springSettled = false;
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
      _springSettled = true;
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
    // If we failed to build a plan (e.g., IconData not in table), fall back
    // to a static representation — filled Icon for fonts, stroked canonical
    // for strings — rather than empty space.
    if (_plan == null || _out == null) {
      if (_canonical != null) {
        final color =
            widget.color ?? DefaultTextStyle.of(context).style.color;
        final child = CustomPaint(
          size: Size.square(widget.size),
          painter: MorphPainter(
            plan: null,
            out: null,
            t: 1,
            canonicalPaths: _canonical,
            canonicalSnap: true,
            strokeWidth: widget.strokeWidth,
            color: color ?? const Color(0xFF000000),
            filled: _filled,
          ),
        );
        final label = widget.semanticLabel;
        return label == null
            ? ExcludeSemantics(child: child)
            : Semantics(label: label, image: true, child: child);
      }
      if (widget.isFont) {
        // Unknown IconData — static Icon fallback
        final data = widget.icon as IconData;
        final color =
            widget.color ?? DefaultTextStyle.of(context).style.color;
        final iconWidget = Icon(data, size: widget.size, color: color);
        final label = widget.semanticLabel;
        return label == null
            ? ExcludeSemantics(child: iconWidget)
            : Semantics(label: label, image: true, child: iconWidget);
      }
      final label = widget.semanticLabel;
      final placeholder = SizedBox.square(dimension: widget.size);
      return label == null
          ? ExcludeSemantics(child: placeholder)
          : Semantics(label: label, image: true, child: placeholder);
    }

    final t = widget._isControlled ? widget.progress! : _spring.x;
    final canonicalSnap =
        widget._isControlled ? widget.progress == 1 : _springSettled;
    final color = widget.color ?? DefaultTextStyle.of(context).style.color;
    final child = CustomPaint(
      size: Size.square(widget.size),
      painter: MorphPainter(
        plan: _plan,
        out: _out,
        t: t,
        canonicalPaths: _canonical,
        canonicalSnap: canonicalSnap,
        strokeWidth: widget.strokeWidth,
        color: color ?? const Color(0xFF000000),
        filled: _filled,
      ),
    );
    final label = widget.semanticLabel;
    return label == null
        ? ExcludeSemantics(child: child)
        : Semantics(label: label, image: true, child: child);
  }
}
