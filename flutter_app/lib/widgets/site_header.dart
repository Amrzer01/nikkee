import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/catalog.dart';
import '../theme/runway_tokens.dart';

class SiteHeader extends StatelessWidget {
  const SiteHeader({
    super.key,
    required this.isMobile,
    required this.bagCount,
    required this.onHomeTap,
    required this.onOpenBag,
  });

  final bool isMobile;
  final int bagCount;
  final VoidCallback onHomeTap;
  final VoidCallback onOpenBag;

  @override
  Widget build(BuildContext context) {
    final height =
        isMobile ? RunwayMetrics.mobileHeaderHeight : RunwayMetrics.desktopHeaderHeight;
    final hPad = isMobile ? 20.0 : 40.0;
    final gap = isMobile ? 18.0 : 32.0;

    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: hPad),
      decoration: const BoxDecoration(
        color: RunwayColors.stage,
        border: Border(bottom: BorderSide(color: RunwayColors.headerBorder)),
      ),
      child: Row(
        children: [
          Semantics(
            label: 'Runway home',
            button: true,
            child: InkWell(
              onTap: onHomeTap,
              child: SizedBox(
                width: isMobile ? 48 : 68,
                height: isMobile ? 17 : 24,
                child: SvgPicture.network(
                  RunwayCatalog.nikeLogoSvgUrl,
                  fit: BoxFit.contain,
                  semanticsLabel: 'Nike',
                  placeholderBuilder: (_) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _NavLink(label: 'Home', isMobile: isMobile, onTap: onHomeTap),
              if (!isMobile) ...[
                SizedBox(width: 28),
                _NavLink(
                  label: 'Nike Orbit',
                  isMobile: isMobile,
                  onTap: () => _launchExternal('https://nike-makknzjs.myshopify.com/pages/nike-orbit'),
                ),
                const SizedBox(width: 28),
                _NavLink(
                  label: 'Hand Rail Pro',
                  isMobile: isMobile,
                  onTap: () => _launchExternal('https://nike-makknzjs.myshopify.com/pages/scene-rail'),
                ),
              ],
              SizedBox(width: isMobile ? 14 : 28),
              _NavLink(label: 'Runway', isMobile: isMobile, isCurrent: true, onTap: onHomeTap),
            ],
          ),
          SizedBox(width: isMobile ? 8 : gap),
          Semantics(
            label: 'Open styling bag',
            button: true,
            child: InkWell(
              onTap: onOpenBag,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 22,
                      height: 24,
                      child: CustomPaint(painter: _BagIconPainter()),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$bagCount',
                      style: runwayTextStyle(
                        fontSize: 10,
                        tabular: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchExternal(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _NavLink extends StatefulWidget {
  const _NavLink({
    required this.label,
    required this.isMobile,
    required this.onTap,
    this.isCurrent = false,
  });

  final String label;
  final bool isMobile;
  final VoidCallback onTap;
  final bool isCurrent;

  @override
  State<_NavLink> createState() => _NavLinkState();
}

class _NavLinkState extends State<_NavLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: widget.isMobile ? 15 : 12),
          child: Text(
            widget.label,
            style: runwayTextStyle(
              fontFamily: 'Inter',
              fontSize: widget.isMobile ? 11 : 14,
              fontWeight: FontWeight.w600,
              decoration: _hovered ? TextDecoration.underline : TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}

class _BagIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = RunwayColors.text
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    final sx = size.width / 24.0;
    final sy = size.height / 26.0;
    canvas.save();
    canvas.scale(sx, sy);

    final body = Path()
      ..moveTo(4, 8)
      ..lineTo(20, 8)
      ..lineTo(21, 24)
      ..lineTo(3, 24)
      ..close();
    canvas.drawPath(body, paint);

    final handle = Path()
      ..moveTo(8, 8)
      ..lineTo(8, 6)
      ..arcToPoint(const Offset(16, 6), radius: const Radius.circular(4))
      ..lineTo(16, 8);
    canvas.drawPath(handle, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
