import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Kasat Desk tokens. Light and dark share one file.
/// Widgets read [KC] after [KC.bind] so a theme change repaints them.
enum KasatThemeMode {
  system,
  light,
  dark;

  String get id => name;

  String get label => switch (this) {
        KasatThemeMode.system => 'Match phone',
        KasatThemeMode.light => 'Light',
        KasatThemeMode.dark => 'Dark',
      };

  String get blurb => switch (this) {
        KasatThemeMode.system => 'Follows the phone’s light or dark setting.',
        KasatThemeMode.light => 'White background.',
        KasatThemeMode.dark => 'Dark background.',
      };

  static KasatThemeMode fromId(String? id) => switch (id) {
        'light' => KasatThemeMode.light,
        'dark' => KasatThemeMode.dark,
        _ => KasatThemeMode.system,
      };
}

abstract final class KC {
  static Brightness _brightness = Brightness.light;

  static void bind(Brightness brightness) => _brightness = brightness;

  static bool get _dark => _brightness == Brightness.dark;

  static const onPrimary = Color(0xFF1D2125);

  static Color get canvas =>
      _dark ? const Color(0xFF1D2125) : const Color(0xFFFFFFFF);

  static Color get surface =>
      _dark ? const Color(0xFF22272B) : const Color(0xFFF7F8F9);

  static Color get surfaceAlt => surface;

  static Color get border =>
      _dark ? const Color(0xFF384047) : const Color(0xFFDCDFE4);

  static Color get borderStrong => border;

  static Color get text =>
      _dark ? const Color(0xFFDEE4EA) : const Color(0xFF172B4D);

  static Color get muted =>
      _dark ? const Color(0xFF9FADBC) : const Color(0xFF626F86);

  static Color get faint => muted;

  static const primary = Color(0xFF579DFF);

  /// Flat tint of the primary fill. No pink wash.
  static Color get primarySoft => Color.alphaBlend(
        primary.withValues(alpha: _dark ? 0.18 : 0.14),
        surface,
      );

  static Color get secondary => text;

  static Color get secondarySoft => surface;

  static Color get urgent =>
      _dark ? const Color(0xFFF87168) : const Color(0xFFC9372C);

  static Color get urgentSoft => Color.alphaBlend(
        urgent.withValues(alpha: _dark ? 0.18 : 0.12),
        surface,
      );

  static Color get calm =>
      _dark ? const Color(0xFF4BCE97) : const Color(0xFF216E4E);

  static Color get calmSoft => Color.alphaBlend(
        calm.withValues(alpha: _dark ? 0.18 : 0.12),
        surface,
      );
}

abstract final class KRadius {
  static const sm = 6.0;
  static const md = 8.0;
  static const lg = 8.0;
  static const xl = 8.0;
  static const pill = 8.0;

  static const rSm = BorderRadius.all(Radius.circular(sm));
  static const rMd = BorderRadius.all(Radius.circular(md));
  static const rLg = BorderRadius.all(Radius.circular(lg));
  static const rXl = BorderRadius.all(Radius.circular(xl));
  static const rPill = BorderRadius.all(Radius.circular(pill));
}

/// 8px spacing scale.
abstract final class KSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class KType {
  static const _sans = 'Inter';
  static const _sansFallback = <String>['NotoSansEthiopic', 'sans-serif'];
  static const _code = 'Menlo';
  static const _codeFallback = <String>['Menlo', 'Courier New', 'monospace'];

  static TextStyle serif({
    double size = 22,
    FontWeight weight = FontWeight.w600,
    Color? color,
    double? height,
    double tracking = -0.2,
  }) {
    return TextStyle(
      fontFamily: _sans,
      fontFamilyFallback: _sansFallback,
      fontSize: size,
      fontWeight: weight,
      color: color ?? KC.text,
      height: height,
      letterSpacing: tracking,
    );
  }

  static TextStyle sans({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height,
    double tracking = 0,
  }) {
    return TextStyle(
      fontFamily: _sans,
      fontFamilyFallback: _sansFallback,
      fontSize: size,
      fontWeight: weight,
      color: color ?? KC.text,
      height: height,
      letterSpacing: tracking,
    );
  }

  static TextStyle label({Color? color, double size = 12}) {
    return sans(
      size: size,
      weight: FontWeight.w600,
      color: color ?? KC.muted,
      tracking: 0.1,
    );
  }

  static TextStyle code({
    double size = 14,
    FontWeight weight = FontWeight.w600,
    Color? color,
    double tracking = 1.5,
  }) {
    return TextStyle(
      fontFamily: _code,
      fontFamilyFallback: _codeFallback,
      fontSize: size,
      fontWeight: weight,
      color: color ?? KC.text,
      letterSpacing: tracking,
    );
  }
}

/// No decorative shadows.
abstract final class KShadow {
  static const card = <BoxShadow>[];
  static const lift = <BoxShadow>[];
}

abstract final class KasatTheme {
  static SystemUiOverlayStyle overlayFor(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor:
          dark ? const Color(0xFF1D2125) : const Color(0xFFFFFFFF),
      systemNavigationBarIconBrightness:
          dark ? Brightness.light : Brightness.dark,
    );
  }

  static const overlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.light,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Color(0xFFFFFFFF),
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  static ThemeData build() => light();

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final canvas = dark ? const Color(0xFF1D2125) : const Color(0xFFFFFFFF);
    final surface = dark ? const Color(0xFF22272B) : const Color(0xFFF7F8F9);
    final border = dark ? const Color(0xFF384047) : const Color(0xFFDCDFE4);
    final text = dark ? const Color(0xFFDEE4EA) : const Color(0xFF172B4D);
    final muted = dark ? const Color(0xFF9FADBC) : const Color(0xFF626F86);
    const primary = Color(0xFF579DFF);
    final danger = dark ? const Color(0xFFF87168) : const Color(0xFFC9372C);

    final scheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: KC.onPrimary,
      secondary: primary,
      onSecondary: KC.onPrimary,
      error: danger,
      onError: canvas,
      surface: canvas,
      onSurface: text,
      surfaceContainerHighest: surface,
      outline: border,
      outlineVariant: border,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      canvasColor: canvas,
      dividerColor: border,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      fontFamily: KType._sans,
      fontFamilyFallback: KType._sansFallback,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        fontFamily: KType._sans,
        fontFamilyFallback: KType._sansFallback,
        bodyColor: text,
        displayColor: text,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: canvas,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: KType._sans,
          fontFamilyFallback: KType._sansFallback,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: text,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KRadius.md),
          side: BorderSide(color: border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: KC.onPrimary,
          elevation: 0,
          minimumSize: const Size(64, 40),
          shape: RoundedRectangleBorder(borderRadius: KRadius.rMd),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          elevation: 0,
          side: BorderSide(color: border),
          minimumSize: const Size(64, 40),
          shape: RoundedRectangleBorder(borderRadius: KRadius.rMd),
        ),
      ),
      iconTheme: IconThemeData(color: muted, size: 24),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: primary,
        selectionColor: primary.withValues(alpha: 0.28),
        selectionHandleColor: primary,
      ),
    );
  }
}
