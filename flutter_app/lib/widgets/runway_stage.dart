import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../math/runway_math.dart';
import '../models/catalog.dart';
import '../state/runway_controller.dart';
import '../theme/runway_tokens.dart';

class RunwayStageColumn extends StatefulWidget {
  const RunwayStageColumn({
    super.key,
    required this.controller,
    required this.isMobile,
    required this.onRevealCard,
  });

  final RunwayController controller;
  final bool isMobile;
  final ValueChanged<int> onRevealCard;

  @override
  State<RunwayStageColumn> createState() => _RunwayStageColumnState();
}

class _RunwayStageColumnState extends State<RunwayStageColumn>
    with TickerProviderStateMixin {
  Offset? _cursorLocal;
  bool _cursorOverView = false;
  bool _cursorOverHit = false;
  late final AnimationController _sweepCtrl;
  late final AnimationController _autoBarCtrl;
  int _seenSweepRev = 0;
  int _seenAutoCycle = -1;

  @override
  void initState() {
    super.initState();
    _sweepCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _autoBarCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.controller.speedMs),
    );
  }

  @override
  void dispose() {
    _sweepCtrl.dispose();
    _autoBarCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;

    if (c.sweepRevision != _seenSweepRev) {
      _seenSweepRev = c.sweepRevision;
      if (!c.reducedMotion) {
        _sweepCtrl.forward(from: 0);
      }
    }
    if (c.playing && c.autoplayCycle != _seenAutoCycle) {
      _seenAutoCycle = c.autoplayCycle;
      _autoBarCtrl.forward(from: 0);
    } else if (!c.playing && _autoBarCtrl.isAnimating) {
      _autoBarCtrl.stop();
    }

    final headPad = widget.isMobile
        ? const EdgeInsets.fromLTRB(20, 30, 20, 0)
        : const EdgeInsets.fromLTRB(56, 44, 56, 0);

    return Container(
      color: RunwayColors.stage,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedOpacity(
                opacity: c.zoomed ? 0.0 : (c.revealed ? 1.0 : 0.0),
                duration: c.reducedMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 350),
                child: Padding(
                  padding: headPad,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Try the Look.',
                        style: runwayTextStyle(
                          fontSize: widget.isMobile
                              ? RunwayMetrics.mobileTitleSize
                              : RunwayMetrics.desktopTitleSize,
                          height: 1.0,
                          letterSpacing: -0.02 *
                              (widget.isMobile
                                  ? RunwayMetrics.mobileTitleSize
                                  : RunwayMetrics.desktopTitleSize),
                        ),
                      ),
                      SizedBox(height: widget.isMobile ? 10 : 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Text(
                          'Six looks, styled head to toe. Tap a pin to see the piece.',
                          style: runwayTextStyle(
                            fontSize: 12,
                            color: RunwayColors.muted,
                            height: 1.55,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: widget.isMobile ? 20 : 0),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      final h = constraints.maxHeight;
                      if (w > 0 && h > 0) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            c.updateViewport(
                              screenWidth: MediaQuery.sizeOf(context).width,
                              stageWidth: w,
                              stageHeight: h,
                              reducedMotion:
                                  MediaQuery.disableAnimationsOf(context),
                            );
                          }
                        });
                      }
                      return _buildStageArea(context, w, h);
                    },
                  ),
                ),
              ),
              if (!widget.isMobile) _buildControlsBar(context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStageArea(BuildContext context, double w, double h) {
    final c = widget.controller;
    if (w <= 0 || h <= 0) return const SizedBox.shrink();

    final metrics = computeStageMetrics(
      mode: c.mode,
      isMobile: widget.isMobile,
      width: w,
      height: h,
    );
    final figureH = metrics.modelH;
    final figureW = figureH * 0.5625;

    final items = <_PositionedActor>[];
    for (final b in c.bodies) {
      final double x;
      final double bottom;
      final double scale;
      final double opacity;
      final double blur;
      final int z;

      if (c.mode == RunwayMode.ring) {
        final pose = computeRingPose(
          bodyIndex: b.index,
          cur: c.cur,
          width: w,
          height: h,
          isMobile: widget.isMobile,
          fs: metrics.fs,
          still: c.still,
          enableBlur: c.enableBlur,
        );
        x = pose.x;
        bottom = pose.bottom;
        scale = pose.scale;
        opacity = pose.opacity;
        blur = pose.blur;
        z = pose.z;
      } else {
        final goal = wrapMod(b.index - c.target, bodyCount);
        final pose = computeClassicPose(
          xPlace: b.x,
          goal: goal,
          fromPlace: b.from,
          onTrip: b.onTrip,
          width: w,
          isMobile: widget.isMobile,
          still: c.still,
          enableBlur: c.enableBlur,
        );
        x = pose.x;
        bottom = pose.bottom;
        scale = pose.scale;
        opacity = pose.opacity;
        blur = pose.blur;
        z = pose.z;
      }

      final halfW = (figureW * scale) / 2.0;
      final culledOp = (x + halfW < -4 || x - halfW > w + 4) ? 0.0 : opacity;
      if (culledOp < 0.01) continue;

      final look = RunwayCatalog.looks[b.lookIndex];
      final footFrac = c.footFraction(b.lookIndex);
      items.add(
        _PositionedActor(
          bodyIndex: b.index,
          look: look,
          x: x,
          bottom: bottom,
          scale: scale,
          opacity: culledOp,
          blur: blur,
          z: z,
          footFrac: footFrac,
        ),
      );
    }
    items.sort((a, b) => a.z.compareTo(b.z));

    final heroLook = c.activeLook;

    return MouseRegion(
      cursor: !widget.isMobile && _cursorLocal != null
          ? SystemMouseCursors.none
          : MouseCursor.defer,
      onHover: (ev) {
        if (!widget.isMobile) {
          setState(() => _cursorLocal = ev.localPosition);
        }
      },
      onExit: (_) => setState(() {
        _cursorLocal = null;
        _cursorOverView = false;
        _cursorOverHit = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => c.startDrag(),
        onHorizontalDragUpdate: (d) => c.updateDrag(d.delta.dx),
        onHorizontalDragEnd: (d) => c.endDrag(d.velocity.pixelsPerSecond.dx),
        onHorizontalDragCancel: () => c.endDrag(0),
        child: ClipRect(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Queue bodies sorted by depth z-index
              for (final actor in items)
                Positioned(
                  left: actor.x - figureW / 2.0,
                  bottom: actor.bottom,
                  width: figureW,
                  height: figureH,
                  child: Opacity(
                    opacity: c.zoomed ? 0.0 : actor.opacity,
                    child: Transform.scale(
                      scale: actor.scale,
                      alignment: Alignment.bottomCenter,
                      child: _ModelFigure(
                        imageUrl: actor.look.image640,
                        blur: actor.blur,
                        footFrac: actor.footFrac,
                        interactive: actor.opacity >= 0.5 && !c.zoomed,
                        onHoverChanged: (hover) =>
                            setState(() => _cursorOverHit = hover),
                        onTap: () {
                          final k = c.mode == RunwayMode.ring
                              ? ringSlotRank(actor.bodyIndex, c.target)
                              : wrapModInt(
                                  actor.bodyIndex - c.target.round(),
                                  bodyCount,
                                );
                          if (k == 0) {
                            c.openPopup();
                          } else if (k.abs() < 6) {
                            c.moveTo(c.target.round() + k.toDouble());
                          }
                        },
                      ),
                    ),
                  ),
                ),

              // Active crisp hero when still
              if (c.still && !c.zoomed)
                Positioned(
                  left: metrics.hx - figureW / 2.0,
                  bottom: metrics.hy,
                  width: figureW,
                  height: figureH,
                  child: Transform.scale(
                    scale: metrics.fs,
                    alignment: Alignment.bottomCenter,
                    child: _ModelFigure(
                      imageUrl: heroLook.image640,
                      blur: 0.0,
                      footFrac: c.footFraction(heroLook.index),
                      interactive: true,
                      onHoverChanged: (hover) =>
                          setState(() => _cursorOverView = hover),
                      onTap: c.openPopup,
                    ),
                  ),
                ),

              // Light sweep overlay
              if (!c.reducedMotion)
                IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _sweepCtrl,
                    builder: (context, _) {
                      final t = RunwayCurves.easeSilk.transform(_sweepCtrl.value);
                      if (_sweepCtrl.value == 0 || _sweepCtrl.value == 1) {
                        return const SizedBox.shrink();
                      }
                      final sweepOp = t < 0.18
                          ? t / 0.18
                          : math.max(0.0, 1.0 - (t - 0.18) / 0.82);
                      return FractionalTranslation(
                        translation: Offset(-1.3 + t * 4.6, 0),
                        child: Opacity(
                          opacity: sweepOp * 0.45,
                          child: Container(
                            width: w * 0.42,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0x00FFFFFF),
                                  Color(0x40FFFFFF),
                                  Color(0x8CFFFFFF),
                                  Color(0x40FFFFFF),
                                  Color(0x00FFFFFF),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

              // Mobile walk progress line
              if (widget.isMobile)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 8,
                  child: Center(
                    child: SizedBox(
                      width: math.min(140.0, w * 0.38),
                      height: 2,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: RunwayColors.text.withValues(alpha: 0.14),
                        ),
                        child: AnimatedFractionallySizedBox(
                          duration: c.reducedMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 1100),
                          curve: RunwayCurves.ease,
                          alignment: Alignment.centerLeft,
                          widthFactor: (c.index + 1) / lookCount,
                          child: const ColoredBox(color: RunwayColors.accent),
                        ),
                      ),
                    ),
                  ),
                ),

              // Desktop frosted Drag / View custom cursor
              if (!widget.isMobile && _cursorLocal != null)
                _CustomStageCursor(
                  position: _cursorLocal!,
                  isDragging: c.dragging,
                  isView: !c.dragging && _cursorOverView,
                  isLink: !c.dragging && !_cursorOverView && _cursorOverHit,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlsBar(BuildContext context) {
    final c = widget.controller;
    return Padding(
      padding: const EdgeInsets.fromLTRB(44, 6, 44, 30),
      child: Row(
        children: [
          _ControlIconButton(
            label: 'Previous look',
            onTap: c.prev,
            child: CustomPaint(
              size: const Size(26, 14),
              painter: _ArrowPainter(forward: false),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Row(
              children: [
                for (var i = 0; i < lookCount; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  _TickControl(
                    look: RunwayCatalog.looks[i],
                    active: i == c.index,
                    past: i < c.index,
                    playing: c.playing,
                    autoBarAnim: _autoBarCtrl,
                    onTap: () => c.go(i),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 20),
          _ControlIconButton(
            label: 'Autoplay',
            onTap: c.toggleAutoplay,
            child: Icon(
              c.playing ? Icons.pause : Icons.play_arrow,
              size: 16,
              color: RunwayColors.text,
            ),
          ),
          const SizedBox(width: 20),
          _ControlIconButton(
            label: 'Next look',
            onTap: c.next,
            child: CustomPaint(
              size: const Size(26, 14),
              painter: _ArrowPainter(forward: true),
            ),
          ),
        ],
      ),
    );
  }
}

class _PositionedActor {
  const _PositionedActor({
    required this.bodyIndex,
    required this.look,
    required this.x,
    required this.bottom,
    required this.scale,
    required this.opacity,
    required this.blur,
    required this.z,
    required this.footFrac,
  });

  final int bodyIndex;
  final LookSpec look;
  final double x;
  final double bottom;
  final double scale;
  final double opacity;
  final double blur;
  final int z;
  final double footFrac;
}

class _ModelFigure extends StatelessWidget {
  const _ModelFigure({
    required this.imageUrl,
    required this.blur,
    required this.footFrac,
    required this.interactive,
    required this.onHoverChanged,
    required this.onTap,
  });

  final String imageUrl;
  final double blur;
  final double footFrac;
  final bool interactive;
  final ValueChanged<bool> onHoverChanged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget figure = LayoutBuilder(
      builder: (context, constraints) {
        final shadowH = (constraints.maxHeight * 0.09).clamp(14.0, 46.0);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: constraints.maxWidth * 0.58 - (constraints.maxWidth * 1.5) / 2,
              bottom: -shadowH / 2,
              width: constraints.maxWidth * 1.5,
              height: shadowH,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: const [
                        Color(0x4D14100C),
                        Color(0x2414100C),
                        Color(0x0A14100C),
                        Color(0x0014100C),
                      ],
                      stops: const [0.0, 0.45, 0.75, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: FractionalTranslation(
                translation: Offset(0, footFrac),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  alignment: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (blur > 0.05) {
      figure = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: figure,
      );
    }

    if (!interactive) {
      return IgnorePointer(child: figure);
    }

    return MouseRegion(
      onEnter: (_) => onHoverChanged(true),
      onExit: (_) => onHoverChanged(false),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onTap,
        child: figure,
      ),
    );
  }
}

class _CustomStageCursor extends StatelessWidget {
  const _CustomStageCursor({
    required this.position,
    required this.isDragging,
    required this.isView,
    required this.isLink,
  });

  final Offset position;
  final bool isDragging;
  final bool isView;
  final bool isLink;

  @override
  Widget build(BuildContext context) {
    final double targetScale = isDragging
        ? 0.74
        : isLink
            ? 0.2
            : 1.0;
    final Color bg = isDragging || isLink
        ? RunwayColors.accent
        : Colors.white.withValues(alpha: 0.4);
    final Color fg =
        isDragging ? RunwayColors.onAccent : RunwayColors.text;
    final Color borderColor = isDragging
        ? RunwayColors.accent
        : isLink
            ? Colors.transparent
            : RunwayColors.text.withValues(alpha: 0.28);

    return Positioned(
      left: position.dx - 42,
      top: position.dy - 42,
      child: IgnorePointer(
        child: AnimatedScale(
          scale: targetScale,
          duration: const Duration(milliseconds: 280),
          curve: RunwayCurves.ease,
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: bg,
                  border: Border.all(color: borderColor),
                ),
                alignment: Alignment.center,
                child: isLink
                    ? const SizedBox.shrink()
                    : Text(
                        isView ? 'VIEW' : 'DRAG',
                        style: runwayTextStyle(
                          fontSize: 10,
                          color: fg,
                          letterSpacing: isDragging ? 4.2 : 2.4,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TickControl extends StatelessWidget {
  const _TickControl({
    required this.look,
    required this.active,
    required this.past,
    required this.playing,
    required this.autoBarAnim,
    required this.onTap,
  });

  final LookSpec look;
  final bool active;
  final bool past;
  final bool playing;
  final Animation<double> autoBarAnim;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final numStr = (look.index + 1).toString().padLeft(2, '0');
    return Semantics(
      label: look.accessibilityLabel,
      button: true,
      selected: active,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 650),
          curve: RunwayCurves.ease,
          width: active ? 190 : 44,
          height: 44,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 2,
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: RunwayColors.text.withValues(alpha: 0.14),
                  ),
                  child: AnimatedBuilder(
                    animation: autoBarAnim,
                    builder: (context, _) {
                      final double fill = active
                          ? (playing ? autoBarAnim.value : 1.0)
                          : (past ? 1.0 : 0.0);
                      return FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: fill.clamp(0.0, 1.0),
                        child: ColoredBox(
                          color: active
                              ? RunwayColors.accent
                              : RunwayColors.text.withValues(
                                  alpha: past ? 0.35 : 0.0,
                                ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 9),
              Text(
                active ? '$numStr  ${look.name}' : numStr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: runwayTextStyle(
                  fontSize: 10,
                  letterSpacing: 1.2,
                  color: active ? RunwayColors.text : RunwayColors.muted,
                  tabular: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlIconButton extends StatelessWidget {
  const _ControlIconButton({
    required this.label,
    required this.onTap,
    required this.child,
  });

  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: SizedBox(width: 44, height: 44, child: Center(child: child)),
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter({required this.forward});

  final bool forward;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = RunwayColors.text
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final sx = size.width / 26.0;
    final sy = size.height / 14.0;
    canvas.save();
    canvas.scale(sx, sy);

    final path = Path();
    if (forward) {
      path
        ..moveTo(1, 7)
        ..lineTo(25, 7)
        ..moveTo(19, 1)
        ..lineTo(25, 7)
        ..lineTo(19, 13);
    } else {
      path
        ..moveTo(25, 7)
        ..lineTo(1, 7)
        ..moveTo(7, 1)
        ..lineTo(1, 7)
        ..lineTo(7, 13);
    }
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter oldDelegate) =>
      oldDelegate.forward != forward;
}
