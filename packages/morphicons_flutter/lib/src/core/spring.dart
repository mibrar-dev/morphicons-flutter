/// Spring: damped harmonic oscillator over the progress x: 0 → 1,
/// ẍ = k·(1−x) − c·ẋ, integrated with semi-implicit Euler at 1/240 s
/// substeps (stable up to ω·h ≈ 2; with k=420, ω≈20.5 — ample margin).
///
/// Interruptible: [Spring.start] re-plans from the current intermediate
/// sampled shape — x resets to 0 (the new plan's `from` is re-sampled at the
/// interruption point) while velocity is preserved (clamped to ±14), so rapid
/// re-triggering produces no visual jump.
library;

/// Mutable spring state: progress [x] (0 → 1) and velocity [v].
class SpringState {
  double x;
  double v;

  SpringState(this.x, this.v);
}

/// One semi-implicit Euler substep of size [h]:
/// a = k·(1−x) − c·v; v += a·h; x += v·h.
SpringState stepSpring(SpringState s,
    {required double k, required double c, double h = 1 / 240}) {
  final a = k * (1 - s.x) - c * s.v;
  final v = s.v + a * h;
  final x = s.x + v * h;
  return SpringState(x, v);
}

/// Settle condition: |1−x| < 0.001 ∧ |v| < 0.02.
bool springSettled(double x, double v) =>
    (1 - x).abs() < 0.001 && v.abs() < 0.02;

/// Maximum |velocity| allowed when (re)starting a spring mid-flight.
const double springMaxVelocity = 14;

class Spring {
  double x = 1;
  double v = 0;
  double k = 250;
  double c = 24;

  void config(double k, double c) {
    this.k = k;
    this.c = c;
  }

  void applyPreset(SpringPreset preset) {
    k = preset.k;
    c = preset.c;
  }

  /// Starts (or re-plans mid-flight) preserving velocity.
  ///
  /// x resets to 0 because the caller re-samples the current intermediate
  /// shape as the new morph source; preserving v keeps the motion continuous.
  void start() {
    x = 0;
    if (v > springMaxVelocity) v = springMaxVelocity;
    if (v < -springMaxVelocity) v = -springMaxVelocity;
  }

  /// Advances [dt] seconds. Returns true on settle
  /// (|1−x| < 0.001 ∧ |v| < 0.02).
  bool step(double dt) {
    const h = 1 / 240;
    var steps = (dt / h).ceil();
    if (steps < 1) steps = 1;
    if (steps > 16) steps = 16;
    final s = dt / steps;
    var state = SpringState(x, v);
    for (var i = 0; i < steps; i++) {
      state = stepSpring(state, k: k, c: c, h: s);
    }
    x = state.x;
    v = state.v;
    return springSettled(x, v);
  }
}

/// Spring presets (ζ = c/(2√k)) with the API's public names.
class SpringPreset {
  final double k;
  final double c;

  const SpringPreset(this.k, this.c);

  /// ζ = 1.00 — critically damped, no overshoot.
  static const smooth = SpringPreset(170, 26);

  /// ζ = 0.73 — fast, subtle overshoot.
  static const snappy = SpringPreset(420, 30);

  /// ζ = 0.40 — playful.
  static const bouncy = SpringPreset(300, 14);
}
