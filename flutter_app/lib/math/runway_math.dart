import 'dart:math' as math;
import 'dart:typed_data';

const int lookCount = 6;
const int bodyCount = 12; // 6 * ceil(8 / 6) = 12
const double springStiffness = 95.0;
final double springDamping = 2.0 * math.sqrt(springStiffness);
const double followLag = 0.04;

enum RunwayMode { ring, classic }

class RingPose {
  const RingPose({
    required this.x,
    required this.bottom,
    required this.scale,
    required this.opacity,
    required this.blur,
    required this.z,
    required this.sl,
    required this.phi,
  });

  final double x;
  final double bottom;
  final double scale;
  final double opacity;
  final double blur;
  final int z;
  final double sl;
  final double phi;
}

class ClassicPose {
  const ClassicPose({
    required this.x,
    required this.bottom,
    required this.scale,
    required this.opacity,
    required this.blur,
    required this.z,
    required this.isExit,
  });

  final double x;
  final double bottom;
  final double scale;
  final double opacity;
  final double blur;
  final int z;
  final bool isExit;
}

class StageMetrics {
  const StageMetrics({
    required this.fs,
    required this.modelH,
    required this.hx,
    required this.hy,
    required this.unit,
  });

  final double fs;
  final double modelH;
  final double hx;
  final double hy;
  final double unit;
}

class SpringStep {
  const SpringStep({
    required this.cur,
    required this.vel,
    required this.settled,
  });

  final double cur;
  final double vel;
  final bool settled;
}

double clampDouble(double value, double min, double max) =>
    math.max(min, math.min(max, value));

double wrapMod(double value, int mod) => ((value % mod) + mod) % mod;

int wrapModInt(int value, int mod) => ((value % mod) + mod) % mod;

double wrapPi(double angle) {
  const twoPi = math.pi * 2.0;
  var a = angle % twoPi;
  if (a < 0) a += twoPi;
  if (a > math.pi) a -= twoPi;
  return a;
}

int shortestLoopDelta(int fromIndex, int toIndex, [int count = lookCount]) {
  var d = wrapModInt(toIndex - fromIndex, count);
  if (d > count / 2) d -= count;
  return d;
}

SpringStep stepSpring(
  double cur,
  double target,
  double vel,
  double dt, [
  double tolerance = 0.0005,
]) {
  const steps = 3;
  final h = dt / steps;
  var c = cur;
  var v = vel;
  for (var i = 0; i < steps; i++) {
    final acc = -springStiffness * (c - target) - springDamping * v;
    v += acc * h;
    c += v * h;
  }
  if ((c - target).abs() <= tolerance && v.abs() <= tolerance) {
    return SpringStep(cur: target, vel: 0, settled: true);
  }
  return SpringStep(cur: c, vel: v, settled: false);
}

RingPose computeRingPose({
  required int bodyIndex,
  required double cur,
  required double width,
  required double height,
  required bool isMobile,
  required double fs,
  required bool still,
  required bool enableBlur,
}) {
  const step = (math.pi * 2.0) / bodyCount;
  final cx = 0.5 * width;
  final r = (isMobile ? 0.72 : 0.62) * width;
  final p = (isMobile ? 1.9 : 1.65) * width;
  final floor = height - 34.0;
  final horizon = 0.36 * height;

  final phi = wrapPi((bodyIndex - cur) * step);
  final zDepth = r * (1.0 - math.cos(phi));
  final persp = p / (p + zDepth);
  final sl = phi.abs() / step;
  final scale = persp * (1.0 + (fs - 1.0) * clampDouble(1.0 - sl, 0.0, 1.0));
  final x = cx + r * math.sin(phi) * persp;
  final feet = horizon + (floor - horizon) * persp;
  final bottom = height - feet;
  final blur =
      enableBlur ? (sl <= 1.0 ? 1.8 * sl : math.min(1.8 + (sl - 1.0) * 2.0, 6.5)) : 0.0;
  var opacity = clampDouble((math.cos(phi) + 0.55) / 0.3, 0.0, 1.0);

  if (still && sl < 0.02) {
    opacity = 0.0;
  }

  return RingPose(
    x: x,
    bottom: bottom,
    scale: scale,
    opacity: opacity,
    blur: blur,
    z: (scale * 1000).round(),
    sl: sl,
    phi: phi,
  );
}

