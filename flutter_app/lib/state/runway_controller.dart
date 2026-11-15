import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import '../math/runway_math.dart';
import '../models/catalog.dart';
import 'styling_bag.dart';

class BodySimState {
  BodySimState(this.index)
      : lookIndex = index % lookCount,
        x = index.toDouble(),
        g = index.toDouble(),
        from = index.toDouble(),
        prevGoal = index.toDouble();

  final int index;
  final int lookIndex;
  double x;
  double g;
  double v = 0.0;
  double from;
  bool onTrip = false;
  double prevGoal;
}

class RunwayController extends ChangeNotifier {
  RunwayController({
    required this.bag,
    required TickerProvider vsync,
    this.speedMs = 5000,
    this.enableBlur = true,
  }) {
    _ticker = vsync.createTicker(_onTick);
    _bodies = List.generate(bodyCount, BodySimState.new);
  }

  final StylingBag bag;
  final int speedMs;
  final bool enableBlur;

  late final Ticker _ticker;
  late final List<BodySimState> _bodies;
  Timer? _autoTimer;
  Duration? _lastElapsed;

  int _index = 0;
  double _target = 0.0;
  double _cur = -1.15;
  double _vel = 0.0;
  bool _still = false;
  bool _revealed = false;
  bool _reducedMotion = false;
  bool _isMobile = false;
  RunwayMode _mode = RunwayMode.ring;
  double _stageWidth = 0;
  double _stageHeight = 0;
  double _unit = 200;

  bool _playing = false;
  bool _engaged = false;
  bool _panelHover = false;
  bool _zoomed = false;
  bool _dragging = false;
  int _sweepRevision = 0;
  int? _hotCardNumber;
  int _autoplayCycle = 0;

  // Drag tracking
  double _dragStartTarget = 0.0;
  double _dragTotalDx = 0.0;

  // Per-look, per-slot (1..3) product interaction state
  final Map<String, String> _selectedSizeBySlot = {};
  final Set<String> _touchedSlots = {};
  final Set<String> _openPickers = {};
  final Set<String> _addedSlots = {};
  final Map<int, String> _bundleMessages = {};
  final Map<int, double> _footFractionByLook = {};

  int get index => _index;
  double get target => _target;
  double get cur => _cur;
  bool get still => _still;
  bool get revealed => _revealed;
  bool get reducedMotion => _reducedMotion;
  bool get isMobile => _isMobile;
  RunwayMode get mode => _mode;
  bool get playing => _playing;
  bool get zoomed => _zoomed;
  bool get dragging => _dragging;
  int get sweepRevision => _sweepRevision;
  int? get hotCardNumber => _hotCardNumber;
  int get autoplayCycle => _autoplayCycle;
  double get unit => _unit;
  List<BodySimState> get bodies => _bodies;
  LookSpec get activeLook => RunwayCatalog.looks[_index];

  String _slotKey(int lookIdx, int cardNum) => '$lookIdx:$cardNum';

  String selectedSize(int lookIdx, int cardNum, CatalogItem item) =>
      _selectedSizeBySlot[_slotKey(lookIdx, cardNum)] ?? item.sizes.first;

  bool isTouched(int lookIdx, int cardNum) =>
      _touchedSlots.contains(_slotKey(lookIdx, cardNum));

  bool isPickerOpen(int lookIdx, int cardNum) =>
      _openPickers.contains(_slotKey(lookIdx, cardNum));

  bool isAdded(int lookIdx, int cardNum) =>
      _addedSlots.contains(_slotKey(lookIdx, cardNum));

  bool isLookComplete(int lookIdx) {
    final look = RunwayCatalog.looks[lookIdx];
    if (look.productIds.length < 2) return false;
    for (var i = 0; i < look.productIds.length; i++) {
      if (!isAdded(lookIdx, i + 1)) return false;
    }
    return true;
  }

  String bundleMessage(int lookIdx) => _bundleMessages[lookIdx] ?? '';

  double footFraction(int lookIdx) => _footFractionByLook[lookIdx] ?? 0.0;

