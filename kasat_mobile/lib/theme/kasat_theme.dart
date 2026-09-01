import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Kasat operational palette. Deliberately narrow: a deep canvas, one raised
/// surface, one accent. Anything that needs to stand out earns it through
/// contrast and type weight, not through colour.
abstract final class KC {
  static const canvas = Color(0xFF09090B);
  static const surface = Color(0xFF18181B);
  static const surfaceHi = Color(0xFF1F1F23);
  static const border = Color(0xFF27272A);
  static const borderHi = Color(0xFF3F3F46);

  static const accent = Color(0xFF10B981);
  static const accentDeep = Color(0xFF065F46);

  static const text = Color(0xFFFAFAFA);
  static const muted = Color(0xFFA1A1AA);
  static const faint = Color(0xFF52525B);

  static const danger = Color(0xFFEF4444);
  static const warn = Color(0xFFF59E0B);
  static const info = Color(0xFF60A5FA);
}

/// Vertical rhythm. Kasat is a high-density surface: 4px base, and we rarely
/// go above 16 between related elements.
abstract final class KSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
}

abstract final class KType {
  static const _mono = 'Menlo';
  static const _monoFallback = <String>['Menlo', 'Courier New', 'monospace'];

  /// Metadata, identifiers, counters, status codes.
  static TextStyle mono({
    double size = 11,
    FontWeight weight = FontWeight.w500,
    Color color = KC.text,
    double tracking = 0.4,
    double? height,
  }) {
    return TextStyle(
      fontFamily: _mono,
      fontFamilyFallback: _monoFallback,
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: tracking,
      height: height,
    );
  }

  /// Section headers and field labels: uppercase, wide tracking, small.
  static TextStyle label({Color color = KC.muted, double size = 10}) {
    return mono(size: size, weight: FontWeight.w700, color: color, tracking: 1.4);
  }

  /// Prose the survivor actually reads or writes.
  static TextStyle sans({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = KC.text,
    double? height,
    double tracking = 0,
  }) {
    return TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: tracking,
    );
  }
}

abstract final class KasatTheme {
  static const overlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: KC.canvas,
    systemNavigationBarIconBrightness: Brightness.light,
  );

  static ThemeData build() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: KC.canvas,
      canvasColor: KC.canvas,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      colorScheme: const ColorScheme.dark(
        surface: KC.canvas,
        primary: KC.accent,
        onPrimary: KC.canvas,
        secondary: KC.accent,
        error: KC.danger,
        outline: KC.border,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: KC.accent,
        selectionColor: Color(0x3310B981),
        selectionHandleColor: KC.accent,
      ),
      dividerColor: KC.border,
      iconTheme: const IconThemeData(color: KC.muted, size: 18),
    );
  }
}
