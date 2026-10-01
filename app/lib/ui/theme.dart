import 'package:flutter/material.dart';

import 'tokens.g.dart';

const fontThai = 'IBMPlexSansThai';
const fontJapanese = 'ZenMaruGothic';

/// The active palette, reachable from any widget via `context.lc`.
/// Screens use only these tokens, never literal colours, so a theme is
/// changed by editing design/tokens.json alone.
class LcColors extends ThemeExtension<LcColors> {
  final LcPalette p;
  final bool reduceMotion;
  const LcColors(this.p, {this.reduceMotion = false});

  @override
  LcColors copyWith({LcPalette? p, bool? reduceMotion}) =>
      LcColors(p ?? this.p, reduceMotion: reduceMotion ?? this.reduceMotion);

  /// Blends every colour, so switching theme fades instead of jumping.
  @override
  LcColors lerp(LcColors? other, double t) {
    if (other == null || identical(other.p, p)) return other ?? this;
    final a = p, b = other.p;
    Color c(Color x, Color y) => Color.lerp(x, y, t)!;
    return LcColors(
      LcPalette(
        id: t < 0.5 ? a.id : b.id,
        name: t < 0.5 ? a.name : b.name,
        dark: t < 0.5 ? a.dark : b.dark,
        bg: c(a.bg, b.bg),
        surface: c(a.surface, b.surface),
        ink: c(a.ink, b.ink),
        muted: c(a.muted, b.muted),
        line: c(a.line, b.line),
        track: c(a.track, b.track),
        accent: c(a.accent, b.accent),
        onAccent: c(a.onAccent, b.onAccent),
        accentSoft: c(a.accentSoft, b.accentSoft),
        coin: c(a.coin, b.coin),
        coinSoft: c(a.coinSoft, b.coinSoft),
        good: c(a.good, b.good),
        goodSoft: c(a.goodSoft, b.goodSoft),
        warn: c(a.warn, b.warn),
        warnSoft: c(a.warnSoft, b.warnSoft),
      ),
      reduceMotion: t < 0.5 ? reduceMotion : other.reduceMotion,
    );
  }
}

extension LcContext on BuildContext {
  LcPalette get lc => Theme.of(this).extension<LcColors>()!.p;
  bool get reduceMotion =>
      Theme.of(this).extension<LcColors>()!.reduceMotion ||
      MediaQuery.of(this).disableAnimations;
  Duration get motionFast => reduceMotion
      ? Duration.zero
      : const Duration(milliseconds: LcTokens.motionFastMs);
  Duration get motionNormal => reduceMotion
      ? Duration.zero
      : const Duration(milliseconds: LcTokens.motionNormalMs);
}

FontWeight _w(int w) => FontWeight.values[(w ~/ 100 - 1).clamp(0, 8)];

/// Japanese text style at a token size.
TextStyle jpStyle(double size, int weight, Color color) => TextStyle(
  fontFamily: fontJapanese,
  fontSize: size,
  fontWeight: _w(weight),
  color: color,
  height: 1.3,
);

