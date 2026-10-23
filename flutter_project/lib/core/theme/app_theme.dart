import 'package:flutter/material.dart';

/// Tons de uma das aparências do app.
///
/// A paleta própria foi pensada para uso prolongado: sem branco nem preto
/// puros, verde-azulado de baixa saturação como cor principal e texto com
/// contraste confortável (acima de 4,5:1, sem o brilho máximo de 21:1).
@immutable
class AppPalette {
  const AppPalette({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.border,
    required this.text,
    required this.textMuted,
    required this.primary,
    required this.onPrimary,
    required this.primarySoft,
    required this.secondary,
    required this.tertiary,
    required this.error,
  });

  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color border;
  final Color text;
  final Color textMuted;
  final Color primary;
  final Color onPrimary;
  final Color primarySoft;
  final Color secondary;
  final Color tertiary;
  final Color error;

  /// Claro: papel levemente acinzentado, cartões um tom acima e verde-azulado.
  static const light = AppPalette(
    brightness: Brightness.light,
    background: Color(0xFFF2F4F1),
    surface: Color(0xFFFAFBF8),
    surfaceRaised: Color(0xFFE8ECE7),
    border: Color(0xFFD9DED7),
    text: Color(0xFF1E2622),
    textMuted: Color(0xFF56615B),
    primary: Color(0xFF2B6B62),
    onPrimary: Color(0xFFF7FBF9),
    primarySoft: Color(0xFFD3E7E1),
    secondary: Color(0xFF52627F),
    tertiary: Color(0xFF8A6526),
    error: Color(0xFFAF3A33),
  );

  /// Escuro: grafite esverdeado (não preto) e texto cinza-claro (não branco).
  static const dark = AppPalette(
    brightness: Brightness.dark,
    background: Color(0xFF131917),
    surface: Color(0xFF1B2320),
    surfaceRaised: Color(0xFF24302B),
    border: Color(0xFF303D37),
    text: Color(0xFFE1E7E3),
    textMuted: Color(0xFFA3AFA8),
    primary: Color(0xFF86CBBB),
    onPrimary: Color(0xFF0F2924),
    primarySoft: Color(0xFF244640),
    secondary: Color(0xFFAEBBD6),
    tertiary: Color(0xFFE2C27E),
    error: Color(0xFFEFA39C),
  );
}

/// Tema do app montado a partir de [AppPalette], com áreas de toque amplas.
class AppTheme {
  static ThemeData get lightTheme => _build(AppPalette.light);
  static ThemeData get darkTheme => _build(AppPalette.dark);

  static ThemeData _build(AppPalette palette) {
    final dark = palette.brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: palette.primary,
          brightness: palette.brightness,
        ).copyWith(
          primary: palette.primary,
          onPrimary: palette.onPrimary,
          primaryContainer: palette.primarySoft,
          onPrimaryContainer: palette.text,
          secondary: palette.secondary,
          tertiary: palette.tertiary,
          error: palette.error,
          surface: palette.surface,
          onSurface: palette.text,
          onSurfaceVariant: palette.textMuted,
          surfaceContainerLowest: palette.background,
          surfaceContainerLow: palette.surface,
          surfaceContainer: palette.surface,
          surfaceContainerHigh: palette.surfaceRaised,
          surfaceContainerHighest: palette.surfaceRaised,
          outline: palette.textMuted,
          outlineVariant: palette.border,
        );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );
    final textTheme = base.textTheme.apply(
      bodyColor: palette.text,
      displayColor: palette.text,
    );
    return base.copyWith(
      extensions: [dark ? AppColors.dark : AppColors.light],
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.background,
      dividerColor: palette.border,
      dividerTheme: DividerThemeData(color: palette.border),
      // A fonte do sistema está disponível mesmo sem conexão.
      textTheme: textTheme.copyWith(
        bodyLarge: textTheme.bodyLarge?.copyWith(fontSize: 16),
        bodySmall: textTheme.bodySmall?.copyWith(
          fontSize: 14,
          color: palette.textMuted,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(fontSize: 16, height: 1.4),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: palette.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: palette.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: dark ? palette.surfaceRaised : palette.text,
        contentTextStyle: TextStyle(
          color: dark ? palette.text : palette.background,
          fontSize: 15,
        ),
        behavior: SnackBarBehavior.floating,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: palette.surface,
        selectedColor: palette.primarySoft,
        side: BorderSide(color: palette.border),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: palette.surface,
        selectedItemColor: palette.primary,
        unselectedItemColor: palette.textMuted,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: palette.primarySoft,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface,
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: rounded,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: palette.onPrimary,
          minimumSize: const Size(48, 48),
          shape: rounded,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: rounded,
          side: BorderSide(color: palette.border),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: palette.primary,
        foregroundColor: palette.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: rounded,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
    );
  }
}

/// Cores com significado (positivo, alerta, perigo e neutro), ajustadas a cada
/// tema para manter contraste. Use `AppColors.of(context)`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.positive,
    required this.warning,
    required this.danger,
    required this.muted,
  });

  static const light = AppColors(
    positive: Color(0xFF2E7A4F),
    warning: Color(0xFF8A5A00),
    danger: Color(0xFFAF3A33),
    muted: Color(0xFF56615B),
  );
  static const dark = AppColors(
    positive: Color(0xFF8ED3A8),
    warning: Color(0xFFE9C46A),
    danger: Color(0xFFEFA39C),
    muted: Color(0xFFA3AFA8),
  );

  final Color positive;
  final Color warning;
  final Color danger;
  final Color muted;

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);

  /// Verde para saldo positivo ou zero, vermelho para negativo.
  Color balance(num value) => value < 0 ? danger : positive;

  @override
  AppColors copyWith({
    Color? positive,
    Color? warning,
    Color? danger,
    Color? muted,
  }) => AppColors(
    positive: positive ?? this.positive,
    warning: warning ?? this.warning,
    danger: danger ?? this.danger,
    muted: muted ?? this.muted,
  );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      positive: Color.lerp(positive, other.positive, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
    );
  }
}
