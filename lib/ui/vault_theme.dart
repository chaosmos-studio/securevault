import 'package:flutter/material.dart';

/// The vault's own look: setup, the vault and its settings.
/// The disguises keep the look of the apps they imitate.
@immutable
class VaultColors extends ThemeExtension<VaultColors> {
  const VaultColors({
    required this.ground,
    required this.surface,
    required this.raised,
    required this.line,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.danger,
  });

  final Color ground;
  final Color surface;
  final Color raised;
  final Color line;
  final Color ink;
  final Color muted;
  final Color accent;
  final Color onAccent;
  final Color accentSoft;
  final Color danger;

  static const light = VaultColors(
    ground: Color(0xFFF3F4F1),
    surface: Color(0xFFFFFFFF),
    raised: Color(0xFFE6E8E4),
    line: Color(0xFFD9DCD7),
    ink: Color(0xFF161A18),
    muted: Color(0xFF59605C),
    accent: Color(0xFF1E5E50),
    onAccent: Color(0xFFFFFFFF),
    accentSoft: Color(0xFFD9E7E1),
    danger: Color(0xFFB3261E),
  );

  static const dark = VaultColors(
    ground: Color(0xFF0F1110),
    surface: Color(0xFF181B1A),
    raised: Color(0xFF242826),
    line: Color(0xFF303533),
    ink: Color(0xFFEEF1EE),
    muted: Color(0xFFA3AAA6),
    accent: Color(0xFF86CBB6),
    onAccent: Color(0xFF0B2A22),
    accentSoft: Color(0xFF1E3A33),
    danger: Color(0xFFF2B8B5),
  );

  @override
  VaultColors copyWith() => this;

  @override
  VaultColors lerp(ThemeExtension<VaultColors>? other, double t) {
    if (other is! VaultColors) return this;
    return VaultColors(
      ground: Color.lerp(ground, other.ground, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      raised: Color.lerp(raised, other.raised, t)!,
      line: Color.lerp(line, other.line, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

extension VaultColorsOf on BuildContext {
  VaultColors get vault => Theme.of(this).extension<VaultColors>()!;
}

const String kVaultFont = 'RedHatText';

/// Type sizes: 13 meta, 15 body, 18 row and button titles, 24 screen titles,
/// 32 for the one large line on a setup step.
abstract final class VaultType {
  static const double meta = 13;
  static const double body = 15;
  static const double row = 17;
  static const double title = 24;
  static const double hero = 30;
}

ThemeData buildVaultTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? VaultColors.dark : VaultColors.light;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.accent,
    onPrimary: c.onAccent,
    primaryContainer: c.accentSoft,
    onPrimaryContainer: c.ink,
    secondary: c.ink,
    onSecondary: c.surface,
    error: c.danger,
    onError: c.surface,
    surface: c.surface,
    onSurface: c.ink,
    onSurfaceVariant: c.muted,
    surfaceContainerLowest: c.ground,
    surfaceContainerLow: c.ground,
    surfaceContainer: c.surface,
    surfaceContainerHigh: c.surface,
    surfaceContainerHighest: c.raised,
    outline: c.line,
    outlineVariant: c.line,
  );

  TextStyle style(double size, FontWeight weight, {double height = 1.35, Color? color}) =>
      TextStyle(
        fontFamily: kVaultFont,
        fontSize: size,
        fontWeight: weight,
        height: height,
        color: color ?? c.ink,
        letterSpacing: size >= 24 ? -0.3 : 0,
      );

  final text = TextTheme(
    displaySmall: style(VaultType.hero, FontWeight.w600, height: 1.15),
    headlineSmall: style(VaultType.title, FontWeight.w600, height: 1.2),
    titleLarge: style(VaultType.title, FontWeight.w600, height: 1.2),
    titleMedium: style(VaultType.row, FontWeight.w500),
    titleSmall: style(VaultType.body, FontWeight.w600),
    bodyLarge: style(VaultType.row, FontWeight.w400, height: 1.5),
    bodyMedium: style(VaultType.body, FontWeight.w400, height: 1.45),
    bodySmall: style(VaultType.meta, FontWeight.w400, color: c.muted),
    labelLarge: style(VaultType.body, FontWeight.w600),
    labelMedium: style(VaultType.meta, FontWeight.w500),
    labelSmall: style(VaultType.meta, FontWeight.w500, color: c.muted),
  );

  final pill = WidgetStatePropertyAll<OutlinedBorder>(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)));

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: kVaultFont,
    textTheme: text,
    scaffoldBackgroundColor: c.ground,
    canvasColor: c.ground,
    splashFactory: InkSparkle.splashFactory,
    extensions: [c],
    appBarTheme: AppBarTheme(
      backgroundColor: c.ground,
      surfaceTintColor: Colors.transparent,
      foregroundColor: c.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 20,
      titleTextStyle: style(20, FontWeight.w600),
    ),
    iconTheme: IconThemeData(color: c.ink, size: 24),
    dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        shape: pill,
        minimumSize: const WidgetStatePropertyAll(Size(64, 56)),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 28)),
        textStyle: WidgetStatePropertyAll(style(VaultType.row, FontWeight.w600)),
        backgroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.disabled) ? c.raised : c.accent),
        foregroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.disabled) ? c.muted : c.onAccent),
        elevation: const WidgetStatePropertyAll(0),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        shape: pill,
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
        textStyle: WidgetStatePropertyAll(style(VaultType.body, FontWeight.w600)),
        foregroundColor: WidgetStatePropertyAll(c.ink),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        shape: pill,
        minimumSize: const WidgetStatePropertyAll(Size(64, 52)),
        side: WidgetStatePropertyAll(BorderSide(color: c.line)),
        textStyle: WidgetStatePropertyAll(style(VaultType.body, FontWeight.w600)),
        foregroundColor: WidgetStatePropertyAll(c.ink),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: c.accent,
      foregroundColor: c.onAccent,
      elevation: 2,
      focusElevation: 2,
      hoverElevation: 3,
      highlightElevation: 3,
      shape: const StadiumBorder(),
      extendedTextStyle: style(VaultType.body, FontWeight.w600),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      hintStyle: style(VaultType.body, FontWeight.w400, color: c.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c.accent, width: 2),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: c.line,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: style(20, FontWeight.w600),
      contentTextStyle: style(VaultType.body, FontWeight.w400, color: c.muted),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.ink,
      contentTextStyle: style(VaultType.body, FontWeight.w500, color: c.surface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.onAccent : c.muted),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.accent : c.raised),
      trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.accent : c.line),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.accent),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.accent,
      selectionColor: c.accentSoft,
      selectionHandleColor: c.accent,
    ),
  );
}
