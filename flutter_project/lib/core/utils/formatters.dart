import 'package:intl/intl.dart';

/// Formatadores utilitários para valores monetários e datas
class AppFormatters {
  static final NumberFormat currency =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  static final DateFormat date = DateFormat('dd/MM/yyyy');
  static final DateFormat monthYear = DateFormat('MMMM yyyy', 'pt_BR');
}
