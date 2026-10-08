import 'package:flutter/material.dart';

/// Uma paleta coerente nos dois temas, com contraste e áreas de toque amplas.
class AppTheme {
  static const scaffoldBackground = Color(0xFF121212);
  static const surfaceCard = Color(0xFF1E1E1E);
  static const mintNeon = Color(0xFF5EEAD4);
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFFA1A1AA);
  static const borderSubtle = Color(0xFF353535);
  static const _lightPrimary = Color(0xFF007960);

  static ThemeData get lightTheme => _build(Brightness.light);
  static ThemeData get darkTheme => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final primary = dark ? mintNeon : _lightPrimary;
    final surface = dark ? surfaceCard : Colors.white;
    final background = dark ? scaffoldBackground : const Color(0xFFF4F6F7);
    final border = dark ? borderSubtle : const Color(0xFFD8DEE3);
    final scheme = ColorScheme.fromSeed(
        seedColor: primary,
        brightness: brightness,
        primary: primary,
        onPrimary: dark ? scaffoldBackground : Colors.white,
        surface: surface);
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final rounded =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    return base.copyWith(
      scaffoldBackgroundColor: background,
      // A fonte do sistema está disponível mesmo sem conexão.
      textTheme: base.textTheme.copyWith(
        titleMedium:
            base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.4),
      ),
      appBarTheme: AppBarTheme(
          backgroundColor: background,
          foregroundColor: scheme.onSurface,
          elevation: 0,
          centerTitle: false),
      cardTheme: CardTheme(
          color: surface,
          elevation: 0,
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: border))),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: surface,
          selectedItemColor: primary,
          unselectedItemColor: dark ? textSecondary : const Color(0xFF515760),
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          elevation: 0),
      inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          contentPadding: const EdgeInsets.all(16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: primary, width: 2))),
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: scheme.onPrimary,
              minimumSize: const Size(48, 52),
              shape: rounded,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14))),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 48),
              shape: rounded,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12))),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          focusElevation: 0,
          hoverElevation: 0,
          highlightElevation: 0,
          shape: rounded),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48))),
    );
  }

  static Color semanticColor(BuildContext context, Color color) {
    if (Theme.of(context).brightness == Brightness.dark) return color;
    if (color == mintNeon) return _lightPrimary;
    if (color == Colors.redAccent) return const Color(0xFFB00020);
    if (color == Colors.amber) return const Color(0xFF865300);
    return Theme.of(context).colorScheme.onSurface;
  }
}
