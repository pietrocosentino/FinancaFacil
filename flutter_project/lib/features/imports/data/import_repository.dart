import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/finance_updates.dart';
import '../domain/import_models.dart';

abstract class ImportRepository {
  Future<Set<int>> similarLines(List<Map<String, Object?>> rows);
  Future<ImportReceipt> save(
    String name,
    String fileHash,
    List<Map<String, Object?>> rows, {
    required bool allowSimilar,
  });
}

class SupabaseImportRepository implements ImportRepository {
  SupabaseImportRepository(this.client);
  final SupabaseClient client;
  String get _owner {
    final id = client.auth.currentUser?.id;
    if (id == null) throw StateError('Sua sessão terminou. Entre novamente.');
    return id;
  }

  @override
  Future<Set<int>> similarLines(List<Map<String, Object?>> rows) async {
    _owner;
    if (rows.isEmpty) return {};
    final result = await client.rpc(
      'preview_finance_import',
      params: {'p_rows': rows},
    );
    return (result as List).map((line) => (line as num).toInt()).toSet();
  }

  @override
  Future<ImportReceipt> save(
    String name,
    String fileHash,
    List<Map<String, Object?>> rows, {
    required bool allowSimilar,
  }) async {
    _owner;
    final result = Map<String, dynamic>.from(
      await client.rpc(
        'import_finance_batch',
        params: {
          'p_file_name': name,
          'p_file_hash': fileHash,
          'p_rows': rows,
          'p_allow_similar': allowSimilar,
        },
      ) as Map,
    );
    notifyFinanceChanged();
    return ImportReceipt(
      result['batch_id'].toString(),
      (result['count'] as num).toInt(),
      result['already_imported'] == true,
    );
  }

}
