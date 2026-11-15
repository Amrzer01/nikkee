import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'math/runway_math.dart';
import 'models/catalog.dart';
import 'state/runway_controller.dart';
import 'state/styling_bag.dart';
import 'theme/runway_tokens.dart';
import 'widgets/bag_dialog.dart';
import 'widgets/look_lightbox.dart';
import 'widgets/look_panel.dart';
import 'widgets/runway_stage.dart';
import 'widgets/site_header.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RunwayApp());
}

class RunwayApp extends StatelessWidget {
  const RunwayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Try the Look — Runway',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: RunwayColors.stage,
        colorScheme: const ColorScheme.light(
          surface: RunwayColors.stage,
          primary: RunwayColors.accent,
          onPrimary: RunwayColors.onAccent,
          onSurface: RunwayColors.text,
        ),
      ),
      home: const RunwayScreen(),
    );
  }
}

class RunwayScreen extends StatefulWidget {
  const RunwayScreen({super.key});

  @override
  State<RunwayScreen> createState() => _RunwayScreenState();
}

class _RunwayScreenState extends State<RunwayScreen>
    with TickerProviderStateMixin {
  late final StylingBag _bag;
  late final RunwayController _controller;
  final GlobalKey<LookPanelState> _panelKey = GlobalKey<LookPanelState>();
  final FocusNode _focusNode = FocusNode();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _bag = StylingBag()..load();
    _controller = RunwayController(bag: _bag, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _controller.init(reducedMotion: MediaQuery.disableAnimationsOf(context));
      _probeFeetAllLooks();
    }
  }

  Future<void> _probeFeetAllLooks() async {
    for (final look in RunwayCatalog.looks) {
      _probeLookFeet(look);
    }
  }

  void _probeLookFeet(LookSpec look) {
    final provider = NetworkImage(look.image640);
    final stream = provider.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool _) async {
        stream.removeListener(listener);
        try {
          final rgba = await info.image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          if (rgba != null && mounted) {
            final frac = computeFootFractionFromRgba(
              rgba.buffer.asUint8List(),
              info.image.width,
              info.image.height,
              40,
            );
            _controller.setFootFraction(look.index, frac);
          }
        } catch (_) {
          // Keep default foot offset 0 on CORS or decode errors
        } finally {
          info.dispose();
        }
      },
      onError: (Object _, StackTrace? __) {
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
  }

  @override
  void dispose() {
    _controller.dispose();
    _bag.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape && _controller.zoomed) {
      _controller.closePopup();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _controller.next();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _controller.prev();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RunwayColors.stage,
      body: Focus(
        focusNode: _focusNode,
        autofocus: !kIsWeb,
        onKeyEvent: _handleKeyEvent,
        child: AnimatedBuilder(
          animation: Listenable.merge([_controller, _bag]),
          builder: (context, _) {
            final size = MediaQuery.sizeOf(context);
            final isMobile = size.width <= 749.0;
            final headerH = isMobile
                ? RunwayMetrics.mobileHeaderHeight
                : RunwayMetrics.desktopHeaderHeight;
            final frameH = computeFrameHeight(
              isMobile: isMobile,
              viewportHeight: size.height,
              headerHeight: headerH,
              mheightVh: 109.0,
            );

            return Stack(
              children: [
                if (isMobile)
                  SingleChildScrollView(
                    child: Column(
                      children: [
                        SiteHeader(
                          isMobile: true,
                          bagCount: _bag.totalCount,
                          onHomeTap: () => _controller.go(0),
                          onOpenBag: () => showStylingBagDialog(context, _bag),
                        ),
                        SizedBox(
                          height: frameH,
                          child: Column(
                            children: [
                              Expanded(
                                child: Stack(
                                  children: [
                                    RunwayStageColumn(
                                      controller: _controller,
                                      isMobile: true,
                                      onRevealCard: (n) =>
                                          _panelKey.currentState?.revealCard(n),
                                    ),
                                    if (_controller.zoomed)
                                      LookLightboxOverlay(
                                        controller: _controller,
                                        isMobile: true,
                                        onPinTap: (n) {
                                          _controller.engage();
                                          _controller.setHotCard(n);
                                          _panelKey.currentState?.revealCard(n);
                                        },
                                      ),
                                  ],
                                ),
                              ),
                              LookPanel(
                                key: _panelKey,
                                controller: _controller,
                                isMobile: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    children: [
                      SiteHeader(
                        isMobile: false,
                        bagCount: _bag.totalCount,
                        onHomeTap: () => _controller.go(0),
                        onOpenBag: () => showStylingBagDialog(context, _bag),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: Stack(
                                children: [
                                  RunwayStageColumn(
                                    controller: _controller,
                                    isMobile: false,
                                    onRevealCard: (n) =>
                                        _panelKey.currentState?.revealCard(n),
                                  ),
                                  if (_controller.zoomed)
                                    LookLightboxOverlay(
                                      controller: _controller,
                                      isMobile: false,
                                      onPinTap: (n) {
                                        _controller.engage();
                                        _controller.setHotCard(n);
                                        _panelKey.currentState?.revealCard(n);
                                      },
                                    ),
                                ],
                              ),
                            ),
                            LookPanel(
                              key: _panelKey,
                              controller: _controller,
                              isMobile: false,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                // Toast status banner (#bag-status)
                if (_bag.toastMessage != null)
                  Positioned(
                    bottom: 24,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: Center(
                        child: Container(
                          color: RunwayColors.text,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          child: Text(
                            _bag.toastMessage!,
                            style: runwayTextStyle(
                              fontSize: 12,
                              color: RunwayColors.onAccent,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
