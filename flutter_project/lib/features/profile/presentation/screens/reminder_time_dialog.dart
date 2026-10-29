import 'package:flutter/material.dart';

class ReminderTimeDialog extends StatefulWidget {
  const ReminderTimeDialog({super.key, required this.initialTime});

  final TimeOfDay initialTime;

  @override
  State<ReminderTimeDialog> createState() => _ReminderTimeDialogState();
}

class _ReminderTimeDialogState extends State<ReminderTimeDialog> {
  late int _hour = widget.initialTime.hour;
  late int _minute = widget.initialTime.minute;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Horário dos lembretes'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Escolha a hora e os minutos do aviso diário.'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: _hour,
                decoration: const InputDecoration(labelText: 'Hora'),
                items: [
                  for (var hour = 0; hour < 24; hour++)
                    DropdownMenuItem(
                      value: hour,
                      child: Text(hour.toString().padLeft(2, '0')),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _hour = value);
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(':'),
            ),
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: _minute,
                decoration: const InputDecoration(labelText: 'Minutos'),
                items: [
                  for (var minute = 0; minute < 60; minute++)
                    DropdownMenuItem(
                      value: minute,
                      child: Text(minute.toString().padLeft(2, '0')),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _minute = value);
                },
              ),
            ),
          ],
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () =>
            Navigator.pop(context, TimeOfDay(hour: _hour, minute: _minute)),
        child: const Text('Salvar'),
      ),
    ],
  );
}
