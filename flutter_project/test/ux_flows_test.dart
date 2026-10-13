import 'package:financafacil/features/transactions/domain/finance_models.dart';
import 'package:financafacil/features/transactions/domain/recurrence.dart';
import 'package:financafacil/features/transactions/presentation/screens/transactions_list_screen.dart';
import 'package:financafacil/shared/widgets/main_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'support/fake_repositories.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));
  testWidgets('troca de aba preserva cadastro até autorizar descarte',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: MainLayout(
            financeRepository: FakeFinanceRepository(),
            profileRepository: FakeProfileRepository())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finanças'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adicionar conta'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Valor'), '90,60');
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
  testWidgets('correção exige confirmação e devolve conta para pendente',
      (tester) async {
    final repository = FakeFinanceRepository()
      ..entries = [
        FinanceEntry(
            id: 'one',
            kind: TransactionKind.expense,
            amount: 90.6,
            description: 'Ótica',
            dueDate: DateTime.now(),
            categoryName: 'Saúde',
            isPaid: true)
      ];
    await tester.pumpWidget(
        MaterialApp(home: TransactionsListScreen(repository: repository)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Corrigir confirmação'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Corrigir confirmação'));
    await tester.pumpAndSettle();
    expect(repository.entries.single.isPaid, true);
    await tester.tap(find.text('Voltar para pendente'));
    await tester.pumpAndSettle();
    expect(repository.entries.single.isPaid, false);
    expect(find.byType(Checkbox), findsOneWidget);
  });
  test('mudança futura não altera mês anterior nem exceção confirmada', () {
    final result = projectRecurrences([
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
            {'from_month': '2027-02-01', 'amount': 100.0}
          ]
        }
      }
    ], [
      {
        'rule_id': 'rule',
        'due_month': '2027-03-01',
        'amount': 90.6,
        'is_paid': true
      }
    ], DateTime(2027, 3));
    expect(result.map((e) => e['amount']), [90.6, 100.0, 90.6]);
    expect(result.last['is_paid'], true);
  });
}
