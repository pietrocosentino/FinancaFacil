/// Configurações globais e credenciais do Supabase
class SupabaseConfig {
  static const String authRedirect =
      'com.pietro.financafacil://login-callback/';
  static const String recoveryRedirect =
      'com.pietro.financafacil://reset-password/';
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://SEU-PROJETO.supabase.co',
  );
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'CHAVE_ANON_REMOVIDA',
  );
}
