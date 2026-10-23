import '../../../core/utils/dates.dart';
import '../../../core/utils/finance_utils.dart';
import 'recurrence.dart';

enum TransactionKind {
  expense('despesa', 'EXPENSE', 'Despesa'),
  income('receita', 'INCOME', 'Receita');

  const TransactionKind(this.databaseValue, this.categoryValue, this.label);
  final String databaseValue;
  final String categoryValue;
  final String label;

  static TransactionKind fromDatabase(Object? value) {
    switch (value?.toString().trim().toUpperCase()) {
      case 'DESPESA':
      case 'EXPENSE':
        return expense;
      case 'RECEITA':
      case 'INCOME':
        return income;
      default:
        throw const FormatException('Tipo de lançamento inválido.');
    }
  }
}

class FinanceCategory {
  const FinanceCategory({required this.id, required this.name});
  final String id;
  final String name;
  factory FinanceCategory.fromMap(Map<String, dynamic> data) =>
      FinanceCategory(id: data['id'].toString(), name: data['name'].toString());
}

class FinanceEntry {
  const FinanceEntry({
    required this.id,
    required this.kind,
    required this.amount,
    required this.description,
    required this.dueDate,
    required this.categoryName,
    required this.isPaid,
    this.notes = '',
    this.isRecurring = false,
    this.installment,
    this.totalInstallments,
    this.lastDue,
    this.manualReceipt = false,
    this.isInactive = false,
    this.categoryId = '',
  });
  final String id;

  /// Vazio quando o registro não informa a categoria.
  final String categoryId;
  final TransactionKind kind;
  final double amount;
  final String description;
  final DateTime? dueDate;
  final String categoryName;
  final bool isPaid;
  final String notes;
  final bool isRecurring;
  final int? installment;
  final int? totalInstallments;
  final DateTime? lastDue;

  /// Mês de renda recorrente marcado como "Não recebi": deixa de ser
  /// automático e passa a exigir confirmação, como uma conta.
  final bool manualReceipt;

  /// Confirmação feita por engano: continua no histórico, mas sai dos totais.
  final bool isInactive;

  /// Conta paga não pode ser alterada nem excluída; resta inativar. Renda
  /// continua editável mesmo depois de recebida (descontos, férias, débitos).
  bool get isLocked => isPaid && !isIncome;

  /// Entra nas somas de receitas, despesas e saldo.
  bool get countsInTotals => !isInactive;
  int get amountInCents => (amount * 100).round();
  bool get isIncome => kind == TransactionKind.income;
  bool get isAutomaticIncome => isIncome && isRecurring && !manualReceipt;
  bool belongsToMonth(DateTime month) =>
      dueDate?.year == month.year && dueDate?.month == month.month;

  /// Mapa no mesmo formato lido por [FinanceEntry.fromMap]; usado no cache
  /// local que mantém os lembretes disponíveis sem conexão.
  Map<String, dynamic> toMap() => {
    'id': id,
    'type': kind.databaseValue,
    'amount': amount,
    'description': description,
    'notes': notes,
    'due_date': dueDate?.toIso8601String(),
    'category': {'name': categoryName},
    'category_id': categoryId,
    'is_paid': isPaid,
    'is_recurrent': isRecurring,
    '_installment': installment,
    '_total_installments': totalInstallments,
    '_last_due': lastDue?.toIso8601String(),
    '_manual_receipt': manualReceipt,
    'is_inactive': isInactive,
  };

  /// Cópia com confirmação ou valor alterados; os demais dados são mantidos.
  FinanceEntry copyWith({bool? isPaid, double? amount, bool? isInactive}) =>
      FinanceEntry(
        id: id,
        kind: kind,
        amount: amount ?? this.amount,
        description: description,
        dueDate: dueDate,
        categoryName: categoryName,
        categoryId: categoryId,
        isPaid: isPaid ?? this.isPaid,
        notes: notes,
        isRecurring: isRecurring,
        installment: installment,
        totalInstallments: totalInstallments,
        lastDue: lastDue,
        manualReceipt: manualReceipt,
        isInactive: isInactive ?? this.isInactive,
      );

  String get recurrenceDescription {
    if (installment == null) return isRecurring ? 'Recorrência antiga' : '';
    return totalInstallments == null
        ? 'Mensal • sem data final'
        : 'Parcela $installment de $totalInstallments';
  }

