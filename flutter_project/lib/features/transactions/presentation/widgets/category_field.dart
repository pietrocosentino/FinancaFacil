import 'package:flutter/material.dart';

import '../../data/finance_repository.dart';
import '../../domain/finance_models.dart';

/// Categoria usada quando o usuário não escolhe nenhuma.
String defaultCategoryName(TransactionKind kind) =>
    kind == TransactionKind.income ? 'Outras receitas' : 'Outras despesas';

/// Mensagem de erro para o texto digitado, ou `null` quando é aceito.
/// Vazio é aceito: a categoria é opcional.
String? categoryNameError(String text) {
  final name = text.trim();
  if (name.isEmpty) return null;
  return name.length < 2 || name.length > 40
      ? 'Use de 2 a 40 caracteres.'
      : null;
}

/// Converte o texto do campo em uma categoria: usa a existente com o mesmo
/// nome, cria uma nova quando não existe e usa a padrão quando está vazio.
Future<String> resolveCategoryId(
  FinanceRepository repository,
  TransactionKind kind,
  List<FinanceCategory> categories,
  String text,
) async {
  final typed = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  final name = typed.isEmpty ? defaultCategoryName(kind) : typed;
  for (final category in categories) {
    if (category.name.toLowerCase() == name.toLowerCase()) return category.id;
  }
  return (await repository.createCategory(kind, name)).id;
}

/// Campo único de categoria: lista para escolher e texto livre para criar uma
/// nova. Opcional.
class CategoryField extends StatelessWidget {
  const CategoryField({
    super.key,
    required this.kind,
    required this.categories,
    required this.controller,
    this.enabled = true,
    this.errorText,
    this.onChanged,
  });
  final TransactionKind kind;
  final List<FinanceCategory> categories;
  final TextEditingController controller;
  final bool enabled;
  final String? errorText;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => DropdownMenu<String>(
      controller: controller,
      enabled: enabled,
      width: constraints.maxWidth,
      enableFilter: true,
      requestFocusOnTap: true,
      menuHeight: 280,
      label: const Text('Categoria (opcional)'),
      hintText: kind == TransactionKind.income
          ? 'Ex.: Salário, Freela, Aluguel recebido'
          : 'Ex.: Moradia, Mercado, Saúde',
      helperText:
          'Escolha da lista ou digite uma nova. Em branco, fica em ${defaultCategoryName(kind)}.',
      errorText: errorText,
      leadingIcon: const Icon(Icons.sell_outlined),
      onSelected: (_) => onChanged?.call(),
      dropdownMenuEntries: [
        for (final category in categories)
          DropdownMenuEntry(value: category.name, label: category.name),
      ],
    ),
  );
}
