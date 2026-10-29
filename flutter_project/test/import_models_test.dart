import 'package:financafacil/features/imports/domain/import_models.dart';
import 'package:financafacil/features/transactions/domain/finance_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const categories = [FinanceCategory(id: 'home', name: 'Moradia')];
  ImportLine row([Map<String, Object?> change = const {}]) => ImportLine(2, {
    'description': 'Aluguel',
    'type': 'Despesa',
    'amount': '1.500,00',
    'due_date': '10/11/2026',
    'recurring': 'Sim',
    'months': '',
    'category': 'Moradia',
    ...change,
  }, categoryId: 'home');

  test('aluguel sem data final usa o dia e fica pendente no contrato', () {
    final line = row();
    expect(line.errors(categories), isEmpty);
    expect(line.amount, 1500);
    expect(line.payload['months'], isNull);
    expect(line.payload['due_day'], 10);
    expect(line.payload.containsKey('is_paid'), isFalse);
  });
  test('ótica mantém valor mensal e dez meses, sem multiplicar o valor', () {
    final line = row({'description': 'Ótica', 'amount': '90,60', 'months': 10});
    expect(line.errors(categories), isEmpty);
    expect(line.payload['amount'], 90.60);
    expect(line.payload['months'], 10);
  });
  test('avulso aceita meses vazios e recusa parcelamento', () {
    expect(row({'recurring': 'Não'}).errors(categories), isEmpty);
    expect(
      row({'recurring': 'Não', 'months': 10}).errors(categories),
      isNotEmpty,
    );
  });
  test('valor numérico preserva centavos; valores inválidos são recusados', () {
    expect(row({'amount': 90.60}).amount, 90.60);
    for (final value in [
      0,
      -1,
      double.infinity,
      double.nan,
      'abc',
      '90,601',
      0.001,
    ]) {
      expect(row({'amount': value}).amount, isNull, reason: '$value');
    }
  });
  test('datas inválidas não viram outro mês automaticamente', () {
    expect(parseImportDate('31/02/2026'), isNull);
    expect(parseImportDate('29/02/2028'), DateTime(2028, 2, 29));
    expect(parseImportDate('2026-11-08'), DateTime(2026, 11, 8));
    expect(row({'due_date': '01/01/2019'}).errors(categories), isNotEmpty);
  });
  test('vencimento dia 31 é mantido em fevereiro com data real válida', () {
    final line = row({'due_date': '28/02/2027', 'due_day': 31});
    expect(line.errors(categories), isEmpty);
    expect(line.payload['due_day'], 31);
    expect(row({'due_day': 8}).errors(categories), isNotEmpty);
  });
  test('quantidade de meses precisa ser inteira e estar no intervalo', () {
    for (final value in [1, 1201, 'dez', 2.5]) {
      expect(row({'months': value}).errors(categories), isNotEmpty);
    }
    expect(row({'months': 1200}).errors(categories), isEmpty);
    expect(row({'months': 2.0}).errors(categories), isEmpty);
  });
  test('tipo e recorrência não recebem valores padrão silenciosos', () {
    expect(row({'type': 'transferência'}).kind, isNull);
    expect(row({'recurring': ''}).recurring, isNull);
    expect(row({'type': 'RECEITA'}).kind, TransactionKind.income);
    expect(row({'recurring': 'NAO'}).recurring, isFalse);
  });
  test(
    'categoria desconhecida exige associação; correspondência ignora acentos',
    () {
      final line = row({'category': ' MORÁDIA '})..matchCategory(categories);
      expect(line.categoryId, 'home');
      line.values['category'] = 'Outra';
      line.matchCategory(categories);
      expect(line.categoryId, isNull);
      expect(line.errors(categories), isNotEmpty);
    },
  );
  test('duas categorias de mesmo nome não são escolhidas automaticamente', () {
    final line = row()
      ..matchCategory([
        ...categories,
        const FinanceCategory(id: 'other', name: 'Moradia'),
      ]);
    expect(line.categoryId, isNull);
  });
  test('fórmula e descrição vazia bloqueiam a linha', () {
    final line = row({'description': ''})..sourceError = 'Fórmula encontrada';
    expect(line.errors(categories).length, greaterThanOrEqualTo(2));
  });
}
