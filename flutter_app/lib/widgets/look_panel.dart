import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/catalog.dart';
import '../state/runway_controller.dart';
import '../state/styling_bag.dart';
import '../theme/runway_tokens.dart';

class LookPanel extends StatefulWidget {
  const LookPanel({
    super.key,
    required this.controller,
    required this.isMobile,
  });

  final RunwayController controller;
  final bool isMobile;

  @override
  State<LookPanel> createState() => LookPanelState();
}

class LookPanelState extends State<LookPanel> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void revealCard(int cardNumber) {
    if (!_scrollController.hasClients) return;
    if (widget.isMobile) {
      final cardW = (MediaQuery.sizeOf(context).width - 64.0) + 16.0;
      _scrollController.animateTo(
        ((cardNumber - 1) * cardW).clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: widget.controller.reducedMotion
            ? Duration.zero
            : const Duration(milliseconds: 350),
        curve: RunwayCurves.ease,
      );
    } else {
      final offset = ((cardNumber - 1) * 140.0)
          .clamp(0.0, _scrollController.position.maxScrollExtent);
      _scrollController.animateTo(
        offset,
        duration: widget.controller.reducedMotion
            ? Duration.zero
            : const Duration(milliseconds: 350),
        curve: RunwayCurves.ease,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final look = c.activeLook;
    final countText = '${look.productIds.length} pieces';

    if (widget.isMobile) {
      return _buildMobilePanel(context, look, countText);
    }

    return MouseRegion(
      onEnter: (_) => c.setPanelHover(true),
      onExit: (_) => c.setPanelHover(false),
      child: Container(
        width: RunwayMetrics.desktopPanelWidth,
        decoration: const BoxDecoration(
          color: RunwayColors.panel,
          border: Border(left: BorderSide(color: RunwayColors.line)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 44, 32, 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('In this look', style: runwayTextStyle(fontSize: 18)),
                  Text(
                    countText.toUpperCase(),
                    style: runwayTextStyle(
                      fontSize: 10,
                      letterSpacing: 1.6,
                      color: RunwayColors.muted,
                      tabular: true,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(32, 6, 32, 20),
                itemCount: look.productIds.length,
                itemBuilder: (context, idx) {
                  final cardNum = idx + 1;
                  final item = RunwayCatalog.requireItem(look.productIds[idx]);
                  final pin = look.pins[idx];
                  return _DesktopProductRow(
                    controller: c,
                    lookIndex: look.index,
                    cardNum: cardNum,
                    isLast: idx == look.productIds.length - 1,
                    item: item,
                    isNew: pin.isNew,
                  );
                },
              ),
            ),
            _BundleFooter(controller: c, isMobile: false, lookIndex: look.index),
          ],
        ),
      ),
    );
  }

  Widget _buildMobilePanel(
    BuildContext context,
    LookSpec look,
    String countText,
  ) {
    final c = widget.controller;
    return Container(
      decoration: BoxDecoration(
        color: RunwayColors.panel,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(RunwayMetrics.mobilePanelRadius),
        ),
        boxShadow: [
          BoxShadow(
            color: RunwayColors.text.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    look.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: runwayTextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  countText.toUpperCase(),
                  style: runwayTextStyle(
                    fontSize: 9,
                    letterSpacing: 1.44,
                    color: RunwayColors.muted,
                    tabular: true,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 100,
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                itemCount: look.productIds.length,
                itemBuilder: (context, idx) {
                  final cardNum = idx + 1;
                  final item = RunwayCatalog.requireItem(look.productIds[idx]);
                  final pin = look.pins[idx];
                  final cardW = MediaQuery.sizeOf(context).width - 64.0;
                  final isLast = idx == look.productIds.length - 1;
                  return Container(
                    width: cardW,
                    margin: EdgeInsets.only(right: isLast ? 0 : 16),
                    padding: const EdgeInsets.only(right: 16, top: 2, bottom: 2),
                    decoration: BoxDecoration(
                      border: isLast
                          ? null
                          : const Border(
                              right: BorderSide(color: RunwayColors.line),
                            ),
                    ),
                    child: _ProductCardContent(
                      controller: c,
                      lookIndex: look.index,
                      cardNum: cardNum,
                      item: item,
                      isNew: pin.isNew,
                      isMobile: true,
                      onOpenPicker: () => _openMobileSheet(
                        context,
                        c,
                        look.index,
                        cardNum,
                        item,
                      ),
                    ),
                  );
                },
              ),
            ),
            _BundleFooter(controller: c, isMobile: true, lookIndex: look.index),
          ],
        ),
      );
  }

