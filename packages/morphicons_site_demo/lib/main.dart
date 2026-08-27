/// Flutter Web bridge for the Morphicons website.
///
/// This is the real `morphicons_flutter` package compiled to the web —
/// the parent page drives it over `postMessage` and receives live
/// telemetry (spring x/v, settle state, solver θ/σ/residual) back.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:morphicons_flutter/morphicons_flutter.dart';
import 'package:morphicons_lucide/icons.dart';
import 'package:web/web.dart' as web;

class _Pair {
  const _Pair(this.id, this.label, this.from, this.to);

  final String id;
  final String label;
  final String from;
  final String to;
}

const _pairs = <_Pair>[
  _Pair(
    'menu-x',
    'menu → x',
    'M4 6L20 6M4 12L20 12M4 18L20 18',
    'M18 6L6 18M6 6L18 18',
  ),
  _Pair(
    'arrow-right-down',
    'arrow-right → arrow-down',
    'M5 12h14m-7-7 7 7-7 7',
    'M12 5v14m-7-7 7 7 7-7',
  ),
  _Pair(
    'plus-minus',
    'plus → minus',
    'M5 12h14M12 5v14',
    'M5 12h14',
  ),
  _Pair(
    'check-x',
    'check → x',
    'M20 6 9 17l-5-5',
    'M18 6 6 18m0-12 12 12',
  ),
  _Pair(
    'square-circle',
    'square → circle',
    'M5 5h14v14H5Z',
    'M12 2a10 10 0 1 0 0 20 10 10 0 1 0 0-20',
  ),
];

@JS('JSON.stringify')
external String _stringify(JSAny? value);

void main() => runApp(const _DemoRoot());

class _DemoRoot extends StatefulWidget {
  const _DemoRoot();

  @override
  State<_DemoRoot> createState() => _DemoRootState();
}

class _DemoRootState extends State<_DemoRoot> {
  late String _mode = _queryMode();

  String _queryMode() {
    final value = Uri.base.queryParameters['demo'];
    if (value == 'core' ||
        value == 'mask' ||
        value == 'canvas' ||
        value == 'iconData') {
      return value!;
    }
    return 'studio';
  }

  @override
  void initState() {
    super.initState();
    web.window.addEventListener(
      'message',
      ((web.MessageEvent event) {
        try {
          final data = jsonDecode(_stringify(event.data)) as Map;
          if (data['source'] == 'morphicons-site' &&
              data['cmd'] == 'demo' &&
              data['mode'] is String) {
            final mode = data['mode'] as String;
            if (mode == 'core' ||
                mode == 'mask' ||
                mode == 'canvas' ||
                mode == 'iconData') {
              setState(() => _mode = mode);
            } else if (mode == 'studio') {
              setState(() => _mode = 'studio');
            }
          }
        } catch (_) {
          // Ignore messages that are not JSON commands for this demo.
        }
      }).toJS,
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (_mode) {
      case 'core':
        return const _DemoApp(child: _CoreDemo());
      case 'mask':
        return const _DemoApp(child: _MaskDemo());
      case 'canvas':
        return const _DemoApp(child: _CanvasDemo());
      case 'iconData':
        return const _DemoApp(child: _IconDataDemo());
      default:
        return const BridgeApp();
    }
  }
}

class _DemoApp extends StatelessWidget {
  const _DemoApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff302b63)),
        scaffoldBackgroundColor: const Color(0xfff7f6f2),
      ),
      home: Builder(
        builder: (context) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            web.window.parent?.postMessage(
              {'source': 'morphicons-flutter', 'type': 'ready'}.jsify(),
              '*'.toJS,
            );
          });
          return Scaffold(body: SafeArea(child: child));
        },
      ),
    );
  }
}

class _DemoFrame extends StatelessWidget {
  const _DemoFrame(
      {required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 18),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoCard extends StatelessWidget {
  const _DemoCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      );
}

class _CoreDemo extends StatefulWidget {
  const _CoreDemo();

