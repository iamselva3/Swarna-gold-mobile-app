import 'package:flutter/material.dart';

/// Colour tokens. Ivory surfaces, charcoal type and a restrained metallic gold
/// used for emphasis only — never as a large fill.
class AppColors {
  AppColors._();

  // Surfaces
  static const Color canvas = Color(0xFFFAF7F0);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSunken = Color(0xFFF3EEE3);
  static const Color line = Color(0xFFE7E0D2);
  static const Color lineStrong = Color(0xFFD5CBB7);

  // Ink
  static const Color ink = Color(0xFF1C1B19);
  static const Color inkSecondary = Color(0xFF55514A);
  static const Color inkTertiary = Color(0xFF857F73);
  static const Color inkInverse = Color(0xFFFAF7F0);

  // Gold
  static const Color gold = Color(0xFFB08A3E);
  static const Color goldDeep = Color(0xFF7A5C1E);
  static const Color goldWash = Color(0xFFF4EAD3);

  // Charcoal panel used for the holdings summary
  static const Color panel = Color(0xFF22211E);
  static const Color panelLine = Color(0xFF3A3833);
  static const Color panelMuted = Color(0xFFB9B2A3);

  // Status
  static const Color positive = Color(0xFF2E6B4E);
  static const Color positiveWash = Color(0xFFE2EFE7);
  static const Color negative = Color(0xFFA33A2E);
  static const Color negativeWash = Color(0xFFF7E4E0);
  static const Color caution = Color(0xFF8A5A10);
  static const Color cautionWash = Color(0xFFF6ECD6);
  static const Color neutralWash = Color(0xFFEDE9E1);
}

/// Spacing scale (4pt grid) and radii.
class Space {
  Space._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;

  /// Horizontal page gutter.
  static const double gutter = 20;
}

class Radii {
  Radii._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double pill = 999;
}