  factory FinanceEntry.fromMap(Map<String, dynamic> data, {DateTime? today}) {
    final kind = TransactionKind.fromDatabase(data['type']);
    final dueDate = DateTime.tryParse(data['due_date']?.toString() ?? '');
    final recurring = data['is_recurrent'] == true;
    final now = today ?? DateTime.now();
    final currentDay = DateTime(now.year, now.month, now.day);
    final manualReceipt = data['_manual_receipt'] == true;
    final automaticIncome =
        kind == TransactionKind.income && recurring && !manualReceipt;
    final category = data['category'];
    final amount = data['amount'] is num
        ? (data['amount'] as num).toDouble()
        : double.tryParse('${data['amount']}');
    if (amount == null || !amount.isFinite || amount <= 0) {
      throw const FormatException('Valor do lançamento inválido.');
    }
    return FinanceEntry(
      id: data['id'].toString(),
      kind: kind,
      amount: amount,
      description: data['description']?.toString() ?? 'Lançamento',
      dueDate: dueDate,
      categoryName: category is Map
          ? category['name']?.toString() ?? 'Sem categoria'
          : 'Sem categoria',
      isPaid: automaticIncome
          ? dueDate != null &&
                !DateTime(
                  dueDate.year,
                  dueDate.month,
                  dueDate.day,
                ).isAfter(currentDay)
          : data['is_paid'] == true,
      notes: data['notes']?.toString() ?? '',
      isRecurring: data['is_recurrent'] == true,
      installment: (data['_installment'] as num?)?.toInt(),
      totalInstallments: (data['_total_installments'] as num?)?.toInt(),
      lastDue: DateTime.tryParse(data['_last_due']?.toString() ?? ''),
      manualReceipt: manualReceipt,
      isInactive: data['is_inactive'] == true,
      categoryId: data['category_id']?.toString() ?? '',
    );
  }
}

/// Dados editáveis de um lançamento avulso pendente.
class EntryDetails {
  EntryDetails({
    required String description,
    required this.amount,
    required this.dueDate,
    required this.categoryId,
    String notes = '',
  }) : description = description.trim(),
       notes = notes.trim() {
    if (this.description.isEmpty || this.description.length > 120) {
      throw const FormatException('Informe um nome de até 120 caracteres.');
    }
    if (!amount.isFinite || amount <= 0) {
      throw const FormatException('Informe um valor válido maior que zero.');
    }
    if (categoryId.isEmpty) {
      throw const FormatException('Selecione uma categoria.');
    }
  }
  final String description;
  final double amount;
  final DateTime dueDate;
  final String categoryId;
  final String notes;

  Map<String, dynamic> toMap() => {
    'description': description,
    'amount': amount,
    'due_date': isoDate(dueDate),
    'category_id': categoryId,
    'notes': notes,
  };
}

/// Alteração definitiva de uma renda fixa: vale do mês informado em diante.
class IncomeChange {
  IncomeChange({
    required String description,
    required this.amount,
    required this.categoryId,
    required this.dueDay,
  }) : description = description.trim() {
    if (this.description.isEmpty || this.description.length > 120) {
      throw const FormatException('Informe um nome de até 120 caracteres.');
    }
    if (!amount.isFinite || amount <= 0) {
      throw const FormatException('Informe um valor válido maior que zero.');
    }
    if (dueDay < 1 || dueDay > 31) {
      throw const FormatException('Informe um dia de 1 a 31.');
    }
    if (categoryId.isEmpty) {
      throw const FormatException('Selecione uma categoria.');
    }
  }
  final String description;
  final double amount;
  final String categoryId;
  final int dueDay;
}

/// Dados de uma renda mensal que valem para todos os meses.
class IncomeRuleDetails {
  IncomeRuleDetails({
    required String description,
    required this.categoryId,
    required this.dueDay,
  }) : description = description.trim() {
    if (this.description.isEmpty || this.description.length > 120) {
      throw const FormatException('Informe um nome de até 120 caracteres.');
    }
    if (dueDay < 1 || dueDay > 31) {
      throw const FormatException('Informe um dia de 1 a 31.');
    }
    if (categoryId.isEmpty) {
      throw const FormatException('Selecione uma categoria.');
    }
  }
  final String description;
  final String categoryId;
  final int dueDay;
}

