import 'package:flutter/services.dart';

String phoneDigits(String value) => value.replaceAll(RegExp(r'\D'), '');

String formatPhone(String value) {
  final digits = phoneDigits(value);
  if (digits.length < 3 || digits.length > 11) return digits;
  final local = digits.substring(2);
  final split = local.length > 8 ? 5 : 4;
  final rest = local.length > split
      ? '${local.substring(0, split)}-${local.substring(split)}'
      : local;
  return '(${digits.substring(0, 2)}) $rest';
}

class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (!newValue.composing.isCollapsed) return newValue;
    var digits = phoneDigits(newValue.text);
    if (digits.length > 15) return oldValue;
    final selection = newValue.selection;
    var beforeCursor = phoneDigits(newValue.text.substring(0,
            selection.isValid ? selection.extentOffset : newValue.text.length))
        .length;

    // Apagar um separador também apaga o dígito anterior, evitando uma máscara
    // que parece não responder ao backspace.
    if (selection.isCollapsed &&
        newValue.text.length < oldValue.text.length &&
        digits == phoneDigits(oldValue.text) &&
        beforeCursor > 0) {
      digits = digits.replaceRange(beforeCursor - 1, beforeCursor, '');
      beforeCursor--;
    }
    final text = formatPhone(digits);
    return TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(
            offset: _offsetAfterDigits(text, beforeCursor)));
  }

  int _offsetAfterDigits(String text, int count) {
    if (count == 0) return 0;
    var seen = 0;
    for (var index = 0; index < text.length; index++) {
      if (RegExp(r'\d').hasMatch(text[index]) && ++seen == count) {
        return index + 1;
      }
    }
    return text.length;
  }
}
