/// Aceita 1234.56, 1234,56 e 1.234,56. Rejeita valores não finitos.
double? parseMoney(String input) {
  var value = input.trim().replaceAll(RegExp(r'\s'), '').replaceAll(r'R$', '');
  if (value.contains(',')) {
    if (!RegExp(r'^(?:\d+|\d{1,3}(?:\.\d{3})+),\d+$').hasMatch(value)) {
      return null;
    }
    value = value.replaceAll('.', '').replaceAll(',', '.');
  } else if (!RegExp(r'^(?:\d+(?:\.\d*)?|\.\d+)$').hasMatch(value)) {
    return null;
  }
  final result = double.tryParse(value);
  return result != null && result.isFinite && result > 0 ? result : null;
}

/// Conserva o mês de destino para vencimentos em dias 29, 30 e 31.
DateTime monthlyDueDate(DateTime start, int offset, {int? day}) {
  final first = DateTime(start.year, start.month + offset, 1);
  final lastDay = DateTime(first.year, first.month + 1, 0).day;
  final requestedDay = day ?? start.day;
  return DateTime(
      first.year, first.month, requestedDay > lastDay ? lastDay : requestedDay);
}
