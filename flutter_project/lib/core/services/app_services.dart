import 'package:supabase_flutter/supabase_flutter.dart';

import 'device_biometrics.dart';
import '../../features/auth/data/auth_gateway.dart';
import '../../features/auth/data/auth_session_service.dart';
import '../../features/imports/data/import_repository.dart';
import '../../features/notifications/data/reminder_service.dart';
import '../../features/profile/data/profile_repository.dart';
import '../../features/transactions/data/finance_repository.dart';

/// Composição das implementações usadas em produção. Telas aceitam injeção em testes.
abstract final class AppServices {
  static final ReminderService reminders = LocalReminderService();
  static final BiometricAuthenticator biometrics =
      DeviceBiometricAuthenticator();
  static AuthSessionService get session =>
      AuthSessionService(Supabase.instance.client);
  static AuthGateway get auth => SupabaseAuthGateway(Supabase.instance.client);
  static ProfileRepository get profile =>
      SupabaseProfileRepository(Supabase.instance.client);
  static SupabaseClient? _financeClient;
  static FinanceRepository? _finance;
  static FinanceRepository get finance {
    final client = Supabase.instance.client;
    if (!identical(client, _financeClient)) {
      _financeClient = client;
      _finance = SupabaseFinanceRepository(client);
    }
    return _finance!;
  }

  static ImportRepository get imports =>
      SupabaseImportRepository(Supabase.instance.client);
}
