import 'package:flutter/material.dart';

class RunwayColors {
  RunwayColors._();

  static const Color stage = Color(0xFFFFFFFF);
  static const Color panel = Color(0xFFFFFFFF);
  static const Color text = Color(0xFF151413);
  static const Color muted = Color(0xFF66625C);
  static const Color accent = Color(0xFF0E0E0E);
  static const Color onAccent = Color(0xFFFFFFFF);
  static const Color line = Color(0xFFC8C8C8);
  static const Color headerBorder = Color(0xFFE4E4E4);
  static const Color cardBg = Color(0xFFDFDFDF);
}

class RunwayCurves {
  RunwayCurves._();

  static const Curve ease = Cubic(0.16, 1.0, 0.3, 1.0);
  static const Curve easeSilk = Cubic(0.65, 0.0, 0.35, 1.0);
  static const Curve easeSpring = Cubic(0.34, 1.56, 0.64, 1.0);
  static const Curve easeSheet = Cubic(0.32, 0.72, 0.0, 1.0);
}

class RunwayMetrics {
  RunwayMetrics._();

  static const double desktopHeaderHeight = 88.0;
  static const double mobileHeaderHeight = 68.0;
  static const double desktopPanelWidth = 380.0;
  static const double desktopPanelPad = 32.0;
  static const double mobilePanelPad = 20.0;
  static const double mobilePanelRadius = 20.0;
  static const double desktopThumbWidth = 92.0;
  static const double mobileThumbWidth = 62.0;
  static const double pillRadius = 30.0;
  static const double mobileFrameVh = 1.09;

  static const double desktopTitleSize = 46.0;
  static const double mobileTitleSize = 24.0;
}

TextStyle runwayTextStyle({
  required double fontSize,
  FontWeight fontWeight = FontWeight.w400,
  Color color = RunwayColors.text,
  double? letterSpacing,
  double? height,
  bool tabular = false,
  TextDecoration? decoration,
  String fontFamily = 'Helvetica',
}) {
  return TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: const ['Arial', 'sans-serif'],
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
    decoration: decoration,
    fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
  );
}