  @override
  State<_CoreDemo> createState() => _CoreDemoState();
}

class _CoreDemoState extends State<_CoreDemo> {
  bool copied = false;
  bool visible = false;
  bool dark = false;
  bool playing = false;
  bool valid = false;
  bool expanded = true;

  @override
  Widget build(BuildContext context) {
    final pair = MorphPair(MorphIconsLucide.play, MorphIconsLucide.pause);
    return _DemoFrame(
      title: 'Core widgets',
      subtitle:
          'Small Flutter-native interactions built from MorphIcon and MorphPair.',
      child: _DemoCard(
        child: Column(
          children: [
            _CoreRow(
              label: 'Copy to clipboard',
              icon: MorphIcon(
                  icon: copied ? MorphIconsLucide.check : MorphIconsLucide.copy,
                  size: 24,
                  semanticLabel: copied ? 'Copied' : 'Copy'),
              onTap: () => setState(() => copied = !copied),
            ),
            _CoreRow(
              label: visible ? 'Password visible' : 'Password hidden',
              icon: MorphIcon(
                  icon:
                      visible ? MorphIconsLucide.eye : MorphIconsLucide.eyeOff,
                  size: 24,
                  semanticLabel: 'Toggle password visibility'),
              onTap: () => setState(() => visible = !visible),
            ),
            _CoreRow(
              label: dark ? 'Dark theme' : 'Light theme',
              icon: MorphIcon(
                  icon: dark ? MorphIconsLucide.moon : MorphIconsLucide.sun,
                  size: 24,
                  semanticLabel: 'Toggle theme'),
              onTap: () => setState(() => dark = !dark),
            ),
            _CoreRow(
              label: playing ? 'Playing' : 'Paused',
              icon: pair.icon(
                  progress: playing ? 1 : 0,
                  size: 24,
                  semanticLabel: 'Play or pause'),
              onTap: () => setState(() => playing = !playing),
            ),
            _CoreRow(
              label: valid ? 'Email looks good' : 'Validate email',
              icon: MorphIcon(
                  icon: valid
                      ? MorphIconsLucide.circleCheck
                      : MorphIconsLucide.circleAlert,
                  size: 24,
                  semanticLabel: 'Validation state'),
              onTap: () => setState(() => valid = !valid),
            ),
            _CoreRow(
              label: expanded ? 'Project files' : 'Project files (collapsed)',
              icon: MorphIcon(
                  icon: expanded
                      ? MorphIconsLucide.chevronDown
                      : MorphIconsLucide.chevronRight,
                  size: 24,
                  semanticLabel: 'Toggle file tree'),
              onTap: () => setState(() => expanded = !expanded),
            ),
            if (expanded)
              const Padding(
                padding: EdgeInsets.only(left: 48, bottom: 4),
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('  lib/\n  test/\n  pubspec.yaml',
                        style:
                            TextStyle(fontFamily: 'monospace', fontSize: 12))),
              ),
          ],
        ),
      ),
    );
  }
}

class _CoreRow extends StatelessWidget {
  const _CoreRow(
      {required this.label, required this.icon, required this.onTap});

  final String label;
  final Widget icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        trailing: IconButton(onPressed: onTap, icon: icon),
        onTap: onTap,
      );
}

class _MaskDemo extends StatefulWidget {
  const _MaskDemo();

  @override
  State<_MaskDemo> createState() => _MaskDemoState();
}

class _MaskDemoState extends State<_MaskDemo> {
  final shapes = <String, String>{
    'menu': MorphIconsLucide.menu,
    'x': MorphIconsLucide.x,
    'sun': MorphIconsLucide.sun,
    'moon': MorphIconsLucide.moon,
    'heart': MorphIconsLucide.heart,
    'star': MorphIconsLucide.star,
  };
  String shape = 'heart';
  int paintMode = 0;

