import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/data/auth_gateway.dart';
import '../../features/auth/data/auth_session_service.dart';
import '../../features/notifications/data/reminder_service.dart';
import '../../features/profile/data/profile_repository.dart';
import '../../features/transactions/data/finance_repository.dart';

/// Composição das implementações usadas em produção. Telas aceitam injeção em testes.
abstract final class AppServices {
  static final ReminderService reminders = LocalReminderService();
  static AuthSessionService get session =>
      AuthSessionService(Supabase.instance.client);
  static AuthGateway get auth => SupabaseAuthGateway(Supabase.instance.client);
  static ProfileRepository get profile =>
      SupabaseProfileRepository(Supabase.instance.client);
  static FinanceRepository get finance =>
      SupabaseFinanceRepository(Supabase.instance.client);
}
