import 'package:financafacil/core/utils/finance_utils.dart';
import 'package:financafacil/core/utils/phone_formatter.dart';
import 'package:financafacil/features/transactions/domain/finance_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Entrada monetária', () {
    test('rejeita agrupamentos ambíguos e notação científica', () {
      for (final value in ['1.2,3', '1,2,3', '1e3', '1.000.00', 'NaN']) {
        expect(parseMoney(value), isNull, reason: value);
      }
    });
    test('preserva os formatos decimal e brasileiro válidos', () {
      for (final value in ['1234.56', '1234,56', '1.234,56', 'R\$ 1.234,56']) {
        expect(parseMoney(value), 1234.56, reason: value);
      }
      expect(parseMoney('.50'), .5);
      expect(parseMoney('90,60'), 90.6);
    });
  });

  group('Máscara de telefone', () {
    final formatter = PhoneInputFormatter();
    test('corrigir dígito no meio mantém o cursor no ponto da edição', () {
      final result = formatter.formatEditUpdate(
        const TextEditingValue(text: '(11) 99999-9999'),
        const TextEditingValue(
          text: '(11) 89999-9999',
          selection: TextSelection.collapsed(offset: 6),
        ),
      );
      expect(result.text, '(11) 89999-9999');
      expect(result.selection.extentOffset, 6);
    });
    test('backspace no separador não prende o usuário na máscara', () {
      final result = formatter.formatEditUpdate(
        const TextEditingValue(
          text: '(11) 99999-9999',
          selection: TextSelection.collapsed(offset: 10),
        ),
        const TextEditingValue(
          text: '(11) 999999999',
          selection: TextSelection.collapsed(offset: 9),
        ),
      );
      expect(phoneDigits(result.text), '1199999999');
      expect(result.selection.extentOffset, lessThan(result.text.length));
    });
    test('respeita composição do teclado', () {
      const composing = TextEditingValue(
        text: '119',
        composing: TextRange(start: 0, end: 3),
      );
      expect(
        formatter.formatEditUpdate(TextEditingValue.empty, composing),
        composing,
      );
    });
    test('limita a 15 dígitos sem apagar a entrada anterior', () {
      const old = TextEditingValue(text: '123456789012345');
      expect(
        formatter.formatEditUpdate(
          old,
          const TextEditingValue(text: '1234567890123456'),
        ),
        old,
      );
    });
  });

  test(
    'referências mensais não normalizam silenciosamente datas inválidas',
    () {
      for (final id in [
        'r:rule:2027-13-01',
        'r:rule:2027-02-30',
        'r:rule:2027-01-01T00:00:00',
        'r::2027-01-01',
      ]) {
        expect(
          () => RecurrenceReference.fromEntryId(id),
          throwsFormatException,
          reason: id,
        );
      }
      expect(
        RecurrenceReference.fromEntryId('r:rule:2027-02-01')!.databaseMonth,
        '2027-02-01',
      );
    },
  );
}