  @override
  Widget build(BuildContext context) {
    final child = DecoratedBox(
      decoration: BoxDecoration(
        color: paintMode == 1 ? const Color(0xff302b63) : null,
        gradient: paintMode == 0
            ? const LinearGradient(
                colors: [Color(0xfff857a6), Color(0xffff5858)])
            : null,
      ),
      child: const SizedBox(width: 220, height: 150),
    );
    return _DemoFrame(
      title: 'MorphMask',
      subtitle:
          'Morph geometry clips real child paint while preserving its layout and semantics.',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _DemoCard(
            child: Center(
                child: MorphMask(
                    icon: shapes[shape]!,
                    color: Colors.white,
                    strokeWidth: 3,
                    semanticLabel: 'Masked paint preview',
                    child: child))),
        const SizedBox(height: 12),
        _DemoCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Shape', style: TextStyle(fontWeight: FontWeight.bold)),
          Wrap(
              spacing: 4,
              children: shapes.keys
                  .map((name) => ChoiceChip(
                      label: Text(name),
                      selected: shape == name,
                      onSelected: (_) => setState(() => shape = name)))
                  .toList()),
          const SizedBox(height: 12),
          const Text('Child paint'),
          Wrap(
              spacing: 4,
              children: ['gradient', 'current color']
                  .asMap()
                  .entries
                  .map((entry) => ChoiceChip(
                      label: Text(entry.value),
                      selected: paintMode == entry.key,
                      onSelected: (_) => setState(() => paintMode = entry.key)))
                  .toList()),
          const SizedBox(height: 10),
          const Text(
              'Cost note: MorphMask uses a saveLayer per painted frame. Keep it for small interactive surfaces, not large icon grids.',
              style: TextStyle(fontSize: 12)),
        ])),
      ]),
    );
  }
}

class _CanvasDemo extends StatefulWidget {
  const _CanvasDemo();

  @override
  State<_CanvasDemo> createState() => _CanvasDemoState();
}

class _CanvasDemoState extends State<_CanvasDemo> {
  bool located = false;
  bool spriteOn = false;
  final pair = MorphPair(MorphIconsLucide.circle, MorphIconsLucide.circleCheck);

  @override
  Widget build(BuildContext context) {
    return _DemoFrame(
      title: 'MorphCanvas',
      subtitle:
          'Deterministic local chart, map-pin state, and sprite composition with CustomPaint.',
      child: Column(children: [
        _DemoCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Trend chart',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const SizedBox(
              height: 120,
              width: double.infinity,
              child: CustomPaint(painter: _TrendPainter())),
        ])),
        const SizedBox(height: 12),
        _DemoCard(
            child: Row(children: [
          MorphCanvas(
              icon: located
                  ? MorphIconsLucide.mapPinCheck
                  : MorphIconsLucide.mapPin,
              size: 52,
              color: const Color(0xff302b63),
              semanticLabel: 'Map pin state'),
          const SizedBox(width: 14),
          Expanded(
              child: Text(located ? 'Location confirmed' : 'Location pending')),
          Switch(
              value: located,
              onChanged: (value) => setState(() => located = value)),
        ])),
        const SizedBox(height: 12),
        _DemoCard(
            child: Row(children: [
          CustomPaint(
              size: const Size.square(58),
              painter: MorphCanvasPainter.controlled(
                  from: MorphIconsLucide.circle,
                  to: MorphIconsLucide.circleCheck,
                  progress: spriteOn ? 1 : 0,
                  color: const Color(0xfff857a6),
                  strokeWidth: 2.5)),
          const SizedBox(width: 14),
          Expanded(child: Text(spriteOn ? 'Sprite: active' : 'Sprite: idle')),
          IconButton(
              onPressed: () => setState(() => spriteOn = !spriteOn),
              icon: MorphIcon(
                  icon:
                      spriteOn ? MorphIconsLucide.pause : MorphIconsLucide.play,
                  semanticLabel: 'Toggle sprite')),
          pair.canvas(
              progress: spriteOn ? 1 : 0,
              size: 32,
              color: const Color(0xff302b63),
              semanticLabel: 'Sprite state'),
        ])),
      ]),
    );
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0xff302b63)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final grid = Paint()
      ..color = const Color(0x22302b63)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      canvas.drawLine(Offset(0, size.height * i / 4),
          Offset(size.width, size.height * i / 4), grid);
    }
    const values = [0.72, 0.58, 0.64, 0.42, 0.49, 0.28, 0.34, 0.16, 0.22];
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final point =
          Offset(size.width * i / (values.length - 1), size.height * values[i]);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) => false;
}