ClassicPose computeClassicPose({
  required double xPlace,
  required double goal,
  required double fromPlace,
  required bool onTrip,
  required double width,
  required bool isMobile,
  required bool still,
  required bool enableBlur,
}) {
  final ax = isMobile ? 0.3 : 0.4;
  final ay = isMobile ? 22.0 : 36.0;
  final sx = isMobile ? 0.32 : 0.125;
  final sy = isMobile ? 22.0 : 58.0;
  const sr = 0.76;
  final ex = isMobile ? 0.55 : 0.38;
  final d = isMobile ? 4 : 5;

  var k = xPlace;
  var e = -1.0;

  if (onTrip) {
    final denom = (goal - fromPlace).abs();
    final u = clampDouble((xPlace - fromPlace).abs() / (denom == 0 ? 1.0 : denom), 0.0, 1.0);
    if (goal > fromPlace) {
      if (u < 0.5) {
        e = 2.0 * u * 1.4;
      } else {
        k = goal + 2.0 * (1.0 - u);
      }
    } else {
      if (u < 0.5) {
        k = fromPlace + 2.0 * u;
      } else {
        e = 2.0 * (1.0 - u) * 1.4;
      }
    }
  } else if (k < 0) {
    e = math.min(-k, 1.4);
  }

  if (e >= 0) {
    return ClassicPose(
      x: width * (ax - ex * e),
      bottom: ay - 22.0 * e,
      scale: 1.0 + 0.14 * e,
      opacity: math.max(0.0, 1.0 - 1.05 * e),
      blur: enableBlur ? 4.0 * math.min(e, 1.0) : 0.0,
      z: 1100,
      isExit: true,
    );
  }

  final x = width * (ax + sx * k);
  final bottom = ay + sy * k;
  final scale = math.pow(sr, k).toDouble();
  var opacity = k <= d - 1 ? 1.0 - 0.13 * k : math.max(0.0, 0.61 * (d - k));
  if (still && k.abs() < 0.02) {
    opacity = 0.0;
  }
  final blur = enableBlur ? math.min(0.9 * k, 3.2) : 0.0;
  final z = 1000 - (10.0 * k).round();

  return ClassicPose(
    x: x,
    bottom: bottom,
    scale: scale,
    opacity: opacity,
    blur: blur,
    z: z,
    isExit: false,
  );
}

double computeFrameHeight({
  required bool isMobile,
  required double viewportHeight,
  required double headerHeight,
  double mheightVh = 109.0,
}) {
  if (isMobile) {
    return viewportHeight * (clampDouble(mheightVh, 50.0, 120.0) / 100.0);
  }
  return math.max(380.0, viewportHeight - headerHeight);
}

StageMetrics computeStageMetrics({
  required RunwayMode mode,
  required bool isMobile,
  required double width,
  required double height,
}) {
  final fs = mode == RunwayMode.ring ? 1.08 : 1.0;
  final hy = mode == RunwayMode.ring ? 34.0 : (isMobile ? 22.0 : 36.0);
  final hx = mode == RunwayMode.ring ? 0.5 * width : (isMobile ? 0.3 : 0.4) * width;
  final modelH = mode == RunwayMode.ring
      ? math.max(200.0, ((height - 34.0 - 18.0) / 1.08).roundToDouble())
      : math.max(200.0, (height - (isMobile ? 24.0 : 36.0) - 18.0).roundToDouble());
  final unit = mode == RunwayMode.ring
      ? math.max(isMobile ? 90.0 : 120.0, 0.3 * width)
      : math.max(isMobile ? 90.0 : 120.0, width * (isMobile ? 0.32 : 0.125) * 1.6);

  return StageMetrics(fs: fs, modelH: modelH, hx: hx, hy: hy, unit: unit);
}

int ringSlotRank(int bodyIndex, double target) {
  var k = (bodyIndex - target).round() % bodyCount;
  if (k < 0) k += bodyCount;
  if (k > bodyCount ~/ 2) k -= bodyCount;
  if (k == -6) k = 6;
  return k;
}

double computeFootFractionFromRgba(
  Uint8List rgba,
  int width,
  int height, [
  int threshold = 40,
]) {
  if (width <= 0 || height <= 0) return 0.0;
  var lastRow = height - 1;
  var found = false;
  for (var y = height - 1; y >= 0; y--) {
    final rowOffset = y * width * 4;
    for (var x = 0; x < width; x++) {
      if (rgba[rowOffset + x * 4 + 3] > threshold) {
        lastRow = y;
        found = true;
        break;
      }
    }
    if (found) break;
  }
  if (!found) return 0.0;
  return clampDouble((height - 1 - lastRow) / height, 0.0, 0.4);
}
