/// Funções de data compartilhadas pelo domínio, pelos repositórios e pelas telas.
library;

String _pad(int value, [int width = 2]) => value.toString().padLeft(width, '0');

/// Data no formato aceito pelo banco: AAAA-MM-DD.
String isoDate(DateTime date) =>
    '${_pad(date.year, 4)}-${_pad(date.month)}-${_pad(date.day)}';

/// Primeiro dia do mês (AAAA-MM-01), chave das ocorrências mensais.
String monthKey(DateTime date) => isoDate(DateTime(date.year, date.month));

/// Dias de calendário entre hoje e o vencimento, sem efeito do horário de verão.
int daysUntil(DateTime dueDate, DateTime today) => DateTime.utc(
  dueDate.year,
  dueDate.month,
  dueDate.day,
).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
