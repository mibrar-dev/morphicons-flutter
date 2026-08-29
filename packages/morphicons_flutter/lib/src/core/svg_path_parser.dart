/// Parser for the SVG `d` attribute (path data).
///
/// Resolves relative commands and shorthands (H/V → L, S/T → C/Q with
/// control-point reflection) and returns raw subpaths with absolute commands.
/// Supports implicit repetition, extra pairs after M (implicit lineto),
/// packed arc flags and scientific notation.
///
/// Conversion to cubics lives in normalize.dart.
library;

/// Raw absolute segment (shorthands already resolved), as a labeled tuple.
/// Compact representation matching the TypeScript original.
sealed class RawSeg {}

class RawSegLine extends RawSeg {
  final double x;
  final double y;
  RawSegLine(this.x, this.y);
}

class RawSegCubic extends RawSeg {
  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final double x;
  final double y;
  RawSegCubic(this.x1, this.y1, this.x2, this.y2, this.x, this.y);
}

class RawSegQuad extends RawSeg {
  final double x1;
  final double y1;
  final double x;
  final double y;
  RawSegQuad(this.x1, this.y1, this.x, this.y);
}

class RawSegArc extends RawSeg {
  final double rx;
  final double ry;
  final double rotDeg;
  final int large; // 0 or 1
  final int sweep; // 0 or 1
  final double x;
  final double y;
  RawSegArc(this.rx, this.ry, this.rotDeg, this.large, this.sweep, this.x, this.y);
}

/// Raw subpath: start point + list of segments + closed flag.
class RawSubpath {
  final double x0;
  final double y0;
  final List<RawSeg> segs;
  bool closed;

  RawSubpath({required this.x0, required this.y0, required this.segs, required this.closed});
}

// Command characters recognized by the parser.
const _commands = 'MmLlHhVvCcSsQqTtAaZz';

