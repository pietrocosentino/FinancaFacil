import '../../../core/utils/finance_utils.dart';
import '../../transactions/domain/finance_models.dart';

String normalizeImportText(String value) {
  const accents = 'áàâãäéèêëíìîïóòôõöúùûüç';
  const plain = 'aaaaaeeeeiiiiooooouuuuc';
  var result = value.trim().toLowerCase();
  for (var i = 0; i < accents.length; i++) {
    result = result.replaceAll(accents[i], plain[i]);
  }
  return result.replaceAll(RegExp(r'\s+'), ' ');
}

String importDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

DateTime? parseImportDate(Object? input) {
  if (input is DateTime) return DateTime(input.year, input.month, input.day);
  final text = input?.toString().trim() ?? '';
  final br = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(text);
  final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text);
  if (br == null && iso == null) return null;
  final year = int.parse(br?.group(3) ?? iso!.group(1)!);
  final month = int.parse(br?.group(2) ?? iso!.group(2)!);
  final day = int.parse(br?.group(1) ?? iso!.group(3)!);
  final date = DateTime(year, month, day);
  return date.year == year && date.month == month && date.day == day
      ? date
      : null;
}

class ImportLine {
  ImportLine(this.line, this.values, {this.categoryId, this.selected = true});
  final int line;
  final Map<String, Object?> values;
  String? categoryId;
  bool selected;
  bool similar = false;
  String? sourceError;

  String text(String field) {
    final value = values[field];
    return value is DateTime
        ? importDate(value)
        : value?.toString().trim() ?? '';
  }

  TransactionKind? get kind {
    try {
      return TransactionKind.fromDatabase(text('type'));
    } on FormatException {
      return null;
    }
  }

  double? get amount {
    final raw = values['amount'];
    final value = raw is num ? raw.toDouble() : parseMoney(text('amount'));
    if (value == null ||
        !value.isFinite ||
        value <= 0 ||
        value > 999999999.99) {
      return null;
    }
    if ((value * 100 - (value * 100).round()).abs() > 0.00001) return null;
    return (value * 100).round() / 100;
  }

  bool? get recurring {
    switch (normalizeImportText(text('recurring'))) {
      case 'sim':
        return true;
      case 'nao':
        return false;
      default:
        return null;
    }
  }

  int? get months {
    final value = text('months');
    final number = num.tryParse(value);
    return number != null && number.isFinite && number == number.toInt()
        ? number.toInt()
        : null;
  }

  DateTime? get due => parseImportDate(values['due_date']);
  int? get day {
    if (text('due_day').isEmpty) return due?.day;
    final number = num.tryParse(text('due_day'));
    return number != null && number.isFinite && number == number.toInt()
        ? number.toInt()
        : null;
  }

  List<String> errors(List<FinanceCategory> categories) => [
        if (sourceError != null) sourceError!,
        if (text('description').isEmpty || text('description').length > 160)
          'Descrição obrigatória, com até 160 caracteres.',
        if (kind == null) 'Tipo deve ser Receita ou Despesa.',
        if (amount == null) 'Valor positivo, com até duas casas decimais.',
        if (due == null || due!.year < 2020 || due!.year > 2100)
          'Vencimento válido entre 2020 e 2100: DD/MM/AAAA.',
        if (recurring == null) 'Recorrente deve ser Sim ou Não.',
        if (text('months').isNotEmpty &&
            (months == null || months! < 2 || months! > 1200))
          'Quantidade de meses: de 2 a 1200, ou vazia para não ter fim.',
        if (recurring == false && text('months').isNotEmpty)
          'Lançamento avulso não possui quantidade de meses.',
        if (day == null || day! < 1 || day! > 31)
          'Dia de vencimento deve ser de 1 a 31.',
        if (recurring == false && text('due_day').isNotEmpty && day != due?.day)
          'No lançamento avulso, o dia deve corresponder à data.',
        if (recurring == true &&
            due != null &&
            day != null &&
            day! >= 1 &&
            day! <= 31 &&
            monthlyDueDate(due!, 0, day: day).day != due!.day)
          'O primeiro vencimento deve corresponder ao dia mensal escolhido.',
        if (!categories.any((category) => category.id == categoryId))
          'Escolha uma categoria para este tipo de lançamento.',
        if (text('notes').length > 1000) 'Observações: até 1000 caracteres.',
      ];

  void matchCategory(List<FinanceCategory> categories) {
    final matches = categories.where((category) =>
        normalizeImportText(category.name) ==
        normalizeImportText(text('category')));
    categoryId = matches.length == 1 ? matches.single.id : null;
  }

  Map<String, Object?> get payload => {
        'line': line,
        'description': text('description'),
        'type': kind!.databaseValue,
        'amount': amount!,
        'due_date': importDate(due!),
        'due_day': day!,
        'recurring': recurring!,
        'months': months,
        'category_id': categoryId!,
        'notes': text('notes'),
      };

  String get signature =>
      '${kind?.databaseValue}|${normalizeImportText(text('description'))}|$amount|${due == null ? '' : importDate(due!)}|$recurring|$months|$day|$categoryId';
}

class ImportBatch {
  const ImportBatch(
      {required this.id,
      required this.name,
      required this.count,
      required this.createdAt,
      required this.active});
  final String id;
  final String name;
  final int count;
  final DateTime createdAt;
  final bool active;
  factory ImportBatch.fromMap(Map<String, dynamic> map) => ImportBatch(
      id: map['id'].toString(),
      name: map['file_name'].toString(),
      count: (map['row_count'] as num).toInt(),
      createdAt: DateTime.parse(map['created_at'].toString()),
      active: map['status'] == 'active');
}

class ImportReceipt {
  const ImportReceipt(this.batchId, this.count, this.alreadyImported);
  final String batchId;
  final int count;
  final bool alreadyImported;
}
