import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Type scale. A serif display face for titles and the wordmark; a geometric
/// sans with tabular figures for everything else so amounts align.
class AppText {
  AppText._();

  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  static TextStyle get brand => GoogleFonts.cormorantGaramond(
        fontSize: 32, fontWeight: FontWeight.w600, color: AppColors.ink, height: 1.1, letterSpacing: 0.2);

  static TextStyle get title => GoogleFonts.cormorantGaramond(
        fontSize: 28, fontWeight: FontWeight.w600, color: AppColors.ink, height: 1.15);

  static TextStyle get headline => GoogleFonts.cormorantGaramond(
        fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.ink, height: 1.2);

  static TextStyle get amountXL => GoogleFonts.manrope(
        fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.ink, height: 1.1,
        letterSpacing: -0.6, fontFeatures: _tabular);

  static TextStyle get amountL => GoogleFonts.manrope(
        fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.ink, height: 1.15,
        letterSpacing: -0.3, fontFeatures: _tabular);

  static TextStyle get amountM => GoogleFonts.manrope(
        fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink, height: 1.25, fontFeatures: _tabular);

  static TextStyle get heading => GoogleFonts.manrope(
        fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink, height: 1.3);

  static TextStyle get body => GoogleFonts.manrope(
        fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.ink, height: 1.45);

  static TextStyle get bodySecondary => body.copyWith(color: AppColors.inkSecondary);

  static TextStyle get small => GoogleFonts.manrope(
        fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.inkSecondary, height: 1.4);

  static TextStyle get smallStrong => small.copyWith(fontWeight: FontWeight.w700, color: AppColors.ink);

  static TextStyle get caption => GoogleFonts.manrope(
        fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.inkTertiary, height: 1.35);

  static TextStyle get overline => GoogleFonts.manrope(
        fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.inkTertiary, height: 1.3, letterSpacing: 0.9);

  static TextStyle tabular(TextStyle style) => style.copyWith(fontFeatures: _tabular);

  /// Fonts used on the first frames; the splash waits for them (bounded) so
  /// text does not re-flow after it appears.
  static List<TextStyle> get preload => [brand, body, heading, small, amountXL];
}

class AppTheme {
  AppTheme._();

  static const SystemUiOverlayStyle overlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  );

  static ThemeData get light {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.ink,
      onPrimary: AppColors.inkInverse,
      secondary: AppColors.goldDeep,
      onSecondary: AppColors.surface,
      tertiary: AppColors.gold,
      onTertiary: AppColors.ink,
      error: AppColors.negative,
      onError: AppColors.surface,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.inkSecondary,
      surfaceContainerLowest: AppColors.surface,
      surfaceContainerLow: AppColors.canvas,
      surfaceContainer: AppColors.surfaceSunken,
      surfaceContainerHigh: AppColors.surfaceSunken,
      surfaceContainerHighest: AppColors.surfaceSunken,
      outline: AppColors.lineStrong,
      outlineVariant: AppColors.line,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme, scaffoldBackgroundColor: AppColors.canvas);
    final textTheme = GoogleFonts.manropeTextTheme(base.textTheme).apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    );

    final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md));
    final buttonText = GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.1);

    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: color, width: width),
        );

    return base.copyWith(
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: overlay,
        titleTextStyle: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: AppColors.inkInverse,
          disabledBackgroundColor: AppColors.lineStrong,
          disabledForegroundColor: AppColors.surface,
          minimumSize: const Size.fromHeight(52),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: AppColors.lineStrong),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.goldDeep,
          textStyle: buttonText.copyWith(fontSize: 14),
          shape: buttonShape,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: 16),
        hintStyle: GoogleFonts.manrope(fontSize: 15, color: AppColors.inkTertiary, fontWeight: FontWeight.w500),
        labelStyle: GoogleFonts.manrope(fontSize: 15, color: AppColors.inkSecondary, fontWeight: FontWeight.w500),
        floatingLabelStyle: GoogleFonts.manrope(fontSize: 14, color: AppColors.goldDeep, fontWeight: FontWeight.w600),
        errorStyle: GoogleFonts.manrope(fontSize: 12.5, color: AppColors.negative, fontWeight: FontWeight.w600),
        prefixIconColor: AppColors.inkTertiary,
        suffixIconColor: AppColors.inkSecondary,
        border: border(AppColors.line),
        enabledBorder: border(AppColors.line),
        focusedBorder: border(AppColors.goldDeep, 1.5),
        errorBorder: border(AppColors.negative),
        focusedErrorBorder: border(AppColors.negative, 1.5),
        disabledBorder: border(AppColors.line),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.panel,
        contentTextStyle: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.inkInverse),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.goldWash,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) => GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w600,
              color: states.contains(WidgetState.selected) ? AppColors.ink : AppColors.inkTertiary,
            )),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              size: 22,
              color: states.contains(WidgetState.selected) ? AppColors.goldDeep : AppColors.inkTertiary,
            )),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg)),
        titleTextStyle: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink),
        contentTextStyle: GoogleFonts.manrope(fontSize: 15, color: AppColors.inkSecondary, height: 1.45),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.goldDeep),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.ink,
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.pill)),
        labelStyle: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink),
        secondaryLabelStyle: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.inkInverse),
        showCheckmark: false,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
      }),
    );
  }
}
