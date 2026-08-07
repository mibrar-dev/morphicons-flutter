/// MorphScheduler: singleton Ticker-driven loop that steps every registered
/// spring once per frame.
///
/// Mirrors upstream's single shared requestAnimationFrame scheduler.
/// Stops the ticker when no springs are active.
library;

import 'package:flutter/scheduler.dart';

/// A spring that can be stepped by the scheduler.
typedef SpringTicker = void Function(double dt);

/// Singleton scheduler that drives all morph animations with a single Ticker.
///
/// This mirrors the upstream JS implementation's single rAF loop:
/// all morph instances share one Ticker, minimizing per-frame overhead.
class MorphScheduler implements TickerProvider {
  MorphScheduler._();

  /// The singleton instance.
  static final MorphScheduler instance = MorphScheduler._();

  Ticker? _ticker;
  final Set<SpringTicker> _tickers = {};
  Duration? _lastTime;

  /// Creates a ticker for this provider.
  ///
  /// Called by AnimationController or any ticker-based animation.
  @override
  Ticker createTicker(TickerCallback onTick) {
    return Ticker(onTick);
  }

  /// Registers a spring ticker to be stepped every frame.
  ///
  /// Starts the shared ticker if this is the first registration.
  void register(SpringTicker ticker) {
    _tickers.add(ticker);
    if (_tickers.length == 1) {
      _startTicker();
    }
  }

  /// Unregisters a spring ticker.
  ///
  /// Stops the shared ticker if this is the last unregistration.
  void unregister(SpringTicker ticker) {
    _tickers.remove(ticker);
    if (_tickers.isEmpty) {
      _stopTicker();
    }
  }

  void _startTicker() {
    if (_ticker != null) return;
    _lastTime = null;
    _ticker = createTicker(_onTick)..start();
  }

  void _stopTicker() {
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = null;
    _lastTime = null;
  }

  void _onTick(Duration elapsed) {
    final last = _lastTime;
    _lastTime = elapsed;

    // First frame: dt = 0 (paints current state, no jump).
    final dt = last == null
        ? 0.0
        : (elapsed - last).inMicroseconds / 1000000.0;

    // Clamp dt to prevent jumps from backgrounded tabs.
    final clampedDt = dt.clamp(0.0, 0.1);

    // Step all registered springs.
    // Copy to list to allow modifications during iteration.
    for (final ticker in _tickers.toList()) {
      ticker(clampedDt);
    }
  }

  /// Whether the scheduler is currently running.
  bool get isRunning => _ticker != null && _ticker!.isActive;

  /// Number of active tickers (for debugging/testing).
  int get activeCount => _tickers.length;
}
