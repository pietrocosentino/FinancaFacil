import 'package:financafacil/features/transactions/domain/finance_models.dart';
import 'package:financafacil/features/transactions/domain/recurrence.dart';
import 'package:financafacil/features/transactions/presentation/screens/transactions_list_screen.dart';
import 'package:financafacil/shared/widgets/main_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/fake_repositories.dart';
import 'support/navigation.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));
  testWidgets('troca de aba preserva cadastro até autorizar descarte', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MainLayout(
          financeRepository: FakeFinanceRepository(),
          profileRepository: FakeProfileRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await openAdd(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Valor da conta'),
      '90,60',
    );
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    expect(find.text('Descartar cadastro?'), findsOneWidget);
    await tester.tap(find.text('Continuar preenchendo'));
    await tester.pumpAndSettle();
    expect(find.text('90,60'), findsOneWidget);
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(find.text('Dados pessoais'), findsOneWidget);
    expect(find.text('pietro@example.com'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('confirmado por engano é inativado e sai dos totais', (
    tester,
  ) async {
    final repository = FakeFinanceRepository()
      ..entries = [
        FinanceEntry(
          id: 'one',
          kind: TransactionKind.expense,
          amount: 90.6,
          description: 'Ótica',
          dueDate: DateTime.now(),
          categoryName: 'Saúde',
          isPaid: true,
        ),
      ];
    await tester.pumpWidget(
      MaterialApp(home: TransactionsListScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('Excluir lançamento'), findsNothing);
    expect(find.text('Editar lançamento'), findsNothing);
    await tester.ensureVisible(find.text('Inativar (confirmei por engano)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inativar (confirmei por engano)'));
    await tester.pumpAndSettle();
    expect(repository.inactiveChanges, isEmpty);
    await tester.tap(find.text('Inativar'));
    await tester.pumpAndSettle();
    expect(repository.inactiveChanges, {'one': true});
    expect(repository.entries.single.isPaid, true);
    expect(find.text('Inativo · fora dos totais'), findsOneWidget);
    expect(
      find.textContaining(RegExp(r'^Despesas R\$\s0,00$')),
      findsOneWidget,
    );
    expect(find.byType(Checkbox), findsNothing);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reativar lançamento'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reativar'));
    await tester.pumpAndSettle();
    expect(repository.inactiveChanges, {'one': false});
    expect(find.text('Pago'), findsOneWidget);
  });
  test('mudança futura não altera mês anterior nem exceção confirmada', () {
    final result = projectRecurrences(
      [
        {
          'id': 'rule',
          'user_id': 'user',
          'first_due': '2027-01-08',
          'due_day': 8,
          'template': {
            'type': 'despesa',
            'amount': 90.6,
            'description': 'Ótica',
            'category_id': '1',
            'future_amounts': [
              {'from_month': '2027-02-01', 'amount': 100.0},
            ],
          },
        },
      ],
      [
        {
          'rule_id': 'rule',
          'due_month': '2027-03-01',
          'amount': 90.6,
          'is_paid': true,
        },
      ],
      DateTime(2027, 3),
    );
    expect(result.map((e) => e['amount']), [90.6, 100.0, 90.6]);
    expect(result.last['is_paid'], true);
  });
}