  void setFootFraction(int lookIdx, double frac) {
    if ((footFraction(lookIdx) - frac).abs() > 0.001) {
      _footFractionByLook[lookIdx] = frac;
      notifyListeners();
    }
  }

  void init({required bool reducedMotion}) {
    _reducedMotion = reducedMotion;
    final startOffset = reducedMotion ? 0.0 : 1.15;
    _target = 0.0;
    _cur = -startOffset;
    _vel = 0.0;
    for (final b in _bodies) {
      final place = b.index + startOffset;
      b.x = place;
      b.g = place;
      b.prevGoal = place;
    }
    if (reducedMotion) {
      _revealed = true;
      _still = true;
      notifyListeners();
    } else {
      Future<void>.delayed(const Duration(milliseconds: 32), () {
        _revealed = true;
        _kick();
        if (!_engaged) play(true);
        notifyListeners();
      });
    }
  }

  void updateViewport({
    required double screenWidth,
    required double stageWidth,
    required double stageHeight,
    required bool reducedMotion,
  }) {
    _reducedMotion = reducedMotion;
    _stageWidth = stageWidth;
    _stageHeight = stageHeight;
    _isMobile = screenWidth <= 749.0;
    final nextMode = _isMobile ? RunwayMode.classic : RunwayMode.ring;
    if (nextMode != _mode) {
      _mode = nextMode;
      if (_mode == RunwayMode.classic) {
        for (final b in _bodies) {
          final goal = wrapMod(b.index - _target, bodyCount);
          b.x = goal;
          b.g = goal;
          b.v = 0.0;
          b.prevGoal = goal;
          b.onTrip = false;
        }
      }
    }
    if (_stageWidth > 0 && _stageHeight > 0) {
      final m = computeStageMetrics(
        mode: _mode,
        isMobile: _isMobile,
        width: _stageWidth,
        height: _stageHeight,
      );
      _unit = m.unit;
    }
  }

  void next() => moveTo(_target.round() + 1.0);

  void prev() => moveTo(_target.round() - 1.0);

  void go(int i) {
    final targetIdx = wrapModInt(i, lookCount);
    final d = shortestLoopDelta(_index, targetIdx, lookCount);
    moveTo(_target.round() + d.toDouble());
  }

  void moveTo(double t) {
    _target = t;
    _still = false;
    final nextIdx = wrapModInt(t.round(), lookCount);
    if (nextIdx != _index) {
      _index = nextIdx;
      _zoomed = false;
      _hotCardNumber = null;
      _sweepRevision++;
    }
    if (_playing) {
      _autoplayCycle++;
      _scheduleAutoplay();
    }
    _kick();
    notifyListeners();
  }

  void toggleAutoplay() {
    if (!_playing) {
      _engaged = false;
      play(true);
    } else {
      play(false);
    }
  }

  void play(bool on) {
    if (on && _reducedMotion) return;
    _playing = on;
    if (on) {
      _autoplayCycle++;
      _scheduleAutoplay();
    } else {
      _autoTimer?.cancel();
      _autoTimer = null;
    }
    notifyListeners();
  }

  void engage() {
    _engaged = true;
    if (_playing) play(false);
  }

  void setPanelHover(bool hover) {
    if (_panelHover == hover) return;
    _panelHover = hover;
    if (!hover && _playing) {
      _autoplayCycle++;
      notifyListeners();
    }
  }

  void _scheduleAutoplay() {
    _autoTimer?.cancel();
    if (!_playing) return;
    _autoTimer = Timer(Duration(milliseconds: speedMs), () {
      if (!_playing) return;
      if (!_dragging && !_panelHover && !_zoomed && !_engaged) {
        next();
      } else {
        _autoplayCycle++;
        _scheduleAutoplay();
        notifyListeners();
      }
    });
  }

  void openPopup() {
    if (_zoomed) return;
    engage();
    _hotCardNumber = null;
    _zoomed = true;
    notifyListeners();
  }

