/// Configurações globais do Supabase.
///
/// URL e chave pública não ficam no código: são passadas na compilação com
/// `--dart-define-from-file=env.local.json` (modelo em `env.example.json`,
/// arquivo real fora do Git) ou, no CI, pelos Secrets do repositório.
class SupabaseConfig {
  static const String authRedirect =
      'com.pietro.financafacil://login-callback/';
  static const String recoveryRedirect =
      'com.pietro.financafacil://reset-password/';
  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
