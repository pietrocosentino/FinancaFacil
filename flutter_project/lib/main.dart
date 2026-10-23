import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'core/services/app_services.dart';
import 'core/services/reminder_preferences.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/screens/auth_gate.dart';
import 'shared/widgets/async_panel.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.surfaceCard,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const FinancaFacilApp());
}

class FinancaFacilApp extends StatelessWidget {
  const FinancaFacilApp({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
    valueListenable: ReminderPreferences.themeMode,
    builder: (_, mode, __) => MaterialApp(
      title: 'FinançaFácil',
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: Theme.of(context).brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: child!,
      ),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: mode,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const _ApplicationStartup(),
    ),
  );
}

class _ApplicationStartup extends StatefulWidget {
  const _ApplicationStartup();
  @override
  State<_ApplicationStartup> createState() => _ApplicationStartupState();
}

class _ApplicationStartupState extends State<_ApplicationStartup> {
  late Future<void> _initialization;
  @override
  void initState() {
    super.initState();
    _initialization = _initialize();
  }

  Future<void> _initialize() async {
    await initializeDateFormatting('pt_BR');
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );
    try {
      await ReminderPreferences.load();
      await AppServices.reminders.initialize();
    } catch (_) {
      // Uma falha de notificações não impede o acesso às finanças.
    }
  }

  @override
  Widget build(BuildContext context) => AsyncPanel<void>(
    future: _initialization,
    onRetry: () => setState(() {
      _initialization = _initialize();
    }),
    errorMessage: 'Não foi possível iniciar o aplicativo. Verifique a conexão.',
    builder: (_) => const AuthGate(),
  );
}
