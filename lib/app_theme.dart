import 'package:flutter/material.dart';

/// Shared semantic colors keep every part of the reading surface in sync.
@immutable
class AzkarColors extends ThemeExtension<AzkarColors> {
  const AzkarColors({
    required this.background,
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.surface,
    required this.card,
    required this.accent,
    required this.text,
    required this.muted,
    required this.border,
    required this.shadow,
    required this.selected,
    required this.onSelected,
  });

  final Color background;
  final Color backgroundTop;
  final Color backgroundBottom;
  final Color surface;
  final Color card;
  final Color accent;
  final Color text;
  final Color muted;
  final Color border;
  final Color shadow;
  final Color selected;
  final Color onSelected;

  static const dark = AzkarColors(
    background: Color(0xFF071224),
    backgroundTop: Color(0xFF11233A),
    backgroundBottom: Color(0xFF040810),
    surface: Color(0xFF11233A),
    card: Color(0xFF142640),
    accent: Color(0xFFD8A64B),
    text: Color(0xFFF8F1E2),
    muted: Color(0xFF97A5B8),
    border: Color(0x33D8A64B),
    shadow: Color(0x42000000),
    selected: Color(0xFF142640),
    onSelected: Color(0xFFF8F1E2),
  );

  static const light = AzkarColors(
    background: Color(0xFFF7F2E7),
    backgroundTop: Color(0xFFFFFCF5),
    backgroundBottom: Color(0xFFEDE5D3),
    surface: Color(0xFFF1EAD9),
    card: Color(0xFFFFFDF7),
    accent: Color(0xFF946B21),
    text: Color(0xFF183E35),
    muted: Color(0xFF657267),
    border: Color(0x66B58B40),
    shadow: Color(0x18183E35),
    selected: Color(0xFF234F43),
    onSelected: Color(0xFFFFF4D9),
  );

  @override
  AzkarColors copyWith({
    Color? background,
    Color? backgroundTop,
    Color? backgroundBottom,
    Color? surface,
    Color? card,
    Color? accent,
    Color? text,
    Color? muted,
    Color? border,
    Color? shadow,
    Color? selected,
    Color? onSelected,
  }) => AzkarColors(
    background: background ?? this.background,
    backgroundTop: backgroundTop ?? this.backgroundTop,
    backgroundBottom: backgroundBottom ?? this.backgroundBottom,
    surface: surface ?? this.surface,
    card: card ?? this.card,
    accent: accent ?? this.accent,
    text: text ?? this.text,
    muted: muted ?? this.muted,
    border: border ?? this.border,
    shadow: shadow ?? this.shadow,
    selected: selected ?? this.selected,
    onSelected: onSelected ?? this.onSelected,
  );

  @override
  AzkarColors lerp(covariant AzkarColors? other, double t) {
    if (other == null) return this;
    return AzkarColors(
      background: Color.lerp(background, other.background, t)!,
      backgroundTop: Color.lerp(backgroundTop, other.backgroundTop, t)!,
      backgroundBottom: Color.lerp(
        backgroundBottom,
        other.backgroundBottom,
        t,
      )!,
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      text: Color.lerp(text, other.text, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      border: Color.lerp(border, other.border, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      selected: Color.lerp(selected, other.selected, t)!,
      onSelected: Color.lerp(onSelected, other.onSelected, t)!,
    );
  }
}

ThemeData azkarTheme(Brightness brightness) {
  final colors = brightness == Brightness.dark
      ? AzkarColors.dark
      : AzkarColors.light;
  return ThemeData(
    brightness: brightness,
    useMaterial3: true,
    fontFamily: 'Amiri',
    scaffoldBackgroundColor: colors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: colors.accent,
      brightness: brightness,
      primary: colors.accent,
      onPrimary: brightness == Brightness.dark
          ? colors.background
          : Colors.white,
      secondary: colors.selected,
      surface: colors.card,
      onSurface: colors.text,
    ),
    dialogTheme: DialogThemeData(backgroundColor: colors.card),
    extensions: [colors],
  );
}

extension AzkarThemeContext on BuildContext {
  AzkarColors get azkarColors => Theme.of(this).extension<AzkarColors>()!;
}
