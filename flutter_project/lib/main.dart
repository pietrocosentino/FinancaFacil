import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'core/errors/app_log.dart';
import 'core/services/app_services.dart';
import 'core/services/device_preferences.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/screens/auth_gate.dart';
import 'shared/widgets/async_panel.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppLog.installGlobalHandlers();
  // Android 15+ desenha o app de ponta a ponta; as barras do sistema ficam
  // transparentes e o SafeArea das telas reserva o espaço delas.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const FinancaFacilApp());
}

class FinancaFacilApp extends StatelessWidget {
  const FinancaFacilApp({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
    valueListenable: DevicePreferences.themeMode,
    builder: (_, mode, __) => MaterialApp(
      title: 'FinançaFácil',
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value:
            (Theme.of(context).brightness == Brightness.dark
                    ? SystemUiOverlayStyle.light
                    : SystemUiOverlayStyle.dark)
                .copyWith(
                  statusBarColor: Colors.transparent,
                  systemNavigationBarColor: Colors.transparent,
                ),
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
      await DevicePreferences.load();
      await AppServices.reminders.initialize();
    } catch (error, stack) {
      AppLog.error(error, stack, 'inicialização dos lembretes');
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