class TransactionDraft {
  TransactionDraft({
    required this.kind,
    required this.amount,
    required String description,
    required this.dueDate,
    required this.categoryId,
    this.notes = '',
    this.alreadyConfirmed = false,
    int? dueDay,
    this.isRecurring = false,
    this.totalInstallments,
  }) : dueDay = dueDay ?? dueDate.day,
       description = description.trim().isEmpty
           ? 'Lançamento'
           : description.trim() {
    if (!amount.isFinite || amount <= 0) {
      throw const FormatException('Informe um valor válido maior que zero.');
    }
    if (this.dueDay < 1 || this.dueDay > 31) {
      throw const FormatException('Informe um dia de 1 a 31.');
    }
    if (isRecurring && alreadyConfirmed) {
      throw const FormatException(
        'Confirme cada mês da recorrência em Finanças.',
      );
    }
    if (categoryId.isEmpty) {
      throw const FormatException('Selecione uma categoria.');
    }
    if (totalInstallments != null &&
        (!isRecurring || totalInstallments! < 2 || totalInstallments! > 1200)) {
      throw const FormatException('Informe de 2 a 1200 parcelas.');
    }
  }
  final TransactionKind kind;
  final double amount;
  final String description;
  final DateTime dueDate;
  final String categoryId;
  final String notes;
  final bool alreadyConfirmed;
  final int dueDay;
  final bool isRecurring;
  final int? totalInstallments;
  Map<String, dynamic> get template => {
    'type': kind.databaseValue,
    'amount': amount,
    'description': description,
    'notes': notes.trim(),
    'category_id': categoryId,
  };
}

class RecurrencePlan {
  const RecurrencePlan({
    required this.id,
    required this.firstDue,
    required this.description,
    required this.amount,
    this.dueDay,
    this.totalInstallments,
    this.endDate,
    this.futureAmounts = const [],
  });
  final String id;
  final DateTime firstDue;
  final int? dueDay;
  int get monthlyDay => dueDay ?? firstDue.day;
  final String description;
  final double amount;
  final int? totalInstallments;
  final DateTime? endDate;
  final List<Map<String, dynamic>> futureAmounts;
  double amountAt(DateTime month) =>
      AmountSchedule(amount, futureAmounts).at(monthKey(month)).toDouble();

  DateTime? get lastDue => totalInstallments == null
      ? null
      : monthlyDueDate(firstDue, totalInstallments! - 1, day: monthlyDay);
  DateTime? get effectiveEnd {
    final last = lastDue;
    if (endDate == null) return last;
    return last == null || endDate!.isBefore(last) ? endDate : last;
  }

  bool isFinished(DateTime today) =>
      effectiveEnd?.isBefore(DateTime(today.year, today.month, today.day)) ??
      false;
  factory RecurrencePlan.fromMap(Map<String, dynamic> data) {
    final template = Map<String, dynamic>.from(data['template'] as Map);
    return RecurrencePlan(
      id: data['id'].toString(),
      firstDue: DateTime.parse(data['first_due'].toString()),
      dueDay: (data['due_day'] as num?)?.toInt(),
      description: template['description'].toString(),
      amount: (template['amount'] as num).toDouble(),
      totalInstallments: (data['total_installments'] as num?)?.toInt(),
      endDate: DateTime.tryParse(data['end_date']?.toString() ?? ''),
      futureAmounts: List<Map<String, dynamic>>.from(
        template['future_amounts'] as List? ?? [],
      ),
    );
  }
}

class RecurrenceReference {
  const RecurrenceReference(this.ruleId, this.month);
  final String ruleId;
  final DateTime month;
  static RecurrenceReference? fromEntryId(String id) {
    if (!id.startsWith('r:')) return null;
    final parts = id.split(':');
    final month = parts.length == 3 ? DateTime.tryParse(parts[2]) : null;
    if (month == null ||
        month.day != 1 ||
        parts[1].isEmpty ||
        monthKey(month) != parts[2]) {
      throw const FormatException('Identificador de recorrência inválido.');
    }
    return RecurrenceReference(parts[1], month);
  }

  String get databaseMonth => monthKey(month);
}
