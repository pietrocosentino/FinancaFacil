import 'package:flutter/material.dart';

/// Diálogo de confirmação padrão. Retorna `true` somente quando o usuário
/// escolhe a ação de confirmação; fechar ou cancelar retorna `false`.
/// [warning] aparece destacado abaixo da mensagem, para consequências que o
/// usuário precisa ler antes de confirmar.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancelar',
  String? warning,
  bool destructive = false,
  bool prominent = false,
  bool scrollable = false,
  bool barrierDismissible = true,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      final label = Text(
        confirmLabel,
        style: destructive ? TextStyle(color: scheme.error) : null,
      );
      void confirm() => Navigator.pop(context, true);
      return AlertDialog(
        title: Text(title),
        scrollable: scrollable || warning != null,
        content: warning == null
            ? Text(message)
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(message),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lock_outline,
                          color: scheme.onErrorContainer,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            warning,
                            style: TextStyle(
                              color: scheme.onErrorContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