/// Parses an SVG path `d` attribute into a list of raw subpaths.
///
/// All commands are resolved to absolute coordinates:
/// - H/V → L
/// - S → C (with control-point reflection)
/// - T → Q (with control-point reflection)
/// - Relative commands (lowercase) converted to absolute
List<RawSubpath> parsePath(String d) {
  final subs = <RawSubpath>[];
  final n = d.length;
  var i = 0;
  var cx = 0.0; // current point
  var cy = 0.0;
  var sx = 0.0; // start of the current subpath
  var sy = 0.0;
  RawSubpath? cur;
  var cmd = '';
  var px = 0.0; // last control point (S/T reflection)
  var py = 0.0;
  var prev = ''; // 'C', 'Q', or ''
  var started = false; // the first command must be M/m

  Never err(String msg) {
    throw FormatException('morphicons: $msg at d[$i]');
  }

  bool isDigit(int c) => c >= 48 && c <= 57;

  void skip() {
    while (i < n) {
      final c = d.codeUnitAt(i);
      // Space, tab, newline, carriage return, form feed, comma
      if (c == 32 || c == 9 || c == 10 || c == 13 || c == 12 || c == 44) {
        i++;
      } else {
        break;
      }
    }
  }

  double num() {
    skip();
    final start = i;
    if (i < n && (d[i] == '+' || d[i] == '-')) i++;
    var dig = false;
    while (i < n && isDigit(d.codeUnitAt(i))) {
      i++;
      dig = true;
    }
    if (i < n && d[i] == '.') {
      i++;
      while (i < n && isDigit(d.codeUnitAt(i))) {
        i++;
        dig = true;
      }
    }
    if (!dig) err('expected number');
    if (i < n && (d[i] == 'e' || d[i] == 'E')) {
      final save = i;
      i++;
      if (i < n && (d[i] == '+' || d[i] == '-')) i++;
      var ed = false;
      while (i < n && isDigit(d.codeUnitAt(i))) {
        i++;
        ed = true;
      }
      if (!ed) i = save; // dangling "e": not an exponent
    }
    return double.parse(d.substring(start, i));
  }

  // Arc flag: a single 0|1 character; accepts the packed form "011 1".
  int flag() {
    skip();
    final c = d[i];
    if (c == '0' || c == '1') {
      i++;
      return c == '1' ? 1 : 0;
    }
    return err('expected arc flag (0|1)');
  }

  // Subpath in progress; after Z, a drawing command opens a new one at (sx, sy).
  RawSubpath open() {
    if (!started) err('path must start with M/m');
    if (cur == null) {
      cur = RawSubpath(x0: cx, y0: cy, segs: [], closed: false);
      subs.add(cur!);
    }
    return cur!;
  }

  // Relative mode flag
  var rel = false;
  double nx() => num() + (rel ? cx : 0);
  double ny() => num() + (rel ? cy : 0);

  while (true) {
    skip();
    if (i >= n) break;
    final ch = d[i];
    if (_commands.contains(ch)) {
      cmd = ch;
      i++;
    } else if (cmd == '') {
      err('path must start with M/m');
    } else if (cmd == 'M') {
      cmd = 'L'; // extra pairs after M → implicit lineto
    } else if (cmd == 'm') {
      cmd = 'l';
    } else if (cmd == 'Z' || cmd == 'z') {
      err('stray data after Z');
    }
    rel = cmd.toLowerCase() == cmd;

    final cmdUpper = rel ? cmd.toUpperCase() : cmd;
    switch (cmdUpper) {
      case 'M': {
        started = true;
        final x = nx();
        final y = ny();
        cx = x;
        cy = y;
        sx = x;
        sy = y;
        cur = RawSubpath(x0: x, y0: y, segs: [], closed: false);
        subs.add(cur!);
        prev = '';
        break;
      }
      case 'L': {
        final x = nx();
        final y = ny();
        open().segs.add(RawSegLine(x, y));
        cx = x;
        cy = y;
        prev = '';
        break;
      }
      case 'H': {
        final x = nx();
        open().segs.add(RawSegLine(x, cy));
        cx = x;
        prev = '';
        break;
      }
      case 'V': {
        final y = ny();
        open().segs.add(RawSegLine(cx, y));
        cy = y;
        prev = '';
        break;
      }
      case 'C':
      case 'S': {
        double x1, y1;
        if (cmd == 'C' || cmd == 'c') {
          x1 = nx();
          y1 = ny();
        } else {
          // S: reflect previous control point
          x1 = prev == 'C' ? 2 * cx - px : cx;
          y1 = prev == 'C' ? 2 * cy - py : cy;
        }
        final x2 = nx();
        final y2 = ny();
        final x = nx();
        final y = ny();
        open().segs.add(RawSegCubic(x1, y1, x2, y2, x, y));
        px = x2;
        py = y2;
        cx = x;
        cy = y;
        prev = 'C';
        break;
      }
      case 'Q':
      case 'T': {
        double x1, y1;
        if (cmd == 'Q' || cmd == 'q') {
          x1 = nx();
          y1 = ny();
        } else {
          // T: reflect previous control point
          x1 = prev == 'Q' ? 2 * cx - px : cx;
          y1 = prev == 'Q' ? 2 * cy - py : cy;
        }
        final x = nx();
        final y = ny();
        open().segs.add(RawSegQuad(x1, y1, x, y));
        px = x1;
        py = y1;
        cx = x;
        cy = y;
        prev = 'Q';
        break;
      }
      case 'A': {
        final rx = num();
        final ry = num();
        final rot = num();
        final large = flag();
        final sweep = flag();
        final x = nx();
        final y = ny();
        open().segs.add(RawSegArc(rx, ry, rot, large, sweep, x, y));
        cx = x;
        cy = y;
        prev = '';
        break;
      }
      case 'Z': {
        if (cur != null) {
          cur!.closed = true;
          cur = null;
        }
        cx = sx;
        cy = sy;
        prev = '';
        break;
      }
      default:
        err('unsupported command "$cmd"');
    }
  }

  return subs.where((s) => s.segs.isNotEmpty).toList();
}
