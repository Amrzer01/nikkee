export const LOOK_COUNT = 6;
export const BODY_COUNT = 12; // n * Math.ceil(8 / n) = 6 * 2 = 12
export const STIFFNESS = 95;
export const DAMPING = 2 * Math.sqrt(STIFFNESS); // ~19.49358869
export const FOLLOW_LAG = 0.04;

export type RunwayMode = 'ring' | 'classic';

export interface RingPose {
  x: number;
  bottom: number;
  scale: number;
  opacity: number;
  blur: number;
  z: number;
  sl: number;
  phi: number;
}

export interface ClassicPose {
  x: number;
  bottom: number;
  scale: number;
  opacity: number;
  blur: number;
  z: number;
  isExit: boolean;
}

export interface FrameMetrics {
  frameH: number;
  fs: number;
  modelH: number;
  hx: number;
  hy: number;
  unit: number;
}

export function clamp(val: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, val));
}

export function wrapMod(value: number, mod: number): number {
  return ((value % mod) + mod) % mod;
}

export function wrapPi(angle: number): number {
  const twoPi = Math.PI * 2;
  let a = wrapMod(angle, twoPi);
  if (a > Math.PI) a -= twoPi;
  return a;
}

export function shortestLoopDelta(fromIndex: number, toIndex: number, count = LOOK_COUNT): number {
  let d = wrapMod(toIndex - fromIndex, count);
  if (d > count / 2) d -= count;
  return d;
}

export function stepSpring(
  cur: number,
  target: number,
  vel: number,
  dt: number,
  tolerance = 0.0005
): { cur: number; vel: number; settled: boolean } {
  const steps = 3;
  const h = dt / steps;
  let c = cur;
  let v = vel;
  for (let i = 0; i < steps; i++) {
    const acc = -STIFFNESS * (c - target) - DAMPING * v;
    v += acc * h;
    c += v * h;
  }
  if (Math.abs(c - target) <= tolerance && Math.abs(v) <= tolerance) {
    return { cur: target, vel: 0, settled: true };
  }
  return { cur: c, vel: v, settled: false };
}

export function computeRingPose(
  bodyIndex: number,
  cur: number,
  W: number,
  H: number,
  isMobile: boolean,
  fs: number,
  still: boolean,
  enableBlur: boolean
): RingPose {
  const step = (Math.PI * 2) / BODY_COUNT; // 30deg
  const cx = 0.5 * W;
  const R = (isMobile ? 0.72 : 0.62) * W;
  const P = (isMobile ? 1.9 : 1.65) * W;
  const floor = H - 34;
  const horizon = 0.36 * H;

  const phi = wrapPi((bodyIndex - cur) * step);
  const zDepth = R * (1 - Math.cos(phi));
  const persp = P / (P + zDepth);
  const sl = Math.abs(phi) / step;
  const scale = persp * (1 + (fs - 1) * clamp(1 - sl, 0, 1));
  const x = cx + R * Math.sin(phi) * persp;
  const feet = horizon + (floor - horizon) * persp;
  const bottom = H - feet;
  const blur = enableBlur ? (sl <= 1 ? 1.8 * sl : Math.min(1.8 + (sl - 1) * 2, 6.5)) : 0;
  let opacity = clamp((Math.cos(phi) + 0.55) / 0.3, 0, 1);

  if (still && sl < 0.02) {
    opacity = 0;
  }

  const z = Math.round(scale * 1000);
  return { x, bottom, scale, opacity, blur, z, sl, phi };
}

