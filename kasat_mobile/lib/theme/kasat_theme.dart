import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Appearance modes. Order matches the Settings picker.
enum KasatThemeMode {
  kasat,
  light,
  dark,
  system;

  String get id => name;

  String get label => switch (this) {
        KasatThemeMode.kasat => 'Kasat',
        KasatThemeMode.light => 'Light',
        KasatThemeMode.dark => 'Dark',
        KasatThemeMode.system => 'Match system',
      };

  String get blurb => switch (this) {
        KasatThemeMode.kasat => 'Warm cream from the Kasat website.',
        KasatThemeMode.light => 'White background.',
        KasatThemeMode.dark => 'Dark background.',
        KasatThemeMode.system => 'Follows the phone light or dark setting.',
      };

  /// Missing value defaults to Kasat for new installs. Stored choices are kept.
  static KasatThemeMode fromId(String? id) => switch (id) {
        'light' => KasatThemeMode.light,
        'dark' => KasatThemeMode.dark,
        'system' => KasatThemeMode.system,
        'kasat' => KasatThemeMode.kasat,
        null => KasatThemeMode.kasat,
        _ => KasatThemeMode.kasat,
      };
}

enum KasatPalette {
  kasat,
  light,
  dark;
}

/// Colour tokens. Widgets read [KC] after [KC.bindMode] so a theme change
/// repaints them. Layout, type, and spacing stay the same across palettes.
abstract final class KC {
  static KasatPalette _palette = KasatPalette.kasat;

  static KasatPalette get palette => _palette;

  static bool get isKasat => _palette == KasatPalette.kasat;

  static bool get _dark => _palette == KasatPalette.dark;

  /// Resolves the active palette from Settings + platform brightness.
  static void bindMode(KasatThemeMode mode, Brightness platformBrightness) {
    _palette = switch (mode) {
      KasatThemeMode.kasat => KasatPalette.kasat,
      KasatThemeMode.light => KasatPalette.light,
      KasatThemeMode.dark => KasatPalette.dark,
      KasatThemeMode.system => platformBrightness == Brightness.dark
          ? KasatPalette.dark
          : KasatPalette.light,
    };
  }

  /// Test helper when a raw brightness is enough (Light / Dark only).
  static void bind(Brightness brightness) {
    _palette =
        brightness == Brightness.dark ? KasatPalette.dark : KasatPalette.light;
  }

  static void bindPalette(KasatPalette palette) {
    _palette = palette;
  }

  /// Page background.
  static Color get canvas => switch (_palette) {
        KasatPalette.kasat => const Color(0xFFFFFAF8),
        KasatPalette.light => const Color(0xFFFFFFFF),
        KasatPalette.dark => const Color(0xFF1D2125),
      };

  /// Cards, sheets, inputs, tab bar, app bar.
  static Color get surface => switch (_palette) {
        KasatPalette.kasat => const Color(0xFFFFFFFF),
        KasatPalette.light => const Color(0xFFF7F8F9),
        KasatPalette.dark => const Color(0xFF22272B),
      };

  static Color get surfaceAlt => surface;

  static Color get border => switch (_palette) {
        KasatPalette.kasat => const Color(0xFFEAD6DA),
        KasatPalette.light => const Color(0xFFDCDFE4),
        KasatPalette.dark => const Color(0xFF384047),
      };

  static Color get borderStrong => border;

  static Color get text => switch (_palette) {
        KasatPalette.kasat => const Color(0xFF3D2A2A),
        KasatPalette.light => const Color(0xFF172B4D),
        KasatPalette.dark => const Color(0xFFDEE4EA),
      };

  static Color get muted => switch (_palette) {
        KasatPalette.kasat => const Color(0xFF6B5555),
        KasatPalette.light => const Color(0xFF626F86),
        KasatPalette.dark => const Color(0xFF9FADBC),
      };

  static Color get faint => muted;

  /// Accent: links, selected tab, focus ring, toggles, progress steps.
  static Color get primary => switch (_palette) {
        KasatPalette.kasat => const Color(0xFFC4587C),
        KasatPalette.light || KasatPalette.dark => const Color(0xFF579DFF),
      };

  /// Links on cream need a warmer, darker tone for contrast.
  static Color get link => switch (_palette) {
        KasatPalette.kasat => const Color(0xFFA4532A),
        KasatPalette.light || KasatPalette.dark => primary,
      };