ThemeData buildTheme(LcPalette p, {bool reduceMotion = false}) {
  final scheme = ColorScheme(
    brightness: p.dark ? Brightness.dark : Brightness.light,
    primary: p.accent,
    onPrimary: p.onAccent,
    primaryContainer: p.accentSoft,
    onPrimaryContainer: p.ink,
    secondary: p.coin,
    onSecondary: p.surface,
    error: p.warn,
    onError: p.surface,
    surface: p.surface,
    onSurface: p.ink,
    onSurfaceVariant: p.muted,
    outline: p.line,
    outlineVariant: p.line,
    surfaceContainerHighest: p.track,
  );
  TextStyle t(double size, int weight, [Color? c]) => TextStyle(
    fontFamily: fontThai,
    fontFamilyFallback: const [fontJapanese],
    fontSize: size,
    fontWeight: _w(weight),
    color: c ?? p.ink,
    height: 1.4,
  );
  final text = TextTheme(
    headlineMedium: t(LcTokens.displaySize, LcTokens.displayWeight),
    titleLarge: t(LcTokens.titleSize, LcTokens.titleWeight),
    titleMedium: t(LcTokens.bodySize + 1, 600),
    bodyLarge: t(LcTokens.bodySize, LcTokens.bodyWeight),
    bodyMedium: t(LcTokens.bodySize - 1, LcTokens.bodyWeight),
    labelLarge: t(LcTokens.labelSize, LcTokens.labelWeight),
    labelMedium: t(LcTokens.captionSize, 500, p.muted),
    bodySmall: t(LcTokens.captionSize, LcTokens.captionWeight, p.muted),
  );
  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(LcTokens.radiusButton),
  );
  const minSize = Size(LcTokens.touchTargetMin, LcTokens.touchTargetMin + 8);
  // A thick ring on the focused control, so a controller or keyboard user
  // always sees where they are.
  WidgetStateProperty<BorderSide?> ring(Color color, BorderSide? rest) =>
      WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.focused)
            ? BorderSide(color: color, width: 3)
            : rest,
      );
  return ThemeData(
    useMaterial3: true,
    focusColor: p.accent.withValues(alpha: 0.16),
    // Material 3 already uses the sparkle ripple on Android; with animations
    // off there is no ripple at all.
    splashFactory: reduceMotion ? NoSplash.splashFactory : null,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    fontFamily: fontThai,
    fontFamilyFallback: const [fontJapanese],
    textTheme: text,
    extensions: [LcColors(p, reduceMotion: reduceMotion)],
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      foregroundColor: p.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: t(LcTokens.titleSize, LcTokens.titleWeight),
    ),
    dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
        disabledBackgroundColor: p.track,
        disabledForegroundColor: p.muted,
        minimumSize: minSize,
        shape: buttonShape,
        textStyle: t(LcTokens.bodySize, 600),
      ).copyWith(side: ring(p.ink, null)),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.ink,
        minimumSize: minSize,
        shape: buttonShape,
        textStyle: t(LcTokens.bodySize, 500),
      ).copyWith(side: ring(p.accent, BorderSide(color: p.line, width: 1.5))),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.accent,
        minimumSize: const Size(
          LcTokens.touchTargetMin,
          LcTokens.touchTargetMin,
        ),
        textStyle: t(LcTokens.labelSize + 1, 600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LcTokens.radiusControl),
        borderSide: BorderSide(color: p.line, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LcTokens.radiusControl),
        borderSide: BorderSide(color: p.line, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LcTokens.radiusControl),
        borderSide: BorderSide(color: p.accent, width: 2),
      ),
      hintStyle: t(LcTokens.bodySize, 400, p.muted),
      labelStyle: t(LcTokens.bodySize, 400, p.muted),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surface,
      indicatorColor: p.accentSoft,
      surfaceTintColor: Colors.transparent,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => t(
          LcTokens.captionSize,
          s.contains(WidgetState.selected) ? 700 : 500,
          s.contains(WidgetState.selected) ? p.ink : p.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? p.accent : p.muted,
        ),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.onAccent : p.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.accent : p.track,
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: p.accent,
      inactiveTrackColor: p.track,
      thumbColor: p.accent,
      overlayColor: p.accentSoft,
      valueIndicatorColor: p.ink,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: p.muted,
      titleTextStyle: t(LcTokens.bodySize, 500),
      subtitleTextStyle: t(LcTokens.captionSize + 1, 400, p.muted),
      minVerticalPadding: 12,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LcTokens.radiusCard),
      ),
      titleTextStyle: t(LcTokens.titleSize, LcTokens.titleWeight),
      contentTextStyle: t(LcTokens.bodySize, 400),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(LcTokens.radiusCardLarge),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.ink,
      contentTextStyle: t(LcTokens.bodySize - 1, 500, p.bg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LcTokens.radiusControl),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.accentSoft : p.surface,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.accent : p.muted,
        ),
        side: WidgetStateProperty.all(BorderSide(color: p.line, width: 1.5)),
        textStyle: WidgetStateProperty.all(t(LcTokens.labelSize + 1, 600)),
        minimumSize: WidgetStateProperty.all(
          const Size(LcTokens.touchTargetMin, LcTokens.touchTargetMin),
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.surface,
      selectedColor: p.accentSoft,
      checkmarkColor: p.accent,
      side: BorderSide(color: p.line, width: 1.5),
      labelStyle: t(LcTokens.labelSize + 1, 500),
      secondaryLabelStyle: t(LcTokens.labelSize + 1, 600, p.accent),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LcTokens.radiusControl),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: p.accent,
      linearTrackColor: p.track,
    ),
    pageTransitionsTheme: reduceMotion
        ? const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
            },
          )
        : null,
  );
}
