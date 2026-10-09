import 'package:supabase_flutter/supabase_flutter.dart';

String importFailure(Object error) {
  if (error is FormatException) return error.message;
  if (error is PostgrestException) {
    if (['42883', '42P01', 'PGRST202', 'PGRST205'].contains(error.code)) {
      return 'A importação ainda não está ativada no banco. Execute importacao_mvp2.sql no Supabase.';
    }
    if (error.code == 'P0001') return error.message;
  }
  return 'Não foi possível concluir. Confira a conexão e tente novamente. Nenhum cadastro parcial será feito.';
}
