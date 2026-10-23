import 'package:financafacil/features/imports/data/import_repository.dart';
import 'package:financafacil/features/imports/domain/import_models.dart';

/// Importação em memória para testes que abrem a tela pelo layout principal.
class FakeImportRepository implements ImportRepository {
  List<Map<String, Object?>>? saved;
  @override
  Future<Set<int>> similarLines(List<Map<String, Object?>> rows) async => {};
  @override
  Future<ImportReceipt> save(
    String name,
    String fileHash,
    List<Map<String, Object?>> rows, {
    required bool allowSimilar,
  }) async {
    saved = rows;
    return ImportReceipt('batch', rows.length, false);
  }

  @override
  Future<List<ImportBatch>> history() async => [];
  @override
  Future<int> undo(String batchId) async => 0;
}
