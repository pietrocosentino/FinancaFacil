import 'package:financafacil/features/transactions/domain/finance_models.dart';
import 'package:financafacil/features/transactions/presentation/screens/transactions_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/fake_repositories.dart';

class AmountRepository extends FakeFinanceRepository {
  bool fail = false;
  String? editedId;
  String? futureId;
  @override
  Future<void> updateAmount(String id, double amount) async {
    if (fail) throw StateError('Offline');
    editedId = id;
    updatedAmount = amount;
  }

  @override
  Future<void> updateFutureAmount(String id, double amount) async {
    futureId = id;
    updatedAmount = amount;
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));
  Future<AmountRepository> show(
    WidgetTester t,
    TransactionKind kind, {
    bool recurring = false,
  }) async {
    final now = DateTime.now();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
    final r = AmountRepository()
      ..entries = [
        FinanceEntry(
          id: recurring ? 'r:salary:$month' : 'one',
          kind: kind,
          amount: 3000,
          description: kind == TransactionKind.income ? 'Salário' : 'Aluguel',
          dueDate: now,
          categoryName: 'Categoria',
          isPaid: true,
          isRecurring: recurring,
          installment: recurring ? 1 : null,
        ),
      ];
    await t.pumpWidget(
      MaterialApp(home: TransactionsListScreen(repository: r)),
    );
    await t.pumpAndSettle();
    await t.ensureVisible(find.byType(PopupMenuButton<String>));
    await t.pumpAndSettle();
    await t.tap(find.byType(PopupMenuButton<String>));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Editar valor'));
    await t.pumpAndSettle();
    await t.tap(find.text('Editar valor'));
    await t.pumpAndSettle();
    return r;
  }

  for (final kind in TransactionKind.values) {
    testWidgets(
      'corrige valor confirmado de ${kind.label} sem desfazer confirmação',
      (t) async {
        final r = await show(t, kind);
        await t.enterText(find.byType(TextFormField), '3.250,50');
        await t.tap(find.text('Salvar'));
        await t.pumpAndSettle();
        expect(r.editedId, 'one');
        expect(r.updatedAmount, 3250.50);
        expect(r.paidIds, isNull);
        expect(r.entries.single.isPaid, true);
      },
    );
  }
  testWidgets('aumento de salário recebido começa no próximo mês', (t) async {
    final r = await show(t, TransactionKind.income, recurring: true);
    await t.tap(find.byType(SwitchListTile));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField), '3500,00');
    await t.tap(find.text('Salvar'));
    await t.pumpAndSettle();
    final now = DateTime.now();
    final next = DateTime(now.year, now.month + 1);
    expect(
      r.futureId,
      'r:salary:${next.year}-${next.month.toString().padLeft(2, '0')}-01',
    );
    expect(r.editedId, isNull);
    expect(r.updatedAmount, 3500);
  });
  testWidgets('cancelar não grava e valor zero impede salvar', (t) async {
    final r = await show(t, TransactionKind.income);
    await t.enterText(find.byType(TextFormField), '0');
    await t.tap(find.text('Salvar'));
    await t.pumpAndSettle();
    expect(find.text('Informe um valor maior que zero.'), findsOneWidget);
    expect(r.editedId, isNull);
    await t.tap(find.text('Cancelar'));
    await t.pumpAndSettle();
    expect(r.editedId, isNull);
  });
  testWidgets('erro ao salvar mantém formulário para tentar novamente', (
    t,
  ) async {
    final r = await show(t, TransactionKind.income);
    r.fail = true;
    await t.enterText(find.byType(TextFormField), '3500,00');
    await t.tap(find.text('Salvar'));
    await t.pumpAndSettle();
    expect(
      find.text('Não foi possível atualizar o valor. Tente novamente.'),
      findsOneWidget,
    );
    expect(r.editedId, isNull);
    r.fail = false;
    await t.tap(find.text('Salvar'));
    await t.pumpAndSettle();
    expect(r.updatedAmount, 3500);
  });
}