  void closePopup() {
    if (!_zoomed) return;
    _zoomed = false;
    notifyListeners();
  }

  void setHotCard(int? cardNum) {
    if (_hotCardNumber == cardNum) return;
    _hotCardNumber = cardNum;
    notifyListeners();
  }

  void selectSize(int lookIdx, int cardNum, String size) {
    engage();
    final key = _slotKey(lookIdx, cardNum);
    _selectedSizeBySlot[key] = size;
    _touchedSlots.add(key);
    notifyListeners();
  }

  void toggleInlinePicker(int lookIdx, int cardNum) {
    if (isAdded(lookIdx, cardNum)) return;
    engage();
    final key = _slotKey(lookIdx, cardNum);
    if (_openPickers.contains(key)) {
      _openPickers.remove(key);
    } else {
      _openPickers.add(key);
    }
    notifyListeners();
  }

  void closeInlinePicker(int lookIdx, int cardNum) {
    final key = _slotKey(lookIdx, cardNum);
    if (_openPickers.remove(key)) {
      notifyListeners();
    }
  }

  bool confirmCard(int lookIdx, int cardNum, CatalogItem item) {
    if (isAdded(lookIdx, cardNum)) return true;
    engage();
    final key = _slotKey(lookIdx, cardNum);
    _touchedSlots.add(key);
    _bundleMessages.remove(lookIdx);

    final size = selectedSize(lookIdx, cardNum, item);
    final match = item.variants.cast<CatalogVariant?>().firstWhere(
          (v) => v != null && v.options.length == 1 && v.options.first == size,
          orElse: () => null,
        );
    if (match == null || !match.available) {
      _bundleMessages[lookIdx] = 'Couldn’t add to bag. Please try again.';
      notifyListeners();
      return false;
    }

    try {
      bag.add([(id: match.id, quantity: 1)]);
      _openPickers.remove(key);
      _addedSlots.add(key);
      if (isLookComplete(lookIdx)) {
        _bundleMessages.remove(lookIdx);
      }
      notifyListeners();
      return true;
    } catch (_) {
      _bundleMessages[lookIdx] = 'Couldn’t add to bag. Please try again.';
      notifyListeners();
      return false;
    }
  }

  /// Attempts to add all ready pieces in [lookIdx].
  /// Returns the 1-based card numbers of pending items whose size was not touched yet.
  List<int> addFullLook(int lookIdx) {
    if (isLookComplete(lookIdx)) return const [];
    engage();
    _bundleMessages.remove(lookIdx);

    final look = RunwayCatalog.looks[lookIdx];
    final ready = <({int cardNum, int variantId})>[];
    final pendingNums = <int>[];
    final pendingNames = <String>[];

    for (var i = 0; i < look.productIds.length; i++) {
      final cardNum = i + 1;
      if (isAdded(lookIdx, cardNum)) continue;
      final item = RunwayCatalog.requireItem(look.productIds[i]);
      final key = _slotKey(lookIdx, cardNum);
      if (_touchedSlots.contains(key)) {
        final size = selectedSize(lookIdx, cardNum, item);
        final variant = item.variants.cast<CatalogVariant?>().firstWhere(
              (v) => v != null && v.available && v.options.first == size,
              orElse: () => null,
            );
        if (variant != null) {
          ready.add((cardNum: cardNum, variantId: variant.id));
        }
      } else {
        pendingNums.add(cardNum);
        pendingNames.add(item.name);
      }
    }

    if (ready.isNotEmpty) {
      try {
        bag.add(ready.map((r) => (id: r.variantId, quantity: 1)).toList());
        for (final r in ready) {
          final key = _slotKey(lookIdx, r.cardNum);
          _openPickers.remove(key);
          _addedSlots.add(key);
        }
      } catch (_) {
        _bundleMessages[lookIdx] = 'Couldn’t add to bag. Please try again.';
        notifyListeners();
        return pendingNums;
      }
    }

    if (pendingNums.isNotEmpty) {
      if (!_isMobile) {
        for (final num in pendingNums) {
          _openPickers.add(_slotKey(lookIdx, num));
        }
      }
      _bundleMessages[lookIdx] = 'Pick a size for: ${pendingNames.join(', ')}';
    } else if (isLookComplete(lookIdx)) {
      _bundleMessages.remove(lookIdx);
    }

    notifyListeners();
    return pendingNums;
  }

