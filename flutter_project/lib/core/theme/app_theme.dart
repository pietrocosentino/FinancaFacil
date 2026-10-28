import 'package:flutter/material.dart';

/// Tons de uma das aparências do app.
///
/// Paleta financeira com verde como cor de ação, neutros quentes e acento
/// dourado discreto. O cartão de saldo previsto usa [AppColors] separado.
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

  /// Claro: fundo quente, superfícies claras e verde financeiro.
  static const light = AppPalette(
    brightness: Brightness.light,
    background: Color(0xFFF5F3ED),
    surface: Color(0xFFFFFEFA),
    surfaceRaised: Color(0xFFECE9DF),
    border: Color(0xFFDEDACF),
    text: Color(0xFF202A25),
    textMuted: Color(0xFF66716A),
    primary: Color(0xFF236B52),
    onPrimary: Color(0xFFF7FBF8),
    primarySoft: Color(0xFFDCECE2),
    secondary: Color(0xFF52687A),
    tertiary: Color(0xFF96713B),
    error: Color(0xFFAF3A33),
  );

  /// Escuro: carvão esverdeado com verde claro para manter contraste.
  static const dark = AppPalette(
    brightness: Brightness.dark,
    background: Color(0xFF111A16),
    surface: Color(0xFF1B2721),
    surfaceRaised: Color(0xFF29372F),
    border: Color(0xFF3A4A40),
    text: Color(0xFFEEF2EB),
    textMuted: Color(0xFFA9B6AB),
    primary: Color(0xFF80C99F),
    onPrimary: Color(0xFF14261D),
    primarySoft: Color(0xFF294638),
    secondary: Color(0xFFAEC1D0),
    tertiary: Color(0xFFD5B477),
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
        elevation: 1,
        shadowColor: palette.text.withValues(alpha: dark ? 0.12 : 0.05),
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
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: palette.primarySoft,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
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

/// Cores com significado e da marca, ajustadas a cada tema para manter
/// contraste. Use `AppColors.of(context)`.
///
/// A marca (verde-petróleo) aparece no cabeçalho e no cartão de saldo; renda
/// é sempre verde e despesa sempre coral, nos botões e nos valores.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.positive,
    required this.warning,
    required this.danger,
    required this.muted,
    required this.brand,
    required this.brandDeep,
    required this.onBrand,
    required this.onBrandMuted,
    required this.brandPositive,
    required this.brandNegative,
    required this.brandWarning,
    required this.income,
    required this.onIncome,
    required this.expense,
    required this.onExpense,
  });

  static const light = AppColors(
    positive: Color(0xFF2E7A4F),
    warning: Color(0xFF8A5A00),
    danger: Color(0xFFAF3A33),
    muted: Color(0xFF56615B),
    brand: Color(0xFF0E5B53),
    brandDeep: Color(0xFF0A4741),
    onBrand: Color(0xFFF2FAF7),
    onBrandMuted: Color(0xFFB9DCD4),
    brandPositive: Color(0xFFA8EBC4),
    brandNegative: Color(0xFFFFB8AC),
    brandWarning: Color(0xFFFFD98F),
    income: Color(0xFF1F7A4A),
    onIncome: Color(0xFFF4FBF6),
    expense: Color(0xFFB4483A),
    onExpense: Color(0xFFFFF6F4),
  );
  static const dark = AppColors(
    positive: Color(0xFF8ED3A8),
    warning: Color(0xFFE9C46A),
    danger: Color(0xFFEFA39C),
    muted: Color(0xFFA3AFA8),
    brand: Color(0xFF15433D),
    brandDeep: Color(0xFF0F312D),
    onBrand: Color(0xFFE6F3EF),
    onBrandMuted: Color(0xFFA6C9C1),
    brandPositive: Color(0xFF9FE6BC),
    brandNegative: Color(0xFFFFB4A8),
    brandWarning: Color(0xFFF5D38A),
    income: Color(0xFF8ED3A8),
    onIncome: Color(0xFF0E2A1B),
    expense: Color(0xFFF0A094),
    onExpense: Color(0xFF3A1410),
  );

  final Color positive;
  final Color warning;
  final Color danger;
  final Color muted;

  /// Fundo do cabeçalho e do cartão de saldo.
  final Color brand;
  final Color brandDeep;
  final Color onBrand;
  final Color onBrandMuted;

  /// Positivo, negativo e alerta legíveis sobre [brand].
  final Color brandPositive;
  final Color brandNegative;
  final Color brandWarning;

  /// Botão e destaques de renda e de despesa.
  final Color income;
  final Color onIncome;
  final Color expense;
  final Color onExpense;

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);

  /// Verde para saldo positivo ou zero, vermelho para negativo.
  Color balance(num value) => value < 0 ? danger : positive;

  /// Mesmo critério de [balance], legível sobre a cor da marca.
  Color brandBalance(num value) => value < 0 ? brandNegative : brandPositive;

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
    brand: brand,
    brandDeep: brandDeep,
    onBrand: onBrand,
    onBrandMuted: onBrandMuted,
    brandPositive: brandPositive,
    brandNegative: brandNegative,
    brandWarning: brandWarning,
    income: income,
    onIncome: onIncome,
    expense: expense,
    onExpense: onExpense,
  );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      positive: mix(positive, other.positive),
      warning: mix(warning, other.warning),
      danger: mix(danger, other.danger),
      muted: mix(muted, other.muted),
      brand: mix(brand, other.brand),
      brandDeep: mix(brandDeep, other.brandDeep),
      onBrand: mix(onBrand, other.onBrand),
      onBrandMuted: mix(onBrandMuted, other.onBrandMuted),
      brandPositive: mix(brandPositive, other.brandPositive),
      brandNegative: mix(brandNegative, other.brandNegative),
      brandWarning: mix(brandWarning, other.brandWarning),
      income: mix(income, other.income),
      onIncome: mix(onIncome, other.onIncome),
      expense: mix(expense, other.expense),
      onExpense: mix(onExpense, other.onExpense),
    );
  }
}
