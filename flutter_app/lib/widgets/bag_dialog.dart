import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../state/styling_bag.dart';
import '../theme/runway_tokens.dart';

Future<void> showStylingBagDialog(BuildContext context, StylingBag bag) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close styling bag',
    barrierColor: const Color(0x55000000),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, _, __) {
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Center(
          child: StylingBagDialog(bag: bag),
        ),
      );
    },
  );
}

class StylingBagDialog extends StatelessWidget {
  const StylingBagDialog({super.key, required this.bag});

  final StylingBag bag;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final dialogWidth = (screenWidth - 32).clamp(280.0, 560.0);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        decoration: BoxDecoration(
          color: RunwayColors.panel,
          border: Border.all(color: const Color(0xFFD9D9D9)),
        ),
        padding: const EdgeInsets.all(24),
        child: AnimatedBuilder(
          animation: bag,
          builder: (context, _) {
            final entries = bag.entries;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Your styling bag',
                        style: runwayTextStyle(fontSize: 25),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Semantics(
                      label: 'Close styling bag',
                      button: true,
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Center(
                            child: Text('×', style: runwayTextStyle(fontSize: 28, height: 1)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'A local outfit shortlist. No payment or order is collected here. Open a piece on the original demo to continue.',
                    style: runwayTextStyle(
                      fontSize: 12,
                      color: const Color(0xFF666666),
                      height: 1.5,
                    ),
                  ),
                ),
                if (entries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Your styling bag is empty. Choose a size beside a piece to save it.',
                      style: runwayTextStyle(
                        fontSize: 12,
                        color: const Color(0xFF666666),
                        height: 1.5,
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: entries.length,
                      itemBuilder: (context, idx) {
                        final entry = entries[idx];
                        final match = bag.matchForVariant(entry.id);
                        if (match == null) return const SizedBox.shrink();
                        final sizeText = match.variant.options.join(' / ');
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: Color(0xFFDDDDDD))),
                          ),
                          child: Row(
                            children: [
                              Image.network(
                                match.item.image,
                                width: 60,
                                height: 80,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      match.item.name,
                                      style: runwayTextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Size $sizeText · Quantity ${entry.quantity} · ${StylingBag.formatMoney(match.item.price)}',
                                      style: runwayTextStyle(fontSize: 12, tabular: true),
                                    ),
                                    const SizedBox(height: 6),
                                    InkWell(
                                      onTap: () => _openPiece(match.item.url),
                                      child: Text(
                                        'View original piece ↗',
                                        style: runwayTextStyle(
                                          fontSize: 12,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Semantics(
                                label: 'Remove ${match.item.name}',
                                button: true,
                                child: InkWell(
                                  onTap: () => bag.remove(entry.id),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Text(
                                      '×',
                                      style: runwayTextStyle(fontSize: 20, height: 1),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                if (entries.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Reference subtotal ${StylingBag.formatMoney(bag.subtotal)}',
                      textAlign: TextAlign.right,
                      style: runwayTextStyle(fontSize: 15, tabular: true),
                    ),
                  ),
                Opacity(
                  opacity: entries.isEmpty ? 0.4 : 1.0,
                  child: ElevatedButton(
                    onPressed: entries.isEmpty
                        ? null
                        : () async {
                            final shortlist = bag.buildShortlistText();
                            await Clipboard.setData(ClipboardData(text: shortlist));
                            bag.showToast('Outfit shortlist copied to clipboard');
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: RunwayColors.text,
                      foregroundColor: RunwayColors.onAccent,
                      disabledBackgroundColor: RunwayColors.text,
                      disabledForegroundColor: RunwayColors.onAccent,
                      shape: const RoundedRectangleBorder(),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    ),
                    child: Text(
                      'Download outfit shortlist',
                      style: runwayTextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: RunwayColors.onAccent,
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

  Future<void> _openPiece(String url) async {
    final uri = StylingBag.validateProductUri(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