  // --- Stage Drag Physics ---

  void startDrag() {
    _dragging = true;
    _still = false;
    _dragStartTarget = _target;
    _dragTotalDx = 0.0;
    _kick();
    notifyListeners();
  }

  void updateDrag(double deltaDx) {
    if (!_dragging) return;
    _dragTotalDx += deltaDx;
    _target = _dragStartTarget - (_dragTotalDx / math.max(90.0, _unit));
    _kick();
    notifyListeners();
  }

  void endDrag(double velocityPxPerSec) {
    if (!_dragging) return;
    _dragging = false;
    final vxMs = velocityPxPerSec / 1000.0;
    const sign = -1.0;
    final from = _dragStartTarget.round();

    if (_isMobile) {
      if (_dragTotalDx.abs() > 30.0 || vxMs.abs() > 0.3) {
        moveTo((from + sign * (_dragTotalDx > 0 ? 1 : -1)).toDouble());
      } else {
        moveTo(from.toDouble());
      }
    } else {
      var nextIdx = (_target + (sign * vxMs * 160.0) / math.max(90.0, _unit)).round();
      if (nextIdx == from && vxMs.abs() > 0.3) {
        nextIdx += (sign * (vxMs > 0 ? 1 : -1)).round();
      }
      nextIdx = nextIdx.clamp(from - 2, from + 2);
      moveTo(nextIdx.toDouble());
    }
  }

  void _kick() {
    if (_ticker.isActive) return;
    _lastElapsed = null;
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    final dt = _lastElapsed == null
        ? 1.0 / 60.0
        : math.min(0.034, (elapsed - _lastElapsed!).inMicroseconds / 1e6);
    _lastElapsed = elapsed;

    if (_reducedMotion) {
      _cur = _target;
      _vel = 0.0;
      for (final b in _bodies) {
        final goal = wrapMod(b.index - _target, bodyCount);
        b.x = goal;
        b.g = goal;
        b.v = 0.0;
        b.onTrip = false;
        b.prevGoal = goal;
      }
      _still = true;
      _ticker.stop();
      notifyListeners();
      return;
    }

    var keepGoing = _dragging;

    if (_mode == RunwayMode.ring) {
      final res = stepSpring(_cur, _target, _vel, dt);
      _cur = res.cur;
      _vel = res.vel;
      if (!_dragging && res.settled) {
        _still = true;
      } else {
        _still = false;
        keepGoing = true;
      }
    } else {
      var allSettled = !_dragging;
      for (final b in _bodies) {
        final goal = wrapMod(b.index - _target, bodyCount);
        if (!_dragging && (goal - b.prevGoal).abs() > bodyCount / 2) {
          b.onTrip = true;
          b.from = b.x;
        }
        b.prevGoal = goal;

        final tau = _dragging
            ? 0.016
            : (b.onTrip ? 0.1 : 0.03 + 0.04 * math.min(goal, 4.0));

        b.g += (goal - b.g) * (1.0 - math.exp(-dt / tau));
        final res = stepSpring(b.x, b.g, b.v, dt, 0.0006);
        b.x = res.cur;
        b.v = res.vel;

        if (b.onTrip && (b.x - goal).abs() < 0.02) {
          b.onTrip = false;
        }

        if (!res.settled || (b.g - goal).abs() > 0.0006 || b.onTrip) {
          allSettled = false;
        } else {
          b.x = goal;
          b.g = goal;
        }
      }

      _cur = _target;
      if (allSettled) {
        _still = true;
      } else {
        _still = false;
        keepGoing = true;
      }
    }

    if (!keepGoing) {
      _ticker.stop();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _ticker.dispose();
    super.dispose();
  }
}
