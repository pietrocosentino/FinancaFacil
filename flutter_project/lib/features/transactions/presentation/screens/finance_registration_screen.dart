import 'package:flutter/material.dart';

class FinanceRegistrationScreen extends StatelessWidget {
  const FinanceRegistrationScreen({
    super.key,
    required this.onAddExpense,
    required this.onAddIncome,
    required this.onImport,
  });
  final VoidCallback onAddExpense;
  final VoidCallback onAddIncome;
  final VoidCallback onImport;

  Widget _option(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Finanças')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'O que você quer cadastrar?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text('Consulte e altere os lançamentos na aba Extrato.'),
        const SizedBox(height: 16),
        _option(
          context,
          Icons.receipt_outlined,
          'Adicionar conta',
          'Despesas, contas fixas e compras parceladas',
          onAddExpense,
        ),
        _option(
          context,
          Icons.savings_outlined,
          'Adicionar renda',
          'Salário e outros valores recebidos',
          onAddIncome,
        ),
        _option(
          context,
          Icons.upload_file_outlined,
          'Importar planilha',
          'Cadastre vários valores usando o modelo Excel',
          onImport,
        ),
      ],
    ),
  );
}
