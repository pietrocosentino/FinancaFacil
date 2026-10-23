import 'package:flutter/material.dart';

/// Diálogo de confirmação padrão. Retorna `true` somente quando o usuário
/// escolhe a ação de confirmação; fechar ou cancelar retorna `false`.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancelar',
  bool destructive = false,
  bool prominent = false,
  bool scrollable = false,
  bool barrierDismissible = true,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (context) {
      final label = Text(
        confirmLabel,
        style: destructive
            ? TextStyle(color: Theme.of(context).colorScheme.error)
            : null,
      );
      void confirm() => Navigator.pop(context, true);
      return AlertDialog(
        title: Text(title),
        scrollable: scrollable,
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelLabel),
          ),
          prominent
              ? ElevatedButton(onPressed: confirm, child: label)
              : TextButton(onPressed: confirm, child: label),
        ],
      );
    },
  );
  return confirmed == true;
}
