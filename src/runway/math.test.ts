import test from 'node:test';
import assert from 'node:assert/strict';
import {
  computeClassicPose,
  computeFootFractionFromAlpha,
  computeFrameHeight,
  computeRingPose,
  computeStageMetrics,
  ringSlotRank,
  shortestLoopDelta,
  stepSpring,
  wrapMod,
  wrapPi,
} from './math';

test('wrapMod and wrapPi wrap symmetrically', () => {
  assert.equal(wrapMod(-1, 6), 5);
  assert.equal(wrapMod(7, 6), 1);
  assert.ok(Math.abs(wrapPi(Math.PI * 1.5) + Math.PI * 0.5) < 1e-9);
});

test('shortestLoopDelta picks shortest arc across 6 looks', () => {
  assert.equal(shortestLoopDelta(0, 5, 6), -1);
  assert.equal(shortestLoopDelta(5, 0, 6), 1);
  assert.equal(shortestLoopDelta(0, 3, 6), 3);
  assert.equal(shortestLoopDelta(1, 5, 6), -2);
});

test('computeRingPose reproduces exact slot 0..4 values from spec', () => {
  const W = 1000;
  const H = 700;
  const s0 = computeRingPose(0, 0, W, H, false, 1.08, false, true);
  assert.ok(Math.abs(s0.scale - 1.08) < 1e-3);
  assert.ok(Math.abs(s0.x - 500) < 1e-3);
  assert.equal(s0.blur, 0);
  assert.equal(s0.opacity, 1);
  assert.equal(s0.z, 1080);

  const s0Still = computeRingPose(0, 0, W, H, false, 1.08, true, true);
  assert.equal(s0Still.opacity, 0);

  const s1 = computeRingPose(1, 0, W, H, false, 1.08, true, true);
  assert.ok(Math.abs(s1.scale - 0.952) < 0.002);
  assert.ok(Math.abs(s1.x - 795) < 2);
  assert.ok(Math.abs(s1.blur - 1.8) < 1e-6);
  assert.equal(s1.opacity, 1);
  assert.equal(s1.z, 952);

  const s4 = computeRingPose(4, 0, W, H, false, 1.08, true, true);
  assert.ok(Math.abs(s4.scale - 0.64) < 0.002);
  assert.ok(Math.abs(s4.blur - 6.5) < 1e-6);
  assert.ok(Math.abs(s4.opacity - 0.167) < 0.002);
  assert.equal(s4.z, 640);
});

test('computeClassicPose matches phone slots k=0..2', () => {
  const W = 390;
  const p0 = computeClassicPose(0, 0, 0, false, W, true, true, true);
  assert.equal(p0.opacity, 0);
  assert.ok(Math.abs(p0.x - 0.3 * W) < 1e-6);

  const p1 = computeClassicPose(1, 1, 1, false, W, true, true, true);
  assert.ok(Math.abs(p1.x - 0.62 * W) < 1e-6);
  assert.equal(p1.bottom, 44);
  assert.ok(Math.abs(p1.scale - 0.76) < 1e-6);
  assert.ok(Math.abs(p1.opacity - 0.87) < 1e-6);
  assert.ok(Math.abs(p1.blur - 0.9) < 1e-6);
});

test('stepSpring converges smoothly without overshoot', () => {
  let cur = -1.15;
  let vel = 0;
  let settled = false;
  for (let i = 0; i < 120; i++) {
    const res = stepSpring(cur, 0, vel, 1 / 60);
    cur = res.cur;
    vel = res.vel;
    settled = res.settled;
    assert.ok(cur <= 0.01);
    if (settled) break;
  }
  assert.equal(settled, true);
  assert.equal(cur, 0);
});

test('computeFrameHeight and computeStageMetrics match spec formulas', () => {
  assert.equal(computeFrameHeight(false, 900, 88), 812);
  assert.equal(computeFrameHeight(false, 400, 88), 380);
  assert.ok(Math.abs(computeFrameHeight(true, 844, 68, 109) - 844 * 1.09) < 1e-6);

  const m = computeStageMetrics('ring', false, 1060, 700);
  assert.equal(m.fs, 1.08);
  assert.equal(m.hx, 530);
  assert.equal(m.hy, 34);
  assert.equal(m.modelH, Math.round((700 - 34 - 18) / 1.08));
});

test('ringSlotRank returns signed shortest rank in -6..6', () => {
  assert.equal(ringSlotRank(11, 0), -1);
  assert.equal(ringSlotRank(1, 0), 1);
  assert.equal(ringSlotRank(6, 0), 6);
});

test('computeFootFractionFromAlpha scans bottom alpha row accurately', () => {
  // 2x10 image where rows 0..7 are opaque and rows 8..9 are transparent
  const data = new Uint8ClampedArray(2 * 10 * 4);
  for (let y = 0; y < 8; y++) {
    for (let x = 0; x < 2; x++) {
      data[(y * 2 + x) * 4 + 3] = 255;
    }
  }
  const frac = computeFootFractionFromAlpha(data, 2, 10, 40);
  // (10 - 1 - 7) / 10 = 0.2
  assert.ok(Math.abs(frac - 0.2) < 1e-6);
});