export function computeClassicPose(
  xPlace: number,
  goal: number,
  fromPlace: number,
  onTrip: boolean,
  W: number,
  isMobile: boolean,
  still: boolean,
  enableBlur: boolean
): ClassicPose {
  const ax = isMobile ? 0.3 : 0.4;
  const ay = isMobile ? 22 : 36;
  const sx = isMobile ? 0.32 : 0.125;
  const sy = isMobile ? 22 : 58;
  const sr = 0.76;
  const ex = isMobile ? 0.55 : 0.38;
  const d = isMobile ? 4 : 5;

  let k = xPlace;
  let e = -1;

  if (onTrip) {
    const denom = Math.abs(goal - fromPlace) || 1;
    const u = clamp(Math.abs(xPlace - fromPlace) / denom, 0, 1);
    if (goal > fromPlace) {
      if (u < 0.5) {
        e = 2 * u * 1.4;
      } else {
        k = goal + 2 * (1 - u);
      }
    } else {
      if (u < 0.5) {
        k = fromPlace + 2 * u;
      } else {
        e = 2 * (1 - u) * 1.4;
      }
    }
  } else if (k < 0) {
    e = Math.min(-k, 1.4);
  }

  if (e >= 0) {
    return {
      x: W * (ax - ex * e),
      bottom: ay - 22 * e,
      scale: 1 + 0.14 * e,
      opacity: Math.max(0, 1 - 1.05 * e),
      blur: enableBlur ? 4 * Math.min(e, 1) : 0,
      z: 1100,
      isExit: true,
    };
  }

  const x = W * (ax + sx * k);
  const bottom = ay + sy * k;
  const scale = Math.pow(sr, k);
  let opacity = k <= d - 1 ? 1 - 0.13 * k : Math.max(0, 0.61 * (d - k));
  if (still && Math.abs(k) < 0.02) {
    opacity = 0;
  }
  const blur = enableBlur ? Math.min(0.9 * k, 3.2) : 0;
  const z = 1000 - Math.round(10 * k);

  return { x, bottom, scale, opacity, blur, z, isExit: false };
}

export function computeFrameHeight(
  isMobile: boolean,
  innerHeight: number,
  headerHeight: number,
  mheightVh = 109
): number {
  if (isMobile) {
    return innerHeight * (clamp(mheightVh, 50, 120) / 100);
  }
  return Math.max(380, innerHeight - headerHeight);
}

export function computeStageMetrics(
  mode: RunwayMode,
  isMobile: boolean,
  W: number,
  H: number
): Omit<FrameMetrics, 'frameH'> {
  const fs = mode === 'ring' ? 1.08 : 1;
  const hy = mode === 'ring' ? 34 : isMobile ? 22 : 36;
  const hx = mode === 'ring' ? 0.5 * W : (isMobile ? 0.3 : 0.4) * W;
  const modelH =
    mode === 'ring'
      ? Math.max(200, Math.round((H - 34 - 18) / 1.08))
      : Math.max(200, Math.round(H - (isMobile ? 24 : 36) - 18));

  const unit =
    mode === 'ring'
      ? Math.max(isMobile ? 90 : 120, 0.3 * W)
      : Math.max(isMobile ? 90 : 120, W * (isMobile ? 0.32 : 0.125) * 1.6);

  return { fs, modelH, hx, hy, unit };
}

export function ringSlotRank(bodyIndex: number, target: number): number {
  let k = Math.round(bodyIndex - target) % BODY_COUNT;
  if (k > BODY_COUNT / 2) k -= BODY_COUNT;
  if (k < -BODY_COUNT / 2) k += BODY_COUNT;
  if (k === -6) k = 6;
  return k;
}

export function computeFootFractionFromAlpha(
  alphaData: Uint8ClampedArray,
  width: number,
  height: number,
  threshold = 40
): number {
  if (width <= 0 || height <= 0) return 0;
  let lastRow = height - 1;
  let found = false;
  for (let y = height - 1; y >= 0; y--) {
    const rowOffset = y * width * 4;
    for (let x = 0; x < width; x++) {
      if (alphaData[rowOffset + x * 4 + 3] > threshold) {
        lastRow = y;
        found = true;
        break;
      }
    }
    if (found) break;
  }
  if (!found) return 0;
  return clamp((height - 1 - lastRow) / height, 0, 0.4);
}