  Future<void> _openMobileSheet(
    BuildContext context,
    RunwayController c,
    int lookIndex,
    int cardNum,
    CatalogItem item,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: RunwayColors.panel,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return AnimatedBuilder(
          animation: c,
          builder: (context, _) {
            final selected = c.selectedSize(lookIndex, cardNum, item);
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 34,
                        height: 4,
                        decoration: BoxDecoration(
                          color: RunwayColors.text.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.only(bottom: 16),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: RunwayColors.line),
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 52,
                            child: AspectRatio(
                              aspectRatio: 4 / 5,
                              child: Image.network(item.image, fit: BoxFit.cover),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: runwayTextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  StylingBag.formatMoney(item.price),
                                  style: runwayTextStyle(
                                    fontSize: 12,
                                    color: RunwayColors.muted,
                                    tabular: true,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            icon: const Icon(Icons.close, size: 18),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _SizePills(
                      optionLabel: item.optionLabel,
                      sizes: item.sizes,
                      selected: selected,
                      onSelect: (s) => c.selectSize(lookIndex, cardNum, s),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () {
                          final ok = c.confirmCard(lookIndex, cardNum, item);
                          if (ok && ctx.mounted) Navigator.of(ctx).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: RunwayColors.text,
                          foregroundColor: RunwayColors.onAccent,
                          shape: const RoundedRectangleBorder(),
                          elevation: 0,
                        ),
                        child: Text(
                          'Add to bag',
                          style: runwayTextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: RunwayColors.onAccent,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _DesktopProductRow extends StatelessWidget {
  const _DesktopProductRow({
    required this.controller,
    required this.lookIndex,
    required this.cardNum,
    required this.isLast,
    required this.item,
    required this.isNew,
  });

  final RunwayController controller;
  final int lookIndex;
  final int cardNum;
  final bool isLast;
  final CatalogItem item;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final isHot = controller.hotCardNumber == cardNum;
    final isOpen = controller.isPickerOpen(lookIndex, cardNum);
    final selected = controller.selectedSize(lookIndex, cardNum, item);

    return MouseRegion(
      onEnter: (_) => controller.setHotCard(cardNum),
      onExit: (_) => controller.setHotCard(null),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: const BorderSide(color: RunwayColors.line),
            bottom: BorderSide(
              color: isHot
                  ? RunwayColors.accent
                  : (isLast ? RunwayColors.line : Colors.transparent),
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ProductCardContent(
              controller: controller,
              lookIndex: lookIndex,
              cardNum: cardNum,
              item: item,
              isNew: isNew,
              isMobile: false,
              onOpenPicker: () => controller.toggleInlinePicker(lookIndex, cardNum),
            ),
            if (isOpen && !controller.isAdded(lookIndex, cardNum)) ...[
              const SizedBox(height: 16),
              _SizePills(
                optionLabel: item.optionLabel,
                sizes: item.sizes,
                selected: selected,
                onSelect: (s) => controller.selectSize(lookIndex, cardNum, s),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: () => controller.confirmCard(lookIndex, cardNum, item),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RunwayColors.text,
                    foregroundColor: RunwayColors.onAccent,
                    shape: const RoundedRectangleBorder(),
                    elevation: 0,
                  ),
                  child: Text(
                    'Add to bag',
                    style: runwayTextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: RunwayColors.onAccent,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProductCardContent extends StatelessWidget {
  const _ProductCardContent({
    required this.controller,
    required this.lookIndex,
    required this.cardNum,
    required this.item,
    required this.isNew,
    required this.isMobile,
    required this.onOpenPicker,
  });

  final RunwayController controller;
  final int lookIndex;
  final int cardNum;
  final CatalogItem item;
  final bool isNew;
  final bool isMobile;
  final VoidCallback onOpenPicker;

  @override
  Widget build(BuildContext context) {
    final isHot = controller.hotCardNumber == cardNum;
    final isAdded = controller.isAdded(lookIndex, cardNum);
    final isPicking = controller.isPickerOpen(lookIndex, cardNum);
    final thumbW =
        isMobile ? RunwayMetrics.mobileThumbWidth : RunwayMetrics.desktopThumbWidth;

    return Row(
      crossAxisAlignment:
          isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.end,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: () => _openUrl(item.url),
              child: Container(
                width: thumbW,
                color: RunwayColors.text.withValues(alpha: 0.05),
                child: AspectRatio(
                  aspectRatio: 4 / 5,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.network(item.image, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isHot
                                ? RunwayColors.accent
                                : Colors.white.withValues(alpha: 0.9),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$cardNum',
                            style: runwayTextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isHot
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
            if (isNew)
              Positioned(
                top: isMobile ? -1 : -7,
                left: isMobile ? 6 : 8,
                child: IgnorePointer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 1,
                        height: 11,
                        margin: const EdgeInsets.only(left: 10),
                        color: RunwayColors.text.withValues(alpha: 0.5),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: RunwayColors.text,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          'NEW',
                          style: runwayTextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.26,
                            color: RunwayColors.panel,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        SizedBox(width: isMobile ? 14 : 18),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.vendorLine.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: runwayTextStyle(
                    fontSize: 10,
                    letterSpacing: 1.4,
                    color: RunwayColors.muted,
                  ),
                ),
                const SizedBox(height: 5),
                GestureDetector(
                  onTap: () => _openUrl(item.url),
                  child: Text(
                    item.name,
                    style: runwayTextStyle(
                      fontSize: isMobile ? 12 : 13,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  StylingBag.formatMoney(item.price),
                  style: runwayTextStyle(fontSize: 12, tabular: true),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Semantics(
          label: isAdded ? 'Added to bag: ${item.name}' : 'Add to bag: ${item.name}',
          button: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: isAdded ? null : onOpenPicker,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: isAdded
                    ? const Icon(Icons.check, size: 20, color: RunwayColors.accent)
                    : AnimatedRotation(
                        turns: isPicking ? 0.125 : 0.0,
                        duration: const Duration(milliseconds: 250),
                        child: const Icon(Icons.add, size: 20, color: RunwayColors.text),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = StylingBag.validateProductUri(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _SizePills extends StatelessWidget {
  const _SizePills({
    required this.optionLabel,
    required this.sizes,
    required this.selected,
    required this.onSelect,
  });

  final String optionLabel;
  final List<String> sizes;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          optionLabel,
          style: runwayTextStyle(fontSize: 11),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final size in sizes)
              InkWell(
                borderRadius: BorderRadius.circular(RunwayMetrics.pillRadius),
                onTap: () => onSelect(size),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 40),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: selected == size ? RunwayColors.text : Colors.transparent,
                    borderRadius: BorderRadius.circular(RunwayMetrics.pillRadius),
                    border: Border.all(
                      color: selected == size ? RunwayColors.text : RunwayColors.line,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    size,
                    style: runwayTextStyle(
                      fontSize: 11,
                      color: selected == size ? RunwayColors.panel : RunwayColors.text,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _BundleFooter extends StatelessWidget {
  const _BundleFooter({
    required this.controller,
    required this.isMobile,
    required this.lookIndex,
  });

  final RunwayController controller;
  final bool isMobile;
  final int lookIndex;

  @override
  Widget build(BuildContext context) {
    final msg = controller.bundleMessage(lookIndex);
    final isComplete = controller.isLookComplete(lookIndex);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final pad = isMobile
        ? EdgeInsets.fromLTRB(20, 8, 20, math.max(12.0, bottomInset + 8.0))
        : const EdgeInsets.fromLTRB(32, 20, 32, 30);

    return Container(
      padding: pad,
      decoration: BoxDecoration(
        color: RunwayColors.panel,
        border: isMobile
            ? null
            : const Border(top: BorderSide(color: RunwayColors.line)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (msg.isNotEmpty) ...[
            Text(
              msg,
              style: runwayTextStyle(
                fontSize: 11,
                height: 1.45,
                color: RunwayColors.accent,
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (!isMobile) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Complete the look',
                        style: runwayTextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Bundle all 3 and save 10%',
                        style: runwayTextStyle(
                          fontSize: 11,
                          color: RunwayColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      StylingBag.formatMoney(RunwayCatalog.bundleOriginalPrice),
                      style: runwayTextStyle(
                        fontSize: 11,
                        color: RunwayColors.muted,
                        decoration: TextDecoration.lineThrough,
                        tabular: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      StylingBag.formatMoney(RunwayCatalog.bundleSalePrice),
                      style: runwayTextStyle(fontSize: 16, tabular: true),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          SizedBox(
            height: isMobile ? 54 : 56,
            child: ElevatedButton(
              onPressed: isComplete
                  ? null
                  : () {
                      final pending = controller.addFullLook(lookIndex);
                      if (isMobile && pending.isNotEmpty) {
                        final look = RunwayCatalog.looks[lookIndex];
                        final item =
                            RunwayCatalog.requireItem(look.productIds[pending.first - 1]);
                        final state =
                            context.findAncestorStateOfType<LookPanelState>();
                        state?._openMobileSheet(
                          context,
                          controller,
                          lookIndex,
                          pending.first,
                          item,
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isComplete ? RunwayColors.accent : RunwayColors.text,
                foregroundColor: RunwayColors.onAccent,
                disabledBackgroundColor: RunwayColors.accent,
                disabledForegroundColor: RunwayColors.onAccent,
                shape: const RoundedRectangleBorder(),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isComplete
                        ? 'Full look in your bag'
                        : (isMobile
                            ? 'Add full look — ${StylingBag.formatMoney(RunwayCatalog.bundleSalePrice)}'
                            : 'Add full look to bag'),
                    style: runwayTextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: RunwayColors.onAccent,
                    ),
                  ),
                  if (!isComplete && !isMobile) ...[
                    const SizedBox(width: 12),
                    const Icon(Icons.arrow_forward, size: 16, color: RunwayColors.onAccent),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
