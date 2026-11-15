import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/catalog.dart';
import '../state/runway_controller.dart';
import '../theme/runway_tokens.dart';

class LookLightboxOverlay extends StatelessWidget {
  const LookLightboxOverlay({
    super.key,
    required this.controller,
    required this.isMobile,
    required this.onPinTap,
  });

  final RunwayController controller;
  final bool isMobile;
  final ValueChanged<int> onPinTap;

  @override
  Widget build(BuildContext context) {
    final look = controller.activeLook;
    final footFrac = controller.footFraction(look.index);
    final kicker = 'LOOK ${(look.index + 1).toString().padLeft(2, '0')}';

    return Positioned.fill(
      bottom: isMobile ? 20 : 0,
      child: Material(
        color: RunwayColors.stage,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: controller.closePopup,
          child: Stack(
            children: [
              // Model stage area
              Positioned.fill(
                top: isMobile ? 72 : 88,
                left: isMobile ? 16 : 48,
                right: isMobile ? 16 : 48,
                bottom: isMobile ? 40 : 48,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final h = math.max(
                      160.0,
                      math.min(constraints.maxHeight, constraints.maxWidth / 0.5625),
                    );
                    final w = h * 0.5625;
                    return Align(
                      alignment: Alignment.bottomCenter,
                      child: GestureDetector(
                        onTap: () {}, // keep open when tapping directly on model
                        child: SizedBox(
                          width: w,
                          height: h,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.72, end: 1.0),
                            duration: controller.reducedMotion
                                ? Duration.zero
                                : const Duration(milliseconds: 650),
                            curve: RunwayCurves.ease,
                            builder: (context, scale, child) {
                              return Transform.scale(
                                scale: scale,
                                alignment: Alignment.bottomCenter,
                                child: child,
                              );
                            },
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned.fill(
                                  child: FractionalTranslation(
                                    translation: Offset(0, footFrac),
                                    child: Image.network(
                                      look.image1080,
                                      fit: BoxFit.contain,
                                      alignment: Alignment.bottomCenter,
                                    ),
                                  ),
                                ),
                                for (final pin in look.pins)
                                  _PinHotspot(
                                    pin: pin,
                                    figureWidth: w,
                                    figureHeight: h,
                                    isHot: controller.hotCardNumber == pin.number,
                                    isMobile: isMobile,
                                    reducedMotion: controller.reducedMotion,
                                    onTap: () => onPinTap(pin.number),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Top bar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: isMobile
                      ? const EdgeInsets.fromLTRB(20, 16, 12, 0)
                      : const EdgeInsets.fromLTRB(56, 32, 32, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              kicker,
                              style: runwayTextStyle(
                                fontSize: 10,
                                letterSpacing: 2.0,
                                color: RunwayColors.muted,
                                tabular: true,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              look.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: runwayTextStyle(
                                fontSize: isMobile ? 18 : 17,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Semantics(
                        label: 'Close',
                        button: true,
                        child: InkWell(
                          onTap: controller.closePopup,
                          customBorder: const CircleBorder(),
                          child: ClipOval(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                              child: Container(
                                width: isMobile ? 44 : 48,
                                height: isMobile ? 44 : 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.55),
                                  border: Border.all(
                                    color:
                                        RunwayColors.text.withValues(alpha: 0.22),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: RunwayColors.text,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom hint
              Positioned(
                left: 0,
                right: 0,
                bottom: isMobile ? 12 : 16,
                child: IgnorePointer(
                  child: Center(
                    child: Text(
                      'TAP A DOT TO SHOP THE PIECE',
                      style: runwayTextStyle(
                        fontSize: 10,
                        letterSpacing: 2.0,
                        color: RunwayColors.muted,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinHotspot extends StatefulWidget {
  const _PinHotspot({
    required this.pin,
    required this.figureWidth,
    required this.figureHeight,
    required this.isHot,
    required this.isMobile,
    required this.reducedMotion,
    required this.onTap,
  });

  final PinSpec pin;
  final double figureWidth;
  final double figureHeight;
  final bool isHot;
  final bool isMobile;
  final bool reducedMotion;
  final VoidCallback onTap;

  @override
  State<_PinHotspot> createState() => _PinHotspotState();
}

class _PinHotspotState extends State<_PinHotspot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rippleCtrl;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _rippleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    if (!widget.reducedMotion) {
      _rippleCtrl.repeat();
    }
  }

  @override
  void dispose() {
    _rippleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cx = widget.figureWidth * widget.pin.leftFrac;
    final cy = widget.figureHeight * widget.pin.topFrac;
    final showHot = widget.isHot || _hovered;

    return Positioned(
      left: cx - 22,
      top: cy - 22,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerLeft,
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: Semantics(
              label: '${widget.pin.number}: ${widget.pin.title}',
              button: true,
              child: GestureDetector(
                onTap: widget.onTap,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (!widget.reducedMotion)
                          AnimatedBuilder(
                            animation: _rippleCtrl,
                            builder: (context, _) {
                              final t = _rippleCtrl.value;
                              return Container(
                                width: 24 + t * 18,
                                height: 24 + t * 18,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white
                                        .withValues(alpha: (1 - t) * 0.8),
                                  ),
                                ),
                              );
                            },
                          ),
                        AnimatedScale(
                          scale: showHot ? 1.3 : 1.0,
                          duration: const Duration(milliseconds: 350),
                          curve: RunwayCurves.easeSpring,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: showHot
                                  ? RunwayColors.accent
                                  : Colors.white.withValues(alpha: 0.86),
                              boxShadow: showHot
                                  ? [
                                      BoxShadow(
                                        color: RunwayColors.accent
                                            .withValues(alpha: 0.22),
                                        spreadRadius: 6,
                                      ),
                                    ]
                                  : const [
                                      BoxShadow(
                                        color: Color(0x59000000),
                                        blurRadius: 14,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${widget.pin.number}',
                              style: runwayTextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: showHot
                                    ? RunwayColors.onAccent
                                    : RunwayColors.text,
                                tabular: true,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (showHot)
            Positioned(
              left: 38,
              child: IgnorePointer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: widget.isMobile ? 150 : 200,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x66000000),
                            blurRadius: 26,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Text(
                        widget.pin.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: runwayTextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.44,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