  /// Soft tint for selected pills, chips, and info boxes.
  static Color get primarySoft => switch (_palette) {
        KasatPalette.kasat => const Color(0xFFF6E4E8),
        KasatPalette.light || KasatPalette.dark => Color.alphaBlend(
            primary.withValues(alpha: _dark ? 0.18 : 0.14),
            surface,
          ),
      };

  /// Primary action button fill.
  static Color get button => switch (_palette) {
        KasatPalette.kasat => const Color(0xFF3D2A2A),
        KasatPalette.light || KasatPalette.dark => const Color(0xFF579DFF),
      };

  /// Text/icon on [button].
  static Color get onButton => switch (_palette) {
        KasatPalette.kasat => const Color(0xFFFFFAF8),
        KasatPalette.light || KasatPalette.dark => const Color(0xFF1D2125),
      };

  static Color get buttonPressed => switch (_palette) {
        KasatPalette.kasat => const Color(0xFF2A1C1C),
        KasatPalette.light || KasatPalette.dark => const Color(0xFF3D7FD9),
      };

  /// Kept for ThemeData / older call sites; same as [onButton].
  static Color get onPrimary => onButton;

  static Color get secondary => text;

  static Color get secondarySoft => surface;

  /// Danger stays #C9372C in light and Kasat. Dark keeps the brighter tone.
  static Color get urgent => switch (_palette) {
        KasatPalette.dark => const Color(0xFFF87168),
        KasatPalette.kasat || KasatPalette.light => const Color(0xFFC9372C),
      };

  static Color get urgentSoft => Color.alphaBlend(
        urgent.withValues(alpha: _dark ? 0.18 : 0.12),
        surface,
      );

  static Color get calm => switch (_palette) {
        KasatPalette.dark => const Color(0xFF4BCE97),
        KasatPalette.kasat || KasatPalette.light => const Color(0xFF216E4E),
      };

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
  static SystemUiOverlayStyle overlayForMode(
    KasatThemeMode mode,
    Brightness platformBrightness,
  ) {
    final palette = switch (mode) {
      KasatThemeMode.kasat => KasatPalette.kasat,
      KasatThemeMode.light => KasatPalette.light,
      KasatThemeMode.dark => KasatPalette.dark,
      KasatThemeMode.system => platformBrightness == Brightness.dark
          ? KasatPalette.dark
          : KasatPalette.light,
    };
    return overlayForPalette(palette);
  }

  static SystemUiOverlayStyle overlayFor(Brightness brightness) {
    return overlayForPalette(
      brightness == Brightness.dark ? KasatPalette.dark : KasatPalette.light,
    );
  }

  static SystemUiOverlayStyle overlayForPalette(KasatPalette palette) {
    final dark = palette == KasatPalette.dark;
    final bar = switch (palette) {
      KasatPalette.kasat => const Color(0xFFFFFAF8),
      KasatPalette.light => const Color(0xFFFFFFFF),
      KasatPalette.dark => const Color(0xFF1D2125),
    };
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: bar,
      systemNavigationBarIconBrightness:
          dark ? Brightness.light : Brightness.dark,
    );
  }

  static const overlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.light,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Color(0xFFFFFAF8),
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  static ThemeData build() => kasat();

  static ThemeData light() => _build(KasatPalette.light);

  static ThemeData dark() => _build(KasatPalette.dark);

  static ThemeData kasat() => _build(KasatPalette.kasat);

  static ThemeData _build(KasatPalette palette) {
    final previous = KC.palette;
    KC.bindPalette(palette);
    final canvas = KC.canvas;
    final surface = KC.surface;
    final border = KC.border;
    final text = KC.text;
    final muted = KC.muted;
    final accent = KC.primary;
    final button = KC.button;
    final onButton = KC.onButton;
    final danger = KC.urgent;
    final brightness =
        palette == KasatPalette.dark ? Brightness.dark : Brightness.light;
    KC.bindPalette(previous);

    final scheme = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: onButton,
      secondary: accent,
      onSecondary: onButton,
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
          backgroundColor: button,
          foregroundColor: onButton,
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
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return muted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accent.withValues(alpha: 0.35);
          }
          return border;
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: accent),
      iconTheme: IconThemeData(color: muted, size: 24),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accent,
        selectionColor: accent.withValues(alpha: 0.28),
        selectionHandleColor: accent,
      ),
    );
  }
}
