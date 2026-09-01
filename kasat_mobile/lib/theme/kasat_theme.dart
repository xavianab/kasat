import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Kasat palette.
///
/// Warm, low-contrast, and deliberately unremarkable. Someone glancing over a
/// survivor's shoulder should see a soft personal app, not a reporting tool —
/// the discretion features elsewhere in the app only work if the surface they
/// sit on is also unremarkable.
abstract final class KC {
  /// Warm cream canvas.
  static const canvas = Color(0xFFFFFAF8);

  /// Cards sit slightly lighter than the canvas.
  static const surface = Color(0xFFFFFFFF);

  /// Panel headers and inset wells.
  static const surfaceAlt = Color(0xFFFDF3EF);

  static const border = Color(0xFFF0E2DC);
  static const borderStrong = Color(0xFFE3CFC7);

  /// Blush pink — primary actions and the app's own voice.
  static const primary = Color(0xFFE07A9A);
  static const primarySoft = Color(0xFFFDEFF3);

  /// Terracotta — secondary emphasis, in-progress states, warm warnings.
  static const secondary = Color(0xFFC96A3A);
  static const secondarySoft = Color(0xFFFBEFE7);

  /// Soft brown, never black.
  static const text = Color(0xFF3D2A2A);
  static const muted = Color(0xFF8A7472);
  static const faint = Color(0xFFB7A3A0);

  /// Muted sage for completed states. Warm-leaning so it sits with the rest.
  static const calm = Color(0xFF7F9B72);
  static const calmSoft = Color(0xFFF1F5EE);

  /// Deep rust stands in for "urgent" — a saturated red would reintroduce the
  /// alarm-panel feel the palette is meant to avoid.
  static const urgent = Color(0xFFC0563F);
  static const urgentSoft = Color(0xFFFBEDE9);
}

/// Nothing in Kasat has a sharp corner.
abstract final class KRadius {
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 28.0;
  static const pill = 999.0;

  static const rSm = BorderRadius.all(Radius.circular(sm));
  static const rMd = BorderRadius.all(Radius.circular(md));
  static const rLg = BorderRadius.all(Radius.circular(lg));
  static const rXl = BorderRadius.all(Radius.circular(xl));
  static const rPill = BorderRadius.all(Radius.circular(pill));
}

abstract final class KSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class KType {
  static const _serif = 'Georgia';
  static const _serifFallback = <String>['Georgia', 'Palatino', 'Times New Roman', 'serif'];

  /// Reserved for tracking codes. Character shapes have to be unambiguous when
  /// a code is copied onto paper, which is the one place a proportional face
  /// actively hurts.
  static const _code = 'Menlo';
  static const _codeFallback = <String>['Menlo', 'Courier New', 'monospace'];

  /// Headings. Serif carries most of the warmth in the interface.
  static TextStyle serif({
    double size = 22,
    FontWeight weight = FontWeight.w600,
    Color color = KC.text,
    double? height,
    double tracking = -0.2,
  }) {
    return TextStyle(
      fontFamily: _serif,
      fontFamilyFallback: _serifFallback,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: tracking,
    );
  }

  /// Body copy, labels, and every piece of metadata that used to be a
  /// monospace badge.
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

  /// Small sentence-case caption above an input or beside a value.
  static TextStyle label({Color color = KC.muted, double size = 12}) {
    return sans(size: size, weight: FontWeight.w600, color: color, tracking: 0.1);
  }

  static TextStyle code({
    double size = 14,
    FontWeight weight = FontWeight.w600,
    Color color = KC.text,
    double tracking = 1.5,
  }) {
    return TextStyle(
      fontFamily: _code,
      fontFamilyFallback: _codeFallback,
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: tracking,
    );
  }
}

/// Soft shadow used sparingly, on raised cards only.
abstract final class KShadow {
  static const card = <BoxShadow>[
    BoxShadow(color: Color(0x0D3D2A2A), blurRadius: 16, offset: Offset(0, 4)),
  ];
  static const lift = <BoxShadow>[
    BoxShadow(color: Color(0x143D2A2A), blurRadius: 28, offset: Offset(0, 8)),
  ];
}

abstract final class KasatTheme {
  static const overlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.light,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: KC.canvas,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  static ThemeData build() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: KC.canvas,
      canvasColor: KC.canvas,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      colorScheme: const ColorScheme.light(
        surface: KC.canvas,
        primary: KC.primary,
        onPrimary: Colors.white,
        secondary: KC.secondary,
        error: KC.urgent,
        outline: KC.border,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: KC.primary,
        selectionColor: Color(0x33E07A9A),
        selectionHandleColor: KC.primary,
      ),
      dividerColor: KC.border,
      iconTheme: const IconThemeData(color: KC.muted, size: 20),
    );
  }
}