class _IconDataDemo extends StatefulWidget {
  const _IconDataDemo();

  @override
  State<_IconDataDemo> createState() => _IconDataDemoState();
}

class _IconDataDemoState extends State<_IconDataDemo> {
  bool _first = true;
  double _t = 0;
  bool _scrub = false;

  @override
  Widget build(BuildContext context) {
    return _DemoFrame(
      title: 'IconData morph (Material)',
      subtitle:
          'Same MorphIcon, same solver — IconData glyphs morph via the curated table (lib/src/icon_data_resolver.dart).',
      child: Column(children: [
        _DemoCard(
          child: Column(children: [
            const Text('Uncontrolled — swap icon, spring animates',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            MorphIcon(
              icon: _first ? Icons.home : Icons.favorite,
              spring: SpringPreset.snappy,
              size: 72,
              color: const Color(0xff111111),
              semanticLabel: _first ? 'Home' : 'Favorite',
            ),
            const SizedBox(height: 8),
            Text(
              'MorphIcon(icon: Icons.${_first ? "home" : "favorite"})',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => setState(() => _first = !_first),
              child: Text(_first ? 'Morph to favorite' : 'Morph to home'),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        _DemoCard(
          child: Column(children: [
            Row(
              children: [
                const Text('Controlled scrub',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Switch(
                  value: _scrub,
                  onChanged: (v) => setState(() => _scrub = v),
                ),
                const Text('scrub',
                    style: TextStyle(fontSize: 11, fontFamily: 'monospace')),
              ],
            ),
            const SizedBox(height: 8),
            if (_scrub) ...[
              MorphIcon.controlled(
                from: Icons.home,
                icon: Icons.settings,
                progress: _t,
                size: 64,
                color: const Color(0xff302b63),
                semanticLabel: 'Home → Settings at ${(_t * 100).round()}%',
              ),
              Slider(
                value: _t,
                onChanged: (v) => setState(() => _t = v),
              ),
              Text('t = ${_t.toStringAsFixed(2)}',
                  style:
                      const TextStyle(fontFamily: 'monospace', fontSize: 11)),
            ] else
              MorphIcon(
                icon: _first ? Icons.search : Icons.star,
                size: 64,
                color: const Color(0xff302b63),
                semanticLabel: 'Search or star',
              ),
            const SizedBox(height: 8),
            const Text(
              'Same widget: MorphIcon(icon: Icons.search) → Icons.star → Icons.menu → Icons.close — all share the Procrustes polar solver.',
              style: TextStyle(fontSize: 11, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ]),
        ),
        const SizedBox(height: 12),
        _DemoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Imperative via GlobalKey',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const _IconDataImperativeRow(),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _DemoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Mixed: Material IconData → Lucide String d',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const _MixedIconDataRow(),
              const SizedBox(height: 6),
              const Text(
                'Mixed kind is allowed in the unified MorphIcon(Object) — stroked String d (Lucide) and filled IconData resolve to 24×24 and blend via the same plan.',
                style: TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _IconDataImperativeRow extends StatefulWidget {
  const _IconDataImperativeRow();
  @override
  State<_IconDataImperativeRow> createState() => __IconDataImperativeRowState();
}

class __IconDataImperativeRowState extends State<_IconDataImperativeRow> {
  final _key = GlobalKey<MorphIconState>();
  bool _toFav = false;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      MorphIcon(
        key: _key,
        icon: Icons.star,
        size: 48,
        color: const Color(0xff111111),
      ),
      const SizedBox(width: 12),
      const Expanded(
        child: Text('Star → Favorite via key',
            style: TextStyle(fontSize: 12, fontFamily: 'monospace')),
      ),
      FilledButton.tonal(
        onPressed: () {
          _toFav = !_toFav;
          _key.currentState?.morphTo(_toFav ? Icons.favorite : Icons.star);
        },
        child: const Text('morphTo'),
      ),
    ]);
  }
}

class _MixedIconDataRow extends StatefulWidget {
  const _MixedIconDataRow();
  @override
  State<_MixedIconDataRow> createState() => __MixedIconDataRowState();
}

class __MixedIconDataRowState extends State<_MixedIconDataRow> {
  bool _toLucide = false;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      // Demonstrates Object union: IconData home ↔ Lucide X (String d)
      MorphIcon(
        icon: _toLucide ? MorphIconsLucide.x : Icons.home,
        size: 48,
        color: const Color(0xff111111),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          _toLucide
              ? 'Icons.home → Lucide x (mixed)'
              : 'Lucide x → Icons.home (mixed)',
          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
        ),
      ),
      FilledButton.tonal(
        onPressed: () => setState(() => _toLucide = !_toLucide),
        child: const Text('Toggle'),
      ),
    ]);
  }
}

class BridgeApp extends StatefulWidget {
  const BridgeApp({super.key});

  @override
  State<BridgeApp> createState() => _BridgeAppState();
}

class _BridgeAppState extends State<BridgeApp> {
  final _controlledIconKey = GlobalKey<MorphIconState>();
  final _uncontrolledIconKey = GlobalKey<MorphIconState>();

  String _from = _pairs.first.from;
  String _to = _pairs.first.to;
  String _current = _pairs.first.from;
  double _k = 170;
  double _c = 26;
  double _strokeWidth = 2;
  String _mode = 'uncontrolled';
  double _t = 0;

  // Solver telemetry for the current pair.
  double? _theta;
  double? _sigma;
  double? _res;
  int? _subpaths;
  double? _buildMs;

  Timer? _telemetry;

  GlobalKey<MorphIconState> get _iconKey =>
      _mode == 'controlled' ? _controlledIconKey : _uncontrolledIconKey;

  @override
  void initState() {
    super.initState();
    _listen();
    _post({'type': 'ready'});
    _recomputePlan();
    _startTelemetry();
  }

  @override
  void dispose() {
    _telemetry?.cancel();
    super.dispose();
  }

  /* ---------- parent <- iframe ---------- */

  void _listen() {
    web.window.addEventListener(
      'message',
      ((web.MessageEvent e) {
        final data = e.data;
        if (data == null) return;
        try {
          final json = jsonDecode(_stringify(data)) as Map;
          if (json['source'] != 'morphicons-site') return;
          _handle(json);
        } catch (_) {
          // Ignore malformed frames.
        }
      }).toJS,
    );
  }

  void _handle(Map m) {
    if (!mounted || m['source'] != 'morphicons-site') return;
    final cmd = m['cmd'];
    if (cmd is! String) return;

    switch (cmd) {
      case 'pair':
        final from = m['from'];
        final to = m['to'];
        if (from is! String ||
            to is! String ||
            from.trim().isEmpty ||
            to.trim().isEmpty ||
            !_canBuildPlan(from, to)) {
          return;
        }
        setState(() {
          _from = from;
          _to = to;
          _current = _from;
          _t = 0;
        });
        _recomputePlan();
      case 'spring':
        final k = m['k'];
        final c = m['c'];
        if (k is! num ||
            c is! num ||
            !_inRange(k, 40, 600) ||
            !_inRange(c, 4, 40)) {
          return;
        }
        setState(() {
          _k = k.toDouble();
          _c = c.toDouble();
        });
      case 'stroke':
        final stroke = m['stroke'];
        if (stroke is! num || !_inRange(stroke, 1, 2.5)) return;
        setState(() => _strokeWidth = stroke.toDouble());
      case 'mode':
        final mode = m['mode'];
        if (mode is! String ||
            (mode != 'controlled' && mode != 'uncontrolled')) {
          return;
        }
        setState(() {
          _mode = mode;
          _current = _from;
          _t = 0;
        });
        _recomputePlan();
      case 'scrub':
        final t = m['t'];
        if (t is! num || !_inRange(t, 0, 1)) return;
        setState(() => _t = t.toDouble());
      case 'morph':
        if (_mode == 'uncontrolled') {
          setState(() => _current = _current == _from ? _to : _from);
        }
      case 'reset':
        setState(() {
          _current = _from;
          _t = 0;
        });
      default:
        return;
    }
  }

  bool _canBuildPlan(String from, String to) {
    try {
      return planBetween(from, to).items.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  bool _inRange(num value, double min, double max) =>
      value.isFinite && value >= min && value <= max;

  /* ---------- iframe -> parent ---------- */

  void _post(Map<String, Object?> payload) {
    final msg = <String, Object?>{
      'source': 'morphicons-flutter',
      ...payload,
    };
    web.window.parent?.postMessage(msg.jsify(), '*'.toJS);
  }

  void _recomputePlan() {
    final watch = Stopwatch()..start();
    late final MorphPlan plan;
    try {
      plan = planBetween(_from, _to);
    } catch (_) {
      return;
    }
    if (plan.items.isEmpty) return;
    watch.stop();
    final item = plan.items.first;
    setState(() {
      _theta = item.theta;
      _sigma = math.exp(item.lnSigma);
      _res = item.res;
      _subpaths = plan.items.length;
      _buildMs = watch.elapsedMicroseconds / 1000.0;
    });
    _post({
      'type': 'plan',
      'theta': _theta,
      'sigma': _sigma,
      'residual': _res,
      'subpaths': _subpaths,
      'buildMs': _buildMs,
      'blockHybrid': item.block != null,
    });
  }

  void _startTelemetry() {
    _telemetry = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final s = _iconKey.currentState;
      if (s == null) return;
      _post({
        'type': 'telemetry',
        'x': s.progress,
        'v': s.velocity,
        'settled': s.settled,
      });
    });
  }

  /* ---------- UI ---------- */

  @override
  Widget build(BuildContext context) {
    final preset = SpringPreset(_k, _c);
    final icon = _mode == 'controlled'
        ? MorphIcon.controlled(
            key: _iconKey,
            from: _from,
            icon: _to,
            progress: _t,
            size: 168,
            strokeWidth: _strokeWidth,
            color: const Color(0xFF111111),
          )
        : MorphIcon(
            key: _iconKey,
            icon: _current,
            spring: preset,
            size: 168,
            strokeWidth: _strokeWidth,
            color: const Color(0xFF111111),
            semanticLabel: 'Morphing icon',
          );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF111111)),
      ),
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(height: 28),
              _telemetryPanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _telemetryPanel() {
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF787774),
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF111111),
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFEAEAEA)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'morphicons_flutter · live from Flutter',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 0.8,
              color: Color(0xFF787774),
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 10),
          row('mode', _mode),
          row('spring',
              'k=${_k.toStringAsFixed(0)} c=${_c.toStringAsFixed(1)}'),
          row('θ (rotation)',
              _theta == null ? '—' : '${_theta!.toStringAsFixed(4)} rad'),
          row('σ (scale)', _sigma == null ? '—' : _sigma!.toStringAsFixed(4)),
          row('residual', _res == null ? '—' : _res!.toStringAsExponential(2)),
          row('subpaths', _subpaths?.toString() ?? '—'),
          row('buildPlan',
              _buildMs == null ? '—' : '${_buildMs!.toStringAsFixed(2)} ms'),
        ],
      ),
    );
  }
}
