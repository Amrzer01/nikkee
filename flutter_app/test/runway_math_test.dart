import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:try_the_look_runway/math/runway_math.dart';
import 'package:try_the_look_runway/models/catalog.dart';
import 'package:try_the_look_runway/state/styling_bag.dart';

void main() {
  test('catalog contains all 6 looks and 8 unique items with exact prices', () {
    expect(RunwayCatalog.looks.length, 6);
    expect(RunwayCatalog.items.length, 8);
    expect(RunwayCatalog.looks[0].name, 'The City Edit');
    expect(RunwayCatalog.requireItem('tatum-5-orbit-copy').vendorLine, 'Nikey | Password: 1');
    expect(RunwayCatalog.requireItem('tshirt').sizes, ['S', 'L', 'M', 'XL']);
  });

  test('computeRingPose matches spec slot metrics', () {
    final frontStill = computeRingPose(
      bodyIndex: 0,
      cur: 0,
      width: 1000,
      height: 800,
      isMobile: false,
      fs: 1.08,
      still: true,
      enableBlur: true,
    );
    expect(frontStill.opacity, 0.0);
    expect(frontStill.scale, closeTo(1.08, 0.001));
    expect(frontStill.z, 1080);

    final slot1 = computeRingPose(
      bodyIndex: 1,
      cur: 0,
      width: 1000,
      height: 800,
      isMobile: false,
      fs: 1.08,
      still: true,
      enableBlur: true,
    );
    expect(slot1.scale, closeTo(0.952, 0.002));
    expect(slot1.x / 1000, closeTo(0.795, 0.002));
    expect(slot1.blur, closeTo(1.8, 0.01));
  });

  test('stepSpring converges to target without overshoot', () {
    var cur = -1.15;
    var vel = 0.0;
    for (var i = 0; i < 180; i++) {
      final res = stepSpring(cur, 0.0, vel, 1 / 60);
      cur = res.cur;
      vel = res.vel;
      expect(cur, lessThanOrEqualTo(0.001));
      if (res.settled) break;
    }
    expect(cur, 0.0);
    expect(vel, 0.0);
  });

  test('shortestLoopDelta picks shortest arc around 6 looks', () {
    expect(shortestLoopDelta(0, 5), -1);
    expect(shortestLoopDelta(5, 0), 1);
    expect(shortestLoopDelta(1, 3), 2);
  });

  test('ringSlotRank returns signed shortest rank in -6..6', () {
    expect(ringSlotRank(0, 0), 0);
    expect(ringSlotRank(11, 0), -1);
    expect(ringSlotRank(6, 0), 6);
  });

  test('computeFootFractionFromRgba finds last non-transparent pixel row', () {
    const w = 4;
    const h = 10;
    final rgba = Uint8List(w * h * 4);
    rgba[(7 * w + 2) * 4 + 3] = 255;
    expect(computeFootFractionFromRgba(rgba, w, h, 40), closeTo(0.2, 0.0001));
  });

  test('StylingBag enforces Shopify host, validates variants, and formats shortlist', () {
    final bag = StylingBag();
    bag.add([
      (id: 57015166796081, quantity: 1), // Tatum 5 Orbit size 42 ($149)
      (id: 56836251681073, quantity: 1), // Hoodie Black size S ($199)
    ]);
    expect(bag.totalCount, 2);
    expect(bag.subtotal, 348.0);
    final shortlist = bag.buildShortlistText();
    expect(shortlist, contains('RUNWAY — STYLING SHORTLIST'));
    expect(shortlist, contains('Tatum 5 Orbit · Size 42 · Quantity 1'));
    expect(() => StylingBag.validateProductUri('https://evil.example.com/item'), throwsArgumentError);
  });
}
