import 'package:financafacil/features/dashboard/domain/finance_summary.dart';
import 'package:financafacil/features/transactions/domain/finance_models.dart';
import 'package:financafacil/features/transactions/presentation/screens/add_transaction_screen.dart';
import 'package:financafacil/features/transactions/presentation/screens/transactions_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/fake_repositories.dart';

Map<String, dynamic> income({
  String type = 'receita',
  bool recurring = true,
  String due = '2026-10-08',
  bool paid = false,
}) => {
  'id': 'salary',
  'type': type,
  'amount': 3000,
  'description': 'Salário',
  'due_date': due,
  'is_paid': paid,
  'is_recurrent': recurring,
};
void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));
  test('salário só entra no saldo na data mensal, sem confirmação', () {
    final row = income();
    expect(
      FinanceEntry.fromMap(row, today: DateTime(2026, 10, 7)).isPaid,
      false,
    );
    final received = FinanceEntry.fromMap(row, today: DateTime(2026, 10, 8));
    expect(received.isPaid, true);
    expect(
      FinanceSummary.forMonth([received], DateTime(2026, 10)).availableBalance,
      3000,
    );
    expect(row['is_paid'], false);
  });
  test(
    'consulta futura não antecipa crédito, mesmo com confirmação antiga',
    () {
      expect(
        FinanceEntry.fromMap(
          income(due: '2026-11-08', paid: true),
          today: DateTime(2026, 10, 8),
        ).isPaid,
        false,
      );
    },
  );
  test('despesa mensal continua exigindo pagamento manual', () {
    expect(
      FinanceEntry.fromMap(
        income(type: 'despesa'),
        today: DateTime(2026, 10, 8),
      ).isPaid,
      false,
    );
  });
  test('renda avulsa mantém confirmação manual', () {
    expect(
      FinanceEntry.fromMap(
        income(recurring: false),
        today: DateTime(2026, 10, 8),
      ).isPaid,
      false,
    );
  });
  test('valor corrigido de salário recebido reflete no saldo', () {
    final row = income()..['amount'] = 3250.50;
    final entry = FinanceEntry.fromMap(row, today: DateTime(2026, 10, 8));
    expect(
      FinanceSummary.forMonth([entry], DateTime(2026, 10)).availableBalance,
      3250.50,
    );
  });
  for (final paid in [false, true]) {
    testWidgets(
      'renda mensal não oferece confirmação; editar permanece ($paid)',
      (t) async {
        final r = FakeFinanceRepository()
          ..entries = [
            FinanceEntry(
              id: 'one',
              kind: TransactionKind.income,
              amount: 3000,
              description: 'Salário',
              dueDate: DateTime.now(),
              categoryName: 'Salário',
              isPaid: paid,
              isRecurring: true,
            ),
          ];
        await t.pumpWidget(
          MaterialApp(home: TransactionsListScreen(repository: r)),
        );
        await t.pumpAndSettle();
        expect(find.byType(Checkbox), findsNothing);
        expect(find.text('Corrigir confirmação'), findsNothing);
        await t.tap(find.byType(PopupMenuButton<String>));
        await t.pumpAndSettle();
        expect(find.text('Corrigir confirmação'), findsNothing);
        final edit = find.text('Editar valor');
        await t.ensureVisible(edit);
        await t.pumpAndSettle();
        await t.tap(edit);
        await t.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
      },
    );
  }
  for (final kind in TransactionKind.values) {
    testWidgets('Sair após cadastrar ${kind.label} retorna à tela anterior', (
      t,
    ) async {
      final r = FakeFinanceRepository();
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AddTransactionScreen(repository: r),
                  ),
                ),
                child: const Text('Abrir cadastro'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Abrir cadastro'));
      await t.pumpAndSettle();
      if (kind == TransactionKind.income) {
        await t.tap(find.text('Receita'));
        await t.pumpAndSettle();
      }
      await t.enterText(find.widgetWithText(TextFormField, 'Valor'), '100');
      await t.enterText(
        find.widgetWithText(TextFormField, 'Nome da conta ou renda'),
        'Teste',
      );
      await t.tap(find.text('Salvar lançamento'));
      await t.pumpAndSettle();
      expect(find.text('Cadastrar outra'), findsOneWidget);
      expect(find.text('Sair'), findsOneWidget);
      await t.tap(find.text('Sair'));
      await t.pumpAndSettle();
      expect(r.saved?.kind, kind);
      expect(find.byType(AddTransactionScreen), findsNothing);
      expect(find.text('Abrir cadastro'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}
